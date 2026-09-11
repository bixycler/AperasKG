# TreeView — Planning <a name='id/BlockNode:00CE1GW7CG001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CE1GW7CG002' class='aperas-anchor aperas-id'></a>

Fix the treeview-specific gaps and the two relocated ingest/parser gaps together, since they were bundled by direct instruction rather than filed separately. No particular cross-dependency between them — order by whichever's simplest to verify in isolation.

## Task Breakdown <a name='id/BlockNode:00CE1GW7CG003' class='aperas-anchor aperas-id'></a>

- `TreeView.unfolds` staleness: <a name='id/BlockNode:00CE1GW7CG005' class='aperas-anchor aperas-id'></a> build the audit/prune sweep (walk every `TreeView`'s `unfolds` list, on some cadence or on demand, stripping any entry that no longer resolves to a live node) — the fix that actually closes the gap. Add write-time validation in `TreeView.unfold(ref)` alongside it as a cheap complementary check, not a substitute. One-time manual cleanup needed regardless for the 10 already-stale ids in the live `.state/TreeView.jsonld`.
- Bare `aperas unfold <ref>` (no `--view` at all): <a name='id/BlockNode:00CE1GW7CG006' class='aperas-anchor aperas-id'></a> make it peek — resolve and print the preview, calling neither `view.unfold(id)` nor the default-view bootstrap. Reserve the bootstrap-and-mutate behavior for `--view` supplied with no name following it.
- `aperas show <ref>`: <a name='id/BlockNode:00CE1GW7CG007' class='aperas-anchor aperas-id'></a> resolve `<ref>` the normal way, then print its raw stored fields untransformed — full `text`, `props`, `tombstonedAt`, and `path`/`title`/`type` as actually recorded, no truncation, no anchor stripping, no rendering.
- Fix the GFM task-list round-trip bug (parser/serializer, likely `astParser.ts`'s task-list handling).
- Fix `List` not being consumed by a preceding `Heading` the way a single paragraph already is.

## Verification Plan <a name='id/BlockNode:00CE1GW7CG00A' class='aperas-anchor aperas-id'></a>

Each fix verified the same way prior `apeironNgn` fixes in this corpus have been: a direct `BlockNode.jsonld`/`ArtifactNode.jsonld` read confirming the exact stored state, not just a command's own summary line, plus (where applicable) a round-trip check via `aperas project --dry-run` against real content exercising the fixed case.
