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

Cross-package imports go through each package's own `exports` map (`"./*": "./src/*.ts"`), not relative dot-paths — `import ... from '@aperas/core/apeironNgn/node'` instead of `'../apeironNgn/node'` — resolved by npm workspace symlinking, the same subpath shape the code already uses today, so the rewrite is a mechanical prefix swap, not a redesign. Root `package.json` no longer carries the old `kg:*` script names: once the `aperas` dispatcher (see [Architecture](#id/BlockNode:00CDDVBXHG005)) covered every verb through the same `run*`/`request()` calls the old scripts used, `npm run kg:X -- <args>` and `npm run aperas -- X <args>` were doing identical work, so the older aliases were dropped rather than kept indefinitely. The dogfooding workflow is `npm run aperas -- <verb> <args>` in a source checkout and the built `aperas <verb>` once installed — one command surface in dev and in production, not two. Two unused dependencies (`terminusdb`, `rehype-stringify`/`remark-rehype` — confirmed zero references anywhere in `src/`) are dropped rather than assigned to any package.

## Configuration <a name='id/BlockNode:00CDHSJQE8001' class='aperas-anchor aperas-id'></a>

Two separate config files, not one — different lifecycles, never mixed:

- `identity.json` — machine-local, never committed. Lives at `$XDG_CONFIG_HOME/aperas/identity.json`, falling back to `~/.config/aperas/identity.json` when that variable is unset — the same place any other CLI tool's machine-local preferences go. Holds `machineNumber` (replacing the env-var-only `APERAS_MACHINE_NUMBER`), which must differ across machines by construction; a shared/committed home for it would make every clone inherit the same number and silently collide on generated ids.
- `aperas.config.json` — shared, committed, sits at a graph's own root: <a name='id/BlockNode:00CDHSJQEG001' class='aperas-anchor aperas-id'></a> the directory directly containing that graph's `artifacts/` and `Apeiron/` (for this repo, `AperasKG/aperas.config.json`). Describes that graph's place in a tree (corp > teams > members, each mergeable into its parent). Its `graph` field takes either shape: a plain path (shorthand — both `artifacts/` and `Apeiron/` co-located directly under it) or `{ "apeiron": "<path>", "artifacts": "<path>" }` (two independently-specifiable roots, for a graph whose data and markdown tree aren't co-located, which is what this repo's own config actually uses). `parent`: a path/url to the graph above, or absent for a root graph. `name`: an optional human-readable display name for the graph, surfaced in host UIs — the webapp reads it via `resolveEffectiveGraphName()` (`graphConfig.ts`) for its `<h1>` and page title (`<name> | Aperas`). Discovered the way `git` finds `.git` — walking up from a starting directory, nearest file wins — so a member's own graph is found before its team's, a team's before its corp's.
- `aperas init` bootstraps a brand-new graph in the current directory: <a name='id/BlockNode:00CP9QMPWR001' class='aperas-anchor aperas-id'></a> creates `aperas.config.json`, an empty `Apeiron/` store (`BlockNode`/`ArtifactNode`/`FolderNode`/`Profile` `.jsonld`, each `[]`), and an `artifacts/` tree — refusing if a config already exists here, never overwriting an existing `.jsonld` file. Without it, `rehydrateStore` (`store.ts`) treats a missing instance file as a real `ENOENT` rather than an empty graph, and the service crashes on startup — which `aperas serve`/`aperas service start` can only report as a generic "did not become ready in time", giving no hint that the real problem is a directory that was never initialized. Found live installing the published package into a fresh project with no `Apeiron/` at all.

Both replace `getArtifactsDir()`'s original `__dirname`-relative hop-counting (correct only for "the CLI's own source sits a fixed number of directories below the one graph it drives" — never true for an installed CLI, and not expressive enough for a tree of graphs regardless); a config-free checkout (no `aperas.config.json` found anywhere above the starting directory) falls back to that same hop-counted path unmigrated, so this repo's own dev setup keeps working either way. See [discussion](../discussion/packaging.md#id/BlockNode:00CDHSCK8R001).

## Workflow <a name='id/BlockNode:00CDY7PGG0001' class='aperas-anchor aperas-id'></a>

The shared ApeironNgn service holds exactly one graph for its whole lifetime, chosen once and deliberately rather than inherited from whichever command happens to run first:

- `aperas service start` is the only command that ever reads `process.cwd()`. It resolves the graph's Apeiron root and artifacts root from there (`aperas.config.json` discovery, or the fallback — see [Configuration](#id/BlockNode:00CDHSJQE8001)), sets both as environment variables on a freshly-spawned service, and binds it for that process's life; already running, it reports the existing binding instead of starting a second one.
- Every other command connects to whatever's already running, at a fixed location (`$XDG_RUNTIME_DIR/aperas`, falling back to a uid-namespaced path under the OS temp directory when unset) — never derived from cwd or from where the code itself is installed. Nothing running? It errors ("no service running — run `aperas service start`") rather than silently starting one bound to an accidental cwd.
- `aperas service stop` gracefully stops whatever's running (same SIGTERM-and-wait as the first half of `restart` below) without starting a replacement — the explicit counterpart to finding its pid and killing it by hand.
- `aperas service restart` stops whatever's running and re-resolves + rebinds from wherever *that* invocation's own cwd is — the only way to both pick up a source-code change and move the service to a different graph.
- Deliberately no concurrency: <a name='id/BlockNode:00CDY7T620001' class='aperas-anchor aperas-id'></a> one active graph system-wide at a time. Working across two graphs means explicitly restarting when switching, never two service processes side by side.

See [Settled](../discussion/packaging.md#id/BlockNode:00CDWPCC3G001), [Resolved](../discussion/packaging.md#id/BlockNode:00CDXFWK3R001), and [Resolved: <a name='id/BlockNode:00CDY7T620002' class='aperas-anchor aperas-id'></a> two-path config](../discussion/packaging.md#id/BlockNode:00CDZM30JG001) for how this was arrived at and verified.

## Dev environment setup <a name='id/BlockNode:00CVJH6930001' class='aperas-anchor aperas-id'></a>

Developing Aperas from source means running the live TypeScript, not the published bundle. Inside `Aperas/monorepo/` that is `npm run aperas -- <verb> <args>` (see [Topology](#id/BlockNode:00CDGTZHSR001)); a global shim makes bare `aperas <verb> <args>` do the same from any directory, so a session whose working directory is a different project, or an agent harness that does not start in `monorepo/`, still drives the checkout's current source rather than whatever `npm install -g aperas` last installed.

The shim is a three-line shell script, `~/.local/bin/aperas`: <a name='id/BlockNode:00CVJH6930002' class='aperas-anchor aperas-id'></a>

```sh
#!/bin/sh
cd /home/will/source/Aperas/monorepo && exec env -u LD_LIBRARY_PATH node_modules/.bin/tsx packages/cli/src/aperas.ts "$@"
```

Replace the path with the checkout's own `monorepo/` directory. Each part has a job:

- `cd <checkout>/monorepo` — `node_modules/.bin/tsx` and `packages/cli/src/aperas.ts` are relative paths into the workspace, so the shim has to stand in `monorepo/` before it can run either. It also fixes what `process.cwd()` means for the one command that reads it: `aperas service start` resolves its graph from there (see [Workflow](#id/BlockNode:00CDY7PGG0001)), so a service started through the shim always binds to this checkout's graph, whichever directory the shim was called from.
- `exec` — replaces the shell with the node process instead of running it as a child, so stdin (the `insert`/`update` verbs read piped markdown), signals, and the exit status all pass straight through.
- `env -u LD_LIBRARY_PATH` — unsets `LD_LIBRARY_PATH` for the node process only. Some hosts (Opcode, for one) export a path to their own bundled libraries, which node picks up in place of the system's and fails at startup with an OpenSSL error that looks like a broken install but is not one. Unsetting it costs nothing where it was never set.
- `node_modules/.bin/tsx packages/cli/src/aperas.ts` — runs the CLI entry point's TypeScript source directly through the workspace's own `tsx`, so there is no build step and every edit to `core` or `cli` is live on the next call. A service already running holds the code it started with, so pick up an engine change with `aperas service restart`.
- `"$@"` — forwards every argument unchanged, quoted so arguments containing spaces or shell metacharacters arrive intact.

To install it: <a name='id/BlockNode:00CVJH6938007' class='aperas-anchor aperas-id'></a>

1. Create the directory if it is missing and write the script: `mkdir -p ~/.local/bin`, then save the three lines above as `~/.local/bin/aperas`.
2. Mark it executable: <a name='id/BlockNode:00CVJH6938009' class='aperas-anchor aperas-id'></a> `chmod +x ~/.local/bin/aperas`.
3. Make sure `~/.local/bin` is on `PATH`. Most login shells add it when the directory exists; an environment that sets its own minimal `PATH` (for example `/usr/local/bin:/usr/bin:/bin`) will not find the shim, and needs the directory added or the shim placed in a directory already on its `PATH`.
4. Dependencies must be installed in the workspace once (`npm install` in `monorepo/`), since the shim relies on its `node_modules/.bin/tsx`.

A one-command check that it works from anywhere: <a name='id/BlockNode:00CVJH693800C' class='aperas-anchor aperas-id'></a>

```sh
cd /tmp && aperas profile list claude
```

It prints the profile's views from the source checkout. `aperas --help` from any directory confirms only that the shim launches, not that the graph is reachable.

## Distribution <a name='id/BlockNode:00CDW3R42G001' class='aperas-anchor aperas-id'></a>

Publishing is a separate build step, not a second mode of the dev workspace's own `package.json`/`exports` (see [discussion](../discussion/packaging.md#id/BlockNode:00CDHJGZV0001)): `esbuild` bundles `packages/cli/src/aperas.ts` (pulling in `core` transitively) into one output file, `oxigraph` marked `--external` since it's WASM-backed and can't be inlined, with a `#!/usr/bin/env node` banner. The build also writes its own minimal `package.json` alongside the bundle — `name`/`version` synced from source, `bin` pointing at the bundle, `oxigraph` (and any other external) listed as a real `dependencies` entry — making the build output a self-contained publishable unit, never touching `packages/cli/package.json`'s own dev-mode `exports` (which keeps pointing at `.ts` source for the workspace, unaffected).

`aperas` shipped for real: <a name='id/BlockNode:00CP9QR9PG001' class='aperas-anchor aperas-id'></a> published on the public npm registry (`0.1.2` through `0.2.2`, `npm publish` from `packages/cli/dist/`) — anyone can `npm install -g aperas` today, not just build the bundle locally. Versioning follows its own scheme rather than semver-as-changelog: the middle number is a linear development-phase counter, independent of any other "Phase N" naming used elsewhere in this project, and the last is a build number within that phase — `0.2.1` is phase 2's first published build, `0.2.2` its second. `0.1.2` predates the scheme.

The published package also carries this project's own two end-user-facing skills (`skills/aperas`, `skills/kg-doc-ingest` — this repo's other, dev-only skills are never bundled) copied into `dist/skills/` by the same build step, plus a new `aperas skill install` command (`kgSkill.ts`) that copies them into an agent's `.claude/skills/` (or `~/.claude/skills/` with `--global`). Without this, an agent working against an installed `aperas` binary has the CLI but none of the graph-first discipline the skill encodes — found live installing `aperas` into a project with no skill counterpart at all.
