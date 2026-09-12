# CLI — Discussion <a name='id/BlockNode:00CF2AEMER001' class='aperas-anchor aperas-id'></a>

## Dashboard <a name='id/BlockNode:00CF2AEMER002' class='aperas-anchor aperas-id'></a>

- **Issues**: <a name='id/BlockNode:00CF2AEMER003' class='aperas-anchor aperas-id'></a> [Open Issues](../issues/cli.md#id/BlockNode:00CF2AEAX0002) — what's genuinely CLI-dispatcher-specific, not engine-level.
- **Planning**: <a name='id/BlockNode:00CF2AEMER004' class='aperas-anchor aperas-id'></a> [Task Breakdown](../planning/cli.md#id/BlockNode:00CF2AEXN8003) — the fix plan for the one open issue above.
- Design and History are not written yet — this concern is thin enough that they may never need to be much more than a stub.

## Settled <a name='id/BlockNode:00CF2AEMER006' class='aperas-anchor aperas-id'></a>

- **Scope**: <a name='id/BlockNode:00CF2AEMER007' class='aperas-anchor aperas-id'></a> `cli` is the thin dispatcher/verb layer over the shared `core` engine — see [discussion/core.md](../discussion/core.md#id/BlockNode:00CF1WZE18001) for the engine itself and its sub-parts (`treeview`, `linking`, `list-consumption`, and `crud` once migrated). `cli`'s own sub-part is `packaging` (build/distribution/dispatcher). A future `webapp` concern is expected to be the third thin wrapper over that same `core`.
- **Split history**: <a name='id/BlockNode:00CF2AEMF0000' class='aperas-anchor aperas-id'></a> this concern was originally created broader — covering the whole reconcile/tombstone bug family plus `treeview`/`linking`/`list-consumption`/`crud` as sub-parts — then split once it became clear that content was actually `core` engine code (`reconcile.ts`, `node.ts`, `astParser.ts`, `apeironNgn/artifacts.ts`), not CLI-dispatcher code. See [discussion/core.md's Freeflow](../discussion/core.md#id/BlockNode:00CF282PR0001) for the incident and the split plan. Only genuinely dispatcher-layer content (the single-`kg:insert` transactionality gap, and `packaging`) stayed here.
