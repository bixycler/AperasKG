# Packaging — Planning <a name='id/BlockNode:00CDDVCDW8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CDDVCDW8002' class='aperas-anchor aperas-id'></a>

To be broken down once [the graph-location question](../issues/packaging.md#id/BlockNode:00CDDVC8N0002) has an answer — [the dispatcher refactor itself](../design/packaging.md#id/BlockNode:00CDDVBXHG005) doesn't depend on it, but shipping a usable package does.

## Task Breakdown <a name='id/BlockNode:00CDDVCDW8003' class='aperas-anchor aperas-id'></a>

1. Create `packages/{core,cli,web}` with their own `package.json`/`tsconfig.json`, matching the file assignment in [Workspace Split](../design/packaging.md#id/BlockNode:00CDGTZHSR001).
2. Move files via `git mv` (preserve history), rewrite cross-package imports to the `@aperas/core/...` subpath form.
3. Root `package.json`: <a name='id/BlockNode:00CDGV1RKR001' class='aperas-anchor aperas-id'></a> workspaces field, updated `kg:*` script paths, dropped dead deps.
4. Rename `Aperas/web/` -> `Aperas/monorepo/`; update `skills/kg-doc-ingest/SKILL.md`'s path references (the only other place in the repo naming this directory).
5. `npm install` at the new root (materializes workspace symlinks), `npx tsc --noEmit` in each package.
6. Smoke-test: <a name='id/BlockNode:00CDGV1RKR004' class='aperas-anchor aperas-id'></a> restart the ApeironNgn service and run a couple of real `kg:*` commands (`kg:tree`, `kg:backlinks`) from the new location against the real graph, confirm output matches pre-split.

## Verification Plan <a name='id/BlockNode:00CDDVCDW8004' class='aperas-anchor aperas-id'></a>
