# CLI — Planning <a name='id/BlockNode:00CF2AEXN8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CF2AEXN8002' class='aperas-anchor aperas-id'></a>

Fix the single open issue directly in `kgInsert.ts` — no `core` changes needed, unlike its former siblings that moved to `core`.

## Task Breakdown <a name='id/BlockNode:00CF2AEXN8003' class='aperas-anchor aperas-id'></a>

- [x] Read `kgInsert.ts`'s create-mode flow to confirm the exact current call order (parse → collision-check → hydrate → resolve links → resolve anchor).
- [x] Reorder: <a name='id/BlockNode:00CF2AEXN8005' class='aperas-anchor aperas-id'></a> resolve/validate the `--after`/`--before` anchor before calling `hydrateFromParsed`, alongside the existing `rejectSlugPathCollisions` check, so a bad anchor is rejected before anything is written.
- [x] Verify: <a name='id/BlockNode:00CF2AEXN8006' class='aperas-anchor aperas-id'></a> force an anchor-resolution failure mid-`kg:insert` and confirm no orphan node survives — check a raw `BlockNode.jsonld` read, not just the CLI's own reported failure.
- [x] Move the Open Issues entry to Resolved once confirmed, with the actual mechanism named.

## Verification Plan <a name='id/BlockNode:00CF2AEXN8008' class='aperas-anchor aperas-id'></a>

Reject an anchor mid-`kg:insert` deliberately and confirm zero orphan nodes appear in a raw store read afterward, not just that the command reports failure — matching how `issues/core.md`'s own batch-`kg:ingest` fix (item 6) is checked.
