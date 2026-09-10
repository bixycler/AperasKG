# CLI Packaging — Design <a name='id/BlockNode:00CDDVBXH8001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CDDVBXHG000' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CDDVBXHG002' class='aperas-anchor aperas-id'></a> [Motivation and the options considered](../discussion/cli-packaging.md#id/BlockNode:00CDDVC33G006) — why this needs packaging, and why a single dispatcher over many bins.
- **Issues**: <a name='id/BlockNode:00CDDVBXHG003' class='aperas-anchor aperas-id'></a> [Open gaps a real install exposes](../issues/cli-packaging.md#id/BlockNode:00CDDVC8N0002).
- **History**: <a name='id/BlockNode:00CDDVBXHG004' class='aperas-anchor aperas-id'></a> [Planning — nothing shipped yet](../history/cli-packaging.md#id/BlockNode:00CDDVCKCG002).

## Architecture <a name='id/BlockNode:00CDDVBXHG005' class='aperas-anchor aperas-id'></a>

The published CLI is a single `aperas` binary that argv-dispatches to a subcommand per verb (`aperas ingest`, `aperas tree`, `aperas unfold`, ...), reusing each command's existing `run*` function and `request()` call against the shared ApeironNgn service — only the argv-parsing/help-printing glue currently duplicated per-file collapses into one router.
