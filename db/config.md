# KG Database Backing

This repo tracks the Aperas knowledge graph. The graph's actual state lives in
TerminusDB, not in git — TerminusDB has its own commit/branch/diff versioning,
which is redundant with (and can't be meaningfully merged by) git.

- **Server**: TerminusDB v12, running via Docker container `terminusdb`
  (restart policy `unless-stopped`, so it survives host reboots).
- **Storage**: Docker named volume `terminusdb_storage`, mounted at
  `/app/terminusdb/storage` inside the container. Host path:
  `/var/lib/docker/volumes/terminusdb_storage/_data`.
- **Database**: `admin/aperas_apeiron`.

## What git tracks here

- `artifacts/` — plain-text (Markdown) projections of the KG: either
  pre-existing artifacts ingested into the graph, or rendered exports from it.
- `db/snapshots/` — periodic database backup archives (see `restore.sh`).
  - **Whole-volume tarball archives (`restore.sh backup-full`)**: The primary adopted mechanism for cross-machine backup and host transfer.
  - **Same-store `.bundle` archives (`restore.sh backup`)**: Kept for fast same-instance local rollbacks; `.bundle` files suffer from cross-store layer reference incompatibility (issue #2509) and cannot be transferred across separate TerminusDB server instances.

## What git does NOT track

The live volume data. It's binary, mutates on every commit, and isn't
diffable — back it up via whole-volume tarball snapshots (`restore.sh backup-full`) or same-instance `.bundle` snapshots for local rollback, not via git.
