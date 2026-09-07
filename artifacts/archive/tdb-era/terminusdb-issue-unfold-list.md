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

**Info:**
 - OS: Ubuntu 26.04 LTS
 - How did you run terminus-server: Using Docker directly
   - `terminusdb/terminusdb-server:v12` (Docker image)
   - `TerminusDB v12.0.7 (57f2093baeafd65e16004e84b7b58e0c5cf72858)`
   - `terminusdb-store v0.19.8`

**Additional context**
Traced the actual root cause into `src/rust/terminusdb-community/src/doc/mod.rs`. For TerminusDB v12, a single-document `doc get` doesn't go through `json.pl`'s `get_document`/`get_document_` at all — it goes through the Rust foreign predicate `print_document_json`, which calls `DocumentContext::get_id_document`. That's where field-level `@unfold` is actually decided, via a `(parent_type_id, predicate_id)` pair (`unfold_pairs`) read off the *enclosing* stack frame:

```rust
let field_level_unfold = match (parent_type_id, predicate_id) {
    (Some(pt), Some(pr)) => self.unfold_pairs.contains(&(pt, pr)),
    _ => false,
};
```

`parent_type_id`/`predicate_id` come from `StackEntry::document_type_id()` / `current_predicate()`:

```rust
fn document_type_id(&self) -> Option<u64> {
    match self {
        Self::Document { type_id, .. } => *type_id,
        _ => None,
    }
}

fn current_predicate(&mut self) -> Option<u64> {
    match self {
        Self::Document { fields, .. } => fields.as_mut().and_then(|f| f.peek().map(|t| t.predicate)),
        _ => None,
    }
}
```

- `Set`/`Optional`/`Cardinality` values sit as direct triples on the document, so the enclosing frame is always `StackEntry::Document`, and both lookups succeed — this is why they work.
- `List` and `Array` values instead sit behind an intermediate `StackEntry::List` / `StackEntry::Array` frame (the RDF Cons chain for `List`, the array's index triples for `Array`), pushed onto the traversal stack while the document's field is walked. Neither variant carries the parent document's type/predicate forward, so `document_type_id()`/`current_predicate()` fall through the wildcard arm above and return `None` for anything nested inside a `List` or `Array` — silently disabling field-level `@unfold` for their elements regardless of what the schema says.
- Class-level `@unfoldable` keeps working regardless, because it's checked via `self.unfoldables.contains(&t.object)`, which only needs the target's own type, not the enclosing frame.

The PR's own test for `List` only asserts the schema round-trips the annotation, never that it actually unfolds at read time:

```javascript
it('should accept @unfold on List property', async function () {
  ...
  const r2 = await document.get(agent, { query: { graph_type: 'schema', id: 'Sequence' } })
  expect(r2.body.elements['@unfold']).to.equal(true)
})
```

That's why it passes CI regardless of whether unfolding actually happens at read time.

**Fix**
Capture the parent's `type_id`/`predicate_id` before pushing the `List`/`Array` frame and thread it through `StackEntry::List` and `ArrayStackEntry` so nested elements still match against `unfold_pairs`. Verified against a from-source build: the fix compiles, all existing Rust unit tests still pass, `cargo clippy` shows no new warnings, and new integration tests for `List` retrieval and a 2D `Array` case (added to `tests/test/field-level-unfold.js`, per the request in [the maintainer reply](https://github.com/terminusdb/terminusdb/issues/2512#issuecomment-5463157961)) pass against a live server built from the fix.

Related: #2321
