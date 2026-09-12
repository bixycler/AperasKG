# TreeView — Design <a name='id/BlockNode:00CE1GW4Y8001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CE1GW4Y8002' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CE1GW4Y8004' class='aperas-anchor aperas-id'></a> [Inventory and split rationale](../discussion/treeview.md#id/BlockNode:00CE1DDF58005) — how `Aperas-treeview-design.md` was divided across concerns.
- **Issues**: <a name='id/BlockNode:00CE1GW4Y8005' class='aperas-anchor aperas-id'></a> [Open Issues](../issues/treeview.md#id/BlockNode:00CE1GW638002) — stale `unfolds` tracking, bare-`unfold` mutation, no raw node inspection, plus two ingest/parser gaps.
- **Planning**: <a name='id/BlockNode:00CE1GW4Y8006' class='aperas-anchor aperas-id'></a> [Task Breakdown](../planning/treeview.md#id/BlockNode:00CE1GW7CG003) — the fixes for the above.
- **History**: <a name='id/BlockNode:00CE1GW4Y8007' class='aperas-anchor aperas-id'></a> [Current Status](../history/treeview.md#id/BlockNode:00CE1GW8T8002) — what's implemented and verified.

## Architecture <a name='id/BlockNode:00CE1GW4Y8008' class='aperas-anchor aperas-id'></a>

Structural `children` and `links` are two independent structures over the same graph: `children` is the physical, authored, positional containment tree, the same for every viewer; `links` are the mental structure — nodes related enough right now to think about together, regardless of physical distance. Folding `links` into the same walk as `children` lets a view bring mentally-related content into direct proximity without moving or duplicating anything in the physical tree — but physical structure always wins wherever the two collide (the canonical-position rule, below). That `links` walk is only as good as what actually resolved into a `Link` in the first place — [linking's own resolution mechanism](../design/linking.md#id/BlockNode:00CDBYV4T8002) is what TreeView's fold is built on top of, not something this concern re-implements.

Three tiers of perata, not one: <a name='id/BlockNode:00CE1GW4Y8009' class='aperas-anchor aperas-id'></a> **artifact projection** (the existing always-fully-unfolded `.md` sync — `BlockNode.children` stays the source of truth for document structure, ignoring fold state entirely); **i-projection** — `TreeView`, the graph's own internal, indexable idea of "what a viewer currently sees," sitting between the raw substrate and any outward render; **UI projection** — a Human UI or Agentic Interface consuming an i-projection, rather than reading a raw fold-state flag off the graph directly.

This replaces a single shared `BaseNode.unfolded` boolean, written by whoever last called `unfold`/`fold` — a human expanding a subtree and an agent doing its own traversal were the same writer as far as the graph was concerned, with no "expanded for me" versus "expanded in the underlying data."

## Data Model <a name='id/BlockNode:00CE1GW4Y800B' class='aperas-anchor aperas-id'></a>

Two top-level classes, un-suffixed (`Profile`/`TreeView`, not `ProfileNode`/`TreeViewNode`) since neither is a `TreeNode` subclass — no title/text/tree position of its own, matching `Link`/`StringProp`'s naming, not `BlockNode`/`ArtifactNode`/`FolderNode`'s:

```
Profile
  handle:      One, xsd:string           -- stable, addressable slug ("default", "will", "claude-agent-1")
  name:        Optional xsd:string       -- display/social name
  kind:        Optional xsd:string       -- open label, suggested {"human","agent"}; no enforced enum, no auth
  preferences: Set, embed -> StringProp  -- arbitrary key/value bag, same shape as BlockNode.props

TreeView
  profile: One, reference -> Profile
  name:    One, xsd:string               -- stable, globally-unique addressable handle
  unfolds: Set, reference -> (TreeNode | Link)
```

A `TreeView` is a lens over the one real graph, not a parallel structure with its own copy of nodes — rendering walks the real `TreeNode`/`Link` graph directly, consulting a `TreeView`'s `unfolds` membership at each hop. `Profile > TreeView` is one-to-many via a backlink query on `TreeView.profile` (the same pattern every other one-to-many relationship in this graph resolves), not a stored `views` list on `Profile` — kind-agnostic for free, since a future non-`TreeView` view kind needs zero extra plumbing as long as it also stores a forward `profile` reference.

Global uniqueness on `TreeView.name`, not per-profile: <a name='id/BlockNode:00CE1GW4Y800E' class='aperas-anchor aperas-id'></a> two different `Profile`s can never share a view name.

`Profile` has no auth or permissions, matching this solo-local-dev tool's stance everywhere else (the ApeironNgn service assumes one trusted local caller).

## Rendering <a name='id/BlockNode:00CE1GW4Y800G' class='aperas-anchor aperas-id'></a>

`--view <ref>` on `aperas tree` drives unfolded-mode rendering keyed off that view's `unfolds` set; omitting it keeps the plain default (title-only, no expand/collapse simulation). `aperas unfold <ref> --view <ref>` adds *only* the one specified ref (a `TreeNode` xor a `Link`) to the view's `unfolds` set — never every child/link too.

A `TreeNode`'s own-line detail has three tiers: <a name='id/BlockNode:00CE1GW4YG000' class='aperas-anchor aperas-id'></a>

- **Genuinely unfolded** (in `unfolds`) — `{title, abstract}`, listing both structural children and its own links, each recursively at whichever tier applies.
- **Not itself unfolded, but its immediate parent is — or it's a direct child of `Root`** (which always counts, without needing its own `unfolds` entry) — `{title, abstract}` preview, listing nothing further by default, *except*: if something below it is unfolded, it additionally lists just the one child continuing toward that, pruning every other child.
- **Neither of the above** (reached only as a breadcrumb in someone else's chain) — `{title}` only, same passthrough-only-child behavior, minus the abstract.

A `Link`'s rendering is layered on top of whichever tier its owner earns, and only ever applies when the owner is genuinely unfolded: **rule a** — the link is merely listed (owner unfolded, link itself not) — shows the target's `{title, abstract}` as a flat preview, never recursing. **Rule b** — the link itself is genuinely unfolded — shows its target fully, one level, recursing into the target's own children and links at whichever tier applies. Nothing here is stored — it's computed fresh at render time from the current `unfolds` set and the graph's structure.

`aperas fold <ref> --view <ref>` removes `<ref>`'s own `unfolds` entry, cascading to anything reached *from* `<ref>` (structural children, then its own links) that also has an explicit entry — a `Link` reaching into the folded subtree from somewhere else, unrelated, is untouched.

**Canonical position for a node reachable more than one way**: <a name='id/BlockNode:00CE1GW4YG006' class='aperas-anchor aperas-id'></a> a node's structural (`parent`-chain) position is its one true home, and wins — is always the canonical full expansion — whenever it appears anywhere in the rendered view for *any* reason (genuinely unfolded itself, its parent is, or it's merely a breadcrumb on the path to something unfolded beneath it), even at bare title-only tier. Any `Link` elsewhere pointing at the same node — even one itself in `unfolds` — collapses instead to a pointer back to the home, tagged `[*see <path>]`; the home itself is tagged `[*]`. Only if the home has no reason to appear anywhere in the render at all does a `Link` pointing at it get to render the target fully, directly at its own position — there being no competing position anywhere else in the view. If two or more links reach a homeless node with no ordering between them, it's a genuine, unprincipled tie (whichever the walk visits first), not a case needing a structural answer. This also makes link-following cycle-safe for free: a link back toward an ancestor (or anything else already canonical elsewhere) hits the "already canonical — point back" branch before it can recurse.

Depth in plain-text `aperas tree` output is marked with a repeated, non-whitespace glyph per level (`'│ '.repeat(depth)`, one `│` plus one space) rather than plain spaces — self-describing (count the marker before the first non-marker character) and immune to whitespace-collapsing, at the same 2-character-per-level width as the plain-space indent it replaces. No box-drawing corner glyphs (├─/└─) — every level renders the same marker regardless of sibling position.

## Viewcone Zoom <a name='id/BlockNode:00CE1GW4YG008' class='aperas-anchor aperas-id'></a>

A **viewcone** is purely structural: the entire structural subtree under an apex node, every descendant regardless of `unfolds` — the "cone" shape a containment tree traces out below any one of its nodes. `cone(Root)` is the whole graph, by construction, so zooming to `Root` degenerates to the ordinary flat render above — viewcone zoom is a strict generalization for a non-`Root` apex.

Inside one viewcone, the rendering/canonical-position rules above apply completely unchanged. The one new case: a link that is itself in `unfolds` (rule b) whose target falls *outside* the current cone triggers a **zoom** — the whole 2-pass render recurses again with the target as a new apex, producing a nested cone. A rule-b link whose target falls *inside* the current cone needs no recursion — it resolves via the same canonical-position rule as any in-cone case.

Canonical position across cones follows **containment**: <a name='id/BlockNode:00CE1GW4YG00A' class='aperas-anchor aperas-id'></a> within one cone, a node's own structural position wins over any link inside that same cone pointing at it (unchanged). Across cones, when a link inside a nested cone escapes to a node that already has a canonical position in one of that cone's *containers* (the cone(s) whose own escaping link led to this nested cone existing at all), the container's position wins, and the nested link becomes a pointer back to it. Only when two cones share no containment relation at all (two independent zooms, or two sibling nested cones) is it a genuine, unprincipled tie — resolved the same way as the flat single-apex tie-break above.

A link pointing back up toward an ancestor of the current apex — an upward-pointing link — is handled by declining to recurse into it: before spawning a nested cone for an escaping target, a check walks the currently-active cone chain (every cone already open in this discovery, not only the root apex) to see whether the target is an ancestor of any of them; if so, the link renders as a flat, non-recursing reference instead of a full expansion. This keeps `aperas tree <apex>`'s contract exact — "show me the tree from *this* apex, nothing above it" — rather than silently promoting the view outward to accommodate a link the caller never asked to follow.

## Persistence <a name='id/BlockNode:00CE1GW4YG00C' class='aperas-anchor aperas-id'></a>

`TreeView` is per-viewer UI state — genuinely ephemeral, churning on every expand/collapse — written to a gitignored `AperasKG/Apeiron/.state/TreeView.jsonld` on its own, independently-tunable flush interval, separate from the ordinary content-mirror cadence. `Profile` is stable identity and preferences that should survive a `git clone` and diff like any other tracked file (even though it's still "per-viewer" in the sense that each caller owns their own rows) — dehydrated to the ordinary tracked mirror (`Profile.jsonld`) alongside `BlockNode`/`ArtifactNode`/`FolderNode`, on the ordinary flush cadence. Whether a given repo actually commits `Profile.jsonld` is that repo's own `.gitignore` decision, not something the code enforces. Neither file is auto-staged by the `pre-commit` hook, which only reflects `aperas track`'s own rewrite of the three content-mirror files into the same commit as the `.md` change that triggered it — a `Profile.jsonld` change (from `aperas profile` or a direct edit) is a manual `git add`, like any other hand-edited settings file.

## Bootstrap <a name='id/BlockNode:00CE1GW4YG00D' class='aperas-anchor aperas-id'></a>

A bare CLI call with no `--view` resolves to a `TreeView` named `"default"`, auto-created (along with a `Profile` with `handle: "default"` to own it) on first miss, so a fresh install works with no setup step. This is the *only* place either class is special-cased — once bootstrapped, `"default"` is an ordinary row: listed, hand-editable, and removable exactly like any other. `aperas tree` deliberately does *not* fall back to it — omitting `--view` there keeps the plain no-view default instead; only `aperas unfold`/`aperas fold` use the bootstrap when `--view` is supplied with no name following it. (See [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638005) for a bare `aperas unfold <ref>` with *no* `--view` flag at all, which currently also falls into this bootstrap path — a known misdesign, not yet fixed.)
