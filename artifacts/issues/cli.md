---
description: No open issues in the CLI dispatcher layer itself — see Resolved for the single `kg:insert` ordering bug that used to live here.
---

# CLI — Issues <a name='id/BlockNode:00CF2AEAX0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CF2AEAX0002' class='aperas-anchor aperas-id'></a>

None currently — see Resolved below.

## Sub-Parts <a name='id/BlockNode:00CF2AEAX0004' class='aperas-anchor aperas-id'></a>

CLI's own known parts, and where each one's issues currently live:

- **`packaging`** — none open. See [Open Issues](../issues/packaging.md#id/BlockNode:00CDDVC8N0002).

## Pending Tasks <a name='id/BlockNode:00CF2AEAX0006' class='aperas-anchor aperas-id'></a>

None — Task Breakdown is complete.

## Resolved <a name='id/BlockNode:00CF2AEAX0007' class='aperas-anchor aperas-id'></a>

- **A single `kg:insert` call isn't transactional**: <a name='id/BlockNode:00CF2AEAX0003' class='aperas-anchor aperas-id'></a> fixed by resolving/validating the `--after`/`--before` anchor right after `rejectSlugPathCollisions`, before any of the piped markdown's top-level nodes are hydrated via `hydrateFromParsed` — a bad anchor is now rejected before anything is written, instead of after. Verified by forcing an anchor-resolution failure mid-`kg:insert` (a nonexistent anchor id) and confirming, via a raw `BlockNode.jsonld` read after an explicit flush, that no orphan node appears — the on-disk store's hash was unchanged from immediately before the attempt. A follow-up insert with a valid anchor still succeeds, confirming the happy path is unaffected.
