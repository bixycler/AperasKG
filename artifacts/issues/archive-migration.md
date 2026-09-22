---
description: Two open snags in the archive split: `Aperas-design.md` doesn't map onto a normal concern-doc shape, and a full-corpus rename sweep once collided inside `archive/`.
---

# Archive Migration — Issues <a name='id/BlockNode:00CE01Y0T0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CE01Y0T0002' class='aperas-anchor aperas-id'></a>

- **`Aperas-design.md` needs a dedicated brainstorm, not a mechanical split**: <a name='id/BlockNode:00CE01Y0T0004' class='aperas-anchor aperas-id'></a> unlike every other doc in this migration, it doesn't map cleanly onto one subsystem's design/issues/planning/history/discussion shape — see [Open Questions](../discussion/archive-migration.md#id/BlockNode:00CE0HD0H8001). (`Aperas-dev-status.md` is no longer grouped here — it's TDB-era in origin and follows that era's settled approach; see [design](../design/archive-migration.md#id/BlockNode:00CE0HPRV8001).)
- **A full-corpus rename sweep once collided on `archive/Aperas-dev-status.md`**: <a name='id/BlockNode:00CE01Y0T0005' class='aperas-anchor aperas-id'></a> noted in [Packaging — Discussion](../discussion/packaging.md#id/BlockNode:00CDEB141G001) — a path-less `aperas track`/`ingest` sweep aborted on a slug-path collision inside that file. Scoped, path-given ingestion (as this whole migration uses) isn't affected, but nothing should ever invoke a path-less sweep while `archive/` still holds untracked legacy content.

## Pending Tasks <a name='id/BlockNode:00CE01Y0T0006' class='aperas-anchor aperas-id'></a>

See [Task Breakdown](../planning/archive-migration.md#id/BlockNode:00CE01Y1Z8003) for the full ordered list.

## Resolved <a name='id/BlockNode:00CE01Y0T0007' class='aperas-anchor aperas-id'></a>

None yet.
