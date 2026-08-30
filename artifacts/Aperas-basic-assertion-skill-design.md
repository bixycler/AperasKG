# Basic Assertion Authoring — Design

## 0. Why this moved out of Phase 2

The original roadmap (`Aperas-design.md`'s Development Roadmap) only ever named one assertion-
related deliverable — Phase 2's "graph search skill" — and treated the Human UI (Phase 1) as
the thing that lets humans/agents see what's in the graph at all. Neither assumption survived
Phase 0 finishing:

- `Assertion` (the concrete `BaseEdge`, `Aperas-core-ontology-design.md` §2.C-D) has been a
  fully working CRUD/WOQL primitive since Phase 0 — `insertAssertion`/`deleteAssertionsInvolvingNode`
  (`crud.ts`), `queryNodeAssertions`/`traceImpactPropagation` (`woql.ts`) — but the *only* thing
  that has ever called `insertAssertion` is a single hardcoded synthetic edge in
  `verifyPhase0.ts`'s test harness. Nothing lets a human or agent write a real one.
- Artifact Projection (`Aperas-artifact-projection-design.md`) turned out to cover the
  monitoring need the Human UI was assumed to be required for — `kg:project` already lets a
  human read back exactly what's stored, without a SolidJS front end.

So the basic ability to *write and inspect* a real `Assertion` — with no automated traversal,
impact-sweeping, or agent behavior attached — is built now, in Phase 0, so that Phase 1's
skill-building work starts with it already available rather than blocked on it. Phase 2's
"graph search skill" (`Aperas-design.md` §Development Roadmap, Phase 2) still owns everything
*automated*: agents that traverse `affects`/`impacts` edges on their own initiative and flag
staleness. This doc only covers the manual primitive those agents would eventually build on.

## 1. Scope: manual, not automated

This is a CLI-operated capability, not a skill that runs on its own. A human or an agent
explicitly invokes a command to assert one claim, or to look up what's already asserted about
a node. No code here decides *when* to assert something or walks the graph proactively — that
remains Phase 2 territory, undesigned.

## 2. Addressing is direct-or-query, not "resolution" or "memory"

- **Direct addressing** — the normal case. You already hold a real node id, from wherever (a
  prior command's own printed confirmation, a query result, code that still has the parsed
  tree available). `AssertionInput.source`/`target` (`BlockNode/<id>`, `ArtifactNode/<id>`,
  `FolderNode/<id>`) is passed through completely unchanged — no lookup, no search, nothing to
  resolve.
- **Query-based addressing** — applies when there's no id in hand at all. The simplest query
  this project has is an exact match on a path, and both path-addressable node kinds get it
  identically: a bare artifact path (e.g. `Aperas-design.md`) resolves via the existing
  `getArtifactRecord` (`artifacts.ts`) to `ArtifactNode/<artifactId>`, and a bare folder path
  (e.g. `.` for the artifacts root, or a subdirectory name) resolves via the structurally
  identical `getFolderRecord` (`folders.ts`) to `FolderNode/<folderId>`. An artifact path and a
  folder path never collide, so trying artifact-then-folder resolution in that order is
  unambiguous. (Earlier revisions of this doc called this "from memory" — that framing
  conflated an ordinary exact-match query with a distinct human-recall mechanism; see
  `Aperas-agentic-query-tools-design.md` §1 for the fuller correction and the complete
  inventory of what query tools this project actually has.)

`BlockNode` has no path-like shortcut: nobody carries an opaque id in their head or types block
content as a handle. So a block-level assertion needs either an id already in hand from
whatever produced the claim (e.g. a skill that just parsed content and still holds the tree), or
a real query tool to find one — see `Aperas-agentic-query-tools-design.md` (`kg:tree`,
`kg:expand`, `kg:search`), which closes this gap three ways: a structural map, a one-level
content peek, and keyword/regex search. (Superseded reasoning, kept for context: this doc
originally argued no such command was needed in Phase 0, since nothing yet created a situation
requiring one — that held until the need was recognized as a set of general-purpose query
tools in their own right, not just an assertion helper.)

## 3. Commands (`kgCli.ts`)

- `kg:assert <source> <predicate> <target>` — `source`/`target` each accept a full node id
  (direct addressing) or a bare artifact/folder path (query-based addressing, per §2); calls
  `insertAssertion`.
- `kg:assertions <node>` — same addressing as above, calls `queryNodeAssertions`, prints each
  as `<direction>  <predicate>  <otherNodeId>`.
- `kg:unassert <source> <predicate> <target>` — same addressing, deletes exactly the matching
  assertion(s), not every assertion touching a node. `deleteAssertionsInvolvingNode` (existing,
  `crud.ts`) is intentionally blunt — it exists for demo/reset cleanup, where wiping everything
  touching one node is correct. A real "undo this claim" command needs a narrower
  `deleteAssertion(client, source, predicate, target)`: filter `Assertion` docs on all three
  fields (not just one), delete only those. New function, `crud.ts`.

## 4. Real bug found by live testing (fixed)

`kg:assertions` initially printed the predicate as `[object Object]`. WOQL binds a node-typed
field (`source`/`target` — `BaseNode`) as a plain id string, but a literal-typed field
(`predicate` — `xsd:string`) as a wrapped `{"@type": "xsd:string", "@value": "..."}` object —
confirmed live by querying directly. `traceImpactPropagation`'s existing test coverage never
caught this because it only checks binding *presence*/*membership* (`AffectedNode`, itself
node-typed), never a literal field's actual value. Fixed in `woql.ts`'s `queryNodeAssertions`
with a small `unwrapLiteral` helper applied to `predicate` in both directions.

## 5. Out of scope

- Any automated creation or traversal (Phase 2's graph search skill).
- Per-asserter branch placement — `Aperas-core-ontology-design.md`'s "Author-Based Placement"
  (§ Design Rationale) describes assertions eventually living in the asserting agent's own
  branch/artifact so they don't require mutating someone else's. That's a multi-agent-branching
  concern (Phase 3 territory); today, same as every other write in this codebase, an `Assertion`
  simply commits to whatever branch the client is already pointed at (`main`). Not addressed
  here.
- Restricting `predicate` to a fixed vocabulary — stays free text, same as `insertAssertion`
  today; the known examples (`impacts`/`verifies`/`derived_from`/`affects`) remain
  conventions, not an enum.
