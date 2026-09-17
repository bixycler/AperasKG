# Aperas Skill — Discussion <a name='id/BlockNode:00CE8XWZJR001' class='aperas-anchor aperas-id'></a>

## Dashboard <a name='id/BlockNode:00CE8XWZK0000' class='aperas-anchor aperas-id'></a>

- [Design](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG003) — the four-level shape, abstract to concrete, the rewrite is aiming at.
- [Issues](../issues/aperas-skill.md#id/BlockNode:00CEA5KW4G002) — where today's flat v0 falls short of it.
- [Planning](../planning/aperas-skill.md#id/BlockNode:00CEA5M6S8005) — the ordered work to get there.
- [History](../history/aperas-skill.md#id/BlockNode:00CEA5MHD8002) — what exists today.

## Open Questions <a name='id/BlockNode:00CEB07XC0001' class='aperas-anchor aperas-id'></a>

- Does this "indirect edge" shape — a node whose role is commentary/judgment about *other* nodes' relationship, not structural containment and not a plain forward citation — deserve its own recognized convention (a naming pattern, a dedicated slot, something `aperas` tooling could specifically query for), now that assertions are whole nodes with context rather than bare triples? Or does an ordinary discussion `listItem` with wikilinks already cover it well enough as-is?
  
  - **What having no convention actually costs — three concrete losses, not an aesthetic one**: <a name='id/BlockNode:00CEC1JMWR001' class='aperas-anchor aperas-id'></a> *queryability*, since `aperas backlinks` returns citers undifferentiated and mixes content that merely references a node with judgments about it, which a reader wants separated; *lifecycle*, since crystallization ends a mediating node's job the moment its relationship becomes a direct citation, and nothing can find promotion candidates while indirect edges stay unidentifiable; and *deep read's context axis*, since judgments about a node are its highest-value context and currently surface buried among incidental mentions.
  - **The option worth arguing for is narrower than the question's framing — a coarse predicate as classifier, with the claim staying in prose**: <a name='id/BlockNode:00CEC1JMWR002' class='aperas-anchor aperas-id'></a> the plumbing already carries a predicate field sitting unused at the generic `[[wikilink]]`. Tagging such a link `judges` while the actual reasoning stays in the source node's own text restores machine-recognizability without re-importing the thing the `kg:assert` recall was right to remove.
  - **This would not undo that recall**: <a name='id/BlockNode:00CEC1JMWR003' class='aperas-anchor aperas-id'></a> `archive/Aperas-design.md`'s Graph view already specifies typed predicates (`impacts`, `verifies`, `derived_from`) as part of the design. Typed predicates were always intended; what was recalled was assertions-*as*-bare-triples — the claim being nothing but a triple — not predicates existing at all.
  - **The counter-argument is Meta-Aperas itself**: <a name='id/BlockNode:00CEC1JMWR004' class='aperas-anchor aperas-id'></a> crystallize an interface only when a real human–agent coordination point demands it, never ahead of one. This concern has produced two indirect-edge nodes so far. Two is not pressure.
  - **Proposed resolution — settle the design, defer the implementation**: <a name='id/BlockNode:00CEC1JMWR005' class='aperas-anchor aperas-id'></a> adopt the coarse-predicate-classifier shape as the intended answer so the decision is not re-litigated, and hold the implementation until there are enough indirect edges to genuinely want querying over them. That is a falsifiable trigger rather than a vague "later".

## Settled <a name='id/BlockNode:00CEA56A0G001' class='aperas-anchor aperas-id'></a>

- **Apeiron is the source; the artifacts are its shadows**: <a name='id/BlockNode:00CEA56A0G002' class='aperas-anchor aperas-id'></a> the `.md` files under `artifacts/` are projections cast by the graph, regenerable from it at any time and never the place a change is made. Editing a projection to change the graph is mistaking the shadow for the thing casting it — it can even appear to work, since the file looks right afterward, while the source is untouched or gets reconciled back in a shape nobody chose. Every other rule in the skill is downstream of this one; "graph-first, always" is its first consequence, not an independent instruction.
- **The substance is links and traversal, not documents**: <a name='id/BlockNode:00CEA56A0G003' class='aperas-anchor aperas-id'></a> a node's meaning isn't carried by its own text alone — it's constituted by what it links to, what links back, and where it sits among its siblings and its thread. `aperas backlinks`/`unfold`/`tree` are therefore the primary way of being in the graph, not verification bolted onto file-editing. Reaching for `grep` over projected files is the same category error one level down: searching the shadows for structure that only exists in the source. Confirmed live — a cross-doc linking question chased through `grep` and a raw `BlockNode.jsonld` read took several steps and still needed redoing, where `aperas backlinks` answered it in one call.
- **Freeflow is the connective thread beneath every other concern**: <a name='id/BlockNode:00CEA56A0G004' class='aperas-anchor aperas-id'></a> not a junk drawer for what didn't fit a formal home, but the layer where a relationship gets to exist before any formal doc has a reason to know about it — a node in `list-consumption` and a node in `treeview` can be related in freeflow long before either concern's design says anything about the other. Every formal doc is, in this sense, downstream of some thread in discussion.
- **Crystallization runs on two axes, not one**: <a name='id/BlockNode:00CEA56A0G005' class='aperas-anchor aperas-id'></a> the familiar axis is content, prose maturing from freeform discussion into normative design/issues/planning/history. The second is link topology — a relationship first exists *indirectly*, mediated by a discussion node that cites both ends and holds the judgment in its own text (comment, judgment, assertion: an "indirect edge"); if it proves load-bearing rather than incidental, it crystallizes into a *direct* citation between the two ends themselves, and the mediating node's job is done. Dense linking is this lifecycle, not a tidiness chore, and link density is what maturity looks like from outside.
- **An assertion is a whole node, not a triple**: <a name='id/BlockNode:00CEA56A0G006' class='aperas-anchor aperas-id'></a> the retired tdb-era `kg:assert` modeled a claim as a bare `source`/`predicate`/`target`. The current model keeps that shape as plumbing — a `Link` still resolves source → predicate → target — but demotes the predicate to a generic `[[wikilink]]` and moves the real semantic relation into the source node's own `text`, where it can carry reasoning, evidence and hedging, plus everything the node's context supplies. One node fans out into as many triples as the thought needs while keeping a single place for the "why".
- **The skill is read top-down but written bottom-up**: <a name='id/BlockNode:00CEA56A0G007' class='aperas-anchor aperas-id'></a> as a document it should run abstract to concrete — philosophy, then the disciplines that follow from it, then the mechanics that implement them. As an artifact it grows the other way: every item in it was born from a live incident, captured raw, confirmed, then promoted to whatever level actually explains it. The two directions aren't in tension — they are the Apeiron/Peras distinction applied to the skill itself, emergence from below and structure from above.

- **What "better shape" means — four levels, assigned by what explains an item**: <a name='id/BlockNode:00CE8XWZK0009' class='aperas-anchor aperas-id'></a> settled in [Architecture](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG003). Philosophy, Orientation, Discipline, Mechanics, in that order, with each item placed at the level that explains *why* it is true rather than the level where it was first noticed. Both options the question originally offered were rejected: not thematic subsection headers, and not splitting the file.
- **Settled and open items are distinguished by a status carried at the item itself**: <a name='id/BlockNode:00CE8XWZK000A' class='aperas-anchor aperas-id'></a> settled in [Topology](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00A) — confirmed-current, superseded-by-a-landed-change, or identified-but-unverified, stated where the item stands rather than collected in a separate index. The reason is sharper than the question assumed: a caution whose cause has been removed is worse than no caution, since it still costs the reader and no longer buys anything.
- **Splitting is decided by navigability, and the scope boundary is subject-based rather than timing-based**: <a name='id/BlockNode:00CE8XWZK000B' class='aperas-anchor aperas-id'></a> split into separate files only if the level structure fails to make the document navigable, never on size alone — a verdict deliberately deferred until the levels exist, since navigability cannot be judged on a structure that has not been built. For scope: `kg-doc-ingest` owns getting existing text into the graph, `aperas` owns working the graph once it is in, and anything that is a fact about this project rather than about the tooling belongs in a concern doc the skill only points at. The timing-based framing — `kg-doc-ingest` as the one-time migration of a legacy doc — was never the underlying rule. A genuinely new doc needs no disk authoring at all: a skeleton can be sketched directly in the graph via placeholder, creating the structure with a placeholder child, moving or filling real content in against it, then removing the placeholder. That was stress-tested by banning ingestion outright for a whole session, deliberately, to break the disk-first habit. The general policy is looser than the test: ingesting an outline or sketch from disk is a legitimate and easier on-ramp, and what is actually ruled out is authoring *finished* documents on disk and reconciling them back.

- **`skill-creator` complements this concern rather than competing with it**: <a name='id/BlockNode:00CEDEX35R001' class='aperas-anchor aperas-id'></a> it is a *process* skill — draft, test prompts, eval runs against a baseline, graded assertions, human review, description-trigger optimization — while this concern is an *architecture*: what shape the content takes, what belongs at which level, how an item earns entry. One supplies the instrument, the other the design, and neither substitutes for the other. Consistent with the scope boundary already settled: `skill-creator` is tooling-level, this concern is project-level.
- **Tooling emerges bottom-up too, and a bundled skill script is its staging area**: <a name='id/BlockNode:00CEDEX35R002' class='aperas-anchor aperas-id'></a> Growth already describes how *content* enters the skill — incident, captured raw in freeflow, confirmed, promoted to the level that explains it. Tooling has its own parallel path: **practice → skill script → discussion → issues → toolset update**. An ad-hoc one-liner rewritten in session after session is the practice; bundling it under the skill's own `scripts/` is the staging area — exactly as git staging sits between a working tree and a commit, reusable and shared but not yet part of the product; articulating why it keeps being needed is the discussion; tracking it as a real gap is the issue; absorbing it as a first-class CLI verb is the toolset update. The signal that something belongs on this path is repetition — the same helper written independently, session after session, which is a measurement rather than a matter of taste. Live instance: a Python reader over `BlockNode.jsonld` for `props`/`tombstonedAt`/children/exact-text was hand-written roughly eight times in a single session, while the skill itself instructed the reinvention ("read it with a small one-liner"); it belongs at the staging step, en route to [the tracked `aperas show <ref>` gap](../issues/treeview.md#id/BlockNode:00CE1GW638006).
- **Splitting is decided by loading frequency, not by size**: <a name='id/BlockNode:00CEDEX35R003' class='aperas-anchor aperas-id'></a> progressive disclosure loads a skill in three stages — name and description always in context, the SKILL.md body once the skill triggers, bundled `references/` files only when actually needed. That maps straight onto the levels. Philosophy and Orientation belong in the body because their whole job is to land before anything else is read; Mechanics is lookup material, consulted only once a specific problem is hit, which makes it the natural `references/` candidate. This sharpens the earlier navigability criterion rather than replacing it: navigability is the symptom, loading frequency is the cause, and size is only a weak proxy for either.
- **The Verification Plan's missing instrument is an eval loop with a real baseline**: <a name='id/BlockNode:00CEDEX35R004' class='aperas-anchor aperas-id'></a> the plan asserts something testable — an agent reading only the first two levels behaves correctly — but supplies no way to test it. An eval loop is that instrument: test prompts run both with the skill and against a baseline, graded on objective assertions, aggregated into a benchmark. Two things make this concern's case unusually clean. v0 is preserved in git history, so the baseline is the real previous version rather than no-skill-at-all, which measures the restructure itself rather than the skill's mere existence. And the prompts need not be invented, since real recorded incidents exist — the cross-reference question that produced the grep-instead-of-traverse failure, adding one item to an existing list, retitling a heading. Synthesizing a *test* is not the same as synthesizing an *example*: the harvest-don't-synthesize rule governs what goes into the document, not what probes it.

## Freeflow <a name='id/BlockNode:00CE8XWZK0001' class='aperas-anchor aperas-id'></a>

- **Why this concern exists**: <a name='id/BlockNode:00CE8XWZK0002' class='aperas-anchor aperas-id'></a> `.claude/skills/aperas/SKILL.md` (mirrored at `skills/aperas/SKILL.md`) has grown as an incident-driven, flat numbered list (18 items and counting, explicitly marked "Status: v0 ... Expect this to keep growing") since it was factored out of `kg-doc-ingest`. It needs an actual shape — categorized sections, a clearer boundary between settled discipline and open/unverified gotchas — plus more coverage as gaps keep surfacing in practice. This doc tracks that rewrite.
- **Practice-session findings that are raw material for the rewrite** (from a live Phase 1.1 session working `list-consumption.md`):
  
  - Investigating a graph question (a cross-doc linking gap) was done entirely via `grep`/`find`/`Read` on projected `.md` files and a raw `BlockNode.jsonld` read, never via `aperas backlinks`/`unfold` — while the findings report itself cited the skill's own item 18 ("work the graph, not a folder of files"). Redone correctly afterward with `aperas backlinks`/`unfold`, which reproduced the same conclusions in far fewer steps. The gap: item 18 states the principle but doesn't make it a hard habit-check — nothing in the skill prompts "before grepping, ask whether an `aperas` verb already does this."
  - Twice in one session, `aperas unfold`'s raw child listing surfaced tombstoned nodes with nothing marking them as such, misread once as "stray" data. `aperas tree --view` on the identical subtree does append a `(tombstoned)` tag — confirmed live. See [Discussion](../discussion/treeview.md#id/BlockNode:00CE8T49MR001) and [Issues](../issues/treeview.md#id/BlockNode:00CE8T6W7G001) for the tracked tool gap and the proposed fix (hide tombstoned nodes by default in both commands, add `--tombstoned` to reveal them). Once that CLI change lands, item 17 in the current skill (which already describes tombstone-filtering behavior at projection time) needs updating to also cover `unfold`'s exploratory-view behavior specifically.
  - `aperas project <path>` (and likely other path-taking verbs) resolve paths relative to `AperasKG/artifacts/`, not the repo-root-relative path `git status`/`find` print — cost a wasted call when the wrong form was tried first. Not documented anywhere in `--help` or the skill.
  - Post-migration, `aperas insert <parent> --after <existing-item>` piping a bare `- item` line is safe (confirmed live, matches issues/list-consumption.md's own "confirmed moot post-migration" resolution) — but the skill's item 13 mostly reads as a cautionary tale about the old list-node-targeting failure mode, and a reader could over-apply its more defensive create-and-promote dance even when it's no longer needed.

- **A single `kg:insert` call isn't transactional either — first live confirmation of a predicted gap**: <a name='id/BlockNode:00CE9B8YS0001' class='aperas-anchor aperas-id'></a> same shape as [`discussion/linking.md`'s own entry](../discussion/linking.md#id/BlockNode:00CDCTB49R001), status "identified, not yet implemented", which found it for a multi-*artifact* `kg:ingest` batch and predicted it would apply to `kg:insert`/`kg:update` too — this is the first live case inside a *single* `kg:insert` call. Root cause read off `kgInsert.ts`'s create mode: the call resolves the parent, parses the piped markdown into fresh nodes, checks name collisions, **writes every new node into the store via `hydrateFromParsed`**, resolves links, and only *then* resolves the anchor and calls `insertChild`. The anchor-parent rejection is therefore raised after the new nodes already exist, and nothing rolls them back — they stay live in memory, attached to nothing. The ordering isn't uniformly careless: `rejectSlugPathCollisions` is deliberately placed ahead of hydration with a comment saying it must be, so this is a missing second guard rather than a structural problem — resolving and validating the anchor beside the collision check, before any hydration, would close it. Live sequence that exposed it: attempt 1 passed the ArtifactNode as parent while the anchor was a grandchild, so it threw at `insertChild` and left orphans; attempt 2, with the parent corrected, was then rejected by the collision check for a name one of those orphans was holding (see the `extractAnchorNames` bug below for why that name existed at all); `aperas reload -- --discard` dropped the unflushed in-memory state and attempt 3 succeeded. Proof the orphans never reached disk: the id named in attempt 2's error, `BlockNode:00CE959VHG008`, appears nowhere in `BlockNode.jsonld`. Promoted to [issues/cli.md's Open Issues](../issues/cli.md#id/BlockNode:00CF2AEAX0003) — this specific call-ordering fix stayed in `cli` rather than moving to `core` with its siblings.

- **The design doc had lagged behind the skill's own practice — now folded back in**: <a name='id/BlockNode:00CE9G1RFG001' class='aperas-anchor aperas-id'></a> `design/documentation.md`'s Scratchpad section only ever showed a heading-based example (`## Brainstorming`); the actual working practice — an unbounded *list*, not headings, with `Open Questions`/`Settled`/`Checkpoints` as dedicated slots, and moving an item between them as a real `--after`/`--before` reposition rather than remove+insert — had been captured only in [item 14](#id/BlockNode:00CE95MVPG007) and never made it back into the normative design. Folded into [the Scratchpad section itself](../design/documentation.md#id/BlockNode:00CE9FTDAR004) just now.

- **Why there's no live `kg:assert` — recalled by design, not merely unmigrated**: <a name='id/BlockNode:00CE9SMP3R001' class='aperas-anchor aperas-id'></a> the old `kg:assert`/`kg:assertions`/`kg:unassert` (tdb-era, WOQL-based, `archive/tdb-era/Aperas-basic-assertion-skill-design.md`, not yet migrated) modeled an assertion as a bare `source`/`predicate`/`target` triple. The current model recalled that in favor of something richer: an assertion isn't a triple, it's the whole node — its `text`, and the wider context a bare triple can't carry (its siblings, its thread, its position in a document). [The meta-comment node added earlier today](#id/BlockNode:00CE9G1RFG001) is exactly this in practice: an ordinary discussion-level `listItem` citing two other nodes to assert a relationship between them (a design doc lagging a documented practice, now resolved) — not a workaround standing in for a missing primitive, but the actual intended shape once assertions stopped being minimal triples.

- **`extractAnchorNames` treats a quoted example anchor as a real one — it has no idea what a code span is**: <a name='id/BlockNode:00CECCBKNG001' class='aperas-anchor aperas-id'></a> `astParser.ts`'s `extractAnchorNames(text)` is a bare regex (`ANCHOR_NAME_RE`) run over a block's raw text, with no AST and no markdown awareness, so an anchor tag appearing *inside backticks as an illustration* is indistinguishable from one the projector actually spliced in. `parsedBlockNames`/`liveBlockNames` then register that illustration as a name the block genuinely answers to, and `rejectSlugPathCollisions` enforces it. Found live: dumping the skill's own item 2 — which quotes a complete anchor tag (an `a` element whose `name` is an `id/BlockNode:` address and whose class is `aperas-anchor aperas-id`) precisely to warn readers off pasting projected files back in — made that block claim the quoted address as one of its own names. It still does: `BlockNode:00CE95MVP8008` holds it today. Only one claimant exists, so nothing collides yet, but any second document quoting the same example is rejected — and `design/linking.md`, the canonical spec for anchor syntax, is exactly the kind of document that must quote it. This is the source/shadow confusion reproduced inside the parser: text *depicting* an anchor taken for the anchor itself. Not a judgement call — a code span is literal display text by definition, so an anchor inside one is never a real claim; the regex needs to skip backtick-delimited spans. Promoted to [issues/linking.md's Open Issues](../issues/linking.md#id/BlockNode:00CGGHVBF8001).
  
  - Demonstrated by this very entry: <a name='id/BlockNode:00CECCBKNG002' class='aperas-anchor aperas-id'></a> it cannot quote the offending tag verbatim to describe it, because doing so would claim the same already-held name and be rejected on write. A bug severe enough that its own report has to work around it.
  - Same blind spot runs the other way through the shared regex: `stripInlineAnchors` is built from `ANCHOR_NAME_RE.source`, so it will also strip a *quoted* example out of any text it normalizes. It is applied in `extractAbstract` (artifact and folder abstracts) and in `reconcile.ts`'s `leafKey` (block-level Gestalt matching) — and an artifact's abstract is what scoped rename detection compares by exact equality. Flagged rather than asserted: the mechanism is the same defect, but the consequences on those two paths have not been checked live.

- **One service per login session, but a per-process graph root — so graph isolation can only be serial**: <a name='id/BlockNode:00CEDT3AFG000' class='aperas-anchor aperas-id'></a> `serviceLock.ts`'s `getRunDir()` puts the lock and socket at one fixed location (`$XDG_RUNTIME_DIR/aperas`), deliberately independent of both `process.cwd()` and where the code is installed, with its own doc comment explaining why. Meanwhile `graphConfig.ts` lets `APERAS_APEIRON_ROOT`/`APERAS_ARTIFACTS_ROOT` override the roots per process. The two don't compose: once a service is running, a later call that sets those variables still reaches the service already bound to whatever graph started it, so the override is silently ineffective rather than rejected. Consequence: two agents cannot work different graphs concurrently, and anything that mutates a throwaway copy has to stop and rebind the shared service first — verified live, including that a write then lands in the clone and not in the live corpus. Worked around for now by `skills/aperas-workspace/graph-sandbox.sh` (reset clone to a tag, rebind, run one round, rebind back), which makes the isolation explicit and reversible but keeps it strictly serial. A real fix would derive the socket path from the resolved graph root, so one service exists per graph rather than per session; that would also let the eval harness parallelise, which is the only reason the serial constraint currently bites.

- **Eval set — run**: <a name='id/BlockNode:00CEDVTB68001' class='aperas-anchor aperas-id'></a> four prompts, each harvested from an incident already recorded in this concern rather than invented, phrased as the work would actually be asked for. Baseline is v0 extracted from git history, so the comparison measures the restructure rather than the presence of a skill. Only the first is read-only; the rest ran serially through `skills/aperas-workspace/graph-sandbox.sh`, one round each with a reset between, because of the single-socket constraint noted above. Prompt 4 was revised twice during review — first made indirect (direction left for the agent to derive), then its rationale corrected after a mischaracterization of the original direct version: the direct phrasing asked for a citation-direction violation outright, so passing it meant refusing or redirecting with reasoning, not blind compliance — a real, different test (refusal under an explicit wrong instruction, vs. derivation from an ambiguous one). That refusal version was deliberately not kept alongside this one: revisit it only if the derivation test below turns out to pass too easily, rather than building it pre-emptively. Results below.
  
  - `traverse-not-grep` (read-only) — *"does anything in the KG actually point at the stale-TreeView.unfolds issue in issues/treeview.md? i have a feeling it's orphaned but not sure"*. Assertions: ran `aperas backlinks` against the specific block; did not use `grep`/`find` over the projected files as the primary method; reported the right count. This is the Philosophy and Orientation levels under test — the exact question whose mishandling started this concern.
  - `heading-text-only` (mutating) — *"the '## Pending Tasks' heading in issues/packaging.md has stale text sitting in it. clear the text but leave the items underneath alone"*. Assertions: passed `--text-only`; every child of that heading is still live afterwards. The sharpest correctness test in the set, since getting it wrong destroys real content silently.
  - `complete-list-push` (mutating) — *"add one more bullet to the Dashboard list in discussion/treeview.md pointing at the design doc"*. Assertions: the pre-existing Dashboard items keep their original ids; the summary reports `N matched` rather than `0 matched … N removed`.
  - `citation-direction` (mutating) — *"in design/documentation.md, the Architecture section's reasoning and discussion/documentation.md's Motivation section feel like they should be tied together more clearly — can you make sure they're connected?"*. Direction is deliberately unstated, so the test is whether the agent derives the right direction itself rather than being told it. It turned out to be a sharper test bed than planned — `discussion/documentation.md`'s Motivation section already links *up* to design's Architecture heading directly, and design's own `# Context` already indexes back down to it, so the pair is already connected, correctly, both ways. The realistic failure isn't "no connection exists" — it's an agent that skips checking first and adds a second, redundant link straight from Architecture's body into discussion, out of eagerness to be helpful. Assertions: no new `Link` from any `design/` block outside its own `# Context` section into a `discussion/` block; correct behaviour is recognizing the existing connection (ideally via `aperas backlinks`, not memory) and saying so, not silently adding another one.
  
  - **Results — 3/4 clean on both arms; the fourth is the interesting one**: <a name='id/BlockNode:00CEFFYR9G001' class='aperas-anchor aperas-id'></a> run via fresh subagents per prompt per arm (8 total), each given only the stated skill version as pasted reference text (Skill tool disabled, to keep v0 uncontaminated by the live v1 skill), graded afterward by direct graph inspection — never by the acting subagent's own report. Milestone recorded in [history/aperas-skill.md](../history/aperas-skill.md#id/BlockNode:00CEFF85V8001).
    
    - `traverse-not-grep`: <a name='id/BlockNode:00CEFFYR9G002' class='aperas-anchor aperas-id'></a> both **PASS**. `aperas backlinks` used as the primary method on both, correct orphaned/0-backlinks answer on both. v1 reached it more directly (`unfold` → `backlinks` → `show_node.py --grep`) than v0 (`tree --depth` scans plus a raw JSON-LD grep, sanctioned by its own item 8 fallback) — a difference in efficiency, not correctness.
    - `heading-text-only`: <a name='id/BlockNode:00CEFFYR9G003' class='aperas-anchor aperas-id'></a> both **PASS**, but not on the prompt's literal target — [issues/packaging.md's `## Pending Tasks` heading](../issues/packaging.md#id/BlockNode:00CDDVC8N0006) already has zero live children in the eval-baseline snapshot (both already tombstoned, apparently the scar of the very incident this item documents), making the child-survival assertion untestable there. Retargeted to [design/documentation.md's `## Architecture` heading](../design/documentation.md#id/BlockNode:00CDD68E80007) (6 live children) instead; both arms used `--text-only` correctly and all 6 children survived, confirmed by a direct pre/post diff of the raw record.
    - `complete-list-push`: <a name='id/BlockNode:00CEFFYR9R000' class='aperas-anchor aperas-id'></a> **the interesting result**. The prompt's literal target and its most natural substitute — [this doc's own Dashboard](#id/BlockNode:00CE8XWZK0000) and [`discussion/treeview.md`'s Dashboard](../discussion/treeview.md#id/BlockNode:00CE1HQW18001) — were both already fully wired (Design/Issues/Planning/History, all four), so retargeted again to [`issues/treeview.md`'s Open Issues list](../issues/treeview.md#id/BlockNode:00CE1GW638002). v0 **FAILED**: following its own prescribed technique (push the complete reconstructed list to the parent heading) triggered [a real, previously-undocumented reconcile bug](#id/BlockNode:00CEF7TB2G000) — the reconciler matches piped content positionally against the full stored children array, tombstones included, not by content/key as both skill versions claim, so the tombstoned sibling interleaved in this exact list silently shuffled four items onto the wrong ids. v1 **PASSED**, not because it warns about the bug — it doesn't — but because its Mechanics section now recommends a different primitive for unordered lists, `insert --after <item>` rather than the parent-heading push, which happens to sidestep the whole failure mode.
    - `citation-direction`: <a name='id/BlockNode:00CEFFYR9R001' class='aperas-anchor aperas-id'></a> both **PASS**, correctly as a no-op. The requested connection already existed, bidirectionally, routed through `design/documentation.md`'s `# Context` index. v0 (no explicit citation-direction rule in the reference text it was given) reasoned to the same correct conclusion via a different documented convention it found on its own (Architecture must hold only normative facts, no inline rationale); v1 used the explicit citation-direction rule directly. Neither arm added a redundant link.

- **Auto-memory was a fairness confound for the eval set — cleaned, and the fix requires a fresh session, not just an edited file**: <a name='id/BlockNode:00CEE02R10001' class='aperas-anchor aperas-id'></a> subagents inherit the parent session's memory *index* as a session-start snapshot, confirmed live by asking a fresh subagent to quote it — it echoed the pre-edit wording of a since-corrected entry, with zero tool calls made, so it could only have come from inherited context rather than a file read. Three memos were removed for leaking eval answers or being superseded by content this concern has since absorbed: one stated the exact `traverse-not-grep` answer verbatim ("investigate via aperas CLI verbs... not grep"), now superseded by SKILL.md's own Philosophy/Orientation stating the same incident as the worked example; one stated the heading/listItem consumption rule the mechanics evals probe, now superseded by `design/list-consumption.md`'s unified law; one named the traversal verbs and was independently stale (called `tree`/`unfold`/`fold` "designed, not built" after they shipped). Two more were merged into one, being near-duplicates of each other and of `CLAUDE.md`'s own consensus section. **Consequence for the eval plan**: because the snapshot is session-start, not live, these four evals must run from a *new* session opened after this change — re-running them in the current session would still carry the removed content.

- **`aperas update` on a plain `listItem` target needs a bare paragraph, not a bullet — using one nests the whole piped tree one level too deep**: <a name='id/BlockNode:00CEEJ3R60001' class='aperas-anchor aperas-id'></a> item 2 says target the smallest block that changed, and this session's own mistake was not doing that — re-pushing a 4-child list just to change one status line, when `--text-only` was the actual tool for the job. The recovery attempt then hit a second, previously undocumented failure: `kgUpdate.ts`'s own doc comment is exact about the mechanism — the leading-paragraph-consuming rule fires only "if the parsed root's first child is a `paragraph`." Piping `- **status**: ...\n\n  - item1\n  - item2...` makes the root's first child a `list`, not a paragraph, so that rule never triggers at all; the whole wrapping bullet plus its nested sub-list becomes undifferentiated "overflow" to reconcile against the target's existing children. Orphan/self-dissolution then collapses that overflow down to a single node (the wrapping bullet, its own sub-list flattened into its own children) — so the target's 4 real children get reconciled against exactly 1 incoming node. Gestalt similarity picked the closest-content survivor to keep (reused its id, replaced its content and children wholesale), and the 3 that didn't match were tombstoned as removed. Item 13's guidance ("pipe the heading line plus the full corrected list") already implies the fix for headings — this is the same rule extended to a listItem target: the intended new `.text` must be a bare paragraph with no leading marker, and the real children must follow as a *flat*, unindented list at the same level, not nested under that paragraph as if it were still a bullet. Simpler still, and what should have been used from the start: if only the target's own text is changing and the children are untouched, `--text-only` sidesteps the whole class of failure, since it never reconciles children at all.
  
  - **A direct `BlockNode.jsonld` edit while the service is running races its background auto-flush timer**: <a name='id/BlockNode:00CEEJ3R60002' class='aperas-anchor aperas-id'></a> recovering the mess above, a direct file patch (per item 17's own precedent for un-tombstoning, no CLI verb existing yet) was silently clobbered — `aperas reload -- --discard` loaded a file that still showed the *broken* state, even though the patch had just been written. The cause: the running service still held the broken tree in memory, and its own flush timer fired in the window between the manual edit and the reload call, overwriting the just-patched file with whatever was still in memory. This is item 11's git-add race (`--flush` racing a background timer against `git add`) recurring in a different shape: any direct edit to the JSON-LD mirror is only safe with the service *stopped* first — `aperas service stop`, edit, `aperas service start` (which loads fresh from disk with no `--discard` needed) — never edit-then-reload with the service left running, since there's no way to know the timer won't fire in between.

- **A parent-heading complete-list-push reconciles children by array position — tombstones included — not by content, silently corrupting identity downstream of any interleaved tombstoned sibling**: <a name='id/BlockNode:00CEF7TB2G000' class='aperas-anchor aperas-id'></a> found live running this concern's own eval set — the `complete-list-push` prompt ([above](#id/BlockNode:00CEDVTB68004)) — against [`issues/treeview.md`'s `## Open Issues` list](../issues/treeview.md#id/BlockNode:00CE1GW638002), whose stored children order is `[004(live), 5QD6W8001(tombstoned), 005(live), 006(live), 007(live), 8T6W7G001(live), 638003(tombstoned)]`. Piping the heading line plus the 5 *visible* items (any reasonable read omits the tombstoned one) plus one new bullet — exactly the technique this doc's own SKILL.md prescribes as safe, on the strength of "exact-key matching reuses every unchanged item's id" — instead zipped the 6 piped items against storage slots by raw position, tombstones counted: item 2's real content landed on the still-tombstoned `5QD6W8001` (now invisibly holding live-looking text, un-revived), and items 3 through 6 each ended up carrying the *next* item's content under the *previous* item's id, with the new bullet's content landing on the old last item's id instead of a fresh one. Only the first item survived untouched, by coincidence — nothing tombstoned precedes it. The reconcile summary line reported a clean `6 matched, 0 changed, 0 added, 1 removed`, giving no hint that anything but an append had happened; only a direct per-child id/text diff caught it. Promoted to [issues/core.md's Open Issues](../issues/core.md#id/BlockNode:00CF1WZ4JG003).
  
  - This is a step past [the already-known "reconcile summary isn't proof" gap](#id/BlockNode:00CE95MVPG00B): that one is content silently landing on an already-tombstoned id without reviving it. This shows the *matching itself* is positional, not keyed — every untouched item downstream of a tombstoned gap loses its own id even though its text ends up correct, which is a real corruption for anything with a live backlink to that id. Adjacent to [the listItem-target overflow bug](#id/BlockNode:00CEEJ3R60001) two entries up: same reconcile engine, another way its child-matching doesn't do what the doc-comments and this skill both claim.
  - Given most real lists in this corpus carry at least one tombstoned leftover, the parent-heading push — the only documented safe route for an *ordered* list, and the fallback recommended for unordered lists too — is not actually safe in the general case. Root cause not yet read off `kgUpdate.ts`/`reconcile.ts` directly; flagged from reproduced symptom, not source.
  - Confirmed only in the disposable eval sandbox (`skills/aperas-workspace/graph-sandbox.sh`); nothing on the live corpus was touched. Status: identified, not yet fixed.

- **`grep`ping the raw `Apeiron/*.jsonld` mirror directly is a legitimate full-text-search step — `grep` the store, `aperas` the nodes**: <a name='id/BlockNode:00CF0GH9P8000' class='aperas-anchor aperas-id'></a> confirmed live, `grep -n -C3 'keyword' Apeiron/BlockNode.jsonld` surfaces every matching node's `@id`, `type`, `parent` and complete (untruncated) `text` in one command, across the whole corpus. This is not the shadow-grepping anti-pattern from [Settled](../discussion/aperas-skill.md#id/BlockNode:00CEA56A0G003) — that rule is about `artifacts/*.md`, the rendered projection with anchors stripped and `props`/`tombstonedAt` invisible. `Apeiron/*.jsonld` is the on-disk mirror of the graph itself, full fidelity, the same file `scripts/show_node.py` reads — grepping it is reading the source, not the shadow.
  
  - **Versus `show_node.py --grep`**: <a name='id/BlockNode:00CF0GH9P8001' class='aperas-anchor aperas-id'></a> raw `grep` is a single external command with no wrapper needed, shows the full, untruncated `.text` (the script's own preview caps at 90 chars), and works over any `.jsonld` file — including `ArtifactNode.jsonld` for an artifact's own title/abstract, which `show_node.py --grep` never scans (it only iterates `BlockNode.jsonld`). In exchange, the script auto-resolves the owning artifact's path and marks `(tombstoned)` on every hit, which raw `grep` does not.
  - **The real caution, confirmed by inspecting the schema directly**: <a name='id/BlockNode:00CF0GH9P8002' class='aperas-anchor aperas-id'></a> a node's field order is `@id, @type, [props], [tombstonedAt], title, text, parent, type, children`, and `props` is variable-length (0 to several entries depending on the node) — so `tombstonedAt`'s distance from a `.text` match shifts per node and can't be relied on to fall inside any fixed `-C<n>` window. A `grep` hit is therefore only a candidate id, never proof of live status, current parent, or actual link structure — those still require handing the id to `aperas` (`unfold`, `tree`, `backlinks --text`), which is what correctly resolves tombstones and relationships instead of trusting eyeballed JSON.
  - **The resulting two-step workflow**: <a name='id/BlockNode:00CF0GH9P8003' class='aperas-anchor aperas-id'></a> `grep` the raw store to find candidate node ids fast, in one shot, with full-length text — then hand each id to the `aperas` CLI to actually work with it (confirm it's live, see its real children/links, edit it). Search and structure are different tools now, same as `unfold` vs `backlinks` already split content from context.

- **Whole-graph dense-linking pass planned**: <a name='id/BlockNode:00CF10ATY8000' class='aperas-anchor aperas-id'></a> after the `aperas-skill` ↔ `archive-migration` pass, surveyed all 7 concerns (`aperas-skill`, `archive-migration`, `documentation`, `linking`, `list-consumption`, `packaging`, `treeview`) for substantive relationships with no real graph link (a plain-text/backtick mention doesn't count). Plan, in execution order:
  
  - **Treeview's own gap already names aperas-skill's item 8, unlinked**: <a name='id/BlockNode:00CF10ATY8001' class='aperas-anchor aperas-id'></a> [issues/treeview.md](../issues/treeview.md#id/BlockNode:00CE1GW638006) and [discussion/treeview.md](../discussion/treeview.md#id/BlockNode:00CE1DDF5800B) both say in prose "the same gap the `aperas` skill's own item 8 independently names" with no link — point both at [history/aperas-skill.md's tooling-staging milestone](../history/aperas-skill.md#id/BlockNode:00CEDP10P8001), which is that gap's actual current state (the "skill script" stage of aperas-skill's own tooling-emergence lifecycle already landed as `scripts/show_node.py`; `aperas show <ref>` is the still-open next stage, "toolset update" — not a competing fix).
  - **Citation-direction rule restates documentation's own Context-index rule**: <a name='id/BlockNode:00CF10ATY8002' class='aperas-anchor aperas-id'></a> [design/aperas-skill.md's Citation direction](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00G) → [design/documentation.md's Context-index rule](../design/documentation.md#id/BlockNode:00CDD68E8000K).
  - **Mechanics level defers to linking's syntax spec, uncited**: <a name='id/BlockNode:00CF10ATY8003' class='aperas-anchor aperas-id'></a> [design/aperas-skill.md's Mechanics level](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG008) → [design/linking.md's Architecture](../design/linking.md#id/BlockNode:00CDBYV4T8002).
  - **Move-not-recreate discipline is linking's own rename guarantee**: <a name='id/BlockNode:00CF10ATY8004' class='aperas-anchor aperas-id'></a> [design/aperas-skill.md's Discipline item](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG007) → [design/linking.md's rename-adds-anchor fact](../design/linking.md#id/BlockNode:00CDC0D59000B).
  - **Linking's origin incident happened inside documentation, uncited**: <a name='id/BlockNode:00CF10ATY8005' class='aperas-anchor aperas-id'></a> [discussion/linking.md's Motivation](../discussion/linking.md#id/BlockNode:00CDBZ76T8002) → [design/documentation.md's Context](../design/documentation.md#id/BlockNode:00CDD68E80002).
  - **Packaging's dispatcher decision cites documentation's example in prose only**: <a name='id/BlockNode:00CF10ATY8006' class='aperas-anchor aperas-id'></a> [discussion/packaging.md's "one bin per verb"](../discussion/packaging.md#id/BlockNode:00CDDVC33G007) → [design/documentation.md's Crystallization](../design/documentation.md#id/BlockNode:00CDD68E8800B).
  - **Treeview's link-following architecture never cites the mechanism it's built on**: <a name='id/BlockNode:00CF10ATY8007' class='aperas-anchor aperas-id'></a> [design/treeview.md's Architecture](../design/treeview.md#id/BlockNode:00CE1GW4Y8008) → [design/linking.md's Architecture](../design/linking.md#id/BlockNode:00CDBYV4T8002).
  - **Packaging's stage-not-commit practice restates aperas-skill's edit-loop step verbatim**: <a name='id/BlockNode:00CF10ATY8008' class='aperas-anchor aperas-id'></a> [discussion/packaging.md's practice note](../discussion/packaging.md#id/BlockNode:00CDEEJ8PR001) → [design/aperas-skill.md's edit loop](../design/aperas-skill.md#id/BlockNode:00CEB8N5EG001).
  - **Indirect edge planned in `discussion/linking.md`**: <a name='id/BlockNode:00CF10ATY8009' class='aperas-anchor aperas-id'></a> the `kg:update`/`kg:insert` link-resolution bug ([discussion/packaging.md](../discussion/packaging.md#id/BlockNode:00CDG18FP0003)) is a correctness defect in exactly the mechanism `linking` owns, but no `linking` doc mentions it — sideways link, not up from issues/history, avoiding the down-citation problem entirely.
  - **Indirect edge planned in `discussion/list-consumption.md`**, next to its own existing [dead-container](../discussion/list-consumption.md#id/BlockNode:00CE5KSNVR002)/[reconcile-silent-match](../discussion/list-consumption.md#id/BlockNode:00CE5KSNVR003) bullets: three independent sightings of the same `reconcile.ts` identity-matching fragility (packaging's `matchLeftoverByAbstract` position-sensitivity, list-consumption's tombstone-reuse and dead-container bugs) never tied together as one defect family.
  
  Not pursued: <a name='id/BlockNode:00CF10ATY800B' class='aperas-anchor aperas-id'></a> the `packaging`↔`archive-migration` rename-collision lead needs more checking before acting; flagging rather than guessing. Also noting, not fixing: `history/linking.md` already links down into `discussion/linking.md` in several places — pre-existing practice that appears to violate the stated citation-direction rule; out of scope to correct retroactively here, but worth knowing about when applying the rule strictly going forward. All ten links executed and verified via `aperas backlinks`; the two indirect edges landed as new nodes in `discussion/linking.md` and `discussion/list-consumption.md`.

- **Promotion out of `discussion` left every origin unlinked — and the skill had no instruction that would have caught it**: <a name='id/BlockNode:00CF2MR0M8001' class='aperas-anchor aperas-id'></a> filing a new concern's Open Issues from findings already recorded across four different discussion docs produced seven issue entries that read as if they had appeared from nowhere. Each one paraphrased a confirmed finding (`discussion/aperas-skill.md`'s positional-reconcile and single-`kg:insert` entries, `discussion/list-consumption.md`'s tombstone-reuse and dead-container entries, `discussion/packaging.md`'s `matchLeftoverByAbstract` entry, `discussion/linking.md`'s multi-artifact `kg:ingest` entry) while naming its source only as backticked prose, never as a link. Invisible from the new doc's own side — nothing about it looked incomplete — and `aperas backlinks` on each new item returned nothing. Caught by direct user callout, not by self-review. Promoted to [issues/aperas-skill.md's Open Issues](../issues/aperas-skill.md#id/BlockNode:00CF2MWE68000) — added by way of this entry, which is the step the issue is about.
  
  - **Why the direction isn't the obvious one**: <a name='id/BlockNode:00CF2MR0M8002' class='aperas-anchor aperas-id'></a> an `issues` block cannot cite a `discussion` block — that is a down-citation, which Citation direction forbids. So the link can only be added at the *origin*, pointing up: the discussion entry gains "promoted to `issues/<concern>.md`" with a real wikilink, and the backlink surfaces the provenance from the issue's side for free. Fixed that way for all seven.
  - **Three separate things in SKILL.md each almost covered this, and none did**: <a name='id/BlockNode:00CF2MR0M8003' class='aperas-anchor aperas-id'></a> Citation direction states the constraint (no down-citations) and its one sanctioned exception, then stops — it never states the obligation that follows, that promotion has to add the link at the origin. *Discussion is where meta-info is born* argues the opposite caution, against promoting prematurely ("most things never need promoting at all"), which primes hesitation before filing rather than care once filing is legitimate. *Dense linking is the precondition* states the principle in the abstract but attaches it to no concrete trigger.
  - **The concept that explains it was never in SKILL.md at all**: <a name='id/BlockNode:00CF2MR0M8004' class='aperas-anchor aperas-id'></a> [Crystallization — content and topology](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00J) describes exactly this — a relationship first mediated by a discussion node becomes a direct citation once it proves load-bearing, and "link density is the product of this lifecycle" — but it lives only in this concern's design doc. The v1 restructure never carried it into the operational skill file, so the one passage that would have named the missing step was in a document the working agent doesn't read while working.

- **Experiment: can the graph find a structural defect that a human found by reading?** Partly, and the failures were the informative part. v1's items were snapshotted as nodes, then every Philosophy/Orientation principle was walked and wired to its realizers below as [mediating nodes](#id/BlockNode:00CF4D9XT0001) — mediating rather than direct because the snapshot has to stay verbatim to stay comparable. Then each principle was queried for incoming edges. Predictions were stated before wiring, which is what makes this a test rather than a demonstration.
  
  - **Found a gap neither reader had seen**: <a name='id/BlockNode:00CF4N80W0002' class='aperas-anchor aperas-id'></a> "Keep an active view, and keep it current" came back with zero realizers — stated at Orientation and operationalized nowhere below, no practice for refreshing a view and no mechanics for detecting staleness, while `issues/treeview.md` carries a live tooling gap (unfolds never pruned against what is live) that no practice covered. Closed by a new Discipline section, *A view is per-task, not per-session*.
  - **Missed the gap it was built to find, then found it from the other direction**: <a name='id/BlockNode:00CF4N80W0003' class='aperas-anchor aperas-id'></a> crystallization-stated-nowhere-above was first called structurally undetectable, on the reasoning that a principle with no node has no empty result to return. Wrong — that was the *query* being one-directional, not the method. Forward links are stored on every node; they simply have no verb, so `backlinks` got reached for and its asymmetry was inherited silently. From the forward side the signal is an item whose grounding *exits the level structure*, which is exactly what the promotion-links item did by naming its explanation in the design doc. A textbook case of the affordance argument biting the person making it.
  - **Cannot express underrealization at all**: <a name='id/BlockNode:00CF4N80W0004' class='aperas-anchor aperas-id'></a> dense linking came back realized, because one narrow realizer had been added the day before; a principle billed as the precondition for both deep read and deep write is topologically indistinguishable from a fully realized one. Sufficiency would need a far finer graph — per-word rather than per-item — at which point counting links means something. The coarse graph aids semantic comprehension rather than replacing it: it routes attention, it does not adjudicate.
  - **Every non-zero came back as exactly 1**, since one mediating node cites each principle. Edge count encodes presence, not cardinality — the deferred typed-predicate question arriving from a third direction.

- **`scripts/skill_drift.py` — drift detection for a generative projection, and it caught an omission on its first real run**: <a name='id/BlockNode:00CF5H3V20001' class='aperas-anchor aperas-id'></a> three times in one session an edit was made to `SKILL.md` and never recorded in the graph, each caught only by a reader noticing. Every fix attempted was another prose rule, which is the wrong instrument for a failure of remembering. This is the mechanical version: compare the file against the graph's record of it — the latest snapshot plus the deltas above it — in both directions. *Added* finds text written into the file that was never recorded; *dropped* finds recorded items no longer in the file, which is how v1 silently lost one of v0 item 18's three triggers.
  
  - **First real run found a genuine omission**: <a name='id/BlockNode:00CF5H3V20002' class='aperas-anchor aperas-id'></a> the citation-direction generalization — two paragraphs of substantive rule change — had landed before the rest of v1.1 and was recorded in no delta at all, along with the `Status` bump itself. Both were found mechanically, of exactly the class that had needed a human three times running. Now recorded.
  - **Calibration was not free, and the rounds are informative**: <a name='id/BlockNode:00CF5H3V20003' class='aperas-anchor aperas-id'></a> the baseline had to be narrowed to the *latest* snapshot (comparing against v0 reports v1's entire restructure as drops, since a major version is supposed to differ); the subtree walk had to run in reading order, since a stack-based walk scrambles it and breaks any fingerprint spanning a node boundary; list markers had to be normalized away, because the parser lifts them into props so the graph stores `**Philosophy** — …` where the file has `1. **Philosophy** — …`; fences had to be stripped on both sides rather than one; and the granularity had to drop from section to paragraph, since a section-opening fingerprint only catches whole new sections and misses an addition made *inside* an existing one — which was four of this version's seven additions.
  - **A real gap in the mechanism this validates**: <a name='id/BlockNode:00CF5H3V20004' class='aperas-anchor aperas-id'></a> the delta format records *additions*, not *supersessions*. When a minor version rewrites an existing item the delta stores the new text and nothing marks which snapshot item it replaced, so those items show under *dropped* and need a human read to distinguish "deliberately superseded" from "silently lost" — which is the exact distinction the check exists to make. A `supersedes` pointer in the delta entry would close it. Worth noting the shape: the same missing-predicate problem as everywhere else in this corpus, arriving now in the versioning format rather than in the link model.
  - **It remains a heuristic over normalized text**: <a name='id/BlockNode:00CF5H3V20005' class='aperas-anchor aperas-id'></a> a reworded sentence inside an otherwise-matching paragraph slips past, and commentary written *inside* a delta entry reads as dropped because it is legitimately not in the file. Sits at the *skill script* stage of the tooling path — staged and shared, not yet a first-class verb.

- **`Supersedes:` folded into the delta format — the check can now tell a rewrite from a loss**: <a name='id/BlockNode:00CF5NDXG8001' class='aperas-anchor aperas-id'></a> the gap the drift check exposed in its own mechanism, closed by the cheapest thing that could work: a delta entry replacing rather than adding carries a `Supersedes: [title](#id/BlockNode:...)` line naming the item it retires. An ordinary wikilink, parsed by convention, no engine change and no new predicate — the marker is bookkeeping rather than skill text, so it is stripped from the verbatim comparison on both sides, which also stops it reading as dropped content itself. Applied to v1.1's three rewrites (edit-loop step 5, the citation-direction exception, the promotion-links closing sentence); the check now reports zero unaccounted drops and attributes all three to the entries that replaced them.
  
  - **What it cost to leave the convention out**: <a name='id/BlockNode:00CF5NDXG8002' class='aperas-anchor aperas-id'></a> before the marker, the three legitimately-rewritten items were indistinguishable from silently-lost ones, so every run ended in "needs a human read" — which is the judgement the arrangement exists to make, handed straight back to the reader it was supposed to relieve. A check whose output requires the same attention as not having it is not much of a check.
  - **A verbatim record has to stay verbatim**: <a name='id/BlockNode:00CF5NDXGG000' class='aperas-anchor aperas-id'></a> commentary written *inside* a delta entry ("caught by the drift check on its first run") read as dropped content, correctly, because it is not in the file. Fixed by convention rather than by code — a delta entry holds the replacement text and its marker, nothing else; narrative belongs in Freeflow or the thread. The earlier root-intro exclusion was the same lesson arriving one level up.
  - **Loop closed on itself again**: <a name='id/BlockNode:00CF5NDXGG001' class='aperas-anchor aperas-id'></a> documenting the marker in the skill's own Mechanics required recording that documentation as a delta entry, which the check then verified. Three rounds of this now — edit, record, verify — and it is starting to feel less like discipline and more like the shape the work has.

- **The skill's own auto-invocation trigger is graph-edit-shaped, not code-shaped — confirmed live across two separate sessions**: <a name='id/BlockNode:00CF6R1KP8000' class='aperas-anchor aperas-id'></a> each one investigated `reconcile.ts`/`node.ts` directly via plain file reads, with no `aperas` traversal and no skill invocation at all, until an explicit user reminder broke it. The skill's frontmatter `description` — the only signal the host's auto-invocation heuristic sees before the body ever loads — lists trigger conditions that are all graph-*editing*-shaped (editing/inserting/removing/renaming a node, a wikilink, a `kg:`/`aperas` mention). Nothing in it names "about to read or edit this repo's source code, which a concern doc already carries issues/design/planning about" — exactly the domain the edit loop's own step 1 ("orient before touching anything") was written for. A task framed as "investigate a bug in `reconcile.ts`" never matches the description, so the skill never loads, so its own advice is never read: not a memory failure inside the skill, a failure to be invoked at all. These two sessions are one of the three observations behind [the trigger-accuracy measurement](../planning/aperas-skill.md#id/BlockNode:00CEDFKN3000A), which has still never been run against a held-out split.
  
  - **Same shape as the write-side gap, one step earlier**: <a name='id/BlockNode:00CF6R1KP8001' class='aperas-anchor aperas-id'></a> [Philosophy's "a look-it-up rule is only half a discipline"](#id/BlockNode:00CF5ZE1S0003) diagnosed why a *stated* instruction doesn't self-execute on the write side. This is the identical failure on the read side, one level further out — before a rule can be half a discipline, something has to load the rule in the first place, and nothing here does that mechanically.
  - **Two candidate fixes, not mutually exclusive, neither built yet**: <a name='id/BlockNode:00CF6R1KP8002' class='aperas-anchor aperas-id'></a> broaden the description to name source-code investigation/editing explicitly (cheap, but soft — the same shape of fix a stated-condition list already is, just a longer list); or a mechanical trigger outside the skill file entirely — a hook firing on a Read/Edit/Grep touching `monorepo/**`, unbidden, the same category of fix `skill_drift.py` already is for the write side. Which to build is not yet decided.

- **A mechanical read-side gate was built, tested, and broke three separate ways — none of them a config typo**: <a name='id/BlockNode:00CF80TVJG001' class='aperas-anchor aperas-id'></a> to close the trigger gap just above, a `PreToolUse` hook (`skills/aperas/scripts/aperas_gate.py`) was registered in a personal `.claude/settings.local.json` — deliberately never shared, since a hard gate baked into the project would be the "destroys the whole meaning of skill" mistake the entry above warns against. It denied `Read`/`Edit`/`Grep` under `monorepo/packages/**` and `AperasKG/**` until the session had run a real `aperas` command, tracked by a session-scoped marker file. Two rounds of live testing found three independent bugs, each confirmed rather than guessed at.
  
  - **Bug 1 — the Bash trigger matched the project's own name**: <a name='id/BlockNode:00CF80TVJG002' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8003' class='aperas-anchor aperas-id'></a> `Bash(*aperas*)` was meant to open the gate on a real `aperas` invocation, but the repository itself is named `Aperas`, so any `find`/`ls`/`grep` command that merely touches a path under it also matches. Confirmed by the marker file's own mtime landing 3–4 seconds after a session's very first `find` call — long before any `Read` of graph content, let alone a real orientation. Fixed by anchoring to the actual invocation shape, `Bash(npm run aperas -- *)`.
  - **Bug 2 — the gated path was never the path actually used**: <a name='id/BlockNode:00CF80TVJR000' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8004' class='aperas-anchor aperas-id'></a> `AperasKG` is a symlink whose real target, `/home/will/source/AperasKG`, sits *outside* the project root as a sibling, not nested under it. A relative `if` pattern resolves against `<cwd>/AperasKG/**`, but every real `Read` call resolved through the symlink and used the target path directly — a different absolute path that pattern can never match. The rule was dead the day it was written; confirmed by running the identical `Read` through both path forms under `--debug hooks` and watching one skip and the other fire. Fixed with an absolute-anchored `//`-pattern naming the real location, kept alongside the harmless, still-inert relative one.
  - **Bug 3 — a stale decoy sat at an ungated path**: <a name='id/BlockNode:00CF80TVJR001' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8005' class='aperas-anchor aperas-id'></a> `skills/aperas-workspace/kg-clone/` — a disposable, gitignored eval-sandbox clone of the whole graph, reproducible via `graph-sandbox.sh` — held copies of the same filenames at a path neither rule covered, so an agent exploring with `find`/`ls` could wander in and read from there with none of the gate's discipline attached. It was not even current: it predated this session's own `cli.md`/`core.md` split. Removed outright.
  - **What actually found these — not reasoning about VS Code, a real headless run with hook tracing**: <a name='id/BlockNode:00CF80TVJR002' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8006' class='aperas-anchor aperas-id'></a> `claude -p "<prompt>" --debug hooks --debug-file <path>` runs one real session and logs every hook match, skip, and the exact JSON decision returned. Guessing at Bug 2 by reasoning about the VS Code extension's process lifecycle produced a plausible but wrong diagnosis (a stale-process theory, "restart VS Code" — which changed nothing); the debug trace found the actual cause in one run.
  - **The example that was tested, kept here since the file itself doesn't survive**: <a name='id/BlockNode:00CF80TVJR003' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8007' class='aperas-anchor aperas-id'></a> `.claude/settings.local.json` is personal and gitignored by design, so this is its only durable record.
    
    ```json
    {
      "hooks": {
        "PreToolUse": [
          {
            "matcher": "Read",
            "hooks": [
              { "type": "command", "if": "Read(monorepo/packages/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Read(AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Read(//home/will/source/AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" }
            ]
          },
          {
            "matcher": "Edit",
            "hooks": [
              { "type": "command", "if": "Edit(monorepo/packages/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Edit(AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Edit(//home/will/source/AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" }
            ]
          },
          {
            "matcher": "Grep",
            "hooks": [
              { "type": "command", "if": "Grep(monorepo/packages/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Grep(AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" },
              { "type": "command", "if": "Grep(//home/will/source/AperasKG/**)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py" }
            ]
          },
          {
            "matcher": "Bash",
            "hooks": [
              { "type": "command", "if": "Bash(npm run aperas -- *)", "command": "python3 ${CLAUDE_PROJECT_DIR}/skills/aperas/scripts/aperas_gate.py --mark" }
            ]
          }
        ]
      }
    }
    ```
  - **Why this was retired rather than kept running**: <a name='id/BlockNode:00CF80TVJR005' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CF6R1KP8008' class='aperas-anchor aperas-id'></a> three bugs surfaced across two rounds of testing, on a mechanism that is inherently personal, machine-specific (its own fix hardcodes an absolute path), and invisible to anyone who didn't set it up themselves. [Promoted to a v1.3 delta](#id/BlockNode:00CF80MKFG001): the next attempt trades a hard mechanical gate for a soft, one-time consent question the skill asks itself, with the answer remembered durably instead of mechanically enforced.

- **The trigger gap is closed, and the fix was pure ordering — the v1.3 that shipped never worked**: <a name='id/BlockNode:00CF9M8BC8000' class='aperas-anchor aperas-id'></a> [the entry above](#id/BlockNode:00CF6R1KP8000) predicted the skill would never load for a code-shaped task, and the v1.3 released to close it still didn't. That description opened by defining the subject — "Aperas is this project's external memory — a knowledge graph, worked through the `aperas` CLI…" — which hands the host's auto-invocation heuristic a *topic* to match the task against, and "execute `planning/cli.md`" scores low against "knowledge graph". The version that works, found by trial and error and amended onto the same commit, reverses the order completely: the unconditional imperative leads ("Before anything else in this project — first turn, every session, whatever the task looks like, including when it looks unrelated, trivial, read-only, or like one quick lookup — check memory…"), and the identity sentence drops to second-to-last. The first clause is what the heuristic weighs, and an imperative keyed on *session position* offers no topic to fail to match. Two guards came with it: "Do this without loading this skill, and never ask permission to do it or offer it as an option; just do it" closes the meta-hedge of offering the check as an option, and "Load this skill only once the answer is yes" separates the unconditional check from the consent-gated skill. Confirmed live: this session ran the check on turn one, unprompted, on a task framed as "execute AperasKG/artifacts/planning/cli.md". The shipped description failing and the reordered one firing on turn one are the other two observations behind [the trigger-accuracy measurement](../planning/aperas-skill.md#id/BlockNode:00CEDFKN3000A).
  
  - **The failed description, kept here since the commit was amended away**: <a name='id/BlockNode:00CF9MFERG001' class='aperas-anchor aperas-id'></a> the original v1.3 (`cb022b5`, reachable now only via reflog and eventually garbage-collected) opened "Aperas is this project's external memory — a knowledge graph, worked through the `aperas` CLI, holding what has been decided, tried, found and planned, so that neither the person nor the agent has to carry it in their head. Read this at the start of any session in this project, whatever the task looks like, and before reading or changing anything. First check memory for a standing decision on whether Aperas manages the session; …". Same instructions, same coverage, opposite order — and it did not fire. Kept here for the same reason the gate's `settings.local.json` example is: the artifact itself doesn't survive.
- **Invocation was necessary but not sufficient — the skill loaded on turn one and still didn't govern the reads**: <a name='id/BlockNode:00CF9M8BC8001' class='aperas-anchor aperas-id'></a> with the description fix above in place, this session ran the memory check on turn one and loaded the skill before anything else — then investigated the entire task through the projections regardless: `Read` on `planning/cli.md`, `find` piped to `grep -l` across `issues/*.md`, a `grep -n` used as a `cat` substitute on `issues/core.md`, `Read` on `issues/cli.md` and `planning/core.md`. The first `aperas` call was `--help`, and it came only because a plan step mechanically required the CLI — *after* `kgInsert.ts` had already been edited. [The entry above](#id/BlockNode:00CF6R1KP8000) diagnosed the two earlier sessions as "not a memory failure inside the skill, a failure to be invoked at all"; that was correct, and closing it isolates the next layer. The skill can be loaded, consented to, and sitting in context, and still not reach the moment an agent reaches for `Read` on an `artifacts/**.md` path — because orientation is bound to the edit loop ("orient before touching anything" is step 1 of *editing*), and a long read-only investigation phase never enters that loop. Promoted to [issues/aperas-skill.md](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ1R001), with [the loop's name](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20000) and [the worked example's structural-only framing](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20001) filed alongside it.
  
  - **What it cost, concretely — this isn't doctrinal**: <a name='id/BlockNode:00CF9MGW8R001' class='aperas-anchor aperas-id'></a> addressing was learned from link syntax in the projections rather than from the CLI, so `issues/cli.md#id/BlockNode:…` (valid *link* form, invalid CLI ref) burned two failed calls before bare ids were found to work; block ids were read out of projected anchor tags, one step from the transcription hazard the edit loop's step 2 warns about; `show_node.py` was run against unflushed mutations, reported the pre-move state, and produced a confident wrong conclusion that a move had gone backwards; and the absence of any way to move a node into an empty parent was discovered by hitting it mid-edit, where one `unfold` on the target during planning would have shown `0 children`. The `show_node.py` half is promoted to [issues/aperas-skill.md](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20003).
  - **The declined read-side instruction doesn't cover this, and shouldn't be re-litigated as though it did**: <a name='id/BlockNode:00CF9MGW8R002' class='aperas-anchor aperas-id'></a> [the read-side decline](#id/BlockNode:00CF5ZK3ZG002) rests on [a look-it-up rule being only half a discipline](#id/BlockNode:00CF5ZE1S0003) — a rule saying "look it up rather than trust memory" can report what the graph holds but never that it is missing something. That argument is about *memory vs. lookup*. This failure is about *shadow vs. source on the read path*: everything was looked up, in the projections. Different axis, so the decline stands on its own terms and simply doesn't reach it. Likewise the retired gate's three bugs were all hook-config faults — a `Bash` pattern matching the repository's own name, a symlink resolving outside the gated root, a stale sandbox clone — and its stated retirement reason was that the vehicle is personal and machine-specific, which argues against that enforcement mechanism, not against a read-side rule living in the skill's own text.
  - **The code-side half of the same deferral was never recorded at all**: <a name='id/BlockNode:00CF9MGW8R003' class='aperas-anchor aperas-id'></a> `code-side` appears nowhere in `BlockNode.jsonld`. The read-side half was written down (as declined); the code-side half — what to do when the task is a source-code change that a concern doc already carries issues/design/planning about — survived only in the participants' memory, and surfaced here only because it was recalled in conversation. The asymmetry is the Philosophy's own case made against itself: nothing in the graph could report the omission, because doing the work and recording the work are two separate acts. Promoted to [issues/aperas-skill.md](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20002).

- **A parent-heading `update` is a third route to recreation, and neither the rule against it nor the promise that protects ids names it**: <a name='id/BlockNode:00CFB1A7GR001' class='aperas-anchor aperas-id'></a> regrouping `planning/aperas-skill.md`'s flat 17-item Task Breakdown into three `###` batches was pushed as a single `aperas update` on the Task Breakdown heading, and came back `0 matched, 0 moved, 0 changed, 20 added, 17 removed` — every item tombstoned and reminted, because the items moved from direct children to grandchildren and the depth change defeated identity matching entirely. Recovered from the staged checkpoint (`git restore` of the working tree from the index, then `aperas reload -- --discard`), and redone the way the skill prescribes: batch headings created carrying placeholder anchors, each item repositioned with a stdin-less `insert` (cross-parent move, id preserved), placeholders tombstoned, then one small same-depth push per batch to set the `orderedList`/`startIndex` run-leader props — which only the very first item had ever carried, which is why batches 2 and 3 initially rendered as bullets. All 17 original ids verified live afterwards. Promoted to [issues/aperas-skill.md](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48001), with [the unconditional id-preservation promise](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48002) and [the unranked collision between the two sections](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48003) filed alongside it.
  
  - **Why the rule didn't fire — it is keyed to a verb, not an outcome**: <a name='id/BlockNode:00CFB1E8X8001' class='aperas-anchor aperas-id'></a> "Move a node; don't remove and recreate it" names `remove` + `insert` as the anti-pattern. This was an `update` on a parent heading; `remove` was never typed, and the tombstoning was a side effect of reconciliation rather than anything visible in the intent. A parent-heading push is a third route to recreation that the rule does not mention at all, so an operator following it faithfully can still destroy every id in a subtree.
  - **Why Mechanics pointed the other way — an unconditional promise**: <a name='id/BlockNode:00CFB1E8X8002' class='aperas-anchor aperas-id'></a> "Adding an item to an existing list" prescribes exactly this call ("target the list's parent heading… exact-key matching reuses every unchanged item's id"), and for an ordered list calls it the only safe route. The id-preservation claim carries no precondition, though it only holds while a node keeps its parent and its depth. Two successful pushes in the same session (`17 matched`, and `11 matched, 6 added`) read as confirmation, so the generalisation from append to restructure felt earned rather than assumed.
  - **The two sections collide, and nothing ranks them**: <a name='id/BlockNode:00CFB1E8X8003' class='aperas-anchor aperas-id'></a> for "relocate items inside an ordered list", Discipline says move and Mechanics says parent-heading push. Mechanics is the more specific and more operational of the two, so it wins by default. The contradiction is not noted in either place.
  - **The through-line with the read-side failure**: <a name='id/BlockNode:00CFB1E8X8004' class='aperas-anchor aperas-id'></a> both rules are keyed to the tool reached for rather than the outcome caused. Orientation keyed on "editing the graph" never fired for reading; identity-preservation keyed on `remove` never fired for `update`. The same restatement fixes both — name the outcome, then let it catch whatever verb produces it.
  - **The operator's own share, which is not the skill's fault**: <a name='id/BlockNode:00CFB1E8X8005' class='aperas-anchor aperas-id'></a> the risk was reasoned about explicitly ("risk of mass tombstoning") and the push went ahead anyway, because a check had shown zero backlinks on all 17 items and that made the downside feel cheap. That substitutes cost-of-being-wrong for what the rule actually says, and the rule also protects a node's place in history, which backlink count has no bearing on.

- **The provenance obligation is scoped to promotion, so a claim added to an entry already in place carries no source**: <a name='id/BlockNode:00CG9MDJF0001' class='aperas-anchor aperas-id'></a> editing `planning/aperas-skill.md`'s trigger-accuracy item to add its supporting evidence produced a node with `links: 0` that nonetheless asserted three recorded observations exist. Caught by a reader running `aperas backlinks` on it and getting nothing back — the tool the skill already provides, turned on the writing side rather than the reading side. Two of the claims were wrong in kind rather than merely unsourced: a version label, "v1.2", inferred from where entries sit in Freeflow and written as though it had been recorded, and a task shape quoted as "investigate a bug in `reconcile.ts`" as if it were a labelled prompt, where the source says only that those sessions investigated `reconcile.ts`/`node.ts`. Repaired by correcting the text and adding pointers up from the two entries that actually hold the observations, so `backlinks` on the task now resolves to both. Promoted to [issues/aperas-skill.md](../issues/aperas-skill.md#id/BlockNode:00CG9MPGVG001).
  
  - **Why the rule didn't fire — it is scoped to an event, not to a property**: <a name='id/BlockNode:00CG9MHGGG001' class='aperas-anchor aperas-id'></a> *Promotion links at the origin* describes this failure verbatim — "A formal doc whose entries paraphrase confirmed findings without linking them reads as complete from its own side — nothing about it looks unfinished — while `aperas backlinks` on every one of its entries returns nothing" — but it opens "When a finding crystallizes *up* out of `discussion` into `issues`/`design`/`planning`/`history`". This was not a promotion. It was an edit adding evidence to an entry that had been sitting in the doc for sessions, so read literally the rule never reaches it.
  - **A resolved issue resurfacing one case over**: <a name='id/BlockNode:00CG9MHGGG002' class='aperas-anchor aperas-id'></a> "The skill states the citation-direction constraint but never the obligation that follows from it" sits in this concern's Resolved list, closed by adding the promotion-links rule. That fix was scoped to the incident shape which produced it, so the same underlying obligation failed again in the neighbouring case. Evidence that a narrow fix to this class of defect does not hold.
  - **The deeper drift — the skill kept deep read's mechanics and dropped its purpose**: <a name='id/BlockNode:00CG9MHGGG003' class='aperas-anchor aperas-id'></a> `archive/Aperas-design.md` defines the capability as provenance projection, "every rendered element retains provenance anchors and backlinks, allowing readers to drill down into the supporting evidence subgraph", and names it outright as "Deep read (provenance projection)". `SKILL.md` renders the same traversal as "Backward — deeper *context*. Who depends on this block, who cites it, what surrounds it", and justifies deep write by what a change breaks. Context and blast radius, never evidence: the word appears exactly once in the whole file, in the dense-linking pass, where it means "that is the evidence you should run the pass" rather than anything about provenance. Under that framing an unlinked claim reads as under-linked, not as malformed.
  - **Every check that passed, and the one nobody ran**: <a name='id/BlockNode:00CG9MHGGR000' class='aperas-anchor aperas-id'></a> ids verified live after each move, backlinks confirmed on the promoted issues, reconcile summaries read for unexpected removals, projections inspected, `skill_drift.py` clean in both directions. Every one of those asks whether the write landed. **None asks whether what was written is true**, which is how an inferred version number and a paraphrase dressed as a quotation survived a session of otherwise careful verification.

- **v2 plan — retire the status tags, give the read side equal standing, and take the document's own history out of `SKILL.md`**: <a name='id/BlockNode:00CGF35FNG001' class='aperas-anchor aperas-id'></a> a read of v1.4 found four defects with one root cause. (1) The `[current]`/`[superseded]`/`[unverified]` tags are obsolete — this doc's snapshot-plus-delta thread already carries per-item status, and across four versions nothing has ever been marked `[unverified]`, so the vocabulary costs every reader and buys nothing. The replacement rule is narrower and needs no vocabulary at all: **only current, verified items appear in `SKILL.md`**, with superseded material and unverified hypotheses living here in the graph instead. That supersedes [Topology's status-at-the-item paragraph](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00C), which asked the file to carry all three states where it stands. (2) Philosophy's shadow paragraph leans entirely to the write side — a projection is never where a change is made — and leaves the read side to a corrective paragraph four items further down. Reading and searching the shadow are the same category error as editing it and belong in the same sentence, which then lets the corrective paragraph be absorbed rather than kept. (3) Orientation's deep-read section names forward/downward and backward but misses the cheapest direction there is: **upward**. Ancestors are context, and climbing a level or two is what an agent actually wants at the moment it reaches for the whole artifact instead; for a node at `discussion/a.md/h1/freeflow/a/aa/aaa`, unfolding `discussion/a.md/h1/freeflow/a` is usually already enough, and you can stop as soon as the block's meaning stops changing. The same section governs deep write as well as deep read, so its title should say both. (4) Five items narrate the document's own past rather than stating the rule: the loop's opening disclaimer about its former name, the provenance bullet explaining which half used to be missing, the citation-direction note on how the rule was generalized, the list-matching precondition recalling how the section used to be worded, and the provenance rule explaining what a promotion-scoped version of itself would fail to reach. The root cause is a context failure in the writing, and it is the same skill the document teaches for reading: in a plan those phrases have context, because the surrounding discussion supplies it, whereas in `SKILL.md` the only context is the block itself and the blocks above it, where they read as scars from a conversation the reader never saw. The fix in each case is to rewrite the original so it is complete, never to leave it standing and append a correction — the tell being whether the sentence still makes sense to someone with no memory of the version that preceded it. Provenance is explicitly not history and stays: a recorded incident is evidence for a rule that is true now, which [Topology](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00B) requires travel with the rule it explains. Because the tag strip touches nearly every item, the change is recorded as a fresh **v2 snapshot** rather than as a delta on v1, which also resets `scripts/skill_drift.py`'s baseline in one step instead of asking it to normalize a retired vocabulary away. Both rules were promoted into Topology: the tag retirement rewrote [the status paragraph](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00C) in place, and the history rule landed as [a new paragraph beside it](../design/aperas-skill.md#id/BlockNode:00CGF54B5G001). The four defects were promoted to Resolved as [the status vocabulary](../issues/aperas-skill.md#id/BlockNode:00CGF7EZ4R001), [the write-only shadow rule](../issues/aperas-skill.md#id/BlockNode:00CGF7EZ4R002), [the missing upward direction](../issues/aperas-skill.md#id/BlockNode:00CGF7EZ4R003) and [the five narrated pasts](../issues/aperas-skill.md#id/BlockNode:00CGF7EZ4R004), and the version itself as [the v2 milestone](../history/aperas-skill.md#id/BlockNode:00CGF71QX8001).

## v0 SKILL.md (verbatim, 2026-09-12) <a name='id/BlockNode:00CE95MVP8001' class='aperas-anchor aperas-id'></a>

Dumped verbatim from `.claude/skills/aperas/SKILL.md` (mirrored at `skills/aperas/SKILL.md`) for easy citing and discussion while reshaping it. Frontmatter and top-matter are kept as one code block; the two numbered lists and the Reference section below are split into individually addressable items, matching the source's own structure — so a rewrite discussion can cite e.g. "item 14" as its own linkable block instead of a line number in a file that's about to move. Retitled from "Current" once v1 landed — it is the prior version now, kept for comparison, not the live one.

```
---
name: aperas
description: General discipline for working directly with the Apeiron knowledge graph via the `aperas` CLI — editing graph-first instead of hand-editing projected files, staging verified steps, writing discussion before executing a plan, wikilink syntax, renaming a tracked artifact (single or a cross-referencing set), and what to do when there's no command for something yet. Use this whenever work touches the AperasKG graph in any way — editing/updating/inserting/removing/renaming a node, adding a wikilink, or any mention of `aperas`/`kg:` commands in the context of this project — even if the user doesn't name the skill directly. Read this before `kg-doc-ingest`, which builds on it for the one-time migration of a legacy hand-written doc.
---

# aperas

Status: **v0** — factored out of `kg-doc-ingest`, which used to carry all of this before there was a second workflow needing the same practices. Everything here came from real incidents across two migration passes (`documentation.md`, then a `cli.md` → `cli-packaging.md` → `packaging.md` doc set) and the `aperas` dispatcher/packaging work that followed. Expect this to keep growing.

> **Aperas-repo insiders**: `aperas` isn't published yet. Every command below (`aperas <verb> ...`) actually runs today as `npm run aperas -- <verb> ...` from `Aperas/monorepo/`. **Delete this note once `aperas` ships as a real installed binary** (see `AperasKG/artifacts/issues/packaging.md`'s Pending Tasks — the `bin` build).
```

### Editing discipline <a name='id/BlockNode:00CE95MVP8003' class='aperas-anchor aperas-id'></a>

1. **Graph-first, always — never hand-edit a projected `.md` file.** Once an artifact is tracked, every change — a wikilink fix, new content, a rename, a retitle — goes through `aperas update`/`aperas insert`/`aperas project`, never a direct edit of the file on disk followed by re-ingesting. Hand-editing and reconciling back in is the *disk-first* direction `kg-doc-ingest` uses for a genuinely new, not-yet-tracked doc; reusing it on something already migrated is reaching for the wrong tool, not a style preference (confirmed live, caught by direct user callout: doing this once for a wikilink fix, then having to redo it through `aperas update` to actually fix the workflow).
   
   - Edit one existing block: <a name='id/BlockNode:00CE95MVP8005' class='aperas-anchor aperas-id'></a> `echo "<replacement markdown>" | aperas update <path>` (targeting the whole artifact reconciles its entire tree; targeting one block directly only touches that block).
   - Add new content: <a name='id/BlockNode:00CE95MVP8006' class='aperas-anchor aperas-id'></a> pipe markdown to `aperas insert <parent-path>`.
   - Then `aperas project <path> --flush` to bake the change back to disk.
2. **Target the smallest block that actually changed, not the whole document.** `aperas update`/`aperas insert` both work at any level — a single list item, a whole artifact. Pushing a large, already-accumulated document's *entire* content just to fix one sentence means hand-reconstructing every other block exactly (any tiny transcription slip silently tombstones+recreates that block, losing its id) — and never do this by copying an already-*projected* file's content, either: it has `<a name='id/BlockNode:...' class='aperas-anchor aperas-id'></a>` tags spliced in that are a projection artifact, not real content — piping them back in bakes them into the block's stored text as if they were prose. Look up the specific block's id (via `aperas tree --depth <n>` on that subtree, or a direct read of `AperasKG/Apeiron/BlockNode.jsonld` if you need its exact raw text — see item 8) and target *that*, however deep it is.
3. **Wikilink syntax.** The link resolver only recognizes a URL that is `[[code]]`, starts with `aperas://tree/` or `aperas://id/`, or contains a bare `#fragment`/`path#fragment`. A plain `../folder/file.md/Slug`-style reference (no `#`) renders fine as prose but is *not* a graph `Link` — `aperas backlinks` on it comes back empty. Use `[title](../folder/file.md#id/BlockNode:<ID>)`, reading the target's actual anchor id off its own already-projected file. Verify with `aperas backlinks BlockNode:<ID> --text` (query the specific target block, not the whole-document path) — and don't just trust an `aperas update`/`aperas insert` summary line's own reported link-resolution count either; a real backlink appearing is the actual proof.
4. **The bold-colon gotcha.** A list item's lead-in-term anchor placement requires the lead-in colon to sit *outside* any `**bold**` span — `**Term**:`, not `**Term:**`. A bold-wrapped colon is rejected by the lead-in detector, so anchor insertion falls through to the next plain-text colon it finds, which can splice an anchor into the middle of unrelated text (e.g. into a link's own title). Match the `**Term**:` convention already established in migrated docs.
5. **Renaming a tracked artifact.** `git mv old.md new.md`, then `aperas ingest <new-path> --track --flush` from the *same* concern set you're renaming — no need to fall back to a full, path-less sweep (that walks the *entire* `artifacts/` tree, `archive/` included, which can hit collisions in never-before-swept legacy content and has no reason to be involved in renaming one doc). Scoped rename detection matches by exact abstract-text equality against already-tracked ArtifactNodes whose recorded path vanished from disk — don't just trust the "N renamed" summary line; confirm the *identity* was actually preserved (same ids at the new path) before moving on. A file rename alone doesn't touch content: if the doc's own H1 needs retitling too, do that as its own `aperas update` targeting the H1 heading directly with `--text-only` (safe as long as it has no `.text`/`.props` of its own to lose — worth a quick check first, e.g. via a direct `BlockNode.jsonld` read). Fix any internal cross-reference paths the same way, one leaf block at a time.
6. **Renaming a set of cross-referencing docs: retitle before you rename the file.** Do every content fix first — H1 retitles, cross-reference paths — while the files are still at their old names, verify, *then* `git mv` + track each one. That order means every `aperas update`/`aperas insert` call in the content-fixing phase still resolves against paths that exist, and the file rename becomes a pure mechanical last step with nothing else riding on it.
7. **A `--after`/`--before` anchor must be a direct child of `<path>`, not a descendant two levels up.** `aperas insert <path> --after <anchor>` fails with "anchor is not a child of X" if `<path>` isn't the anchor's actual immediate parent — a heading's own text content and its nested list are two different levels (the list is the heading's child; the list *items* are the list's children, not the heading's). If unsure, check the real structure first (`aperas tree --depth <n>` on that subtree, or a direct `BlockNode.jsonld` read) rather than guessing which level to target.
8. **No raw single-node inspection command yet.** `aperas tree`/`aperas backlinks --text` only ever show a *rendered preview* (title + truncated, anchor-stripped abstract) — right for browsing, not for verifying a stored field is exactly what's about to be pushed back, or for reading a field they never show at all (`props`, `tombstonedAt`). Until `aperas show <ref>` exists (pending — see `issues/packaging.md`), fall back to a direct read of `AperasKG/Apeiron/BlockNode.jsonld`/`ArtifactNode.jsonld` (a small Python/node one-liner) for ground truth.

### Working practices <a name='id/BlockNode:00CE95MVP800F' class='aperas-anchor aperas-id'></a>

9. **Track your own view.** `aperas profile create <handle> --name "<Display Name>"`, then `aperas profile create-view <name> --profile <handle>`. Use `aperas unfold <path> --view <name> --flush` to reveal nodes you're actively working on, `aperas tree --view <name>` to render that unfolded lens, and plain `aperas tree --depth <n>` (no `--view`) for a skeletal title-only view of the whole corpus.
10. **Restart to double-check disk state.** After a batch of mutations (especially tombstones), `aperas service restart` gracefully restarts the shared ApeironNgn service (flushes, then reloads fresh from the on-disk mirror) — the clean way to confirm what you think landed on disk actually did.
11. **Stage each verified step yourself.** After a step lands clean (a stable round-trip, a rename that checked out, a reconciliation with no unexpected removals), `git add` it immediately — in both the code repo and `AperasKG/` (the graph mirror + docs). That turns the git index into a running checkpoint: if a later step goes wrong, `git restore`/`git diff` against the index recovers cleanly, no guesswork. This is staging only, never committing — `git commit` stays the user's own call. Pass `--flush` on the mutating call you're about to stage, not just at the end of a sequence — the service's own flush timer can otherwise land *after* a `git add`, so the index catches stale content and needs re-staging once the timer fires.
12. **Write discussion before executing, not after.** Once a design/plan is settled — even just agreed in chat, even a "yes, do it" reply — write it into the relevant `discussion` (or `design`/`planning`) doc *before* starting the implementation, not as a wrap-up once it's done. This applies to any nontrivial multi-step change (a refactor, a rename spanning several files, a new mechanism), not just doc migration. The reason it matters more than it seems: the conversation context a plan lives in can be compacted or cut off at any point, and a plan that only ever existed as chat turns is gone the moment that happens, with no way to resume or hand the work off from what's on disk. Caught live once (a 3-way workspace split was authorized in chat with nothing written down yet) — don't let it recur. Treat the `discussion` doc as a scratchpad, not something to only write once fully resolved: freeflow raw investigation notes into it as you go (inventory findings, open questions, even a "not yet decided" list), not just the final settled conclusion — that's what actually protects the work if context is lost mid-investigation, not just mid-plan.
13. **A heading-target `update` with no `--text-only` reconciles children too — even an empty-bodied one.** Piping just a heading line (e.g. `## Pending Tasks`, no body) to clear a heading's own stale `.text` looks like a pure retitle, but without `--text-only` it still runs the generic reconcile: 0 piped children vs. N existing ones reconciles as *all* removed, tombstoning real content (a live item planted moments earlier, in the live incident that caught this). `--text-only` is what makes a heading-text-only edit safe (item 5 already relies on this for retitles) — it overwrites just `.text`/`.title` and skips reconciliation entirely, confirmed via a direct `BlockNode.jsonld` read showing children untouched. Recovered the live incident via `git restore` on the staged `Apeiron/*.jsonld` (per item 11, only possible because the prior step had actually been staged) followed by `aperas reload -- --discard` to make the service pick the restored disk state back up. **Adding a new item into an existing list — don't target the list node at all, and get the piped line exactly right.** `aperas insert <list-id>` (or `update <list-id>`) piping a bare `- item` line reliably creates a nested list-in-list instead of a sibling item: the piped top-level list node becomes one new child of the target list, not an unwrapped item inside it — hit repeatedly across independent attempts (inserting, updating a list node directly, and once more piping a line that *included* the item's own ordinal marker, e.g. `3. **Text**`, when targeting that ordered item directly — the leading `3.` alone is enough for the parser to read the piped content as a fresh list, not plain retitle text; pipe just the bare content, never the marker). Piping plain text with *no* bullet marker at all is its own distinct failure, not a safe alternative: it creates a wrongly-typed `paragraph` node instead of a `listItem`, breaking a contiguous run into two pieces (confirmed via the actual projected output: the new entry rendered with no bullet and no indentation, sitting as a stray paragraph between two list runs).
    
    **Prefer targeting the list's *parent heading* instead**, piping the heading line plus the full corrected list (every existing item, verbatim, plus the new one) to `aperas update <heading-id>` — Stage A's exact-key matching reuses every unchanged item's id (confirmed via a direct `BlockNode.jsonld` read: `N matched` for the untouched items, only the new one shows as `added`), so nothing is lost, and there's no nested-list wart to clean up afterward. **This only works if the piped content is genuinely complete** — piping the heading line plus *only* the new item (treating it as if it were an append) silently reconciles the existing items away as removed, exactly the same failure mode as this item's first paragraph, just via a heading that already has real list children instead of folded text. Hit live doing exactly that to a 4-link Dashboard list, expecting a one-line addition to leave the other three untouched; it didn't — `0 matched, 0 added, 5 removed` was the actual summary line, not the harmless one-line diff it looked like. There is no shortcut for "just append one item" via a heading-target `update`: either supply the whole reconstructed list, or use the create-and-promote dance below.
    
    If a nested list-in-list (or a stray wrong-typed paragraph) has already happened, recovery is the same two-step dance either way: promote the real item out with `aperas insert <item-id> --after <existing-direct-child-of-the-list>`, then `aperas remove` the now-empty wrapper (or the stray paragraph directly) — or just redo the operation via the parent-heading approach above with the *complete* list this time.
14. **Freeflow documents as an unbounded tree, not a flat list of headings.** Refines item 12: give a freeflow `discussion` doc a few dedicated top-level slots right after the Dashboard — `## Open Questions`, `## Settled`, `## Checkpoints` — for whatever's concern-shaped enough to want a fixed home. **Moving an item between slots is a real move, not remove-then-insert**: `aperas insert <existing-node-path-or-id> --after/--before <anchor>` with *no* stdin piped repositions that exact node — anchor's current parent becomes its new parent, "cross-parent moves work for free" per `kgInsert.ts`'s own module doc — preserving its id, any backlinks to it, and its place in history, instead of tombstoning the original and minting a fresh one for what's conceptually the same thought. Caught live getting this backwards: promoting two Freeflow findings into a fresh `## Checkpoints` heading via `aperas remove` + `aperas insert` (piping reworded text) left two needlessly tombstoned orphans behind for a same-session relocation that a plain move would have handled with zero churn — left as a lesson rather than redone, but don't repeat it. Reach for remove+insert only when the wording is genuinely changing enough that it's not really the same item any more (an Open Questions bullet resolving into a differently-worded Settled one, say) — even then, a move followed by a separate `--text-only` edit is worth considering first, since it keeps the id and only the text actually needs to change.
    
    The reason headings are wrong for this: <a name='id/BlockNode:00CE95MVPG008' class='aperas-anchor aperas-id'></a> a heading is the tool for a *fixed, predefined* structure — the Document Topology's whole premise is that each concern doc has a small, stable set of headings regardless of how much content piles up underneath them. Markdown headings are also capped at 6 levels in principle (only the first 3 are practically usable before the nesting gets awkward), and — this is the part that's easy to miss — a raw Markdown heading has no real nesting at all: `##` vs `###` is just a number on an otherwise flat line of text; Apeiron lifts that number into a real parent-child edge, but the *source syntax* itself is dead flat. A list, by contrast, nests natively and indefinitely through indentation, which is the only structure that can grow unboundedly without the skeleton growing with it, and the only one a `TreeView`'s `aperas fold`/`unfold` has a real subtree to act on. When the Freeflow list grows long enough to clutter the view, fold its older entries by nesting them one level deeper under a wrapper item, not by giving them their own headings. Not yet exercised past a handful of entries — the folding step is a described intent, not a verified mechanism.
15. **Discussion is where all meta-info is born — not a sink for what didn't fit elsewhere.** This isn't just a filing convention; it's `AperasKG/artifacts/archive/Aperas-design.md`'s own Apeiron/Peras distinction applied to the Document Topology itself. `discussion` is the Apeiron-equivalent concern: unbound, schema-free, the Talk/discourse facet where every comment, assertion, deliberation, and reasoning trace originates, formless, before anything is decided about where — or whether — it belongs elsewhere. `design`/`issues`/`planning`/`history` are Peras: typed, crystallized projections that specific *kinds* of content get promoted into, deliberately, once a dedicated home for that kind has actually been designed. Most things never need that promotion at all. So something turning up mid-task that isn't what the task is about (a bug in the ingest engine while migrating docs, say) isn't a filing problem demanding an immediate formal home — it's supposed to start in *this* task's own `discussion` doc and simply stay there (Checkpoints if it's logged-but-parked, Freeflow if it's still being chased) for as long as no dedicated home exists, which may be indefinitely. Confirmed wrong live, in exactly this shape: two ingest/parser bugs found while drafting an unrelated doc's Task Breakdown got filed straight into `issues/packaging.md`, on the assumption that a finding needs an immediate formal home somewhere — wrong twice over, since `packaging` wasn't even the right *eventual* concern (it covers CLI build/distribution, not graph-engine parsing/reconciliation, which is really `Aperas-apeironngn-design.md`'s domain and has no live concern doc yet), and since reaching for promotion at all skipped past the point of having a discussion sink in the first place. Reverted (`aperas remove` on the wrongly-added items, `--text-only` restoring the heading's prior placeholder text) and re-homed as a Checkpoints entry with no outgoing link. The test isn't "is there an existing doc this could plausibly belong to" — it's "has a dedicated home for this actually been designed yet," and until the answer is yes, discussion is exactly where it belongs, not a waypoint.
16. **A piped `echo "..."` silently drops nested double quotes — that's bash, not `aperas`.** Content containing its own `"literal quotes"` (a quoted phrase inside prose, say) loses them when piped via `echo "<content with "nested" quotes>" | aperas update ...` — bash's own quote parsing closes the outer string at the first inner `"` and re-opens after it, dropping both marks with no error from anything. Caught live re-reading a projected dry-run: `not merely "wherever convenient"` had silently become `not merely wherever convenient`. Write content with embedded double quotes to a file first (a `python3 -c "print(...)" > /tmp/....txt` one-liner handles the escaping correctly) and `cat` that file into the command instead of an inline `echo`.
17. **A reconcile summary line's counts aren't proof new content actually landed where you can see it.** Pushing several new items into an existing list can silently match one's content onto an *already-tombstoned* leftover node's id (a stale test-probe, an earlier removed item — whatever last occupied a matchable slot) without reviving it, so it stays invisible (tombstoned children are filtered at render time) even though the summary line reports it as matched/added with no error. Caught live: a Resolved-section push reported plausible counts, but the projected dry-run showed one fewer visible bullet than pushed. `aperas project <path> --dry-run` and actually counting what's visible is the only real check — not the mutating command's own summary. Recovery is a direct `BlockNode.jsonld` read to find which id silently absorbed the missing content, then clearing its `tombstonedAt` directly (no CLI verb for this yet).
18. **Work the graph, not a folder of files — dense linking, deep read, deep write, and an active view are the actual point, not optional polish.** `AperasKG/artifacts/archive/Aperas-design.md`'s own philosophy names this directly: *dense linking* (everything related gets linked, either directly — A references B — or indirectly, via a discussion that talks about both), *deep read* (examining a block means reading its linked blocks too, not just its sub-blocks, and checking backlinks once the search scope widens), and *deep write* (updating a block means checking its backlinks and forward links to update what's related, not leaving them stale). Skipping all three and just reading/writing one doc at a time — however carefully — is using Aperas like a folder of markdown files pulled out book by book, memory standing in for the graph's own crosslinks; the graph's whole advantage over that is structural, not something extra to layer on once the "real" work is done. Caught live, three ways in one sitting: (1) closed out a gap in `list-consumption.md` that directly resolved a gap filed in `treeview.md`, and a second gap sitting right next to it, without ever linking the two docs together — a real wikilink existed one hop away (the origin `discussion/archive-migration.md` entry both gaps trace back to) and was never followed or backfilled; (2) declared "no causal story" for a stale-looking bug without first checking `aperas backlinks` on it, which would have shown zero backlinks — itself evidence the report may never have been reproduced, not just unexplained; (3) a `--view <name>` created early in a session and never touched again silently goes stale — it still answers `aperas tree --view <name>`, just showing whatever was unfolded during a *previous* task, and nothing warns that it no longer reflects current work. Concretely: before answering "why"/"is this related to X" from memory, run `aperas backlinks <id> --text` and follow at least one hop of any link already on the block; before closing an issue a design/fix resolves, link the two directly (both directions, not just the direction that happened to get written first); and `aperas unfold <path> --view <name>` whatever you're actually working on *as* you start it, not as an afterthought — a view left pointing at last session's work is worse than no view, since it looks current without being current.

### Reference <a name='id/BlockNode:00CE95MVPG00D' class='aperas-anchor aperas-id'></a>

- `AperasKG/artifacts/design/linking.md` is the canonical spec for the addressing/anchor/wikilink syntax referenced in items 3 and 4 — read it when a link isn't resolving and the reason isn't obvious.
- `AperasKG/artifacts/design/documentation.md` describes the concern taxonomy (design/issues/planning/history/discussion) these docs get sorted into, and the Freeflow-document pattern item 12 above is built on.

## v1 SKILL.md (verbatim, 2026-09-13) <a name='id/BlockNode:00CF46W4Q8001' class='aperas-anchor aperas-id'></a>

Dumped verbatim from `skills/aperas/SKILL.md` (reached by symlink from `.agents/skills/` and `.claude/skills/`), the same way [v0](#id/BlockNode:00CE95MVP8001) was — a copy rather than a live projection, deliberately, so successive versions sit side by side and what a restructure *drops* stays findable. That is not hypothetical: v0's presence here is the only reason item 18's third trigger was found missing from v1. Frontmatter and top-matter are kept as one code block; section headings are demoted one level so every item below stays individually addressable.

```
---
name: aperas
description: Working directly with the Apeiron knowledge graph via the `aperas` CLI — the graph is the source and the `.md` files under `artifacts/` are projections of it, so every change goes through the CLI rather than a file edit. Covers traversal-first reading (deep read/deep write/dense linking), the edit loop, citation direction, staging, wikilink and anchor syntax, renaming, and the current tool gaps. Use this whenever work touches the AperasKG graph in any way — editing/updating/inserting/removing/renaming a node, adding a wikilink, or any mention of `aperas`/`kg:` commands in this project — even if the user doesn't name the skill. Read this before `kg-doc-ingest`, which covers getting existing text *into* the graph.
---

# aperas

Status: **v1** — restructured from a flat, incident-ordered list of eighteen items into four levels, abstract to concrete. Content is unchanged except where marked superseded; the arrangement was the defect. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

> **Aperas-repo insiders**: `aperas` isn't published yet. Every command below (`aperas <verb> ...`) actually runs today as `npm run aperas -- <verb> ...` from `Aperas/monorepo/`. **Delete this note once `aperas` ships as a real installed binary** (see `AperasKG/artifacts/issues/packaging.md`'s Pending Tasks — the `bin` build).
```

### How to read this <a name='id/BlockNode:00CF46W4QG001' class='aperas-anchor aperas-id'></a>

Four levels, each following from the one above:

1. **Philosophy** — what the graph *is*. Everything else is a consequence.
2. **Orientation** — what reading and writing *mean* here.
3. **Discipline** — how to behave once oriented.
4. **Mechanics** — how to type it.

Read top-down. Stopping after Orientation should already leave you acting correctly in the ordinary case; starting at Mechanics gives you a list of gotchas with nothing to hang them on. An item sits at the level that explains *why* it is true, not the level where it was first noticed.

Each item is marked **[current]**, **[superseded]** (the cause has since been removed — kept so the old advice isn't re-derived), or **[unverified]** (described, not yet confirmed live).

#### Scope <a name='id/BlockNode:00CF46W4QG008' class='aperas-anchor aperas-id'></a>

This skill owns *working the graph*. `kg-doc-ingest` owns *getting existing text into it* — tracking, ingesting, round-trip verification. Anything that is a fact about this project rather than about the tooling belongs in a concern doc under `AperasKG/artifacts/`, which this skill only points at.

Note the boundary is by subject, not by timing: <a name='id/BlockNode:00CF46W4QG009' class='aperas-anchor aperas-id'></a> a genuinely new document needs no disk authoring at all (see *Sketching a structure*, Mechanics). What is ruled out is authoring a *finished* document on disk and reconciling it back in.

---

### 1. Philosophy <a name='id/BlockNode:00CF46W4QG00B' class='aperas-anchor aperas-id'></a>

**The Apeiron is the source; the `.md` files under `artifacts/` are shadows it casts.** [current]

A projection can be regenerated from the graph at any time. It is never the place a change is made. Editing a projection to change the graph is mistaking the shadow for the thing casting it — and it can appear to work, because the file looks right afterwards, while the source is untouched or gets reconciled back into a shape nobody chose.

The graph's substance is nodes *and the links between them*. A node's meaning is not carried by its own text alone; it is constituted by what it links to, what links back, and where it sits among its siblings and its thread.

Every rule below is downstream of this. "Graph-first, always" is its first consequence, not an independent instruction.

**Worked example — the same task, both ways.** Asked whether two docs cross-referenced each other, one session reached for `grep` over the projected `.md` files plus a raw `BlockNode.jsonld` read. It took several steps, produced an answer, and still had to be redone — because the question was about link structure, which exists in the source and only *appears* in the shadow. Redone properly it was one command:

```bash
aperas backlinks BlockNode:00CE1GW638007 --text
# → "No backlinks found."
```

That is the whole answer, from the source, in one call. Searching projections for structure that only exists in the graph is the same category error as editing them — one level down.

---

### 2. Orientation <a name='id/BlockNode:00CF46W4QG00K' class='aperas-anchor aperas-id'></a>

**Traversal is the primary mode of work, not a check appended to it.** [current] Reading means following links; writing means placing them.

`archive/Aperas-design.md`'s Multi-Agent Projection Pattern names these as the architecture's own capabilities. They are crystallized practice rather than theory — but the practice predates this system, coming from years of real knowledge-graph work in Logseq and carried in as design instead of being rediscovered here. That this system has barely exercised them yet is a fact about its infancy, not their standing.

#### Deep read runs in two directions <a name='id/BlockNode:00CF46W4QG00N' class='aperas-anchor aperas-id'></a>

They answer different questions, and the tool surface already carves them apart:

- **Forward and downward — deeper *content*.** A block's children and its outgoing links: what it is made of and what it refers to. This is what an ordinary read wants, and it is why `aperas unfold <ref>` previews children *and* forward links together — both are content, in the same sense.
- **Backward — deeper *context*.** Who depends on this block, who cites it, what surrounds it. `aperas backlinks <id> --text` stands alone as a command because it is the other axis. Reach for it when the decision is harder than reading: editing, or an investigation whose scope has widened.

**Deep write is inherently backward.** [current] What a change breaks is only answerable from the citing side. Updating a block means checking its backlinks and forward links and updating what the change has made stale — not leaving them to rot.

**Dense linking is the precondition for both.** [current] Everything related gets linked, directly (A references B) or indirectly (a discussion node that talks about both). A sparsely linked graph gives deep read nothing to descend into and deep write nothing to follow. Linking is constitutive here, not tidiness.

**Keep an active view, and keep it current.** [current] Set one up once:

```bash
aperas profile create <handle> --name "<Display Name>"
aperas profile create-view <name> --profile <handle>
```

Then `aperas unfold <path> --view <name> --flush` whatever you are working on *as* you start it, `aperas tree --view <name>` to render that lens, `aperas fold` to collapse a subtree again, and plain `aperas tree --depth <n>` (no `--view`) for a skeletal title-only map of the whole corpus.

A view created early and never touched again still answers `aperas tree --view <name>`, showing whatever was unfolded during a previous task, with nothing warning you it is stale — worse than no view, because it looks current without being current.

**Worked example — a traversal, start to finish.**

```bash
aperas unfold BlockNode:00CE0HD0HG007 --view my-view --flush
# → the block's own text, plus each forward link previewed:
#   │ ...Link... [[wikilink]] → BlockNode:00CE1GW638002  ## Open Issues  [+6]
aperas unfold BlockNode:00CE1GW638002 --view my-view --flush
# → that heading's children, one of which is the block actually being looked for
```

Two commands, each one hop. The content axis, followed until it arrives.

---

### 3. Discipline <a name='id/BlockNode:00CF46W4QG012' class='aperas-anchor aperas-id'></a>

#### The edit loop <a name='id/BlockNode:00CF46W4QG013' class='aperas-anchor aperas-id'></a>

The shape of nearly every real task:

1. **Orient before touching anything — content first, context when the decision is hard.** Start with `aperas unfold <ref>` for children and forward links. Escalate to `aperas backlinks <id> --text` for context. Editing always qualifies, because step 5 cannot work without it.
2. **Locate the smallest block that actually changed.** [current] Not the artifact, not the enclosing heading: the leaf whose content is wrong. `aperas update`/`aperas insert` work at any level, and targeting something larger means hand-reconstructing every unchanged sibling exactly — where one transcription slip silently tombstones that block and mints a fresh id in its place. **Never reconstruct by copying from an already-*projected* file**: it has anchor tags spliced in that are a projection artifact, not content, and piping them back bakes them into the block's stored text as prose.
3. **Edit graph-first.** [current] Pipe replacement content to `aperas update <id>`; `aperas insert` for genuinely new content; a stdin-less `insert` to *move* a node rather than recreate it. Never a direct edit of the file on disk followed by re-ingesting — that is `kg-doc-ingest`'s disk-first direction, correct only for text not yet in the graph. (Caught live by direct user callout: doing this once for a wikilink fix, then having to redo it through `aperas update` to actually fix the workflow.)
4. **Verify by traversal, not by the summary line.** [current] A reconcile count reports what the command *believes* it did. Proof is a backlink that actually resolves, or `aperas project <path> --dry-run` where the content is actually visible. A push can silently match new content onto an already-tombstoned node's id without reviving it, so it stays invisible while the summary reports it as added — caught live when a Resolved section rendered one fewer bullet than was pushed.
5. **Deep write — follow what the change made stale.** Check backlinks and forward links; update what now disagrees.
6. **Project, then stage.** `aperas project <path> --flush`, then `git add` immediately.

#### Stage each verified step <a name='id/BlockNode:00CF46W4QR005' class='aperas-anchor aperas-id'></a>

[current] After a step lands clean, `git add` it — in both the code repo and `AperasKG/`. The index becomes a running checkpoint: if a later step goes wrong, `git restore`/`git diff` against it recovers cleanly. **Staging only, never committing** — `git commit` stays the user's call. Pass `--flush` on the mutating call you are about to stage, not just at the end of a sequence; the service's own flush timer can otherwise land *after* a `git add`, leaving the index holding stale content.

This is not bookkeeping. Recovering a live incident that tombstoned real content was only possible because the prior step had actually been staged.

#### Write discussion before executing, not after <a name='id/BlockNode:00CF46W4QR007' class='aperas-anchor aperas-id'></a>

[current] Once a plan is settled — even just agreed in chat, even a "yes, do it" — write it into the relevant `discussion` doc *before* starting, for any nontrivial multi-step change. The conversation a plan lives in can be compacted or cut off at any point, and a plan that only ever existed as chat turns is gone the moment that happens, with no way to resume or hand it off from what is on disk. Caught live once: a 3-way workspace split authorized in chat with nothing written down.

Treat the discussion doc as a scratchpad, not something to write only once resolved. Freeflow raw investigation notes into it as you go — inventory findings, open questions, a "not yet decided" list. That is what protects the work if context is lost mid-*investigation*, not just mid-plan.

#### Move a node; don't remove and recreate it <a name='id/BlockNode:00CF46W4QR009' class='aperas-anchor aperas-id'></a>

[current] `aperas insert <node-id> --after/--before <anchor>` with **no stdin piped** repositions that exact node — the anchor's current parent becomes its new parent, cross-parent moves included. It preserves the id, every backlink to it, and its place in history.

Reach for remove+insert only when the wording is changing enough that it is genuinely not the same item any more — and even then, a move followed by a separate `--text-only` edit keeps the id while changing only what actually changed. Caught live getting this backwards: promoting two findings into a new section via `remove` + `insert` left two needlessly tombstoned orphans behind, for a relocation a plain move would have handled with zero churn.

#### Citation direction <a name='id/BlockNode:00CF46W4QR00B' class='aperas-anchor aperas-id'></a>

[current] The concerns form an abstraction gradient — `design` most abstract, `discussion` least, `issues`/`planning`/`history` between. A citation may point **up** the gradient or **sideways** freely. It may not point **down**: a design block does not reference a discussion block, for the same reason a node carries a parent pointer rather than a list of children.

The one sanctioned exception is a designated index — a design doc's own `# Context` section, which exists precisely to index its concern's other facets, one link each. That is a single structurally-privileged reference, not citations scattered through the body.

#### Promotion links at the origin <a name='id/BlockNode:00CF46W4QR00D' class='aperas-anchor aperas-id'></a>

[current] The rule above has a corollary that has to be acted on in the same breath as a promotion. When a finding crystallizes *up* out of `discussion` into `issues`/`design`/`planning`/`history`, the new entry cannot cite the discussion entry it came from — that is a down-citation. So the link is added at the **origin** instead: the discussion entry gains "promoted to `issues/<concern>.md`" with a real wikilink, pointing up. The provenance then surfaces from the new entry's side for free, as a backlink.

Do it at the moment of promotion, not as a later tidying pass. A formal doc whose entries paraphrase confirmed findings without linking them reads as complete from its own side — nothing about it looks unfinished — while `aperas backlinks` on every one of its entries returns nothing, and the provenance survives only in the head of whoever filed it. Caught live: seven issues compiled into a new concern doc from findings recorded across four different discussion docs, every origin left unlinked, noticed only by direct user callout.

This is the topology half of crystallization (`design/aperas-skill.md`): <a name='id/BlockNode:00CF46W4QR00F' class='aperas-anchor aperas-id'></a> a relationship first mediated by a discussion node becomes a direct citation once it proves load-bearing. Link density is the product of that lifecycle, which is why `discussion` is where it gets paid for.

#### Discussion is where meta-info is born <a name='id/BlockNode:00CF46W4QR00G' class='aperas-anchor aperas-id'></a>

[current] Not a sink for what didn't fit elsewhere. `discussion` is the Apeiron-equivalent concern: unbound, schema-free, where every comment, assertion and reasoning trace originates before anything is decided about where — or whether — it belongs elsewhere. `design`/`issues`/`planning`/`history` are Peras: typed projections that specific *kinds* of content get promoted into, once a dedicated home for that kind has actually been designed. Most things never need promoting at all.

So something surfacing mid-task that isn't what the task is about — an engine bug found while migrating docs, say — starts in *this* task's discussion doc and stays there for as long as no dedicated home exists, possibly indefinitely. The test is not "is there an existing doc this could plausibly belong to" but "has a dedicated home for this actually been designed yet". Confirmed wrong live: two parser bugs were filed straight into `issues/packaging.md` on the assumption a finding needs an immediate formal home — wrong twice over, since packaging wasn't even the right eventual concern, and since reaching for promotion skipped the point of having a discussion sink at all.

See `design/documentation.md` for the concern taxonomy and the Freeflow document shape (an unbounded *list*, not a growing set of headings).

---

### 4. Mechanics <a name='id/BlockNode:00CF46W4QR00M' class='aperas-anchor aperas-id'></a>

This section describes the usage of the `aperas` CLI. For detailed syntax, see `aperas --help` and `aperas <verb> --help`.

#### Paths <a name='id/BlockNode:00CF46W4QR00N' class='aperas-anchor aperas-id'></a>

[current] Paths passed to `aperas project`/`ingest`/etc. resolve relative to the graph's `artifacts` root defined in `aperas.config.json`, e.g., `discussion/foo.md` relative to `AperasKG/artifacts/`, **not** the repo-relative `AperasKG/artifacts/discussion/foo.md` that `git status` and `find` print. The repo-relative form fails with "No ingested ArtifactNode or FolderNode found".

#### Wikilink syntax <a name='id/BlockNode:00CF46W4QR00P' class='aperas-anchor aperas-id'></a>

[current] The resolver only recognizes a URL that is `[[code]]`, starts with `aperas://tree/` or `aperas://id/`, or contains a bare `#fragment`/`path#fragment`. A plain `../folder/file.md/Slug` reference (no `#`) renders fine as prose but is **not** a graph `Link` — `aperas backlinks` on it comes back empty. Use `[title](../folder/file.md#id/BlockNode:<ID>)`.

Verify with `aperas backlinks BlockNode:<ID> --text` against the specific target block, not the whole-document path. Do not trust a command's own reported link-resolution count; a real backlink appearing is the proof. A link written without a `#fragment` silently creates nothing at all, and the ingest summary will not mention it.

#### Anchor placement — the bold-colon rule <a name='id/BlockNode:00CF46W4QR00R' class='aperas-anchor aperas-id'></a>

[current] A list item's lead-in colon must sit *outside* any bold span: `**Term**:`, never `**Term:**`. A bold-wrapped colon is rejected by the lead-in detector, so anchor insertion falls through to the next plain-text colon it finds — which can splice an anchor into the middle of unrelated text, such as a link's own title.

#### Sketching a structure <a name='id/BlockNode:00CF46W4QR00S' class='aperas-anchor aperas-id'></a>

[current] A new heading or subtree can be built directly in the graph, with no disk authoring: create a placeholder node with `aperas resolve --create-holder <path> --titles <title> [<title>...]`, then *fill* the real content in with `aperas update` and `aperas insert`. This is why a genuinely new document never requires the disk-first path.

#### `--after`/`--before` anchors <a name='id/BlockNode:00CF46W4QR00T' class='aperas-anchor aperas-id'></a>

[current] The anchor must be a **direct child** of `<path>`, not a descendant. `aperas insert <path> --after <anchor>` fails with "anchor is not a child of X" otherwise. A heading's own text and its nested list are two different levels. Check the real structure first — `aperas tree --depth <n>`, or `scripts/show_node.py --children <ref>` — rather than guessing.

Be aware this failure is not clean: <a name='id/BlockNode:00CF46W4QR00V' class='aperas-anchor aperas-id'></a> the new nodes are hydrated into the store *before* the anchor is validated, so a rejected insert leaves live orphans in memory that can collide with your retry. `aperas reload -- --discard` clears them.

#### Updating a heading — `--text-only` <a name='id/BlockNode:00CF46W4QR00W' class='aperas-anchor aperas-id'></a>

[current] A heading-target `update` **without** `--text-only` reconciles children too, even from an empty body: piping just `## Pending Tasks` with no body reconciles 0 piped children against N existing ones as *all removed*, tombstoning real content. `--text-only` overwrites just `.text`/`.title` and skips reconciliation entirely — that is what makes a retitle safe.

#### Adding an item to an existing list <a name='id/BlockNode:00CF46W4QR00X' class='aperas-anchor aperas-id'></a>

[current] Target the list's **parent heading** — `aperas update <heading-id>` — and pipe the heading line plus the *complete* corrected list, every existing item verbatim plus the new one. Exact-key matching reuses every unchanged item's id (`N matched`, only the new one `added`).

**This only works if the piped content is genuinely complete.** Piping the heading plus *only* the new item reconciles the existing ones away as removed. Hit live on a 4-link Dashboard expecting a one-line addition: the actual summary was `0 matched, 0 added, 5 removed`.

For an **ordered** list this is the only safe route, because a freshly inserted item becomes its own run-leader and can restart the numbering rather than continuing it.

For an unordered list, `aperas insert <parent> --after <existing-item>` piping a bare `- item` line is safe. [superseded — was previously unsafe] It used to create a nested list-in-list; the list-consumption migration removed every live `list`-typed node, so there is no longer a list node to mistakenly target. The old create-and-promote recovery dance — `aperas insert <item-id> --after <existing-direct-child-of-the-list>` to promote the real item out, then `aperas remove` the emptied wrapper — is therefore only needed for pre-existing warts, not new work.

Two input rules still apply: <a name='id/BlockNode:00CF46W4QR011' class='aperas-anchor aperas-id'></a> pipe the bare content, **never** the ordinal marker (a leading `3.` alone makes the parser read it as a fresh list), and **never** plain text with no bullet marker (it parses as a `paragraph`, breaking a contiguous run in two).

Known cosmetic consequence: <a name='id/BlockNode:00CF46W4QR012' class='aperas-anchor aperas-id'></a> a freshly inserted item carries its own explicit `orderedList`/`startIndex`, marking it a run-leader and rendering a spurious blank line before it. Not corruption — see `issues/list-consumption.md`.

#### Renaming <a name='id/BlockNode:00CF46W4QR013' class='aperas-anchor aperas-id'></a>

[current] **One artifact**: `git mv old.md new.md`, then `aperas ingest <new-path> --track --flush` scoped to that concern set — not a full path-less sweep, which walks the entire `artifacts/` tree including `archive/` and can hit collisions in never-swept legacy content. Rename detection matches by exact abstract-text equality against tracked ArtifactNodes whose recorded path vanished. Don't trust the "N renamed" summary; confirm the ids actually survived at the new path.

A file rename touches no content. If the H1 needs retitling too, that is a separate `aperas update` on the H1 with `--text-only`.

**A set of cross-referencing docs**: <a name='id/BlockNode:00CF46W4QR015' class='aperas-anchor aperas-id'></a> do every content fix first — H1 retitles, cross-reference paths — *while the files are still at their old names*, verify, then `git mv` each. That way every call in the content-fixing phase resolves against paths that still exist, and the rename becomes a purely mechanical last step.

#### Shell quoting <a name='id/BlockNode:00CF46W4QR016' class='aperas-anchor aperas-id'></a>

[current] A piped `echo "..."` silently drops nested double quotes — that is bash, not `aperas`. Bash closes the outer string at the first inner `"` and reopens after it, dropping both marks with no error from anything. Caught live: `not merely "wherever convenient"` had silently become `not merely wherever convenient`. Write content containing double quotes to a file first and `cat` it in.

#### Service state <a name='id/BlockNode:00CF46W4QR017' class='aperas-anchor aperas-id'></a>

[current] `aperas service restart` flushes and reloads from the on-disk mirror — the clean way to confirm what you think landed actually did. `aperas reload -- --discard` throws away in-memory state and re-reads disk, which is the recovery when a failed call has left orphans behind.

If the service has died, an unflushed mutation is gone. Flushing per step (above) is what makes this survivable.

#### Inspecting raw node state <a name='id/BlockNode:00CF46W4QR019' class='aperas-anchor aperas-id'></a>

[current] `aperas tree`/`backlinks --text`/`unfold` all show a *rendered preview* — title plus truncated, anchor-stripped abstract. For a field they never show (`props`, `tombstonedAt`) or for a block's exact stored text, use the bundled reader rather than writing another one:

```bash
scripts/show_node.py <ref>                 # full record: props, tombstonedAt, parent, children, links
scripts/show_node.py --text <ref>          # exact stored text, undecorated
scripts/show_node.py --children <ref>      # direct children, tombstoned ones marked
scripts/show_node.py --grep PATTERN [-i]   # full-text search — there is no `aperas search`
scripts/show_node.py --artifact <ref>      # which artifact a block lives in
```

Refs take a bare snowflake or a full id. It is read-only, and it locates `AperasKG/Apeiron/` itself.

`--text` is the one that matters before an edit: <a name='id/BlockNode:00CF46W4QR01C' class='aperas-anchor aperas-id'></a> redirect it to a file, change only what needs changing, and `cat` that back into `aperas update`. That keeps the untouched part of a block byte-identical instead of retyped from a preview — which is what step 2 of the edit loop warns about, since a transcription slip silently tombstones the block and mints a new id.

This is a staging area, not the fix: <a name='id/BlockNode:00CF46W4QR01D' class='aperas-anchor aperas-id'></a> the real gap is tracked in `issues/treeview.md` ("No raw single-node inspection command"), whose proposed resolution is an `aperas show <ref>` verb. `--children` marking tombstones is likewise standing in for `unfold`'s missing marker.

Specifically, **`unfold` does not mark tombstoned children** while `tree --view` appends `(tombstoned)`, so a tombstoned leftover can read as live data under `unfold`. Tracked in `issues/treeview.md`.

#### Full-text search — grep the raw store directly <a name='id/BlockNode:00CF46W4QR01F' class='aperas-anchor aperas-id'></a>

[current] `show_node.py --grep` works, but a plain `grep -n -C3 '<pattern>' AperasKG/Apeiron/BlockNode.jsonld` is faster and shows more: one command, the complete untruncated `text` (the script's own preview caps at 90 chars), and it also works over `ArtifactNode.jsonld` for an artifact's own title/abstract — which `--grep` never scans, since it only iterates blocks. This is not the shadow-grepping mistake the Philosophy example warns about: `Apeiron/*.jsonld` is the on-disk mirror of the graph itself, not the rendered `artifacts/*.md` projection, so grepping it is reading the source, not the shadow.

A hit is a candidate id, not proof of anything. Confirmed live: a node's field order is `@id, @type, [props], [tombstonedAt], title, text, parent, type, children`, and `props` is variable-length — so `tombstonedAt`'s distance from a `text` match shifts per node, and no fixed `-C<n>` window can be trusted to surface it. Treat every match as an id to hand to `aperas` (`unfold`/`tree`/`backlinks --text`) for the actual live/tombstoned status, parent, and links: grep finds the nodes, `aperas` deals with them.

---

### Reference <a name='id/BlockNode:00CF46W4QR01J' class='aperas-anchor aperas-id'></a>

- `AperasKG/artifacts/design/linking.md` — canonical spec for addressing, anchors and wikilink syntax. Read it when a link isn't resolving and the reason isn't obvious.
- `AperasKG/artifacts/design/documentation.md` — the concern taxonomy and the Freeflow document shape.
- `AperasKG/artifacts/design/aperas-skill.md` — this skill's own design: <a name='id/BlockNode:00CF46W4QR01N' class='aperas-anchor aperas-id'></a> the four levels, citation direction, and how items enter (incident → freeflow → confirmed → promoted to the level that explains it).
- `archive/Aperas-design.md` — the founding philosophy: <a name='id/BlockNode:00CF46W4QR01P' class='aperas-anchor aperas-id'></a> Apeiron/Aperas/Peras, deep read and deep write, Meta-Aperas.

#### Open tool gaps <a name='id/BlockNode:00CF46W4QR01Q' class='aperas-anchor aperas-id'></a>

Tracked in the graph rather than accumulating here: raw single-node inspection and `unfold`'s missing tombstone marker (`issues/treeview.md`); non-transactional writes leaving in-memory orphans, and `extractAnchorNames` treating a quoted example anchor as a real name claim (`discussion/aperas-skill.md`).

## Vertical thread (v1) — which principles are realized below <a name='id/BlockNode:00CF4D9XT0001' class='aperas-anchor aperas-id'></a>

Each of v1's Philosophy and Orientation principles was walked deliberately, in order, and matched against every Discipline and Mechanics item that operationalizes it. An entry below records a principle that has at least one realizer. A principle with **no entry, and therefore no backlinks, is unrealized** — that absence is a measurement, not an oversight, since the whole set was walked. The edges live here as mediating nodes rather than in the snapshot itself, because the snapshot has to stay verbatim to remain comparable across versions.

- **[The graph's substance is nodes *and* the links between them](#id/BlockNode:00CF46W4QG00D)** is realized by [Move a node; don't remove and recreate it](#id/BlockNode:00CF46W4QR009) — preserving the id is what preserves the links — and by [Citation direction](#id/BlockNode:00CF46W4QR00B), whose parent-pointer reasoning is the same principle applied to which way a reference may run.
- **[The Apeiron is the source; the `.md` files are shadows](#id/BlockNode:00CF46W4QG00B)** is realized by [the edit loop](#id/BlockNode:00CF46W4QG013), whose step 3 (edit graph-first) and step 6 (project, then stage) are the principle turned into an order of operations.
- **[Forward and downward — deeper content](#id/BlockNode:00CF46W4QG00P)** and **[backward — deeper context](#id/BlockNode:00CF46W4QG00Q)** are both realized by [the edit loop](#id/BlockNode:00CF46W4QG013)'s step 1, which splits orienting into exactly those two moves and says when to escalate from one to the other.
- **[Deep write is inherently backward](#id/BlockNode:00CF46W4QG00R)** is realized by [the edit loop](#id/BlockNode:00CF46W4QG013)'s step 5, follow what the change made stale.
- **[Dense linking is the precondition for both](#id/BlockNode:00CF46W4QG00S)** is realized by exactly one item, [Promotion links at the origin](#id/BlockNode:00CF46W4QR00D), and only for the single case of a finding crystallizing up out of discussion. Note what that means: a principle asserted as the precondition for *both* deep read and deep write has one narrow realizer, added 2026-09-13 — before that edit it had none at all. This is the gap that prompted the experiment, surfacing as thinness rather than absence only because it was partially patched a day earlier.

- **Grounding that exits the level structure — the forward-side signal**: <a name='id/BlockNode:00CF4MBFQG001' class='aperas-anchor aperas-id'></a> [Promotion links at the origin](#id/BlockNode:00CF46W4QR00D) names its own explanation as crystallization's topology axis, but the only statement of it is [in the design doc](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG00J), not at any Philosophy or Orientation level of the skill itself. A Discipline item grounded outside the level structure is the detectable form of a *missing* principle: querying backlinks can never surface it, since a principle with no node has no empty result to return, but the realizer's forward link points somewhere and that somewhere is measurable. Read from this side, the gap is "an item whose explanation is off-level," which is exactly the defect — a reader meeting the rule never meets what makes it true.

- **Threading v1.1's additions onto the v1 base** — the same walk, re-run across the delta, which is what the snapshot-plus-delta shape is for. Two zeroes closed, one new principle grounded:
  
  - **[Keep an active view, and keep it current](#id/BlockNode:00CF46W4QG00T)** — the experiment's zero — is now realized by [A view is per-task, not per-session](#id/BlockNode:00CF4QNX00005), with the mechanics in [Comparing distant docs](#id/BlockNode:00CF4QNX00007). The finding closed in the version immediately after the query that produced it.
  - **[Dense linking is the precondition for both](#id/BlockNode:00CF46W4QG00S)** gains three realizers beyond the single narrow one it had: [edit loop step 5 rewritten](#id/BlockNode:00CF4QNWZR004), which restores the trigger v1 dropped from v0's item 18; [the dense-linking pass](#id/BlockNode:00CF4QNX00002) for the deliberate wide-radius case; and [Comparing distant docs](#id/BlockNode:00CF4QNX00007) for the commands. Presence was never the issue here — thinness was, and thinness is what changed.
  - **The maturation principle** ([Philosophy](#id/BlockNode:00CF4QNWZR002), [Orientation](#id/BlockNode:00CF4QNWZR003)) is the node whose absence the forward-side query detected. Now that it exists on-level, [Promotion links at the origin](#id/BlockNode:00CF46W4QR00D) grounds upward inside the skill rather than sideways into the design doc — [recorded as its own delta](#id/BlockNode:00CF4QNX00001). The off-level grounding that made the gap detectable is itself what got repaired.
  - Worth noting what this cost: <a name='id/BlockNode:00CF4R3C78005' class='aperas-anchor aperas-id'></a> seven additions, four thread entries, all hand-written, and the graph proposed none of it. Re-threading is per-minor-version recurring work, which is the standing argument for an edge being a first-class thing rather than prose that happens to contain links.

- **Grounding the recall machinery — the three zeroes the forward audit returned**: <a name='id/BlockNode:00CF5ZK3ZG001' class='aperas-anchor aperas-id'></a> [the drift check](#id/BlockNode:00CF5GV8FR001) and [the `Supersedes` marker](#id/BlockNode:00CF5N94NR001) were Mechanics items with no principle above them, which is why they read as handy utilities rather than as something the skill requires. They now realize **[nobody working this graph will remember](#id/BlockNode:00CF5ZE1S0002)** — a record that must be consulted to be useful protects nothing, so what the philosophy demands is machinery that interrupts rather than machinery that waits to be asked. Both are instances of exactly that: one reports an omission unbidden, the other lets the report distinguish a deliberate rewrite from a silent loss.
  
  - **Its companion** — [a look-it-up rule is only half a discipline](#id/BlockNode:00CF5ZE1S0003) — grounds why the read-side instruction was declined rather than added. Doing the work and recording the work are two separate acts here, and only a comparison against the world outside the graph can see the second one missing. That principle is what the drift check implements.
  - **Both zeroes were found forward**, from the realizer's empty grounding, where "keep an active view" was found backward from the principle's empty backlinks. Two directions, two defect shapes, one walk — and the second one was only available because a one-directional query had already been caught being one-directional.

## v1.1 additions — delta on the v1 snapshot <a name='id/BlockNode:00CF4QNWZR001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v1 snapshot](#id/BlockNode:00CF46W4Q8001) rather than snapshotted afresh: a snapshot is taken at a major version, and minor versions are recorded as deltas against it, so the base stays stable and what changed stays legible without duplicating the whole document each time. Each addition below is verbatim and individually addressable, which is what lets [the vertical thread](#id/BlockNode:00CF4D9XT0001) extend across the two.

### Philosophy — the maturation principle <a name='id/BlockNode:00CF4QNWZR002' class='aperas-anchor aperas-id'></a>

**That substance matures; it does not merely accumulate.** [current] Both axes run the same direction — Apeiron toward Peras, unbounded toward bounded. On the **content** axis, prose hardens from formless discussion into typed design, issues, planning, history. On the **topology** axis, a relationship first exists *indirectly*, mediated by a discussion node that cites both ends and carries the judgment in its own text; once it proves load-bearing it crystallizes into a *direct* citation, and the mediating node's job is done. Link density is the residue of that lifecycle, which is why it reads as maturity from outside rather than as tidiness — and why `discussion` is where the cost of it gets paid.

### Orientation — link maturity <a name='id/BlockNode:00CF4QNWZR003' class='aperas-anchor aperas-id'></a>

**A link is placed at the maturity the relationship has earned.** [current] Writing means placing links, but not all of them direct and not all at once. A relationship that still needs judgment to state goes into a mediating discussion node citing both ends; one that has proven load-bearing becomes a direct citation between them. Reaching for a direct link too early asserts a dependency nobody has tested; leaving one mediated forever makes every traversal pay for the hop.

### Discipline — edit loop step 5, rewritten <a name='id/BlockNode:00CF4QNWZR004' class='aperas-anchor aperas-id'></a>

Supersedes: [v1's step 5](#id/BlockNode:00CF46W4QR003)

5. **Deep write — follow what the change made stale, and link what was never linked.** Check backlinks and forward links; update what now disagrees — and add the citation where the change has just made a relationship real. Closing an issue that a design or a fix resolves means linking the two to each other before moving on, in both directions, not only the one that happened to get written first. This is the per-edit instance of dense linking, and the only moment it is cheap: you are already standing where the missing link is visible.
6. **Project, then stage.** `aperas project <path> --flush`, then `git add` immediately.

### Discipline — Promotion links at the origin, closing sentence regrounded <a name='id/BlockNode:00CF4QNX00001' class='aperas-anchor aperas-id'></a>

Supersedes: [v1's closing sentence](#id/BlockNode:00CF46W4QR00F)

This is the topology half of crystallization, stated at Philosophy above: a relationship first mediated by a discussion node becomes a direct citation once it proves load-bearing.

### Discipline — The dense-linking pass <a name='id/BlockNode:00CF4QNX00002' class='aperas-anchor aperas-id'></a>

[current] Occasionally, and deliberately, work the relationships instead of the content. Bring distant nodes into one view, then take each pair in turn and ask whether a real, nameable dependency exists. If one does and a plain citation carries it, link directly, respecting direction. If stating it takes judgment, write a mediating discussion node that cites both ends and holds the reasoning in its own text.

The counterweight matters as much as the practice: <a name='id/BlockNode:00CF4QNX00003' class='aperas-anchor aperas-id'></a> **do not manufacture links.** Two docs sharing a corpus, or sharing vocabulary, is not a dependency. The test is whether you can say in one sentence what one owes the other. A pass that adds twenty weak links has made the graph harder to traverse, not denser — deep read now descends into noise.

Run it when a concern set has grown without anyone standing back from it, when two concerns keep coming up together, or when one finding turns out to have been recorded in several places independently. That last case is itself the evidence: the relationship existed and nothing captured it.

### Discipline — A view is per-task, not per-session <a name='id/BlockNode:00CF4QNX00005' class='aperas-anchor aperas-id'></a>

[current] Orientation's rule is that a view left pointing at last session's work is worse than no view. The practice that follows: re-unfold as the task's scope moves, and treat any view you did not open yourself as unknown until checked. `aperas tree --view <name>` renders whatever was unfolded whenever, with nothing marking age, so an inherited view looks identical to one built for the question actually in front of you.

Cheapest discipline is a named view per task rather than one long-lived default — creating one is a single call, and a view scoped to the task documents its own contents. The cleanup gap underneath this is real and tracked: nothing prunes a view's `unfolds` against what is still live (`issues/treeview.md`), so stale refs accumulate silently in any view kept across tasks.

### Mechanics — Comparing distant docs: the view as a lens <a name='id/BlockNode:00CF4QNX00007' class='aperas-anchor aperas-id'></a>

[current] `--view` is not a bookmark list; it is the mechanism for putting nodes that sit far apart in the tree next to each other. Unfold every doc being compared into one view, then render it once:

```bash
for f in issues/a.md discussion/b.md design/c.md; do
  aperas unfold "$f" --view <name> --flush
done
aperas tree --view <name>
```

Run `aperas backlinks <id> --text` on a target before adding a link to it — working across several docs at once makes it easy to add a citation that already exists. And note that a link resolves by its `id/` fragment: the leading relative path is for the human reader, so a stale path still resolves correctly while misleading anyone who reads it. Observed live renaming a concern — every fragment kept working, every path string had to be fixed by hand.

### Top matter — Status bumped to v1.1 <a name='id/BlockNode:00CF5GK5BR001' class='aperas-anchor aperas-id'></a>

Status: **v1.1** — v1 restructured a flat, incident-ordered list of eighteen items into four levels, abstract to concrete; the arrangement was the defect. v1.1 repairs the vertical thread between those levels: crystallization stated at Philosophy and Orientation rather than only as a Discipline rule, and dense linking realized below Orientation rather than only asserted there. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Discipline — Citation direction, exception generalized <a name='id/BlockNode:00CF5GK5BR002' class='aperas-anchor aperas-id'></a>

Supersedes: [v1's "one sanctioned exception" paragraph](#id/BlockNode:00CF46W4QR00C)

The sanctioned exception is a **normative, singular** pointer — one whose target is the block's whole referent rather than one of many possible mentions. A design doc's own `# Context` section is the familiar instance (one link per facet, a fixed set), but it is the *property* that is sanctioned, not that location: a history milestone announcing one snapshot, or a design block naming *the* canonical exemplar, qualify the same way.

The test is whether removing the link leaves the block **incomplete**. A milestone whose content is "this snapshot was taken" no longer says what it exists to say once its pointer is gone; "here is a discussion that also touched on this" loses only enrichment, and stays forbidden. What the rule is actually against is a *list of children* — unbounded, discretionary, accumulating — so cardinality is the real criterion and direction is only its usual symptom. [current] Generalized after a milestone needed exactly such a pointer and the rule, stated as "designated index," named an instance where it meant a property.

### Mechanics — Checking the skill against its own record <a name='id/BlockNode:00CF5GV8FR001' class='aperas-anchor aperas-id'></a>

[current] `SKILL.md` is a *generative* projection of its concern — authored from design rather than serialized by a command — so unlike an `aperas project` artifact it can drift from its source with nothing detecting it. `scripts/skill_drift.py` compares the file against the graph's record of it (the latest snapshot plus the deltas above it):

```bash
scripts/skill_drift.py              # both directions
scripts/skill_drift.py --added      # written into the file, never recorded
scripts/skill_drift.py --dropped    # recorded, no longer in the file
```

Run it after editing this file, before considering the edit done. *Added* is the check that matters most — an edit made and not recorded is invisible from the file's own side, which is how three separate additions in one session went unrecorded until a reader noticed. *Dropped* catches the opposite: v1 silently lost one of v0 item 18's three triggers, and nothing flagged it. Both are heuristics over normalized text, so a reworded sentence inside an otherwise-matching paragraph can still slip past.

### Mechanics — Supersedes marker, added to the drift-check section <a name='id/BlockNode:00CF5N94NR001' class='aperas-anchor aperas-id'></a>

A delta entry that replaces rather than adds carries a `Supersedes: [title](#id/BlockNode:...)` line naming the item it retires, which is what lets the check tell a deliberate rewrite from a silent loss.

## v1.2 additions — delta on the v1 snapshot <a name='id/BlockNode:00CF5ZE1S0001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v1 snapshot](#id/BlockNode:00CF46W4Q8001) alongside [the v1.1 delta](#id/BlockNode:00CF4QNWZR001). Recorded because `scripts/skill_drift.py` reported all three the moment they were written, which is the first time the recording step was prompted by the tooling rather than by a reader noticing.

### Philosophy — nobody working this graph will remember <a name='id/BlockNode:00CF5ZE1S0002' class='aperas-anchor aperas-id'></a>

**Nobody working this graph will remember.** [current] Not the human across weeks, not the agent across a context window. So the graph is not only where things are kept — it is what *notices*: the structural gaps and the emergent alignments between nodes, neither of which anyone will spot by holding the corpus in their head. A record that has to be consulted to be useful protects nothing, because being asked is the part that fails: the moment you would know to check is the moment you have already forgotten. What earns its place is what interrupts unbidden — a check reporting an omission, a backlink appearing where none was expected, a query coming back zero. Storage is the easy half and the projections already do it; recall is the half that costs something to build and the half that works.

### Philosophy — a look-it-up rule is only half a discipline <a name='id/BlockNode:00CF5ZE1S0003' class='aperas-anchor aperas-id'></a>

This is why a rule of the form "look it up instead of trusting your memory" is only half a discipline here. It can tell you what the graph says; it can never tell you the graph is *missing* something, because doing the work and recording the work are two separate acts and only the second one is visible from inside. Catching an omission takes a comparison against the world outside the graph. Confirmed live, three times in one session: each unrecorded edit was invisible from every side that could be consulted, and was caught by a reader noticing or by a check diffing the file against the record — never by looking something up.

### Top matter — Status bumped to v1.2 <a name='id/BlockNode:00CF5ZE1S0004' class='aperas-anchor aperas-id'></a>

Supersedes: [v1.1's status line](#id/BlockNode:00CF5GK5BR001)

Status: <a name='id/BlockNode:00CF5ZE1S0005' class='aperas-anchor aperas-id'></a> **v1.2** — v1 restructured a flat, incident-ordered list of eighteen items into four levels, abstract to concrete; the arrangement was the defect. v1.1 repaired the vertical thread between those levels: crystallization stated at Philosophy and Orientation rather than only as a Discipline rule, and dense linking realized below Orientation rather than only asserted there. v1.2 grounds the recall machinery — snapshot, delta, drift check — in the Philosophy statement that makes it non-optional. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Mechanics — drift-check accuracy caveat, corrected <a name='id/BlockNode:00CF6AJYP0001' class='aperas-anchor aperas-id'></a>

Supersedes: [the v1.1 drift-check section's caveat](#id/BlockNode:00CF5GV8FR001)

Run it after editing this file, before considering the edit done. *Added* is the check that matters most — an edit made and not recorded is invisible from the file's own side, which is how three separate additions in one session went unrecorded until a reader noticed. *Dropped* catches the opposite: v1 silently lost one of v0 item 18's three triggers, and nothing flagged it. The *added* side compares each unit in full — one unit per list item, since a list containing even one superseded item no longer appears contiguously in any single record — so a rewording anywhere in a unit is caught. The *dropped* side still matches on a prefix and is correspondingly weaker.

The *added* side compares each unit in full — one unit per list item, since a list containing even one superseded item no longer appears contiguously in any single record — so a rewording anywhere in a unit is caught. The *dropped* side still matches on a prefix and is correspondingly weaker.

## v1.3 additions — delta on the v1 snapshot <a name='id/BlockNode:00CF80MKFG001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v1 snapshot](#id/BlockNode:00CF46W4Q8001) alongside [the v1.1](#id/BlockNode:00CF4QNWZR001) and [v1.2](#id/BlockNode:00CF5ZE1S0001) deltas. Retires the mechanical read-side gate — built, tested, and found fragile in three ways — in favor of a one-time consent question the skill asks itself, remembered rather than enforced.

### Top matter — Frontmatter description: session consent clause added <a name='id/BlockNode:00CF80MKFR000' class='aperas-anchor aperas-id'></a>

Supersedes: [the v1 snapshot's frontmatter](#id/BlockNode:00CF46W4QG000)

--- name: <a name='id/BlockNode:00CF8BZWM0002' class='aperas-anchor aperas-id'></a> aperas description: Aperas is this project's external memory — a knowledge graph, worked through the `aperas` CLI, holding what has been decided, tried, found and planned, so that neither the person nor the agent has to carry it in their head. Read this at the start of any session in this project, whatever the task looks like, and before reading or changing anything. First check memory for a standing decision on whether Aperas manages the session; if none is recorded, ask with AskUserQuestion using exactly these choices — Never / Not now / Yes, this session only / Yes, all sessions — and record only 'all sessions' or 'never' as a durable memory, so a session-scoped answer is asked again next session while a durable one is never asked again. Once granted, it governs the work — orient in the graph before acting, change it through the CLI rather than by editing files, and put back what the work turns up. For getting existing documents into the graph the first time, `kg-doc-ingest` covers that; read this one first. ---

### Top matter — Frontmatter description: reordered imperative-first <a name='id/BlockNode:00CF9SRRFG001' class='aperas-anchor aperas-id'></a>

Supersedes: [v1.3's first frontmatter, ordered identity-first](#id/BlockNode:00CF8BZWM0002)

--- name: <a name='id/BlockNode:00CF9SRRFG002' class='aperas-anchor aperas-id'></a> aperas description: Before anything else in this project — first turn, every session, whatever the task looks like, including when it looks unrelated, trivial, read-only, or like one quick lookup — check memory for a standing decision on whether Aperas manages this session. Do this without loading this skill, and never ask permission to do it or offer it as an option; just do it. If a decision is recorded, follow it. If none is, ask with AskUserQuestion using exactly these choices — Never / Not now / Yes, this session only / Yes, all sessions — and record only 'all sessions' or 'never' durably, so a session-scoped answer is asked again next session. Load this skill only once the answer is yes; it then governs the work — orient in the graph before acting, change it through the CLI rather than by editing files, put back what the work turns up. Aperas is this project's external memory: a knowledge graph, worked through the `aperas` CLI, holding what has been decided, tried, found and planned. For first-time ingest of existing documents, `kg-doc-ingest` covers that; this one first. ---

### Top matter — Status bumped to v1.3 <a name='id/BlockNode:00CF80MKFR001' class='aperas-anchor aperas-id'></a>

Supersedes: [v1.2's status line](#id/BlockNode:00CF5ZE1S0005)

Status: <a name='id/BlockNode:00CF80MKFR002' class='aperas-anchor aperas-id'></a> **v1.3** — v1 restructured a flat, incident-ordered list of eighteen items into four levels, abstract to concrete; the arrangement was the defect. v1.1 repaired the vertical thread between those levels: crystallization stated at Philosophy and Orientation rather than only as a Discipline rule, and dense linking realized below Orientation rather than only asserted there. v1.2 grounds the recall machinery — snapshot, delta, drift check — in the Philosophy statement that makes it non-optional. v1.3 replaces a mechanical read-side gate, found fragile in three ways during testing, with a one-time consent question the skill asks and remembers instead of enforces, and rewrites the description in plain terms, scoped to the whole session rather than to graph edits alone. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

## v1.4 additions — delta on the v1 snapshot <a name='id/BlockNode:00CGA4ZN88001' class='aperas-anchor aperas-id'></a>

Threaded onto the v1 snapshot alongside the v1.1, v1.2 and v1.3 deltas. Keys rules to outcomes rather than to the verb or the event that happens to produce them, after a session confirmed the skill can be loaded, consented to, and still not govern the work.

### Top matter — Status bumped to v1.4 <a name='id/BlockNode:00CGA4ZN88002' class='aperas-anchor aperas-id'></a>

Supersedes: [v1.3’s status line](#id/BlockNode:00CF80MKFR002)

Status: <a name='id/BlockNode:00CGA4ZN88003' class='aperas-anchor aperas-id'></a> **v1.4** — v1 restructured a flat, incident-ordered list of eighteen items into four levels, abstract to concrete; the arrangement was the defect. v1.1 repaired the vertical thread between those levels: crystallization stated at Philosophy and Orientation rather than only as a Discipline rule, and dense linking realized below Orientation rather than only asserted there. v1.2 grounds the recall machinery — snapshot, delta, drift check — in the Philosophy statement that makes it non-optional. v1.3 replaces a mechanical read-side gate, found fragile in three ways during testing, with a one-time consent question the skill asks and remembers instead of enforces, and rewrites the description in plain terms, scoped to the whole session rather than to graph edits alone. v1.4 answers what v1.3's own success then exposed — that being loaded is not the same as governing the work — by keying rules to outcomes rather than to the verb or the event that happens to produce them: the edit loop becomes the loop, provenance is named as the half of context that was missing, and identity preservation now covers every call that can tombstone a node rather than the one that looks like a delete. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Top matter — Status line compacted, version rationale left to Discussion <a name='id/BlockNode:00CGA8YGW8001' class='aperas-anchor aperas-id'></a>

Supersedes: [v1.4's own status line](#id/BlockNode:00CGA4ZN88003)

Status: <a name='id/BlockNode:00CGA8YGW8002' class='aperas-anchor aperas-id'></a> **v1.4** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Version-by-version rationale lives in `discussion/aperas-skill.md`'s snapshot and deltas, not here. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Philosophy — Aperas is an evidence-based documentation system <a name='id/BlockNode:00CGA4ZN88004' class='aperas-anchor aperas-id'></a>

**Aperas is an evidence-based documentation system: a claim and its provenance are one object.** [current] This follows directly from the sentence above. If a node's meaning is constituted by what it links to and what links back, then a claim whose source is not reachable from it is not a weaker entry — it is a different kind of thing, an assertion wearing the costume of a record. It reads as complete from its own side, passes every mechanical check the tooling can run, and fails the only question the graph exists to answer: *how do you know?*

`archive/Aperas-design.md` builds its whole read side on this, defining deep read as provenance projection — "every rendered element retains provenance anchors and backlinks, allowing readers to drill down into the supporting evidence subgraph." The link may sit at either end: a forward citation where *Citation direction* (Discipline) permits one, a backlink from the source where it does not. One of the two must exist before the claim is left in place, not after.

### Philosophy — the content case is not the safe half <a name='id/BlockNode:00CGA4ZN88006' class='aperas-anchor aperas-id'></a>

**And the content case is not the safe half.** [current] "I was only reading the text, and the text is identical in both" is true, and still misses what was dropped: a projection carries a block's words and none of its place — not what cites it, not what it rests on, not whether it is still live. The loss is invisible precisely because the words really are the same, so nothing signals what came off with them. Read a concern through `aperas unfold`, not through the file that renders it.

### Orientation — an artifacts path is a node reference, not a file path <a name='id/BlockNode:00CGA4ZN88007' class='aperas-anchor aperas-id'></a>

**An `artifacts/**.md` path in your hand is a node reference, not a file path.** [current] This is the one mechanical test the skill has: if a path under `artifacts/` is about to become an argument to `Read`, `grep`, `find` or `cat`, the call is already wrong, and `aperas unfold <ref>` is what it meant. It holds for *reading*, not only for writing, and most of all when you are "just checking one thing" — which is how an entire investigation goes through the shadows without any single step feeling like a decision. Two things are deliberately not over the line: `Apeiron/*.jsonld` is the graph's own on-disk mirror, so grepping it is reading the source (see *Full-text search*, Mechanics), and source code is not in the graph at all.

### Orientation — provenance named inside the backward direction <a name='id/BlockNode:00CGA4ZN88008' class='aperas-anchor aperas-id'></a>

- **Two different relationships arrive through that one call, and only one of them was ever named here.** [current] *Dependents* — what relies on this block, what breaks if it changes — is what deep write needs, and is all the line above used to describe. *Sources* — what the block rests on — is what makes a claim checkable, and it shows up among backlinks rather than forward links whenever citation direction forbids the forward form. Provenance sits inside context, not against it; it needs saying because it is the half that was missing, which is why a node with no sources reads as merely under-linked instead of unsupported. `archive/Aperas-design.md` keeps the two apart by operation instead, giving provenance to deep read and impact traversal to deep write.

### Discipline — the edit loop becomes the loop, with an entry condition <a name='id/BlockNode:00CGA4ZN8800A' class='aperas-anchor aperas-id'></a>

Supersedes: [the v1 loop’s opening line](#id/BlockNode:00CF46W4QG013)

[current] Not "the edit loop". It is the shape of nearly every real task, and naming it for editing is what kept it from firing on tasks that never reach an edit — a reader correctly concludes the section is for later, and a whole investigation runs outside it. **Three things put you in the loop, not one:**

- **About to read a concern.** Traversal, not `Read`.
- **About to read or change source code this graph carries a concern about.** See *Source the graph already has a concern about*, below.
- **About to change the graph.** The steps below, in full.

The opening is the same in all three cases; only the tail differs. A traversal-only task ends after step 1, a source change ends by recording what it found, and a graph change runs the whole thing.

### Discipline — source the graph already has a concern about <a name='id/BlockNode:00CGA4ZN8800G' class='aperas-anchor aperas-id'></a>

[current] A task framed as "fix this bug in `reconcile.ts`" is not outside this skill. The graph very likely already holds issues, design, planning and history for that exact file, written by someone who will not be there to tell you. The obligation runs at **both** ends, not just the front.

**Before**, and before reading the source rather than after forming a theory about it:

```bash
grep -n 'reconcile.ts' AperasKG/Apeiron/BlockNode.jsonld   # candidate ids
aperas unfold <id> --view <task>                           # then work them in the graph
```

What turns up changes the work: <a name='id/BlockNode:00CGA4ZN8800K' class='aperas-anchor aperas-id'></a> a root cause already identified, a fix already ordered, an approach already tried and rejected for a reason nobody is going to repeat to you.

**After**, record what the work found. A fix that lands with nothing written is invisible from every side that can be consulted, because doing the work and recording it are two separate acts and only the second is visible from inside (Philosophy, above).

Confirmed live three times: <a name='id/BlockNode:00CGA4ZN8800N' class='aperas-anchor aperas-id'></a> two sessions investigated `reconcile.ts`/`node.ts` by plain file reads with no traversal and no skill load at all; a third loaded the skill on turn one, consented to it, and still read the entire task out of the projections before editing code. The first two were a trigger failure and are fixed; the third is why this section exists.

### Discipline — identity preservation restated outcome-first <a name='id/BlockNode:00CGA4ZN8800P' class='aperas-anchor aperas-id'></a>

Supersedes: [the v1 move rule](#id/BlockNode:00CF46W4QR009), [its remove+insert caveat](#id/BlockNode:00CF46W4QR00A)

[current] Stated by outcome, not by verb, because three different calls reach the same destruction and only one of them looks like a delete:

- `remove` + `insert` — the obvious one.
- `aperas update` on a **parent heading** — reconciliation tombstones and remints the subtree as a *side effect*; nothing in the intent resembles deleting, and the word `remove` is never typed.
- a full-list push whose items **change depth** — matching is defeated entirely, so every id is recreated.

`aperas insert <node-id> --after/--before <anchor>` with **no stdin piped** repositions that exact node — the anchor's current parent becomes its new parent, cross-parent moves included. It preserves the id, every backlink to it, and its place in history. Reach for anything else only when the wording is changing enough that it is genuinely not the same item any more — and even then, a move followed by a separate `--text-only` edit keeps the id while changing only what actually changed.

Zero backlinks is not a licence. The rule also protects a node's place in history, which backlink count has no bearing on.

Caught live twice: <a name='id/BlockNode:00CGA4ZN8G006' class='aperas-anchor aperas-id'></a> promoting two findings into a new section via `remove` + `insert` left two needlessly tombstoned orphans for a relocation a plain move would have handled with zero churn; and regrouping a flat 17-item list under three new sub-headings as a single parent-heading `update` returned `0 matched, 20 added, 17 removed`. Redone as create-headings-with-anchors, then move each item, then set the run-leader props per batch — all 17 ids survived. See *Adding an item to an existing list* (Mechanics) for the matching promise this rule constrains.

### Discipline — promotion links become every claim carries its source <a name='id/BlockNode:00CGA4ZN8G007' class='aperas-anchor aperas-id'></a>

Supersedes: [the v1 promotion corollary](#id/BlockNode:00CF46W4QR00D), [its do-it-at-promotion-time line](#id/BlockNode:00CF46W4QR00E)

[current] Philosophy's evidence rule, as something to do. Before leaving any text in a formal doc — `issues`, `design`, `planning`, `history` — check that each claim in it can be traced: provenance first, and every other relationship the text carries alongside it, each reified as a real link rather than described in prose. Then run `aperas backlinks <id> --text` on **what you just wrote**, not only on what you are about to read. A node whose claims rest on nothing returns nothing, and that silence is the entire signal.

Direction decides which end the link lives at, never whether it exists. When a finding crystallizes *up* out of `discussion` into `issues`/`design`/`planning`/`history`, the new entry cannot cite the discussion entry it came from — that is a down-citation. So the link is added at the **origin** instead: the discussion entry gains "promoted to `issues/<concern>.md`" with a real wikilink, pointing up. The provenance then surfaces from the new entry's side for free, as a backlink.

**This is a property of the claim, not a step in the promotion ritual**, and reading it as the latter is a live failure mode. An edit that adds supporting evidence to an entry already sitting in the doc is not a promotion, so a version of this rule scoped to promotions never reaches it. Caught live: a planning entry was edited to cite three recorded observations and came out with `links: 0` — complete-looking from its own side, caught only when a reader ran `backlinks` on it. The same unguarded gap passed an inferred version number written as recorded fact, and a paraphrase set in quotation marks as though it were a logged prompt. Every mechanical check in this file passed on that edit; all of them ask whether the write landed, none asks whether what was written is true.

### Mechanics — show_node.py reads the on-disk mirror <a name='id/BlockNode:00CGA4ZN8G00B' class='aperas-anchor aperas-id'></a>

It reads the **on-disk mirror**, so after an unflushed mutation it reports pre-flush state while `aperas unfold`/`tree` report the live service's. Flush first, or ask the CLI, when checking something you just changed. Caught live: a move and a tombstone were both invisible to it, producing a confident and wrong conclusion that the move had gone backwards.

### Mechanics — the exact-key-matching promise gets its precondition <a name='id/BlockNode:00CGA4ZN8G00C' class='aperas-anchor aperas-id'></a>

**That promise holds only while every item keeps its parent and its depth** — a precondition this section used to state unconditionally, which is exactly how it got read as licence for a restructure. A push that moves items to a new depth, regrouping a flat list under fresh sub-headings say, matches nothing and recreates everything; use moves for that instead (see *Preserve identity*, Discipline).

## v2 SKILL.md (verbatim, 2026-09-15) <a name='id/BlockNode:00CGF613VR001' class='aperas-anchor aperas-id'></a>

Dumped verbatim from `skills/aperas/SKILL.md`, the same way [v0](#id/BlockNode:00CE95MVP8001) and [v1](#id/BlockNode:00CF46W4Q8001) were. A fresh snapshot rather than a delta because the change reaches nearly every item: retiring the inline `[current]`/`[superseded]`/`[unverified]` vocabulary rewrites the text of 36 of them, which would leave `scripts/skill_drift.py` reporting the whole document as both added and dropped against the v1 baseline. Taking the snapshot resets that baseline in one step, and the v1.1-v1.4 deltas above stay where they are as the record of how v1 became this. Frontmatter and top-matter are kept as one code block; section headings are demoted one level so every item below stays individually addressable.

```
---
name: aperas
description: Before anything else in this project — first turn, every session, whatever the task looks like, including when it looks unrelated, trivial, read-only, or like one quick lookup — check memory for a standing decision on whether Aperas manages this session. Do this without loading this skill, and never ask permission to do it or offer it as an option; just do it. If a decision is recorded, follow it. If none is, ask with AskUserQuestion using exactly these choices — Never / Not now / Yes, this session only / Yes, all sessions — and record only 'all sessions' or 'never' durably, so a session-scoped answer is asked again next session. Load this skill only once the answer is yes; it then governs the work — orient in the graph before acting, change it through the CLI rather than by editing files, put back what the work turns up. Aperas is this project's external memory: a knowledge graph, worked through the `aperas` CLI, holding what has been decided, tried, found and planned. For first-time ingest of existing documents, `kg-doc-ingest` covers that; this one first.
---

# aperas

Status: **v2** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

> **Aperas-repo insiders**: `aperas` isn't published yet. Every command below (`aperas <verb> ...`) actually runs today as `npm run aperas -- <verb> ...` from `Aperas/monorepo/`. **Delete this note once `aperas` ships as a real installed binary** (see `AperasKG/artifacts/issues/packaging.md`'s Pending Tasks — the `bin` build).
```

### How to read this <a name='id/BlockNode:00CGF613VR003' class='aperas-anchor aperas-id'></a>

Four levels, each following from the one above:

1. **Philosophy** — what the graph *is*. Everything else is a consequence.
2. **Orientation** — what reading and writing *mean* here.
3. **Discipline** — how to behave once oriented.
4. **Mechanics** — how to type it.

Read top-down. Stopping after Orientation should already leave you acting correctly in the ordinary case; starting at Mechanics gives you a list of gotchas with nothing to hang them on. An item sits at the level that explains *why* it is true, not the level where it was first noticed.

Everything here is current and confirmed live. A rule whose cause has since been removed, and one identified but not yet verified, both belong in `discussion/aperas-skill.md` rather than here — a caution you cannot act on costs the reader and buys nothing.

#### Scope <a name='id/BlockNode:00CGF613W0002' class='aperas-anchor aperas-id'></a>

This skill owns *working the graph*. `kg-doc-ingest` owns *getting existing text into it* — tracking, ingesting, round-trip verification. Anything that is a fact about this project rather than about the tooling belongs in a concern doc under `AperasKG/artifacts/`, which this skill only points at.

Note the boundary is by subject, not by timing: <a name='id/BlockNode:00CGF613W0003' class='aperas-anchor aperas-id'></a> a genuinely new document needs no disk authoring at all (see *Sketching a structure*, Mechanics). What is ruled out is authoring a *finished* document on disk and reconciling it back in.

---

### 1. Philosophy <a name='id/BlockNode:00CGF613W0005' class='aperas-anchor aperas-id'></a>

**The Apeiron is the source; the `.md` files under `artifacts/` are shadows it casts.**

A projection can be regenerated from the graph at any time. It is never where a change is made, and never where a question is answered. Both failures look identical from outside — the file reads right — which is why neither announces itself.

Change it and you have mistaken the shadow for the thing casting it: the file looks correct afterwards, while the source is untouched or gets reconciled back into a shape nobody chose. Read it and you get a block's words and none of its place — not what cites it, not what it rests on, not whether it is still live — and the loss is invisible precisely because the words really are the same. Ask it about *structure* and you get nothing at all, since links exist only in the source.

The graph's substance is nodes *and the links between them*. A node's meaning is not carried by its own text alone; it is constituted by what it links to, what links back, and where it sits among its siblings and its thread.

Every rule below is downstream of this. "Graph-first, always" is its first consequence, not an independent instruction.

**Aperas is an evidence-based documentation system: a claim and its provenance are one object.** This follows directly from the sentence above. If a node's meaning is constituted by what it links to and what links back, then a claim whose source is not reachable from it is not a weaker entry — it is a different kind of thing, an assertion wearing the costume of a record. It reads as complete from its own side, passes every mechanical check the tooling can run, and fails the only question the graph exists to answer: *how do you know?*

`archive/Aperas-design.md` builds its whole read side on this, defining deep read as provenance projection — "every rendered element retains provenance anchors and backlinks, allowing readers to drill down into the supporting evidence subgraph." The link may sit at either end: a forward citation where *Citation direction* (Discipline) permits one, a backlink from the source where it does not. One of the two must exist before the claim is left in place, not after.

**That substance matures; it does not merely accumulate.** Both axes run the same direction — Apeiron toward Peras, unbounded toward bounded. On the **content** axis, prose hardens from formless discussion into typed design, issues, planning, history. On the **topology** axis, a relationship first exists *indirectly*, mediated by a discussion node that cites both ends and carries the judgment in its own text; once it proves load-bearing it crystallizes into a *direct* citation, and the mediating node's job is done. Link density is the residue of that lifecycle, which is why it reads as maturity from outside rather than as tidiness — and why `discussion` is where the cost of it gets paid.

**Nobody working this graph will remember.** Not the human across weeks, not the agent across a context window. So the graph is not only where things are kept — it is what *notices*: the structural gaps and the emergent alignments between nodes, neither of which anyone will spot by holding the corpus in their head. A record that has to be consulted to be useful protects nothing, because being asked is the part that fails: the moment you would know to check is the moment you have already forgotten. What earns its place is what interrupts unbidden — a check reporting an omission, a backlink appearing where none was expected, a query coming back zero. Storage is the easy half and the projections already do it; recall is the half that costs something to build and the half that works.

This is why a rule of the form "look it up instead of trusting your memory" is only half a discipline here. It can tell you what the graph says; it can never tell you the graph is *missing* something, because doing the work and recording the work are two separate acts and only the second one is visible from inside. Catching an omission takes a comparison against the world outside the graph. Confirmed live, three times in one session: each unrecorded edit was invisible from every side that could be consulted, and was caught by a reader noticing or by a check diffing the file against the record — never by looking something up.

**Worked example — the same task, both ways.** Asked whether two docs cross-referenced each other, one session reached for `grep` over the projected `.md` files plus a raw `BlockNode.jsonld` read. It took several steps, produced an answer, and still had to be redone — because the question was about link structure, which exists in the source and only *appears* in the shadow. Redone properly it was one command:

```bash
aperas backlinks BlockNode:00CE1GW638007 --text
# → "No backlinks found."
```

That is the whole answer, from the source, in one call. Read a concern through `aperas unfold`, not through the file that renders it.

---

### 2. Orientation <a name='id/BlockNode:00CGF613W000K' class='aperas-anchor aperas-id'></a>

**Traversal is the primary mode of work, not a check appended to it.** Reading means following links; writing means placing them.

`archive/Aperas-design.md`'s Multi-Agent Projection Pattern names these as the architecture's own capabilities. They are crystallized practice rather than theory — but the practice predates this system, coming from years of real knowledge-graph work in Logseq and carried in as design instead of being rediscovered here. That this system has barely exercised them yet is a fact about its infancy, not their standing.

**An `artifacts/**.md` path in your hand is a node reference, not a file path.** This is the one mechanical test the skill has: if a path under `artifacts/` is about to become an argument to `Read`, `grep`, `find` or `cat`, the call is already wrong, and `aperas unfold <ref>` is what it meant. It holds for *reading*, not only for writing, and most of all when you are "just checking one thing" — which is how an entire investigation goes through the shadows without any single step feeling like a decision. Two things are deliberately not over the line: `Apeiron/*.jsonld` is the graph's own on-disk mirror, so grepping it is reading the source (see *Full-text search*, Mechanics), and source code is not in the graph at all.

#### Deep read and deep write run along the same three directions <a name='id/BlockNode:00CGF613W000P' class='aperas-anchor aperas-id'></a>

They answer different questions, and the tool surface already carves them apart:

- **Forward and downward — deeper *content*.** A block's children and its outgoing links: what it is made of and what it refers to. This is what an ordinary read wants, and it is why `aperas unfold <ref>` previews children *and* forward links together — both are content, in the same sense.
- **Upward — surrounding *context*.** A block's ancestors: <a name='id/BlockNode:00CGF613W000R' class='aperas-anchor aperas-id'></a> the heading it sits under, the thread it belongs to. This is the cheapest move in the graph and the one most often skipped, because the pull it answers is the pull toward opening the whole artifact "for context" — and it almost never takes the whole artifact. For a node at `discussion/a.md/h1/freeflow/a/aa/aaa`, unfolding `discussion/a.md/h1/freeflow/a` is usually already enough. Climb a level at a time and stop once the block's meaning stops changing.
- **Backward — deeper *context*: dependents and sources.** `aperas backlinks <id> --text` stands alone as a command because it is the other axis, and two distinct relationships arrive through it. *Dependents* — what relies on this block, what breaks if it changes. *Sources* — what the block rests on, which is what makes a claim checkable; provenance surfaces here rather than among forward links whenever citation direction forbids the forward form, so a node with no backlinks may be not merely under-linked but unsupported. `archive/Aperas-design.md` keeps the two apart by operation instead, giving provenance to deep read and impact traversal to deep write.

Deep read takes the first two as a matter of course, and the third when the decision is harder than reading: editing, or an investigation whose scope has widened. **Deep write is inherently backward** — what a change breaks is only answerable from the citing side, so updating a block means checking its backlinks and forward links and updating what the change has made stale, not leaving them to rot.

**Dense linking is the precondition for both.** Everything related gets linked, directly (A references B) or indirectly (a discussion node that talks about both). A sparsely linked graph gives deep read nothing to descend into and deep write nothing to follow. Linking is constitutive here, not tidiness.

**A link is placed at the maturity the relationship has earned.** Writing means placing links, but not all of them direct and not all at once. A relationship that still needs judgment to state goes into a mediating discussion node citing both ends; one that has proven load-bearing becomes a direct citation between them. Reaching for a direct link too early asserts a dependency nobody has tested; leaving one mediated forever makes every traversal pay for the hop.

**Keep an active view, and keep it current.** Set one up once:

```bash
aperas profile create <handle> --name "<Display Name>"
aperas profile create-view <name> --profile <handle>
```

Then `aperas unfold <path> --view <name> --flush` whatever you are working on *as* you start it, `aperas tree --view <name>` to render that lens, `aperas fold` to collapse a subtree again, and plain `aperas tree --depth <n>` (no `--view`) for a skeletal title-only map of the whole corpus.

A view created early and never touched again still answers `aperas tree --view <name>`, showing whatever was unfolded during a previous task, with nothing warning you it is stale — worse than no view, because it looks current without being current.

**Worked example — a traversal, start to finish.**

```bash
aperas unfold BlockNode:00CE0HD0HG007 --view my-view --flush
# → the block's own text, plus each forward link previewed:
#   │ ...Link... [[wikilink]] → BlockNode:00CE1GW638002  ## Open Issues  [+6]
aperas unfold BlockNode:00CE1GW638002 --view my-view --flush
# → that heading's children, one of which is the block actually being looked for
```

Two commands, each one hop. The content axis, followed until it arrives.

---

### 3. Discipline <a name='id/BlockNode:00CGF613W0015' class='aperas-anchor aperas-id'></a>

#### The loop <a name='id/BlockNode:00CGF613W0016' class='aperas-anchor aperas-id'></a>

This is the shape of nearly every real task, not only the ones that reach an edit. **Three things put you in the loop:**

- **About to read a concern.** Traversal, not `Read`.
- **About to read or change source code this graph carries a concern about.** See *Source the graph already has a concern about*, below.
- **About to change the graph.** The steps below, in full.

The opening is the same in all three cases; only the tail differs. A traversal-only task ends after step 1, a source change ends by recording what it found, and a graph change runs the whole thing.

1. **Orient before touching anything — content first, context when the decision is hard.** Start with `aperas unfold <ref>` for children and forward links. Escalate to `aperas backlinks <id> --text` for context. Editing always qualifies, because step 5 cannot work without it.
2. **Locate the smallest block that actually changed.** Not the artifact, not the enclosing heading: the leaf whose content is wrong. `aperas update`/`aperas insert` work at any level, and targeting something larger means hand-reconstructing every unchanged sibling exactly — where one transcription slip silently tombstones that block and mints a fresh id in its place. **Never reconstruct by copying from an already-*projected* file**: it has anchor tags spliced in that are a projection artifact, not content, and piping them back bakes them into the block's stored text as prose.
3. **Edit graph-first.** Pipe replacement content to `aperas update <id>`; `aperas insert` for genuinely new content; a stdin-less `insert` to *move* a node rather than recreate it. Never a direct edit of the file on disk followed by re-ingesting — that is `kg-doc-ingest`'s disk-first direction, correct only for text not yet in the graph. (Caught live by direct user callout: doing this once for a wikilink fix, then having to redo it through `aperas update` to actually fix the workflow.)
4. **Verify by traversal, not by the summary line.** A reconcile count reports what the command *believes* it did. Proof is a backlink that actually resolves, or `aperas project <path> --dry-run` where the content is actually visible. A push can silently match new content onto an already-tombstoned node's id without reviving it, so it stays invisible while the summary reports it as added — caught live when a Resolved section rendered one fewer bullet than was pushed.
5. **Deep write — follow what the change made stale, and link what was never linked.** Check backlinks and forward links; update what now disagrees — and add the citation where the change has just made a relationship real. Closing an issue that a design or a fix resolves means linking the two to each other before moving on, in both directions, not only the one that happened to get written first. This is the per-edit instance of dense linking, and the only moment it is cheap: you are already standing where the missing link is visible.
6. **Project, then stage.** `aperas project <path> --flush`, then `git add` immediately.

#### Source the graph already has a concern about <a name='id/BlockNode:00CGF613W8009' class='aperas-anchor aperas-id'></a>

A task framed as "fix this bug in `reconcile.ts`" is not outside this skill. The graph very likely already holds issues, design, planning and history for that exact file, written by someone who will not be there to tell you. The obligation runs at **both** ends, not just the front.

**Before**, and before reading the source rather than after forming a theory about it:

```bash
grep -n 'reconcile.ts' AperasKG/Apeiron/BlockNode.jsonld   # candidate ids
aperas unfold <id> --view <task>                           # then work them in the graph
```

What turns up changes the work: <a name='id/BlockNode:00CGF613W800C' class='aperas-anchor aperas-id'></a> a root cause already identified, a fix already ordered, an approach already tried and rejected for a reason nobody is going to repeat to you.

**After**, record what the work found. A fix that lands with nothing written is invisible from every side that can be consulted, because doing the work and recording it are two separate acts and only the second is visible from inside (Philosophy, above).

Confirmed live three times: <a name='id/BlockNode:00CGF613W800E' class='aperas-anchor aperas-id'></a> two sessions investigated `reconcile.ts`/`node.ts` by plain file reads with no traversal and no skill load at all; a third loaded the skill on turn one, consented to it, and still read the entire task out of the projections before editing code. The first two were a trigger failure and are fixed; the third is why this section exists.

#### Stage each verified step <a name='id/BlockNode:00CGF613W800F' class='aperas-anchor aperas-id'></a>

After a step lands clean, `git add` it — in both the code repo and `AperasKG/`. The index becomes a running checkpoint: if a later step goes wrong, `git restore`/`git diff` against it recovers cleanly. **Staging only, never committing** — `git commit` stays the user's call. Pass `--flush` on the mutating call you are about to stage, not just at the end of a sequence; the service's own flush timer can otherwise land *after* a `git add`, leaving the index holding stale content.

This is not bookkeeping. Recovering a live incident that tombstoned real content was only possible because the prior step had actually been staged.

#### Write discussion before executing, not after <a name='id/BlockNode:00CGF613W800H' class='aperas-anchor aperas-id'></a>

Once a plan is settled — even just agreed in chat, even a "yes, do it" — write it into the relevant `discussion` doc *before* starting, for any nontrivial multi-step change. The conversation a plan lives in can be compacted or cut off at any point, and a plan that only ever existed as chat turns is gone the moment that happens, with no way to resume or hand it off from what is on disk. Caught live once: a 3-way workspace split authorized in chat with nothing written down.

Treat the discussion doc as a scratchpad, not something to write only once resolved. Freeflow raw investigation notes into it as you go — inventory findings, open questions, a "not yet decided" list. That is what protects the work if context is lost mid-*investigation*, not just mid-plan.

#### Preserve identity — against any operation that can tombstone a node you meant to keep <a name='id/BlockNode:00CGF613W800K' class='aperas-anchor aperas-id'></a>

Three different calls reach the same destruction, and only one of them looks like a delete:

- `remove` + `insert` — the obvious one.
- `aperas update` on a **parent heading** — reconciliation tombstones and remints the subtree as a *side effect*; nothing in the intent resembles deleting, and the word `remove` is never typed.
- a full-list push whose items **change depth** — matching is defeated entirely, so every id is recreated.

`aperas insert <node-id> --after/--before <anchor>` with **no stdin piped** repositions that exact node — the anchor's current parent becomes its new parent, cross-parent moves included. It preserves the id, every backlink to it, and its place in history. Reach for anything else only when the wording is changing enough that it is genuinely not the same item any more — and even then, a move followed by a separate `--text-only` edit keeps the id while changing only what actually changed.

Zero backlinks is not a licence. The rule also protects a node's place in history, which backlink count has no bearing on.

Caught live twice: <a name='id/BlockNode:00CGF613W800S' class='aperas-anchor aperas-id'></a> promoting two findings into a new section via `remove` + `insert` left two needlessly tombstoned orphans for a relocation a plain move would have handled with zero churn; and regrouping a flat 17-item list under three new sub-headings as a single parent-heading `update` returned `0 matched, 20 added, 17 removed`. Redone as create-headings-with-anchors, then move each item, then set the run-leader props per batch — all 17 ids survived. See *Adding an item to an existing list* (Mechanics) for the matching promise this rule constrains.

#### Citation direction <a name='id/BlockNode:00CGF613W800T' class='aperas-anchor aperas-id'></a>

The concerns form an abstraction gradient — `design` most abstract, `discussion` least, `issues`/`planning`/`history` between. A citation may point **up** the gradient or **sideways** freely. It may not point **down**: a design block does not reference a discussion block, for the same reason a node carries a parent pointer rather than a list of children.

The sanctioned exception is a **normative, singular** pointer — one whose target is the block's whole referent rather than one of many possible mentions. A design doc's own `# Context` section is the familiar instance (one link per facet, a fixed set), but it is the *property* that is sanctioned, not that location: a history milestone announcing one snapshot, or a design block naming *the* canonical exemplar, qualify the same way.

The test is whether removing the link leaves the block **incomplete**. A milestone whose content is "this snapshot was taken" no longer says what it exists to say once its pointer is gone; "here is a discussion that also touched on this" loses only enrichment, and stays forbidden. What the rule is actually against is a *list of children* — unbounded, discretionary, accumulating — so cardinality is the real criterion and direction is only its usual symptom.

#### Every claim carries its source <a name='id/BlockNode:00CGF613W800X' class='aperas-anchor aperas-id'></a>

Philosophy's evidence rule, as something to do. Before leaving any text in a formal doc — `issues`, `design`, `planning`, `history` — check that each claim in it can be traced: provenance first, and every other relationship the text carries alongside it, each reified as a real link rather than described in prose. Then run `aperas backlinks <id> --text` on **what you just wrote**, not only on what you are about to read. A node whose claims rest on nothing returns nothing, and that silence is the entire signal.

Direction decides which end the link lives at, never whether it exists. When a finding crystallizes *up* out of `discussion` into `issues`/`design`/`planning`/`history`, the new entry cannot cite the discussion entry it came from — that is a down-citation. So the link is added at the **origin** instead: the discussion entry gains "promoted to `issues/<concern>.md`" with a real wikilink, pointing up. The provenance then surfaces from the new entry's side for free, as a backlink.

**This is a property of the claim, not a step in the promotion ritual.** An edit that adds supporting evidence to an entry already sitting in the doc is not a promotion, and is covered exactly the same. Caught live: a planning entry was edited to cite three recorded observations and came out with `links: 0` — complete-looking from its own side, caught only when a reader ran `backlinks` on it. The same unguarded gap passed an inferred version number written as recorded fact, and a paraphrase set in quotation marks as though it were a logged prompt. Every mechanical check in this file passed on that edit; all of them ask whether the write landed, none asks whether what was written is true.

A formal doc whose entries paraphrase confirmed findings without linking them reads as complete from its own side — nothing about it looks unfinished — while `aperas backlinks` on every one of its entries returns nothing, and the provenance survives only in the head of whoever filed it. Caught live: seven issues compiled into a new concern doc from findings recorded across four different discussion docs, every origin left unlinked, noticed only by direct user callout.

This is the topology half of crystallization, stated at Philosophy above: a relationship first mediated by a discussion node becomes a direct citation once it proves load-bearing.

#### The dense-linking pass <a name='id/BlockNode:00CGF613W8012' class='aperas-anchor aperas-id'></a>

Occasionally, and deliberately, work the relationships instead of the content. Bring distant nodes into one view, then take each pair in turn and ask whether a real, nameable dependency exists. If one does and a plain citation carries it, link directly, respecting direction. If stating it takes judgment, write a mediating discussion node that cites both ends and holds the reasoning in its own text.

The counterweight matters as much as the practice: <a name='id/BlockNode:00CGF613W8013' class='aperas-anchor aperas-id'></a> **do not manufacture links.** Two docs sharing a corpus, or sharing vocabulary, is not a dependency. The test is whether you can say in one sentence what one owes the other. A pass that adds twenty weak links has made the graph harder to traverse, not denser — deep read now descends into noise.

Run it when a concern set has grown without anyone standing back from it, when two concerns keep coming up together, or when one finding turns out to have been recorded in several places independently. That last case is itself the evidence: the relationship existed and nothing captured it.

#### A view is per-task, not per-session <a name='id/BlockNode:00CGF613W8015' class='aperas-anchor aperas-id'></a>

Orientation's rule is that a view left pointing at last session's work is worse than no view. The practice that follows: re-unfold as the task's scope moves, and treat any view you did not open yourself as unknown until checked. `aperas tree --view <name>` renders whatever was unfolded whenever, with nothing marking age, so an inherited view looks identical to one built for the question actually in front of you.

Cheapest discipline is a named view per task rather than one long-lived default — creating one is a single call, and a view scoped to the task documents its own contents. The cleanup gap underneath this is real and tracked: nothing prunes a view's `unfolds` against what is still live (`issues/treeview.md`), so stale refs accumulate silently in any view kept across tasks.

#### Discussion is where meta-info is born <a name='id/BlockNode:00CGF613W8017' class='aperas-anchor aperas-id'></a>

Not a sink for what didn't fit elsewhere. `discussion` is the Apeiron-equivalent concern: unbound, schema-free, where every comment, assertion and reasoning trace originates before anything is decided about where — or whether — it belongs elsewhere. `design`/`issues`/`planning`/`history` are Peras: typed projections that specific *kinds* of content get promoted into, once a dedicated home for that kind has actually been designed. Most things never need promoting at all.

So something surfacing mid-task that isn't what the task is about — an engine bug found while migrating docs, say — starts in *this* task's discussion doc and stays there for as long as no dedicated home exists, possibly indefinitely. The test is not "is there an existing doc this could plausibly belong to" but "has a dedicated home for this actually been designed yet". Confirmed wrong live: two parser bugs were filed straight into `issues/packaging.md` on the assumption a finding needs an immediate formal home — wrong twice over, since packaging wasn't even the right eventual concern, and since reaching for promotion skipped the point of having a discussion sink at all.

See `design/documentation.md` for the concern taxonomy and the Freeflow document shape (an unbounded *list*, not a growing set of headings).

---

### 4. Mechanics <a name='id/BlockNode:00CGF613W801B' class='aperas-anchor aperas-id'></a>

This section describes the usage of the `aperas` CLI. For detailed syntax, see `aperas --help` and `aperas <verb> --help`.

#### Paths <a name='id/BlockNode:00CGF613W801C' class='aperas-anchor aperas-id'></a>

Paths passed to `aperas project`/`ingest`/etc. resolve relative to the graph's `artifacts` root defined in `aperas.config.json`, e.g., `discussion/foo.md` relative to `AperasKG/artifacts/`, **not** the repo-relative `AperasKG/artifacts/discussion/foo.md` that `git status` and `find` print. The repo-relative form fails with "No ingested ArtifactNode or FolderNode found".

#### Wikilink syntax <a name='id/BlockNode:00CGF613W801D' class='aperas-anchor aperas-id'></a>

The resolver only recognizes a URL that is `[[code]]`, starts with `aperas://tree/` or `aperas://id/`, or contains a bare `#fragment`/`path#fragment`. A plain `../folder/file.md/Slug` reference (no `#`) renders fine as prose but is **not** a graph `Link` — `aperas backlinks` on it comes back empty. Use `[title](../folder/file.md#id/BlockNode:<ID>)`.

Verify with `aperas backlinks BlockNode:<ID> --text` against the specific target block, not the whole-document path. Do not trust a command's own reported link-resolution count; a real backlink appearing is the proof. A link written without a `#fragment` silently creates nothing at all, and the ingest summary will not mention it.

#### Anchor placement — the bold-colon rule <a name='id/BlockNode:00CGF613WG000' class='aperas-anchor aperas-id'></a>

A list item's lead-in colon must sit *outside* any bold span: `**Term**:`, never `**Term:**`. A bold-wrapped colon is rejected by the lead-in detector, so anchor insertion falls through to the next plain-text colon it finds — which can splice an anchor into the middle of unrelated text, such as a link's own title.

#### Sketching a structure <a name='id/BlockNode:00CGF613WG001' class='aperas-anchor aperas-id'></a>

A new heading or subtree can be built directly in the graph, with no disk authoring: create a placeholder node with `aperas resolve --create-holder <path> --titles <title> [<title>...]`, then *fill* the real content in with `aperas update` and `aperas insert`. This is why a genuinely new document never requires the disk-first path.

#### `--after`/`--before` anchors <a name='id/BlockNode:00CGF613WG002' class='aperas-anchor aperas-id'></a>

The anchor must be a **direct child** of `<path>`, not a descendant. `aperas insert <path> --after <anchor>` fails with "anchor is not a child of X" otherwise. A heading's own text and its nested list are two different levels. Check the real structure first — `aperas tree --depth <n>`, or `scripts/show_node.py --children <ref>` — rather than guessing.

Be aware this failure is not clean: <a name='id/BlockNode:00CGF613WG003' class='aperas-anchor aperas-id'></a> the new nodes are hydrated into the store *before* the anchor is validated, so a rejected insert leaves live orphans in memory that can collide with your retry. `aperas reload -- --discard` clears them.

#### Updating a heading — `--text-only` <a name='id/BlockNode:00CGF613WG004' class='aperas-anchor aperas-id'></a>

A heading-target `update` **without** `--text-only` reconciles children too, even from an empty body: piping just `## Pending Tasks` with no body reconciles 0 piped children against N existing ones as *all removed*, tombstoning real content. `--text-only` overwrites just `.text`/`.title` and skips reconciliation entirely — that is what makes a retitle safe.

#### Adding an item to an existing list <a name='id/BlockNode:00CGF613WG005' class='aperas-anchor aperas-id'></a>

Target the list's **parent heading** — `aperas update <heading-id>` — and pipe the heading line plus the *complete* corrected list, every existing item verbatim plus the new one. Exact-key matching reuses every unchanged item's id (`N matched`, only the new one `added`).

**That promise holds only while every item keeps its parent and its depth.** A push that moves items to a new depth — regrouping a flat list under fresh sub-headings, say — matches nothing and recreates everything; use moves for that instead (see *Preserve identity*, Discipline).

**This only works if the piped content is genuinely complete.** Piping the heading plus *only* the new item reconciles the existing ones away as removed. Hit live on a 4-link Dashboard expecting a one-line addition: the actual summary was `0 matched, 0 added, 5 removed`.

For an **ordered** list this is the only safe route, because a freshly inserted item becomes its own run-leader and can restart the numbering rather than continuing it.

For an unordered list, `aperas insert <parent> --after <existing-item>` piping a bare `- item` line is safe: <a name='id/BlockNode:00CGF613WG009' class='aperas-anchor aperas-id'></a> no live `list`-typed node remains in the graph to mistakenly target. Should you meet an item nested inside a wrapper list anyway, promote it out with `aperas insert <item-id> --after <existing-direct-child-of-the-list>` and `aperas remove` the emptied wrapper.

Two input rules apply either way: <a name='id/BlockNode:00CGF613WG00A' class='aperas-anchor aperas-id'></a> pipe the bare content, **never** the ordinal marker (a leading `3.` alone makes the parser read it as a fresh list), and **never** plain text with no bullet marker (it parses as a `paragraph`, breaking a contiguous run in two).

Known cosmetic consequence: <a name='id/BlockNode:00CGF613WG00B' class='aperas-anchor aperas-id'></a> a freshly inserted item carries its own explicit `orderedList`/`startIndex`, marking it a run-leader and rendering a spurious blank line before it. Not corruption — see `issues/list-consumption.md`.

#### Renaming <a name='id/BlockNode:00CGF613WG00C' class='aperas-anchor aperas-id'></a>

**One artifact**: `git mv old.md new.md`, then `aperas ingest <new-path> --track --flush` scoped to that concern set — not a full path-less sweep, which walks the entire `artifacts/` tree including `archive/` and can hit collisions in never-swept legacy content. Rename detection matches by exact abstract-text equality against tracked ArtifactNodes whose recorded path vanished. Don't trust the "N renamed" summary; confirm the ids actually survived at the new path.

A file rename touches no content. If the H1 needs retitling too, that is a separate `aperas update` on the H1 with `--text-only`.

**A set of cross-referencing docs**: <a name='id/BlockNode:00CGF613WG00E' class='aperas-anchor aperas-id'></a> do every content fix first — H1 retitles, cross-reference paths — *while the files are still at their old names*, verify, then `git mv` each. That way every call in the content-fixing phase resolves against paths that still exist, and the rename becomes a purely mechanical last step.

#### Shell quoting <a name='id/BlockNode:00CGF613WG00F' class='aperas-anchor aperas-id'></a>

A piped `echo "..."` silently drops nested double quotes — that is bash, not `aperas`. Bash closes the outer string at the first inner `"` and reopens after it, dropping both marks with no error from anything. Caught live: `not merely "wherever convenient"` had silently become `not merely wherever convenient`. Write content containing double quotes to a file first and `cat` it in.

#### Service state <a name='id/BlockNode:00CGF613WG00G' class='aperas-anchor aperas-id'></a>

`aperas service restart` flushes and reloads from the on-disk mirror — the clean way to confirm what you think landed actually did. `aperas reload -- --discard` throws away in-memory state and re-reads disk, which is the recovery when a failed call has left orphans behind.

If the service has died, an unflushed mutation is gone. Flushing per step (above) is what makes this survivable.

#### Inspecting raw node state <a name='id/BlockNode:00CGF613WG00J' class='aperas-anchor aperas-id'></a>

`aperas tree`/`backlinks --text`/`unfold` all show a *rendered preview* — title plus truncated, anchor-stripped abstract. For a field they never show (`props`, `tombstonedAt`) or for a block's exact stored text, use the bundled reader rather than writing another one:

```bash
scripts/show_node.py <ref>                 # full record: props, tombstonedAt, parent, children, links
scripts/show_node.py --text <ref>          # exact stored text, undecorated
scripts/show_node.py --children <ref>      # direct children, tombstoned ones marked
scripts/show_node.py --grep PATTERN [-i]   # full-text search — there is no `aperas search`
scripts/show_node.py --artifact <ref>      # which artifact a block lives in
```

Refs take a bare snowflake or a full id. It is read-only, and it locates `AperasKG/Apeiron/` itself.

It reads the **on-disk mirror**, so after an unflushed mutation it reports pre-flush state while `aperas unfold`/`tree` report the live service's. Flush first, or ask the CLI, when checking something you just changed. Caught live: a move and a tombstone were both invisible to it, producing a confident and wrong conclusion that the move had gone backwards.

`--text` is the one that matters before an edit: <a name='id/BlockNode:00CGF613WG00P' class='aperas-anchor aperas-id'></a> redirect it to a file, change only what needs changing, and `cat` that back into `aperas update`. That keeps the untouched part of a block byte-identical instead of retyped from a preview — which is what step 2 of the edit loop warns about, since a transcription slip silently tombstones the block and mints a new id.

#### Checking the skill against its own record <a name='id/BlockNode:00CGF613WG00Q' class='aperas-anchor aperas-id'></a>

`SKILL.md` is a *generative* projection of its concern — authored from design rather than serialized by a command — so unlike an `aperas project` artifact it can drift from its source with nothing detecting it. `scripts/skill_drift.py` compares the file against the graph's record of it (the latest snapshot plus the deltas above it):

```bash
scripts/skill_drift.py              # both directions
scripts/skill_drift.py --added      # written into the file, never recorded
scripts/skill_drift.py --dropped    # recorded, no longer in the file
```

A delta entry that replaces rather than adds carries a `Supersedes: [title](#id/BlockNode:...)` line naming the item it retires, which is what lets the check tell a deliberate rewrite from a silent loss.

Run it after editing this file, before considering the edit done. *Added* is the check that matters most — an edit made and not recorded is invisible from the file's own side, which is how three separate additions in one session went unrecorded until a reader noticed. *Dropped* catches the opposite: v1 silently lost one of v0 item 18's three triggers, and nothing flagged it. The *added* side compares each unit in full — one unit per list item, since a list containing even one superseded item no longer appears contiguously in any single record — so a rewording anywhere in a unit is caught. The *dropped* side still matches on a prefix and is correspondingly weaker.

This is a staging area, not the fix: <a name='id/BlockNode:00CGF613WG00V' class='aperas-anchor aperas-id'></a> the real gap is tracked in `issues/treeview.md` ("No raw single-node inspection command"), whose proposed resolution is an `aperas show <ref>` verb. `--children` marking tombstones is likewise standing in for `unfold`'s missing marker.

Specifically, **`unfold` does not mark tombstoned children** while `tree --view` appends `(tombstoned)`, so a tombstoned leftover can read as live data under `unfold`. Tracked in `issues/treeview.md`.

#### Full-text search — grep the raw store directly <a name='id/BlockNode:00CGF613WG00X' class='aperas-anchor aperas-id'></a>

`show_node.py --grep` works, but a plain `grep -n -C3 '<pattern>' AperasKG/Apeiron/BlockNode.jsonld` is faster and shows more: one command, the complete untruncated `text` (the script's own preview caps at 90 chars), and it also works over `ArtifactNode.jsonld` for an artifact's own title/abstract — which `--grep` never scans, since it only iterates blocks. This is not the shadow-grepping mistake the Philosophy example warns about: `Apeiron/*.jsonld` is the on-disk mirror of the graph itself, not the rendered `artifacts/*.md` projection, so grepping it is reading the source, not the shadow.

A hit is a candidate id, not proof of anything. Confirmed live: a node's field order is `@id, @type, [props], [tombstonedAt], title, text, parent, type, children`, and `props` is variable-length — so `tombstonedAt`'s distance from a `text` match shifts per node, and no fixed `-C<n>` window can be trusted to surface it. Treat every match as an id to hand to `aperas` (`unfold`/`tree`/`backlinks --text`) for the actual live/tombstoned status, parent, and links: grep finds the nodes, `aperas` deals with them.

#### Comparing distant docs — the view as a lens <a name='id/BlockNode:00CGF613WG00Z' class='aperas-anchor aperas-id'></a>

`--view` is not a bookmark list; it is the mechanism for putting nodes that sit far apart in the tree next to each other. Unfold every doc being compared into one view, then render it once:

```bash
for f in issues/a.md discussion/b.md design/c.md; do
  aperas unfold "$f" --view <name> --flush
done
aperas tree --view <name>
```

Run `aperas backlinks <id> --text` on a target before adding a link to it — working across several docs at once makes it easy to add a citation that already exists. And note that a link resolves by its `id/` fragment: the leading relative path is for the human reader, so a stale path still resolves correctly while misleading anyone who reads it. Observed live renaming a concern — every fragment kept working, every path string had to be fixed by hand.

---

### Reference <a name='id/BlockNode:00CGF613WG013' class='aperas-anchor aperas-id'></a>

- `AperasKG/artifacts/design/linking.md` — canonical spec for addressing, anchors and wikilink syntax. Read it when a link isn't resolving and the reason isn't obvious.
- `AperasKG/artifacts/design/documentation.md` — the concern taxonomy and the Freeflow document shape.
- `AperasKG/artifacts/design/aperas-skill.md` — this skill's own design: <a name='id/BlockNode:00CGF613WG016' class='aperas-anchor aperas-id'></a> the four levels, citation direction, and how items enter (incident → freeflow → confirmed → promoted to the level that explains it).
- `archive/Aperas-design.md` — the founding philosophy: <a name='id/BlockNode:00CGF613WG017' class='aperas-anchor aperas-id'></a> Apeiron/Aperas/Peras, deep read and deep write, Meta-Aperas.

#### Open tool gaps <a name='id/BlockNode:00CGF613WG018' class='aperas-anchor aperas-id'></a>

Tracked in the graph rather than accumulating here: raw single-node inspection and `unfold`'s missing tombstone marker (`issues/treeview.md`); non-transactional writes leaving in-memory orphans, and `extractAnchorNames` treating a quoted example anchor as a real name claim (`discussion/aperas-skill.md`).

## v2.1 additions — delta on the v2 snapshot <a name='id/BlockNode:00CGMY04AG001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v2 snapshot](#id/BlockNode:00CGF613VR001), one changed unit plus the status bump. Reasoning: this is exactly the kind of gap Philosophy already names — a claim that reads as complete from its own side while its provenance is silently gone — but the loop's own verification step never named it as a live risk against links specifically, only against tombstoned-id reuse. Two confirmed live incidents in the same session (see [discussion/linking.md](../discussion/linking.md#id/BlockNode:00CGMX88R0001)) made it clear the omission wasn't hypothetical.

### Discipline — verify by traversal now names links as its sharpest instance <a name='id/BlockNode:00CGMY04AG002' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own "Verify by traversal" item](#id/BlockNode:00CGF613W8006)

**Verify by traversal, not by the summary line.** A reconcile count reports what the command *believes* it did. Proof is a backlink that actually resolves, or `aperas project <path> --dry-run` where the content is actually visible. A push can silently match new content onto an already-tombstoned node's id without reviving it, so it stays invisible while the summary reports it as added — caught live when a Resolved section rendered one fewer bullet than was pushed. Links are the sharpest instance of this, not a special case: a write whose text carries a real citation can report `"N resolved"` and still leave `.links` empty afterward, with nothing else — not the summary, not a plain preview, not the projected file — showing any sign of it. Confirmed live twice in one session, by two unrelated mechanisms: a graph-wide staleness sweep found 9 nodes whose links had silently never resolved at all, and a separate incident later the same session watched four freshly-`"resolved"` links vanish from nodes that had just been moved and re-texted. Treat a link-bearing write as unverified until `aperas show <id>` (or `aperas backlinks <id> --text` from the other end) actually shows the `Link`, the same way step 6 already treats a plain content write as unverified until traversal confirms it. See `issues/linking.md` for the open, still-uninvestigated half of this.

### Top matter — Status bumped to v2.1 <a name='id/BlockNode:00CGMZAPCR001' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own status line](#id/BlockNode:00CGF613VR002)

Status: <a name='id/BlockNode:00CGMZAPCR002' class='aperas-anchor aperas-id'></a> **v2.1** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

## v2.2 additions — delta on the v2 snapshot <a name='id/BlockNode:00CGN8W9M8001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v2 snapshot](#id/BlockNode:00CGF613VR001), same day as v2.1: the toolset changes v2.1 itself landed (`aperas show`, tombstone hiding, bare-`unfold` peek, `pruneStaleUnfolds`, the run-leader fix) were never folded back into the file's own Mechanics section until now, leaving it describing tools by their pre-fix state right next to a Discipline item written in the post-fix one.

### Top matter — Status bumped to v2.2 <a name='id/BlockNode:00CGN8W9M8002' class='aperas-anchor aperas-id'></a>

Supersedes: [v2.1's own status heading](#id/BlockNode:00CGMZAPCR001) and [its status line](#id/BlockNode:00CGMZAPCR002)

Status: <a name='id/BlockNode:00CGN8W9M8003' class='aperas-anchor aperas-id'></a> **v2.2** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Mechanics — inspecting raw node state now leads with `aperas show` <a name='id/BlockNode:00CGN8W9MG000' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own raw-node-state section](#id/BlockNode:00CGF613WG00K), [its refs line](#id/BlockNode:00CGF613WG00M), [its on-disk-mirror caveat](#id/BlockNode:00CGF613WG00N), [its staging-area framing](#id/BlockNode:00CGF613WG00V)

`aperas tree`/`backlinks --text`/`unfold` all show a *rendered preview* — title plus truncated, anchor-stripped abstract. For a field they never show (`props`, `tombstonedAt`) or for a block's exact stored text, `aperas show <ref>` goes through the live service, so — unlike a raw-file reader — it always reflects the current in-memory state, not the last flush:

```bash
aperas show <ref>            # full record, exactly as stored: props, tombstonedAt, parent, children, links, title, text
aperas show <ref> --text     # exact stored text only, undecorated
```

`--text` is the one that matters before an edit: <a name='id/BlockNode:00CGNAAC40001' class='aperas-anchor aperas-id'></a> redirect it to a file, change only what needs changing, and `cat` that back into `aperas update`. That keeps the untouched part of a block byte-identical instead of retyped from a preview — which is what step 2 of the edit loop warns about, since a transcription slip silently tombstones the block and mints a new id.

`scripts/show_node.py` still covers what `aperas show` doesn't — `--grep PATTERN` (full-text search; there is still no `aperas search`) and `--artifact <ref>` (which artifact a block lives in). It reads the **on-disk mirror**, so after an unflushed mutation it reports pre-flush state while `aperas show`/`unfold`/`tree` report the live service's. Flush first, or ask the CLI, when checking something you just changed. Caught live once, before `aperas show` existed: a move and a tombstone were both invisible to the script, producing a confident and wrong conclusion that the move had gone backwards.

### Mechanics — bare `unfold` is a peek, `--view <name>` still mutates <a name='id/BlockNode:00CGN8W9MG002' class='aperas-anchor aperas-id'></a>

A bare `aperas unfold <ref>` (no `--view` flag at all) is a read-only peek: it resolves and previews `<ref>` without touching any `TreeView` state, matching `aperas tree`'s own no-`--view` default. `--view <name>` (a name actually given) still bootstraps that view — minting the `"default"` one and its owning `Profile` on first use — and adds `<ref>` to its `unfolds` set, which is what a later `aperas tree --view <name>` actually renders. `--view` supplied with no name following it behaves the same bootstrap-and-mutate way as naming `"default"` explicitly; only the flag's outright absence peeks.

### Discipline/Mechanics — tombstoned nodes hidden by default, not just tagged <a name='id/BlockNode:00CGN8W9MG003' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own "unfold doesn't mark tombstoned children" gap note](#id/BlockNode:00CGF613WG00W)

`aperas tree` and `aperas unfold` both hide a tombstoned node — and its whole subtree, since there is nothing live left under it to reveal — from their default output, tagging it `(tombstoned)` only once `--tombstoned` is passed. `aperas unfold` additionally refuses to unfold a tombstoned node directly without the flag, with a clear error, rather than returning something that looks like an empty success. A node reached only through a still-live `Link` elsewhere is exactly as hidden as one reached structurally — the flag controls visibility, not the traversal path that found it.

### Mechanics — the view-cleanup gap is closed <a name='id/BlockNode:00CGN8W9MG005' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own "nothing prunes a view's unfolds" line](#id/BlockNode:00CGF613W8016)

Cheapest discipline is a named view per task rather than one long-lived default — creating one is a single call, and a view scoped to the task documents its own contents. `unfold` now refuses a ref with no quads at all at write time, and an explicit sweep (`aperas reload`, service shutdown) strips any `unfolds` entry that's gone stale since — but a tombstoned-yet-present target is left alone by both, since it's a legitimate, revealable-via-`--tombstoned` entry, not a stale one.

### Mechanics — the run-leader cosmetic issue is fixed for the common case <a name='id/BlockNode:00CGN8W9MG007' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own "known cosmetic consequence" note](#id/BlockNode:00CGF613WG00B)

Fixed for the common case: <a name='id/BlockNode:00CGN8W9MG008' class='aperas-anchor aperas-id'></a> `aperas insert` now clears a freshly-parsed lone item's own `orderedList`/`startIndex` when it lands next to a plain continuation item (no run-leader props of its own), so it silently joins that run instead of starting a spurious new one. Landing right before or after an item that *is* itself a run-leader still carries its own props and renders a spurious blank line — not corruption, a narrower remaining case — see `issues/list-consumption.md`.

### Reference — open tool gaps, refreshed <a name='id/BlockNode:00CGN8W9MG009' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own open-tool-gaps line](#id/BlockNode:00CGF613WG018)

Tracked in the graph rather than accumulating here: <a name='id/BlockNode:00CGN8W9MG00A' class='aperas-anchor aperas-id'></a> links silently failing to persist or resolve, confirmed twice in one session by unrelated mechanisms, with nothing detecting either automatically (`issues/linking.md`); `aperas resolve`'s title-ambiguity check not filtering tombstoned candidates, so a dead holder can still make a live path read as ambiguous (`discussion/core.md`'s Freeflow); a pre-existing, unreproduced `verify.ts` failure in the id-anchor emission idempotency check for list items/paragraphs (`planning/linking.md`'s Task Breakdown).

## v2.3 additions — delta on the v2 snapshot <a name='id/BlockNode:00CH5FJMDR001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v2 snapshot](#id/BlockNode:00CGF613VR001). Reordering and clarification of the Mechanics section for inserting and updating list items, to explicitly warn against a newly discovered failure mode where updating an existing list item by piping a bulleted string accidentally nests it (by replacing its children with a new list, rather than adopting a bare paragraph's text).

### Top matter — Status bumped to v2.3 <a name='id/BlockNode:00CH5FJMDR002' class='aperas-anchor aperas-id'></a>

Supersedes: [v2.2's own status line](#id/BlockNode:00CGN8W9M8003)

Status: <a name='id/BlockNode:00CH5FJMDR003' class='aperas-anchor aperas-id'></a> **v2.3** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Mechanics — list manipulation section rewritten <a name='id/BlockNode:00CH5FJME0000' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own "Adding an item to an existing list" heading](#id/BlockNode:00CGF613WG005), [its depth caveat](#id/BlockNode:00CGF613WG006), [its ordered-list safe-route paragraph](#id/BlockNode:00CGF613WG008), [its unordered list instruction](#id/BlockNode:00CGF613WG009), [its input-rules paragraph](#id/BlockNode:00CGF613WG00A), and [v2.2's run-leader fix](#id/BlockNode:00CGN8W9MG008).

### Inserting an item into an existing list <a name='id/BlockNode:00CH5FJME0001' class='aperas-anchor aperas-id'></a>

For an **unordered** list, the safest and cleanest route is to insert the new item directly as a sibling of an existing one: `aperas insert <parent> --after <existing-item>`.

- **The input rule**: <a name='id/BlockNode:00CH5FJME0002' class='aperas-anchor aperas-id'></a> Pipe the bare item text **with its bullet marker** (e.g. `- new item`).
- **Never pipe plain text** with no bullet: <a name='id/BlockNode:00CH5FJME0003' class='aperas-anchor aperas-id'></a> it parses as a `paragraph`, which breaks a contiguous list run in two.
- Should you meet an item nested inside a wrapper list, promote it out with `aperas insert <item-id> --after <existing-direct-child-of-the-list>` and `aperas remove` the emptied wrapper.

For an **ordered** list, direct insertion is riskier because a freshly inserted item becomes its own run-leader and can restart the numbering rather than continuing it. (Though a recent fix clears this for the common case of landing next to a plain continuation item, landing next to a run-leader still renders a spurious blank line). 
The safer route for ordered lists is to target the list's **parent heading** (`aperas update <heading-id>`) and pipe the heading line plus the *complete* list (every existing item verbatim plus the new one).

- Exact-key matching reuses every unchanged item's id, **but only while every item keeps its parent and depth**. A push that changes item depth (e.g. regrouping under sub-headings) recreates everything; use `aperas insert` (moves) for that instead.
- **This only works if the piped content is genuinely complete.** Piping the heading plus *only* the new item reconciles the existing ones away as removed, tombstoning real content.

### Updating an existing list item <a name='id/BlockNode:00CH5FJME8001' class='aperas-anchor aperas-id'></a>

To update the text of an *existing* list item without changing its identity, use `aperas update <item-id>`.

- **The input rule**: <a name='id/BlockNode:00CH5FJME8002' class='aperas-anchor aperas-id'></a> Pipe the bare text **without any bullet marker** (e.g. `updated text`, never `- updated text`).
- **Explanation**: <a name='id/BlockNode:00CH5FJME8003' class='aperas-anchor aperas-id'></a> The target node is already a `listItem`. If you pipe a `- `, the parser sees a *new list*, and `update` will replace the existing item's children with this new list, resulting in a nested list rendering bug (`- - updated text`). By piping bare text, it parses as a paragraph, and `update` correctly adopts its text into the existing list item.

## v2.4 additions — delta on the v2 snapshot <a name='id/BlockNode:00CHXVEW98001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v2 snapshot](#id/BlockNode:00CGF613VR001). This round is a correctness/completeness pass, not new discipline: a user-requested review of the GC-persistence and link-integrity-check fixes found both incomplete on first landing, fixed for real here, plus the frontmatter reformat (`>-` block scalar) that had never been re-recorded since it landed.

### Top matter — frontmatter reformatted, never re-recorded until now <a name='id/BlockNode:00CHXVP090001' class='aperas-anchor aperas-id'></a>

Supersedes: [v2's own frontmatter block](#id/BlockNode:00CGF613VR002)

```
---
name: aperas
description: >-
  Before anything else in this project — first turn, every session, whatever the task looks like,
  including when it looks unrelated, trivial, read-only, or like one quick lookup — check memory
  for a standing decision on whether Aperas manages this session. Do this without loading this
  skill, and never ask permission to do it or offer it as an option; just do it. If a decision
  is recorded, follow it. If none is, ask with AskUserQuestion using exactly these choices —
  Never / Not now / Yes, this session only / Yes, all sessions — and record only 'all sessions'
  or 'never' durably, so a session-scoped answer is asked again next session. Load this skill
  only once the answer is yes; it then governs the work — orient in the graph before acting,
  change it through the CLI rather than by editing files, put back what the work turns up.
  Aperas is this project's external memory: a knowledge graph, worked through the `aperas` CLI,
  holding what has been decided, tried, found and planned. For first-time ingest of existing
  documents, `kg-doc-ingest` covers that; this one first.
---

```

### Reference — open tool gaps, refreshed again <a name='id/BlockNode:00CHXVT8BR001' class='aperas-anchor aperas-id'></a>

Supersedes: [v2.2's own open-tool-gaps line](#id/BlockNode:00CGN8W9MG00A)

Tracked in the graph rather than accumulating here: <a name='id/BlockNode:00CHXVWW68002' class='aperas-anchor aperas-id'></a> `aperas resolve`'s title-ambiguity check not filtering tombstoned candidates, so a dead holder can still make a live path read as ambiguous (`discussion/core.md`'s Freeflow). The link-integrity drift check this list used to name as missing is built and live (`aperas check-links`, see *Mechanics* — `issues/linking.md`); the `verify.ts` id-anchor emission idempotency failure this list used to name as unreproduced is also fixed and passing (`discussion/core.md`).

### Mechanics — `aperas check-links` documented <a name='id/BlockNode:00CHXVYA0R001' class='aperas-anchor aperas-id'></a>

Answers exactly the question dense linking depends on and nothing else routinely checks: does every internal-style reference a live block's text actually names (`[[code]]`, `aperas://...`, `path#fragment`) have a matching resolved `Link` in that block's own `.links`? `aperas check-links` reports discrepancies; `aperas check-links --repair` re-resolves and flushes them in the same call. It resolves each occurrence for real (the same dispatch `kg:update`/`kg:insert` themselves use, read-only here — never mints a placeholder as a side effect of a scan) rather than guessing from the text, so it correctly stays silent on a code that simply doesn't resolve yet (routine, or already tracked separately as a dangling reference) and only flags a code that resolves to a live target with nothing to show for it in `.links` — the exact, previously-invisible failure mode this tool exists for.

### Top matter — Status bumped to v2.4 <a name='id/BlockNode:00CHXW4S30001' class='aperas-anchor aperas-id'></a>

Supersedes: [v2.3's own status line](#id/BlockNode:00CH5FJMDR003)

Status: <a name='id/BlockNode:00CHXW6FY0002' class='aperas-anchor aperas-id'></a> **v2.4** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

## v2.5 additions — delta on the v2 snapshot <a name='id/BlockNode:00CHYJ6PR8001' class='aperas-anchor aperas-id'></a>

Threaded onto [the v2 snapshot](#id/BlockNode:00CGF613VR001). v2.4 documented `aperas check-links` as a tool with no discipline attached to it, which left the check in exactly the position this skill's own Philosophy warns against — available, correct, and dependent on somebody remembering to ask. Resolved by moving two of the three checks out of discipline entirely and into the service, leaving only the one an agent genuinely has to run. Measured before designing: a corpus-wide sweep is ~0.6s of service-side work (1428 live blocks, 358 carrying link text), so "too expensive to run often" — the premise the first cut of this design rested on — was simply false.

### Top matter — Status bumped to v2.5 <a name='id/BlockNode:00CHYJB998001' class='aperas-anchor aperas-id'></a>

Supersedes: [v2.4's own status line](#id/BlockNode:00CHXW6FY0002)

Status: <a name='id/BlockNode:00CHYJDBR8000' class='aperas-anchor aperas-id'></a> **v2.5** — four levels, Philosophy through Mechanics, each item explaining a consequence of the one above it. Only current, verified items appear here; superseded material, unverified hypotheses and version-by-version rationale live in `discussion/aperas-skill.md`'s snapshot and deltas. Concern docs: `AperasKG/artifacts/{design,issues,planning,history,discussion}/aperas-skill.md`.

### Discipline — the end-of-batch sweep, and the two checks that need nothing from you <a name='id/BlockNode:00CHYJEXVR001' class='aperas-anchor aperas-id'></a>

**At the end of a batch — not after each step — run `aperas check-links` once before handing back.** The per-write check the service runs on its own only sweeps the artifact that was written; this is the pass that catches the damage that lands *elsewhere* — an edit in artifact A breaking a citation that lives in artifact B, which nothing scoped to A can see. It costs about 0.6s against the whole corpus, so the reason to run it once per batch rather than per edit is noise, not expense.

The other two link checks need nothing from you, and that is the point — the two recorded losses were both found by a human happening to look, never by a check that fired. The service now sweeps the written artifact after every `update`/`insert`/`remove` and reports anything that write resolved but failed to persist, right under the write's own `Links: N resolved…` line; and it sweeps the whole corpus at startup and on `reload`, carrying any finding on *every* later response until it clears. When either one speaks up, it is describing a link that already looks fine everywhere else — treat it as real and re-run the write (which has fixed it before) or `aperas check-links --repair`.
