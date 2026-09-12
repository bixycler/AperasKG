# CLI — Issues <a name='id/BlockNode:00CF2AEAX0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CF2AEAX0002' class='aperas-anchor aperas-id'></a>

- **A single `kg:insert` call isn't transactional**: <a name='id/BlockNode:00CF2AEAX0003' class='aperas-anchor aperas-id'></a> `kgInsert.ts`'s create mode resolves the parent, parses piped markdown into fresh nodes, checks name collisions, writes every new node into the store via `hydrateFromParsed`, resolves links, and only *then* resolves the `--after`/`--before` anchor — so an anchor-resolution failure leaves the newly-hydrated nodes live in memory, attached to nothing, with no rollback. `rejectSlugPathCollisions` is deliberately ordered ahead of hydration; this is a missing second guard (resolve/validate the anchor beside that same check, before any hydration), not a structural problem. `aperas reload -- --discard` is the only current recovery. The fix is entirely within `kgInsert.ts`'s own call ordering — no `core` change needed, which is why this stays in `cli` rather than moving with its siblings.

## Sub-Parts <a name='id/BlockNode:00CF2AEAX0004' class='aperas-anchor aperas-id'></a>

CLI's own known parts, and where each one's issues currently live:

- **`packaging`** — none open. See [Open Issues](../issues/packaging.md#id/BlockNode:00CDDVC8N0002).

## Pending Tasks <a name='id/BlockNode:00CF2AEAX0006' class='aperas-anchor aperas-id'></a>

See [Task Breakdown](../planning/cli.md#id/BlockNode:00CF2AEXN8003) for the fix plan.

## Resolved <a name='id/BlockNode:00CF2AEAX0007' class='aperas-anchor aperas-id'></a>

None yet.
