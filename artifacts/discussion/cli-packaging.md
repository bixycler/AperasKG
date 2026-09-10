# CLI Packaging — Discussion <a name='id/BlockNode:00CDDVC338001' class='aperas-anchor aperas-id'></a>

## Resolved: anchor-drift strip, and a real trackFromDisk bug underneath it <a name='id/BlockNode:00CDEZ1A68001' class='aperas-anchor aperas-id'></a>

Added `stripInlineAnchors` (`astParser.ts`) and applied it everywhere a block's stored abstract/text gets compared against a fresh disk parse for exact equality: `extractAbstract` (before truncating, so a mid-window anchor can't survive as a mangled fragment either), `reconcile.ts`'s `leafKey` (block-level Gestalt matching), and the rename matchers' own key computation (`apeironNgn/artifacts.ts`). Verified against the two real cases that surfaced this (`design/cli.md`'s Discussion bullet, `discussion/cli.md`'s staging-practice paragraph): stripped text now round-trips exactly.

That got the batch rename to report "5 renamed" — but a direct check of the graph showed all 5 *still* duplicated. The real, deeper bug was in `ArtifactNode.trackFromDisk` (`node.ts`): its "skip if unchanged" guard compared `fileHash` alone, `this.path` never entered it. A pure rename is exactly the case where the hash *is* unchanged (nothing but the location moved) — so the guard's early return skipped the `this.path = artifactPath` write below it every time, on every rename, while still reporting `{ tracked: true }`-shaped success to its caller. `trackAllArtifacts`'s own rename path had carried this same bug the whole time; it just never surfaced because a real-world rename usually carries a content edit alongside it, which masked the hash match. Fixed: the guard now requires the path to match too, not just the hash — a rename (same hash, different path) now correctly falls through and updates `path`/`title`/`fileHash`/`lastTrackedAt`.

All three fixes together, re-verified: <a name='id/BlockNode:00CDEZ1A68003' class='aperas-anchor aperas-id'></a> batch-renaming the 5 `cli.md` docs to `cli-packaging.md` now reports "5 renamed" *and* the graph shows exactly 5 ArtifactNodes (no duplicates), each still carrying its original id and its original BlockNode children — confirmed via direct inspection, not just the summary line.

## Resolved: scoped rename detection, without a full-corpus sweep <a name='id/BlockNode:00CDEM7DVG001' class='aperas-anchor aperas-id'></a>

Added `trackArtifactsScoped` (`apeironNgn/artifacts.ts`), wired into `kg:track`/`kg:ingest`'s explicit-`<path>...` branch. It detects a rename by pairing only the paths the caller actually gave against already-tracked ArtifactNodes whose recorded path no longer exists on disk — never a directory listing, so `archive/` (or anything else not yet migrated) can't enter either side, no matter how large it gets.

First attempt reused `trackAllArtifacts`'s own `matchLeftoverByAbstract` (the Gestalt/Ratcliff-Obershelp recursion `reconcile.ts` uses everywhere else) and only matched 2 of 5 batch-renamed files — not from ambiguity, but because that algorithm is position-sensitive: it works for reconciling siblings that share a rough common order across an edit, not for an unordered bag of whole-artifact identities scattered across concern folders. A match's recursive split can discard a whole quadrant of otherwise-valid candidates just because the corresponding range on the other side is empty. Replaced with `matchByExactKey`: same "decline rather than guess" principle (a key occurring more than once on either side stays unmatched), but no positional requirement — confirmed via debug trace, then verified live (4 of 5 correctly renamed, identity preserved).

**Left open, a distinct bug:** the 5th case still doesn't match, and a separate block-level reconciliation surfaced the same shape of problem — an ArtifactNode's (or BlockNode's) cached abstract `.text` is snapshotted at ingestion time, before `kg:project` ever splices an inline `id/<ID>` anchor into a list-item/paragraph's rendered form. Once a block has been through even one project cycle, its stored text and its freshly-reparsed disk text differ by exactly that anchor — breaking any matcher that requires exact equality, ours included. Not attempted here; needs its own fix (re-deriving the stored abstract with anchors stripped, or comparing anchor-insensitively).

## Practice: stage checkpoints myself, leave commits to the user <a name='id/BlockNode:00CDEEJ8PR001' class='aperas-anchor aperas-id'></a>

The rename incident above recovered cleanly only because `Apeiron/*.jsonld` happened to already be staged from an earlier point — `git restore` could reset the working tree to that known-good index state in one step. That shouldn't be luck: after each verified-stable step (a clean round-trip, a successful reconciliation with no unexpected removals), stage the change (`git add`) immediately, so the git index is always a running checkpoint. If a later step goes wrong, `git restore`/`git diff` against the index recovers it without guesswork.

This is deliberately staging only, never committing: <a name='id/BlockNode:00CDEEJ8PR002' class='aperas-anchor aperas-id'></a> `git commit` stays a decision for the user to make explicitly, reviewing what accumulated. Staging is not that — it's a private safety net, the same role `git stash` or a snapshot would play, just reusing git's own index instead of a separate mechanism.

## Incident: artifact rename has no working path yet <a name='id/BlockNode:00CDEB141G001' class='aperas-anchor aperas-id'></a>

Tried to exercise a rename (`cli.md` -> `cli-packaging.md`) to see whether the system's rename detection preserves block identity or silently treats it as delete+create. Neither scoped nor full ingestion actually renames safely today:

- **Scoped `kg:ingest --track <paths>` doesn't rename at all.** `kgTrack.ts` documents this: <a name='id/BlockNode:00CDEB141G002' class='aperas-anchor aperas-id'></a> an explicit-path track/ingest never runs the whole-corpus rename/removal sweep. Moving the file on disk and ingesting the new path just created a brand-new ArtifactNode with fresh BlockNode IDs — and left the old ArtifactNode worse off than a clean removal: the FolderNode structural sweep detached it from the tree (invisible to `kg:tree`) without tombstoning it, so it kept squatting on the old `path` as a live, orphaned node.
- **The only real rename detection (Gestalt-match) lives in the full, path-less sweep** (`trackAllArtifacts`), and that sweep walks every file under `AperasKG/artifacts/` with no exclusion for `archive/` — which has never been swept before now. It aborted immediately on a pre-existing full-slug-path collision between two blocks in `archive/Aperas-dev-status.md`, before writing anything.

Recovered by restoring `Apeiron/*.jsonld` from the git index (the last known-good staged state) and reverting the disk `mv`. No dedicated "rename an artifact" primitive exists yet — this needs a real design, not another ad hoc attempt.

## Dashboard <a name='id/BlockNode:00CDDVC33G000' class='aperas-anchor aperas-id'></a>

- [Design](../design/cli-packaging.md#id/BlockNode:00CDDVBXH8001) — architecture decisions once crystallized.
- [Issues](../issues/cli-packaging.md#id/BlockNode:00CDDVC8N0001) — gaps this reasoning surfaces.
- [Planning](../planning/cli-packaging.md#id/BlockNode:00CDDVCDW8001) — task breakdown once a shape is agreed.
- [History](../history/cli-packaging.md#id/BlockNode:00CDDVCKCG001) — status/milestones.

## Motivation: dogfooding vs. shipping <a name='id/BlockNode:00CDDVC33G006' class='aperas-anchor aperas-id'></a>

Every `kg:*` command today is its own `tsx`-run entrypoint (`web/src/lib/kgX.ts`) invoked as `npm run kg:X -- <args>` — that only works inside a source checkout of this repo, with `tsx` and every other devDependency installed. That's fine for us dogfooding the skills we write against this CLI, but the skills under `skills/` are meant for end users, who won't have this repo cloned. Before more skills lean on `kg:*` commands, the CLI itself needs to be something installable and runnable standalone.

## Considered: one bin per verb <a name='id/BlockNode:00CDDVC33G007' class='aperas-anchor aperas-id'></a>

Register each existing `kgX.ts` as its own `bin` entry (`aperas-ingest`, `aperas-tree`, ...). Minimal code change — every file already runs standalone. Rejected: pollutes the user's PATH with roughly twenty near-identically-named commands, and throws away the single `aperas <verb>` entrypoint every illustrative example in the corpus already assumes (e.g. design/documentation.md's Workflows: `echo "..." | aperas update design/crud.md/Architecture`).

## Landing on: one dispatcher binary <a name='id/BlockNode:00CDDVC33G008' class='aperas-anchor aperas-id'></a>

A single `aperas` executable that argv-dispatches to a subcommand (`aperas ingest ...`, `aperas tree ...`, ...). Low-risk refactor: every `kgX.ts` already separates a pure `run*` function (e.g. `runIngest`, `runProject`) from its own `main()`'s argv-parsing/help-printing glue — the dispatcher only needs to own argv routing and reuse the existing `run*`/`request()` calls and `kgHelp.ts` machinery, not rewrite any command's logic.

## Naming: `aperas`, not `kg` <a name='id/BlockNode:00CDF8B3TG00A' class='aperas-anchor aperas-id'></a>

`kg` is short and matches the existing `kg:*` script prefix, but it collides too easily with other tools people already have on their PATH (a common `kubectl` alias, among others) — a real risk once this is something end users install globally, not just an internal npm script name scoped to this repo. Settled on `aperas` instead: unambiguous, matches the project's own name, no realistic collision.

## Open question: the runtime <a name='id/BlockNode:00CDDVC33G009' class='aperas-anchor aperas-id'></a>

`tsx` (on-the-fly TypeScript execution) is a devDependency today, not something to ship a published CLI depending on. Needs a real build step (`esbuild`/`tsc`) compiling to plain JS, with `bin` pointing at the built entrypoint (a `#!/usr/bin/env node` shebang) — `npm run kg:X` during development can keep using `tsx` unchanged; only the published artifact needs to be compiled.

## Open question: where's the graph? <a name='id/BlockNode:00CDDVC33G00A' class='aperas-anchor aperas-id'></a>

`getArtifactsDir()` resolves `AperasKG/artifacts` as a hardcoded sibling of `web/` — true for us, not for an end user with no such sibling folder. Packaging needs some answer for where an installed `aperas` binary finds (or creates) its own graph — cwd-relative discovery, an env var, a config file — that's still open, and probably the biggest remaining unknown, separate from the dispatcher/bundling mechanics above.

## Resolved (partially): retitling a heading, and a deeper wikilink gap it exposed <a name='id/BlockNode:00CDG18FP0001' class='aperas-anchor aperas-id'></a>

Renaming this doc set (`cli-packaging.md` -> `packaging.md`) needed each doc's own H1 retitled too (`# CLI Packaging — X` -> `# Packaging — X`). Pushed the whole corrected document through `kg:update` targeting the *ArtifactNode* (`design/packaging.md`), the same way the `kg -> aperas` content fix worked earlier — and it blew up all 7 blocks into fresh "added" ones (0 matched), tombstoning every original BlockNode id in the process.

**Root cause:** `kg:update` *does* have a retitle-in-place feature (`kgUpdate.ts`: <a name='id/BlockNode:00CDG18FP0002' class='aperas-anchor aperas-id'></a> when the piped input's own first child is a heading of matching depth, it relabels `title`/`text` in place, no restructuring) — but it only fires when the *target itself* is that heading BlockNode. Targeting the ArtifactNode instead routes the whole document through the generic `reconcileTree`/Gestalt matcher, where a heading's match key is `title` alone (`reconcile.ts`'s `leafKey`) — no positional or depth-aware fallback. A title change is therefore an exact-key mismatch at the very top of the tree, and since nothing above it can anchor a match, the *entire* subtree reconciles as removed+added instead of "one heading changed, rest unchanged." Artifact-level renames get a real "same identity, new label" primitive (`trackFromDisk`, after this session's earlier fix); heading-level retitling only gets one when addressed directly, not through a whole-document push.

**A second, deeper gap this exposed:** neither `kg:update` nor `kg:insert` ever calls `resolveBlockLinks` — grepped every call site; it only ever runs from `ingestArtifact` (the `kg:ingest`/disk-first path). A block that's "matched" (untouched) keeps whatever links it already had, but anything reconciled as "changed" or "added" via `kg:update`/`kg:insert` gets *no* link resolution at all, silently. Confirmed directly: a fresh "added" list item's own BlockNode has no `links` field whatsoever. `documentation.md` and `linking.md` were unaffected (their wikilink-bearing blocks only ever went through "matched" `kg:update` passes, carrying forward resolution from an earlier real `kg:ingest`) — this doc set is the one place it actually broke, because the retitle accident forced every block through "added".

Recovered by restoring `Apeiron/*.jsonld` from the git index and reprojecting from the graph (the disk `.md` files needed a `kg:project` to come back after a restore mishap deleted them outright — recoverable because the graph itself, not the working tree, was the actual source of truth here). Not yet fixed: the rename to `packaging.md` (still `cli-packaging.md` on disk) and the wikilink-resolution gap in `kg:update`/`kg:insert` — tracked, not resolved.

## Resolved: `kg:update`/`kg:insert` now resolve wikilinks <a name='id/BlockNode:00CDGAFQQR001' class='aperas-anchor aperas-id'></a>

Both commands now call `resolveBlockLinks` (`apeironNgn/artifacts.ts`) themselves, the same wrapper `ingestArtifact` already used — closing the gap the retitle incident above exposed.

The pieces needed were already in `node.ts`, just private to `ingestFromDisk`: <a name='id/BlockNode:00CDGAFQR0000' class='aperas-anchor aperas-id'></a> `collectLinkTargetsByBlock`/`collectOldWikilinksByBlock` snapshot a block's pre-mutation resolved link state, and `extractLinkCodes` (`artifacts.ts`) reads the `linkCodes` a fresh parse already stashes per node. Both are now exported, plus a new `findEnclosingArtifactId` (mirroring `artifactPathOfBlock`'s walk, but returning an id) so a command that starts from an arbitrary Block/ArtifactNode target — not `ingestArtifact`'s own already-known artifact id — can still find the right node for `resolveBlockLinks`'s `danglingRef` bookkeeping.

`kg:update`: <a name='id/BlockNode:00CDGAFQR0001' class='aperas-anchor aperas-id'></a> the old-link snapshot is taken right after `oldShape` (before any mutation); whichever branch (`--text-only` or the default reconcile) builds the new tree also now extracts pending link codes from it *before* hydrating — same order `ingestFromDisk` uses, since `extractLinkCodes` strips the schema-unknown `linkCodes` field as it walks. `kg:insert`'s create mode does the same over its freshly-parsed `topLevel`, with empty old-state maps (nothing existed before).

Verified two ways: <a name='id/BlockNode:00CDGAFQR0002' class='aperas-anchor aperas-id'></a> a throwaway `kg:insert`'d block with a `#id/...` link resolved immediately (`kg:backlinks` showed the new block as a real backlink, not just a reported count); and a no-op `kg:update` reconcile of an existing two-link block reused both `Link` ids rather than minting duplicates (`kg:backlinks` afterward showed the same two entries, unchanged).

## Resolved: heading retitle-in-place, at the reconcile level too <a name='id/BlockNode:00CDGGTE6R001' class='aperas-anchor aperas-id'></a>

`kg:update`'s direct-heading-retitle feature only ever covered *targeting the heading itself*; a whole-document/whole-tree push (targeting the ArtifactNode, or a real `kg:ingest` re-parse of an edited file) still went through `reconcile.ts`'s generic `diffChildren`, where a heading's Stage A match key is `title` alone (`leafKey`) — an edited title was an exact-key miss with nothing to fall back on, so the entire subtree beneath a retitled heading reconciled as wholesale removed+added, exactly what happened above.

Added a Stage A2 to `diffChildren`: <a name='id/BlockNode:00CDGGTE6R002' class='aperas-anchor aperas-id'></a> headings still unmatched after Stage A's exact-title pass get a positional fallback — bucketed by depth (`astParser.ts`'s new `headingDepth`, reading the title's own leading `#` run, so a `##` can never fool-match a `#`), then paired in original relative order within each bucket. Same "position is the anchor" trade-off Stage B already accepts for `list`/`listItem` containers, just extended to headings once title itself is off the table as a key. A pair matched this way (or via Stage A's own text-only case) that differs in `title` and/or `text` is counted as `changed`, not folded into `matched` (`headingChanged`, generalized from the old `headingTextChanged`).

Verified on a throwaway test artifact: <a name='id/BlockNode:00CDGGTE6R003' class='aperas-anchor aperas-id'></a> retitling its H1 through a whole-document `kg:update` (the same shape of push that caused the original incident) now reports "2 matched, 1 changed, 0 added, 0 removed" — the two section headings matched cleanly, the retitled H1 counted as changed, and disk projection confirmed all three BlockNode ids were preserved (no tombstones).
