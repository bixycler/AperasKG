# Webapp — Planning <a name='id/BlockNode:00CJ6V6CH0001' class='aperas-anchor aperas-id'></a>

## Implementation Plan <a name='id/BlockNode:00CJ6V6CH0002' class='aperas-anchor aperas-id'></a>

- **Phase 1 is deep read, shallow write**: <a name='id/BlockNode:00CJ6V6CH0003' class='aperas-anchor aperas-id'></a> the whole read surface plus a single in-place text edit of the current node. This is the phase the settled design describes, and its write boundary is principled rather than a scope cut — one node's own text is the only change that needs no reconciliation and no structural judgment.
- **Phase 2+ is deep write**: <a name='id/BlockNode:00CJ6V6CH0004' class='aperas-anchor aperas-id'></a> composing an intent and handing it to the Agent. Unexamined, and deliberately not foreclosed by anything in Phase 1.
- **The ordering has a rationale**: <a name='id/BlockNode:00CJ6V6CH0005' class='aperas-anchor aperas-id'></a> core extraction comes first because both the CLI and the UI consume it, and because doing it while the CLI is still the only caller keeps the byte-identical text output as a free regression test. The auth token comes next because it is independent of the listener and is the one piece whose lifecycle should be proven before anything depends on it. The listener, the tick channel and the UI follow in that order, each with a working consumer by the time it lands.

## Task Breakdown <a name='id/BlockNode:00CJ6V6CH0006' class='aperas-anchor aperas-id'></a>

- [ ] **Slice 1 — `buildRenderTree` in core**: <a name='id/BlockNode:00CJ6V6CH0007' class='aperas-anchor aperas-id'></a> promote `discoverCone`'s plan to a returned render tree, redefine `renderTreeWithView` as `toText(buildRenderTree(...))`, and add a `format` discriminator to the `tree` service op.
- [ ] **Slice 2 — per-run auth token**: <a name='id/BlockNode:00CJ6V6CH8000' class='aperas-anchor aperas-id'></a> generate at service start, store in the run directory at mode 0600, expose for the dev server.
- [ ] **Slice 3 — HTTP listener**: <a name='id/BlockNode:00CJ6V6CH8001' class='aperas-anchor aperas-id'></a> loopback bind, op allowlist, the four auth checks, restrictive CORS preflight.
- [ ] **Slice 4 — tick channel**: <a name='id/BlockNode:00CJ6V6CH8002' class='aperas-anchor aperas-id'></a> streaming NDJSON endpoint, `fetch()` + `ReadableStream` client with reconnect, unconditional refetch on reconnect, hidden-tab pause, and a distinct 401 state.
- [ ] **Slice 5 — `FolderDiv` as a Solid component**: <a name='id/BlockNode:00CJ6V6CH8003' class='aperas-anchor aperas-id'></a> three slots onto three render tiers, fold and unfold via the arrow handle.
- [ ] **Slice 6 — links at two sites**: <a name='id/BlockNode:00CJ6V6CH8004' class='aperas-anchor aperas-id'></a> link text as `cite-ref`, endnote list as `cite-note`, click-through both ways, one back-reference per position, hover popover that can promote a link into `unfolds`.
- [ ] **Slice 7 — zoom**: <a name='id/BlockNode:00CJ6V6CH8005' class='aperas-anchor aperas-id'></a> ctrl-click to set an apex, breadcrumbs to zoom out.
- [ ] **Slice 8 — shallow write**: <a name='id/BlockNode:00CJ6V6CH8006' class='aperas-anchor aperas-id'></a> host-side `updateText(id, text)` choosing the per-type input form, link-sweep results surfaced.

## Verification Plan <a name='id/BlockNode:00CJ6V6CH8007' class='aperas-anchor aperas-id'></a>

- **Slice 1 is verified by the existing suite**: <a name='id/BlockNode:00CJ6V6CH8008' class='aperas-anchor aperas-id'></a> the text render must stay byte-identical across the extraction — any diff is a regression, and no new assertion is needed to catch it.
- **Slice 2 is verified by file mode and lifetime**: <a name='id/BlockNode:00CJ6V6CH8009' class='aperas-anchor aperas-id'></a> the token file exists at 0600, its value changes across a service restart, and the old value stops being accepted.
- **Slice 3 is verified adversarially**: <a name='id/BlockNode:00CJ6V6CH800A' class='aperas-anchor aperas-id'></a> not just positively — a request with no token, with a wrong token, with a foreign `Origin`, and with a non-loopback `Host` must each be rejected; a cross-origin `fetch` from a scratch page must fail at the preflight rather than reaching a handler. An op outside the allowlist must be refused even with a valid token.
- **Slice 4 is verified by killing the service mid-stream**: <a name='id/BlockNode:00CJ6V6CH800B' class='aperas-anchor aperas-id'></a> the client must reconnect, refetch unconditionally, and — once the token from the previous run is rejected — surface the 401 state rather than retrying silently.
- **Slices 5 to 7 are verified against `aperas tree --view`**: <a name='id/BlockNode:00CJ6V6CH800C' class='aperas-anchor aperas-id'></a> the same view rendered by the UI and by the CLI must agree on tier, canonical-position verdict and hidden counts for every node, since both now read the same render tree.
- **Slice 8 is verified by round-tripping an edit**: <a name='id/BlockNode:00CJ6V6CH800D' class='aperas-anchor aperas-id'></a> text typed in the UI, stored, projected and re-parsed must come back byte-identical, and a write whose links fail to persist must be visible in the UI rather than swallowed.
