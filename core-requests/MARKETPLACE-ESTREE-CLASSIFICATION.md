# Marketplace classification — the estree requests (incl. stalled)

PLAN.md §11 marketplace mode: the core accepts transforms that build +
don't regress (self-fallbacking ops); backends decide accept/reject;
offers are the notification channel. This classifies the 17 stalled
estree-20260813 requests (the estree worker never reached them — §11's
bottleneck) into: **owner** (core worker / estree worker / split) and
**OFFERED-TO** (the backends that should be notified to adopt the op).

## Core worker — shared A1/IR transforms (offer to all consumers)

| request | what it is | OFFERED-TO |
|---|---|---|
| `183713-a1-ssa-const-copy-prop` | the umbrella: `shir_passes::const_prop` — "so all nine renderers emit code without the literal variable copies…" | **all 9 backends** (estree, c, go, perl, python, rust, sh, zig, java) |
| `182434-const-fold-arith` | A1 arith/const-pool folding + `$(( ))` elision | all 9 |
| `182435-dce-dead-vars` | dead-store elimination via the A1 `var_lifetimes`/`var_const` | all 9 |
| `182436-loop-index-srr` | IR loop-invariant hoisting + strength reduction | all 9 |
| `182441-loop-status-interproc` | extend `mark_loop_status_deadness` (shir.rs) | all 9 |
| `201235-hoist-pure-loop-invariants` | shIR pass: hoist pure fn calls out of loops | all 9 |
| `182442-case-lookup-table` | the LIFT part (pure int/char case → a lookup op); the per-backend render stays with each renderer | all 9 (each renders the op or falls back to the case chain) |
| `184909-string-accumulator` | **split** — the IR-level analysis goes core; the estree-renderer lowering stays estree | core analysis → notify estree (primary consumer) + perl/rust (string-join natives) |
| `182433-lastexit-test-liveness` | **split** — the liveness ANALYSIS is shared (shir.rs); the estree consumer stays estree | core analysis → notify estree |

## Core worker — canonical bug-fixes (the A1 path)

| request | OFFERED-TO |
|---|---|
| `182438-a1-array-param-key-bug` | the A1 round-trip consumers: estree + otranspilerl (the `--shir-in-estree` path) — notify estree |
| `182439-a1-array-local-lift-key-bug` | same — notify estree |
| `235901-a1-loop-scan-hang` | same — notify estree |

## Estree worker — renderer-bound (stay with estree; no offer needed)

| request | why |
|---|---|
| `182431-inline-pure-fns` | ESTree-renderer inlining of leaf fns — JS-specific emission |
| `182432-split-elide-typed-args` | the `String(x).split(/\s+/).filter(...)` elision — estree's word-split emission |
| `182437-typed-lowering-var-types` | the estree backend adopting the (already shared) A1 `var_types` verdicts |
| `182440-strip-dead-env-fallback` | estree emitter: `sh2.vars.x` alone for store reads |
| `182443-writefile-status-liveness` | the redirect/writeFile lowering — estree-renderer |

## The notification mechanics

For each core-bound transform, the core worker appends the manifest +
`## OFFERED-TO: <backends>` to the request file (the marketplace notice).
The named backends' workers see the offer in their next gate cycle (the
request file is in their escalation scope) and respond accept/reject —
accept = implement the op's render (native), reject = keep the fallback
(the op renders as the exec it came from; self-fallbacking guarantees no
regression). The `builtin` op (core-requests/shir-builtin-op-20260816.md)
is the first offer: OFFERED-TO **rust, perl, c** (the backends that shell
out the builtins.json commands).

## Summary

- **12 → core worker** (9 shared transforms + 3 canonical A1 bug-fixes) —
  the stalled backlog §11 predicted would unblock once the core is the
  marketplace gate, not the serial mediator.
- **5 stay with estree** (renderer-specific emission).
- **2 split** (shared analysis core / renderer consumer estree).
- Notifications fan out to all 9 for the shared transforms; the
  renderer-specific consumers (estree, perl, rust) for the rest.
