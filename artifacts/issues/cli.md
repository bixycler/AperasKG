---
description: One open — `aperas check-links`'s runtime prefix, missed by the CLI's own `kg:*`-to-`aperas` rename; see Resolved for the single `kg:insert` ordering bug that used to live here.
---

# CLI — Issues <a name='id/BlockNode:00CF2AEAX0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CF2AEAX0002' class='aperas-anchor aperas-id'></a>

One open — `aperas check-links`'s runtime prefix, missed by the CLI's own `kg:*`-to-`aperas` rename.

- **`aperas check-links` still prints the old `[ApeironNgn check-links]` prefix**: <a name='id/BlockNode:00CR8XN9VG002' class='aperas-anchor aperas-id'></a> `packages/cli/src/kgCheckLinks.ts` prints `[ApeironNgn check-links]` at all five sites (lines 44, 58, 61, 65, 79) — every other `kgX.ts` file's runtime `console.log`/`console.error` prefix was already rewritten from `[ApeironNgn kg:X]` to `[aperas X]`, matching [the `aperas` dispatcher covering every verb identically](../design/packaging.md#id/BlockNode:00CDGTZHSR005). This file's prefix had no `kg:` in it, which likely let it escape a pattern-based rename. Fix: reword the five sites to `[aperas check-links]`, matching the convention every other command's runtime prefix already follows. Found by the grapher, reproduced by the orchestrator, 2026-09-27.

## Sub-Parts <a name='id/BlockNode:00CF2AEAX0004' class='aperas-anchor aperas-id'></a>

CLI's own known parts, and where each one's issues currently live:

- **`packaging`** — none open. See [Open Issues](../issues/packaging.md#id/BlockNode:00CDDVC8N0002).

## Pending Tasks <a name='id/BlockNode:00CF2AEAX0006' class='aperas-anchor aperas-id'></a>

None — Task Breakdown is complete.

## Resolved <a name='id/BlockNode:00CF2AEAX0007' class='aperas-anchor aperas-id'></a>

- **A single `kg:insert` call isn't transactional**: <a name='id/BlockNode:00CF2AEAX0003' class='aperas-anchor aperas-id'></a> fixed by resolving/validating the `--after`/`--before` anchor right after `rejectSlugPathCollisions`, before any of the piped markdown's top-level nodes are hydrated via `hydrateFromParsed` — a bad anchor is now rejected before anything is written, instead of after. Verified by forcing an anchor-resolution failure mid-`kg:insert` (a nonexistent anchor id) and confirming, via a raw `BlockNode.jsonld` read after an explicit flush, that no orphan node appears — the on-disk store's hash was unchanged from immediately before the attempt. A follow-up insert with a valid anchor still succeeds, confirming the happy path is unaffected.
