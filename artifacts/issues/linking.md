# Linking — Issues

<a name='---open-issues' class='aperas-anchor aperas-tree'></a>
## Open Issues
- **Collision check only covers a block's current slug-path.** Since anchors accumulate (a block can carry more than one `name` over its history — see [Anchors](../design/linking.md#---topology/----anchors)), a new block could in principle collide with another block's *retired* name, not just a currently-live one. Not addressed by the Full-Path Collisions rule as written.

<a name='---pending-tasks' class='aperas-anchor aperas-tree'></a>
## Pending Tasks
- Implement colon-delimited lead-in-term title extraction in `astParser.ts` (today only headings produce a title; list items/paragraphs fall back to the snowflake id).
- Roll the colon-outside-bold lead-in convention out to the rest of the corpus — normalized so far only in the `linking` concern's own docs.
- Implement ingestion-time anchor addition: mint the node id and add an `id/<ID>` anchor, tagged `class="aperas-anchor aperas-id"`, alongside the block's existing `aperas-anchor aperas-tree` slug-path anchor, then project the result back to the file mirror (the anchor's `id` attribute itself is left unwritten — reserved for the webapp's own future use).
- Implement the cleanup pass that removes an `aperas-tree` anchor once every referrer has migrated off it.
- Migrate `Aperas-apeironngn-design.md`'s existing `[[deep-path]]`-wrapped self-references to the `aperas://`/`#fragment` forms.
- Convert `issues/documentation.md`'s two remaining links (`../design/documentation.md/Context`, `.../Topology/Document-Level-Skeletons`), still written in the pre-`aperas://`/`#fragment` bare-path form.
- Build the leading-part translator between the in-app (`aperas://tree/`, `aperas://id/`) and compatible (`../folder/file#`) syntaxes.
- Implement parser support for the target design — `astParser.ts`'s `collectLinkCodes` currently only recognizes the older `[title]([[code]])` wrapped form, not a plain `aperas://` scheme URL or a `#id/<ID>`/`#<block-slug-path>` fragment.
- Enforce the full-slug-path-collision rejection at anchor-injection/ingestion time (see [Topology](../design/linking.md#---topology)).

<a name='---resolved' class='aperas-anchor aperas-tree'></a>
## Resolved
- **Heading-in-list**: resolved — a block's title isn't limited to headings, which cap at H6 and don't fit an unbounded tree. Any block whose text opens with a colon-delimited lead-in term (`Term: rest of the text`) uses that term as its title; the colon, outside any bold, is the sole structural delimiter — bold/`**...**` around the term is a free style choice, not part of the rule, and its `**` characters slugify like any other non-alphanumeric character if present, same as headings' `#` markers. List nesting carries unbounded depth the same way heading nesting carries bounded depth. See [Architecture](../design/linking.md#---architecture).
- **`[[deep-path]]` coexistence**: not needed, at least for now — `aperas://` scheme URLs (in-app) and `#fragment`s (compatible/pre-ingestion), including an `id/<ID>` fragment form, already make an internal reference unambiguous without a `[[...]]` wrapper. See [Topology](../design/linking.md#---topology).
- **"No automated rename repair"**: misdiagnosed — a rename adds an anchor rather than replacing one, so an old reference doesn't break at rename time; there's nothing to repair, only a later cleanup once it's actually safe. See [Architecture](../design/linking.md#---architecture).
- **"Duplicate-slug collisions"**: misdiagnosed — a collision only happens when two blocks share an identical *full* slug-path (same heading text at the exact same tree position), a genuine authoring error, correctly a hard reject, not a case needing disambiguation logic. Reusing the same heading title at different tree positions is ordinary and never collides, since the full path includes the distinguishing ancestor segments. See [Topology](../design/linking.md#---topology).
