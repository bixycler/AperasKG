# Linking — History

<a name='---current-status' class='aperas-anchor aperas-tree'></a>
## Current Status
Two internal-reference conventions coexist: node-ID addressing (currently implemented as `[[code]]`-wrapped `Kind:snowflake`, verified in `astParser.ts`/`resolve.ts`; the target design drops the `[[...]]` wrapper in favor of `aperas://id/<ID>` or `#id/<ID>`, see [Architecture](../design/linking.md#---architecture) and [Topology](../design/linking.md#---topology)) and slug-anchor addressing (`#fragment` matched against an injected `<a name="...">`, prototyped but not yet adopted corpus-wide — see [Open Issues](../issues/linking.md#---open-issues)).

<a name='---milestones' class='aperas-anchor aperas-tree'></a>
## Milestones
- **TerminusDB era**: `[title]([[code]])` convention designed and settled — `code` a snowflake/node-id, bare `[[...]]` reserved for a never-built UI auto-expansion, never for hand-typing or parsing on its own (`Aperas-deep-path-resolution-design.md`, `Aperas-markdown-fractal-mapping-design.md` §4, archived under `archive/tdb-era/` — backend superseded, convention carried forward unchanged).
- **ApeironNgn era**: same convention re-implemented and live-verified (`astParser.ts`'s `collectLinkCodes`/`WIKILINK_PREDICATE`, `resolve.ts`'s deep-path grammar) — used extensively in `Aperas-apeironngn-design.md`'s own self-references, in the verbose full-heading-text form, e.g.:
  ```markdown
  [Step 7](<[[/Aperas-apeironngn-design.md/# ApeironNgn: Embedded Substrate Design/4. Rollout sequence/Step 7: `ArtifactNode extends BlockNode`, the root block retired outright, `text` a copied abstract for both — implemented, verified]]>)
  ```
- **2026-09-08**: slug-anchor authoring convention (`slugify()`-derived, `/`-joined segment paths as explicit `<a name>` anchors, referenced via plain `#fragment` links) prototyped and validated live in `test-slugifed-path.md`, as a more compact, pre-ingestion-friendly alternative to hand-typing the full-heading-text `[[deep-path]]` form, e.g.:
  ```markdown
  <a name='---sub-1/----sub-1-1'></a>
  ### Sub 1.1

  [Sub 1.1](#---sub-1/----sub-1-1)
  ```
  Recorded as its own design concern (`design/linking.md`, see [Landing on standard links + injected anchors](../discussion/linking.md#---landing-on-standard-links---injected-anchors)) rather than folded into `documentation`.
