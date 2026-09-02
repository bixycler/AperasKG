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
   script.** Incremental, verified, not a big-bang cutover — each `kgCli.ts` command (`kg:track`,
   `kg:ingest`, `kg:tree`, `kg:unfold`/`kg:fold`, `kg:search`, `kg:assert`/`kg:assertions`/
   `kg:unassert`, `kg:path`, `kg:project`, ...) gets its own ApeironNgn implementation, run against
   the same real data, and diffed against its existing TerminusDB-backed output before being
   considered migrated — the same live-verification discipline already standard here
   (`kg:track && kg:ingest && build && verify:phase0 -- --db`), applied to the migration itself
   rather than skipped for it.
3. **Archive the TerminusDB-based scripts once every script has migrated and verified clean.**
   Archived, not deleted — kept for reference/rollback, not discarded.

## 5. Open questions

- Deferred, not forgotten: what happens when the KG grows to GB scale, given in-memory-only
  storage means the whole thing is rehydrated from `AperasKG/Apeiron/`'s JSON-LD on every process
  start and held entirely in RAM while running. Explicitly not solved now — revisit (`pyoxigraph`
  + a projection bridge, a native non-WASM Node binding, or something else) once size actually
  makes it a problem, not speculatively ahead of it.
- What pairs with Oxigraph for the regex/full-text secondary index (§3) — a hand-rolled index over
  the reified triples, or an existing embeddable engine (e.g. Tantivy)?
- `client.ts`/`crud.ts`/`woql.ts`/`graphql.ts` already isolate every TerminusDB-specific call
  behind named modules (`Aperas-architecture.md` §3) — does that boundary hold as-is for
  ApeironNgn, or does the lazy-traversal query model (§3) need a different shaped seam than
  "swap the implementation behind the same functions"?
