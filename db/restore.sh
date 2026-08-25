#!/usr/bin/env bash
# Backup/restore helpers for the Aperas KG's TerminusDB-backed state.
# See config.md for what these snapshots are (and aren't) a substitute for.
set -euo pipefail

CONTAINER="${TERMINUSDB_CONTAINER:-terminusdb}"
DB_SPEC="${TERMINUSDB_DB_SPEC:-admin/aperas_apeiron}"
SNAPSHOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/snapshots"
TDB_BIN="/app/terminusdb/terminusdb"

usage() {
  echo "Usage: $0 backup | restore <bundle-file> | verify [--keep] <bundle-file>" >&2
  exit 1
}

backup() {
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local dbname="${DB_SPEC#*/}"
  local remote_path="/tmp/${dbname}_${ts}.bundle"
  local local_path="${SNAPSHOT_DIR}/${dbname}_${ts}.bundle"

  echo "Bundling ${DB_SPEC} inside container '${CONTAINER}'..."
  docker exec "$CONTAINER" "$TDB_BIN" bundle "$DB_SPEC" -o "$remote_path"

  echo "Copying bundle to ${local_path}..."
  docker cp "${CONTAINER}:${remote_path}" "$local_path"
  docker exec "$CONTAINER" rm -f "$remote_path"

  echo "Done: ${local_path}"

  # A bundle can be written successfully yet still be unusable (truncation, transport
  # corruption, whatever produced the mojibake-mangled snapshot this script once left
  # behind) — restoring into a disposable database is the only way to actually know it
  # works, and doing it now, at backup time, is the only point where "just take another
  # snapshot" is still a cheap fix.
  if ! verify "$local_path"; then
    echo "[!] WARNING: the snapshot just taken failed verification. It has been kept" \
      "at ${local_path} for forensics, but do not rely on it — investigate or re-run backup." >&2
    return 1
  fi
}

restore() {
  local bundle_file="$1"
  [ -f "$bundle_file" ] || { echo "No such file: $bundle_file" >&2; exit 1; }

  local remote_path="/tmp/$(basename "$bundle_file")"
  echo "Copying ${bundle_file} into container '${CONTAINER}'..."
  docker cp "$bundle_file" "${CONTAINER}:${remote_path}"

  echo "Unbundling into ${DB_SPEC}..."
  docker exec "$CONTAINER" "$TDB_BIN" unbundle "$DB_SPEC" "$remote_path"
  docker exec "$CONTAINER" rm -f "$remote_path"

  echo "Done. Restored ${DB_SPEC} from ${bundle_file}."
}

verify() {
  local keep=0
  if [ "${1:-}" = "--keep" ]; then
    keep=1
    shift
  fi
  local bundle_file="$1"
  [ -f "$bundle_file" ] || { echo "No such file: $bundle_file" >&2; exit 1; }

  local dbname="${DB_SPEC#*/}"
  local org="${DB_SPEC%/*}"
  local verify_db="${dbname}_verify_$$"
  local remote_path="/tmp/$(basename "$bundle_file")_verify_$$"

  echo "Verifying ${bundle_file} by restoring into a disposable database (${org}/${verify_db})..."
  docker cp "$bundle_file" "${CONTAINER}:${remote_path}"
  docker exec "$CONTAINER" "$TDB_BIN" db create "${org}/${verify_db}" --label="restore.sh verification (temporary)" >/dev/null

  local ok=1
  if docker exec "$CONTAINER" "$TDB_BIN" unbundle "${org}/${verify_db}" "$remote_path"; then
    ok=0
  fi

  docker exec "$CONTAINER" rm -f "$remote_path" >/dev/null 2>&1 || true

  if [ "$ok" -eq 0 ]; then
    echo "[✓] Verified: ${bundle_file} unbundles cleanly."
    if [ "$keep" -eq 1 ]; then
      echo "    --keep: leaving '${org}/${verify_db}' in place for inspection." \
        "Delete it yourself when done:" \
        "docker exec ${CONTAINER} ${TDB_BIN} db delete ${org}/${verify_db}"
    else
      docker exec "$CONTAINER" "$TDB_BIN" db delete "${org}/${verify_db}" >/dev/null 2>&1 || true
    fi
    return 0
  else
    echo "[!] Verification FAILED: ${bundle_file} did not unbundle cleanly." >&2
    # A failed unbundle leaves nothing worth inspecting — clean up regardless of --keep.
    docker exec "$CONTAINER" "$TDB_BIN" db delete "${org}/${verify_db}" >/dev/null 2>&1 || true
    return 1
  fi
}

case "${1:-}" in
  backup) backup ;;
  restore) [ $# -ge 2 ] || usage; restore "$2" ;;
  verify)
    shift
    [ $# -ge 1 ] || usage
    verify "$@"
    ;;
  *) usage ;;
esac
