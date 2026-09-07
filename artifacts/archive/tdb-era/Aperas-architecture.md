# Aperas Substrate Architecture Specification (Phase 0)

Technical reference for the Phase 0 TerminusDB substrate implementation, canonical JSON-LD schema design, AST transduction pipelines, backup mechanisms, and cross-machine synchronization protocols.

---

## 1. System Paradigm & Repository Layout

### Architectural Paradigm
- **Apeiron (Fluid Core Substrate)**: Schema-free semantic continuum — Markdown content as an unbounded fractal tree, not a fixed document/block hierarchy.
- **Peras (Crystallized Interfaces)**: Typed boundary structures. As of the fractal-ontology redesign, the whole `BlockNode` tree is eagerly parsed and committed on ingest, each block assigned a Snowflake-generated identity independent of its content or offsets, rather than reified lazily on-demand — the on-demand-reification mechanism (`SpanNode`, character-offset spans) described in earlier revisions of this doc was eliminated, not merely deferred.

### Directory Structure: Core vs Community Boundaries
```
Aperas/                               # Core Engine (Maintained by Core Dev Team)
├── scripts/                          # Universal infrastructure & DB operational tooling
│   ├── restore.sh                    # Backup, restore & verification suite
│   ├── tdb-log.sh                    # Local-time commit log helper (default count: 20)
│   └── tdb-doc.sh                    # Local-time document inspection helper
├── skills/                           # Core agent skill definitions
│   └── terminusdb/                   # TerminusDB operational reference skill
├── web/                              # TypeScript project for substrate transducers & UI
│   └── src/lib/                      # Core data access, AST transducer & schema modules
│
└── AperasKG/                         # Domain KG (Maintained by Community)
    ├── artifacts/                    # Plain-text Markdown domain projections & documentation
    ├── Apeiron/                      # Portable JSON-LD substrate mirror (schema + instances), bidirectional — see §5
    ├── schema/                       # Domain-specific JSON-LD schemas extending core
    ├── ontology/                     # Domain-specific predicate taxonomy / vocabularies
    └── transducers/                  # Domain-specific ingestion/parsing scripts
```

---

## 2. Canonical Data Substrate & Schema

The canonical schema is implemented in `web/src/lib/schema.json` (pure JSON-LD, no longer duplicated as TypeScript interfaces) using a fractal, content-addressed class lineage — see `Aperas-core-ontology-design.md` for the full rationale:

| JSON-LD Class | Key Strategy | Core Fields | Purpose |
| :--- | :--- | :--- | :--- |
| `BaseNode` | — (abstract) | `links: Set<BaseLink>` | Root of all addressable content; owns intrinsic links. |
| `BaseLink` | — (abstract) | `target: BaseNode`, `predicate` | Intrinsic connection authored inside a node. |
| `BaseEdge` | — (abstract) | `source: BaseNode` (+ `BaseLink` fields) | Extrinsic assertion, independently authored/floating. |
| `Assertion` | — (concrete, no own fields) | inherits `BaseEdge` | The one concrete extrinsic-edge leaf type — `BaseEdge` is abstract, so something instantiable is needed to actually write edges like `impacts`/`verifies`/`affects`. See `Aperas-core-ontology-design.md` §2.C. |
| `BlockNode` | Lexical (`blockId`, Snowflake-generated) | `blockId`, `title`, `text`, `children: List<BlockNode>`, `unfolded` | Fractal content atom — a document is just the root `BlockNode` of its `ArtifactNode`; no separate `DocumentNode`. |
| `ArtifactNode` | Lexical (`path`) | `path`, `fileHash`, `lastTrackedAt`, `ingestedHash`, `lastIngestedAt`, `root: BlockNode` | Metadata index for tracking repository files and hash deltas; anchors the fractal tree. `fileHash`/`ingestedHash` are flat file-content hashes, not structural — see `Aperas-core-ontology-design.md` §1.B. |
| `FolderNode` | Lexical (`path`) | `title`, `path`, `text`, `children: List<BaseNode>` | Structural container mirroring a directory under `AperasKG/artifacts/`; absorbs its own `README.md` (never exposed as a separate `ArtifactNode`) and references nested `FolderNode`s/`ArtifactNode`s by id. See `Aperas-core-ontology-design.md` §4.A. |

> **Design note**: `BlockNode` identity is a Snowflake-style generated id (see `web/src/lib/snowflake.ts`), not a content hash — decoupling node identity from content fingerprinting was the resolution to the identity/dedup conflation documented in `Aperas-core-ontology-design.md` Appendix F.
>
> **Superseded**: `DocumentNode`, `SpanNode`, and `TripleAssertion` (Lexical/Random-keyed, positional `blockId`s) were the Phase 0 schema before this redesign — eliminated entirely, not merely renamed.

> **Schema Protocol Requirement**: Schema initialization uses `full_replace` for idempotent updates. The submitted schema array **must include an explicit `@context` document** (`@base: "terminusdb:///data/"`, `@schema: "terminusdb:///schema#"`), or the server will reject the replacement.

---

## 3. Data Access & Transduction Modules

| Module | Location | Responsibilities & Protocol Constraints |
| :--- | :--- | :--- |
| **Client Manager** | `web/src/lib/client.ts` | Configures `TerminusDB.WOQLClient`, creates `aperas` database, applies idempotent schema initialization via `full_replace` from `schema.json`. |
| **Node Identity** | `web/src/lib/snowflake.ts` | Generates the 64-bit Snowflake-style `blockId` (timestamp + machine identity + sequence, 13-char Crockford Base32) — see `Aperas-core-ontology-design.md` §1.A. |
| **AST Transducer** | `web/src/lib/astParser.ts` | Uses `unified.js` (`remark-parse`) to recursively convert Markdown into a nested `BlockNode` tree, assigning each block a fresh Snowflake id via `snowflake.ts` (identity is never derived from content or position). |
| **Artifact Tracking & Ingestion** | `web/src/lib/artifacts.ts` | Computes `fileHash`, tracks/upserts lightweight `ArtifactNode`s, and ingests the full `BlockNode` tree on change — see §4 below. |
| **Folder Ingestion** | `web/src/lib/folders.ts` | Walks `AperasKG/artifacts/` and commits the `FolderNode` structural tree — see §4 below. |
| **Extrinsic Assertion CRUD** | `web/src/lib/crud.ts` | `insertAssertion`/`deleteAssertionsInvolvingNode` for the concrete `Assertion` type (source/predicate/target, node-typed per §3 of the design doc's rejection of the `xsd:string` anti-pattern), plus generic best-effort document delete helpers. |
| **WOQL Engine** | `web/src/lib/woql.ts` | Builds and executes WOQL queries over `Assertion` — `queryNodeAssertions` (both directions) and `traceImpactPropagation` (one-hop sweep along a predicate like `impacts`). |
| **GraphQL Client** | `web/src/lib/graphql.ts` | `getArtifactTreeViaGraphQL` fetches an `ArtifactNode` and its full nested `BlockNode` tree (bounded depth) via the auto-generated GraphQL endpoint — see the note below on why this is the *only* full-tree read path. |
| **Version Control** | `web/src/lib/versionControl.ts` | Manages branches, temporal commit histories, version diffing, merge applications (`apply`), and state resets. Class-agnostic — unaffected by the schema redesign. |
| **JSON-LD Import/Export** | `web/src/lib/export.ts` | `exportJsonLd`/`importJsonLd` mirror the current schema plus every instance document (per class) between TerminusDB and plain JSON-LD files in `AperasKG/Apeiron/` — see §5. |

> **Read-path note**: `client.getDocument()` on an `ArtifactNode` returns `root` as a bare reference id string, not the nested tree, and likewise for `BlockNode.children`. This is *not* because `@subdocument` is required for unfolding (a natural-sounding but wrong assumption we initially made) — it's simply that `BlockNode` isn't schema-annotated as unfoldable. TerminusDB has two independent schema-level annotations that control this: property-level `"@unfold": true` and class-level `"@unfoldable": []`. We benchmarked marking `BlockNode` class-level `@unfoldable` (which does work, including through the recursive `List<BlockNode>` children) against the real 149-block `Aperas-core-ontology-design.md` tree, and it was ~3.5x slower than `getArtifactTreeViaGraphQL`'s GraphQL query (~48ms vs ~13.5ms steady-state) — so we kept GraphQL as the tree-read path rather than adopting it. Separately, we found that the *property-level* `"@unfold": true` variant silently does nothing on `List`-typed fields specifically (works on `Set`/`Optional`/`Cardinality`) — an upstream bug, filed as [terminusdb/terminusdb#2512](https://github.com/terminusdb/terminusdb/issues/2512), traced to `List`'s internal RDF-linked-list (`Cons`/`rdf:first`/`rdf:rest`) representation not being reachable from the property-level unfold check. That bug doesn't affect our decision (we'd have used class-level `@unfoldable`, which is unaffected), but is a useful data point that this part of TerminusDB is new and still maturing.

---

## 4. Artifact Tracking & Ingestion Pipeline

Managed via `web/src/lib/artifacts.ts` and CLI entrypoint `web/src/lib/kgCli.ts`:

- **Lightweight Registration (`npm run kg:track`)**:
  Computes content hashes for files under `AperasKG/artifacts/` and upserts lightweight `ArtifactNode` records — a no-op skip (no KG write at all) when the hash is unchanged, so unscoped sweeps (e.g. the `post-index-change` hook) stay cheap.
- **Incremental Ingestion (`npm run kg:ingest`)**:
  Compares current file content hash (`fileHash`) against stored `ingestedHash`. If changed, parses Markdown into a nested `BlockNode` tree (fresh Snowflake ids throughout) and commits it via a single `ArtifactNode.root` update — TerminusDB recursively ingests the whole tree in one operation. Re-ingesting an already-ingested artifact currently orphans its entire previous tree rather than reusing unchanged blocks' ids — acceptable for now since ingestion targets uningested artifacts; cross-ingestion identity matching is unimplemented (see `Aperas-core-ontology-design.md` Appendix F).
  Also rebuilds the `FolderNode` structural tree (`web/src/lib/folders.ts`) in the same run: one `FolderNode` per directory under `AperasKG/artifacts/`, each absorbing its own `README.md` (parsed blocks become the folder's own children; the file itself is never exposed as a separate `ArtifactNode`) and referencing nested `FolderNode`s/`ArtifactNode`s by id. The whole folder tree is committed as a single nested write from the artifacts root each run — cheap, since it's directory-count-sized, not content-sized.

---

## 5. JSON-LD Substrate Import/Export

`web/src/lib/export.ts`, wired through `kgCli.ts`, bidirectionally mirrors the schema and every instance document between TerminusDB and plain JSON-LD files in `AperasKG/Apeiron/`:

| File | Contents |
| :--- | :--- |
| `schema.jsonld` | The full schema graph (`getDocument({ graph_type: 'schema' })`), verbatim. |
| `ArtifactNode.jsonld`, `FolderNode.jsonld`, `BlockNode.jsonld`, `Assertion.jsonld` | One file per instance class — a leading `@context` document, then every live (`getDocument({ type, as_list: true })`) instance of that class, sorted by id for diff-stable re-exports. |

- **`npm run kg:export`** — writes all of the above from the current TerminusDB state, overwriting the files.
- **`npm run kg:import`** — reads the files back: applies `schema.jsonld` via `full_replace`, then upserts each class's instances (every document already carries its own `@id`, so a matching document is updated in place, not duplicated). Each class is submitted as a single batched `updateDocument` call, in the dependency order `BlockNode` → `ArtifactNode` → `FolderNode` → `Assertion`, so a document is never written before something it references — `BlockNode`'s own parent/child references resolve within its own batch (one commit, so intra-batch forward references are fine); everything after it can then safely reference already-committed ids. Every write is its own TerminusDB commit, so before writing the schema or a given class, its content hash is compared (`hashDocSet` in `client.ts` — the same order-independent hash already used to skip a no-op schema apply) against what's currently live, and the write is skipped entirely when nothing changed, rather than landing a no-op commit.

### Purpose: how `AperasKG` holds a backup of its own KG

This round-trip — not a TerminusDB-level backup — is the correct answer to "how does `AperasKG` hold a record of its KG," per its original design goal of storing both the artifacts and the KG. `AperasKG/Apeiron/` is the canonical graph content, materialized as plain, diffable JSON-LD text and committed to the same git repository as `AperasKG/artifacts/` — an ordinary `git commit` over that directory *is* the KG's backup, with all the history, diffing, and portability that implies, and `kg:import` is the restore path (bootstrap a fresh database, or recover state) back out of it. This also happens to make the content engine-agnostic — `AperasKG/Apeiron/` is a snapshot any future substrate engine could read without a bespoke migration script (see `Aperas-design.md`'s Development Roadmap, "Phase 4: Substrate Evolution") — but that's a secondary benefit of the same design, not the primary reason it exists.

### Scope and non-goals

- **Flat, not nested.** Instances are dumped and read back exactly as `getDocument`/`updateDocument` handle them — `BlockNode.children` and `ArtifactNode.root` are reference ids, not inlined subtrees (see §2's "Read-path note"), matching how TerminusDB itself stores documents and keeping per-class diffs scoped to that class alone.
- **Includes tombstoned documents.** The export/import round-trip is a full audit snapshot, not a live-only view — reconciliation's `tombstonedAt` markers (`Aperas-reconciliation-matching-design.md`) are preserved rather than filtered out.
- **Whole-class granularity, not a merge.** Import upserts every document in a class file; it doesn't diff against the live database or reconcile divergence — reconciliation (`reconcile.ts`) only ever runs against `AperasKG/artifacts/` content during `kg:ingest`, not against this export/import path.

---

## 6. TerminusDB Server Operational Backup

This section is server infrastructure for the TerminusDB instance itself — Docker-volume-level disaster recovery, unrelated to `AperasKG`'s own record of its content. It answers "how do I recover this TerminusDB server if its volume is lost," not "how does `AperasKG` hold a backup of its KG." That second question is answered by §5: `AperasKG/Apeiron/` plus `kg:export`/`kg:import`, git-tracked alongside `AperasKG/artifacts/` like any other content in the domain-KG repo — not by storing TerminusDB-level snapshots in or near `AperasKG` at all, which an earlier design iteration tried (`db/` briefly lived under `AperasKG/`) before being reconsidered as the wrong coupling: a git-tracked domain repo has no good way to diff, merge, or meaningfully version an opaque binary DB snapshot, and (per the investigation below) those snapshots aren't even portable between independent TerminusDB stores.

### Whole-Volume Disaster Recovery (`restore.sh backup-full | verify-full | restore-full`)
- **Primary Adopted Method**: Creates a tarball of the backing Docker volume `terminusdb_storage` via a temporary Alpine container with the TerminusDB container temporarily stopped to ensure on-disk head consistency.
- **Scope**: **Cross-Machine Host Transfer**.
- **Restore Safety**: `restore-full` extracts into an isolated temporary volume/container (`<container>-restored`) for inspection. Automatic promotion (`--overwrite`) updates container volume bindings with automatic fallback to `-old` on startup failure.

### Same-Store Snapshot (`restore.sh backup | verify | restore`)
- **Mechanism**: Wraps TerminusDB `bundle` / `unbundle` CLI commands. `backup` self-verifies by unbundling into a temporary verification database.
- **Scope**: **Same-instance snapshot & local rollback only**. CLI `.bundle` exports suffer from cross-store layer reference incompatibility (issue #2509) and cannot be transferred across independent TerminusDB server instances.

---

## 7. SSH-Tunneled Remotes

TerminusDB remotes communicate over HTTP REST endpoints. Cross-machine communication between separate hosts utilizes SSH local port forwarding:

1. **Transport Rationale**: Native remote commands (`push`/`pull`/`fetch`/`clone`) speak HTTP(S) only. TerminusDB itself listens on `0.0.0.0:6363` inside the container (confirmed via `/proc/net/tcp`) — the loopback-only restriction (`127.0.0.1:6363`) is this project's own `docker run -p 127.0.0.1:6363:6363` deployment choice, not a TerminusDB default. Either way, this project's containers are loopback-only, so cross-machine transport requires an SSH tunnel.
2. **Tunnel Endpoint**: `ssh -N -f -L 0.0.0.0:6364:localhost:6363 <user>@<remote-host>`
3. **Firewall Access**: `sudo ufw allow from 172.17.0.0/16 to any port 6364 proto tcp`
4. **Bridge Addressing**: Remote URLs target the host's Docker bridge gateway (`http://172.17.0.1:6364/admin/aperas`).
5. **Remote Tracking**: `fetch` updates local remote-tracking descriptors (`<org>/<db>/<remote>/branch/<branch>`). `fetch` must be executed before `push` or `pull` can resolve remote heads.

---

## 8. Verification & Operational Utilities

- **Verification Test Harness**: `npm run verify:phase0 -- --db` (`web/src/lib/verifyPhase0.ts`) — end-to-end, idempotent, self-cleaning live test: AST parsing, schema init, artifact track/ingest, GraphQL tree read, `FolderNode` ingestion, `Assertion` CRUD + WOQL impact propagation, and temporal commit management (branch + commit log). Demo-state cleanup has to happen in reference-reversed order — `FolderNode` before `ArtifactNode` before its `BlockNode`s — since TerminusDB enforces referential integrity and rejects deleting a still-referenced document.
- **`Aperas/scripts/tdb-log.sh`**: Provides compact, local-time commit history (`--count 20` by default) with fast client-side message filtering (`--filter`). Avoids sluggish `tdb history` diffs.
- **`Aperas/scripts/tdb-doc.sh`**: Wraps `tdb doc get` to convert ISO UTC timestamps to local time and unescape literal newlines (`\n`) into readable multi-line prose.
