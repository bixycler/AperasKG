#!/usr/bin/env bash
# Backup/restore helpers for the Aperas KG's TerminusDB-backed state.
# See config.md for what these snapshots are (and aren't) a substitute for.
set -euo pipefail

CONTAINER="${TERMINUSDB_CONTAINER:-terminusdb}"
DB_SPEC="${TERMINUSDB_DB_SPEC:-admin/aperas_apeiron}"
SNAPSHOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/snapshots"
TDB_BIN="/app/terminusdb/terminusdb"

usage() {
  echo "Usage: $0 backup | restore <bundle-file>" >&2
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

case "${1:-}" in
  backup) backup ;;
  restore) [ $# -ge 2 ] || usage; restore "$2" ;;
  *) usage ;;
esac
