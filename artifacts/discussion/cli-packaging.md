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

Register each existing `kgX.ts` as its own `bin` entry (`kg-ingest`, `kg-tree`, ...). Minimal code change — every file already runs standalone. Rejected: pollutes the user's PATH with roughly twenty near-identically-named commands, and throws away the `kg <verb>` grouping every doc and code comment already writes commands as (e.g. `kg:update design/crud.md/Architecture --text ...` in design/documentation.md's Workflows).

## Landing on: one dispatcher binary <a name='id/BlockNode:00CDDVC33G008' class='aperas-anchor aperas-id'></a>

A single `kg` executable that argv-dispatches to a subcommand (`kg ingest ...`, `kg tree ...`, ...). Low-risk refactor: every `kgX.ts` already separates a pure `run*` function (e.g. `runIngest`, `runProject`) from its own `main()`'s argv-parsing/help-printing glue — the dispatcher only needs to own argv routing and reuse the existing `run*`/`request()` calls and `kgHelp.ts` machinery, not rewrite any command's logic.

## Open question: the runtime <a name='id/BlockNode:00CDDVC33G009' class='aperas-anchor aperas-id'></a>

`tsx` (on-the-fly TypeScript execution) is a devDependency today, not something to ship a published CLI depending on. Needs a real build step (`esbuild`/`tsc`) compiling to plain JS, with `bin` pointing at the built entrypoint (a `#!/usr/bin/env node` shebang) — `npm run kg:X` during development can keep using `tsx` unchanged; only the published artifact needs to be compiled.

## Open question: where's the graph? <a name='id/BlockNode:00CDDVC33G00A' class='aperas-anchor aperas-id'></a>

`getArtifactsDir()` resolves `AperasKG/artifacts` as a hardcoded sibling of `web/` — true for us, not for an end user with no such sibling folder. Packaging needs some answer for where an installed `kg` binary finds (or creates) its own graph — cwd-relative discovery, an env var, a config file — that's still open, and probably the biggest remaining unknown, separate from the dispatcher/bundling mechanics above.
