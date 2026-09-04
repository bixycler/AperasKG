# Upstream issue: `bundle`/`unbundle` cannot move data between two independent stores

Filed against `terminusdb/terminusdb` as [#2509](https://github.com/terminusdb/terminusdb/issues/2509) (2026-08-26). Related: [#1147](https://github.com/terminusdb/terminusdb/issues/1147), [#1235](https://github.com/terminusdb/terminusdb/pull/1235).

## Title

`bundle`/`unbundle` cannot move data between two independent stores — even on the same host (reproducible; related to #1147, #1235)

## Body

### Summary

`terminusdb bundle`/`terminusdb unbundle` (CLI) only round-trips correctly when the destination is the **same store** that produced the bundle (i.e. a different database within the same running server/storage directory). The moment the destination is a genuinely **different store** — a separate `store init`, even one created moments earlier from the identical Docker image, on the identical physical machine — `unbundle` deterministically fails with `unknown_layer_reference`.

This is very likely the same underlying bug reported in #1147 (closed as not planned, unreproduced by maintainers) and investigated without success in #1235. I believe I've found the reason #1235's tests didn't catch it: every test in `tests/test/cli-bundle.js` calls `cli.store.init()` exactly once in the top-level `before()` hook and shares that single store across all three tests — so none of them ever exercise a bundle moving between two *different* stores, which is the one scenario that actually fails.

### Environment

- `terminusdb/terminusdb-server:v12` (Docker image), pinned digest `sha256:385faf298ad77aaf2d4d6df5e84a4cbe3596d01dab2e3b991af905639ae56388`
- `TerminusDB v12.0.7 (57f2093baeafd65e16004e84b7b58e0c5cf72858)`
- `terminusdb-store v0.19.8`
- Confirmed identical versions on two independent physical machines (originally reported as a cross-machine issue), **and** reproduced with two containers on a single machine (see below) — ruling out network/host/version/edition as factors.
- Community edition (no license key). The only documented guarantee for moving a database between servers I could find (https://terminusdb.org/docs/enterprise-backup-restore/) is explicitly scoped to Enterprise edition and uses a different mechanism (`/api/bundle` + `/api/unbundle` REST endpoints, target database pre-created). This report is about the CLI `bundle`/`unbundle` commands in Community edition.
- `auto-optimize` community plugin (probabilistic layer squash/GC) was disabled for all tests below (moved `/plugins/auto-optimize.pl` out and restarted) to rule it out as a factor. Made no difference.

### Reproduction (single machine, two independent stores)

```bash
# Store A: existing long-running instance
docker run -d --name tdb-a -p 6363:6363 -v tdb_storage_a:/app/terminusdb/storage terminusdb/terminusdb-server:v12

# Store B: brand-new, independent instance, same image, same host
docker run -d --name tdb-b -p 6364:6363 -v tdb_storage_b:/app/terminusdb/storage terminusdb/terminusdb-server:v12

# In store B: create a minimal scratch database
docker exec tdb-b terminusdb db create admin/test --schema=true
docker exec tdb-b terminusdb doc insert admin/test --graph-type=schema \
  --data='{"@type":"Class","@id":"Person","@key":{"@type":"Random"},"name":"xsd:string"}' -m "schema"
docker exec tdb-b terminusdb doc insert admin/test --data='{"@type":"Person","name":"Test1"}' -m "commit 1"
docker exec tdb-b terminusdb bundle admin/test -o /tmp/test.bundle
docker cp tdb-b:/tmp/test.bundle ./test.bundle

# Positive control: unbundle back into store B itself (a different db name, same store) — works
docker cp ./test.bundle tdb-b:/tmp/test.bundle
docker exec tdb-b terminusdb db create admin/test_verify
docker exec tdb-b terminusdb unbundle admin/test_verify /tmp/test.bundle
# => "Unbundle successful"

# The actual test: unbundle into store A (different store, same host, same image/version)
docker cp ./test.bundle tdb-a:/tmp/test.bundle
docker exec tdb-a terminusdb db create admin/test_verify
docker exec tdb-a terminusdb unbundle admin/test_verify /tmp/test.bundle
# => Error: error(unknown_layer_reference("<hash>"))
```

Result is 100% deterministic across repeated runs and across multiple independent bundle files (I tested this against three separate scratch databases with different content/commit counts, always the same failure mode, always a different specific missing-layer hash each time).

### What this rules out

- **Version mismatch** — both stores run the exact same image digest.
- **`auto-optimize` plugin** — disabled on both stores before testing; no change.
- **Store "age"** — reproduced with a store that was `store init`'d seconds before the test, same as the destination.
- **Network/transport corruption** — reproduced with both stores on one machine, files moved via `docker cp` only.
- **Content-specific corruption** — reproduced with a minimal, freshly-created 6-commit scratch database, not just a large/organically-evolved one.

### What still works

Bundling and unbundling **within the same store** (different database, same running server/storage directory) works reliably every time, including after forced/probabilistic layer squashes.

### Ask

- Given #1235's tests never actually exercise the two-store case, would a PR adding that missing test case (spin up two `store.init()` stores, bundle from one, unbundle into the other) be welcome, to at least turn this into a real reproducible regression test?
- Is cross-store portability of `bundle`/`unbundle` intended to work at all in Community edition, or is it only ever meant for same-store snapshot/restore (with genuine cross-server moves being an Enterprise-only capability, as the backup-restore docs suggest)? If the latter, it'd be worth stating explicitly in the CLI docs/help text, since "a pack ... that can then be reconstituted" (the current `bundle --help` description) reads as store-agnostic.

Related: #1147, #1235
