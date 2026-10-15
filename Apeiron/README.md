# Apeiron JSON-LD Mirror

This directory is the stored form of the knowledge graph: plain JSON-LD files, one per node class, tracked in git. The ApeironNgn service holds the graph in memory, reads these files into it at start (`rehydrateStore`, `store.ts`) and writes the store back to them (`dehydrateToJsonLd`, `dehydrate.ts`). The `aperas` CLI reaches the graph through that service, not through these files. The service replaced a TerminusDB database, which these files used to mirror.

## Files

| File | Holds |
|---|---|
| `ArtifactNode.jsonld` | One node per tracked document, carrying its path and its ingest and projection hashes. |
| `FolderNode.jsonld` | One node per folder of the artifacts tree. |
| `BlockNode.jsonld` | The blocks (headings, paragraphs, lists) every document is made of. |
| `Profile.jsonld` | The profiles, with a `handle` and optional `name` and `kind`. |
| `.state/` | Git-ignored: `TreeView.jsonld` (every view and its fold state), and the `BlockNode`, `ArtifactNode` and `FolderNode` documents that sit under `.threads/`. It need not exist on a fresh checkout. |

`Link` and `StringProp` have no files of their own: they are embedded in the `links`, `props` and `preferences` of the document that owns them.

## Format

Each file is a JSON array of documents, sorted by `@id`, written with two-space indentation and a trailing newline. A document lists its fields in the order the class shape declares them (`shape.ts`), after `@id` and `@type`. A field that is unset or an empty set is left out, except `children`, which is always written, as `[]` when empty:

- `BlockNode`: `links`, `props`, `tombstonedAt`, `holder`, `title`, `text`, `parent`, `type`, `children`
- `ArtifactNode`: the same, then `path`, `fileHash`, `lastTrackedAt`, `ingestedHash`, `lastIngestedAt`, `projectedHash`
- `FolderNode`: `links`, `props`, `tombstonedAt`, `holder`, `title`, `text`, `parent`, `path`, `children`, `projectedHash`
- `Profile`: `handle`, `name`, `kind`, `preferences`
- `TreeView`: `profile`, `name`, `unfolds`, `root`

An embedded `Link` has `@id`, `@type`, `target`, `predicate`, `props`; an embedded `StringProp` has `@id`, `@type`, `key`, `value`. Embedded entries are sorted by `@id` within their field. Containment is stated twice in a file, in the `children` of the container and in the `parent` of each child; the load reads the `parent` as written, and the data keeps the two in agreement.

Rehydrating the files and then dehydrating returns them byte for byte, so a flush with no change leaves git clean. Every ordering above exists to keep that true.

## Who writes them

Only the service writes these files, when it flushes: after a mutating command run with `--flush`, on `aperas flush`, on a timer while changes are pending, and at shutdown. A flush rewrites a whole class file. If a file changed on disk since the service last read it (a `git pull`, a hand edit) while changes are pending, the flush refuses and writes nothing; `aperas reload --discard` keeps the disk version and `aperas flush --clobber` keeps the in-memory one. Change the graph with `aperas` commands rather than by editing these files.
