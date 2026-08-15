# core-requests/ — escalation channel: workers -> the ESTree core owner

When a per-worktree backend worker or per-frontend worker hits a genuine
shared-core limitation (a missing shIR node, a deserializer round-trip
gap, a contract field, a parser limitation), its `pi` invocation is told
to APPEND a structured request here instead of touching the core.

## Request file format

One file per request: `core-requests/<lang>-<YYYYMMDD-HHMMSS>.md`

```markdown
# <lang>: <one-line summary>

## NEED
What the shared core must provide (node type, deserializer support,
contract field, parser fix...).

## WHY
The failing case / build error / Unsupported reason that prompted this.

## MINIMAL-CORE-CHANGE
The smallest change to src/shir.rs, src/ir.rs, src/estree.rs,
src/parser/, or the A1 contract (shir_json.rs / shir_json_in.rs) that
would satisfy NEED. Concrete: node name, fields, serialization shape.

## FAILING-CASE
A minimal source snippet (in <lang>) that currently fails, so the
estree worker can reproduce it.
```

## Processing (the estree worker mediates)

- `main_loop_estree.pl` polls `core-requests/*.md` at the start of each
  iteration (it is the single owner of the shared core).
- It passes ALL pending requests to ONE `pi` invocation (opencode-go +
  deepseek-v4-flash, automatic key rotation), instructing it to:
  - **revisit STALLED requests first** — requests in
    `core-requests/stalled/` (they waited ≥3 cycles) are folded in
    before pending ones and before any general estree/benchmark
    improvement, up to `SH2_STALLED_MAX` (default 15) per iteration;
  - **mediate between conflicting requests** (oldest first; if two are
    truly incompatible, implement the one that maximizes corpus
    coverage and note the rejection);
  - **implement each without regressing the ESTree corpus** (verify
    `./fail-estree` — estree_failed must stay at the trusted baseline,
    ideally 0);
  - keep its fix surface to the shared core + harness/*.
- After `pi` finishes, the worker runs `./fail-estree` itself:
  - green (no regression): commits the core changes (scoped) and moves
    every request to `core-requests/done/`.
  - regressed: `scoped_stash` (reverts pi's changes), leaves the
    requests in place, and logs the regression — the corpus gate wins.

## Stalled (≠ done)

A request that survives **3 consecutive cycles** without implementation
(or explicit rejection) is moved to `core-requests/stalled/` — NOT `done/`.
Stalled is a status, not a verdict:

- the estree worker **revisits** stalled requests every iteration,
  stalled-first (see above), until pi implements or rejects them;
- an implemented or rejected stalled request moves to `done/` like any
  other;
- `core-requests/stalled-needs.tsv` is regenerated each iteration — one
  row per stalled request (lang, filename, title) — so the backlog stays
  visible to humans/agents.

## Trapped workers (sleep until estree wakes them)

A worker that hits **3 consecutive build failures** is TRAPPED. It:

1. ensures a core request exists (`core-requests/<lang>-<ts>.md`,
   with a fallback "TRAPPED" request if `pi` didn't write one),
2. creates the marker **`core-requests/sleeping-<lang>`**,
3. **sleeps** (loops every 60s) while the marker exists — it does NOT
   busy-loop the build.

The estree worker **wakes it**: after processing a request batch GREEN
(no corpus regression), it removes `core-requests/sleeping-<lang>` for
 each implemented request's language. The worker then wakes, resets its
 failure count, and retries. If the batch regressed, the markers stay
 (workers remain asleep) and the regression is logged.

## Done

`core-requests/done/<lang>-<ts>.md` = implemented (or rejected, with the
mediation note in the file).
`core-requests/stalled/<lang>-<ts>.md` = still open; waiting to be
implemented (revisited stalled-first each iteration).
