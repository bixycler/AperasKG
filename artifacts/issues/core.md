---
description: The engine-level bug family this concern owns — most prominently a still-unexplained per-operation slowdown that compounds the longer a long-lived process stays alive, once bad enough to hang the whole service for 40 minutes.
---

# Core — Issues <a name='id/BlockNode:00CF1WZ4JG001' class='aperas-anchor aperas-id'></a>

## Open Issues <a name='id/BlockNode:00CF1WZ4JG002' class='aperas-anchor aperas-id'></a>

- **Confirmed at real production scale, 2026-09-20**: <a name='id/BlockNode:00CKSAK04R001' class='aperas-anchor aperas-id'></a> a corpus-wide re-ingestion left the entire service unresponsive for 40 minutes straight, not merely slow. `kg:migrate-frontmatter` (the [frontmatter-as-props redesign](../discussion/core.md#id/BlockNode:00CKE4FFF0001)'s one-time pass, re-running `ingestFromDisk` against every live `ArtifactNode` with `bypassUnchangedCheck: true`) started 2026-09-20T05:14:39Z, ran continuously with the service process pinned at 150-280% CPU (confirmed still doing real work, never idle), and was still running with no end in sight when killed at approximately 2026-09-20T05:55Z, roughly 40 minutes in — for a corpus on the order of 50 artifacts, this is the same "12-55 seconds per operation, compounding the longer the process has been alive" pathology the entry above already names, stretched by scale from seconds into most of an hour. Root cause of the unresponsiveness, confirmed by reading `service.ts` directly rather than guessing: its migration loop calls `ingestArtifact` → `ingestFromDisk` → `reconcileTree` synchronously per artifact with no `await`/yield point anywhere in that path, and Node's single-threaded event loop cannot service *anything else* — a timer, a new socket connection, another CLI command — while a synchronous call is still on the stack. `service.ts`'s own 10-second auto-flush (`setInterval(() => enqueue(() => flushIfDirty()), 10_000)`, line 401-403) never got a single chance to fire for the whole run, confirmed directly: the JSON-LD mirror's own mtime never moved once during those 40 minutes. Independently corroborated live: a plain `aperas show <id>` issued from a separate terminal while the migration was still running failed with "No ApeironNgn service running" — not a crash, the event loop was simply never free to accept or process that new connection. Killed for an unrelated reason — a separate `reconcile.ts` bug this same run surfaced (`carryForwardFields` not re-syncing a fallback-titled block's `title` when it carries the *old* `blockId` forward, since `astParser.ts`'s own fallback sets `title` to a block's *fresh* scratch `blockId` when no real lead-in exists), not yet filed as its own entry — not because the operation had actually stalled.
  
  - **Since measured (2026-10-11), not resolved**: <a name='id/BlockNode:00D1EZZWD8001' class='aperas-anchor aperas-id'></a> the 40-minute stall during a corpus-wide re-ingestion is consistent with the mechanism measured since for the slow `verify` steps, a long synchronous burst over wasm-bound wrappers that never yields, with repeated full garbage collections taking 70 to 87% of the time of the slow steps and a fresh process rehydrating the same directory in 2.9 s against 37.8 s after a rehydrate and a dehydrate; it is not shown to be the same cause, since the migration was neither profiled nor traced for collections. The related service-side costs are in [the removal-stall issue](../issues/core.md#id/BlockNode:00CVNX6A3R000) and [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001). This entry stays open: the service-level stall it records is not closed, and the `verify` suite's independence of the core's cost (see the resolved entries on the `verify` slowdown and on why isolation helps) does not touch it.

- **`ArtifactNode`/`FolderNode.text` is a stale, heuristic copy that can't be baked — found via a folder-listing link that stayed inert after the fix meant to cover it**: <a name='id/BlockNode:00CKE4R93R001' class='aperas-anchor aperas-id'></a> `design/linking.md`'s own `**Discussion**:` line rendered `inline-link-inert` in the "design" folder's listing, even after the bare-relative-path resolver fix and `bakeResolvedLinkIds` render-time fix ([history/linking.md](../history/linking.md#id/BlockNode:00CJAVGNJG001), [history/webapp.md](../history/webapp.md#id/BlockNode:00CJAVRF90001), both 2026-09-18) were verified working for the direct case. Root cause: the folder-listing preview reads the `ArtifactNode`'s own `.text`, which is a *copy* of its first content-bearing descendant's text (`extractAbstract`), made once at hydration time — the descendant's real `Link` (confirmed already correctly resolved via `aperas show`) is never duplicated onto the container, so `bakeResolvedLinkIds` has nothing to bake with for this render path specifically. Deeper problem underneath: this copy is never refreshed by an ordinary deep edit either — `kgUpdate.ts`'s `target.text = text` never touches an ancestor's own `.text`, only a full re-hydration or the one-time holder-promotion path ever recomputes it — so the preview can go stale independent of this specific bug too. Direction agreed (see [discussion/core.md](../discussion/core.md#id/BlockNode:00CKE4FFF0001)'s 2026-09-20 Freeflow entry for full rationale): retire the copy/heuristic entirely; give `ArtifactNode`/`FolderNode` a real `description` field in their own YAML frontmatter, with its own genuinely-owned `Link`s, edited via `aperas update` extended to accept `FolderNode` and to consume `frontmatter` — the corpus's long-standing "update as a scoped reconciliation" pattern, not a new bespoke channel. Implemented in `e66996b`, but only partly: the `description` prop and its bakeable links landed, while one of the two preview paths still reads the copy this issue exists to retire — see [the follow-on](#id/BlockNode:00CN7V9BX0001).
- **No revive/untombstone operation exists, and the shutdown-time tombstone GC can turn a same-session mistake into permanent loss with no grace window**: <a name='id/BlockNode:00CN1PT1B0001' class='aperas-anchor aperas-id'></a> confirmed live during recovery from [an accidental structural tombstone](../discussion/core.md#id/BlockNode:00CN1PKAQG001) — `aperas insert <tombstoned-id> --after <anchor>` (the identity-preserving move primitive) repositions a tombstoned node but does not clear `tombstonedAt`, and no other verb in `service.ts`'s full op switch does either, so once a node is tombstoned there is no CLI-level path back short of hand-editing the JSONLD mirror. Worse, `aperas service stop`'s shutdown flush runs `pruneUnreachableTombstones` (the same mark-and-sweep GC documented at the other explicit-sweep call sites, `kg:reload`/`flush --clobber`) with no warning and no delay — a node tombstoned moments earlier in the very same session, if its `parent` has already been stripped (as an ordinary tombstone does), is indistinguishable from genuinely old, safely-collectible garbage and gets permanently deleted on the next stop/restart/reload. There is currently no cool-down, no confirmation, and no way to tell from the tombstoning operation's own output that a subsequent routine service restart will make the mistake unrecoverable. The only reason this specific incident was recoverable at all was an out-of-band `git stash` taken by the operator moments before the fatal restart — not anything the tooling itself provided.
- **The frontmatter-`description` retirement of `ArtifactNode`/`FolderNode.text` landed on only one of the two preview paths, so `unfold` and `backlinks` still show the stale heuristic copy**: <a name='id/BlockNode:00CN7V9BX0001' class='aperas-anchor aperas-id'></a> the direction agreed in [the parent issue](#id/BlockNode:00CKE4R93R001) shipped in `e66996b` — `description` became a real frontmatter-owned prop carrying its own bakeable `Link`s — and `buildNodeItem` (`node.ts:1799-1801`) was updated to read `description ?? .text` for `ArtifactNode`/`FolderNode`, which is what `aperas tree` and the webapp render through `emitNode`. `kgUnfold.ts`'s `nodeAbstract` (lines 32-46) was not: it reads `node.text` unconditionally, for every node kind, with no `description` check at all — and it feeds the unfolded target's own line, every structural child line, every link-target preview, and `aperas backlinks --text`, which is the reason that function was extracted in the first place. So for any artifact or folder whose authored `description` differs from the derived `.text`, the two surfaces disagree, and `aperas unfold` — the orientation command the skill puts first — renders precisely the heuristic copy the redesign set out to retire. Confirmed live 2026-09-22 against `issues/aperas-skill.md`, whose two values currently differ: `tree` and the webapp show the description, `unfold` shows `.text` both when the artifact is the target and when it appears as a child of its folder. It stayed invisible because the two values normally paraphrase each other — the corpus-wide frontmatter sweep seeded most descriptions from text that already said much the same thing — so only an artifact whose description was authored to differ exposes it. `aperas show` is not part of the defect: it prints the stored node raw, which is what made the divergence legible in the first place. Notably this is a re-run of a defect this same file already records in its own doc comment — "this file has its own, separate preview-printing path (not `emitNode`), so it had its own separate instance of the same bug" — the duplicated preview path diverging a second time, on the next change that crossed it. Fix direction: give `nodeAbstract` the same `description ?? .text` precedence `buildNodeItem` uses, or better, have both call one shared helper, since the recorded history of these two paths is that they diverge on every change that touches only one. Not yet implemented.
- **A corpus-wide `aperas ingest` (no path) can hang indefinitely on an interactive confirmation prompt with no signal that it's waiting rather than working**: <a name='id/BlockNode:00CNX1T4XG001' class='aperas-anchor aperas-id'></a> `kg:ingest` run unscoped detected content it proposed to remove and printed `Are you sure you want to remove these? [yes/NO]:`, then blocked on stdin. Run from a non-interactive shell (no tty attached), that stdin is immediately at EOF, so the prompt never resolves — the process just sits there. Confirmed live: the process showed near-zero CPU the entire time (ruling out "genuinely slow on a large corpus," which shows sustained high CPU instead, e.g. at service startup), and the ApeironNgn service itself answered an unrelated read (`aperas backlinks`) instantly throughout, proving the request never even reached the service's own queue — the block is entirely client-side, before `request()` is ever called. When stdin finally closed, the process exited 0 with the prompt still unanswered on screen; the flagged items turned out to already be old tombstones (dated a week prior), so nothing was actually lost this time, but nothing in the tool's own behavior guarantees that — an EOF being treated as "no" is incidental, not a documented contract. Not yet implemented: either a `--yes`/`--non-interactive` flag that skips the prompt with an explicit answer, or a `stdin.isTTY` check that hard-refuses (rather than blocking) when the answer can't actually be given.
- **The ApeironNgn service can die silently, and a stuck prior process can survive `service stop`/`start`**: <a name='id/BlockNode:00CRBJ0VYG001' class='aperas-anchor aperas-id'></a> found 2026-09-27, twice in one session. First: `service restart`/`service start` timed out ("did not become ready in time") once while a prior instance was still mid-rehydration under load; a retry a few seconds later succeeded. Second, worse: the service died mid-turn with no error until the next call, and the stuck old process (90+ minutes old, no lock file, invisible to `service stop`) sat consuming growing CPU/memory; `service start` failed twice with the same "did not become ready" message before the stuck process was killed by PID and a fresh start came up clean in about a minute. No data was lost either time — every write had been flushed and survived on disk. Undiagnosed: why the process dies silently, why it leaves no lock file and is invisible to `service stop`, and whether the readiness check is too tight for this corpus's current size.
- **A command can fail with "No ApeironNgn service running" while the service is up, and an unchanged retry works**: <a name='id/BlockNode:00CVMPABY8001' class='aperas-anchor aperas-id'></a> recorded in two separate grapher Reports. Filed 2026-10-02.
  
  - **Symptom**
    
    - The first `aperas insert` of one turn failed with that message while `aperas service start` immediately reported the service already running (pid 220722).
    - The same message came back later in that turn on `aperas project issues/linking.md`, and in a second turn on an `aperas update` between otherwise working commands.
    - Every unchanged retry succeeded with no restart.
    - Unlike [the silent death below](#id/BlockNode:00CRBJ0VYG001), the service never went down.
    - **Reproduced by load later the same day**, in the v4.3 filing sweep: while the service was busy after an `aperas remove --flush` of a finished thread task (the process was alive at 100 to 290 percent CPU for minutes), every command, `aperas show` included, failed with that message.
      
      - The same commands worked once the service was idle again, which fits a 300 ms ping reading a busy service as down.
    - **Two earlier observations point the same way**: <a name='id/BlockNode:00D0X5TK4G008' class='aperas-anchor aperas-id'></a>
      
      - `aperas service start` answered "Already running" with the old pid right after a command failed.
      - `service.log` holds only startup lines, with no shutdown, flush or connect-failure line, so it cannot say why a client could not reach a live service.
  - **Root cause**
    
    - **A likely cause**, read from the code and consistent with the load observations under Symptom and Measurements:
      
      - `ensureServiceRunning` (`packages/cli/src/apeironNgn/serviceClient.ts:149`) throws that message whenever `ping()` returns false.
      - `ping()` (line 83) turns every error, a timeout included, into `false` after `PING_TIMEOUT_MS = 300`.
      - A service busy with a flush or an ingest and slow to answer within 300 ms therefore reads as not running.
    - **The mechanism**, from the investigation's code survey of 2026-10-02 (read from `service.ts`, `serviceClient.ts` and `kgService.ts`; the failures are consistent with it, and no direct test has isolated it):
      
      - Every request, `ping` included, enters `handleConnection`, is chained onto the single promise `queue` by `enqueue`, and runs `handle`, which has no `await`, so each operation is one uninterrupted synchronous run.
      - A `ping` therefore waits behind the operation in flight and every request already queued ahead of it, and the client's `ping()` gives up after `PING_TIMEOUT_MS = 300`.
      - The 300 ms bound covers queue wait plus the ping's own handling, not whether the loop is stuck.
      - Any operation over about 0.3 s, or a queue of two or three, makes the next command say "No ApeironNgn service running" with nothing stalled.
      - Every other command first calls `ensureServiceRunning`, which is that one 300 ms ping, and `request()` itself sends with no timeout, so a command that passes the ping waits as long as the service takes.
      - **What the queue takes depends on what the queue holds**: <a name='id/BlockNode:00D0X5TK4G00P' class='aperas-anchor aperas-id'></a>
        
        - [Every write re-parses its whole artifact twice](#id/BlockNode:00CVQHBP0R001).
        - [A task removal runs a full-store scan per embedded node](#id/BlockNode:00CVNX6A3R000).
        - [Boot does seconds of synchronous work before the socket exists](#id/BlockNode:00CVQHCEW8001).
  - **Measurements**
    
    - **After the lock turned ready, every `aperas` command failed with "No ApeironNgn service running" for 19.5 to 23.0 s in 6 of 6 starts** (measured 2026-10-10 by the Coder in the store-size investigation; scratch service, 6 cold starts, load average 2 to 3.5)
      
      - They failed because the startup link sweep is enqueued on the event loop right after `markReady` (`service.ts` lines 818 to 826) and the 300 ms `ping` times out.
      - This is the mechanism above shown on a service that is not stalled, only busy; the measurement is in [the start entry](#id/BlockNode:00D0W05P08001).
    - **A settled service answers a `profile list` in 0.55 s wall** (measured 2026-10-10, same runs)
  - **Not proven**
    
    - How much of a failed ping's 300 ms is queue wait against the in-flight operation is untested.
    - The fix to try, under Fix directions, is untested against a counted run of the same load.
    - A concurrent second client as the cause of the earlier drops is not tested.
    - **The sampler's recorded failures fit it without a stall** (read, not proven):
      
      - Of its 11 failed probes, three are at 5, 12 and 19 percent CPU with 2 to 4 `aperas` clients running (21:11:24, 21:14:24, 21:15:24), where another client's operation or flush was probably queued ahead of the probe.
      - The sampler keeps only whether the answer held `"@id"` and discards the failure text, so it cannot tell the ping failure from a request error or a timeout (see [the no-coverage issue](#id/BlockNode:00CVQHD7CR001)).
  - **Fix directions**
    
    - **Fix to try**: <a name='id/BlockNode:00D0X5TK4G017' class='aperas-anchor aperas-id'></a> retry the ping once or twice, or raise the timeout, before throwing, and say in the message when a socket exists but did not answer.
- **A write to a thread node never marks the `.state/` mirror dirty, so it exists only in memory until a view change or a shutdown sweep, and a killed service loses it**: <a name='id/BlockNode:00CVNZXVR8001' class='aperas-anchor aperas-id'></a> found 2026-10-02 when the service stuck after the pruning removals (see the removal-stall entry above) was killed. Filed 2026-10-02.
  
  - **Symptom**
    
    - `.state/BlockNode.jsonld` was last written at 18:26:20 while 15 `aperas remove --flush` calls, each reporting success, ran after it.
    - Every earlier turn's thread writes persisted only because the turn ended with `aperas zoom`.
    - After the kill, the fresh service rehydrated the stale `.state/` records of the removed tasks beside their tombstoned copies that had leaked into the tracked mirror (see the leak entry in `issues/treeview.md`).
    - It logged "323 duplicate @id(s) in the mirror", merged them, and listed the removed task roots as live again with their descendants tombstoned.
  - **Root cause**
    
    - In `packages/cli/src/apeironNgn/service.ts`, `insert`, `update`, `remove` and `retype` set only `dirty`, whose `flushIfDirty` writes the tracked content mirror, and that mirror excludes every `.threads/`-scoped node.
    - The thread-scoped `BlockNode`, `ArtifactNode` and `FolderNode` records are written only by `flushStateIfDirty` into `.state/`, which does nothing unless `stateDirty` is set.
      
      - Only the `unfold`, `fold`, `zoom` and profile ops, the garbage-collection sweeps and `shutdown`'s own sweep set `stateDirty`.
    - The gap is a routing mismatch, not a timer-cadence one, and both timers (3 s and 10 s) work as designed.
      
      - A thread-scoped node is routed to the `.state/` mirror when the store is dehydrated (`THREAD_PARTITIONED_CLASSES`, `isThreadScopedId`), but the dirty flag is chosen without that partition.
      - So the four handlers set `dirty`, which feeds the content flush that excludes thread nodes, and never `stateDirty`, which feeds the `.state/` flush that includes them.
    - **History, from git**
      
      - The `.state/` mirror and `dehydrateStateToJsonLd` arrived on 2026-09-03 with the TreeView refactor (`e4cc806`), for views only, so no node record needed it.
      - `stateDirty` followed in the 09-15 and 09-17 commits (`96ed8f9`, `0624b7d`).
      - The thread partition arrived on 2026-09-27 with the multi-agent v3.0 commit (`b58dc5d`), which added the `zoom` op with `stateDirty = true` and one `dirty = true` and did not touch the four handlers, so the thread tier inherited a flush path built for views.
  - **Not proven**
    
    - That an external change to the thread `BlockNode` file in `.state/` goes unnoticed today (not checked).
  - **Fix directions**
    
    - **Fix, agreed 2026-10-02 as three parts that fold all node-related persistence into `.state/`**
      
      - (1) any write to a thread-scoped node sets `stateDirty` (`isThreadScopedId` is already imported in the same file), so the 3-second timer and every `--flush` persist it;
      - (2) the `.state/` divergence stamps cover the thread-partitioned node classes and not only `STATE_CLASSES` (`TreeView`), so an external change to the thread `BlockNode` file there is noticed (not checked: that an external change goes unnoticed today);
      - (3) every flush path writes both mirrors from one rule.
- **`aperas resolve`'s title-ambiguity check does not filter tombstoned candidates, so a dead holder makes a live path read as ambiguous**: <a name='id/BlockNode:00CVQ0PVS0001' class='aperas-anchor aperas-id'></a> reproduced 2026-10-02: `aperas tree issues/cli.md` fails with `'cli.md' is ambiguous among: ArtifactNode:00CF2AEA78000 ("cli.md"), ArtifactNode:00CF1TZQV8000 ("cli.md")`, where the second id is a tombstoned holder, while `aperas tree issues/core.md` resolves. First seen when the thin `cli.md` docs were created. Cause, read from the code: `findChild(text)` (`node.ts:479-490`) builds its `candidates` array from `this.treeChildren` filtering only on `title !== undefined`, never on `tombstonedAt`, and `BlockNode.treeChildren` and `FolderNode.treeChildren` (`node.ts:513-515`, `1143-1145`) return `this.children ?? []` with no liveness filter at any layer above, so a tombstoned sibling with a matching title lands in both the exact-slug match and the prefix-slug fallback and can make an otherwise unique live title ambiguous. `findChild` is one shared method on `TreeNode`, called from exactly two places, `resolve.ts:116` (`aperas resolve`) and `resolveCreate.ts:164` (`aperas resolve --create-holder`), each once per deep-path segment, so one filter covers both commands, and every command that resolves a bare path (`tree`, `show`, `project`, `insert`) inherits the failure. Fix to try: filter `candidates` in `findChild` to exclude any child with `tombstonedAt` set before either slug match runs, using the same idiom as [the `diffChildren` fix](../issues/core.md#id/BlockNode:00CF1WZ4JG004) (`isLiveOld` in `reconcile.ts`) and [the dead-container fix](../issues/core.md#id/BlockNode:00CF1WZ4JG006) (`tombstoneVacuousContainers`). Workaround: resolve the live node by ID, or by a path that does not end on the ambiguous title. Not yet fixed; no coder task is open for it. Filed 2026-10-02.
- **The ApeironNgn service's resident memory climbs to about 5.8 GB over hours under heavy use, and a fresh service idles at about 1.3 GB for 3.66 MB of data**: <a name='id/BlockNode:00CVQ4Z968001' class='aperas-anchor aperas-id'></a> found 2026-10-02, in the v4.3 skill task, with two parts. Filed 2026-10-02.
  
  - **Symptom**
    
    - The old service (pid 220722, up from 16:16) reached 4.74 GB at 19:20 and 5.76 GB at 19:42, a rise of roughly 40 to 50 MB a minute over its last hour, with two threads at 100 percent CPU and almost no disk writes.
    - Its V8 heap limit is 2.1 GB, far below its resident size, so most of the memory sat outside the V8 heap.
    - A fresh service idles at 1.05 to 1.5 GB (median 1.34 GB, maximum 2.18 GB) over 379 samples and 63 minutes.
    - The whole graph on disk is 3.66 MB of JSON-LD, about 37,000 quads, so the idle service is roughly 350 times the data size at rest.
      
      - Corrected 2026-10-10: <a name='id/BlockNode:00D0X1SZ3R006' class='aperas-anchor aperas-id'></a> the quad count is 41,752 by `store.size` and the 37,000 had no recorded method; the engine costs about 0.5 KB per quad, so the store itself is not 350 times the data (see Measurements).
    - The fresh service did not grow over that hour under light use, so the climb to 5 GB needs heavier work (thread-task removals) or a long uptime that the sampler has not seen.
  - **Root cause**
    
    - **Established mechanism** (measured by the Coder in the store-size investigation, 2026-10-10)
      
      - Memory is allocated per JavaScript wrapper and per full scan, not per quad ([the scan entry](#id/BlockNode:00D0W02KPG001)).
      - A reload leaves the old store alive until an event-loop turn, each synchronous rehydrate adding a store of about 75 MB external ([the reload entry](#id/BlockNode:00D0W00YCR001)), which measures the reload hypothesis below.
      - The engine is not the cost, and the hypothesis that the store itself is that large is overturned (figures under Measurements).
    - **Suspected causes**: <a name='id/BlockNode:00D0X1SZ3R00D' class='aperas-anchor aperas-id'></a> hypotheses written 2026-10-02 as untested (the reload part is measured, see above); no scratch run has reproduced the climb to 5.8 GB under heavy use.
      
      - **The store is Oxigraph's WASM store, whose linear memory grows and never shrinks, and each reload builds a new store, so a leak in reload or removal could keep old stores alive** (hypothesis, written 2026-10-02 as untested)
        
        - A reload also builds a new `Store` and leaves the old one to the garbage collector, as [the boot and shutdown issue](#id/BlockNode:00CVQHCEW8001) describes.
      - **Each full-store scan allocates a JavaScript `Quad` per store quad, a candidate source of garbage-collector pressure and of the external-memory growth recorded here** (read, untested; from the investigation's code survey)
        
        - `allIdsOfKind`, the scan that [the removal-stall issue](#id/BlockNode:00CVNX6A3R000) charges per embedded node, allocates a JavaScript `Quad` for every store quad on each call (about 40k objects, about 140 ms).
  - **Measurements**
    
    - **Conditions** (by the Coder in the store-size investigation, 2026-10-10): <a name='id/BlockNode:00D0X1SZ40001' class='aperas-anchor aperas-id'></a> scratch processes and scratch services on copies under `/tmp`, single runs unless a count is given, machine load average 2 to 3.5, the live service not stopped or touched.
    - **The store holds 41,752 quads by `store.size`** (measured)
      
      - 29,537 come from the content mirror and 12,216 from `.state/`, one shared; 10,622 nodes, 0 dangling, 0 duplicate ids.
      - The count equals the length of a full `store.match`.
      - The live service logged 41,246 at its boot, so the live store does hold the thread partition.
      - The earlier 37,000 and 39,600 had no recorded method.
      - A count of about 50,610 derived from the mirror overshoots, because `add()` was called 46,519 times and 4,767 of those were duplicates (every `parent` quad is emitted twice, from the child's `parent` field and from the parent's `children` array, `store.ts` lines 95 and 112).
    - **The engine is not the cost** (measured)
      
      - Bare Oxigraph 0.5.11 (Node CJS build, wasm, in memory) costs about 0.47 KB resident and 0.59 KB external per quad when bulk-loaded and about 1.3 KB external per quad with per-quad `add` (rssAnon 59 to 196 MB for 10k to 100k quads), so 41.7k quads are 20 to 55 MB.
      - The idle 1.3 GB is about 26 to 36 KB per quad, so the hypothesis that the store itself is that large does not hold.
    - **Where the memory goes** (measured)
      
      - After `rehydrateStore` alone rss was 273 MB over a 119 MB baseline (heapUsed 60 MB, external 81 MB), about 3.7 KB per quad including parse garbage, and the JSON parse took 28 ms.
      - After the boot sweeps and the link sweep rss was 572 MB with external 282 MB, the V8 heap back to about 54 MB after a `gc()` and an event-loop turn, and external never shrinking.
    - **A reload leaves the old store alive until an event-loop turn** (measured, [the reload entry](#id/BlockNode:00D0W00YCR001))
      
      - Each synchronous rehydrate adds a store of about 75 MB external, and a reload-style cycle reached rss 1.73 GB by its fourth run.
      - A dirty reload on a scratch service reached 1.26 GB.
    - **The live service's high-water mark is 1.66 GB** (VmHWM, read from `/proc`)
    - **Each full-store scan retained about 9 MB of heap and 21 MB of external memory until the event loop turned, with resident size at 2.0 GB after 60 scans of the heaviest task** (the removal measurement of 2026-10-02: seven bounded runs on `/tmp` copies by the Coder, nothing written to the real graph or the live service; its figures are in [the removal-stall issue](#id/BlockNode:00CVNX6A3R000))
  - **Not proven**
    
    - Not known whether the climb and the stall share a cause.
    - The live service's own phases are not measured (they would need the user's approval to stop it).
    - The climb to 5.8 GB under heavy use is not measured: no scratch run reproduced it.
  - **Fix directions**
    
    - Measurements still to take: <a name='id/BlockNode:00D0X1SZ4000Q' class='aperas-anchor aperas-id'></a> have the service report `process.memoryUsage()` (heap used, external, array buffers) and the store's own size, and start it with `--heapsnapshot-signal=SIGUSR2` so a snapshot can be taken when the process is large, since the external sampler cannot see inside it.
    - The measurements that would tell these hypotheses apart are listed in [the no-coverage issue](#id/BlockNode:00CVQHD7CR001).
  - **Workaround**
    
    - A restarted service returns to about 1.3 GB, but a restart is for the user to approve.
  - **Related**
    
    - [The thread-task `aperas remove` entry](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X1SZ4000W' class='aperas-anchor aperas-id'></a> the stall there was recorded at 3.4 to 4.6 GB resident, and it charges the full-store scan per embedded node.
    - [The `npm run verify` entry](#id/BlockNode:00CJ0202MG001) and [its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000): <a name='id/BlockNode:00D0X1SZ4000X' class='aperas-anchor aperas-id'></a> the slowdown there put oxigraph's WASM footprint at 850 MB to 1 GB and ruled it out as the cause of the slowdown, which does not rule it out as a size problem.
    - [The boot and shutdown issue](#id/BlockNode:00CVQHCEW8001): <a name='id/BlockNode:00D0X1SZ4000Y' class='aperas-anchor aperas-id'></a> a reload builds a new `Store` and leaves the old one to the garbage collector.
    - [The no-coverage issue](#id/BlockNode:00CVQHD7CR001): <a name='id/BlockNode:00D0X1SZ4000Z' class='aperas-anchor aperas-id'></a> the service has no timing, memory or load-test coverage.
    - [The scan entry](#id/BlockNode:00D0W02KPG001): <a name='id/BlockNode:00D0X1SZ40010' class='aperas-anchor aperas-id'></a> full-store scans materialize every quad as a JavaScript object.
    - [The scans issue's Fix directions](#id/BlockNode:00D0X65RB8008): <a name='id/BlockNode:00D0Y9MJAR001' class='aperas-anchor aperas-id'></a> the candidate layers for the full-store scans are listed there and are not repeated here.
    - [The reload entry](#id/BlockNode:00D0W00YCR001): <a name='id/BlockNode:00D0X1SZ40011' class='aperas-anchor aperas-id'></a> a reload leaves the old store alive until an event-loop turn runs.
    - [The design-gap entry](#id/BlockNode:00D0W07DRR000): <a name='id/BlockNode:00D0X1SZ40012' class='aperas-anchor aperas-id'></a> the design gap behind these figures; `design/` has no document for the store, hydration or the service lifecycle.
- **Every `remove`, `insert`, `update` and `retype` re-parses the whole artifact with remark before and after the operation, about 1.7 to 2.5 ms a block, so a write to a large thread file costs seconds before its own work**: <a name='id/BlockNode:00CVQHBP0R001' class='aperas-anchor aperas-id'></a> found 2026-10-02 in the slow-service investigation's code survey of the service. Filed 2026-10-02.
  
  - **Symptom**
    
    - Because the service runs one operation at a time, every second a write spends in the sweeps is also queue wait for every other client, which is the mechanism in [the spurious "not running" issue](#id/BlockNode:00CVMPABY8001).
  - **Root cause**
    
    - Read from `service.ts`: <a name='id/BlockNode:00D0X8TTAR001' class='aperas-anchor aperas-id'></a> each of the four handlers calls `checkArtifactLinkIntegrity(store, artifactId)` before the operation (`artifactForRef`, then the pre-check, then the `runX` call) and `withLinkCheck` calls it again after, over the whole owning artifact and not only the blocks the operation touched.
    - Each sweep (`collectAllBlockNodes`, then `sweepBlocks`) walks every live block, reads its `text`, parses the whole text with the remark processor (`collectLinkCodesFromText`, no cache).
    - For each block that has link text it reads `.links`, computes `toPath()` and calls `resolveOneCode` per link.
  - **Measurements**
    
    - Measured in a scratch process: <a name='id/BlockNode:00D0X8TTAR005' class='aperas-anchor aperas-id'></a> 638 to 932 ms for `.threads/coder.md` (367 live blocks, 65 links), which is about 1.7 to 2.5 ms per live block, so about 1.3 to 1.9 s for the two sweeps.
    - For `.threads/grapher.md` (767 blocks, 487 links) the same rate gives about 1.3 to 1.9 s a sweep, derived and not measured, because the in-memory run on that file did not finish in 100 s.
  - **Not proven**
    
    - Derived, not measured: <a name='id/BlockNode:00D0X8TTAR008' class='aperas-anchor aperas-id'></a> the sweeps cost seconds, so on their own they do not reach the minutes of [the removal stall](#id/BlockNode:00CVNX6A3R000); they are one of three cost centres of a `remove` there.
    - Whether the per-write sweep slows the same way in the long-lived service as the corpus sweep did in a long process (see the earlier record under Related) is untested.
  - **Fix directions**
    
    - Fix directions: <a name='id/BlockNode:00D0X8TTAR00B' class='aperas-anchor aperas-id'></a> none decided.
    - Candidates, the grapher's reading and none tried: <a name='id/BlockNode:00D0X8TTAR00C' class='aperas-anchor aperas-id'></a>
      
      - Parse a block's text once and cache the result by that text, so unchanged blocks are not re-parsed.
      - Check after the operation only the blocks it touched and the links that point at them.
      - Keep the pre-check only where it tells something the post-check cannot.
    - The first measurement is to time the sweep alone on a thread artifact and against block count (item 3 of the investigation's first measurements, which needs per-operation timing the service does not yet have).
  - **Related**
    
    - Earlier record: <a name='id/BlockNode:00D0X8TTAR00J' class='aperas-anchor aperas-id'></a> [the `npm run verify` entry](#id/BlockNode:00CJ0202MG001) names the same kind of operation, `checkLinkIntegrity`'s corpus sweep, as the one that went from low hundreds of milliseconds fresh to 12 to 55 seconds late in a long process.
    - [The boot and shutdown issue](#id/BlockNode:00CVQHCEW8001), whose startup and shutdown sweeps share the full-store scan cost.
    - [The no-coverage issue](#id/BlockNode:00CVQHD7CR001), which lists the measurements that would time the sweep.
- **Boot and shutdown cost grows with the tombstones and sits close to the client's 5 s ready wait and 10 s stop wait**: <a name='id/BlockNode:00CVQHCEW8001' class='aperas-anchor aperas-id'></a> found 2026-10-02 in the slow-service investigation's code survey of the service. Filed 2026-10-02.
  
  - **Symptom**
    
    - `waitForReady` in `serviceClient.ts` polls `ping()` every 100 ms for 5 s (read), and `stopIfRunning` in `kgService.ts` gives the process only 10 s from the `kill`.
    - About 1 s of rehydrate and about 3.5 s of startup collection, plus the `tsx` compile, sit close to the 5 s ready wait.
    - A service that misses the ready wait keeps starting detached while `aperas service start` reports "did not become ready in time", and the lock stays `starting` for a 10 s grace (read).
    - The 5 s ready wait and the 10 s stop wait are therefore both shorter than the work they wait for on a dirty or just-started service.
    - The shutdown limit fits "didn't stop within 10s of SIGTERM" in [the removal-stall issue](#id/BlockNode:00CVNX6A3R000).
  - **Root cause**
    
    - **Boot and shutdown do their sweeps and flushes synchronously, and the cost grows with the tombstones** (read from `service.ts`, `serviceClient.ts` and `kgService.ts`; the figures are under Measurements)
      
      - **Boot** (read from `service.ts`) runs entirely synchronously before the socket exists, in this order:
        
        - The code fingerprint, the token, `rehydrateStore` and `stampAll` of both mirrors.
        - The startup garbage collection: <a name='id/BlockNode:00D0X1HTFG00B' class='aperas-anchor aperas-id'></a> `tombstoneVacuousContainers`, `pruneUnreachableTombstones`, `pruneStaleUnfolds`, then both flushes if anything changed.
        - The creation of the 10 s and 3 s flush timers and the 30 minute idle timer, then `listen`.
        - Only in the `listen` callback does `markReady` flip the lock to ready, and the startup link sweep runs after that.
      - **Shutdown** (read): <a name='id/BlockNode:00D0X1HTFG00E' class='aperas-anchor aperas-id'></a> the SIGTERM handler runs in JavaScript, so it cannot run while an operation is in progress, and its body queues behind everything already waiting.
      - Shutdown re-runs the three sweeps and both flushes.
      - **The cost grows with the tombstones**: <a name='id/BlockNode:00D0X1HTFG00G' class='aperas-anchor aperas-id'></a> the next reload, startup or shutdown prunes each unreachable tombstoned block with the same full-store scan as in [the removal-stall issue](#id/BlockNode:00CVNX6A3R000), about 140 ms a node (measured per scan).
        
        - Removing a 42-block task therefore adds about 6 s to a later start or stop (derived, 42 times 140 ms, not measured end to end), on top of the fixed 2.3 s and 1.2 s.
      - **A reload** (any operation carrying `--reload`) runs all of this plus `rehydrateStore()` into a new `Store`, two `stampAll`s and a corpus link sweep in one synchronous run.
        
        - The old store is left to the garbage collector while Oxigraph's WASM linear memory never shrinks (read; relevant to [the memory issue](#id/BlockNode:00CVQ4Z968001), untested there).
  - **Measurements**
    
    - **Boot phases on a scratch copy** (measured): <a name='id/BlockNode:00D0X1HTFG00N' class='aperas-anchor aperas-id'></a> rehydrate about 1.06 s, `tombstoneVacuousContainers` about 1.2 s and `pruneUnreachableTombstones` about 2.3 s even with nothing to prune.
    - **Shutdown on an idle copy took about 3.5 s** (measured) for the three sweeps and both flushes, before any per-node hard-delete work.
    - **The startup link sweep takes 2 to 18 s, not 0.6 s** (measured; corrected 2026-10-10)
      
      - The earlier figure was about 0.6 s, measured on a scratch copy.
      - On a scratch service the link sweep took 2.06 s after an event-loop turn and 17.7 s run straight after the boot sweeps, so 2 to 18 s (phases below).
    - **Conditions of the measurements below** (by the Coder in the store-size investigation, 2026-10-10): a scratch service with its own run directory and port, copies of the data under `/tmp`, single runs unless a count is given, machine load average 2 to 3.5; the live service not touched.
    - **Start: the lock turned ready at 5.28 to 5.77 s in 6 of 6 cold starts** (measured 2026-10-10)
      
      - It is made of about 1 s of node and `tsx` start, 1.1 s of `rehydrateStore` and 3.2 s of boot sweeps (`Rehydrated` is logged about 3.3 s before the lock turns ready).
    - **The CLI printed "did not become ready in time" at 5.42 to 5.76 s in all 6, although the service was up 0 to 60 ms later** (measured 2026-10-10)
    - **After ready, every command was refused with "No ApeironNgn service running" for 19.5 to 23.0 s** (measured 2026-10-10)
      
      - The cause is that the startup link sweep holds the event loop and the 300 ms ping times out ([the start entry](#id/BlockNode:00D0W05P08001)).
    - **The synchronous boot takes 5.3 to 5.8 s to ready and the link sweep a further 2 to 18 s, depending on whether an event-loop turn separates the phases** (measured 2026-10-10, [the scan entry](#id/BlockNode:00D0W02KPG001))
    - **Stop: 0.6 s after SIGTERM when the service is settled and clean** (measured 2026-10-10; 1.96 s wall with CLI start)
    - **Stop: 12.5 s (2 of 2) after any `unfold`, `fold` or `zoom --view` has marked the service dirty** (measured 2026-10-10)
      
      - The shutdown sweeps are about 1.6 s and the two flushes the rest.
      - The same flushes ran 1.1 s and 1.5 s when the store had had an event-loop turn since the sweeps and 8 to 17 s each when it had not.
      - The client waits 10 s, so `restart` then errors out at 10 s and starts nothing ([the restart entry](#id/BlockNode:00D0W044DG001)).
    - **Stop: 18 to 21 s when SIGTERM arrives during the 17 to 20 s startup link sweep** (measured 2026-10-10)
    - **A `reload` after a mutation took 74 s and 119 s on two scratch services, against 4.4 s clean** (measured 2026-10-10, [the reload entry](#id/BlockNode:00D0W00YCR001))
      
      - The old store left to the garbage collector, which Root cause gives as read, is measured there.
  - **Not proven**
    
    - That the shutdown limit is the cause of the "didn't stop within 10s of SIGTERM" in [the removal-stall issue](#id/BlockNode:00CVNX6A3R000): consistent with it, not shown to be the cause (shown 2026-10-10 for a service marked dirty by a view op: the stop took 12.5 s).
    - The cost of `unfold`, `fold` and `zoom` is read and not measured: <a name='id/BlockNode:00D0X1HTFR00B' class='aperas-anchor aperas-id'></a> each sets both dirty flags, so each causes a full content dehydrate within 10 s and a state dehydrate within 3 s.
  - **Fix directions**: <a name='id/BlockNode:00D0X1HTFR00C' class='aperas-anchor aperas-id'></a> none decided.
    
    - The investigation's first steps are the ones that make the figures visible: one timestamped line per boot phase with its duration, the client logging its poll count and elapsed time when the wait fails, and sweep cost measured against tombstone count and dehydrate time at current node counts (measurements 6, 7 and 8 of the first measurements).
    - Whether the sweeps can run after the socket exists, or the waits can grow with the work, is a design question not yet raised; `design/` has no document for the service lifecycle ([the design-gap entry](#id/BlockNode:00D0W07DRR000)).
  - **Related**
    
    - [The removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X1HTFR00G' class='aperas-anchor aperas-id'></a> the same full-store scan per node, and the failed stop in its Symptom.
    - [The memory issue](#id/BlockNode:00CVQ4Z968001): <a name='id/BlockNode:00D0X1HTFR00H' class='aperas-anchor aperas-id'></a> the old store left to the garbage collector on a reload is relevant to it, untested there.
    - [The spurious "not running" issue](#id/BlockNode:00CVMPABY8001): <a name='id/BlockNode:00D0X1HTFR00J' class='aperas-anchor aperas-id'></a> a boot of 4 to 5 s against the client's 5 s wait is one way a start reads as failed.
    - [The whole-artifact re-parse issue](#id/BlockNode:00CVQHBP0R001): <a name='id/BlockNode:00D0X1HTFR00K' class='aperas-anchor aperas-id'></a> every write re-parses the whole artifact before and after the operation.
    - [The no-coverage issue](#id/BlockNode:00CVQHD7CR001): <a name='id/BlockNode:00D0X1HTFR00M' class='aperas-anchor aperas-id'></a> the service has no timing, memory or load-test coverage, and it lists the timestamped boot log.
    - [The start entry](#id/BlockNode:00D0W05P08001): <a name='id/BlockNode:00D0X1HTFR00N' class='aperas-anchor aperas-id'></a> `aperas service start` prints "did not become ready in time" at 5 s although the lock turns ready at 5.3 to 5.8 s.
    - [The restart entry](#id/BlockNode:00D0W044DG001): <a name='id/BlockNode:00D0X1HTFR00P' class='aperas-anchor aperas-id'></a> `aperas service restart` errors out after 10 s and starts nothing whenever the service has been marked dirty.
    - [The reload entry](#id/BlockNode:00D0W00YCR001): <a name='id/BlockNode:00D0X1HTFR00Q' class='aperas-anchor aperas-id'></a> a reload leaves the old store alive until an event-loop turn runs, and a reload after a mutation takes 74 to 119 s.
    - [The scan entry](#id/BlockNode:00D0W02KPG001): <a name='id/BlockNode:00D0X1HTFR00R' class='aperas-anchor aperas-id'></a> full-store scans materialize every quad as a JavaScript object.
    - [The design-gap entry](#id/BlockNode:00D0W07DRR000): <a name='id/BlockNode:00D0X1HTFR00S' class='aperas-anchor aperas-id'></a> `design/` has no document for the store, hydration or the service lifecycle.
- **The service has no timing, memory or load-test coverage, and its one durable log holds only startup lines**: <a name='id/BlockNode:00CVQHD7CR001' class='aperas-anchor aperas-id'></a> found 2026-10-02 in the slow-service investigation's code survey of the service. Filed 2026-10-02.
  
  - **Root cause**
    
    - **In the service** (read)
      
      - There is no timing or memory logging.
      - `APERAS_DEBUG_TIMING` output is lost because `spawnService` starts the service with `stdio: 'ignore'`.
      - `logService` (`service.log`) is the only durable channel and holds startup lines only, so a stall of 5.4 or 12 minutes left no line.
    - **In the tests and scripts** (read)
      
      - `verify.ts` (749 lines) and `verifyExtended.ts` (757 lines) run in-process against a `rehydrateStore()` copy, never import `service.ts` or `serviceClient.ts`, never spawn the service, and never call `runRemove` or `withLinkCheck`.
      - `verifySupport.ts#instrumentStepTiming`, a `console.log` wrapper that times each "N. Testing..." step, is the only timing harness and produced the record in [the `npm run verify` entry](#id/BlockNode:00CJ0202MG001).
      - `apeironNgnSmokeTest.ts` checks rehydrate and field access only.
      - `packages/web/devApiServer.ts` is one more concurrent client that calls `request()` with no timeout but is not a load test.
      - There are no concurrent-client, latency or long-uptime scripts, and no test of the timers, `reloadStore`, `shutdown` or the SIGTERM path.
    - **The external sampler**, a Python script in a session scratch area outside the repo, has these gaps (read from the script and its CSV)
      
      - The lock path (`/run/user/1000/aperas/apeironngn.lock`), the probe node (`BlockNode:00CE8XWZK0000`, which a future prune or another graph can remove, turning every probe into a false failure) and `aperas` on `PATH` are hard-coded.
      - The probe is a full `aperas show` client, so each probe time includes a `tsx` client start (541 ms on the first row) and a 60 s cadence cannot resolve a stall of seconds.
      - `probe()` keeps only whether `"@id"` appears in stdout and discards stderr and the exit code, so the 300 ms ping failure, a request error and the 20 s timeout all read as a failed probe, which is exactly what the 11 failed probes need to be told apart by.
      - **It has no**: <a name='id/BlockNode:00D0X5JQER00G' class='aperas-anchor aperas-id'></a>
        
        - raw ping over the unix socket at 1 s cadence,
        - separate main-thread and garbage-collector-thread columns,
        - `VmHWM`,
        - `/proc/<pid>/io` write bytes,
        - mirror-file size or modification time (flush cadence would be visible for free),
        - join with `service.log` by time,
        - stall durations or memory slope in its report,
        - metadata row,
        - test.
      - It records only a client count and not the verbs of the running `aperas` commands.
  - **Fix directions**: <a name='id/BlockNode:00D0X5JQF0000' class='aperas-anchor aperas-id'></a> none decided; from the investigation's Freeflow and the orchestrator's recommendations.
    
    - **Instrumentation** in a new `apeironNgn/serviceDiagnostics.ts` behind one environment switch read by `spawnService` (which already copies `process.env`), all through `logService`:
      
      - an event-loop delay histogram,
      - `process.memoryUsage()` and heap statistics every 30 to 60 s,
      - one timestamped line per boot phase,
      - per-operation timings split into queue wait, pre-check, operation, flush and post-check, for operations over about 250 ms.
    - **Limits** (read, unverified where marked)
      
      - The histogram records only when the loop turns, so a 5-minute stall appears as one sample after it ends, and a worker-thread watchdog on a `SharedArrayBuffer` heartbeat would see it live (not built or tried).
      - `--heapsnapshot-signal=SIGUSR2` can reach the service through `NODE_OPTIONS` with no code change but blocks the loop on a large process, needs about that much memory again, and misses the WASM memory (the V8 heap is about 2.1 GB against up to 5.8 GB resident).
      - `--cpu-prof` writes only at exit and cannot capture a stuck or killed process.
      - For a live stall an inspector or `perf` is the candidate (unverified).
    - **The sampler** moves into the repo as Python under `monorepo/packages/cli/diagnostics/` with a `svc:sample` script, adds a raw-socket ping each second that keeps the failure text, and drops the one-minute client probe.
    - **The first measurements, in order**: <a name='id/BlockNode:00D0X5JQF000C' class='aperas-anchor aperas-id'></a>
      
      1. Event-loop lag and `process.memoryUsage()` logged by the service.
      2. Per-operation timing.
      3. One controlled `remove` on a fresh service against the same after a long uptime, with the link sweep timed alone.
      4. A CPU profile during a stall.
      5. A heap snapshot at idle and when large.
      6. A timestamped boot log and ping timing.
      7. Sweep cost against tombstone count.
      8. Dehydrate time at current node counts.
  - **Related**
    
    - This is the missing ground for [the spurious "not running" issue](#id/BlockNode:00CVMPABY8001), [the removal stall](#id/BlockNode:00CVNX6A3R000) and [the memory issue](#id/BlockNode:00CVQ4Z968001), whose mechanisms rest on code reading and one reproduction each.
    - [The whole-artifact re-parse issue](#id/BlockNode:00CVQHBP0R001) and [the boot and shutdown issue](#id/BlockNode:00CVQHCEW8001): <a name='id/BlockNode:00D0X5JQF000Q' class='aperas-anchor aperas-id'></a> the two cost centres other than the removal scan whose figures are measured only in a scratch process.
- **A reload leaves the old store alive until an event-loop turn runs, and a reload after a mutation takes 74 to 119 s**: <a name='id/BlockNode:00D0W00YCR001' class='aperas-anchor aperas-id'></a> measured 2026-10-10 by the Coder in the store-size investigation. Filed 2026-10-10.
  
  - **Symptom**
    
    - `aperas reload` after a dirty `unfold` took 119.05 s and 74.43 s wall on two fresh scratch services (rss afterwards 1.26 GB, VmHWM 1.04 GB).
    - A clean `aperas reload` took 4.41 s and 4.61 s on a warm scratch service.
    - A third read right after a clean reload exited 1 at 0.76 s with "No ApeironNgn service running" and its message was not captured.
  - **Root cause**
    
    - The old store is dropped by assignment, as `service.ts` line 379 does, and stays alive until an event-loop turn runs (read from the source; the effect is measured below).
      
      - Every term of every added quad is a wasm-bindgen wrapper registered in a `FinalizationRegistry` (`oxigraph/node.js` from line 1212, `vocab.ts` lines 58, 74 and 93).
      - Its callbacks run only on a macro-task turn, so a synchronous run never lets the old store go.
  - **Measurements**
    
    - **Conditions** (by the Coder in the store-size investigation, 2026-10-10): <a name='id/BlockNode:00D0X8XR9000A' class='aperas-anchor aperas-id'></a> scratch node processes and scratch services with their own run directory and port, on copies of the store under `/tmp`; single runs unless a count is given, at a machine load average of 2 to 3.5, the live service untouched.
    - **Repeated `rehydrateStore` with the old store dropped by assignment, as `service.ts` line 379 does**
      
      - With no event-loop turn between runs, external memory grew 81, 157, 232, 307, 382, 457 MB over six runs (one whole store, about 75 MB, per run), rss 275 to 812 MB, and run time rose 1.2, 8.0, 11.2, 20.0, 20.5, 23.2 s.
      - A forced `global.gc()` after each run freed none of it (identical external, heapUsed only 12 to 23 MB lower).
      - With a 200 ms event-loop turn around two `gc()` calls external was 81 MB and then flat at 104 MB, rss about 300 MB and a run about 1 s.
      - Calling `store.free()` on the old store changed nothing beyond that.
    - **The whole reload-style cycle (rehydrate, three sweeps, link sweep)**
      
      - With no turns between runs it took 26.0, 64.5, 97.7 and 225.1 s with rss 566, 971, 1,372 and 1,731 MB and external 282, 560, 837 and 1,115 MB.
      - Run 5 was killed with `kill -9` after 647 s, because a tight synchronous loop ignores `kill`, so it has no figures.
      - With an event-loop turn and a `gc()` between runs it took 22.7, 14.5, 18.8, 4.0 and 4.0 s with external 282, 297, 312, 312 and 312 MB.
    - **The dirty reload replicated in one process as one synchronous request after a settled boot (`m5.ts`)**
      
      - Shutdown sweeps 1,570 ms, content flush 8,323 ms, state flush 10,472 ms, `rehydrateStore` with the old store still referenced 29,630 ms, link sweep 38,506 ms.
      - Total 88,504 ms, end rss 999 MB, external 576 MB.
    - **The same phases with a 300 ms event-loop turn between them (`m5b.ts`)**
      
      - 1,471, 1,145, 1,484, 903 and 1,752 ms, total 8,080 ms including the four turns, end rss 808 MB, external 278 MB.
      - The same code costs 8 s as separate event-loop turns and 88 s as one synchronous request.
    - **The live service's high-water mark** is 1.66 GB (VmHWM, read from `/proc` by the Coder).
  - **Not proven**
    
    - Not measured: <a name='id/BlockNode:00D0X8XR9R00E' class='aperas-anchor aperas-id'></a> a reload on the live service (it would need the user's approval to stop it).
    - The same cycle after the scans are changed (not measured).
  - **Fix directions**
    
    - No fix has been tried.
    - [The scans issue's Fix directions](#id/BlockNode:00D0X65RB8008): <a name='id/BlockNode:00D0Y9NHJ0001' class='aperas-anchor aperas-id'></a> the candidate layers for the scans in the reload cycle are listed there and are not repeated here.
  - **Related**
    
    - [The boot and shutdown issue](#id/BlockNode:00CVQHCEW8001): <a name='id/BlockNode:00D0X8XR9R00K' class='aperas-anchor aperas-id'></a> this measures what it described as the old store left to the garbage collector (read, untested there); it is extended and links here.
    - [The memory issue](#id/BlockNode:00CVQ4Z968001): <a name='id/BlockNode:00D0X8XR9R00M' class='aperas-anchor aperas-id'></a> this measures the hypothesis there that a reload could keep old stores alive; it is extended and links here, and this entry holds the measurement and the 74 to 119 s reload.
- **Full-store scans materialize every quad as a JavaScript object, and the service's memory and time follow the scans and the wrappers they leave, not the 41.7k quads**: <a name='id/BlockNode:00D0W02KPG001' class='aperas-anchor aperas-id'></a> measured 2026-10-10 by the Coder in the store-size investigation. Filed 2026-10-10.
  
  - **Root cause**
    
    - **The scans** (read from the source)
      
      - `allIdsOfKind` (`dehydrate.ts` lines 49 to 58) does `store.match(null, null, null, null)` and reads `q.subject` on each of the 41.7k quads.
      - It is called by: <a name='id/BlockNode:00D0X65RA0004' class='aperas-anchor aperas-id'></a>
        
        - `tombstoneVacuousContainers` (`node.ts` lines 2230 to 2248, once per fixed-point loop, so at least once).
        - `pruneUnreachableTombstones` (lines 2183 to 2214: <a name='id/BlockNode:00D0X65RA0006' class='aperas-anchor aperas-id'></a> 2 calls for the mark roots and 3 for the sweep).
        - `pruneStaleUnfolds` (line 2087, 1 call).
        - `checkLinkIntegrity` (`linkIntegrity.ts` lines 85 and 86, 1 call).
      - Together that is at least 8 scans in boot, and 4 scans per flush (`dehydrate.ts` lines 111 to 116 and 149 to 168).
      - Further matches are made by `wrap` (`node.ts` line 2144, a new object plus `Object.seal` per node), `readField` (lines 156 to 162, one `store.match` per field read) and `childrenOf` (lines 73 to 84, one match plus one more per child).
      - The second pass of `rehydrateStore` (`store.ts` lines 154 to 158) scans the whole store for dangling references (97 ms).
    - **The wrappers the scans leave** (read from the source)
      
      - `store.match` returns an array of `Quad` wrappers (`oxigraph/node.js` lines 611 to 620, then `.slice()`), so each scan creates 41.7k quad wrappers plus the term wrappers.
      - The wrappers are released only after a garbage collection and a macro-task turn.
      - WASM linear memory, once grown, is never returned (the comments at `node.ts` lines 2166 to 2169 say "WASM's grow-only memory").
  - **Measurements**
    
    - **Conditions** (by the Coder in the store-size investigation, 2026-10-10): <a name='id/BlockNode:00D0X65RB0005' class='aperas-anchor aperas-id'></a> same conditions as [the reload entry](#id/BlockNode:00D0W00YCR001) above, scratch processes and services on copies under `/tmp`, single runs, load average 2 to 3.5.
    - **The effect of the scans on one boot** (measured 2026-10-10; a process with baseline rss 119 MB, heapUsed 13, external 5)
      
      - After `rehydrateStore` alone: <a name='id/BlockNode:00D0X65RB0007' class='aperas-anchor aperas-id'></a> rss 273 MB (heapUsed 60, external 81).
      - After `tombstoneVacuousContainers`: <a name='id/BlockNode:00D0X65RB0008' class='aperas-anchor aperas-id'></a> rss 314 (external 110).
      - After `pruneUnreachableTombstones`: <a name='id/BlockNode:00D0X65RB0009' class='aperas-anchor aperas-id'></a> rss 481 (external 221).
      - After `pruneStaleUnfolds`: <a name='id/BlockNode:00D0X65RB000A' class='aperas-anchor aperas-id'></a> rss 511 (external 241).
      - After `checkLinkIntegrity` run at once: <a name='id/BlockNode:00D0X65RB000B' class='aperas-anchor aperas-id'></a> rss 572 (external 282).
      - After `gc()` and an event-loop turn the V8 heap fell to about 54 MB while external stayed at 282 and rss at 572.
    - **The link sweep took 17,681 ms run straight after the boot sweeps and 2,060 ms after an event-loop turn** (measured 2026-10-10)
    - **The shutdown path** (`m4.ts`), with no turn since boot (measured 2026-10-10)
      
      - Shutdown sweeps 1,590 ms, `dehydrateToJsonLd` 13,818 ms, `dehydrateStateToJsonLd` 11,790 ms.
      - A cold variant without the link sweep: <a name='id/BlockNode:00D0X65RB000G' class='aperas-anchor aperas-id'></a> 1,598, 16,693 and 12,840 ms.
      - A second pass over the same store: <a name='id/BlockNode:00D0X65RB8000' class='aperas-anchor aperas-id'></a> 23,662 and 24,042 ms.
        
        - Of these, `allIdsOfKind(BlockNode)` was 271 ms and `isThreadScopedId` 4,748 times 5,639 ms.
        - `serializeDoc` 1,307 times (thread subset) took 6,294 ms and 3,441 times (content subset) 16,404 ms.
      - The same flushes ran 1.1 s and 1.5 s when the store had had an event-loop turn since the sweeps, and 8 to 17 s each when it had not.
    - **The cost is superlinear in the number of live wasm-bound objects and not in the quad count** (measured 2026-10-10)
      
      - On the bare engine with per-quad `store.add(quad(...))` (what Aperas does), 50k quads had 19 Mark-Compacts totalling 585 ms and 100k had 128 totalling 4,684 ms, with the add cost per quad 3 to 4 times higher.
      - Bulk `store.load` of the same 100k quads took 0.29 s.
      - The engine alone is not slow at this size (see [the memory issue](#id/BlockNode:00CVQ4Z968001) for its per-quad cost).
  - **Fix directions**
    
    - The object-bound `removeDanglingUnfolds` landed in commit `0a7a226` and ran in the live service: it replaces the scan of every quad, made once per embedded node removed, with one `store.match` on the predicate `unfolds` and the deleted id as object. Result (2026-10-11, one removal in the live service): a task of 164 live blocks and 101 embedded `Link` nodes was removed in 3.7 s with no stall, the tree then showed every other task intact, and `aperas check-links` scanned 6,549 live blocks with 0 discrepancies. Before it, removals of 42 and 31 blocks stalled the service for 5.4 and 12 minutes, and a scratch removal of 34 embedded nodes took 21 s with 34 full scans. On a copy of the real store the old form took 512.8 ms per deleted id and the object-bound form 0.015 ms. It covers every field of a `TreeView` that holds an unfolded id and exists in code, which is `unfolds` alone. The `free()` item below and the layers after it are not applied.
    - **`free()` on the quads and the terms read from them** (measured 2026-10-11, one sample; the first remedy for the scans in the service, being applied as one read helper)
      
      - **Measured**: <a name='id/BlockNode:00D1DP5GG0002' class='aperas-anchor aperas-id'></a> ten full-store scans in one tick, baseline external memory 90.7 MB. Left to the finalizer: 223 ms a scan and 253.9 MB external. `q.free()` on each quad: 162 ms a scan and 115.8 MB external. `q.free()` plus the subject term freed: 109 ms a scan and 101.3 MB external, with no growth after the first scan. Resident set size across the three variants: 499, 351 and 289 MB. What had no effect was a forced `gc()` without a turn, not `free()`.
      - **Caveats**: <a name='id/BlockNode:00D1DP5GG8000' class='aperas-anchor aperas-id'></a> one sample, ten scans in one tick; the first scan's +10.6 MB of wasm memory is never returned; a term read from a quad (`q.subject`) is a separate object with its own handle that must be freed too; `allIdsOfKind` reads the subject twice per quad.
      - **Plan**: <a name='id/BlockNode:00D1DP5GG8001' class='aperas-anchor aperas-id'></a> `free()` is the first remedy for the scans in the service, before Layer 1 (bound matches), Layer 2 (the index) and the pause, which stays the safety net. It is not decided and not tried in the service, and a sample of one is not yet a measurement of the service.
      - **Map of the store reads for the change** (the Coder's survey of 2026-10-11; read, not edited; line numbers are in `monorepo/packages`; "bound" means the subject, predicate or object is given; "args" are the `nodeIri`/`predIri`/`encodeLiteral` objects made fresh by every call and never freed)
        
        - **Sites, by file**
          
          - **Full scans** (`match(null, null, null, null)`): <a name='id/BlockNode:00D1GCR1XR003' class='aperas-anchor aperas-id'></a> `allIdsOfKind`, `core/.../dehydrate.ts:49-59`, makes per quad the `Quad` and `q.subject` read twice (`termType` at 52, `value` at 53), 3 wasm objects, about 176k per call here, last used at 53, returns `string[]`. Callers, each paying the whole scan: `folders.ts:21`, `artifacts.ts:200`, `dehydrate.ts:136,161,168` (once per kind per flush), `kgTrack.ts:82,92,104`, `kgProfile.ts:65,111`, `linkIntegrity.ts:112`, `node.ts:985,2094,2201,2209,2247` (`tombstoneVacuousContainers` repeats it in a loop until nothing changes), `verifyDanglingUnfolds.ts:24`. The second pass of `rehydrateStore`, `store.ts:154-159`, is a full scan too: the `Quad` and `q.object` at 155 and 157, 3 objects, output a `Set<string>`.
          - **Field reads**: <a name='id/BlockNode:00D1GCR1XR004' class='aperas-anchor aperas-id'></a> `readField` and `decodeTerm`, `node.ts:149-162`, reached by every field read through `defineAccessors` (`node.ts:1329-1337`); bound subject and predicate; per quad the `Quad`, `m.object` at 150 and, for a literal, `decodeLiteral` (`vocab.ts:99-104`) takes `term.datatype`, one more `NamedNode`. The hottest site in the program. `decodeField`, `dehydrate.ts:75-95`, is the same read plus recursion into `serializeDoc` for `embed` (82); `serializeDoc` calls it for every field of every node on every flush.
          - **Child reads**: <a name='id/BlockNode:00D1GCR1XR005' class='aperas-anchor aperas-id'></a> `childrenOf`, `node.ts:73-83`, a match bound on the object (`PARENT_PRED`, `nodeIri(id)`), then per child a bound match with `nodeIri(childId)`, reading `m.subject.value` and `idxMatches[0].object` twice; the same shape in `insertOrderedChild` (`node.ts:119-125`) and `orderedChildIds` (`dehydrate.ts:63-73`).
          - **Other bound reads**: <a name='id/BlockNode:00D1GCR1XR006' class='aperas-anchor aperas-id'></a> `nodeExists` (`vocab.ts:65-67`, only `.length`, 20 call sites); `ownerOfLink` (`node.ts:1423-1424`); `findProfileByHandle` and `findTreeViewByName` (`node.ts:2040,2050`); `backlinks` (`node.ts:2161`; callers `kgBacklinks.ts:32`, `kgProfile.ts:59,69`, `node.ts:1789,2266`, `apeironNgnSmokeTest.ts:103`); `findByExactPath` (`tree.ts:19-22`), `findLiveByKindAndPath` (`artifacts.ts:187-193`), `pathOf` (`threadScope.ts:18-23`) and `owningArtifactOrFolderId` (`threadScope.ts:32-44`, one match per level up the parent chain, per id, called by `isThreadScopedId` from `dehydrate.ts:137` and `168`). One flush, `dehydrate.ts:128-146` and `dehydrateStateToJsonLd` (`dehydrate.ts:160-170`), costs about 3 full scans, about 7000 x (1 + parent depth) path matches and every field of every node.
          - **Delete and add paths**: <a name='id/BlockNode:00D1GCR1XR007' class='aperas-anchor aperas-id'></a> `node.ts:100,101,136-141,178,231,237,256,265-269,294,301` (`appendOrderedChild`, `insertOrderedChild`, `clearField`, `hardDeleteNode`, `writeField`): each quad is passed to `store.delete(m)` and dropped; line 237 deletes every quad of a node; `insertOrderedChild` does 2 matches and 2 deletes per sibling. `hardDeleteNode` recurses (`node.ts:231-233`, `294-298`) while its own quad array is being iterated. `removeDanglingUnfolds` (`node.ts:251-259`) is bound on `predIri('unfolds')` and the deleted id, and passes each quad only to `store.delete(m)`. The adds (`node.ts:103-104,144-145,201,203,274-275,313,318,327` and `store.ts:95,96,107,112,116` in rehydrate) make a fresh `Quad` plus 2-3 args per call and drop them; `store.add` does not consume them.
          - **No match of their own**: <a name='id/BlockNode:00D1GCR1XR008' class='aperas-anchor aperas-id'></a> `checkLinkIntegrity` (`linkIntegrity.ts:110-122`) calls `allIdsOfKind` and `wrap` (`node.ts:2149-2154`, a node is `{store, id}`) and reads through the accessors; `service.ts` calls the boot `rehydrateStore` at 162, the sweeps `tombstoneVacuousContainers`, `pruneUnreachableTombstones` and `pruneStaleUnfolds` at 202-204, 365-373, 418-420 and 474-477 (each runs `allIdsOfKind` several times), and the dehydrate at 237, 328, 421 and 425; at reload (378-379) `store = result.store` drops the old `Store` without `store.free()`.
          - **Test only**: <a name='id/BlockNode:00D1GCR1XR009' class='aperas-anchor aperas-id'></a> `cli/src/verifyDanglingUnfolds.ts:25` returns the `Quad[]` and `store.add(q)` at 60 re-adds them (`referenceDanglingUnfoldQuads`, retained on purpose), 48 and 56 (`.length` only), 70-73 `unfoldedIds`; `cli/src/verifyLinkRefusals.ts:60` spreads the whole store.
        - **What can be freed, and what must be kept**
          
          - **Free at the root as soon as the value is read**: <a name='id/BlockNode:00D1GCR1XR00B' class='aperas-anchor aperas-id'></a> every quad and term in `allIdsOfKind`, the rehydrate second pass, `readField`/`decodeTerm`, `childrenOf`, `orderedChildIds`, `decodeField`, `pathOf`, `owningArtifactOrFolderId`, `findByExactPath`, `findLiveByKindAndPath`, `ownerOfLink`, `backlinks`, `find*ByName/Handle`, `nodeExists`, `unfoldedIds`. Their results are strings, numbers, booleans, or `wrap`ped nodes holding `store` and `id`, so no wasm object outlives its call in production code; nothing is stored in a Map or a closure.
          - **Free after the call that uses them**: <a name='id/BlockNode:00D1GCR1XR00C' class='aperas-anchor aperas-id'></a> the `Quad` in every delete loop (after `store.delete(m)`), every fresh quad and arg in every `store.add(...)`, every `nodeIri`/`predIri`/`encodeLiteral` arg after its `match` call.
          - **Keep**: <a name='id/BlockNode:00D1GCR1XR00D' class='aperas-anchor aperas-id'></a> `PARENT_PRED`, `SIBLING_INDEX_PRED` (`vocab.ts:139-140`) and `XSD_INTEGER`, `XSD_BOOLEAN` (`vocab.ts:11-12`), module constants used by every call, so freeing one makes every later use throw; `subject` in `encodeDoc` (83) and `childSubject` in `appendOrderedChild` (99) until the last line that uses them; `deletedIri` in `verifyDanglingUnfolds.ts:21`; the quads in `referenceDanglingUnfoldQuads` until the comparison ends.
          - **Care points**: <a name='id/BlockNode:00D1GCR1XR00E' class='aperas-anchor aperas-id'></a> free the `Quad` after the term read from it is turned into a string, not before; with `matches[0]` and `matches.map(...)` the array is freed after the last use of any element; `hardDeleteNode` recurses while its quad array is iterated, so each quad is freed per element and after `store.delete`; free an arg only after the `match` that took it, and only if it was created for that call. Measured in a scratch process: a term taken from `q.subject` stays valid after `q.free()`, but `q.subject` after `q.free()` throws "null pointer passed to rust"; the results of `match(arg, ...)` stay readable after `arg.free()`, but `match(freedArg, ...)` throws; `store.add(quad)` does not consume the quad; `store.delete(freedQuad)` throws; a freed module constant used later as an argument throws.
        - **The other fields of `removeDanglingUnfolds`**: <a name='id/BlockNode:00D1GCR1XR00F' class='aperas-anchor aperas-id'></a> it covers only `unfolds` (`node.ts:256`, `predIri('unfolds')`); `shape.ts:146` defines only `unfolds` and `root` on a `TreeView`. `unfoldsCollapsed` and `unfoldsNoPreview` exist nowhere in `packages/`, only as a proposal in the graph (4 blocks in `Apeiron/BlockNode.jsonld`). If they are added as set fields of `TreeView`, `removeDanglingUnfolds` must sweep their predicates too, or match on the object alone and filter on the predicate set.
        - **Shapes for one helper that frees at the root** (a measured fact for all of them: `match` builds the whole array first, so no shape lowers the peak, only what stays alive after the call)
          
          - **A. Eager plain rows**: <a name='id/BlockNode:00D1GCR1XR00H' class='aperas-anchor aperas-id'></a> `readQuads(store, subjectId|null, field|null, object)` returns `{subject: string, predicate: string, object: {termType, value, datatype?}}[]`; the helper builds its own args from strings and frees args, quads and terms before returning. It changes the read sites listed above and turns `nodeExists` into `countMatches`. Safe by construction (no wasm object leaves the helper); the cost is one plain object per quad.
          - **B. Callback**: <a name='id/BlockNode:00D1GCR1XR00J' class='aperas-anchor aperas-id'></a> `forEachMatch(store, s, p, o, (q) => ...)` frees each quad after the callback; fits the delete loops. Hazard: a callback that keeps `q` or a term gets a null-pointer throw later.
          - **C. Generator yielding plain values**: <a name='id/BlockNode:00D1GCR1XR00K' class='aperas-anchor aperas-id'></a> no gain over A, because the array is already built; a generator that stops early would need a `finally`.
          - **D. Specific helpers**: <a name='id/BlockNode:00D1GCR1XR00M' class='aperas-anchor aperas-id'></a> `deleteMatches(store,s,p,o): number` for the delete loops, `countMatches` for `nodeExists`, `addQuad(store,s,p,o)` for all the `store.add(quad(...))` sites.
          - **The Coder's recommendation**: <a name='id/BlockNode:00D1GCR1Y0000' class='aperas-anchor aperas-id'></a> A for reads, D for writes, B not used; helpers take ids and field names as strings so they own the lifetime of every arg, with `predIri` cached per field name in a Map (a bounded set from `SHAPE_BY_KIND`, never freed) to remove the second kind of per-call allocation. `using`/`Symbol.dispose` exists on the classes (node 22) but the packages' `tsconfig` targets es2023 with `lib: ["ES2023"]`, so it needs a config change; not recommended here.
        - **Measurement** (on a copy under `/tmp` of 58,780 quads, a fresh process per variant, `node --expose-gc`, `gc()` between calls): the unchanged `allIdsOfKind` grows about 42 MB per call and takes 570 to 1,140 ms; the variant that frees the subject term and the quad stays flat at 349 MB after a first-call rise of 32 MB, at about 150 ms per call. Caveats: one site, one corpus size, and resident set size is the only gauge (`process.memoryUsage().arrayBuffers` reads 0 and oxigraph exports no wasm memory size); without `gc()` between calls the freed variant looked as if it grew 17 MB per call, which was collectable string garbage.
        - **What the production-bound measurement must show**: <a name='id/BlockNode:00D1GCR1Y0002' class='aperas-anchor aperas-id'></a> memory with `gc()` before every reading, the signal being a plateau (flat after call 1 with the change, linear without); the service shape, not one function: a cycle of `dehydrateToJsonLd`, `dehydrateStateToJsonLd`, the three sweeps and `checkLinkIntegrity`, at least 10 cycles, then a `rehydrateStore` reload loop with and without `store.free()` on the old store; time per call and per cycle; identical output, meaning the dehydrated `*.jsonld` byte-for-byte equal to the unchanged code's output on the same copy, and the `commit` suite green, plus a test that a helper never returns or leaves a freed object (any "null pointer passed to rust" is a miss); a split of the gain by site (`allIdsOfKind`, `readField`, add-args), because the gauge is rss.
        - **Still unknown**: <a name='id/BlockNode:00D1GCR1Y0003' class='aperas-anchor aperas-id'></a> the same plateau for the other sites (only `allIdsOfKind` was measured, with one corpus size), and whether `new Store()` freed on reload is a gain or a hazard for a request in flight (requests go through `enqueue()`, `service.ts:5`, but the swap at 378-379 was not traced against held references).
    - **The plan of the user, 2026-10-11: the `free()` helper first, then a pure JavaScript engine to compare** (decided as an order; the helper's shape is the orchestrator's reading of "best effort", open to the user's correction)
      
      - **Order**: <a name='id/BlockNode:00D1GC79B8001' class='aperas-anchor aperas-id'></a> (1) the `free()` helper over the store reads (the item above, with the map of the sites under it), with its scratch measurement on a copy of the real store; (2) no further hacks on Oxigraph; (3) a pure JavaScript ApeironNgn engine, the dedicated engine the name suggested, as a separate task, compared with the `free()` version. The user's words: "I think we should applied the `free()` patch as our best effort on Oxigraph, but no more hack on Oxigraph. After that, we'll try the pure JS ApeironNgn (as the name originally suggested, a dedicated engine) to compare with the `free()`-patched version."
      - **Why the store may change**: <a name='id/BlockNode:00D1GC79B8002' class='aperas-anchor aperas-id'></a> the store is only an in-memory reflection of the mirror, and the mirror (the JSON-LD under `Apeiron/`) is the source of truth, which has stayed stable from TerminusDB to now, so a replacement store (Oxigraph, or plain JavaScript) does not hold the truth.
      - **In the `free()` change**: <a name='id/BlockNode:00D1GC79B8003' class='aperas-anchor aperas-id'></a> the whole read helper of the map (reads as plain values, write helpers that take strings, `predIri` cached per field name), taken from the Coder's recommendation because "best effort" points that way. **Out of it**: the whole-store `free()` on reload (measured to change nothing), the plain JavaScript engine, and new fields for `removeDanglingUnfolds` (none exist in code).
      - **The comparison of the `free()` version with the pure JavaScript engine**: <a name='id/BlockNode:00D1GC79B8004' class='aperas-anchor aperas-id'></a> not decided, not tried. What a replacement has to offer is small: the code calls only `match`, `add` and `delete` on a store, plus the term and quad constructors `quad`, `namedNode` and `literal`.
    
    - **Layer 1 — bound matches in place of unbounded ones** (a candidate, the first of the layers, after the `free()` item; not decided, not tried)
      
      - **Replaces**: <a name='id/BlockNode:00D0Y9HG30002' class='aperas-anchor aperas-id'></a> the unbounded `store.match(null, null, null, null)` in `allIdsOfKind` (`dehydrate.ts` lines 49 to 58) with a match for a kind's type quads only; the scan in `removeDanglingUnfolds` with one object-bound `store.match(null, unfolds, deletedIri, null)`; the reads in `wrap` (`node.ts` line 2144) and `readField` (lines 156 to 162) with one subject-bound match per node. **Corrected 2026-10-11**: the store has no type quads, because `encodeDoc` skips `@type` (`store.ts` line 86), and `urn:aperas:pred:type` is the `type` field of a `BlockNode` (paragraph, heading, listItem), so the `allIdsOfKind` part has no form to be bound on. The `removeDanglingUnfolds` part is done (see the fix status above). What a bound `allIdsOfKind` could use instead: a kind quad written by `encodeDoc` and every creation path (exact, touches many files); a predicate that every instance of the kind carries, which gave identical id sets on a copy of the real store for `ArtifactNode` (54, on `path`), `FolderNode` (17, `path`), `TreeView` (17, `name`) and `Profile` (9, `handle`) and 5,556 against 5,557 for `BlockNode`, the missing one being a stray block with no title, `type`, parent or children, so `BlockNode`, the big kind, stays on the scan; or Layer 2.
      - **To check first**, on a copy of the real store: <a name='id/BlockNode:00D0Y9HG30003' class='aperas-anchor aperas-id'></a> that every node has a type quad agreeing with the kind `nodeKindFromId` derives from its id. The check failed at once: no node has a type quad (see the correction in `Replaces` above). Still unmeasured: the cost of a bound form against the full scan for the four kinds whose predicates gave identical sets (the twelve-fold saving was an estimate).
      - **Condition**: <a name='id/BlockNode:00D0Y9HG30004' class='aperas-anchor aperas-id'></a> the first of the layers, after the `free()` item; the later layers are tried only if this one leaves the cost in place.
    - **Layer 2 — a kind-to-ids index** (a candidate; not decided, not tried)
      
      - **Replaces**: <a name='id/BlockNode:00D0Y9HG30006' class='aperas-anchor aperas-id'></a> only the body of `allIdsOfKind`; its callers are unchanged and it returns a snapshot array. The index is a `Map<kind, Set<id>>` attached to the store, built from `seenIds` at rehydrate.
      - **To check first**: <a name='id/BlockNode:00D0Y9HG30007' class='aperas-anchor aperas-id'></a> the index is kept by two write helpers through which the 27 `store.add` and `store.delete` sites are routed (not built), and the verify run compares it with a full scan after each operation (not run).
      - **Condition**: <a name='id/BlockNode:00D0Y9HG30008' class='aperas-anchor aperas-id'></a> only if layer 1 still leaves too many wrappers.
    - **Layer 3 — a per-node record cache, the fine-grained index** (a candidate; not decided, not tried)
      
      - **Replaces**: <a name='id/BlockNode:00D0Y9HG3000A' class='aperas-anchor aperas-id'></a> repeated reads of a node's fields through `wrap` and `readField`, each of which crosses into wasm. One plain JavaScript record per node (strings and numbers, no wasm handle), filled by a single subject-bound match with the quads freed at once and invalidated by the write helpers; a set of tombstoned ids is the smallest form.
      - **To check first**: <a name='id/BlockNode:00D0Y9HG3000B' class='aperas-anchor aperas-id'></a> nothing about `free()` itself, which is measured, as one sample, in the `free()` item before Layer 1; the record cache and its invalidation by the write helpers are unchecked. It sits one level above the library because a wasm quad has no object to be one-to-one with.
      - **Condition**: <a name='id/BlockNode:00D0Y9HG3000C' class='aperas-anchor aperas-id'></a> only if per-node reads still dominate after layers 1 and 2.
    - **Beside the layers, not part of them** (candidates; not decided, not tried)
      
      - **Bulk load**: <a name='id/BlockNode:00D0Y9HG3000E' class='aperas-anchor aperas-id'></a> rehydrate by one `store.load` of an N-Quads string, with the dangling references collected in a JavaScript set while encoding; it would replace the per-quad adds and the second full scan (`store.ts` lines 154 to 158). Untested.
      - **Smaller measures**: <a name='id/BlockNode:00D0Y9HG3000F' class='aperas-anchor aperas-id'></a> yielding to the event loop between phases (the pause) as the safety net for the `free()` item before Layer 1; not decided, not tried.
      - **The flush**: <a name='id/BlockNode:00D0Y9HG3000G' class='aperas-anchor aperas-id'></a> a bulk `store.dump` does not serve it, because the mirror is stable-id JSON-LD; it needs its own design, which does not exist.
  - **Related**
    
    - [The removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X65RB800B' class='aperas-anchor aperas-id'></a> the scan cost per embedded node in a task removal is held there and is not repeated here.
    - [The memory issue](#id/BlockNode:00CVQ4Z968001) and [the removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X65RB800C' class='aperas-anchor aperas-id'></a> the scan point already in them (a candidate source of garbage-collector pressure, read, untested) is extended and linked to this entry; this one is filed separately because it covers boot, flush and read paths and not only removal.
- **`aperas service restart` errors out after 10 s and starts nothing whenever the service has been marked dirty, which any `unfold`, `fold` or `zoom --view` does**: <a name='id/BlockNode:00D0W044DG001' class='aperas-anchor aperas-id'></a> measured 2026-10-10 by the Coder in the store-size investigation. Filed 2026-10-10.
  
  - **Symptom**
    
    - After one `unfold ... --view <view>`, the CLI gave up at 10.45 and 10.42 s with "Service (pid N) didn't stop within 10s of SIGTERM" and, for `restart`, started no new service.
    - After the failed stop the old process did exit, so the next `service start` costs about 5.5 s plus about 20 s in which commands are refused (see the start entry below).
    - A restart, its error at 10 s, a start, its error at 5.5 s and retrying commands until they work adds up to about 40 to 50 s of waiting.
  - **Root cause**
    
    - The client's stop wait is shorter than the flushes that the stop runs.
      
      - The SIGTERM handler runs in JavaScript and queues behind the work in flight.
    - The dirty state is the usual state in agent use.
  - **Measurements**
    
    - **Conditions** (by the Coder in the store-size investigation, 2026-10-10): <a name='id/BlockNode:00D0X8VQZR006' class='aperas-anchor aperas-id'></a> a scratch service with its own run directory (`XDG_RUNTIME_DIR`, `APERAS_HTTP_PORT=2790`; `getRunDir()` reads `XDG_RUNTIME_DIR`, `serviceLock.ts` lines 49 to 52), single runs unless a count is given, load average 2 to 3.5; the live lock stayed on pid 33127 throughout.
    - **An idle `service stop` of a settled service**: <a name='id/BlockNode:00D0X8VQZR007' class='aperas-anchor aperas-id'></a> the old pid was gone 1.96 s after the command started (about 1 s of that is CLI startup).
    - **A restart of an idle settled service**
      
      - The pid was gone at 1.64 and 1.60 s.
      - The CLI exited 1 at 6.76 and 6.65 s with "did not become ready in time", and the new lock turned ready at 6.79 and 6.70 s.
    - **After one `unfold ... --view <view>`**, which sets `dirty` and `stateDirty` (`service.ts` lines 520 to 534; an `unfold` without `--view` is a peek and sets nothing)
      
      - `service stop` and `service restart` took the old pid 12.49 s to exit in 2 of 2 runs.
      - The mirror files show the content flush at 20:51:55 to 56 and the state flush finishing at 20:52:05.
      - Of the 12.5 s the shutdown sweeps are about 1.6 s and the two flushes the rest.
    - **A `restart` issued about 6 s after a start, while the startup link sweep still runs**
      
      - It took 21.08 s for the old pid to go; the CLI gave up at 10.69 s and started nothing.
      - A first attempt failed the same way.
  - **Not proven**
    
    - Not measured: <a name='id/BlockNode:00D0X8VQZR00K' class='aperas-anchor aperas-id'></a> a restart on the live service (it would need the user's approval to stop it).
  - **Fix directions**
    
    - No fix has been tried.
  - **Related**
    
    - [The removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X8VQZR00Q' class='aperas-anchor aperas-id'></a> this is the measured form of "didn't stop within 10s of SIGTERM" recorded there.
    - [The boot and shutdown issue](#id/BlockNode:00CVQHCEW8001): <a name='id/BlockNode:00D0X8VQZR00R' class='aperas-anchor aperas-id'></a> there it was read as "consistent with it, not shown to be the cause"; here it is a separate defect (a stop wait shorter than the flushes), so it is filed here and those two link to it.
- **`aperas service start` prints "did not become ready in time" at 5 s although the lock turns ready at 5.3 to 5.8 s, and every command is then refused for about 20 s**: <a name='id/BlockNode:00D0W05P08001' class='aperas-anchor aperas-id'></a> measured 2026-10-10 by the Coder in the store-size investigation, scratch service as in [the restart entry](#id/BlockNode:00D0W044DG001) above, cold `service start` 6 times, load average 2 to 3.5. The lock turned ready at 5.28 to 5.77 s and the CLI exited 1 with "ApeironNgn service did not become ready in time" at 5.42 to 5.76 s in all 6 runs, because `READY_TIMEOUT_MS = 5_000` in `serviceClient.ts` (lines 24 and 25) starts counting after the CLI has loaded, while the service came up 0 to 60 ms later; the ready time breaks down as about 1 s of node and `tsx` start, 1.1 s of `rehydrateStore` and 3.2 s of boot sweeps (`Rehydrated` is logged about 3.3 s before the lock turns ready). After ready, every `aperas` command in the first 19.5 to 23.0 s failed with "No ApeironNgn service running" (6 of 6 starts; `usable_minus_ready` 19.5, 20.2, 20.9, 21.4, 22.0 and 23.0 s, measured through a probe that costs about 1 s of CLI start, so accurate to about 1 s), because the startup link sweep is enqueued on the event loop right after `markReady` (`service.ts` lines 818 to 826) and `ping` has a 300 ms timeout (`serviceClient.ts` line 23). A service that is already settled answers a `profile list` in 0.55 s wall, CLI start included. This measures two points already in the graph: the 5 s ready wait that [the boot and shutdown issue](#id/BlockNode:00CVQHCEW8001) put close to the real boot time, and the 300 ms ping that [the spurious "not running" issue](#id/BlockNode:00CVMPABY8001) names as the reason a busy service reads as down; both are extended with these figures and link here, and this entry holds the start-side measurement. Not measured: a start on the live service (it would need the user's approval to stop it). No fix has been tried. Filed 2026-10-10.
- **`design/` has no document for the store, hydration or the service lifecycle**: <a name='id/BlockNode:00D0W07DRR000' class='aperas-anchor aperas-id'></a> noted 2026-10-10 in the store-size investigation. The graph holds the early ApeironNgn design only in the archive (`archive/Aperas-design.md`, where `rehydrateStore` is a quoted 256 ms at 1,594 BlockNodes), and nothing in `design/` states the quad shape the store holds, when and how the mirrors are hydrated and dehydrated, what the boot, the flush timers, the shutdown and the reload each do and in what order, or what the client's waits (300 ms ping, 5 s ready, 10 s stop) are allowed to assume of them. The boot and shutdown issue already says there is no document for the service lifecycle; this entry records the same gap for the store and hydration too, so the figures in the issues above have no design to be read against. Recorded only; no design is written here. Filed 2026-10-10.
- **Garbage collection never collects an unreachable block that was never tombstoned**: <a name='id/BlockNode:00D1A2AY68001' class='aperas-anchor aperas-id'></a> it has only a link, nothing refers to it, and neither sweep marks or prunes it. Filed 2026-10-11.
  
  - **Symptom**
    
    - `BlockNode:00CJ2TCV40000` has no `type`, no title, no parent, `children: []` and one `Link` (position 114) to `BlockNode:00CJ6TGSX8001`, which exists (read with `aperas show`, 2026-10-11).
    - Nothing refers to it: <a name='id/BlockNode:00D1A2AY68004' class='aperas-anchor aperas-id'></a> `aperas backlinks` finds no link to it (read, 2026-10-11).
    - It is still in the store after restarts (the user's question, 2026-10-11).
  - **Root cause**
    
    - `tombstoneVacuousContainers` marks only a `list`, or a `listItem` with no text, as vacuous, so a block with no `type` never qualifies (read, `node.ts` lines 2231 to 2252).
    - `pruneUnreachableTombstones` skips any block that is not tombstoned, with the comment "never tombstoned — not a GC candidate regardless of reachability" (read, `node.ts` line 2208).
    - So an unreachable block that was never tombstoned is collected by neither sweep, by design (read; not yet checked by the Coder).
  - **Not proven**
    
    - How it came to be a block with only a link is unknown.
    - Whether other unreachable blocks of this shape exist is not counted.
  - **Fix directions**
    
    - None decided. Whether the block is garbage or a shape to keep is the user's to say; the block is not to be touched until then.
  - **Related**
    
    - [The full-store-scans issue](#id/BlockNode:00D0W02KPG001): <a name='id/BlockNode:00D1A2AY6800G' class='aperas-anchor aperas-id'></a> a bound `allIdsOfKind` on `title` or `type` gives 5,556 `BlockNode` ids against 5,557 from the scan, and the one missing is this block, so it would drop from the next flush (measured by the Coder in the store-size investigation).
  - **Stray block removed, issue still open**
    
    - The stray block `BlockNode:00CJ2TCV40000` was removed offline in the mirror sweep of 2026-10-11, by the user's decision: records went from 5,972 to 5,971, and `aperas show` says the node is not found after the service started.
    - The issue stays open for the collector's blind spot itself: <a name='id/BlockNode:00D1BBPCKG003' class='aperas-anchor aperas-id'></a> an unreachable block that was never tombstoned is collected by no sweep. No fix is decided.

## Sub-Parts <a name='id/BlockNode:00CF1WZ4JG00A' class='aperas-anchor aperas-id'></a>

Core's own known parts, and where each one's issues currently live:

- **`crud`** — not yet migrated; archived at `archive/Aperas-crud-design.md`, whose own §6 ("Bookkeeping gaps found while designing this") already names several items overlapping this doc's Open Issues above. Planned as `archive-migration`'s next sub-task.
- **`treeview`** — 4 open: <a name='id/BlockNode:00CF1WZ4JG00C' class='aperas-anchor aperas-id'></a> stale `TreeView.unfolds` references, a bare `aperas unfold <ref>` mutating the default view instead of peeking, no raw single-node inspection command, and `unfold` not marking tombstoned children. See [Open Issues](../issues/treeview.md#id/BlockNode:00CE1GW638002).
- **`linking`** — 2 open, both filed: <a name='id/BlockNode:00CF1WZ4JG00D' class='aperas-anchor aperas-id'></a> `extractAnchorNames` treats a backtick-quoted example anchor as a real claimed name, and `aperas update` never re-derives a non-heading block's title. See [Open Issues](../issues/linking.md#id/BlockNode:00CDBYV5A8002).
- **`list-consumption`** — 1 open: <a name='id/BlockNode:00CF1WZ4JG00F' class='aperas-anchor aperas-id'></a> inserting a list item always spawns a fresh run-leader. See [Open Issues](../issues/list-consumption.md#id/BlockNode:00CE32GRZG000).

## Pending Tasks <a name='id/BlockNode:00CF23SXQ8001' class='aperas-anchor aperas-id'></a>

See [Task Breakdown](../planning/core.md#id/BlockNode:00CF23FB1G003) for the ordered fix plan.

## Resolved <a name='id/BlockNode:00CF1WZ4JG00J' class='aperas-anchor aperas-id'></a>

- **A parent-heading list-push reconciles children by array position, tombstones included, not by content/key**: <a name='id/BlockNode:00CF1WZ4JG003' class='aperas-anchor aperas-id'></a> found running `aperas-skill`'s own eval against [issues/treeview.md's Open Issues list](../issues/treeview.md#id/BlockNode:00CE1GW638002) — piping the heading line plus every visible item (skipping tombstoned ones, as any reasonable read would) zips the piped items against storage slots by raw position, silently reassigning live content onto wrong ids once a tombstoned sibling is interleaved. Contradicts what both the skill and the code's own doc comments claim ("exact-key matching"). Root cause not yet read off `reconcile.ts` directly — identified from reproduced symptom, confirmed only in a disposable eval sandbox, not the live corpus. Same defect family as the next two items below — one fix in `reconcile.ts` likely closes all three. Root cause now read directly: leaf matching (`diffChildren`'s `matchKeyed`) runs `gestaltMatchingBlocks` — the same recursive longest-exact-run algorithm as `matchLeftoverByAbstract` (item 3 below), just keyed on exact string equality rather than similarity — over the *piped* array against the *live (non-tombstoned) child* array. It is genuinely exact-key matching, not raw positional zipping; the recursion's own left/right split around each matched run is what a skipped tombstoned sibling can throw off when duplicate or near-duplicate keys sit on either side of the gap. That root-cause note was wrong, corrected here rather than left standing next to the fix that contradicts it: `listItem` is a `CONTAINER_TYPE`, not a `LEAF_TYPE`, so it never reaches `matchKeyed`/Stage A at all. The real mechanism is Stage B's per-type container alignment, which zipped old/new by raw array position with zero content comparison — confirmed by direct reproduction (a 4-item list missing its already-tombstoned 2nd item: item 3's content landed on item 2's dead id, item 4's content landed on item 3's id, item 4's own id was tombstoned). **Resolved**: Stage B now keys `listItem` buckets through `matchKeyed`+`leafKey`, the same machinery Stage A's leaves already use, instead of a positional zip — verified against the reproduction above (each item now lands on its own real id) and against an ordinary reordering/insert-in-the-middle case (also previously mismatched, not only the tombstone case). Same fix as [item 2 below](#id/BlockNode:00CF1WZ4JG004).
- **`aperas update`'s reconciliation can silently match fresh content onto an already-tombstoned node's id without reviving it**: <a name='id/BlockNode:00CF1WZ4JG004' class='aperas-anchor aperas-id'></a> reproduced twice in `list-consumption`'s eval sandbox — a new bullet's content lands on a stale, already-tombstoned id instead of a fresh one, and `tombstonedAt` is never cleared, so the content stays invisible even though the summary line reports a clean match/add. **Resolved**: root cause was every old-side matching pool (Stage A's leaves and heading buckets, Stage B's containers) including tombstoned candidates with no exclusion at all — a live new node's content could bind to a dead id purely because its stripped text happened to match. Fixed by excluding every tombstoned old child from every matching pool in `diffChildren`: a dead slot is never reused, new content always gets a fresh id instead. Verified live: a new item with text identical to an already-tombstoned sibling's now lands on a brand-new id, not the dead one. Same fix as [item 1 above](#id/BlockNode:00CF1WZ4JG003).
- **A multi-artifact `kg:ingest` isn't transactional either**: <a name='id/BlockNode:00CF1WZ4JG008' class='aperas-anchor aperas-id'></a> `ingestArtifacts`/`ingestAllArtifacts` (`apeironNgn/artifacts.ts`) loop per file with no try/catch, so a later file's failure leaves earlier files' writes already committed to the in-memory store with no rollback across the batch. Same shape as the single-`kg:insert` gap above, one layer up (a batch of artifacts vs. a batch of nodes within one call). **Resolved**, but not with that fix: true all-or-nothing would need a store-wide snapshot/rollback primitive that doesn't exist here, a bigger undertaking than this item's scope. Chosen instead: isolate per file, matching the pattern this module already uses for `untracked` — `ingestOne` wraps each `ingestArtifact` call in try/catch, collecting `{path, error}` failures and continuing, so one bad file no longer silently aborts every file after it in the same batch. `retryDanglingRefs` (called at the end of every `kg:ingest` run, unconditionally) had the identical unguarded loop and got the same fix, though it was never named by this issue. Verified live: a batch of two files, one with a genuine full-slug-path collision, ingested the valid file and reported the broken one as a failure rather than throwing and aborting before the folder-tree rebuild.
- **Folder/Artifact-tier holders have no promotion channel at all, and nothing clears `.holder` once real content lands underneath**: <a name='id/BlockNode:00CF1WZ4JG009' class='aperas-anchor aperas-id'></a> found live creating this very doc. `aperas resolve --create-holder` scaffolds a placeholder `ArtifactNode`/`Block` chain, and filling real content into the *Block* children works fine — but `kg:insert`'s promote path is Block-tier only ("kg:insert only positions Block-level nodes"), so there is no verb that ever flips a Folder/Artifact's own `.holder` back off, even once every child underneath it is real. `aperas project` correctly refuses to render such a subtree ("still has a placeholder (holder) node somewhere in its subtree"), but nothing resolves that refusal short of a direct edit or removing and recreating the artifact disk-first. Matches `Aperas-crud-design.md` §4.1/§6 exactly.. **Resolved, narrower than filed**: read directly, `ArtifactNode extends BlockNode` and already passes `kg:update`'s own type check — piping any content through `kg:update` on a holder `ArtifactNode` already cleared `.holder` before this fix, no code change needed there. The real gap was `FolderNode` alone: `kg:insert`'s move/promote mode was hard-restricted to `BlockNode`, and `kg:update` explicitly excludes `FolderNode` from its own target-kind check, so nothing graph-first ever reached `FolderNode.hydrateFromParsed`'s existing (and already-correct) `this.holder = undefined`. Fixed by extending `kg:insert`'s anchor-*less* bare-promote branch to also accept a `FolderNode` target — a `FolderNode` + `--after`/`--before` combination is rejected outright with a clear message, since a folder's position comes from its own path, never list order, so repositioning was never the missing piece. Verified live on a scratch holder chain (`resolve --create-holder`): the folder's `.holder` cleared on a bare promote, and the anchor combination was correctly rejected.
- **A props-only change reports as `0 changed`, so a write that really happened is invisible in the summary**: <a name='id/BlockNode:00CFATMWY0001' class='aperas-anchor aperas-id'></a> `reconcileTree`'s summary categories (matched/moved/changed/added/removed) are computed over text, so a push whose only effect is on a node's `props` — a list item's `checked`, or a run's `orderedList`/`startIndex` — comes back as `N matched, 0 changed` while a real write has occurred. Confirmed live pushing GFM checkboxes onto `planning/aperas-skill.md`'s Task Breakdown: every one of the 17 items gained a fresh `checked` StringProp and the summary reported `17 matched, 0 moved, 0 changed, 0 added, 0 removed`. Not data loss — the write lands and projects back correctly — but the summary cannot be used to confirm it, and reading it as "nothing was written" is the natural mistake. Same family as the skill's own "verify by traversal, not by the summary line", surfacing in a category the line does not cover at all. **Resolved**: `headingChanged` generalized into `pairChanged` — the existing heading text/title check, plus an order-independent `props` key/value comparison applied to *any* matched pair, not only headings. Verified live: pushing GFM checkboxes onto a scratch list now reports `0 matched, 2 changed`, and re-pushing the identical (now-checked) content afterward correctly reports `2 matched, 0 changed` — no false positives.
- **`matchLeftoverByAbstract` (Gestalt/Ratcliff-Obershelp recursion) is position-sensitive**: <a name='id/BlockNode:00CF1WZ4JG005' class='aperas-anchor aperas-id'></a> works for reconciling siblings that share a rough common order, not for an unordered bag of whole-artifact identities scattered across concern folders — a match's recursive split can discard a whole quadrant of otherwise-valid candidates. Worked around for the rename path specifically (replaced by exact-key matching there), but the same algorithm was used elsewhere in `reconcile.ts` and still carried the weakness on those other paths. **Resolved**: confirmed narrower in scope than first filed — `matchLeftoverByAbstract` is used only by `trackAllArtifacts`/`trackArtifactsScoped` (`artifacts.ts`) and folder rename detection (`folders.ts`), never reached by list-item matching (that path already went through the separately-fixed `matchKeyed`+`leafKey`, [item 1 above](#id/BlockNode:00CF1WZ4JG003)). `trackArtifactsScoped` already had its own order-independent workaround (`matchByExactKey`), duplicating the real fix rather than sharing it. Rewrote `matchLeftoverByAbstract` itself to exact-key matching with no positional requirement at all, and pointed both remaining call sites (whole-corpus artifact/folder rename detection) at it, retiring the now-redundant local copy. Verified with the exact reproduction this issue was filed from — a scrambled 4-item removed/added pair in fully reversed order — matching all 4 correctly where the old recursive algorithm stranded 2 of them in an already-discarded quadrant.
- **A fully-dead container is never itself tombstoned**: <a name='id/BlockNode:00CF1WZ4JG006' class='aperas-anchor aperas-id'></a> `pruneUnreachableTombstones` only collected nodes that were themselves tombstoned and unreachable; nothing ever tombstoned a container once its last live child was gone (children get tombstoned one at a time as they're resolved, but the now-vacuous wrapper was never itself marked dead). Confirmed live against `issues/packaging.md`'s own dead nested-list-wrapper chain. **Resolved**: added `tombstoneVacuousContainers`, a companion sweep run right before `pruneUnreachableTombstones` at all three of its own explicit-sweep call sites (`kg:reload`, `kg:flush --clobber`, service shutdown) — marks `tombstonedAt` on a `list` node with no live children, or a `listItem` carrying no `.text` of its own and no live children (a pure structural wrapper), repeating to a fixed point since tombstoning an inner wrapper can vacate its own parent in turn. Verified live: an `outer wrapper item` `listItem` (no text of its own) holding one nested item, with the nested item removed via `aperas remove`, correctly gained its own `tombstonedAt` on the next reload sweep.
- **`aperas update` re-derives an `ArtifactNode` target's own title from pushed text, corrupting its file-basename identity and breaking its own path resolution**: <a name='id/BlockNode:00CGM54FX0001' class='aperas-anchor aperas-id'></a> found while updating this doc's own leading-summary text (every concern doc's `ArtifactNode.text` carries a short current-status headline as a graph-side-only field, never projected into the actual `.md` file) — `issues/core.md`'s `ArtifactNode` itself had its `title` silently overwritten with a re-derived lead-in term from whatever text was last pushed to it, instead of staying `"core.md"` (the file basename `trackFromDisk` sets once at track time). Confirmed by direct inspection: the corruption already existed in the last committed state, predating this session's own work. Broke `aperas unfold issues/core.md`/every other bare-path resolution of that artifact outright — `findChild`'s slug match is title-based, uniformly for every tree-positioned kind, so a wrong title makes the artifact unreachable by its own path even though its `path` field and structural position were both still correct. **Root cause**: `kgUpdate.ts`'s non-heading title re-derivation (`if (target.type !== 'heading') { title = firstChild.title; }`, added by an earlier fix in this same session for the equivalent, correct bug on ordinary blocks — see [item 1](#id/BlockNode:00CF1WZ4JG003)) never excluded `ArtifactNode` targets, even though an `ArtifactNode`'s title is never a function of its own text the way a block's lead-in is. **Resolved**: the condition now also checks `kind !== 'ArtifactNode'`, leaving `title` `undefined` (and so `target.title` unchanged) whenever the update target is an artifact root. `issues/core.md`'s own title was manually corrected back to `"core.md"`; two other artifacts found with the same stale-but-otherwise-harmless symptom (`issues/treeview.md`'s own leading summary describing an issue already resolved) were refreshed to `"None."` while confirming the title fix held. Verified live: re-pushing `issues/documentation.md`'s own "None." text through the fixed code left its title untouched.
- **ApeironNgn service restart and `flush --clobber` silently dropped GC, startup skipped GC entirely, and every warning was unreachable regardless of wording**: <a name='id/BlockNode:00CGR1BM9G001' class='aperas-anchor aperas-id'></a> `flush --clobber` performed mark-and-sweep tombstone GC (`pruneUnreachableTombstones`) without reporting what changed, service startup never ran the sweep at all (`service.ts:112` calls bare `rehydrateStore()`, contradicting `reloadStore`'s own doc comment claiming startup was already a sweep boundary), and `shutdown()`'s guarded `flushIfDirty()` could silently drop a computed GC result whenever disk had diverged externally. **First pass** (this same session) added a startup GC call and clearer wording on the shutdown warnings — reviewed afterward and found both incomplete: the startup GC computed but never set `dirty`/`stateDirty` (declared *after* that block ran), so it was never actually persisted — confirmed live via `flush --clobber` finding real, hours-old backlog the first time any non-`--discard` sweep boundary was hit at all; and every message involved, old or reworded, went to `console.error`, which is unreachable in real operation since the service is spawned with `stdio: 'ignore'` unconditionally (`serviceClient.ts`, both the dev and built-bundle spawn paths) — wording clarity was irrelevant when nothing could ever see it. Separately, `kg:reload`'s own GC counts were never surfaced at all, only `flush --clobber`'s. **Actually resolved**: reordered `service.ts` so `dirty`/`stateDirty` exist before the boot sweep runs, and the sweep now flushes immediately when it finds anything (safe at cold boot — disk can't have diverged yet, this store was just read from it); added a durable `logService()` helper (`service.ts`) that appends to a `$XDG_RUNTIME_DIR`-based log file alongside `console.error`, used for the boot-GC line, the shutdown warnings, and the timed-flush error paths; `reloadStore()` now returns the same GC metrics `clobberFlush()` already did, and `kg:reload` prints them the same way `kg:flush` does. The unrelated "RDF deduplication" this entry previously described as part of the same fix was a mischaracterization of a distinct, real bug — see the entry below.
- **A hand-edit collapsed two distinct `Profile` documents onto one `@id`, and `rehydrateStore`/`dehydrateToJsonLd` had no way to notice** — `Apeiron/Profile.jsonld` carried two separate entries (`handle: "claude"` and `handle: "antigravity"`) both under `Profile:00CDD5NTXG000` (introduced in the same commit that renamed two other profiles into these two, `403527b`). `rehydrateStore`'s `encodeDoc` keys every quad by `@id`, so both documents' fields land on one subject; `dehydrateToJsonLd` can then only ever emit one JSON document per subject, so one of the two silently disappears on every subsequent flush/reload/clobber — confirmed live, reproduced by forcing a `flush --clobber` and watching the "claude" entry vanish while "antigravity" survived. Previously described in this same entry (before this correction) as "RDF deduplication," as if it were a working, intentional mechanism — it never was; there was no duplicate-`@id` detection anywhere. The `Profile.jsonld` collision itself was already fixed in a later commit (`antigravity` now has its own distinct id) before this was root-caused. **Resolved**: `rehydrateStore`/`encodeDoc` (`store.ts`) now collect every `@id` seen more than once into a new `RehydrateResult.duplicateIds` array — surfaced, not auto-resolved (picking a winner would just be a second, quieter way to lose the same data) — and both the initial boot rehydrate and `kg:reload` log a durable warning naming every colliding id whenever the array is non-empty.
- **`npm run verify`'s runtime had no visibility and two real, fixable costs** — nobody could say which of its ~30 steps made a run slow, and two genuine inefficiencies existed unnoticed alongside whatever the process-lifetime slowdown turns out to be (see the entry above, now resolved). **Resolved, three parts**: (1) a permanent, zero-cost-when-quiet step timer (wraps `console.log`, keys on each step's own numbered header, prints a sorted breakdown at the end even on failure via an outer `try`/`finally`) — the diagnostic that made the finding above possible to state precisely at all. (2) `astParser.ts` built a fresh `unified().use(remarkParse).use(remarkGfm)` pipeline on every single call across three call sites, two of them (`collectLinkCodesFromText`, `findLeadInSpliceOffset`) hit once per block rather than once per document — hoisted into two module-level singletons (one with `remarkFrontmatter` for whole-document parsing, one without, since running the frontmatter plugin over an arbitrary block's own text risks misreading a stylistic `---` thematic break as a frontmatter delimiter). Measured to cost nothing on its own (isolated timing was identical before and after) but removed as real, confirmed waste regardless. (3) `verify.ts`'s own step 19 called `checkLinkIntegrity` immediately before `repairLinkIntegrity`, which recomputed the identical report internally as its own `reportBefore` — `repairLinkIntegrity` now takes an optional pre-computed report, cutting one of four full corpus sweeps in that step. Net effect on the actual numbers: step 19 dropped ~40s, full suite ~326s -> ~290s — real, but small next to the ~230s the process-lifetime slowdown, now resolved, accounts for across steps 13-19.
- **`reconcile.ts`'s `carryForwardFields` corrupts `title` on any fallback-titled block it reconciles, breaking its own path resolution**: <a name='id/BlockNode:00CKSP8JX0000' class='aperas-anchor aperas-id'></a> found live via [kg:migrate-frontmatter's corpus-wide re-ingestion run](../issues/core.md#id/BlockNode:00CKSAK04R001) (2026-09-20). `astParser.ts`'s fallback title for a block with no extractable lead-in term (`let title = blockId`) is the block's own *fresh, scratch* id, assigned during that parse, before reconciliation ever runs — not a function of its text the way every other title is. `carryForwardFields` carries the matched pair's *old* `blockId` forward (correctly preserving identity) but never re-synced `title` to match, on the explicit — and, for this one case, false — assumption in its own doc comment that a matched block's freshly-computed title is always already identical to what carrying the old one forward would have produced. Confirmed live: 37 blocks across the corpus had `title` silently overwritten with a fresh scratch id from a discarded parse the moment they were reconciled — the same family as [the `ArtifactNode`-title corruption already fixed above](../issues/core.md#id/BlockNode:00CGM54FX0001), one level down, at the ordinary-block scale, and with the same downstream break: `toPath()`'s slug-based addressing uses `title` directly, so a corrupted one makes the block unreachable by its own path. **Resolved**: `carryForwardFields` now captures the fresh node's own about-to-be-discarded `blockId` before overwriting it, and re-points `title` at the id it's actually keeping whenever `title` was only ever mirroring that discarded value. Not yet re-verified against a live corpus-wide reconciliation pass — the run that surfaced it was reverted, corruption and all, rather than repaired in place.
- **Verify emergency**: <a name='id/BlockNode:00D1BAT6Q0001' class='aperas-anchor aperas-id'></a> the full `npm run verify` takes about 24 minutes, so by the user's rule no turn runs it as a batch until it is under a minute; the emergency is on. Filed 2026-10-11.
  
  - **Symptom**
    
    - The last full `npm run verify` took 1,434 s, about 24 minutes at roughly 100% CPU, with steps 7, 9c, 10 and 11 costing 649, 203, 188 and 202 s (measured 2026-10-11 by the Coder, on a scratch copy of the mirror with the doubled link targets rewritten).
    - The user's rule of 2026-10-11: <a name='id/BlockNode:00D1BAT6Q0004' class='aperas-anchor aperas-id'></a> no turn runs it as a batch until it is under a minute.
  - **Root cause**
    
    - Not known beyond the step timings above.
    - [The `npm run verify` slowdown entry](#id/BlockNode:00CJ0202MG001) recorded about 5 minutes, a process-lifetime slowdown that store freshness and heap size did not explain, and split `verify.ts` to bring `verify` to about 42 s. [Its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000) left the mechanism unexplained. On 2026-10-11 the user said it "has been refactored once, but has grown up again".
  - **The rule** (the user's, 2026-10-11)
    
    - The threshold is one minute. At Step 7 a verify is tried once, as a run capped at one minute; if it finishes green within the minute, Step 7 is normal.
    - The emergency is on when it does not finish within the minute. The trial is stopped, the change is verified by the required tests only (its own tests, `tsc`, targeted passes), and nobody runs verify, not even the trial, while the emergency is on.
    - The emergency is off when a core fix lets one run finish green within a minute; then verify is run as normal.
  - **Fix directions**
    
    - The core slowdown has no fix decided; the emergency calls for one.
    - **The test design is settled** and lives in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001): standalone scripts in groups, suites as compound scripts, the `essential`, `commit` and `demand` tiers, a runner on `node --import tsx --test` with concurrency 2 and a per-file timeout, and the legacy suite moved under `src/tests/legacy/`. The design marks each claim measured, read or designed, not built; the build is not done, and the core slowdown remedy for the service is not part of it.
      
      - **When the emergency ends**: <a name='id/BlockNode:00D1D5PV78002' class='aperas-anchor aperas-id'></a> when the legacy suite is retired and the `commit` tier runs under a minute, by the rule above. The design's [Workflows](../design/testing.md#id/BlockNode:00D1D5F64800F) hold the same condition.
      - **The flag is this issue**: <a name='id/BlockNode:00D1D5PV78003' class='aperas-anchor aperas-id'></a> no flag file exists or will exist (`monorepo/verify-emergency.json` was never created and nothing reads it). The issue stays open until the condition above holds.
    - **Phase 1 is built**: <a name='id/BlockNode:00D1DBSMS0001' class='aperas-anchor aperas-id'></a> the runner (`run.mjs`) and the first five test files; the legacy suite is not yet retired, and the issue stays open. [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001) marks which items are built and which are designed, not built.
    - **The skills' v4.4 text is done**: <a name='id/BlockNode:00D1DD18CG001' class='aperas-anchor aperas-id'></a> the four skills now say to run `npm run verify` (the `commit` suite) before handing a change back and at Step 7, `--group <area>` and `--suite essential` after an edit, and never the legacy suite unless the user asks, as [the v4.4 milestone](../history/aperas-skill.md#id/BlockNode:00D1DCS9YG001) records. The issue stays open.
    - The user's design for the command: <a name='id/BlockNode:00D1BAT6Q8007' class='aperas-anchor aperas-id'></a> it accepts arguments for which test cases to run, a toggle for emergency mode, and an option to force the full suite despite emergency mode; in emergency mode it refuses to run the full suite; a built-in timer warns the user when a run passes one minute. Not built. [The settled design](../design/testing.md#id/BlockNode:00D1D5F63R001) keeps the case selection (`--suite`, `--group`, `--case`, `--list`) and the one-minute warning and drops the emergency toggle and the force option.
    - How a named case runs alone, settled: <a name='id/BlockNode:00D1BAT6Q8008' class='aperas-anchor aperas-id'></a> the standalone-script form, one ordered file per chain, as [the settled design](../design/testing.md#id/BlockNode:00D1D5F64000D) records. The original problem stays true of `verify.ts`: it is one long function whose later steps use the store built by earlier ones (step 9c needs what steps 1 to 9b made).
    - Where the state lives, the timer and the force option, settled by [the design](../design/testing.md#id/BlockNode:00D1D5F63R001): no emergency state file, the issue is the flag, the timer only warns, and there is no force option.
  - **Status**
    
    - On from 2026-10-11. This issue is the flag: <a name='id/BlockNode:00D1BAT6Q800B' class='aperas-anchor aperas-id'></a> opening it turned the flag on, and resolving it turns the flag off.
  - **Resolved**: <a name='id/BlockNode:00D1EGQDN8001' class='aperas-anchor aperas-id'></a> the legacy suite is retired and deleted, and `npm run verify` runs the `commit` suite in 8 to 20 s, with the corpus checks in the `demand` suite on a copy of the real mirror. The emergency was closed by making the suite independent of the core's slowness, not by fixing the core: the core's cost stays open in [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001), [the reload issue](../issues/core.md#id/BlockNode:00D0W00YCR001), [the memory issue](../issues/core.md#id/BlockNode:00CVQ4Z968001), [the issue of commands refused while the service is up](../issues/core.md#id/BlockNode:00CVMPABY8001) and [the issue of commands refused after a start](../issues/core.md#id/BlockNode:00D0W05P08001). The flag is therefore off. The built suites are in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001).
  - **Related**
    
    - [The `npm run verify` slowdown entry](#id/BlockNode:00CJ0202MG001) and [its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000): <a name='id/BlockNode:00D1BAT6Q800D' class='aperas-anchor aperas-id'></a> the earlier record of the same cost, at about 5 minutes.
- **A thread-task `aperas remove` can leave the service CPU-bound for many minutes, during which every command fails and a graceful stop does not complete**: <a name='id/BlockNode:00CVNX6A3R000' class='aperas-anchor aperas-id'></a> found 2026-10-02 pruning finished tasks in the v4.3 skill task; the stalls were observed and the suspected causes below fit them, but no run attributed a stall to any of them before the fix. Filed 2026-10-02. **Resolved 2026-10-11** for the cause the Root cause section names, the scan of the whole store for every embedded node removed: the object-bound `removeDanglingUnfolds` landed in commit `0a7a226` and ran in the live service, where one `aperas remove --flush` of a task of 164 live blocks and 101 embedded `Link` nodes took 3.7 s with exit 0 and no stall, the thread tree then showed every other task intact, and `aperas check-links` scanned 6,549 live blocks with 0 discrepancies. That is about 36 ms per embedded node, against about 14,000 ms for 34 nodes at the old cost per scan, and the old service stalled 5.4 and 12 minutes on removals of 42 and 31 blocks. It covers every field that exists: `removeDanglingUnfolds` sweeps `unfolds`, and `unfoldsCollapsed` and `unfoldsNoPreview` do not exist in code (`shape.ts` defines only `unfolds` and `root` on a `TreeView`). One removal is one sample; the other suspected causes below (the link-integrity sweeps, the tombstone hard-deletes at shutdown and startup, a process-lifetime slowdown) were not separated from the scans by any run, and the scans' wrappers remain in [the scan entry](#id/BlockNode:00D0W02KPG001).
  
  - **Symptom**
    
    - Found 2026-10-02 pruning finished tasks from `.threads/grapher.md` and `.threads/coder.md` in the v4.3 skill task. Of 15 removals, most returned in 2 to 10 seconds.
    - After removing `memory-rules-and-orientation-restructure` (42 live blocks) the service answered nothing for about 5.4 minutes (tombstone at 11:37:44Z, next success at 11:43:07Z).
    - After removing `promote-and-fix-subagent-tool-gap` (31 live blocks) it stayed unreachable for about 12 minutes (tombstone at 11:44:10Z, first answer at about 11:56:40Z).
    - Tasks of 39 and 50 blocks returned quickly, so size alone does not predict it.
    - Throughout, the process was alive at 100 to 290 percent CPU and 3.4 to 4.6 GB resident, and `service.log` recorded nothing.
    - Every command, `aperas show` included, failed with "No ApeironNgn service running", which is the symptom of [the service-ping issue](#id/BlockNode:00CVMPABY8001).
    - A later `aperas service restart` sent SIGTERM and failed with "didn't stop within 10s of SIGTERM"; the old process was still alive more than 40 minutes later, when it was killed.
    - On the fresh service started afterwards (about 1 GB resident), three further removals took 2, 2 and 45 seconds and the next command could not reach the service for minutes, so age and heap size alone do not explain the stall.
  - **Root cause**
    
    - **Established mechanism** (measured in general by the store-size investigation of 2026-10-10)
      
      - The scans create a wrapper per quad that is released only after a garbage collection and an event-loop turn, and a reload leaves the old store alive until a turn ([the scan entry](#id/BlockNode:00D0W02KPG001), [the reload entry](#id/BlockNode:00D0W00YCR001)).
    - **Suspected causes**: <a name='id/BlockNode:00D0WZYWFR003' class='aperas-anchor aperas-id'></a> five; no run has attributed a stall to any of them.
      
      - **A scan of the whole store for every embedded node under the removed task** (read from `service.ts` and the store code in the investigation's code survey of 2026-10-02; the cost of one scan measured in a scratch process)
        
        - One `aperas remove --flush` of a task `T` in artifact `A` runs, synchronously and in this order, `artifactForRef`, the pre-check sweep of `A`, `runRemove`, the content flush, and the post-check sweep of `A`.
        - `runRemove` calls `tombstoneLiveSubtree`, which for each block depth-first sets `children = []`, `links = undefined`, `props = undefined` and `tombstonedAt`.
        - The `links` and `props` assignments go through `writeField`'s embed branch, which calls `hardDeleteNode` on every embedded `Link` and `StringProp`, recursing into each `Link`'s position props.
        - Each `hardDeleteNode` begins with `removeDanglingUnfolds`, which calls `allIdsOfKind(store, 'TreeView')`, a `store.match` over every quad in the store.
        - The cost of a removal therefore follows the number of embedded nodes under the removed task, about that count times 140 ms, and not its block count.
        - This fits the pattern in Symptom (39 and 50 blocks fast, 42 and 31 slow): a task whose blocks carry many wikilinks has many `Link` nodes and position props, while a plain list has few.
      - **The tombstones that each removal leaves are hard-deleted one at a time at shutdown and startup** (read, with the per-node cost measured; the likely cost; not tested)
        
        - Each removal also leaked its descendants' tombstones into the tracked `Apeiron/BlockNode.jsonld` (see [the leak issue](../issues/treeview.md#id/BlockNode:00CRCGRGJR002) in `issues/treeview.md`).
        - `pruneUnreachableTombstones` hard-deletes each unreachable tombstone one at a time at shutdown and startup.
        - At the next reload, shutdown or startup it finds the removed blocks unreachable and calls `hardDeleteNode` on each, another full scan each: about 6 s for 42 blocks (derived) on top of its fixed 2.3 s, which is the cost described in [the boot and shutdown issue](#id/BlockNode:00CVQHCEW8001).
      - **Each scan leaves a JavaScript `Quad` wrapper per store quad, which raises garbage-collector pressure and external memory** (read, untested; the effect is measured in the Coder's runs and in the store-size investigation)
        
        - The scan allocates a JavaScript `Quad` per store quad on every call (about 40k objects, 140 ms), which is a candidate source of the garbage-collector pressure and the external-memory growth in [the memory issue](#id/BlockNode:00CVQ4Z968001) (read, untested).
        - The retained external memory in the Coder's removal runs (see Measurements) is the same effect that the memory issue records.
      - **Two whole-artifact link-integrity sweeps around every write** (second suspected cause; untested; a lead, not a finding)
        
        - Every `remove`, `insert`, `update` and `retype` runs `checkArtifactLinkIntegrity(store, artifactId)` before the operation and again in `withLinkCheck` after it, over the whole artifact (read from `service.ts`), so one `remove` of a task inside a 600-block thread file costs two full link-integrity sweeps on top of the removal itself.
        - The verify-slowdown issues, [the `npm run verify` entry](#id/BlockNode:00CJ0202MG001) and [its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000), name the same kind of operation, `checkLinkIntegrity`'s corpus sweep, as the one that went from low hundreds of milliseconds fresh to 12 to 55 seconds late in a long process, so the sweeps are a candidate for the removal stall.
        - No test has separated the sweeps from the tombstone hard-deletes above.
        - The sweeps are real and are measured (see Measurements), but two of them cost seconds (derived), not the minutes seen; [their own issue](#id/BlockNode:00CVQHBP0R001) carries them.
      - **A process-lifetime slowdown, the same mechanism as the verify slowdown** (hypothesis, not a finding)
        
        - It would be the process-lifetime slowdown already recorded in [the `npm run verify` entry](#id/BlockNode:00CJ0202MG001) and [its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000): a long-lived node process that degrades, here the service at about 5 GB resident after about three hours, where a process split is not an option because the service is the shared store.
        - The earlier slowdown showed up as steps running 12 to 55 seconds instead of hundreds of milliseconds, with oxigraph at roughly 1 GB, not as multi-minute stalls with no answer at all.
        - The repeat on a fresh process fits poorly with a slowdown that builds up over a process's lifetime, though degradation within a few minutes of heavy work would still match.
        - The earlier entry's leading guess was a JIT-level degradation, which this entry does not test.
        - If it is the same mechanism, the profiling that entry proposes (`--prof` or `--trace-deopt`) is the next step, run against the service.
  - **Measurements**
    
    - **One full-store scan costs 136 to 144 ms at 39.6k quads** (measured, in a scratch process)
      
      - Caveat: <a name='id/BlockNode:00D0WPK57G00E' class='aperas-anchor aperas-id'></a> the 39.6k count had no recorded method. The store holds 41,752 quads by `store.size`, measured 2026-10-10.
    - **A whole-artifact link-integrity sweep costs 1.7 to 2.5 ms a live block, so about 0.6 to 0.9 s on a 367-block thread file** (measured per block)
      
      - Two sweeps cost seconds (derived); [their own issue](#id/BlockNode:00CVQHBP0R001) carries them.
    - **Pruning the removed blocks costs about 6 s for 42 blocks on top of a fixed 2.3 s** (derived from the per-scan cost; read)
    - **Removing one `#### Turn` of a thread (34 embedded nodes) took 30 to 40 s with the event loop blocked, and the state flush added 16 to 20 s** (measured by the Coder 2026-10-02 and recorded here 2026-10-10)
      
      - Conditions: <a name='id/BlockNode:00D0WPK57R003' class='aperas-anchor aperas-id'></a> seven bounded runs of the removal path on `/tmp` copies of the store, nothing written to the real graph or the live service.
      - The pre-sweep cost about 0.6 s, `runRemove` 9 to 10.6 s, the content flush 19 to 29 s and the post-sweep 0.2 s.
      - `runRemove` did exactly 34 full-store scans, one per embedded node, at 208 to 352 ms each.
    - **The heaviest task (122 embedded nodes) was still inside `runRemove` when the 60-second limit hit, after 60 scans, and the average cost per scan rose from 130 ms to 3,013 ms across them** (measured by the Coder, same runs)
    - **Under `--trace-gc`, Mark-Compact time per ten scans rose from 1.0 s to 28.3 s of that window's 29.2 s** (measured by the Coder, same runs)
      
      - It was triggered by external memory pressure: <a name='id/BlockNode:00D0WPK57R008' class='aperas-anchor aperas-id'></a> each scan retained about 9 MB of heap and 21 MB of external memory until the event loop turned, and resident size reached 2.0 GB after 60 scans.
    - **Repeated scans alone slowed down; 160 deletions did not, and a fresh `Store` did not restore the speed** (measured by the Coder, same runs)
    - **Content and state flushes cost 3 to 4 times as much after a removal** (measured by the Coder, same runs)
    - **An in-memory removal of the heaviest coder tasks in a fresh process did not finish in 100 s** (measured by the Coder)
      
      - Caveat: <a name='id/BlockNode:00D0WPK57R00C' class='aperas-anchor aperas-id'></a> consistent with the mechanism but not attributed to a step.
    - **A settled scratch service marked dirty by a view op took 12.5 s to stop, so it misses the client's 10 s stop wait** (measured, 2 of 2, [the restart entry](#id/BlockNode:00D0W044DG001))
      
      - Consistent with the "didn't stop within 10s of SIGTERM" in Symptom, not an explanation of it: that process was stuck CPU-bound for more than 40 minutes, and this figure comes from a settled scratch service.
  - **Not proven**
    
    - The 5.4 and 12 minute stalls would need about 2,300 and 5,000 such scans at 140 ms, and whether those tasks held that many embedded nodes is not known.
    - A task of about 120 embedded nodes plausibly takes minutes, which fits the 5.4 and 12 minute stalls; it is not proven, because no run finished a removal of that size and `.threads/grapher.md` was not measured.
    - The whole mechanism against a stall is untested; it needs the per-operation timings and a profile during a stall that [the no-coverage issue](#id/BlockNode:00CVQHD7CR001) lists.
    - Whether the sweeps or the tombstone hard-deletes cost more is untested: no test has separated them.
    - That the tombstone hard-deletes at shutdown and startup are the likely cost is not tested.
    - That the scans' wrappers are the source of the garbage-collector pressure and the external-memory growth is read, not tested.
    - That this is the verify slowdown again is a hypothesis, not a finding.
  - **Workaround**
    
    - Wait, retry the command unchanged, and do not kill the process.
    - Killing the service lost every removal, because the thread tier's `.state/` mirror had not been flushed since before the removals, which is [its own issue](#id/BlockNode:00CVNZXVR8001).
  - **Related**
    
    - [The service-ping issue](#id/BlockNode:00CVMPABY8001): <a name='id/BlockNode:00D0WPK57R00V' class='aperas-anchor aperas-id'></a> a command can fail with "No ApeironNgn service running" while the service is up.
    - [The `.state/` mirror issue](#id/BlockNode:00CVNZXVR8001): <a name='id/BlockNode:00D0WPK57R00W' class='aperas-anchor aperas-id'></a> a write to a thread node never marks the mirror dirty, so a killed service loses it.
    - [The boot and shutdown issue](#id/BlockNode:00CVQHCEW8001): <a name='id/BlockNode:00D0WPK57R00X' class='aperas-anchor aperas-id'></a> boot and shutdown cost grows with the tombstones.
    - [The re-parse issue](#id/BlockNode:00CVQHBP0R001): <a name='id/BlockNode:00D0WPK57R00Y' class='aperas-anchor aperas-id'></a> every write re-parses the whole artifact before and after the operation.
    - [The no-coverage issue](#id/BlockNode:00CVQHD7CR001): <a name='id/BlockNode:00D0WPK580000' class='aperas-anchor aperas-id'></a> the service has no timing, memory or load-test coverage.
    - [The memory issue](#id/BlockNode:00CVQ4Z968001): <a name='id/BlockNode:00D0WPK580001' class='aperas-anchor aperas-id'></a> resident memory climbs to about 5.8 GB over hours under heavy use.
    - [The scan entry](#id/BlockNode:00D0W02KPG001): <a name='id/BlockNode:00D0WPK580002' class='aperas-anchor aperas-id'></a> full-store scans materialize every quad as a JavaScript object.
    - [The scans issue's Fix directions](#id/BlockNode:00D0X65RB8008): <a name='id/BlockNode:00D0Y9KNP8001' class='aperas-anchor aperas-id'></a> the candidate layers for the full-store scans are listed there and are not repeated here.
    - [The reload entry](#id/BlockNode:00D0W00YCR001): <a name='id/BlockNode:00D0WPK580003' class='aperas-anchor aperas-id'></a> a reload leaves the old store alive until an event-loop turn runs.
    - [The restart entry](#id/BlockNode:00D0W044DG001): <a name='id/BlockNode:00D0WPK580004' class='aperas-anchor aperas-id'></a> `aperas service restart` errors out after 10 s whenever the service has been marked dirty.
    - [The `npm run verify` entry](#id/BlockNode:00CJ0202MG001) and [its resolved "why" entry](#id/BlockNode:00CJ0HX2Y0000): <a name='id/BlockNode:00D0WPK580005' class='aperas-anchor aperas-id'></a> the process-lifetime slowdown of the verify run.

- **`npm run verify` costs ~5 minutes, dominated by a process-lifetime slowdown neither store-freshness nor heap size explains** — instrumented per-step (a `console.log`-wrapping timer keyed on each step's own `"N. Testing..."` header, printing a sorted breakdown even on failure) and found the same operation (`checkLinkIntegrity`'s corpus sweep, and separately `parseMarkdownTree`-driven ingestion in Linking Slice steps 13-18) costs low hundreds of ms freshly isolated, but 12-55 *seconds* run as `verify.ts`'s own later steps — steps 3-6 doing the identical kind of parsing work stay fast, steps 7-12 in between do no heavy parsing at all, then 13 onward is uniformly slow. Two credible causes ruled out by direct experiment, not by inspection: (1) oxigraph's own WASM memory footprint (`external`, ~850MB-1GB by that point vs ~50MB fresh) looked causal, but compacting the store mid-run (dehydrate a scratch dir, rehydrate a brand-new `Store` with the identical live content) made the same sweep *slower*, not faster — ruling out "this one store instance is bloated." (2) V8 heap-size tuning (`--max-old-space-size=8192 --max-semi-space-size=128`) changed nothing measurably.
  
  - **Practical problem resolved, root cause still not**: <a name='id/BlockNode:00CJ0QG048001' class='aperas-anchor aperas-id'></a> since the leading hypothesis was V8-engine-level degradation intrinsic to one long process (only a genuinely fresh process/V8 isolate resets it), split `verify.ts` into two files instead of chasing the exact mechanism further — `verify.ts` (steps 1-12, `npm run verify`) and the new `verifyExtended.ts` (steps 13-19, `npm run verify:slow`), sharing only small structural helpers (`verifySupport.ts`). Measured live: `verify` now runs in ~42s (down from ~290-326s); `verify:slow` alone runs the same steps 13-19 in ~70-100s (down from ~230s+ *inside* the combined process) — confirming the isolation hypothesis practically without confirming *why* isolation helps. That "why" is deliberately left open in [the next Open Issues entry](#id/BlockNode:00CJ0HX2Y0000) as a narrower, lower-stakes curiosity now that the actual pain (an unaffordable per-turn cost) is gone.
  - **Resolved**: <a name='id/BlockNode:00D1EZNJ30001' class='aperas-anchor aperas-id'></a> the slowdown was measured further on 2026-10-11 and the suite this entry describes no longer exists. What was found: in every slow step the full garbage collections (Mark-Compact) took 70 to 87% of the step's time, and fast steps had 0 or 1 of them; 849 of 895 collections in one run and 1,041 of 1,088 in the other freed 5 MB or less from a heap of about 230 to 450 MB, each pause about 150 to 290 ms, so the cost is repeated full collections that find almost nothing to free (two runs, each cut at 180 s, one sample each). A 50 ms timer between steps cut the collection time in some steps (step 5 from 24,985 ms to 0, step 5d from 47,103 ms to 3 ms, steps 5c and 5f less) and not in others (step 3, step 5g); a bare `setImmediate` yield and no yield did not. A fresh process takes 2.9 s to rehydrate the corpus directory, against 37.8 s in a process that has already rehydrated and dehydrated it (one run, 55,968 quads), so the slowness is state built up in the process and not the data. The old suite's steps 7, 10 and 11 cost 649, 188 and 202 s on the real-size store and milliseconds on a tiny fixture, so the cost came from the size of the store and not from the steps' own work. What replaced it: the monolithic suite (26 steps, about 1,430 s (1,431 s in the run's own table, 1,434 s wall) in one measured run) is retired and deleted, its checks are standalone files in groups under `monorepo/packages/cli/src/tests/`, `npm run verify` runs the `commit` suite in 8 to 20 s, and `npm run verify -- --suite demand` runs 56 cases on a copy of the real mirror in 73 s and 74 s (two occasions); the built suites are in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001). What is still a reading and not shown: that the trigger is V8 starting full collections when external (wasm) memory has grown past its limit, which the collection cannot lower because the wasm side is released by a later callback, was not tested; the earlier guess of a JIT-level degradation is replaced by the collection reading and was not tested either. The core's own cost is not fixed, only the suite made independent of it, and stays open in [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001) and [the removal-stall issue](../issues/core.md#id/BlockNode:00CVNX6A3R000).

- **Why isolation helps is still unexplained** — narrower and lower-stakes now that the split above removes the actual pain, but the mechanism itself is still just "two ruled-out hypotheses and one unconfirmed one" (see the entry above: not oxigraph's own memory footprint, not V8 heap-size — leading guess is inline-cache megamorphism or similar JIT-level degradation in a long process running many differently-shaped operations, never directly confirmed). Worth a closer look sometime with real V8 profiling (`--prof`/`--trace-deopt`) if it recurs somewhere a process split isn't a viable fix, but not worth chasing further here.
  
  - **Resolved**: <a name='id/BlockNode:00D1EZSCH8001' class='aperas-anchor aperas-id'></a> explained, in part measured, not proved (2026-10-11). Measured: the slow steps are repeated full garbage collections (Mark-Compact), 70 to 87% of the time of every slow step, that free 5 MB or less each from a heap of about 230 to 450 MB; a 50 ms timer between steps cut them in some steps (step 5 from 24,985 ms to 0, step 5d from 47,103 ms to 3 ms) and not in others (step 3, step 5g), and a `setImmediate` yield or none did not; a fresh process rehydrates the same directory in 2.9 s against 37.8 s in a process that has already rehydrated and dehydrated, about thirteen times (one run); the old suite's steps 7, 10 and 11 cost 649, 188 and 202 s on the real-size store and milliseconds on a tiny one. This replaces the leading guess of inline-cache megamorphism or another JIT-level degradation in a long process, which the collection measurements replace as the reading and which was itself not tested; the V8 profiling (`--prof`, `--trace-deopt`) proposed here was not run. Still a reading and not shown: that the trigger is V8 starting a full collection when external (wasm) memory has grown past its limit, which the collection cannot lower because the wasm side is released by a later callback, so that a pause lets the callbacks run and stops the collections; it was not tested whether `free()` on the quads, which leaves external memory flat in the earlier scan test, would remove the growth. Two runs, each cut at 180 s, one sample per variant. The suite no longer depends on it: the monolithic suite is retired and replaced by standalone files, `npm run verify` runs the `commit` suite in 8 to 20 s and `npm run verify -- --suite demand` runs 56 cases on a copy of the real mirror in 73 s and 74 s, as recorded in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001); the core's cost itself stays open in [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001).
