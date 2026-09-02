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
   - **`kg:project --dry-run` — done, diffed clean.** `apeironNgn/project.ts`
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
     artifact file) is still out of scope — that write targets the filesystem, not this step.
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
3. **Fold migrated functions into class methods.** §3's classes are deliberately *mere schema* at
   first — field access and shape enforcement only, no behavior — specifically so step 2's
   migrations stay easy (point an existing free function at a class instance, don't simultaneously
   rewrite it into method form). Once a function has been migrated and diffed clean per step 2,
   this step folds it onto its natural class as a method (e.g. `project.ts`'s Markdown serializer
   → a `BlockNode` method) — one function at a time, each fold diffed against the still-standing
   free-function version before being considered done, same discipline as step 2 itself. This is
   what actually closes §1's "ties data structure directly with control structure" mental model;
   without this step the classes would stay permanently schema-only, which was never the intent.
4. **Archive the TerminusDB-based scripts once every script has migrated and verified clean.**
   Archived, not deleted — kept for reference/rollback, not discarded.

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
