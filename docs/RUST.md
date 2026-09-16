# Python→Rust translation — status and optimisations

## How it works
`py-sh-go` frontend → shir → `rust_backend::shir_to_rust` (11k lines).
Same shir contract as C/JS; only the renderer differs (Rust idioms:
`thread_local!` + `Cell`/`RefCell` for vars, `Mutex` for shared,
`Vec<String>` for lists, `BTreeMap` for assocs).

## Status (Sept 2026): 98/100 (stdout+exit; t95/t96 stderr-only diffs) Python testdata pass (t87 BigInt, t101 tiers, t99)
Fixed this round (6 subsystems):
- i64 widening (literals + infix Bin; vars already `Cell<i64>`)
- Positional argv reads (filtered from decls; `__sh_arg(i)` helper)
- `sortedIntJoin` (numeric sort + dedup) — t86 factor print
- ArrayComp loop lowering — t80 comprehensions
- sum/max/min reductions — t92/t94
- Assoc string keys, caseMatch/glob, Try, dash-letter test gate,
  dict `declare -A` (t73, t68, t78, t50)

Remaining gaps (11 files, 2 subsystems + misc):
- **BigInt** (t87-t91, t93, t101): needs `num-bigint` (cached offline)
  + taint tracking + `--extern` linkage for generated code (proof of
  concept works: `--extern` links, BigInt correct). i128 covers to 38
  digits (t101's 20) but not 2**200 (61 digits). Design: mirror C's
  GMP tiers (i64 fast + BigInt replay) or blanket BigInt (slower).
- **OOB-abort** (t95/t96/t98/t99): Python IndexError (crash) vs shell
  empty-continue. Needs frontend-gated strict indexing (shir schema
  flag; global abort would regress shell OOB-empty).
- t73 dict (fixed), t50/t68/t78 (fixed). Sets (t91 partly BigInt).

## BigInt design (foundation landed, not yet wired)
- Taint: `collect_bigint_vars` (fixpoint over assigns; huge consts via
  `eval_arith_bigint` with num-bigint, propagations via `arith_uses`).
- Tier-0 (planned): string-held decimals, per-op parse/compute/format
  (correct, slower; covers t87-t91,t93,t101 dynamic huge).
- Tier-1 (future): native `RefCell<BigInt>` vars (needs Option init +
  op routing; mirrors C GMP).
- Linkage: generated code needs `--extern num_bigint=<rlib>` + `-L`
  (proven manually; future Rust gate must pass them).
- Per-function bigint args (t89/t90 design, not yet implemented):
  `n` from `$1` with huge call args needs BigInt, but taint only covers
  Assign targets (params aren't assigned). Fix: precompute
  `fn_bigint_args` (scan fnCalls for huge/bigint args, mark callee),
  track `current_fn` during rendering, route digit `$N` reads in marked
  fns through BigInt string path (parse, not i64). Preserves t86 speed
  (unmarked fns stay i64).
- i128 rejected as blanket (4x slowdown on t86 loops); selective i128
  needs range proof (future). OOB-abort needs frontend flag (schema).

## BigInt compares + sortedBigintJoin landed (t89/t90)
- Arith `==`/`!=`/`<`/... with tainted/huge sides render as numeric
  BigInt compare (t89 huge mod vs 0).
- `sortedBigintJoin` (numeric BigInt sort+dedup+join; t90 huge factors).
- Cache taint-gate (skip `__pn_N` for bigint-marked; t90 huge argv).
- Huge-literal assign marking (t90-style `n = <20 digits>`).
- t86 still ~2s (cache preserved for non-huge).

## OOB-abort + string reductions landed (t95/t96/t98)
- `IrExpr::Index` is Python-specific (shell uses param strings;
  verified zero Index nodes in 009/064_07) → strict: negative wraps,
  OOB exits 1 (IndexError; prior output stands). `ArithAst::Index`
  stays forgiving (possibly shell).
- String `min/max/sum` calls (for `_min_xs = min(xs)` temps) + numeric
  versions in `expr_num` (t98 accumulation).
- t95/t96/t98 stdout+exit match (stderr tracebacks excluded, gate-style).

## Optimisations (vs C backend)
Measured t86 (67M-trip factor loop):
- Python: 6.7s. C: 5.6s user (0.97s wall? re-measure). Rust: 7.3s.
- Rust 30% slower than C from **string-parse per iteration**
  (`__sh_arg(0).trim().parse()` + `String` clone per op, 134M parses)
  vs C's cached numerics. Fix is numeric homing (parse once to i64
  local, reuse) — mirrors C's int work; needs loop-invariant analysis.
  Documented, not yet implemented.
- Already ported: inline aggregates (t94 sum/max/min O(1) reads? No —
  currently O(n) scans; C maintains inline. Future: same.)
- Narrowing (u16 loop vars? Rust uses i64 throughout; width analysis
  future), Vec growth (amortized, same as C), profiling (none yet).
- Numeric param caching (entry-bound `__pn_N` i64 locals for Arith-used
  `$N`; t86 7.3s→2.35s, 3×). `set --` invalidates (documented gap, rare).
  Main-body caching deferred (functions only; top-level numeric loops
  with `$N` uncommon).

## Methodology
Same as C: fail-list diffing (manual sweeps, no Rust gate yet —
`harness/` runner is follow-up), single-point fixes, sibling tests
(t80+t83-t86+t92+t94 green together), soundness first (i128 heuristic
rejected as unsound without range proof; BigInt deferred to proper
tiers, not hacks).
