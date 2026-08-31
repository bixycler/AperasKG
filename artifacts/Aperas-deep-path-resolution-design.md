# Deep Path Resolution & `kg:resolve` — Design

**Status**: both directions are **implemented and live-verified** — `kg:path` (id→path, §8) and
`kg:resolve` (path→id, §1-7, including `--base`, `--create-holder`, and the `kg:tree`/`kg:search`
backport in §7.5) — via `nodeRef.ts`'s `resolveNodeRefDetail`/`resolveNodeRefOrNull`.

## 0. What this is

Path resolution is fundamentally one operation: converting a relative, human-typed path into an
absolute node code (a full `BlockNode/ArtifactNode/FolderNode` id) — the "query-based addressing"
tier `nodeRef.ts` already provides (`Aperas-basic-assertion-skill-design.md` §2). Today that
conversion stops at the file/folder boundary: `getArtifactRecord`/`getFolderRecord` resolve a
path to an `ArtifactNode`/`FolderNode`, and nothing carries a path further into that artifact's
own block tree. This extends the same conversion one more tier — `folder/file.md/heading/title`
— and gives it a command of its own, since nothing currently exposes resolution directly; every
existing caller only ever sees it as a side effect of some other command (`kg:assert`, `kg:tree`,
...).

## 1. Command

```
kg:resolve [--base <path>] <path> [<path>...]
kg:resolve [--base <path>] --create-holder <path> --titles <title> [<title>...]
```

The first form resolves each `<path>` through every tier (`Aperas-basic-assertion-skill-design.md`
§2, extended by §3-4 below) and prints one line per input, in order — id, kind, and title, same
one-line shape `kg:tree --depth 0` already uses. Exits non-zero with a clear reason on a miss
(unresolvable prefix, or an ambiguous segment — §4).

Multiple `<path>` arguments are accepted specifically so `--base` (§2.1) pulls its weight:
resolving many paths against the same base in one call, rather than re-resolving the base from
scratch — and re-typing it — for each one.

The second form is `--create-holder` (§7): single-path only, and shaped differently on purpose —
see §7.1 for why it needs its own `--titles` list rather than reusing `<path>`'s own segments.

## 2. Path grammar

`/`-separated segments, Linux-flavored:

- **Leading `/`** → absolute: anchored at the tracked artifacts root, ignoring any `--base`
  (§2.1) in effect. This is also what every path meant before `--base` existed — the only
  grammar there was, so nothing about existing (bare, no-`--base`) callers changes.
- **No leading `/`** → relative to the base in effect: `--base <path>` if given, the implicit
  base (§2.1) for callers that have one (wikilink extraction), or the artifacts root by default —
  which is exactly today's behavior, so a bare path with no `--base` in play resolves exactly as
  it always has.
- **`.`** → the base itself. Mostly useful as `kg:resolve --base <path> .` to print what a base
  resolved to.
- **`..`** → the base's own parent, one level up (§2.1's walk mechanics) — chainable (`../..`)
  like any real filesystem.

No `#`-anchor syntax, no special marker splitting "file part" from "block part" beyond the above:
per the unbounded-tree principle (`Aperas-core-ontology-design.md` §4), there's no structural
boundary between a folder segment, a file segment, and a heading segment to mark differently in
the first place — `/`, `.`, and `..` are the only reserved tokens, and each means the same thing
at every tier. (A `BlockNode` genuinely titled `.` or `..` becomes unaddressable by title at that
position — the same trade a real filesystem already makes.)

### 2.1 `--base` and walking `..`

`--base <path>` resolves first, through the full algorithm (§3-4), then each subsequent `<path>`
argument is resolved relative to that node. `..` moves up one level from wherever the walk
currently stands:

- Within a `BlockNode` tree, `..` reads `.parent` (§8's field) — the same hop `resolveIdToPath`
  already walks, just in reverse.
- At the artifact/folder tier, `BlockNode.parent` doesn't apply — `ArtifactNode`/`FolderNode`
  carry no `.parent` field, only a stored `path` string (§3). `..` there trims the last
  `/`-segment off that string and re-resolves it via `getFolderRecord` — a property of the path,
  not a field on the node, same as an ordinary filesystem.
- `..` past the artifacts root is a miss ("already at root"), not a silent no-op.

The base supplies the "which artifact, which subtree" that every relative path would otherwise
have to repeat: rather than typing `sub/file.md/Heading/Sub A` and `sub/file.md/Heading/Sub B` in
full, `kg:resolve --base sub/file.md/Heading "Sub A" "Sub B"` says the shared prefix once.

Callers that don't go through the CLI at all — wikilink extraction, primarily (`astParser.ts`'s
`resolveBlockLinks`) — get an *implicit* base: the path of the block containing the
`[[wikilink]]` text, not the path of that block's owning artifact. A `[[wikilink]]` is written
from a specific place in the tree, and the most-likely-intended target is judged relative to that
place — the same way a relative filesystem path is judged relative to the file that contains it,
not to some project root; `[[../Sibling Section]]` written inside one heading's subtree to reach
a sibling heading is exactly the case this exists for. Getting "the containing block's own path"
is itself `resolveIdToPath` (§8) — so the wikilink extractor ends up a consumer of both
directions of this design, not just the forward one.

## 3. Segmentation algorithm

The stored `path` field on `ArtifactNode`/`FolderNode` is one exact-match string
(`artifacts.ts:235`, `folders.ts:141` — `query: { path: ... }`), not resolved segment-by-segment,
so a multi-segment input like `sub/file.md/Some Heading` can't be split up front — `sub/file.md`
is itself one atomic stored path. Resolve by longest-prefix search instead:

1. Split the input on `/` into segments `[s0, s1, ..., sN]`.
2. Try progressively shorter prefixes, longest first: `s0/../sN`, then `s0/../s(N-1)`, ... down to
   `s0` alone. For each candidate prefix, try `getArtifactRecord` then `getFolderRecord` (same
   try-both-they-never-collide order every other caller already uses).
3. The first prefix that resolves is the base node; every segment *after* it is a slug segment to
   descend through the base node's block tree, one `BlockNode` child per segment (§4).
4. No prefix resolves at all → the existing "not a tracked artifact or folder path" miss.

This is a pure extension: an input with no trailing slug segments behaves exactly as today
(longest-prefix search immediately finds the whole thing, zero slug segments to descend).

**Confirmed live**: the synthetic `"Document Root"` wrapper every artifact's tree starts with
(astParser.ts's `convertAstNode`, `type: 'root'`) is a real, addressable segment here, not skipped
— an `ArtifactNode`'s one descendable child (§4) is that wrapper, not the real first heading
underneath it. This matches `resolveIdToPath` (§8), which already walks through it as an ordinary
hop, so a full path from `kg:path` and one typed into `kg:resolve` round-trip consistently — e.g.
`file.md/document-root/-my-heading`, not `file.md/-my-heading`. A `FolderNode` has no such
wrapper (its children — README content and nested folders/artifacts alike — sit directly in its
own `children` list), so this only ever applies one hop deep, right after an `ArtifactNode`.

## 4. Descending slug segments

For each remaining segment, filter the current node's direct `children` to `BlockNode`s whose
`title`, slugified (§5), matches the segment slugified (§5 applied to both sides, so a caller can
type either raw heading text or an already-slugified form and it matches either way). Matching is
two-tier, exact before prefix — the same precedence a short git hash resolves under (a full hash
that happens to also be a prefix of some other object's hash still just names the object it
exactly matches):

1. **Exact**: candidates whose slugified title equals the segment exactly. Exactly one → descend,
   done — a longer sibling that happens to start with the same text never interferes.
2. **Prefix**, tried only if step 1 found none: candidates whose slugified title *starts with* the
   segment. Lets a caller type `setup` for a child titled `Setup Guide` without knowing the rest,
   the same convenience `git show a1b2c3` gets from a hash prefix — as long as it's the *only*
   sibling starting that way.

At either tier:

- **Zero matches** → miss, same as an unresolvable prefix.
- **Exactly one match** → descend, continue to the next segment.
- **More than one match** → decline rather than guess (the same principle `reconcile.ts`'s
  matching already follows for ambiguous content) — fail with an error naming the id and title of
  every sibling that matched, rather than silently picking one. Two siblings with identical titles
  fail at step 1 without ever falling through to step 2 — prefix matching resolves an
  *abbreviation*, it never papers over a genuine duplicate.

This matches on *any* `BlockNode.title` uniformly, not just headings — a non-heading block titled
via `kg:title` is addressable by that title the same way a heading is, consistent with this
project's repeated "don't special-case by node kind without a real reason" rule
(`Aperas-core-ontology-design.md` §4's pitfall note; `Aperas-interactive-summarization-design.md`
§5).

**Real bug found live during implementation**: a heading's stored `title` keeps its raw `#`/`##`
marker (astParser.ts's convention), which §5's blanket slugify rule turns into *leading dashes* —
harmless for exact matching (both sides get the same treatment) but fatal for prefix matching as
first implemented: `## Setup Guide` slugifies to `---setup-guide`, so typing `setup` (a caller has
no reason to know or type the heading's own depth) never matched via plain `startsWith`, making
the whole prefix tier dead on arrival for the dominant addressable-content case. Fixed by stripping
leading dashes off the *candidate* before the `startsWith` check, prefix tier only — exact matching
is untouched.

**Reserved tokens apply per-segment, not just to a whole `--base`**: before either tier, a segment
that is exactly `.` or `..` is never looked up as a title at all — it's the structural move §2.1
already defines (stay, or go to `.parent`), wherever it appears in the path, not only when typed
alone or as `--base`. `Heading A/../Heading B` mid-path works the same way `../` does at the very
front. A real `BlockNode` titled `.` or `..` is simply unreachable via that segment position (§2's
footnote) — one more instance of the trade a real filesystem already makes.

## 5. Slugify

```
slugify(text) = text.toLowerCase().replace(/[^a-z0-9]/g, '-')
```

One rule, deliberately not collapsing runs or trimming edges: every individual non-alphanumeric
character becomes its own `-`, preserving exact length/position rather than folding different
inputs toward the same output — maximal distinction over cosmetic prettiness. No special-casing
for a heading's leading `#`/`##` marker either; under this blanket rule it's just another
character that becomes a `-` like any other, no AST-awareness needed. Applied to both the
candidate `BlockNode.title` and the query segment before comparing, so a `kg:title`-set title
with no markdown syntax at all and a raw heading title match on equal footing — e.g. a raw
heading title (`"# Interactive Title & Cross-Link Authoring — Design"`) slugifies to
`-interactive-title---cross-link-authoring---design`, hyphen-for-character, no cleanup.

## 6. Where this plugs in

**The shared primitive**: `nodeRef.ts`'s `resolveNodeRefOrNull(client, path)` gains an options
parameter — `resolveNodeRefOrNull(client, path, opts?: { base?: string; createHolder?: boolean;
titles?: string[] })` — carrying §2's grammar (`/`, `.`, `..`), §3's longest-prefix search, §4's
exact-then-prefix descent, and §7's holder creation, all in one place, added to the function's
existing tier-3 path fallback.

Every command that already resolves a `<path>` argument through the plain form —
`kg:assert`/`kg:assertions`/`kg:unassert`, `kg:tree`, `kg:unfold`/`kg:fold`, `kg:title`, `kg:link`
— gains deep addressing (§3-4) for free, with no `opts` of their own to supply; none of them need
`--base` or `--create-holder`, so `opts` simply stays empty for those calls.

**`kg:resolve`** is the new command that exposes this directly, for inspection or scripting,
rather than only as a side effect of some other operation — the CLI-level home for `--base` and
`--create-holder` (§1), which are nothing more than `opts.base`/`opts.createHolder`/`opts.titles`
parsed off `process.argv`.

**The wikilink extractor** (`astParser.ts`'s `resolveBlockLinks`) calls `resolveNodeRefOrNull`
directly, bypassing the CLI entirely — it already has everything `opts` needs without prompting
anyone: `opts.base` from the containing block's own path (via `resolveIdToPath`, §8),
`opts.createHolder: true` unconditionally (§7.3), and `opts.titles` from splitting the wikilink's
raw text on `/` (§7.1) — one source feeding both the matching path and the holder titles.

**Not touched**: `kg:project` (`kgCli.ts:233-242`) calls `getArtifactRecord`/`getFolderRecord`
directly rather than through `resolveNodeRefOrNull`, because it needs the record itself (to know
the on-disk target file path to write), not just a resolved id. No change needed there — it never
addresses into the block tree, only ever the artifact/folder itself.

## 7. Holder nodes — resolving a miss into a placeholder, not just an error

§4's "decline rather than guess" covers *ambiguity*. A miss is different: the path is
unambiguous, there's just nothing there yet. Declining is still the right default — most callers
(`kg:assert`, a human typing `kg:resolve` at a prompt) want a clear error, not a surprise node
appearing in the tree. But two real callers want the opposite: a way to *mark* the still-missing
target so something later can find and fill it in, rather than losing the reference entirely.

### 7.1 What gets created, and why `--titles` is separate from `<path>`

`--create-holder` creates one node per unresolved segment, continuing to descend into each
newly-created one for whatever remains — `mkdir -p`, not just the last component. Segments that
already resolve are left untouched; only the miss point onward gets created, `holder: true` set
on each. Every holder `BlockNode` created this way is `type: 'heading'` — not a default among
several possible shapes, the only one supported; see §7.4 for why, and for the one thing it rules
out.

`<path>` is still what does the *matching* (§4, prefix included) — but §4's prefix matching means
a segment on the way down may be a deliberate abbreviation (`setup` addressing `Setup Guide`), and
using that abbreviation verbatim as a new node's permanent title would be wrong: a holder is new,
real, lasting content, not a lookup key. So `--create-holder` requires a parallel `--titles` list —
but aligned from the *tail*, not the head, and scoped to only the segments that can even use one.

**Which segments need a title at all**: only the heading-tier ones (§4's slug-descent). The
artifact/folder tier (§3) never does — `ArtifactNode`/`FolderNode.title` isn't a matching key or
an authored value anywhere in this codebase, it's a pure derivation from the path segment itself
(`trackArtifact`, `artifacts.ts:127`: `title: basename(artifactPath)`; the folder-tracking
equivalent, `folders.ts:44`: `relPath.split('/').pop()!` — both recomputed unconditionally on
every track/rebuild; the real match key is `path`, looked up exactly). A holder `ArtifactNode`/
`FolderNode` gets that same derived title immediately, the moment it's created, with nothing to
supply — and when the real file is eventually tracked, `basename` overwrites it again regardless,
so there was never anything worth preserving there to begin with. `.`/`..` tokens (§2) don't need
one either — they never look anything up.

**Alignment, tail-first**: `--titles` lines up against the heading-tier segment sequence `S`
(§4's segments only — base's own trailing heading segments too, if `--base` reaches that far,
§7.2) from the *end*: the last title pairs with the deepest segment, the second-to-last with the
next one up, and so on, for as many titles as given. Segments shallower than the shortest prefix
`--titles` reaches are assumed to already exist — the caller only supplies titles for as deep as
it actually expects to be creating, not one for every segment regardless of need. Resolution still
tries the normal match (§4) at *every* segment first, title-covered or not: a title-covered
segment that turns out to already exist just leaves that title unused, same as before; an
uncovered (shallower) segment that unexpectedly misses is a plain error — "would need to be
created, no title available for it" — the same "decline rather than guess" answer as any other
miss, `--create-holder` or not. `--titles` longer than `S` is a usage error up front (extra titles
with nothing left to pair against); shorter is fine by construction — that's the whole point.

Both callers this exists for already have the full titles on hand for free, so this isn't the
ceremony it looks like at the call site:

- **The wikilink extractor** already has the wikilink's raw, unslugified text — splitting it on
  `/` gives both `<path>` (via §5's slugify, for matching) and `--titles` (that same split, used
  as-is) from one source, no separate authoring step.
- **A "vision drawer"** (§7.3) is, by definition, working from real intended titles — that's the
  content it's sketching, not an afterthought.

A direct human `kg:resolve --create-holder` call still has to type both `<path>` and `--titles`,
but tail-alignment keeps it to just the segments actually being created — no need to restate
titles for a path prefix that already resolves.

**Real bug found live**: `ArtifactNode`'s one "child" is its singular `root` field, not a
`children` List — the first implementation always wrote `children: [...]` regardless of the
current node's kind, which is fine for `BlockNode`/`FolderNode` but fails schema check
(`unknown_property_for_type`) the moment a miss needs a holder created directly under an
`ArtifactNode` (reachable via `..` popping up past a block tree into its owning artifact — §2.1).
Fixed by branching on kind: an `ArtifactNode` with no `root` yet gets the holder set as `root`
directly; one that already has a `root` declines instead (there's no structural slot for a second,
sibling root — a real edit adds *inside* the existing root, not beside it).

**Output**: one line per segment, not just the final id — §1's plain form only ever prints the
end result because nothing changed along the way, but `--create-holder` can touch several levels
at once, and which ones were already there versus newly imagined is exactly what a caller needs to
see. Each line carries the same `<id>  [<kind>]  <title>` shape as everywhere else, tagged
`(existing)` or `(created holder)`.

### 7.2 How far "imagined" reaches: the whole tree, not just blocks

Holder creation isn't bounded to the `BlockNode` tier. If §3's longest-prefix search fails
outright — no tracked `ArtifactNode`/`FolderNode` matches any prefix at all — `--create-holder`
extends the same `mkdir -p` logic up through that tier too: a whole path, folders and file and
headings alike, can be sketched into existence with nothing on disk yet. This is what lets a
"vision drawer" (§7.3) actually draw a *tree*, not just fill gaps inside artifacts that already
exist.

Disambiguating which imagined segments are `FolderNode`s versus the one `ArtifactNode` versus
`BlockNode`s beneath it reuses the convention every real path in this project already follows: the
segment carrying this project's file extension (`.md`) is the `ArtifactNode`; segments before it
are `FolderNode`s; segments after it are `BlockNode`s. No new marker syntax — one already exists
in every path anyone types here.

A holder `ArtifactNode` has no real file on disk and no content hash; it's a placeholder for a
file that will eventually be written and tracked (`kg:track`+`kg:ingest`) the normal way. Because
`FolderNode`/`ArtifactNode` need the same `holder` marker `BlockNode` does, it belongs on
`BaseNode` rather than repeated per concrete kind — the same "don't special-case by node kind"
default §4 already follows for title-addressing.

`--base` composes with `--create-holder` the same way as any other segment: if the base path
itself doesn't resolve, it's imagined too, root included — being "the base" doesn't make it any
less eligible than a segment reached by descending into it. No separate title list for it either:
§7.1's tail-aligned `S` is base's own heading-tier segments followed by `<path>`'s, one combined
sequence in resolution order — `--titles` aligns against the tail of *that*, so the common case
(base already fully exists, only `<path>` needs creating) costs nothing extra, and the rare case
(base itself needs imagining too) is just more of the same sequence, not a different mechanism.

**Schema: a field, not a `Prop`.** `holder: { "@type": "Optional", "@class": "xsd:boolean" }` on
`BaseNode` — not an entry in the existing `props: Set<Prop>` (`props.ts`'s `StringProp` et al.).
`props` is reserved for heterogeneous, mdast/frontmatter-derived metadata read back as an opaque
`{key, value}` bag — a list's `ordered`/`startIndex`, frontmatter serialized as one whole entry
(`astParser.ts`, `artifacts.ts:316-318`) — content the parser happens to carry, not core ontology
state. `holder` is the opposite: a first-class concept needed on every node of every kind, checked
on essentially every resolve and worth checking on every traversal that wants to honor it — the
same reasoning `parent` (§8) already settled for this schema: a real typed field beats a value
buried in a generic collection once the concept is universal rather than incidental per-node data.

`kg:tree`/`kg:search` mark and can filter holders — settled in §7.5, not left open.

### 7.3 The two callers this exists for

- **The wikilink extractor** (`artifacts.ts`'s `resolveBlockLinks` — moved there from `astParser.ts`
  during implementation, since resolution needs DB access a pure parser doesn't have; §2.1's
  implicit base): today a `[[wikilink]]` to a heading that hasn't been written yet has nowhere to
  point and the reference is simply dropped. With `--create-holder` (passed automatically here — a
  forward reference is exactly the case this exists for, not a per-call user choice), it resolves
  to a holder instead, and the `[[wikilink]]`-predicate `Link`
  (`Aperas-interactive-summarization-design.md`) points at something real.

  **Real bug found live, more fundamental than a typo**: resolving links *before* the tree's own
  write (the original ordering) is a genuine chicken-and-egg failure, not just a style choice —
  the implicit base (`resolveIdToPath` on the containing block) only works on an already-persisted
  `.parent` chain, so anything inside the artifact currently being ingested would still be resolved
  against the *previous* ingestion's stale tree, missing whatever's brand new in this very edit.
  Fixed by moving link resolution to a separate pass *after* the big write (extracting and
  stripping each block's raw `linkCodes` beforehand — schema.json has no such field, so leaving it
  in for the write itself also fails schema check — then resolving and patching each affected
  block by id once the tree is queryable), at the cost of one extra write per block that actually
  has a wikilink. A second, smaller bug in the same area: building `--titles` as a raw
  `code.split('/')` overshoots §7.1's tail-alignment count whenever the code contains `..`/`.`
  tokens (§2) — fixed by filtering those out before building the titles list, since only name
  segments ever consume one.
- **A "vision drawer"**: a not-yet-built, not otherwise specified tool for sketching an intended
  tree shape — folders, files, and headings with no real content yet — ahead of writing any of it.
  `--create-holder` is the primitive such a tool would need, all the way from the artifacts root
  (§7.2) down to a single heading: resolve/create the intended structure first, populate it later.
  Whether that tool ends up an interactive `kg:` command (in the spirit of `kg:title`/`kg:link`)
  or something else is out of scope here; the point is the primitive it would need already falls
  out of this flag without a separate design.

### 7.4 Why holders are heading-only

A holder `BlockNode` is always created with `type: 'heading'` (§7.1) — that's what makes
reconciliation need no new design at all: `reconcile.ts`'s `leafKey` — its Stage A match key — is
`node.title` for a heading and `node.text` for anything else (`reconcile.ts:96-98`). A holder's
`.title` is already the real, intended title (§7.1's whole reason `--titles` exists), so when
real content finally arrives with a matching heading, Stage A's Gestalt match keys on title
equality and matches the holder exactly like it would match any unedited heading being carried
forward — same key, same code path; `carryForwardFields` (`reconcile.ts:112`) reuses the holder's
`blockId` on the incoming real node with zero extra logic. Empty `text` never enters into it.

A non-heading titled block (the `kg:title` style of addressable-but-not-a-heading block) keys on
`text` instead, and an empty `text` won't Gestalt-match a real populated one automatically —
there's no working reconciliation path for that case, so `--create-holder` doesn't offer it: a
segment that would need a non-heading holder still declines, same as any miss without the flag.

This restriction sits only at the bottom of the descent (§4's slug tier) — the artifact/folder
tier above it (§7.2) is unrestricted, root included. `ArtifactNode`/`FolderNode` reconcile by
path/abstract similarity (`matchLeftoverByAbstract`, `reconcile.ts:368`), not by this
heading-vs-text key distinction, so nothing about imagining a whole tree from the root down
depends on this choice — only what a leaf holder is allowed to become.

### 7.5 Marking and filtering in `kg:tree` / `kg:search`

§7.2 left this open; settling it now, since both commands already have a natural place for it.

**The mark**: one more trailing field on the line, the same convention `--create-holder`'s own
output (§7.1) already uses for exactly this distinction:

- `kg:tree`: `<id>  [<kind>]  <title>  (holder)` — `printTree` (`kgCli.ts:63-79`) already fetches
  the full doc to read `.title`; reading `.holder` off that same fetch costs nothing new.
- `kg:search`: `<id>  [<kind>]  <field>  <value>  (holder)` — `searchNodes` (`woql.ts:120`)
  returns a bare `{id, field, value}` straight from a WOQL triple query, no full document read.
  The print loop (`kgCli.ts:320-327`) already does one `getNode` fetch per match, but today only
  conditionally, for `BlockNode`'s `type` label (`if (label === 'BlockNode')`) — reading `.holder`
  needs that same fetch unconditionally, for every match kind, not only `BlockNode`. Accepted
  cost: one extra `getNode` round trip per `ArtifactNode`/`FolderNode` match that previously
  skipped it entirely (`BlockNode` matches already paid this).

**The filter**: `--no-holders` on both commands, print-time only — neither command's underlying
query changes, since a match or a tree node still has to be fetched/visited to know whether it's
a holder in the first place.

- `kg:search --no-holders`: matches are a flat list, so this just drops holder matches before
  printing — nothing else to reconcile.
- `kg:tree --no-holders`: matches are a tree, so dropping is per-node, not per-subtree. §7.2
  already established holders exist at per-node granularity, not all-or-nothing (a still-holder
  `FolderNode` can have a real `ArtifactNode` underneath it once that one piece gets tracked), so
  hiding a holder's own line can't also hide what's beneath it. `printTree` recurses into a
  filtered node's children at the *same* depth it would have used for the hidden node itself — the
  holder becomes transparent for indentation purposes, not a pruning point. A holder whose entire
  subtree is also holders (the common case: one `mkdir -p` chain, nothing real underneath it yet)
  simply produces no output for that whole branch, one hidden line at a time — reading the same as
  pruning, without a separate subtree-level check to get wrong.

Without `--create-holder` (the default), a miss behaves exactly as §3/§4 already specify — no
node is created, resolution simply declines.

## 8. `kg:path` — the reverse direction (id→path) — **implemented and live-verified**

Checked first whether `Aperas-core-ontology-design.md` §3.A's "native backlinks" claim already
gave this for free: it doesn't. Confirmed live: `t(X, 'links', <a real Link id>)` correctly
returns the owning `BlockNode`, but `t(X, 'children', <a real child id>)` returns **nothing**,
even though that id is genuinely in its parent's `children`. `Set`-typed fields produce a direct
triple; `List`-typed ones (`BlockNode.children`, `ArtifactNode.root`, `FolderNode.children` — the
tree's actual containment, `List` rather than `Set` because child order is semantically
meaningful) don't — TerminusDB represents `List` membership through cons-cell/RDF-list
indirection, not a direct `Parent predicate Child` triple. §3.A has been corrected to state this
precisely rather than leave the disproven generalization standing.

**The fix**: a direct `parent: Optional<BaseNode>` field on `BlockNode` (`schema.json`) — not a
`parentId: xsd:string` requiring kind-guessing to become useful, a real typed reference read
straight off the document, same as `Link`/`Assertion`'s `target`/`source` already work. Points at
the direct container's full id — another `BlockNode`, or the owning `ArtifactNode`/`FolderNode`
for a tree's own root.

- **`astParser.ts`**: `stampParents`, a post-pass over the *finished* tree (not threaded through
  construction) setting `child.parent` for every direct child. Exported, not auto-run only once —
  see the next bug.
- **`artifacts.ts`**: the tree's own root has no parent from parsing alone (nothing inside the
  parser knows the owning `ArtifactNode`) — stamped externally: `finalRoot.parent =
  ArtifactNode/<artifactId>`.
- **`folders.ts`**: README absorption relocates top-level parsed blocks directly into
  `FolderNode.children`, bypassing a root block entirely — those get re-stamped to
  `FolderNode/<folderId>`, overriding what `astParser.ts` set before the splice.
- **`nodeRef.ts`**: `resolveIdToPath` walks `.parent` up to the first `ArtifactNode`/`FolderNode`,
  collecting each hop's slugified `title`, then prepends that node's own `path` (already the full
  nested path from the artifacts root — no further upward walk needed once reached). `slugify`
  (§5) lives here too, shared with the not-yet-built `kg:resolve` side.
- **`kgCli.ts`**: `kg:path <id>`.

**Real bug found and fixed before this worked at all**: `stampParents` originally ran once,
pre-reconciliation, inside `parseMarkdownTree`. `reconcile.ts`'s `carryForwardFields` then
reassigns `blockId` for every matched pair (the fresh parse's transient id → the old carried-
forward one) — so every already-stamped child's `.parent` pointed at its container's *discarded*
pre-reassignment id, a reference to a document that never actually gets written. Confirmed live as
`references_untyped_object` (`SchemaCheckFailure`) on the very next real re-ingest of any existing
artifact — not a hypothetical. Fixed by calling `stampParents` a second time in `artifacts.ts`,
*after* reconciliation, on the final tree.

**Second real bug, found by `verify:phase0 -- --db`'s own cleanup step failing**: `parent` makes
`ArtifactNode`↔root-`BlockNode` a genuine reference cycle for the first time (root points down via
`children`/`root`, now also points up via `parent`) — the same class of cycle
`findLinkIdsTargeting`'s doc comment already covers for `Link`↔`BlockNode`, with the same fix:
delete everything in the cycle together, in one combined batch, not the `ArtifactNode` separately
and first. `verifyPhase0.ts`'s `resetDemoState` did exactly the latter; fixed to match.

**Migration caveat, same pattern as every prior schema addition in this project**: `parent` is
`Optional`, so existing content isn't broken, but a `BlockNode` ingested before this field existed
has no `parent` set until its artifact is actually re-ingested (content-hash-unchanged artifacts
are correctly skipped by `kg:ingest`, so this doesn't happen automatically). `kg:path` reports a
clear, specific miss for this case rather than crashing — confirmed live against both a freshly
re-ingested block (full path resolved correctly, multiple levels deep) and a stale one (correct,
actionable miss message).
