# Agentic Query Tools — Design

## 0. What this is, and what it supersedes

`Aperas-agentic-bfs-projection-design.md` conflated two different traversal shapes under one
wrong name — a depth-bounded recursive walk it called "BFS Traversal" is actually depth-first
(IDDFS-shaped, once bounded), not breadth-first. This doc replaces it: three distinct tools,
correctly named, plus a third capability (keyword/regex search) every earlier revision flagged
as missing but never built. Together they answer "what does an agent or human have to find a
node or explore the graph," per `Aperas-core-ontology-design.md` §5.A's Agentic Interface
concept and the gap first identified in `Aperas-basic-assertion-skill-design.md` §2.

## 1. Three distinct tools, not one

- **`kg:tree`** — a deep structural map: recursively lists nodes across many levels, optionally
  depth-bounded. Algorithmically a depth-first walk with an optional depth cutoff —
  IDDFS-shaped, not BFS. Good for getting oriented across a large chunk of the KG at a glance.
- **`kg:unfold`** (and its inverse, `kg:fold`) — true breadth-first: given one node, show its
  own `title` plus the full `text` of each of its immediate children (first level only) — no
  recursion, no depth param, since "first level" is the whole point. Named `fold`/`unfold` (not
  `collapse`/`expand`) to match the ontology's own existing vocabulary — see §3, this is also
  the first thing to ever give the long-inert `BlockNode.unfolded` schema field a real effect.
  This is the real analog of `Aperas-core-ontology-design.md` §5.A mode 3's "BFS tool calls to
  expand subtrees": a single frontier-expansion step an agent calls repeatedly, choosing which
  child to unfold next based on what it just read.
- **`kg:search`** — keyword/regex content search, matched server-side via WOQL. Not structural
  at all — finds nodes by matching a pattern against content, regardless of position in the
  tree. Closes the gap every earlier revision of this design named and left open.

## 2. A real implementation gap this surfaced, fixed directly in `astParser.ts`

Designing `kg:unfold` (§3) exposed a missed gap in already-shipped ingestion behavior, not just
a display-layer choice: `heading` and `blockquote`/`listItem` were all being treated as
equally content-less containers (`text = ""`), but they aren't equally opaque —

- A `heading`'s real content lives in its children, but per the folding philosophy ("a block's
  children fold into its text (abstract)"), it should still carry an abstract of its own, the
  same way `ArtifactNode`/`FolderNode` already do via `extractAbstract`. It didn't — it was
  hardcoded to `""` regardless.
- A `listItem` is a real semantic unit (like a heading's section, just one level down), so it
  deserves the same treatment — also missing.
- A `list` genuinely has no content of its own — its children (`listItem`s) are the actual
  content units. It's the *only* true content-less container.
- A `blockquote` is a quote, not a summary — its full content should be projected as-is, not
  reduced to an abstract or emptied out.

Fixed in `astParser.ts`'s `convertAstNode`: `heading`/`listItem` now compute `text` via
`extractAbstract` once their `children` exist (the first paragraph found among descendants,
cascading correctly through nesting — confirmed live: a `Sub` heading two levels down correctly
picked up its own nearest paragraph, not an ancestor's); `list` still empties `text`; `blockquote`
now falls through to the ordinary leaf default (`text = rawText`, its full raw slice, quote
markers included) instead of being emptied. Verified this doesn't disturb reconciliation:
`reconcile.ts` keeps its own independent `LEAF_TYPES`/`CONTAINER_TYPES` (type-based, not
text-based) for Stage A/B matching, so none of this changes which nodes match how — confirmed by
re-running `verify:phase0 -- --db` clean, both in-memory and against the live DB.

**Known limitation surfaced by this fix**: `kg:track`/`kg:ingest` skip re-ingestion based on file
content hash — a parser-logic change like this one doesn't change any file's bytes, so already-
ingested real artifacts keep their old (empty) heading/listItem `text` until something forces
re-ingestion. Confirmed live: re-running `kg:track`/`kg:ingest` after this fix touched zero
artifacts. Not fixed here — a real, pre-existing gap (parser version isn't part of the
change-detection key), out of scope for this design.

## 3. `kg:tree` — render rule: `title`, exclusively

An earlier revision proposed falling back to a text excerpt when `title` isn't meaningful.
Rejected: a `BlockNode`'s `title` literally *is* its own `blockId` whenever nothing has
summarized it yet (`astParser.ts:76`) — and that **is** the meaningful signal, not a gap to
paper over. Seeing a raw id as a node's title tells the reader "this node is opaque — nothing
has read and summarized me" (Fractal Ontology Enhancements' AI-summarization step, still
unbuilt per `Aperas-dev-status.md`). Extracting a text excerpt instead would hide that signal
behind a false sense of readability. So: print `title` uniformly for every node kind, no
fallback branching, no special-casing for containers either — `FolderNode`/`ArtifactNode`
titles are always meaningful (dirname/filename) anyway, so the rule is genuinely uniform.

Command: `kg:tree [path] [--depth N]`
- `path` optional, defaults to `.` (the artifacts-root `FolderNode`) — the full tree from
  folders.
- Same addressing as the assertion CLI: a full node id or a bare artifact/folder path, resolved
  via the existing `resolveNodeRef` (direct-or-query, `Aperas-basic-assertion-skill-design.md`
  §2).
- No depth limit by default — genuinely the full tree. `--depth N` truncates to N levels,
  printing a `…` marker at each truncation point rather than silently stopping, so it's visibly
  a limit, not the actual leaf.
- One recursive walk handles every level uniformly — `FolderNode` (nested `FolderNode`s,
  `ArtifactNode` references, README-derived `BlockNode` children) and `ArtifactNode` →
  `BlockNode` tree alike; the fractal ontology means no node kind needs special-casing.
- Output: one line per node, indented by depth: `<id>  [<kind>]  <title>` — `<kind>` is
  `FolderNode`/`ArtifactNode` for those, or the `BlockNode`'s own mdast `type` for blocks.

## 4. `kg:unfold` / `kg:fold` — one breadth-first step, persisted

Command: `kg:unfold <path>`
- `path`: same direct-or-query addressing as everywhere else (full id or artifact/folder path).
- No depth, no recursion by design — resolves to one node, then prints its own
  `<id>  [<kind>]  <title>` **plus**, for each of its immediate children,
  `<id>  [<kind>]  <full text>`. Full `text` *in addition to* title, not instead of it — an
  earlier revision of this doc worded it as "full text, not title," which wrongly implied
  dropping the title; the point was only to emphasize that children get their full content
  here, unlike `kg:tree`'s title-only listing.
- Now that §2's fix gives `heading`/`listItem` a real abstract, only a `list` child (the one
  true content-less container per §2) ever has nothing to show — it prints
  `<id>  [<kind>]  (no text of its own — see kg:unfold <id>)`. Every other child kind now has
  something real to display.
- **Persists**, not just displays: also sets `BlockNode.unfolded = true` on the target node —
  the first code path to ever write `true` to that field (it's existed since early in the
  schema, defaulted `false` on creation, carried forward by reconciliation, but never
  meaningfully written or read — confirmed live by grepping the codebase). Implementation note:
  `BlockNode.children` is a required `List`, so the write has to resubmit the full existing
  document with only `unfolded` changed (fetch-then-resubmit), the same pattern
  `tombstoneSubtree` (`reconcile.ts`) already uses for a different field on the same class.
- `kg:fold <path>` is the exact inverse: sets `unfolded = false` on the target node, no content
  printed beyond a confirmation — there's nothing new to show by re-collapsing.

**Composability, corrected**: an earlier revision described `kg:tree` + `kg:unfold` as
"composable" but only demonstrated a *sequence* of separate calls (`tree` → `unfold x` →
`unfold y` → ...) whose results a reader has to mentally combine — not a single artifact. What
"composable" should actually mean: the *persisted* `unfolded` state left behind by a sequence of
`kg:fold`/`kg:unfold` calls is a standing, queryable shape — "a selectively expanded tree" — not
just this session's scrollback. This design doesn't yet specify a single command that renders
that combined shape in one shot (e.g. a `kg:tree` variant that shows full text at nodes flagged
`unfolded` and stops at folded ones, rather than uniformly title-only) — that's a natural next
step once `kg:fold`/`kg:unfold` exist and something has actually been unfolded, but it's a real
design fork (should `kg:tree` change its default behavior, or should this be a separate command)
worth settling deliberately rather than folding in by assumption here.

## 5. `kg:search` — keyword/regex content search

Command: `kg:search <pattern>` — PCRE-style regex, matching `WOQL.re`'s own semantics.

Confirmed live (not just documented): TerminusDB's WOQL builder exposes
`WOQL.re(pattern, inputVarName, resultVarList)` (`terminusdb` npm package, `lib/woql.js:1262`)
— genuine server-side regex matching, not a client-side scan. Tested directly against the real
KG: `WOQL.re('Assertion', titleVar, matchVar)` combined with `WOQL.triple(doc, 'title',
titleVar)` correctly matched 3 real `BlockNode` titles containing "Assertion." A pattern with a
regex metacharacter (`kg:\w+`) also matched correctly using ordinary single-level JS string
escaping — the "escape twice" note in the client's own docstring turned out to be about
internal JSON-LD wire transport, already handled by the client library; callers don't need to
double-escape anything themselves.

- Searches `title` and `text` across all three node classes (`BlockNode`, `ArtifactNode`,
  `FolderNode`) — six queries (3 classes × 2 fields), each
  `WOQL.and(WOQL.triple(v.Doc, field, v.Value), WOQL.re(pattern, v.Value, v.Match))`. A
  class/field a given document doesn't have (e.g. `Optional text` absent) simply produces no
  triple to match against — no special-casing needed.
- `title`/`text` are `xsd:string` literals, so bindings come back wrapped
  (`{"@type", "@value"}`), exactly like `predicate` did in `Aperas-basic-assertion-skill-design.md`
  §4 — reuses the existing `unwrapLiteral` (`woql.ts`) rather than re-solving the same problem.
- Output: `<id>  [<kind>]  <field>  <value>` per match, across all six queries, deduplicated by
  id (a node could match on both `title` and `text`).

## 6. Phase placement — decided

Confirmed: moved into Phase 0, same reasoning as Artifact Projection and Basic Assertion
Authoring (a real capability gap blocking basic KG usability, not contingent on the UI existing
first). `Aperas-design.md`'s roadmap and `Aperas-dev-status.md` updated to match.
