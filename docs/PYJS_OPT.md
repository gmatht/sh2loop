# PYJS_OPT — JS backend output: optimization survey + implementation log

Survey of the JS emitted for the Python corpus (`frontends/py-sh-go/testdata/*.py`
via `./2js <prefix>` = `otranspilerl-cli <test>.py - --target js`, dual loops on).
Read the output for 12 tests spanning args → closures → bigint factor
(t23, t41, t52, t76, t84, t86, t87, t88, t90, t92, t93, t94), listed what a
renderer-level pass could remove or tighten. Numbered items are independent
work items.

## Method and baseline

`--target js` pretty-prints the ESTree (via `harness/vendor/astring.mjs`,
Prettier `arrow-parens: always`). Correctness oracle throughout: `node
harness/estree-runner.mjs` stdout vs `python3` stdout (the 91/91
`frontend-stdout` gate), plus `cargo test` (lib unit tests must stay green).

Baseline (worker `626cf1cb`, before this round), per test
(lines / `sh2.*` calls / `String(` / `Number(`):

| test | lines | sh2.* | String( | Number( | notes |
|------|-------|-------|----------|-----------|-------|
| t23 func_args | 2 | 4 | 1 | 0 | dynamic dispatch, positional store |
| t41 local_var | 6 | 3 | 1 | 0 | comma-sequence define, global `y` |
| t52 full_prog | 5 | 5 | 1 | 0 | captureSync + fnCall |
| t76 varargs | 2 | 5 | 1 | 0 | 2-param, dynamic |
| t84 bare_return | 7 | 4 | 0 | 0 | dead code after `return` kept |
| t86 factor | 24 | 7 | 5 | 1 | lifted `p1`, `__p1n`, setArray loop |
| t87 bignum | 14 | 0 | 12 | 0 | fully native BigInt (model output) |
| t88 factor53 | 23 | 7 | 5 | 1 | same shape as t86 |
| t90 factor_bigint | 14 | 5 | 2 | 1 | imod + BigInt joins |
| t92 max_min_sum | 8 | 6 | 6 | 0 | `*Arr` native twins on string arrays |
| t93 extent_mixed | 7 | 5 | 5 | 0 | all-`Arr` twins |
| t94 list_growth | 8 | 6 | 4 | 0 | setArrayAppend per iteration |

t87 (zero runtime calls) is the reference shape: native bindings, native
operators, `process.stdout.write` sinks. The gap is everything that still
routes through `sh2.*` or keeps dead scaffolding.

## Implementation status

Each item is marked DONE (implemented, gate-kept) or DEFERRED (reason
given). Round 1 (params, local-drop, String-drop, DCE, isqrt seeding)
verified: lib 635/0, 93/93 estree valid (t95/t96 excluded — broken
python oracles, pre-existing), t86 C stdout+ASan+valgrind match, 9/9
integration tests. Round 2 (this commit): rebased onto worker main
(assoc decls, growable vecs, BASHC_OPT batch, capture/cat); re-verified
same gates green (lib 635/0, 93/93, integration 9/9). 6 pre-existing
estree fails fixed separately (PLAN v43; echo-split miscompile,
cond_zero soundness, stale shapes with execution proof). Verification per batch:
`cargo test --lib` (must hold at 0 failed), the 12-test manual gate above
(C+estree render, node run vs python3 oracle), and the `frontend-stdout`
91/91 gate where the CLI builds against the worktree.

## A. Functions and calls

1. **Named parameters** (t86/t88/t52/t76): `function all_factors(p1)` +
   `const __p1n = Number(p1)` should be `function all_factors(n)` (source
   name). IR `Function.params` carries names; backends with named params
   declare them and skip positional materialization (`n = $1`) and bare
   scope pins. Calls stay positional (no call-site change). Positional-only
   backends (sh), empty lists (shell fns), length mismatches, and JS-reserved
   / non-ASCII names fall back to `pN`. **DONE**: IR `Function.params` +
   JSON compat + `PARAM_NAMES`/`js_param_names`/`param_frame_read` mapping +
   named arrows/declarations + bare-`Declare(params)` skip + numeric
   `Declare` exemption port. t86 is `function all_factors(n)` with
   `n = Number(n) || 0` entry coercion; 12/12 def-tests C+estree match;
   `tests/c_fn_params.rs` (named + reserved-fallback); C keeps worker
   param-copy aliasing (output identical).
2. **Dynamic dispatch for void/small functions** (t23/t41/t52/t76/t84):
   `sh2.functions.set("f", () => ...)` + `sh2.fnCall("f", args)` + positional
   store reads, vs lifted direct calls. Lift (`param_lift_set`) correctly
   disqualifies default-args (t23: body reads more positionals than calls
   provide — native call would leave params `undefined` vs Python defaults)
   and void/side-effect shapes. Expanding lift (JS default params, void
   direct calls) is a calling-convention redesign. **DEFERRED** (worker call-
   convention design; dynamic dispatch is correct, cost is per-call Map +
   arg flatten, negligible at corpus call counts).
3. **Bare `local` builtins** (t86/t88): `sh2.builtin("local", ["n"])` /
   `["i"]` — runtime no-ops. A bare `local x` (no init) is unobservable:
   reads see `""` whether declared-empty or unset, and py-sh-go never
   relies on dynamic scope (lexical dataflow only; callees use params).
   `local x=v` (init) is a real store write and stays. **DONE**:
   `drop_bare_local_builtins` post-pass (fail-closed callee allowlist;
   FunctionDeclarations only; unit-tested both directions). t86 loses
   both `local` calls, output identical.

## B. Arrays

4. **Function-local growable arrays native** (t86/t88/t90 `factors`):
   `sh2.setArray("factors", [])` + per-iteration `setArrayAppend` +
   `sh2.sortedIntJoin("factors")` should be `let factors = []` + `push` +
   `sortedIntJoinArr(factors)` (twins exist — t93 uses them). The migration
   (`array_migrate_*`, conservative whitelist) refuses here — TBD whether
   function scope, loop-carried appends, or computed elements veto.
   **DEFERRED** (investigated: veto chain is `FunctionDeclaration`
   bodies never visited + `str_refs==4` from legacy string-name calls
   (`setArray`/`sortedIntJoin` take `"factors"`). Rewiring needs the
   migration's ordering + function-scope soundness proofs (aliasing,
   dynamic reads) — worker's active area. Output correct, cost is
   per-op runtime dispatch. Pointer: `array_migrate_bodies` FunctionDeclaration
   arm + `str_refs` accounting for legacy names.
5. **String arrays parsed per operation** (t92 `["3","1",..]` + `maxArr`
   parsing each element): int-domain array literals could lower to numeric
   arrays once, not parse per op. Needs frontend int-domain array literals
   + backend numeric-array `*Arr` overloads. **DEFERRED** (cross-cutting:
   frontend typing + runtime twins; current output correct, cost is parse
   per op on small arrays).

## C. Values and coercions

6. **Redundant `String(template)`** (t86/t88 `String(`[...]`)`): outer
   `String()` around a template literal (always a string) is a no-op.
   **DONE**: `echo_arg_scalar` skips the wrapper for TemplateLiteral /
   string-literal renders + `drop_redundant_string_wraps` deep post-pass
   (catches every emitter). t86 `String(` count 5→0, output identical.
   One over-specific test updated (`grep_null...` demanded defensive
   `String()` on a statically-string haystack; execution verified).
7. **`let`-then-assign init fold** (t87 `let x = 0; x = BigInt(...)`):
   merge `let v = 0;`/`let v;` with the first straight-line `v = K`
   (K side-effect-free, no mentions between) → `let x = BigInt(...)`.
   Mirrors the C `fold_init_store` rule. **DONE**:
   `fold_let_init_store` post-pass (same-block, no-mention (reads/writes/
   captures/nested/dynamic), const K, pure init; `let` only). t87 loses
   the redundant init; +2 unit tests (merge + blocked-by-read); one
   shape expectation updated (init-decl, value+no-store pinned).
8. **Repeated `BigInt(x || 0)` guards** (t87, 12×): hoist loop-invariant
   coercions to entry consts (generalize the `__p1n` param-read hoist to
   never-written-between locals). Needs liveness proof per read region;
   wrong hoist across a write is a miscompile. **DEFERRED** (needs
   write-liveness analysis; current output correct, cost is a guard +
   BigInt() call per read).
9. **Bigint pow literal const-fold** (`BigInt("10") ** BigInt("30")`,
   giant Horner chains): pure constant expressions could fold at
   frontend/A1 time. Frontend const evaluation for bigint ops is worker
   domain; Horner chains are exact (just verbose). **DEFERRED**.
10. **Param coercion hoisting** (`__p1n` const): DONE (existing; loop-
    invariant `Number(p)||0` folds to entry const — the 7x microbench
    note in code). Kept as-is; named params flow through it.
11. **isqrt string temps**: DONE (structured `isqrt` node; `Math.trunc(
    Math.sqrt(..))` native; temps `Int`-typed).

## D. Control flow and dead code

12. **Dead code after `return`** (t84 `return; write(unreachable)`):
    drop statements after unconditional `return`/`throw` in block bodies
    (estree-side post-pass; core `unreachable_after_exit` transform does
    not run on the py-sh-go A1 path). **DONE**:
    `drop_unreachable_after_exit` post-pass (truncate after return/throw
    per block list + arrow-body descent; single non-Block bodies skipped
    as vacuous). t84 loses the dead write, output identical; unit test.
13. **Loop shapes** (`while` + `i++`, native `for` where seq-proven):
    DONE (already native; `for (let i..)` for literal ranges, `while`
    for dynamic bounds — both minimal).

## E. Module shape and printing

14. **Trailing `(write, lastExit = 0, true)` flag**: DONE/DOCUMENTED
    (keep-last contract for program value; tested).
15. **`const` for single-assign temps**: DEFERRED (needs definite-
    assignment proof; `let` is correct, `const` is cosmetic).
16. **`[].concat` literals to array** (t90/t94 `[].concat("1",...)`):
    **DONE**: `fold_concat_literals` post-pass (all-literal args only;
    spread/dynamic veto; deep walker incl. ForOf/arrows). +2 unit tests
    (fold + veto). Cosmetic (saves a runtime call per site).
16. **Top-level `let` consolidation** (`let a = 0, b = 0`): DONE (already
    comma-joined; note).
