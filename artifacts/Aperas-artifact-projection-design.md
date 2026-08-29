# Artifact Projection — Design

`Aperas-core-ontology-design.md` §5.A names three projection modes that turn a stored
`BlockNode` tree back into an output: Artifact Projection (serialize back to the physical
`.md` file, always fully unfolded regardless of each block's `unfolded` state), the Human UI,
and the Agentic BFS interface. This doc settles the design for the first of the three —
Artifact Projection, the direct inverse of `astParser.ts`'s Markdown → tree transform. The
other two modes are out of scope here. The design below is settled; nothing has been
implemented yet.

## 1. Canonical regeneration, not byte-exact

`heading`/`paragraph`/`code` blocks already round-trip exactly — their `title`/`text` are raw
source slices, not derived summaries. Container types (`list`, `listItem`, `blockquote`) are
regenerated as clean, valid Markdown rather than reproducing the original file's exact
whitespace and spacing. This matches the bar reconciliation already uses elsewhere in this
project: "parses back to the same tree," not "identical bytes."

## 2. List items are always blank-line-separated in the output

mdast's `spread` (tight vs. loose list) isn't captured. CommonMark requires blank lines
between list items whenever any item is "loose" (multi-paragraph); always emitting them is
valid either way and has no effect on the re-parsed tree, since remark already wraps every
list item's content in a paragraph regardless of the original list's tightness (a pre-existing,
separately-confirmed quirk — not something this design introduces). Capturing `spread` would
only ever affect cosmetic rendering spacing, never structure, so it's left out.

## 3. Blockquote line-prefixing is a projection-side concern

CommonMark only requires the `> ` marker on a blockquote's first line (or after a blank line
ends and restarts the quote) — a continuation line needs no marker at all ("lazy
continuation"). Whether `astParser.ts`'s raw-text slice for a multi-line paragraph inside a
`blockquote` contains a stray `> ` on its continuation lines therefore depends on how the
source was actually written, not on anything the parser does: confirmed live, `"> line
one\n> line two"` (marker repeated, common in practice) slices to `"line one\n> line two"`
(marker present in the leaf's own `text`), while `"> line one\nline two"` (lazy continuation,
also valid) slices to `"line one\nline two"` (nothing stray — matches mdast's own semantic
`text.value` either way). Rather than depending on which form a given source used — or fixing
this at ingestion, which would perturb reconciliation's matching keys for existing blockquote
content — the serializer normalizes at output time: strip any leading `> ` from each line of a
blockquote's rendered content (a no-op when there isn't one), then re-apply `> ` uniformly.

## 4. New fields: `ordered`, `start`, `checked` — captured, not derived

A `list` node's numbered-vs-bulleted style and starting number, and a `listItem`'s task-list
checkbox state, aren't recoverable from anything currently stored — they have to be captured
at parse time. mdast already carries all three directly on the relevant nodes (`list.ordered`,
`list.start`, `listItem.checked`, confirmed live) — nothing lazy or derived about them, they
sit on the same mdast node object `astParser.ts` already visits. They're absent from
`ParsedBlockNode` today because `convertAstNode` was never asked to read them, not because
they were unavailable: it extracts `blockId`/`title`/`text`/`type`/`children` identically for
every node type and has never read a type-specific mdast property, since nothing downstream
needed one before projection made round-tripping a goal. So this is a scope gap in the
existing extraction logic, closed by capture — not inference of something the parser
previously discarded.

Schema (`BlockNode`, all `Optional` — unlike the `artifactId`/`type` migration, this needs no
DB wipe, since existing documents remain valid against new optional fields):
- `ordered: Optional xsd:boolean` — set on `list` nodes.
- `start: Optional xsd:integer` — set on `list` nodes (mdast always provides one, even for
  unordered lists, where it's simply unused).
- `checked: Optional xsd:boolean` — set on `listItem` nodes only when mdast's own `checked` is
  non-null; its absence (not `false`) is what distinguishes "not a task item" from "unchecked."

## 5. The algorithm

Pure, recursive dispatch on `node.type`:
- **root** / any other container fallback: children rendered and joined with a blank line.
- **heading**: `title` (already the full raw heading line, `#`s included) followed by its
  rendered children, blank-line-joined.
- **paragraph**: `text`, dedented (every line but the first stripped of whatever common leading
  whitespace they share — needed because a multi-line leaf's raw slice only has line 1's
  container-required indentation stripped; every later line keeps its literal original-file
  column, confirmed live on both a `blockquote` continuation line and a nested `code` fence's
  interior — left alone, a container's own re-indentation (below) would compound on top of that
  stale absolute value instead of establishing a clean baseline).
- **code**: same dedenting, plus one more check — a *fenced* block's raw slice starts with its
  own `` ``` ``/`~~~` marker, same as any other leaf, and is emitted as-is once dedented. An
  *indented* (4-space) code block is also mdast type `code`, but its raw slice carries no fence
  at all, and unlike every other leaf, line 1 isn't stripped of its marker either (confirmed
  live — the indentation *is* the syntax marker, so it survives on every line including the
  first). Left alone this would silently degrade into an ordinary paragraph on projection, so a
  raw slice with no fence marker is dedented across all its lines (line 1 included) and
  re-wrapped in a fresh generic fence — always converting indented-style input to fenced-style
  output (§8).
- **blockquote**: render children, strip a leading `> ` from every line, re-prefix every line
  with `> ` (§3).
- **list**: render each child as a list item — marker is `${n}. ` if `ordered`, else `- `,
  with `n` starting at `start ?? 1` — joined with a blank line (§2).
- **list item**: prefix = marker + (`[x] ` / `[ ] ` if `checked` is defined), body = children
  rendered and blank-line-joined, every line after the first indented to the prefix's width.
  This is what makes a nested `list` under a `listItem` indent correctly — it falls out of the
  recursion for free, no special-casing needed.

## 6. Entry point

`projectArtifactToMarkdown(client, path)`: fetch the tree via the existing
`getArtifactTreeViaGraphQL` (`graphql.ts` — its field selection needs `ordered`/`start`/
`checked` added, the same fix already needed once this session for the `type` field), then run
the serializer over `tree.root`. Root itself is never emitted — it falls through the generic
container fallback, which is exactly "join my children."

## 7. Verification strategy

Round-trip equivalence — parse a sample exercising every branch (ordered list, unordered list
with a task item, nested list, blockquote, code, headings) → serialize → re-parse → compare —
is checked by reusing `reconcile.ts`'s `reconcileTree` (the original parse as `oldRoot`, the
re-parsed result as `newRoot`): equivalence is `stats.added === 0 && stats.removed === 0`,
i.e. every block matches. This reuses already-verified matching logic as the equivalence check
instead of a bespoke tree comparator, and doubles as exercise of `reconcile.ts` against list/
task-list shapes it hasn't been run against yet.

Run against every real artifact in `AperasKG/artifacts/` (not just the synthetic sample): 9 of
11 round-trip with zero added/removed. The other 2 each produce exactly one added+removed pair,
both explained by §1's canonical-not-byte-exact choice rather than a bug:
- A nested `code` fence whose original *absolute* indentation was deeper than the minimal
  amount its list item requires (source used 4 spaces where 2 would do) re-projects at the
  canonical 2 — the code's own *relative* internal formatting is preserved, only the baseline
  shifts, but that's still a different `text`, so exact-key Stage A correctly doesn't match it.
- An indented-style code block converts to fenced-style on projection (§5) — a real, disclosed
  change to the stored `text`, so it doesn't match either, for the same reason.
  Both are accepted per the same "precision over recall" principle reconciliation already uses
  elsewhere (§2 of the reconciliation design) — a wrong same-content guess is worse than a
  visible remove+add.
