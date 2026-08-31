# Aperas Core Ontology Design

This document defines the core semantic graph ontology for Aperas. It establishes mathematically rigorous identity, strong polymorphic typing, and universal addressability for all graph components.

## 1. Node Identity vs. Content Fingerprint

Addressable components (e.g., `BlockNode`) require stable identities that survive re-ingestion. Because identity must remain constant across edits while content-change detection must reflect every edit, these concerns are handled by two separate fields (see Appendix F for why a single-hash design failed).

### A. Node Identity (Stable, Content-Independent)

A `BlockNode`'s `@id` is a **Snowflake-style generated identifier**. It is assigned once at creation and is fully decoupled from the node's content and position, ensuring that `BaseLink` and `BaseEdge` assertions survive edits to their referenced nodes.

**64-bit Layout**: Encoded as a 13-character Crockford Base32 string. It is compact and lexicographically sortable by creation time.

| Field | Bits | Purpose |
| :--- | :--- | :--- |
| **Sign** | 1 | Unused. Keeps value a positive signed int64 for cross-language compatibility. |
| **Timestamp** | 45 | Milliseconds since custom epoch (e.g., 2025-01-01) — provides ~1,115 years of range. |
| **Machine ID** | 10 | 1 anomaly-flag bit + 9 machine-number bits — supports 512 machines with personal failover identities. |
| **Sequence** | 8 | Per-machine-identity counter, reset each millisecond — allows 256 ids/ms/machine. |

**Deterministic Collision Avoidance**: 
Collisions are prevented by construction rather than probability. Timestamps separate different times, the sequence counter disambiguates same-millisecond generation on one machine, and the machine ID separates different machines. 

**Handling Local Clock Anomalies (NTP corrections)**:
1. **Prevention**: NTP uses gradual "slew" adjustments instead of "step" (instant jumps).
2. **Absorption**: The generator uses a high-water-mark (`max(now, last_emitted)`). Small backward jumps are absorbed by the sequence counter.
3. **Failover**: If a backward jump is too large (risking counter overflow), the generator flips its anomaly bit to use a distinct failover machine ID, preventing collisions with its normal output.

*(Note: While extreme, unbounded backward jumps under sustained load remain theoretically possible, they require deliberate clock tampering.)*

### B. Content Fingerprint & Reconciliation

Once a `BlockNode` tree is ingested into the database, **the DB becomes the source of truth**. Edits are made directly in the DB, and artifact files are regenerated (projected) from it. Re-ingestion is a **fallback reconciliation path**, triggered only when an external hand-edit causes the file to drift from its projected state.

**Minimal Fingerprinting on `ArtifactNode`**:
Only two flat, file-level hashes are maintained (no structural hashes):
1. **`fileHash`**: Hash of the raw file's current content, recomputed on every `track` event.
2. **`ingestedHash`**: Hash of the raw file's content as of the last confirmed sync (ingestion or projection). 

**Reconciliation Trigger**: If `fileHash !== ingestedHash`, an unwitnessed edit occurred outside the DB, triggering reconciliation. 

**DB-to-File Changes**: No hash is needed for DB updates. Because DB writes are always witnessed, the system can mark the corresponding artifact as needing re-projection within the same transaction.

## 2. The Universal Node-Link-Edge Lineage
The core graph is built on a clean, fractal inheritance lineage. Every relationship is a fully addressable, first-class Document.

### A. BaseNode (The Root)
The abstract root of all addressable content (inherited by `BlockNode`, `ArtifactNode`, `FolderNode`). It explicitly owns an array of its intrinsic links.
```json
{
  "@id": "BaseNode",
  "@type": "Class",
  "@abstract": [],
  "links": { "@type": "Set", "@class": "BaseLink" }
}
```

### B. BaseLink (Intrinsic Connections)
An abstract class representing connections authored physically *inside* a source node (e.g., Markdown hyperlinks).
*   **Inheritance**: Inherits from `BaseNode`. (This means links themselves possess a `links` array, allowing arbitrary depth for provenance or comments).
*   **Implicit Source**: Because a `BaseLink` resides within the `BaseNode.links` array, the node holding the array is implicitly the source.
```json
{
  "@id": "BaseLink",
  "@type": "Class",
  "@abstract": [],
  "@inherits": ["BaseNode"],
  "target": "BaseNode",
  "predicate": "xsd:string"
}
```

### C. BaseEdge (Extrinsic Assertions)
An abstract class representing independent semantic claims asserted from the outside (e.g., an AI Agent deducing a relationship).
*   **Inheritance**: Inherits from `BaseLink`.
*   **Explicit Source**: Because it floats independently of any node's `links` array, it adds a `source` pointer to explicitly declare its origin.
```json
{
  "@id": "BaseEdge",
  "@type": "Class",
  "@abstract": [],
  "@inherits": ["BaseLink"],
  "source": "BaseNode"
}
```

### D. Assertion (The Concrete Extrinsic Edge)
`BaseEdge` is abstract, so it can never be instantiated directly — something concrete has to exist to actually write an extrinsic claim (`impacts`, `verifies`, `derived_from`, `affects`, ...). `Assertion` is that one generic leaf: it adds no fields of its own, just makes the `source`/`predicate`/`target` (+ inherited `links`) lineage instantiable.
```json
{
  "@id": "Assertion",
  "@type": "Class",
  "@inherits": ["BaseEdge"]
}
```

### E. Link (The Concrete Intrinsic Edge)
`BaseLink` is abstract too — the same gap as `BaseEdge`/`Assertion`, just noticed later, once `BlockNode.links` extraction (Aperas-markdown-fractal-mapping-design.md §4) actually needed to write one. `Link` is `BaseLink`'s one concrete leaf: no fields of its own, just makes the `target`/`predicate` (+ inherited `links`) lineage instantiable. Used for an inline Markdown link whose target resolves to an internal node (`[title]([[code]])`) — the `predicate` is always the fixed constant `"references"` for this use, distinguishing structural inline links from `Assertion`'s deliberately-chosen semantic predicates at query time.
```json
{
  "@id": "Link",
  "@type": "Class",
  "@inherits": ["BaseLink"]
}
```

## 3. Universal Addressability & Ownership
*   **No Subdocuments**: `BaseLink` and `BaseEdge` are standard TerminusDB Classes, *not* `@subdocument`s. Every relationship possesses a global `@id`, enabling graph reification (assertions about assertions).
*   **Author-Based Placement**: Extrinsic assertions (`BaseEdge`) are never embedded into the nodes they connect. They are stored in the branch or artifact owned by the **Asserter** (the author). This ensures that agents can assert claims about human-authored nodes without mutating the human's artifact.

### A. Native Backlinks & Bidirectional Traversal — only for `Set`-typed fields, not `List`

Because TerminusDB is built on RDF triples under the hood, `Set`-typed fields — `BaseNode.links:
Set<BaseLink>`, `BaseEdge.source`/`target: BaseNode` — really do produce one direct triple per
value, so a generic `t(X, Predicate, Target)` query genuinely finds anything pointing at a target
through one of those, no custom backlink table needed. **Confirmed live**:
`t(X, 'links', 'Link/y8LuGtix5YFbBn6Y')` correctly returned the owning `BlockNode` as `X`.

That does **not** extend to `List`-typed fields — and the tree's actual containment structure
(`BlockNode.children`, `ArtifactNode.root`, `FolderNode.children`) is `List`, not `Set`,
deliberately: child order is semantically meaningful (document/section order; `project.ts`'s
serializer depends on it) and `Set` is unordered. TerminusDB represents `List` membership through
intermediate cons-cell/RDF-list structure at the triple level, not a direct `Parent predicate
Child` triple. **Confirmed live**: `t(X, 'children', '<a known child's id>')` returned zero
bindings, even though that id is genuinely present in its parent's `children` list. So "upward
breadcrumbs" and "universal backlink tracing" *do* work for `links` (item 1's own example happens
to pick a `Set` field, so it was never actually wrong) but do **not** give you a node's structural
parent, or an id→path conversion, for free — that would need either a schema change (a persisted
`parentId`/back-reference field on `BlockNode`, the standard trade of write-time bookkeeping for
O(1) reverse lookup) or an explicit downward search from a known root, not a generic triple query.
Not built as of this writing — see `Aperas-deep-path-resolution-design.md`, which covers the
*other* direction (path → id) only; id → path remains a real, separate, unbuilt gap.

1. **Upward Breadcrumbs via a `Set` field (Context Retrieval)**:
   Because `BaseLink` is a fully addressable Document, it does not need a physical `parent`
   pointer for this specific case. If a user addresses a `Link`/`BaseLink` directly
   (`Link/123`), they can follow the breadcrumbs "upward" to find the parent context, since
   `links` is `Set`-typed:
   ```javascript
   // What ParentNode has a 'links' property pointing to me?
   WOQL.triple("v:ParentNode", "links", "Link/123")
   ```

2. **Backlink Tracing, scoped to `Set`-typed edges (Logseq/Roam style)**:
   You can instantly query the graph for anything pointing to a target *through a `Set`-typed
   field* — `links`, or `Assertion.source`/`target` — regardless of the predicate:
   ```javascript
   // What nodes point to this block via a Set-typed field, and via what relationship?
   WOQL.triple("v:SourceNode", "v:Predicate", "BlockNode/MyTargetBlock")
   ```
   This returns every intrinsic `BaseLink`/`Link` or extrinsic `BaseEdge`/`Assertion` referencing
   the target — but never a structural parent, since `children`/`root` aren't reachable this way.

## 4. The Unbounded Block Tree (Node Typology)
The graph topology models all content as an unbounded fractal tree spanning across folders, files, and blocks — "unbounded" in the same sense **Apeiron** (§Philosophy) names the unconditioned, boundless substrate: no fixed depth limit, not merely "very large." The rigid boundaries between structural layers are eliminated to form a single continuous tree.

> **Recurring pitfall when designing tools against this ontology**: reaching for "file" as a unit
> of scope. A path like `foo.md` names one `ArtifactNode` — a single node in the same uniform
> tree as every `FolderNode`/`BlockNode` around it, not a bounded container with its own
> traversal rules. There is no "whole file" tier to recurse into or out of; a command that walks
> "everything under `<path>`" is doing exactly the same walk whether `<path>` resolves to a
> `BlockNode`, an `ArtifactNode`, or a `FolderNode` — see `kg:tree`'s `childRefs`/`printTree`
> (`kgCli.ts:47-51,59`), which already recurses through all three with no kind-based branching.
> Any new command's scoping flags should be designed against depth/traversal-cost concerns (e.g.
> "should this default to walking descendants at all," per
> `Aperas-interactive-summarization-design.md` §3/§7), never against a file/folder/block
> distinction — that distinction doesn't exist here, and designing as if it does is the mistake
> to catch early.

### A. FolderNode (The Structural Container)
Inherits from `BaseNode`. Represents a directory in the filesystem, acting as a seamless bridge in the unbounded tree. 
*   **`README.md` Ingestion**: A separate `README.md` file is a legacy "dumb folder" workaround. The `README.md` is fully absorbed into the `FolderNode`. Its content populates the folder's `text` (abstract) and initial `children` blocks. The `README.md` is not exposed as a separate `ArtifactNode`.
*   **`children`**: Contains other nested `FolderNode`s and `ArtifactNode`s, alongside the parsed block children from the `README.md`.

**Identity**: a Snowflake-style generated id, same scheme as `BlockNode` (§1.A); `path` is a plain, mutable field, not part of the key (Appendix G).
```json
{
  "@id": "FolderNode",
  "@type": "Class",
  "@inherits": ["BaseNode"],
  "title": "xsd:string",
  "path": "xsd:string",
  "text": { "@type": "Optional", "@class": "xsd:string" },
  "children": { "@type": "List", "@class": "BaseNode" }
}
```

### B. ArtifactNode (The Physical Anchor)
Represents the physical file on disk. It handles file metadata and holds a single pointer to the root of the block tree. Inherits from `BaseNode` — without this, no `BaseLink`/`BaseEdge` could target or originate from a whole file, contradicting §3's universal-addressability goal.

**Identity**: Snowflake-generated, same as `FolderNode` above; `path` is a plain, mutable field, not the key (Appendix G). Gains `title`/`text` to match the folding philosophy (§5) uniformly across the whole fractal lineage: `title` is the filename, `text` is an abstract of the file's own content (naive fallback — first paragraph — until AI-driven summarization, §5 enhancement backlog, actually exists).
```json
{
  "@id": "ArtifactNode",
  "@type": "Class",
  "@inherits": ["BaseNode"],
  "title": "xsd:string",
  "path": "xsd:string",
  "text": { "@type": "Optional", "@class": "xsd:string" },
  "fileHash": "xsd:string",
  "lastTrackedAt": "xsd:dateTime",
  "ingestedHash": { "@type": "Optional", "@class": "xsd:string" },
  "lastIngestedAt": { "@type": "Optional", "@class": "xsd:dateTime" },
  "root": { "@type": "Optional", "@class": "BlockNode" }
}
```

### C. BlockNode (The Fractal Atom)
Inherits from `BaseNode`. Every distinct piece of content is a `BlockNode`. The schema is driven by the philosophy of **Abstraction by Folding**: a block's children fold into its `text` (abstract), which folds into a `title`, which folds into a hidden `@id`.

*   **`title` (The Semantic Label)**: Used for wikilinks and graph queries.
    *   For direct UI input: The author is prompted to provide a title.
    *   For Markdown ingestion: The parser uses an AI agent to summarize the block into a title. If AI is unavailable, it falls back to the block ID.
*   **`text` (The Abstract/Body)**: The actual content shown in the current document.
*   **`children`**: An ordered `List` of child `BlockNode`s.
*   **`unfolded`**: A boolean flag representing the persistent view-state for UIs and Agents.
    *   **Human UI & Agent Interface**: When rendering to a screen or an AI prompt, the graph defaults to *folded* (`false`) to manage cognitive/token overload. Only the current block's `text` and the children's `title`s are shown. If this flag is `true`, the subtree auto-expands on load.
    *   **Artifact Projection**: When syncing to a physical `.md` file, the tree is ALWAYS 100% unfolded (writing the full document to disk). This flag is ignored.

```json
{
  "@id": "BlockNode",
  "@type": "Class",
  "@inherits": ["BaseNode"],
  "title": "xsd:string",
  "text": { "@type": "Optional", "@class": "xsd:string" },
  "children": { "@type": "List", "@class": "BlockNode" },
  "unfolded": { "@type": "Optional", "@class": "xsd:boolean" }
}
```

## 5. The Folding Philosophy & Graph Traversal
The entire architecture is governed by the philosophy of **Abstraction by Folding**: an unbounded subtree folds into an abstract (`text`), which folds into a semantic label (`title`), which folds into a hidden `@id`.

### A. The Three Projection Modes
How this folded state is handled depends strictly on the interaction interface:
1. **Artifact Projection (File Syncing)**: When the system serializes a graph back to a physical `.md` file, the tree is ALWAYS 100% unfolded. The persistent `unfolded` state is ignored, as the physical file must contain the entire document body. For `FolderNode`s, the block children are serialized back out to the folder's `README.md`.
2. **Human UI (Phase 1 Web App)**: The UI is folded by default and traverses seamlessly across folder/file boundaries. Users see the `text` (abstract) of the current node (`FolderNode`, `ArtifactNode`, or `BlockNode`) and the abstracts of its direct children. Expanding a `FolderNode` reveals child files/folders and its own `README.md` blocks inline without context switching.
3. **Agentic Interface (BFS Traversal)**: AI agents interact with the graph exactly like the Human UI to manage token limitations. They receive folded views and can navigate continuously from a workspace root `FolderNode` down to a deeply nested `BlockNode` using BFS tool calls to expand subtrees.

### B. Link Targeting & "Hover Previews"
We distinguish between **Intrinsic Links** (`BaseNode.links`) and **Extrinsic Edges** (`BaseEdge`):
*   **Intrinsic Links (`links`)**: Links and metadata (tags, properties) authored directly inside the node. Stored in `BaseNode.links`.
*   **Extrinsic Edges (`BaseEdge`)**: Independent assertions created by external authors/agents. They float independently (to avoid mutating the source node) and are discovered via WOQL queries.
*   **UI Display**: The UI displays non-inline metadata/properties from `links` and queried extrinsic `BaseEdge`s in dedicated reference panels. Inline links remain rendered naturally inside the `text` body.
*   **The Preview Mechanism**: 
    *   **Human UI**: Humans receive the preview interactively by **hovering** over a link or wikilink in the UI, popping up the target block's abstract (`text`).
    *   **Agent Interface**: Agents receive the target block's abstract (`text`) embedded directly in the `links` list returned by the projection/tool call, providing instant preview context without requiring UI hover triggers.
*   **Manual Jump**: If the user or agent needs more context than the target's abstract, they manually "jump" to the target block to explore its children.

---

## Appendix: Design History & Rationale

This section archives the original problems that necessitated this design.

### A. The Positional Identity Flaw
In Phase 0, `BlockNode` IDs were positional (`doc1_block_1`). If an author inserted a paragraph at the top of a document, all subsequent blocks shifted their IDs. This silently broke or orphaned any semantic edges pointing to those blocks upon re-ingestion. Moving to **Content-Addressed Identity** resolves this — though content-addressing itself was later found to have its own problems and was superseded; see Appendix F.

### B. The `xsd:string` Anti-Pattern
Initially, relationships defined `subjectId` and `objectId` as `xsd:string`. This treated relationships as flat text rather than true graph edges, destroying referential integrity. Introducing `BaseNode` as a polymorphic type target resolves this, forcing all edges to point to actual documents in the database.

### C. The Rejection of Subdocuments
TerminusDB's `@subdocument` feature was initially considered for `BaseNode.links` to tightly couple intrinsic links to their parent. However, subdocuments lose their global `@id`. In Aperas, every entity—even a single parsed link or punctuation mark—must be universally addressable so that external agents can comment on or refute it. Thus, subdocuments were rejected, and `BaseLink` was promoted to a full Document class.

### D. Resolving Provenance
Initially, `provenance` was modeled as a hardcoded string or dedicated context object on an edge. By making `BaseLink` inherit from `BaseNode`, every link gets its own `links` array. Provenance is now simply achieved by pushing a new `BaseLink` (e.g., `predicate: "asserted_by"`) into the parent link's array, unifying the ontology completely.

### E. The Unbounded Block Tree
Initially, the schema enforced a rigid structural hierarchy (`DocumentNode` -> `BlockNode`). However, this rigid "solid" paradigm was abandoned in favor of a fractal, Logseq-inspired block tree. `DocumentNode` was eliminated entirely, as a document is conceptually just a root `BlockNode`. Flattening the graph to Markdown is now handled cleanly via an `unfolded` flag in the projection layer.

### F. Separating Identity from Content Fingerprint
The content-addressed scheme from Appendix A (`@id = hash(parent context + content)`) conflated two requirements that pull in opposite directions: identity needs to stay constant across edits and moves so external references don't break; a content fingerprint needs to change whenever content changes, for dedup and change-detection. A single content-derived hash cannot satisfy both. Concretely, it broke two ways: (1) two independently-authored blocks with coincidentally identical text collapsed onto the same `@id`, silently merging distinct entities and their assertions; (2) because the hash was computed bottom-up through the tree, any edit to a leaf changed the hash of every ancestor up to the artifact root, orphaning assertions on whole sections for a single-word edit anywhere beneath them.

Resolved by decoupling the two entirely: `@id` is now a Snowflake-style generated identifier, assigned once and fully independent of content (§1.A) — collision-avoidance is deterministic (timestamp + machine identity + sequence counter), not derived from what the node contains. The content fingerprint (§1.B) turned out not to need a recursive/structural hash at all.

A first attempt at §1.B proposed reusing the bottom-up construction from this section — a recursive, per-`BlockNode` `treeHash` — for three things: detecting the DB-ahead-of-file case (by comparing it against `fileHash`), scoping reconciliation to only the diverged subtrees, and cross-checking the identity-matcher's decisions. The first use rested on a category error: `fileHash` hashes a flat string and a tree fingerprint hashes a nested structure — outputs of different functions over different domains, never meaningfully comparable regardless of whether real drift exists. Once that's gone, the DB-ahead-of-file case is better solved by direct on-write signaling instead (§1.B), and the remaining two uses (reconciliation scoping, cross-check) didn't justify a persisted, per-edit-maintained field on their own — reconciliation is rare and artifacts are bounded, human-document-sized trees, so a best-effort matcher can simply run over the whole tree each time without a hash-based pre-filter. Dropped entirely, not kept even as an on-demand technique — leaving two flat file-domain hashes (`fileHash`/`ingestedHash`) as the whole of the fingerprint design, and reconciliation itself resolved at the strategy level as best-effort content matching over the whole tree, with the specific matching algorithm left as an implementation detail.

### G. Separating Artifact/Folder Identity from Location

`ArtifactNode` and `FolderNode` were originally Lexical-keyed on `path` — not a deliberated design decision, just the obvious, simple choice made in an early, undesigned prototyping pass, before this document's identity/fingerprint rigor (§1, Appendix F) existed at all.

On inspection, while designing reconciliation matching (see `Aperas-reconciliation-matching-design.md`), this turned out to be the same category error Appendix F already fixed once for `BlockNode`, just on a different axis: identity conflated with a mutable property. There, the mutable property was content; here, it's location. A file or folder rename is a routine edit, exactly like a paragraph edit, not an identity change — but `path`-as-`@id` makes every rename destructive by construction, since the `@id` is *recomputed* from the new path, orphaning the old document's identity and everything that ever referenced it directly. The only way to route around that self-inflicted damage is to detect the rename after the fact and manually transplant `root` onto a freshly-identified document — real, working, but entirely unnecessary machinery, built to compensate for the identity scheme rather than because the problem demanded it.

Resolved the same way as Appendix F: `ArtifactNode` and `FolderNode` both get a Snowflake-generated identity (§1.A), and `path` becomes an ordinary mutable field. A detected rename (matched by content, same as everything else — see §4.A/B's `title`/`text` and the reconciliation doc's file/folder-matching design) becomes a field update on the same document, not a new identity; anything that referenced the artifact or folder by id keeps working with no transplant needed. `root` only ever needed transplanting because the container around it couldn't survive a move — fix the container, and the transplant machinery becomes unnecessary for this case (still needed for the case where a match genuinely fails and a new identity is warranted).

Two costs were weighed before committing to this: losing the free, deterministic `id`-from-`path` lookup, and losing the database-enforced guarantee that no two documents can claim the same path. The first turned out not to be a cost at all — benchmarked, a `path`-filtered query came back faster than the direct id lookup it would replace (~7.5ms vs ~48ms at 50 documents). The second is real in shape (an application-level check-then-upsert race could in principle create duplicate `path`s) but not practically significant given how this project is actually deployed — one local TerminusDB per machine, reconciled via fetch/push, not a single server multiple machines write into concurrently; worth remembering if that deployment model ever changes.
