# Apeiron JSON-LD Mirror

This directory holds a plain, git-trackable JSON-LD mirror of the knowledge graph — `schema.jsonld` plus one `<ClassName>.jsonld` file per instance class (`ArtifactNode`, `FolderNode`, `BlockNode`, `Assertion`) — kept in sync with TerminusDB in both directions via `npm run kg:export` and `npm run kg:import` (see `web/src/lib/export.ts`).

It exists as a portable interchange boundary: the canonical graph content expressed as plain documents, independent of TerminusDB's own storage internals. See `Aperas-architecture.md` §5 for the mirror format and `Aperas-design.md`'s Development Roadmap ("Phase 4") for why this boundary matters — it's what would let a future substrate engine (ApeironNgn) replace TerminusDB without reshaping the data. `kg:import` also doubles as a practical bootstrap/restore path today: populate a fresh database, or recover state, straight from what's committed here.

Regenerate with `npm run kg:export` rather than hand-editing the `.jsonld` files — a hand edit would just get overwritten by the next export, and would be applied as-is by `kg:import` (there's no validation beyond what TerminusDB's schema enforces on write).
