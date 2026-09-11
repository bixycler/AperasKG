# Archive Migration — Discussion <a name='id/BlockNode:00CE01Y42R001' class='aperas-anchor aperas-id'></a>

## Dashboard <a name='id/BlockNode:00CE01Y42R002' class='aperas-anchor aperas-id'></a>

- [Design](../design/archive-migration.md#id/BlockNode:00CE01XZPG001) — architecture/topology once crystallized.
- [Issues](../issues/archive-migration.md#id/BlockNode:00CE01Y0T0001) — gaps this reasoning surfaces.
- [Planning](../planning/archive-migration.md#id/BlockNode:00CE01Y1Z8001) — task breakdown.
- [History](../history/archive-migration.md#id/BlockNode:00CE01Y320001) — status/milestones.

## Open Questions <a name='id/BlockNode:00CE0HD0H8001' class='aperas-anchor aperas-id'></a>

- **What's the proper structure for `Aperas-design.md` (the pre-ApeironNgn roadmap)?** It doesn't map cleanly onto one subsystem's design/issues/planning/history/discussion shape like every other doc migrated so far — needs a dedicated brainstorm before that sub-task starts. (`Aperas-dev-status.md` no longer belongs here — see [Settled](../discussion/archive-migration.md#id/BlockNode:00CE0HD0HG002): it's TDB-era in origin and follows that era's already-settled approach.)

## Settled <a name='id/BlockNode:00CE0HD0HG000' class='aperas-anchor aperas-id'></a>

- **TDB-era migration approach**: <a name='id/BlockNode:00CE0HD0HG002' class='aperas-anchor aperas-id'></a> don't decompose `tdb-era/` docs 1:1 (this includes `Aperas-dev-status.md`, which is TDB-era in origin despite sitting at the `archive/` top level — pulled out of `tdb-era/` only because its coverage spans many future dev phases too broad for that folder). For whatever knowledge in them is still live in the current (ApeironNgn) system, author brand-new concern docs reflecting today's understanding — following Document Topology from the start, with concern names chosen up front to avoid any collision (no post-hoc rename needed, unlike the `cli.md` → `packaging.md` incident). Anything no longer live goes to that concern's `history` doc as retired background, not carried into `design`.
- **`Aperas-apeironngn-design.md` decomposition**: <a name='id/BlockNode:00CE0HD0HG003' class='aperas-anchor aperas-id'></a> settled — split into multiple concern-doc-sets, not one. Which ones and how many is still open (see [Issues](../issues/archive-migration.md#id/BlockNode:00CE01Y0T0002)).

## Checkpoints <a name='id/BlockNode:00CE0HD0HG004' class='aperas-anchor aperas-id'></a>

- Meta-task doc set (`archive-migration`) created, round-trip verified, cross-references upgraded to real wikilinks.
- Two ingest/parser gaps found while drafting the Task Breakdown — a GFM task-list round-trip bug (checkbox items double on projection: piping `- [ ] text` stores the literal `[ ] ` marker inside the block's own `.text` alongside a separate `checked: false` prop, so `aperas project` re-emits `- [ ] ` on top of it) and `List` not being consumed by a preceding `Heading` the way a single trailing paragraph already is. Neither has a real home yet — holding both here until `Aperas-apeironngn-design.md` is actually decomposed and a concern for the ingest/parser/reconcile engine exists to receive them. (Wrongly logged in Packaging — Issues at first; reverted.)

## Freeflow <a name='id/BlockNode:00CE0YFEN0001' class='aperas-anchor aperas-id'></a>

- **Inventory of `artifacts/archive/`**: <a name='id/BlockNode:00CE0YFEN0003' class='aperas-anchor aperas-id'></a> Contents as found:
  
  - Top-level (ApeironNgn era, mixed-concern, newest): <a name='id/BlockNode:00CE0YFEN0004' class='aperas-anchor aperas-id'></a> `Aperas-treeview-design.md`, `Aperas-crud-design.md`, `Aperas-apeironngn-design.md`, `Aperas-design.md` (the pre-ApeironNgn roadmap).
  - `reports/bugs/` — working bug reports, not yet inventoried in detail.
  - `design/`, `discussion/`, `issues/`, `history/`, `planning/` (each holding a `linking.md`) — pre-migration snapshots of the doc set already fully live at the top-level `linking.md` concern docs. Confirmed by diff: same content modulo slug-path vs. id-based anchors. Nothing to migrate here; archived for history only.
  - `tdb-era/` — 16 files describing the TerminusDB-backed substrate ApeironNgn replaced, plus `Aperas-dev-status.md`: <a name='id/BlockNode:00CE0YFEN0007' class='aperas-anchor aperas-id'></a> TDB-era in origin despite sitting at the `archive/` top level, pulled out of `tdb-era/` only because its coverage spans many future dev phases too broad for that folder. Treated the same as the rest of this era — see [Settled](../discussion/archive-migration.md#id/BlockNode:00CE0HD0HG002). Oldest, and lowest priority for this pass.
- **Why newest-first**: <a name='id/BlockNode:00CE0YFEN0008' class='aperas-anchor aperas-id'></a> The ApeironNgn-era docs describe the substrate this migration itself runs on (`store.ts`, `artifacts.ts`, reconciliation, addressing) — getting that into the graph early means later sub-tasks (including the TDB-era ones, which are pure history at this point) can link back to live design docs instead of archived prose. TDB-era docs don't block anything downstream, so they go last.
