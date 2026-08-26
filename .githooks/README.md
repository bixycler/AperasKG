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
