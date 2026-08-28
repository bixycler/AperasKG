# Domain Ontology

This directory is an extension point for the community to define domain-specific predicate vocabularies.

Aperas adopts **Edge Subclassing (OOP)** for relationships. Instead of using raw strings for predicates, KGs define edges as schema classes that inherit from core base classes (e.g., `BaseEdge` or `AffectsEdge`).

This unlocks native WOQL subsumption (`isa()` queries), allowing the graph to mathematically guarantee that querying a parent edge type automatically fetches all specialized child edges defined by the community.

Place your ontology schema and `predicates.jsonld` definitions here.
