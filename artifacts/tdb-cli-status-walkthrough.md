# TerminusDB CLI Status Walkthrough & Operational Reference

Operational reference for checking status, commit logs, document contents, and remote state of the `aperas` database using the `tdb` CLI shortcut. For complete reference of TerminusDB CLI, see the [official documentation](https://terminusdb.org/docs/terminusdb-cli-commands/).

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
tdb log admin/aperas | less
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
tdb log admin/aperas --json --count -1 2>/dev/null \
  | jq '.[] | select(.message | contains("Aperas-dev-status.md"))'
```

---

## 3. Substrate Document Inspection

Retrieve stored documents by JSON-LD class (`ArtifactNode`, `BlockNode`, `BaseLink`, `BaseEdge`):

### Raw JSONL Output
`tdb doc get` outputs raw JSONL (one JSON object per line) with UTC timestamps and literal `\n`/`\t` escape sequences:

```bash
tdb doc get admin/aperas --type="ArtifactNode" | jq | less
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
tdb query admin/aperas "t(X, 'docId', Y)" --json
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
tdb remote add admin/aperas remote_node "http://172.17.0.1:6364/admin/aperas"
tdb fetch admin/aperas --remote=remote_node --user=admin --password=<password>
```

### 4. Inspect Remote Tracking State Read-Only
Inspect fetched remote branches before merging into local state:

```bash
# View remote commit log
tdb log admin/aperas/remote_node/branch/main | less

# View remote document content
TERMINUSDB_DB_SPEC="admin/aperas/remote_node/branch/main" Aperas/scripts/tdb-doc.sh --id="ArtifactNode/Aperas-dev-status.md"
```

---

## 6. Reconciling Diverged Histories (`rebase`)

`push`/`pull` only fast-forward — if the local and remote branches have both moved on from their common point, both fail with `no_common_history` rather than merging. `rebase` is the reconciliation path (see `skills/terminusdb/references/cli.md` §"Merging" for its general semantics: replays one side's divergent commits onto the other, new commit IDs, no merge commit).

### 6.1. `rebase`'s `FROM` argument rejects a remote-tracking spec directly
`terminusdb rebase TO FROM` silently falls back to printing usage (exit `0`, no error text) when `FROM` is a remote-tracking branch spec (`admin/aperas/remote_node/branch/main`) — it only accepts a local branch spec. Materialize the remote-tracking head as a local branch first:

```bash
tdb branch create admin/aperas/local/branch/from_remote --origin=admin/aperas/remote_node/branch/main
```

### 6.2. `rebase TO FROM`: `TO ← FROM` is the direction of the write
`TO` is the destination and gets overwritten; `FROM` is the source/base and stays untouched — same as git rebase (`rebase TO FROM` ≡ `git checkout TO && git rebase FROM`), see `skills/terminusdb/references/cli.md` §"Merging" for the full mapping. Direction matters for performance, not just correctness:

Given a long-lived local `main` (1120 commits) and a short remote-derived branch (`from_remote`, 9 commits unique beyond the common ancestor), only one direction reconciles cleanly — put the branch you want *updated* as `TO`:

```bash
# TO=main (the branch that would be overwritten), FROM=from_remote (supplies the base).
# Replays main's 1120 commits on top of from_remote's small base — hangs / spins CPU, kill and avoid:
# tdb rebase admin/aperas admin/aperas/local/branch/from_remote

# TO=from_remote (the branch that gets overwritten), FROM=main (supplies the base, untouched).
# Forwards main's 1120 commits as the new base, then replays from_remote's own 9 unique
# commits on top of it — completes quickly, no conflicts:
tdb rebase admin/aperas/local/branch/from_remote admin/aperas
```

After the working direction, `from_remote` (`TO`) contains the full reconciled history (1129 commits); `main` (`FROM`) is untouched by the operation — promoting the reconciled branch into `main`, or force-syncing a remote, is covered in §7 below.

### 6.3. Cleaning up the scratch branch
Once `from_remote` (or any working branch created for a reconciliation like this) has served its purpose — its history promoted into `main` via §7.1, or abandoned — delete it:

```bash
tdb branch delete admin/aperas/local/branch/from_remote
```

Same `BRANCH_SPEC` shape `branch create`/`rebase` take (full `local/branch/<name>` path, not a bare db spec). This only removes the branch pointer, not any commits/layers still reachable from `main` or elsewhere — nothing reachable only from `from_remote` and nowhere else survives, same as any content-addressed VCS.

---

## 7. Force-Syncing Branches (`reset` — no merge, discard-and-replace)

`push`/`pull` have no `--force` flag (checked live via `--help`) — there's no wire-protocol way to make one side's branch simply overwrite the other's. The actual hard-reset primitive is `reset`, exactly like `git reset --hard <commit>`, and it's purely local: it only ever rewrites a branch ref on the store the CLI is currently talking to.

```bash
tdb reset BRANCH_SPEC COMMIT_OR_COMMIT_SPEC
```

Unlike §6's `rebase`, no intermediate local branch needed (like `rebase`'s `FROM`-argument) — `reset` takes a raw commit id, and any commit `fetch` has already pulled the layers for works directly, remote-tracking spec or not:

```bash
tdb fetch admin/aperas --remote=remote_node --user=admin --password=<password>
tdb log admin/aperas/remote_node/branch/main | head -1              # note the tip commit id
tdb reset admin/aperas/local/branch/main <remote-tracking-tip-commit-id>
```

**Reciprocal**: this recipe *is* both directions — "forced pull" (above) is just "forced push" run **from the other end**. We cannot do a forced push from this end, because `reset` is local-only.

---

## 8. Backup & Recovery Operations

- **Whole-Volume Tarball (`Aperas/scripts/restore.sh backup-full | verify-full | restore-full`)**:
  **Primary adopted backup & transfer mechanism**. Captures consistent cold snapshots of `terminusdb_storage` for cross-machine host transfers.
- **Same-Store Snapshot (`Aperas/scripts/restore.sh backup | verify | restore`)**:
  CLI `.bundle` exports are restricted to same-instance local rollbacks only (due to cross-store layer reference incompatibility issue #2509).
