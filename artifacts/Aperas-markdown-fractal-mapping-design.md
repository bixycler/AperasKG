# Markdown → Fractal Tree Mapping — Design

## 0. Why this doc exists

Markdown/mdast is a **loose** structure: node shapes vary per type (a `heading` carries its
content differently from a `paragraph`; `list`/`listItem` nest oddly; whole categories of block
exist that the parser doesn't even recognize without extra plugins), and remark itself parses
headings as flat siblings rather than a nesting construct. `BlockNode` is meant to be a **tight**,
uniform structure with no fixed depth bound — the same three-part shape at every depth, described
by `Aperas-core-ontology-design.md` §5's "Abstraction by Folding": *"an unbounded subtree folds
into an abstract (`text`), which folds into a semantic label (`title`), which folds into a hidden
`@id`."* That's a claim of **uniformity** — every node, regardless of its mdast origin, is
supposed to look the same shape-wise. In practice, the mapping in `astParser.ts` has grown
ad hoc, one exception at a time (heading gets special title handling, containers get emptied
text, `ordered`/`start`/`checked` bolted on for `list`/`listItem` specifically). This doc is the
settled mapping: what `title`/`text`/`children` mean for every block type, uniformly, and an
honest audit of what's covered today versus silently isn't.

## 1. `title`/`text` are core content — one consistent meaning, everywhere

Both fields mean the same thing for every node, not a per-type special case:
- **`title`**: this node's own folded label. Meaningful today only where the source actually
  supplies one (a `heading`'s literal heading line); everywhere else it's a `blockId` fallback,
  standing in for "nothing has summarized me yet" (AI-driven title summarization is a separate,
  unbuilt enhancement — `Aperas-dev-status.md`, "Fractal Ontology Enhancements"). That fallback
  is itself meaningful signal (`Aperas-agentic-query-tools-design.md` §2), not a gap to hide.
- **`text`**: this node's own *immediate* content — not a cache, not a derived read-only summary
  computed from elsewhere and bolted on after the fact. If a node has a `text`, that content is
  *this node's*, the same way a `paragraph`'s `text` unquestionably belongs to it and to no
  other node.

That second point is the one worth stating plainly, because the code shipped earlier this
session violated it: `heading`/`listItem`'s `text` was computed via `extractAbstract(block)` —
a **copy** of whatever descendant paragraph happened to be found first, deep search included,
while that same paragraph *also* remained, fully duplicated, as its own independent child
`BlockNode`. That's inconsistent with every leaf type, where `text` is never a duplicate of
something addressable elsewhere. §2 below supersedes that with a consuming (not copying) rule
for `heading`/`listItem` specifically, which is what makes `text` mean the same thing — *my own
content, not a copy of someone else's* — across every node type uniformly.

## 2. `heading` and `listItem`: equal, and *consume* their leading paragraph

**Settled**: `heading` and `listItem` are structurally equal — both are "the main block type": a
label (title, or its blockId-fallback equivalent) plus optional own content (`text`) plus
structural children. A `heading` is not special-cased relative to a `listItem`; the only
difference is that a heading's `title` happens to already be meaningful (the heading line) while
a listItem's isn't (no natural label).

**Consuming, not copying**: when a `heading` or `listItem` node's *immediate* first child (after
`groupByHeadings`, for headings) is a `paragraph`, that paragraph's `text` becomes this node's
own `text`, and the paragraph is **not** kept as a separate child — it's absorbed, one node
fewer in the tree, not two nodes carrying identical content. If the first child isn't a
paragraph (e.g. a heading immediately followed by a sub-heading, or a listItem containing only a
nested list with no leading sentence — both legal Markdown), `text` stays empty; there's nothing
of the node's own to consume, same as today.

This is a **shallow** rule — the immediate child only, not a recursive search through nested
containers. That's a deliberate change from the shipped `extractAbstract`-based version, which
dug arbitrarily deep (through a `list`/`listItem` chain) to find *some* text to copy. Under the
consuming model, a heading whose first child is a `list` (not a `paragraph`) simply has no
`text` of its own — its content genuinely lives only in its children, and that's an accurate
statement about the document, not a gap to paper over by reaching deeper for something to show.

**What this supersedes**: an earlier `astParser.ts` version (`extractAbstract` reused for
`heading`/`listItem`, called after `children` exist) was **not** this design — it was a copy, and
a deep one. **Implemented**: `convertChildren` now performs the shallow consuming version
described here instead.

## 3. `blockquote`: decided — opaque leaf, structured content inside is an anti-pattern

Settled: `blockquote` is a true opaque leaf, the same category as `code`/`table`/
`thematicBreak`/`html` — `text = rawText` (the full raw slice, markers included, as the source
wrote them) and **no children at all**, regardless of what's actually nested inside it. A
blockquote *can* contain a full sub-tree in theory (nested lists, multiple paragraphs, further
structure) — but doing so is a discouraged anti-pattern, not something this ontology
decomposes. Authors should be warned against putting structured content inside a blockquote;
the system doesn't attempt to structurally model it either way.

**Implemented and verified**: `astParser.ts`'s `convertAstNode` no longer recurses into a
`blockquote`'s children at all (forced to `[]`, the same treatment `table`'s `tableRow`/
`tableCell` already get by simply not being structural — here made explicit, since blockquote's
inner content *would* otherwise recurse, using the same node types as everything else).
`reconcile.ts`'s `blockquote` moved from `CONTAINER_TYPES` to `LEAF_TYPES` (it now has real
`text` and no children, exactly like any other leaf — matched by content equality, not
type+position). `project.ts`'s `blockquote` case now reads `node.text` directly (strip-then-
reapply `> ` markers, same normalization as before) instead of recursing into now-empty
children. Verified: `verify:phase0 -- --db` clean (one fewer block per blockquote in the sample,
as expected — its former paragraph child no longer exists as a separate node).

## 4. Coverage audit: what's done, what's decided, what's still to discuss

Checked empirically against the actual parser throughout, not assumed — including a second pass
after two follow-up questions ("have you actually checked gfm's table support" / "what about
bold and italic") turned out not to have been verified as precisely as they should have been the
first time.

### Done (implemented and verified)

- **`thematicBreak`/`html`**: both now in `astParser.ts`'s `isStructural`, treated as ordinary
  leaves (`text = rawText`, same as `code`). Added to `reconcile.ts`'s `LEAF_TYPES` (otherwise
  invisible to matching, showing as removed+added on every re-ingestion regardless of change) and
  to `project.ts`'s leaf case (otherwise silently dropped again at projection time, having no
  children to fall back on). Verified: `verify:phase0 -- --db` clean.
- **`table`, and `remark-gfm` wired in for real**: `.use(remarkParse).use(remarkGfm)` in
  `astParser.ts`'s pipeline. `table` added to `isStructural` as one more opaque leaf (no
  per-row/per-cell decomposition — its children come out empty for free, since `tableRow`/
  `tableCell` aren't structural either), plus the same `LEAF_TYPES`/`project.ts` additions as
  above. Confirmed GFM's table support itself is complete (header row, all three alignment
  forms, arbitrary rows/columns) before committing to the opaque treatment. **Side effect,
  genuinely fixed**: task-list `checked` — previously always `null` regardless of source syntax,
  since GFM task-list parsing needs `remark-gfm` too; `verifyPhase0.ts` now asserts the actual
  value, not just round-trip shape. Verified: `verify:phase0 -- --db` clean, sample markdown
  exercises a real aligned table and both checked/unchecked items.
  **Not yet exercised against real content**: three real artifacts already contain genuine
  tables (`Aperas-architecture.md`, `Aperas-core-ontology-design.md`,
  `tdb-cli-status-walkthrough.md`), stored as opaque `paragraph`s from before this change —
  `kg:track`'s hash-gate means they won't re-ingest until touched. Reasoned (not forced) that the
  eventual `paragraph`→`table` type change reconciles cleanly rather than removed+added, since
  `reconcile.ts`'s Stage A matches on `leafKey`'s string value only, never `.type`.

### Decided — inline content is out of scope, permanently

Bold/italic/strikethrough/footnotes: none of these are block-level, none go in `isStructural`,
none get special-cased — confirmed correct today regardless (`**bold**`/`*italic*` are core
CommonMark; strikethrough's literal text survives verbatim in the raw slice with or without
`remark-gfm` either way, since this project never re-serializes inline content — every leaf's
`text` is a raw source-slice, replayed byte-for-byte, independent of what remark's own AST
recognizes inline). This is a closed decision, not a gap — inline *structural* extraction of
addressable spans is a different, separately-tracked concern (Fractal Ontology Enhancements).

### Implemented — `BlockNode.links` extraction

Links are **not** in the "permanently out of scope" bucket above — unlike bold/italic/etc.,
extracting them was an already-designed feature
(`Aperas-fractal-ontology-implementation-plan.md` Stage 2 item 4; tracked in
`Aperas-dev-status.md`'s "Fractal Ontology Enhancements"): inline links become `Link` objects
(the concrete `BaseLink` leaf — `Aperas-core-ontology-design.md` §2.E, added alongside this
work, the same gap `Assertion` already closed for `BaseEdge`) in `BlockNode.links`, `Link.target`
pointing at a real node.

**Scope, clarified this turn**: extraction isn't wikilink-specific — it applies to *any* link
whose target resolves to an internal node reference (a snowflake code), not just wikilink syntax
used on its own. The deciding factor is what the target *is* (internal code vs. external URL).
A link to an external URL never becomes a `BaseLink`; there's nothing internal to target.

**Corrected, confirmed live**: `[[...]]` isn't a separate, competing link syntax needing its own
plugin — it's how the *target* of an ordinary link is written to signal "this is an internal
code, not a URL": `[internal link]([[00C5H15NT0000]])`. Tested directly: plain `remark-parse`
(no plugin, no `remark-gfm`) already parses this as a completely ordinary `link` mdast node —
`{ url: "[[00C5H15NT0000]]", children: [{ type: "text", value: "internal link" }] }` — exactly
the same node shape as `[external](https://example.com)` (confirmed side-by-side in the same
test), just with a different-looking `url` string. So the parsing half is *entirely* free
already, for both forms — no wikilink plugin needed at all for this project's actual usage. An
earlier revision of this doc wrongly assumed `[[...]]` would be used the Obsidian/Logseq way (as
a standalone replacement for `[text](url)`, tested in isolation as bare `[[Some Page]]`) and
concluded a plugin like `remark-wiki-link` was required — that conclusion doesn't apply to the
form actually being designed here.

**Implemented — walking mdast `link` nodes directly, as originally designed above, not a raw-text
regex.** A first pass tried regexing the already-captured raw `title`/`text` slice directly for
`\[[^\]]*\]\(\[\[([^\])]+)\]\]\)`, reasoning that every leaf's `title`/`text` is already a raw,
byte-for-byte source slice (§1) so a plain string match would find every occurrence uniformly.
**That was wrong, confirmed live**: a plain string regex can't tell a real `link` node from an
`inlineCode`/`code` span's literal contents — remark never re-parses backtick-wrapped text for
nested constructs, but a raw-text regex doesn't know that boundary exists at all. This doc's own
authoring-convention example a few paragraphs up, `` `[title]([[code]])` `` (deliberately
backtick-wrapped, illustrating the syntax as inert prose), triggered exactly this false positive
on ingestion. Fixed by reverting to the originally-designed approach: `astParser.ts`'s
`collectLinkCodes` walks the actual mdast (sub)tree recursively, matching only genuine `link`
nodes' `url` field against `^\[\[(.+)\]\]$`, and never descending into an `inlineCode`/`code`
node at all — so backtick-wrapped example text stays correctly inert. Since this pure, DB-less
parser can't resolve a code into a real node id, it only captures the raw codes onto an ephemeral
`ParsedBlockNode.linkCodes` field (never written to the DB); `artifacts.ts`'s `resolveBlockLinks`
(which has DB access) resolves each one at ingestion time and replaces it with a real
`links: [{"@type": "Link", target, predicate: "references"}]` entry, deleting `linkCodes` before
the tree is written.

**Authoring convention, settled — bare `[[code]]` never needs parser support at all.** The
canonical stored form is always `[title]([[code]])` — a human never has to hand-type that. The
(unbuilt) Human UI is where a bare `[[code]]` — typed or pasted — gets auto-expanded into the
full `[title]([[code]])` form, filling in `title` for the human, before it's ever saved as
Markdown. This closes the wikilink question definitively: there is no scenario where the
Markdown *parser* needs to understand standalone `[[...]]` on its own — that form only exists
transiently as a UI input convenience, never in a saved file. A wikilink plugin genuinely isn't
needed, not now and not later, unless a future decision changes what gets *saved*.

**Open questions, found on audit — resolved:**
- **What does the inner code resolve against, and what about dangling references?** Resolved via
  the same addressing scheme used elsewhere (`resolveDirectOrSnowflake`, `directResolve.ts`): a
  full node id, or a bare snowflake code (tried as `BlockNode`, then `ArtifactNode`, then
  `FolderNode` — Snowflake ids share one generation scheme, so a bare code alone doesn't say
  which). Resolution is best-effort and non-fatal: an unresolvable code (typo, forward reference,
  or a target genuinely gone) is skipped with a console warning, never fails the whole
  artifact's ingestion — confirmed live with a deliberately-dangling `[[ZZZZZZZZZZZZZ]]` code.
- **`Link.predicate` value?** A fixed constant, `"references"` — not the link's visible text
  (arbitrary, not a stable relation name); distinguishes structural inline links from
  `Assertion`'s deliberately-chosen semantic predicates at query time.
- **Does extraction touch `text`?** No — confirmed as implemented: `text`/`title` stay the exact
  raw slice, `links` is a purely additive index built from a *copy* of the matched substrings,
  never a mutation of the leaf's own content.
- **Multiple links / `Set` ordering?** Left as `Set<Link>`, no ordering added — `links` remains a
  lookup index only, `text` is always the rendering/reading-order source of truth.
- **Reconciliation/projection consequences?** None needed, confirmed (not just inferred) by the
  live round-trip tests in `verifyPhase0.ts`: `text` is unaffected, so reconciliation and
  projection both continue to work unchanged.

**One real prerequisite gap found during implementation, not previously flagged even in this
audit**: `BaseLink` is `@abstract`, and — unlike `BaseEdge`, which already had `Assertion` as its
one concrete leaf — nothing inherited directly from `BaseLink` was instantiable at all.
`BlockNode.links: Set<BaseLink>` literally couldn't be written to until a concrete `Link` class
was added (`Aperas-core-ontology-design.md` §2.E), mirroring `Assertion` exactly (no fields of
its own, just makes the lineage instantiable).

**A genuine reference cycle, discovered live while extending `verifyPhase0.ts`'s cleanup for
this feature**: a block whose `links` field points at a `Link`, which in turn `target`s some
other block (a self-link makes this a literal cycle back to the same root) can't be cleaned up
by deleting the `Link` and the blocks as separate sequential calls — each side fails as
still-referenced by the other. TerminusDB's referential-integrity-on-delete check only allows a
reference from *outside* the set of documents being deleted in one call, so the fix is deleting
the `Link` ids together with the blocks that form the cycle, in one combined batch
(`findLinkIdsTargeting`, `crud.ts`) — not a design change, but a real operational detail anyone
writing cleanup/deletion code touching `Link` needs to know.

### Pointer

YAML frontmatter — parsing shape confirmed, stage-appropriate design settled. See §5.

## 5. YAML frontmatter as node props — opaque for now, extensible later

**Scope: `ArtifactNode` and `FolderNode` both, decided.** A `README.md`'s own frontmatter (if it
has any) extracts into `FolderNode.props` via the exact same mechanism as an ordinary artifact's
frontmatter → `ArtifactNode.props` — not an `ArtifactNode`-only feature. This falls out for
close to free: `parseMarkdownTree`'s signature change (below) already has to touch `folders.ts`'s
README call site regardless (it's the same function), so handling both node kinds is barely more
work than handling one.

**Confirmed parsing shape**: `remark-frontmatter` (now installed, tested, not yet wired into
`astParser.ts`) with `.use(remarkFrontmatter, ['yaml'])` recognizes a leading `---\n...\n---`
block as its own mdast node, `{ type: 'yaml', value: '<raw yaml body, delimiters stripped>' }` —
confirmed live against a real multi-key example. Critically, this only *isolates* the block; it
does **not** parse the YAML into an object — `.value` is still just a string (e.g.
`"title: My Doc\ntags: [foo, bar]\ndraft: true"`). Turning that into real key/value data needs a
YAML parser too (e.g. the `yaml` or `js-yaml` package — neither installed yet).

**Shape of the change, not yet built**:
- Frontmatter is file-level metadata, not a block — it should never become a `BlockNode` at all
  (parallel to how `folders.ts` already treats a directory's own `README.md` specially, never
  exposing it as a separate `ArtifactNode`). `parseMarkdownTree`'s signature would need to
  change: return the parsed props alongside the root `BlockNode`, not fold them into the tree.
  That ripples into every caller — `artifacts.ts`'s `ingestArtifact` (→ `ArtifactNode.props`)
  and `folders.ts`'s README handling (→ `FolderNode.props`, per the scope decision above), plus
  `verifyPhase0.ts`.
- **Realized through §7's unified `props` mechanism, not a bespoke per-node-kind field.** An
  earlier revision of this doc proposed a dedicated `ArtifactNode.props: Optional xsd:string`
  field specifically for frontmatter. Superseded: §7 designs one generic `props` mechanism for
  *any* node kind's extensible metadata, and frontmatter is simply one more user of it — a
  single entry (e.g. `{key: "frontmatter", value: "<raw yaml body, as-is>"}`) in whichever
  node's (`ArtifactNode` or `FolderNode`) own `props` list, not a field of its own. Still opaque
  for this stage (the raw
  body, not JSON-parsed — no YAML-parsing dependency needed yet), same reasoning as before, just
  expressed through the shared mechanism instead of a one-off field.

**Implemented**: §7's schema addition, `remark-frontmatter` wired into the pipeline, and
`parseMarkdownTree`'s signature changed to `{root, frontmatter?}`, threaded through every caller
(`artifacts.ts`'s `ingestArtifact`, `folders.ts`'s README handling, `verifyPhase0.ts`) to extract
and return the frontmatter body separately from the `BlockNode` tree.

## 6. README ingestion: same copy-not-consume gap, and no round-trip at all

Investigated directly, per a specific concern: was `FolderNode`'s README absorption actually
built the way it was designed — README's abstract *consumed* (not copied) into `FolderNode.text`,
with the parsed README content as the folder's own leading children? Re-reading `folders.ts`:

- **The same copy-not-consume gap §2 fixed for `heading`/`listItem` also existed here — now
  fixed the same way.** `buildFolderTree` no longer copies via `extractAbstract`; it consumes:
  when the README's parsed root's first child is a `paragraph`, that paragraph's `text` becomes
  `FolderNode.text` and is dropped from `readmeChildren`, with any list *that paragraph had
  itself adopted* (§8) promoted to `FolderNode`'s own leading children — the same consume-then-
  adopt symmetry §8 already establishes for heading/listItem, applied one level up.
- **`FolderNode` → README.md projection — implemented.** `Aperas-core-ontology-design.md` §5.A
  names this as part of Artifact Projection: *"For `FolderNode`s, the block children are
  serialized back out to the folder's `README.md`."* `graphql.ts`'s new
  `getFolderTreeViaGraphQL` and `project.ts`'s new `serializeFolderToReadme`/
  `projectFolderToReadme` close this — `kg:project` now accepts either an artifact or a folder
  path (tried in that order, same as everywhere else), and full round-trip is live-verified
  (`verifyPhase0.ts` step 6b: project → write → re-ingest → project again reproduces the exact
  same output, a stable fixed point).

  **Open questions, resolved:**
  - `FolderNode` isn't a `BlockNode`, so it has no mdast `type` for `serializeBlock`'s dispatch to
    key on — but no wrapper was needed at all: `renderChildren` never switches on `node.type`
    itself (only `serializeBlock`'s dispatch does), so `serializeFolderToReadme` just calls it
    directly against the `FolderNode`, emitting `folder.text` (the consumed leading sentence)
    ahead of it.
  - Frontmatter round-trip: yes, for both kinds. A shared `withFrontmatter` helper in `project.ts`
    reads `getProp(node, 'frontmatter')` and prepends a re-emitted `---\n...\n---\n\n` block —
    fixing the same pre-existing gap in `ArtifactNode` projection at the same time (it never
    re-emitted frontmatter either, until now).
  - Read path: a small purpose-built `getFolderTreeViaGraphQL`, not a fully generic "any node"
    abstraction. It uses the hybrid polymorphism pattern from §7's GraphQL findings: `_type`/
    `_json` for the one polymorphic `FolderNode.children` hop, then reuses the *existing*
    `fetchBlockSubtree`/truncation-refetch machinery (now exported from `graphql.ts`) for each
    `BlockNode` child's own concrete subtree — no duplicated logic, and no need for the plain
    Document API fallback originally guessed at here.
  - **Corrected from the original proposal**: `kg:project` writes to disk **by default** for
    both `ArtifactNode` and `FolderNode` (a `--dry-run` flag prints instead) — not print-only as
    first proposed. `Aperas-core-ontology-design.md` §1.B is explicit that once a tree is
    ingested, *"the DB becomes the source of truth. Edits are made directly in the DB, and
    artifact files are regenerated (projected) from it"* — re-ingestion is named the *fallback*
    path, only for hand-edits outside the DB. The original print-only proposal had this backwards
    (an artifact of Phase 0 not yet having DB-native content-authoring tools, which made
    file-editing the *practical* norm so far — not the intended end-state).
  - `FolderNode.children` mixes the README's own `BlockNode`s with references to nested
    `FolderNode`/`ArtifactNode` documents — `serializeFolderToReadme` filters `children` down to
    `BlockNode`-typed entries (identified by the absence of a GraphQL `_type` tag, which
    `getFolderTreeViaGraphQL` only attaches to the reference stubs it doesn't inline) before
    calling `renderChildren`, exactly as proposed.

## 7. `props`: one extensible mechanism, not one field per feature

Settled direction, designed now (not deferred): a generic, per-node `props` mechanism, so a new
piece of type-specific metadata never again needs its own schema field. `ordered`/`start`/
`checked` (shipped earlier this session) are exactly the pattern being moved away from — three
separate fields, one per feature — and **all three migrate onto `props`**, not just the two list
adoption forces to move (see §8: an earlier revision of this doc left `checked` in place since
nothing *forces* it to move, but there's no good reason to leave the one remaining hardcoded
per-feature field once everything else is uniform — consistency, not necessity, is the actual
argument, and it's the stronger one).

**Schema** (revised — abstract base + one concrete leaf, mirroring `BaseEdge`/`Assertion`):
```json
{
  "@id": "Prop",
  "@type": "Class",
  "@abstract": [],
  "@subdocument": [],
  "key": "xsd:string"
}
```
```json
{
  "@id": "StringProp",
  "@type": "Class",
  "@subdocument": [],
  "@inherits": ["Prop"],
  "value": "xsd:string"
}
```
- **`Prop` is abstract and carries only `key`** — deliberately, so `value`'s type is never fixed
  at the mechanism's own level. This is the exact same pattern already used for `BaseEdge`
  (abstract) → `Assertion` (the one concrete leaf, `Aperas-core-ontology-design.md` §2.C-D): the
  shared shape lives on the abstract parent, the concrete detail lives on whichever leaf
  actually gets instantiated. Here it buys real freedom later — a future `BooleanProp` (`value:
  xsd:boolean`) or `IntegerProp` (`value: xsd:integer`) could be added as another concrete leaf
  of the same abstract `Prop`, genuinely WOQL-typed and queryable on `value` itself, without
  touching `Prop` or anything already built on it — `BaseNode.props: Set<Prop>` is already
  polymorphic over whatever concrete leaf a given prop actually is.
- **For now, `StringProp` is the only concrete leaf, exactly as designed before the rename**:
  `value` is a single `xsd:string`, JSON-encoded for anything that isn't naturally a string
  (a boolean as `"true"`, a number as `"3"`, a list as `"[\"foo\",\"bar\"]"`), decoded at the
  application layer. Every prop this doc actually needs today (`orderedList`, `startIndex`,
  `checked`, frontmatter) uses `StringProp` — nothing forces reaching for a hypothetical typed
  variant yet.
- `@subdocument`, deliberately unlike `BaseLink`/`BaseEdge` — a prop is owned entirely by the one
  node it belongs to, with no reification use case (nobody needs to assert something *about* a
  prop the way `Assertion` lets you assert about an edge), so it doesn't need the global `@id`
  `BaseLink`/`BaseEdge` specifically require for that (`Aperas-core-ontology-design.md` §2's "No
  Subdocuments" rule doesn't apply here — that rule's reasoning was reification, which doesn't
  apply to `Prop`).
- `key` stays a plain top-level field regardless of which concrete leaf carries a given prop, so
  "find every node with a `checked` prop" is a real, direct WOQL triple match either way; only
  `value` (and only for `StringProp`) stays opaque to the query engine.
- Added to `BaseNode` (not just `BlockNode`) as `props: { "@type": "Set", "@class": "Prop" }`
  (polymorphic over `Prop`'s concrete leaves; `Optional` in effect via an empty `Set`, no
  migration needed for existing documents) — so any node kind (`BlockNode`, `ArtifactNode`,
  `FolderNode`) can use the same mechanism, matching the user's own framing ("ordered & start
  for list, frontmatter for artifact" — two different node kinds, one shared mechanism).

**Plain field vs. `props` — the actual boundary, stated explicitly.** This has been applied
case-by-case throughout this doc without ever being written down as a general rule: a plain
`BaseNode`/`BlockNode` field (`blockId`, `type`, `title`, `text`, `children`, `unfolded`) is for
something *every* node conceptually has, regardless of type — even a fallback/empty value is
still that concept, present universally. A `props` entry is for something only *some* node
*types* have at all — `orderedList` means nothing on a `paragraph`, `checked` means nothing on a
`heading`, frontmatter means nothing on a `BlockNode`. That's the actual test for "does a new
field belong on the schema directly, or as a `props` entry": is it universal (→ field) or
type-conditional (→ `props`)? `unfolded` staying a plain field (not migrating here) is exactly
this — every node has a fold state, so it's not a `props` candidate at all, unlike
`orderedList`/`checked`/frontmatter, which are all conditional on the node being some specific
kind of thing.

**"Each type of block decides its own props"** is enforced by convention in ingestion code
(`astParser.ts` decides which keys a `list`/`listItem`/etc. populates), not by the schema —
the schema itself stays generic and open, consistent with this project's existing perimeter-
boundary-transducer philosophy (type constraints belong to the code that populates a node, not
to a rigid schema-level enum of allowed keys per type).

**`orderedList`/`startIndex` are this mechanism's first real user — decided in §8, not
deferred.** (Renamed from `ordered`/`start` — see §8.) An earlier revision of this doc treated
migrating these onto `props` as a single, indefinitely-deferred future item. Corrected: they
migrate now, as part of §8's list-adoption design — once a `list` node can dissolve, they need
somewhere to live that isn't a `list`-only field, and `props` is exactly that. `checked` joins
them (§8) for consistency, not because anything forces it to.

**Implemented**: schema addition (`Prop`/`StringProp`, `BaseNode.props`), a shared `getProp`/
`setProp` helper (`props.ts`, used by `astParser.ts`, `project.ts`, `folders.ts`, `artifacts.ts`),
and the full migration (§8/§9's projection mechanics, below). `StringProp` needs its own
`@key: {"@type": "Random"}` (confirmed live — TerminusDB rejects a `@subdocument` class with no
key strategy at all, even though nothing outside the owning node ever needs to address a `Prop`
directly); `Prop` itself stays keyless since it's `@abstract` and never instantiated.

**GraphQL representation, confirmed live — no inline fragment.** `props: Set<Prop>` can't be
queried as `props { key ... on StringProp { value } }`: TerminusDB's auto-generated GraphQL
schema materializes `Prop` as its own concrete `OBJECT` type (confirmed via introspection —
`possibleTypes: null`), not an interface/union `StringProp` implements, so `value` (a
`StringProp`-only field) is simply absent from `Prop`'s GraphQL type — asking for it via a
fragment errors ("objects of type Prop can never be of type StringProp"). **This is a TerminusDB
codegen gap, not a GraphQL spec limitation** — the spec fully supports exactly this pattern
(an abstract/interface type plus `... on ConcreteType` inline fragments, `possibleTypes` naming
its implementors); TerminusDB's schema generator just doesn't map `@abstract` classes to that
construct at all. Checked TerminusDB's own GraphQL and schema reference docs for a flag or
annotation that might enable it — neither mentions interfaces, unions, or `... on` anywhere. The
only documented related mechanism is `_type` ("useful when a super-class is queried, as we can
obtain what concrete subclass it corresponds to") — confirming the intended pattern is inspect-
`_type`-yourself, not spec-standard fragments. The fix is `_json`, an escape hatch every
generated GraphQL type carries: `props { key _json }` returns each prop's full subdocument as a
JSON string (`value` included), which `graphql.ts`'s `normalizeProps` parses back into the
ordinary `{key, value}` shape every other reader already expects. Anything reading `props`
through GraphQL (only `graphql.ts`'s artifact-tree read path does — the CLI's `kg:tree`/
`kg:unfold`/`kg:search` all use the plain Document API instead) needs this same `_json`-then-
parse step; the plain Document API's own `getDocument` needs no such workaround — confirmed live,
it already returns each prop's `key`/`value` directly, unmodified, since it's just returning the
JSON-LD exactly as stored with no generated type-projection layer in between.

**This generalizes — confirmed via introspection on `BaseNode`/`BaseLink`/`BaseEdge`, not
`Prop`-specific.** Every `@abstract` class in this schema, when it's the type of some field
(`Set`/`List`/`Optional`), hits the identical restriction: its GraphQL object exposes only the
fields defined *directly on that abstract class itself* — never a concrete leaf's own additional
fields — with no fragment escape, only `_json`. Concretely, in this schema:
- `BaseNode` (fields: `links`, `props`, `tombstonedAt` only — not `blockId`/`title`/`text`/`path`,
  which live on the concrete subclasses `BlockNode`/`ArtifactNode`/`FolderNode`).
- `BaseLink` (adds `predicate`, `target` — both defined on `BaseLink` itself, so these two work
  fine without any fragment/`_json` workaround).
- `BaseEdge` (adds `source`, likewise defined on `BaseEdge` itself, also fine as-is).

Nothing currently queries `BaseNode.links: Set<BaseLink>` via GraphQL, so `source`/`target`/
`predicate` being directly queryable there is moot today — but it will matter once `BlockNode.links`
extraction (§4) ships and something needs to read it back. More immediately relevant:
**`FolderNode.children: List<BaseNode>` has never been queried via GraphQL at all**, and per the
rule above, a naive attempt would only ever surface `links`/`props`/`tombstonedAt` per child —
never the `blockId`/`title`/`text` (`BlockNode`), `path`/`artifactId` (`ArtifactNode`), or
`folderId` (`FolderNode`) fields any real reader actually needs, since those all live on the
concrete subclasses, not `BaseNode`. This is exactly why `kgCli.ts`'s `kg:tree`/`kg:unfold`
deliberately read folder trees via the plain Document API (`client.getDocument`) instead of
GraphQL — confirmed, now, to be a necessary choice rather than an incidental one.
`ArtifactNode.root`/`BlockNode.children` are unaffected by any of this, since `BlockNode` itself
is concrete, not abstract.

**WOQL does not share this restriction — confirmed live, no workaround needed at all.** Unlike
GraphQL's generated type system, `WOQL.triple` matches directly against the underlying RDF
triples, with no notion of "which GraphQL object type exposes this field" to get in the way.
Tested two ways against real data: (1) `WOQL.triple(v.Node, 'props', v.PropDoc)` →
`WOQL.triple(v.PropDoc, 'key', v.Key)` → `WOQL.triple(v.PropDoc, 'value', v.Value)`, zero type
constraint, returned all 50 real `key`+`value` pairs directly — no `_json`, no fragment. Adding
an explicit `WOQL.triple(v.PropDoc, 'rdf:type', '@schema:StringProp')` constraint changed nothing
(same 50 bindings), confirming it's optional, not required. (2) The deeper case —
`BaseLink → BaseEdge → Assertion`, two abstract levels rather than one — queried `source`/
`predicate`/`target` off a real `Assertion` document with zero type constraint and got a clean
match. So `queryNodeAssertions`/`traceImpactPropagation` (`woql.ts`) and `kg:search` (which also
queries `title`/`text` untyped across all three node classes at once, §5 of
`Aperas-agentic-query-tools-design.md`) were already, unknowingly, relying on exactly this
behavior — it just happened to work because WOQL never needed the workaround GraphQL does.
Net implication for the two features audited above: **any future `BlockNode.links` read path
built on WOQL (rather than GraphQL) needs no `_json`-style workaround at all**, regardless of how
deep the abstract hierarchy gets.

## 8. List refactor: adoption instead of a standalone list block

**The problem**: today, a `list` is always its own `BlockNode`, sitting between its logical
"owner" (the paragraph/heading/listItem that introduces it) and its own `listItem` children —
an artificial intermediate node the fractal-outliner model doesn't actually need in the common
case. Settled: a `list` should be **adopted** by whatever block immediately precedes it, when
that preceding sibling is a `paragraph`, `listItem`, or `heading` — its own `listItem`s become
direct children of that preceding sibling instead, and the `list` wrapper itself doesn't exist
as a node at all. Only when no such preceding sibling exists (a list is the very first thing in
its parent's children — e.g. the first content in a document, or the first thing inside a
blockquote) does it remain an orphaned "list block," exactly as today (no title, no text).

**Scope of "immediately precedes," precisely**: the list's previous sibling *within its current
parent's children, at the point `groupByHeadings` has already run* (so a heading's own nested
content already sees its restructured, non-flat sibling list) — checked once per list, against
the original parse structure, not recomputed after other adoptions have already happened at the
same level.

**Interaction with §2's consuming rule — explicit, not just implied.** `heading` and `listItem`
are equal here too: when a list's immediate predecessor is exactly the leading paragraph that
§2 just consumed into that heading/listItem's own `text`, the list adopts into the
*consumer* — the heading/listItem itself — not into nothing. A consumed-away paragraph still
counts as a valid adoption anchor via whatever absorbed it; it doesn't make the list orphaned
just because the specific node it originally sat next to no longer exists as its own entry in
`children`. Concretely, for `## Heading\n\nIntro sentence.\n\n- item one\n- item two`: the
leading paragraph "Intro sentence." consumes into `heading.text` per §2, and the list right
after it adopts into the *heading*, so `heading.children` becomes the two `listItem`s directly
— no intermediate `list` node, exactly as if the heading were a `listItem` in the already-given
nested example below. This is the same rule stated twice for two symmetric cases, not two
different rules — worth stating explicitly rather than leaving it to be inferred from only the
`listItem` example, which is the ambiguity that prompted this clarification.

This also covers the common nested-list case: `- Parent item\n  - Nested item` today produces
`listItem("Parent item") → [paragraph, list → [listItem("Nested item")]]`; under adoption, since
the nested list's immediately preceding sibling *is* `listItem`'s own leading paragraph (already
consumed into `listItem.text` per §2), the nested list's own `listItem`s become direct children
of the outer `listItem` — no intermediate `list` node for the ordinary single-nested-list-
under-a-bullet case at all.

**Two lists directly adjacent to each other — the second is orphaned, not merged into the
first's adoption.** "Immediately precedes" is checked against the literal raw sibling right
before a given list, and a `list` is never itself a valid anchor (only `paragraph`/`listItem`/
`heading` are). So a bullet list directly followed by an ordered list — nothing but a blank line
between them, a common Markdown pattern — does not have the second list adopt into whatever the
first list adopted into: by the time the second list is reached, its own immediately-preceding
raw sibling is the first `list` itself, not a valid anchor, so it stays its own orphaned node.
This isn't just tidy — a node can only ever host one list's `orderedList`/`startIndex` pair (see
below), so letting a second, unrelated list merge into the same adoption would silently corrupt
one of the two lists' own numbering.

**Renamed for clarity: `ordered`/`start` → `orderedList`/`startIndex`.** Once these can live on
a node that isn't itself a `list` (an adopting `heading`/`paragraph`/`listItem`), the old names
read wrong — "`ordered`" on a heading's `props` doesn't say what it's describing. `orderedList`/
`startIndex` read correctly regardless of which node kind carries them.

**Where they live once the `list` node dissolves — decided.** `orderedList`/`startIndex` become
`props` (§7) of whichever block *now functions as a list* — the adopting parent when adoption
happens, or the orphaned `list` block itself when it doesn't (uniform treatment, not a special
case for either side). This is `props`'s first real user, motivated directly by adoption needing
somewhere for these two fields to go once the `list` node that used to hold them can disappear.
A node can only ever end up hosting *one* logical list's worth of adopted `listItem`s, never two
unrelated ones needing different `orderedList`/`startIndex` values — because adoption is checked
per-list against that specific list's own unique immediately-preceding sibling; two sibling
lists can never share the same immediate predecessor (something — even just the first list
itself — always separates them), so one set of `props` per node is always enough.

**`checked` migrates too, for consistency, not necessity.** An earlier revision of this doc left
`checked` on `listItem` as a plain field, reasoning that adoption never dissolves `listItem`
nodes so nothing *forces* it to move. True, but incomplete: once `orderedList`/`startIndex` are
on `props`, leaving `checked` as the one remaining hardcoded per-feature field is inconsistent
with the whole point of §7 — one mechanism, not "some metadata uses it, some doesn't." `checked`
moves too.

**Artifact Projection — designed, not just flagged.** Today, `serializeBlock`'s `list` case is
the only place list-marker/indentation logic lives, reading `node.ordered`/`node.start` directly
and iterating `node.children` (all `listItem`s, homogeneous). Under adoption, that's no longer
enough — a `heading`/`paragraph`/`listItem`'s own `children` can be a *mix* of ordinary blocks
and a contiguous run of adopted `listItem`s. Proposed: generalize `renderChildren` (used by every
case, not just `list`) to scan its node's `children` for contiguous runs of `type === 'listItem'`
— render each such run exactly like today's `list` case does (via `serializeListItem`, reading
`orderedList`/`startIndex` from *this* node's own `props`, `checked` from each item's own
`props`), and render everything else via the existing per-type dispatch, one block at a time.
This subsumes the old `list` case entirely rather than sitting alongside it: an orphaned `list`
is just the special case where the *entire* `children` array is one such run — no separate case
needed. The scan checks every position rather than assuming the run is always last, but in
practice a *mid-children* run is an anti-pattern, not a case worth designing around as if it
were normal:
- **`paragraph`**: structurally can't happen at all. A paragraph never has children of its own
  except an adopted list — nothing else ever becomes a paragraph's child — so its `children` is
  either empty or *entirely* one run. There's no "after" to worry about.
- **`heading`/`listItem`**: *can* have other genuine children (sub-headings, more prose) after
  an adopted list, since these node kinds do have real structural children beyond what any list
  contributes — but doing so is a discouraged anti-pattern: once a section's content becomes
  a list, further prose at the same level reads better as a new section (a following heading)
  than as more content trailing after a list under the same one. Worth a warning to authors, not
  a reason to complicate the algorithm — the general "scan every position" design already
  handles it correctly if it happens anyway, which is the right way round: correct by
  construction for the exceptional case, without needing to special-case *for* it.

**Reconciliation — designed, and it turns out nothing needs to change.** `diffChildren` already
operates generically on whatever `children` array it's handed — it doesn't know or care whether
a `listItem` used to live under a `list` wrapper. `listItem` is already in `CONTAINER_TYPES`
(Stage B: matched by type and relative position within the segments Stage A's leaf-anchors
define), and that classification is keyed purely on `.type`, unaffected by *whose* children array
a node sits in. So adopted `listItem`s mixed in among an adopting parent's other children match
exactly the same way they already do today as a `list`'s own children — grouped by type within
whichever segment they fall into. No changes needed to `reconcile.ts` at all; this was flagged
as an open risk in an earlier revision of this doc before actually re-reading `diffChildren`
closely enough to confirm it.

## 9. Consequences for Artifact Projection — implemented

§2's consuming rule required `project.ts`'s `serializeBlock` to change for `heading`/
`serializeListItem` — under the old *copying* model, the leading paragraph was still there to
recurse into via `renderChildren`; under the *consuming* model it no longer exists as a child at
all, so both cases now emit `node.text` explicitly before rendering the rest of `children`. This
shipped in the same change as §2 itself, not after, since skipping it would have silently
dropped the leading sentence from every projected document.

## 10. Consequences for Reconciliation (a positive side effect, worth naming)

`reconcile.ts` matches `heading` by `.title` (Stage A) and `listItem` by type+position (Stage B)
— neither key depends on the *value* of `.text`. So consuming the leading paragraph doesn't
change either node's own matching behavior. What it does change: today, that leading paragraph
is a separate child, itself Stage-A-matched by *exact text equality* — editing just that
sentence makes it fail to match (declined, shows as remove+add, per the reconciliation design's
"decline rather than guess" principle) even though the heading/listItem around it is unchanged.
Once consumed, that same edit becomes an in-place field update on the already-matched
heading/listItem (no separate node to fail-to-match) — arguably a more natural outcome ("I
tweaked the section's opening line" reads as an edit, not a delete-and-recreate), but a real,
worth-flagging shift in reconciliation stats for anything that edits leading sentences under
headings or list items.

## 11. Status

**Implemented and verified**: §1 (uniform title/text semantics); §2 (heading/listItem consume,
shallow — `convertChildren` in `astParser.ts`); §3 (blockquote, opaque leaf); §4's
`thematicBreak`/`html`/`table` + `remark-gfm` wiring; §5 (frontmatter, extracted via
`remark-frontmatter` and returned separately from `parseMarkdownTree` as `{root, frontmatter}`,
realized as one `props` entry on both `ArtifactNode` and `FolderNode`); §6's first finding
(the same copy-not-consume fix applied to `folders.ts`'s README absorption, including transferring
any list the consumed leading paragraph had itself adopted up to the `FolderNode` itself); §7
(the full `Prop`/`StringProp` schema, `BaseNode.props`, the shared `getProp`/`setProp` helper in
`props.ts`); §8 (list adoption — including the heading/listItem consume-then-adopt symmetry, the
`orderedList`/`startIndex` rename, and the two-adjacent-lists orphaning case found during
implementation); §9 (`project.ts`'s `serializeBlock`/`renderChildren`/`serializeListItem`
generalized for consumed text and adopted-listItem runs, reading `orderedList`/`startIndex`/
`checked` from `props`). `verify:phase0 -- --db` clean end-to-end (AST transduction, projection
round-trip, live TerminusDB read/write via the new GraphQL `props`/`_json` path, reconciliation,
FolderNode ingestion, Assertion CRUD); `npm run build` clean.

**Known limitation, inherited from precedent, not new**: `kg:track`'s hash-gate means real
artifacts already ingested before this change won't pick up the new heading/listItem text,
`props`-based `orderedList`/`checked`, or frontmatter until something changes their file content
and forces re-ingestion — the same limitation already disclosed for the earlier heading/listItem
abstract fix (`Aperas-agentic-query-tools-design.md` §2) and the `table`/`remark-gfm` wiring
above. Not fixed here, by the same reasoning: parser-version isn't part of the change-detection
key, and forcing a bulk re-ingest is a separate, disruptive operation from a parser-logic fix.

**Implemented and verified — Agentic Query Tools** (`Aperas-agentic-query-tools-design.md`):
`kg:tree`, `kg:unfold`/`kg:fold`, `kg:search` all live in `kgCli.ts`, smoke-tested against the
real KG. `kg:unfold`/`kg:fold` work uniformly against any node kind for *display* (title/text of
the node and its immediate children), but only persist `unfolded` when the target is actually a
`BlockNode` (the only kind the field exists on) — a no-op note, not an error, otherwise.

**Implemented and verified — `BlockNode.links` extraction** (§4's last subsection): a new
concrete `Link` class (`Aperas-core-ontology-design.md` §2.E — `BaseLink` was abstract with no
concrete leaf at all, a real prerequisite gap found while implementing this), `astParser.ts`'s
pure `extractLinkCodes` capturing raw `[[code]]` targets, `artifacts.ts`'s `resolveBlockLinks`
resolving them at ingestion time (best-effort, `directResolve.ts`'s shared full-id/bare-snowflake
resolution). `verify:phase0 -- --db` exercises both a resolving and a deliberately-dangling link.

**Implemented and verified — `FolderNode` → `README.md` projection** (§6's second finding):
`graphql.ts`'s `getFolderTreeViaGraphQL`, `project.ts`'s `serializeFolderToReadme`/
`projectFolderToReadme`, `kgCli.ts`'s `kg:project` extended to accept a folder path and to
**write to disk by default** (corrected from an earlier print-only proposal — see §6's resolved
open questions). `verify:phase0 -- --db` confirms the full project → write → re-ingest → project
cycle is a stable fixed point.

**Deferred deliberately**: inline features (§4, bold/italic/strikethrough/footnotes) confirmed
permanently out of scope — no future revisit implied.
