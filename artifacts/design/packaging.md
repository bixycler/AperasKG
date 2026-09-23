---
description: The single `aperas` binary as a thin dispatcher over the shared `core` engine, and the three-package (`core`/`cli`/`web`) workspace split behind it.
---

# Packaging — Design <a name='id/BlockNode:00CDDVBXH8001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CDDVBXHG000' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CDDVBXHG002' class='aperas-anchor aperas-id'></a> [Motivation and the options considered](../discussion/packaging.md#id/BlockNode:00CDDVC33G006) — why this needs packaging, and why a single dispatcher over many bins.
- **Issues**: <a name='id/BlockNode:00CDDVBXHG003' class='aperas-anchor aperas-id'></a> [Open gaps a real install exposes](../issues/packaging.md#id/BlockNode:00CDDVC8N0002).
- **History**: <a name='id/BlockNode:00CDDVBXHG004' class='aperas-anchor aperas-id'></a> [Planning — nothing shipped yet](../history/packaging.md#id/BlockNode:00CDDVCKCG002).

## Architecture <a name='id/BlockNode:00CDDVBXHG005' class='aperas-anchor aperas-id'></a>

The published CLI is a single `aperas` binary that argv-dispatches to a subcommand per verb (`aperas ingest`, `aperas tree`, `aperas unfold`, ...), reusing each command's existing `run*` function and `request()` call against the shared ApeironNgn service — only the argv-parsing/help-printing glue currently duplicated per-file collapses into one router. That dispatcher lives in its own package (`packages/cli`), never merged with the graph engine it drives (`packages/core`): the same engine a CLI invocation loads in-process today is what a future UI (`packages/web`) would embed directly, with no CLI layer in between. See [Topology](#id/BlockNode:00CDGTZHSR001) for the concrete package boundaries this implies.

## Topology <a name='id/BlockNode:00CDGTZHSR001' class='aperas-anchor aperas-id'></a>

An npm workspace under a renamed root (`Aperas/monorepo/`, replacing `Aperas/web/` — a directory called "web" stopped meaning "the frontend" once it also housed the whole engine and CLI), three packages:

- `packages/core` — the ApeironNgn engine and markdown parsing: <a name='id/BlockNode:00CDGTZHSR002' class='aperas-anchor aperas-id'></a> `apeironNgn/*` (everything except the service/RPC layer, which is CLI-scoped — see below), `astParser.ts`, `reconcile.ts`, `props.ts`, `project.ts`, `snowflake.ts`, `leadingPart.ts`, `nodeRef.ts`, `lineReader.ts`, `folders.ts`, `artifacts.ts`. No process/argv/RPC concerns.
- `packages/cli` — every `kgX.ts` command, `kgHelp.ts`, the service/RPC layer (`apeironNgn/service.ts`, `serviceClient.ts`, `serviceLock.ts`, `serviceProtocol.ts`, `apeironNgn/codeVersion.ts` — moving here since the service exists purely to let many short-lived CLI processes share one warm graph, a CLI concern, not a core one), `apeironNgnSmokeTest.ts`, and `verify.ts` (the end-to-end test harness — it calls `kgX.ts`'s own `run*` functions directly, so it depends on both core and cli and can't live in core without core depending back on cli). Depends on `core`.
- `packages/web` — the Solid/Vite app, stripped to a placeholder (its current content is 100% unmodified scaffold, never built out). Depends on `core`.

Cross-package imports go through each package's own `exports` map (`"./*": "./src/*.ts"`), not relative dot-paths — `import ... from '@aperas/core/apeironNgn/node'` instead of `'../apeironNgn/node'` — resolved by npm workspace symlinking, the same subpath shape the code already uses today, so the rewrite is a mechanical prefix swap, not a redesign. Root `package.json` keeps the existing `kg:*` script names (pointing at their new `packages/cli/src/...` locations) so the dogfooding workflow (`npm run kg:X -- <args>`, now run from `Aperas/monorepo/`) is unchanged in shape. Two unused dependencies (`terminusdb`, `rehype-stringify`/`remark-rehype` — confirmed zero references anywhere in `src/`) are dropped rather than assigned to any package.

## Configuration <a name='id/BlockNode:00CDHSJQE8001' class='aperas-anchor aperas-id'></a>

Two separate config files, not one — different lifecycles, never mixed:

- `identity.json` — machine-local, never committed. Lives at `$XDG_CONFIG_HOME/aperas/identity.json`, falling back to `~/.config/aperas/identity.json` when that variable is unset — the same place any other CLI tool's machine-local preferences go. Holds `machineNumber` (replacing the env-var-only `APERAS_MACHINE_NUMBER`), which must differ across machines by construction; a shared/committed home for it would make every clone inherit the same number and silently collide on generated ids.
- `aperas.config.json` — shared, committed, sits at a graph's own root: <a name='id/BlockNode:00CDHSJQEG001' class='aperas-anchor aperas-id'></a> the directory directly containing that graph's `artifacts/` and `Apeiron/` (for this repo, `AperasKG/aperas.config.json`). Describes that graph's place in a tree (corp > teams > members, each mergeable into its parent). Its `graph` field takes either shape: a plain path (shorthand — both `artifacts/` and `Apeiron/` co-located directly under it) or `{ "apeiron": "<path>", "artifacts": "<path>" }` (two independently-specifiable roots, for a graph whose data and markdown tree aren't co-located, which is what this repo's own config actually uses). `parent`: a path/url to the graph above, or absent for a root graph. `name`: an optional human-readable display name for the graph, surfaced in host UIs — the webapp reads it via `resolveEffectiveGraphName()` (`graphConfig.ts`) for its `<h1>` and page title (`<name> | Aperas`). Discovered the way `git` finds `.git` — walking up from a starting directory, nearest file wins — so a member's own graph is found before its team's, a team's before its corp's.

Both replace `getArtifactsDir()`'s original `__dirname`-relative hop-counting (correct only for "the CLI's own source sits a fixed number of directories below the one graph it drives" — never true for an installed CLI, and not expressive enough for a tree of graphs regardless); a config-free checkout (no `aperas.config.json` found anywhere above the starting directory) falls back to that same hop-counted path unmigrated, so this repo's own dev setup keeps working either way. See [discussion](../discussion/packaging.md#id/BlockNode:00CDHSCK8R001).

## Workflow <a name='id/BlockNode:00CDY7PGG0001' class='aperas-anchor aperas-id'></a>

The shared ApeironNgn service holds exactly one graph for its whole lifetime, chosen once and deliberately rather than inherited from whichever command happens to run first:

- `aperas service start` is the only command that ever reads `process.cwd()`. It resolves the graph's Apeiron root and artifacts root from there (`aperas.config.json` discovery, or the fallback — see [Configuration](#id/BlockNode:00CDHSJQE8001)), sets both as environment variables on a freshly-spawned service, and binds it for that process's life; already running, it reports the existing binding instead of starting a second one.
- Every other command connects to whatever's already running, at a fixed location (`$XDG_RUNTIME_DIR/aperas`, falling back to a uid-namespaced path under the OS temp directory when unset) — never derived from cwd or from where the code itself is installed. Nothing running? It errors ("no service running — run `aperas service start`") rather than silently starting one bound to an accidental cwd.
- `aperas service stop` gracefully stops whatever's running (same SIGTERM-and-wait as the first half of `restart` below) without starting a replacement — the explicit counterpart to finding its pid and killing it by hand.
- `aperas service restart` stops whatever's running and re-resolves + rebinds from wherever *that* invocation's own cwd is — the only way to both pick up a source-code change and move the service to a different graph.
- Deliberately no concurrency: <a name='id/BlockNode:00CDY7T620001' class='aperas-anchor aperas-id'></a> one active graph system-wide at a time. Working across two graphs means explicitly restarting when switching, never two service processes side by side.

See [Settled](../discussion/packaging.md#id/BlockNode:00CDWPCC3G001), [Resolved](../discussion/packaging.md#id/BlockNode:00CDXFWK3R001), and [Resolved: <a name='id/BlockNode:00CDY7T620002' class='aperas-anchor aperas-id'></a> two-path config](../discussion/packaging.md#id/BlockNode:00CDZM30JG001) for how this was arrived at and verified.

## Distribution <a name='id/BlockNode:00CDW3R42G001' class='aperas-anchor aperas-id'></a>

Publishing is a separate build step, not a second mode of the dev workspace's own `package.json`/`exports` (see [discussion](../discussion/packaging.md#id/BlockNode:00CDHJGZV0001)): `esbuild` bundles `packages/cli/src/aperas.ts` (pulling in `core` transitively) into one output file, `oxigraph` marked `--external` since it's WASM-backed and can't be inlined, with a `#!/usr/bin/env node` banner. The build also writes its own minimal `package.json` alongside the bundle — `name`/`version` synced from source, `bin` pointing at the bundle, `oxigraph` (and any other external) listed as a real `dependencies` entry — making the build output a self-contained publishable unit, never touching `packages/cli/package.json`'s own dev-mode `exports` (which keeps pointing at `.ts` source for the workspace, unaffected).
