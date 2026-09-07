# Architecture of Documents: Separation of Concerns & Matrix Workflow

## 1. Concrete Reality: The Mixing Problem
Currently, documents in `AperasKG/artifacts/` are massive mixtures of completely different logical concerns. Looking at actual project files (e.g., `Aperas-crud-design.md` and `Aperas-treeview-design.md`), the writer often mixes everything into a single document and sometimes even the same paragraph. 

No transducer or adapter can automatically untangle this. A single artifact today contains:
- **Core Design:** The actual specification (e.g., `3. Core model: placeholder is a flag`).
- **Issues & Gaps:** Bugs discovered live during implementation (e.g., `6. Bookkeeping gaps found while designing this`).
- **History & Status:** Implementation progress and verification records (e.g., `Status: implemented, live-verified against a synthetic graph`).
- **Discussion & Rationale:** Why something was built a certain way, or rejected (e.g., `12. Considered and rejected`).
- **Implementation Details:** Notes to self about code structure.

## 2. Block-Based Separation of Concerns
To achieve pure Perata (clean projections for the reader), the storage layer must adopt a **Block-Based Separation of Concerns**. Instead of one mixed file, the Apeiron stores strictly isolated documents (or trees):

1. **Design Docs:** Pure architectural specifications, data models, and rules.
2. **Issue Docs:** Bug reports, architectural gaps, and pending fixes.
3. **History/Status Docs:** What was implemented, when it was verified, and milestones.
4. **Discussion Docs:** Rejected ideas, motivation, and theoretical context.

This guarantees that a reader parsing the "Design Doc" sees *only* the design, without needing complex transducers to strip out bug reports and history logs.

## 3. The Matrix Topology (Physical vs. Logical)
A rigid physical directory structure inevitably fails because software development requires different lenses at different times (e.g., building a feature vs. fixing a cross-cutting bug). Because all edits happen on the unbounded tree (Apeiron), we optimize physical storage for the **Reader** (stability) and use TreeViews/Freeflow documents for the **Agent** (dynamic tasks).

### 3.1 Physical Storage: Concern-Centric
At the file-system layer, artifacts are strictly grouped by concern. This forms the system-wide documentation naturally. 
```text
artifacts/
  ├── design/
  │   ├── crud.md                 (Pure Perata: Architecture, Models, Specs)
  │   └── treeview.md
  ├── issues/
  │   ├── crud.md                 (Bugs, gaps, pending tasks)
  │   └── network.md
  ├── history/
  │   └── crud.md                 (Implementation status, log of changes)
  └── discussion/
      └── crud.md                 (Rationale, rejected ideas, unstructured thought)
```

### 3.2 Document-Level Skeletons
To ensure uniformity across the corpus, each concern document should follow a strict top-level heading structure. Standardizing these paths (e.g., `crud/design.md/Data-Model`) allows the agent to reliably address them.

- **`design.md` (The Pure Spec)**: Only normative, current-state architectural facts. No "I think we should..."
  - `# Context`, `# Architecture`, `# Data Model`, `# Workflows`
- **`issues.md` (The Task Tracker)**: Actionable, resolvable nodes.
  - `# Open Issues`, `# Pending Tasks`, `# Resolved`
- **`history.md` (The State and Timeline)**: Chronological or state-based facts.
  - `# Current Status`, `# Milestones`

## 4. The Freeflow Workflow (Scratchpad & Dashboard)
The strict physical isolation of concerns is necessary for long-term health, but it is hostile to the creative process. The Aperas workflow bridges this gap by using a **Freeflow Artifact** in the `discussion/` directory as the active workspace.

When starting a task, the agent doesn't jump between `design.md` and `issues.md`. They create a freeflow discussion document, which serves two simultaneous purposes:

### 4.1 The Dashboard (Context Assembly)
The top of the freeflow document acts as a control panel. The agent authors structural links to all the formal blocks across the corpus that are relevant to the current task.

**`discussion/crud-reconciliation-task.md`**
```markdown
# CRUD Reconciliation Task

## Dashboard
[Current Architecture](../design/crud.md/Architecture)
[The Bug Report](../issues/crud.md/Open-Issues/Nowhere-Problem)
[Status](../history/crud.md/Current-Status)
```
*(By linking these, the agent anchors the formal state into their workspace. When unfolded via `TreeView`, it projects all these scattered formal blocks into a single localized lens).*

### 4.2 The Scratchpad (Freeflow Authoring)
Beneath the dashboard, the agent dumps unstructured, messy thoughts exactly as they do today.

```markdown
## Brainstorming
So the issue happens because the parent node is missing.
If we use a placeholder flag on the node, it could reconcile safely...
```
This is pure Apeiron. It is unbounded, unstructured, and safe from strict schema rules. It exists only in the discussion concern.

### 4.3 Crystallization (The Update Loop)
Eventually, the brainstorming yields a concrete decision. The thought *crystallizes* from a messy idea into a formal architectural rule, or a formal task. 

Instead of leaving that crystallized rule buried in the freeflow text, the agent projects it back to the formal block using the CRUD surface:

```bash
# Push the crystallized rule to the formal design block
kg:update design/crud.md/Architecture --text "A placeholder is a flag, not a distinct kind..."

# Push the resolution status to the formal history block
kg:update history/crud.md/Current-Status --text "Resolved Nowhere Problem via placeholder flags."
```

### 4.4 The Resulting Ecosystem
This creates a perfect symbiosis:
- The **Freeflow Document** retains the entire historical journey of the thought process, the rejected ideas, and the dashboard of links that defined the task context.
- The **Formal Documents** (`design.md`, `issues.md`) remain pristine and strictly isolated, containing only the crystallized reality of the system. 
- The **Agent** navigates the graph easily, using the freeflow document as a central hub that fans out to the formal specs.
