# Packaging — Discussion <a name='id/BlockNode:00CDDVC338001' class='aperas-anchor aperas-id'></a>

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

- [Design](../design/packaging.md#id/BlockNode:00CDDVBXH8001) — architecture decisions once crystallized.
- [Issues](../issues/packaging.md#id/BlockNode:00CDDVC8N0001) — gaps this reasoning surfaces.
- [Planning](../planning/packaging.md#id/BlockNode:00CDDVCDW8001) — task breakdown once a shape is agreed.
- [History](../history/packaging.md#id/BlockNode:00CDDVCKCG001) — status/milestones.

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

## Resolved: the `cli-packaging.md` → `packaging.md` rename itself <a name='id/BlockNode:00CDGN9FMR001' class='aperas-anchor aperas-id'></a>

Redone now that both blockers above are fixed. Sequence used, per doc: (1) retitle the H1 directly (`kg:update --text-only` targeting the heading BlockNode itself, not the ArtifactNode) — confirmed first that none of the five H1s carried their own `.text`/`.props`, so `--text-only`'s unconditional overwrite of those fields on a heading-target update was a no-op, not a loss; (2) fix each internal cross-reference bullet's own path text (`cli-packaging.md` → `packaging.md`) via `kg:update` targeting that specific leaf block directly, one at a time — not a whole-document push, so Stage A's ordinary exact-key matching (unaffected by the title/path edits happening elsewhere in the same document) is what reconciles each one, with nothing at stake beyond that one block's own identity; (3) `git mv` each file, then scoped `kg:ingest --track --flush`, one concern at a time.

Verified past the summary line: <a name='id/BlockNode:00CDGN9FMR002' class='aperas-anchor aperas-id'></a> every renamed ArtifactNode still carries its original id (`00CDDTBJBG000`/`00CDDTBQWG000`/`00CDDTBYG0000`/`00CDDTC3S0000`/`00CDDTC8H0000`), none tombstoned, and no orphaned `cli-packaging.md`-pathed entry survives. A couple of the cross-reference bullets (the ones with no bold lead-in term, so no rendered id-anchor — e.g. the Dashboard list) had never actually had their `[[wikilink]]`s resolved at all before this pass, since they were authored before the `kg:update`/`kg:insert` link-resolution fix above existed; fixing their path text was incidentally also the first time they got resolved.

## Freeflow: 3-way workspace split — inventory before deciding shape <a name='id/BlockNode:00CDGPBDKG001' class='aperas-anchor aperas-id'></a>

Starting the investigation the user asked for ("do... the 3-way split refactor") before moving any files, per the practice above (discussion first). Dumping raw findings here as I go rather than only writing a polished plan at the end — this doc is the scratchpad.

**Current `web/src` inventory** (`find src -type f`): <a name='id/BlockNode:00CDGPBDKG002' class='aperas-anchor aperas-id'></a> the entire engine + CLI lives under `src/lib/` — `apeironNgn/*.ts` (the graph engine: `node.ts`, `artifacts.ts`, `folders.ts`, `reconcile.ts`, `store.ts`, `service.ts`, `serviceClient.ts`, `shape.ts`, `vocab.ts`, `dehydrate.ts`, `tree.ts`, `resolve*.ts`, `codeVersion.ts`, `compareMigration.ts`), plus parsing/shared (`astParser.ts`, `reconcile.ts`, `props.ts`, `project.ts`, `snowflake.ts`, `leadingPart.ts`, `nodeRef.ts`, `lineReader.ts`, `folders.ts`, `artifacts.ts`, `verify.ts`), plus every `kgX.ts` CLI entrypoint (`kgIngest.ts`, `kgUpdate.ts`, `kgInsert.ts`, ... `kgService.ts`, `kgHelp.ts`) and `apeironNgnSmokeTest.ts`. Frontend is just `App.tsx`/`index.tsx`/`App.css`/`index.css`/`assets/*` at `src/` root.

**Important finding: the "frontend" isn't actually a real UI yet.** Read `App.tsx` (106 lines) — it's the unmodified Vite+Solid scaffold template (hero image, framework logos, a counter button, links to Vite/Solid/GitHub/Discord docs). Nothing in it touches the graph, ApeironNgn, or any `kg:*` concept. So "3-way split" today is really "extract engine + CLI out of a project that also happens to carry unused scaffolding," not "separate two things that both have real content." Doesn't block the split, but changes the risk profile — there's no real `web` behavior to preserve/test, just a build target to keep working (or drop).

**`package.json` scripts**: <a name='id/BlockNode:00CDGPBDKG004' class='aperas-anchor aperas-id'></a> `dev`/`build`/`preview` (vite, frontend-only) + `verify` (`tsx src/lib/verify.ts`) + 19 `kg:*` entries, all `tsx src/lib/kgX.ts` — no `bin` field yet, no built/compiled output anywhere, everything runs from source via `tsx`.

**Dependencies** (already checked once this session, re-confirmed): <a name='id/BlockNode:00CDGPBDKG005' class='aperas-anchor aperas-id'></a> `oxigraph`, `@rdfjs/data-model`, `remark-parse`/`remark-gfm`/`remark-frontmatter`/`unified`/`unist-util-visit` are core/cli. `solid-js`/`lucide-solid`/`clsx` are web-only. Two more worth flagging: `terminusdb` and `rehype-stringify`/`remark-rehype` — grepped `src/` for both, **zero hits**. Likely dead deps left over from the pre-ApeironNgn TerminusDB era (`AperasKG/artifacts/archive/tdb-era/`) and some abandoned markdown->HTML rendering path. Candidates to drop entirely rather than assign to any package — need a decision, not just a mechanical move.

**Build config**: <a name='id/BlockNode:00CDGPBDKG006' class='aperas-anchor aperas-id'></a> one `tsconfig.app.json` covers ALL of `src` today (`jsx: preserve`, `jsxImportSource: solid-js`, `lib: ["ES2023", "DOM"]`) — meaning the engine/CLI code currently compiles under a config that also demands DOM types and a JSX pragma it never uses. A 3-way split needs at least 2 distinct tsconfigs (core/cli: node target, no DOM/JSX; web: current app config), maybe 3 if cli wants its own (e.g. to add a `bin`-oriented build step) separate from core's plain library build.

**Not yet decided / need to think through before moving anything**:

- Where exactly is the core/cli boundary? Every `kgX.ts` is a thin argv/stdio wrapper around a `run*` function + `request()` call to the shared service — is `kgHelp.ts` core or cli-only? Is `apeironNgn/serviceClient.ts` (the RPC client) cli, or does core need it too (probably cli/service-layer, not pure graph engine)?
- `apeironNgn/service.ts` — the actual long-running service process — core, or its own thing entirely (arguably neither "library" nor "CLI command", it's a daemon)?
- What happens to the totally-unused Vite/Solid scaffold — carry it forward as `packages/web`'s starting point, or drop it and create `packages/web` empty/minimal until there's an actual UI to build? Dropping avoids moving dead weight but throws away working build tooling (vite config, tsconfig) that'd have to be recreated later anyway.
- `terminusdb`/`rehype-stringify`/`remark-rehype`: <a name='id/BlockNode:00CDGPBDKG00B' class='aperas-anchor aperas-id'></a> drop now (as part of this refactor, since we're already touching package.json) or leave alone (out of scope, separate cleanup)?

## Freeflow: 3-way split — proposed package boundaries <a name='id/BlockNode:00CDGPTZ7G000' class='aperas-anchor aperas-id'></a>

Working through the open questions from the inventory above.

**core vs cli boundary, resolved:** the service/RPC layer (`apeironNgn/service.ts`, `serviceClient.ts`, `serviceLock.ts`, `serviceProtocol.ts`) is CLI-scoped, not core — its whole reason to exist is letting many short-lived `tsx kgX.ts` processes share one warm in-memory graph, which is a CLI-ergonomics problem specifically. A different future consumer (a web server embedding the engine in-process) would just hold its own `Store` via `core` directly, no service needed. So:

- **`packages/core`**: <a name='id/BlockNode:00CDGPTZ7G002' class='aperas-anchor aperas-id'></a> `apeironNgn/{node,artifacts,folders,dehydrate,shape,vocab,tree,resolve,resolveCreate,store,codeVersion,compareMigration}.ts`, `astParser.ts`, `reconcile.ts`, `props.ts`, `project.ts`, `snowflake.ts`, `leadingPart.ts`, `nodeRef.ts`, `lineReader.ts`, top-level `folders.ts`/`artifacts.ts`, `verify.ts`. Pure graph engine + markdown parsing, no process/argv/RPC concerns, no DOM.
- **`packages/cli`**: <a name='id/BlockNode:00CDGPTZ7G003' class='aperas-anchor aperas-id'></a> every `kgX.ts`, `kgHelp.ts`, `apeironNgn/service.ts` + `serviceClient.ts` + `serviceLock.ts` + `serviceProtocol.ts`, `apeironNgnSmokeTest.ts`. Depends on `core`. Future `aperas.ts` dispatcher lands here too.
- **`packages/web`** (open question below): <a name='id/BlockNode:00CDGPTZ7G004' class='aperas-anchor aperas-id'></a> `App.tsx`/`index.tsx`/`App.css`/`index.css`/`assets/*`, `vite.config.ts`, `tsconfig.app.json`. Depends on `core` (a real UI would query the graph directly or via its own client, not shell out to CLI commands).

**Dead-dependency cleanup, proposed as part of this same refactor** (not separately, since splitting `package.json` into 3 means deciding a home for every dep anyway, and these two have none): drop `terminusdb` and `rehype-stringify`/`remark-rehype` — confirmed zero `src/` references to any of the three, leftover from the pre-ApeironNgn TerminusDB era and an abandoned markdown-to-HTML path.

**Two real judgment calls, not mine to make silently — surfacing them in chat rather than deciding here:**

1. What happens to the Vite/Solid scaffold in `packages/web` — it's 100% unmodified template content (hero image, framework logos, a counter, links to Vite/Solid/GitHub/Discord). Options: carry the build tooling (vite config, tsconfig) forward but strip the demo content to a bare placeholder; drop `packages/web` entirely for now and recreate it when there's an actual UI to build; or leave it as-is (ship the literal template).
2. The workspace root's own name. `Aperas/web/` becomes the npm workspace root once it contains `packages/{core,cli,web}` — every skill instruction and habit this session says "run from `Aperas/web/`", and `getArtifactsDir()` resolves the graph as a sibling of `web/`. Keeping the directory named `web` while it no longer *is* "the web frontend" (that's now `packages/web` one level down) reads oddly, but renaming it is a bigger, separately-risky move (git history, the skill file, `getArtifactsDir()`'s sibling assumption). Leaning toward: keep the directory named `web` for now (minimize blast radius on this already-large refactor), revisit the name later if it actually causes confusion in practice.

## Freeflow: root-rename blast radius, actually measured <a name='id/BlockNode:00CDGS4BBG001' class='aperas-anchor aperas-id'></a>

Asked to calculate this rather than guess. Grepped every `.md`/`.json`/`.ts`/`.tsx`/`.yml`/`.yaml` in the repo (excluding `AperasKG/artifacts/archive/`) for `Aperas/web`, `../web`, or `/web/` path references — **exactly one hit**: `skills/kg-doc-ingest/SKILL.md` (its `.agents/skills`/`.claude/skills` copies are symlinks to the same file, so that's one edit, not three).

`getArtifactsDir()` (`artifacts.ts`) turned out *not* to be part of this blast radius at all — it never hardcodes the string `"web"`; it walks up a fixed number of `..` hops from its own file's location (`import.meta.url`) to the repo root, then descends into `AperasKG/artifacts` (itself a symlink to a sibling of the repo, resolved transparently by the OS either way). That hop count needs updating regardless of what the root directory is named, purely because the file is moving one level deeper (`web/src/lib/artifacts.ts` → `<root>/packages/core/src/artifacts.ts`) — the split causes this change, not the rename.

No `.vscode/`, CI config, Dockerfile, or other doc anywhere references `web/` as a path. `web/package.json`'s own `"name": "web"` field is cosmetic (never published, root-of-workspace only) and can change independently of the directory name either way.

So the actual added cost of renaming the root beyond what the split needs anyway: one text edit to the skill file's "run from Aperas/web/" instructions, plus a one-time habit adjustment in conversation — much smaller than initially estimated. Reporting this back rather than deciding unilaterally, since the recommendation changes given real numbers instead of a guess.
