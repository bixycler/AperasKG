# Internal Linking & Addressing <a name='id/BlockNode:00CDBYV4T0001' class='aperas-anchor aperas-id'></a>

## Context <a name='id/BlockNode:00CDBYV4T0002' class='aperas-anchor aperas-id'></a>

- **Discussion**: <a name='id/BlockNode:00CDBYV4T0004' class='aperas-anchor aperas-id'></a> [Why this syntax, and what we considered instead](../discussion/linking.md).
- **Issues**: <a name='id/BlockNode:00CDBYV4T0005' class='aperas-anchor aperas-id'></a> [No open design questions; pending implementation tasks](../issues/linking.md#id/BlockNode:00CDBYV5A8003).
- **Planning**: <a name='id/BlockNode:00CDBYV4T8000' class='aperas-anchor aperas-id'></a> [First implementation slice](../planning/linking.md).
- **History**: <a name='id/BlockNode:00CDBYV4T8001' class='aperas-anchor aperas-id'></a> [Convention timeline](../history/linking.md#id/BlockNode:00CDBZ7698003).

## Architecture <a name='id/BlockNode:00CDBYV4T8002' class='aperas-anchor aperas-id'></a>

A markdown document in the corpus can reference another node (an artifact, a folder, a heading, a block) both before it has ever been ingested into Apeiron and after. The two addressing styles this implies aren't two permanent, freely-interchangeable choices — they map to a lifecycle (see [discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TG001)):

- **Slugified-path addressing**: <a name='id/BlockNode:00CDBYV4T8003' class='aperas-anchor aperas-id'></a> a path of `slugify()`-derived segments, computable directly from the raw markdown text itself. This is deliberately manual, and the only option before ingestion: a writer hand-injects it while authoring or refactoring a doc, before any node id exists to reference instead.
- **Node-ID addressing**: <a name='id/BlockNode:00CDBYV4T8004' class='aperas-anchor aperas-id'></a> a stable, opaque identifier (a snowflake, minted once at node creation, never derived from or invalidated by content) that only exists *after* ingestion.

Ingestion mints a node id for the target block, in the graph only. Projecting that block back to the file mirror is the step that adds an `id/<ID>` anchor alongside its existing slug-path anchor — not replacing it (ingestion never writes to disk at all; see [Workflows](#id/BlockNode:00CDBYV4TG007)). Because the old anchor isn't removed, every existing referring link keeps resolving unchanged; nothing needs to find or rewrite them. The slug-path anchor is only ever a compatibility bridge, though, not a second permanent form: it stays until every referrer has itself been ingested and so no longer needs it, at which point a cleanup pass removes it (see [Anchors](#id/BlockNode:00CDBYV4T800H), [Issues](../issues/linking.md#id/BlockNode:00CDBYV5A8003)).

This guarantee is about ingestion specifically — a heading's *title* changing later is a separate, manual, untracked event with no equivalent promise: resolution always re-`slugify()`s a candidate's *current* title live, so a bare slug-path fragment written against a pre-rename title simply has no path back to the renamed block once it stops matching. See [Discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TG002) and [Resolved: "No automated rename repair"](../issues/linking.md#id/BlockNode:00CDBYV5A800A).

## Topology <a name='id/BlockNode:00CDBYV4T8007' class='aperas-anchor aperas-id'></a>

The canonical stored form for any internal reference is a standard CommonMark link, `[title](target)`. No separate bracket syntax (`[[link]]`) is needed for this, at least for now — the syntactic markers below already make an internal reference unambiguous without an extra wrapper (see [discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TG002)).

Two syntactic contexts apply orthogonally to the two addressing styles from Architecture.

### In-App Context <a name='id/BlockNode:00CDBYV4T8009' class='aperas-anchor aperas-id'></a>

Resolved directly against the graph by Apeiron's own tooling (`kg:tree`, `kg:unfold`, a future webapp), never against files on disk. Canonical syntax uses the `aperas://` scheme:

- `[title](aperas://tree/<block-slug-path>)`: <a name='id/BlockNode:00CDBYV4T800A' class='aperas-anchor aperas-id'></a> slugified-path addressing.
- `[title](aperas://id/<ID>)`: <a name='id/BlockNode:00CDBYV4T800B' class='aperas-anchor aperas-id'></a> node-ID addressing.

### Projected/Pre-Ingestion Context <a name='id/BlockNode:00CDBYV4T800C' class='aperas-anchor aperas-id'></a>

A markdown file meant to also work as a plain file on disk (a projected artifact, or a doc being authored/refactored before ingestion). Compatible syntax uses an ordinary relative file link with a `#fragment`:

- `[title](../folder/file#<block-slug-path>)`: <a name='id/BlockNode:00CDBYV4T800D' class='aperas-anchor aperas-id'></a> slugified-path addressing.
- `[title](../folder/file#id/<ID>)`: <a name='id/BlockNode:00CDBYV4T800E' class='aperas-anchor aperas-id'></a> node-ID addressing, the literal `id/` fragment prefix distinguishing it from a slug-path fragment; backed by a `name="id/<ID>"` anchor, same mechanism as the slug-path form (see [Anchors](#id/BlockNode:00CDBYV4T800H)).

`<ID>` is always the full `Kind:snowflake` form (e.g. `BlockNode:00C5H15NT0000`), never a bare snowflake alone.

The trailing address — `<block-slug-path>` or `id/<ID>` — is identical in both contexts; only the leading part differs (`aperas://tree/` / `aperas://id/` vs. a relative file path followed by `#`). Translating a reference between the two contexts is therefore only ever a leading-part swap, never a change to the trailing address itself.

### Anchors <a name='id/BlockNode:00CDBYV4T800H' class='aperas-anchor aperas-id'></a>

A target block carries its anchor(s) inline, tagged with a `class` identifying which kind — never as a separate preceding line. `<a>` isn't a CommonMark block-level HTML tag, so a standalone `<a name=...></a>` line doesn't stay structurally inert: it parses as an ordinary paragraph and gets consumed as the following heading's own leading text, reordering it on projection and, where real leading prose already exists, displacing that prose into a separate block (see [Discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TG004)). Placement is block-shape-specific:

**Heading** — appended to the end of the heading's own line. Before ingestion:

```markdown
### Sub 1.1 <a name='--top-heading/---sub-1/----sub-1-1' class='aperas-anchor aperas-tree'></a>
```

After ingestion, once a node id exists, the id anchor is added alongside:

```markdown
### Sub 1.1 <a name='--top-heading/---sub-1/----sub-1-1' class='aperas-anchor aperas-tree'></a><a name='id/BlockNode:00C5H15NT0000' class='aperas-anchor aperas-id'></a>
```

**List item / paragraph** — inline, right after the lead-in colon:

```markdown
- **Term**: <a name='id/BlockNode:00C5H15NT0000' class='aperas-anchor aperas-id'></a> rest of text
```

`aperas-tree` marks a compatibility anchor, kept only until every referrer has migrated; `aperas-id` marks the permanent one. `aperas-id` is expected to dominate now that editing goes through the graph directly (`kg:insert`/`kg:update`, then `kg:project` to disk) — a block created or renamed straight in the graph already has a real id, with no pre-ingestion phase needing a placeholder at all. `aperas-tree` is left for the rare remaining case: hand-editing markdown without access to a running Apeiron service, where no id exists yet to reference. The class is what makes a later cleanup pass able to find and remove `aperas-tree` anchors that are no longer referenced, rather than leaving them to accumulate indefinitely (see [Issues](../issues/linking.md#id/BlockNode:00CDBYV5A8003)).

- `name` holds the address — either `<block-slug-path>` or `id/<ID>`, the same literal-prefix convention as the link fragment. `<block-slug-path>` is the `/`-joined `slugify()` output of every segment from the document root down to the target; each segment is `slugify()` applied to the block's own raw title text — a heading's raw line (`#`/`##` markers included), or, at unbounded depth in a list, a colon-delimited lead-in term (see [Issues](../issues/linking.md#id/BlockNode:00CDBYV5A800A)). Hand-written by the author pre-ingestion; projecting the block back to the file mirror adds the `id/<ID>` form alongside it (see [Workflows](#id/BlockNode:00CDBYV4TG007)).
- `id` is left unassigned by this design — `name` is for anchor/fragment-navigation, `id` is for the (future) webapp's own HTML element management, a different concern this doc doesn't specify. It's also why the slug-path form couldn't go there regardless: `id` values shouldn't contain `/`, and a slug-path does.

For a heading, the anchor is stripped out of the raw line before it's used as `title`, and kept separately (see [Workflows](#id/BlockNode:00CDBYV4TG007)) — `title` itself stays clean. For a list item or paragraph, nothing is stripped: `text` keeps the anchor exactly where it was written (right after the lead-in colon), unmodified — the block's `title` is a separately-extracted, read-only label taken from the span before the colon, never subtracted out of `text`. That's safe specifically because a list item/paragraph's `text` is what gets rendered back to markdown; `title` isn't independently serialized for these the way it is for a heading, so there's nothing to reassemble.

### Lead-In Term Detection <a name='id/BlockNode:00CDBYV4TG000' class='aperas-anchor aperas-id'></a>

A list item or paragraph's lead-in term (the colon-delimited title an unbounded-depth list uses in place of a heading — see [Issues](../issues/linking.md#id/BlockNode:00CDBYV5A800A)) is found by walking the block's own parsed inline structure, not by scanning raw characters: a candidate colon (`:`, or `：` for Japanese) is only accepted if it sits in plain visible text — never inside inline code (`` `Kind:snowflake` ``'s own colon is data, not punctuation) and never inside a `**bold**`/`*italic*` span. A rejected candidate doesn't end the search; scanning continues for a later one in the same text.

Two further checks, best-effort rather than exact (a wrongly-detected term is corrected the same way any title now is — edit the lead-in term itself in the text; there's no separate override any more, see [History](../history/linking.md#id/BlockNode:00CDBZ7698003)):

- **Length cap**: <a name='id/BlockNode:00CDC0D598000' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CDBYV4TG002' class='aperas-anchor aperas-id'></a> the visible (non-code) text before the colon must be short — at most 10 words for a space-delimited script, or 20 characters for Japanese (no spaces to count words by). A lead-in term is always short in every real example; a colon only reachable after a long run of ordinary prose is a real English sentence's own internal colon, not a lead-in delimiter — confirmed live that sentence-boundary detection alone doesn't discriminate that case, only length does.
- **Space after the colon** (space-delimited scripts only): <a name='id/BlockNode:00CDC0D598001' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CDBYV4TG003' class='aperas-anchor aperas-id'></a> a genuine lead-in always reads "Term: rest", space included, whereas a technical string that simply never got wrapped in backticks (a bare `aperas://tree/...` URL, a `key:value` pair) almost never has a space right after its own colon. This catches what the inline-code exclusion above can't: a colon that's real data, just not properly fenced as such. Nothing following the colon at all — its own inline content simply ends there, e.g. a lead-in immediately followed only by nested list children, no inline "rest" on the same line — counts the same as a space: there's no adjacent non-space character to be suspicious of.

Which script's rules apply is read from a `lang: en|ja|vi` frontmatter field (English, Japanese, Vietnamese — the first three supported), defaulting to `en`. Vietnamese, like English, is space-delimited and uses the word-count cap; only Japanese uses the character-count cap and skips the space-after-colon check (Japanese prose isn't space-delimited at all).

### Anchor-Matching Requirement for Resolution <a name='id/BlockNode:00CDBYV4TG005' class='aperas-anchor aperas-id'></a>

Finding a name-token or id match for a reference's target (the existing deep-path walk, or a direct id lookup) only produces a *candidate* — it's accepted as the actual resolution target only if that candidate also carries a `class="aperas-anchor"` tag whose `name` equals the fragment being resolved (the heading's stashed anchor, or a literal scan of a list item's/paragraph's own `text`). A block nobody tagged is never mistaken for a link target this way, which is what disambiguates an internal reference from an ordinary, unrelated same-page anchor link (e.g. `[jump to top](#top)`) now that there's no `[[...]]`-style wrapper marking intent the way there was before (see [Discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TG006)).

### Full-Path Collisions <a name='id/BlockNode:00CDBYV4TG006' class='aperas-anchor aperas-id'></a>

Two blocks must never resolve to the same full `<block-slug-path>` — a hard authoring error (reject at write time: ingestion, `kg:insert`, or `kg:update`), not a case needing disambiguation. Reusing the same heading *title* at different tree positions is ordinary (e.g. two sibling sections each with their own "Overview" subheading) and never collides, since their full paths differ by their distinct ancestor segments; only two blocks at the exact same tree position with the exact same heading text would produce an identical full path, which is a genuine duplicate.

## Workflows <a name='id/BlockNode:00CDBYV4TG007' class='aperas-anchor aperas-id'></a>

Authoring a cross-reference before ingestion: compute the target's slug path and write it as a standard link with a `#fragment`, backed by a hand-written `<a name="..." class="aperas-anchor aperas-tree">` anchor placed inline on the target's own line — appended to the heading's line, or right after a list item's lead-in colon (see [Anchors](#id/BlockNode:00CDBYV4T800H)).

At ingestion: <a name='id/BlockNode:00CDC0D598006' class='aperas-anchor aperas-id'></a> <a name='id/BlockNode:00CDBYV4TG008' class='aperas-anchor aperas-id'></a> the target's node id is minted, in the graph only — nothing is written to disk yet. Projecting that block back to the file mirror is what adds an `<a name="id/<ID>" class="aperas-anchor aperas-id">` anchor alongside the block's existing slug-path anchor: appended at line end for a heading; spliced into `text` right after the lead-in colon for a list item or paragraph, leaving the rest of `text` untouched, and only if `text` doesn't already contain that block's own id-anchor (idempotent — re-projecting an already-anchored block doesn't duplicate it). Existing referring links keep resolving against the slug-path anchor unchanged; nothing needs to find or rewrite them. The anchor's `id` attribute itself is not written by this; it's left for the webapp's own future use.

Authoring a cross-reference after ingestion, where the target already has a node id: address it directly with the `id/<ID>` (or `aperas://id/<ID>`) form.

Once every referrer has itself been ingested and so no longer needs the compatibility form, a cleanup pass removes the block's `aperas-tree` anchor, leaving only `aperas-id`.

A referring artifact's own text not changing is not the same as its links staying resolved: the target of a link is free to change shape (a rename, a newly-created anchor, an artifact ingested for the first time) without the referrer's text moving at all, and an artifact whose file hash is unchanged since its last ingestion is never re-ingested on its own — nothing would otherwise re-run its link resolution against the graph's current state. `kg:ingest` closes this gap with a small retry mechanism: every code a block fails to resolve is stashed on its own artifact (one `danglingRef` prop per distinct code, rewritten wholesale — not appended to — on every ingestion, so a code that stops applying disappears with it); after the explicitly-requested artifacts and the folder tree are both settled, every live artifact's stashed codes are retried against the current graph, and any artifact with at least one now-resolvable code is force-reingested — its own text is unchanged, so this is a link-resolution refresh, not a real re-parse, but it goes through the same reconciliation path as any other ingestion (see [Discussion](../discussion/linking.md#id/BlockNode:00CDBZ76TR008) for why re-ingesting isn't the same as re-parsing here, and why one retry pass rather than a fixed-point loop). This applies uniformly to every code form, including a `#fragment` link that never got flagged as dangling in the first place (most never resolve, by design — see [Anchor-Matching Requirement for Resolution](#id/BlockNode:00CDBYV4TG005)): it's retried silently either way, just never warned about.
