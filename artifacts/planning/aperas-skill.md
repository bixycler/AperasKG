---
description: Restructuring the skill in place rather than rewriting from scratch, since every existing item was paid for by a real incident.
---

# Aperas Skill — Planning <a name='id/BlockNode:00CEA5M6S8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CEA5M6S8002' class='aperas-anchor aperas-id'></a>

Restructure in place rather than rewriting from a blank file. Every existing item was paid for by a live incident, so the content is the asset and the arrangement is the defect — a fresh draft would silently drop hard-won specifics that no one would notice missing until the incident recurred.

The verbatim copy already dumped into the discussion doc is the working surface for the rewrite: each item is an addressable block, so the reorganisation can be discussed and tracked by citing blocks rather than line numbers in a file that is about to move.

Order matters. The level assignment comes first and everything else follows from it, because an item's level (see [Architecture](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG003)) determines both where it lands and how it gets reworded — the same fact stated as philosophy and as mechanics is not the same sentence.

## Task Breakdown <a name='id/BlockNode:00CEA5M6S8005' class='aperas-anchor aperas-id'></a>

### Batch 1 — the v1 restructure <a name='id/BlockNode:00CFAMC7XG001' class='aperas-anchor aperas-id'></a>

Shipped as v1 through v1.3: the four-level arrangement, its examples, the scope boundary, the bundled scripts, and the first eval run.

1. [x] Assign every one of the eighteen existing items to a level — philosophy, orientation, discipline, or mechanics — by asking what explains it, not where it was first noticed. Items that split across levels get split.
2. [x] Restate the philosophy and orientation levels from the settled framing, so they read as the cause of what follows rather than as two more rules.
3. [x] Rewrite each remaining item rule-first, with its originating incident attached rather than leading.
4. [x] Mark every item's status explicitly where it stands: <a name='id/BlockNode:00CEA5M6S8009' class='aperas-anchor aperas-id'></a> confirmed-current, superseded by a landed change, or unverified.
5. [x] Harvest an example for each level in the kind that level takes — a contrast pair for philosophy, a traversal transcript for orientation, one full worked loop for discipline, a command plus its exact failure text for mechanics. Draw every one from a real recorded incident; synthesise nothing.
6. [x] Extract accumulated tool gaps out of the prose into tracked issues in the graph, leaving the skill with a pointer rather than a growing caveat list.
7. [x] Decide the scope boundary against `kg-doc-ingest` and against concern docs, and state it in the skill itself.
8. [x] Stage the repeatedly hand-written helpers as bundled `scripts/`, starting with a raw-node reader over `BlockNode.jsonld`/`ArtifactNode.jsonld` for the fields no CLI verb exposes. The skill currently instructs its own reinvention, which is the clearest possible signal the helper belongs staged rather than described. Replace that instruction with a pointer to the script, and keep the tracked toolset gap it is standing in for.
9. [x] Build the eval set from recorded incidents, run it against the v0 baseline preserved in git history, grade on objective assertions, and review the benchmark. This is what actually closes the Verification Plan; until it runs, the claim that the levels change behaviour is untested.

### Deferred from Batch 1 <a name='id/BlockNode:00CFAMC7XG003' class='aperas-anchor aperas-id'></a>

Neither is blocked; each is waiting on a condition named in its own line.

1. [ ] Defer by loading frequency once the body starts crowding: <a name='id/BlockNode:00CEDFKN30008' class='aperas-anchor aperas-id'></a> Philosophy, Orientation and Discipline stay in SKILL.md, Mechanics moves to `references/` when its bulk begins to push the levels above it out of easy reach. Not yet warranted — the body is well inside the point where deferral buys anything.
2. [ ] Measure the frontmatter description against a held-out split, since triggering decides whether any of the rest is ever read. Three observations are already on record, each seen live rather than reasoned about: two sessions on an earlier, graph-edit-shaped description that loaded the skill not at all while investigating `reconcile.ts`/`node.ts`; the description that shipped as v1.3, which still did not fire; and the reordered one, which fired on turn one for a task given as "execute AperasKG/artifacts/planning/cli.md". None of the three was ever tried against a case it had not already been fixed against, so the held-out split is what is missing, not the labelling. The should-not-trigger class needs restating too: universal scope means nothing inside this project should fail to fire, so the negative cases are cross-project ones — sessions in repositories this graph does not cover.

### Batch 2 — read-side and code-side <a name='id/BlockNode:00CFAMC7XR000' class='aperas-anchor aperas-id'></a>

Opened by the session that confirmed the skill can load, be consented to, and still not govern the work. Ordered so the rename lands first, since it is what makes the rest attachable.

1. [x] Rename `The edit loop` to the workflow it actually is, and state its entry condition — [issue](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20000). The three triggers (reading a concern, reading or changing source the graph carries a concern about, changing the graph) become the loop's own opening rather than a bolted-on subsection: one universal opening (orient), a branching tail, and a close that records whatever changed. Do this first — it is what makes the read-side and code-side rules attachable instead of appended.
2. [x] Add the read-side substitution rule at Orientation — [issue](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ1R001) — directly under "Traversal is the primary mode of work", stating that an `artifacts/**.md` path about to become an argument to `Read`/`grep`/`find`/`cat` is a node reference and `aperas unfold <ref>` is what it meant, and naming the two things deliberately not over the line: `Apeiron/*.jsonld` is the source mirror, and source code is not in the graph at all.
3. [x] State the content-case corollary at Philosophy — [issue](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20001) — as the consequence of the existing sentence that a node's meaning is constituted by what it links to, what links back, and where it sits, so the point lands as a repair of that thread rather than a new claim. Keep it at that level: Mechanics' "grep the raw store directly" is already its concrete instance and stays where it is.
4. [x] Add the code-side entry at Discipline as an obligation at both ends — [issue](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20002): before the work, find what the graph already holds about that file or subsystem; after it, record what the work found, since a fix landed with nothing written is invisible from every side that can be consulted.
5. [x] Note in Mechanics that `scripts/show_node.py` reads the on-disk mirror — [issue](../issues/aperas-skill.md#id/BlockNode:00CFA7PQ20003) — so after an unflushed mutation it reports pre-flush state, where `aperas unfold`/`tree` report the live service's.
6. [x] Record and verify: <a name='id/BlockNode:00CFA93WKG00G' class='aperas-anchor aperas-id'></a> a v1.4 delta entry per changed unit carrying a `Supersedes:` pointer and nothing else in its text, `scripts/skill_drift.py` clean in both directions, and each of the five Open Issues moved to Resolved with the actual mechanism named rather than "fixed".
7. [x] Restate the identity-preservation rule outcome-first rather than verb-first — [issue](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48001) — so it names any operation that can tombstone a node meant to be kept, a parent-heading `update` included, rather than the single verb that happened to be noticed first. Attach the missing precondition to Mechanics' exact-key-matching promise — [issue](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48002) — namely that it holds only while a node keeps its parent and depth, and leave a pointer in both directions so the two sections stop contradicting each other — [issue](../issues/aperas-skill.md#id/BlockNode:00CFB1HX48003).
8. [x] Thread provenance vertically through all four levels — [issue](../issues/aperas-skill.md#id/BlockNode:00CG9MPGVG001). At Philosophy, state that Aperas is an evidence-based documentation system in which a claim and its provenance are one object. At Orientation, name the second relationship that backward traversal already carries: the current enumeration covers dependents only, which is what deep write needs, while sources — what a claim rests on — arrive through the very same `aperas backlinks` call and have no name at all, which is why an unlinked claim reads as under-linked rather than unsupported. Provenance belongs inside context rather than against it, and wants emphasis because it is the half currently missing; `archive/Aperas-design.md` separates the two by operation instead, giving provenance to deep read and impact traversal to deep write. At Discipline, land it as a check on every written text before it is left in place: provenance and every other relationship the text carries must be reified as a link, forward where citation direction allows and as a backlink from the source where it does not. Mechanics already has the instrument (`aperas backlinks` on what was just written), and no rule yet points at it. v1.1 did exactly this repair for crystallization and dense linking; this is the same repair for the principle both were serving.

## Verification Plan <a name='id/BlockNode:00CEA5M6S800D' class='aperas-anchor aperas-id'></a>

The rewrite succeeds if an agent reading only the first two levels behaves correctly in the ordinary case — graph-first, traversal-first — without having reached any mechanics.

Two concrete checks, both available from this corpus rather than from judgement alone. First, every incident already recorded in this concern's discussion should be predictable from a statement at the philosophy or discipline level; one that isn't marks a gap at that level, not a missing gotcha. Second, the grep-instead-of-traverse failure specifically should be prevented by something a reader meets before any CLI verb appears, since that failure happened to a reader who had the rule available and still did not apply it.

The instrument for both checks is an eval loop, since neither is answerable from reading the document. Test prompts are run twice over — once by an agent holding the skill, once by a baseline agent — then graded against assertions and aggregated into a benchmark.

The baseline is the **previous version of the skill**, not the absence of one. v0 is preserved in git history, so the comparison measures the restructure itself rather than merely re-confirming that having a skill beats having none.

Prompts are harvested, not invented — real incidents already recorded in this concern's discussion supply them: the cross-reference question that produced the grep-instead-of-traverse failure, adding one item to an existing list, retitling a heading, linking two docs that resolve each other's gaps. Synthesizing a *test* is not the same as synthesizing an *example*; the harvest-don't-synthesize rule governs what goes into the document, not what probes it.

Assertions must be objectively checkable, which these are: <a name='id/BlockNode:00CEDFCMY0004' class='aperas-anchor aperas-id'></a> did the run reach for `aperas backlinks` rather than `grep`; did a heading-text edit pass `--text-only`; did a list addition push the complete list; did the ids survive a move. Anything needing human judgement stays qualitative rather than being forced into an assertion.

Trigger accuracy is measured separately and last, once the content is settled. The frontmatter description is the only part of a skill always in context, so it alone decides whether the skill is consulted at all — a property that is empirically testable against labelled should-trigger and should-not-trigger queries, with a held-out split so the wording is not merely fitted to them, rather than settled by taste.

### Status by batch <a name='id/BlockNode:00CFANC9KR001' class='aperas-anchor aperas-id'></a>

The method above applies to every batch; what differs is how far each has actually been run. A batch is not closed by having a criterion, only by having run it.

- **Batch 1 — the v1 restructure**: <a name='id/BlockNode:00CFANC9M0000' class='aperas-anchor aperas-id'></a> run, but narrower than the claim. The eval set was built, run against the v0 baseline, and caught a real bug (see History). Every prompt in it exercised graph editing, though — the one path the skill already governed — so the criterion was never tried against a read-only or code-shaped task. When one finally ran against v1.3 it failed exactly where the eval had not looked: the skill loaded, was consented to, and the whole investigation still went through the projections. Verified as far as it was tested, and the test was narrower than the claim.
- **Deferred from Batch 1**: <a name='id/BlockNode:00CFANC9M0001' class='aperas-anchor aperas-id'></a> not verified, and only one of the two is due. Deferral by loading frequency is conditional on the body crowding, which it has not. Trigger accuracy is the live one: the frontmatter description turned out to be the highest-leverage line in the file, and the version that works was reached by trial and error and confirmed at n=1 — precisely the unmeasured state its own line calls for fixing.
- **Batch 2 — read-side and code-side**: <a name='id/BlockNode:00CFANC9M0002' class='aperas-anchor aperas-id'></a> not verified. Its criterion is behavioural and objectively checkable from a transcript, in the form the assertions paragraph above requires: given a code-shaped task in this repo, with the skill loaded and no reminder given, the first access to anything under `artifacts/` is an `aperas` call rather than `Read`/`grep`/`find`, and the session records what it found before finishing. Until that runs against a held-out prompt, Batch 2 is written-but-untested — the state Batch 1 was in before its own eval was tried.
