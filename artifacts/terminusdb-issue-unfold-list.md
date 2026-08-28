# Upstream issue: property-level `@unfold: true` is a no-op on `List` properties

Filed against `terminusdb/terminusdb` as [#2512](https://github.com/terminusdb/terminusdb/issues/2512) (2026-08-29). Related: [#2321](https://github.com/terminusdb/terminusdb/pull/2321) (introduced field-level `@unfold`).

## Title

Field-level `@unfold: true` is a no-op on `List`-typed properties (works on `Set`/`Optional`/`Cardinality`); likely a gap in #2321

## Body

**Describe the bug**
Property-level `"@unfold": true` (added in #2321) works correctly for `Optional`, `Set`, and `Cardinality` properties, but is silently ignored for `List` properties: the field is returned as plain id references, with no error or warning. Class-level `@unfoldable` on the target class does not have this problem, it correctly unfolds through `List` properties, including recursive self-referential ones.

Docs describe `List` as supported, with the same example syntax as the other container types:
- https://terminusdb.org/docs/document-unfolding-reference/: table listing "List: `{ "@type": "List", "@class": "Customer", "@unfold": true }`" under "works with all property type families"
- https://terminusdb.org/docs/schema-reference-guide/: "Add `"@unfold": true` to any complex property definition (Optional, Set, Array, List, or Cardinality)"

**To Reproduce**
Steps to reproduce the behavior:

```
docker exec tdb terminusdb db create admin/unfold_test --schema=true
docker exec tdb terminusdb doc insert admin/unfold_test --graph-type=schema --data='[
  {"@type":"Class","@id":"Item","@key":{"@type":"Lexical","@fields":["name"]},"name":"xsd:string"},
  {"@type":"Class","@id":"SetHolder","@key":{"@type":"Lexical","@fields":["name"]},
   "name":"xsd:string","items":{"@type":"Set","@class":"Item","@unfold":true}},
  {"@type":"Class","@id":"ListHolder","@key":{"@type":"Lexical","@fields":["name"]},
   "name":"xsd:string","items":{"@type":"List","@class":"Item","@unfold":true}}
]' -m "schema"

docker exec tdb terminusdb doc insert admin/unfold_test --data='[
  {"@type":"Item","name":"i1"},
  {"@type":"Item","name":"i2"},
  {"@type":"SetHolder","name":"sh1","items":["Item/i1","Item/i2"]},
  {"@type":"ListHolder","name":"lh1","items":["Item/i1","Item/i2"]}
]' -m "data"

docker exec tdb terminusdb doc get admin/unfold_test --id=SetHolder/sh1
# => items unfolds inline: "items":[{"@id":"Item/i1","@type":"Item","name":"i1"}, ...]

docker exec tdb terminusdb doc get admin/unfold_test --id=ListHolder/lh1
# => items stays as bare refs: "items":["Item/i1","Item/i2"]   <-- @unfold:true had no effect
```

**Current behavior**
`ListHolder.items` (a `List` with `@unfold: true`) is returned as bare id references. Confirmed this is independent of the request-level `unfold` query/CLI flag: passing `unfold=true` or `unfold=false` explicitly made no observable difference in either direction for either class, only the schema-level annotations (`@unfold`, `@unfoldable`) determine the outcome.

**Expected behavior**
`ListHolder.items` unfolds inline, the same as `SetHolder.items` does, matching the docs linked above.

**What still works**
Marking the target class `@unfoldable: []` (class-level) instead of the property `@unfold: true` correctly unfolds `List` properties, including through a self-referential recursive `List<Self>` (verified 3 levels deep, cycle-protected). So the container-type gap is specific to the property-level `@unfold` mechanism, not to unfolding-through-`List` in general.

**Info (please complete the following information):**
 - OS: Ubuntu 26.04 LTS
 - How did you run terminus-server: Using Docker directly
   - `terminusdb/terminusdb-server:v12` (Docker image)
   - `TerminusDB v12.0.7 (57f2093baeafd65e16004e84b7b58e0c5cf72858)`
   - `terminusdb-store v0.19.8`

**Additional context**
Traced the likely root cause into the #2321 diff. `json.pl`'s unfold decision predicate (added by #2321):

```prolog
should_unfold_property(DB, _ParentId, _P, TargetClass) :-
    is_subdocument(DB, TargetClass), !.
should_unfold_property(DB, _ParentId, _P, TargetClass) :-
    is_unfoldable(DB, TargetClass), !.
should_unfold_property(DB, ParentId, P, _TargetClass) :-
    instance_of(DB, ParentId, ParentClass),
    property_is_unfold(DB, ParentClass, P, true), !.
```

The third clause (property-level `@unfold`) needs `ParentId` plus the property name `P` to look up `property_is_unfold/4`. The first two clauses need only `TargetClass`, resolvable from anywhere.

- `List`-typed values are represented internally as an RDF Collection: a chain of `Cons` cells linked by `rdf:first`/`rdf:rest`, not a direct edge from the parent to the target instance.
- Confirmed via raw triple inspection: a `Set` property's target is one hop from the parent; a `List` property's target is behind two additional hops, through an intermediate `Cons` node.
- Per the #2321 diff, `List` materialization goes through a separate, pre-existing routine, `list_type_id_predicate_value/8`, which does not call `should_unfold_property/3` at all. So the property-level `@unfold` signal (clause 3 above, tied to `ParentId`/`P`) never reaches the code that walks the `Cons` chain.
- Class-level `@unfoldable` (clause 2 above) keeps working regardless, because it only needs the target class, which is still resolvable at each `Cons` hop through whatever does check it there.

The PR's own test for `List` only asserts the schema round-trips the annotation, never that it actually unfolds at read time:

```javascript
it('should accept @unfold on List property', async function () {
  ...
  const r2 = await document.get(agent, { query: { graph_type: 'schema', id: 'Sequence' } })
  expect(r2.body.elements['@unfold']).to.equal(true)
})
```

That's why it passes CI regardless of whether unfolding actually happens at read time.

Two open questions for maintainers:
- Is `List` support for property-level `@unfold` intended (matching the docs), making this a bug in the `list_type_id_predicate_value/8` path? Or was `List` never actually meant to be supported at the property level, only via class-level `@unfoldable`, making this a docs bug in `document-unfolding-reference` and `schema-reference-guide` instead?
- If the former, would a PR adding an actual data-retrieval test for the `List` case (not just the schema round-trip currently in `field-level-unfold.js`) be welcome, to close the CI gap that let this ship?

Related: #2321
