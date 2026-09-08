# Internal Linking & Addressing

<a name='---context' class='aperas-anchor aperas-tree'></a>
## Context
- **Discussion**: [Why this syntax, and what we considered instead](../discussion/linking.md).
- **Issues**: [No open design questions; pending implementation tasks](../issues/linking.md#---pending-tasks).
- **History**: [Convention timeline](../history/linking.md#---milestones).

<a name='---architecture' class='aperas-anchor aperas-tree'></a>
## Architecture
A markdown document in the corpus can reference another node (an artifact, a folder, a heading, a block) both before it has ever been ingested into Apeiron and after. The two addressing styles this implies aren't two permanent, freely-interchangeable choices — they map to a lifecycle (see [discussion](../discussion/linking.md#---the-trade-off-that-doesn-t-go-away)):

- **Slugified-path addressing**: a path of `slugify()`-derived segments, computable directly from the raw markdown text itself. This is deliberately manual, and the only option before ingestion: a writer hand-injects it while authoring or refactoring a doc, before any node id exists to reference instead.
- **Node-ID addressing**: a stable, opaque identifier (a snowflake, minted once at node creation, never derived from or invalidated by content) that only exists *after* ingestion.

Ingestion mints a node id and adds an `id/<ID>` anchor to the target block, alongside its existing slug-path anchor — not replacing it — then projects the result back to the file mirror. Because the old anchor isn't removed, every existing referring link keeps resolving unchanged; nothing needs to find or rewrite them. The slug-path anchor is only ever a compatibility bridge, though, not a second permanent form: it stays until every referrer has itself been ingested and so no longer needs it, at which point a cleanup pass removes it (see [Anchors](#---topology/----anchors), [Issues](../issues/linking.md#---pending-tasks)).

<a name='---topology' class='aperas-anchor aperas-tree'></a>
## Topology
The canonical stored form for any internal reference is a standard CommonMark link, `[title](target)`. No separate bracket syntax (`[[link]]`) is needed for this, at least for now — the syntactic markers below already make an internal reference unambiguous without an extra wrapper (see [discussion](../discussion/linking.md#---landing-on-standard-links---injected-anchors)).

Two syntactic contexts apply orthogonally to the two addressing styles from Architecture.

<a name='---topology/----in-app-context' class='aperas-anchor aperas-tree'></a>
### In-App Context
Resolved directly against the graph by Apeiron's own tooling (`kg:tree`, `kg:unfold`, a future webapp), never against files on disk. Canonical syntax uses the `aperas://` scheme:
- `[title](aperas://tree/<block-slug-path>)`: slugified-path addressing.
- `[title](aperas://id/<ID>)`: node-ID addressing.

<a name='---topology/----projected-pre-ingestion-context' class='aperas-anchor aperas-tree'></a>
### Projected/Pre-Ingestion Context
A markdown file meant to also work as a plain file on disk (a projected artifact, or a doc being authored/refactored before ingestion). Compatible syntax uses an ordinary relative file link with a `#fragment`:
- `[title](../folder/file#<block-slug-path>)`: slugified-path addressing.
- `[title](../folder/file#id/<ID>)`: node-ID addressing, the literal `id/` fragment prefix distinguishing it from a slug-path fragment; backed by a `name="id/<ID>"` anchor, same mechanism as the slug-path form (see [Anchors](#---topology/----anchors)).

`<ID>` is always the full `Kind:snowflake` form (e.g. `BlockNode:00C5H15NT0000`), never a bare snowflake alone.

The trailing address — `<block-slug-path>` or `id/<ID>` — is identical in both contexts; only the leading part differs (`aperas://tree/` / `aperas://id/` vs. a relative file path followed by `#`). Translating a reference between the two contexts is therefore only ever a leading-part swap, never a change to the trailing address itself.

<a name='---topology/----anchors' class='aperas-anchor aperas-tree'></a>
### Anchors
A target block carries an `<a>` tag immediately before it, tagged with a `class` identifying which kind of anchor it is. Before ingestion:
```markdown
<a name='---sub-1/----sub-1-1' class='aperas-anchor aperas-tree'></a>
### Sub 1.1
```
After ingestion, once a node id exists, the id anchor is added alongside — the slug-path anchor stays, for now:
```markdown
<a name='---sub-1/----sub-1-1' class='aperas-anchor aperas-tree'></a>
<a name='id/BlockNode:00C5H15NT0000' class='aperas-anchor aperas-id'></a>
### Sub 1.1
```
`aperas-tree` marks a compatibility anchor, kept only until every referrer has migrated; `aperas-id` marks the permanent one. The class is what makes a later cleanup pass able to find and remove `aperas-tree` anchors that are no longer referenced, rather than leaving them to accumulate indefinitely (see [Issues](../issues/linking.md#---pending-tasks)).

- `name` holds the address — either `<block-slug-path>` or `id/<ID>`, the same literal-prefix convention as the link fragment. `<block-slug-path>` is the `/`-joined `slugify()` output of every segment from the document root down to the target; each segment is `slugify()` applied to the block's own raw title text — a heading's raw line (`#`/`##` markers included), or, at unbounded depth in a list, a colon-delimited lead-in term (see [Issues](../issues/linking.md#---resolved)). Hand-written by the author pre-ingestion; ingestion adds the `id/<ID>` form alongside it (see [Workflows](#---workflows)).
- `id` is left unassigned by this design — `name` is for anchor/fragment-navigation, `id` is for the (future) webapp's own HTML element management, a different concern this doc doesn't specify. It's also why the slug-path form couldn't go there regardless: `id` values shouldn't contain `/`, and a slug-path does.

<a name='---topology/----full-path-collisions' class='aperas-anchor aperas-tree'></a>
### Full-Path Collisions
Two blocks must never resolve to the same full `<block-slug-path>` — a hard authoring error (reject at anchor-injection/ingestion time), not a case needing disambiguation. Reusing the same heading *title* at different tree positions is ordinary (e.g. two sibling sections each with their own "Overview" subheading) and never collides, since their full paths differ by their distinct ancestor segments; only two blocks at the exact same tree position with the exact same heading text would produce an identical full path, which is a genuine duplicate.

<a name='---workflows' class='aperas-anchor aperas-tree'></a>
## Workflows
Authoring a cross-reference before ingestion: compute the target's slug path and write it as a standard link with a `#fragment`, backed by a hand-written `<a name="..." class="aperas-anchor aperas-tree">` anchor placed just before the target heading.

At ingestion: the target's node id is minted, and an `<a name="id/<ID>" class="aperas-anchor aperas-id">` anchor is added alongside the block's existing slug-path anchor — then the result is projected back to the file mirror. Existing referring links keep resolving against the slug-path anchor unchanged; nothing needs to find or rewrite them. The anchor's `id` attribute itself is not written by this; it's left for the webapp's own future use.

Authoring a cross-reference after ingestion, where the target already has a node id: address it directly with the `id/<ID>` (or `aperas://id/<ID>`) form.

Once every referrer has itself been ingested and so no longer needs the compatibility form, a cleanup pass removes the block's `aperas-tree` anchor, leaving only `aperas-id`.
