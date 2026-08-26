#!/usr/bin/env bash
# Cross-branch document diff: compares every document of the given type(s) between the
# local branch and a fetched remote-tracking branch.
#
# `terminusdb diff --before-commit/--after-commit` only resolves commit refs within a
# single branch's own history — passing a remote-tracking commit while DB_SPEC points at
# local main (or vice versa) fails with NotValidRefError (confirmed live, both
# directions). This works around that by comparing document snapshots directly (the
# --before/--after raw-JSON form of `diff`, which isn't branch-scoped) instead of commits.
#
# Usage:
#   tdb-cross-diff.sh --remote NAME [--branch NAME] [--type TYPE ...] \
#                      [--user U --password P | --token T]
#
#   --remote NAME       remote to fetch and compare against (required)
#   --branch NAME       remote branch to compare (default: main)
#   --type TYPE         document type to compare; repeatable (default: ArtifactNode
#                        DocumentNode BlockNode SpanNode TripleAssertion)
#   --user/--password   forwarded to `fetch` for remote auth
#   --token             forwarded to `fetch` for remote auth (alternative to user/password)
#
# Prints, per type with any difference: doc ids only on the local side, doc ids only on
# the remote side, and a field-level diff for doc ids present on both sides whose content
# differs.
set -euo pipefail

CONTAINER="${TERMINUSDB_CONTAINER:-terminusdb}"
DB_SPEC="${TERMINUSDB_DB_SPEC:-admin/aperas_apeiron}"
TDB_BIN="/app/terminusdb/terminusdb"

remote=""
branch="main"
types=()
auth_args=()

usage() {
  echo "Usage: $0 --remote NAME [--branch NAME] [--type TYPE ...] [--user U --password P | --token T]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --remote) remote="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --type) types+=("$2"); shift 2 ;;
    --user) auth_args+=(--user="$2"); shift 2 ;;
    --password) auth_args+=(--password="$2"); shift 2 ;;
    --token) auth_args+=(--token="$2"); shift 2 ;;
    *) usage ;;
  esac
done

[ -z "$remote" ] && usage
[ "${#types[@]}" -eq 0 ] && types=(ArtifactNode DocumentNode BlockNode SpanNode TripleAssertion)

echo "Fetching '$remote'..." >&2
docker exec "$CONTAINER" "$TDB_BIN" fetch "$DB_SPEC" --remote="$remote" "${auth_args[@]}" >&2

remote_spec="$DB_SPEC/$remote/branch/$branch"

# `doc get` streams concatenated JSON objects (no enclosing array, no commas) -- jq parses
# consecutive top-level values natively, so `-s` (slurp) turns that stream into one array
# we can reduce into an @id-keyed map for set comparison against the other side.
docs_by_id() {
  local spec="$1" type="$2"
  docker exec "$CONTAINER" "$TDB_BIN" doc get "$spec" --type="$type" --count -1 2>/dev/null \
    | jq -sc 'reduce .[] as $d ({}; .[$d["@id"]] = $d)'
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

for type in "${types[@]}"; do
  local_file="$tmpdir/local.json"
  remote_file="$tmpdir/remote.json"
  docs_by_id "$DB_SPEC" "$type" > "$local_file"
  docs_by_id "$remote_spec" "$type" > "$remote_file"

  # Files, not --argjson: an --argjson map for a doc-heavy type (e.g. BlockNode) hits the
  # same ARG_MAX wall as the inline diff below -- --slurpfile reads from disk instead.
  only_local="$(jq -nc --slurpfile l "$local_file" --slurpfile r "$remote_file" '($l[0]|keys) - ($r[0]|keys)')"
  only_remote="$(jq -nc --slurpfile l "$local_file" --slurpfile r "$remote_file" '($r[0]|keys) - ($l[0]|keys)')"
  changed="$(jq -nc --slurpfile l "$local_file" --slurpfile r "$remote_file" \
    '($l[0]) as $l | ($r[0]) as $r
     | (($l|keys) as $lk | ($r|keys) as $rk | $lk - ($lk - $rk)) as $shared
     | [$shared[] | select($l[.] != $r[.])]')"

  # docs_by_id already wrote the reduced @id-keyed map to each file -- reuse as-is.
  local_map="$(cat "$local_file")"
  remote_map="$(cat "$remote_file")"

  [ "$only_local" = "[]" ] && [ "$only_remote" = "[]" ] && [ "$changed" = "[]" ] && continue

  echo "=== $type ==="
  [ "$only_local" != "[]" ] && echo "  only on local:      $(echo "$only_local" | jq -r 'join(", ")')"
  [ "$only_remote" != "[]" ] && echo "  only on '$remote':  $(echo "$only_remote" | jq -r 'join(", ")')"

  echo "$changed" | jq -r '.[]' | while IFS= read -r id; do
    [ -z "$id" ] && continue
    echo "  --- $id ---"
    before="$(echo "$remote_map" | jq -c --arg id "$id" '.[$id]')"
    after="$(echo "$local_map" | jq -c --arg id "$id" '.[$id]')"
    # `diff --before/--after` takes JSON only as inline CLI args (no file/stdin form) --
    # large docs (e.g. a DocumentNode's full rawMarkdown) can blow past ARG_MAX, so skip
    # the inline diff above a safe size and point at the two sides instead.
    if [ $((${#before} + ${#after})) -gt 100000 ]; then
      echo "    content differs (${#before} + ${#after} bytes -- too large to diff inline)"
      echo "    inspect via: ./db/tdb-doc.sh --id=\"$id\"  (local)"
      echo "             and: TERMINUSDB_DB_SPEC=\"$remote_spec\" ./db/tdb-doc.sh --id=\"$id\"  ('$remote')"
    else
      docker exec "$CONTAINER" "$TDB_BIN" diff --before="$before" --after="$after" 2>/dev/null | jq .
    fi
  done
done
