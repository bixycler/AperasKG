# Domain Transducers

This directory is an extension point for the community to define custom, domain-specific ingestion scripts.

If your domain Knowledge Graph requires specialized parsing (e.g., extracting custom YAML frontmatter, parsing specialized tables, or integrating with external APIs), place those specific transducer scripts here.

These scripts should consume raw content from `artifacts/` and use the Aperas Core API to build the specialized graph structures defined in `schema/`. They can easily extend core logic via standard TypeScript **OOP Class Inheritance** (`class DomainParser extends BaseParser`) or functional **Pipeline Composition** (injecting plugins into `unified.js`).
