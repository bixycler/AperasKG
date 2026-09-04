# Aperas Fractal Ontology - Implementation Plan

This plan outlines the steps to refactor the Aperas Knowledge Graph codebase to implement the fractal block-tree ontology designed in `Aperas-core-ontology-design.md`. Stage 1 is fully implemented and live-verified; Stage 2 is implemented except items 4 (Link Extraction) and 5 (Title vs. Text Split), which remain open; Stage 3 (Database & UI Alignment) hasn't started. See `Aperas-dev-status.md` for current status and `Aperas-architecture.md` for the as-built reference. Node identity evolved past what Stage 2 anticipated (content-addressed hashing was tried and superseded by Snowflake-style ids — see `Aperas-core-ontology-design.md` Appendix F); this plan is kept as a historical record, not a live checklist.

## Stage 1: Core Schema Overhaul
**Target Files**: Create `web/src/lib/schema.json` and delete `web/src/lib/schema.ts`
1. **Eliminate `schema.ts`**: The current `schema.ts` file contains useless TypeScript interfaces that type the TerminusDB schema metadata (e.g., `docId: "xsd:string"`). This is a double-maintenance anti-pattern. We will delete `schema.ts` entirely.
2. **Create `schema.json`**: Create a pure, static JSON array file representing the raw JSON-LD schema required by TerminusDB.
3. **Clean Slate**: Do not port over the legacy `DocumentNode`, `SpanNode`, or `TripleAssertion` definitions to the new JSON file.
4. **Implement Lineage (in `schema.json`)**:
   *   Define `BaseNode` (Abstract class, `links: Set<BaseLink>`).
   *   Define `BaseLink` (Inherits `BaseNode`, adds `target: BaseNode`).
   *   Define `BaseEdge` (Inherits `BaseLink`, adds `source: BaseNode`).
5. **Implement Topology (in `schema.json`)**:
   *   Define `FolderNode` (Inherits `BaseNode`, adds `title`, `path`, `text`, `children: List<BaseNode>`).
   *   Define `BlockNode` (Inherits `BaseNode`, adds `title`, `text`, `children: List<BlockNode>`, `unfolded: boolean`).
   *   Define `ArtifactNode` (adds `path`, `contentHash`, `root: BlockNode`).

## Stage 2: Ingestion & AST Parser Refactoring
**Target File**: `web/src/lib/astParser.ts` and `web/src/lib/artifacts.ts`
1. **Directory Traversal & Folder Ingestion**: Refactor `artifacts.ts` to ingest folder structures as `FolderNode`s. If a `README.md` exists in a folder, its content is fully ingested into the `FolderNode` (extracting the abstract into `text` and prepending its parsed children to the folder's `children`). Do not expose `README.md` as a separate `ArtifactNode`.
2. **Fractal Tree Generation**: Refactor the markdown transducer to output an infinitely nested tree of `BlockNode`s rather than a flat, positional list.
3. **Content-Addressed IDs**: Replace positional ID generation (`doc1_block1`) with deterministic content hashing (combining parent context and block content).
4. **Link Extraction**: Modify the parser to extract inline Markdown links and properties, storing them structurally as `BaseLink` objects in the `BlockNode.links` array.
5. **Title vs. Text Split**: Implement the ingestion logic for `title` vs `text`. (For headings: title is heading text, text is body. For normal blocks: fallback to first line or ID until the AI summarization agent is integrated).

## Stage 3: Database & UI Alignment
1. **Database Sync**: Push the new schema to TerminusDB and verify class inheritance (`isa` subsumption) and properties.
2. **Projection Engines & Traversal**: 
   *   Update WOQL/GraphQL queries to support BFS traversal seamlessly across `FolderNode`, `ArtifactNode`, and `BlockNode` boundaries.
   *   Stub or update the Markdown generation logic to respect the `unfolded` property and serialize `FolderNode` block children back into `README.md`s.
   *   Update SolidJS UI tree components to render the polymorphic hierarchy smoothly (Folder -> File -> Block).
   *   Prepare UI components to handle the "Hover Preview" of link targets.
