# Apeiron Node CRUD — Design

## 1. Motivation

The missing piece for working directly on Apeiron instead of always going through a real markdown
artifact: a full CRUD surface over nodes, built by reusing the ingestion/reconciliation/parsing
machinery that already exists rather than growing a parallel set of write ops. Direct creation and
positioning target a deep path instead of an artifact path and (mostly) have no file on disk backing
them; direct text/children updates are literally the same markdown-ingest pipeline `ArtifactNode`
already runs, just retargeted at an arbitrary node instead of a whole document.

The `holder` flag (`shape.ts`'s `TREE_NODE_SHAPE`, set today only by `--create-holder`'s deep-path
scaffolding, `resolveCreate.ts`) already does almost exactly the bookkeeping direct creation needs.
This doc settles what it actually means, closes the gaps found while working that out, and designs
the rest of the CRUD surface around it: positioned insertion/creation/promotion (`kg:insert`),
abstract placeholder minting (`kg:resolve --create-holder`), content replacement
(`kg:update`), and recursive removal (`kg:remove`) — alongside the already-implemented `kg:title`.

## 2. Command map

- **`kg:insert <path> [--after|--before <anchor>]`** ([§7](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/7. `kg:insert` — position, promote, or create]]>)) — concrete-only. No stdin: move
  and/or promote an *existing* node. With piped markdown on stdin: create a brand-new concrete node
  under an existing parent, positioned in one step.
- **`kg:resolve --create-holder <path> --titles <title>...`** ([§8](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/8. `kg:resolve --create-holder` — scope and internal unification]]>)) — abstract-only. Mints a
  forward-reference placeholder chain (`holder:true`), append-only. Unchanged externally; internals
  unified this round.
- **`kg:update <path> [--text-only]`** ([§9](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/9. `kg:update` and `--text-only`]]>)) — stdin required. Replaces an existing node's content from
  markdown, either fully reconciled against its current children or (with `--text-only`) with
  overflow content simply prepended.
- **`kg:remove <path>`** ([§10](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/10. `kg:remove`]]>)) — recursive tombstone of an arbitrary node, on demand.
- **`kg:title <path> <title>`** ([§11](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/11. `kg:title`]]>)) — already implemented; included for completeness.

## 3. Core model: placeholder is a flag, not a kind

Apeiron's unbounded-tree philosophy draws no distinction in *kind* between a placeholder and a
real node — a `BlockNode`/`ArtifactNode`/`FolderNode` marked `holder: true` is exactly the same
shape of thing as one that isn't. `holder`'s only real meaning, confirmed by checking every place
it's read (`node.ts`'s rendering, `FolderNode.hydrateFromParsed`'s preservation loop): **reconciliation
survival** — "don't tombstone me just because a disk-derived parse doesn't produce me; I'm not
missing content, I was never going to be produced by a disk walk in the first place."

**Promotion** is simply clearing that flag once real content authoritatively arrives — through
whichever of the channels below apply to that node's kind. There's no separate "placeholder" type
to convert *from*; a promoted node is the exact same node, same id, same position, just with the
flag cleared and (per [§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>) below) its derived fields finally populated.

## 4. Promotion channels, per node category

A node's kind determines which channels apply — this is the actual reason Folder/Artifact and
Block need different treatment, not an arbitrary split.

### 4.1 Folder/Artifact — no position channel

- **(i) Ingestion match — path only, not text.** `trackArtifact`/`ingestFolderTree`'s first pass
  matches purely on `path` (`findLiveArtifactByPath`, `existingByPath`); this is the whole
  promotion story for the common case — a holder's `path` was set to the exact location real
  content is expected to land. The *separate* rename-detection pass (`matchLeftoverByAbstract`,
  exact-equality Gestalt matching on `.text`) exists to catch an already-real artifact moving to a
  new path — it cannot serve as a promotion channel for a holder, because a holder's `.text` key is
  always `''` (see [§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)), and even in the degenerate case of two simultaneously-empty keys,
  `dropAmbiguousSingletons` (reconcile.ts:77-93) refuses the match as unanchored. These are
  orthogonal mechanisms, not layered: path-match is promotion; text-match rename-detection is a
  different feature for content that's already real.
- **(o) Projection.** Writing an in-graph subtree back out to disk (`kg:project`/`runProject`) is
  equally a promotion event — gated on the whole subtree being *purely concrete* (no holder
  anywhere underneath; see [§4.2](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.2 Block — the full three channels]]>)'s own **(o)**, which is where this requirement actually
  originates). Needs new bookkeeping — see [§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>).
- **No (p).** Folder/Artifact children carry an ordered `siblingIndex` only because the storage
  mechanism is shared homogeneously with `BlockNode` — real filesystem order is never
  human-authored (`folders.ts`'s `buildFolderTree` walks bare `readdirSync` with no `.sort()`
  anywhere in the scan), so position carries no identity meaning for this kind. Folder/Artifact
  creation stays append-only, correctly, not just "good enough" — `kg:insert` (§7) deliberately
  excludes these kinds from positioning.

### 4.2 Block — the full three channels

- **(i) Ingestion match — title only, via reconciliation.** Stage A's exact-title Gestalt matching
  (`reconcile.ts`, `leafKey`) already promotes a matched holder heading for free: `carryForwardFields`
  (reconcile.ts:137-150) whitelists only `blockId`/`title`/`links`/`props` — `.holder` was never in
  that list, so the *reconciled plain-object tree* naturally ends up with no `.holder` at all. That
  alone isn't sufficient, though — see [§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)'s note on `BlockNode.hydrateFromParsed`, which is what
  actually writes the real store node and today never touches `.holder` at all.
- **(p) Relative position-setting.** Deliberately anchoring a block's position in Apeiron directly
  (`kg:insert`, [§7](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/7. `kg:insert` — position, promote, or create]]>)) is itself sufficient promotion signal, independent of **(i)** — a Block
  is the one kind where order is actually part of its meaning, so a human asserting "this goes here"
  is real evidence of intent, not scaffolding. Applies unconditionally: repositioning an already-real
  node is just a move, with the `.holder` clear being a no-op — there's no branch on prior holder
  state, one mechanism covers both cases.
- **(o) Projection.** Eligible only if it, and everything under it, is purely concrete — the same
  gate [§4.1](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.1 Folder/Artifact — no position channel]]>)'s own **(o)** relies on, just stated at the level it actually originates from (a
  Folder/Artifact's own projectability is really "is every Block underneath me concrete," recursively).

## 5. The reconciliation "nowhere problem," worked example

Today, *any* unmatched old child — holder or not — is destructive: `diffChildren` (reconcile.ts:164-234)
routes every `removedOld` index into `ctx.removedCandidates`, `reconcileNode` (reconcile.ts:334-336)
collects them there, and `detectCrossParentMoves` (reconcile.ts:386-389) ends with `tombstoneSubtree`
for whatever's left unclaimed by a cross-parent move. A block-level holder would be deleted the very
first time its owning artifact is reconciled at all, unrelated edits included — confirmed live, this
is why block-level holder support was left out originally: a floating placeholder has no obvious
home once the surrounding content shifts.

The fix reuses scaffolding `diffChildren` already computes for an unrelated purpose (scoping Stage
B's container alignment): its anchor-derived `segments` (reconcile.ts:194-202) partition old/new
children into aligned ranges. A `removedOld` index necessarily falls inside exactly one such segment.
Instead of pushing a `holder`-flagged `removedOld` child into `ctx.removedCandidates`, splice it
into `newNode.children` at that segment's `newRange` upper bound (i.e. immediately before the next
anchor) — this keeps it between the same two real neighbors it originally sat between, even if
content around it changed.

**Worked example** (all headings — text-less containers, matched purely by title, same as any
Stage-B container alignment already is):

Old tree (holder present, never yet matched):
```
0: heading "Intro"
1: heading "Setup"
2: heading "Future Section"   holder:true, no .text
3: heading "Conclusion"
```
New parse (unrelated edit elsewhere; "Future Section" still doesn't exist on disk):
```
0: heading "Intro"
1: heading "Setup"        (text changed — irrelevant, leafKey ignores it)
2: heading "Conclusion"
3: heading "Appendix"     (new)
```
Stage A matches `{0→0, 1→1, 3→2}` (the "Intro,Setup" run, then "Conclusion" alone); `"Future
Section"` matches nothing → `removedOld = [2]`; `"Appendix"` is new → `addedNew = [3]`. The anchor
walk produces segment `{oldRange:[2,3), newRange:[2,2)}` for old-index 2 — an *empty* new range,
but not nowhere: it names index 2 in the final array, exactly the slot immediately before
`Conclusion`. Splicing there gives:
```
Intro, Setup, [Future Section], Conclusion, Appendix
```
— original neighbors preserved, Appendix (added elsewhere) unaffected. This generalizes to a
non-empty segment too: the holder always lands immediately before the next real anchor, wherever
that anchor currently sits, whether or not something else was also added in the same gap.

**Implementation note (not yet designed in code, flagged so it isn't lost).** `ChildDiff`
(reconcile.ts:152-156) currently returns only `{matched, removedOld, addedNew}` — the `segments`
array above is local to `diffChildren` and never exposed, so `reconcileNode` has no way to look up
which segment a given `removedOld` index falls into. The interface needs extending to carry that
(e.g. a splice-target index per holder-flagged `removedOld` entry). There's also an ordering hazard:
`reconcileNode`'s matched-pairs loop (reconcile.ts:321-332) indexes `newNode.children[newIndex]` by
*original* array position, so any splice into `newNode.children` must happen only *after* that loop
finishes — never interleaved with it — and if more than one holder lands at the same level in the
same call, they must be spliced from the highest target index down to the lowest, so an earlier
splice doesn't shift the target position of a later one.

## 6. Bookkeeping gaps found while designing this (all currently real, all need closing)

- **`toReconcileShape()` (node.ts:487-499) doesn't include `.holder` at all** — `reconcile.ts` has
  no way to see which old child is a placeholder yet. Needs adding before [§5](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/5. The reconciliation "nowhere problem," worked example]]>)'s fix can work.
- **`BlockNode.hydrateFromParsed` (node.ts:524-535) has no preservation logic** — only
  `FolderNode.hydrateFromParsed` (node.ts:826-840) protects an unmatched holder from being
  overwritten by the fresh parse's own `children` write. This is really the same gap as [§5](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/5. The reconciliation "nowhere problem," worked example]]>)'s
  tombstone problem, one layer up: with [§5](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/5. The reconciliation "nowhere problem," worked example]]>)'s fix, reconciliation itself never lets a holder become
  a `removedOld`-tombstone candidate, so `hydrateFromParsed`'s own `children` write can stay as-is.
- **`BlockNode.hydrateFromParsed` also never clears `.holder` on the matched-and-promoted node
  itself.** §4.2 (i)'s claim that a Stage-A-matched holder "naturally ends up with no `.holder`"
  describes only the reconciled *plain-object* tree `reconcileTree` hands back — `carryForwardFields`
  never copies `.holder` onto that object, true. But the write that actually lands on the real
  store node (same id, carried forward via `blockId`) is `BlockNode.hydrateFromParsed` (node.ts:524-535),
  which sets `type`/`title`/`text`/`props`/`links`/`children` but never assigns `.holder` at all — so
  whatever `holder:true` quad already exists on that id is left untouched forever. Needs an explicit
  `this.holder = undefined`, same class of fix as the next bullet.
- **`FolderNode.hydrateFromParsed` has the identical gap for its own (i) channel.** §4.1 (i) is
  scoped to `ArtifactNode`, but a holder-flagged `FolderNode` is just as real (minted today by
  `resolveCreate.ts`'s deep-path scaffolding for an imagined intermediate folder). Once a real
  directory appears on disk, `ingestFolderTree`/`buildFolderTree` reuse that `FolderNode` by path —
  landing in `FolderNode.hydrateFromParsed` (node.ts:805-843), which sets `title`/`path`/`text`/
  `props`/`children` but, like `BlockNode`'s own version, never touches `.holder`. Needs the same fix.
- **The Folder/Artifact rename/removal *sweep* is a wholly separate mechanism from the above, and
  has the same "nowhere problem" §5 fixed at Block level — found live while testing §5's fix.**
  `ingestFolderTree`'s own rename-detection sweep (`apeironNgn/folders.ts:77-83`, `dbOnlyPaths`/
  `removedCandidates`) and `trackAllArtifacts`'s identical sweep (`apeironNgn/artifacts.ts:74,81`,
  `dbOnlyIds`/`removedCandidates`) both tombstone any live Folder/Artifact whose `path` doesn't
  appear in the fresh disk walk, unless `matchLeftoverByAbstract` finds a rename match for it —
  neither checks `.holder` at all. A top-level holder Folder/Artifact (minted by
  `resolveCreate.ts`'s scaffolding for an as-yet-nonexistent path) *always* looks exactly like a
  removed node to this sweep, and — being freshly minted with no real abstract text yet — has
  nothing for `matchLeftoverByAbstract` to rename-match either, so it gets tombstoned the very
  first time `kg:ingest` runs a full pass, unrelated edits included. This is a different code path
  from `FolderNode.hydrateFromParsed`'s own preservation loop just above (that one protects a
  holder's *reference from its parent's `children`*; this sweep can tombstone the holder *itself*,
  independent of whether any parent still points at it) — confirmed live: creating a holder
  Folder/Artifact chain and then running a full `kg:ingest` tombstoned the holder folder outright.
  Fix: exclude holder-flagged ids from `dbOnlyPaths`/`dbOnlyIds` in both places, before they ever
  reach `removedCandidates` — the same "not on disk isn't evidence of removal" principle §5 already
  established for Block-level children, applied at the sweep's own entry point instead.
- **Nothing ever clears `.holder` on the (o) promotion path either.** Confirmed: `runProject`
  (kgProject.ts:19-45) doesn't touch `.holder` at all — needs an explicit `this.holder = undefined`
  once real content is actually written, same as the two bullets above.
- **`ArtifactNode.text` is only ever computed by `ingestFromDisk`** (`extractAbstract(newRoot)`,
  node.ts:660) — nothing derives it from a node's own live children. So **(o)** projection needs its
  own equivalent derivation (walk `treeChildren` for the first concrete content, same shape as
  `extractAbstract` but reading the graph instead of a parsed file) — otherwise a projected-and-thus-real
  artifact would still read `.text === undefined` forever, and would still fail rename-detection if
  it's ever later moved. **(o)** also needs to refresh `fileHash`/`ingestedHash`/`lastIngestedAt`
  (so a subsequent real re-ingest of the same file reads "unchanged," not a spurious reconciliation
  against itself) — the same three fields `ingestFromDisk` already sets for **(i)**. `FolderNode`
  has the identical gap, minus the hash fields it doesn't have: its own `.text` is likewise only
  ever set by a real disk-read (`folders.ts`'s `buildFolderTree`), so a promoted-via-projection
  `FolderNode` needs the same graph-based derivation too, or its own rename-detection fails the same
  way `ArtifactNode`'s would.
- **`ArtifactNode.toMarkdown()`'s own guard was checking the wrong thing for this new channel** —
  found while wiring the fix above. It returned `null` whenever `this.ingestedHash === undefined`
  (node.ts:659, a proxy for "nothing ingested yet" that was accurate back when a real disk-based
  ingest was the only way content ever arrived). `kg:insert` (§7) can now populate a holder
  `ArtifactNode`'s children directly, with `ingestedHash` staying `undefined` forever since
  `ingestFromDisk` never runs on it — so the old guard would refuse to render (and thus project)
  perfectly real, `kg:insert`-authored content. Fixed by checking `children.length === 0` instead —
  `children` is never `undefined` for `orderedContainment` fields (always a real, possibly-empty
  array by construction), so this is the actually-correct "nothing to render yet" signal, and it's
  correct for content that arrived via either channel.
- **`runProject` doesn't check subtree purity.** Nothing today stops projecting a subtree that
  still has holder descendants mid-tree, silently baking placeholder content into a "real" file.
  [§4.2](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.2 Block — the full three channels]]>)'s **(o)** gate needs an actual `hasNoPlaceholderDescendant`-style check before writing.
- **`project.ts`'s renderer is not tombstone-aware — found live via `kg:remove` followed by
  `kg:project` on the same artifact.** Tombstoning (`applyTombstone`/`tombstoneLiveSubtree`)
  deliberately leaves a dead node in its parent's `children` list, marked via `tombstonedAt` rather
  than spliced out, so mark-and-sweep GC and referrer tracking still see it. Every tree-rendering
  site in `node.ts` already knows to check for this (`tombstoneTag`), but `project.ts`'s
  `renderChildren` (which both `ArtifactNode.toMarkdown()` and `FolderNode.toReadme()` funnel every
  child through via `serializeBlock`) walks `node.children` unconditionally, with no `tombstonedAt`
  check anywhere — so a tombstoned child's last-known content gets silently re-emitted into the
  projected file. Not specific to `kg:remove`: any tombstone, however it got there (an ordinary
  `kg:update` reconcile against now-removed content included), leaks the same way. Fix: filter
  `!c.tombstonedAt` out of `renderChildren`'s children before walking/serializing them.
- **`appendOrderedChild` (node.ts:98-105) is append-only** — `siblingIndex` is always assigned
  `siblingCount`, i.e. current tail. No primitive exists for inserting at an arbitrary position —
  closed by `insertOrderedChild`, [§7](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/7. `kg:insert` — position, promote, or create]]>).

## 7. `kg:insert` — position, promote, or create

**The primitive.** `insertOrderedChild(store, parentId, childId, anchorId, side: 'before' | 'after')`
— read the parent's current ordered children, splice `childId` next to `anchorId`, rewrite every
sibling's `siblingIndex` from the resulting array position. This is not a new convention —
`siblingIndex` values are already contiguous `0..N-1` per parent by construction today, every
removal path already being a full rewrite that renormalizes from array position (per
[Step 11](<[[/Aperas-apeironngn-design.md/# ApeironNgn: Embedded Substrate Design/4. Rollout sequence/Step 11: `parent`]]>)'s own doc note in `Aperas-apeironngn-design.md`); insertion just needs the same
treatment on the other side.

**The command, `kg:insert <path> [--after <anchor>|--before <anchor>]`, is concrete-only** — it
never mints abstract placeholders (that stays `kg:resolve --create-holder`'s job, [§8](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/8. `kg:resolve --create-holder` — scope and internal unification]]>)), and it
never scaffolds missing parent structure — the parent named or implied must already exist, holder
or real, it doesn't matter which. It has two modes, distinguished by whether markdown is piped to
stdin (`process.stdin.isTTY` — no pipe means no stdin content):

- **No stdin — move/promote an existing node.** `<path>` names the existing node itself (real or
  holder). Effect: reposition it relative to `--after`/`--before <anchor>` (the anchor's *current*
  parent becomes the node's new parent — cross-parent moves work for free, no special-casing), and
  unconditionally clear `.holder`. If the node was already real, the `.holder` clear is simply a
  no-op and this is a plain move. Omitting both `--after` and `--before` is valid: a bare promote
  with no repositioning (useful when a holder is already sitting exactly where it should — e.g. one
  auto-created in place by a dangling wikilink whose own deep path already implied the right
  parent).
- **Stdin piped — create a new concrete node.** `<path>` names the **parent** to create under (not
  the new node's own address — there's nothing left for a path segment to name once the node's
  title comes from the parsed content instead of a `--titles` flag). The piped markdown is parsed
  via the same `parseMarkdownTree` real artifacts use; each new node's type/title/text/children are
  taken entirely from that parse (a multi-block snippet becomes a real subtree, not a single flat
  node) — no `--type`/`--titles` needed. If the parsed content has more than one top-level block
  (e.g. two sibling headings), all of them are created and inserted as a sequence at the anchor
  position, preserving their own relative order — not merged into one node, not rejected. The whole
  sequence is attached under `<path>` at `--after`/`--before <anchor>` (or appended at the tail if no
  anchor given), and is real from the moment it's created — it never passes through a `holder:true`
  state, unlike a placeholder minted by `--create-holder`.

**Wire note.** Piped content reaches the service as a plain string field on the request object
(e.g. `{ op: 'insert', path, markdown, after, before, flush }`) — the existing NDJSON framing
already handles this safely, since `JSON.stringify` escapes embedded newlines (the same reasoning
`service.ts`'s own protocol doc comment already gives for the wire format generally); no new framing
is needed. Same applies to `kg:update` ([§9](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/9. `kg:update` and `--text-only`]]>)).

**Guards:** the target (existing-node mode) must resolve to a `BlockNode` — `ArtifactNode`/
`FolderNode` are rejected, per [§4.1](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.1 Folder/Artifact — no position channel]]>)'s "no (p)" ruling. The anchor (if given) must resolve and must
not be the same node as the target. `--after` and `--before` are mutually exclusive.

## 8. `kg:resolve --create-holder` — scope and internal unification

**Unchanged externally.** This stays the *abstract-only* mechanism: mints a forward-reference
placeholder chain (`holder:true` throughout), append-only, used both manually and automatically
(`resolveBlockLinks` passes `createHolder: true` for every dangling wikilink). It answers "I don't
know exactly where this ends up yet, I just need something to point at" — the opposite of
`kg:insert`'s "I know exactly what and where."

**Why Block-tier creation here is always `type: 'heading'`, not user-specifiable.**
Reconciliation's matching key (`reconcile.ts`'s `leafKey`) is `node.type === 'heading' ? node.title
: (node.text ?? '')`. A holder's `.text` is always `''` ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)), and two empty-text candidates are
declined as an unanchored ambiguous match (`dropAmbiguousSingletons`). So a non-heading placeholder
could never be matched/promoted via channel (i) at all — it would sit forever unfindable by any
future real content. This isn't a missing feature to add later; it's why the type has to stay fixed.

**How `--titles` is actually consumed (as it exists today, restated precisely since it's easy to
misread).** It's one flat array, but it is *not* one entry per path segment:
- Folder/Artifact segment titles are always the **literal path-segment text itself** (`descend`'s
  miss-branch, node.ts — see below) — never drawn from `--titles`. A folder/file's title is just
  its own filesystem name; there's nothing separate to supply.
- Only Block/heading segments — past the `.md` boundary — consume `--titles` entries, tail-aligned
  against however many *name* tokens are still being resolved at that point. So the number of
  `--titles` needed equals the number of new heading segments past the artifact boundary, not the
  total path segment count.
- **Each `--titles` entry must be the full markdown heading line, `#` prefix included** (e.g.
  `### 1.2.3`, not `1.2.3`) — confirmed live, the hard way: `serializeBlock` (project.ts) emits a
  heading's `title` as-is with no prefix synthesized, exactly matching what a real parsed heading's
  own title already contains (`rawSlice` captures the whole raw line). A bare title with no `#`
  round-trips silently as a `paragraph`, not a `heading`, the moment the holder is promoted/projected
  and re-ingested — the reconciler isn't wrong to treat that as a real structural change; the title
  was simply never in the shape a heading's title is supposed to be in.
- The Folder/Artifact-vs-Block boundary itself is detected purely syntactically: the **first name
  segment whose text ends in `.md`** is the artifact; everything before it is Folder tier, everything
  after is Block tier. If no segment ends in `.md`, resolution refuses to guess and throws.

**The gap found, and the fix (full unification, approved).** `resolveTokens`'s hop-by-hop walk
(via `TreeNode.findChild`) only fell into the old `createImaginedPrefix` when *nothing at all*
resolved from the root (`consumed === 0`). If some real prefix existed and then a miss occurred
(`consumed > 0`), it called `descend()` directly instead — and `descend()`'s miss-branch
unconditionally minted a `BlockNode` heading regardless of tier. So e.g. resolving
`foo/bar/baz.md/heading --titles Heading` where `foo` is a real folder but `bar` isn't yet: the walk
consumes `foo`, misses on `bar`, and wrongly minted `bar` as a heading instead of a `FolderNode` —
`createImaginedPrefix`'s own `.md`-boundary logic never ran at all for this case.

Fixed by generalizing `descend()`'s miss-branch to check `kindOf(currentId)`:
- Current node is `FolderNode` and the missed token doesn't end in `.md` → mint a `FolderNode`
  (literal-text title, same as `createImaginedPrefix` used to).
- Current node is `FolderNode` and the missed token *does* end in `.md` → mint an `ArtifactNode`
  (literal-text title).
- Current node is `ArtifactNode`/`BlockNode` → mint a `BlockNode` heading (title from `--titles`,
  unchanged from today).

With this in place, `createImaginedPrefix` is removed entirely — the `consumed === 0` case in
`resolveTokens` just calls `descend(store, rootId, tokens, opts, trace)` directly and the same
generalized miss-handling covers it, no separate bottom-up-then-attach construction needed. The one
thing that needs explicit re-preservation: the upfront "some segment must end in `.md`" validation,
re-expressed incrementally (before minting a new `FolderNode`, confirm at least one *later*
remaining token still ends in `.md`; otherwise throw the same "needs a filename to know where the
artifact boundary is" error) rather than a single upfront scan.

## 9. `kg:update` and `--text-only`

Generalizes `ArtifactNode.ingestFromDisk`'s own mechanism (parse, then either fresh-hydrate or
`reconcileTree`-reconcile depending on whether there's already content) from "artifact root" down to
**any existing node**. `<path>` always names the existing target; stdin is always required — there's
no dual-mode ambiguity here the way there is for `kg:insert`.

Both modes start identically: parse stdin via `parseMarkdownTree`, whose own leading-paragraph
"consuming" rule (`astParser.ts` §2) only fires for a real heading/listItem *container* — the piped
markdown is parsed as a standalone root, which never gets it (checked live: `isHeadingOrListItem`
is `false` for a file's own root). `path` here plays exactly the role a heading would, though, so
this replicates the rule by hand rather than getting it for free: if the parsed root's first child
is a `paragraph`, its text becomes `path.text` and it's dropped from the child list before anything
else runs; `path`'s own `type`/`title` are never touched, only `text`/`children`. Both modes also
unconditionally clear `path.holder` — real content just arrived, regardless of which mode runs next,
same reasoning as `kg:insert`'s own unconditional clear ([§4.2](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.2 Block — the full three channels]]>) (p)). Confirmed live: the default
mode gets this for free via `hydrateFromParsed`'s own clear ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)); `--text-only` never calls
`hydrateFromParsed`, so it needs the same clear spelled out explicitly instead. They differ in what
happens to everything after that:

- **Default — full reconcile.** Overflow blocks are diffed against `path`'s existing children via
  the full Gestalt-match machinery ([§5](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/5. The reconciliation "nowhere problem," worked example]]>)'s apparatus) — matched/moved/changed/removed/added,
  identical to what a real artifact re-ingest already does.
- **`--text-only`.** Overflow blocks still become children — never silently dropped — but via a raw
  **prepend** ahead of whatever's already there, with no diffing and no attempt to match/reuse
  existing child identities. This is the cheap path: skip the expensive, identity-preserving
  reconciliation when all that's actually wanted is a text-field update, while still not losing any
  extra content that happened to be piped in alongside it.

**Targeting an `ArtifactNode` specifically.** `kg:update` never reads or writes the backing file, so
`fileHash` is correctly left untouched — but leaving `ingestedHash` untouched too would be wrong:
the next plain `kg:ingest` of that file would still see `ingestedHash === fileHash` (if the file
itself hasn't changed) and skip re-processing entirely, silently leaving the `kg:update`-injected
content permanently unreconciled against the file. Fixed by having `kg:update` recompute
`ingestedHash` itself — via the same in-memory rendering pipeline `kg:project`/`runProject` already
uses (`toMarkdown()` + `withFrontmatter`), hashed with the same `computeFileHash` real files use, but
never written to disk. `fileHash` stays exactly as it was (only a real disk read ever changes it),
so `ingestedHash === fileHash` now correctly fails the moment the graph and file diverge — forcing
the next real ingest to reconcile properly instead of wrongly skipping, whether or not the file
itself ever actually changes in the meantime. Can call `toMarkdown()`'s own public accessor
directly, no bypass needed — its guard now checks `children.length`, not `ingestedHash` ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)'s
own toMarkdown fix), so it already returns real content the moment `kg:update` has written any,
regardless of whether a real ingest ever ran. This isn't gated on subtree purity the way
`kg:project`'s own **(o)** channel is ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)) — it's a fingerprint, not a disk write, so a holder elsewhere in the
subtree doesn't block it.

## 10. `kg:remove`

Wraps the existing `tombstoneLiveSubtree` (node.ts:706-714) for manual, on-demand invocation against
an arbitrary node — today that function only ever runs as a side effect of a whole tracked artifact
disappearing from disk (`artifacts.ts`'s artifact-tombstone path). `kg:remove <path>` exposes the
same recursive tombstone directly, against any Block/Artifact/Folder target (the artifacts root
itself, `path === '.'`, is explicitly refused — tombstoning the whole corpus is never intended).
Explicitly **not** a hard delete — `hardDeleteNode` (the actual quad-erasing GC primitive used for
orphaned embedded subdocuments) stays internal-only, never exposed to users; a tombstoned node's
quads remain, inert, exactly like any other reconciliation removal.

## 11. `kg:title`

Already implemented (interactive, reads from stdin/readline) — included here only so the CRUD map
in [§2](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/2. Command map]]>) is complete. No design changes from this round.

## 12. Considered and rejected

- **Ordinal/absolute-index addressing** (e.g. treating a bare `"2"` or `"§2"` code as "the 2nd
  child," for the case where a wikilink forward-references content that doesn't exist yet). Turned
  out to be based on a misreading of the actual link syntax: a real wikilink is
  `[§2](<[[/full/real/path/with/the/real/heading/title]]>)` — the `§2` is display text only; the
  actual resolution path already carries the real title. So `resolveBlockLinks`
  (apeironNgn/artifacts.ts:194-205) never needs anything beyond ordinary exact-then-prefix title
  matching (`findChild`, node.ts:428-439), which already works today. Heuristically extracting a
  position from a numbered heading title (`"2. Concrete design"` → position 2) was also considered
  and rejected as too risky — not worth the guess, consistent with reconciliation's own general
  "decline rather than guess" posture.
- **Text-match rename-detection as a holder-promotion channel** ([§4.1](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/4. Promotion channels, per node category/4.1 Folder/Artifact — no position channel]]>)) — structurally can't
  work (empty-string key, ambiguous-singleton guard), and even if it could, blending it with
  path-match would muddy two mechanisms that are conceptually answering different questions ("did
  this move" vs. "did the thing I was waiting for arrive").
- **Separate `kg:move` + `kg:create` commands, instead of one unified `kg:insert`.** Considered
  because "for an existing node this is just a move" is a fair observation on its own — but splitting
  it would mean duplicating the same deep-path resolution and positioning logic across two commands
  for no real benefit. One command whose behavior branches on "does the target already exist" is
  simpler, and mirrors how `ingestFromDisk` already unifies "fresh hydrate" vs. "reconcile" under one
  operation rather than two. (This is unrelated to `kg:resolve --create-holder`, which stays its own
  command regardless — the split that was actually rejected here is move-vs-create, not
  abstract-vs-concrete.)

## 13. Status

**Implemented and verified** (`npm run verify` green throughout; every mechanism below additionally
covered by disk-free unit tests — a plain in-memory `Store`, no service/disk involved — exercising
the specific scenario each fix targets, all removed again once confirmed since they were scratch,
not permanent suite additions):

1. `holder` threaded through `toReconcileShape` ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)).
2. The reconciliation splice fix, including the `ChildDiff` interface extension (`holderSpliceTargets`)
   and the cross-parent-move sub-diff path ([§5](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/5. The reconciliation "nowhere problem," worked example]]>)) — caught and fixed a same-target-splice
   ordering bug live (two holders landing in the same gap came out reversed) before it shipped.
3. `.holder` cleared on all four write paths (`ArtifactNode.trackFromDisk`, `BlockNode.hydrateFromParsed`,
   `FolderNode.hydrateFromParsed`, `runProject`) + **(o)**'s derived-field bookkeeping ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)).
   Also found and fixed live, beyond what this section originally listed: the Folder/Artifact
   rename/removal *sweep* (a separate mechanism from the above) had the identical "nowhere problem"
   §5 fixed at Block level — a top-level holder always looked removed to it. Also found while wiring
   this: `ArtifactNode.toMarkdown()`'s own guard was checking `ingestedHash`, a stale proxy that
   blocked rendering `kg:insert`-authored content — fixed to check `children.length` instead.
4. `insertOrderedChild` + `kg:insert` ([§7](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/7. `kg:insert` — position, promote, or create]]>)) — move/promote/create, multi-block sequences, both
   `TreeNode` overrides (`BlockNode`/`FolderNode`).
5. `runProject`'s purity gate + `.text` derivation (extended to `FolderNode` too, not just
   `ArtifactNode` as originally scoped) + hash refresh, all skipped correctly for `--dry-run`
   ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)).
6. `kg:resolve --create-holder`'s internal unification ([§8](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/8. `kg:resolve --create-holder` — scope and internal unification]]>)) — `createImaginedPrefix` removed
   entirely; verified live against the exact bug scenario that motivated it (a partially-real
   prefix followed by a folder-tier gap, which used to mint a wrongly-typed heading).
7. `kg:update` / `--text-only` ([§9](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/9. `kg:update` and `--text-only`]]>)) — corrected live: `parseMarkdownTree`'s leading-paragraph
   consuming rule never fires at its own root, so the absorption is replicated by hand rather than
   inherited for free (§9's own text now reflects this).
8. `kg:remove` ([§10](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/10. `kg:remove`]]>)) — extended to accept a `FolderNode` target too, with an explicit refusal to
   remove the artifacts root itself.
9. `project.ts`'s renderer excluding tombstoned children ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)) — found during the live
   end-to-end CLI pass below: `kg:remove` on a real scratch artifact correctly tombstoned a block
   (confirmed via `kg:tree`), but `kg:project` on the same artifact still rendered that block's
   content. `renderChildren` now filters `tombstonedAt` children before serializing.
10. `kg:ingest`'s confirm/`--force` gate on destructive disk-driven reconciliation ([§14](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/14. `kg:ingest`'s confirm/--force gate on destructive reconciliation]]>)) — found
    the same live end-to-end pass: `kg:insert`-authored content on an already-real artifact,
    never yet projected, was silently tombstoned the next time a real disk-driven `kg:ingest` ran
    against that file for an unrelated reason.
11. `kg:track --reverse` ([§15](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/15. `kg:track --reverse` — tracking, pointed the other way]]>)) — new `projectedHash` field on `ArtifactNode`/`FolderNode`, set by
    `kg:project` on every real write; `runReverseTrack` reports never-projected/changed-since-
    projection/stale-on-disk drift, read-only, no mutation.
12. `kg:track`'s own confirm/`--force` gate on its removal sweep ([§14](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/14. `kg:ingest`'s confirm/--force gate on destructive reconciliation]]>)) — the follow-up flagged
    as out of scope when §14 first shipped, now closed the same way; `pre-commit`/`post-index-change`
    updated to pass `--force` so their existing unattended behavior doesn't change.
13. `kg:project`'s confirm/`--force` gate against clobbering disk changes it doesn't know about
    ([§16](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/16. `kg:project`'s own reciprocal gap — it could silently clobber a hand-edited file]]>)) — `fileHash`/`projectedHash` compared against the current on-disk hash before
    every real write.

A live end-to-end pass through the actual running service/CLI is now underway (a real corpus
mirror populate via `kg:ingest --track`, followed by real `kg:resolve --create-holder`/`kg:update`/
`kg:insert`/`kg:remove`/`kg:project` calls against scratch artifacts) — everything in 1-8 above was
originally verified only via direct, disk-free calls into each `run*` function against a hand-built
in-memory `Store`. Items 9-10 are what this pass has caught so far; earlier rounds of the same live
testing (recorded only in session history, not here, since they're narrative rather than lasting
design content) also caught and fixed: `kg:insert`'s stdin-detection relying on `isTTY` alone (an
empty non-interactive read isn't the same as "nothing piped"), `kg:update` proceeding silently on
empty stdin instead of refusing, and `kg:project`'s `writeFileSync` failing on a promoted holder
folder whose directory never existed on disk.

## 14. `kg:ingest`'s confirm/`--force` gate on destructive reconciliation

**Direction, restated.** `kg:project` (graph → disk) is the normal output direction from here on —
the whole point of working directly on Apeiron (plan with holders, edit with `kg:insert`/
`kg:update`, traverse with `kg:tree`/`kg:unfold`) is that a real markdown file is something you
*produce* at the end, not something every edit has to round-trip through. `kg:ingest` (disk →
graph) becomes the secondary, occasional direction: re-absorbing a file that changed on disk for
reasons outside this graph's own edits (a hand-edit, a `git pull`, a merge). The git hooks
(`AperasKG/.githooks/pre-commit`/`post-index-change`) currently only call `kg:track`, not
`kg:ingest` — as this direction becomes the normal one, those hooks need rewriting to match
(flagged here, not done as part of this round).

**The gap this closes.** Reconciliation's only signal for "this was removed" is absence from the
freshest disk parse — it has no way to distinguish "genuinely deleted from the markdown" from "only
ever existed in-graph, via `kg:insert`/`kg:update`, and hasn't been projected to disk yet." Found
live: inserting a real (non-holder) block directly into an already-real artifact, then running an
ordinary `kg:track`+`kg:ingest` after an unrelated real edit to the same file, silently tombstoned
the un-projected block right along with picking up the real edit. The same blind spot applies to
`ingestFolderTree`'s own structural sweep ([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)) — a real Folder/Artifact whose path
disappears from a fresh disk walk is tombstoned outright, no confirmation.

**The fix: hold back, don't guess.** Neither call site tries to distinguish the two cases (that
would mean guessing intent) — instead, any removal either one is about to make is held back
unless the caller explicitly says to proceed:

- `ArtifactNode.ingestFromDisk(force)`: if `reconcileTree` produces a non-empty `tombstones` list
  and `force` is false, nothing is committed at all for that artifact — no `hydrateFromParsed`, no
  `applyTombstone`, hashes untouched — and the tombstone previews (`blockId`/`type`/`title`) are
  returned as `pendingConfirmation` instead. Retried later (with `force: true`, or once confirmed),
  it recomputes and applies fresh rather than replaying a stale decision.
- `ingestFolderTree(store, force)`: same idea for its `stillRemoved` set — a folder about to be
  tombstoned is left alone (unattached from the fresh tree, but not tombstoned) and its path is
  returned via `pendingRemovals` instead, when `force` is false. Renames and additions in the same
  sweep are unaffected — only the removal step itself is gated.
- `kg:ingest`'s CLI client (`kgIngest.ts`) collects both kinds of held-back removal from the first
  response, prints what would be removed (each artifact's node titles, each folder's path), and
  prompts once — `Are you sure you want to remove these? [yes/NO]`, defaulting to **NO** on
  anything but an explicit `yes`/`y`. Confirming re-issues the same request with `force: true`;
  declining leaves everything pending exactly as the first response found it (re-running later,
  with or without `--force`, sees the same prompt again — nothing is silently lost or silently
  applied). `--force` on the CLI skips the prompt entirely, for non-interactive/scripted callers
  (a future hook included) where nothing can answer it.

**Follow-up (closed): `kg:track`'s own removal sweep had the identical gap.** `trackAllArtifacts`
(`apeironNgn/artifacts.ts`) has its own `stillRemoved` sweep — a real `ArtifactNode` whose path
disappears from disk, detected independently of `kg:ingest` entirely (a plain `kg:track` triggers
it). It gets the exact same treatment: a `force` parameter, held back into `pendingRemovals` when
`!force`, threaded through `runTrack`/the service protocol. `kgTrack.ts`'s CLI prompts exactly like
`kgIngest.ts` does, with its own `--force`; `kg:ingest --track` folds the same `force` value into
its nested `runTrack` call (one flag governs every removal the whole invocation can trigger, tracked
sweep included — `kgIngest.ts`'s own confirmation list now folds in `trackResult.pendingRemovals`
too, so nothing removal-shaped falls through a gap between the two CLIs).

This one *is* live on the current hooks, unlike `kg:ingest` — `AperasKG/.githooks/pre-commit` and
`post-index-change` both call plain `kg:track` today, unattended, on every commit/index change. A
default-NO interactive prompt there would either hang waiting for stdin or silently leave the
mirror stale mid-commit — neither acceptable for something that currently just works. Both hooks now
pass `--force` explicitly, preserving today's actual behavior (unconditional removal, same as
before this gate existed) while leaving the *manual* `kg:track` path safe-by-default. This
`--force` is meant to carry forward as-is once the hooks are rewritten for the `kg:project`-first
direction (still not done — the actual rewrite is a separate, larger change than this gate).

## 15. `kg:track --reverse` — tracking, pointed the other way

**Direction, restated again.** Phase 0's own asymmetry was never "ingestion is bad" — it was that
the *cheap* bookkeeping half (`kg:track`: does this file exist, has its hash moved) was always safe
to run automatically (the git hooks do, on every commit), while the *heavy* content half
(`kg:ingest`: actually parse and reconcile) always stayed a deliberate, explicit, human-invoked
step, never run automatically. Phase 1+ keeps that same asymmetry, mirrored: `kg:project` (the new
heavy half, graph → disk) stays deliberate and explicit, exactly like `kg:ingest` always was — no
automatic projection, ever. What *should* run automatically (once the hooks are rewritten to match
the new primary direction — flagged in [§14](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/14. `kg:ingest`'s confirm/--force gate on destructive reconciliation]]>), not done here) is the cheap bookkeeping half's own mirror
image: not "has disk changed," but "has the graph changed since disk last caught up."

**The mechanism.** A new field, `projectedHash` (`ArtifactNode`/`FolderNode` alike), holds the hash
of the markdown `kg:project` last actually wrote for that node — set only by `kg:project` itself, on
every real (non-`--dry-run`) write, alongside its existing bookkeeping. It's deliberately its own
field, not a reuse of `ingestedHash`: that one already carries an ingest-direction meaning (`kg:project`
sets it to mean "matches disk," `kg:update` recomputes it to mean "graph is ahead of disk," per
[§9](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/9. `kg:update` and `--text-only`]]>)) — overloading it further would blur "needs re-ingest" and "needs re-project" into one
ambiguous signal instead of two clear ones.

`kg:track --reverse` (`runReverseTrack`, `kgTrack.ts`) is the read-only report that uses it: for
every real (non-tombstoned) `ArtifactNode`/`FolderNode` with actual content to render
(`toMarkdown()`/`toReadme()` non-null/non-empty), recompute its hash and compare against
`projectedHash`. No field is ever written by this pass itself — it only ever reads and reports,
exactly as cheap and side-effect-free as forward `kg:track`'s own hash comparison is. Three
categories, one pass:

- **Never projected** — `projectedHash` was never set. The typical case: a holder populated via
  `kg:insert`/`kg:update` (or promoted by either) but never yet written to disk at all.
- **Changed since last projection** — `projectedHash` is set, but the current render no longer
  matches it (more `kg:insert`/`kg:update`/`kg:remove` edits landed since the last `kg:project`).
- **Stale on disk** — the reverse of forward-track's own removal detection: an `ArtifactNode`
  that's tombstoned in-graph, but whose `path` still names a file that exists on disk.
  `kg:project` only ever writes, never deletes, so a graph-side removal never reaches the file on
  its own; this category exists purely to surface that, not to act on it — deleting the file is left
  to the human. (Not attempted for `FolderNode`: a removed folder mapping to "the directory still
  exists" isn't as crisp a check — a directory can go on existing for unrelated reasons a single
  hash comparison can't distinguish — so this category stays `ArtifactNode`-only for now.)

Nothing here is gated on subtree purity the way `kg:project`'s own **(o)** channel is
([§6](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/6. Bookkeeping gaps found while designing this (all currently real, all need closing)]]>)) — a holder artifact with real, pure content underneath is exactly a legitimate "never
projected" candidate (it just hasn't been projected *yet*), and one with impure (holder-containing)
content underneath will simply hit `kg:project`'s own existing purity error the moment projection is
actually attempted; this report doesn't need to duplicate that check to be useful.

## 16. `kg:project`'s own reciprocal gap — it could silently clobber a hand-edited file

**§14's issue, mirrored.** §14 fixed disk clobbering graph: a real disk-driven reconciliation
silently destroying in-graph content the file itself never knew about. `kg:project` had the exact
same failure mode in the opposite direction — graph clobbering disk. Found live: project a fresh
artifact, hand-edit the resulting file directly on disk (add a section), then run `kg:project`
again with *no graph-side change at all* — it silently overwrote the file back to the stale graph
content, destroying the hand-edit. `runProject`'s write path (`kgProject.ts`) never read the file
it was about to overwrite; it unconditionally `writeFileSync`'d whatever the graph currently
rendered. Every intervening real change to that file — a hand-edit, an external tool, a
`git checkout` of an older revision — was invisible to it and got silently discarded the moment
`kg:project` ran again, with no warning of any kind.

**The fix.** Before the real write, `runProject` now reads the current file on disk (if it exists)
and hashes it, comparing against whichever field already means "the graph's last known disk
content" for that kind:

- **`ArtifactNode`: `fileHash`.** Deliberately not `projectedHash` — `fileHash` is refreshed by
  *both* directions (a real `kg:track`/`kg:ingest` read sets it, and `kg:project`'s own write sets
  it too, to the exact same value), so it's already "what disk should currently read as, as far as
  the graph knows" regardless of which direction last touched it. This matters for the common case
  of projecting an artifact that was ingested from real disk and never projected before
  (`projectedHash` unset, but `fileHash` matches disk exactly) — using `projectedHash` here would
  have flagged that ordinary case as a false conflict every time. `fileHash` unset entirely, with a
  file already sitting at the target path, is treated as a conflict too — the graph has never read
  that path, so any existing content there is as unknown to it as a hand-edit would be.
- **`FolderNode`: `projectedHash`.** No `fileHash`-equivalent baseline exists for a folder's README
  (ordinary folder ingestion never hash-tracks it). Unlike the `ArtifactNode` case, an *unset*
  `projectedHash` here is **not** treated as a conflict even if a README already exists on disk —
  that's just the ordinary first-projection-of-an-already-ingested-folder case, and flagging it
  would make every folder's first `kg:project` demand `--force` for no reason. Only a *set*
  `projectedHash` that no longer matches disk counts as a real conflict. (Narrower than the
  `ArtifactNode` check for this reason — a known, accepted asymmetry, not an oversight.)

A conflict holds back exactly like [§14](<[[/Aperas-crud-design.md/# Apeiron Node CRUD — Design/14. `kg:ingest`'s confirm/--force gate on destructive reconciliation]]>)'s gate: nothing is written and no bookkeeping (`.holder`
clear, hash refresh) is committed — the response instead reports `conflict: true`, `kgProject.ts`'s
CLI prints what's going on and prompts `Overwrite anyway? [yes/NO]` (default **NO**), confirming
re-issues the same request with `force: true`, and `--force` on the CLI skips the prompt entirely.
Verified live: a hand-edit survived a decline, got overwritten on confirmation, and `--force`
applied with no stdin at all; a real disk-ingested-but-never-projected artifact projected cleanly
with no false-positive prompt.
