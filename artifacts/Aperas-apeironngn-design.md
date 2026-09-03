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
  result. `ArtifactNode`/`FolderNode` follow the same pattern (`root`/`children` as `reference`,
  their own scalar fields as `one`/`optional`), inheriting `links`/`props` from `BaseNode`.
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
5. **A shared service process — not started, to be designed later.** Every `kg*Ngn.ts` invocation
   today calls `rehydrateStore()` cold and discards the `Store` at process exit; no state survives
   between CLI calls. Measured against the real corpus: rehydration itself is ~256ms (9671 quads,
   1482 nodes), but a full CLI invocation is ~1.6s wall-clock — so the rehydrate is actually the
   *minor* cost, most of it being Node/tsx process spawn and TypeScript transpilation, which a
   persistent process would eliminate outright regardless of corpus size (a different concern from
   §5's already-open "what happens at GB scale" question — this is per-invocation setup cost, not
   working-set size). Deliberately deferred: a shared process reintroduces exactly the concurrency/
   shared-mutable-state question §3 opted out of ("no shared mutable database, no locking, no
   transaction isolation to build") and needs real answers for write-serialization across
   concurrent CLI callers, an IPC/RPC transport, and a staleness story (noticing when
   `AperasKG/Apeiron/` changes underneath it, e.g. from a `git pull`) before it's worth building.

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
  - `treeChildren` → `this.root ? [this.root] : []`; `appendChild` sets `this.root`, throwing if
    one already exists (a node that already has a root can't gain a second one this way — same
    schema-shape constraint `nodeRef.ts` documents against real TerminusDB behavior). The rich,
    title-specific version of that error (`` `${id} already has a root block — can't create
    '${title}' as a second one...` ``) stays in `resolveCreate.ts`'s own pre-check, run *before*
    minting a holder so a rejected create never leaves an orphan `BlockNode` behind;
    `appendChild`'s own version is a generic backstop, never actually the one a real caller sees.
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
  - `resolve.ts`/`resolveCreate.ts`'s outer search (`resolveArtifactOrFolderPrefix`,
    `resolveDeepPath`, `resolveDeepPathDetail`, `createImaginedPrefix`) — multi-root search and
    cross-node creation across the whole store; calls `.findChild()`/`.appendChild()` per hop now.
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
instead of spawning a second copy. The winner spawns `npx tsx service.ts` detached and unref'd
(same invocation style every `kg:xxx` script already uses via `npx tsx`, so no new devDependency),
and the spawned process itself overwrites the lock with its own pid and `status:'ready'` once
`listen()` succeeds — the lock always reflects the actual owning process, not the process that
happened to start it.

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

**Wire protocol.** Newline-delimited JSON, one request per connection (client connects, writes one
line, reads one line, closes) — `JSON.stringify` always escapes an embedded `\n`, so this framing
needs no parser beyond a string split.
```ts
type ServiceRequest =
  | { op: 'ping' }
  | { op: 'track'; paths: string[]; flush: boolean }
  | { op: 'ingest'; flush: boolean }
  | { op: 'unfold'; ref: string; flush: boolean }
  | { op: 'fold'; ref: string; flush: boolean }
  | { op: 'resolve'; paths: string[]; base?: string; createHolder: boolean; titles?: string[]; flush: boolean }
  | { op: 'titleCandidates'; pathArg: string; recursive: boolean }         // read-only, lists kg:title's prompt targets
  | { op: 'setBlockTitle'; blockId: string; title: string; flush: boolean }
  | { op: 'linkCandidates'; pathArg: string; recursive: boolean; all: boolean } // read-only, lists kg:link's prompt targets
  | { op: 'addBlockLink'; blockId: string; targetRef: string; flush: boolean }  // targetRef resolved server-side
  | { op: 'project'; path: string }                              // read-only; result carries rendered markdown
  | { op: 'tree'; pathArg: string; maxDepth?: number; noHolders: boolean; unfoldedMode: boolean }
  | { op: 'path'; idArg: string };

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
