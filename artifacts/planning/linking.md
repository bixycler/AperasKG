# Linking — Planning <a name='id/BlockNode:00CDBZ77EG001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CDBZ77EG002' class='aperas-anchor aperas-id'></a>

Two slices carry [design/linking.md](../design/linking.md)'s addressing convention to a working implementation:

- **Slice 1** (landed): <a name='id/BlockNode:00CDBZ77EG003' class='aperas-anchor aperas-id'></a> the mechanism itself — lead-in-term title extraction, recognizing `aperas://`/`#fragment` link forms, and id-anchor emission (both headings and list items).
- **Slice 2** (landed): <a name='id/BlockNode:00CDBZ77EG004' class='aperas-anchor aperas-id'></a> completes the toolset for working directly on Apeiron — collision rejection at ingestion, the cleanup pass, and folding Slice 1's own verification into `verify.ts`. Corpus-wide rollout of the convention (correcting non-compliant colon lead-ins, migrating old-style `[[deep-path]]` links) is a separate topic, not detailed here.

No anchor *recognition/absorption* mechanism is needed for Slice 1 — a hand-written tree anchor is left as ordinary content and round-trips today with zero new code, confirmed live (see [Dropping anchor recognition entirely](../discussion/linking.md#id/BlockNode:00CDBZ76TG003)). The only new mechanism is emitting a fresh id-anchor at projection time.

## Task Breakdown <a name='id/BlockNode:00CDBZ77F0001' class='aperas-anchor aperas-id'></a>

### Slice 1 <a name='id/BlockNode:00CDBZ77F0002' class='aperas-anchor aperas-id'></a>

1. [x] **Lead-in-term title extraction** (`astParser.ts`) — landed as `findLeadInColonOffset`/`extractLeadInTitle`, revised after live corpus ingestion surfaced real corruption from the originally-planned raw-character scan; see [Lead-In Term Detection](../design/linking.md#id/BlockNode:00CDBYV4TG000) for the settled rule and [Finding the real lead-in colon](../discussion/linking.md#id/BlockNode:00CDBZ76TR000) for why.
   
   - Walks the block's own parsed inline mdast nodes, not raw characters — a candidate colon (or `：` for Japanese) must sit in plain text, never inside `inlineCode` or a `strong`/`emphasis` span.
   - Gated by a length cap (10 words / 20 Japanese characters) and, for a space-delimited script, a following-whitespace check — both needed on top of the code/bold exclusion, not instead of it.
   - Which script's rules apply comes from a new `lang: en|ja|vi` frontmatter field (`extractLangFromFrontmatter`), threaded through both parsing and projection.
   - No qualifying colon found → keep the existing `blockId` fallback (astParser.ts:274) unchanged.
   - `text` is left completely unmodified by this — `title` is a read-only label extracted from (not cut out of) the span before the colon. Safe because `serializeListItem`/the paragraph projection case already render from `text` alone and never touch a list item's/paragraph's `title`, so there's nothing to reassemble at projection.
   - Superseded `kg:title` entirely rather than coexisting with it — see [History](../history/linking.md#id/BlockNode:00CDBZ7698003).
2. [x] **Recognizing `aperas://` and `#fragment` forms** (`astParser.ts` + `apeironNgn/artifacts.ts`)
   
   - Extend `collectLinkCodes`'s matching (currently only `LINK_URL_RE`, astParser.ts:107,152).
   - `aperas://tree/<path>` / `aperas://id/<ID>` — pass through verbatim; `resolveDeepPathDetail` (`resolveCreate.ts`) already dispatches on these prefixes for resolution.
   - A relative link with a `#fragment`: <a name='id/BlockNode:00CDBZ77F000E' class='aperas-anchor aperas-id'></a> an `id/<ID>` fragment reroutes to the direct-id tier, ignoring the file-path part; any other fragment flattens `#` to `/` and reuses the existing folder/file/heading deep-path grammar (sound — `slugify` is idempotent on an already-slugified segment) — but only once the leading file-path part (`../folder/file`, or empty for a same-document fragment) has been turned into a canonical artifact path first (next bullet); the grammar's own `..` isn't usable directly on it.
   - The existing `[[code]]` bracket form keeps working unchanged — additive, not a replacement.
   - **Leading-part translator, built in full here** (a new module, e.g. `apeironNgn/leadingPart.ts`): resolving a compatible-context fragment link at all already requires converting its OS-relative leading part into a canonical artifact path — `resolveCreate.ts`'s own `..` counts every segment (folder, filename, heading) as one uniform hop, a different rule than an ordinary relative file path uses (a filename isn't its own directory level), so the grammar's `..` can't be fed the raw leading part directly. Since that conversion has to exist anyway just to resolve, build both directions of it together now rather than half now (relative → canonical, for resolution) and the other half later for the cleanup pass (canonical → relative, to emit/rewrite a compatible link from a resolved target) — splitting them across two slices would mean designing the same path arithmetic twice, inconsistently. Only the relative → canonical direction is actually called by this slice; the reverse sits ready, unused until Slice 2's cleanup pass needs it.
   - **Required companion fix**, `artifacts.ts`'s `resolveBlockLinks` (~line 221): <a name='id/BlockNode:00CDBZ77F000H' class='aperas-anchor aperas-id'></a> its `titles: code.split('/').filter(...)` is a separate, non-resolution computation for `--create-holder`'s placeholder-naming, tail-aligned against the resolver's own name-token count (`resolveCreate.ts:113-116`). It isn't scheme-aware, so for an `aperas://tree/...` code it produces extra bogus entries (`"aperas:"`, `"tree"`) that survive the existing empty/`.`/`..` filter — pushing `titles.length` past `nameCount` and hitting `resolveCreate.ts:113-116`'s existing `titles.length > nameCount` throw for *every* `aperas://`-prefixed link, not just producing a wrong holder name. Needs to strip the `aperas://tree/` prefix (or use `[]` for `aperas://id/` codes, which have zero name-tokens) before this split.
   - **Resolution gate, required for disambiguation**: <a name='id/BlockNode:00CDBZ77F000J' class='aperas-anchor aperas-id'></a> a `#fragment` link has no `[[...]]`-style wrapper to mark intent, so it's syntactically identical to an ordinary, unrelated same-page anchor link. After the existing name-token/id walk finds a *candidate* target, only accept it if that candidate also carries a `class="aperas-anchor"` tag whose `name` equals the fragment — the heading's stashed anchor prop (Task 3), or a literal scan of a list item's/paragraph's own `text` (no prop is kept for these). See [Distinguishing a wikilink from an ordinary anchor link](../discussion/linking.md#id/BlockNode:00CDBZ76TG006) for why a syntactic heuristic (e.g. requiring a leading dash) isn't enough on its own — it only covers heading-derived slugs, not list-item ones.
3. [x] **Id-anchor emission** (`astParser.ts` parsing + `project.ts` projection). **Caveat found later**: <a name='id/BlockNode:00CDBZ77F000K' class='aperas-anchor aperas-id'></a> the list-item/paragraph idempotency property this was built to guarantee (see the "List item / paragraph" sub-item below) currently fails `verify.ts`'s own step 13 check ("re-projecting an already-anchored list item duplicates/loses its id-anchor") — reproduces on a clean checkout with no unrelated changes applied, root cause not yet investigated.
   
   - **Heading**: <a name='id/BlockNode:00CDBZ77F000M' class='aperas-anchor aperas-id'></a>
     
     - Before assigning `title = rawText` (astParser.ts:279), check for a trailing `<a name='...' class='aperas-anchor aperas-(tree|id)'></a>` on the raw line.
     - If present, strip it from `title` and stash the anchor markup in a prop (`setProp`) — survives reconciliation via the generic props copy.
     - In `project.ts`'s heading case (project.ts:113-119), re-append: <a name='id/BlockNode:00CDBZ77F000Q' class='aperas-anchor aperas-id'></a> the stashed tree-anchor if present, and unconditionally an `<a name='id/<ID>' class='aperas-anchor aperas-id'>` for the block's own permanent id, both at line end.
     - See [Verifying anchor placement against the real parser](../discussion/linking.md#id/BlockNode:00CDBZ76TG004) for why this placement, not a preceding line.
   - **List item / paragraph**: <a name='id/BlockNode:00CDBZ77F000S' class='aperas-anchor aperas-id'></a>
     
     - No title-side change — the anchor lives in `text`, after the colon, as literal content.
     - In `project.ts` (`serializeListItem`, project.ts:157-167, and the paragraph case): <a name='id/BlockNode:00CDBZ77F000V' class='aperas-anchor aperas-id'></a> when a block's `text` doesn't already contain its own `id/<ID>` anchor, splice `<a name='id/<ID>' class='aperas-anchor aperas-id'></a> ` in right after the first `:`.
     - Idempotency matters — re-projecting an already-anchored block must not duplicate it.

### Slice 2 <a name='id/BlockNode:00CDBZ77F000X' class='aperas-anchor aperas-id'></a>

Completes the toolset needed to work directly on Apeiron day-to-day: reject a real authoring mistake at ingestion time, let a compatibility anchor actually retire once it's safe to, and cover Slice 1's own mechanism in `verify.ts`. Corpus-wide rollout — correcting non-compliant colon lead-ins and migrating old-style `[[deep-path]]` links — is a separate topic, out of scope here.

1. [x] **Fold Slice 1's scratch-ingest verification into `verify.ts`** — landed as `verify.ts`'s step 13, following its existing pattern (`DEMO_DIR` scratch artifacts, thrown-`Error` assertions).
   
   - Covers: <a name='id/BlockNode:00CDBZ77F000Z' class='aperas-anchor aperas-id'></a> a heading's tree-anchor+id-anchor round trip; a heading with genuine leading prose staying unaffected; a list item's id-anchor splice idempotency (via its *parent's* projection — a bare `listItem` has no `serializeBlock` case of its own, `serializeListItem` is only ever invoked by the parent's `renderChildren`); `aperas://id/<ID>`, `../file#id/<ID>`, and `[[Kind:snowflake]]` (written as a real link, `[title](<[[code]]>)` — a bare, unwrapped `[[code]]` was never itself a recognized link, see [History](../history/linking.md#id/BlockNode:00CDBZ7698003)) all resolving identically; the anchor-matching gate correctly rejecting a title-only match with no anchor.
2. [x] **Full-slug-path collision rejection** — landed as `apeironNgn/node.ts`'s `rejectSlugPathCollisions`, called from three write paths: `ArtifactNode.ingestFromDisk` (a whole artifact's fresh parse, right before `hydrateFromParsed`), `kg:insert`'s create mode (a new subtree under an arbitrary live parent), and `kg:update`'s heading-rename path (a single renamed title, checked against its own parent's path) — every place a block's title can be set or changed now shares the same check.
   
   - [Full-Path Collisions](../design/linking.md#id/BlockNode:00CDBYV4TG006) is a writer-facing authoring rule, not a system-managed lifecycle concept — the system's only job is to detect a violation and refuse it, never to fix it or track history on the writer's behalf.
   - A collision is the new block's computed slug-path matching another live block's current `toPath()`, *or* any anchor `name` still embedded in that block's `treeAnchor` prop or raw text — [Anchor-Matching Requirement for Resolution](../design/linking.md#id/BlockNode:00CDBYV4TG005) already treats either as a live resolvable target today, so both are real collisions, not just the current title. `astParser.ts`'s `extractAnchorNames` is the new find-all counterpart to `TRAILING_HEADING_ANCHOR_RE` this needed, for the list-item/paragraph case (headings already had a way via `treeAnchor`).
   - On collision: <a name='id/BlockNode:00CDCMWPC8003' class='aperas-anchor aperas-id'></a> throws, rejecting the whole write (no partial write), naming both colliding blocks/paths. See [A bare snowflake isn't a full node id](../discussion/linking.md#id/BlockNode:00CDBZ76TR00C) for a real bug this surfaced while landing it.
   - `kg:update`'s own check covers only the renamed heading itself, not its separately-reconciled overflow subtree — a freshly-introduced multi-level tree is `kg:insert`'s own check to catch.
3. [x] **The cleanup pass** — landed as documented: <a name='id/BlockNode:00CDBZ77F0014' class='aperas-anchor aperas-id'></a> no new removal API, since none was needed.
   
   - Confirming "every referrer has switched" can't rely on `kg:backlinks` alone — it only queries the graph, so it only sees referrers that have themselves already been tracked/ingested into Apeiron; a file with an old-style reference that isn't tracked, or hasn't been re-ingested since converting, wouldn't show up there and would be missed. A full-text search across the corpus (every markdown file, tracked or not) is what actually confirms it.
   - Once that comes back clean, removal is a blanket mechanical strip: every `<a name='...' class='aperas-anchor aperas-tree'></a>` tag, wherever it appears, deleted directly from its source text — not a careful case-by-case edit per block.
   - Re-ingest afterward. Nothing else is needed: <a name='id/BlockNode:00CDBZ77F8001' class='aperas-anchor aperas-id'></a> a heading's `treeAnchor` prop (and a list item/paragraph's embedded anchor) is derived fresh from the current file text on every ingestion — `carryForwardFields` already rebuilds `props` from scratch each time — so once the anchor is gone from the text, it's gone from the graph too, confirmed live (`verify.ts` step 15) with no separate prop-removal step ever needed.

## Verification Plan <a name='id/BlockNode:00CDBZ77F8002' class='aperas-anchor aperas-id'></a>

### Slice 1 <a name='id/BlockNode:00CDBZ77F8003' class='aperas-anchor aperas-id'></a>

Reuse the scratch-ingest methodology already used while planning this (write a throwaway artifact under a scratch subfolder of the real `AperasKG/artifacts/`, matching `verify.ts`'s own `DEMO_DIR` pattern; `rehydrateStore()` the real mirror in-memory, never dehydrated back; `trackArtifact`/`ingestFolderTree`/`ingestArtifact`; read back via `wrap()`; `rmSync` the scratch folder after). Concretely check:

- A heading with a hand-written tree-anchor at line-end: <a name='id/BlockNode:00CDBZ77F8004' class='aperas-anchor aperas-id'></a> `title` is clean, the anchor survives in a prop, and projecting re-emits both anchors at line end in the right order.
- A heading with genuine leading prose *and* a tree-anchor: <a name='id/BlockNode:00CDBZ77F8005' class='aperas-anchor aperas-id'></a> prose stays exactly as `text`, unaffected — this was the live-verified regression to guard against.
- A list item with a colon and no anchor: <a name='id/BlockNode:00CDBZ77F8006' class='aperas-anchor aperas-id'></a> projecting adds the id-anchor once, right after the colon; re-projecting the same already-ingested content doesn't duplicate it.
- The `aperas://id/<ID>` and `../file#id/<ID>` link forms both resolve to the same target as the equivalent `[[Kind:snowflake]]` form does today.
- A `#fragment` link whose text happens to match some block's title, but that block carries no `aperas-anchor` tag, does *not* resolve — the anchor-matching gate correctly rejects the candidate rather than treating it as a wikilink.

Longer-term, this scratch-ingest check is worth folding into `verify.ts` as a new numbered step — not required to land this slice, but tracked in [issues/linking.md](../issues/linking.md#id/BlockNode:00CDBYV5A8003) so it isn't lost.

### Slice 2 <a name='id/BlockNode:00CDBZ77F800A' class='aperas-anchor aperas-id'></a>

Landed as `verify.ts`'s steps 13-15, all three passing against the real corpus mirror:

- **Task 1** (step 13): <a name='id/BlockNode:00CDBZ77F800B' class='aperas-anchor aperas-id'></a> the Slice 1 checklist above, end to end.
- **Task 2** (step 14): <a name='id/BlockNode:00CDBZ77F800C' class='aperas-anchor aperas-id'></a> (a) two blocks with an identical fresh path in the same doc are rejected, (b) a new block colliding with another live block's current `toPath()` is rejected, (c) a new block colliding with another live block's still-embedded anchor name is also rejected, (d) no false positive when paths are genuinely distinct.
- **Task 3** (step 15): <a name='id/BlockNode:00CDBZ77F800D' class='aperas-anchor aperas-id'></a> deleting an anchor tag from a block's source text and re-ingesting drops it from `treeAnchor`/the graph, with no other block affected; a full-text safety search catches an old-style reference living in a file that isn't tracked/ingested, a case `kg:backlinks` alone misses.
