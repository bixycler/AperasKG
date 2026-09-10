# Packaging — Issues <a name='id/BlockNode:00CDDVC8N0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CDDVC8N0002' class='aperas-anchor aperas-id'></a>

- **`kg:*` only runs from inside this source checkout.** Every command requires `npm run kg:X --` from `Aperas/web`, with `tsx` and the rest of the devDependencies installed — not something an end user installing a skill that shells out to `aperas` can rely on. See [Motivation](../discussion/packaging.md#id/BlockNode:00CDDVC33G006).
- **The graph's location is hardcoded.** `getArtifactsDir()` resolves `AperasKG/artifacts` as a fixed sibling of `web/` — true only for this repo's own layout, not for an installed CLI running against an arbitrary user's own graph. See [discussion](../discussion/packaging.md#id/BlockNode:00CDDVC33G00A).

## Pending Tasks <a name='id/BlockNode:00CDDVC8N0006' class='aperas-anchor aperas-id'></a>

None.

## Resolved <a name='id/BlockNode:00CDDVC8N0007' class='aperas-anchor aperas-id'></a>

None.
