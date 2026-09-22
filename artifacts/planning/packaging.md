---
description: The 19-step packaging build-out, all done and verified, from the three-package workspace split through the `aperas` dispatcher.
---

# Packaging — Planning <a name='id/BlockNode:00CDDVCDW8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CDDVCDW8002' class='aperas-anchor aperas-id'></a>

Broken down below once [the graph-location question](../issues/packaging.md#id/BlockNode:00CDDVC8N0002) had an answer. All 19 numbered steps are done and verified — see [history](../history/packaging.md#id/BlockNode:00CDDVCKCG002) for the closing summary.

## Task Breakdown <a name='id/BlockNode:00CDDVCDW8003' class='aperas-anchor aperas-id'></a>

1. [x] Create `packages/{core,cli,web}` with their own `package.json`/`tsconfig.json`, matching the file assignment in [Workspace Split](../design/packaging.md#id/BlockNode:00CDGTZHSR001).
2. [x] Move files via `git mv` (preserve history), rewrite cross-package imports to the `@aperas/core/...` subpath form.
3. [x] Root `package.json`: <a name='id/BlockNode:00CDGV1RKR001' class='aperas-anchor aperas-id'></a> workspaces field, updated `kg:*` script paths, dropped dead deps.
4. [x] Rename `Aperas/web/` -> `Aperas/monorepo/`; update `skills/kg-doc-ingest/SKILL.md`'s path references (the only other place in the repo naming this directory).
5. [x] `npm install` at the new root (materializes workspace symlinks), `npx tsc --noEmit` in each package.
6. [x] Smoke-test: <a name='id/BlockNode:00CDGV1RKR004' class='aperas-anchor aperas-id'></a> restart the ApeironNgn service and run a couple of real `kg:*` commands (`kg:tree`, `kg:backlinks`) from the new location against the real graph, confirm output matches pre-split.
7. [x] Export `main` from every `kgX.ts` (leaving the existing `if (process.argv[1]?.endsWith(...)) main()` self-invocation guard untouched underneath it).
8. [x] Add `packages/cli/src/aperas.ts`: <a name='id/BlockNode:00CDH90MNG003' class='aperas-anchor aperas-id'></a> a static verb-to-module table (also doubling as the top-level `--help`/no-args listing), argv re-slicing before calling the target's `main()`, and a clean error listing valid verbs on an unrecognized one.
9. [x] Root `package.json`: <a name='id/BlockNode:00CDH90MNG004' class='aperas-anchor aperas-id'></a> add an `"aperas": "tsx packages/cli/src/aperas.ts"` script — deliberately not a real `bin`/build yet (see [the runtime question](../discussion/packaging.md#id/BlockNode:00CDDVC33G009), still open).
10. [x] Spot-check a handful of verbs through `aperas <verb>` against their `kg:<verb>` equivalent, confirm identical output.
11. [x] Re-run `npm run verify` (calls `run*` directly, so it should be unaffected either way — a regression there means something broke in a shared file, not the dispatcher).
12. [x] Add `identity.json` (machine-local, gitignored) reader/writer replacing `APERAS_MACHINE_NUMBER` env-var-only lookup in `snowflake.ts`.
13. [x] Add `aperas.config.json` discovery: <a name='id/BlockNode:00CDHSZ05G003' class='aperas-anchor aperas-id'></a> upward search from cwd, resolving `graph`/`parent` pointers; fall back to today's hop-counted `getArtifactsDir()` when none is found (so this repo's own dev setup keeps working unmigrated).
14. [x] Verify: <a name='id/BlockNode:00CDHSZ05G004' class='aperas-anchor aperas-id'></a> a config-free checkout (this repo, for now) still resolves the graph exactly as before; a synthetic nested config (a fake team/member pair of directories) resolves both levels and their `parent` link correctly.
15. [x] Build script (e.g. `packages/cli/build.mjs`): <a name='id/BlockNode:00CDW3XN08002' class='aperas-anchor aperas-id'></a> `esbuild` bundling `aperas.ts` to `packages/cli/dist/aperas.js` (`--external:oxigraph`, `#!/usr/bin/env node` banner), plus a generated minimal `dist/package.json` (`bin`, synced `name`/`version`, `oxigraph` as a real dependency) — see [Distribution](../design/packaging.md#id/BlockNode:00CDW3R42G001).
16. [x] Verify the built bundle standalone: <a name='id/BlockNode:00CDW3XN08003' class='aperas-anchor aperas-id'></a> `node packages/cli/dist/aperas.js tree --depth 1` (no `tsx`) against the real graph, confirm it matches the dev-mode dispatcher's output.
17. [x] Rewrite each `kgX.ts`'s own `printHelp({ usage: ... })` string(s) from `kg:X --` to `aperas <verb>`, dropping the npm-script-only ` --` separator that `aperas` doesn't need.
18. [x] Verify: <a name='id/BlockNode:00CDW3XN08005' class='aperas-anchor aperas-id'></a> `aperas <verb> --help` for a handful of commands now shows `aperas <verb> ...` as its usage line; the `kg:X` npm scripts (still pointing at the same files directly) are unaffected, since this only changes the printed label, not the actual argv parsing.
19. [x] **Done.** Shipped the explicit-start service redesign: <a name='id/BlockNode:00CDX7VWY0002' class='aperas-anchor aperas-id'></a> dropped auto-spawn from `ensureServiceRunning()` (errors, pointing at `aperas service start`); added `aperas service start` (binds a fresh service to the graph resolved from that invocation's own cwd) and updated `restart` to re-resolve+rebind the same way; moved the lock/socket to a fixed `$XDG_RUNTIME_DIR`-based location, independent of cwd and code install path. Verified live in dev and built-bundle modes, full `npm run verify` suite still clean — see [Resolved](../discussion/packaging.md#id/BlockNode:00CDXFWK3R001). The one gap this pass left (client-side `getArtifactsDir()` callers not honoring the bound graph root) was closed in a follow-up pass — see [Resolved: two-path graph config](../discussion/packaging.md#id/BlockNode:00CDZM30JG001).
20. [x] **Done — this Task Breakdown is complete, no open gaps.** `kg:show <ref>` (previously tracked here) turned out to be a TreeView/node-rendering gap rather than a packaging one, and moved to `AperasKG/artifacts/archive/Aperas-treeview-design.md` §16, to be picked up when that document itself gets migrated. The client-side `getArtifactsDir()` graph-root gap flagged during item 19 has since been closed too — see [history](../history/packaging.md#id/BlockNode:00CDDVCKCG002) for the closing summary.

## Verification Plan <a name='id/BlockNode:00CDDVCDW8004' class='aperas-anchor aperas-id'></a>
