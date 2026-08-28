# Domain Schemas

This directory is an extension point for the community to define domain-specific JSON-LD schemas.

While the Aperas Core defines the universal primitives (`BaseNode`, `BaseLink`, `BaseEdge`, `BlockNode`, `ArtifactNode`), specific Knowledge Graphs (like this one) can define custom shapes using the `@inherits` keyword.

*   **Node Schemas**: e.g., an `ArchitectureDecisionNode` that `@inherits ["BlockNode"]`.
*   **Edge Schemas**: e.g., an `ImplementsEdge` that `@inherits ["BaseEdge"]`.

*(See the official [TerminusDB Schema Reference Guide](https://terminusdb.org/docs/schema-reference-guide/#inherits) for details on `@inherits` and hierarchical subsumption).*

Place your `.jsonld` schema definitions here.
