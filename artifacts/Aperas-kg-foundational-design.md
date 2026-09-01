# KG Foundational Design: Triples, Schema, and Structural Containment

**Status: foundational discussion.** Synthesizes two open threads into one architectural stance,
laid out along the project's own Apeiron —[Aperas]→ Peras transduction: triples, queried natively
via WOQL (§1); schema crystallizing into a Peras, projected via GraphQL, at a cost (§2); `List` as
a further bound within that Peras, with its trade-offs and candidate solutions (§3).

## 1. Apeiron: triples are ground truth, queried natively via WOQL

TerminusDB stores RDF triples. Schema declares shape and type over those triples, but it does not
gate what's queryable — WOQL matches triples directly, with no notion of class hierarchy at all.
Confirmed live: an untyped `WOQL.triple` query finds `Assertion` documents through two abstract
levels (`BaseLink → BaseEdge → Assertion`) with zero type constraint, identically to a version with
an explicit `rdf:type` constraint added (`Aperas-markdown-fractal-mapping-design.md` §7). This one
fact is the premise everything below follows from: **schema in this project is not the source of
the graph's query semantics — the triples already are, independent of any class declared over
them.**

**In the project's own Apeiron/Aperas/Peras vocabulary** (`Aperas-design.md`'s "Metaphysical
foundation," conceptual triad Unbounded–Unbound–Bound): the unbound substrate is just the bundle
of links — triples, Apeiron, "the unconditioned, schema-free continuum where thoughts and semantic
links flow without artificial boundaries." Schema is where *patterns emerge* for some of those
links to bind — Aperas the transduction, "the active emergence of structured Peras out of the
unconditioned Apeiron" — while everything not addressed by a bound pattern stays reachable exactly
as it was. That's why WOQL, operating at the Apeiron level directly, was never blocked by any of
this: a boundary agent hitting a schema violation gets "type validation tracebacks... fed back...
without polluting the fluid core" (`Aperas-design.md`) — the core stays unbound even when a
particular boundary (GraphQL, `@abstract`'s codegen gap) is strict. Schema doesn't carve the
substrate; it crystallizes one navigable Peras out of it, leaving the rest of the substrate exactly
as unbound as before.

## 2. Peras: schema crystallized, projected via GraphQL — and its costs

Since WOQL bypasses schema-derived typing entirely (§1), schema cannot be improving what's
queryable — there is no query it unlocks that raw triples didn't already support. `props: Set<Prop>`'s
`key`/`value` pairs come back from `WOQL.triple` identically whether or not a `rdf:type` constraint
is added (`Aperas-markdown-fractal-mapping-design.md` §7, tested both ways, same 50 bindings
either way).

What schema actually does, concretely, in this project:

- **Write-time validation.** TerminusDB refuses a write that doesn't match schema. This project
  has already relied on that as a forcing function, not just a safety net: the `artifactId`/
  `folderId` Snowflake-key migration required a full wipe of existing documents because
  TerminusDB rejected the old instances against a schema with new required fields
  (`Aperas-dev-status.md`, "Reconciliation matching" entry). A writer bug that produces a
  malformed document is caught immediately, not discovered later as a silently dangling or
  malformed node.
- **Identity strategy.** `@key` (`Lexical` on `blockId`/`artifactId`/`folderId`, `Random` for
  `StringProp`) is a schema-level declaration, and it's what decides the addressing scheme —
  path-based vs id-based lookup — every reader (`getArtifactRecord`, `getFolderRecord`, `kg:path`)
  depends on.
- **Polymorphism, bought and paid for.** `@abstract BaseNode`/`BaseLink`/`BaseEdge` let
  `BlockNode`/`ArtifactNode`/`FolderNode` and `Link`/`Assertion` share fields once instead of each
  redeclaring them — this is what made the `unfolded` promotion a one-line schema move rather than
  three separate field additions (`Aperas-agentic-query-tools-design.md` §4). The cost of that
  same abstraction shows up directly in GraphQL: `@abstract` classes don't materialize as GraphQL
  interfaces/unions (`possibleTypes: null`, confirmed via introspection), so any field typed to an
  abstract class loses subclass-specific fields there — the `_json` workaround
  (`Aperas-markdown-fractal-mapping-design.md` §7). That gap is a direct, traceable consequence of
  the schema's abstraction choice, not an unrelated TerminusDB quirk — WOQL, working off triples
  rather than schema-derived types, never had the problem.
- **Codegen surface.** The GraphQL API and the Document API are both auto-derived from schema.
  `graphql.ts` exists, and inherits its quirks, specifically *because* something generates a typed
  API from the schema — there'd be nothing to generate from raw triples.
- **Bulk subtree projection — an instance of the codegen point, worth calling out on its own.**
  Fetching a whole nested tree (`ArtifactNode.root` down through every `BlockNode.children`) in one
  round trip, rather than one document fetch per node, is itself schema-dependent, not free at the
  triple level. `client.getDocument()` on its own returns `root`/`children` as bare id references —
  a nested fetch needs an explicit schema-level annotation to know it should unfold: property-level
  `"@unfold": true` or class-level `"@unfoldable": []` (`Aperas-architecture.md`'s read-path note).
  GraphQL gets the same capability differently — its generated query shape mirrors the schema's own
  `List`/`Set`/`Optional` nesting directly, so `root { children { children { ... } } }` is a single
  selectable query precisely because the schema declared that nesting in the first place.

  **Benchmarked live** against the real 149-block `Aperas-core-ontology-design.md` tree: the
  **Document API**, driven by class-level `@unfoldable` (works, including recursively through
  `List<BlockNode>`), ran \~3.5x slower than **GraphQL**'s `getArtifactTreeViaGraphQL`
  (\~48ms vs \~13.5ms steady-state) — so GraphQL was kept as the tree-read path
  (`Aperas-architecture.md`'s read-path note). To be precise about what that number says: it's the
  **Document API's** `@unfoldable` mechanism that's slower, not "schema" as a concept and not
  GraphQL — both are schema-enabled projections of the identical nested shape, exercised through
  two different generated surfaces, and one of those two surfaces measurably wins.

  **The other side of the same trade-off: node-by-node ("paired") reconstruction, benchmarked live
  across all three APIs** (`bench-tree-fetch-strategies.ts`, kept in `web/src/lib/` for reuse), same
  91-node `Aperas-core-ontology-design.md` tree, root fetched once then walked recursively, one
  fetch per node, building only the raw block tree (no Markdown projection):

  | Approach | Time | vs. bulk |
  |---|---|---|
  | ApeironNgn (in-process Oxigraph, post-rehydration walk — `Aperas-apeironngn-design.md`) | 5.6ms | 0.3x |
  | Bulk GraphQL (`getArtifactTreeViaGraphQL`) | 18.3ms | 1x |
  | Node-by-node, GraphQL (shallow query/node) | 826ms | 45x |
  | Node-by-node, WOQL | 2882ms | 158x |
  | Node-by-node, Document API (`getDocument({id})`) | 4364ms | 239x |

  Bulk wins by nearly two orders of magnitude over *every* TerminusDB node-by-node alternative,
  regardless of API — confirming §2's premise concretely rather than by argument alone: the win is
  specifically in amortizing round-trip count via schema-declared nesting, not in which API happens
  to serve the bulk request. ApeironNgn beats even the bulk path, for a different reason — no round
  trip at all, bulk or otherwise, since the store lives in-process; its one cost the others don't
  carry is a one-time whole-store rehydration (270ms this run), amortized across every artifact a
  running process touches, not repeated per request.

  **Why the TerminusDB ordering is Document API (slowest) > WOQL (middle) > GraphQL (fastest), not
  ranked by call count** — instrumented directly (`bench-tree-fetch-strategies.ts`'s `callCounts`),
  not inferred:

  | API | Calls | Cost/call |
  |---|---|---|
  | Document API | 91 | 48.0ms |
  | GraphQL | 91 | 9.1ms |
  | WOQL | 454 | 6.3ms |

  WOQL makes 5x more calls than either of the other two (the cons-cell chain walk costs one extra
  round trip per list element, on top of the per-node type/title/text/head lookups — §3), yet still
  finishes faster in total than Document API, because its per-call cost is the *cheapest* of the
  three. Document API loses on both axes that matter: not fewer calls than WOQL, and far more
  expensive per call than either alternative — real extra server-side work per single-document
  fetch (schema-aware document assembly/validation) and client-side work (fuller object
  materialization by the `terminusdb` JS package), not just "one call, therefore cheap."

  **The heterogeneous-node problem is identical for WOQL and GraphQL, and it's the real reason
  node-by-node can't just be "ask for whatever fields this node has."** Neither the RDF triple layer
  nor GraphQL's generated types have a notion of "project whatever named fields this node's concrete
  type happens to declare" without being told the type first — this is the same root cause as §2's
  abstract-class GraphQL gap, just hitting WOQL too, since a hand-written WOQL query needs concrete
  field names the same way a GraphQL selection does. Concretely, fetching a mixed-type tree (say,
  `FolderNode → ArtifactNode → BlockNode`) via either API decomposes into three steps, not two:
  (1) get the topology (which node contains which, via which predicate — the traversal itself isn't
  uniform either, since `FolderNode.children`/`BlockNode.children` use `children` but
  `ArtifactNode.root` uses `root`); (2) fetch **homogeneous per-type fragments** — one query per
  concrete type, since within a type the fields are uniform; (3) **stitch** — join topology and
  fragments back into one nested tree by id, client-side. Step 3 is the true second pass, and it's
  where GraphQL's bulk-fetch win actually comes from: `getArtifactTreeViaGraphQL`'s ~18ms *already
  includes* that stitching, done server-side as part of query execution, which is exactly why a
  from-scratch node-by-node rebuild (paying for traversal, per-type fragments, *and* client-side
  stitching separately) loses by two orders of magnitude to a mechanism that does all three in one
  server-side pass.
- **A checked, not just written-down, ontology.** `@abstract` on `Prop`/`BaseLink`/`BaseEdge`
  states "never instantiate this directly" as an enforced fact (TerminusDB itself refuses the
  instantiation), not a convention a future contributor has to remember from reading
  `Aperas-core-ontology-design.md`. `Assertion`/`Link`/`StringProp` exist purely to make an
  otherwise-inert abstract lineage instantiable.

## 3. `List`: a further bound within the Peras — trade-offs and candidate solutions

Within the crystallized Peras (§2), `List` is a further bound layered on top of the schema's own
binding: schema alone says *this link exists, typed thus*; `List` additionally says *these links
are ordered*. That second constraint is not free — the trade this project already found is that
order is bought at the cost of the link's reciprocity: an ordered (`List`) link has no native
return path, where an unordered (`Set`) one does.

- `Set`/`Optional` fields sit as direct triples, which is why they get free reverse traversal —
  `t(X, 'links', targetId)` finds the owner with no extra bookkeeping.
- `List` fields are represented through cons-cell/RDF-linked-list indirection at the triple level,
  which is why the identical query returns nothing for `children` even though the child is
  genuinely present (`Aperas-core-ontology-design.md` §3.A). **The forward direction isn't a clean
  escape from this either — confirmed live while building the node-by-node WOQL benchmark (§2):**
  `t(parentId, 'children', v.Child)` *does* bind, but not to the member value — it binds to
  TerminusDB's internal cons cell (`"Cons/Xfw2qZ4yvCD0e3MM"`, not `"BlockNode/00C7BJZ8Y8001"`, what
  the Document API returns for the same field). Querying that cons cell directly shows the real
  shape: `rdf:type: rdf:List`, `rdf:first: <the actual value>`, `rdf:rest: <next Cons, or rdf:nil at
  the end>` — a genuine RDF linked list, requiring an explicit walk (one extra round trip per
  element) to recover real values in either direction. So `List` gives plain `triple()` no shortcut
  at all, forward or reverse — only a schema-level mechanism (class-level `@unfoldable`, GraphQL's
  generated nesting) resolves it without manual cons-walking.
- This project's structural containment (`BlockNode.children`, `ArtifactNode.root`,
  `FolderNode.children`) chose `List` deliberately, because child order is semantically meaningful
  (document/section order — `project.ts`'s Markdown serializer depends on it) and `Set` is
  unordered. That choice was correct for what it optimizes for; it was never a free choice,
  because it forfeits native reverse traversal in exchange for preserving order.
- Consequence: reverse lookup on a `List` field has to be hand-built as a backlink field
  (`parent: Optional<BaseNode>`, built for `kg:path`'s id→path need —
  `Aperas-deep-path-resolution-design.md` §8) rather than inherited for free.

### 3.1. `parent` is `BlockNode`-only, not yet `BaseNode`

`FolderNode` has no `parent` field at all today. Two consequences:

- **Nested `FolderNode` → `FolderNode` containment** gets no back-pointer — `buildFolderTree`
  (`folders.ts`) pushes a child `FolderNode` object into `structuralChildren` without stamping
  anything on it.
- **A `FolderNode`'s `ArtifactNode` references** are plain id strings
  (`` `ArtifactNode/${artifactId}` ``), not documents — there's nothing to stamp `.parent` onto at
  the point they're referenced at all.

This is the same shape of gap `unfolded` had before it was promoted to `BaseNode`
(`Aperas-agentic-query-tools-design.md` §4: designed against `BlockNode` only, then `FolderNode`/
`ArtifactNode` were added as concrete classes later without the field following them).

**A real asymmetry with the `unfolded` precedent, worth flagging before treating this as the same
fix**: `unfolded` only ever needs to survive on the node's *own* record — `trackArtifact`/
`buildFolderTree`'s existing carry-forward machinery (read `existingByPath`/`existing`, spread the
old value forward) is enough. `parent` is different: for the `ArtifactNode`-by-id-reference case,
the *referencer* (`FolderNode`) would need to write into the *referenced* document
(`ArtifactNode`), not its own. That's a cross-document write `trackArtifact` doesn't do today — it
would need to know its owning `FolderNode`'s id at track time, which the current one-directional
"folders reference artifacts by id" flow doesn't give it. Promoting `parent` to `BaseNode` is not
just a schema-field copy-paste the way `unfolded`'s promotion was; the `ArtifactNode` case needs
new plumbing.

### 3.2. Backlink as a general pattern for future `List` fields

The general claim: for any `Source.field: List<Target>`, a backlink field on `Target` recovers
"who points at me" — sidestepping `List`'s cons-cell indirection by putting the reverse pointer on
a field type (`Optional`/`Set`) that TerminusDB does back with a direct triple. True, with three
caveats that matter once this stops being about `parent` specifically:

- **Cardinality must match on the target side.** `Optional<Source>` works only when each `Target`
  has exactly one owner (tree/forest shape) — true for `children`/`root` today. A `List` used for
  a many-to-many relation (the same `Target` legitimately referenced from more than one
  `Source.field`) needs `Set<Source>` on the target instead of `Optional<Source>` — still
  triple-backed, still works, just a different field type chosen to match real cardinality.
- **Not automatic — it's a second, hand-synced field.** TerminusDB doesn't maintain inverse edges
  the way a native property graph (e.g. Neo4j) treats a relationship as one bidirectionally
  traversable object. A backlink is an independent field every writer that mutates the forward
  `List` must remember to also update, forever — nothing in the schema enforces the two stay in
  sync. This project is already paying that cost for `parent`: `astParser.ts`'s `stampParents`
  post-pass, the re-stamp-on-splice in `folders.ts`'s README absorption, and the real bug
  `reconcile.ts` had to fix where `blockId` reassignment on a matched pair desynced `parent` from
  the fresh value (`Aperas-deep-path-resolution-design.md` §8). Generalizing the pattern means
  generalizing that maintenance obligation to every future `List` field that adopts it.
- **Recovers identity, not position.** A backlink answers "which container holds this node," not
  "at what index." `project.ts`'s serializer depends on list order today via the forward `List`
  itself (unaffected by any of this — forward reads go through the Document API, which returns
  `List` order intact). A future need for "what's my index in my parent's `children`" would need
  an explicit index/order field alongside the backlink, not something the backlink pattern gives
  for free.

**Standing principle for future `List` fields**: build the backlink reactively, once a concrete
consumer needs reverse lookup — the way `parent` was actually built for `kg:path`, not
speculatively for every `List` field up front. `List` vs `Set` is decided by whether order matters
for that field; the backlink is decided separately, by whether reverse lookup is ever actually
needed.

### 3.3. An alternative to backlink-on-target: a parallel `Set` alongside the `List`

Of §3.2's caveats, two are genuine weaknesses rather than mere usage notes: the hand-sync fragility
(a second field, on a *different* document, that nothing enforces staying in sync — the exact
category of bug `reconcile.ts` already had to fix once) and the cross-document-write plumbing §3.1
found missing for `FolderNode`'s `ArtifactNode`-by-id references. Both stem from the same root
choice: putting the reciprocal pointer on the *target*.

An alternative: instead of (or before reaching for) a backlink field on the target, add a `Set`
field on the *source* that mirrors the same membership the `List` already holds —
`children: List<BlockNode>` alongside, say, `childrenSet: Set<BlockNode>` — both populated from the
same array, in the same write, by the same function. `List` carries order; `Set` carries the
graph-native reverse edge, since (established above, §1/§3) a `Set` is what TerminusDB backs with a
direct triple. Reverse lookup then becomes an ordinary `t(X, 'childrenSet', targetId)` query — no
field write on the target/child document at all.

What this fixes relative to backlink-on-target:

- **No cross-document write.** The reciprocal field lives on the *same* document as the `List` it
  mirrors, populated by the same constructor that builds the `List`. This is exactly what §3.1
  flagged as missing for `ArtifactNode` referenced by bare id inside `FolderNode.children` — a
  parallel `Set` on `FolderNode` itself needs no plumbing into `ArtifactNode` at all, sidestepping
  the gap rather than closing it the hard way.
- **Sync risk becomes local, not cross-document.** Still two fields to keep consistent — nothing
  makes that automatic — but both are on one document, settable by one local invariant ("derive
  `childrenSet` from `children` right here"), not a contract between two independently-written
  documents that can drift the way `parent` did.

What it does *not* fix: **position-blindness is unchanged.** A `Set` is exactly as order-free as
the backlink was — it answers "is C a child of P," not "at what index." That gap stays open
regardless of which reciprocity mechanism is chosen; an index field, if ever needed, is a separate
addition either way.

It also trades away something `parent` had: `doc.parent` is an O(1) field read on the child itself,
needing no query. A parallel `Set` moves that same lookup from "read a field" to "run a WOQL
triple query" — still cheap and native, per §1, but a query rather than a stored fact on the node
in hand. Whether that trade is worth it likely depends on the access pattern: `kg:path` reads a
single node's parent repeatedly while walking upward (favors a stored field); a one-off "who
contains this" lookup has no such advantage (favors the query, and avoids the write entirely).

## 4. Unifying stance

In this KG, both the containment field-type choices (`List` vs `Set`/`Optional`) and the schema
itself are best understood as **deliberate trade-offs made at the edges of the graph, not as the
graph's semantics**. Query power via WOQL is already maximal and schema-agnostic — nothing about
class hierarchy or field type changes what a triple-level query can find. What field-type and
schema choices actually buy or cost is: which reverse navigations are free versus hand-built and
hand-synced (`List` vs `Set`), and which of write-time integrity, addressing, and generated-API
ergonomics improve or degrade (schema shape generally, `@abstract` specifically). Any future
decision — a new `List` field, a new `@abstract` class, a new typed reference — should be
evaluated against those edges specifically, not against an assumption that it changes what's
queryable, because per §1 it doesn't.

## 5. Concrete precedents this stance is drawn from

- `unfolded`'s promotion to `BaseNode` — cheap, because it only needed to share a field, not
  reroute a query capability (`Aperas-agentic-query-tools-design.md` §4).
- `parent`'s construction — built specifically for `kg:path`'s id→path need, not speculatively
  ahead of a consumer (`Aperas-deep-path-resolution-design.md` §8).
- `Prop`/`_json` — the GraphQL-specific tax paid for `Prop` being `@abstract`, absent entirely from
  the equivalent WOQL read path (`Aperas-markdown-fractal-mapping-design.md` §7).

## 6. Open questions

- Promote `parent` to `BaseNode` now — accepting the `ArtifactNode` cross-document-write plumbing
  it needs beyond what `unfolded`'s promotion required (§3.1) — or replace the whole approach with
  a parallel `Set` (§3.3), which sidesteps that plumbing entirely?
- Formalize "every `List` field gets a matching backlink" as a standing schema convention, or keep
  deciding case-by-case as `parent` itself was decided (§3.2)? If formalized, backlink-on-target or
  parallel-`Set`-on-source (§3.3) as the default shape — or pick per field based on whether the
  access pattern favors a stored O(1) field read (`parent`) or a one-off query with no
  target-document write (parallel `Set`)?
- Given GraphQL-specific readers are the only ones paying the abstract-class tax (§2), is there a
  case for migrating more read paths onto WOQL, or is GraphQL's ergonomics worth the cost case by
  case?
- Does this stance argue for more conservative introduction of future `@abstract` classes, given
  each one is a GraphQL cost with no offsetting query-power gain (since WOQL never needed the
  abstraction in the first place)?
- Node-by-node WOQL (156x bulk, §2) still used plain `triple()`/cons-walking, not `path()`. Given
  the gap to bulk is nearly two orders of magnitude either way, is `path()` worth benchmarking as a
  narrower optimization (fewer round trips for topology specifically), or does the heterogeneous-
  fragment/stitching cost (§2) dominate regardless of how topology alone is fetched?
