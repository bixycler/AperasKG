# Bug report: `kg:tree`/`kg:unfold` title/text tiering

**Resolved.** Fixed as proposed below: `node.ts`'s `renderViewLines`/`renderLinkLine` now
concatenate title+abstract instead of choosing one, `showAbstract` ORs in the node's own unfold
status, and `astParser.ts`'s `extractAbstract` gained a shared `truncateForPreview` helper —
applied both there (ingest time, so a stored `ArtifactNode`/`FolderNode.text` is a genuine short
preview) and at render time (a safety net for an ordinary `BlockNode`'s own long paragraph, never
truncated in storage). "Abstract" throughout this doc and the design doc means title+text shown
together, not a separate derived field. Note: already-ingested `ArtifactNode`/`FolderNode`s keep
their old, untruncated stored `.text` until next re-ingested (nothing here forces a mass
re-ingestion) — the render-time truncation covers that gap regardless. The box-drawing question
below was answered (keep plain indentation) but not revisited further.

Investigation into: rendered lines sometimes show only a title, sometimes only text with no
title, and `kg:tree --view default` renders a lot of content with nothing unfolded.
Aperas-treeview-design.md §4/§5/§6 is the design these tiers are supposed to implement.

## Root causes

**Bug A — own-line template replaces title with text instead of showing both**
(`web/src/lib/apeironNgn/node.ts:1121`, `renderViewLines`):
```ts
const content = !showAbstract ? node.title : isTextlessList ? '...' : (node.text ?? node.title);
```
Design says tier 1/2 is `{title, abstract}` — both, on the same line. The code picks one or the
other: when a node has text, the title is dropped from the line entirely.

**Bug B — the own-line tier ignores the node's own unfold status**
(`node.ts:1114`):
```ts
const showAbstract = parentQualifiesForPreview; // ignores isGenuinelyUnfolded
```
A node genuinely unfolded itself but reached through a non-qualifying breadcrumb parent (e.g. `3.3.1`
in §4's worked example) incorrectly renders title-only. Should be
`parentQualifiesForPreview || isGenuinelyUnfolded`. `renderLinkLine` (`node.ts:1148-1178`) has the
same omission in all three branches — a `Link`'s own line never shows text/abstract, in any tier.

**Unbounded abstract, compounding both bugs**: `extractAbstract` (`astParser.ts:360`) returns the
first descendant block's entire raw `text` verbatim — no truncation. Live example:
`ArtifactNode/00CA01ZW50000` (`Aperas-dev-status.md`) has a 39,413-character `text`. Root's direct
children always get the preview tier unconditionally (by design — `buildViewRenderContext` always
adds the root id to `unfoldedTreeIds`), so `kg:tree --view default` — even with a genuinely empty
`unfolds` (confirmed against the real `.state/TreeView.jsonld`, not stale test data) — hits Bug A
and dumps that entire blob in place of the title for each root child.

## Current tiers as implemented

| Tier | Design | Code | Actual behavior |
|---|---|---|---|
| 1. Genuinely unfolded | `{title, abstract}`, lists children+links | `node.ts:1121-1129` | Text replaces title (Bug A); falls to tier-3 if parent doesn't qualify (Bug B) |
| 2. Preview (parent unfolded / Root child) | `{title, abstract}`, no further children except pass-through | `node.ts:1121,1126-1128` | Text replaces title (Bug A); children pruning otherwise correct |
| 3. Bare breadcrumb | `{title}` only | `node.ts:1121` | Correct, except incorrectly also hit by tier-1 nodes (Bug B) |
| Link's own line | preview/canonical tiers both include `{title, abstract}` | `node.ts:1148-1178` | Always title-only, no tier ever shows abstract |
| Plain no-`--view` tree | title-only, always | `node.ts:977-1000` (`renderTreeLines`) | Correct as-is, no bug |

## Proposed fix (pending approval)

1. Concatenate title+text instead of choosing one (fixes Bug A).
2. `showAbstract = parentQualifiesForPreview || isGenuinelyUnfolded` (fixes Bug B), applied the same
   way in `renderLinkLine`.
3. Cap the text shown at **render time only** (not the stored `.text` — `kg:project`/markdown
   output keeps the full value) — open question: cap length/style (character limit vs. first line,
   with what truncation hint).

## Open design question (not a bug)

Box-drawing characters (`├─`/`│`/`└─`) only appear in the design doc's own illustrative examples —
the real CLI output is already plain-indented (`id [kind] title` per line). Recommendation: keep
plain indentation as the default — more reliably parseable by a script or an agent than box-drawing
glyphs, which mainly help a human eye and would need stripping otherwise. If prettier human output
is wanted too, an opt-in flag reads better than a default swap.
