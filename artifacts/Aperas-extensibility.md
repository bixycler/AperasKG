# The Aperas Extensibility Model: Apeiron to Perata

Aperas is not a monolithic application with a single, closed database; it is an engine for growing forms (Perata) out of a formless core (Apeiron). 

Because there will be many different Domain KGs (e.g., `ArchitectureKG`, `PersonalKG`, `ProjectX_KG`), the boundary between the Core and the Domain must support deep **extension and refinability**.

## 1. Core vs. Community Governance

*   **Aperas (The Apeiron Core):** Managed by the Core Dev Team. It provides the universal potential: the database driver, the base universal schemas (`BaseNode`, `BaseLink`, `BaseEdge`, `BlockNode`, `ArtifactNode`), and the infrastructure tooling (like `restore.sh`).
*   **A Domain KG (The Perata):** Managed by the Community. A specific KG repository (like `AperasKG`) is a specific materialization. It contains the raw content (`artifacts/`), **and** the specific logic that defines its shape (its Schemas, Ontologies, and Transducers).

## 2. Mechanisms of Extension (OOP & Composition)

The technical implementation of this extensibility leverages Object-Oriented polymorphism in TerminusDB and functional composition in TypeScript.

### A. Schema Extension (`@inherits`)
Domain KGs can define custom node shapes that natively inherit properties from the Aperas Core nodes using the `@inherits` JSON-LD keyword.
*   **Property Inheritance**: A domain `RequirementNode` inheriting from `BlockNode` automatically gains `title`, `text`, and `children`, plus its own specific fields like `priority`.
*   **Subsumption (Polymorphism)**: TerminusDB natively understands this inheritance Directed Acyclic Graph (DAG). A query for `BlockNode` will automatically return all `RequirementNode` instances. *(See the official [TerminusDB Schema Reference Guide](https://terminusdb.org/docs/schema-reference-guide/#inherits) for details).*

### B. Ontology Extension (Edge Subclassing)
Aperas adopts **Edge Subclassing (OOP)** for defining predicates and relationships. 
Instead of relying on fragile string fields, relationships are modeled as abstract schema classes (e.g., `BaseEdge`). A Domain KG can define specific relationships that inherit from these bases:
```json
{ "@id": "AffectsEdge", "@type": "Class", "@inherits": ["BaseEdge"], "source": "BlockNode", "target": "BlockNode" }
{ "@id": "BlocksEdge", "@type": "Class", "@inherits": ["AffectsEdge"] }
```
*   **WOQL Subsumption Query**: Because the edge is an object in a hierarchy, you query it using `isa()`, which natively understands subsumption. *(See the [WOQL Class Reference Guide](https://terminusdb.org/docs/woql-class-reference-guide/#is-a) for details on `isa`)*.
    ```javascript
    WOQL.isa("v:EdgeId", "AffectsEdge")
        .triple("v:EdgeId", "source", "v:NodeA")
        .triple("v:EdgeId", "target", "v:NodeB")
    ```
    This single query automatically fetches all `AffectsEdge` instances **and** all domain-specific `BlocksEdge` instances seamlessly, with strict typing constraints.

### C. Transducer Extension (Pipeline & Class Overrides)
Because transducers are TypeScript logic, they extend via standard programming patterns:
*   **Pipeline Composition**: Using tools like `unified.js`, the core provides a base pipeline (`unified().use(remarkParse)`). A Domain KG injects its own specific plugins (`.use(domainSpecificYamlPlugin)`) into the chain.
*   **OOP Class Inheritance**: A domain script can extend a core parser class (`class ArchitectureTransducer extends BaseMarkdownTransducer`) to override specific parsing behaviors.
