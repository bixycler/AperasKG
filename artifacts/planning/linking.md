# Linking — Planning

## Implementation Plan <a name='--linking---planning/---implementation-plan' class='aperas-anchor aperas-tree'></a>
Two slices carry [design/linking.md](../design/linking.md)'s addressing convention to a working implementation:

- **Slice 1** (this pass): the mechanism itself — lead-in-term title extraction, recognizing `aperas://`/`#fragment` link forms, and id-anchor emission (both headings and list items).
- **Slice 2** (next pass, placeholder below): everything that depends on Slice 1 being live, or applies the convention beyond this corpus's own four docs — the cleanup pass, the leading-part translator, and corpus-wide rollout/migration of existing docs. Detailed tasks for these already exist in [issues/linking.md](../issues/linking.md#--linking---issues/---pending-tasks)'s Pending Tasks; Slice 2 isn't broken down here yet since it shouldn't be designed in detail until Slice 1's actual shape is known.

No anchor *recognition/absorption* mechanism is needed for Slice 1 — a hand-written tree anchor is left as ordinary content and round-trips today with zero new code, confirmed live (see [Dropping anchor recognition entirely](../discussion/linking.md#--internal-linking---addressing---discussion/---dropping-anchor-recognition-entirely)). The only new mechanism is emitting a fresh id-anchor at projection time.

## Task Breakdown <a name='--linking---planning/---task-breakdown' class='aperas-anchor aperas-tree'></a>

### Slice 1 <a name='--linking---planning/---task-breakdown/----slice-1' class='aperas-anchor aperas-tree'></a>
1. **Lead-in-term title extraction** (`astParser.ts`) — landed as `findLeadInColonOffset`/`extractLeadInTitle`, revised after live corpus ingestion surfaced real corruption from the originally-planned raw-character scan; see [Lead-In Term Detection](../design/linking.md#--internal-linking---addressing/---topology/----lead-in-term-detection) for the settled rule and [Finding the real lead-in colon](../discussion/linking.md#--internal-linking---addressing---discussion/---finding-the-real-lead-in-colon) for why.
   - Walks the block's own parsed inline mdast nodes, not raw characters — a candidate colon (or `：` for Japanese) must sit in plain text, never inside `inlineCode` or a `strong`/`emphasis` span.
   - Gated by a length cap (10 words / 20 Japanese characters) and, for a space-delimited script, a following-whitespace check — both needed on top of the code/bold exclusion, not instead of it.
   - Which script's rules apply comes from a new `lang: en|ja|vi` frontmatter field (`extractLangFromFrontmatter`), threaded through both parsing and projection.
   - No qualifying colon found → keep the existing `blockId` fallback (astParser.ts:274) unchanged.
   - `text` is left completely unmodified by this — `title` is a read-only label extracted from (not cut out of) the span before the colon. Safe because `serializeListItem`/the paragraph projection case already render from `text` alone and never touch a list item's/paragraph's `title`, so there's nothing to reassemble at projection.
   - Superseded `kg:title` entirely rather than coexisting with it — see [History](../history/linking.md#--linking---history/---milestones).

2. **Recognizing `aperas://` and `#fragment` forms** (`astParser.ts` + `apeironNgn/artifacts.ts`)
   - Extend `collectLinkCodes`'s matching (currently only `LINK_URL_RE`, astParser.ts:107,152).
   - `aperas://tree/<path>` / `aperas://id/<ID>` — pass through verbatim; `resolveDeepPathDetail` (`resolveCreate.ts`) already dispatches on these prefixes for resolution.
   - A relative link with a `#fragment`: an `id/<ID>` fragment reroutes to the direct-id tier, ignoring the file-path part; any other fragment flattens `#` to `/` and reuses the existing folder/file/heading deep-path grammar (sound — `slugify` is idempotent on an already-slugified segment) — but only once the leading file-path part (`../folder/file`, or empty for a same-document fragment) has been turned into a canonical artifact path first (next bullet); the grammar's own `..` isn't usable directly on it.
   - The existing `[[code]]` bracket form keeps working unchanged — additive, not a replacement.
   - **Leading-part translator, built in full here** (a new module, e.g. `apeironNgn/leadingPart.ts`): resolving a compatible-context fragment link at all already requires converting its OS-relative leading part into a canonical artifact path — `resolveCreate.ts`'s own `..` counts every segment (folder, filename, heading) as one uniform hop, a different rule than an ordinary relative file path uses (a filename isn't its own directory level), so the grammar's `..` can't be fed the raw leading part directly. Since that conversion has to exist anyway just to resolve, build both directions of it together now rather than half now (relative → canonical, for resolution) and the other half later for the cleanup pass (canonical → relative, to emit/rewrite a compatible link from a resolved target) — splitting them across two slices would mean designing the same path arithmetic twice, inconsistently. Only the relative → canonical direction is actually called by this slice; the reverse sits ready, unused until Slice 2's cleanup pass needs it.
   - **Required companion fix**, `artifacts.ts`'s `resolveBlockLinks` (~line 221): its `titles: code.split('/').filter(...)` is a separate, non-resolution computation for `--create-holder`'s placeholder-naming, tail-aligned against the resolver's own name-token count (`resolveCreate.ts:113-116`). It isn't scheme-aware, so for an `aperas://tree/...` code it produces extra bogus entries (`"aperas:"`, `"tree"`) that survive the existing empty/`.`/`..` filter — pushing `titles.length` past `nameCount` and hitting `resolveCreate.ts:113-116`'s existing `titles.length > nameCount` throw for *every* `aperas://`-prefixed link, not just producing a wrong holder name. Needs to strip the `aperas://tree/` prefix (or use `[]` for `aperas://id/` codes, which have zero name-tokens) before this split.
   - **Resolution gate, required for disambiguation**: a `#fragment` link has no `[[...]]`-style wrapper to mark intent, so it's syntactically identical to an ordinary, unrelated same-page anchor link. After the existing name-token/id walk finds a *candidate* target, only accept it if that candidate also carries a `class="aperas-anchor"` tag whose `name` equals the fragment — the heading's stashed anchor prop (Task 3), or a literal scan of a list item's/paragraph's own `text` (no prop is kept for these). See [Distinguishing a wikilink from an ordinary anchor link](../discussion/linking.md#--internal-linking---addressing---discussion/---distinguishing-a-wikilink-from-an-ordinary-anchor-link) for why a syntactic heuristic (e.g. requiring a leading dash) isn't enough on its own — it only covers heading-derived slugs, not list-item ones.

3. **Id-anchor emission** (`astParser.ts` parsing + `project.ts` projection)
   - **Heading**:
     - Before assigning `title = rawText` (astParser.ts:279), check for a trailing `<a name='...' class='aperas-anchor aperas-(tree|id)'></a>` on the raw line.
     - If present, strip it from `title` and stash the anchor markup in a prop (`setProp`) — survives reconciliation via the generic props copy.
     - In `project.ts`'s heading case (project.ts:113-119), re-append: the stashed tree-anchor if present, and unconditionally an `<a name='id/<ID>' class='aperas-anchor aperas-id'>` for the block's own permanent id, both at line end.
     - See [Verifying anchor placement against the real parser](../discussion/linking.md#--internal-linking---addressing---discussion/---verifying-anchor-placement-against-the-real-parser) for why this placement, not a preceding line.
   - **List item / paragraph**:
     - No title-side change — the anchor lives in `text`, after the colon, as literal content.
     - In `project.ts` (`serializeListItem`, project.ts:157-167, and the paragraph case): when a block's `text` doesn't already contain its own `id/<ID>` anchor, splice `<a name='id/<ID>' class='aperas-anchor aperas-id'></a> ` in right after the first `:`.
     - Idempotency matters — re-projecting an already-anchored block must not duplicate it.

### Slice 2 <a name='--linking---planning/---task-breakdown/----slice-2' class='aperas-anchor aperas-tree'></a>
Placeholder — not broken down yet. Covers, at the level of detail already tracked in [issues/linking.md](../issues/linking.md#--linking---issues/---pending-tasks): the cleanup pass (removes an `aperas-tree` anchor once every referrer has migrated, consuming Slice 1's already-built leading-part translator to emit/rewrite compatible links from a resolved target), and corpus-wide rollout/migration (`Aperas-apeironngn-design.md`'s `[[deep-path]]` self-references, `issues/documentation.md`'s two remaining links, the colon-lead-in convention beyond the `linking` concern's own docs). To be broken down into the same task-by-task detail as Slice 1 once Slice 1 has actually landed.

## Verification Plan <a name='--linking---planning/---verification-plan' class='aperas-anchor aperas-tree'></a>

### Slice 1 <a name='--linking---planning/---verification-plan/----slice-1' class='aperas-anchor aperas-tree'></a>
Reuse the scratch-ingest methodology already used while planning this (write a throwaway artifact under a scratch subfolder of the real `AperasKG/artifacts/`, matching `verify.ts`'s own `DEMO_DIR` pattern; `rehydrateStore()` the real mirror in-memory, never dehydrated back; `trackArtifact`/`ingestFolderTree`/`ingestArtifact`; read back via `wrap()`; `rmSync` the scratch folder after). Concretely check:
- A heading with a hand-written tree-anchor at line-end: `title` is clean, the anchor survives in a prop, and projecting re-emits both anchors at line end in the right order.
- A heading with genuine leading prose *and* a tree-anchor: prose stays exactly as `text`, unaffected — this was the live-verified regression to guard against.
- A list item with a colon and no anchor: projecting adds the id-anchor once, right after the colon; re-projecting the same already-ingested content doesn't duplicate it.
- The `aperas://id/<ID>` and `../file#id/<ID>` link forms both resolve to the same target as the equivalent `[[Kind:snowflake]]` form does today.
- A `#fragment` link whose text happens to match some block's title, but that block carries no `aperas-anchor` tag, does *not* resolve — the anchor-matching gate correctly rejects the candidate rather than treating it as a wikilink.

Longer-term, this scratch-ingest check is worth folding into `verify.ts` as a new numbered step — not required to land this slice, but tracked in [issues/linking.md](../issues/linking.md#--linking---issues/---pending-tasks) so it isn't lost.

### Slice 2 <a name='--linking---planning/---verification-plan/----slice-2' class='aperas-anchor aperas-tree'></a>
Placeholder — not broken down yet. Depends on Slice 2's own task breakdown existing first.
