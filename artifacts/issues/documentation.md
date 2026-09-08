# Documentation — Issues

## Open Issues
None.

## Pending Tasks
None.

## Resolved
- **Context/Discussion boundary was undefined.** `design.md`'s skeleton named `# Context` as a heading, while the concern taxonomy filed "motivation" under Discussion Docs — with no stated line between the two, Context could silently regrow into narrative.
  Resolved by defining `# Context` as a factual index: a link plus a brief, non-argumentative summary per linked doc (what exists, not why). Rationale and narrative stay in the linked `discussion.md`, never inline in `design.md`. See [Context](../design/documentation.md/Context) and [Document-Level Skeletons](../design/documentation.md/Topology/Document-Level-Skeletons).
