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
  - **Since measured (2026-10-12), the mechanism refined, not resolved**: <a name='id/BlockNode:00D22Z4RF0001' class='aperas-anchor aperas-id'></a> the Coder's profile of one insert ([the cost-of-a-write issue](#id/BlockNode:00D22Z1HJ8001)) tested the mechanism under Root cause on an instrumented scratch service, with a pinger sending a ping every 50 ms (the client's own timeout is 300 ms).
    
    - **Measured**: <a name='id/BlockNode:00D22Z4RF0002' class='aperas-anchor aperas-id'></a> in the two runs whose events were logged (12 tasks over 1 s) no request's `data` event was logged inside any task window; a ping sent in a window was logged as received 0 to 60 ms after the window ended and answered 0.4 to 2.2 ms after receipt. In all six runs (3 on a big artifact, 3 on a small one) the pinger saw exactly one slow ping per busy window, of 1.3 to 4.7 s.
    - **What it shows**: <a name='id/BlockNode:00D22Z4RF0003' class='aperas-anchor aperas-id'></a> a request is refused while the service is busy not because of the queue but because the work is synchronous. `runInsert`, `checkArtifactLinkIntegrity` and `dehydrateToJsonLd` never yield to the event loop, so the socket is not read at all while one runs, and a ping never reaches the queue. The queue would add ordering only if the handlers yielded, and they do not. This answers the first item under Not proven: a ping does not wait in the queue for part of its 300 ms, it is not read until the work ends.
    - **Windows in which the service is unreachable to a ping**: <a name='id/BlockNode:00D22Z4RF0004' class='aperas-anchor aperas-id'></a> the whole handler of an insert (1.6 s on a small artifact, 3.2 s on a 5,200-line one), and again the timer's dehydrate (1.4 s) at a point set by the 10 s timer within 10 s of any write. The orchestrator's refused `aperas flush` 0.7 s after an insert (a stall test, one sample) fits such a window.
    - **Not shown**: <a name='id/BlockNode:00D22Z4RF0005' class='aperas-anchor aperas-id'></a> the mechanism was shown for an insert and the timer flush on scratch services; the other verbs and the live service were not measured. Whether the retry of the "Fix to try" below would have to outlast a window of 1.4 to 3.2 s to help is a reading, not tested.
  - **Since observed (2026-10-15), three more times**: <a name='id/BlockNode:00D3YH8H08001' class='aperas-anchor aperas-id'></a> in the survey of the callers, `aperas tree design/core.md` and `aperas unfold BlockNode:00D24N87T0003` answered "No ApeironNgn service running" while the service processes were alive, for about 40 s and then about 20 s, and waiting and retrying worked each time. In the isolated service trial, one `ingest` right after another call returned the same message on the trial's service, whose ping timeout of 300 ms the busy service had missed; the retry worked. Nothing was started, stopped or restarted in either case.
  - **Since observed (2026-10-15), a busy service looked stopped, and the message led to a second start**: <a name='id/BlockNode:00D457SD1R001' class='aperas-anchor aperas-id'></a> reads and writes answered "No ApeironNgn service running" again and again while the service process was alive and listening. At its slowest the CPU was clamped ([the clamp](#id/BlockNode:00D457M2F8001)), but any request that keeps the service busy for over 300 ms does it: `PING_TIMEOUT_MS = 300` (`cli/src/apeironNgn/serviceClient.ts:23`), and `ensureServiceRunning` (line 149) throws the message at line 151 whenever the ping fails, a busy service included. A person who followed the message ran `aperas service start` a second time, and it replaced the socket, the lock and the token and left the first service running and unreachable ([the second `service start`](#id/BlockNode:00D4198VGG001)). Read from the code, not run: `runStart` (`cli/src/kgService.ts:50-56`) pings with the same 300 ms and, when the ping fails, clears the lock without asking whether its pid is alive and spawns another service; that fits the observation.
    
    - **Fix directions, listed and not chosen**: <a name='id/BlockNode:00D457SD20000' class='aperas-anchor aperas-id'></a> a longer or adaptive timeout; a retry; telling a refused connection (no service) from a timeout (a busy one) in the message; checking that the lock's pid is alive (`isProcessAlive` exists in `serviceLock`) before the message and before `runStart` clears the lock; making `service start` refuse when a service process is alive. They add to the "Fix to try" above.
    - Related: <a name='id/BlockNode:00D457SD20001' class='aperas-anchor aperas-id'></a> [the start-wait entry](#id/BlockNode:00D0W05P08001) (the lock turns ready after the wait ends; its second-start observation) and [step 8 of Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000M), the service. The code is the working engine's; the new engine's service is outside this document, so the entry belongs to the service lifecycle, an Open point of [the design](../design/core.md#id/BlockNode:00D24N87T000W).
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
  - **Since sampled (2026-10-12), one sample, the gap is present on the current code**: <a name='id/BlockNode:00D22ZC858001' class='aperas-anchor aperas-id'></a> the Coder, while profiling an insert, used a plain scratch service on a copy of the mirror and ran `echo text | aperas insert BlockNode:00CR9ME608000 --flush` under a heading of `.threads/coder.md`, then `aperas flush`. `.state/BlockNode.jsonld` and `BlockNode.jsonld` were both unchanged (the string was in neither file after 6 s), although `aperas show` returned the new text. So neither `--flush` nor `aperas flush` wrote the thread node to `.state/`, which the agreed fix would make them do (part 1 above). The code reading agrees with Root cause: `insert` sets only `dirty`, `flushIfDirty` excludes thread-scoped nodes, and `flushStateIfDirty` runs only when `stateDirty` is set, which `unfold`, `fold`, `zoom` and the sweeps set. The sample was not repeated, and no other verb or thread file was tried.
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
      
      - **The store is Oxigraph's WASM store, whose linear memory grows and never shrinks, and each reload builds a new store, so a leak in reload or removal could keep old stores alive** (hypothesis, written 2026-10-02 as untested; measured in part since: the reload keeps the old store alive until an event-loop turn (2026-10-10), and external memory added by the boot sweeps was seen never to shrink; no leak in reload or removal was shown. After [the `free()` landing](../history/core.md#id/BlockNode:00D21FP4ZG003) of 2026-10-12 the old `Store` is still left to the garbage collector at reload, because the whole-store `free()` on reload was left out. The growth that followed the unfreed wrappers of the scans stopped in a scratch process, where eight scans stay flat at about 265 MB, and a fresh service answered at 379 MB resident where a fresh service had idled at 1.05 to 1.5 GB, one sample; the removal scan is replaced by the object-bound form of commit `0a7a226`. Whether resident memory still grows over a longer run is not shown)
        
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
      - **The other counts in the record are other moments, or other quantities, not corrections of this one** (reconciled 2026-10-12 against the entries themselves): the store grows with every write, mostly thread blocks and their links, so each figure belongs to its date. On 2026-10-02 the memory entry's 37,000 and 39,600 had no recorded method. On 2026-10-10 the store held 41,752 by `store.size`, and the live service logged 41,246 at its boot; the scans entry's 41.7k is this count. On 2026-10-11 a fresh copy of the real store held 47,836 (the Coder's comparison of the id sets by kind with the full scan; the testing design's "about 48,000" agrees with it), and the service had logged 50,055 at its previous start; two corpus copies of that day held 55,714 and 55,968 (the round-trip measurements, and the testing design's 55,968); the service logged 58,376 at its start that day (12:32 UTC); the Coder's copies for the `free()` item held 58,780 and, for its patch, 59,275. The 46,519 and the 50,610 are not store sizes: 46,519 is the number of `add()` calls of one rehydrate, 4,767 of them duplicates (46,519 less 4,767 is the 41,752), and 50,610 is a count derived from the mirror that overshoots for the same reason. Whether a count includes `.state/` is stated only where it is split (29,537 and 12,216 on 2026-10-10); the others are counts of a full store.
        
        - **Data size on disk follows the same rule**: <a name='id/BlockNode:00D217Y2N8002' class='aperas-anchor aperas-id'></a> the 3.66 MB of the memory entry's title is the mirror when the entry was filed (2026-10-02), the testing design's "a 5 MB `Apeiron/` directory" was read on 2026-10-11, and `du -sb` on `Apeiron/` measured 6.27 MB on 2026-10-12, with `.state/` inside it; whether the earlier figures included `.state/` is not recorded.
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
  - **Since measured (2026-10-12)**: <a name='id/BlockNode:00D22ZD780001' class='aperas-anchor aperas-id'></a> the two sweeps cost 831 ms before and 780 ms after one insert into the 5,200-line `discussion/aperas-skill.md` (a copy of the mirror; medians of 6 inserts in 3 fresh processes), and 24 and 18 ms for a 37-line artifact. The remark parse of every block's text (`collectLinkCodesFromText`) is 1,070 ms of the 1,574 ms the profile attributes to them. The measurement and the other cost centres of one write (a path index over all live blocks, the timed dehydrate) are in [the cost-of-a-write issue](#id/BlockNode:00D22Z1HJ8001).
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
    
    - The object-bound `removeDanglingUnfolds` landed in commit `0a7a226` and ran in the live service: it replaces the scan of every quad, made once per embedded node removed, with one `store.match` on the predicate `unfolds` and the deleted id as object. Result (2026-10-11, one removal in the live service): a task of 164 live blocks and 101 embedded `Link` nodes was removed in 3.7 s with no stall, the tree then showed every other task intact, and `aperas check-links` scanned 6,549 live blocks with 0 discrepancies. Before it, removals of 42 and 31 blocks stalled the service for 5.4 and 12 minutes, and a scratch removal of 34 embedded nodes took 21 s with 34 full scans. On a copy of the real store the old form took 512.8 ms per deleted id and the object-bound form 0.015 ms. It covers every field of a `TreeView` that holds an unfolded id and exists in code, which is `unfolds` alone. The `free()` item below landed as commit `d794060` on branch `oxigraph`, with its measurements and its live check recorded in that item; Layers 1 to 3 and the pause are not decided and not tried, and are parked until the comparison with a JavaScript engine.
    - **`free()` on the quads and the terms read from them** (measured 2026-10-11, one sample; the first remedy for the scans in the service; landed 2026-10-12 as commit `d794060` on branch `oxigraph`, as one read helper that frees at the root)
      
      - **Measured**: <a name='id/BlockNode:00D1DP5GG0002' class='aperas-anchor aperas-id'></a> ten full-store scans in one tick, baseline external memory 90.7 MB. Left to the finalizer: 223 ms a scan and 253.9 MB external. `q.free()` on each quad: 162 ms a scan and 115.8 MB external. `q.free()` plus the subject term freed: 109 ms a scan and 101.3 MB external, with no growth after the first scan. Resident set size across the three variants: 499, 351 and 289 MB. What had no effect was a forced `gc()` without a turn, not `free()`.
      - **Caveats**: <a name='id/BlockNode:00D1DP5GG8000' class='aperas-anchor aperas-id'></a> one sample, ten scans in one tick; the first scan's +10.6 MB of wasm memory is never returned; a term read from a quad (`q.subject`) is a separate object with its own handle that must be freed too; `allIdsOfKind` reads the subject twice per quad.
      - **Plan**: <a name='id/BlockNode:00D1DP5GG8001' class='aperas-anchor aperas-id'></a> `free()` was the first remedy for the scans in the service, before Layer 1 (bound matches), Layer 2 (the index) and the pause, which stays the safety net. It landed as commit `d794060` (see **Landed** at the end of this item). Layers 1 to 3 and the pause are not decided and not tried, and are parked until the comparison with a JavaScript engine (the user's plan, the next entry in Fix directions); a sample of one was not a measurement of the service, and the measurements in **Landed** are the ones that count.
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
        - **Still unknown** when the survey was made (2026-10-11): <a name='id/BlockNode:00D1GCR1Y0003' class='aperas-anchor aperas-id'></a> the same plateau for the other sites (only `allIdsOfKind` was measured, with one corpus size), and whether `new Store()` freed on reload is a gain or a hazard for a request in flight (requests go through `enqueue()`, `service.ts:5`, but the swap at 378-379 was not traced against held references). Since the landing, [the Landed entry](#id/BlockNode:00D216W8Z0001) records the plateau on production code for `allIdsOfKind`, the dehydrate and the rehydrate, on one corpus size (59,275 quads); the gain split by site is not shown, and whether releasing the old `Store` on reload is a gain or a hazard stays unknown, because the whole-store `free()` on reload was left out of the change.
      - **Landed** (2026-10-12): <a name='id/BlockNode:00D216W8Z0001' class='aperas-anchor aperas-id'></a> the patch is commit `d794060`, "Fix core performance 2", on branch `oxigraph`: the read helper of the map above, in the form the Coder recommended (plain-value reads, write helpers that take strings, `predIri` cached per field name), with the two rules that every wasm object is freed at the root as soon as its value is read and that no shared constant is freed. The whole-store `free()` on reload, the plain JavaScript engine and new `TreeView` fields stay out, as the user's plan says.
        
        - **What changed**: <a name='id/BlockNode:00D216W8Z0002' class='aperas-anchor aperas-id'></a> ten files, two of them new: `storeAccess.ts` in `core` (250 lines) and its test `store/storeAccess.test.ts`, named in the `commit` suite; the converted sites are in `node.ts`, `dehydrate.ts`, `store.ts`, `tree.ts`, `threadScope.ts`, `artifacts.ts` and `vocab.ts`. Every read returns plain strings, numbers, booleans or rows; `eachMatch` frees each quad after its callback and the argument terms in a `finally`; `deleteMatches` frees a quad only after deleting it; `addQuad` frees the quad and its terms. `decodeLiteral` also frees the datatype term it made.
        - **Checked by the orchestrator**: <a name='id/BlockNode:00D216W8Z8000' class='aperas-anchor aperas-id'></a> the diff scope and `storeAccess.ts` read in full; `npm run verify -- --suite essential` 27 of 27 in 3.2 s and `npm run verify` (the `commit` suite) 61 of 61 in 19.5 s; `tsc --noEmit` on `core` and `cli` printed nothing. The `demand` suite and the legacy suite were not run.
        - **Measured on a copy of the mirror** (the Coder; production code, 59,275 quads, 3 samples per case, a fresh process each, `gc()` between calls): eight `allIdsOfKind` calls went from 349 to 634 MB (+40 MB a call) to flat at about 265 MB (264.6 to 264.7), and from 0.7 to 1.7 s a call to 0.14 to 0.23 s; a dehydrate of both mirrors went from 33 to 38 s to 2.5 to 3.8 s, with resident size from about 770 to about 350 MB; a rehydrate went from 3.3 to 3.5 s to 2.0 to 2.9 s, with resident size from about 300 to about 258 MB. The dehydrated directories are byte-identical before and after in all three repetitions.
        - **Live check** (2026-10-12, the orchestrator; one sample each): <a name='id/BlockNode:00D216W8Z8002' class='aperas-anchor aperas-id'></a> `aperas service restart` found no service running and started one; the service answered 17 s after its process started (08:15:59 to 08:16:16 UTC) at 379 MB resident, where a fresh service had idled at 1.05 to 1.5 GB. `aperas tree --view` took 0.57 s; `aperas check-links` over 6,900 live blocks took 2.7 s twice, clean, with the service at 375 to 379 MB across both scans. The second insert into the Freeflow document took 5.0 s and a projection of that document 2.4 s; resident size went from 379 MB at start through 392 and 413 MB after the two inserts to 424 MB after the projection.
        - **Not shown**: <a name='id/BlockNode:00D216W8Z8003' class='aperas-anchor aperas-id'></a> the trend of resident memory over a longer run (the rise of about 45 MB over five commands is one sample, not a trend); the write paths of ingest, `remove` and the tombstone sweeps, which tests cover but no measurement or live run exercised; the gain split by site; and whether releasing the old `Store` on reload is a gain or a hazard. The test-only reads in `verifyDanglingUnfolds.ts` and `verifyLinkRefusals.ts` still read raw quads without `free()`.
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
      - **To check first**: <a name='id/BlockNode:00D0Y9HG30007' class='aperas-anchor aperas-id'></a> the index is kept by the two write helpers `addQuad` and `deleteMatches`, through which the store's `add` and `delete` sites are now routed (commit `d794060`); they keep no index, so the index is not built, and the verify run compares it with a full scan after each operation (not run).
      - **Condition**: <a name='id/BlockNode:00D0Y9HG30008' class='aperas-anchor aperas-id'></a> only if layer 1 still leaves too many wrappers.
    - **Layer 3 — a per-node record cache, the fine-grained index** (a candidate; not decided, not tried)
      
      - **Replaces**: <a name='id/BlockNode:00D0Y9HG3000A' class='aperas-anchor aperas-id'></a> repeated reads of a node's fields through `wrap` and `readField`, each of which crosses into wasm. One plain JavaScript record per node (strings and numbers, no wasm handle), filled by a single subject-bound match with the quads freed at once and invalidated by the write helpers; a set of tombstoned ids is the smallest form.
      - **To check first**: <a name='id/BlockNode:00D0Y9HG3000B' class='aperas-anchor aperas-id'></a> nothing about `free()` itself, which landed on 2026-10-12 and is measured on production code (3 samples per case, one corpus size) in [the Landed entry of the `free()` item](#id/BlockNode:00D216W8Z0001); the write helpers through which a cache would be invalidated exist now, as `addQuad` and `deleteMatches` in `storeAccess.ts`, but they free quads and keep no index, so the record cache and its invalidation by those helpers are unchecked. It sits one level above the library because a wasm quad has no object to be one-to-one with.
      - **Condition**: <a name='id/BlockNode:00D0Y9HG3000C' class='aperas-anchor aperas-id'></a> only if per-node reads still dominate after layers 1 and 2.
    - **Beside the layers, not part of them** (candidates; not decided, not tried)
      
      - **Bulk load**: <a name='id/BlockNode:00D0Y9HG3000E' class='aperas-anchor aperas-id'></a> rehydrate by one `store.load` of an N-Quads string, with the dangling references collected in a JavaScript set while encoding; it would replace the per-quad adds and the second full scan (`store.ts` lines 154 to 158). Untested.
      - **Smaller measures**: <a name='id/BlockNode:00D0Y9HG3000F' class='aperas-anchor aperas-id'></a> yielding to the event loop between phases (the pause) as the safety net for the `free()` item before Layer 1; not decided, not tried.
      - **The flush**: <a name='id/BlockNode:00D0Y9HG3000G' class='aperas-anchor aperas-id'></a> a bulk `store.dump` does not serve it, because the mirror is stable-id JSON-LD; it needs its own design, which does not exist.
  - **Related**
    
    - [The removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X65RB800B' class='aperas-anchor aperas-id'></a> the scan cost per embedded node in a task removal is held there and is not repeated here.
    - [The memory issue](#id/BlockNode:00CVQ4Z968001) and [the removal-stall issue](#id/BlockNode:00CVNX6A3R000): <a name='id/BlockNode:00D0X65RB800C' class='aperas-anchor aperas-id'></a> the scan point already in them (a candidate source of garbage-collector pressure, read, untested) is extended and linked to this entry; this one is filed separately because it covers boot, flush and read paths and not only removal.
  - **Found again 2026-10-12, in the fact-check of the draft `design/core.md`**: <a name='id/BlockNode:00D253J400001' class='aperas-anchor aperas-id'></a>  the Coder counted the scans behind `allIdsOfKind` against the rule of [The index](../design/core.md#id/BlockNode:00D24N87SR015) (lookups answered from three structures, the whole store traversed only for the check at load).
    
    - **Root cause** (read from the code)
      
      - `allSubjectIds` (`storeAccess.ts` lines 204 to 210) is a scan of every quad, and it is what `allIdsOfKind` calls (`dehydrate.ts` line 39): every call to `allIdsOfKind` pays one whole scan, as the entry above records for its callers.
      - Callers counted: <a name='id/BlockNode:00D253J400004' class='aperas-anchor aperas-id'></a> 8 scans per flush of both mirrors (4 kinds tracked, 1 + 3 of the thread scope), `pruneUnreachableTombstones` (5 calls over the kinds), `tombstoneVacuousContainers` (once per round), `buildLiveSlugPathIndex`, `checkLinkIntegrity`, `kgTrack`, the lists of live artifacts and live folders, and `pruneStaleUnfolds`.
      - `allObjectRefIds`, which lists the ids referenced and never defined, is a full scan too and is called once per load.
      - Every other production lookup binds the subject, or the field and the value; these two scans are the exceptions to the rule of the design, and the rule is a goal of the new engine and not a description of today.
    - **Not proven**
      
      - The cost of the extra scans is the one measured above; the Coder did not measure the effect of the set of ids per kind that the design describes.
      - Which callers of "all ids of kind K" drop the tombstoned ids afterwards: the draft design stated that most of them do, a few want the tombstoned ones, and the write of the mirror takes all; no list of the callers by what they keep is recorded. It decides whether [a set of live ids](../design/core.md#id/BlockNode:00D24N87T000X) is worth keeping beside the collection of each kind.
    - **Fix directions**
      
      - None decided. The design's set of ids for each kind would answer `allIdsOfKind` without a scan.
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
  
  - **Since observed (2026-10-15), on a service of the checkout `Aperas.dev` over a clone of the current graph**: <a name='id/BlockNode:00D3YH0QGR001' class='aperas-anchor aperas-id'></a> the start took 6 to 7 s (the clone held about 78.7k quads and 8,700 blocks), against the `READY_TIMEOUT_MS = 5_000` of `serviceClient.ts`. `aperas service start` and `aperas service restart` printed "did not become ready in time" and exited 1 in 3 of 3 starts, although the service came up and the lock turned `ready`; a script that trusts the exit code reads the start as failed. For scale on the same clone, a read verb took 0.85 to 1.15 s through `npm run` (about 0.85 s of it `npm` and `tsx`), a write with `--flush` 2 to 4 s, a `project` write 2.6 s, `check-links` 3.6 to 3.8 s, a `reload` 7.8 to 8.3 s, and the resident memory was 209 to 219 MB after a collection, 360 to 410 MB just after the start and 430 to 495 MB after writes and a full-size load. Nothing was changed. Judged in [Batch 13](../planning/core.md#id/BlockNode:00D3XQQ2W0010), step 2 (the time to ready at boot against the client's waits); no step of the plan changes the constant.
  - **Decided (2026-10-15, the user)**: <a name='id/BlockNode:00D3Z1FX4R001' class='aperas-anchor aperas-id'></a> `READY_TIMEOUT_MS` stays as it is, 5,000 ms. The target is on the new engine: its start is ready within the constant, which [Batch 13, step 2](../planning/core.md#id/BlockNode:00D3XQQ2W0012) measures with the time to ready at boot.
  - **Since observed (2026-10-15), a second `service start`**: <a name='id/BlockNode:00D4198VGG001' class='aperas-anchor aperas-id'></a> a second `aperas service start` while a service is running replaces the socket, the lock and the token, and can leave the first service running and unreachable, so that every command answers "No ApeironNgn service running". It is not a defect of the agents' use of `service start`. Whether `service start` should refuse when a service process is alive is not decided.
  - **Since observed (2026-10-15), the 57 s start was the clamp**: <a name='id/BlockNode:00D457N7XR001' class='aperas-anchor aperas-id'></a> the start of 57 s of the real service in the evening of 2026-10-15 was taken on a CPU clamped to its 400 MHz minimum, 12.7 times slower than normal (a fixed 10M-iteration Python loop took 7.85 s against 0.62 s after the reboot). At normal speed the service listens about 7 s after its launch, in line with the 6 to 7 s of the observation above on the clone. The command still prints "did not become ready in time", because the wait stays 5 s by the user's decision, and the target stands that the new engine's start is ready within it. The rule that a timing is taken with a calibration beside it is in [Layer 7](../planning/core.md#id/BlockNode:00D457HDWG001) of the Verification Plan.
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
  - **The test cases, kept, decided 2026-10-16 (the user)**: <a name='id/BlockNode:00D4P4J3KR001' class='aperas-anchor aperas-id'></a> the 42 live blocks of [42 live `BlockNode`s have no `parent` and no container lists them](#id/BlockNode:00D3YS41VR001) and the artifact of [one live artifact, `concepts.md`, has no `parent`](#id/BlockNode:00D3F6RJCG001), none of them reachable by containment, are left as they stand by the migration of the mirror ([Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8002)), so that they test the resolution of this issue in the new engine. A resolution that collects unreachable nodes would collect all 43, `concepts.md` included; nothing uses `concepts.md` now, and it is kept for the test.
- **One `insert` blocks the service for 1.6 to 3.2 s before its reply and for 1.4 s more after it, and none of it is the parse, the write or the dehydrate on `--flush`: it is a path index rebuilt over every live block, two link sweeps of the target artifact, and the timed dehydrate of all four content classes**: <a name='id/BlockNode:00D22Z1HJ8001' class='aperas-anchor aperas-id'></a> profiled 2026-10-12 by the Coder (`write-cost-profile`, Turn 1) on a scratch copy of the mirror, after the `free()` patch (commit `d794060`). Filed 2026-10-12.
  
  - **Symptom**
    
    - One inserted paragraph of about 600 characters, no `--flush`, on a copy of the mirror of 7,433 live blocks and 62,792 quads. The handler wall time before the reply was a median of 3,234 ms (3,096 to 3,295) on the 5,200-line `discussion/aperas-skill.md` and 1,572 ms (1,519 to 1,755) on the 37-line `planning/core.md`, with CPU of 3,849 and 1,697 ms. The CLI process wall was 3.79 s and 2.10 s, so the client's own start, stdin, ping, connect and print take about 0.55 s of it. Cells: 6 inserts in 3 fresh processes for the big artifact, 6 in 3 for the small one.
    - The single sample of the stall test (3.84 s wall, 4.36 s of service CPU) reproduces: 3.52 to 3.63 s unprofiled and 3.71 to 3.76 s profiled, 2 inserts per cell, one process per cell.
    - The reply is sent only after the second link sweep, because the handler defers nothing; the reply is 167 bytes.
    - After the reply the 10 s timer finds the store dirty and runs `dehydrateToJsonLd`: 1,401 ms wall (1,367 to 1,469, 6 flushes after big inserts), 1,383 ms after small inserts and 1,399 ms after inserts with a link. It comes 0 to 10 s after the write, by the timer's phase. Service CPU over the 14 s after an insert was 158 to 218 ticks (median 177; 19 inserts in 11 processes unprofiled), which is this flush.
  - **Root cause** (profile and counts of the Coder; line numbers are declaration lines in the source, because the profiler reports line 1 or 2 for TypeScript run through `tsx`)
    
    - **The path index follows the store, not the artifact**: <a name='id/BlockNode:00D22Z1HJG004' class='aperas-anchor aperas-id'></a> `rejectSlugPathCollisions` (`node.ts:986`) calls `buildLiveSlugPathIndex` (`node.ts:957`), which the code itself documents as a fresh full scan, on every write. It took a median of 1,556 ms on the big artifact and 1,527 ms on the small one. Inside it: `liveBlockNames` 1,247 ms, `toPath` (`node.ts:430`) 1,125 ms, which walks the `parent` chain of each block up to its artifact with no cache (about 8.7 `parent` reads per live block), and `allIdsOfKind` 144 ms. Counts for one insert: one full scan (62,792 quads materialised), about 170 thousand bound `store.match` lookups at about 9 microseconds each, and 91,224 `wrap` calls on the big artifact (72,088 on the small one).
    - **The path check recomputes shared ancestors** (added 2026-10-14, read in the code by the orchestrator): `toPath` climbs from each block to its artifact on its own, so the slug path of an ancestor shared by many blocks is recomputed once for every block below it, within the one rebuild of the index that each write makes.
    - **The two link sweeps follow the artifact, not the store**: <a name='id/BlockNode:00D22Z1HJG005' class='aperas-anchor aperas-id'></a> `checkArtifactLinkIntegrity` (`linkIntegrity.ts:131`) ran 831 ms before and 780 ms after the operation on the big artifact, and 24 and 18 ms on the small one. About 1,070 ms of the 1,574 ms in the profile is `collectLinkCodesFromText` (`astParser.ts:517`): the remark parse of every block's text, run for every block of the artifact twice, with no cache. This is the cost the [per-write re-parse issue](#id/BlockNode:00CVQHBP0R001) names.
    - **The timed flush follows the store**: <a name='id/BlockNode:00D22Z1HJG006' class='aperas-anchor aperas-id'></a> 1.4 s for both artifacts. In the 14 s window after an insert (3 profiles, 42 s sampled) 88.7 percent of the samples were idle and `flushIfDirty` was 3,988 ms inclusive, i.e. nothing else; inside it `allIdsOfKind` 1,651 ms (4 full scans, 334,075 quads materialised), `serializeDoc` 1,331 ms and `isThreadScopedId` 847 ms (per block `owningArtifactOrFolderId` and `firstRefIriOf`). It dehydrates all four content classes after an insert, which changes `BlockNode` and at most `ArtifactNode`.
    - The parse of the new text, the hydration, `resolveBlockLinks`, the placement and the line numbering cost 0 to 3 ms each; a link in the text adds 1 to 2 ms. The `setInterval` of 3 s (`flushStateIfDirty`) does nothing after an insert, as an insert sets only `dirty` (see [the thread-write issue](#id/BlockNode:00CVNZXVR8001)).
    - Garbage collection is 3 to 5 percent of the wall time (156 collections in an insert on the big artifact, 114 ms of pause); the CPU time above the wall time is V8's helper threads.
  - **What it is not**
    
    - The `free()` patch is not the cause: <a name='id/BlockNode:00D22Z1HJG00A' class='aperas-anchor aperas-id'></a> `freeWasm` costs 98 ms of the 3,034 ms handler (3.2 percent). With `freeWasm` made a no-op, the first insert in a fresh process was about the same (3,566 to 3,635 ms big, 1,840 to 1,953 ms small), but the second insert in the same process took 31.5 to 33.3 s on the big artifact (up to 12 s on the small one) after 180 to 195 major collections, with 1.12 to 1.29 GB resident against 432 to 462 MB with the patch, and the timer flush after it 19 to 25 s. So the patch holds the cost at the level above and what is left is the access pattern it cannot touch: one `store.match` and one new wasm term for every field read, repeated about 170 thousand times, plus 7,433 uncached ancestor walks.
    - The timer flush is not the cost of the write, but a second block of its own that falls within 10 s of it.
  - **Not proven**
    
    - That the index build is linear in the store: <a name='id/BlockNode:00D22Z1HJG00D' class='aperas-anchor aperas-id'></a> the store size was not varied, so the claim is read from the code (one `wrap` and one ancestor walk per live block).
    - The 0.55 s of the CLI process was not split further (one sample set; an earlier read of 0.6 s agrees).
    - The live service was not profiled: <a name='id/BlockNode:00D22Z1HJR000' class='aperas-anchor aperas-id'></a> it reported "Running code is stale" and the Coder did not touch it. Its resident size after a day near 450 MB (patched) or above 1 GB would show which code it runs.
    - Only `insert` was profiled. `update`, `remove` and `retype` share the two sweeps, and whether they share the path index was not measured.
    - Counters and timers added about 6 percent to the wall time, the profiler about 4 percent.
  - **Fix directions**
    
    - None decided. The Coder's proposals, each of which changes behaviour, listed as candidates and none tried:
      
      - Do not rebuild the index on every write: <a name='id/BlockNode:00D22Z1HJR005' class='aperas-anchor aperas-id'></a> look up the candidate names of the new subtree directly (an index query by path), or keep the index across writes and invalidate it on the write itself. The name set is the path plus embedded anchors, and whether anchors are global, which decides whether a per-artifact index is enough, could not be told from the code.
      - Make `toPath` cheap in bulk: <a name='id/BlockNode:00D22Z1HJR006' class='aperas-anchor aperas-id'></a> memoise the ancestor title chain, or compute the index in one top-down walk instead of one bottom-up walk per block.
      - For the link sweeps: <a name='id/BlockNode:00D22Z1HJR007' class='aperas-anchor aperas-id'></a> sweep only the written subtree, or cache `collectLinkCodesFromText` per block text, since the before and after sweeps parse the same unchanged text twice.
      - Do not run `dehydrateToJsonLd` on the loop in one piece: <a name='id/BlockNode:00D22Z1HJR008' class='aperas-anchor aperas-id'></a> write only the class files a write changed, or chunk it so the loop can answer; and let `ping` answer while the service is busy (see the refusal measured under [the spurious "not running" issue](#id/BlockNode:00CVMPABY8001)).
      - If none of that is wanted, log the per-task timing; the Coder's instrumented `enqueue` is a model of 15 lines. This is the coverage gap of [the no-coverage issue](#id/BlockNode:00CVQHD7CR001).
  - **Related**
    
    - [The full-store-scans issue](#id/BlockNode:00D0W02KPG001), whose `free()` landing this profile measures; [the start issue](#id/BlockNode:00D0W05P08001), whose startup link sweep costs 3.0 s wall and 4.4 s CPU once per start (3,057, 3,102 and 2,924 ms in three starts).
    - The Coder's question whether the per-field probes should be cheap (a table per predicate) or whether "all fields of one subject" is the unit to optimise, which the census counts support (7,274 of 7,276 `holder` probes and 5,769 of 7,276 `links` probes at a flush found nothing), belongs to the design of the store and is not decided here.
  - **Since observed (2026-10-15), a figure taken on a clamped CPU**: <a name='id/BlockNode:00D457M2F8001' class='aperas-anchor aperas-id'></a> between about 18:00 on 2026-10-15 and the first reboot the CPU held its 400 MHz minimum clock under full load, and a fixed 10M-iteration Python loop took 7.85 s against 0.62 s after the reboot, 12.7 times slower. The 57 s of service CPU for one insert in the idle-CPU trial of that evening (5,693 ticks) was measured on that CPU, so at normal speed it is about 4.5 s, which fits the profile of this entry (1.6 to 3.2 s of CPU per insert on 7,433 live blocks; the graph is about 30% bigger now). The live service was not profiled.
    
    - The trial's reading that the service burns CPU while idle does not stand: over four 60 s windows it used 0%, counted in ticks, which do not depend on the clock speed. The service has no timer that works while idle: of its three timers the 10 s flush and the 3 s flush return at once when nothing is dirty, and the third is the exit after 30 idle minutes.
    - A write on the live service takes a few seconds at normal speed. What is still not measured: one write at full speed with its calibration beside it, by the rule of [Layer 7](../planning/core.md#id/BlockNode:00D457HDWG001) of the Verification Plan.
- **The tree view lists a block's links newest first, not in the order of their `position` in the text, so the displayed order is the store's match order**: <a name='id/BlockNode:00D22ZK7C8001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the orchestrator while checking which reads depend on the engine's order; confirmed by the user's reading of the output. Filed 2026-10-12.
  
  - **Symptom**
    
    - Tested on `BlockNode:00CDBZ7698002`, whose text names its three link targets in the order `00CDBYV4T8002`, `00CDBYV4T8007`, `00CDBYV5A8002`. `aperas unfold` lists the three `Link` nodes in the reverse order of the text (the newest link first); the stored mirror (`BlockNode.jsonld`) lists them oldest first.
    - One block and one view were checked. The projected markdown and the web view were not.
  - **Root cause**
    
    - Read from the code: <a name='id/BlockNode:00D22ZK7C8006' class='aperas-anchor aperas-id'></a> `links` is read with `readField`, which returns the quads in the store's match order, and the tree and unfold rendering print them in that order (`node.ts` near lines 1745 and 1882, `kgUnfold.ts` near lines 109 to 115). Every wikilink carries a `position` prop, the offset of its occurrence in the text, which would give the text order; the renderer does not read it.
    - The same match order is what other readers get, and where it shows (the Coder's census, item 7): the rendering of `links` (above), `toReconcileShape` (`node.ts:527`), `kgLink.ts:54` (which writes the list back in the order it read it), the order of `view.unfolds` in `buildRenderTree` and in `kgProfile.ts:115`, the printed `backlinks` (`kgBacklinks.ts:32`, `kgProfile.ts:69`), and the comparison of a `Link`'s `position` props with the freshly computed list (`positionsEqual`), where a different order only causes a rewrite of the props and never a wrong value. The census counted four `Link`s in the mirror with two positions.
    - The order of the printed `backlinks` carries no meaning (nothing reads it); only the display of a block's own links has an order the text defines.
  - **Not proven**
    
    - Which other views show the same reversal, and whether the reversal holds for every block with several links or only for the one tested.
    - The user's decision of 2026-10-12 is that the engine keeps JavaScript's natural oldest-first order, and the engine will support a reverse view of a field in general; under that order this display would flip to the text order by accident of the engine and not by a rule of the renderer. Where the order of the display is only cosmetic that may be accepted; where a reader's choice depends on it (the case in [the first-match issue](#id/BlockNode:00D22ZMTKG001)) it may not.
    - Whether the render's choice of the one canonical place of a node reached through several unfolded links follows the order of the unfolded ids, which the mirror lists only by id; if it does, the rendered tree depends on that order. Raised 2026-10-12 with the user's decisions on the order, not checked since; the design keeps it as [The canonical-render order check](../design/core.md#id/BlockNode:00D24N87T000Q).
  - **Fix directions**
    
    - None decided.
- **`findByExactPath` takes the first node found at a path, and a path can be held by a tombstoned and a live node, so it returns the live one only because the store lists the newest first**: <a name='id/BlockNode:00D22ZMTKG001' class='aperas-anchor aperas-id'></a> a latent defect, found 2026-10-12 by the orchestrator in the check of order-sensitive reads (the Coder's census, item 7) and called a bug by the user if it would return the removed one. Filed 2026-10-12.
  
  - **Symptom**
    
    - No wrong result is visible today. The real mirror has exactly one path held twice, `issues/cli.md`: a tombstoned `ArtifactNode:00CF1TZQV8000` and a live, newer `ArtifactNode:00CF2AEA78000`. A removed node keeps its `path`, so `path` is unique only among live nodes.
    - `findByExactPath` (`tree.ts:20`) is `firstSubjectWhere(store, 'path', ...)`: <a name='id/BlockNode:00D22ZMTKR000' class='aperas-anchor aperas-id'></a> it takes the first match and does not look at `tombstonedAt`. Today the first match is the newer, live artifact because the store returns the newest first; under oldest-first it would be the old removed one, and nothing in the lookup says that the answer depends on the order.
  - **Root cause**
    
    - The lookup relies on the engine's match order for a choice of node. Its sibling `findLiveByKindAndPath` (`artifacts.ts:188`) filters out the tombstoned and is correct. Callers of the plain one found by `grep`: `resolve.ts:69`, `resolveCreate.ts:98` (both for the root, `.`), `linkIntegrity.ts:323` and `kgProject.ts:46` (an artifact path from the command line), and some verify scripts. Which of them can meet a tombstoned duplicate was not checked for each.
    - The same first-match lookups exist on other fields: <a name='id/BlockNode:00D22ZMTKR003' class='aperas-anchor aperas-id'></a> `findProfileByHandle` (`node.ts:2012`), `findTreeViewByName` (`node.ts:2021`) and the owner of a link. `handle` and `name` are unique by design (the code refuses a duplicate view name) and the real mirror has no duplicate (17 views, none repeated; no repeated handle), so they are not a defect today.
  - **Not proven**
    
    - Which caller of `findByExactPath` could receive the tombstoned node, and what would then happen to it; the check of 2026-10-12 was of the lookup, not of each caller.
  - **Fix directions**
    
    - None decided. The orchestrator's reading of the case: <a name='id/BlockNode:00D22ZMTKR007' class='aperas-anchor aperas-id'></a> the lookup needs a live-first rule (or an explicit order) before the engine's order changes.
  - **Related**
    
    - [The title-ambiguity issue](#id/BlockNode:00CVQ0PVS0001), where `aperas resolve` does not filter tombstoned candidates and a dead holder makes a live path read as ambiguous: the same shape, in the title check of the resolver instead of the path lookup.
    - [The display-order issue](#id/BlockNode:00D22ZK7C8001), which is the order-sensitive read whose effect is only on the screen.
- **`apeironNgnSmokeTest.ts` is referenced by no script, suite or import, and asks for a predicate that no longer exists**: <a name='id/BlockNode:00D22ZV0FG001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the census of the store's predicates and access patterns (item 2). Filed 2026-10-12.
  
  - **Symptom**
    
    - `cli/src/apeironNgnSmokeTest.ts` (lines 99 to 106) calls `backlinks(store, artifact['@id'], '__parent')` and compares the result with `artifact.children`. `__parent` was renamed `parent`, so the call asks for a predicate that no node carries.
    - Nothing runs the file: <a name='id/BlockNode:00D22ZV0FR000' class='aperas-anchor aperas-id'></a> no script, suite or import names it (checked by `grep` over `monorepo/packages`; only the compiler's `tsconfig.tsbuildinfo` lists it). Whether it passes or fails today was not run.
  - **Root cause**
    
    - The rename of `__parent` to `parent` did not reach a file that nothing runs, so no test or build step noticed. [The no-coverage issue](#id/BlockNode:00CVQHD7CR001) records that this script checks rehydrate and field access only.
  - **Not proven**
    
    - Whether the script, run now, would fail at that line or elsewhere; the Coder did not touch it.
  - **Fix directions**
    
    - None decided. The Coder's question, left open for the design of the store: leave the file out of the design's contract, or fix it when the design lands.
- **`encodeDoc` and `mintEmbedded` write any key they are given as a predicate, so the closed predicate vocabulary of the store is not enforced at the two paths that take keys from outside the shape**: <a name='id/BlockNode:00D22ZWZMR001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the census of the store's predicates (item 2); latent, as neither produces a foreign predicate with today's data. Filed 2026-10-12.
  
  - **Symptom**
    
    - None today. The mirror holds 27 predicates and 60,810 quads, every predicate a shape field or one of the two structural ones (`parent`, `__siblingIndex`), and no predicate outside `SHAPE_BY_KIND` and those two (checked for every subject; 0 foreign IRIs). In production code every field name comes from a shape key or is one of nine literals (`parent`, `__siblingIndex`, `path`, `links`, `handle`, `name`, `unfolds`, `target`, `profile`).
  - **Root cause** (read from the code)
    
    - `encodeDoc` (`store.ts:70`) writes every key of a mirror document except `@id` and `@type` as a quad, whether or not the shape has it. A key outside the shape lives in memory, and the dehydrate would later drop it, since `serializeDoc` (`dehydrate.ts:73`) walks only the shape's fields: it would survive until the next flush and then vanish from the mirror.
    - `mintEmbedded` (`node.ts:165`) writes every string, number or boolean key of an embedded entry, apart from `@type`, `@id` and `id`, with no check against the shape of the embedded kind.
    - In the tests, `storeAccess.test.ts` writes made-up predicates `count` and `flag` on scratch stores, and one quad with a foreign subject IRI to prove that `subjectsWhere` throws and `deleteMatches` still works, on purpose; no test or fixture writes any other predicate outside the shape.
  - **Not proven**
    
    - That any real input reaches either path with an unknown key; the census found none and did not try to build one.
  - **Fix directions**
    
    - None decided.
- **Tombstoning does not empty the node at every site: 52 of the 219 tombstoned nodes in the mirror still hold `children`, `links` or `props`**: <a name='id/BlockNode:00D252W7VG001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, re-counted by the orchestrator on the real files, and counted again 2026-10-15 in the Coder's census of a clone of the mirror. Filed 2026-10-12.
  
  - **Symptom**
    
    - Counted 2026-10-15 on a clone of the mirror (the tracked files of `Apeiron/` and `Apeiron/.state/`, read with `jq`): of 219 tombstoned nodes (188 in `Apeiron/`, of which one is an `ArtifactNode`, the holder `cli.md`, and 31 in `Apeiron/.state/`), 52 still hold `children`, `links` or `props`; the rule in [Tombstones](../design/core.md#id/BlockNode:00D24N87SR01V) says a removed node is emptied of all three. In `Apeiron/` none holds `children` or `links` (the `children` key is present and empty on all 188) and 40 hold `props`; in `Apeiron/.state/` 12 hold something: `children` on 4, `links` on 7, `props` on 5. The count is of one moment; the mirror gains tombstones with each removal.
    - 40 of the 52 are `list` and `listItem` nodes tombstoned on 2026-09-11, which is what `tombstoneVacuousContainers` leaves.
    - The other 12 come from one call at 2026-10-02T12:44:35.641Z, all in `.state/BlockNode.jsonld`: 1 `heading` and 11 `listItem` of a thread's Ask, Work and Report (ids `00CS0ZEPH8002` to `00CS0ZEPH8004`, `00CS179PR8001`, `00CS179PR8002`, `00CS179PRG000` to `00CS179PRG002` and `00CS179PRG006` to `00CS179PRG009`).
    - Tombstones also stay in the tree: <a name='id/BlockNode:00D3YT5WD0001' class='aperas-anchor aperas-id'></a> 187 of the 188 in `Apeiron/` still carry a `parent` and are listed in the `children` of their container (the one without a `parent` is `BlockNode:00CR9SRMW8002`), and all 31 in `Apeiron/.state/` carry a `parent`, where [Tombstones](../design/core.md#id/BlockNode:00D24N87SR01V) and [A removed node leaves its container](../design/core.md#id/BlockNode:00D24N87T000R) say a tombstone has none and is in no container's list. 142 of the 188 in `Apeiron/` keep a `text`, as the design allows. Two `Link`s in `Apeiron/` target a tombstoned node (`BlockNode:00CN1PKAQG001:links:Link:00CN1PKEW8002` and `BlockNode:00D24NRBSR001:links:Link:00D24NRQBG002`).
  - **Root cause** (read from the code)
    
    - `applyTombstone` (`node.ts` near line 850), `tombstoneLiveSubtree` (near line 870, used by `aperas remove` and by the artifact removal at `artifacts.ts` near line 272) and the folder removal (`folders.ts` lines 154 to 159) clear `children`, `links` and `props`.
    - `tombstoneVacuousContainers` (`node.ts` near line 2221, run at service start, at reload, at clobber and at shutdown) sets `tombstonedAt` alone, so the 40 nodes above keep their `props`.
    - Tested by the Coder on a scratch store (`/tmp/tomb.mts`): <a name='id/BlockNode:00D252W7VG009' class='aperas-anchor aperas-id'></a> `tombstoneLiveSubtree` leaves `children`, `links` and `props` of the removed nodes empty and also removes the `parent` of every descendant, so a subtree removed by `aperas remove` leaves the removed root in its container's `children` and detaches the rest.
  - **Not proven**
    
    - What produced the 12 nodes of 2026-10-02. They carry text, so the sweep above would skip them (it skips a `listItem` with text, and any `heading`) and does not explain them, and the other sites clear all three. The command is not in the git history of the mirror, because `.state/` is ignored; what would decide is the thread or the user's account of that day.
  - **Fix directions**
    
    - Decided 2026-10-15 for the tombstones the mirror already holds: <a name='id/BlockNode:00D252W7VG00D' class='aperas-anchor aperas-id'></a> the one-time migration strips them from the tree (each loses `children`, `links` and `props`, its `parent` and its entry in the `children` of its container, and keeps its literal properties), in [Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001). For the code that tombstones, the engine does it in [Batch 7](../planning/core.md#id/BlockNode:00D3XQQ2VR014) and the callers in [Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000C), where whether `tree --tombstoned` still shows a removed child is an open point.
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)): 218 of the 219 tombstones were stripped (187 in the mirror and 31 in `.state/`), the 219th being already clean, and 107 containers were edited (98 in the mirror and 9 in `.state/`); after it no tombstone holds a `parent`, `children`, `links` or `props`, and no container lists one. The real mirror keeps its tombstones as they stand until the cutover.
  - **Related**
    
    - [Tombstones](../design/core.md#id/BlockNode:00D24N87SR01V) in the design, which states the rule.
- **Sibling indexes are not kept dense: a move to another parent leaves a gap in the old parent and the next append there can repeat an index**: <a name='id/BlockNode:00D252Y7WR001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, tested on a scratch store. Filed 2026-10-12.
  
  - **Symptom**
    
    - Tested by the Coder on a scratch store (`/tmp/cont.mts`): <a name='id/BlockNode:00D252Y7WR003' class='aperas-anchor aperas-id'></a> children at indexes 0, 1, 2 under one parent; the one at 1 moved to another parent with `insertChild` or `appendChild` (what `aperas insert` with no stdin does); the old parent's others stay at 0 and 2; then `appendChild` on the old parent gave the new child index 2, the same as the last one.
    - The real mirror never shows it: <a name='id/BlockNode:00D252Y7WR004' class='aperas-anchor aperas-id'></a> the file writes the array order, and a reload renumbers.
  - **Root cause** (read from the code)
    
    - No code removes a child and renumbers the rest. A move deletes the child's `parent` and index (`node.ts` lines 87 to 127) and leaves the others as they were.
    - `countMatches` (line 90) gives the next index as the number of children and assumes the indexes are dense.
    - Two children with the same index come out of `orderedChildIds` (`storeAccess.ts` lines 188 to 196) in the store's match order, with no tie-break by id.
  - **Not proven**
    
    - **Question — a moved child with no sibling index**: <a name='id/BlockNode:00D252Y7WR00A' class='aperas-anchor aperas-id'></a> reading `writeField` (`node.ts` lines 242 to 250) suggests that when a reconcile moves a block from an old parent to a new one, and the new parent's `children` is written first, the old parent's later `children` write deletes the child's sibling index (line 244 deletes the indexes of every child it detaches, by subject), and the child stays under the new parent with no index, sorted as 0. The Coder did not run a reconcile with a move. What would decide: a scratch ingest of a document in which a block moves between two headings, then reading the indexes.
  - **Fix directions**
    
    - None decided. Whether the indexes are dense is an Open point of the design (the density of sibling indexes).
  - **Related**
    
    - [Containment](../design/core.md#id/BlockNode:00D24N87SR00Z) in the design.
- **A child can end with two `parent` pairs: writing `children` detaches only the children the container already has**: <a name='id/BlockNode:00D2532JJR001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, tested on a scratch store. Filed 2026-10-12.
  
  - **Symptom**
    
    - Tested by the Coder on a scratch store (`/tmp/cont.mts`): <a name='id/BlockNode:00D2532JJR003' class='aperas-anchor aperas-id'></a> a child written into the `children` of a second container ends with two `parent` quads (the parents of the child read back as both containers).
    - The real mirror has none: <a name='id/BlockNode:00D2532JJR004' class='aperas-anchor aperas-id'></a> 0 children listed by two containers, 0 children undefined, and every listed child carries a `parent` equal to its lister (7,829 `parent` quads and as many `__siblingIndex` quads).
  - **Root cause** (read from the code)
    
    - `writeField` for `children` (`node.ts` lines 238 to 251) detaches only the children that the container being written already holds, so nothing removes the child from the container that held it before.
    - `parent` is declared an optional reference, so the shape does not refuse a second value either.
  - **Not proven**
    
    - Whether any production path writes a child into a second container without first taking it out; the Coder tested the primitive and did not look for such a path.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [Containment](../design/core.md#id/BlockNode:00D24N87SR00Z) in the design, which says a tree node has at most one parent.
- **The kind of an id is read from the `props` and `links` segments only, and an id-like string in a field aborts the load or loads as a reference to a node that does not exist**: <a name='id/BlockNode:00D2534RSG001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, the second part tested on a scratch store. Filed 2026-10-12.
  
  - **Symptom**
    
    - Tested by the Coder on a scratch store (`/tmp/mini.mts`): <a name='id/BlockNode:00D2534RSG003' class='aperas-anchor aperas-id'></a> a title "BlockNode: hello" makes the load throw `Invalid IRI code point ' '`; a title "BlockNode:zzz" loads as a reference to a node that does not exist (reported as dangling); a title equal to a real id reads back as a node, not as a string.
    - The real mirror has no such string (0), and no `preferences` embed (0 of 9 profiles), so neither part shows in the data today.
  - **Root cause** (read from the code)
    
    - **The kind of an embedded id**: <a name='id/BlockNode:00D2534RSR001' class='aperas-anchor aperas-id'></a> `nodeKindFromId` (`vocab.ts` lines 47 to 52) matches only the fields `props` and `links`, so an id such as `Profile:x:preferences:StringProp:y` (the form `mintEmbedded` builds, `node.ts` line 167) is read as `Profile`. The design reads the kind from the last `field:Kind:` segment.
    - **What counts as an id in a value**: <a name='id/BlockNode:00D2534RSR002' class='aperas-anchor aperas-id'></a> `encodeDoc` (`store.ts` lines 100 to 104) with `isNodeRef` (`vocab.ts` lines 38 to 40) tests only the prefix `BlockNode:`, `ArtifactNode:`, `FolderNode:`, `Profile:` or `TreeView:` on every string value of every field. The two resolvers (`resolve.ts` lines 35 to 41 and `resolveCreate.ts` lines 45 to 49) are stricter: a valid snowflake must follow `Kind:`, and only for BlockNode, ArtifactNode and FolderNode.
  - **Not proven**
    
    - Whether a real title or text can reach the load with such a prefix; the mirror has none today. The `text` of a block is a field of the same kind and goes through the same test, which the Coder did not try.
  - **Fix directions**
    
    - None decided. What an id-like string does at load is an Open point of the design.
  - **Related**
    
    - [Ids](../design/core.md#id/BlockNode:00D24N87SR01N) in the design.
- **The store is read directly in places outside the helpers: `nodeExists`, the size, and the dev tools and tests**: <a name='id/BlockNode:00D2536E1R001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`. Filed 2026-10-12.
  
  - **Symptom**
    
    - The design's interface section says callers ask for a fixed list of reads and writes and nothing else; the code departs from it in three places, none of which gives a wrong result today.
  - **Root cause** (read from the code)
    
    - `nodeExists` is in `vocab.ts` (lines 65 to 77) and calls `store.match` itself, not a helper of `storeAccess.ts`.
    - The quad count is read as `store.size` in `store.ts` (line 147).
    - The dev tools `verifyDanglingUnfolds.ts`, `verifyLinkRefusals.ts` and `apeironNgnSmokeTest.ts`, and the tests, call `store.match`, `add` and `delete` directly. The production code does not otherwise.
    - The wasm objects of these direct reads are freed by the helpers of `storeAccess.ts` for the production code; the dev tools and tests hold quads. `vocab.nodeExists` frees its own.
  - **Not proven**
    
    - Whether the dev tools and tests should count as callers of the interface, or only the production code; the design does not say.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [The engine's interface](../design/core.md#id/BlockNode:00D24N87T0003) in the design.
    - [The smoke-test issue](#id/BlockNode:00D22ZV0FG001), which is one of the direct callers.
  - **Map of the callers above the store** (the Coder's survey before Batch 11, 2026-10-15, of `monorepo/packages` at commit `d794060`; read, not edited; counts are upper bounds, since the import counts include comments and alias spellings and the instance-surface counts are by name, so they include unrelated methods of the same name)
    
    - **(1) Exports used, with call counts** (identifier occurrences outside the import line, comments included; "files" in brackets)
      
      - `index.ts` (3 re-export lines) is imported by nothing: <a name='id/BlockNode:00D3YFA80R003' class='aperas-anchor aperas-id'></a> every consumer imports `@aperas/core/apeironNgn/<module>`. `apeironNgnSmokeTest.ts` (139 lines, uses `backlinks(…, '__parent')`, a field that no longer exists), `compareMigration.ts` (124 lines, a TerminusDB comparison) and `index.ts` are referenced by no script, suite or file.
      - **Commands** (17 `kg*.ts` files; 26 exported `runX(store: Store, …)` entry points; each imports `type { Store }` from `oxigraph`): `wrap` 41 (14 files), `resolveDeepPath` 21 (13), `backlinks` 12 (2: `kgBacklinks.ts`, `kgProfile.ts`), `resolveBlockLinks` 11 (`kgInsert.ts`, `kgUpdate.ts`), `displayLabel` 9 (5), `nodeKindFromId` 8 (6), `nodeExists` 5 (`kgFold.ts:19`, `kgShow.ts:26`, `kgUnfold.ts:106,131`, `kgZoom.ts:28`), `allIdsOfKind` 5 (`kgProfile.ts:65,111`, `kgTrack.ts:82,92,104`), `assertLinksAcceptable` 4, `resolveTreeView` 4, `collectOldWikilinksByBlock` 3, `findEnclosingArtifactId` 3, `deriveAbstractFromLiveChildren` 3, `trackAllArtifacts` 3, `buildRenderTree` 3, `findProfileByHandle` 3, `tombstoneLiveSubtree` 2 (`kgRemove.ts:42`), `applyTombstone` 1 (`kgUpdate.ts:332`), `serializeDoc` 2 (`kgShow.ts`), and one or two each of `ingestAllArtifacts`, `ingestArtifacts`, `findLiveArtifactByPath`, `trackArtifact`, `retryDanglingRefs`, `ingestFolderTree`, `findByExactPath` (`kgProject.ts:46`), `ownerOfLink`, `removeProfile`, `createTreeView`, `removeTreeViewByName`, `findTreeViewByName`, `hasHolderDescendant`, `rejectSlugPathCollisions`, `resolveDeepPathDetail`. No command calls a `storeAccess` helper or touches an Oxigraph object; they reach the store only through `wrap` and these functions.
      - **Instance surface used on a wrapped node** (core and non-test cli, comments included): `toPath` 28, `treeChildren` 32, `ingestFromDisk` 10, `hydrateFromParsed` 12, `appendChild` 8, `insertChild` 8, `trackFromDisk` 5, `toMarkdown` 7, `toReadme` 5, `mintWikilink` 4, `findChild` 4, `renderTree` 9, `toReconcileShape` 5, `addLink` 2, `collectDescendants` 2, plus every shape field as a property (`links`, `props`, `unfolds`, `children`, `parent`, `tombstonedAt`, `holder`, `title`, `text`, `path`).
      - **Service** (`service.ts`, not importing `Store`; holds `let store` and passes it to every `runX`): `rehydrateStore` 2 (`:162`, `:378`), `getApeironExportDir` 2, `dehydrateToJsonLd` and `dehydrateStateToJsonLd` 4 each (`flushIfDirty`, `flushStateIfDirty`, `clobberFlush` ×2), `DEHYDRATE_CLASSES` and `STATE_CLASSES` 5 each, the three sweeps `tombstoneVacuousContainers`, `pruneUnreachableTombstones`, `pruneStaleUnfolds` at four sites each (`:202-204` startup, `:365-373` reload, `:418-420` clobber, `:474-478` shutdown), `resolveTreeView` 4, `checkLinkIntegrity` 2, `checkArtifactLinkIntegrity` 5, `repairLinkIntegrity` 1, `owningArtifactId` 1, `isThreadScopedId` 1, `runMigrateFrontmatter` 1, `resolveDeepPath` 2, `nodeKindFromId` 1, `wrap` 1; the 30 `case` arms of `handle()` (`:488-695`) call the `runX` functions.
      - **Web** (`packages/web`): <a name='id/BlockNode:00D3YFA810003' class='aperas-anchor aperas-id'></a> no import of core or of the engine. It meets the code only through JSON: `tree` with `format: 'render-tree'` (`apiRoutes.ts:49`, mirrored by hand in `web/src/render.ts:2-8`), `backlinks` (`render.ts:73`), `show`, `unfold`/`fold`/`zoom`, `profileListView`, `update`. The one field of that JSON that the engine change can touch is a link's `predicate` (`render.ts:42`, `FolderDiv.tsx:534`). `web/devApiServer.ts` imports only `serviceClient` and `apiRoutes`, both engine-free.
      - **Tests and tools** (calls outside `src/`): <a name='id/BlockNode:00D3YFA810004' class='aperas-anchor aperas-id'></a> `wrap` 62 (13 files), `trackArtifact` 21 (9 files) and `ingestArtifact` 21 (8 files), `findByExactPath` 12, `ingestFolderTree` 14, `allIdsOfKind` 7, `rehydrateStore` 8 (7 files), `dehydrateToJsonLd` and `dehydrateStateToJsonLd` 4 each, `ensureDefaultView` 4, `checkLinkIntegrity` 5, `repairLinkIntegrity` 5, and every `storeAccess`/`vocab` name in `tests/store/storeAccess.test.ts` alone.
      - **The 12 helpers of `storeAccess.ts` against the engine's interface** ([the interface](../design/core.md#id/BlockNode:00D24N87T0003)): <a name='id/BlockNode:00D3YFA810005' class='aperas-anchor aperas-id'></a> `objectsOf` (4 production sites: `node.ts:137,210,268`, `dehydrate.ts:44`) and `firstLiteralOf`/`firstRefIriOf` (1 each, `threadScope.ts:20,37`) are "the values of field F of subject S"; `orderedChildIds` (3: `node.ts:71,107`, `dehydrate.ts:75`) is "the children in order"; `deleteMatches` (11 sites, all in `node.ts`; one unbound subject at `:235`, the `unfolds` sweep, which is "remove the pairs that name a value in a field") and `addQuad` (11 in `node.ts`, 5 in `store.ts`) are the writes; `subjectsWhere` with a reference object (`node.ts:242,2132`) and `firstSubjectWhere` with a reference (`node.ts:1397`) are "the subjects whose field holds node V". Not offered by the interface and so not re-implementable on it: `subjectsWhere`/`firstSubjectWhere` with a **literal** object (`tree.ts:21` for `path`, `artifacts.ts:189` for `path`, `node.ts:2013` for `handle`, `node.ts:2022` for `name`: four sites, all Batch 10); `allSubjectIds` (1 site, under `allIdsOfKind`, 21 production callers) and `allObjectRefIds` (1 site, `store.ts:144`), which become the kind collections and "referenced and never defined"; `countMatches` (1 production site, `node.ts:90`, the sibling count of `appendOrderedChild`), which the ordered-field splice replaces.
    - **(2) `node.ts` by layer** (2,241 lines; ranges are approximate, line counts rounded)
      
      - **Engine access, about 350 lines**: <a name='id/BlockNode:00D3YFA810007' class='aperas-anchor aperas-id'></a> `ApeironNode` type 55-63; `childrenOf` 70-72; `appendOrderedChild` 87-93; `insertOrderedChild` 106-127; `decodeObj`/`readField`/`idOf`/`clearField` 129-158; `mintEmbedded` 165-186; `hardDeleteNode` 205-217 (called from four sites: `writeField:271`, `removeTreeViewByName:2049`, `pruneUnreachableTombstones:2184`, `removeProfile:2238-2239`); `removeDanglingUnfolds` 230-236; `writeField` 238-311; `ApeironInstance` 317-325; `appendChild`/`insertChild` of `BlockNode` 491-502 and `FolderNode` 1121-1129; `CLASS_BY_KIND`/`classForId` 1281-1296; `defineAccessors` 1302-1323; `wrap`/`backlinks` 2117-2133.
      - **Render, about 690 lines**: <a name='id/BlockNode:00D3YFA810008' class='aperas-anchor aperas-id'></a> `TreeNode.renderTree` 417-422; the plain renderer 1325-1374; the view cone, `isInCone`, `ZoomState`, `discoverCone` 1376-1572; the item types 1574-1668; `bakeResolvedLinkIds` 1670-1709; `buildNodeItem`/`buildLinkItem` 1711-1902; `toText` 1904-1964; `buildRenderTree`/`renderTreeWithView` 1966-2007. Pure caller logic over `wrap`, `treeChildren`, `links`, `parent` and `backlinks(…, 'target').length` (`:1762`, one count per rendered node).
      - **Ingest, track and project, about 610 lines**: <a name='id/BlockNode:00D3YFA810009' class='aperas-anchor aperas-id'></a> `BlockNode.toMarkdown` 513, `toReconcileShape` 526-539, `hydrateFromParsed` 573-591; `ArtifactNode.trackFromDisk` 619-642 (reads the file system), `toMarkdown` 657-661, `ingestFromDisk` 696-835 (reads the file system, runs `reconcileTree`); `applyTombstone` 850-859 and `tombstoneLiveSubtree` 870-878; `hasHolderDescendant`/`deriveAbstractFromLiveChildren` 885-911; `rejectSlugPathCollisions` with its full scan `buildLiveSlugPathIndex` 924-1012; `collectLinkTargetsByBlock`/`collectOldWikilinksByBlock` 1025-1082; `findEnclosingArtifactId` 1091-1099; `FolderNode.toReadme` 1137-1142 and `hydrateFromParsed` 1159-1198.
      - **Resolve and path, about 100 lines**: <a name='id/BlockNode:00D3YFA81000A' class='aperas-anchor aperas-id'></a> `TreeNode.key`/`toPath`/`findChild`/`collectDescendants` 387-481; `ownerOfLink` 1396-1398.
      - **Sweeps, about 115 lines**: <a name='id/BlockNode:00D3YFA81000B' class='aperas-anchor aperas-id'></a> `pruneStaleUnfolds` 2063-2075; `pruneUnreachableTombstones` 2159-2189; `tombstoneVacuousContainers` 2206-2227.
      - **Anything else (profiles and views, about 160 lines)**: <a name='id/BlockNode:00D3YFA81000C' class='aperas-anchor aperas-id'></a> `Link`/`StringProp`/`Profile`/`TreeView` classes with `unfold` 1248-1253 and `fold` 1262-1278 (1204-1279); `findProfileByHandle`, `findTreeViewByName`, `createTreeView`, `removeTreeViewByName` 2012-2051; `ensureDefaultView`, `resolveTreeView` 2080-2115; `removeProfile` 2234-2241. `BaseNode.addLink`/`mintWikilink` 343-373 are link logic on the class.
      - `pruneUnreachableTombstones` (2159-2189) is the mark-and-sweep that [the engine's sweep](../design/core.md#id/BlockNode:00D3CHJXK8001) states: <a name='id/BlockNode:00D3YFA81000D' class='aperas-anchor aperas-id'></a> it is replaced by the engine's sweep (Batch 7), not kept as caller logic; step 7 of Batch 11 is then two sweeps, not three.
    - **(3) Every test and tool that touches `oxigraph` or a hand-built `Store`**
      
      - Value imports of `oxigraph`: <a name='id/BlockNode:00D3YFA81000F' class='aperas-anchor aperas-id'></a> `tests/support/fixture.ts:5` (`new Store()` twice, `:66-67`, only to write an empty mirror), `verifyLinkRefusals.ts:14,189-190` (the same two), `tests/store/storeAccess.test.ts:8` (`Store`, `quad`, `namedNode`; `new Store()` at `:161,184,191,215`), and in production `store.ts:9,121`, `vocab.ts:6`, `storeAccess.ts:22`. Type-only imports: the other 30 files of the 36 (17 `kg*.ts`, 9 in core, `chain.test.ts:11`, `corpus.ts:8`, `roundtripChild.ts:9`, `verifyDanglingUnfolds.ts:14`), and the inline `import('oxigraph')` in `vocab.ts:65,67`.
      - Raw store methods: <a name='id/BlockNode:00D3YFA81000G' class='aperas-anchor aperas-id'></a> `tests/store/storeAccess.test.ts` (the oracle: `store.match` at 49, 51, 53, 68, 86, 119, 205-206; `has` at 170; `add` at 217; `size` at 126, 168, 179, 186, 222); `tests/linking/integrity.test.ts:78` (`store.match` and `store.delete` of one `links` quad, with `predIri`/`nodeIri`); `tests/support/roundtripChild.ts:15` (every quad as a line, including `q.graph.value`); `verifyDanglingUnfolds.ts:25,48,53,55,56,60,70` (`match`, `size`, `add`; used by `tests/store/dangling-unfolds.test.ts` and `tests/corpus/dangling-unfolds.test.ts:17,29`); `verifyLinkRefusals.ts:60-61` (`match` of all quads for a count, `size`); `store.size` against `quadCount` in `tests/store/roundtrip.test.ts:36,39`, `tests/corpus/copy.test.ts:43`, `tests/corpus/roundtrip.test.ts:58,70`.
      - `makeFixtureStore` builds a store by rehydrating an empty mirror in a scratch root (`fixture.ts:66-69`); 14 test files use it; `makeCorpusCopy` rehydrates a copy of `AperasKG/Apeiron` (`corpus.ts:52`) for the 4 `corpus/` files, which are in `demand` only.
    - **(4) Graph position, `has`, `load`, `dump`, and dependence on `match` order**
      
      - **Graph position**: <a name='id/BlockNode:00D3YFA81000K' class='aperas-anchor aperas-id'></a> none in production. Every `store.match` passes `null` as the fourth argument (`storeAccess.ts:91`, `vocab.ts:69`) and `quad(s, p, o)` has no graph (`storeAccess.ts:243`). The only read of a graph is `q.graph.value` in `tests/support/roundtripChild.ts:15`.
      - **`has`**: <a name='id/BlockNode:00D3YFA81000M' class='aperas-anchor aperas-id'></a> one use, `tests/store/storeAccess.test.ts:170`. **Oxigraph `load`/`dump`**: no use anywhere (the only `.load(` is `aperas.ts:98`, a dynamic import of a command); the code's own load and dump are `rehydrateStore` (`store.ts:120-148`, through `addQuad`) and `dehydrateToJsonLd`/`dehydrateStateToJsonLd` (`dehydrate.ts:100-143`). **`size`**: `store.ts:147` (`quadCount`), the service log lines at `service.ts:163,387`, and the tests above.
      - **Order of set-field values**: <a name='id/BlockNode:00D3YFA81000N' class='aperas-anchor aperas-id'></a> `readField` returns the values of a `set` field in match order (`node.ts:138`; the set fields are `links` and `props` in `BASE_NODE_SHAPE` and `LINK_SHAPE`, `preferences` in `PROFILE_SHAPE` and `unfolds` in `TREE_VIEW_SHAPE`, all in `shape.ts`). The mirror does not depend on it (`dehydrate.ts:58` sorts a set by `localeCompare`). Three readers do: (a) `artifacts.ts:371-373` `positionsEqual` compares the `position` list of a reused `Link`, read in match order, with the fresh ascending list, element by element (`artifacts.ts:611`); if the order differs the `Link`'s `props` are rewritten and the `position` `StringProp`s change id, without a change in content; (b) `buildRenderTree` collects `unfolds` in match order (`node.ts:1975-1987`) and `discoverCone` lets the first escaping link in that order claim the target (`:1530-1569`, `if (!zs.canonical.has(targetId))` at `:1538,1560`), so the place of a node reached through two unfolded links is the order's choice, which is [the canonical-render order check](../design/core.md#id/BlockNode:00D24N87T000Q); (c) the order of a block's links in `tree`, `unfold` and the web (`node.ts:1745,1807`, `kgUnfold.ts`), which is [the tree view lists a block's links newest first](../issues/core.md#id/BlockNode:00D22ZK7C8001), gated by [the order of links without a position](../design/core.md#id/BlockNode:00D24N87T000P).
      - **Order of single values**: <a name='id/BlockNode:00D3YFA81000P' class='aperas-anchor aperas-id'></a> the first of a `one` or `optional` field (`node.ts:140`, `dehydrate.ts:61`, `threadScope.ts:20,37`). Only `findByExactPath` (`tree.ts:20-21`, `firstSubjectWhere(…, 'path', …)`) can have several: it takes the first subject with that `path` whether tombstoned or live (its callers: `resolve.ts:69`, `resolveCreate.ts:98`, `kgProject.ts:46`, `linkIntegrity.ts:323`, 12 test and tool sites). The artifact side already filters (`findLiveByKindAndPath`, `artifacts.ts:188-191`); `kgProject.ts:46` and `linkIntegrity.ts:323` do not. the Coder did not reproduce a wrong pick; the pointer is the risk, and [the design](../design/core.md#id/BlockNode:00D24N87T0007) says "a caller that must name one node asks for the live one".
      - **Order of subjects**: <a name='id/BlockNode:00D3YFA81000Q' class='aperas-anchor aperas-id'></a> `backlinks` (`node.ts:2131-2133`) gives `kgBacklinks.ts:32` its printed order, `kgProfile.ts:69` its list of views and `removeProfile` its cascade; `orderedChildIds` (`storeAccess.ts:188-196`) sorts by `siblingIndex` with a stable sort, so a child with a `parent` and no index (index 0) or two children with one index keep match order.
      - **Order of ids of a kind** (`allSubjectIds`, first seen, `storeAccess.ts:199-206`, behind `allIdsOfKind`): the report order of `kgTrack.ts:82-110` (`neverProjected`, `changed`, `staleOnDisk`), of `kgProfile.ts:65,111` (profile and view lists), of `checkLinkIntegrity` (`linkIntegrity.ts:112`, so the `check-links` output and the `linkWarning` text of the service), and `buildLiveSlugPathIndex` (`node.ts:957-965`, "first writer wins per name": it decides which block the collision error names). Of the 21 production calls of `allIdsOfKind`, 13 drop the tombstoned ids afterwards ([a set of live ids](../design/core.md#id/BlockNode:00D24N87T000X)): `artifacts.ts:197-198` (4 callers), `folders.ts:20-21` (3), `node.ts:959,2172,2218`, `linkIntegrity.ts:112`, `kgTrack.ts:82,92`; 2 want only the dead (`node.ts:2180`, `kgTrack.ts:104`); 6 want all (`dehydrate.ts` ×3, `kgProfile.ts` ×2, `node.ts:2065`).
      - **`localeCompare`**: <a name='id/BlockNode:00D3YFA81000S' class='aperas-anchor aperas-id'></a> in `dehydrate.ts:58,106,130,138` (the deliberate difference of layer 4) and in `project.ts:70` (the frontmatter keys of a projected file, which is the caller's and stays).
    - **(5) The Oxigraph engine as the reference of a differential run**
      
      - **The archive is not runnable alone.** `Aperas.dev/monorepo/.archive/oxigraph/` holds 40 files (13 `apeironNgn/` modules of core that name a store, 17 `kg*.ts`, `service.ts`, the smoke test, 5 tests and support files, the 2 `verify*.ts` tools; not `shape.ts`, `astParser.ts`, `reconcile.ts`, `snowflake.ts`, `graphConfig.ts`, `aperas.ts` or `serviceClient.ts`), byte-identical to `d794060`. Its imports (`../astParser`, `../snowflake`, `../graphConfig`, `./apeironNgn/serviceClient`, `aperas.ts`) point to files the archive does not hold. The runnable reference is a **checkout** of `d794060`: `/home/will/source/Aperas` itself (it has `node_modules`, `@aperas/*` workspace links and `oxigraph@0.5.11`; the real service runs from it), or a second worktree of that commit with `monorepo/node_modules` copied or linked.
      - **Two services on two copies**: <a name='id/BlockNode:00D3YFA81000W' class='aperas-anchor aperas-id'></a> the isolation exists and is used. `/proc/<pid>/environ` of a second service shows `XDG_RUNTIME_DIR`, `APERAS_HTTP_PORT`, `APERAS_APEIRON_ROOT`, `APERAS_ARTIFACTS_ROOT` and `APERAS_GRAPH_NAME` set apart from the real service's (which has `/run/user/1000`, port 2736 and the real roots). The lock, socket and token are per `XDG_RUNTIME_DIR` (`serviceLock.ts:41-56`), the port per `APERAS_HTTP_PORT` (`:69`), the roots per the two root variables (`resolveEffectiveApeironRoot` and `resolveEffectiveArtifactsRoot` in `graphConfig.ts`), which win over `aperas.config.json`. So a second pair is four variables and one scratch directory each.
      - **The `aperas` command is bound to one checkout**: <a name='id/BlockNode:00D3YFA81000X' class='aperas-anchor aperas-id'></a> `/home/will/.local/bin/aperas` runs `cd /home/will/source/Aperas/monorepo && node_modules/.bin/tsx packages/cli/src/aperas.ts`. The new engine is run as `cd /home/will/source/Aperas.dev/monorepo && env -u LD_LIBRARY_PATH node_modules/.bin/tsx packages/cli/src/aperas.ts …` with its own variables; the reference gets the same with the `Aperas` path and a second set of variables.
      - **The copies**: <a name='id/BlockNode:00D3YFA81000Y' class='aperas-anchor aperas-id'></a> `AperasKG/Apeiron` is 7.8 MB with `.state/` and `artifacts/` is 4.5 MB. Both copies must come from one snapshot, taken after `aperas flush` on the real service (the files on disk lag its memory by up to 10 s, `FLUSH_INTERVAL_MS`, `service.ts:97`) or from `git` at one commit, and then cloned: `makeCorpusCopy` (`corpus.ts:36-62`) copies only `Apeiron` and leaves `artifacts/` empty, which is enough for graph-only commands but not for `track`, `ingest` and `project`, which read the markdown tree.
      - **What the harness has to normalise** (none of it exists): <a name='id/BlockNode:00D3YFA81000Z' class='aperas-anchor aperas-id'></a> (a) ids minted by a command come from `snowflake.ts` (a clock, the machine number and a sequence), so two runs mint different ids; the comparer has to map the k-th new id of one run to the k-th of the other, and `APERAS_MACHINE_NUMBER` must be one value for both; (b) timestamps (`lastTrackedAt`, `lastIngestedAt`, `tombstonedAt`, `new Date().toISOString()` at 11 production sites) differ between runs; (c) both dumps are sorted by `@id`, with `localeCompare` on one side and code point on the other (deliberate), and sets are sorted by the same rule, so the comparer parses both and compares by id and as sets, and `children` as lists; (d) the stdout of a command lists ids of a kind or subjects in an order that differs (the lists in (4)), so each listing is either sorted before comparing or recorded as a deliberate difference.
      - **A script of commands** has to be written: <a name='id/BlockNode:00D3YFA810010' class='aperas-anchor aperas-id'></a> the 22 of the 27 verbs of `aperas.ts` that reach the service (`init`, `service`, `serve`, `identity` and `skill` do not), each with `--flush`, then a final `flush` and a compare of `Apeiron/` and `.state/`. Anything not reachable by a verb (the sweeps at boot, reload and shutdown) is reached by `reload`, `flush --clobber` and a restart of the isolated service.
- **The loader writes a node's `parent` from the `parent` pair in the file, not from the container that lists it, so a file whose `parent` and `children` disagree loads as it stands**: <a name='id/BlockNode:00D2538VKR001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`. Filed 2026-10-12.
  
  - **Symptom**
    
    - None in the data: <a name='id/BlockNode:00D2538VKR003' class='aperas-anchor aperas-id'></a> the real mirror has 0 mismatches in either direction between a child's `parent` and the container that lists it, and the live blocks without a `parent` are listed by no container, as expected (42 or 43 of them; the Coder gave both figures).
    - A file with a `parent` that no container lists would load as a child sorted at index 0 (read from the code, not run).
  - **Root cause** (read from the code)
    
    - `encodeDoc` (`store.ts`) reads `parent` as its own predicate in its generic branch, and writes the containment again through `children`; `serializeDoc` (`dehydrate.ts` lines 70 to 82) writes `parent` from the store's own `parent` quad, not from a container's list.
    - The README of the mirror and the design draft both say `parent` is derived from the container's `children`; that is true as an invariant of the data and false as a description of the code.
  - **Not proven**
    
    - What a load does with a `parent` that names a container which does not list the child, or a child listed by a container that is not its `parent`; neither was run.
  - **Fix directions**
    
    - None decided. Whether `parent` is the lister's fact or a pair of its own is an Open point of the design.
  - **Related**
    
    - [Containment in the file](../design/core.md#id/BlockNode:00D24N87T0000) in the design.
- **Ingested artifacts without a `type`: 9 of 57 `ArtifactNode` documents carry none, 7 of them with an `ingestedHash` and a `lastIngestedAt`**: <a name='id/BlockNode:00D253D680001' class='aperas-anchor aperas-id'></a>  found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`. Filed 2026-10-12.
  
  - **Symptom**
    
    - Counted by the Coder on the real mirror: <a name='id/BlockNode:00D253D680003' class='aperas-anchor aperas-id'></a> 48 of 57 artifacts have `type` (`root`), 9 do not. Seven of the 9 have an `ingestedHash` and a `lastIngestedAt`: `history/packaging.md`, `discussion/webapp.md`, `design/webapp.md`, `planning/webapp.md`, `history/webapp.md`, `.threads/grapher.md` and `.threads/coder.md`.
    - The other two of the 9 are the tombstoned `issues/cli.md` and the live `concepts.md` (which has no `ingestedHash` either). The orchestrator's count of 6 and the Coder's of 7 are two sets of this: the 6 are the live artifacts without a `type` in the tracked `ArtifactNode.jsonld` (the 5 above that are not threads, and `concepts.md`), the 7 are the artifacts without a `type` that carry an `ingestedHash`, with the two thread artifacts of `Apeiron/.state/` (re-counted on both files by the grapher on 2026-10-12).
    - These seven have been through an ingest and have no `type`, which an ingest sets on an artifact (see Root cause).
  - **Root cause**
    
    - Not found. `hydrateFromParsed` (`node.ts` line 574) sets `type` on every ingest, so a node with children and hashes and no `type` was not produced by that path in its present form.
  - **Not proven**
    
    - **Question — which command or code version produced them**: <a name='id/BlockNode:00D253D680009' class='aperas-anchor aperas-id'></a> what would decide is `git log -p` on `Apeiron/ArtifactNode.jsonld` for one of the seven, or a re-ingest on a copy.
  - **Fix directions**
    
    - None decided. The design either states the exception or this issue is resolved by finding the cause.
  - **Related**
    
    - [ArtifactNode](../design/core.md#id/BlockNode:00D24N87SR00R) in the design.
- **The load computes `danglingRefs` and the service never reads it, so nobody is told at run time of an id that is referenced and never defined**: <a name='id/BlockNode:00D258W098001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, among the findings the orchestrator asked to file. Filed 2026-10-12.
  
  - **Symptom**
    
    - None in the data: <a name='id/BlockNode:00D258W098003' class='aperas-anchor aperas-id'></a> the real mirror has 0 dangling references (the Coder's boot measurement of the whole store, 10,622 nodes, gave 0 as well).
    - Were one to appear, a reference to a node that does not exist, the service would not say so. The Coder's scratch store showed a title "BlockNode:zzz" loading as a reference to a node that does not exist and reported as dangling in the result of the load, which is the only place the list reaches.
  - **Root cause** (read from the code)
    
    - `rehydrateStore` (`store.ts` lines 142 to 147) scans the store for object references (`allObjectRefIds`) and returns `danglingRefs`, sorted, in its result. A search of `monorepo/packages` finds readers of the field only in `apeironNgnSmokeTest.ts` (lines 50 to 55), in the corpus support (`tests/support/corpus.ts`, `roundtripChild.ts`) and in the two round-trip tests. `service.ts` reads `duplicateIds` from the same result (lines 162 and 390) and logs it; it names `danglingRefs` nowhere.
    - The design says the load lists the ids that are referenced and never defined and returns the list to its caller, and that what is done with it belongs to the service lifecycle, which has no design yet.
  - **Not proven**
    
    - What the service should do with the list (log it as it does a repeated id, refuse, or leave it to a check on demand); the design does not say.
    - Whether the 97 ms second pass that builds the list is worth keeping if nothing reads it at run time; it is a part of the cost listed under the scans issue.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [Embedded nodes have ids and are removed outright](../design/core.md#id/BlockNode:00D24N87SR013) in the design, which states what the load returns.
    - [The service lifecycle](../design/core.md#id/BlockNode:00D24N87T000W), an Open point of the design.
    - [The full-store scans issue](#id/BlockNode:00D0W02KPG001), where the second pass is one of the scans.
    - [The duplicate-id entry](#id/BlockNode:00CHXSZ56R001), resolved: <a name='id/BlockNode:00D258W09G002' class='aperas-anchor aperas-id'></a> the repeated id is the case the service does read from the same result.
    - [The ghost folder](#id/BlockNode:00D417WK80001): <a name='id/BlockNode:00D419V27R001' class='aperas-anchor aperas-id'></a> the `children` of the root folder in the tracked mirror names the `.threads` folder, whose document lives only in `.state/`, so a load of the mirror without `.state/` meets an id that is referenced and never defined, the case this list is for; what the caller does with it is the service lifecycle.
- **The thread-scope test sits in `core/apeironNgn`, inside the engine's directory, and not in the layer above it that the design says it belongs to**: <a name='id/BlockNode:00D2590B2R001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, among the findings the orchestrator asked to file. Filed 2026-10-12.
  
  - **Symptom**
    
    - No wrong result: <a name='id/BlockNode:00D2590B2R003' class='aperas-anchor aperas-id'></a> the split by scope is stable on the real mirror (the Coder's round trip gave 4,818 + 2,988 blocks, 55 + 2 artifacts and 16 + 1 folders, content mirror and `.state/`).
    - The design says the scope test belongs to the layer above the engine and that the engine supplies the ids of each kind. In the code the test is `isThreadScopedId` of `threadScope.ts` in `monorepo/packages/core/src/apeironNgn/`, called by the engine's own write-back (`dehydrate.ts` lines 104 and 136) and by the service (`service.ts` line 313, the thread size cap).
  - **Root cause** (read from the code)
    
    - The header of `threadScope.ts` says why the module sits there: <a name='id/BlockNode:00D2590B30002' class='aperas-anchor aperas-id'></a> it is a raw-quad twin of the owner walk of `linkIntegrity.ts`, and it must stay importable from `dehydrate.ts`, which `node.ts` and `linkIntegrity.ts` already import, so that nothing cycles. It depends only on `vocab.ts` and the helpers of `storeAccess.ts`.
    - The rule it applies: <a name='id/BlockNode:00D2590B30003' class='aperas-anchor aperas-id'></a> an artifact or a folder is in scope when its own `path` is `.threads` or begins with `.threads/`; a block is in scope when the artifact or folder found by climbing its `parent` chain is; a block with no `parent` is never in scope; `Profile`, `Link`, `StringProp` and `TreeView` never are.
    - `firstLiteralOf` and `firstRefIriOf` of the helpers have no other caller than this module (the Coder's reading of the interface).
  - **Not proven**
    
    - What moving it would touch: <a name='id/BlockNode:00D2590B30006' class='aperas-anchor aperas-id'></a> `dehydrate.ts` would have to receive the test or the two sets of ids from outside, and the design does not say in which form the layer above hands it back.
    - Whether the design's sentence is a target for the code or the sentence should say that the test lives with the write-back; neither was tried.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [Written by kind and scope](../design/core.md#id/BlockNode:00D24N87SR01Y) in the design, which states the placement.
    - [The code differs from the boundary](#id/BlockNode:00D4NBNCF8001), the wider case, resolved: <a name='id/BlockNode:00D4NBT02G001' class='aperas-anchor aperas-id'></a> [Batch 15](../planning/core.md#id/BlockNode:00D4NBFKAG001) moved `threadScope.ts` to `src/shell/` in `Aperas.dev` with the rest of the engine's directory (2026-10-16), which does not close this issue; the test becomes the graph a node belongs to in [Batch 9](../planning/core.md#id/BlockNode:00D3XQQ2VR01M). The working checkout `Aperas/` keeps it in `core/src/apeironNgn/`.
- **`ownerOfLink` takes the first node whose `links` names a link, and nothing checks that there is only one**: <a name='id/BlockNode:00D2593220001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, named there in passing under the first-match lookup; the orchestrator asked for its own entry. Filed 2026-10-12.
  
  - **Symptom**
    
    - None visible. A `Link` is an embedded node with one owner, and the real mirror holds 2,687 `Link`s, each found by its owner through this lookup. The case of a `Link` listed in the `links` of two nodes was not counted.
  - **Root cause** (read from the code)
    
    - `ownerOfLink` (`node.ts` lines 1396 to 1398) is `firstSubjectWhere(store, 'links', { ref: linkId })`, the first match of the reverse lookup; its comment calls the result "the one `TreeNode` a `Link` belongs to".
    - Its callers: <a name='id/BlockNode:00D2593220006' class='aperas-anchor aperas-id'></a> `kgBacklinks.ts` (line 35, the owner shown for each backlink) and `buildRenderTree` in `node.ts` (line 1982, the owner of each unfolded `Link` entry of a view). With two owners the answer would be the one the store lists first, which is the dependence on the engine's order that the design rules out.
  - **Not proven**
    
    - Whether any `Link` has two owners in the mirror or can get them through a write; the Coder named the lookup as first-match and did not look for a second owner.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [The first-match path lookup](#id/BlockNode:00D22ZMTKG001), which names the owner of a link among the other first-match lookups that are not defects today; this entry is the one for that lookup.
    - [A lookup does not depend on first match](../design/core.md#id/BlockNode:00D24N87SR01H) in the design.
- **A repeated `@id` is detected and logged, then the load goes on and merges the quads of every occurrence onto one subject; the design says only that the load names the repeat**: <a name='id/BlockNode:00D2595QAG001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder in the fact-check of the draft `design/core.md`, among the findings the orchestrator asked to file. Filed 2026-10-12.
  
  - **Symptom**
    
    - None in the data: <a name='id/BlockNode:00D2595QAG003' class='aperas-anchor aperas-id'></a> the real mirror has 0 repeated ids among 16,614 documents.
    - Once it happened: <a name='id/BlockNode:00D2595QAR000' class='aperas-anchor aperas-id'></a> two `Profile` documents under one `@id` were merged, and one of them vanished at the next write (the resolved entry linked below). The service now logs a warning at start and at reload that names the ids and says at most one document per id survives the next write-back; no command replies with it.
  - **Root cause** (read from the code)
    
    - `encodeDoc` (`store.ts` lines 70 to 75) pushes an id seen before onto `duplicateIds` and then goes on to add every field of the document as quads, so the quads of every occurrence land on one subject. `rehydrateStore` returns the ids, sorted and without repeats (line 147). The doc comment of the result says the repeat is surfaced and never resolved, because picking a winner would be a quieter way to lose the same data.
    - Readers of `duplicateIds`: <a name='id/BlockNode:00D2595QAR003' class='aperas-anchor aperas-id'></a> `service.ts` (lines 162 to 167 and 390 to 394), which logs the warning and nothing more.
    - The design (`An @id names one document`) says only that the load names a repeated id to its caller and the service logs it; it does not say whether the load should go on.
  - **Not proven**
    
    - What the engine holds for a field that is single-valued by shape when two occurrences give it two values; the Coder did not run it.
    - Whether a refusal to load, or a load that goes on and tells the client, is the better rule; the design lists no Open point for it.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [The duplicate-id entry](#id/BlockNode:00CHXSZ56R001), resolved: <a name='id/BlockNode:00D2595QAR00B' class='aperas-anchor aperas-id'></a> the collapse of two profiles, which added the list of repeated ids and the warning.
    - [An `@id` names one document](../design/core.md#id/BlockNode:00D24N87SR01P) in the design.
- **A stopped service and a busy one give the same refusal, "No ApeironNgn service running", so an agent reports a crash or waits for a service that is not there**: <a name='id/BlockNode:00D2PCFDBR001' class='aperas-anchor aperas-id'></a> found 2026-10-13 by the orchestrator in the check of the Coder's stalled turn of 2026-10-12, on the user's explanation that the service stops itself after an idle time. Filed 2026-10-13.
  
  - **Symptom**
    
    - After the service stops, by the idle shutdown of 30 minutes or by any other stop, every command is refused with "No ApeironNgn service running. Start one with: aperas service start".
    - The same refusal is given while the service is up and busy and does not answer a ping ([the entry on a refusal while the service is up](#id/BlockNode:00CVMPABY8001)). An agent cannot tell a stopped service, which it must start, from a busy one, which it must wait for, so it reports a crash or waits for a service that is not there.
    - The CLI does not start the service by itself: <a name='id/BlockNode:00D2PCFDBR005' class='aperas-anchor aperas-id'></a> `aperas service start` is the only place that does.
    - The Coder's turn of 2026-10-12 began at about 14:15Z and its first `aperas` calls worked; its `Edit` of `Apeiron/README.md` then waited on a permission prompt for over 30 minutes with no `aperas` command (the turn lasted about 13.7 hours of wall time), and after the answer every call was refused.
  - **Root cause** (read from the code)
    
    - `service.ts` sets an idle timer of 30 minutes (`IDLE_TIMEOUT_MS`, line 99), and `resetIdleTimer` (around line 433) ends the service by a plain `shutdown(0)`, which writes no log line.
    - `ensureServiceRunning` (`serviceClient.ts`, line 151) throws the one message whenever `ping()` fails, whatever the reason, and its comment says it never starts a service.
    - Evidence of the stop: <a name='id/BlockNode:00D2PCFDC0003' class='aperas-anchor aperas-id'></a> the run directory, where the service removes its socket and lock when it stops, last changed at 14:51Z on 2026-10-12, and the log's last line is 14:13Z, so the stop came about 30 minutes after the last command.
  - **Not proven**
    
    - The exact moment of the stop: <a name='id/BlockNode:00D2PCFDC0005' class='aperas-anchor aperas-id'></a> the shutdown leaves no log line, so it is read from the time of the run directory.
  - **Fix directions**
    
    - None decided.
  - **Related**
    
    - [A command can fail with "No ApeironNgn service running" while the service is up](#id/BlockNode:00CVMPABY8001), the busy case that gives the same message.
    - [The service can die silently](#id/BlockNode:00CRBJ0VYG001), a stop with no signal to the client.
    - [The service lifecycle](../design/core.md#id/BlockNode:00D24N87T000W) in the design, which has no design of its own yet.
- **A move, `aperas insert <id> --after <anchor>` with no body, waits on standard input when it is an open pipe**: <a name='id/BlockNode:00D2PVVMWG001' class='aperas-anchor aperas-id'></a> found 2026-10-13 by the Grapher when it ran a move from a harness in the update of `design/core.md`, and agreed by the orchestrator to be filed. Filed 2026-10-13. The skills and the mechanics reference carry the workaround from v4.7; the fix in the code is not decided.
  
  - **Symptom**
    
    - A move run from a harness whose standard input is an open pipe does not finish:  the command ran for 120 seconds and the harness moved it to the background. The same move run again with standard input from `/dev/null` finished at once, and the first process stayed blocked on standard input and was left running.
    - No wrong result and no fault of the service: <a name='id/BlockNode:00D2PVVMWR000' class='aperas-anchor aperas-id'></a>  the wait is in the client, before the request is sent.
    - The `aperas` skill's quick reference ("no stdin moves node"), the `aperas-grapher` skill ("with no stdin") and the mechanics reference say the move takes no standard input, and none says that standard input must be closed when the command is run from a harness that leaves it open.
  - **Occurrences**
    
    - 2026-09-27: <a name='id/BlockNode:00D4PMMZY0002' class='aperas-anchor aperas-id'></a> a grapher's move hung in its shell; the grapher stopped it and reran it with `< /dev/null`, and it succeeded. The cause was then left unknown.
    - 2026-10-13: <a name='id/BlockNode:00D4PMMZY0003' class='aperas-anchor aperas-id'></a> the occurrence this issue was filed on, in the update of `design/core.md`.
    - 2026-10-16: <a name='id/BlockNode:00D4PMMZY8000' class='aperas-anchor aperas-id'></a> the third, in a grapher's filing turn; the move hung about two minutes until it was rerun with `< /dev/null`. It is of the same root as [the `ingest` prompt hang](#id/BlockNode:00CNX1T4XG001), a client that waits on standard input, which `eb352f5` fixed with `--no-prompt`.
  - **Root cause** (read from the code)
    
    - `readStdinIfPiped` in `monorepo/packages/cli/src/kgInsert.ts` (line 241) returns at once only when `process.stdin.isTTY` is true; otherwise it reads the stream to its end and takes an empty read as "nothing was piped", which selects the move.
    - Its comment says why a test of `isTTY` alone is not enough:  a harness with no terminal reads `isTTY` as false, and a bare `insert` was then taken for a create with empty content. The read to the end was chosen as the signal, and it needs the stream to end; a stream that stays open never ends.
  - **Not proven**
    
    - Whether a harness other than the one that ran the move behaves the same:  a harness that closes standard input for each command would not wait.
    - Whether any other command that reads standard input waits the same way; only the move was run.
  - **Fix directions**
    
    - None decided.
    - Proposed 2026-10-16, not decided: <a name='id/BlockNode:00D4PMQPW0001' class='aperas-anchor aperas-id'></a> an explicit move signal, so that a move never reads standard input.
  - **Workaround**
    
    - Run the move with standard input closed, `aperas insert <id> --after <anchor> --flush < /dev/null`.
    - Carried in the skills from v4.7, as a stopgap until a fix is decided: every move recipe in the `aperas` and `aperas-grapher` skills and in `skills/aperas/references/mechanics.md` ends in `< /dev/null` and says why, and the reference has a section on the move.
- **`dehydrate` sorts with `localeCompare`, a comparison that depends on the locale, where the mirror's orders are decided as plain code-point order**: <a name='id/BlockNode:00D39EY5B0001' class='aperas-anchor aperas-id'></a> found 2026-10-12 by the Coder's fact-check of `design/core.md`; the order decided by the user on 2026-10-14. Filed 2026-10-14.
  
  - **Symptom**
    
    - None observed. On a copy of the real mirror the Coder checked 6,084 sorted lists and found every one in code-unit order, with 0 differences, and the four tracked class files are sorted by `@id` in plain code-point order.
  - **Root cause** (as reported by the census, the lines read again in the code)
    
    - `dehydrate.ts` sorts the values of a set field (line 58) and the documents of each file (lines 106, 130 and 138) with `stableId(a).localeCompare(stableId(b))`. The order `localeCompare` gives depends on the locale and the collation data of the runtime, so the byte-for-byte round trip could depend on the machine that flushes.
    - The design decides plain code-point comparison for the mirror's orders: <a name='id/BlockNode:00D39EY5B8002' class='aperas-anchor aperas-id'></a> [Ids give a stable order](../design/core.md#id/BlockNode:00D24N87SR01F) and [A flush is a dump](../design/core.md#id/BlockNode:00D39EAKW0001).
  - **Not proven**
    
    - An actual difference between machines: <a name='id/BlockNode:00D39EY5B8004' class='aperas-anchor aperas-id'></a> no flush under another locale or another runtime was compared.
  - **Fix directions**
    
    - None decided.
- **One live artifact, `concepts.md`, has no `parent`, so its path cannot be derived from the parent chain**: <a name='id/BlockNode:00D3F6RJCG001' class='aperas-anchor aperas-id'></a> found 2026-10-12 in the fact-check of the draft `design/core.md`, counted again 2026-10-14 by the Grapher. Filed 2026-10-14 as seven artifacts; narrowed 2026-10-15 to `concepts.md`, after the user's correction that the `README.md` files are the organic part of their folder.
  
  - **Symptom**
    
    - In `Apeiron/ArtifactNode.jsonld` (read 2026-10-14), 7 of the 54 live `ArtifactNode` documents carry no `parent`: `concepts.md` and six `README.md` nodes (`README.md`, `design/README.md`, `discussion/README.md`, `issues/README.md`, `planning/README.md` and `history/README.md`). The fact-check of 2026-10-12 counted the same seven. The six `README.md` nodes are strays, filed as [Six live `ArtifactNode`s for `README.md` files](#id/BlockNode:00D3WTZG9G001): a `README.md` file is the organic part of its folder, which holds its content among its own children, and needs no parent of its own. `concepts.md`, at the root, is the one live artifact without a parent.
    - The root folder has no parent by definition, its path being `.`; `concepts.md` is an artifact, which the derivation of the path needs to have one.
    - Checked 2026-10-15 on a clone of the mirror (`Apeiron/`, `Apeiron/.state/`): <a name='id/BlockNode:00D3YTHB7R001' class='aperas-anchor aperas-id'></a> `ArtifactNode:00CR5AEJ88000` (`concepts.md`) is live and has no `parent`, and no `FolderNode` lists it in its `children`. The live nodes without a `parent` are 7 `ArtifactNode`s (this one and the six `README.md` artifacts), the root folder `FolderNode:00CDBYV47G000` and 42 `BlockNode`s that no container lists; the blocks are filed in [42 live `BlockNode`s have no `parent` and no container lists them](#id/BlockNode:00D3YS41VR001). What the migration of the mirror does with `concepts.md` is part of [an open point of Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8001).
  - **Fix directions**
    
    - No fix in the migration. Decided 2026-10-16 (the user): <a name='id/BlockNode:00D3F6RJCG006' class='aperas-anchor aperas-id'></a> the migration of the mirror leaves `concepts.md` as it stands, with no `parent`, beside the 42 blocks of [42 live `BlockNode`s have no `parent` and no container lists them](#id/BlockNode:00D3YS41VR001) ([Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8002)), so that it tests how the new engine handles it, the case of [garbage collection never collects an unreachable block that was never tombstoned](#id/BlockNode:00D1A2AY68001). Nothing uses `concepts.md` now and it could be removed, but it is kept for that test. The design lists the options under [Deriving the path](../design/core.md#id/BlockNode:00D25698B0001), neither chosen: (a) give `concepts.md` the folder that holds it as its parent, before the path is derived, or (b) keep the stored path for it as an exception.
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)) leaves `concepts.md` as it stands, among the 44 live documents without a `parent`. Its node has no file under `artifacts/`, which [a new issue](#id/BlockNode:00D4JZ0A7R001) files.
  - **Related**
    
    - [The path is derived from the parent chain](../design/core.md#id/BlockNode:00D24N87SR01S) in the design.
- **Every `Link` carries a `predicate`, which the design of a `Link` no longer has**: <a name='id/BlockNode:00D3WNBPPG001' class='aperas-anchor aperas-id'></a> found 2026-10-15, when the user removed the predicate of a `Link` from `design/core.md`; counted the same day by the Grapher. Filed 2026-10-15.
  
  - **Symptom**
    
    - In the mirror files (the tracked files of `Apeiron/` and `Apeiron/.state/`), counted 2026-10-15 with `jq` on a clone, every embedded `Link` has a `predicate`, and every one of them is `[[wikilink]]`: 2,157 in `Apeiron/` (2,155 owned by a `BlockNode` and 2 by an `ArtifactNode`; 2,152 targets are `BlockNode`s, 5 are `ArtifactNode`s, none is undefined) and 1,510 in `Apeiron/.state/`. None is `references` and none lacks a `predicate`. Every `Link` has `props` holding a `position` and nothing else. The `predicate` of `Link` is the only key outside the declared shapes on any node of the mirror (`ArtifactNode`, `BlockNode`, `FolderNode`, `Profile` and `StringProp` have none). No manual link exists as a record: `aperas link` and `kg:link` occur only as prose, in three blocks of `Apeiron/`. The count is of one moment, since the mirror gains a `Link` with each block that holds a wikilink, and it is of the files as last flushed, not of the store in memory.
    - The code writes a predicate on every `Link` it makes: <a name='id/BlockNode:00D3WNBPPR000' class='aperas-anchor aperas-id'></a> `[[wikilink]]` for a wikilink (`WIKILINK_PREDICATE` of `@aperas/core/astParser`) and `references` for a manual link (`addLink('references', ...)` in `kgLink.ts`, whose removal of a manual link also filters on that predicate). Tests in `tests/links/`, `tests/ingest/` and `tests/gc/` write `references` links and filter on both values. Found by a search of the code, not traced.
  - **Fix directions**
    
    - Decided: <a name='id/BlockNode:00D3WNBPPR002' class='aperas-anchor aperas-id'></a> the `predicate` leaves every `Link`, and manual links are dropped, since they were never used and the mirror holds none. The mirror loses the `predicate` in its one-time migration ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)). The code of the caller loses the six sites that tell a wikilink from a manual link (`artifacts.ts:606`, `node.ts:1067`, `node.ts:343-345` and `:369`, `kgLink.ts:56`, `kgUnfold.ts:113,144` with `node.ts:1936,1940`, and the render JSON that `web/src/render.ts:42` and `FolderDiv.tsx:534` read), the verbs `aperas link` and `aperas unlink`, and the predicate in the text of `tree` and `unfold`, in [Batch 11, step 9](../planning/core.md#id/BlockNode:00D3YG50AR001). The tests that write or filter on a predicate are `ingest/chain.test.ts:134,148,159`, `gc/collection.test.ts:63` and `store/views.test.ts`.
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)): 3,934 `Link`s lost their `predicate` (2,332 in the mirror and 1,602 in `.state/`), another 10 vanished with their tombstones, and no `predicate` is left anywhere; a second run changes nothing. The real mirror keeps its `predicate` until the cutover, since the working engine needs it.
  - **Related**
    
    - [Links are outgoing ports](../design/core.md#id/BlockNode:00D24N87SR011) and [the fields of `Link`](../design/core.md#id/BlockNode:00D24N87SR00T) in the design.
- **Six live `ArtifactNode`s for `README.md` files stand outside any folder and duplicate the README content their folders already hold**: <a name='id/BlockNode:00D3WTZG9G001' class='aperas-anchor aperas-id'></a> found 2026-10-15 by the orchestrator in the mirror, after the user's correction that the `README.md` files are the organic part of their `FolderNode`; counted again the same day by the Grapher. Filed 2026-10-15.
  
  - **Symptom**
    
    - In `Apeiron/ArtifactNode.jsonld` (read 2026-10-15), six live `ArtifactNode`s have the paths `README.md`, `design/README.md`, `discussion/README.md`, `issues/README.md`, `planning/README.md` and `history/README.md`. None of them has a `parent`, none is listed in the `children` of any `FolderNode`, and each has one child block.
    - The README content of a folder is already the folder's own: each of the six folders (the root folder `.`, `design`, `discussion`, `issues`, `planning` and `history`) holds one `BlockNode` among its children with its README's content, beside its artifacts and subfolders. The child block of each of the six `ArtifactNode`s has the same text as the block its folder holds, and neither has children, so the six duplicate what the folders hold.
    - Their `lastTrackedAt` and `lastIngestedAt` fall on 2026-09-22. How they were made is not traced. Counted on the mirror files as last flushed, not on the store in memory.
    - Checked 2026-10-15 on a clone of the mirror (`Apeiron/` and `Apeiron/.state/`, read with `jq`): the six are `ArtifactNode:00CN1QE950000` (`README.md`), `ArtifactNode:00CN4ZQ8Y0000` (`design/README.md`), `ArtifactNode:00CN4ZSF58000` (`discussion/README.md`), `ArtifactNode:00CN4ZTZRR000` (`issues/README.md`), `ArtifactNode:00CN4ZWHCG000` (`planning/README.md`) and `ArtifactNode:00CN4ZXWJ8000` (`history/README.md`). All are live and of `type` `root`; each has a `description` that is its abstract and a `text` that is its summary, and one child, a `paragraph` with no children and no links (`BlockNode:00CN1QEAGG001`, `BlockNode:00CN4ZQAPG001`, `BlockNode:00CN4ZSHMG001`, `BlockNode:00CN4ZV1G8001`, `BlockNode:00CN4ZWJMG001`, `BlockNode:00CN4ZXXRR001`), and no other block. Nothing points at the twelve nodes: the only references in `Apeiron/` are each artifact's own `children` entry and its paragraph's `parent`; no `Link` targets an artifact or its paragraph, from any owner in `Apeiron/` or `Apeiron/.state/`; no `FolderNode` lists an artifact as a child; no `TreeView` unfolds or roots at one. In `Apeiron/.state/` the ids occur only in the text of thread blocks, never as a `Link`. A folder projects to its own `README.md` (`aperas project <folder>` writes to it), so the six artifacts duplicate files that the folders already own.
  - **Fix directions**
    
    - Decided 2026-10-15: <a name='id/BlockNode:00D3WTZG9R003' class='aperas-anchor aperas-id'></a> the six artifacts and their six paragraphs are deleted outright from the mirror in the one-time migration ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)), and not given a parent. A tombstone would only wait for the engine to run to be wiped, with the same net result. A `track` or `ingest` run after the deletion must not register them again; the dry run of the migration on a clone checks that.
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)): the six artifacts and their six paragraphs, 12 documents, were deleted, and no `README.md` artifact is defined after. On a copy with only that deletion applied, `aperas ingest --no-prompt` and `aperas track` registered no `README.md` artifact and no README paragraph, and the folders keep the content of their README as sub-blocks (children), and their `text` stays their frontmatter `description`. The real mirror keeps the six until the cutover.
  - **Related**
    
    - [One live artifact, `concepts.md`, has no `parent`](#id/BlockNode:00D3F6RJCG001), which first counted these six among its seven, and [Deriving the path](../design/core.md#id/BlockNode:00D25698B0001) in the design.
- **The stored `text` of an artifact or a folder is a copy of a descendant's text, kept only as a rename fingerprint, where it should come from the frontmatter `description`**: <a name='id/BlockNode:00D3WV3CZ0001' class='aperas-anchor aperas-id'></a> found 2026-10-15 by the user, reading `design/core.md`, who called the fingerprint "a legacy left over, not intended design"; counted the same day by the Grapher. Filed 2026-10-15.
  
  - **Symptom**
    
    - The stored `text` of an `ArtifactNode` or a `FolderNode` is a copy of the text of its first descendant that has any, and its one remaining use is as a fingerprint for detecting a rename; the abstract a reader sees has been the frontmatter `description` since the redesign of 2026-09-20. The design gives the `text` from the `description`, as the value the rename check compares (see [The artifact is its own root document](../design/core.md#id/BlockNode:00D24N87SR010)).
    - In the mirror files read 2026-10-15: <a name='id/BlockNode:00D3WV3CZ8000' class='aperas-anchor aperas-id'></a> of 54 live `ArtifactNode`s, 53 carry a `description` and none has a `text` equal to it, while 48 have a `text` equal to the text of one of their own blocks; of 16 live `FolderNode`s, 6 carry a `description`, none equal to its `text`. Counted on the mirror files as last flushed, not on the store in memory.
    - Where the code sets the `text` and where the rename check reads it (by the orchestrator's reading, the comments in `node.ts` at the ingest and the render) is not traced.
  - **Fix directions**
    
    - None decided. Whatever the fix, an artifact or a folder without a `description` has no basis for detecting a rename, by design: the user called it "a miss of the content, not of the system", and its remedy is to write a `description`.
  - **Related**
    
    - [The stale, heuristic copy of `text`](#id/BlockNode:00CKE4R93R001) and [its follow-on on the preview paths](#id/BlockNode:00CN7V9BX0001), which retired the copy as the abstract a reader sees.

- **No test calls most commands of the CLI or the service, so the groups of Batch 11 that move them have no test group to be green on**: <a name='id/BlockNode:00D3YFXDC8001' class='aperas-anchor aperas-id'></a> found 2026-10-15 by the Coder in the survey of the callers before Batch 11. Filed 2026-10-15.
  
  - **Symptom**
    
    - No test file calls `runTree`, `runShow`, `runPath`, `runResolve`, `runProject`, `runTrack`, `runReverseTrack`, `runUnfold`, `runFold`, `runZoom`, `runRemove`, `runProfile*` or `runLinkCandidates`, and none imports `service.ts` or `serviceClient.ts`. The `run*` functions that a test calls are `runInsert` (3 files), `runUpdate` (5), `runRetype` (7), `runBacklinks` (5), `runAddBlockLink` (5), `runRemoveBlockLink` (3) and `runIngest` (1).
    - Rendering is covered only by `store/views.test.ts:46-48` (`renderTree` with a view) and `links/refusals.test.ts`; projection only by `folder/folders.test.ts:53,60` and `linking/anchors.test.ts:75-100`.
    - So the reads of Batch 11's step 3 (most of it) and its step 8, the service, have no test group; with no test written before the move, the differential run of Verification Plan layer 4 is their only check.
  - **Fix directions**
    
    - Decided 2026-10-15 (the user): <a name='id/BlockNode:00D3YFXDC8007' class='aperas-anchor aperas-id'></a> the missing tests are added as explicit steps of Batch 11 ([step 10](../planning/core.md#id/BlockNode:00D3Z01YER001)) and not only as a clause of its Done when, one per group whose commands the survey found untested, each written before its group moves and run against the working engine, and named in [Layer 1](../planning/core.md#id/BlockNode:00D3XQW6AG001) of the Verification Plan. They are written at the batch or batches that require them, not before: here, Batch 11, each before its group moves and none ahead of the batch. A proposal, not agreed: [which of them can be waived](../planning/core.md#id/BlockNode:00D3Z01YER006) because the differential script already covers the command.
  - **Closed by**
    
    - [Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000C), step 10 (the tests, written before the groups of steps 3, 4, 5 and 8 move) and its Done when.
  - **Related**
    
    - [The service has no timing, memory or load-test coverage](#id/BlockNode:00CVQHD7CR001), which is about timing and memory and not about the commands' results.
    - [The map of the callers above the store](#id/BlockNode:00D3YFA80R001), which lists the tests that touch the store.
- **Three behaviours of the caller depend on the order of an unordered read of the store, and five listings change order with the engine**: <a name='id/BlockNode:00D3YFXDC800D' class='aperas-anchor aperas-id'></a> found 2026-10-15 by the Coder in the survey of the callers before Batch 11, which extends the order-sensitive reads first found on 2026-10-12 ([the newest-first issue](#id/BlockNode:00D22ZK7C8001), [the live-or-tombstoned issue](#id/BlockNode:00D22ZMTKG001)). Filed 2026-10-15.
  
  - **Symptom**
    
    - `positionsEqual` (`artifacts.ts:371-373`, used at `artifacts.ts:611`) compares the `position` list of a reused `Link`, read in match order, with the fresh ascending list, element by element. If the order differs, the `Link`'s `props` are rewritten and the `position` `StringProp`s change id without a change in content.
    - `buildRenderTree` collects `unfolds` in match order (`node.ts:1975-1987`) and `discoverCone` lets the first escaping link in that order claim the target (`node.ts:1530-1569`, the test `if (!zs.canonical.has(targetId))` at lines 1538 and 1560), so the place of a node reached through two unfolded links is the order's choice, which is [the canonical-render order check](../design/core.md#id/BlockNode:00D24N87T000Q) of the design.
    - `findByExactPath` (`tree.ts:20-21`) takes the first subject with the path, tombstoned or live, as in [the live-or-tombstoned issue](#id/BlockNode:00D22ZMTKG001). Its callers are `resolve.ts:69`, `resolveCreate.ts:98`, `kgProject.ts:46`, `linkIntegrity.ts:323` and 12 test and tool sites. The artifact side already filters (`findLiveByKindAndPath`, `artifacts.ts:188-191`); `kgProject.ts:46` and `linkIntegrity.ts:323` do not. The Coder did not reproduce a wrong pick.
    - Five listings take their order from the engine's: <a name='id/BlockNode:00D3YFXDCG000' class='aperas-anchor aperas-id'></a> the report of `checkLinkIntegrity` (`linkIntegrity.ts:112`, so the output of `check-links` and the `linkWarning` text of the service); `track --reverse` (`kgTrack.ts:82-110`); the profile and view lists (`kgProfile.ts:65,111`); `backlinks` (`node.ts:2131-2133`, which gives `kgBacklinks.ts:32` its printed order, `kgProfile.ts:69` its list of views and `removeProfile` its cascade); and the links of a block in `tree`, `unfold` and the web ([the newest-first issue](#id/BlockNode:00D22ZK7C8001)). Two more depend on first-seen order: `buildLiveSlugPathIndex` (`node.ts:957-965`, "first writer wins per name", which decides the block a collision error names) and `orderedChildIds` (`storeAccess.ts:188-196`, whose stable sort leaves a child with no sibling index, or two with one index, in match order).
  - **Fix directions**
    
    - The first three can be fixed in the caller: <a name='id/BlockNode:00D3YFXDCG002' class='aperas-anchor aperas-id'></a> `positionsEqual` by comparing sorted lists, `findByExactPath` by asking for the live node, and the canonical place by a rule that does not follow the order of `unfolds` (gated by the design's open point). Whether the five listings are sorted in the caller, so that the layer-4 output compare is exact, or listed as deliberate differences is not decided.
  - **Closed by**
    
    - [Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000C), step 3 (the canonical place and `findByExactPath` as the live primitive of Batch 10) and step 5 (`positionsEqual`); the five listings wait for the open point of that batch.
  - **Related**
    
    - [`findByExactPath` takes the first node found at a path](#id/BlockNode:00D22ZMTKG001), [the tree view lists a block's links newest first](#id/BlockNode:00D22ZK7C8001), and [The order of links without a position](../design/core.md#id/BlockNode:00D24N87T000P) and [A set of live ids](../design/core.md#id/BlockNode:00D24N87T000X) in the design.
    - [The map of the callers above the store](#id/BlockNode:00D3YFA80R001), section (4).
- **42 live `BlockNode`s have no `parent` and no container lists them**: <a name='id/BlockNode:00D3YS41VR001' class='aperas-anchor aperas-id'></a> found 2026-10-15 in the Coder's census of a clone of the mirror, which counted the parentless nodes. Filed 2026-10-15.
  
  - **Symptom**
    
    - In the files of `Apeiron/BlockNode.jsonld` (a clone, read 2026-10-15 with `jq`), 42 live `BlockNode`s have no `parent` key. No `FolderNode`, `ArtifactNode` or `BlockNode` lists any of them in its `children`, so none is reachable by containment from a live root.
    - They are 8 headings, 29 list items and 5 paragraphs. Eight of them (six headings and the `**Work**` and `**Report**` list items) have children of their own, 3 to 7 each, and those children's `parent` points back at them; the other 34 have none. They include `## Workspace Split` (`BlockNode:00CDGTX55R001`), `## Dashboard` (`BlockNode:00CE1HNTYR001`), `## Dev environment setup` (`BlockNode:00CVJH53Q8001`), the skill-delta entries `v2.2` to `v2.11` (`BlockNode:00CR8VN7BG001` to `BlockNode:00CR8VR6ZR001`) and a thread's `**Work**` and `**Report**` (`BlockNode:00CR9S6080001`, `BlockNode:00CR9S6088000`).
    - No `Link` targets any of the 42, no `TreeView` unfolds or roots at one, and no node other than the children of the eight refers to them. In the rest of the mirror, `parent` and `children` agree (0 disagreements, 0 repeated ids, 0 nodes in two containers).
    - The full list is the live `BlockNode`s of `Apeiron/BlockNode.jsonld` without a `parent` key.
  - **Fix directions**
    
    - No fix. Decided 2026-10-16 (the user): <a name='id/BlockNode:00D3YS41VR008' class='aperas-anchor aperas-id'></a> the migration of the mirror leaves the 42 as they stand ([Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8002)), so that they test how the new engine handles nodes that nothing reaches, the case of [garbage collection never collects an unreachable block that was never tombstoned](#id/BlockNode:00D1A2AY68001).
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)) leaves them as they stand: the live documents without a `parent` are 44 in the migrated clone, the root folder, `concepts.md` and these 42 blocks. Still undecided.
  - **Related**
    
    - [Where a node's parent comes from](../design/core.md#id/BlockNode:00D2562RC8001) and [Containment](../design/core.md#id/BlockNode:00D24N87SR00Z) in the design; [Garbage collection never collects an unreachable block that was never tombstoned](../issues/core.md#id/BlockNode:00D1A2AY68001), whose case these blocks are by their reachability; [one live artifact, `concepts.md`, has no `parent`](../issues/core.md#id/BlockNode:00D3F6RJCG001) for the artifact that the census found beside them.
- **Documents of the mirror lack fields that the design declares `one`**: <a name='id/BlockNode:00D3YV43Q0001' class='aperas-anchor aperas-id'></a> found 2026-10-15 in the Coder's census of a clone of the mirror, which checked every document against the shapes of [Fields per class](../design/core.md#id/BlockNode:00D24N87SR00M). Filed 2026-10-15.
  
  - **Symptom**
    
    - [A field the shapes declare as `one`](../design/core.md#id/BlockNode:00D24N87SR00Y) is present on every document of its class, and 20 documents of the mirror (`Apeiron/`) lack one or more of them. All 16 `FolderNode`s lack `projectedHash`. Two of the 55 `ArtifactNode`s lack `fileHash`, `ingestedHash`, `lastIngestedAt`, `lastTrackedAt` and `projectedHash`: `ArtifactNode:00CF1TZQV8000` (`issues/cli.md`, a tombstoned holder) and `ArtifactNode:00CR5AEJ88000` (`concepts.md`, live and never tracked); the other 53 have all five. Two of the 9 `Profile`s lack `kind` (`default`, which holds only its `handle`, and `dinhlx`) and one lacks `name` (`default`).
    - `type` of an `ArtifactNode` is optional in the shapes, and 7 of the 55 have none; that is not a gap.
    - Every other declared key is present where the shape asks for it, and no node of the mirror carries a key outside the shapes except the `predicate` of a `Link` ([every `Link` carries a `predicate`](#id/BlockNode:00D3WNBPPG001)).
  - **Fix directions**
    
    - Decided 2026-10-15 (the user), in two parts. (1) The hash and timestamp fields that projection or ingest sets (`projectedHash`, `fileHash`, `ingestedHash`, `lastIngestedAt` and `lastTrackedAt`) and the `kind` of a `Profile` become optional in the shapes. The design edit is made (2026-10-16): [Fields per class](../design/core.md#id/BlockNode:00D24N87SR00M) declares them optional and [the sentence on the `one` fields](../design/core.md#id/BlockNode:00D24N87SR00Y) no longer names them. (2) The migration of the mirror ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)) fills only `kind: human` of `Profile:00CJC4S69R000` (`dinhlx`), which lacks `kind`. `Profile:00CA03JXD8000` (`default`) lacks `kind` and `name`: it is the auto-generated fallback for everyone, so it has no `kind` and none can be given, because it cannot know. Whether `default` should have a `name` is not decided; it is [an open point of Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8001). What remains, so the issue stays open: the real mirror gets the `kind` of `dinhlx` at the cutover (done on a clone only), and whether `default` should have a `name`, which is also the one document still lacking a field that the shapes declare `one`.
    - The dry run of 2026-10-16 on a clone ([Batch 9, step 6](../planning/core.md#id/BlockNode:00D3Y3DMTR001)): `Profile:00CJC4S69R000` (`dinhlx`) now holds `kind: human` and `default` is unchanged, with no other document of the mirror touched by this part. The design edit of the optional fields is made (2026-10-16), and the real mirror gets the `kind` at the cutover.
  - **Related**
    
    - [Enforcement](../design/core.md#id/BlockNode:00D24N87T000M) in the design, which gates what the load does with a document outside the shape, and [The meta-model and the schemas](../planning/core.md#id/BlockNode:00D3XQQ2VG003) in Batch 3.
- **`concepts.md` has no file under `artifacts/`, so `track` offers to remove its node permanently, and a yes would delete it**: <a name='id/BlockNode:00D4JZ0A7R001' class='aperas-anchor aperas-id'></a> found 2026-10-16 in the dry run of the migration of the mirror, on a clone and on the real graph. Filed 2026-10-16.
  
  - **Symptom**
    
    - `ArtifactNode:00CR5AEJ88000` (`concepts.md`) is live, holds one child block and a `text` that describes it as the shared vocabulary promoted up by the grapher, and has no `parent` and none of the hash and timestamp fields ([it was never tracked](#id/BlockNode:00D3YV43Q0003)). No file `concepts.md` exists under `artifacts/`, in the clone or in the real graph. `aperas track` therefore offers to remove the node permanently, with "no matching file found on disk"; run with a yes, it would delete the node and its block. The node is the graph's own copy, and the graph is the source: its projection is missing, and the projection is not what is wrong. The offer is harmless unless the prompt is answered yes.
  - **Fix directions**
    
    - Listed, not chosen: <a name='id/BlockNode:00D4JZ0A7R005' class='aperas-anchor aperas-id'></a> project it (`aperas project concepts.md`), which gives it a file and ends the offer; or leave it, and answer no at every `track` prompt that names it.
  - **Related**
    
    - [One live artifact, `concepts.md`, has no `parent`](#id/BlockNode:00D3F6RJCG001) and [42 live `BlockNode`s have no `parent` and no container lists them](#id/BlockNode:00D3YS41VR001), the parentless documents of the census, which the migration of the mirror leaves as they stand ([settled in Batch 9](../planning/core.md#id/BlockNode:00D3YSA5T8002)); [the confirmation prompt of a corpus-wide `ingest`](#id/BlockNode:00CNX1T4XG001), the other prompt that proposes to remove nodes whose file is not on disk.

## Sub-Parts <a name='id/BlockNode:00CF1WZ4JG00A' class='aperas-anchor aperas-id'></a>

Core's own known parts, and where each one's issues currently live:

- **`crud`** — not yet migrated; archived at `archive/Aperas-crud-design.md`, whose own §6 ("Bookkeeping gaps found while designing this") already names several items overlapping this doc's Open Issues above. Planned as `archive-migration`'s next sub-task.
- **`treeview`** — 4 open: <a name='id/BlockNode:00CF1WZ4JG00C' class='aperas-anchor aperas-id'></a> stale `TreeView.unfolds` references, a bare `aperas unfold <ref>` mutating the default view instead of peeking, no raw single-node inspection command, and `unfold` not marking tombstoned children. See [Open Issues](../issues/treeview.md#id/BlockNode:00CE1GW638002).
- **`linking`** — 2 open, both filed: <a name='id/BlockNode:00CF1WZ4JG00D' class='aperas-anchor aperas-id'></a> `extractAnchorNames` treats a backtick-quoted example anchor as a real claimed name, and `aperas update` never re-derives a non-heading block's title. See [Open Issues](../issues/linking.md#id/BlockNode:00CDBYV5A8002).
- **`list-consumption`** — 1 open: <a name='id/BlockNode:00CF1WZ4JG00F' class='aperas-anchor aperas-id'></a> inserting a list item always spawns a fresh run-leader. See [Open Issues](../issues/list-consumption.md#id/BlockNode:00CE32GRZG000).

## Pending Tasks <a name='id/BlockNode:00CF23SXQ8001' class='aperas-anchor aperas-id'></a>

See [Task Breakdown](../planning/core.md#id/BlockNode:00CF23FB1G003) for the plan of the engine of the design, and the [Archive](../planning/core.md#id/BlockNode:00D3XP4XK0001) there for the reconcile fixes that are done.

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
- **When `APERAS_APEIRON_ROOT`, `APERAS_ARTIFACTS_ROOT` and `APERAS_GRAPH_NAME` are unset, a service of another checkout binds whatever `Aperas.dev/AperasKG` points at, which is the real graph**: <a name='id/BlockNode:00D3Z1PHRR001' class='aperas-anchor aperas-id'></a> found 2026-10-15 in the isolated service trial of `Aperas.dev`'s `aperas`. Filed 2026-10-15.
  
  - **Symptom**
    
    - `resolveFallbackGraphRoot()` in `packages/core/src/graphConfig.ts` resolves `<repo root>/AperasKG`. In the checkout `Aperas.dev` that path is a symlink to the real graph, so the unset case of `APERAS_APEIRON_ROOT`, `APERAS_ARTIFACTS_ROOT` and `APERAS_GRAPH_NAME` binds the real graph, with no error and no sign.
    - `resolveEffectiveApeironRoot` takes the environment variable first, then an `aperas.config.json` found by walking up from the start directory, then the fallback. `npm run aperas --` pins the working directory to `monorepo/`, so the walk starts there and a clone's own `aperas.config.json` is not found through it.
    - The trial used the variables, so it did not bind the real graph; a run without them would have.
  - **Fix directions** (listed, not chosen)
    
    - (a) Drop the symlink, so that the unconfigured case finds no graph. A cloned mirror is then reached by the three variables, or by running `tsx packages/cli/src/aperas.ts` from the clone's directory, whose own `aperas.config.json` the walk finds.
    - (b) Refuse to start without an explicit root.
    - (c) Keep the symlink and warn.
  - **Related**
    
    - [Two services on two copies](#id/BlockNode:00D3YFA81000W) and [the `aperas` command is bound to one checkout](#id/BlockNode:00D3YFA81000X), in the map of the callers above the store: the isolation of a second service by its environment variables, and the command that runs one checkout.
  - **Resolved (2026-10-15, the user)**: <a name='id/BlockNode:00D41A7ZR8001' class='aperas-anchor aperas-id'></a> no code change is intended, and none of the fix directions (a), (b) and (c) is pursued; the symlink is left as it is. The mechanism is the one that (a) names for a cloned mirror: running `tsx packages/cli/src/aperas.ts` from the clone's directory, whose portable `aperas.config.json` the walk of `resolveEffectiveApeironRoot` finds (the orchestrator checked that the roots resolve to the clone from there, with no variable set). A second service still needs its own `XDG_RUNTIME_DIR` and `APERAS_HTTP_PORT`, because the lock, the socket, the token and the port are per user.
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
- **`design/` has no document for the store, hydration or the service lifecycle**: <a name='id/BlockNode:00D0W07DRR000' class='aperas-anchor aperas-id'></a> noted 2026-10-10 in the store-size investigation. The graph holds the early ApeironNgn design only in the archive (`archive/Aperas-design.md`, where `rehydrateStore` is a quoted 256 ms at 1,594 BlockNodes), and nothing in `design/` states the quad shape the store holds, when and how the mirrors are hydrated and dehydrated, what the boot, the flush timers, the shutdown and the reload each do and in what order, or what the client's waits (300 ms ping, 5 s ready, 10 s stop) are allowed to assume of them. The boot and shutdown issue already says there is no document for the service lifecycle; this entry records the same gap for the store and hydration too, so the figures in the issues above have no design to be read against. Recorded only; no design is written here. Filed 2026-10-10.
  
  - **The early design's trigger for revisiting the store was met by wrapper overhead, not by data size** (2026-10-12): the archived ApeironNgn design chose Oxigraph's in-memory store as "not a from-scratch build" (its section 3) and decided to revisit it only "once the KG's actual size makes in-memory rehydration or working-set size a real problem (GB-level)" (its section 4, in the rollout step on the store; its section 5 repeats the wait). The trigger is a data size. In practice the service idled at 1.05 to 1.5 GB for 3.66 MB of JSON-LD on disk (about 6.3 MB now, see the counts in [the memory entry](#id/BlockNode:00CVQ4Z968001)), and the measured mechanism is the wrappers that full-store scans leave alive, not the data ([the scan entry](#id/BlockNode:00D0W02KPG001)); the recorded trigger names no wrapper overhead.
  - **Resolved** (2026-10-15): <a name='id/BlockNode:00D3X3MHF0001' class='aperas-anchor aperas-id'></a> [Core — Design](../design/core.md#id/BlockNode:00D24N87SR001) is the document for the store and its mirror, drafted with the user from 2026-10-12 to 2026-10-15: the engine in memory, and the mirror, its format, the load and the flush on its caller's side. The service lifecycle stays outside it, listed under its Open points as [The service lifecycle](../design/core.md#id/BlockNode:00D24N87T000W).

- **`npm run verify` costs ~5 minutes, dominated by a process-lifetime slowdown neither store-freshness nor heap size explains** — instrumented per-step (a `console.log`-wrapping timer keyed on each step's own `"N. Testing..."` header, printing a sorted breakdown even on failure) and found the same operation (`checkLinkIntegrity`'s corpus sweep, and separately `parseMarkdownTree`-driven ingestion in Linking Slice steps 13-18) costs low hundreds of ms freshly isolated, but 12-55 *seconds* run as `verify.ts`'s own later steps — steps 3-6 doing the identical kind of parsing work stay fast, steps 7-12 in between do no heavy parsing at all, then 13 onward is uniformly slow. Two credible causes ruled out by direct experiment, not by inspection: (1) oxigraph's own WASM memory footprint (`external`, ~850MB-1GB by that point vs ~50MB fresh) looked causal, but compacting the store mid-run (dehydrate a scratch dir, rehydrate a brand-new `Store` with the identical live content) made the same sweep *slower*, not faster — ruling out "this one store instance is bloated." (2) V8 heap-size tuning (`--max-old-space-size=8192 --max-semi-space-size=128`) changed nothing measurably.
  
  - **Practical problem resolved, root cause still not**: <a name='id/BlockNode:00CJ0QG048001' class='aperas-anchor aperas-id'></a> since the leading hypothesis was V8-engine-level degradation intrinsic to one long process (only a genuinely fresh process/V8 isolate resets it), split `verify.ts` into two files instead of chasing the exact mechanism further — `verify.ts` (steps 1-12, `npm run verify`) and the new `verifyExtended.ts` (steps 13-19, `npm run verify:slow`), sharing only small structural helpers (`verifySupport.ts`). Measured live: `verify` now runs in ~42s (down from ~290-326s); `verify:slow` alone runs the same steps 13-19 in ~70-100s (down from ~230s+ *inside* the combined process) — confirming the isolation hypothesis practically without confirming *why* isolation helps. That "why" is deliberately left open in [the next Open Issues entry](#id/BlockNode:00CJ0HX2Y0000) as a narrower, lower-stakes curiosity now that the actual pain (an unaffordable per-turn cost) is gone.
  - **Resolved**: <a name='id/BlockNode:00D1EZNJ30001' class='aperas-anchor aperas-id'></a> the slowdown was measured further on 2026-10-11 and the suite this entry describes no longer exists. What was found: in every slow step the full garbage collections (Mark-Compact) took 70 to 87% of the step's time, and fast steps had 0 or 1 of them; 849 of 895 collections in one run and 1,041 of 1,088 in the other freed 5 MB or less from a heap of about 230 to 450 MB, each pause about 150 to 290 ms, so the cost is repeated full collections that find almost nothing to free (two runs, each cut at 180 s, one sample each). A 50 ms timer between steps cut the collection time in some steps (step 5 from 24,985 ms to 0, step 5d from 47,103 ms to 3 ms, steps 5c and 5f less) and not in others (step 3, step 5g); a bare `setImmediate` yield and no yield did not. A fresh process takes 2.9 s to rehydrate the corpus directory, against 37.8 s in a process that has already rehydrated and dehydrated it (one run, 55,968 quads), so the slowness is state built up in the process and not the data. The old suite's steps 7, 10 and 11 cost 649, 188 and 202 s on the real-size store and milliseconds on a tiny fixture, so the cost came from the size of the store and not from the steps' own work. What replaced it: the monolithic suite (26 steps, about 1,430 s (1,431 s in the run's own table, 1,434 s wall) in one measured run) is retired and deleted, its checks are standalone files in groups under `monorepo/packages/cli/src/tests/`, `npm run verify` runs the `commit` suite in 8 to 20 s, and `npm run verify -- --suite demand` runs 56 cases on a copy of the real mirror in 73 s and 74 s (two occasions); the built suites are in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001). What is still a reading and not shown: that the trigger is V8 starting full collections when external (wasm) memory has grown past its limit, which the collection cannot lower because the wasm side is released by a later callback, was not tested; the earlier guess of a JIT-level degradation is replaced by the collection reading and was not tested either. The core's own cost is not fixed, only the suite made independent of it, and stays open in [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001) and [the removal-stall issue](../issues/core.md#id/BlockNode:00CVNX6A3R000).

- **Why isolation helps is still unexplained** — narrower and lower-stakes now that the split above removes the actual pain, but the mechanism itself is still just "two ruled-out hypotheses and one unconfirmed one" (see the entry above: not oxigraph's own memory footprint, not V8 heap-size — leading guess is inline-cache megamorphism or similar JIT-level degradation in a long process running many differently-shaped operations, never directly confirmed). Worth a closer look sometime with real V8 profiling (`--prof`/`--trace-deopt`) if it recurs somewhere a process split isn't a viable fix, but not worth chasing further here.
  
  - **Resolved**: <a name='id/BlockNode:00D1EZSCH8001' class='aperas-anchor aperas-id'></a> explained, in part measured, not proved (2026-10-11). Measured: the slow steps are repeated full garbage collections (Mark-Compact), 70 to 87% of the time of every slow step, that free 5 MB or less each from a heap of about 230 to 450 MB; a 50 ms timer between steps cut them in some steps (step 5 from 24,985 ms to 0, step 5d from 47,103 ms to 3 ms) and not in others (step 3, step 5g), and a `setImmediate` yield or none did not; a fresh process rehydrates the same directory in 2.9 s against 37.8 s in a process that has already rehydrated and dehydrated, about thirteen times (one run); the old suite's steps 7, 10 and 11 cost 649, 188 and 202 s on the real-size store and milliseconds on a tiny one. This replaces the leading guess of inline-cache megamorphism or another JIT-level degradation in a long process, which the collection measurements replace as the reading and which was itself not tested; the V8 profiling (`--prof`, `--trace-deopt`) proposed here was not run. Still a reading and not shown: that the trigger is V8 starting a full collection when external (wasm) memory has grown past its limit, which the collection cannot lower because the wasm side is released by a later callback, so that a pause lets the callbacks run and stops the collections. Whether `free()` on the quads would remove the growth, which was not tested when this was written, was tested by [the `free()` landing](../history/core.md#id/BlockNode:00D21FP4ZG003) of 2026-10-12: in a scratch process on a copy of the mirror (59,275 quads, 3 samples per case, a fresh process each), eight scans of all ids stayed flat at about 265 MB where they had grown 40 MB a call, a dehydrate of both mirrors fell from 33 to 38 s to 2.5 to 3.8 s and a rehydrate from 3.3 to 3.5 s to 2.0 to 2.9 s. That agrees with the reading and does not prove it, because the recorded measurements do not count collections. Two runs, each cut at 180 s, one sample per variant, for the earlier measurements. The suite no longer depends on it: the monolithic suite is retired and replaced by standalone files, `npm run verify` runs the `commit` suite in 8 to 20 s and `npm run verify -- --suite demand` runs 56 cases on a copy of the real mirror in 73 s and 74 s, as recorded in [Testing — Design](../design/testing.md#id/BlockNode:00D1D5F63R001); the core's cost itself stays open in [the full-store-scans issue](../issues/core.md#id/BlockNode:00D0W02KPG001).
- **A `children` entry of the root folder in the tracked mirror names the `.threads` folder, whose document lives only in `.state/`: a dangling reference from the main graph into the threads graph, which `ingest` reads as a ghost folder to remove**: <a name='id/BlockNode:00D417WK80001' class='aperas-anchor aperas-id'></a> found 2026-10-15 by the Coder in the debugging of [the `ingest` prompt](#id/BlockNode:00CNX1T4XG001). Filed 2026-10-15.
  
  - **Symptom**
    
    - `FolderNode:00CR5AN248000` is the `.threads` folder; its document, with `holder: true`, lives only in `Apeiron/.state/`, and the `children` of the root folder in the tracked mirror (`Apeiron/`) names it. The threads graph was thought isolated from the main graph through `parent`, and `children` is a reference from the main graph into it.
    - Without `.state/` (a `git clone`, a CI run, a fresh harness copy) the id loads as a live folder with no path and no `holder`, and `ingestFolderTree` lists it for removal. Every `ingest` reaches it, with paths or without and with `--track` or without, because the folder sweep runs each time; `track` with paths cannot, for it never runs the removal sweep. The proposed removal prints the folder's name as `null`, since JSON turns a missing path into `null`, and the prompt waits on standard input because nothing checks for a terminal.
    - With standard input closed (`</dev/null`) the answer is no: <a name='id/BlockNode:00D417WK9G000' class='aperas-anchor aperas-id'></a> nothing is removed, the rest of the ingest still lands, the exit code is 0 and the hold-back is only a message in the output; with standard input open and silent the prompt blocks for good. `--force` is no way round it, since it tombstones the ghost and writes a `FolderNode:00CR5AN248000` tombstone into the tracked mirror. A copy without `.state/` also drops the root's `children` entry on its first ingest.
    - It cannot fire on the real graph or on a copy that carries `.state/`; it can fire in the harness and the dry runs of the new engine's plan if their copies are made without `.state/`.
  - **Root cause** (read from the code by the Coder)
    
    - `ingestFolderTree` in `core/src/apeironNgn/folders.ts` (lines 20 to 22 and 56 to 57) treats any id with the prefix `FolderNode:` that is a subject in the store as a live folder. The ghost has no path, so `pendingRemovals` carries `undefined`, which JSON turns into `null` (`folders.ts:152`, `kgIngest.ts:148`).
    - The reference exists because the multi-graph design that would keep the threads graph apart is not built: the tracked mirror lists the id in the `children` of its container, and the document is written to `.state/` only ([Containment](../design/core.md#id/BlockNode:00D24N87SR00Z) states what a container lists).
  - **Fix directions**
    
    - Decided 2026-10-15 (the user): <a name='id/BlockNode:00D417WKA0002' class='aperas-anchor aperas-id'></a> the multi-graph design is out of scope, so the dangling reference is worked around and not removed. The workaround is the enhanced filter, which keeps only the live `FolderNode`s that have a document and a path (the one-line change at `folders.ts:56`), and it is fixed now together with the stdin prompt of [the `ingest` prompt issue](#id/BlockNode:00CNX1T4XG001): a flag that answers every removal prompt of `ingest` and `track` with no, and no refusal on a missing terminal (a refusal on a missing terminal would break `echo yes | aperas project` and the piped answers that `lineReader.ts` states as a design goal). It is made on branch `oxigraph` of `Aperas/`, the engine the workflow uses. A coder is making it now; this issue stays open until the coder reports.
    - The multi-graph design that would remove the reference is not in scope.
  - **Not proven**
    
    - What the new engine's load does with a `children` entry whose id has no document: a ghost, an error or nothing. The Coder did not read it. The design says the load returns the ids that are referenced and never defined, and what the caller does with that list belongs to the service lifecycle ([the load computes `danglingRefs` and the service never reads it](#id/BlockNode:00D258W098001)). The differential run of [Batch 13, step 3](../planning/core.md#id/BlockNode:00D3XQQ2W0013) carries a fixture for it.
  - **Related**
    
    - [The `ingest` prompt issue](#id/BlockNode:00CNX1T4XG001), whose prompt this entry's cause explains and whose fix is made together with it.
    - [The load computes `danglingRefs` and the service never reads it](#id/BlockNode:00D258W098001): <a name='id/BlockNode:00D417WKAG000' class='aperas-anchor aperas-id'></a> the ghost folder is a dangling reference of the main graph, the case that list is for, and the new engine returns it there.
    - [The service lifecycle](../design/core.md#id/BlockNode:00D24N87T000W), an Open point of the design, which decides what is done with the list of undefined ids.
    - [Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000C), step 5: <a name='id/BlockNode:00D417WKAR000' class='aperas-anchor aperas-id'></a> the removal detection of `ingest` moves with it.
  - **Resolved (2026-10-15)**: <a name='id/BlockNode:00D4579FMR001' class='aperas-anchor aperas-id'></a> both private `allLiveIdsOfKind` helpers now keep only the live nodes that have a `path`, so the ghost is no longer a live node: the filter `path !== undefined` is at `core/src/apeironNgn/folders.ts:20` (it feeds `ingestFolderTree`, so the removal sweep no longer lists the `.threads` folder, and `existingByPath`, `folderIdByPath`, `liveArtifactIds` and `getFolderRecord`) and at `core/src/apeironNgn/artifacts.ts:197` (it feeds `trackAllArtifacts`, so a full `track` no longer reports it). The ghost `ArtifactNode` was reproduced the same way: named in the root's `children`, it made a full `track` return `pendingRemovals: [undefined]` before the fix and no longer does. Folders really gone from disk and folders flagged `holder` that have a document behave as before (both tested).
    
    - Tests: <a name='id/BlockNode:00D4579FMR002' class='aperas-anchor aperas-id'></a> `ghost.test.ts`, 4 cases, red before the fix, named in the `commit` suite.
    - Where it stands: <a name='id/BlockNode:00D4579FMR003' class='aperas-anchor aperas-id'></a> staged on branch `oxigraph` of `Aperas/` and not committed (committing is the user's), and live in the running service since its restart of 2026-10-15.
    - Evidence, run by the orchestrator at normal CPU speed: <a name='id/BlockNode:00D4579FMR004' class='aperas-anchor aperas-id'></a> `commit` 70 of 70 in 19.6 s (budget 60 s), `essential` 27 of 27 in 2.9 s (budget 5 s), the groups `folder,prompt,ingest` 19 of 19 in 1.4 s.
    - **Not resolved by this**: <a name='id/BlockNode:00D4579FMR005' class='aperas-anchor aperas-id'></a> [the `danglingRefs` entry](#id/BlockNode:00D258W098001) stays open, and so does the dangling `children` reference itself, which is worked around and not removed; the multi-graph design that would remove it is out of scope. What the new engine's load does with such an entry stays under Not proven above.
    - The prompt that the ghost raised is resolved with it: <a name='id/BlockNode:00D4579FMR006' class='aperas-anchor aperas-id'></a> [the `ingest` prompt issue](#id/BlockNode:00CNX1T4XG001).
- **A corpus-wide `aperas ingest` (no path) can hang indefinitely on an interactive confirmation prompt with no signal that it's waiting rather than working**: <a name='id/BlockNode:00CNX1T4XG001' class='aperas-anchor aperas-id'></a> `kg:ingest` run unscoped detected content it proposed to remove and printed `Are you sure you want to remove these? [yes/NO]:`, then blocked on stdin. Run from a non-interactive shell (no tty attached), that stdin is immediately at EOF, so the prompt never resolves — the process just sits there. Confirmed live: the process showed near-zero CPU the entire time (ruling out "genuinely slow on a large corpus," which shows sustained high CPU instead, e.g. at service startup), and the ApeironNgn service itself answered an unrelated read (`aperas backlinks`) instantly throughout, proving the request never even reached the service's own queue — the block is entirely client-side, before `request()` is ever called. When stdin finally closed, the process exited 0 with the prompt still unanswered on screen; the flagged items turned out to already be old tombstones (dated a week prior), so nothing was actually lost this time, but nothing in the tool's own behavior guarantees that — an EOF being treated as "no" is incidental, not a documented contract. Not yet implemented: either a `--yes`/`--non-interactive` flag that skips the prompt with an explicit answer, or a `stdin.isTTY` check that hard-refuses (rather than blocking) when the answer can't actually be given.
  
  - **Since observed (2026-10-15), on a document and not the corpus**: <a name='id/BlockNode:00D3YH1Y88000' class='aperas-anchor aperas-id'></a> on a service of the checkout `Aperas.dev` over a clone of the current graph, `aperas ingest discussion/trial-scratch.md` (one new document) stopped on an interactive confirmation that named a folder "permanently removed: 'null' (folder)", the folder's name printed as the string `null`, and waited on standard input for 211 s. It did not repeat for a second document, and with `</dev/null` the later runs did not prompt. The root cause is not found: why a folder with no name was proposed for removal at all is not traced, so the prompt may not be only the one of a corpus-wide ingest. An unscripted caller hangs here. The removal detection moves with the ingest in [Batch 11](../planning/core.md#id/BlockNode:00D3XQQ2W000C), step 5; the prompt itself (a `--yes` flag or a `stdin.isTTY` check) belongs to no step of the plan.
  - **Being debugged first (2026-10-15)**: <a name='id/BlockNode:00D3Z1E97R001' class='aperas-anchor aperas-id'></a> a coder is debugging this prompt now, and it is debugged first; a fix, if any, follows the finding. No batch of [the plan](../planning/core.md#id/BlockNode:00CF23FB1G003) changes for it.
  - **Cause found, and the fix decided (2026-10-15, the user)**: <a name='id/BlockNode:00D4190V7G000' class='aperas-anchor aperas-id'></a> the Coder found the folder called `null`: it is a ghost `FolderNode`, the id of the `.threads` folder, which the tracked mirror names in the `children` of the root and whose document lives only in `.state/`, so that without `.state/` any `ingest` lists it for removal and the prompt waits on standard input ([the ghost folder](#id/BlockNode:00D417WK80001)). The root cause that the entry above does not find is this one, and the wording of this issue, a corpus-wide ingest, is incomplete: any `ingest` reaches the prompt, with paths or without and with `--track` or without. With standard input closed the answer is no and the rest of the ingest lands; with it open and silent the prompt blocks for good. The user decided to fix it now, in the working engine on branch `oxigraph`: a flag that answers every removal prompt of `ingest` and `track` with no, and no refusal on a missing terminal, together with the filter that keeps the ghost out of the removals. A coder is making it, and the issue stays open until the coder reports.
  - **Resolved (2026-10-15)**: <a name='id/BlockNode:00D457ANWR001' class='aperas-anchor aperas-id'></a> `aperas ingest` and `aperas track` take `--no-prompt`. `confirmRemoval` in `cli/src/removalPrompt.ts` (new) then returns no at once, before any readline and any write of the question, so standard input is never read; the removals are still listed and the "Skipped" line is printed. `--force` is checked first and still wins. There is no `isTTY` check, so `echo yes | aperas ingest` keeps working and a closed stdin still counts as no. The flag is parsed, kept out of `<path>...` and documented in the help of each command. The prompts of `project` and of `link` are untouched.
    
    - **The cause of the one hang seen was the ghost folder**: <a name='id/BlockNode:00D457ANWR002' class='aperas-anchor aperas-id'></a> the hang on a document, and the folder printed as `null`, came from [the ghost folder](#id/BlockNode:00D417WK80001), which the removal sweep of every `ingest` listed; with its filter in place the sweep no longer proposes it.
    - A prompt is now avoidable with no terminal by `--no-prompt`. When the flag is absent the prompt still reads standard input, by design: a refusal on a missing terminal would break the piped answers that `lineReader.ts` states as a design goal.
    - Tests: <a name='id/BlockNode:00D457ANWR004' class='aperas-anchor aperas-id'></a> `removalPrompt.test.ts`, 5 cases, named in the `commit` suite.
    - Where it stands: <a name='id/BlockNode:00D457ANX0000' class='aperas-anchor aperas-id'></a> staged on branch `oxigraph` of `Aperas/` and not committed (committing is the user's), and live in the running service since its restart of 2026-10-15; the flag is client-side, so it works as soon as the CLI runs the new source.
    - Evidence, run by the orchestrator at normal CPU speed: <a name='id/BlockNode:00D457ANX0001' class='aperas-anchor aperas-id'></a> `commit` 70 of 70 in 19.6 s (budget 60 s), `essential` 27 of 27 in 2.9 s (budget 5 s), the groups `folder,prompt,ingest` 19 of 19 in 1.4 s.
    - **Not resolved by this**: <a name='id/BlockNode:00D457ANX0002' class='aperas-anchor aperas-id'></a> [the `danglingRefs` entry](#id/BlockNode:00D258W098001) stays open, and so does the dangling `children` reference of the ghost, which is worked around and not removed (the multi-graph design that would remove it is out of scope).
- **The code differs from the boundary: `src/apeironNgn/` holds the old engine and the code that calls it together, and there is no `src/shell/`**: <a name='id/BlockNode:00D4NBNCF8001' class='aperas-anchor aperas-id'></a> found 2026-10-16, when [the boundary](../design/core.md#id/BlockNode:00D3CJFB7G001) was mapped to the folders of `src`, and measured by the Coder's survey of the dependencies of `monorepo/packages/core/src/` in `Aperas.dev` at `4062128`. Filed 2026-10-16.
  
  - **Symptom**
    
    - The design places the engine, in memory, in `monorepo/packages/core/src/apeironNgn/` and the shell, on disk, in `monorepo/packages/core/src/shell/`, and the engine's directory imports nothing of the shell, no file system and no store library ([the shell](../design/core.md#id/BlockNode:00D4M7YEZG001)). In the code, `src/apeironNgn/` holds the Oxigraph engine and the code that calls it together (the node classes and `wrap`, ingest and projection, the dump and the load, resolve, link integrity and the sweeps), and there is no `src/shell/`.
    - The directory's own imports cross the boundary: <a name='id/BlockNode:00D4NBNCF8004' class='aperas-anchor aperas-id'></a> `node.ts` imports `dehydrate.ts` for `allIdsOfKind`, which pulls persistence into the engine's import closure and, through `store.ts` and `graphConfig.ts`, `node:fs`; 30 of its files import Oxigraph's `Store` as a type, and 6 import its values.
  - **Fix directions**
    
    - Decided 2026-10-16 (the user): <a name='id/BlockNode:00D4NBNCF8006' class='aperas-anchor aperas-id'></a> the current code moves to `src/shell/` as it is, with no `legacy/` directory, before the new engine is written, and the old engine's files are deleted as the batches replace them. The move is [Batch 15](../planning/core.md#id/BlockNode:00D4NBFKAG001), which closes this issue; once [Batch 12](../planning/core.md#id/BlockNode:00D3XQQ2W000S) is done, nothing under `src/shell/` imports `oxigraph`.
  - **Related**
    
    - [The thread-scope test sits inside the engine's directory](#id/BlockNode:00D2590B2R001), a narrower case of the same difference: Batch 15 moves `threadScope.ts` out of the engine's directory with the rest, and that issue stays open until [Batch 9](../planning/core.md#id/BlockNode:00D3XQQ2VR01M) makes the scope test the graph a node belongs to.
  - **Resolved (2026-10-16)**: <a name='id/BlockNode:00D4P4K8P0001' class='aperas-anchor aperas-id'></a> [Batch 15](../planning/core.md#id/BlockNode:00D4NBFKAG001) moved the current code from `core/src/apeironNgn/` to `core/src/shell/` in `Aperas.dev` (branch `js-apeironngn`), staged and not committed: `core/src/apeironNgn/` is gone, no import names `@aperas/core/apeironNgn/` outside `.archive/`, and the directory is free for the engine of [Batch 3](../planning/core.md#id/BlockNode:00D3XQQ2VG001). The old engine stays under `src/shell/` and imports `oxigraph` there until [Batch 12](../planning/core.md#id/BlockNode:00D3XQQ2W000S) deletes it. The working checkout `Aperas/` on branch `oxigraph` keeps the old layout.
