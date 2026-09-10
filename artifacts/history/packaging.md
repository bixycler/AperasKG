# Packaging — History <a name='id/BlockNode:00CDDVCKCG001' class='aperas-anchor aperas-id'></a>

## Current Status <a name='id/BlockNode:00CDDVCKCG002' class='aperas-anchor aperas-id'></a>

The rename to `packaging.md` and the 3-way workspace split (`packages/core`/`cli`/`web` under a renamed `Aperas/monorepo/` root) are both done and verified — see [Workspace Split](../design/packaging.md#id/BlockNode:00CDGTZHSR001). Still planning: the dispatcher binary itself (`aperas`), and the open packaging/graph-location questions.

## Milestones <a name='id/BlockNode:00CDDVCKCG003' class='aperas-anchor aperas-id'></a>

- Workspace split: <a name='id/BlockNode:00CDH1CNN8002' class='aperas-anchor aperas-id'></a> `packages/core`/`cli`/`web` under `Aperas/monorepo/`, all three type-check clean, full `npm run verify` harness (18 checks) passes end-to-end from the new location.
