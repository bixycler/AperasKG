---
description: No open issues — the list-consumption law is fully implemented and the corpus migration is complete.
---

# List Consumption — Issues <a name='id/BlockNode:00CE32GRZ8001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CE32GRZG000' class='aperas-anchor aperas-id'></a>

None.

## Pending Tasks <a name='id/BlockNode:00CE32GRZG006' class='aperas-anchor aperas-id'></a>

None — Task Breakdown is complete, see [History](../history/list-consumption.md#id/BlockNode:00CE32GW3G002).

## Resolved <a name='id/BlockNode:00CE32GRZG007' class='aperas-anchor aperas-id'></a>

- **Consumption and self-dissolution (§2/§8's existing behavior)**: <a name='id/BlockNode:00CE32GRZG009' class='aperas-anchor aperas-id'></a> already correctly implemented — the unified law's first two cases were never broken, only previously unstated as one rule. See [History](../history/list-consumption.md#id/BlockNode:00CE32GW3G002).
- **Orphaned lists dissolve, `orderedList`/`startIndex` normalized onto the run's own first item**: <a name='id/BlockNode:00CE5B6A58001' class='aperas-anchor aperas-id'></a> `astParser.ts`'s orphan branch now splices items flat into the true parent instead of wrapping a `list`-typed node, and all three adoption branches set props uniformly via one `setProp(items[0], ...)` call. `project.ts`'s `renderChildren` reads props from each run's own first item and ends a run at a type change or the next item's own explicit `orderedList` — verified against two synthetic cases (a separator between two runs, and two runs directly adjacent with none) plus the full real corpus (48 legacy anchors relocated, 59 live `list` nodes fixpoint-spliced and tombstoned; see [History](../history/list-consumption.md#id/BlockNode:00CE32GW3G002)).
- **`aperas insert <list-id>` piping a bare `- item` line created a nested list-in-list**: <a name='id/BlockNode:00CE5D1A10004' class='aperas-anchor aperas-id'></a> confirmed moot post-migration — live-tested against the migrated corpus (inserting a bare bullet after an existing listItem) creates a plain sibling `listItem`, no wrapper. There is no longer a live `list`-typed node anywhere in the corpus to mistakenly target this way.
- **`aperas insert <list-id>` piping plain text with no leading `- ` marker created a wrongly-typed `paragraph`**: <a name='id/BlockNode:00CE5D1A10005' class='aperas-anchor aperas-id'></a> this half was never actually about list-node existence — piping text with no bullet marker still parses as a `paragraph`, migration or not (live-tested). Not a list-consumption bug: it's the parser correctly doing what the input told it to do. A caution for the `aperas` skill's own insert guidance, not something this design can fix.
- **`verify.ts` hard-asserted the old anchor-owns-it convention**: <a name='id/BlockNode:00CE5D1A10006' class='aperas-anchor aperas-id'></a> rewritten — "Testing consumption", "Testing dissolution when orphaned, zero-separator variant", and "Testing dissolution when orphaned, separated variant" replace the old "heading consume + list adoption"/"adjacent lists" checks, asserting props on each run's own first item and dissolution into flat children.
- **Orphan-dissolution's adjacent-runs case**: <a name='id/BlockNode:00CE5D1A10007' class='aperas-anchor aperas-id'></a> the run-boundary-by-own-explicit-props rule (see Design) is implemented in `project.ts` and covered by `verify.ts`'s zero-separator test.

- **Inserting a list item always spawns a fresh run-leader**: <a name='id/BlockNode:00CE32GRZG002' class='aperas-anchor aperas-id'></a> `aperas insert` piping a single new bullet always parsed that content as its own orphaned one-item list, so the new item got its own explicit `orderedList`/`startIndex` from the normalization rule (see Design) — marking it a run-leader relative to whatever precedes it, even when the preceding item was an ordinary continuation of the very same list with the identical value. The render-time boundary rule (a next item's own explicit prop starts a new run) then treated it as a *second* run, rendering a spurious blank line before it. Not data corruption (bullet type and numbering both stayed correct), but a real regression versus the old anchor-owns-it model, where a freshly inserted item carried no prop of its own and silently joined whatever run it landed in. **Resolved**: `kgInsert.ts` now clears a freshly-parsed lone `listItem`'s own `orderedList`/`startIndex` when the sibling it lands next to is a plain (no-props-of-its-own) `listItem` — see [Freeflow](../discussion/list-consumption.md#id/BlockNode:00CE5EHVXR008) for the full mechanism and its deliberate scope limit.
