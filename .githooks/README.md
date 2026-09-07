# Git hooks

`core.hooksPath` is a local git config, not something a clone picks up automatically. On a fresh
checkout of this repo, run once:

```bash
git config core.hooksPath .githooks
```

**Rewritten for Phase 1+** (`Aperas-crud-design.md` §14/§15/§16): the graph, edited directly via
`kg:insert`/`kg:update`/`kg:remove`/`kg:project`, is the primary content now — not hand-edited
`artifacts/*.md` files reconciled in via `kg:track`/`kg:ingest`, the Phase 0 direction. Both hooks
below were rewritten to match; the pre-Phase-1 versions (scoped `kg:track` on staged artifacts, an
unscoped `kg:track` sweep on reset/checkout) are `git log`-able history, not reproduced here.

## pre-commit

Runs `npm run kg:flush` (in the sibling `Aperas/web` directory) unconditionally, then `git add`s
the `Apeiron/*.jsonld` mirror files it updates — so the mirror sync lands *in the same commit* as
whatever prompted it, not as a separate leftover working-tree change right after the commit
completes. No longer scoped to staged artifact files: the graph can have pending changes (from
`kg:insert`/`kg:update`/`kg:remove`/`kg:project` sessions) with nothing artifact-shaped staged at
all, so this just flushes whatever's currently dirty — cheap and safe, a flush with nothing pending
is a no-op and a no-op `git add` is harmless. Also runs `npm run kg:track -- --reverse` (read-only,
never blocks) to warn if any real artifact/folder has graph-side content `kg:project` hasn't caught
up to yet, so a commit doesn't silently ship a stale projection with no one told.

Failures from `kg:flush` are logged and the commit is allowed to proceed anyway (`exit 0`) rather
than blocked — a real flush conflict (the mirror changed on disk since this service last read it,
e.g. a `git pull`/merge landed without a `kg:reload` first) is deliberately not auto-resolved here
(no `--clobber`), since resolving it wrong would silently discard someone else's content; resolve
manually (`kg:reload`, `kg:reload --discard`, or `kg:flush --clobber`, whichever is actually correct
for what happened) and re-commit.

## post-index-change

Covers what `pre-commit` doesn't: branch switches (`git checkout`/`git switch`) and `git reset`
(including `--hard`, which fires no git hook of its own) — anything that writes the index outside
of a commit, potentially rewriting the mirror files themselves underneath the running service. Runs
`npm run kg:reload -- --discard`, skipped entirely when the working tree wasn't actually touched
(e.g. `git reset` without `--hard`, via the `$1` arg git supplies). `--discard` resolves any flush
conflict in favor of whatever git just put on disk — the opposite resolution from `pre-commit`'s own
flush, and the correct one here: this hook's whole job is picking up what a git operation just did
to the working tree, so pending local mutations losing to that is the intended outcome, not a risk.

A dedicated `post-checkout` hook was tried first but dropped, back in the Phase 0 version: every
working-tree-changing checkout already writes the index too, so `post-index-change` fires alongside
it with equivalent coverage — confirmed live, both hooks fired back-to-back on the same `checkout`.
That finding is unaffected by the Phase 1+ rewrite above.

Together, `pre-commit` (the common case — an ordinary commit) and `post-index-change` (everything
else that moves `HEAD` or the working tree without one) are the closest coverage git's hook system
allows — there's no single hook that catches all working-tree changes uniformly.
