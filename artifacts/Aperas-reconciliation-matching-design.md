# Reconciliation Matching — Design

Re-ingesting an already-ingested artifact today just orphans its entire prior `BlockNode` tree. The strategy for doing better was settled in `Aperas-core-ontology-design.md` §1.B and Appendix F; this doc works out the algorithm that actually does it. The design below is settled; nothing has been implemented yet.

## Settled already (prior to this doc)

- Reconciliation fires when `fileHash !== ingestedHash` — an edit landed on disk outside the DB (§1.B).
- The approach is best-effort content matching over the whole tree, not a positional or hash-prefiltered pass — artifacts are bounded, human-document-sized trees, so there's no need to scope the search first (Appendix F).
- A persisted, per-edit-maintained structural hash (`treeHash`) was considered and explicitly dropped, for both identity and reconciliation-scoping purposes (Appendix F).

## Blocking prerequisite: heading nesting must ship first

`astParser.ts` currently treats `heading` as a flat block type — a document's headings and their following content all end up as siblings under the root, with no nesting by heading level (tracked in `Aperas-dev-status.md`). This has to be fixed *before* reconciliation goes live, not after: if reconciliation ships against today's flat shape and the heading fix lands later, every existing document reshapes at once (every block's parent changes), and the matcher will read that as "everything changed," orphaning the whole graph in one re-ingest — precisely the outcome reconciliation exists to prevent. Lists (ordered and unordered) already nest correctly and aren't affected.

## 1. The matching algorithm: Gestalt, not Myers

Chosen deliberately over Myers/LCS-style diffing: Myers optimizes for the fewest edit operations (a machine-optimal cost function); Gestalt Pattern Matching (Ratcliff/Obershelp — the algorithm behind Python's `difflib.SequenceMatcher`) finds the longest matching contiguous run first, then recurses on the remainder either side of it. The two produce different notions of "correct" — Myers can produce confusing criss-cross matches around repeated content (the same reason git offers `--patience`/`--histogram` as alternatives to its default Myers diff), where what matters for reconciliation isn't a compact edit script, it's whether the match a human would recognize as "the same block, edited" is the one preserved. Natural-over-optimal is the right cost function here, since the actual consequence of a match is whether a `BaseLink`/`Assertion` stays attached to what a person would agree is the same content.

Applied recursively, level by level: the root is always trivially matched (one root per `ArtifactNode`); for any matched parent pair, their `children` lists are diffed in two stages, then each matched child pair recurses into its own children.

**Stage A — anchor on leaf content.** Filter each level's children down to content-bearing nodes (`heading`, `paragraph`, `code`) and run Gestalt on that subsequence. The comparison key is **heading XOR text**: a heading's own line when the node is a heading, its own `text` otherwise — never the placeholder `title` a non-heading block currently carries (which is just its own `blockId`, and would always differ between old and new by construction, silently defeating any matcher that touched it).

**Stage B — anchor containers by context, not content.** Container-type nodes (`list`, `listItem`, `blockquote`) carry no reliable content of their own to compare (see the container-text gap below) — and don't need to. Their meaning comes from what's written around them ("...with the following list:", "The quote above is..."), so the leaf matches from Stage A partition both children lists into segments (before the first anchor, between each consecutive anchor pair, after the last); within a segment, containers align to their counterpart by type and relative position. No subtree signature, no hash, transient or otherwise — the surrounding matched prose is the anchor.

**Gap to close alongside this**: `list`/`listItem` currently store the *entire subtree's* raw slice as their own `text` — confirmed live, e.g. a `listItem`'s `text` byte-for-byte duplicated one level down in its own paragraph child. Container-type nodes should carry no own `text` at all; content lives only in their leaf descendants. This is what makes Stage B's "containers have no content to compare" true by design rather than by omission.

## 2. Duplicate/ambiguous leaves: let it go

If two leaf blocks with identical content can't be told apart by context (unanchored by anything on either side, the "two Notes blocks" case), decline to match rather than guess. Both old candidates get tombstoned, the new one mints a fresh id. Precision over recall — a wrong guess silently misattributes whatever pointed at the old block to its content-twin; declining just means the tombstone stands unresolved, which is visible and inspectable rather than silently wrong.

## 3. Fate of unmatched old blocks: explicit tombstone

Not implicit (a document that just stops being referenced carries no signal it was ever a deliberate removal, versus an orphan-by-bug, versus mid-reconciliation limbo — that's not a weaker tombstone, it isn't one at all). An explicit `tombstonedAt` field, set when a node is determined to have no match: removed from whatever `children`/`root` list held it, but the document persists at its own `@id` — any edge still resolves, and can render "removed on `<date>`" instead of either dangling silently or reattaching to the wrong thing.

Applies uniformly across `BlockNode`, `ArtifactNode`, and `FolderNode` (see §4).

## 4. Scope: the whole infinite tree, and a prerequisite identity fix

Reconciliation covers `FolderNode`/`ArtifactNode` structural drift too, not just within-artifact `BlockNode` content — a file renamed or moved on disk is the same kind of event as a block moved to a different section, and gets the same treatment.

This surfaced a real prerequisite: `ArtifactNode`/`FolderNode` were Lexical-keyed on `path`, an undesigned choice from an early prototyping pass, not a deliberated one. That's the same category error Appendix F already fixed once for `BlockNode` — identity conflated with a mutable property, content there, location here — and it means a rename is destructive by construction (the `@id` is recomputed from the new path, so the old identity, and everything that referenced it, breaks). **Resolved**: `ArtifactNode`/`FolderNode` get Snowflake-generated ids like `BlockNode`; `path` becomes an ordinary mutable field. A detected rename becomes a field update on the existing document, not a new identity — no tombstone-and-transplant needed for the artifact/folder itself (only `root`/tree-content ever needed transplanting, and only because the container around it couldn't survive a move under the old scheme). Full rationale in `Aperas-core-ontology-design.md` Appendix G.

This also means `ArtifactNode` needs `title`/`text` fields it didn't have before — the folding philosophy (§5) applied uniformly: full dir tree → README → abstract (`text`, first paragraph as a naive stand-in until real AI summarization exists) → filename (`title`).

**Matching rule for files/folders — title first, abstract as fallback, not "never trust the name."** Unlike a non-heading block's placeholder title (always meaningless, always differs), a filename is a real, human-authored, sticky signal — the same category as a heading's own text. So: match unchanged paths trivially (already free — `path` is a plain field now, so an unchanged path is an exact match with no reconciliation logic needed at all). For the leftover set only (an old path gone from disk, a new file with no tracked `ArtifactNode`), fall back to matching by `text` (abstract) similarity to detect a genuine rename — same "let it go if ambiguous" rule as leaf blocks. A rename is a real, deliberate edit (like changing a heading), not something to be blind to by default; it should just take a radical-enough change in the abstract to actually get missed.

Cost check before committing: a `path`-filtered query replacing today's free direct-id lookup benchmarked *faster* (~7.5ms vs ~48ms at 50 documents) — not a cost at all. Losing the database-enforced path-uniqueness guarantee is real in shape (an application-level check-then-upsert race could in principle create duplicate paths) but not practically significant given this project's actual deployment — one local TerminusDB per machine, reconciled via fetch/push, not concurrent writers against a shared server.

## 5. Visibility: report changed and moved, not just added/removed

A wrong match is silent by nature — nothing errors, an edge just ends up pointing at different content than a human expects — so a reconciliation pass should produce a summary. Not just counts of added/removed: **changed** and **moved** are their own categories, and they're not separate machinery, they fall directly out of classifying each match's outcome, applied uniformly at every level of the fractal tree (`FolderNode`/`ArtifactNode`/`BlockNode`):

- same content, same position/path → unchanged
- same content, different position/path → **moved**
- different content, same identity → **changed**
- no match → added (new) or removed (tombstoned)

A renamed file is the `ArtifactNode`-level instance of the same operation as a block moved to a different section: an orphaned old path matched against an untracked new path by content similarity, one mechanism, three fractal layers.
