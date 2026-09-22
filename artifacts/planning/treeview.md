---
description: The now-done fix list for treeview's real gaps: stale `unfolds` tracking, a mutating bare `unfold`, no raw inspection command, plus two relocated parser bugs.
---

# TreeView — Planning <a name='id/BlockNode:00CE1GW7CG001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CE1GW7CG002' class='aperas-anchor aperas-id'></a>

Fix the treeview-specific gaps and the two relocated ingest/parser gaps together, since they were bundled by direct instruction rather than filed separately. No particular cross-dependency between them — order by whichever's simplest to verify in isolation.

## Task Breakdown <a name='id/BlockNode:00CE1GW7CG003' class='aperas-anchor aperas-id'></a>

- [x] `TreeView.unfolds` staleness: <a name='id/BlockNode:00CE1GW7CG005' class='aperas-anchor aperas-id'></a> Done. `pruneStaleUnfolds` (`node.ts`) sweeps every `TreeView`'s `unfolds` list at the same explicit-sweep points as `pruneUnreachableTombstones`, stripping any entry with no quads at all; `TreeView.unfold(ref)` refuses (no-op) a nonexistent ref at write time too. The corpus's live `.state/TreeView.jsonld` was already clean of stale ids by the time the sweep landed — no manual cleanup needed — see [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638004).
- [x] Bare `aperas unfold <ref>` (no `--view` at all): <a name='id/BlockNode:00CE1GW7CG006' class='aperas-anchor aperas-id'></a> Done. `kgUnfold.ts` distinguishes the flag's outright absence (peek — no `view.unfold(id)`, no default-view bootstrap) from `--view` present with no name following it (unchanged bootstrap-and-mutate default). Verified live: a bare unfold on an already-unfolded ref left the default view's `unfolds` count unchanged, `--view default` on a fresh ref still grew it — see [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638005).
- [x] `aperas show <ref>`: <a name='id/BlockNode:00CE1GW7CG007' class='aperas-anchor aperas-id'></a> Done. `kgShow.ts` resolves the normal deep-path way, then prints the node's exact stored fields via `dehydrate.ts`'s own exported `serializeDoc` — the identical per-kind shape walk that writes the on-disk mirror. `--text` prints only the raw `text` field, undecorated, for a byte-identical round-trip back into `kg:update` — see [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638006).
- [x] Fix the GFM task-list round-trip bug (parser/serializer, likely `astParser.ts`'s task-list handling). Done — see [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638007) (Resolved).
- [x] Fix `List` not being consumed by a preceding `Heading` the way a single paragraph already is. Done — see [Issues](../issues/treeview.md#id/BlockNode:00CE1GW638008) (Resolved).
- [x] Hide tombstoned nodes from `kg:tree`/`kg:unfold` by default, tagged `(tombstoned)` only via `--tombstoned`: <a name='id/BlockNode:00CGM6MJER001' class='aperas-anchor aperas-id'></a> Done. `TreeOptions.showTombstoned` gates every renderer. Not originally in this Task Breakdown — added once `kg:unfold`'s own tombstone-marker gap ([Issues](../issues/treeview.md#id/BlockNode:00CE8T6W7G001)) was reviewed and found to have a proposed direction but no tracked plan item.
- [x] Fix `aperas update` re-deriving an `ArtifactNode` target's own title from pushed text: <a name='id/BlockNode:00CGM6MJF0000' class='aperas-anchor aperas-id'></a> Done — found auditing this batch's own leading-summary-text edits, corrupting `issues/core.md`'s and `issues/linking.md`'s own path resolution. See [Issues](../issues/core.md#id/BlockNode:00CGM54FX0001) for the full account; not originally scoped to this plan, but the same tombstone/title-integrity family as the rest of it.

## Verification Plan <a name='id/BlockNode:00CE1GW7CG00A' class='aperas-anchor aperas-id'></a>

Each fix verified the same way prior `apeironNgn` fixes in this corpus have been: a direct `BlockNode.jsonld`/`ArtifactNode.jsonld` read confirming the exact stored state, not just a command's own summary line, plus (where applicable) a round-trip check via `aperas project --dry-run` against real content exercising the fixed case.
