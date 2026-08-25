# Checking DB status with `tdb`

Quick reference for the `tdb` alias — the shortcut for `docker exec terminusdb /app/terminusdb/terminusdb` — covering the checks that answer "is the substrate okay?": existence, history, contents, and a direct query.

```bash
alias tdb='docker exec terminusdb /app/terminusdb/terminusdb'
```

## 1. Confirm the database and its branches

Lists every database on the server; `--branches` also shows each one's branch set — the fastest way to confirm `aperas_apeiron` is actually there.

```bash
tdb db list --branches
```

## 2. Check recent commit history

Confirms `kg:track` / `kg:ingest` runs actually landed.

```bash
tdb log admin/aperas_apeiron
```

## 3. Inspect what's stored, by type

Pull every document of a given class straight out of the substrate. Swap the type to check a different collection — `DocumentNode`, `BlockNode`, `TripleAssertion`, `ArtifactNode`.

```bash
tdb doc get admin/aperas_apeiron --type="ArtifactNode"
```

> **Note:** `--as-list=true` is left off on purpose above. It only switches the output from JSONL (one JSON object per line) to a single JSON array — a machine-consumption format, not a readability one. Add it back when piping into `jq` or a script.

## 4. Query directly with WOQL

For anything more specific than "give me everything of type X" — bindings, joins, traversals — go straight to WOQL's text syntax.

```bash
tdb query admin/aperas_apeiron "t(X, 'docId', Y)" --json
```
