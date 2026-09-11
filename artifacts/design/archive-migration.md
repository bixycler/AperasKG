# Archive Migration — Design <a name='id/BlockNode:00CE01XZPG001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CE01XZPG002' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CE01XZPG004' class='aperas-anchor aperas-id'></a> [Inventory and open questions](../discussion/archive-migration.md#id/BlockNode:00CE0YFEN0003) — what's in `artifacts/archive/`, and decisions still open about how to split it.
- **Issues**: <a name='id/BlockNode:00CE01XZPG005' class='aperas-anchor aperas-id'></a> [Open Issues](../issues/archive-migration.md#id/BlockNode:00CE01Y0T0002) — hazards and pending decomposition calls.
- **Planning**: <a name='id/BlockNode:00CE01XZPG006' class='aperas-anchor aperas-id'></a> [Task Breakdown](../planning/archive-migration.md#id/BlockNode:00CE01Y1Z8003) — the ordered sub-task list.
- **History**: <a name='id/BlockNode:00CE01XZPG007' class='aperas-anchor aperas-id'></a> [Current Status](../history/archive-migration.md#id/BlockNode:00CE01Y320002) — progress so far.

## Architecture <a name='id/BlockNode:00CE01XZPG008' class='aperas-anchor aperas-id'></a>

`artifacts/archive/` holds hand-written docs that predate the [Document Topology](../design/documentation.md#id/BlockNode:00CDD68E8000E)'s concern-based separation — each one mixes design, issues, planning, and history for its subject into a single file. Migrating one means splitting it into its own concern-doc-set (`design/`, `issues/`, `planning/`, `history/`, `discussion/`) under a new concern name, using the disk-first path the `kg-doc-ingest` skill defines for a genuinely new, not-yet-tracked doc set: author the split `.md` files directly, then `aperas ingest --track --flush`, verify round-trip fidelity, project, and upgrade any legacy prose cross-references into real wikilinks.

Each legacy doc (or tight cluster of docs covering one subsystem) becomes its own sub-task, run to completion — including folding whatever's learned back into the `aperas`/`kg-doc-ingest` skills — before the next one starts. Sub-tasks proceed newest era to oldest: the ApeironNgn-era top-level docs first, then `reports/bugs/`, then `tdb-era/` last, since the newer docs describe the substrate this migration itself runs on and are the most load-bearing to have in the graph early.

## Topology <a name='id/BlockNode:00CE01XZPR000' class='aperas-anchor aperas-id'></a>

`archive/{design,discussion,issues,history,planning}/linking.md` are pre-migration snapshots of a doc set already fully migrated to the top-level `linking.md` concern docs — no sub-task needed for those; they stay archived as-is for history.

Everything else in `archive/` still needs a sub-task. Target concern names are decided per sub-task, not fixed here — see [Task Breakdown](../planning/archive-migration.md#id/BlockNode:00CE01Y1Z8003) for the current list and [Open Issues](../issues/archive-migration.md#id/BlockNode:00CE01Y0T0002) for the ones whose split isn't obvious yet.

For `tdb-era/` specifically (this includes `Aperas-dev-status.md`, which is TDB-era in origin despite sitting at the `archive/` top level — pulled out only because its coverage spans many future dev phases too broad for that folder): don't decompose the old docs 1:1. Instead, for whatever knowledge in them is still live in the current (ApeironNgn) system, author brand-new concern docs reflecting today's understanding — following Document Topology from the start, with concern names chosen up front to avoid any collision (no post-hoc rename needed, unlike the `cli.md` → `packaging.md` incident). Anything no longer live goes to that concern's `history` doc as retired background, not carried into `design`. See [Settled](../discussion/archive-migration.md#id/BlockNode:00CE0HD0HG002).

`Aperas-apeironngn-design.md` is settled: <a name='id/BlockNode:00CE0HPRV8002' class='aperas-anchor aperas-id'></a> decompose into multiple concern-doc-sets — it's too broad for one. `Aperas-design.md` (the pre-ApeironNgn roadmap) is different: it doesn't map cleanly onto a single subsystem's design/issues/planning/history/discussion shape, unlike every other doc migrated so far. Its structure isn't decided yet — see [Open Questions](../discussion/archive-migration.md#id/BlockNode:00CE0HD0H8001).
