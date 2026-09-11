# Archive Migration — Planning <a name='id/BlockNode:00CE01Y1Z8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CE01Y1Z8002' class='aperas-anchor aperas-id'></a>

Per sub-task: author the split concern-doc-set on disk under a new concern name, `aperas ingest --track --flush`, verify round-trip fidelity (`aperas project --dry-run`, diff modulo anchors), project for real, re-ingest to confirm a clean pass, then upgrade any legacy prose cross-references into real wikilinks and verify with `aperas backlinks`. Fold anything learned back into the `aperas`/`kg-doc-ingest` skills before starting the next sub-task.

## Task Breakdown <a name='id/BlockNode:00CE01Y1Z8003' class='aperas-anchor aperas-id'></a>

- Archive migration meta-task doc set (this doc set) — created and tracked. Done.
- `Aperas-treeview-design.md` → done: <a name='id/BlockNode:00CE07TC0G004' class='aperas-anchor aperas-id'></a> split into [design](../design/treeview.md#id/BlockNode:00CE1GW4Y8001)/[issues](../issues/treeview.md#id/BlockNode:00CE1GW638001)/[planning](../planning/treeview.md#id/BlockNode:00CE1GW7CG001)/[history](../history/treeview.md#id/BlockNode:00CE1GW8T8001)/[discussion](../discussion/treeview.md#id/BlockNode:00CE1DDF4G001) as `treeview`. Round-trip verified, cross-references upgraded, backlinks confirmed.
- `Aperas-crud-design.md` → concern name TBD (likely `crud`)
- `Aperas-apeironngn-design.md` → settled: <a name='id/BlockNode:00CE07TC0G006' class='aperas-anchor aperas-id'></a> decompose into multiple concern-doc-sets. Which ones and how many is still open (see [Issues](../issues/archive-migration.md#id/BlockNode:00CE01Y0T0002)).
- `Aperas-dev-status.md` → TDB-era in origin despite sitting at the `archive/` top level (pulled out of `tdb-era/` only because its coverage spans many future dev phases too broad for that folder); treated the same as `tdb-era/*` below: brainstorm a structure, then write new docs from scratch, not decomposition (see [Settled](../discussion/archive-migration.md#id/BlockNode:00CE0HD0HG002)).
- `Aperas-design.md` (the original pre-ApeironNgn roadmap) → needs its own brainstorm for a proper structure — doesn't map onto a normal subsystem shape like the others (see [Open Questions](../discussion/archive-migration.md#id/BlockNode:00CE0HD0H8001)).
- `reports/bugs/` → inventory, then map into whichever subsystem's `issues/` concern each report actually belongs to
- `tdb-era/*` (16 files, oldest) → not a mechanical decomposition: <a name='id/BlockNode:00CE07YNJ800A' class='aperas-anchor aperas-id'></a> for whatever knowledge in them is still live in the current system, write *new* concern docs reflecting today's understanding, following Document Topology from the start with concern names chosen up front to avoid collision. Superseded content goes to that concern's `history` doc only (see [Settled](../discussion/archive-migration.md#id/BlockNode:00CE0HD0HG002)).

## Verification Plan <a name='id/BlockNode:00CE01Y1Z800D' class='aperas-anchor aperas-id'></a>

A sub-task is done when: the round-trip diff is clean, `aperas backlinks` confirms every upgraded cross-reference actually resolves, `aperas tree` shows the new concern docs in place, and the corresponding legacy file (or the piece of it that's now covered) is either retired from `archive/` top level or left with a note that it's superseded.
