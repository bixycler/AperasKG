# List Consumption — Planning <a name='id/BlockNode:00CE32GTR8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CE32GTR8002' class='aperas-anchor aperas-id'></a>

The parser change (orphan-dissolution) and the serializer change (props-on-run-leader) land together, not sequentially — shipping either alone leaves the other case silently wrong (an orphan-dissolved run with no node-level props to read, or a node-level prop read that can't tell two dissolved runs apart). The corpus migration follows once both are verified against a synthetic multi-run case, then runs against the real corpus with a full before/after diff as the gate.

## Task Breakdown <a name='id/BlockNode:00CE32GTR8003' class='aperas-anchor aperas-id'></a>

All done. `astParser.ts` normalizes props onto the run's own first item and splices orphaned lists flat; `project.ts` reads props per-run-leader and detects boundaries by type-or-own-explicit-props; both synthetic multi-run cases (separated, zero-separator) are covered in `verify.ts`; the real corpus (48 legacy anchors, 59 live `list` nodes) is migrated, verified byte-identical except one approved, understood exception (see [Issues](../issues/list-consumption.md#id/BlockNode:00CE32GRZG007)); `verify.ts`'s old hard-asserted tests are rewritten; the two `insert`-into-a-list-target gotchas are reassessed — one moot (no live `list` node left to mistakenly target), one reclassified as a general, unrelated parser-input caveat, not a list-consumption bug. A separate post-migration regression found afterward — `aperas insert` always minting a fresh run-leader prop on a lone piped bullet — is now also fixed (see [Issues](../issues/list-consumption.md#id/BlockNode:00CE32GRZG002)).

## Verification Plan <a name='id/BlockNode:00CE32GTR800A' class='aperas-anchor aperas-id'></a>

Done: every tracked artifact projected before and after the migration and diffed — byte-identical for 27 of 28, with the 28th (`issues/packaging.md`) a pre-diagnosed, user-approved exception (a chain of fully-tombstoned nested `list` wrappers whose old rendering quirk manufactured spurious blank lines; the migration correctly renders the now-fully-dead chain as truly empty). `npm run verify` passes clean against the migrated corpus, including the two synthetic multi-run cases.
