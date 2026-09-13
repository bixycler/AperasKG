# Aperas Skill — Design <a name='id/BlockNode:00CEA5Y5J8001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CEA5Y5J8002' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CEA5Y5J8003' class='aperas-anchor aperas-id'></a> [Settled](../discussion/aperas-skill.md#id/BlockNode:00CEA56A0G001) — the philosophy this design is drawn from, and the incidents it was drawn from.
- **Issues**: <a name='id/BlockNode:00CEA5Y5JG000' class='aperas-anchor aperas-id'></a> [Open Issues](../issues/aperas-skill.md#id/BlockNode:00CEA5KW4G002) — where the current v0 falls short of the shape below.
- **Planning**: <a name='id/BlockNode:00CEA5Y5JG001' class='aperas-anchor aperas-id'></a> [Task Breakdown](../planning/aperas-skill.md#id/BlockNode:00CEA5M6S8005) — the ordered work to get there.
- **History**: <a name='id/BlockNode:00CEA5Y5JG002' class='aperas-anchor aperas-id'></a> [Current Status](../history/aperas-skill.md#id/BlockNode:00CEA5MHD8002) — what exists today.

## Architecture <a name='id/BlockNode:00CEA5Y5JG003' class='aperas-anchor aperas-id'></a>

The skill teaches one thing, and everything else in it is a consequence: **Apeiron is the source, and the `.md` files under `artifacts/` are shadows projected from it.** A projection can be regenerated at any time; it is never where a change is made.

Four levels, each following from the one above: <a name='id/BlockNode:00CEA5Y5JG004' class='aperas-anchor aperas-id'></a>

1. **Philosophy** — the graph is the source, and its substance is nodes together with the links between them. A node's meaning is constituted by what it links to, what links back, and where it sits, not by its own text alone.
2. **Orientation** — traversal is therefore the primary mode of work rather than a check appended to it. Reading means following links; writing means placing them. `archive/Aperas-design.md`'s Multi-Agent Projection Pattern names both as the architecture's own capabilities. *Deep read* runs in two directions answering different questions: forward and downward — a block's children and its outgoing links — is deeper **content**, what the block is made of and refers to, and is what an ordinary read wants; backward along backlinks is deeper **context**, who depends on this and what surrounds it, reached for when the decision is harder than reading. The tool surface already carves it this way: `aperas unfold` previews children and forward links together because both are content, while `backlinks` stands alone because it is the other axis. *Deep write* is inherently backward — what a change breaks is only answerable from the citing side. *Dense linking* is the precondition for all of it: a sparsely linked graph gives deep read nothing to descend into and deep write nothing to follow. These are crystallized practice rather than theory, but the practice predates this system — years of real knowledge-graph work in Logseq, carried in as design instead of rediscovered here. That this system has barely exercised them yet is a fact about its infancy, not their standing: the same bottom-up emergence that turns an incident into a skill item, running at the scale of a whole architecture.
3. **Discipline** — how to behave once oriented: <a name='id/BlockNode:00CEA5Y5JG007' class='aperas-anchor aperas-id'></a> edit graph-first, target the smallest block that actually changed, write discussion before executing, stage each verified step, respect citation direction, prefer a move over remove-and-recreate wherever identity should survive — the same guarantee [linking's rename mechanism](../design/linking.md#id/BlockNode:00CDC0D59000B) makes structurally, by adding an anchor rather than replacing one.
4. **Mechanics** — how to type it: <a name='id/BlockNode:00CEA5Y5JG008' class='aperas-anchor aperas-id'></a> CLI verbs and their path-resolution rules, [wikilink and anchor syntax](../design/linking.md#id/BlockNode:00CDBYV4T8002), `--after`/`--before` parentage, shell quoting, and the current tool gaps with their workarounds.

An item belongs at the level that explains *why* it is true, not the level where it was first noticed. A shell-quoting bug is Mechanics. Treating a projected file as the source is Philosophy — and its recurrence is evidence that the first level has not landed, which no quantity of Mechanics will repair.

## Topology <a name='id/BlockNode:00CEA5Y5JG00A' class='aperas-anchor aperas-id'></a>

The four levels are the document's own top-level structure, in that order, abstract to concrete. The ordering is load-bearing rather than cosmetic: a reader who stops after the first two levels should already act correctly in the ordinary case, while a reader who starts at the bottom acquires a list of gotchas with nothing to hang them on.

Within a level, each item is stated rule-first, with its originating incident attached rather than leading. The incident must travel with the rule, since a rule whose cause is lost gets misapplied at its edges or cargo-culted past its expiry — but it should not have to be excavated before the rule can be read.

Every item carries its status where it stands: <a name='id/BlockNode:00CEA5Y5JG00C' class='aperas-anchor aperas-id'></a> confirmed-current, superseded by a change that has since landed, or identified-but-unverified. A caution whose cause has been removed is worse than no caution, because it still costs the reader something and no longer buys anything.

### Examples — the vertical thread <a name='id/BlockNode:00CEB0XSW0001' class='aperas-anchor aperas-id'></a>

Examples are not a fifth level. They run vertically through all four, because a level stated only as theory is the failure mode the levels exist to prevent: a reader who has understood a principle abstractly but never seen it instantiated will still reach for the wrong tool under pressure.

Each level takes a different kind of example, and the kind is dictated by what that level has to teach.

- **Philosophy** takes a *contrast pair* — the same task done both ways, wrong then right, so the principle registers as a lived distinction rather than a slogan. Grepping projected files against traversing the graph, with both transcripts shown and the cost of the first made visible, teaches the source/shadow distinction in a way no restatement of it can.
- **Orientation** takes a *short traversal transcript* — a real `aperas backlinks` answer, one hop followed, the thing found at the other end. This is what "reading means following links" looks like when it is happening, and it is short enough to read as a whole.
- **Discipline** takes *one full worked loop*, end to end: <a name='id/BlockNode:00CEB0XSW8000' class='aperas-anchor aperas-id'></a> locate the smallest block that changed, update it, verify via backlinks rather than the summary line, project, stage. Nearly every real task is this loop, so one complete instance carries further than five fragments.
- **Mechanics** takes the *minimal command plus its exact failure text*. The error string is half the example and often the more useful half — recognising `anchor is not a child of X` is what converts a five-minute detour into a five-second one.

Examples are harvested, never synthesised. The bottom-up growth path already produces them: every incident that earns an item is, by construction, a real transcript with a real error message attached. A synthesised example can be subtly wrong in ways nobody notices until it is followed — this corpus has already paid that price once, when a migration's "before" snapshot was computed through the already-updated serialiser and produced a baseline that looked plausible and was meaningless.

### What lives in the body, and what gets deferred <a name='id/BlockNode:00CEDF5XVR001' class='aperas-anchor aperas-id'></a>

A skill loads in three stages: name and description are always in context, the SKILL.md body arrives once the skill triggers, and bundled `references/` files are read only when actually needed. The levels map onto that directly, so **what to defer is decided by loading frequency, not by size.**

Philosophy and Orientation belong in the body unconditionally. Their whole job is to land before anything else is read, and a reader who never reaches them is the failure mode the level ordering exists to prevent. Discipline belongs there too, being the shape of ordinary work. Mechanics is different in kind: it is lookup material, consulted when a specific problem is hit rather than read through, which makes it the natural candidate for deferral into `references/` once its bulk starts crowding out the levels above it.

Size is only a weak proxy for this, and navigability is the symptom rather than the cause. The real question about any passage is whether a reader needs it *every* time or *occasionally* — and a level whose items are all consulted occasionally can be deferred wholesale without the reader losing anything they were relying on.

## Workflows <a name='id/BlockNode:00CEA5Y5JG00D' class='aperas-anchor aperas-id'></a>

Two scopes run through this section, and they coincide rather than merely resembling one another. The **object workflow** is what the skill teaches an agent to do while working the graph. The **meta workflow** is how the skill document itself is grown and maintained. Growth below is purely meta; the edit loop is purely object; citation direction and crystallization are object rules that the skill's own upkeep then obeys in turn. `archive/Aperas-design.md` calls this coincidence Meta-Aperas — the platform builds itself using the exact principles it uses to manage knowledge — so the overlap is the design working as intended, not a section wanting to be split in two.

### The edit loop — object workflow <a name='id/BlockNode:00CEB8N5EG001' class='aperas-anchor aperas-id'></a>

The shape of nearly every real task against the graph, and the thing a Discipline-level worked example should instantiate end to end.

1. **Orient before touching anything — content first, context when the decision is hard.** Start with `aperas unfold <ref>`, which previews the block's children *and* its forward links together: both are deeper **content**, the substance the block is made of and refers to, and that is what an ordinary read needs. Escalate to `aperas backlinks <id> --text` for deeper **context** — who depends on this block, who cites it, what surrounds it — when the decision is harder than reading: editing, or an investigation whose scope has widened. Editing is always such a case, since step 5 cannot find what a change breaks without it. A block's meaning is not contained in its own text, so an edit decided without both directions is decided on partial information.
2. **Locate the smallest block that actually changed.** Not the artifact, not the enclosing heading: the leaf whose content is wrong. Anything larger means reconstructing unchanged siblings by hand, where a single transcription slip silently tombstones a block and mints a new id in its place.
3. **Edit graph-first.** Pipe replacement content to `aperas update <id>`, or `aperas insert` for genuinely new content, and reposition with a stdin-less `insert` when a node should move rather than be recreated. The projected file is never the place an edit is made.
4. **Verify by traversal, not by summary line.** A reconcile count reports what the command believes it did. A backlink that actually resolves, or a `--dry-run` projection where the content is actually visible, is what proves it happened.
5. **Deep write — follow what the change made stale.** Check the block's backlinks and forward links and update what now disagrees with it. This is the step most easily skipped and the one that keeps the graph coherent rather than merely correct in one place.
6. **Project, then stage.** `aperas project <path> --flush`, then `git add` in `AperasKG/` straight away, so the index stands as a checkpoint if a later step goes wrong. Staging only — committing stays the user's call.

### Growth — bottom-up emergence <a name='id/BlockNode:00CEA5Y5JG00E' class='aperas-anchor aperas-id'></a>

The skill accretes from live incidents, never from reasoning in the abstract. An item travels a fixed path: an incident occurs during real work; it is captured raw in the task's own freeflow discussion, before it is understood rather than after; it is then confirmed, by reproduction or by tracing it to a cause in the code; and only then is it promoted into the skill, at the level that explains it.

The first two steps are non-negotiable in that order. A finding written up once the work has concluded has already lost the specifics that made it worth keeping.

Tooling emerges the same way, along its own path: <a name='id/BlockNode:00CEDF24W0001' class='aperas-anchor aperas-id'></a> **practice → skill script → discussion → issues → toolset update.** A helper written ad hoc during real work is the practice. Bundling it under the skill's own `scripts/` is a staging area — reusable and shared, but not yet part of the product, in the same sense that git staging sits between a working tree and a commit. Articulating why it keeps being needed is the discussion; tracking it as a real gap is the issue; absorbing it as a first-class CLI verb is the toolset update.

The signal for entry onto this path is repetition, which is a measurement rather than a judgement: the same helper written independently, session after session. A skill that *instructs* the reinvention — telling the reader to write a one-liner it could simply have bundled — has identified the need and then declined to stage it.

### Citation direction <a name='id/BlockNode:00CEA5Y5JG00G' class='aperas-anchor aperas-id'></a>

The concerns form an abstraction gradient, `design` most abstract and `discussion` least, with `issues`, `planning` and `history` between. A citation may point up that gradient or sideways along it freely. It may not point down: a design block does not reference a discussion block, for the same reason a node carries a parent pointer and not a list of children. The concern taxonomy's own `# Context` convention ([documentation](../design/documentation.md#id/BlockNode:00CDD68E8000K): "one link plus a brief, non-argumentative summary per doc") already states this same up-only citation shape for that one sanctioned exception, independently of this rule.

The one sanctioned exception is a designated index. A design doc's `# Context` section exists precisely to index its own concern's other facets, one link each — a single structurally-privileged reference, not a citation scattered through the body.

### Crystallization — content and topology <a name='id/BlockNode:00CEA5Y5JG00J' class='aperas-anchor aperas-id'></a>

Crystallization matures a thought along two axes at once.

On the **content** axis, prose moves from freeform discussion into normative design, issues, planning, or history.

On the **topology** axis, a relationship that first existed *indirectly* — mediated by a discussion node that cites both ends and carries the judgment in its own text — becomes a *direct* citation between those ends once it proves load-bearing rather than incidental, and the mediating node's work is then done. Link density is the product of this lifecycle, which is why it reads as maturity from outside rather than as tidiness.

### Versioning — snapshot, delta, thread <a name='id/BlockNode:00CF595QQR001' class='aperas-anchor aperas-id'></a>

The skill file is a *generative* projection of this concern rather than a mechanical one: no command serializes design into SKILL.md, so the two can drift in a way an `aperas project` artifact cannot. Three devices keep the drift legible, and together they are the meta workflow's maintenance half.

A **snapshot** is a verbatim copy of the skill file taken at a major version and split so every item is individually addressable. Copy, not projection: a projection holds only the current version, so what a restructure *drops* would survive nowhere but git archaeology. That loss is not hypothetical — v0's snapshot is the only reason a trigger v1 silently dropped was ever found. Successive snapshots make the skill's evolution the object of study rather than just its latest state.

A **delta** records a minor version's additions verbatim against the standing snapshot, rather than re-snapshotting the whole document. The base stays stable, what changed stays legible, and each addition is addressable on the same terms as the snapshot's own items.

A **thread** wires each Philosophy and Orientation principle to the items that realize it below, as mediating nodes — mediating because the snapshot must stay verbatim to stay comparable. The thread is what makes the level structure auditable instead of merely asserted: a principle with no realizer is a measurement, not an impression. Read backward, from a principle's backlinks, it detects a principle stated and never operationalized. Read forward, from a realizer's grounding, it detects the opposite defect — an item whose explanation sits outside the level structure, which is the observable form of a principle that was never stated at all. It cannot detect *under*-realization, since presence and sufficiency are not the same measurement and this graph is too coarse to count the difference; that judgment stays with the reader.

A delta entry that *replaces* rather than adds carries a **`Supersedes:`** line naming the snapshot item it retires, as an ordinary wikilink. Without it, an item a minor version deliberately rewrote is indistinguishable from one silently dropped — which is the single judgement the whole arrangement exists to support, so leaving it to a reader's memory defeats the purpose. The marker is bookkeeping rather than skill text, and is excluded from the verbatim comparison on both sides.

Drift between the file and this record is then mechanically checkable, which is the point: `scripts/skill_drift.py` reports text written into the file but never recorded, and recorded items absent from the file with no entry claiming to supersede them. Both defects had previously been caught only by a reader noticing, three times in one session for the first and once across a major version for the second.
