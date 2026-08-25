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
- `db/snapshots/` — periodic `.bundle` exports of `admin/aperas_apeiron` (see
  `restore.sh`). These are coarse checkpoints, not continuous history — the
  fine-grained commit history stays inside TerminusDB itself.

## What git does NOT track

The live volume data. It's binary, mutates on every commit, and isn't
diffable — back it up via snapshots (`restore.sh backup`) or a full volume
tarball for disaster recovery, not via git.
