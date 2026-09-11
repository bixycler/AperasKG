# Aperas Skill — Planning <a name='id/BlockNode:00CEA5M6S8001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CEA5M6S8002' class='aperas-anchor aperas-id'></a>

Restructure in place rather than rewriting from a blank file. Every existing item was paid for by a live incident, so the content is the asset and the arrangement is the defect — a fresh draft would silently drop hard-won specifics that no one would notice missing until the incident recurred.

The verbatim copy already dumped into the discussion doc is the working surface for the rewrite: each item is an addressable block, so the reorganisation can be discussed and tracked by citing blocks rather than line numbers in a file that is about to move.

Order matters. The level assignment comes first and everything else follows from it, because an item's level (see [Architecture](../design/aperas-skill.md#id/BlockNode:00CEA5Y5JG003)) determines both where it lands and how it gets reworded — the same fact stated as philosophy and as mechanics is not the same sentence.

## Task Breakdown <a name='id/BlockNode:00CEA5M6S8005' class='aperas-anchor aperas-id'></a>

1. Assign every one of the eighteen existing items to a level — philosophy, orientation, discipline, or mechanics — by asking what explains it, not where it was first noticed. Items that split across levels get split.
2. Restate the philosophy and orientation levels from the settled framing, so they read as the cause of what follows rather than as two more rules.
3. Rewrite each remaining item rule-first, with its originating incident attached rather than leading.
4. Mark every item's status explicitly where it stands: <a name='id/BlockNode:00CEA5M6S8009' class='aperas-anchor aperas-id'></a> confirmed-current, superseded by a landed change, or unverified.
5. Harvest an example for each level in the kind that level takes — a contrast pair for philosophy, a traversal transcript for orientation, one full worked loop for discipline, a command plus its exact failure text for mechanics. Draw every one from a real recorded incident; synthesise nothing.
6. Extract accumulated tool gaps out of the prose into tracked issues in the graph, leaving the skill with a pointer rather than a growing caveat list.
7. Decide the scope boundary against `kg-doc-ingest` and against concern docs, and state it in the skill itself.
8. Stage the repeatedly hand-written helpers as bundled `scripts/`, starting with a raw-node reader over `BlockNode.jsonld`/`ArtifactNode.jsonld` for the fields no CLI verb exposes. The skill currently instructs its own reinvention, which is the clearest possible signal the helper belongs staged rather than described. Replace that instruction with a pointer to the script, and keep the tracked toolset gap it is standing in for.
9. Defer by loading frequency once the body starts crowding: <a name='id/BlockNode:00CEDFKN30008' class='aperas-anchor aperas-id'></a> Philosophy, Orientation and Discipline stay in SKILL.md, Mechanics moves to `references/` when its bulk begins to push the levels above it out of easy reach. Not yet warranted — the body is well inside the point where deferral buys anything.
10. Build the eval set from recorded incidents, run it against the v0 baseline preserved in git history, grade on objective assertions, and review the benchmark. This is what actually closes the Verification Plan; until it runs, the claim that the levels change behaviour is untested.
11. Measure the frontmatter description last, once the content has settled — labelled should-trigger and should-not-trigger queries with a held-out split, since triggering decides whether any of the rest is ever read.

## Verification Plan <a name='id/BlockNode:00CEA5M6S800D' class='aperas-anchor aperas-id'></a>

The rewrite succeeds if an agent reading only the first two levels behaves correctly in the ordinary case — graph-first, traversal-first — without having reached any mechanics.

Two concrete checks, both available from this corpus rather than from judgement alone. First, every incident already recorded in this concern's discussion should be predictable from a statement at the philosophy or discipline level; one that isn't marks a gap at that level, not a missing gotcha. Second, the grep-instead-of-traverse failure specifically should be prevented by something a reader meets before any CLI verb appears, since that failure happened to a reader who had the rule available and still did not apply it.

The instrument for both checks is an eval loop, since neither is answerable from reading the document. Test prompts are run twice over — once by an agent holding the skill, once by a baseline agent — then graded against assertions and aggregated into a benchmark.

The baseline is the **previous version of the skill**, not the absence of one. v0 is preserved in git history, so the comparison measures the restructure itself rather than merely re-confirming that having a skill beats having none.

Prompts are harvested, not invented — real incidents already recorded in this concern's discussion supply them: the cross-reference question that produced the grep-instead-of-traverse failure, adding one item to an existing list, retitling a heading, linking two docs that resolve each other's gaps. Synthesizing a *test* is not the same as synthesizing an *example*; the harvest-don't-synthesize rule governs what goes into the document, not what probes it.

Assertions must be objectively checkable, which these are: <a name='id/BlockNode:00CEDFCMY0004' class='aperas-anchor aperas-id'></a> did the run reach for `aperas backlinks` rather than `grep`; did a heading-text edit pass `--text-only`; did a list addition push the complete list; did the ids survive a move. Anything needing human judgement stays qualitative rather than being forced into an assertion.

Trigger accuracy is measured separately and last, once the content is settled. The frontmatter description is the only part of a skill always in context, so it alone decides whether the skill is consulted at all — a property that is empirically testable against labelled should-trigger and should-not-trigger queries, with a held-out split so the wording is not merely fitted to them, rather than settled by taste.
