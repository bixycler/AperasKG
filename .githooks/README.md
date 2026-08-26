# Git hooks

`core.hooksPath` is a local git config, not something a clone picks up automatically. On a fresh
checkout of this repo, run once:

```bash
git config core.hooksPath .githooks
```

## post-commit

Runs `npm run kg:track` (in the sibling `Aperas/web` directory) whenever a commit touches any
`artifacts/*.md` file, so `ArtifactNode`s stay in sync without a manual step. Failures are logged
but don't block anything — the commit has already completed by the time a post-commit hook runs.

## post-index-change

Covers what `post-commit` doesn't: branch switches (`git checkout`/`git switch`) and `git reset`
(including `--hard`, which fires no git hook of its own) — anything that writes the index outside
of a commit. This hook gets no before/after ref pair, and fires for index writes generally, not
just checkout/reset specifically, so it runs an unscoped `npm run kg:track` sweep rather than a
targeted diff, skipped entirely when the working tree wasn't actually touched (e.g. `git reset`
without `--hard`). Cheap even though unscoped: each artifact's content hash is compared against
its last-tracked hash, so unaffected files no-op.

A dedicated `post-checkout` hook was tried first but dropped: every working-tree-changing checkout
already writes the index too, so `post-index-change` fires alongside it and its unscoped sweep
already covers the same artifacts — confirmed live, both hooks fired back-to-back on the same
`checkout` with fully overlapping coverage. `post-checkout` only added a *scoped* diff (log exactly
which artifacts changed) over `post-index-change`'s unscoped sweep, not any missing coverage — not
worth the duplicate `kg:track` invocation on every checkout.

Together, `post-commit` (scoped, cheap, the common case) and `post-index-change` (unscoped safety
net for everything else that moves `HEAD` or the working tree) are the closest coverage git's hook
system allows — there's no single hook that catches all working-tree changes uniformly.
