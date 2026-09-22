---
description: No open issues — every packaging gap (build step, graph discovery, artifact rename) is resolved.
---

# Packaging — Issues <a name='id/BlockNode:00CDDVC8N0001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CDDVC8N0002' class='aperas-anchor aperas-id'></a>

None.

## Pending Tasks <a name='id/BlockNode:00CDDVC8N0006' class='aperas-anchor aperas-id'></a>

None.

## Resolved <a name='id/BlockNode:00CDDVC8N0007' class='aperas-anchor aperas-id'></a>

- Each command's own `--help` usage line (and its missing-required-arg fallback) now prints `aperas <verb>` instead of `kg:X --` — rewritten across all 18 `kgX.ts` files.
- `aperas` builds to a real `bin`: <a name='id/BlockNode:00CDWQ0V88003' class='aperas-anchor aperas-id'></a> `packages/cli/build.mjs` (`esbuild`, `oxigraph` external) produces a self-contained `packages/cli/dist/` (bundle + minimal `package.json` with a `bin` entry). Verified running standalone via plain `node`, no `tsx`, against the real graph — see [discussion](../discussion/packaging.md#id/BlockNode:00CDWP69B8001).

- Shipped the explicit-start service redesign: <a name='id/BlockNode:00CDXG7H30002' class='aperas-anchor aperas-id'></a> `ensureServiceRunning()` errors instead of auto-spawning; `aperas service start`/`stop`/`restart` (`kgService.ts`) are now the only places that read `process.cwd()` to resolve+bind the graph (`stop` doesn't itself read cwd, but completes the trio alongside the two that do); the lock/socket moved to a fixed `$XDG_RUNTIME_DIR`-based location, independent of both cwd and code install path. Verified live in both dev and built-bundle modes — see [discussion](../discussion/packaging.md#id/BlockNode:00CDXFWK3R001).

- `kg:show <ref>` — relocated, not implemented: <a name='id/BlockNode:00CDY7A3P0002' class='aperas-anchor aperas-id'></a> on reflection this is a TreeView/node-rendering gap, not a packaging one, so it moved to `AperasKG/artifacts/archive/Aperas-treeview-design.md` §16, to be picked up when that document itself gets migrated into the graph — see [discussion](../discussion/packaging.md#id/BlockNode:00CDWB1Y6R001) for the original write-up of the gap.

- Closed the client-side graph-root gap: <a name='id/BlockNode:00CDZQJVG8002' class='aperas-anchor aperas-id'></a> `aperas.config.json`'s `graph` field now takes either a plain path (shorthand) or `{ "apeiron": "...", "artifacts": "..." }` (independent roots); `resolveEffectiveApeironRoot()`/`resolveEffectiveArtifactsRoot()` (`graphConfig.ts`) each check their own env var (`APERAS_APEIRON_ROOT`/`APERAS_ARTIFACTS_ROOT`, set by `aperas service start`/`restart`) before config discovery/the fallback. `getArtifactsDir()`'s existing callers — `runTrack`/`runIngest`/`runProject` and the shared `apeironNgn/artifacts.ts`/`folders.ts`/`node.ts` helpers — needed no signature changes at all. Verified live: cold-started the built bundle from a cwd deep inside `AperasKG/`, confirmed the lock recorded the real (non-fallback) discovered paths for both roots, then ran `aperas project` from an unrelated cwd (`monorepo/`) and confirmed it read and wrote against the correctly-bound `artifacts/` — see [discussion](../discussion/packaging.md#id/BlockNode:00CDZM30JG001).
