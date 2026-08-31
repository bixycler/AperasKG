# Interactive Title & Cross-Link Authoring — Design

**Implemented and live-verified.** `kg:title`/`kg:link` (`kgCli.ts`), `updateBlockNode` (`crud.ts`
§2), and the `reconcileNode`/`resolveBlockLinks` persistence fix (§4/§7) are all live against the
real `aperas` DB — a title and a cross-link set via these commands both survived a real
re-ingestion round-trip (confirmed via direct `doc get`, not just the tools' own success output).
One implementation-time bug found and fixed beyond what this doc anticipated: `rl.question()`
(readline/promises) races against stream-end when real `await`s happen between prompts — piped,
non-interactive stdin (the coding-agent-driving-the-tool case this doc is built around) hit both
an immediate throw and a silently-abandoned hung call depending on timing. Fixed by consuming the
readline interface's own async iterator instead of `.question()` — see `createLineReader` in
`kgCli.ts`. Also found live: `graphql.ts`'s block field selection never included `links` at all,
so `oldNode.links` was always `undefined` regardless of the `reconcileNode` fix — added `links {
_id }` to `blockFieldSelection` plus a `normalizeLinks` step (mirroring the existing
`normalizeProps`/`_json` pattern) to convert GraphQL's full-IRI `_id` down to the short ref-id
string form `updateDocument` expects.

## 0. Why interactive, not an LLM API call

`Aperas-design.md`'s Development Roadmap (Phase 3, "Preservation of manual skills &
zero-background-API sub-agent execution") already commits this project to a zero-background-API
posture: no tool embeds a secondary LLM API key or spawns a background summarization service.
Stage 2 item 5 (`Aperas-fractal-ontology-implementation-plan.md` §Stage 2) was originally framed
as "an AI summarization agent... integrated" during ingestion, but can be revised following the
zero-API-key principle.

The actual principle, restated for this feature: whoever is running the tool — a human, or a
coding agent that already *is* an LLM — already has the intelligence needed to write a title, or
name a cross-link. So the tool just asks, interactively, instead of calling out to anything. This
generalizes past titles: any future "AI task" in this codebase should be shaped the same way —
turn it into a CLI prompt for input, not a backend call. Cross-links (`BlockNode.links`) are the
second instance of this pattern covered here (§7) — the existing extraction is real but narrow
(literal `[[wikilink]]` syntax only, `astParser.ts:92-106`), so plenty of genuine references a
block's prose makes never become a `Link` today unless the author happened to use that syntax.

## 1. Scope

Two independent gaps, same interaction shape:

- `BlockNode.title`'s fallback — replacing the naive `title = blockId` default (`astParser.ts` —
  see `convertAstNode`'s default branch) for blocks that never got a real title. Heading blocks
  are excluded by construction: their `title` is already the heading's own text (never the
  blockId fallback), so there's nothing to prompt for.
- `BlockNode.links` — adding cross-links a block's prose actually makes but that wikilink syntax
  extraction (`astParser.ts:92-106`) didn't catch. See §7.

`ArtifactNode`/`FolderNode.text` (the file/folder abstract, naive first-paragraph fallback per
`Aperas-core-ontology-design.md`) is explicitly **out of scope for this pass** — see §6.

## 2. Shared write primitive (new — nothing like it exists today)

Confirmed live: `crud.ts` has no update/patch function at all — its only write path is
`insertAssertion`'s `client.addDocument(...)` (insert-only), plus the delete helpers. Nothing
wraps the TerminusDB client's own `updateDocument`/`replaceDocument`, and both `kg:title` and
`kg:link` need to change one field on an already-ingested `BlockNode` by id.

One shared primitive covers both, `crud.ts`:

```ts
async function updateBlockNode(
  client, blockId: string, patch: Partial<Pick<BlockNode, "title" | "links">>
): Promise<void>
```

Fetch the existing `BlockNode/<blockId>` document, shallow-merge `patch` onto it (for `links`,
append rather than replace — see §7), call the client's `updateDocument`/`replaceDocument` with
the merged full document (TerminusDB has no partial-field PATCH; a full-document replace is the
only write shape available, same as `artifacts.ts`'s existing per-`BlockNode` writes during
ingestion). Both `kg:title` and `kg:link` call this instead of re-running ingestion/reconciliation
just to change one field on one already-identified document.

## 3. `kg:title` command

```
kg:title <path>              # just the single node at <path> (no descendants)
kg:title <path> --recursive  # <path>'s full uniform tree, descendants included
```

`FolderNode`, `ArtifactNode`, and `BlockNode` aren't separate structural tiers with a boundary
between them — they're all just nodes in one unbounded tree, and `kg:tree`'s own
`childRefs`/`printTree` already walk all three through identical recursion with no kind-based
branching (`kgCli.ts:47-51,59` — `ArtifactNode`'s child is `root`, `FolderNode`/`BlockNode`'s are
`children`, same call either way). So `--recursive` here isn't gating a boundary between kinds —
it's the same uniform walk `kg:tree` does, just opt-in rather than opt-out. `kg:tree` can default
to unbounded depth because it's read-only and printing more costs nothing; `kg:title`/`kg:link`
are interactive, so defaulting to full depth would mean `kg:title .` could silently start a
thousand-block prompt session by accident. `--recursive` is that opt-in, not a kind distinction.
Pass the artifacts root with `--recursive` to sweep everything in one run.

For each `BlockNode` matching the fallback sentinel (§4), print the block's raw content (its
`text`, plus enough parent/path context to disambiguate) and read one line from stdin as the new
title.

- **Empty input / EOF** → leave the existing fallback untouched, move to the next block. Matches
  the original "AI unavailable → ID fallback" framing from `Aperas-core-ontology-design.md`,
  just with "no operator input given" standing in for "AI unavailable."
- **Non-empty input** → `updateBlockNode(client, blockId, { title })` (§2) immediately, then move
  to the next block.

## 4. Real bug this surfaces: titles don't survive re-ingestion (must fix first)

Confirmed live in `reconcile.ts`: `reconcileNode` (`reconcile.ts:234-236`) only carries
`newNode.blockId = oldNode.blockId` forward for a matched (content-unchanged) pair — every other
field, including `title`, comes from the fresh parse. `astParser.ts`'s `ingestArtifact` then
writes the whole reconciled tree back as one nested `ArtifactNode.root` document
(`artifacts.ts:344-360`), a full per-`BlockNode` replace. Net effect: a title set via `kg:title`
today would be silently wiped back to the `blockId` fallback on the artifact's next
`kg:ingest`/`kg:track` re-run — the feature would appear to work once and then quietly regress.

**Fix, in `reconcileNode`**: for a matched pair, also carry `newNode.title = oldNode.title`
forward, not just `blockId`. This is safe unconditionally — "matched" already means
content-equivalent, so for a heading (whose title *is* its content) `oldNode.title` and the
fresh parse's title are identical anyway; for every other block, whatever real title exists
(operator-set or still the ID fallback) is exactly what should persist.

Same gap already exists for `unfolded` — currently preserved only on tombstoned nodes
(`reconcile.ts:205`, inside `tombstoneSubtree`), never on matched ones, so a block's `unfolded`
state today already silently resets to `false` on every re-ingest. Not this feature's bug to
own, but the `title` fix should carry `unfolded` forward the same way while touching this code,
since it's the identical class of gap with an identical fix shape.

## 5. Scan criterion: what counts as "not yet titled"

`block.title === block.blockId || !block.title` — the exact fallback sentinel, *or* simply empty
(covers a title later cleared by hand, or any future write path that leaves it blank without
going through the fallback default). Heading blocks never match either condition (their title is
always their own non-empty heading text), so they're naturally skipped without any special-casing.

## 6. Out of scope

- **`ArtifactNode`/`FolderNode.text` abstract override.** The naive fallback there is "first
  paragraph," not a distinguishable sentinel like `title === blockId` — there's no cheap way to
  tell "still the naive fallback" from "someone's real prose that happens to start the file"
  without a marker. Doing this properly needs a fallback-provenance flag (the existing `props`
  mechanism, e.g. `abstractIsFallback: true`, cleared once overridden) that isn't designed yet.
  Deferred as a follow-up once `kg:title`'s narrower `BlockNode` case is live and the interaction
  pattern is proven.
- **Any automatic/bulk invocation.** Neither `kg:title` nor `kg:link` is ever called by
  `kg:ingest`/`kg:track` — those stay exactly as fast and non-interactive as they are today.
  These are deliberate, separate passes an operator runs when they actually want better titles
  or richer cross-linking.

## 7. `kg:link` command

```
kg:link <path>                       # just the single node at <path> (no descendants), if unlinked
kg:link <path> --recursive           # <path>'s full uniform tree, unlinked BlockNodes only
kg:link <path> --recursive --all     # <path>'s full uniform tree, every BlockNode
```

Same `--recursive` semantics and reasoning as `kg:title` §3 — an opt-in walk of the same uniform
tree `kg:tree` already traverses, not a kind-based boundary; defaulting to full depth would risk
an accidental thousand-block interactive session. `--all` is an independent filter on top of
whatever scope `--recursive` selects: skip already-linked blocks, or don't. `--all` without
`--recursive` still means something (re-prompt `<path>` itself even if already linked), just a
narrow one — `<path>`'s own tree is only entered at all once `--recursive` is given.

For each `BlockNode` in scope, print its raw content and loop reading target references from
stdin — one per line, blank line ends this block's loop and advances to the next block. Each
non-blank line is resolved the same way `kg:assert`'s `source`/`target` already are
(`Aperas-basic-assertion-skill-design.md` §2: a full node id passed through directly, or a bare
artifact/folder path resolved via `getArtifactRecord`/`getFolderRecord` — reusing that existing
resolver rather than inventing a second one) and appended — not replacing existing entries — as
`{ "@type": "Link", target, predicate: "references" }` via `updateBlockNode(client, blockId,
{ links: [...existing, newLink] })` (§2).

Unlike `title`, there's no fallback sentinel for "still needs a link" — an empty `links` array is
a legitimate, common state, not evidence of an unfilled default. Default scan skips any block
that already has at least one `Link` (on the assumption a first pass already looked at it); a
`--all` flag re-prompts every block in scope regardless, for a deliberate second pass. Re-running
without `--all` is therefore not idempotent-complete the way `kg:title` is — it's "catch what's
still empty," not "catch everything under-specified." Flagged here as a real asymmetry between
the two commands, not resolved further; revisit if it proves too coarse in practice.

Same re-ingestion risk as §4 applies here too, structurally: `reconcileNode` doesn't carry
`links` forward for matched pairs either (only `blockId`, confirmed live), and
`resolveBlockLinks` (`artifacts.ts:266-284`) already doesn't diff against previous `links` on
re-ingestion regardless (`artifacts.ts:260-264`'s own comment flags stale `Link` docs as a known
gap). The §4 fix (carry fields forward for matched pairs in `reconcileNode`) should include
`links` alongside `title`/`unfolded` while that code is being touched.
