# ApeironNgn: Embedded Substrate Design

**Status: in progress — Phase 0.1.** Moved up from `Aperas-design.md`'s originally-speculative
Phase 4 slot: the roadmap item's stated precondition — "confirming that TerminusDB Community
edition's rough edges... are structural rather than incidental before committing engineering
effort to a replacement" — is resolved by this session's live-verified findings (§2), and the
switch itself has been decided. This doc is the concrete engine, storage encoding, and query model
for that work, not a still-open proposal.

## 1. The actual reason, stated first, not derived from a benchmark

This is not a response to a measured bottleneck — the production access pattern this project
actually uses today (bulk tree fetch via `getArtifactTreeViaGraphQL`) is fast, ~18ms for a
91-node tree (`Aperas-kg-foundational-design.md` §2's benchmark table — where ApeironNgn's own
number, 5.6ms for the same tree post-rehydration, also now lives). The reason is architectural fit
with Aperas's own stated philosophy
(`Aperas-design.md`'s "Metaphysical foundation," `Aperas-kg-foundational-design.md` §1): a boundary
agent is supposed to "sample the fluid core (Apeiron) and project it into rigid, type-safe
structures (Peras)." TerminusDB forces that projection to happen *twice*, redundantly and
inconsistently — once into TerminusDB's own JSON-LD schema (a Peras TerminusDB owns), and again
into whatever shape each of WOQL/GraphQL/the Document API happens to hand back (three different
Perata for the identical `source`/`target` fields, live-verified: plain string, plain-string-with-
wrapped-literals, and a full-IRI-bearing nested object, respectively). ApeironNgn's actual promise
is collapsing that to one Peras: the OOP class *is* the schema and *is* the traversal mechanism,
so there's no second, independent projection layer for the query language to disagree with the
class about. "Form is not a rigid cage, but a temporary, playful instrument" (`Aperas-design.md`)
— a class boundary the application itself owns is exactly that; a schema language plus three
independently-shaped query surfaces on top of it is the opposite.

## 2. What confirmed this isn't incidental

Full technical catalogue in `Aperas-kg-foundational-design.md`; summary of what was live-verified
this session, all against the real `aperas` TerminusDB instance:

- `List`-typed fields (this project's actual containment shape — order is semantically meaningful)
  give plain `triple()` no shortcut in *either* direction: reverse lookup finds nothing at all;
  forward lookup binds to TerminusDB's internal `Cons` cell, not the member value, requiring an
  explicit `rdf:first`/`rdf:rest` walk (§3).
- `@abstract` classes don't materialize as GraphQL interfaces — any field typed to one loses
  subclass-specific data without the `_json` escape hatch (§2).
- Node-by-node ("paired") tree reconstruction, benchmarked live across all three APIs, lost to
  bulk fetch by 47–240x — not because any one API is badly built, but because the heterogeneous-
  node problem (no API can generically ask "whatever fields this type has" without knowing the
  type first) forces per-type fragment queries plus client-side stitching, work TerminusDB's bulk
  path already does server-side (§2).
- Two real upstream bugs, filed and confirmed live: the cross-store `bundle`/`unbundle`
  incompatibility (`terminusdb/terminusdb#2509`) and the `List`-typed `@unfold` gap
  (`terminusdb/terminusdb#2512`) — both already cited in `Aperas-design.md`'s Phase 4 contingency,
  now with the second one's root cause traced precisely (§3: property-level unfold never reaches
  into the `Cons` chain the way class-level `@unfoldable` does).
- A real server-side panic (byte-index string truncation landing inside a multi-byte UTF-8
  character), reproduced twice against real content, not a one-off.

## 3. The concrete design

- **Engine: Oxigraph**, not a from-scratch build. A mature, embeddable (in-process, Rust) RDF
  store with genuine SPO/POS/OSP multi-index storage — the original Phase 4 sketch called for "a
  small, embeddable Rust graph engine... no general Datalog/Prolog solver, no auto-generated
  GraphQL schema"; Oxigraph is a real, off-the-shelf instance of exactly that shape, not a gap
  ApeironNgn needs to fill from zero.
- **Ordered containment: reified triples, not `rdf:List`.** Every child carries its own `parent`
  and `siblingIndex` as direct, bounded-degree triples (`(child, parent, P)`, `(child,
  siblingIndex, N)`) instead of a `Cons`-chain collection. This isn't a workaround for TerminusDB's
  specific `List` bug — it sidesteps the entire class of problem RDF's native list encoding has:
  no random access, no reverse index on membership, because a list is fundamentally a linked
  structure rather than a set of ordinary triples. Both `parent` (in-degree ≤ 1, structurally, for
  a tree) and `siblingIndex` are cheap in *either* direction on Oxigraph's ordinary indexes; order
  is recovered by sorting an already-fetched set, not by traversing a chain.
- **Bulk/tree fetch: self-implemented, paired, level-wise.** A recursive reverse-index walk —
  fetch a node's own fields, reverse-query its children via the `parent` index, sort by
  `siblingIndex`, recurse — the same "control structure paired with data structure" model examined
  earlier against TerminusDB, except now viable: each hop is an in-process lookup, not an HTTP
  round trip, so the 47–240x penalty node-by-node paid under TerminusDB doesn't apply here. This is
  real, new engineering surface — TerminusDB's bulk GraphQL path did this stitching for free;
  ApeironNgn has to build it, deliberately, as the trade for owning the shape.
- **Schema: the OOP class itself**, not a declarative schema language. The class enforces shape on
  every read/write; an unmatched read/write either fails hard or fills the gap, per the class's own
  policy — no second, independently-evolving schema representation for the class to drift from.
- **Field shape: declared once, per concrete class — not inferred from data.** A `Set`-typed field
  holding exactly one value must stay distinguishable from an `Optional` field that happens to be
  set — a plain match-count check can't tell them apart. The fix: a small table each concrete class
  owns, declaring per field its **cardinality** (`one` / `optional` / `set` / the special
  `orderedContainment` used only by `children`) and, for node-shaped values, its **storage kind**
  (`reference`, a bare id — `links`/`parent`/`root`; or `embed`, a full nested object — `props`,
  since `Prop`/`StringProp` are `@subdocument`). `fieldValue` consults this table
  for known fields, falling back to match-count inference only for a field the table doesn't cover
  (fine for ad hoc exploration, not relied on for anything round-tripped). Deliberately not derived
  from TerminusDB's `schema.json` — already shown to drift from the live schema (§4's `Link` fix,
  the `ordered`/`start` field discrepancy) — authored directly against the concrete classes
  ApeironNgn actually has, the same "no second, independently-evolving schema representation"
  stance as the bullet above, extended from *presence* to *shape*. It's also the direct
  prerequisite for JSON-LD export/dehydrate (rehydration's inverse, not yet built): serializing a
  node back to a document needs exactly this same fact — bare value vs. array, id string vs.
  embedded object — which exists nowhere queryable in the engine today. Concretely, for two of the
  five concrete classes:

  ```ts
  BlockNode: {
    blockId: { cardinality: 'one' },                              // literal
    type:    { cardinality: 'one' },                               // literal
    title:   { cardinality: 'one' },                               // literal
    text:    { cardinality: 'optional' },                          // literal
    parent:  { cardinality: 'optional', storageKind: 'reference' }, // -> BaseNode
    children:{ cardinality: 'orderedContainment', storageKind: 'reference' }, // -> BlockNode
    links:   { cardinality: 'set', storageKind: 'reference' },      // -> Link (bare id)
    props:   { cardinality: 'set', storageKind: 'embed' },          // -> Prop (full object)
  }
  Link: {
    target:    { cardinality: 'one', storageKind: 'reference' },    // -> BaseNode
    predicate: { cardinality: 'one' },                              // literal
  }
  ```

  So a `BlockNode` with one `links` entry serializes as `"links": ["Link/xyz"]` (array, bare id),
  never `"links": "Link/xyz"`; one `props` entry serializes as `"props": [{"@id": ..., "@type":
  "StringProp", "key": ..., "value": ...}]` (array, full object); `title` always serializes as a
  bare string, never `["…"]`, regardless of how the underlying `match()` call happens to shape its
  result. `ArtifactNode`/`FolderNode` follow the same pattern for their own scalar fields
  (`one`/`optional`), each inheriting `links`/`props`/`title`/`text` from `BaseNode`/`TreeNode` as
  before; `ArtifactNode` alone also inherits `type`/`parent`/`children` from `BlockNode` (§4 Step 7
  — originally a separate `root` reference field; `ArtifactNode` was later merged with its own root
  document outright, `FolderNode` deliberately left out of that merge — see Step 7 for why).
- **Schema = class — implemented and live-verified, not just designed.** One real class per
  concrete type, not the single generic function `wrapNode` used to be:
  `web/src/lib/apeironNgn/shape.ts` (the `SHAPE` tables), `classes.ts` (`BlockNode`, `ArtifactNode`,
  `FolderNode`, `Link`, `StringProp`, each carrying only its own `static SHAPE`), and `node.ts`'s
  `wrap(store, id)` (replacing `wrapNode`), branching into three parts:
  - **Constructor / registry lookup.** `CLASS_BY_KIND`, keyed by the id prefix (`"BlockNode"` →
    `BlockNode`, etc., via `vocab.ts`'s `nodeKindFromId`) — the one generic dispatch point left,
    keyed directly off the id scheme `snowflake.ts` already mints ids by. One real wrinkle found
    implementing this: a `props` subdocument's own id is shaped `${parentId}/props/StringProp/
    <snowflake>` — the *owning* node's class prefix leads the string, so a naive leading-prefix
    check would misclassify every `StringProp` as whatever its parent happens to be.
    `nodeKindFromId` checks for `/props/ClassName/` first, falling back to the leading prefix
    otherwise — live-verified against a real `props`/`links` read (below).
  - **`get` trap**, reading through the class's own `SHAPE`, not match-count inference. A known
    field decodes per its declared cardinality; an unknown field returns `undefined` (safe for ad
    hoc exploration, not relied on for anything round-tripped). Live-verified: a synthetic
    `BlockNode` with exactly one `props` entry and one `links` entry — the exact case that used to
    misbehave — now reads back as real one-element arrays (`Array.isArray` true), each entry
    correctly resolved to its own `key`/`value` or `target`/`predicate` fields.
  - **`set` trap — the first real write path into the `Store`.** Validates the assigned value
    against `SHAPE`, then translates to `store.delete`/`store.add` calls. Live-verified for every
    shape: a literal `one` field, an `optional` reference, a `set` of existing references, a `set`
    of `embed`-kind entries (minting a fresh `StringProp` id and writing its own literal fields),
    `orderedContainment` reindexing (replacing an existing `children` set correctly detaches the
    dropped members — no stray `__parent`/`__siblingIndex` quads left behind), an unknown field
    throwing, and clearing a required field throwing.
  - **Mere schema, deliberately — see §4's rollout step 3.** A class here is field access and
    shape enforcement only, no behavior. That's what makes migrating a free function easy —
    pointing `project.ts`'s serializer at a class instance instead of a generic `wrap()` result is
    a one-line change, not a simultaneous rewrite into method form. But leaving it there forever
    would contradict §1's own mental model ("ties data structure directly with control
    structure") — folding migrated functions into methods is its own later rollout step, not a
    permanent aside.
- **Query: `a.b.c` as literal property access, not a separate query language** — implemented as a
  `Proxy` per node (`web/src/lib/apeironNgn/node.ts`), live-verified against the entire real
  `AperasKG/Apeiron/` mirror (`apeironNgnSmokeTest.ts`: every artifact's tree, node-for-node,
  against the raw JSON-LD as ground truth). The earlier framing of this as needing
  `valueOf`/`Symbol.toPrimitive`-style deferred-forcing machinery, isomorphic to a Gremlin
  traversal builder, was written while it was still an open question whether Oxigraph's Node
  binding would be sync or async — it's confirmed sync (`oxigraph` skill), so there's no I/O gap
  for a Promise-like wrapper to hide, and no such wrapper exists in the implementation. The
  laziness that actually matters survives anyway, at the right granularity for free: `.b` returns
  a fresh Proxy naming its neighbor via the one triple needed to identify it — none of *that*
  neighbor's own fields are read until something asks for them — so `a.b.c` costs exactly two
  `store.match()` calls, not a subtree's worth. Getting this granularity right was still the part
  that most needed care; it just didn't need the mechanism originally assumed.
- **Versioning: git-native, already built, not new work.** Per the existing Phase 4 plan
  (`Aperas-design.md`): `AperasKG/Apeiron/` already lives inside a real git repository, so a
  JSON-LD write followed by an ordinary `git commit` *is* the version control — no bespoke
  commit-layer to reimplement.
- **Concurrency: explicitly not supported, by design, not by omission.** Each Aperas instance owns
  its own local store — no shared mutable database, no locking, no transaction isolation to build.
  Cross-instance sync happens via `git merge` on the underlying JSON-LD, the same way code merges.
  `reconcile.ts`'s Gestalt (Ratcliff/Obershelp) matcher — already built, already live-verified, used
  today for re-ingestion after a local edit — is structurally the same problem as cross-instance
  merge-conflict resolution on structured content, a reuse candidate rather than new mechanism to
  invent.
- **Search: still needs a secondary index, regardless of engine.** Regex/free-text search has no
  index-servable shortcut in general, under TerminusDB or Oxigraph alike — this isn't a cost the
  switch avoids, just one that stays constant either way.

## 4. Rollout sequence

1. **ApeironNgn development — implemented, live-verified against the real mirror.**
   `web/src/lib/apeironNgn/` (`vocab.ts`/`store.ts`/`node.ts`), checked via
   `apeironNgnSmokeTest.ts` against every artifact in `AperasKG/Apeiron/` (23 artifacts, 1594
   BlockNodes, node-for-node against the raw JSON-LD as ground truth — no TerminusDB dependency at
   all, by design).
   - **Storage: in-memory only, deliberately, for now.** Checked live (`oxigraph` skill,
     `references/persistence.md`): the Node/WASM build has no RocksDB, no on-disk option at all —
     `Store` is pure in-process memory, rehydrated from `AperasKG/Apeiron/`'s JSON-LD at process
     start (`store.ts`'s `rehydrateStore`). Decided: stay here rather than reach for `pyoxigraph`
     (native, RocksDB-backed, but a second language/process needing its own projection bridge to
     the Node UI) or a native non-WASM Node binding (real engineering work of its own) — revisit
     only once the KG's actual size makes in-memory rehydration or working-set size a real problem
     (GB-level), not before. No separate JS-level cache on top of it, for the same reason — one
     memory tier, not two, kept simple until something actually demands otherwise.
   - **The prop-access interface.** §3's `a.b.c` traversal (`node.ts`'s `wrapNode`) — see §3's
     updated note on why this ended up as a plain per-node `Proxy` rather than the Gremlin-
     isomorphic deferred-execution model originally sketched.
   - **The `export.ts`/`Link` gap — fixed and live-verified, not just noted.** `INSTANCE_CLASSES`
     now includes `Link`; `apeironNgn/store.ts`'s `INSTANCE_FILES` reads it too, so a `Link`'s own
     `target`/`predicate` rehydrate correctly instead of leaving a dangling reference. The fix
     needed more than adding a name to a list: `BlockNode` and `Link` form a genuine two-way
     reference cycle (`BlockNode.links` -> `Link` id, `Link.target` -> a `BlockNode` id — the same
     cycle `crud.ts`'s `findLinkIdsTargeting` already documents for deletion), and TerminusDB
     checks referential integrity per commit, not across commits — live-verified: a `BlockNode`
     referencing a not-yet-existing `Link` id fails even when that `Link` is created in the very
     next separate call, but succeeds when both are submitted together in one commit, in either
     order. `importJsonLd` now commits `BlockNode`+`Link` together as one group
     (`IMPORT_COMMIT_GROUPS`) rather than as two separate per-class calls. Round-trip verified live:
     created a real embedded-literal `Link` (server-assigned id, same shape `artifacts.ts`'s
     `resolveBlockLinks` produces in normal use) referencing a target `BlockNode`, exported it,
     deleted both from TerminusDB, re-imported from the mirror, and confirmed both documents came
     back at their original ids with the reference intact in both directions.
2. **Migrate Aperas scripts one by one, comparing output against the TerminusDB version per
   script.** Incremental, verified, not a big-bang cutover — each command gets its own ApeironNgn
   implementation, run against the same real data, and diffed against its existing TerminusDB-
   backed output before being considered migrated — the same live-verification discipline already
   standard here (`kg:track && kg:ingest && build && verify:phase0 -- --db`), applied to the
   migration itself, rather than skipped for it. `client.ts`/`crud.ts`/`woql.ts`/`graphql.ts` are
   replaced wholesale by ApeironNgn's own `store.ts`/`node.ts`/`tree.ts` (etc.), not ported
   function-by-function — they don't appear as line items below. `Assertion` (`BaseEdge`) is out of
   scope entirely — `kg:assert`/`kg:assertions`/`kg:unassert` are not being migrated.
   - **`kg:tree` — done, diffed clean.** `apeironNgn/tree.ts` (`renderTree`, ported line-for-line
     from `kgCli.ts`'s `printTree`) plus `kgTreeNgn.ts` (`npm run kg:tree:ngn`), fully synchronous —
     no round trips to hide behind `await` at all, unlike every TerminusDB-backed path in §2's
     benchmark. Diffed byte-for-byte against `kg:tree` across: the full 1048-line default tree from
     root, a specific artifact, `--depth`, `--no-holders` (with a real temporary holder node), and
     `--unfolded` (with a real temporarily-unfolded artifact) — identical in every case. Path
     resolution here is intentionally narrower than the original: a full node id, or an *exact*
     `path` literal match — not `kg:resolve`'s full deep-path grammar (`.`/`..`/prefix matching/
     bare snowflake codes), which is its own separate future migration, not duplicated into this
     one. Not yet wired to replace `kg:tree` itself — kept as a separate script until more of the
     corpus and more commands have exercised it.
   - **`kg:search` — deliberately not next.** Blocked on §5's secondary-index question, on
     purpose: a plain store-scan migration now would just be thrown away once a real full-text
     index (e.g. Tantivy) lands. Revisit once that's chosen, not before.
   - **`kg:path` — done, diffed clean.** `apeironNgn/path.ts` (`resolveIdToPath`, ported from
     `nodeRef.ts`) plus `kgPathNgn.ts` (`npm run kg:path:ngn`), reusing `resolveTreeRef` for ref
     resolution and `nodeRef.ts`'s own `slugify` directly (pure, no TerminusDB dependency — nothing
     to port). Verified via `compareMigration.ts` across a leaf block several levels deep, a root
     block, an `ArtifactNode`/`FolderNode` addressed directly, a nonexistent-id error path, and 15
     random `BlockNode`s from across the corpus — identical in every case. One real gap in the
     harness itself, found and fixed getting here: it only compared `stdout`, silently missing
     `kg:path`'s error paths (`console.error`, non-zero exit) entirely — now compares `stdout`,
     `stderr`, and exit status, with each migrated script's own identifying tag
     (`[Aperas KG CLI]` vs. `[ApeironNgn kg:path]`) normalized out of the comparison (only the tag,
     not the rest of the line — confirmed live that a genuine mismatch still gets caught, not
     masked).
   - **`kg:resolve` — done, both tiers, diffed clean.** `apeironNgn/resolve.ts` (the deep-path
     grammar — `.`/`..`/leading `/`/`--base`/exact-then-prefix title matching — minus
     `--create-holder`) plus `apeironNgn/resolveCreate.ts` (the write-extended grammar,
     `--create-holder`/`--titles` included: single-heading creation under existing content, and
     `createImaginedPrefix`'s "imagine the whole chain" — new nested `FolderNode`s down to a new
     `ArtifactNode` down to a new `BlockNode`, anchored at whichever ancestor already exists),
     unified by `kgResolveNgn.ts` (`npm run kg:resolve:ngn`) dispatching on `--create-holder` the
     same way `kgCli.ts` does. A single `path`-literal `Store` lookup replaces `nodeRef.ts`'s
     separate artifact-then-folder tries (`path` is only declared on those two classes, so any
     match is inherently one or the other); `--create-holder`'s new nodes are built bottom-up
     (artifact first, then each wrapping folder) and attached to their anchor by id, the same
     "create then attach" shape `kgLinkNgn.ts` uses for `Link`. Read-only tier diffed via
     `compareMigration.ts` across a deep exact/prefix path, `--base` relative descent, multiple
     `<path>` args in one call, a bare snowflake code, `..` navigation (both BlockNode-tier and
     artifact/folder-tier), a full node id, and the ambiguous/not-found error cases — identical in
     every case. `--create-holder` isn't diffable against a live TerminusDB run the same way (it
     writes) — verified instead against scratch copies of the real mirror (both the single-heading
     and imagine-whole-chain cases, plus the "no title supplied" and "ArtifactNode already has a
     root" error cases), checking the resulting JSON-LD structurally against the pre-write original
     — see the "Write-path verification" bullet below for why scratch copies, not live diffing, is
     this step's actual verification method from here on.
   - **`kg:project` — done, diffed clean; non-dry-run (real write) mode also implemented.**
     `apeironNgn/project.ts`
     (`projectArtifactToMarkdown`/`projectFolderToReadme`) plus `kgProjectNgn.ts`
     (`npm run kg:project:ngn -- <path> --dry-run`), reusing `project.ts`'s own
     `serializeBlock`/`renderChildren`/`withFrontmatter` directly — a `Proxy`'s property reads are
     indistinguishable from a plain object's to that code, so nothing there needed porting, only a
     new pair of fetch functions in place of `graphql.ts`'s tree fetchers. A FolderNode's mixed
     BlockNode/FolderNode/ArtifactNode `children` are told apart by `nodeKindFromId`, not GraphQL's
     `_type` tag. Diffed clean against 17 of the 18 real tracked artifacts plus the root folder and
     a nonexistent path; the 18th (`Aperas-design.md`) fails on the TerminusDB side with a real
     `API Error Code: 500` at that document's size — the GraphQL bulk-fetch path breaking down at
     scale is exactly §1's stated reason for this whole migration, not a gap in this port (ApeironNgn
     itself projects the same document in under a second, no error). Non-dry-run mode (writes the
     artifact file / folder `README.md`) was added later, once `kg:track:ngn`/`kg:ingest:ngn` had a
     real corpus run to project from — see "First real-corpus run" below.
   - **Write-back path — implemented and round-trip verified.** `apeironNgn/dehydrate.ts`'s
     `dehydrateToJsonLd`, rehydration's inverse: rewrites a whole class's JSON-LD file at a time
     from the `Store`'s current content, using §3's `SHAPE` tables to know exactly how each field
     serializes — same full-file-rewrite behavior as `export.ts` against TerminusDB, no git commit
     (that stays a separate, existing step). Verified live: rehydrated the entire real
     `AperasKG/Apeiron/` mirror, dehydrated it straight back out to a scratch directory, and
     compared every one of the 1056 real documents (1037 `BlockNode`, 18 `ArtifactNode`, 1
     `FolderNode`) against the original — zero semantic mismatches (`Set`-field member order, e.g.
     `props`, differs harmlessly, since a `Set`'s order was never meaningful). One real bug found
     and fixed along the way: `xsd:dateTime`-typed literals get canonicalized by Oxigraph on
     read-back per the RDF spec, live-verified to silently rewrite `"...23:02:27.480Z"` to
     `"...23:02:27.48Z"` — a real string mutation, not a display quirk. Fixed by not tagging date-
     looking strings with that datatype at all (`vocab.ts`'s `encodeLiteral`); they were never
     decoded any differently from a plain string anyway, so the distinction cost real fidelity for
     no actual benefit.
   - **`kg:unfold`/`kg:fold` — done, diffed clean.** `apeironNgn/unfold.ts`'s `setUnfolded` plus
     `kgUnfoldNgn.ts`/`kgFoldNgn.ts` (`npm run kg:unfold:ngn` / `kg:fold:ngn`) — the one boolean
     field, set through the `set` trap and dehydrated immediately. Diffed clean against real
     not-found/usage-error cases (safe: no mutation on that path); the actual set/unset write is
     verified via scratch copies (see below), since running it for real against the default paths
     would mutate live TerminusDB or the real mirror.
   - **`kg:title`/`kg:link` — done, verified via scratch.** `kgTitleNgn.ts`/`kgLinkNgn.ts`
     (`npm run kg:title:ngn` / `kg:link:ngn`), reusing `collectBlockNodes`'s ApeironNgn port
     (`apeironNgn/collect.ts`) and the same interactive line-reader as the TerminusDB version
     (moved to a shared `lineReader.ts` so both sides import it without triggering `kgCli.ts`'s own
     `main()` as a module-load side effect). Dehydrates after each accepted answer, matching
     `kgCli.ts`'s own per-answer/per-block write immediacy — an interrupted session keeps whatever
     it already gathered, not just whatever a single end-of-run write would have caught. `kg:link`
     creates each new `Link` directly (mint an id, `wrap()` it, set `target`/`predicate`, attach by
     id) rather than handing `node.ts`'s `set` trap a `{"@type": "Link", ...}` literal — its
     auto-minting path always shapes a fresh id as `.../props/<type>/...`, correct for `props`'
     `StringProp` subdocuments but wrong for a top-level `Link`; sidestepped here rather than
     widened, the same "create then attach" pattern `resolveCreate.ts`'s holder creation already
     uses. Verified against empty-stdin real-TerminusDB runs (identical candidate listing/summary
     format, zero mutation) plus scratch-copy runs exercising a real accepted title and a real new
     `Link` (correct top-level shape, correct field values).
   - **`kg:track`/`kg:ingest` — done, verified via scratch. The big one.**
     `apeironNgn/artifacts.ts`/`apeironNgn/folders.ts` plus `kgTrackNgn.ts`/`kgIngestNgn.ts`
     (`npm run kg:track:ngn` / `kg:ingest:ngn`). `astParser.ts`/`reconcile.ts`/`snowflake.ts` are
     reused completely unchanged — already pure, DB-less logic, exactly as anticipated; so are
     `folders.ts`'s own `buildFolderTree`/`collectFolderPaths`/`countFolders` (every existing-state
     lookup they need arrives as a plain `Map` argument, not a client call, so the TerminusDB
     coupling was only ever in their *caller*). The real new work is smaller than a whole-document
     TerminusDB replace needs: a `Store` write mutates one field at a time in place, so nothing has
     to be reconstructed just to survive the call the way `artifacts.ts`'s `normalizeArtifactDoc`
     does — a rename/tombstone is a two-or-three-field assignment, not a full-document rebuild.
     Where the original omits a field from its replacement doc to clear it (`text`/`props`, when a
     fresh parse yields none), the equivalent is an explicit `undefined` assignment through the
     same `set` trap. The old (already-ingested) tree, needed for reconciliation, is materialized
     from the `Store` into the exact plain-object shape `reconcile.ts` already expects (`type`/
     `title`/`text`/`children`/`unfolded`/`blockId`, `links` as bare ref-id strings) — `reconcileTree`
     doesn't care whether that shape came from a GraphQL fetch or a `Store` walk. Verified on the
     real corpus via scratch copies: a real re-track (on-disk content that had already drifted from
     its last-tracked hash) touched exactly the 2 expected fields on the 1 affected `ArtifactNode`,
     nothing else; a real re-ingest of that and two other artifacts whose content had drifted since
     their last ingestion (found, not manufactured — a genuine backlog in the real corpus) produced
     correct reconciliation stats (added/removed/unchanged) and a rebuilt tree whose heading
     structure matches the real Markdown file exactly, heading-for-heading; a rehydrate of the
     freshly-written scratch mirror, dehydrated straight back out, reproduced it with zero semantic
     mismatches and zero dangling references.
   - **Write-path verification: scratch copies, not live diffing, from `kg:unfold` on.**
     `compareMigration.ts` runs the real default-path CLI on both sides — safe for a read, but a
     write-capable ApeironNgn script run that way mutates the real `AperasKG/Apeiron/` mirror on
     *success*, not just on a bug (confirmed: the auto-mode permission classifier itself declines a
     bare `kgXNgn.ts` invocation for a script it can't tell won't write). From `kg:unfold`/`kg:fold`
     onward, a write path is instead exercised against a throwaway copy of the real mirror
     (`rehydrateStore(scratchDir)`/`dehydrateToJsonLd(store, scratchDir)`, both already accept a
     directory override), checked structurally (order-independent, same as the dehydrate round-trip
     check above — key order is never semantically meaningful) against the pre-write original. The
     one still-live-safe case is a script's *declining* paths (not-found, ambiguous, usage error) —
     those never reach a write, so they're still diffed directly against real TerminusDB.
   - **Not really "migrated" so much as retired:** `kg:export`/`kg:import` exist specifically to
     bridge TerminusDB↔mirror — once ApeironNgn *is* the substrate, their reason for existing goes
     away rather than needing a ported equivalent.
   - **Diff harness, built for reuse.** `apeironNgn/compareMigration.ts` — runs a `kgCli.ts`
     subcommand and its ApeironNgn equivalent with the same args, strips TerminusDB-only leading
     infra noise (the connection/schema-apply banner, and `graphql.ts`'s per-query "Executing query
     against..." line — both absent under ApeironNgn by construction, present under every TerminusDB
     command regardless of which one runs), and diffs stdout, stderr, and exit status, with each
     migrated script's own identifying tag normalized out of the per-line comparison. Replaces the
     by-hand bash diffing `kg:tree`'s migration used; every script in this list re-verifies against
     it instead of a fresh ad hoc comparison each time.
3. **Fold migrated functions into class methods — done, verified.** Real per-class accessor
   properties replaced the `Proxy` (`node.ts`'s `wrap()`, `Object.seal`ed instances); the class
   hierarchy went real (`ApeironInstance` -> `BaseNode` -> `TreeNode` -> `{BlockNode, ArtifactNode,
   FolderNode}`, `Link`/`StringProp` as leaf subdocs), closing §1's "ties data structure directly
   with control structure" model. See "Class hierarchy refactor" and "Classification" below for
   exactly what changed and where every migrated function landed.
4. **Archive the TerminusDB-based scripts once every script has migrated and verified clean.**
   Archived, not deleted — kept for reference/rollback, not discarded.
5. **A shared service process — implemented and running, not deferred.**
   `web/src/lib/apeironNgn/service.ts` holds one `rehydrateStore()`'d `Store` in memory across CLI
   calls instead of every `kg*Ngn.ts` invocation rehydrating/dehydrating cold, closing the
   per-invocation setup cost this bullet originally measured (~1.6s wall-clock per call, mostly
   Node/tsx spawn and TypeScript transpilation, not the ~256ms rehydrate itself — a different
   concern from §5's "what happens at GB scale" working-set question). The concurrency/shared-
   mutable-state tension §3 opted out of ("no shared mutable database, no locking, no transaction
   isolation to build") is resolved here by an in-process request queue (`enqueue()`), not a
   database-level lock — every request across every connection is serialized strictly one at a
   time, so the "no locking" stance in §3 still holds; it's this one owning process, not the store
   itself, that enforces it. Transport: a Unix domain socket (`node:net`), auto-started on demand
   by `serviceClient.ts#ensureServiceRunning` with a lock file (`serviceLock.ts`) claiming ownership
   and guarding the start race. Flushes to `AperasKG/Apeiron/`'s JSON-LD mirror every 10s if dirty,
   or immediately on a request's `flush: true`; a second, independent interval/dirty-flag pair does
   the same for `Profile`/`TreeView`'s own gitignored `.state/` mirror
   (`Aperas-treeview-design.md` §8 — expand/collapse churns more often than content edits, tuned
   separately rather than riding the content mirror's cadence). Exits after 30 idle minutes or on
   SIGTERM/SIGINT, flushing both if dirty either way. **The staleness story — solved.** The service
   still holds one `Store` snapshot from whenever it was last (re)hydrated, with nothing that
   *automatically* notices `AperasKG/Apeiron/` changing underneath it (e.g. a `git pull` landing
   someone else's commit) — but a manual restart is no longer the only fix: `kg:reload`
   (`{ op: 'reload' }`) flushes both dirty flags first, then rehydrates a fresh `Store` and swaps it
   in, live, without killing the process — the revived TDB-era `kg:import`'s equivalent
   (`kg:export` stays retired; there's no second store to export *to* anymore). Every op that reads
   the store's current content also takes its own `reload: boolean`, the reciprocal of a mutating
   op's `flush`: `flush` forces a sync *out* immediately after a write, `reload` forces a sync *in*
   immediately before the op runs — one round trip instead of two, and safe to combine with a
   mutation in the same request (`reload` then the write then `flush`) since `reloadStore()` flushes
   any dirty work first rather than discarding it. That's not just the read-only trio
   (`kg:tree`/`kg:project`/`kg:path`) — `kg:track`/`kg:ingest`/`kg:unfold`/`kg:fold`/`kg:resolve` all
   take it too, letting a write pick up an external change before it runs rather than needing a
   separate `kg:reload` first. The two exceptions are `kg:title`/`kg:link`'s per-answer submission
   ops (`setBlockTitle`/`addBlockLink`) — each is one sub-step of an already-in-progress interactive
   session, where reloading mid-loop would invalidate the `blockId`s the session's own candidate
   list (`titleCandidates`/`linkCandidates`, which *does* take `reload`, for the same one-round-trip
   reason as everything else) already handed back.

   **Flushing safely: a divergence guard, and how to resolve a real conflict.**
   `dehydrateToJsonLd`/`dehydrateStateToJsonLd` are blind full-file replaces, not merges — every
   flush overwrites a managed `.jsonld` file with exactly (and only) what's currently in memory. That
   makes any flush capable of silently destroying an external write (another process's `git pull`, a
   hand-edit) that landed on a mirror file while this service held its own unflushed local mutation:
   flushing first, as `reload` used to do unconditionally, clobbers the external content before ever
   reading it. `flushIfDirty`/`flushStateIfDirty` guard against this with a content-hash stamp per
   managed file, taken after every read or write — a flush first checks whether the file's current
   hash still matches what this process last saw, and refuses (throws, nothing written, the pending
   mutation stays `dirty`) on a mismatch instead of overwriting. Keyed on the hash, not the `dirty`
   flag alone: `dirty` by itself is the ordinary, harmless case (a pending local edit, no external
   activity at all) — only an actual divergence is worth refusing over. This sits at the flush
   chokepoint, so it protects every path that flushes: the timers, any op's `flush: true`, and
   `reload`'s own internal flush.

   A genuine conflict — both `dirty` and a real divergence — has no automatic resolution (there's no
   merge capability here, deliberately, matching §3's "no shared mutable database" stance); it takes
   an explicit choice, made through one of two symmetric primitives. `kg:reload --discard`
   (`{ op: 'reload', discard: true }`) keeps the external change: skips the flush entirely rather
   than trying and failing, drops the pending local mutation, and rehydrates fresh from disk as-is.
   `kg:flush --clobber` (`{ op: 'flush', clobber: true }`) keeps the local mutation instead: writes
   current memory over disk unconditionally, no dirty check, no divergence check, discarding whatever
   external content was there. `kg:flush` is otherwise a new, minimal standalone op — the same
   guarded flush every mutating op's own `flush: true` already triggers, but on demand and
   independent of any specific mutation, useful on its own just to *learn about* a conflict (it
   throws) without the side effects of running an unrelated op to get there. Neither `discard` nor
   `clobber` is ever implied by an op's own bare `reload`/`flush` flag — both stay opt-in, deliberate,
   spelled out at the call site, since silently picking a side would be exactly the kind of surprise
   the guard exists to prevent in the first place. Named `clobber`, not `force`: `npm run kg:flush
   --force`, run without npm's own `--` separator, has npm intercept `--force` as one of *its* CLI
   flags rather than forwarding it to the script's argv — the flush then runs unclobbered and hits
   the guard, with no indication anything was misrouted beyond npm's own generic force-flag warning.
   `clobber` isn't an npm option, so it always reaches the script regardless of invocation style.

   A stop (`SIGTERM`/`SIGINT`) still has to complete no matter what, so it can't defer to that same
   deliberate choice: `shutdown()` tries each guarded flush independently (a divergence in one mirror
   must not skip the unrelated other) and catches whatever either throws — logged, then the process
   exits regardless, accepting the local mutation as lost on this one path rather than either hanging
   or (the bug this closed) letting the flush's rejection go unhandled while `clearLock()`/
   `process.exit()` ran anyway, silently discarding the same pending work with no trace of it at all.

### Step 3: fold migrated functions into class methods — implemented, verified

**Mechanism: real accessors, not `Proxy`.** `node.ts`'s old `get` trap returned `undefined` for
any prop not in a class's `SHAPE` table — a method would have silently resolved to `undefined`
through it instead of being called. Fixed by dropping the `Proxy` entirely: `wrap()` is now
`const instance = new (classForId(id))(store, id); Object.seal(instance); return instance;`, and
each leaf class gets real `get`/`set` accessor properties generated once per class at module load
(`node.ts`'s `defineAccessors`, closing over each field's name and `FieldSpec`, calling the same
`readField`/`writeField` helpers the old traps used). `Object.seal` is what preserves "an unknown
field read returns `undefined`, an unknown field write throws" without any trap logic — a sealed
instance rejects a brand-new own-property in strict mode. Methods are ordinary prototype methods
now — `this.title`/`this.children` inside one hit the real accessor directly, no receiver-binding
to reason about. One accepted behavior change: an unknown-field write's error is now a generic
strict-mode `TypeError` (`Cannot add property 'x', object is not extensible`) instead of the old
custom `ApeironNgn: 'x' isn't a declared field on Y.` message — an internal-invariant check a
script author would hit while developing, not a documented CLI-facing contract. (The alternative
considered — keeping the `Proxy` and adding a `Reflect`-based method fallback in its `get` trap,
binding a matched method to the receiver — was rejected: a smaller diff, but a subtler mechanism
to carry forward for the receiver-binding, plus an extra `prop in target` check on every field
access, for no real benefit once the accessor approach was confirmed to work.)

`classes.ts` no longer exists as a separate file — merged into `node.ts`. The classes needed to
call back into `wrap()` for recursive hydration/reconciliation (`BlockNode.hydrateFromParsed`,
etc.), and `wrap()` needs `classForId`, so keeping them in two files would have created a real
circular import between them for no benefit; one cohesive module (the class hierarchy plus the
instantiation mechanism) removes the cycle by construction.

**Class hierarchy refactor — done.** The old flat hierarchy (every concrete class extending
`ApeironInstance` directly, `BASE_NODE_FIELDS` spread by hand into each leaf `SHAPE`) is now a real
hierarchy — real `extends`, one level per genuinely shared shape:

```
ApeironInstance          -- store/id only, no fields (unchanged)
  └─ BaseNode             -- unchanged: links, props, tombstonedAt, holder, unfolded
       └─ TreeNode         -- new: title, text, key (derived, not stored — see below)
            ├─ BlockNode    -- own: type, parent, children
            ├─ ArtifactNode -- own: path, fileHash, lastTrackedAt, ingestedHash, lastIngestedAt, root
            └─ FolderNode   -- own: path, children
```

`BaseNode` keeps exactly its current five fields — `title`/`text`/`key` move up to the new
`TreeNode` level, not into `BaseNode` itself, since `Link`/`StringProp` (below) don't participate
in the tree and shouldn't gain them.

- **`key`, derived, not stored.** `blockId`/`artifactId`/`folderId` are three separately-named
  literal fields today, but each is always identical to its own id's local part by construction
  (`writeBlockTree` sets `n.blockId = node.blockId` for the very id it just `wrap()`ped as
  `` `BlockNode/${node.blockId}` ``, same pattern for `artifactId`/`folderId`) — the old
  TerminusDB schema's own `@key: {Lexical, @fields: [blockId]}` directive already said as much:
  the field's whole purpose was generating the id, not carrying independent information. `TreeNode`
  replaces all three with one derived getter, `get key() { return this.id.slice(this.id.indexOf('/')
  + 1); }` — never its own triple, so nothing to keep in sync and nothing for `writeField` to
  validate. Every current reader of `blockId`/`artifactId`/`folderId` switches to `.key`.
- **`children`: already dissolved into `parent`/`siblingIndex` — not a new change, confirmed.**
  This was already true before this session (§3 "Ordered containment: reified triples, not
  `rdf:List`") — `children` has never been a stored triple in ApeironNgn; `node.ts`'s `childrenOf`
  already derives it by reverse-querying `PARENT_PRED`, sorted by `SIBLING_INDEX_PRED`. Restated
  here only because it's the working precedent for `key` above: both are derived, on-the-fly
  properties on top of the real stored facts (`parent`/`siblingIndex` triples; the id string
  itself), not independently-stored data that could drift from them.
- **`Link` becomes a subdocument, sibling to `Prop`/`StringProp`, not a top-level node.** Today
  `Link` is addressable (`Link/<snowflake>`, its own `Link.jsonld` file, `BASE_NODE_FIELDS` spread
  into `LINK_SHAPE` alongside `target`/`predicate`) purely because it inherited from `BaseEdge` ->
  `BaseLink` -> `BaseNode` in the old TerminusDB schema. Once `Assertion`/`BaseEdge` are gone (next
  bullet), nothing still needs `Link` to be independently addressable or to carry `links`/`props`/
  `tombstonedAt`/`holder`/`unfolded` of its own — it becomes exactly `Prop`'s shape of thing: `{
  target, predicate }` only, minted as `${parentId}/links/Link/<snowflake>` (mirroring `props`'
  `${parentId}/props/StringProp/<snowflake>`), `BASE_NODE_FIELDS.links`'s `storageKind` flipped
  from `reference` to `embed`. Checked live against the actual generic machinery, not assumed: both
  `dehydrate.ts`'s `decodeField`/`serializeDoc` (branches on `spec.storageKind === 'embed'`, already
  fully generic — not `props`-specific) and `store.ts`'s `encodeDoc` (recurses into any nested
  object carrying its own `@id`, also not `props`-specific) already do exactly the right thing for
  an embedded `Link` with zero new code — only `dehydrate.ts`'s `DEHYDRATE_CLASSES` and `store.ts`'s
  `INSTANCE_FILES` need `'Link'` removed (no more standalone `Link.jsonld`). This also directly
  removes the "create then attach" workaround `kgLinkNgn.ts`/`artifacts.ts`'s `resolveBlockLinks`
  both currently need (today's generic `mintEmbedded`-via-`writeField` auto-mint always shapes a
  fresh id as `.../props/<type>/...`, wrong for a top-level `Link` — moot once `Link` really is
  `storageKind: 'embed'`, since the existing generic embed-mint path becomes correct for it too).
  **Decided: `Link` sheds `BASE_NODE_FIELDS` entirely** — its shape becomes exactly `{ target,
  predicate }`, nothing else, matching `Prop`'s own minimal `{ key }`/`{ key, value }` shape. A
  side effect worth stating plainly: since `StringProp` already didn't spread `BASE_NODE_FIELDS`
  either, `BaseNode` (and everything it carries — `links`/`props`/`tombstonedAt`/`holder`/
  `unfolded`) ends up used only by `TreeNode` and its descendants once this lands; nothing else in
  the hierarchy extends it. Kept as its own level anyway (per the earlier instruction that
  `BaseNode` stays parent of `TreeNode`) — it still documents a real conceptual boundary
  ("participates in the links/props/lifecycle system") separate from `TreeNode`'s ("has a
  title and a position in the tree"), even though only one branch uses it today.
- **`Assertion`/`BaseEdge` are not migrated in any form — the capability is subsumed, not
  ported.** Previously "permanently out of scope" meant "no `kg:assert`/`kg:assertions`/
  `kg:unassert` port"; this finalizes it one step further — there is no ApeironNgn class for
  `Assertion`/`BaseEdge` at all, ever, because the thing they were for (recording a claim linking
  two nodes, with justification) is already fully expressible as ordinary artifact content: a
  `BlockNode` holding the claim in prose, with a wikilink resolving to a real `Link` at ingest time
  (the same mechanism `kg:ingest`'s `resolveBlockLinks` already uses for every other in-text
  wikilink) — e.g. "Through the analysis of this investigation, we conclude that
  `[X](../../reportX/sectionY)` is wrong." This is strictly more capable than the old model, not a
  reduced substitute: the justification *is* the surrounding prose (not a separate, easy-to-neglect
  field), and it projects to/from a real Markdown artifact for free (`kg:project`/`kg:ingest`
  already round-trip any `BlockNode` with a wikilink) — `Assertion` never had that, which is the
  concrete problem this resolves, not just a naming preference. Checked live: the real
  `AperasKG/Apeiron/Assertion.jsonld` has zero documents today (the basic-assertion-authoring work
  was only ever exercised by a synthetic edge in `verifyPhase0.ts`'s test harness, per
  `Aperas-basic-assertion-skill-design.md` §0) — nothing to migrate or convert, so finalizing this
  costs nothing. This also closes a real latent gap noticed while checking: `store.ts`'s
  `INSTANCE_FILES` still reads `Assertion.jsonld` on every rehydrate (its fields land as raw quads,
  since `encodeDoc` doesn't consult any class registry) while `dehydrate.ts`'s `DEHYDRATE_CLASSES`
  never writes it back out — today, any real `Assertion` doc would silently vanish on the next
  dehydrate. Removing `'Assertion'` from `INSTANCE_FILES` (alongside dropping it from
  `ID_PREFIX_RE`/`KIND_RE` in `vocab.ts`) closes the gap by removing the read path entirely, rather
  than by adding the write path back.

**Classification — as actually implemented.** A function folds onto a class only when a single
already-identified node is a natural `this` for it; a function that searches across the whole
store, or sweeps every node of a kind, stays free (it has no one node to be `this` until *after*
it runs). Each level gets only the methods whose governing field(s) — or whose need for a
title/position in the tree — actually live at that level; a subclass doesn't restate a fold its
parent already covers. One correction from the original proposal, caught while implementing:
`collectBlockNodes` folds onto `TreeNode`, not `BlockNode` — the starting node passed to it can be
any tree-positioned kind (an `ArtifactNode`/`FolderNode` root, not just a `BlockNode`), so it needs
`treeChildren`'s polymorphism the same way `renderTree`/`toPath`/`findChild` do; putting it on
`BlockNode` alone would have made it uncallable from the common `kg:title`/`kg:link` entry point.

- **`BaseNode` (`links`/`props`/`tombstonedAt`/`holder`/`unfolded` — used only by `TreeNode` and
  below now that `Link`/`StringProp` don't extend it):**
  - `unfold.ts`'s `setUnfolded(store, id, value)` → `node.fold()` / `node.unfold()`.
  - **New, not a fold of an existing function but the direct payoff of `Link` becoming
    `storageKind: 'embed'`:** `node.addLink(predicate, target)` →
    `this.links = [...(this.links ?? []), { predicate, target }]`. This is what actually replaces
    `kgLinkNgn.ts` and `artifacts.ts`'s `resolveBlockLinks`'s hand-rolled "mint a `Link/<snowflake>`
    id, `wrap()` it, set `target`/`predicate`, attach by id" — once `links` is embed-kind, the
    generic `mintEmbedded` path handles a fresh `{ predicate, target }` literal correctly on its
    own (already true for `props`), so the workaround both call sites used to need is gone
    entirely, not just moved. Verified live against a scratch copy: a fresh link mints as
    `BlockNode/<id>/links/Link/<snowflake>`, decodes back through `.links` as a real wrapped `Link`
    with `.target`/`.predicate` correct.
  - **A second real bug, found by a pointed question about id persistence, not by the standing
    test matrix (the real corpus has zero `BlockNode`s with any `links` today, so nothing had ever
    exercised this path live): re-ingesting a block with an existing `Link` silently destroyed it.**
    `reconcile.ts`'s `carryForwardFields` carries an unchanged block's `links` forward as *bare
    ref-id strings* (`toReconcileShape()`'s own output shape, `["BlockNode/.../links/Link/xyz"]`) —
    correct for the old `storageKind: 'reference'`, where a bare string was exactly what `writeField`
    expected. Once `links` became `storageKind: 'embed'`, `writeField`'s embed branch only recognized
    "already has an identity, reuse it" for an *object* carrying `@id`/`id` — a bare string fell
    through to `mintEmbedded`, which then ran `Object.entries()` on the string itself (JS treats a
    string as array-like: index → character), producing a brand-new `Link` with none of the
    original's `target`/`predicate` and silently orphaning the real one. Confirmed live before the
    fix: gave a real block a real link, re-ingested its (unchanged) artifact, watched the link's
    `predicate`/`target` both vanish and its id change. Fixed by treating a bare string the same as
    an object-with-`@id` in the embed branch (`node.ts`'s `writeField`) — reuse its id, never mint.
    Re-verified the same reproduction afterward: the link's id, `target`, and `predicate` all
    survive a reconcile-as-unchanged re-ingest intact.
  - **A third bug, same family, found by asking whether ids actually persist across a rehydrate
    cycle at all: `props` churned a fresh id on every single ingest, for every prop, regardless of
    whether anything changed.** Unlike `links`, `props` is genuinely rebuilt from the fresh parse
    every ingest (list numbering, checkbox state — re-derived from the current document, not a
    separately asserted fact `resolveBlockLinks` merges in afterward), and `astParser.ts`'s
    `setProp` never attaches an id to what it builds — so every prop on every block looked "brand
    new" to `writeField`'s embed branch on every single ingest, even for blocks reconciliation
    itself classifies as content-unchanged. Confirmed live against the real corpus's own current
    `StringProp` entries (still carrying their original TerminusDB-era random keys, since neither
    `kg:track:ngn` nor `kg:ingest:ngn` had ever actually been run for real yet) that a forced
    re-ingest of genuinely unchanged content would replace every one of them at once — a large,
    permanent, purely-cosmetic git diff on the very first real run, and again on every run after.
    Fixed at the `reconcile.ts` level, not `node.ts`: `BlockNode.toReconcileShape()` now includes
    `props` as `{id, key, value}` triples (previously omitted from the reconcile shape entirely),
    and `carryForwardFields` matches the old and new prop lists by `key` (a block has at most one
    prop per key today), carrying the old id forward only when the *value* also matches exactly —
    a genuinely changed value still mints a fresh id, same as a new prop would. Safe for the
    TerminusDB-backed path sharing this same `reconcile.ts` function: `graphql.ts`'s own old-tree
    fetch (`props { key _json }`) never requests an id in the first place (TDB's own
    `@key: {"@type": "Random"}` mints its own on every write regardless), so `old.id === undefined`
    there and the new carry-forward branch is a guarded no-op, leaving that path's behavior
    unchanged. Re-verified live: forced a re-ingest of `Aperas-design.md` (real, unchanged content)
    against a scratch copy and confirmed a real block's `orderedList`/`startIndex` prop ids —
    including their original TerminusDB-era values — came back byte-identical afterward.
  - **Same bug family, found later by inspection, not live reproduction: the fix above only
    covered per-block props, not the artifact/folder-level singular `frontmatter` prop.**
    `ArtifactNode.ingestFromDisk` (`node.ts`) and the shared `folders.ts`'s `buildFolderTree`
    (README frontmatter) each built a brand-new id-less `StringProp` literal on every write,
    unconditionally — neither goes through `reconcile.ts`'s per-block machinery at all, so the
    block-level fix never reached them. Not yet exercised against the real corpus (none of the 18
    tracked artifacts currently carry YAML frontmatter), so no live repro; caught by re-reading the
    fix's own reasoning and noticing it didn't generalize. Fixed by factoring the carry-forward
    rule out into a new shared `props.ts#carryForwardProp(existing, key, value)` (reuse the old id
    only when both `key` and `value` already match) and calling it from both sites — unit-verified
    directly (all four branches: fresh/no-existing, reuse/value-unchanged, fresh/value-changed,
    fresh/key-not-found), not yet live-reproduced for the same reason it was never exercised
    before. Safe for the TerminusDB-backed `folders.ts` caller for the same reason as the original
    fix: its own `existingByPath` doesn't populate `props`, so the carry-forward is a guarded
    no-op there regardless of whether TDB's own `@key: {"@type": "Random"}` would honor a supplied
    id anyway.
  - **Related but distinct bug, found by inspection: a `Set`-cardinality field's own array
    *order* wasn't stable, not just its ids.** `dehydrate.ts`'s `decodeField` returned
    `matches.map(decodeOne)` for `links`/`props` straight from `store.match()`, with no sort —
    Oxigraph's match order for a `Set`-typed field isn't guaranteed stable across a
    rehydrate/dehydrate cycle, so a `links`/`props` array with more than one entry could come back
    in a different order on every write even with the id-churn fixes above in place, reshuffling
    into git-diff noise despite no real content change. Fixed by sorting `decodeField`'s `set`
    branch by a stable key, generalizing the existing `stableId` helper (previously top-level-
    document-only, `doc['@id']`) to also handle a decoded set entry — an embed object (sorts by
    its own `@id`), a bare reference-id string, or a plain literal — the same "sorted so re-exports
    produce clean, content-driven diffs" principle `dehydrateToJsonLd` already applies to top-level
    documents, just not previously applied inside a nested `Set` field. Not live-reproduced (no
    real artifact currently has more than one `links`/`props` entry to actually shuffle) — fixed by
    direct reasoning and confirmed independently by the user, not by exercising real reordering.
  - **Real bug found and fixed while implementing, unrelated to the fold itself:** every "is this
    node live" filter across `artifacts.ts`/`folders.ts`/`resolve.ts`/`resolveCreate.ts` checked
    `node.tombstonedAt !== true` — but `tombstonedAt` is written as an ISO date *string*
    (`new Date().toISOString()`), never the literal boolean `true`, so that comparison was
    unconditionally `true` regardless of whether a node was actually tombstoned. The original
    TerminusDB-backed code these were ported from always checked plain truthiness (`!d.tombstonedAt`,
    `artifacts.ts`/`folders.ts`), which the ApeironNgn port had silently drifted from. Only surfaced
    now because real per-field types (`declare tombstonedAt?: string`) let the compiler flag the
    comparison as suspicious — under the old `Proxy`'s `unknown`-typed reads, nothing could catch
    it. Fixed everywhere to `!node.tombstonedAt`, matching the original semantics.
  - **Minor, pre-existing bug found while implementing `kg:project:ngn`'s real (non-dry-run) write
    mode:** `project.ts`'s shared `withFrontmatter` — the one exit point both the TerminusDB-backed
    `kg:project` and `kgProjectNgn.ts` funnel through before `writeFileSync`-ing straight to disk —
    never appended a final trailing newline, since neither it nor `serializeBlock`/`renderChildren`
    (nor their ApeironNgn equivalents) add one after the last block. Affected both engines equally
    (same shared function), not something the ApeironNgn port introduced. Fixed by having
    `withFrontmatter` guarantee its return value ends in exactly one `\n`.
- **`TreeNode` (`title`/`text`/`key` — shared by every tree-positioned kind):**
  - `tree.ts`'s `renderTree(store, rootId, opts)` → `node.renderTree(opts)`; `childIds`/
    `displayLabel` — `displayLabel` stays a small free helper in `tree.ts` (still used directly by
    two CLIs outside a full tree render); `childIds` is gone, superseded by `treeChildren`.
  - `path.ts`'s `resolveIdToPath(store, id)` → `node.toPath()`; `path.ts` itself is deleted.
  - `collect.ts`'s `collectBlockNodes(store, id, recursive)` → `node.collectDescendants(recursive)`
    (moved here from the original proposal's `BlockNode` placement — see the correction above);
    `collect.ts` itself is deleted.
  - `resolve.ts`'s `descend`/`resolveCreate.ts`'s equivalent (single-hop "given this node, find the
    child matching this segment") → `node.findChild(text)`, used internally by the still-free
    outer resolver rather than being its own CLI-facing fold. Read-only, throws on ambiguity, same
    as the free functions it replaced.
  - **New, needed to make the methods above (and `resolve.ts`'s per-hop descent) polymorphic
    instead of branching on kind:** `get treeChildren(): TreeNode[]` (throws if a concrete class
    doesn't override it — never actually reached, since `classForId` only ever dispatches to a
    leaf class) plus `appendChild(childId: string): void`, both overridden per concrete class below
    — together they replace `tree.ts`'s old `childNodes(node, kind)` and `resolve.ts`'s/
    `resolveCreate.ts`'s equivalent kind-switches with ordinary virtual calls.
- **`BlockNode`:**
  - `treeChildren`/`appendChild` → `this.children` (read) / append to it (write).
  - `project.ts`'s block-rendering half of `projectArtifactToMarkdown`/`projectFolderToReadme`
    (today's `serializeBlock` call) → `node.toMarkdown()`.
  - `artifacts.ts`'s `writeBlockTree(store, parsed)` → `node.hydrateFromParsed(parsed)` (recursive:
    the node is `wrap()`ped first at the known target id, then hydrates itself and its children).
  - `artifacts.ts`'s `materializeBlockTree(store, id)` → `node.toReconcileShape()` (recursive;
    produces the plain object `reconcile.ts` expects — still keyed `blockId` in its *output*, since
    that's `reconcile.ts`'s own external contract, unaffected by `key` replacing the stored field
    internally).
- **`ArtifactNode`:**
  - `treeChildren` → `this.root ? [this.root] : []` (unchanged — still what rendering/`kg:tree` see).
    `findChild`/`appendChild` as originally built here matched/attached against `root` itself as a
    single opaque child, `appendChild` throwing once a root already existed; §4 Step 6 replaced both
    with the current behavior (delegate through to the root document, root and artifact addressed as
    one logical node) — see Step 6 for why and the mechanics.
  - `project.ts`'s `projectArtifactToMarkdown`'s render half → `node.toMarkdown()` (frontmatter via
    `withFrontmatter` plus `this.root.toMarkdown()`; `null` when there's no root yet).
  - `artifacts.ts`'s `trackArtifact`'s per-node half → `node.trackFromDisk(artifactPath)` — takes
    the path explicitly (not `this.path`), since a brand-new, not-yet-tracked instance has no path
    of its own yet. Folding this onto the class turned out to remove real duplication: the old
    free function needed separate "new node" (mint an `artifactId`, set every field) and "existing
    node" (check the hash, maybe skip, set every field) branches; once `key` replaced the separate
    `artifactId` field, there's nothing left to mint, so one method body now handles both — a
    fresh node's `fileHash` just reads `undefined`, unconditionally "changed."
  - `artifacts.ts`'s `ingestArtifact`'s per-node half → `node.ingestFromDisk()`, returning
    `{ blockCount, reconciliation, pendingLinks }`. Deliberately does *not* also resolve the
    `pendingLinks` itself — that's `artifacts.ts`'s `resolveBlockLinks`, a multi-block sweep with
    no single node to be `this`, run by the free `ingestArtifact` wrapper immediately after.
  - `artifacts.ts`'s `getArtifactPath(store, id)` → deleted outright; every caller already just
    wants `node.path`, a plain field read.
- **`FolderNode`:**
  - `treeChildren`/`appendChild` → `this.children` (read) / append to it (write) — same shape as
    `BlockNode`'s, kept as its own separate implementation rather than shared on `TreeNode` (no
    4th hierarchy level was introduced for this).
  - `project.ts`'s `projectFolderToReadme`'s render half → `node.toReadme()`.
  - `folders.ts`'s `writeFolderTree(store, parsed)` → `node.hydrateFromParsed(parsed)` (recursive,
    mirrors `BlockNode`'s of the same name — kept as its own override rather than a shared
    `TreeNode` method, since a folder's children mix `BlockNode`/`FolderNode`/`ArtifactNode`
    3-ways where a block's are homogeneous).
- **`Link`/`StringProp` (leaf subdocs, no `BaseNode`/`TreeNode` in their chain):** no folds — they
  carry data only (`target`/`predicate`; `key`/`value`), never a `this` for any migrated function.
- **Stays free (store-wide search/sweep, or harness — no single node is `this` yet):**
  - `store.ts` (`rehydrateStore`/`getApeironExportDir`) — builds the store itself, before any node
    exists.
  - `dehydrate.ts` (`allIdsOfKind`/`dehydrateToJsonLd`) — whole-class/whole-store sweep.
  - `vocab.ts` — id/IRI/literal encoding; substrate infrastructure `node.ts` itself sits on, never
    in scope for folding.
  - `tree.ts`'s `findByExactPath`/`resolveTreeRef` — store-wide search for a *starting* node.
  - `resolve.ts`/`resolveCreate.ts`'s outer search (`resolveDeepPath`, `resolveDeepPathDetail`,
    `createImaginedPrefix`) — multi-root search and cross-node creation across the whole store;
    calls `.findChild()`/`.appendChild()` per hop now, folder/file segments included (§4 Step 6 —
    an intermediate `resolveArtifactOrFolderPrefix` whole-string search briefly stood in for this,
    since removed).
  - `artifacts.ts`'s `trackAllArtifacts`/`ingestAllArtifacts`/`findLiveArtifactByPath`/
    `resolveBlockLinks` — sweep over every artifact or every pending wikilink, or search by path,
    before any one node is known; `trackAllArtifacts`/`ingestAllArtifacts` are now thin loops
    calling `.trackFromDisk()`/`.ingestFromDisk()`.
  - `folders.ts`'s `getFolderRecord`/`ingestFolderTree` — same shape; `ingestFolderTree` is now a
    thin loop calling `.hydrateFromParsed()` at the end.
  - `compareMigration.ts` — test harness, not domain logic; never folds.

**Mirror format consequence, decided.** `dehydrateToJsonLd` no longer writes `blockId`/
`artifactId`/`folderId` into `AperasKG/Apeiron/*.jsonld` at all now (derived-not-stored, per
`key`) — confirmed via a structural diff against the real mirror before this was decided. That
field is also what the *old* TerminusDB schema's `@key: {Lexical, @fields: [blockId]}` uses to
assign a document's own key on import, so a mirror dehydrated by the new code is no longer
re-importable via the old `kg:import`. Decided to accept this rather than have `dehydrate.ts`
special-case emitting the field output-only: consistent with `kg:export`/`kg:import` already being
slated for retirement (§4 point 2's "not really migrated so much as retired"), not something this
migration needs to keep working through.

**Sequencing, as it actually happened** (same one-at-a-time / diff-before-next discipline as
step 2): the hierarchy refactor first (verified via a scratch-copy rehydrate → mutate → dehydrate
→ re-rehydrate round trip, `danglingRefs: []`, zero semantic diff besides harmless `Set`-order
noise in `props`/`links` — the same kind already accepted for the original dehydrate work); then
`BaseNode` (`fold`/`unfold`/`addLink`, verified live: a fresh embedded `Link` mints and decodes
correctly); then `TreeNode` and all three `treeChildren`/`appendChild` overrides together (verified
against the real corpus: `renderTree`/`kg:tree`'s full 1048-line output and `kg:path`/`kg:resolve`
including a real 3-hop deep path all diffed byte-identical against TerminusDB; `findChild` +
`appendChild` verified end-to-end via a real `--create-holder` run against a scratch copy — correct
multi-hop descent, correct holder attachment, immediately re-resolvable, and confirmed the
`ArtifactNode`-already-has-a-root guard rejects *before* minting, leaving no orphan node behind);
then `BlockNode`/`ArtifactNode`/`FolderNode`'s own methods (verified via a real `kg:track`+
`kg:ingest` sweep against a scratch copy of the actual corpus — genuine, non-manufactured drift on
4 real artifacts, correct reconciliation stats, zero dangling references on round-trip); then the
`resolve.ts`/`resolveCreate.ts` family's `descend` switched to call `.findChild()`/`.appendChild()`
internally, verified as part of the same `--create-holder` run above.

### Step 4: real-corpus validation, then archive the TerminusDB-backed half — implemented, verified

**First real-corpus run of `kg:track:ngn`/`kg:ingest:ngn`, and non-dry-run `kg:project:ngn`.**
Everything above through step 3 had only ever been verified against scratch copies. Ran the real
pipeline for the first time against the actual `AperasKG/artifacts/` corpus: reverted the working
tree to the last committed mirror as ground truth, ran `kg:track:ngn`+`kg:ingest:ngn` for real, and
confirmed every one of the 13 artifacts with no genuine content change came back byte-identical
(same block ids, same content — the critical idempotency property, and a stronger result than the
TerminusDB-backed full-sweep `kg:ingest` gets on the same corpus, see `Aperas-dev-status.md`'s
appendix). The 5 artifacts that did change all reconciled sanely; one (`Aperas-core-ontology-
design.md`) reconciled 6 added/6 removed blocks despite an unchanged file hash, traced to the
astParser/mapping rules having evolved since it was last really ingested, not a defect. Non-dry-run
`kg:project:ngn` was then implemented (mirroring `kgCli.ts`'s `project` write branch: writes to the
artifact's own file, or the folder's `README.md`) and used for real to project that reconciled tree
back to `Aperas-core-ontology-design.md` — confirmed the only differences from the original file
were canonical formatting normalization (blank-line list spacing, `*`→`-` bullets), zero content
lost, closing out the unexplained reconciliation delta.

**Found in the process, outside the rollout plan's own scope: `AperasKG/.githooks/post-commit`/
`post-index-change` were still invoking the TerminusDB-backed `npm run kg:track`, not
`kg:track:ngn`.** Not a deliberate deferral like `kg:export`/`kg:import`'s retirement — a plain
oversight, since the hooks live outside `web/src/lib/kgCli.ts` entirely and call `kg:track` as a
hardcoded string, so migrating the underlying script never touched them. Fixed: both hooks (and
`.githooks/README.md`) now call `kg:track:ngn`; re-ran `post-index-change` directly afterward and
confirmed it completes with no TerminusDB connection at all. Separately moved `post-commit` to
`pre-commit` (staging the mirror sync's own output via `git add`) so it lands in the same commit
as the artifact change it reflects, instead of trailing it as a separate leftover working-tree
change right after the commit completes.

**`verifyPhase0.ts` replaced by `verifyApeironNgn.ts`.** `client.ts`/`crud.ts`/`woql.ts`/
`graphql.ts`/`versionControl.ts` (and `export.ts`'s `kg:export`/`kg:import`) are all abandoned
along with TerminusDB itself, per the same decision as their retirement above — so the project's
main correctness harness needed an ApeironNgn-only replacement, not a `--db`-gated branch onto a
dead dependency. New `web/src/lib/verifyApeironNgn.ts` (`npm run verify:ngn`) ports everything
`verifyPhase0.ts` covered except Assertion/WOQL (the model doesn't have `Assertion` anymore) and
temporal commit management (ordinary `git branch`/`commit`/`diff` on `AperasKG/Apeiron/` already
covers that, nothing ApeironNgn-specific needed). Runs entirely against an in-memory `Store`
rehydrated from the real mirror — never dehydrates back to it, so the real `AperasKG/Apeiron/`
files are untouched by every run (confirmed live: ran it twice back-to-back, zero git diff both
times); the one dehydrate/rehydrate check uses its own scratch directory. The demo artifact/folder
still have to live under a real (if disposable) `__verify_apeironngn_demo/` subfolder of
`AperasKG/artifacts/` — `getArtifactsDir()`/`ingestFolderTree` have no directory-override param,
unlike `rehydrateStore`/`dehydrateToJsonLd` — cleaned up in a `finally` regardless of pass/fail.

**Real bug found on its very first run, not by inspection this time: `mintEmbedded` (`node.ts`)
stored a freshly-minted `Link.target` as a literal, not a node reference.** Its per-field loop
checked `typeof v === 'string'` before consulting the field's own declared `storageKind`, so
`BaseNode.addLink(predicate, target)` — whose normal calling convention passes `target` as a bare
id *string* — always fell into the literal branch even though `LINK_SHAPE` declares `target` as
`storageKind: 'reference'`. Every freshly-minted link's target decoded back as a plain string on
read, not a wrapped node, so `.target.id` (and any reverse-traversal through it) silently read
`undefined`. Reproduced live by `verifyApeironNgn.ts`'s own link-extraction check (§5b) on its
first run against a real self-link. Fixed by checking `shape[k]?.storageKind === 'reference'`
first, regardless of whether `v` is a string or an object (`idOf` already handles both) — falling
through to the literal branch only when the field isn't a reference. Re-verified: the same check
passes after the fix.

**TDB-backed code renamed and archived; ApeironNgn scripts promoted to the plain command names.**
With every `kg:*` command's real-corpus write path now verified (above) and `verify.ts` covering
what `verifyPhase0.ts` used to, the TDB-backed half no longer needed first-class command names —
renamed and archived rather than deleted outright, kept for reference for some time before final
removal (some mechanism may only exist in code, not written up in a doc). Two more files turned
out to be mixed TDB/engine-agnostic, the same way `artifacts.ts`/`project.ts` were (§4 rollout
step 2): `folders.ts` (`getFolderRecord`/`ingestFolderTree` split out to `foldersTdb.ts`) and
`nodeRef.ts` (the whole `client`-based deep-path resolver split out to `nodeRefTdb.ts`, leaving
only `slugify`/`tokenize`/`pathToNameTokens`/`Token` — what `apeironNgn/node.ts`/`resolveCreate.ts`/
`resolve.ts` actually import — behind). `bench-tree-fetch-strategies.ts` (a TDB-vs-ApeironNgn
fetch-strategy comparison, not wired into any npm script) archived too, once its TDB half had
nothing live left to compare against.

Renaming scheme: every TDB-backed file gets a `Tdb` suffix (`kgCli.ts` → `kgCliTdb.ts`,
`client.ts` → `clientTdb.ts`, etc.); every ApeironNgn `kgXxxNgn.ts` drops the `Ngn` suffix
(`kgTreeNgn.ts` → `kgTree.ts`, ..., `verifyApeironNgn.ts` → `verify.ts`) and its npm command
loses `:ngn` (`kg:tree:ngn` → `kg:tree`) to take over the plain name. Every TDB npm command got a
matching `:tdb` suffix for the final regression pass (`kg:track:tdb`, `verify:tdb`, ...) — both
`verify` and `verify:tdb` were run for real after the rename (the latter against live
TerminusDB, full pass including Assertion/WOQL and branch/commit management) before archiving,
then the `:tdb` npm script entries were deleted entirely (not left pointing at `.archive/`) once
the files actually moved, matching the earlier decision to drop rather than keep them reachable
via `npm run`.

Final location: `.archive/scripts/` (`restore.sh`/`tdb-log.sh`/`tdb-doc.sh`/`README.md` — no code
dependencies, unaffected either way) and `web/.archive/src/lib/` for the renamed `*Tdb.ts` files
plus `bench-tree-fetch-strategies.ts`. `web/.archive/`, not a repo-root `.archive/web/`,
deliberately: the first attempt (mirroring the full `web/src/lib/...` path under a repo-root
`.archive/`) left the archive syntactically self-contained (`./artifacts`, `./reconcile`, etc. all
copied in alongside, not reached-back-into) but *unrunnable* — Node resolves an external package
(`terminusdb`) by walking up from the importing file looking for `node_modules`, and a repo-root
`.archive/web/src/lib/` never passes through the real `web/node_modules` on that walk. Nesting one
level shallower inside `web/` itself (`web/.archive/src/lib/`) fixes that — confirmed live,
`npx tsx web/.archive/src/lib/kgCliTdb.ts tree ...` actually runs — while staying outside
`tsconfig.app.json`'s `include: ["src"]`, so it's still never swept into routine type-checking.
Every shared dependency the archived files need (`artifacts.ts`, `project.ts`, `folders.ts`,
`nodeRef.ts`, `reconcile.ts`, `props.ts`, `astParser.ts`, `snowflake.ts`, `lineReader.ts`) is
copied in alongside them, not reached-back-into — a deliberate frozen snapshot, since those live
files are free to keep evolving and nothing should silently break the archive later. The one
exception: `bench-tree-fetch-strategies.ts`'s `apeironNgn/store.ts`/`apeironNgn/node.ts` imports
reach back into the real `web/src/lib/apeironNgn/` rather than being copied — unlike the TDB
modules, that code isn't abandoned, it's the live implementation, so freezing a copy of it would
just go stale instead of staying accurate.

Not done as part of this pass, flagged as a follow-up rather than silently left inconsistent:
`Aperas-architecture.md` still describes the now-archived TDB implementation as the current
system spec (directory layout, module table, `kg:track`/`kg:ingest`/`kg:export` description, etc.)
— unlike this doc's own rollout narrative (correctly historical, left as-is), that one presents
itself as current-state architecture and needs an actual rewrite to describe ApeironNgn, not just
a note. Deferred by explicit choice, not an oversight.

### Step 5: shared service process — implemented, verified

Every `kg:xxx` script today starts a fresh process on each invocation: `rehydrateStore()` (a full
parse of `BlockNode.jsonld`/`ArtifactNode.jsonld`/`FolderNode.jsonld` into a brand-new `Store`),
followed, for mutating ops, by an unconditional full-rewrite `dehydrateToJsonLd(store)` before
exit. Cost scales with the whole mirror's size on every single call, including the
`pre-commit`/`post-index-change` git hooks, which fire on every commit, branch switch, and reset.

This step replaces that with a single long-running service process
(`web/src/lib/apeironNgn/service.ts`) holding one `Store` in memory across invocations. Every
`kg:xxx` script becomes a thin client: parse argv, `ensureServiceRunning()` (auto-start if nothing
is listening), send one request, print the result, exit. Only `service.ts` calls
`rehydrateStore()`/`dehydrateToJsonLd()` — the CLI scripts no longer do. No fallback "standalone,
no service" mode is planned: auto-start already makes the service transparent on a cold
invocation, so a fallback would just duplicate the old rehydrate/dehydrate logic for no benefit.

**Transport and locking.** The service listens on a Unix domain socket (`node:net`, no new
dependency) at `web/.run/apeironngn.sock`. "No concurrency" is enforced two ways: a file lock
(`web/.run/apeironngn.lock`, holding `{pid, socketPath, startedAt, status}`) guarantees only one
service process ever owns the mirror directory, and an in-process promise-chain queue inside that
one service guarantees its own concurrent socket connections are handled strictly one at a time,
regardless of transport concurrency:
```ts
let queue: Promise<unknown> = Promise.resolve();
function enqueue<T>(fn: () => T | Promise<T>): Promise<T> {
  const result = queue.then(fn, fn);
  queue = result.then(() => undefined, () => undefined);
  return result;
}
```

**Auto-start and the lock race.** A client checks liveness by connecting to the socket and sending
`{op:'ping'}` (more reliable than trusting a PID alone, since PIDs get reused); a failed connect
plus an existing lock file means either a live-but-slow-to-answer service or a stale lock left by a
crashed one — `process.kill(pid, 0)` (throws `ESRCH` if dead) combined with a `status:'starting'`
timestamp older than ~10s disambiguates, unlinking both lock and socket files if stale. The
would-be starter claims the lock via `fs.openSync(lockPath, 'wx')` — atomic exclusive create;
`EEXIST` means someone else is already starting it, so this client polls-connect with backoff
instead of spawning a second copy. The winner spawns `service.ts` directly via the local `tsx`
binary (`node_modules/.bin/tsx`, `tsx` a devDependency — see "Toolchain: dropping `npx`" below),
detached and unref'd, and the spawned process itself overwrites the lock with its own pid and
`status:'ready'` once `listen()` succeeds — the lock always reflects the actual owning process, not
the process that happened to start it.

**Dirty-tracking and flush.** A `dirty` flag is set by any mutating op handler after it runs; a
`setInterval(..., 10_000)` flushes via the unchanged `dehydrateToJsonLd(store)` if dirty, then
clears the flag. `flush` is a field on the request payload rather than a separate message
(`{op:'track', paths, flush: true}`); when true, the flush happens synchronously before the
response is sent, so the calling CLI process — and the `pre-commit` hook's `git add` right after it
— only proceeds once the mirror is actually on disk. `--flush` is parsed out of argv the same way
each script already parses its other flags (`kgTree.ts`'s `--no-holders`/`--unfolded`, etc.). One
behavior change this implies: a plain `kg:track` invocation without `--flush` now marks the store
dirty and returns, with the on-disk mirror catching up within 10s rather than synchronously — the
intended effect of centralizing dehydrate, not a bug.

**Invoking any flag through `npm run`.** Every `--flag` across the whole `kg:xxx` suite
(`--flush`/`--reload`/`--discard`/`--clobber`/`--recursive`/`--view`/etc.) needs npm's own `--`
separator to actually reach the script when run as `npm run kg:xxx`: `npm run kg:xxx --flush`
(no `--`) has npm's own CLI parser consume `--flush` itself — silently, with no forwarded flag and
often no visible warning at all (a *recognized* npm option like `--force` at least prints
"npm warn using --force"; an unrecognized one like `--clobber` doesn't print anything, and just
vanishes) — while a plain, unprefixed positional word (a path, a ref) passes through untouched
either way. The correct invocation is always `npm run kg:xxx -- --flush` (`--` before the flag), or
skip `npm run` entirely and call the script directly:
`node_modules/.bin/tsx src/lib/kgTrack.ts --flush`. This isn't specific to any one flag or op — it's
a property of `npm run` itself, so no flag name choice avoids it.

**Toolchain: dropping `npx`.** Every `kg:xxx` script and the service's own auto-start both ran
`npx tsx <entry>` originally. `tsx` isn't a local devDependency, so each call pays `npx`'s own
package-resolution overhead on top of actually running `tsx` — measured at ~1s of the ~1.45s a
bare `npm run kg:tree` took, even with `tsx` already cached and fully offline (`npx --offline`
still took ~1s; the cached `tsx` binary called directly took ~0.3s). Fixed by adding `tsx` as a
devDependency and calling it directly — `package.json`'s `kg:xxx` scripts read `tsx <entry>` (no
`npx`; `npm run` resolves the local `node_modules/.bin` automatically) and `serviceClient.ts`'s
`spawnService` calls `node_modules/.bin/tsx` explicitly (used for auto-start, and — since a code
change requires restarting the service by hand to take effect, see the workflow note in "Manual
kill target" below — for every manual restart during development too). Brought `npm run kg:tree`
down to ~0.6s, unrelated to and stacking with the rehydrate-avoidance win this whole step is about.

**Wire protocol.** Newline-delimited JSON, one request per connection (client connects, writes one
line, reads one line, closes) — `JSON.stringify` always escapes an embedded `\n`, so this framing
needs no parser beyond a string split.
```ts
type ServiceRequest =
  | { op: 'ping' }
  | { op: 'reload'; discard: boolean }                             // reload the store from disk
  | { op: 'flush'; clobber: boolean }                               // force an immediate dehydrate
  | { op: 'track'; paths: string[]; flush: boolean; reload: boolean }
  | { op: 'ingest'; paths: string[]; flush: boolean; reload: boolean; track: boolean }
  | { op: 'unfold'; ref: string; viewRef?: string; flush: boolean; reload: boolean }
  | { op: 'fold'; ref: string; viewRef?: string; flush: boolean; reload: boolean }
  | { op: 'resolve'; paths: string[]; base?: string; createHolder: boolean; titles?: string[]; flush: boolean; reload: boolean }
  | { op: 'titleCandidates'; pathArg: string; recursive: boolean; reload: boolean } // read-only, lists kg:title's prompt targets
  | { op: 'setBlockTitle'; blockId: string; title: string; flush: boolean }
  | { op: 'linkCandidates'; pathArg: string; recursive: boolean; all: boolean; reload: boolean } // read-only, lists kg:link's prompt targets
  | { op: 'addBlockLink'; blockId: string; targetRef: string; flush: boolean }  // targetRef resolved server-side
  | { op: 'project'; path: string; reload: boolean }               // read-only; result carries rendered markdown
  | { op: 'tree'; pathArg: string; maxDepth?: number; noHolders: boolean; viewRef?: string; reload: boolean }
  | { op: 'path'; idArg: string; reload: boolean };

type ServiceResponse = { ok: true; result: unknown } | { ok: false; error: string };
```

**Per-script refactor.** Each `kg:xxx.ts` currently calls `main()` unconditionally at module
bottom; the refactor adds the same self-invocation guard `verify.ts` already uses
(`if (process.argv[1]?.endsWith('kgTrack.ts')) main();`) so `service.ts` can import each script's
operation function without triggering its CLI side effects. `kgTrack.ts`/`kgIngest.ts`/
`kgUnfold.ts`/`kgFold.ts` are one-shot batch mutators (rehydrate → one operation → dehydrate once)
and split cleanly into an exported `run*(store, ...args)` plus a thin client `main()`.
`kgResolve.ts` only dehydrates inside its `--create-holder` branch — plain lookup mode is
read-only. `kgTitle.ts` and `kgLink.ts` are interactive (readline against stdin), dehydrating after
every accepted answer rather than once at the end, so they need granular per-answer ops instead of
one request per invocation: a read-only `titleCandidates`/`linkCandidates` op lists what to prompt
for in one round trip, then each accepted answer is its own `setBlockTitle`/`addBlockLink` round
trip. `kg:link`'s target resolution (`resolveDeepPath` on the raw answer text) moves server-side
too — `addBlockLink` takes the unresolved `targetRef` and reports back whether it resolved, so an
invalid answer can be re-prompted without the readline loop needing its own store access.
`kgProject.ts`/
`kgTree.ts`/`kgPath.ts` never call `dehydrateToJsonLd` at all; they route through the service
purely for the rehydrate-avoidance win. `kgProject.ts`'s rendered `.md` write stays client-side
(the service returns the markdown string; the CLI wrapper writes the file) so the service's own
disk-write footprint stays limited to exactly the 3 mirror files.

**Idle shutdown.** The service exits after 30 minutes with no requests handled (any `op`, including
`ping`, resets the idle timer — in practice a `ping` is always immediately followed by real work,
so it's a fine proxy for "someone's using it"). On fire it goes through the same graceful-shutdown
path as `SIGTERM`/`SIGINT`: flush if dirty, unlink lock and socket, exit. The next `kg:xxx`
invocation (or git hook) auto-starts a fresh service exactly like any other cold start.

**Disk locations.** `web/.run/apeironngn.sock` and `web/.run/apeironngn.lock`, resolved relative to
`__dirname` the same way `getApeironExportDir()` already is — not `cwd`. Added to `web/.gitignore`
(`.run/`). Deliberately not under `AperasKG/` — that directory's contents are otherwise all
git-tracked mirror data.

**Git hook.** `AperasKG/.githooks/pre-commit`'s `npm run kg:track -- $relative_paths` gains
`--flush`, so the mirror is guaranteed on disk before the hook's `git add`. `post-index-change`
doesn't `git add` anything after `kg:track` (it only exists to keep the mirror's hash-comparison
cache warm), so it stays flush-less, relying on the 10s timer.

**Failure handling.** A hard crash (SIGKILL/OOM) loses up to 10s of unflushed mutations —
acceptable, since the one path that must not lose data (commits) always goes through `--flush`,
which blocks until the write is confirmed on disk. A clean stop (`SIGTERM`/`SIGINT`) stops
accepting new connections, finishes the in-flight request, flushes if dirty, and unlinks the lock
and socket files before exiting, so a deliberate stop never leaves a stale lock or drops recent
changes.

**Manual kill target.** Calling the local `tsx` binary directly (no `npx`) keeps this a two-PID
chain, not the four-PID one an `npx tsx` spawn would produce: `node_modules/.bin/tsx` (a small
loader process) spawns the actual runtime — `node --require .../preflight.cjs --import
.../loader.mjs service.ts` — as its one child, confirmed via `ps -o pid,ppid,pgid,sid`. The
`SIGTERM`/`SIGINT` handler above lives only in that inner `node` process (the one actually running
`service.ts`'s code); the `tsx` wrapper PID above it installs no handler of its own. Linux does not
cascade a signal from parent to child automatically — `kill -TERM <pid>` (a bare, positive PID)
reaches exactly that one process, nothing downstream of it — so killing the wrapper PID this way
leaves the real service running, orphaned, still holding the lock/socket, while only the wrapper
exits.

There are two correct ways to stop it. Either signal the inner `node` PID directly (cross-check
`web/.run/apeironngn.lock`'s own `pid` field if unsure which PID that is — the service always keeps
that field pointed at itself; see "Auto-start and the lock race" above) — or signal the whole
process group at once with a *negative* PID, `kill -TERM -<pgid>`: `detached: true` at spawn time
made the `tsx` wrapper the leader of a fresh process group, and the `node` process spawned
downstream of it inherited that same group without re-detaching, so both PIDs share one PGID
(numerically equal to the wrapper PID) and `kill -TERM -<pgid>` delivers the signal to both
simultaneously — the leaf process runs its normal graceful shutdown, the wrapper just dies on the
same signal (no handler, default terminate, harmless). The minus sign is what selects the group
instead of a single PID; leaving it off is the wrapper-PID mistake above. Find both PIDs (and
confirm they share a PGID) with `ps -o pid,pgid,cmd -C node | grep apeironNgn/service`.

**Restart-on-code-change, a standing rule.** The service holds `apeironNgn/*.ts` in memory from the
moment it starts — editing any of those files has no effect on an already-running service, same as
any other long-lived process. There's no file-watcher/hot-reload; a code change only takes effect
once the service is killed (one of the two correct ways above) and a `kg:xxx` invocation auto-starts
a fresh one. Forgetting this reads as a baffling "the fix isn't working" until the stale process is
the thing actually still running.

**Verified live**, against the real `AperasKG/Apeiron/` mirror (not a scratch copy — every op here
is idempotent on unchanged content, so a no-op re-track/re-flush was safe to run for real):
cold start from a removed `.run/` (service auto-spawns, lock ends at `status:'ready'` with the
service's own pid, correct output); warm reuse immediately after (no second rehydrate — the same
pid answers, an order of magnitude faster than the cold call); two and three simultaneous cold
invocations racing on an empty `.run/` (exactly one service ends up running each time, every
invocation still gets correct output); two simultaneous mutating `--flush` calls (both land, all 6
mirror files stay valid JSON, zero diff since nothing actually changed); the 10s auto-flush
(mutate without `--flush`, mirror mtime provably unchanged immediately after, flips ~10-15s later,
zero content diff); `--flush` writing synchronously before the CLI process exits; a hard `kill -9`
followed by a fresh invocation (dead lock detected, clean restart, correct output — the crash
scenario the "starting" grace window and `status:'ready'` liveness check exist for); a graceful
`SIGTERM` after a real (reversible) mutation with no flush yet, confirming it flushes-then-exits
when dirty and skips the write when not (used deliberately to discard a test mutation without
touching disk, then re-verified the next cold rehydrate reflects the correct on-disk state).
`kgTitle.ts`/`kgLink.ts`'s interactive round trips and the git hook's actual `git commit` path
were checked by direct invocation and code inspection rather than a live end-to-end run — the
underlying mechanics (`--flush` argv parsing, `kg:track -- <paths> --flush`) are already covered
by the tests above.

### Step 6: ingest ordering, `--track`, link-resolution reporting, and root-document addressing — implemented, verified

`kg:ingest --track` folds `kg:track`'s own refresh into the same call: `kg:ingest`'s change
detection is `ingestedHash === fileHash` (has the *tracked* hash moved since last ingestion), a
different question from whether the file on disk has actually changed — without a fresh track
first, an on-disk edit to an already-tracked artifact is invisible to a plain `kg:ingest`.
`kg:ingest <path> --track` is `kg:track <path> && kg:ingest <path>` in one call (`kgIngest.ts`'s
`runIngest` runs `runTrack` first when the flag is set).

**Link-resolution outcome is its own report line, separate from reconciliation.**
Reconciliation's `changed` count reflects a block's own authored content (text/structure) only — a
wikilink's *resolution outcome* (dangling → resolved, or the reverse) can flip purely because
something *else* in the graph changed between ingestions, which reconciliation can't see (it runs
before `resolveBlockLinks` does, on the tree as freshly parsed, without knowing yet what any link
will resolve to). `artifacts.ts`'s `resolveBlockLinks` now returns its own `LinkResolutionStats`
(`{ resolved, dangling, changed }`), diffing each block's freshly-resolved link targets against its
*previous* resolved targets (`ArtifactNode.ingestFromDisk` collects those before reconciliation
overwrites anything, threading them through as `oldLinkTargets`). `kgIngest.ts` prints it as its own
line under the reconciliation summary: `Links: N resolved, M dangling, K changed.`

**Ingest ordering: track and rebuild the folder tree before parsing any content or resolving any
link.** `kgIngest.ts`'s `runIngest` used to rebuild the `FolderNode` tree (`ingestFolderTree`) only
*after* every target artifact had already been tracked, parsed into its fractal `BlockNode` tree,
and had its wikilinks resolved. `ingestFolderTree` only ever needs artifacts to be *tracked* (have a
`path`) — never their parsed content — so nothing actually depended on that ordering. The cost of
getting it backwards: `resolveBlockLinks` resolves a wikilink relative to its own block's ancestry,
which for a brand-new artifact climbs back up into the artifact's own *not-yet-attached* place in
the folder tree — a tree-based lookup at that point can't find a real, already-tracked path it
hasn't reached yet, and (worse) `--create-holder`'s fallback then mints a duplicate holder chain for
something that already exists. Fixed by reordering: `runIngest` now tracks every explicit path (and
runs `ingestFolderTree`) *before* calling `ingestArtifacts`/`ingestAllArtifacts` — the tree is
always consistent by the time any content gets parsed or any link resolved, for every artifact in
the batch, including ones newly tracked in the very same call. `ingestArtifacts` itself no longer
tracks inline (that guarantee is now the caller's job, made explicit); any direct caller of
`trackArtifact`/`ingestArtifact` outside `runIngest` (`verify.ts`'s own demo harness included) needs
to rebuild the folder tree between the two for the same reason.

**Folder/file path segments match the same way headings always did.** The deep-path grammar's
folder/file tier used to be its own whole-string search (`resolveArtifactOrFolderPrefix`, since
removed): join the leading NAME tokens, look the joined string up as one literal `path` value. That
gave folder/file segments only exact matching, never the prefix tolerance headings already had via
`TreeNode.findChild`. With the ingest-ordering fix above guaranteeing the tree is always consistent
by the time `resolve.ts`/`resolveCreate.ts` run, `findChild`'s exact-then-prefix slug matching was
generalized (it matched `BlockNode` children only before) to match a `FolderNode`/`ArtifactNode`
child the same way — so `t` now prefix-matches a real `test.md`/`test/` the same way it already
prefix-matched a `# Test` heading, and multi-segment paths resolve hop-by-hop through `treeChildren`
uniformly at every tier, not just within one document.

**An artifact and its root document are the same logical node for addressing.** Every artifact's
content lives under a synthetic root `BlockNode` (`type: 'root'`, title `"Document Root"`) —
real, still visible in `kg:tree`'s rendering and still `ArtifactNode.root` in storage, but never
meant to be a real addressing boundary of its own: an artifact only ever has the one document, so
"the artifact" and "its root document" name the same thing. The deep-path grammar used to treat the
root block as an ordinary intermediate segment regardless — a heading `H` directly under an
artifact's root resolved as `<artifact>/document-root/<heading>`, and `..` from `H` landed on the
synthetic root block itself, not the artifact. Both corrected to treat the root block as invisible:
  - `ArtifactNode.findChild(text)` (`node.ts`) delegates straight to `this.root.findChild(text)`
    instead of matching `text` against `[root]`'s own title — so `<artifact>/<heading>` resolves in
    one hop, `<artifact>/document-root/<heading>` no longer resolves at all (the segment doesn't
    exist to match against).
  - `ArtifactNode.appendChild(childId)` delegates to `this.root.appendChild(childId)` (resetting
    `childId`'s own `.parent` to `this.root`, overriding whatever the caller set) when a root
    already exists, rather than throwing — attaching a new top-level heading directly under an
    artifact is the *normal* case now (creating one via `--create-holder` no longer needs an
    explicit `document-root` hop first), not an error; only becoming the very first root (no
    existing one to delegate to) still sets `this.root` directly, unchanged from before.
  - `TreeNode.toPath()` skips emitting a path segment for a block whose `type === 'root'`, walking
    straight through to its `.parent` (already stamped to the owning `ArtifactNode` at ingestion
    time) — so a heading's own computed path is `<artifact>/<heading>`, never
    `<artifact>/document-root/<heading>`.
  - `resolve.ts`'s and `resolveCreate.ts`'s `descend`, on `..` from a `BlockNode`: after following
    `.parent` once, if that landed on a `type === 'root'` block, follows `.parent` *again*
    (already stamped to the `ArtifactNode`) before continuing — so `..` from a top-level heading
    reaches the artifact directly, matching `toPath()`'s own treatment of the same hop.

None of this touches storage or `kg:tree`'s rendering — the root block still exists, still holds
`children`, still prints as its own `[root] Document Root` line. Only the deep-path grammar (and
`--create-holder`'s attachment logic) treats it as transparent. (Superseded by Step 7 below: the
root block was later removed from storage entirely, not just made addressing-transparent.)

**A separate, pre-existing nuance this interacts with: a heading's *first* paragraph is a different
addressing level than its later ones.** `Aperas-markdown-fractal-mapping-design.md` §2's consuming
rule — a heading (or `listItem`) absorbs its immediately-following paragraph as its own `text`,
rather than making it a child `BlockNode` — means a wikilink written in that *first* paragraph is,
for addressing purposes, a link *from the heading itself*: the containing block's own path is
`<artifact>/<heading>`, so a sibling sub-heading is reachable directly, `subheading`, no `..`
needed. A *second* (or later) paragraph under the same heading is never absorbed — it's a real,
separate `BlockNode` one level *below* the heading (a sibling of any sub-headings, not the same node
as the heading), defaulting to its own generated id as its title (nothing else names it, until
`kg:title` overrides it). A wikilink written there needs one extra `..` to reach the same
sub-heading: `../subheading`. The two paragraphs *read* identically in the rendered document —
nothing about the surface markdown marks which addressing level a given paragraph's links resolve
from — so a link's correct `..` count depends on whether it's the heading's first paragraph or not,
not just on how many headings visually separate it from its target. Unrelated to the root-document
fix above (a `BlockNode`-to-`BlockNode` structural fact, not an artifact/root one), but easy to
conflate with it since both change how many `..` a link needs relative to what the prose visually
suggests.

**Verified live**, against the real corpus mirror (`test/test.md`, already containing a nested
heading): `test/test.md/test` resolves the heading in one hop where `test/test.md/document-root/
test` now correctly misses; `kg:path` on that heading reports `test/test.md/--test` (no
`document-root` segment); `--base <heading-id> ..` resolves to the artifact directly; `--create-
holder` on a brand-new top-level heading under that already-ingested artifact attaches it as a real
sibling of the existing content (confirmed via `kg:tree`), not a rejected "already has a root"
error; a temporary second paragraph added under `test/test.md`'s `# Test` heading confirmed the
first-paragraph-vs-later-paragraph addressing split directly (`sub` resolved from the first
paragraph's own base, missed from the second paragraph's base, `../sub` resolved from there) before
being reverted. `npm run verify`'s own demo harness (`verify.ts`) needed the same
tracking-then-folder-rebuild reordering applied to its own direct `trackArtifact`/`ingestArtifact`
calls (it doesn't go through `runIngest`), and its "truly dangling" wikilink fixture needed its
hardcoded `..` count increased by one level — the same literal `../../../../` that used to correctly
overshoot into unresolvable territory under the old (one-level-deeper) tree shape now lands validly
on the artifact's own document, since a hop that used to be consumed by the synthetic root segment
no longer exists to consume it. `test/test.md`'s own real wikilink had the identical, pre-existing
staleness (written against the old, one-level-deeper shape) and needed the same one-level `..`
correction, found by exactly this recalibration check — a concrete reminder that any wikilink
written before this fix landed may need re-auditing, not just the two test fixtures caught here.

### Step 7: `ArtifactNode extends BlockNode`, the root block retired outright, `text` a copied abstract for both — implemented, verified

Two problems with Step 6's design, found on review rather than in the field:

**The synthetic root block was addressing-transparent but still physically real** — a second
document per artifact purely because `kg:track` and `kg:ingest` used to be separate free functions,
each needing "the artifact" and "its content" as separate things to mint/wire up. Once folded onto
one class each (§4 Step 3), that separation was no longer a technical necessity, just left over from
it — Step 6 patched every place the two-node split leaked into addressing (`findChild`/`appendChild`
delegation, `toPath`'s `type === 'root'` skip, `descend`'s double `.parent` hop on `..`, an
"already has a root" guard against a second one) rather than removing the split itself.

**`FolderNode.text`'s consuming rule required a literal top-level leading paragraph, which a
realistically-formatted README rarely has.** `folders.ts`'s `buildFolderTree` only consumed an
abstract when the README's parsed root's *first child* was a bare `paragraph` — a README that opens
with a heading (the normal case: `# Title` first) produced an empty `FolderNode.text` every time,
silently. `ArtifactNode.text` never had this problem (`extractAbstract` already searched
pre-order, not just the first child), so the two node kinds had quietly diverged in robustness
without that being a deliberate choice.

**Resolved by merging `ArtifactNode` into its own document content, and reusing `extractAbstract`
for both node kinds:**

- **`ArtifactNode extends BlockNode` now** (`node.ts`), not `TreeNode` directly — the class
  hierarchy is `BaseNode -> TreeNode -> BlockNode -> ArtifactNode`. `ArtifactNode` no longer has a
  `root` field; it *is* its own root document (`type`/`children`/`text` live on it directly, same
  as any `BlockNode`), inheriting `type` as `optional` rather than `BlockNode`'s `one` (unset until
  something's actually been ingested). **`FolderNode` deliberately stays on `TreeNode` directly**,
  not `BlockNode` — considered and rejected: a folder was never merged with anything (a README's
  content already lived straight in `FolderNode.children`, no synthetic wrapper to begin with), so
  unlike `ArtifactNode` it has no genuine claim to `BlockNode`'s shape. Audited field by field, it
  would inherit nothing it actually uses — `type`/`parent` never set or read, `treeChildren`/
  `appendChild` always overridden (a folder's children are a real 3-way `BlockNode`/`FolderNode`/
  `ArtifactNode` mix, never `BlockNode`'s homogeneous assumption), and `toMarkdown`/
  `hydrateFromParsed` actively wrong (`FolderNode`'s own `hydrateFromParsed` takes a
  `ParsedFolderNode`, a genuinely different, incompatible shape from `BlockNode`'s
  `ParsedBlockNode` — an early draft of this step had `FolderNode extends BlockNode` too, for a
  uniform-looking `BlockNode -> {ArtifactNode, FolderNode}` diagram, and that parameter-shape clash
  forced renaming the method to avoid an invalid override; reverted once the audit showed the
  `extends` relationship itself was the actual problem, not the name). `FolderNode` keeps declaring
  its own `children` independently, same as before this step.
- **All four of Step 6's addressing patches are gone, not just satisfied** — with no second node
  to be transparent about, there's nothing left to patch: `ArtifactNode.findChild`/`.appendChild`/
  `.treeChildren` are `BlockNode`'s own plain versions, inherited unmodified (a top-level heading
  is an ordinary child; appending one is an ordinary ordered-containment append); `TreeNode.toPath`
  no longer special-cases `type === 'root'` (no node ever has that type anymore); `resolve.ts`'s
  and `resolveCreate.ts`'s `descend` no longer double-hops on `..` (a top-level heading's `.parent`
  already points straight at the owning `ArtifactNode`); the "already has a root" guard is gone
  outright (no singular-root concept left to guard).
- **`ArtifactNode.ingestFromDisk` (`node.ts`) reconciles against `this` directly** instead of a
  separate `oldRoot` — `toReconcileShape`/`hydrateFromParsed` are `BlockNode`'s own inherited
  methods, called on `this`; nothing about `reconcile.ts` itself needed to change; a freshly-parsed
  document's own top-level `blockId`/`parent` are discarded rather than materialized (only its
  `children` become real `BlockNode`s, each stamped straight to `this.id`). "Has this artifact ever
  been ingested before" is `this.ingestedHash !== undefined`, not `this.children !== undefined` —
  `children` is `orderedContainment`, which always reads back as a real (possibly empty) array,
  never `undefined`, so it can't tell "never ingested" apart from "ingested with zero top-level
  blocks."
- **`ArtifactNode.text`/`FolderNode.text` are both a copied abstract now** (`extractAbstract`,
  `astParser.ts` — a pre-order search for the first descendant with non-blank text), never
  consumed out of `children` the way §2's heading/listItem rule consumes a heading's own leading
  paragraph. `folders.ts`'s `buildFolderTree` no longer special-cases a bare leading paragraph at
  all — `readmeText = extractAbstract(parsedRoot)`, `readmeChildren = parsedRoot.children`
  unconditionally, both node kinds sharing the identical mechanism `ArtifactNode` already used.
  This is a deliberate, named departure from §1 of `Aperas-markdown-fractal-mapping-design.md`
  ("`text` is never a duplicate of something addressable elsewhere") rather than a quiet violation
  of it: a heading has its own leading sentence as genuine content; an artifact or folder is a pure
  container with no content of its own, so its `text` is honestly a derived preview, expected to
  duplicate whatever the first real descendant with content already is. The corollary:
  `FolderNode.toReadme()` no longer re-emits `this.text` into the projected body ahead of
  `children` — doing so would print the same sentence twice in the actual file now that nothing is
  removed from `children` to make room for it (`ArtifactNode.toMarkdown()` never re-emitted `text`
  either, for the same reason).
- **The real `AperasKG/Apeiron/` mirror was empty at the time this landed** (mid-rebuild from an
  unrelated in-progress change) — no migration story needed; the new shape is simply what the next
  `kg:track`+`kg:ingest` sweep produces.

**Verified**: `npm run build` (`tsc -b && vite build`) clean; `npm run verify`'s full demo harness
passing end to end against the merged shape — tracking, ingestion, re-ingestion reconciliation
(`18 matched, 0 moved, 0 changed, 2 added` on the edited re-ingest), `BlockNode.links` extraction
(self-link now resolving to the `ArtifactNode` itself rather than a separate root `BlockNode`),
`FolderNode` README projection (including a new explicit assertion that `FolderNode.text` picks up
a *headed* README's abstract — `# Demo Folder` first, `Intro sentence...` second — the exact shape
the old top-level-paragraph consuming rule produced an empty abstract for), and a dehydrate ->
rehydrate round-trip (`{"BlockNode":27,"ArtifactNode":1,"FolderNode":4}`, 0 dangling references).
`apeironNgnSmokeTest.ts` (ground-truth-vs-live-Store comparison against the real mirror) updated to
pick an artifact by `type !== undefined && children.length > 0` instead of a `root` reference, but
not itself re-verified end to end here — the real mirror is empty until the next real ingest sweep.

### Step 8: `Link.props`, occurrence positions, and target-deduped wikilink edges — implemented, verified

**The gap.** Nothing correlates a specific `[[wikilink]]` occurrence in a block's `text` with the
`Link` object it resolved to. Given a block whose text mentions two different targets (or the same
target twice), a reader has `text` (raw, with the literal `[[code]]` substrings still in it) and
`links` (a `Set` of `{predicate, target}`) but no way to line the two up short of independently
re-running wikilink detection and hoping the order matches. Separately (found while designing a fix
for this): `resolveBlockLinks` (`artifacts.ts`, and the wikilink-regeneration fix earlier in this
doc's own narrative) mints one `Link` per raw occurrence, not per distinct target — so a block
mentioning the same target twice already produces two edges to it today. That's a real problem
beyond tidiness: `.links` is a genuine second traversal axis alongside `children` (`TreeView.fold`,
`node.ts`, walks both), so a duplicate edge to the same target is a graph-correctness smell, not
just a display nit.

**Resolved by generalizing `props` (Aperas-markdown-fractal-mapping-design.md §7) onto `Link`
itself, rather than inventing a bespoke field for position specifically:**

- **One `Link` per distinct `(predicate, target)` pair per block, not per raw occurrence.** A block
  mentioning the same target twice keeps one edge, carrying every position that target occurs at.
- **Position storage: `Link` gains `props: { cardinality: 'set', storageKind: 'embed' }`** — the
  exact same `Set<StringProp>` mechanism `BlockNode`/`ArtifactNode`/`FolderNode` already use for
  "a new piece of type-conditional metadata never needs its own schema field" (§7's own framing,
  applied here to `Link` for the first time). A wikilink-derived `Link` carries one `{key:
  'position', value: '<offset>'}` prop entry per occurrence of that target in the block's text —
  a real multiset, reusing already-proven embed/mint/dehydrate/carry-forward machinery instead of
  being the first thing to exercise a raw `cardinality: 'set'` *literal* field (which the
  `writeField`/`readField` machinery already supports generically, just never exercised — `props`
  is the safer, already-tested route to the same multiset capability). This settles a design
  question `Link`'s own shape has carried since the original fractal-tree draft: `Link extends
  BaseNode` (full inheritance, giving `props` but also an unwanted `links`/`tombstonedAt`/`holder`
  — a link having its *own* outbound links or independent tombstone lifecycle corresponds to
  nothing real) was tried and judged overkill; a single simple scalar field (enough for "one note
  per link," not enough for a set of positions without re-serializing into that one string) was
  tried next and judged insufficient. Cherry-picking just `props` onto `Link` directly in
  `LINK_SHAPE` — no `extends BaseNode`, since `SHAPE` tables are already fully flattened
  per-class and don't rely on the class hierarchy for field composition — is the middle point:
  exactly the one field actually needed, reusing the mechanism already proven elsewhere, nothing
  dragged along unused.
- **Non-wikilink (`kg:link`, `'references'`-predicate) `Link`s share the same `props` slot** for
  whatever metadata they might want later (a note, a timestamp) — no dedicated schema field needed
  for that either, by the same §7 principle. `position` itself is only ever populated on
  `WIKILINK_PREDICATE` links; a manual link has no source-text occurrence to position.
- **One number per occurrence — mdast's own link-node start offset** — not a start/end range and
  not per-target-array-of-two-numbers. A single start position is sufficient to correlate an
  occurrence with its `Link`; recovering the full span, if ever needed, re-applies the same
  wikilink grammar starting from that known point rather than storing a redundant end offset.
- **Block-relative, never file-relative — deliberately, not as an afterthought.** Storing a
  position relative to the whole file would reintroduce exactly the fragility git patches suffer
  from (every edit before a link shifts its file offset, needing fuzzy context-matching to cope) —
  precisely the class of problem the fractal block architecture exists to avoid by construction.
  mdast's own link-node `position.start.offset` is file-relative by default; converting it to be
  relative to the owning block's own (already-`.trim()`-ed) `text` needs to be one clean, correctly-
  built primitive extending `rawSlice`'s own offset math (`astParser.ts`), not a subtraction
  reinvented at each call site that happens to need it.
- **Headings excluded from link-scanning entirely, not just from this position scheme.** A heading
  functions as an anchor/target itself (other content links *to* it by title); a link nested inside
  its own title text is an HTML nested-anchor situation (invalid per spec, and in practice exactly
  as confusable as the spec's ban implies — confirmed the hard way, independent of this design).
  `astParser.ts`'s heading case should stop calling `collectLinkCodes` on the heading's own title
  line — only its consumed leading-paragraph `text` (§2's consuming rule) may still contain links.
  Beyond the correctness case for banning it, this has a direct simplifying payoff for the position
  scheme: with title excluded, every block's wikilink positions are relative to `text` alone,
  uniformly — no `field: 'title' | 'text'` discriminant needed anywhere. (Real behavior change for
  existing content: a wikilink written inside a heading's own title line stops resolving as a
  `Link` edge on the next ingestion — the raw title text is unaffected, still a verbatim slice,
  it simply stops being extracted.)
- **API gap to fill:** `props.ts`'s `getProp` is `.find()` — first match only, correct for
  genuinely single-valued props (`frontmatter`, `orderedList`, `checked`). `position` is
  legitimately multi-valued per `Link`, so it needs a plural sibling, `getProps(node, key):
  string[]`, alongside the existing singular accessor.

**Implemented as designed**, matching the surface sketched above one-for-one:
- `shape.ts`: `LINK_SHAPE` gains `props: { cardinality: 'set', storageKind: 'embed' }`.
- `node.ts`: `Link` gains `declare props?: ApeironNode[]`. `BaseNode` gains `addWikilink(target,
  positions)` — mints one fresh `Link` (predicate `WIKILINK_PREDICATE`), sets its `props` to one
  `{key: 'position', value: '<offset>'}` entry per position, and attaches it by id. A dedicated
  method, not an overload of `addLink` (which `kg:link` also calls, with no position or
  dedup-by-target concept of its own) — and, necessarily, back to the "mint id, `wrap()`, set
  fields, attach by id" shape `addLink`'s own doc comment says `links` becoming `storageKind:
  'embed'` retired: `mintEmbedded` only writes an entry's own top-level fields, it doesn't recurse
  into a nested `Set`-typed one, so a single-call `{predicate, target, props}` literal can't mint
  `props` correctly — safe to always mint fresh here (never merge into an existing same-target
  `Link`) since every wikilink-derived `Link` on a block is already stripped before this runs
  (Step 7's `hydrateFromParsed` fix). (Superseded by Step 9: `addWikilink` split into a
  non-attaching `mintWikilink`, and `hydrateFromParsed` no longer strips wikilinks up front — the
  "always mint fresh, nothing to reuse" premise here no longer holds.)
- `astParser.ts`: `sliceWithOffset`/`relativeOffset` (the `rawSlice`-adjacent primitive, block-
  relative offset conversion in one place); `collectLinkCodes` now takes `(containerNode,
  markdown)` and returns `LinkOccurrence[]` (`{code, position}`) instead of `string[]`; the heading
  case no longer calls it on the heading's own title line, only on a consumed leading paragraph.
  `ParsedBlockNode.linkCodes` retyped accordingly, threading through `PendingLinkCodes`
  (`artifacts.ts`) and `extractLinkCodes` unchanged otherwise (it only ever moved the field around,
  never inspected its shape).
- `apeironNgn/artifacts.ts`'s `resolveBlockLinks`: resolves every code, groups successes by target
  in a per-block `Map<target, position[]>`, then calls `addWikilink` once per distinct target.
- `props.ts`: `getProps(node, key): string[]` alongside the existing singular `getProp`.
- `verify.ts` (§5d): confirms two occurrences of the same target in one block produce one `Link`
  carrying two `position` props (not two `Link`s), and that each position lands on the opening `[`
  of its wikilink construct in `block.text`.

**Two real bugs surfaced during implementation, both found by the existing test suite catching
something it wasn't specifically written to catch — fixed as part of this step, not deferred:**

- **`vocab.ts`'s `nodeKindFromId` misclassified a `Link`'s own `props` entries.** `SUBDOC_RE`
  (`/\/(?:props|links)\/([A-Za-z]+)\//`) was matched non-globally, returning the *first* `/props/`
  or `/links/` segment in an id. Every id shaped this way used to have exactly one such segment —
  `Link.props` is the first case of a subdocument nested *inside* another subdocument
  (`.../links/Link/<snowflake>/props/StringProp/<snowflake>`), so the first-match regex found the
  outer `/links/Link/` and `wrap()`ed every `position` prop as a second `Link` instead of a
  `StringProp` — quads written correctly, `.key`/`.value` reading back `undefined` on the
  misclassified wrapper. Fixed: match globally, take the *last* (deepest/rightmost) segment, which
  is always the id's real, immediate kind regardless of nesting depth.
- **Reassigning an embed field only ever detached the old subdocument, never deleted it** —
  `writeField`'s `clearField` removes the forward reference quad but left whatever it used to point
  at sitting in the store forever, unreferenced. Harmless to the JSON-LD mirror (`dehydrateToJsonLd`
  only walks structure reachable from a live top-level sweep, so an orphan is simply never visited,
  never written) but a real, slowly-growing footprint in the long-lived `service.ts` process, which
  keeps one `Store` alive across every `kg:track`/`kg:ingest` call for its whole uptime rather than
  starting fresh each command. Pre-existing since the wikilink-regeneration fix (a dropped stale
  wikilink `Link` was already leaking its `target`/`predicate` quads), `Link.props` just made each
  leaked instance bigger (a `props` entry's own `key`/`value` quads too) and this step's own new
  4-ingestion test in `verify.ts` finally pushed the leak past the dehydrate/rehydrate round-trip's
  exact-quad-count check. Fixed generally, not narrowly for wikilinks: `writeField` now, for any
  `storageKind: 'embed'` field, computes which currently-referenced ids survive into the new value
  and recursively deletes (`deleteSubdocument`, new) whichever don't, before clearing the forward
  reference — covers every embed field's reassignment (also, incidentally, an equivalent pre-
  existing leak on an ordinary `props` value change via `carryForwardFields`'s per-key merge in
  `reconcile.ts`, not just `links`), not just the one call site that surfaced it.

**Verified**: `npm run build` (`tsc -b && vite build`) clean; `npm run verify`'s full suite passing,
including both new cases above and (unchanged) every prior one — the dehydrate/rehydrate round-trip
in particular now passes with the orphan-cleanup fix in place, confirmed via a deliberate before/
after check (reverting the fix reproduces the exact quad-count mismatch the fix resolves).

### Step 9: consistent tombstoning (incl. recursive artifact removal) and wikilink `Link` identity stability — implemented, verified

Resolves §5's two tombstoning open questions (as they stood after Step 8's sweep), both left
open at the time.

**Tombstone consistency.** All three tombstone sites now clear `children`/`links`/`props` alike,
matching `applyTombstone`'s own original rationale ("a dead node has no more use for `X`"):
- `node.ts`'s `applyTombstone` (reconcile-driven, per removed block) now also clears `props` (it
  already cleared `children`/`links`).
- `folders.ts`'s folder-tombstone now also clears `links`/`props` (it already cleared `children`).
- `artifacts.ts`'s artifact-tombstone previously cleared *nothing* but its own `tombstonedAt` flag
  — checking why turned up a second, larger gap than the props-consistency question alone: unlike
  the reconcile path (`reconcile.ts`'s `tombstoneSubtree` already recurses the whole removed old
  subtree, one tombstone record per descendant) or the folder path (every folder path, nested or
  not, is independently listed, so a removed subfolder gets tombstoned on its own regardless of its
  parent), a whole artifact's *own* BlockNode subtree isn't tracked by file path at all — only the
  artifact's path is. So deleting a tracked markdown file used to leave its entire fractal tree, and
  every block's own `links`/`props`, fully live and permanently unreferenced: the same invisible-
  garbage class as Step 8's `Link` leak, one level up, once per artifact removal instead of once per
  stale wikilink. Fixed with a new `node.ts` function, `tombstoneLiveSubtree(node, now)` — walks
  `children` depth-first, tombstoning every descendant the same way (`children`/`links`/`props`
  cleared, `tombstonedAt` set) before doing the same to the artifact itself. Unlike `applyTombstone`
  it operates directly on the live tree, not a captured old-shape record — there's no separate old/
  new distinction on this path, just one live tree being marked dead all at once.

**Wikilink `Link` identity stability** (§5's "tractable half"). A wikilink `Link` used to get a
fresh id on every re-ingestion even when its target and occurrence positions hadn't changed at all
— `hydrateFromParsed` dropped every carried-forward wikilink `Link` unconditionally before
`resolveBlockLinks` ran, so there was never anything left to reuse. Fixed by moving the decision
into `resolveBlockLinks`, where the fresh target/position groupings are actually known:
- `hydrateFromParsed` now carries `links` forward unconditionally (manual *and* wikilink alike) —
  the id-churn fix no longer depends on stripping anything early.
- `ingestFromDisk` snapshots each matched block's *old* wikilink `Link`s (id, target, positions) via
  a new `collectOldWikilinksByBlock`, at the same point (and for the same reason) it already
  snapshots `oldLinkTargets` — before anything below it touches the tree.
- `resolveBlockLinks` sweeps the *union* of blocks with pending `[[wikilink]]` codes and blocks that
  had old wikilink `Link`s — not just the former, which would miss a block whose wikilinks were all
  removed (`extractLinkCodes` never records a block with zero codes, so a naive "just walk
  `pending`" sweep would leave such a block's now-stale `Link`s live forever, the exact bug class
  this whole step is about, just newly reachable through this specific gap). For each block: a
  fresh target reuses an old wikilink `Link`'s id whenever some old entry names the *same target* —
  **`target` alone is the identity key, not the position list** (a correction made after an initial
  version of this fix matched on target *and* exact position equality: position drifts from any
  unrelated edit earlier in the same block's own text, so requiring an exact position match would
  still churn the id on nearly every real edit, defeating the fix's own point). When a matched old
  `Link`'s stored positions differ from the fresh ones, they're rewritten in place — `Link.props` is
  itself `storageKind: 'embed'` (Step 8), so this reassignment's own embed-diff cleans up the stale
  `position` `StringProp`s and mints the fresh ones without touching the `Link`'s own id, `target`,
  or `predicate`. A target with no old match at all mints fresh via `mintWikilink` (renamed from
  `addWikilink`, and no longer self-attaching — see below). `block.links` is written exactly once, as
  `[...manualIds, ...survivingOrFreshWikilinkIds]` — `writeField`'s own embed-diff cleanup (Step 8)
  is what deletes every wikilink `Link` that isn't in that final list, i.e. one whose target
  disappeared from the block's text entirely.
- `BaseNode.addWikilink` renamed to `mintWikilink` and no longer attaches its result to `this.links`
  itself — it only mints the `Link` and returns its id, so `resolveBlockLinks` can decide the whole
  block's final surviving id list before writing `.links` once, rather than the old "always append"
  shape that made reuse impossible in the first place.

**Verified**: `npm run build` clean; `npm run verify`'s full suite passing, plus three new cases:
§5e confirms the self-link wikilink `Link` from §5c/5d keeps the exact same id across a further,
unrelated re-ingestion of the same artifact (the forward-reference wikilink in the same paragraph is
deliberately excluded from this check — its *target* is a freshly-minted holder BlockNode each time,
a separate, pre-existing holder-churn question this step isn't about); §5f confirms the
target-only-matching correction directly — inserting a clause before a block's two wikilink mentions
shifts both occurrences' positions while keeping the same `Link` id, with `position` props updated
to the new offsets.

**Left open at the time, by explicit choice**: §5's "hard half" (a genuinely-deleted `Link`/
`StringProp` leaving a dangling `TreeView.unfolds` reference with no trace) was unchanged by this
step — deferred to a later discussion. Resolved by Step 10, immediately below.

### Step 10: visible tombstones and dangling-`unfolds` cleanup — implemented, verified

Resolves §5's "hard half," the piece Step 9 explicitly left open: a tombstoned `BlockNode`
reached through a stale reference rendered with no signal it had died, and a genuinely-deleted
`Link`/`StringProp` left its `TreeView.unfolds` entry dangling forever with zero trace. Both
findings came from tracing the actual rendering/deletion code rather than assuming — see Step 9's
own write-up for the precise "invisible but reads as alive" vs. "invisible with zero trace" framing
that motivated fixing both.

- **Tombstones are now visible.** A `(tombstoned)` tag is appended to a node's rendered title line
  wherever one gets printed: `renderTreeLines` (plain tree), `renderViewLines` (view-based tree), and
  all three of `renderLinkLine`'s output lines (a link's plain preview, its canonical full render, and
  its "see elsewhere" pointer) — the last of these specifically because a `Link.target` is exactly the
  "reached through a still-live reference elsewhere" case the original trace flagged as the more
  misleading of the two failure modes (silently showing stale content as current). One shared
  `tombstoneTag(node)` helper (`node.ts`) keeps the check and the marker text in one place rather than
  four independent copies.
- **Dangling `unfolds` entries are now swept automatically on delete.** `deleteSubdocument` (Step 8)
  is the *only* place a `Link`/`StringProp` is ever actually removed — every current deletion path
  (wikilink regeneration, Step 9's tombstone-consistency cleanup) already funnels through it. A new
  `removeDanglingUnfolds(store, deletedId)` runs there, right before an id's own quads are deleted:
  it sweeps every `TreeView`'s `unfolds` field for a reference to that id and removes it. Since
  `deleteSubdocument` already recurses into nested embeds (a `Link`'s own `props`), this call fires
  once per id at every level, covering both possible `unfolds` targets (`Link` and `StringProp`)
  uniformly, with no new call site needed at any deletion site, present or future.
- **Match-by-target reuse (Step 9) turned this from a design question into a correction opportunity
  worth noting for the record**: the original design for the tractable half of §5 (Step 9) required
  an *exact* target-and-position match to reuse a wikilink `Link`'s id — a real user correction
  caught this before implementation drifted further, since position drift alone (from an unrelated
  edit earlier in the same block) would have kept churning ids despite the fix's own goal. No new
  code here — noted because it's the same "identity vs. incidental metadata" distinction this step's
  own tombstone-visibility fix leans on (a tombstoned node's `title` isn't cleared either — it stays
  as last-known content, deliberately, not as an oversight).
- **Two brainstorming questions, answered and worth keeping on record:**
  - *When are tombstones themselves ever removed?* At the time this was asked: never — a tombstoned
    node kept its own quads (`title`/`type`/`text`/`tombstonedAt`) forever, mirroring TerminusDB's
    soft-delete model (a permanent "this used to exist, here's its last known state" record), with
    no expiry/compaction pass anywhere in the design. **Superseded by Step 11**: a tombstoned node
    is removed once nothing live can reach it any more (its own structural subtree already cleared
    at tombstoning time; the remaining question was always *incoming* references from elsewhere) —
    see Step 11's mark-and-sweep GC for the actual mechanism and when it runs.
  - *Is `deleteSubdocument`'s orphan cleanup a correctness requirement, or just eager garbage
    collection?* The latter, precisely — and more consequential than ordinary GC'd-language cleanup
    would be, for a reason specific to this runtime. Nothing is semantically broken by an orphaned
    `Link`/`StringProp` sitting around — `dehydrateToJsonLd` only walks structure reachable from its
    own top-level sweep (Step 8's own framing), so an orphan is invisible to the mirror either way.
    But `service.ts`'s `Store` is Rust compiled to WASM (`wasm-bindgen`), not a JS object — it lives
    entirely in the WASM module's own linear memory, managed by Rust's ownership model, not the JS
    GC. Rust's own collections do free memory internally when an entry is removed, reusable by later
    allocations *within* that linear memory — but WebAssembly linear memory itself can only *grow*
    (`memory.grow`); there is no instruction to shrink it back down. Whatever peak size the heap
    reaches, the WASM instance holds for the rest of the process's life, however much of it is later
    freed internally and sitting idle. So for this long-lived process specifically, letting orphans
    accumulate before cleaning them up — rather than never creating them in the first place — would
    leave a **permanent, irreversible** high-water mark: unlike a GC'd runtime, there is no way to
    ever hand that memory back to the OS short of restarting the process. Eager cleanup avoids that
    peak from forming at all, which is strictly more valuable here than the same cleanup would be in
    a language with a real tracing GC underneath. (Not independently verified against Oxigraph's own
    allocator/data-structure internals — this follows from WASM's memory model generally, which is
    well established; if it ever matters enough to confirm precisely, measuring process RSS across a
    long ingest-heavy `service.ts` session would settle it directly.)

**Verified**: `npm run build` clean; `npm run verify`'s full suite passing, plus two new cases run
*after* §7's dehydrate/rehydrate round-trip check (deliberately — both mint a `TreeView`/`Profile`
via `ensureDefaultView`, which is per-viewer state dehydrated separately from the main JSON-LD mirror,
Aperas-treeview-design.md §8, and so is out of scope for what §7's round-trip check exercises or
expects present in the store): §8 constructs a standalone tombstoned `BlockNode`, links to it from an
already-ingested block, and confirms the rendered line for that target carries `(tombstoned)`; §9
unfolds a freshly-minted `Link`, deletes it via the same `writeField`-embed-diff path Step 8 already
exercises, and confirms its `unfolds` entry disappears with it, with no dangling entry left behind.

### Step 11: `parent`/`PARENT_PRED` merge, mark-and-sweep tombstone GC, and `kg:unlink` — implemented, verified

Three related changes from one thread of questions about `PARENT_PRED`/`siblingIndex` internals and
the "hard half" GC design from Step 10.

**`parent`/`PARENT_PRED` merge.** `TreeNode.parent` (a `BlockNode`-only field) and `PARENT_PRED`
(the private `__parent` reification predicate every `orderedContainment` write already stamped on
each child) turned out to be two independently-written quads recording the exact same fact — every
write site set both, always in sync by convention, never by construction, confirmed by checking all
three: `hydrateFromParsed`'s per-child stamp, `ingestFromDisk`'s top-level stamp, and
`resolveCreate.ts`'s holder creation (which set `.parent` explicitly *and* called `appendChild`,
which stamps the same fact again). `ParsedBlockNode.parent`'s own doc comment gave away why the
separate field existed at all: a TDB-era workaround, since TerminusDB's `List`-typed `children`
couldn't be reverse-queried as a direct triple — precisely the constraint `PARENT_PRED`'s reified-
triples design was invented to eliminate. The field had simply outlived its own justification.
Fixed by merging: `parent` promoted to `TREE_NODE_SHAPE` (every tree-positioned kind gets it now,
`FolderNode`/`ArtifactNode` included, not just `BlockNode`), `PARENT_PRED` changed to
`predIri('parent')` (the exact IRI the generic field accessor already used), and every explicit
`.parent = ...` write site deleted — the `orderedContainment` write path (`writeField`,
`appendOrderedChild`) is now the *sole* writer, as a side effect of whichever container's `children`
write includes a given id. This retired `astParser.ts`'s `stampParents` entirely, along with the
"must be re-run after reconciliation reassigns ids" fragility its own doc comment described as a
confirmed-live bug before this was understood — there's no separate early stamp any more to go
stale, since the real `parent` quad is now written exactly once, using final ids, as part of the
container's own write. `structuralParentOf` collapsed from a `BlockNode`-vs-everything-else
dispatch to a single uniform `.parent` read for any kind. One residual hazard worth flagging, not
worth structurally preventing here: since the predicate is now shared, an ordinary `someNode.parent
= x` write (the generic optional-reference field setter, not the containment path) would make `x`'s
own `.children` include `someNode` too, with no `siblingIndex` recorded — landing it at sort-index 0
among `x`'s other children. Nothing after this merge ever assigns `.parent` directly any more; if
that changes, go through `.children`/`appendChild` instead (`vocab.ts`'s own doc comment on
`PARENT_PRED` carries this warning at the point someone would actually hit it).

**Aside, correcting something said in-session and worth getting right for the record:** the JSON-LD
mirror's plain `children: [...]` array (as opposed to the live store's `parent`/`siblingIndex`
reification) is *not* a design choice made for ApeironNgn's file format — it's inherited directly
from TerminusDB's own document-JSON export of a `List`-typed field (TDB's document view always
serializes a `List` as a plain array, Cons-chain or not, underneath), kept through the migration for
continuity. It happens to also be the *right* shape for a JSON file regardless of that history — a
JSON array's own position already encodes order, so there's nothing to reify at the file level the
way RDF triples need — but that's a fortunate fit, not the reason the shape exists. `dehydrate.ts`'s
`orderedChildIds`/`store.ts`'s `encodeDoc` translate losslessly between the two representations in
both directions (confirmed by §7's round-trip check, which compares exact quad counts).
`siblingIndex` stays private/internal, deliberately not promoted alongside `parent`: `parent` earns
public status because it's independently useful information about a node; `siblingIndex` is
meaningless outside its own container's context, so `parent` (up) plus `children` (down, ordered)
already cover both directions without it. Its values are contiguous `0..N-1` per parent today by
construction (every removal path is a full `children` rewrite, which always re-normalizes from array
position) rather than by any enforced invariant — worth a future guard if a surgical single-child
removal path is ever added without going through a full rewrite, not urgent now.

**Mark-and-sweep tombstone GC** — a new mechanism identified in a follow-up discussion after Step
10 shipped, extending the *same* deletion machinery (`hardDeleteNode`/`removeDanglingUnfolds`) to
top-level tombstoned documents, not just embedded `Link`/`StringProp` subdocuments. An initial
design for it checked each tombstoned candidate for *any* incoming reference at all, dead or alive,
and was caught before implementation as exactly the failure mode refcounting GC has with cycles — a
cluster of mutually-referencing tombstoned nodes, with nothing live pointing in from
outside, would show a nonzero referrer count from each other forever, and never qualify for
collection. Fixed with real mark-and-sweep instead (`node.ts`'s `pruneUnreachableTombstones`): the
mark phase starts from every live `ArtifactNode`/`FolderNode` (the only genuine roots — a live
`BlockNode` is always reachable transitively through its owning artifact) and walks `treeChildren`
plus each visited node's own `Link.target`s; anything tombstoned that's never marked — including a
whole disconnected dead cluster — is genuinely unreachable and gets hard-deleted. `deleteSubdocument`
(Step 8) renamed to `hardDeleteNode` and reused unmodified for this — it was already written
generically off `SHAPE_BY_KIND`, so it needed no changes to also delete a top-level kind, not just an
embedded one; it also already calls `removeDanglingUnfolds` (Step 10), so a pruned node's own
`unfolds` entries get swept in the same pass, no separate handling needed. Mutates the *live* store
directly rather than filtering what a subsequent dehydrate writes, so both `dehydrateToJsonLd` and
the separate `dehydrateStateToJsonLd` (over `TreeView`/`Profile`) see a consistent post-prune state
for free. Wired into `service.ts` at the three points that either always flush both mirrors together
or represent the "next startup" boundary directly: `reloadStore` (skipped on `discard`, which throws
away in-memory state instead of flushing it), `clobberFlush`, and `shutdown` (idle-timeout exit
included, each wrapped so a GC failure can't block the shutdown itself) — matching the "gone at the
next service startup" framing a prior conversation used to describe the intended behavior, now
actually true.

**`kg:unlink`** — the missing removal counterpart to `kg:link`, and the piece that actually lets the
GC above make progress on a real manual reference: without it, a `kg:link` pointing at a since-
tombstoned node had no way to ever be removed short of tombstoning its own owning block, permanently
pinning that target alive from the GC's perspective. `kgLink.ts`'s `runRemoveBlockLink(store,
blockRef, targetRef)` resolves both endpoints via deep-path resolution (unlike `runAddBlockLink`'s
`blockId`, which only ever arrives pre-resolved from `linkCandidates`' interactive flow — `kg:unlink`
has no candidate list to resolve it for you, so both sides need to accept a path here), then removes
any `predicate === 'references'` link on that block whose target matches, via the usual "read
current, filter, write once" `.links` reassignment — `writeField`'s embed-diff (`hardDeleteNode`)
handles the rest. Deliberately scoped to manual links only: a wikilink is self-managing (Step 9) and
would just reappear on the next ingestion if force-removed here. New `kgUnlink.ts` CLI, non-
interactive (unlike `kg:link`, a removal already needs both endpoints named, so there's no useful
candidate list to prompt over) — `kg:unlink -- <block> <target> [--flush]`. New service op
`removeBlockLink`, mirroring `addBlockLink`.

**Verified**: `npm run build` clean; `npm run verify`'s full suite passing, plus two new cases: §10
constructs two tombstoned `BlockNode`s referencing only each other (no live root reaches either) plus
a third tombstoned node kept alive by a manual link from a still-live block, and confirms the mutual
pair is pruned while the referenced one survives; §11 removes that surviving manual link via
`runRemoveBlockLink` and confirms a further GC pass then collects it, proving `kg:unlink` and the GC
compose correctly end-to-end.

## 5. Open questions

- Deferred, not forgotten: what happens when the KG grows to GB scale, given in-memory-only
  storage means the whole thing is rehydrated from `AperasKG/Apeiron/`'s JSON-LD on every process
  start and held entirely in RAM while running. Explicitly not solved now — revisit (`pyoxigraph`
  + a projection bridge, a native non-WASM Node binding, or something else) once size actually
  makes it a problem, not speculatively ahead of it.
- What pairs with Oxigraph for the regex/full-text secondary index (§3) — a hand-rolled index over
  the reified triples, or an existing embeddable engine (e.g. Tantivy)? **`kg:search`'s migration
  is deliberately blocked on this** — not migrated ad hoc via a plain store scan in the meantime,
  since that would just be thrown away once a real secondary index lands.
- `client.ts`/`crud.ts`/`woql.ts`/`graphql.ts` already isolate every TerminusDB-specific call
  behind named modules (`Aperas-architecture.md` §3) — does that boundary hold as-is for
  ApeironNgn, or does the lazy-traversal query model (§3) need a different shaped seam than
  "swap the implementation behind the same functions"?
- **Tombstoning consistency across the three places it happens — resolved by Step 9.** All three
  now clear `children`/`links`/`props` alike (`artifacts.ts`'s artifact-tombstone also gained
  recursive whole-subtree tombstoning, a second gap found while fixing the first) — see Step 9's
  own write-up in §4 for the full story.
- **`Link`/`StringProp` have no tombstone concept at all** — TerminusDB's `@subdocument` has no
  independent address, so nothing outside its owner could ever reference one; this entire class of
  problem is structurally impossible there. ApeironNgn's embedded subdocuments are real,
  independently addressable documents (their own `wrap()`-able snowflake-suffixed ids, dispatched
  through the same `classForId`/`nodeKindFromId` machinery as everything else) — a deliberate
  simplification (one uniform id/dispatch scheme, no second opaque storage mode for embeds), but it
  means they're peers, not truly enclosed, and can accumulate a dangling-reference problem ordinary
  top-level documents have tombstoning specifically to manage gracefully. `Link`/`StringProp` extend
  `ApeironInstance` directly, not `BaseNode` — no `tombstonedAt` field exists for them to carry, so
  `deleteSubdocument` (Step 8) is a genuine hard delete, no soft-delete step available even if
  wanted. Checked the actual blast radius before deciding how much this matters: `TreeView.unfolds`
  is the *only* `reference`-kind field anywhere in the schema whose target can be a `Link`/
  `StringProp` at all (`Link.target`/`BlockNode.parent` only ever point at `TreeNode`-kind things)
  — so whatever this becomes, it's narrowly scoped today, not a general problem.
  - **The tractable half: wikilink `Link`s used to churn identity even when nothing changed —
    resolved by Step 9.** See Step 9's own write-up in §4 for the full mechanism (moving the
    reuse-or-remint decision from `hydrateFromParsed` into `resolveBlockLinks`, keyed on `target`
    alone against a snapshot of each block's prior wikilink `Link`s — `position` drift alone
    updates a matched `Link`'s `props` in place rather than reminting).
  - **The hard half: a genuinely *removed* `Link`/`StringProp` used to have no graceful-degradation
    story beyond "silently absent" — resolved by Step 10.** Traced first (`renderTreeWithView`/
    `buildViewRenderContext`/`renderLinkLine`, `node.ts`) to answer precisely rather than assumed:
    the real prior behavior was **"a tombstoned node still renders as if alive" vs. "a deleted
    `Link` in `unfolds` renders with zero trace at all"** — two different invisible failure modes,
    not "tombstone marker vs. nothing" as first assumed, with the tombstoned case arguably the more
    misleading of the two since it actively shows stale content as current. Step 10 fixes both: a
    `(tombstoned)` render tag for the first, an automatic `unfolds`-sweep on delete for the second.
    See Step 10's own write-up in §4 for the mechanism.
