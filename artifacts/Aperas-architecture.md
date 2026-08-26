# Aperas Substrate Architecture Specification (Phase 0)

Technical reference for the Phase 0 TerminusDB substrate implementation, canonical JSON-LD schema design, AST transduction pipelines, backup mechanisms, and cross-machine synchronization protocols.

---

## 1. System Paradigm & Repository Layout

### Architectural Paradigm
- **Apeiron (Fluid Core Substrate)**: Schema-free semantic continuum storing Markdown content as coarse AST nodes and character offset ranges.
- **Peras (Crystallized Interfaces)**: Disposable, typed boundary structures reified on-demand for deterministic interaction.

### Directory Structure & Boundaries
```
Aperas/
├── AperasKG/                         # Git repository tracking KG artifacts and tooling
│   ├── artifacts/                    # Plain-text Markdown projections & documentation
│   └── db/                           # Operational scripts, CLI utilities & snapshots
│       ├── snapshots/                # Periodic database snapshots
│       ├── config.md                 # Server & volume configuration reference
│       ├── restore.sh                # Backup, restore & verification suite
│       ├── tdb-log.sh                # Local-time commit log helper (default count: 20)
│       └── tdb-doc.sh                # Local-time document inspection helper
├── skills/                           # Local agent skill definitions
│   └── terminusdb/                   # TerminusDB operational reference skill
└── web/                              # TypeScript project for substrate transducers & UI
    └── src/lib/                      # Core data access, AST transducer & schema modules
```

---

## 2. Canonical Data Substrate & Schema

The canonical schema is implemented in `web/src/lib/schema.ts` using JSON-LD class definitions:

| JSON-LD Class | Key Strategy | Core Fields | Purpose |
| :--- | :--- | :--- | :--- |
| `DocumentNode` | Lexical (`docId`) | `docId`, `title`, `rawMarkdown`, `createdAt` | Root container for ingested articles or specs. |
| `BlockNode` | Lexical (`blockId`) | `blockId`, `docId`, `nodeType`, `content`, `startOffset`, `endOffset`, `parentBlockId` | Coarse structural AST nodes (paragraph, header, list item). |
| `SpanNode` | Lexical (`spanId`) | `spanId`, `blockId`, `text`, `startOffset`, `endOffset`, `predicate` | On-demand reified inline character offset ranges (`<span>` pattern). |
| `TripleAssertion` | Random | `subjectId`, `predicate`, `objectId`, `provenance`, `timestamp` | Typed semantic edges (`impacts`, `verifies`, `derived_from`, `affects`). |
| `ArtifactNode` | Lexical (`path`) | `path`, `contentHash`, `lastTrackedAt`, `ingestedHash`, `lastIngestedAt`, `docId` | Metadata index for tracking repository files and hash deltas. |

> **Schema Protocol Requirement**: Schema initialization uses `full_replace` for idempotent updates. The submitted schema array **must include an explicit `@context` document** (`@base: "terminusdb:///data/"`, `@schema: "terminusdb:///schema#"`), or the server will reject the replacement.

---

## 3. Data Access & Transduction Modules

| Module | Location | Responsibilities & Protocol Constraints |
| :--- | :--- | :--- |
| **Client Manager** | `web/src/lib/client.ts` | Configures `TerminusDB.WOQLClient`, creates `aperas_apeiron` database, applies idempotent schema initialization via `full_replace`. |
| **AST Transducer** | `web/src/lib/astParser.ts` | Uses `unified.js` (`remark-parse`) to convert Markdown into `BlockNode` trees while preserving exact character start/end offsets. |
| **Document CRUD** | `web/src/lib/crud.ts` | Handles document/block persistence and lazy span atomization. Uses `deleteDocumentsIfExist` to batch block deletion into a single atomic commit during document re-ingestion. |
| **WOQL Engine** | `web/src/lib/woql.ts` | Executes graph queries and impact sweeps along `impacts` edges. **Requirement**: String literals must be wrapped in `WOQL.string(...)`; raw strings are parsed as node references. |
| **GraphQL Client** | `web/src/lib/graphql.ts` | Dispatches custom GraphQL queries to `/api/graphql/<org>/<db>` via `client.sendCustomRequest`. |
| **Version Control** | `web/src/lib/versionControl.ts` | Manages branches, temporal commit histories, version diffing, merge applications (`apply`), and state resets. |

---

## 4. Artifact Tracking & Ingestion Pipeline

Managed via `web/src/lib/artifacts.ts` and CLI entrypoint `web/src/lib/kgCli.ts`:

- **Lightweight Registration (`npm run kg:track`)**:
  Computes content hashes for files under `AperasKG/artifacts/` and upserts lightweight `ArtifactNode` records.
- **Incremental Ingestion (`npm run kg:ingest`)**:
  Compares current file content hash against stored `ingestedHash`. If modified, parses Markdown into AST nodes, clears prior block trees via `deleteDocumentsIfExist`, and commits the updated `DocumentNode` and `BlockNode` set in a single commit.

---

## 5. Backup, Disaster Recovery & Synchronization Strategy

### Whole-Volume Disaster Recovery (`restore.sh backup-full | verify-full | restore-full`)
- **Primary Adopted Method**: Creates a tarball of the backing Docker volume `terminusdb_storage` via a temporary Alpine container with the TerminusDB container temporarily stopped to ensure on-disk head consistency.
- **Scope**: **Cross-Machine Host Transfer**.
- **Restore Safety**: `restore-full` extracts into an isolated temporary volume/container (`<container>-restored`) for inspection. Automatic promotion (`--overwrite`) updates container volume bindings with automatic fallback to `-old` on startup failure.

### Same-Store Snapshot (`restore.sh backup | verify | restore`)
- **Mechanism**: Wraps TerminusDB `bundle` / `unbundle` CLI commands. `backup` self-verifies by unbundling into a temporary verification database.
- **Scope**: **Same-instance snapshot & local rollback only**. CLI `.bundle` exports suffer from cross-store layer reference incompatibility (issue #2509) and cannot be transferred across independent TerminusDB server instances.

---

## 6. SSH-Tunneled Remotes

TerminusDB remotes communicate over HTTP REST endpoints. Cross-machine communication between separate hosts utilizes SSH local port forwarding:

1. **Transport Rationale**: Native remote commands (`push`/`pull`/`fetch`/`clone`) speak HTTP(S) only. TerminusDB itself listens on `0.0.0.0:6363` inside the container (confirmed via `/proc/net/tcp`) — the loopback-only restriction (`127.0.0.1:6363`) is this project's own `docker run -p 127.0.0.1:6363:6363` deployment choice, not a TerminusDB default. Either way, this project's containers are loopback-only, so cross-machine transport requires an SSH tunnel.
2. **Tunnel Endpoint**: `ssh -N -f -L 0.0.0.0:6364:localhost:6363 <user>@<remote-host>`
3. **Firewall Access**: `sudo ufw allow from 172.17.0.0/16 to any port 6364 proto tcp`
4. **Bridge Addressing**: Remote URLs target the host's Docker bridge gateway (`http://172.17.0.1:6364/admin/aperas_apeiron`).
5. **Remote Tracking**: `fetch` updates local remote-tracking descriptors (`<org>/<db>/<remote>/branch/<branch>`). `fetch` must be executed before `push` or `pull` can resolve remote heads.

---

## 7. Verification & Operational Utilities

- **Verification Test Harness**: `npm run verify:phase0 -- --db` (`web/src/lib/verifyPhase0.ts`) tests schema application, AST transduction, span atomization, CRUD, WOQL traversals, GraphQL endpoints, and branch history.
- **`AperasKG/db/tdb-log.sh`**: Provides compact, local-time commit history (`--count 20` by default) with fast client-side message filtering (`--filter`). Avoids sluggish `tdb history` diffs.
- **`AperasKG/db/tdb-doc.sh`**: Wraps `tdb doc get` to convert ISO UTC timestamps to local time and unescape literal newlines (`\n`) into readable multi-line prose.
