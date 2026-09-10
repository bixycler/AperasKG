# TreeView & Profile — Design

**Status: implemented, live-verified against a synthetic graph exercising every scenario [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>) works
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
mechanics below are new, not a restatement of that doc's [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>).

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
into the same walk as `children` buys an i-projection that a purely-structural tree could never give:
bringing mentally-related content into direct proximity without moving or duplicating anything in
the physical tree. Physical structure still wins wherever the two collide in the combined render —
[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s canonical-position rule (a node's structural home is always canonical when it qualifies) is
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
2. **i-projection** — the new intermediate tier this doc proposes. "i-" is deliberately underspecified,
   the same way the project's other core terms (Apeiron/Aperas/Peras) carry more than one reading
   at once: imagine, inner/internal, idea, intel, intermediate, index all apply to what this tier
   does — it's the graph's own internal, indexable idea of "what a viewer currently sees," sitting
   between the raw substrate and any outward-facing render. `TreeView` ([§3](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/3. Data model: `Profile` and `TreeView`]]>)) is the first, and for
   now the only, i-projection kind.
3. **UI projection** — Human UI and Agentic Interface, both consuming an i-projection rather than
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
  handle:      One, xsd:string           -- stable, addressable slug ("default", "will", "claude-agent-1");
                                          -- named `handle`, not `id` — every node already has an opaque
                                          -- intrinsic id (`ApeironInstance.id`), and this is a second,
                                          -- human-chosen identifier, not a replacement for it (§11)
  name:        Optional xsd:string       -- display/social name
  kind:        Optional xsd:string       -- open label, suggested {"human","agent"}; no auth (§7)
  preferences: Set, embed -> StringProp  -- arbitrary key/value bag, same shape as BlockNode.props (§11)

TreeView
  profile: One, reference -> Profile
  name:    One, xsd:string               -- stable, globally-unique addressable handle (§11); tightened
                                          -- from Optional once every TreeView is always created with
                                          -- one, via `kg:profile create-view` or the "default" bootstrap
  unfolds: Set, reference -> (TreeNode | Link)
```

`TreeNode` here is the existing class (`node.ts`) — `BlockNode | ArtifactNode | FolderNode` — and
`Link` is the existing embedded `{ target, predicate }` subdocument (`BaseNode.links`). **There is
no separate "view-time" node type.** A `TreeView` is a lens over the one real graph — a set of
which edges out of an already-visible node are currently revealed — not a parallel structure that
gets its own copy of nodes. Rendering walks the real `TreeNode`/`Link` graph directly, consulting a
`TreeView`'s `unfolds` membership at each hop to decide whether to keep descending. (An earlier
draft of this doc proposed a distinct view-time `TreeNode` to handle a node reached by more than
one path — unnecessary, retracted; see [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>).)

`Profile > TreeView` is one-to-many, stored as the reference living on `TreeView` (`profile`), not
a `treeViews` list on `Profile` — the reverse direction is a backlink query (`node.ts`'s existing
`backlinks(store, id, 'profile')` pattern), same as every other one-to-many relationship in this
graph already resolves (a `BlockNode`'s children are found by reverse-querying `__parent`, not
stored forward). No new mechanism needed — including for a future non-`TreeView` view kind (a
"linear view," say): the same backlink resolves it for free as long as it also stores a forward
`profile` reference ([§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>)).

## 4. Worked example

The sample graph [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)/[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s rules are checked against. Labels are shorthand for real node ids (`1.2`
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
line is one `kg:unfold <ref> --view <this>` call, each adding *only* the stated `ref`, per [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)):

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
│  ├─ 1.l1→2.2{title}  [*see 2/2.2]
│  └─ 1.l2→3.3{title,abstract}
├─ 2{title,abstract}
│  ├─ 2.1{title,abstract}
│  ├─ 2.2{title,abstract} [*]
│  │  ├─ 2.2.1{title,abstract}
│  │  ├─ 2.2.2{title,abstract}
│  │  └─ 2.2.l1→1.2{title}  [*see 1/1.2]
│  ├─ 2.l1→1.2{title,abstract}
│  └─ 2.l2→3.3{title,abstract}
└─ 3{title,abstract}                    — Root-child preview (unconditional, §5)
   └─ 3.3{title}                        — breadcrumb: 3.3 itself has no `unfolds` entry
      └─ 3.3.1{title,abstract}
         ├─ 3.3.1.1{title,abstract}
         └─ 3.3.1.2{title,abstract}
```

Reading this against [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)/[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s rules:
- `1.2` gets `[*]` at its structural home — qualifying: visible under unfolded `1`, and separately
  unfolded itself (step 2) — the *canonical* full render ([§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)).
- `2.2.l1→1.2` is a `Link`, itself unfolded (step 4), which would normally mean "show target
  fully" ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)'s rule b) — but `1.2` already has a qualifying home, so this position collapses to a
  pointer instead ([§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)).
- `1.l2→3.3` is a plain link entry, listed only because its owner `1` is unfolded ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)'s rule a) —
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

**Fold sequence**, applied to the state above ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)):

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
`unfolds`, never cached from an earlier render ([§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)). And `3` shows `{title,abstract}` in *both*
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
it lists any children at all is a separate question layered on top (see [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>) for each in context):

- **Genuinely unfolded (in `unfolds`)** — own line `{title, abstract}`; lists *both* its structural
  children and its own `links` (rule a), each recursively at whichever tier applies to it.
- **Not itself unfolded, but its immediate parent is genuinely unfolded — or it's a direct child of
  `Root`** (`Root` always counts here without needing an `unfolds` entry of its own — it's the one
  always-qualifying "parent") — own line `{title, abstract}` (preview). Lists nothing further by
  default. **Exception**: if something below it is unfolded (reachable only by descending through
  it), it additionally lists just the *one* child continuing toward that — pruning every other,
  irrelevant child. This is what makes `3` in [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s example show `{title,abstract}` plus exactly one
  child (`3.3`), never `3.1`/`3.2` and never its own link `l1→1.1`.
- **Neither of the above** — its own parent doesn't qualify either (it's itself only reached as a
  breadcrumb link in someone else's chain) — own line `{title}` only, no abstract. Same
  passthrough-only-child behavior as the tier above, minus the abstract. This is `3.3` in [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s
  example: `3`'s parent-qualification doesn't propagate down to it, since `3` itself is only at
  preview tier, not genuinely unfolded — and `3.3` in turn shows only its one relevant child
  (`3.3.1`), never `3.3.2`. That's the concrete answer to whether an interior breadcrumb node
  prunes to just the relevant path or lists everything the way `Root`'s children do: it prunes.

A `Link`'s own rendering is a separate, one-hop question, layered onto whichever `TreeNode` owns
it, governed by two named rules (only ever invoked for a `Link` whose owner is itself genuinely
unfolded — a `Link` belonging to a non-unfolded owner is never listed at all, by either rule):

- **Rule a** — the `Link` is merely *listed*, because its owner is genuinely unfolded, but the
  `Link` itself has no `unfolds` entry of its own: shows the target's `{title, abstract}` as a
  flat, one-line preview, never recursing further, regardless of where the target sits.
- **Rule b** — the `Link` itself is genuinely unfolded (has its own `unfolds` entry): shows its
  target *fully*, one level, as if the target were itself in the tier-1 case above — recursing
  into the target's own structural children and its own `links`, each at whichever tier applies.

This is computed fresh at render time from the current `unfolds` set and the graph's own structure
— nothing about it is stored, which is also what resolves the previous draft's open "should
breadcrumb auto-expansion mutate `unfolds`, permissive or strict" question: it doesn't mutate
anything either way, so there's no such choice to make. See [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>) for how a target reached two
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

Worked through against [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s example line by line, the rule turns out simpler than "whichever gets
visited first in the render walk":

**A node's structural (`parent`-chain) position is its one true home.** The home wins — is
*always* the canonical full expansion, no matter what — whenever it actually appears anywhere in
this rendered view, for *any* reason: because it's genuinely unfolded itself, because its immediate
parent is (making it a listed preview child), or merely because it sits on the breadcrumb
passthrough path down to something else genuinely unfolded beneath it ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)'s passthrough-child
exception). The home's own line doesn't need to earn a `{title,abstract}` tier to still be the
canonical position — even a bare title-only breadcrumb outranks a competing `Link`, as long as that
line is actually printed somewhere in the tree. Any `Link` elsewhere pointing at the same node —
even one that's itself in `unfolds`, which would otherwise mean "show the target fully" (rule b) —
collapses instead to a short pointer back to the home, tagged `[*see <path>]`, and doesn't recurse.
The home position itself gets tagged `[*]` — "reachable more than one way in this view," regardless
of whichever display tier its own line happens to earn. Matches `1.2`/`2.2` in [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s example
(both qualify under the narrower original reading too) *and* extends to a node reached only as a
breadcrumb (§4's `3.3`-shaped case) that also happens to be a `Link`'s target: the breadcrumb still
wins, since it's already printed there for its own, unrelated reason — a `Link` recursing fully on
top of that would just duplicate content the breadcrumb's own passthrough chain already shows
beneath it.

**Loosened from an earlier, narrower version of this rule**, which required the home to separately
have its *own* `unfolds` entry *and* a genuinely-unfolded parent — real gap, found live: a `Link`
targeting a pure breadcrumb node (neither it nor its parent genuinely unfolded) several levels above
something else that *is* genuinely unfolded. The narrower rule let the `Link` "win" there and fully
re-expand a subtree the breadcrumb's own passthrough chain was *already* rendering underneath it —
same content twice, once via each position, not the clean "one canonical, one pointer" split this
section promises. The home was always going to be printed regardless of the `Link` existing at all;
giving the `Link` a competing full expansion never added anything but a duplicate.

**If the home has no reason to appear in this render at all** — nothing beneath it is genuinely
unfolded, its own parent isn't genuinely unfolded, and it isn't itself genuinely unfolded —
whichever `Link`(s) pointing at it *are* themselves in `unfolds` get to show the target fully,
directly at their own position, since there's truly no competing position anywhere else in the
view. Exactly what happens after [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s `kg:fold 1`: `1.2`'s own entry is gone and its home (under `1`)
no longer lists anything, nor is `1.2` reachable as a breadcrumb toward anything else, so
`2.2.l1->1.2` — untouched by folding `1` — becomes the *only* position with any claim on it and
renders fully there instead of pointing anywhere.

This also makes link-following cycle-safe for free: a `Link` pointing back toward an ancestor (or
toward anything else already canonical elsewhere in this same render) hits the "already canonical
elsewhere — point back" branch before it can recurse.

**If a node has no home rendered anywhere in this view and is reached by two or more different
unfolded `Link`s at once** — both are equally "second pass" (neither is the structural home), so
there's no meaningful ordering between them to break the tie with. Whichever one the walk happens to
encounter first becomes canonical; that's purely a function of implementation-internal iteration
order, not a structural or positional rule worth defining — a real tie, not a case that needs a
principled answer.

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
`BlockNode/xyz  [heading]  Some Title  [*see /reportX/sectionY]`. No space between `*` and `see`,
and the path itself uses the real `/`-separated form (`toPath()`'s own output), never the informal
`>` shorthand this doc's own worked-example diagrams once used.

## 7. `Profile`: lightweight identity, still no auth

Confirmed scope, extended in [§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>): `Profile` started as a way to keep separate `TreeView`s from
colliding — "human" vs. "agent," or finer-grained if that turns out to matter (per-agent-session,
say). It has since grown a small amount of real, addressable identity (`handle`/`name`/`kind`) and an
open preferences bag ([§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>)), but the posture hasn't changed: no auth, no permissions, matching every
other stance this solo-local-dev tool already takes (the ApeironNgn service itself assumes one
trusted local caller). `kind` values like `"human"`/`"agent"` are a suggested starting vocabulary,
not an enforced enum — the same unenforced-label philosophy the original single `name` field
carried, now split across `name` (display) and `kind` (category).

## 8. Git separation: a `.state/` subfolder, gitignored

`TreeView` is per-viewer UI state ("what's currently expanded") — genuinely ephemeral, churning on
every expand/collapse click, with no reason to ever sit in git history. `Profile`, by contrast, is
stable: identity and preferences ([§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>)) that should survive a `git clone` and diff like any other
tracked file, even though it's still "per-viewer" in the sense that each caller owns their own
rows. The original version of this section conflated those two questions — *whose* is it, versus
*how long does it live* — because until `Profile` grew real content ([§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>)), everything "per-viewer"
also happened to be ephemeral. Splitting them apart:

- **`TreeView`** stays in `dehydrate.ts`'s `STATE_CLASSES`, written to the gitignored
  `AperasKG/Apeiron/.state/TreeView.jsonld` by `dehydrateStateToJsonLd`, on its own
  `STATE_FLUSH_INTERVAL_MS`/`stateDirty` cadence — everything else in this section describes only
  `TreeView` now.
- **`Profile`** moved to `dehydrate.ts`'s `DEHYDRATE_CLASSES`, written to
  `AperasKG/Apeiron/Profile.jsonld` alongside `BlockNode`/`ArtifactNode`/`FolderNode`, on the
  ordinary `FLUSH_INTERVAL_MS`/`dirty` cadence — tracked by default like every other content-mirror
  file. Whether a given repo actually commits it is a decision for *that repo's own* `.gitignore`,
  not something ApeironNgn's code enforces: an org mirror likely wants its members' `Profile.jsonld`
  tracked; a personal fork might ignore it on branches meant to be merged upstream while tracking it
  on personal branches. **Not** auto-staged by `AperasKG/.githooks/pre-commit`, though — that hook
  only runs (and only ever stages `BlockNode`/`ArtifactNode`/`FolderNode.jsonld`) because its one
  job is reflecting `kg:track`'s own rewrite of *those* files into the same commit as the `.md`
  change that triggered it; `kg:track`/`kg:ingest` never touch `Profile` at all, so there's nothing
  for that hook to pick up. Committing a `Profile.jsonld` change (from `kg:profile` or a direct
  edit) is a manual `git add`, same as any other hand-edited settings file — consistent with, not
  an exception to, the "settings file" framing above.

Implemented (for `TreeView`): `dehydrateToJsonLd`'s existing `${kind}.jsonld` pattern
(`dehydrate.ts`), reused for a second, separate pass — `dehydrateStateToJsonLd(store, dir =
join(getApeironExportDir(), '.state'))` — reusing the same `serializeDoc`/`allIdsOfKind`/`stableId`
helpers rather than a parallel implementation. `store.ts`'s `rehydrateStore` reads `.state/
TreeView.jsonld` as a second, tolerant pass (missing `.state/` entirely — a fresh checkout, or
before any view has ever been unfolded — is not an error, unlike a missing content-mirror file).

`AperasKG/Apeiron/` lives in the **AperasKG repo**, a sibling of this one, reached from here only
via the `AperasKG` symlink (confirmed: `git -C AperasKG rev-parse --show-toplevel` resolves to
`/home/dinhlx/source/AperasKG`) — so the gitignore entry (`Apeiron/.state/`, now covering only
`TreeView.jsonld`) belongs in *that* repo's own `.gitignore`, alongside its existing
`*.bundle`/`*.tar.gz`/`snapshots/` entries, not this repo's `web/.gitignore` (which only covers
`.run/`, this repo's own analogous local-state precedent, for a different reason — the ApeironNgn
service's lock/socket files).

The shared service isn't hypothetical — `web/src/lib/apeironNgn/service.ts` is a complete, running
implementation ([Aperas-apeironngn-design.md §4 step 5](<[[/Aperas-apeironngn-design.md/# ApeironNgn: Embedded Substrate Design/4. Rollout sequence/Step 5: shared service process — implemented, verified]]>), whose own "not started" line has been
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
`"default"`-named view ([§10](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/10. Open questions — all resolved]]>)) on `unfold`/`fold`; `kg:tree` instead keeps its plain no-view default
when `viewRef` is omitted, matching [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>).

## 9. Migrating existing `unfolded` data — checked, nothing to migrate

Checked live against the real mirror: `AperasKG/Apeiron/BlockNode.jsonld` has 1220 `"unfolded":
false` entries and zero `true`; `ArtifactNode.jsonld` has 1, also `false`. Nothing has ever
actually set it. `unfolded` can be dropped from `BASE_NODE_SHAPE`/`BaseNode` outright — no
migration, no default-view seeding needed.

## 10. Open questions — all resolved

- **[§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)'s breadcrumb-pruning question** — settled by [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s `3`/`3.3`/`3.3.1` case: an interior
  breadcrumb node prunes to just the relevant path, `Root` is the one exception.
- **[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s multi-`Link`-no-qualifying-home tie-break** — confirmed as a genuine, unresolvable tie
  ("luck," not a structural rule), not something needing a principled answer.
- **[§8](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/8. Git separation: a]]>)'s flush cadence** — two independently-tunable intervals, implemented.
- **Default `Profile`/`TreeView` for a bare CLI call with no `--view`** — implemented as proposed:
  the literal string `"default"`. `node.ts`'s `ensureDefaultView(store)` resolves `TreeView` where
  `name === "default"` via exact-literal lookup (the same pattern `findByExactPath`, `tree.ts`,
  already uses for `ArtifactNode`/`FolderNode.path`), auto-creating it — and a `Profile` with
  `handle: "default"` to own it — on first miss, so a caller never needs to know a generated id or
  run a one-time setup step. `--view` only ever takes a `TreeView` ref directly (there's no separate
  `--profile` flag anywhere in this design), so `Profile.handle` resolution only matters for that
  one bootstrap path, not for everyday CLI use. Used by `kg:unfold`/`kg:fold` when `--view` is omitted;
  `kg:tree` deliberately does *not* fall back to it ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)) — omitting `--view` there keeps the plain
  no-view default instead. See [§11](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/11. `Profile` becomes real identity — `kg:profile`]]>) for why this bootstrap doesn't make `"default"` permanently
  special beyond that one first-use moment.

## 11. `Profile` becomes real identity — `kg:profile`

**Status: designed, not yet implemented.**

`Profile` started ([§7](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/7. `Profile`: lightweight identity, still no auth]]>)) as pure internal bucketing — just enough to keep separate `TreeView`s from
colliding. Once it needs to be addressable from a CLI and hand-edited directly in its own mirror
file ([§8](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/8. Git separation: a]]>)) like a settings file, "a label with no key" stopped being enough: it needs a stable slug
distinct from whatever gets displayed, an open category, and somewhere to hang arbitrary
preferences. [§3](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/3. Data model: `Profile` and `TreeView`]]>)'s schema reflects that:

```
Profile
  handle:      One, xsd:string           -- stable, addressable slug ("default", "will", "claude-agent-1")
  name:        Optional xsd:string       -- display/social name
  kind:        Optional xsd:string       -- open label, suggested {"human","agent"}; left unset if not given
  preferences: Set, embed -> StringProp  -- arbitrary key/value bag
```

Two deliberate non-additions:
- **No stored `views` field.** A `Profile`'s owned `TreeView`s (and any future non-`TreeView` view
  kind — a "linear view," say) are still found the same way [§3](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/3. Data model: `Profile` and `TreeView`]]>) already resolves
  `Profile > TreeView`: reverse-querying `profile` (`backlinks(store, id, 'profile')`).
  Kind-agnostic for free — a future view kind needs zero extra plumbing here as long as it also
  stores a forward `profile` reference.
- **`preferences` reuses the existing `props`/`StringProp` embed shape** (`BlockNode.props`) rather
  than a new subdocument type — same encode/decode/dehydrate machinery, zero new plumbing.

**`kg:profile` — deliberately minimal**, since most of a `Profile`'s content is meant to be viewed
and edited directly in `Profile.jsonld` ([§8](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/8. Git separation: a]]>)) — the same posture as any other settings file,
matching [§7](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/7. `Profile`: lightweight identity, still no auth]]>)'s "no auth, no enforced enum" stance:

- `kg:profile create <handle> [--name <name>] [--kind <kind>]` — `kind` (like `name`) is `Optional`,
  left unset if omitted rather than defaulted to a sentinel value.
- `kg:profile list [<handle>]` — no arg: one line per `Profile` (`handle`/`name`/`kind`/owned-view
  count); given a `handle`: full detail, adding `preferences` and the owned views' own ids/names.
- `kg:profile remove <handle>` — cascade-deletes every `TreeView` it owns first (the same
  recursive-delete posture `hardDeleteNode` already takes for embedded subdocuments and tombstoned
  subtrees elsewhere in the model — a `Profile` gone with its `TreeView`s left dangling would be a
  worse state than either "keep both" or "remove both").

No rename or per-preference-key subcommand — a direct edit to `Profile.jsonld` already covers both,
and adding CLI surface for something already reachable by hand-editing the mirror would just be two
ways to do the same thing.

**View lifecycle — `kg:profile *-view`.** A `TreeView`'s own `name` plays exactly the addressable
role `Profile.handle` does: a stable, human-chosen slug, not a raw node id — so `TREE_VIEW_SHAPE`
tightens `name` from `Optional` to `One` to match, and it gets the same "set up before use"
discipline. `--view <name>` (`kg:tree`/`kg:unfold`/`kg:fold`) already refuses an unrecognized name
outright rather than silently minting one on first typo (`resolveTreeView`'s existing behavior,
unchanged) — the one exception stays `"default"`, still auto-created on first use ([§10](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/10. Open questions — all resolved]]>)).

- `kg:profile create-view <name> --profile <handle>` — mints a new, empty `TreeView` owned by the
  named `Profile` (which must already exist — no implicit profile creation here either). Rejects a
  duplicate `name`, the same uniqueness check `kg:profile create` already applies to `handle`.
- `kg:profile list-view [<name>]` — no arg: one line per `TreeView` (`name`/owning `Profile`
  `handle`/unfold count); given a `name`: full detail (its `unfolds` set).
- `kg:profile remove-view <name>` — deletes exactly that one `TreeView`, without touching its owning
  `Profile` — the single-view counterpart to `kg:profile remove <handle>`'s all-at-once cascade.

Global uniqueness, not per-profile: two different `Profile`s can never have same-named views,
matching `Profile.handle`'s own single flat namespace rather than adding a second, profile-scoped
one.

**Auto-init is not the same as hardcoded.** [§10](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/10. Open questions — all resolved]]>)'s `"default"` `Profile`/`TreeView` bootstrap
(`ensureDefaultView`) is the *only* place either one gets special-cased — a one-time
create-if-missing convenience so a fresh install works with no setup step, now creating a `Profile`
with `handle: "default"` rather than just a bare `name` (`kind` stays unset, same as any other
freshly-created `Profile` with no `--kind` given). Once that bootstrap has run once, `"default"` is
an ordinary row: listed by `kg:profile list` like any other, hand-editable
in the mirror like any other, and removable via `kg:profile remove default` (cascading to its
views) exactly like any other `handle` — nothing downstream of that one bootstrap moment ever
treats it as forever-privileged.

**Git/mirror placement**: covered in [§8](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/8. Git separation: a]]>) — `Profile` is dehydrated to the tracked content mirror
(`DEHYDRATE_CLASSES`), not `.state/`; whether it's actually committed in a given repo is that
repo's own `.gitignore` decision, not something this design enforces.

## 12. Depth legibility in plain-text tree output

**Status: implemented.**

`renderTreeLines`/`renderViewLines` (`node.ts`) indent each depth level with two literal spaces
(`'  '.repeat(depth)`) and nothing else — the only design examples with box-drawing characters
(├─/│/└─, [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s worked-example trees) are illustrative, not what the CLI actually emits.

**The problem**: recovering a line's depth from plain-space indentation requires already knowing
the per-level width (2, today) and dividing the leading-space count by it — that convention isn't
visible in the output itself, for a human or an agent reader alike. Worse, the signal is fragile:
repeated spaces are exactly the kind of thing some renderers, terminals, or copy/paste paths
normalize or collapse, which would silently corrupt the only place depth is encoded.

**Option A — full box-drawing tree art**, connecting siblings the way [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s illustrative examples
do: visually the most familiar (matches `tree`/`ls -R`-style output), but it doesn't actually fix
the problem above — depth is still `prefixWidth / perLevelWidth`, just spread across a 2-3-glyph
wide unit instead of a 2-space one, so a reader still needs the same outside knowledge of that
width. It also carries a real implementation cost: which corner glyph a line gets (├─ vs └─)
depends on whether it's the last sibling, and whether an ancestor's continuation column renders │
or blank depends on whether *that* ancestor was itself a last sibling — producing this needs a
full pass with sibling lookahead first, not the current single top-down recursive emit
(`renderTreeLines`/`renderViewLines` emit each line as they visit it, in one pass).

**Option B — a single repeated marker per level**, e.g. `'│ '.repeat(depth)` in place of
`'  '.repeat(depth)`: the marker is non-whitespace, so depth becomes "count the marker glyph before
the first non-marker character" — self-describing from the output alone, with no per-repo
indent-width convention to know in advance, and no ambiguity from whitespace-collapsing. To a human
eye it reads as a set of clean vertical guide lines — mechanically close to what box-drawing's own
│ continuation column already gives — without option A's last-sibling lookahead cost: the existing
single recursive pass is unchanged, only the literal indent string changes.

**Decided: option B**, marker `'│ '` (one `│` plus one space, 2 characters per level — the same
width as today's plain 2-space indent, just with the leading space replaced by a visible glyph).
Every indent site in `node.ts` switches uniformly: `renderTreeLines`, `renderViewLines`,
`renderLinkLine`, and the `…`-pruned-children marker (currently all `'  '.repeat(...)` at various
depths) all become `'│ '.repeat(...)`. No distinction between a continuing branch and a last
sibling — every level renders the same marker regardless of position, unlike true box-drawing art,
which needs sibling lookahead to pick between `│` and blank per level (option A's cost, avoided
here).

Applying this to [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s post-fold worked example (the tree after `kg:fold 1`/`kg:fold 3`):

```
│ 1{title,abstract}
│ 2{title,abstract}
│ │ 2.1{title,abstract}
│ │ 2.2{title,abstract}
│ │ │ 2.2.1{title,abstract}
│ │ │ 2.2.2{title,abstract}
│ │ │ 2.2.l1→1.2{title,abstract}
│ │ │ │ 1.2.1{title,abstract}
│ │ │ │ 1.2.2{title,abstract}
│ │ │ │ 1.2.l1→2.1{title,abstract}
│ │ │ │ 1.2.l2→3.1{title,abstract}
│ │ 2.l1→1.2{title,abstract}
│ │ 2.l2→3.3{title,abstract}
│ 3{title,abstract}
```

## 13. Viewcone Zoom: projecting from an arbitrary apex

**Status: implemented (`node.ts`'s `discoverCone`/`emitNode`/`emitLinkLine`/`renderTreeWithView`),
live-verified against a synthetic graph reproducing [§13.1](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/13. Viewcone Zoom: projecting from an arbitrary apex/13.1 Worked example]]>)'s worked example exactly, byte-for-byte
down to the `2.2.l1→1.2` pointer and the `2`/`3.3.1` non-appearances — not yet exercised against
the real `AperasKG/Apeiron/` corpus, which has no live wikilinks yet to actually escape a cone with.
`npm run verify`'s full suite (22/22, including its own Link/tombstone tree-rendering case) passes
unchanged.**

A **viewcone**'s boundary is purely structural: the *entire* structural subtree under an apex node
— every descendant, regardless of `unfolds` — the "cone" shape a containment tree traces out below
any one of its nodes. This is why it's called a cone, not a "viewset": it's a tree shape, defined
by `parent`-chain containment alone, the same shape [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)-[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>) already render, just not yet named or
generalized past `Root`.

**A single iteration of the 2-pass algorithm is bounded entirely by its viewcone** — [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)/[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s
existing rules apply completely unchanged *inside* one cone: a node's tier (full/preview/
title-only) still comes from whether it and its structural ancestors are in `unfolds`; a link
listed only because its owner is genuinely unfolded ([§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>) rule a) still renders as a flat preview,
never recursing, regardless of where its target sits. The one thing that's new: **a link that is
itself in `unfolds` (rule b) and whose target falls *outside* the current cone** doesn't have a
canonical position this pass can resolve on its own ([§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s canonical-home computation only knows
about nodes inside the cone it was computed for) — that's the trigger to zoom: recurse the whole
2-pass algorithm again with the target as the new apex, producing a nested viewcone. A rule-b link
whose target falls *inside* the current cone needs no recursion at all — it's projected in the very
same second pass, by the very same existing [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>) rule (pointer to the qualifying home, or full render
if no home qualifies).

This is not blind recursion — it only ever follows a link that is *actually* in `unfolds`, so it's
bounded by however deep that set's own link-chain happens to go, never by an arbitrary depth limit.

**`Root` never escapes its own cone.** `cone(Root)` is the entire graph — every node sits somewhere
under `Root` structurally, by construction — so no link, unfolded or not, can ever have a target
outside it. Zooming to `Root` therefore degenerates to exactly today's flat, already-implemented
single-pass render ([§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)-[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)): viewcone zoom is a strict generalization, introducing new behavior only
for a non-`Root` apex.

Following the *parent* chain upward for "broader context" is a real, common reading pattern
(checking a document's breadcrumb trail, not just its outbound links) but is navigation
methodology layered on top, not part of the projection algorithm above — `parent` is not folded
into `links` and needs no change to the 2-pass algorithm itself.

**Prior art: Logseq's block zoom** (Logseq ← Roam Research ← WorkFlowy's "zoom" ← outliners'
generic "hoist," at least as far back as Dave Winer's ThinkTank/MORE, 1984). Logseq's "zoom into a
block" is exactly a single, non-recursive
viewcone — the clicked block becomes the apex, its structural descendants the whole view, with no
notion of following a logical (page-)link outward as part of the same zoomed render. Logseq
approximates the "broader logical context" this design's recursion gives natively by stacking
separately-zoomed blocks as independent panes in its right sidebar — each pane its own flat,
structural-only zoom, manually opened one at a time, never unified into one render the way a
viewcone's nested cones are. This design folds both structural and logical (`Link`) escape into the
same recursive projection, computed and rendered as a single tree rather than a user-assembled
stack of separate views.

### 13.1 Worked example

Reusing [§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>)'s exact sample graph and its exact unfold sequence (`unfolds` = `{1, 1.2, 2, 2.2, 3.3.1,
Link(1.l1→2.2), Link(2.2.l1→1.2)}` — nothing hypothetical added), **zooming to apex `1`**:

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
   │  ├─ 3.3.1{.1,.2}
   │  └─ 3.3.2
   └─ l1 → 1.1
```

**Stage 1 — `zoom(1)` alone.** `cone(1)` = `1`'s entire structural subtree,
`{1.1, 1.2{1.2.1, 1.2.2}, 1.3}` — every descendant, whether or not it's unfolded. Rendered by the
unchanged [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)/[§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>) rules:

```
1{title,abstract}
├─ 1.1{title,abstract}
├─ 1.2{title,abstract} [*]
│  ├─ 1.2.1{title,abstract}
│  ├─ 1.2.2{title,abstract}
│  ├─ 1.2.l1→2.1{title,abstract}
│  └─ 1.2.l2→3.1{title,abstract}
├─ 1.3{title,abstract}
├─ 1.l1→2.2  ⇒ escapes cone(1) — pending, resolved by zoom(2.2) below
└─ 1.l2→3.3{title,abstract}   — rule a only (never itself unfolded): flat preview, never escapes
```

`1.2` gets `[*]`, a canonical home fully resolved *within* `cone(1)` — its own links `l1→2.1`/
`l2→3.1` are rule-a-only, so neither escapes. The only thing left unresolved at this stage is
`1.l1→2.2`: itself in `unfolds` (rule b), target outside `cone(1)`. **Nothing about `2.2`'s own
content — including its link `2.2.l1`** — is touched yet at this stage; `2.2` is only known here as
an escaping link's target, not yet as an apex of its own.

**Stage 2 — `zoom(2.2)`**, triggered by the escape above. `cone(2.2)` = `{2.2.1, 2.2.2}` — `2.2`'s
own children only; `2` (its structural *parent*, an ancestor not a descendant) is not part of this
cone at all, regardless of `2` being separately in `unfolds`:

```
2.2{title,abstract}
├─ 2.2.1{title,abstract}
├─ 2.2.2{title,abstract}
└─ 2.2.l1→1.2  ⇒ escapes cone(2.2) — target already canonical in cone(1)
```

This is where `2.2.l1` is touched for the first time — not at stage 1, only once `2.2` itself
becomes an apex. It escapes again, this time back to `1.2`, which already has a canonical home in
`cone(1)`.

**Combined into one tree** (nesting stage 2 at the point stage 1 escaped):

```
1{title,abstract}
├─ 1.1{title,abstract}
├─ 1.2{title,abstract} [*]
│  ├─ 1.2.1{title,abstract}
│  ├─ 1.2.2{title,abstract}
│  ├─ 1.2.l1→2.1{title,abstract}
│  └─ 1.2.l2→3.1{title,abstract}
├─ 1.3{title,abstract}
├─ 1.l1→2.2{title,abstract}
│  ├─ 2.2.1{title,abstract}
│  ├─ 2.2.2{title,abstract}
│  └─ 2.2.l1→1.2  [*see 1/1.2]       — cone(1) is a container of cone(2.2); its home wins (§13.2)
└─ 1.l2→3.3{title,abstract}
```

`2` and `3.3.1` — both genuinely in `unfolds` ([§4](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/4. Worked example]]>) steps 5 and 7) — never appear anywhere in either
stage or the combined tree: neither ever sits inside a cone this chain actually visits, nor is
either ever an escaping link's target. Their `unfolds` membership is simply never consulted, a
concrete demonstration of "bounded by which links are unfolded and where they point," not by
exhaustively walking every unfolded node in the graph.

### 13.2 Resolved: canonical-home is per-cone internally, containment-ordered across cones

Neither of the two flat alternatives originally posed — not one global map computed as if the
whole recursion were a single flat pass, and not fully independent per-cone maps with no
cross-cone awareness at all. Two different rules, depending on whether the two competing
positions sit in the same cone or not:

**Within one viewcone**, unchanged from [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>): a node's own structural position, when it qualifies
(visible, and separately in `unfolds`), is always canonical over any link *inside that same cone*
pointing at it.

**Across viewcones**, canon follows containment: when a link inside a nested (recursively-spawned)
cone escapes to a node that already has a canonical position in one of that cone's **containers**
— the cone(s) whose own escaping link led, directly or transitively, to this nested cone existing
at all — the container's position wins, and the nested link becomes a pointer back to it. In the
worked example, `cone(2.2)` exists only because `cone(1)`'s own link `1.l1` escaped to it, making
`cone(1)` a container of `cone(2.2)`. `1.2` is already canonical in `cone(1)`, so `2.2.l1→1.2`
resolves as a pointer: `2.2.l1→1.2  [*see 1/1.2]` — not a re-expansion.

**Only when two cones share no containment relation at all** (neither a container of the other —
two independent zooms, or two sibling nested cones spawned from unrelated escaping links) is it a
genuine, unprincipled tie: resolved the same way [§10](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/10. Open questions — all resolved]]>) already accepts for the flat single-apex case
— whichever gets projected first, a fact of implementation-internal order, not a structural rule.

Termination follows the same shape as before: any link from a nested cone back toward a position
already held by one of its own containers stops there rather than re-expanding. The only case left
unresolved is a tie between cones with no containment relation — already an accepted, unprincipled
case elsewhere in this design ([§10](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/10. Open questions — all resolved]]>)), not a new gap this introduces.

### 13.3 Known gap: upward-pointing links (identified, not yet fixed)

`parent` is itself an implicit upward link — every `BlockNode` already carries one, silently.
Nothing stops a wikilink from making that same edge *explicit*: a block linking to its own
container, at any distance. Two shapes this takes, the second reducing to the first.

**Case 1 — self-cycle.** A `Link`'s target is a structural ancestor of its own owner block. If that
ancestor still sits *inside* the current cone (between the query's apex and the link's own owner),
nothing special happens — it's an ordinary in-cone target, resolved like any other by
`hasStructuralPresence` and [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)'s rule. But if the target sits *above* the apex itself —
outside the current cone entirely — the escaping-link machinery spawns a nested cone for it, and
since the target is an ancestor, `cone(target)` *contains* `cone(apex)` wholesale rather than
sitting beside it, the way a genuinely independent escaping target would.

**Case 2 — a link to `D`, where `D`'s cone contains an already-active cone `C`.**
- **2.1, `C` is itself a nested (non-initial) cone** — already correct today, automatically:
  `zs.canonical` is one map shared across the whole recursion, and a container cone is always
  discovered before the nested cones it spawns ([§13.2](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/13. Viewcone Zoom: projecting from an arbitrary apex/13.2 Resolved: canonical-home is per-cone internally, containment-ordered across cones]]>)). Whatever `C`'s apex already resolved to
  wins; a link to `D` (or to anything already inside `C`) simply becomes a pointer. No fix needed.
- **2.2, `C` is the query's own initial/root cone** — this is where it breaks, and it's just case 1
  restated: the initial cone has no outer container of its own to defer to, so a link escaping to
  its ancestor `D` doesn't nest *beside* the already-discovered root cone, it nests *around* it.
  `discoverCone(D)` re-derives `neededChildren`/`unfoldedTreeIds` for everything already inside the
  root cone, double-counting `attemptCount` for all of it — and if `D` itself later becomes a
  rendered canonical position (some other link targets it and wins), its recursion walks straight
  back down through the root cone's own content and reprints it: the same duplication bug [§6](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/6. Two paths to the same node: one canonical, the rest become pointers]]>)
  just fixed, recurring one level up.

This entire gap only exists because `kg:tree`'s query apex is routinely *not* the true graph
`Root` — an `ArtifactNode` deep inside the folder tree, with real ancestors above it. Zooming to the
actual `Root` sidesteps it by construction (["`Root` never escapes its own cone"](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/13. Viewcone Zoom: projecting from an arbitrary apex]]>), above) — the gap only
surfaces once viewcone zoom is used from a non-`Root` apex, which is its entire purpose.

**Two ways to close this gap**, weighed against each other:

1. **Stop recursion at a container of the initial cone.** Before spawning a nested cone for an
   escaping target, check whether the target is an ancestor of the query's *initial* apex — one
   upward walk, equivalently `isInCone(rootApexId, targetId)`. If so, decline to recurse into it at
   all: render the link as a flat, non-recursing reference (rule a's shape, or a distinct tag making
   clear "points outside the current view") instead of a full rule-b expansion.
2. **Find the maximal cone first, re-root the whole projection there.** Detect every upward escape
   reachable from the initial apex — potentially transitively, since an ancestor's own link could
   point even further up — compute the highest such ancestor, and run the entire 2-pass algorithm
   from that bigger apex instead of the one actually requested.

**Chosen: option 1.** Option 2 is structurally "more correct" in isolation — it turns every case
into an ordinary downward containment relationship, eliminating the inverted container/nested
mismatch entirely — but it silently changes what the query is even about: `kg:tree
Aperas-apeironngn-design.md` would stop being scoped to that document the moment some deep paragraph
happens to link back to its own containing folder, promoting an apex the user never asked for and
pulling [§5](<[[/Aperas-treeview-design.md/# TreeView & Profile — Design/5. Rendering: three display tiers; `kg:unfold` touches exactly one ref]]>)'s Root-child unconditional-preview rule over siblings and unrelated branches under it.
It also isn't actually cheaper — finding "maximal" needs its own pre-pass walking upward escapes to
a fixed point before the real projection can even start, just a differently-shaped cost than
option 1's. `kg:tree`'s contract is "show me the tree from *this* apex, nothing above it"; option 1
preserves that contract exactly, degrading an upward-pointing link to a flat reference rather than
promoting the whole view outward to accommodate it.

**Status: direction chosen (option 1), not yet implemented.** Still needs the exact detection
(likely generalizing past just the *initial* apex to any cone already active in the current
discovery chain, not only the root) and the exact rendering shape for a link that declines to
recurse this way.

## 14. Known gap: stale `TreeView.unfolds` references (identified, not yet fixed)

`TreeView.unfold(ref)` (`apeironNgn/node.ts:1064-1067`) appends `ref` to `unfolds` with no existence
check at all. The only cleanup that exists, `removeDanglingUnfolds` (`apeironNgn/node.ts:240-258`),
is purely reactive: it fires exclusively from inside `hardDeleteNode`, at the exact moment that
specific id is hard-deleted, and strips only that one id from every `unfolds` list. Nothing else
ever revisits an *existing* `unfolds` entry — there is no independent sweep that re-validates the
whole list against what's currently live. Mark-and-sweep GC (`pruneUnreachableTombstones`,
`apeironNgn/node.ts:1677-1707`) never treats `unfolds` as a reachability root either (correctly — a
view shouldn't keep content alive), so a node reachable only via some view's fold-state is pruned
like any other unreachable tombstone, and `removeDanglingUnfolds` only cleans that up if the
`unfolds` entry already existed *at the moment of that specific deletion*.

The realistic failure mode is the ordering these two facts leave open: a node gets unfolded while it
is genuinely live, and is only removed *afterward*, through whatever content-side path that removal
actually takes — reconciliation replacing a block with a new id on edit, an artifact-level removal,
GC's own tombstone sweep running at a different time than expected. None of those paths are
obligated to know that some view still names the id they're removing. Confirmed live, not
hypothetical: `.state/TreeView.jsonld`'s `default` view currently names 10 `BlockNode` ids with no
corresponding document at all — caught by `rehydrateStore()`'s own dangling-reference detector
(`apeironNgn/store.ts`, its second pass over every RDF triple's object position) — after unrelated,
heavy reconciliation churn elsewhere in the corpus reassigned/removed the blocks those ids used to
name.

**Two ways to close this gap**, not mutually exclusive:

1. **Write-time validation.** `TreeView.unfold(ref)` refuses (or silently no-ops) when `ref` doesn't
   resolve to a live node at the moment of the call. Cheap, but doesn't address the failure mode
   actually observed: the id was perfectly valid when unfolded, and went stale afterward through a
   completely unrelated edit — this check never runs again once the entry is already in place.
2. **An audit/prune sweep.** Walk every `TreeView`'s own `unfolds` list — on some cadence, or on
   demand via a command — and strip any entry that no longer resolves to a live node. This is the
   piece that actually closes the gap, and it's the same shape of fix `retryDanglingRefs`
   (`apeironNgn/artifacts.ts`; see AperasKG/artifacts/history/linking.md's Milestones and
   AperasKG/artifacts/discussion/linking.md's "Cross-artifact link staleness") just built for a
   different kind of derived pointer state (a dangling link code, there, instead of a dangling
   `unfolds` entry, here): something that points at another node's existence needs to be revisited
   when that existence changes, and nothing does that automatically without a dedicated sweep.

**Status: identified, not yet implemented; option 2 is the one that actually closes the gap** (option
1 is a cheap complementary safety check worth adding alongside it, not a substitute). The 10 already-
stale ids in the live `.state/TreeView.jsonld` need a one-time manual cleanup regardless of when (or
whether) the general sweep gets built.
