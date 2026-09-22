---
description: Fully implemented and migrated: all three cases of the unified list law are live, and the real corpus has zero bare `list` nodes left.
---

# List Consumption — History <a name='id/BlockNode:00CE32GW3G001' class='aperas-anchor aperas-id'></a>

## Current Status <a name='id/BlockNode:00CE32GW3G002' class='aperas-anchor aperas-id'></a>

Fully implemented and migrated. All three cases of the unified law (consumption, dissolution via merged self, dissolution when orphaned) are live in `astParser.ts`/`project.ts`, `orderedList`/`startIndex` are normalized onto each run's own first item everywhere, and the real corpus (48 legacy anchors relocated, 59 live `list` nodes fixpoint-spliced and tombstoned) has been migrated — zero `list`-typed BlockNodes remain live. See [Issues](../issues/list-consumption.md) (now all resolved) and [Planning](../planning/list-consumption.md) (Task Breakdown, all done).

## Milestones <a name='id/BlockNode:00CE32GW3G003' class='aperas-anchor aperas-id'></a>

- Verified live, via direct reads of `astParser.ts`/`project.ts`: <a name='id/BlockNode:00CE32GW3G005' class='aperas-anchor aperas-id'></a> consumption (a list adopts into whichever real node immediately precedes it) and self-dissolution (a list adopts into its own container once that container's leading paragraph has been consumed into its `.text`) were already correctly implemented — including the specific safeguard against two adjacent lists corrupting each other's props (`adoptionAnchor` resets after every list, adopted or orphaned). No code change needed for either case; this design's contribution is stating them as one law and identifying the one case they don't yet cover.

- Implemented and migrated: <a name='id/BlockNode:00CE5BVP6R001' class='aperas-anchor aperas-id'></a> `astParser.ts`'s `convertChildren` normalizes `orderedList`/`startIndex` onto the run's own first converted item uniformly across all three cases, and the orphan branch splices items flat instead of wrapping a `list`-typed node; `project.ts`'s `renderChildren` reads props from each run's own first item and ends a run at a type change or the next item's own explicit `orderedList` prop. A one-off migration script relocated props off the 48 legacy anchors and fixpoint-spliced all 59 live `list` nodes into their parents (tombstoned, kept per the never-splice-out-of-children convention); verified via a full before/after projection diff across all 28 tracked artifacts, byte-identical except one pre-existing, unrelated quirk in `issues/packaging.md` (see [Resolved](../issues/list-consumption.md#id/BlockNode:00CE32GRZG007)). `npm run verify` passes clean against the migrated corpus, including three new synthetic tests (consumption, zero-separator dissolution, separated-runs dissolution).
