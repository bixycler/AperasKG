# TerminusDB CLI Status Walkthrough & Operational Reference

Operational reference for checking status, commit logs, document contents, and remote state of the `aperas_apeiron` database using the `tdb` CLI shortcut. For complete reference of TerminusDB CLI, see the [official documentation](https://terminusdb.org/docs/terminusdb-cli-commands/).

```bash
alias tdb='docker exec terminusdb /app/terminusdb/terminusdb'
```

---

## 1. Database & Branch Verification

Confirm database presence and inspect active branches across all stored databases:

```bash
tdb db list --branches
```

---

## 2. Commit Log Inspection & Document Filtering

### Standard Branch Log
Inspect full commit history for the main branch:

```bash
tdb log admin/aperas_apeiron | less
```

### Compact Local-Time History
Use `tdb-log.sh` (located in `Aperas/scripts/`) for local-time formatting and auto-paging. Output defaults to 20 commits (`--count` parameter is only needed when overriding, e.g., `--count 50` or `--count -1`):

```bash
Aperas/scripts/tdb-log.sh
```

### Document History Filtering
> **Performance Warning**: `tdb history --id="..."` is measurably slow — over 6× slower than dumping the entire log (572 commits: `log --count -1` ~2.2s vs. `history` for one document ~13s). It's not walking an index of changed ids per commit; the exact mechanism wasn't confirmed, but the timing is consistent with checking the document's actual state at every commit along the way. Use message-filtering on `tdb log` or `tdb-log.sh` as the fast alternative:

```bash
# Fast message filter via tdb-log.sh
Aperas/scripts/tdb-log.sh --filter "Aperas-dev-status.md"

# Fast JSON filter via raw CLI & jq
tdb log admin/aperas_apeiron --json --count -1 2>/dev/null \
  | jq '.[] | select(.message | contains("Aperas-dev-status.md"))'
```

---

## 3. Substrate Document Inspection

Retrieve stored documents by JSON-LD class (`ArtifactNode`, `BlockNode`, `BaseLink`, `BaseEdge`):

### Raw JSONL Output
`tdb doc get` outputs raw JSONL (one JSON object per line) with UTC timestamps and literal `\n`/`\t` escape sequences:

```bash
tdb doc get admin/aperas_apeiron --type="ArtifactNode" | jq | less
```
> **Note**: Add `--as-list=true` to convert JSONL lines into a single JSON array for program analysis.

### Unescaped Local-Time View (`tdb-doc.sh`)
Use `tdb-doc.sh` to unescape embedded line breaks into readable text and convert ISO UTC timestamps to local time:

```bash
Aperas/scripts/tdb-doc.sh --type="BlockNode"
```

---

## 4. Direct WOQL Graph Queries

Execute arbitrary WOQL queries against the substrate:

```bash
tdb query admin/aperas_apeiron "t(X, 'docId', Y)" --json
```

---

## 5. SSH-Tunneled Remotes

### Transport Overview
TerminusDB's native remote commands (`push`/`pull`/`fetch`/`clone`) communicate exclusively over HTTP(S) REST APIs without native SSH transport support. TerminusDB itself listens on `0.0.0.0:6363` inside the container — the loopback-only restriction (`127.0.0.1:6363`) is this project's own `docker run -p` configuration, not a TerminusDB default. Either way, cross-machine communication between separate hosts requires an SSH local port forward tunnel here.

### 1. Establish SSH Local Port Forwarding
Forward local port `6364` on the source host to port `6363` on the remote target host. Bind to `0.0.0.0` so the local Docker container network can reach the tunnel:

```bash
ssh -N -f -L 0.0.0.0:6364:localhost:6363 <user>@<remote-host>
```

### 2. Configure Host Firewall (UFW)
Allow traffic from the Docker bridge subnet (`172.17.0.0/16`) to port `6364`:

```bash
sudo ufw allow from 172.17.0.0/16 to any port 6364 proto tcp
```

### 3. Add Remote & Fetch Tracking Heads
Point the remote URL to the host's Docker bridge gateway (`172.17.0.1`):

```bash
# Verify bridge gateway IP
docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'

# Register remote and fetch remote-tracking reference
tdb remote add admin/aperas_apeiron remote_node "http://172.17.0.1:6364/admin/aperas_apeiron"
tdb fetch admin/aperas_apeiron --remote=remote_node --user=admin --password=<password>
```

### 4. Inspect Remote Tracking State Read-Only
Inspect fetched remote branches before merging into local state:

```bash
# View remote commit log
tdb log admin/aperas_apeiron/remote_node/branch/main | less

# View remote document content
TERMINUSDB_DB_SPEC="admin/aperas_apeiron/remote_node/branch/main" Aperas/scripts/tdb-doc.sh --id="ArtifactNode/Aperas-dev-status.md"
```

---

## 6. Backup & Recovery Operations

- **Whole-Volume Tarball (`Aperas/scripts/restore.sh backup-full | verify-full | restore-full`)**:
  **Primary adopted backup & transfer mechanism**. Captures consistent cold snapshots of `terminusdb_storage` for cross-machine host transfers.
- **Same-Store Snapshot (`Aperas/scripts/restore.sh backup | verify | restore`)**:
  CLI `.bundle` exports are restricted to same-instance local rollbacks only (due to cross-store layer reference incompatibility issue #2509).
