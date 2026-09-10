# Architecture of Documents: Separation of Concerns & Matrix Workflow <a name='id/BlockNode:00CDD68E80001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CDD68E80002' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CDD68E80004' class='aperas-anchor aperas-id'></a> [Motivation — the mixing problem](../discussion/documentation.md#id/BlockNode:00CDD68EV8002) — rationale for adopting block-based separation, evidenced by the pre-Phase-1.1 corpus.
- **Issues**: <a name='id/BlockNode:00CDD68E80005' class='aperas-anchor aperas-id'></a> [Resolved: Context/Discussion boundary](../issues/documentation.md#id/BlockNode:00CDD68FE0004) — Context conflicted with Discussion's "motivation"; resolved by defining Context as a factual index, not narrative.
- **History**: <a name='id/BlockNode:00CDD68E80006' class='aperas-anchor aperas-id'></a> to be updated.

## Architecture <a name='id/BlockNode:00CDD68E80007' class='aperas-anchor aperas-id'></a>

To achieve pure Perata (clean projections for the reader), the storage layer must adopt a **Block-Based Separation of Concerns**. Instead of one mixed file, the Apeiron stores strictly isolated documents (or trees):

1. **Design Docs:** Pure architectural specifications, data models, and rules.
2. **Issue Docs:** Bug reports, architectural gaps, and pending fixes.
3. **Planning Docs:** Implementation plans, task breakdowns, and step-by-step execution guides.
4. **History/Status Docs:** What was implemented, when it was verified, and milestones.
5. **Discussion Docs:** Rejected ideas, motivation, and theoretical context.

This guarantees that a reader parsing the "Design Doc" sees *only* the design, without needing complex transducers to strip out bug reports and history logs.

## Topology <a name='id/BlockNode:00CDD68E8000E' class='aperas-anchor aperas-id'></a>

A rigid physical directory structure inevitably fails because software development requires different lenses at different times (e.g., building a feature vs. fixing a cross-cutting bug). Because all edits happen on the unbounded tree (Apeiron), we optimize physical storage for the **Reader** (stability) and use TreeViews/Freeflow documents for the **Agent** (dynamic tasks).

### Physical Storage: Concern-Centric <a name='id/BlockNode:00CDD68E8000F' class='aperas-anchor aperas-id'></a>

At the file-system layer, artifacts are strictly grouped by concern. This forms the system-wide documentation naturally.

```text
artifacts/
  ├── design/
  │   ├── crud.md                 (Pure Perata: Architecture, Models, Specs)
  │   └── treeview.md
  ├── issues/
  │   ├── crud.md                 (Bugs, gaps, pending tasks)
  │   └── network.md
  ├── planning/
  │   └── crud.md                 (Implementation plans, step-by-step execution guides)
  ├── history/
  │   └── crud.md                 (Implementation status, log of changes)
  └── discussion/
      └── crud.md                 (Rationale, rejected ideas, unstructured thought)
```

### Document-Level Skeletons <a name='id/BlockNode:00CDD68E8000H' class='aperas-anchor aperas-id'></a>

To ensure uniformity across the corpus, each concern document should follow a strict top-level heading structure. Standardizing these paths (e.g., `design/crud.md/Data-Model`) allows the agent to reliably address them.

- **Design Docs (`design/*.md`)**: <a name='id/BlockNode:00CDD68E8000J' class='aperas-anchor aperas-id'></a> Only normative, current-state architectural facts. No "I think we should..."
  
  - `# Context` — a factual index of this concern's discussion, issue, planning, and history docs: one link plus a brief, non-argumentative summary per doc (what exists, not why). Rationale, rejected alternatives, and narrative stay in the linked Discussion doc — never inline here.
  - `# Architecture`, `# Topology`, `# Workflows`
- **Issue Docs (`issues/*.md`)**: <a name='id/BlockNode:00CDD68E8000N' class='aperas-anchor aperas-id'></a> Actionable, resolvable nodes.
  
  - `# Open Issues`, `# Pending Tasks`, `# Resolved`
- **Planning Docs (`planning/*.md`)**: <a name='id/BlockNode:00CDD68E8000Q' class='aperas-anchor aperas-id'></a> Actionable steps and plans for implementation.
  
  - `# Implementation Plan`, `# Task Breakdown`, `# Verification Plan`
- **History Docs (`history/*.md`)**: <a name='id/BlockNode:00CDD68E88000' class='aperas-anchor aperas-id'></a> Chronological or state-based facts.
  
  - `# Current Status`, `# Milestones`

## Workflows <a name='id/BlockNode:00CDD68E88002' class='aperas-anchor aperas-id'></a>

The strict physical isolation of concerns is necessary for long-term health, but it is hostile to the creative process. The Aperas workflow bridges this gap by using a **Freeflow Artifact** in the `discussion/` directory as the active workspace.

When starting a task, the agent doesn't jump between `design.md` and `issues.md`. They create a freeflow discussion document, which serves two simultaneous purposes:

### The Dashboard (Context Assembly) <a name='id/BlockNode:00CDD68E88004' class='aperas-anchor aperas-id'></a>

The top of the freeflow document acts as a control panel. The agent authors structural links to all the formal blocks across the corpus that are relevant to the current task.

**`discussion/crud-reconciliation-task.md`**

```markdown
# CRUD Reconciliation Task

## Dashboard
[Current Architecture](../design/crud.md/Architecture)
[The Bug Report](../issues/crud.md/Open-Issues/Nowhere-Problem)
[The Plan](../planning/crud.md/Implementation-Plan)
[Status](../history/crud.md/Current-Status)
```

*(By linking these, the agent anchors the formal state into their workspace. When unfolded via `TreeView`, it projects all these scattered formal blocks into a single localized lens).*

### The Scratchpad (Freeflow Authoring) <a name='id/BlockNode:00CDD68E88008' class='aperas-anchor aperas-id'></a>

Beneath the dashboard, the agent dumps unstructured, messy thoughts exactly as they do today.

```markdown
## Brainstorming
So the issue happens because the parent node is missing.
If we use a placeholder flag on the node, it could reconcile safely...
```

This is pure Apeiron. It is unbounded, unstructured, and safe from strict schema rules. It exists only in the discussion concern.

### Crystallization (The Update Loop) <a name='id/BlockNode:00CDD68E8800B' class='aperas-anchor aperas-id'></a>

Eventually, the brainstorming yields a concrete decision. The thought *crystallizes* from a messy idea into a formal architectural rule, or a formal task.

Instead of leaving that crystallized rule buried in the freeflow text, the agent projects it back to the formal block using the CRUD surface:

```bash
# Push the crystallized rule to the formal design block
kg:update design/crud.md/Architecture --text "A placeholder is a flag, not a distinct kind..."

# Push the execution steps to the formal planning block
kg:update planning/crud.md/Task-Breakdown --text "- [ ] Add placeholder flag to nodes\n- [ ] Reconcile missing parents"

# Push the resolution status to the formal history block
kg:update history/crud.md/Current-Status --text "Resolved Nowhere Problem via placeholder flags."
```

### The Resulting Ecosystem <a name='id/BlockNode:00CDD68E8800E' class='aperas-anchor aperas-id'></a>

This creates a perfect symbiosis:

- The **Freeflow Document** (in `discussion/`) retains the entire historical journey of the thought process, the rejected ideas, and the dashboard of links that defined the task context.
- The **Formal Documents** (in `design/`, `issues/`, `planning/`, `history/`) remain pristine and strictly isolated, containing only the crystallized reality of the system.
- The **Agent** navigates the graph easily, using the freeflow document as a central hub that fans out to the formal specs.
