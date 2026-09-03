# Git hooks

`core.hooksPath` is a local git config, not something a clone picks up automatically. On a fresh
checkout of this repo, run once:

```bash
git config core.hooksPath .githooks
```

## pre-commit

Runs `npm run kg:track:ngn` (in the sibling `Aperas/web` directory) for whatever `artifacts/*.md`
files are staged in this commit, then `git add`s the `Apeiron/*.jsonld` mirror files it updates —
so the mirror sync lands *in the same commit* as the artifact change it reflects, not as a
separate leftover working-tree change sitting there right after a post-commit hook runs (this used
to be a `post-commit` hook; moved to `pre-commit` specifically to fix that). Failures are logged
and the commit is allowed to proceed anyway (`exit 0`) rather than blocked — re-run
`npm run kg:track:ngn` manually and re-commit if you want the sync retried. A staged deletion is a
known gap: the scoped path mode reads the file from disk to hash it, so it fails for a path that
no longer exists — only `post-index-change`'s unscoped sweep (below) catches removals.

## post-index-change

Covers what `pre-commit` doesn't: branch switches (`git checkout`/`git switch`) and `git reset`
(including `--hard`, which fires no git hook of its own) — anything that writes the index outside
of a commit. This hook gets no before/after ref pair, and fires for index writes generally, not
just checkout/reset specifically, so it runs an unscoped `npm run kg:track:ngn` sweep rather than a
targeted diff, skipped entirely when the working tree wasn't actually touched (e.g. `git reset`
without `--hard`). Cheap even though unscoped: each artifact's content hash is compared against
its last-tracked hash, so unaffected files no-op.

A dedicated `post-checkout` hook was tried first but dropped: every working-tree-changing checkout
already writes the index too, so `post-index-change` fires alongside it and its unscoped sweep
already covers the same artifacts — confirmed live, both hooks fired back-to-back on the same
`checkout` with fully overlapping coverage. `post-checkout` only added a *scoped* diff (log exactly
which artifacts changed) over `post-index-change`'s unscoped sweep, not any missing coverage — not
worth the duplicate `kg:track:ngn` invocation on every checkout.

Together, `pre-commit` (scoped, cheap, the common case) and `post-index-change` (unscoped safety
net for everything else that moves `HEAD` or the working tree) are the closest coverage git's hook
system allows — there's no single hook that catches all working-tree changes uniformly.
