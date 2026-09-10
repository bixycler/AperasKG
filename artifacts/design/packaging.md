# Packaging — Design <a name='id/BlockNode:00CDDVBXH8001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CDDVBXHG000' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CDDVBXHG002' class='aperas-anchor aperas-id'></a> [Motivation and the options considered](../discussion/packaging.md#id/BlockNode:00CDDVC33G006) — why this needs packaging, and why a single dispatcher over many bins.
- **Issues**: <a name='id/BlockNode:00CDDVBXHG003' class='aperas-anchor aperas-id'></a> [Open gaps a real install exposes](../issues/packaging.md#id/BlockNode:00CDDVC8N0002).
- **History**: <a name='id/BlockNode:00CDDVBXHG004' class='aperas-anchor aperas-id'></a> [Planning — nothing shipped yet](../history/packaging.md#id/BlockNode:00CDDVCKCG002).

## Architecture <a name='id/BlockNode:00CDDVBXHG005' class='aperas-anchor aperas-id'></a>

The published CLI is a single `aperas` binary that argv-dispatches to a subcommand per verb (`aperas ingest`, `aperas tree`, `aperas unfold`, ...), reusing each command's existing `run*` function and `request()` call against the shared ApeironNgn service — only the argv-parsing/help-printing glue currently duplicated per-file collapses into one router.

## Workspace Split <a name='id/BlockNode:00CDGTZHSR001' class='aperas-anchor aperas-id'></a>

An npm workspace under a renamed root (`Aperas/monorepo/`, replacing `Aperas/web/` — a directory called "web" stopped meaning "the frontend" once it also housed the whole engine and CLI), three packages:

- `packages/core` — the ApeironNgn engine and markdown parsing: <a name='id/BlockNode:00CDGTZHSR002' class='aperas-anchor aperas-id'></a> `apeironNgn/*` (everything except the service/RPC layer, which is CLI-scoped — see below), `astParser.ts`, `reconcile.ts`, `props.ts`, `project.ts`, `snowflake.ts`, `leadingPart.ts`, `nodeRef.ts`, `lineReader.ts`, `folders.ts`, `artifacts.ts`. No process/argv/RPC concerns.
- `packages/cli` — every `kgX.ts` command, `kgHelp.ts`, the service/RPC layer (`apeironNgn/service.ts`, `serviceClient.ts`, `serviceLock.ts`, `serviceProtocol.ts`, `apeironNgn/codeVersion.ts` — moving here since the service exists purely to let many short-lived CLI processes share one warm graph, a CLI concern, not a core one), `apeironNgnSmokeTest.ts`, and `verify.ts` (the end-to-end test harness — it calls `kgX.ts`'s own `run*` functions directly, so it depends on both core and cli and can't live in core without core depending back on cli). Depends on `core`.
- `packages/web` — the Solid/Vite app, stripped to a placeholder (its current content is 100% unmodified scaffold, never built out). Depends on `core`.

Cross-package imports go through each package's own `exports` map (`"./*": "./src/*.ts"`), not relative dot-paths — `import ... from '@aperas/core/apeironNgn/node'` instead of `'../apeironNgn/node'` — resolved by npm workspace symlinking, the same subpath shape the code already uses today, so the rewrite is a mechanical prefix swap, not a redesign. Root `package.json` keeps the existing `kg:*` script names (pointing at their new `packages/cli/src/...` locations) so the dogfooding workflow (`npm run kg:X -- <args>`, now run from `Aperas/monorepo/`) is unchanged in shape. Two unused dependencies (`terminusdb`, `rehype-stringify`/`remark-rehype` — confirmed zero references anywhere in `src/`) are dropped rather than assigned to any package.
