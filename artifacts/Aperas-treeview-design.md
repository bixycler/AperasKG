# TreeView & Profile — Design

**Status: implemented, live-verified against a synthetic graph exercising every scenario §4 works
through by hand — not yet run against the real `AperasKG/Apeiron/` corpus.** Written to pin down
the design before Phase 0 work on it started, per `Aperas-design.md`'s roadmap: the tree view
needed refactoring in Phase 0 so Phase 1's Human UI Peras would have something stable to build
against, rather than being built on top of the single-flag model this replaces and then needing
rework once multiple viewers exist. Grounded in
`Aperas-apeironngn-design.md` and the live `web/src/lib/apeironNgn/` code, not in
`Aperas-core-ontology-design.md`'s older Three-Projection-Modes/Intrinsic-vs-Extrinsic-links
framing — that doc predates the ApeironNgn migration and describes a model since superseded in
real ways (e.g. `Assertion`/`BaseEdge` eliminated outright, `Link` demoted from a top-level node
to a `BlockNode`-owned subdocument). Only "Abstraction by Folding" — fold a subtree to an
abstract, an abstract to a title — carries forward as still-live philosophy; the specific
mechanics below are new, not a restatement of that doc's §5.

## 1. The problem: `unfolded` is one flag, shared by everyone

Today `BaseNode.unfolded` (`shape.ts`'s `BASE_NODE_SHAPE`) is a single boolean per node, in the
graph itself, read and written by whoever last called `kg:unfold`/`kg:fold`
(`Aperas-agentic-query-tools-design.md`). A human expanding a subtree and an agent doing its own
BFS traversal are the same writer as far as the graph is concerned — one collapses what the other
just expanded. There's no "expanded for me" versus "expanded in the underlying data." Separately,
`links` are graph structure `BlockNode`/`ArtifactNode`/`FolderNode` already carry (`BaseNode.links`,
inherited by `TreeNode` and everything under it) but nothing today makes them part of a folded
walk the way structural `children` are.

**Why links belong in the walk at all.** Every node's own view is centered on itself — it's always
the center of its own world. Structural `children` is the *physical* structure: fixed, authored,
positional, the same distance apart for every viewer regardless of what they're currently thinking
about. `links` form a second, independent structure over the same nodes — the *mental* structure:
which nodes are related enough, right now, to think about together, regardless of where they
physically sit in the containment tree. An assertion drawing on three nodes scattered across three
different documents wants those three treated as siblings for the purpose of writing it — placed
side by side for direct comparison — not left at whatever physical distance separates them in the
tree, the way a split-screen editor puts two unrelated files next to each other because you're
working on them together, not because they live near each other on disk. That's what folding links
into the same walk as `children` buys an i-view that a purely-structural tree could never give:
bringing mentally-related content into direct proximity without moving or duplicating anything in
the physical tree. Physical structure still wins wherever the two collide in the combined render —
§6's canonical-position rule (a node's structural home is always canonical when it qualifies) is
exactly this principle made concrete: mental structure supplements the physical tree at the
positions links create, it never overrides it.

## 2. Three tiers of perata, not one

`Aperas-design.md`'s own vocabulary (Apeiron the substrate, Aperas the transduction, Peras/perata
the crystallized interfaces it produces) already implies layering; the graph today only really has
two: the raw Apeiron store, and whatever a given projection (`kg:tree`, `kg:project`, the future
Web UI) renders directly off it. This proposal makes the middle layer real:

1. **Artifact projection** (unchanged) — the existing always-fully-unfolded `.md` sync
   (`Aperas-artifact-projection-design.md`). `BlockNode.children` stays the source of truth for
   document structure; this tier ignores fold state entirely, exactly as today.
2. **i-view** — the new intermediate tier this doc proposes. "i-" is deliberately underspecified,
   the same way the project's other core terms (Apeiron/Aperas/Peras) carry more than one reading
   at once: imagine, inner/internal, idea, intel, intermediate, index all apply to what this tier
   does — it's the graph's own internal, indexable idea of "what a viewer currently sees," sitting
   between the raw substrate and any outward-facing render. `TreeView` (§3) is the first, and for
   now the only, i-view kind.
3. **UI projection** — Human UI and Agentic Interface, both consuming an i-view rather than
   reading `BaseNode.unfolded` off the graph directly. Out of scope here beyond noting that this is
   the dependency Phase 1's Web App needs settled first.

## 3. Data model: `Profile` and `TreeView`

Two new top-level classes, alongside the existing `BlockNode`/`ArtifactNode`/`FolderNode`/`Link`/
`StringProp` (`node.ts`'s `CLASS_BY_KIND`, `vocab.ts`'s `ID_PREFIX_RE`/`KIND_RE`, `shape.ts`'s
`SHAPE_BY_KIND` — all three need entries for both). Named `Profile`/`TreeView`, not
`ProfileNode`/`TreeViewNode` — neither is a `TreeNode` subclass (no title/text/tree position of its
own), so the un-suffixed naming matches `Link`/`StringProp`, not `BlockNode`/`ArtifactNode`/
`FolderNode`.

```
Profile
  name: Optional xsd:string     -- e.g. "human", "agent" — a label, not an enum; no auth (§7)

TreeView
  profile: One, reference -> Profile
  name:    Optional xsd:string
  unfolds: Set, reference -> (TreeNode | Link)
```

`TreeNode` here is the existing class (`node.ts`) — `BlockNode | ArtifactNode | FolderNode` — and
`Link` is the existing embedded `{ target, predicate }` subdocument (`BaseNode.links`). **There is
no separate "view-time" node type.** A `TreeView` is a lens over the one real graph — a set of
which edges out of an already-visible node are currently revealed — not a parallel structure that
gets its own copy of nodes. Rendering walks the real `TreeNode`/`Link` graph directly, consulting a
`TreeView`'s `unfolds` membership at each hop to decide whether to keep descending. (An earlier
draft of this doc proposed a distinct view-time `TreeNode` to handle a node reached by more than
one path — unnecessary, retracted; see §6.)

`Profile > TreeView` is one-to-many, stored as the reference living on `TreeView` (`profile`), not
a `treeViews` list on `Profile` — the reverse direction is a backlink query (`node.ts`'s existing
`backlinks(store, id, 'profile')` pattern), same as every other one-to-many relationship in this
graph already resolves (a `BlockNode`'s children are found by reverse-querying `__parent`, not
stored forward). No new mechanism needed.

## 4. Worked example

The sample graph §5/§6's rules are checked against. Labels are shorthand for real node ids (`1.2`
stands in for whatever real id sits at that structural position) — a concrete stand-in, not a
literal addressing scheme. The ground-truth graph below is deliberately not fully explored by the
unfold sequence — `3` has children and a link of its own that the view never touches, exactly as a
real graph would: unfolding only ever reveals what's been explicitly asked for, never the full
structure around it.

**Sample graph**: three top-level `TreeNode`s under `Root`, each with structural children, plus a
handful of `Link`s crossing between them:

```
Root
├─ 1
│  ├─ 1.1
│  ├─ 1.2
│  │  ├─ 1.2.1
│  │  ├─ 1.2.2
│  │  ├─ l1 → 2.1
│  │  └─ l2 → 3.1
│  ├─ 1.3
│  ├─ l1 → 2.2
│  └─ l2 → 3.3
├─ 2
│  ├─ 2.1
│  ├─ 2.2
│  │  ├─ 2.2.1
│  │  ├─ 2.2.2
│  │  └─ l1 → 1.2
│  ├─ l1 → 1.2
│  └─ l2 → 3.3
└─ 3
   ├─ 3.1
   ├─ 3.2
   ├─ 3.3
   │  ├─ 3.3.1
   │  │  ├─ 3.3.1.1
   │  │  └─ 3.3.1.2
   │  └─ 3.3.2
   └─ l1 → 1.1
```

**Unfold sequence** (`Root` is always unfolded — listing `1`/`2`/`3` needs no action; every other
line is one `kg:unfold <ref> --view <this>` call, each adding *only* the stated `ref`, per §5):

1. `kg:unfold 1` → `1` becomes `{.1, .2, .3, l1→2.2, l2→3.3}` (its children and its links, both
   listed).
2. `kg:unfold 1.2` → `1.2` becomes `{.1, .2, l1→2.1, l2→3.1}`.
3. `kg:unfold` the `Link` `1.l1` (→ `2.2`) → target shown fully: `2.2{.1, .2, l1→1.2}`.
4. `kg:unfold` the `Link` `2.2.l1` (→ `1.2`) → target shown fully: `1.2{.1, .2, l1→2.1, l2→3.1}`
   (already true from step 2 — this unfolds a *different* `Link` that also reaches the same node).
5. `kg:unfold 2` → `2` becomes `{.1, .2, l1→1.2, l2→3.3}`.
6. `kg:unfold 2.2` → `2.2` becomes `{.1, .2, l1→1.2}`.
7. `kg:unfold 3.3.1` directly — not reached through `3 > 3.3 > 3.3.1` — → `3.3.1` becomes
   `{.1, .2}`. Nothing else under `3` (`3.1`, `3.2`, `3.3.2`, `3`'s own link `l1→1.1`) was ever
   asked for, so none of it appears below.

**Resulting tree** (`kg:tree --view <this>`):

```
├─ 1{title,abstract}
│  ├─ 1.1{title,abstract}
│  ├─ 1.2{title,abstract} [*]
│  │  ├─ 1.2.1{title,abstract}
│  │  ├─ 1.2.2{title,abstract}
│  │  ├─ 1.2.l1→2.1{title,abstract}
│  │  └─ 1.2.l2→3.1{title,abstract}
│  ├─ 1.3{title,abstract}
│  ├─ 1.l1→2.2{title}  [* see 2 > 2.2]
│  └─ 1.l2→3.3{title,abstract}
├─ 2{title,abstract}
│  ├─ 2.1{title,abstract}
│  ├─ 2.2{title,abstract} [*]
│  │  ├─ 2.2.1{title,abstract}
│  │  ├─ 2.2.2{title,abstract}
│  │  └─ 2.2.l1→1.2{title}  [* see 1 > 1.2]
│  ├─ 2.l1→1.2{title,abstract}
│  └─ 2.l2→3.3{title,abstract}
└─ 3{title,abstract}                    — Root-child preview (unconditional, §5)
   └─ 3.3{title}                        — breadcrumb: 3.3 itself has no `unfolds` entry
      └─ 3.3.1{title,abstract}
         ├─ 3.3.1.1{title,abstract}
         └─ 3.3.1.2{title,abstract}
```

Reading this against §5/§6's rules:
- `1.2` gets `[*]` at its structural home — qualifying: visible under unfolded `1`, and separately
  unfolded itself (step 2) — the *canonical* full render (§6).
- `2.2.l1→1.2` is a `Link`, itself unfolded (step 4), which would normally mean "show target
  fully" (§5's rule b) — but `1.2` already has a qualifying home, so this position collapses to a
  pointer instead (§6).
- `1.l2→3.3` is a plain link entry, listed only because its owner `1` is unfolded (§5's rule a) —
  never itself separately unfolded — so it gets the ordinary preview tier, `{title,abstract}`.
- `3` gets `{title,abstract}` — *not* title-only — because it's a direct child of `Root`, which
  always earns the preview tier regardless of whether `3` is itself in `unfolds` (it isn't). It
  additionally lists exactly one child, `3.3`, purely because something further down is unfolded —
  not `3.1`/`3.2`, and not `3`'s own link `l1→1.1` (links are only ever listed by a node that's
  genuinely *in* `unfolds`, which `3` is not).
- `3.3`, one level deeper, gets `{title}` only — its own immediate parent (`3`) doesn't itself
  qualify as genuinely unfolded (it's only a preview), so `3.3` doesn't inherit `3`'s preview
  status the way a plain child of a *genuinely* unfolded node would. It lists exactly one child,
  `3.3.1` — not its sibling `3.3.2` — for the same "only the relevant path" reason. This is the
  concrete case answering the previous draft's open question about whether an interior breadcrumb
  node prunes down to just the relevant path or lists everything the way `Root` does: it prunes —
  `3.3.2` never appears anywhere in this tree.
- `3.3.1` is genuinely unfolded (step 7) — full tier, regardless of the breadcrumb chain above it.

**Fold sequence**, applied to the state above (§5):

- `kg:fold 1` — removes `1`'s own entry, cascading to remove everything under it that was *also*
  separately unfolded: `1.2` and the `Link` `1.l1→2.2`. (`1.2`'s own children/links were never
  separately unfolded, so nothing further cascades from there.)
- `kg:fold 3` — cascades all the way down through `3`'s structural subtree (`3` itself was never
  in `unfolds`, `3.3` wasn't either — the cascade walks *through* both, since neither has to be
  in `unfolds` itself to be on the path to something that is) to remove `3.3.1`'s entry.

**Resulting tree**:

```
├─ 1{title,abstract}
├─ 2{title,abstract}
│  ├─ 2.1{title,abstract}
│  ├─ 2.2{title,abstract}               — no [*]: 1.2's home no longer qualifies
│  │  ├─ 2.2.1{title,abstract}
│  │  ├─ 2.2.2{title,abstract}
│  │  └─ 2.2.l1→1.2{title,abstract}     — now the only qualifying position; renders fully
│  │     ├─ 1.2.1{title,abstract}
│  │     ├─ 1.2.2{title,abstract}
│  │     ├─ 1.2.l1→2.1{title,abstract}
│  │     └─ 1.2.l2→3.1{title,abstract}
│  ├─ 2.l1→1.2{title,abstract}
│  └─ 2.l2→3.3{title,abstract}
└─ 3{title,abstract}                    — still a Root-child preview; no children listed now,
                                            since nothing beneath it is unfolded anymore
```

`2.2.l1→1.2` flips from a pointer to a full render the moment `1.2`'s home stops qualifying —
the canonical-position decision is recomputed fresh at render time from whatever's currently in
`unfolds`, never cached from an earlier render (§6). And `3` shows `{title,abstract}` in *both*
the pre-fold and post-fold trees — an earlier draft of this doc had it flip from title-only
pre-fold to title+abstract post-fold, which was simply inconsistent: a `Root`-child's own-line
detail doesn't depend on whether it's currently breadcrumbing toward something unfolded.

## 5. Rendering: three display tiers; `kg:unfold` touches exactly one ref

`TreeOptions` (`tree.ts`) and `kg:tree`'s CLI drop `unfoldedMode`/`--unfolded` as a bare boolean;
`--view <ref>` takes its place. Supplying a view drives unfolded-mode rendering keyed off that
view's `unfolds` set; omitting it keeps today's other default (title-only, no expand/collapse
simulation) unchanged.

**Correction to an earlier draft of this doc**: `kg:unfold <ref> --view <ref>` adds *only* the one
specified `ref` (a `TreeNode` xor a `Link`) to the view's `unfolds` set — matching the current
`setUnfolded(store, id, value)` implementation exactly, not the "add every child and every link
too" behavior a previous draft wrongly proposed. `<ref>` for a `TreeNode` resolves the normal way
(id or path); for a `Link`, only a bare id (snowflake code) is accepted — a `Link` has no `path`
field and no natural slug of its own to build one from.

What actually gets *shown* at render time follows from whatever's in the set — not from anything
`kg:unfold` writes beyond that one entry. A `TreeNode`'s own-line detail has three tiers; whether
it lists any children at all is a separate question layered on top (see §4 for each in context):

- **Genuinely unfolded (in `unfolds`)** — own line `{title, abstract}`; lists *both* its structural
  children and its own `links` (rule a), each recursively at whichever tier applies to it.
- **Not itself unfolded, but its immediate parent is genuinely unfolded — or it's a direct child of
  `Root`** (`Root` always counts here without needing an `unfolds` entry of its own — it's the one
  always-qualifying "parent") — own line `{title, abstract}` (preview). Lists nothing further by
  default. **Exception**: if something below it is unfolded (reachable only by descending through
  it), it additionally lists just the *one* child continuing toward that — pruning every other,
  irrelevant child. This is what makes `3` in §4's example show `{title,abstract}` plus exactly one
  child (`3.3`), never `3.1`/`3.2` and never its own link `l1→1.1`.
- **Neither of the above** — its own parent doesn't qualify either (it's itself only reached as a
  breadcrumb link in someone else's chain) — own line `{title}` only, no abstract. Same
  passthrough-only-child behavior as the tier above, minus the abstract. This is `3.3` in §4's
  example: `3`'s parent-qualification doesn't propagate down to it, since `3` itself is only at
  preview tier, not genuinely unfolded — and `3.3` in turn shows only its one relevant child
  (`3.3.1`), never `3.3.2`. That's the concrete answer to whether an interior breadcrumb node
  prunes to just the relevant path or lists everything the way `Root`'s children do: it prunes.

A `Link`'s own rendering is a separate, one-hop question, layered onto whichever `TreeNode` owns
it: a `Link` in `unfolds` shows its target fully (rule b, one level, as if the target were itself
in the tier-1 case above); a `Link` merely *listed* because its owner is genuinely unfolded, but
not itself in `unfolds`, shows the target's `{title, abstract}` as a preview, no further
recursion; a `Link` belonging to an owner that isn't genuinely unfolded is never listed at all —
only a tier-1 owner lists its links.

This is computed fresh at render time from the current `unfolds` set and the graph's own structure
— nothing about it is stored, which is also what resolves the previous draft's open "should
breadcrumb auto-expansion mutate `unfolds`, permissive or strict" question: it doesn't mutate
anything either way, so there's no such choice to make. See §6 for how a target reached two
different ways picks which tier wins where.

`kg:fold <ref> --view <ref>` removes `<ref>`'s own `unfolds` entry, and cascades: recursively
removes the `unfolds` entry of anything reached *from* `<ref>` (structural children, then `<ref>`'s
own links, same order as rendering) that also has its own explicit entry. Anything outside
`<ref>`'s own subtree that happens to reach into it via a separate, unrelated `Link` is untouched —
folding one path to a node doesn't fold every path to it.

## 6. Two paths to the same node: one canonical, the rest become pointers

Your original framing: for structural `children` the graph is a strict tree — one path from root to
any node — so reaching a deep target just means the breadcrumb down to it is already well-defined.
The complication is a `Link` creating a second path to something also reached structurally (or via
another `Link`).

Worked through against §4's example line by line, the rule turns out simpler than "whichever gets
visited first in the render walk":

**A node's structural (`parent`-chain) position is its one true home.** If that home is both
(a) visible — its immediate structural parent is itself in `unfolds`, so it's actually listed
there — and (b) the node itself has its own `unfolds` entry, the home position is *always* the
canonical full expansion, no matter what. Any `Link` elsewhere pointing at the same node — even one
that's itself in `unfolds`, which would otherwise mean "show the target fully" (rule b, §5) —
collapses instead to a short pointer back to the home, tagged e.g. `[* 2 > 2.2]`, and doesn't
recurse. The home position itself gets tagged `[*]` — "reachable more than one way in this view."
Matches `1.2`/`2.2` in §4's example exactly: both have a qualifying home *and* a separate unfolded
`Link` pointing at them, and in both cases the home wins, the `Link` becomes the pointer.

**If the home doesn't qualify** — not visible (its own parent isn't unfolded, e.g. after folding an
ancestor), or the node itself was never given its own `unfolds` entry — whichever `Link`(s)
pointing at it *are* themselves in `unfolds` get to show the target fully, directly at their own
position, since there's no competing canonical elsewhere. Exactly what happens after §4's
`kg:fold 1`: `1.2`'s own entry is gone and its home (under `1`) no longer lists anything, so
`2.2.l1->1.2` — untouched by folding `1` — becomes the *only* qualifying position and renders fully
there instead of pointing anywhere.

This also makes link-following cycle-safe for free: a `Link` pointing back toward an ancestor (or
toward anything else already canonical elsewhere in this same render) hits the "already canonical
elsewhere — point back" branch before it can recurse.

**If a node has no qualifying home and is reached by two or more different unfolded `Link`s at
once** — both are equally "second pass" (neither is the structural home), so there's no meaningful
ordering between them to break the tie with. Whichever one the walk happens to encounter first
becomes canonical; that's purely a function of implementation-internal iteration order, not a
structural or positional rule worth defining — a real tie, not a case that needs a principled
answer.

**Real implementation consequence**: `renderTreeLines`'s current shape is a single top-down
recursive pass, emitting each line as it's visited. Deciding "does this position get the canonical
full render or a pointer" requires knowing, for the whole view, which nodes have a qualifying home
and which don't — derivable from the `unfolds` set and the graph structure alone, *before* any line
is emitted. A first pass that computes that (a map from node id → its canonical position, if any)
followed by a second pass that emits lines using it is the natural shape; not a one-line addition
to the existing function.

**Line format** — implemented as proposed (`node.ts`'s `renderViewLines`/`renderLinkLine`): `[*]`
follows the existing `(holder)` tag's pattern, appended at the line's end rather than sitting next
to the `[kind]` bracket (`displayLabel`) where it'd risk reading as part of it; a pointer line keeps
the normal `id  [kind]  title` prefix (still identifiable/greppable) with the target's path
appended instead of descending, reusing `TreeNode.toPath()` when the canonical position is a home,
or `<linkId> (link)` when it's another `Link` with no qualifying home — e.g.
`BlockNode/xyz  [heading]  Some Title  (see /reportX/sectionY)`.

## 7. `Profile`: a Chrome-profile-style bucket, not identity

Confirmed scope: `Profile` exists only to keep separate `TreeView`s from colliding — "human" vs.
"agent," or finer-grained if that turns out to matter (per-agent-session, say) — nothing more.
No auth, no permissions, matching every other posture this solo-local-dev tool already takes
(the ApeironNgn service itself assumes one trusted local caller). `name` values like `"human"`/
`"agent"` are just labels a caller chooses, not an enforced enum.

## 8. Git separation: a `.state/` subfolder, gitignored

`Profile`/`TreeView` are per-viewer UI state ("what's currently expanded"), not authored content —
unlike `ArtifactNode`/`BlockNode`/`FolderNode`, which `AperasKG/.githooks/pre-commit` stages on
every commit because they mirror real `.md` source. Implemented: `dehydrateToJsonLd`'s existing
`${kind}.jsonld` pattern (`dehydrate.ts`), reused for a second, separate pass —
`AperasKG/Apeiron/.state/Profile.jsonld` and `AperasKG/Apeiron/.state/TreeView.jsonld` — written by
`dehydrateStateToJsonLd(store, dir = join(getApeironExportDir(), '.state'))`, reusing the same
`serializeDoc`/`allIdsOfKind`/`stableId` helpers rather than a parallel implementation.
`store.ts`'s `rehydrateStore` reads the two state files as a second, tolerant pass (missing
`.state/` entirely — a fresh checkout, or before any view has ever been unfolded — is not an
error, unlike a missing content-mirror file). `pre-commit`'s `git add` list is unchanged — the
whole point is these files are never staged.

`AperasKG/Apeiron/` lives in the **AperasKG repo**, a sibling of this one, reached from here only
via the `AperasKG` symlink (confirmed: `git -C AperasKG rev-parse --show-toplevel` resolves to
`/home/dinhlx/source/AperasKG`) — so the gitignore entry (`Apeiron/.state/`) belongs in *that*
repo's own `.gitignore`, alongside its existing `*.bundle`/`*.tar.gz`/`snapshots/` entries, not
this repo's `web/.gitignore` (which only covers `.run/`, this repo's own analogous local-state
precedent, for a different reason — the ApeironNgn service's lock/socket files).

The shared service isn't hypothetical — `web/src/lib/apeironNgn/service.ts` is a complete, running
implementation (`Aperas-apeironngn-design.md` §4 step 5, whose own "not started" line has been
fixed to match). This design landed as edits to that real file, not a new one.

**Flush cadence: two separate, independently-adjustable intervals — implemented.**
`STATE_FLUSH_INTERVAL_MS` and a `stateDirty` flag sit alongside the pre-existing
`FLUSH_INTERVAL_MS`/`dirty`, with their own `setInterval` calling `dehydrateStateToJsonLd` instead
of `dehydrateToJsonLd` — the exact same pattern `service.ts` already used for the content mirror,
duplicated rather than parameterized, so each interval stays independently tunable (`.state/`
churns on every expand/collapse click, tuned tighter than the 10s content default; being
gitignored and cheap to rewrite, there's no reason to tie the two together).

**Consequence for the `'unfold'`/`'fold'` handlers — implemented.** Both now set `stateDirty`, not
`dirty` (they mutate `TreeView.unfolds`, never `BlockNode`/`ArtifactNode`/`FolderNode`), and their
request shapes (`ServiceRequest`'s `unfold`/`fold`/`tree` variants, `serviceProtocol.ts`) carry a
`viewRef` field alongside the existing `ref`/`flush` fields — omitted, it resolves to the
`"default"`-named view (§10) on `unfold`/`fold`; `kg:tree` instead keeps its plain no-view default
when `viewRef` is omitted, matching §5.

## 9. Migrating existing `unfolded` data — checked, nothing to migrate

Checked live against the real mirror: `AperasKG/Apeiron/BlockNode.jsonld` has 1220 `"unfolded":
false` entries and zero `true`; `ArtifactNode.jsonld` has 1, also `false`. Nothing has ever
actually set it. `unfolded` can be dropped from `BASE_NODE_SHAPE`/`BaseNode` outright — no
migration, no default-view seeding needed.

## 10. Open questions — all resolved

- **§5's breadcrumb-pruning question** — settled by §4's `3`/`3.3`/`3.3.1` case: an interior
  breadcrumb node prunes to just the relevant path, `Root` is the one exception.
- **§6's multi-`Link`-no-qualifying-home tie-break** — confirmed as a genuine, unresolvable tie
  ("luck," not a structural rule), not something needing a principled answer.
- **§8's flush cadence** — two independently-tunable intervals, implemented.
- **Default `Profile`/`TreeView` for a bare CLI call with no `--view`** — implemented as proposed:
  the literal string `"default"`. `node.ts`'s `ensureDefaultView(store)` resolves `TreeView` where
  `name === "default"` via exact-literal lookup (the same pattern `findByExactPath`, `tree.ts`,
  already uses for `ArtifactNode`/`FolderNode.path`), auto-creating it — and a `Profile` named
  `"default"` to own it — on first miss, so a caller never needs to know a generated id or run a
  one-time setup step. `--view` only ever takes a `TreeView` ref directly (there's no separate
  `--profile` flag anywhere in this design), so `Profile.name` resolution only matters for that one
  bootstrap path, not for everyday CLI use. Used by `kg:unfold`/`kg:fold` when `--view` is omitted;
  `kg:tree` deliberately does *not* fall back to it (§5) — omitting `--view` there keeps the plain
  no-view default instead.
