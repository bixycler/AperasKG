# Bug report: `list`-type `BlockNode`s hold their entire raw markdown as `.text`

**Resolved.** Fixed as proposed below: `convertAstNode` (`astParser.ts`) now sets `text = ''` for
`list`, matching `heading`/`root`/`listItem`. Live-verified against the real mirror after a full
clear-mirror-and-reingest: `Aperas-dev-status.md`'s stored abstract is now the correct first
paragraph ("See `Aperas-architecture.md` for how everything below is actually built...", bounded
by `truncateForPreview`), not the former 39,413-character raw blob.

Follow-on from `treeview-render-tiers.md` — that report's render-time fixes made this visible;
this is a separate, deeper root cause in parsing, not rendering.

## Root cause

`astParser.ts`'s `convertAstNode` defaults every block's `text` to `rawText` (the raw markdown
slice the node spans), then overrides it back to `''` for specific types that shouldn't carry
their own text:

```ts
let text = rawText;  // default
if (node.type === 'heading') { text = ''; ... }
else if (node.type === 'root') { text = ''; ... }
else if (node.type === 'listItem') { text = ''; }
// paragraph/code/thematicBreak/html/table fall through to the leaf default (text = rawText).
// blockquote also falls through...
```

`list` is missing from this chain — and from the comment's own enumeration of intentional
fall-throughs. It silently inherits the raw-slice default instead.

**Design vs. code**: `Aperas-markdown-fractal-mapping-design.md` §8 (archived under `tdb-era/`, but
still the current authoritative spec for this parsing logic — nothing in the ApeironNgn migration
touched markdown→block mapping) is explicit: an orphaned `list` block should have "no title, no
text." Title is fine (the `blockId` fallback already applies, per §1). Text is not — this is a
coding gap against a settled, unambiguous spec, not an underspecified design.

## Two symptoms, one cause

`Aperas-dev-status.md` has two nested `list` blocks wrapping its real content (an outer orphaned
list, then a heading whose own body is itself another list — both hit the same gap independently):

1. **Unbounded stored text**: the outer list's `.text` was the entire 39,413-character raw
   markdown of the file.
2. **`extractAbstract` returning the wrong content**: its pre-order "first descendant with
   non-empty text" search stopped at the first (buggy) `list` block it hit, before ever reaching
   the real first paragraph underneath — completely independent of `extractAbstract`'s own
   truncation fix (`treeview-render-tiers.md`), which only bounds whatever text it's handed, not
   what it finds first.

Confirmed by patching a scratch copy with the missing branch and re-running `extractAbstract`
against the real file: result changed from the full raw blob to the correct
`"See \`Aperas-architecture.md\` for how everything below is actually built..."` — the same one
fix resolves both symptoms; no separate fix to `extractAbstract`'s own search logic is needed.

## Fix

Add the missing branch, matching the existing pattern exactly:
```ts
else if (node.type === 'list') { text = ''; }
```

## Consequence

Already-ingested `list` blocks (and anything whose `ArtifactNode`/`FolderNode.text` derived from
one) keep their old, oversized/wrong stored values until next re-ingested — the parser fix only
applies going forward, same caveat as `treeview-render-tiers.md`'s `extractAbstract` truncation.
