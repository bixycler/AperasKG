---
description: Why `cli` ended up thin: everything that looked CLI-specific except the `kg:insert` ordering gap and `packaging` turned out to be `core` engine content instead.
---

# CLI — Discussion <a name='id/BlockNode:00CF2AEMER001' class='aperas-anchor aperas-id'></a>

## Dashboard <a name='id/BlockNode:00CF2AEMER002' class='aperas-anchor aperas-id'></a>

- **Issues**: <a name='id/BlockNode:00CF2AEMER003' class='aperas-anchor aperas-id'></a> [Open Issues](../issues/cli.md#id/BlockNode:00CF2AEAX0002) — what's genuinely CLI-dispatcher-specific, not engine-level.
- **Planning**: <a name='id/BlockNode:00CF2AEMER004' class='aperas-anchor aperas-id'></a> [Task Breakdown](../planning/cli.md#id/BlockNode:00CF2AEXN8003) — the fix plan for the single-`kg:insert` transactionality gap, now resolved.
- Design and History are not written yet — this concern is thin enough that they may never need to be much more than a stub.

## Settled <a name='id/BlockNode:00CF2AEMER006' class='aperas-anchor aperas-id'></a>

- **Scope**: <a name='id/BlockNode:00CF2AEMER007' class='aperas-anchor aperas-id'></a> `cli` is the thin dispatcher/verb layer over the shared `core` engine — see [discussion/core.md](../discussion/core.md#id/BlockNode:00CF1WZE18001) for the engine itself and its sub-parts (`treeview`, `linking`, `list-consumption`, and `crud` once migrated). `cli`'s own sub-part is `packaging` (build/distribution/dispatcher). The third thin wrapper over that same `core` is [`webapp`](../discussion/webapp.md#id/BlockNode:00CJ2TCV40001), opened 2026-09-17.
- **Split history**: <a name='id/BlockNode:00CF2AEMF0000' class='aperas-anchor aperas-id'></a> this concern was originally created broader — covering the whole reconcile/tombstone bug family plus `treeview`/`linking`/`list-consumption`/`crud` as sub-parts — then split once it became clear that content was actually `core` engine code (`reconcile.ts`, `node.ts`, `astParser.ts`, `apeironNgn/artifacts.ts`), not CLI-dispatcher code. See [discussion/core.md's Freeflow](../discussion/core.md#id/BlockNode:00CF282PR0001) for the incident and the split plan. Only genuinely dispatcher-layer content (the single-`kg:insert` transactionality gap, and `packaging`) stayed here.

## Freeflow <a name='id/BlockNode:00CR81TAV8001' class='aperas-anchor aperas-id'></a>

- **The insert-transactionality fix covers a missing anchor but not a misplaced one**: <a name='id/BlockNode:00CR81W4RG001' class='aperas-anchor aperas-id'></a> [A single `kg:insert` call isn't transactional](../issues/cli.md#id/BlockNode:00CF2AEAX0003) is marked Resolved, having moved anchor *resolution* ahead of hydration, verified only with a nonexistent anchor id. An anchor that resolves but isn't a child of the given parent is still rejected late, in `insertOrderedChild`, after the piped nodes are hydrated. Found 2026-09-27.
  
  - **Repro**: <a name='id/BlockNode:00CR81W4RG002' class='aperas-anchor aperas-id'></a> `cat item.md | aperas insert BlockNode:00CGJHDK68001 --after BlockNode:00CGJHDK68001` (the item passed as its own parent) failed with "insertOrderedChild: anchor … is not a child of …" and left the live parentless orphan `BlockNode:00CR6BD1X0001` (since tombstoned).
  - **Skill drift**: <a name='id/BlockNode:00CR81W4RG003' class='aperas-anchor aperas-id'></a> the base skill's *`--after`/`--before` anchors* still says "Be aware this failure is not clean". That is stale against the Resolved issue for a missing anchor, and still true for a misplaced one.
- **`aperas check-links` still prints the old `[ApeironNgn check-links]` prefix**: <a name='id/BlockNode:00CR8RVCF8001' class='aperas-anchor aperas-id'></a> the [v2.11 delta](../discussion/aperas-skill.md#id/BlockNode:00CQYGPR50001) records runtime prefixes rewritten from `[ApeironNgn kg:X]` to `[aperas X]`, but `packages/cli/src/kgCheckLinks.ts` prints `[ApeironNgn check-links]` at all five sites (lines 44, 58, 61, 65, 79). The prefix had no `kg:` in it, which likely let it escape the rename. Found by the grapher, reproduced by the orchestrator, 2026-09-27. Filed as [an Open Issue in issues/cli.md](../issues/cli.md#id/BlockNode:00CR8XN9VG002).
  
  - **Possibly related**: <a name='id/BlockNode:00CR8RVCF8002' class='aperas-anchor aperas-id'></a> `packages/cli/src/apeironNgn/service.ts` logs `[ApeironNgn service]`. That may be intentional, since it names the service component rather than a CLI verb.
