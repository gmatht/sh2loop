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

Perf grounding (round 3): a 1M-iteration factor loop (t86 idiom, N=1e12)
runs in 0.29s under node (≈0.3µs/trip) — the loop is already tight
(native modulo/increment; runtime appends fire only on divisor hits).
67M-trip cost is inherent trip count, not per-op overhead. This
downgrades loop-micro-opts (native arrays, guard hoisting) from perf
wins to readability wins: pursued only when safe and cheap.

## Implementation status

Each item is marked DONE (implemented, gate-kept) or DEFERRED (reason
given). Round 4 (this commit): merged worker main through BASHC_OPT
round 2 + item-7 gate + capture work; re-verified everything green
(lib 641/0 with worker's new tests, 9/9 integration, 93/93 estree
valid, t86 C match with named `long long n`). Const-temps (item 15)
stays deferred (cosmetic single line; definite-assignment proof needed;
low value/risk this round). Round 1 (params, local-drop, String-drop, DCE, isqrt seeding)
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

## Round 5 — t97/t98 list-growth survey + nested temp-read fold (2026-09-12)

Surveyed new `t97/t98_list_growth*min.py` (`xs.append(i); sum_min += min(xs)`):
gate MATCH, but per-iteration `setVar(_min_xs,min)+guard-chain` is O(n²)
(min re-scans; running-min strength-reduction deferred — needs loop
analysis, min-scan dominates anyway).

Implemented nested single straight-line temp-read fold in
`fold_temp_roundtrips` (extends adjacent pair loop beyond `Tv = read`):
same counts/purity gates + straight-line vet (loops/closures/branches/
try vetoed) + E-dep write check + dynamic-call veto. Try-scope threading
(`in_try` through walker/`fold_temp_roundtrips`/`try_fold_nested`;
closures vetoed) after `try_except_as_binding_read_not_folded` caught a
catch-preamble fold — as-binding reads must survive (fail-closed wins).
Store-reading E (e.g. `min("xs")`) stays vetoed by `temp_eval_pure`
(relaxing to deterministic+adjacent is sound but deferred — value is
cleanliness, min-scan dominates).

Tests: `temp_fold_nested_straight_read`, `temp_fold_nested_vetoed_loop`.
Lib 644/0 (was 642/0 + 2 new), c_* suites pass, 93/93 estree valid
(t95/t96 pre-existing broken oracles).

## Round 6 — coerce-prop, certain-string String-drop, append fusion (2026-09-12)

Surveyed t86/t92/t97 JS for hot-loop waste (loop-trip cost dominates per
prior measurement, so this round targets per-iteration calls + call counts).

17. **Redundant `Number(v) || 0` re-coercions** (t86: 4× `Number(n) || 0`
    with one entry `n = Number(n) || 0`): after `v = Number(E) || 0` (any
    E — `|| 0` kills NaN) or `let v = <numeric>`, later `Number(v) || 0`
    is exactly `v`. **DONE**: `prop_coerced_numbers` post-pass (forward
    facts; kills on reassign/update/`setVar("v")`/`eval`/closure-captured
    writes; arrows/functions get fresh facts; branch/loop descent with
    persistent kills (sound, over-conservative); establishing RHS reads
    OLD values; unguarded `Number(E)` sources never establish (NaN)).
    t86 4→2 survivors (entry source + `arithEval` arrow body, correctly
    vetoed — deferred execution). +3 unit tests (propagate, reassign-kill,
    NaN-source veto).
18. **`String()` around certain-string runtime calls** (t92: 6×
    `String(sh2.maxArr/...)`, t97: sum/arrayLen): the `*Arr`/store
    sum/max/min, `sorted*Join(All)`, `arrayLen` always return strings
    (verified in `harness/sh2-namespace.mjs`). **DONE**: extended
    `is_already_string` in `drop_redundant_string_wraps` with a
    fail-closed allowlist (mixed `arithEval`/`arrayIndex`/`getVar`
    excluded). t92 6→0, output identical. +2 unit tests (drop + keep).
19. **Adjacent same-array append fusion** (t86: two `setArrayAppend`
    per factor): `append(A,E1)+append(A,E2)` → one append (concatenated
    elements); `setArray(A,X)+append(A,Y)` → `setArray(A,X+Y)`. Adjacent
    only (no interleaving; same evaluation order). **DONE**:
    `fuse_array_appends` post-pass (array-literal args only; descends
    blocks/branches/loops/functions/arrows — purely local pair rule).
    t86 2→1 calls per factor. +2 unit tests (fuse + other-array veto).

Verification: lib 653/0 (+7), c_* suites pass, 93/93 estree valid
(t95/t96 pre-existing broken oracles), t86/t92/t97 oracle MATCH.

## Round 7 — string-fact guards, conditional/logical String-drop, str-method table (2026-09-12)

Sweep: 70 `String(ident)` guards across 38 tests — most wrap provably-string
vars (`let x = "world"; write(String(x))`, t64's 14× `String(x)`).

20. **String-fact propagation** (mirror of item 17): after `v = <string>`
    (literal, template, `String(..)`, certain-string sh2.* call (shared
    `sh2_certain_string`, hoisted to top level), `+` with a string side,
    all-string conditional, string method on a string receiver, or a
    known-string var), later `String(E)` → `E` whenever E establishes a
    string. **DONE**: `prop_string_facts` post-pass (same kills/descent/
    closure discipline as item 17; runs before the String-drop so newly
    exposed wrappers fold). Corpus `String(ident)` 70→18 (survivors are
    numbers/unknowns: t03's `x = 42`, t20's for-of element, t29's counter).
    t30's branch-assigned `y`, t37/t38's `s`, t02's `x` all fold. +4 unit
    tests (fold, reassign-kill, transitive+concat, number-never-establishes).
21. **`is_already_string` conditionals/logicals** (t64's 4 outer
    `String(ternary)`): a conditional/logical with all-string arms is a
    string. **DONE** (recursive predicate arms). +2 unit tests (drop + mixed
    veto). Generalizing S1's fold to any establishing arg (not just
    identifiers) plus a `str_method_returns_string` table (slice/trim/case/
    replace/…; length-arg/predicate/index methods excluded) completes t64:
    14→0 `String(`. Survivors elsewhere are numbers/unknowns (verified).

Deferred: `[E].flat().join(" ")` single-site shape (t37 only — print-list
lowering wraps a scalar; emitter-layer fix, worker/frontend domain).

Verification: lib 659/0 (+6), c_* suites pass, 93/93 estree valid
(t95/t96 pre-existing broken oracles), full oracle MATCH sweep.

## Round 8 — bigint facts, const-arith init fold, loop-scope soundness (2026-09-12)

Surveyed bigint/assoc outputs: t87 wraps an already-BigInt `x` in
`BigInt(x || 0)` 8×, and `let x = 0; x = BigInt(..**..)` misses the
init fold (RHS predicate rejects Binary).

22. **Bigint-fact propagation** (fourth fact-family member): after
    `v = <bigint>` (`BigInt(..)`, bigint arithmetic/bitwise with a
    bigint side — mixed-type throws, so a produced value is exact —
    `-`/`~` on a bigint, all-bigint conditional, known-bigint var),
    `BigInt(v)` → `v` (identity) and `BigInt(v || 0)` → `v` (`0n` is
    falsy: `0n||0` is `0`, `BigInt(0)` is `0n`). **DONE**:
    `prop_bigint_facts` (same kills/descent/closure discipline).
    t87 8→0 guards; t90's loop-body `BigInt(n || 0)` 6+→1 (entry source
    kept; `BigInt(i || 0)` kept — `i` is a number). t91's accumulator
    guard correctly survives (first iteration reads numeric `0` —
    single-pass entry facts save it). +5 unit tests (fold, comparison
    veto, reassign-kill, loop-leak veto, for-of entry facts).
23. **`is_const_rhs` arithmetic** (t87 init): Binary/Logical with const
    sides is const (pure, deterministic; any throw fires identically in
    the adjacent original). **DONE** (predicate extension, no new pass):
    `let x = 0; x = BigInt("2") ** BigInt("100")` → single decl. +1 test.
24. **Loop/branch scope soundness (fix)**: review found establishments
    inside `if`/`while` leaked out (zero-trip loop / untaken branch
    would misread) — latent in all three fact passes, unmanifested in
    corpus. **FIXED**: branches and loop bodies (while/do/for/for-of)
    run on cloned facts, discarded after; `for` init stays straight-line.
    No corpus output changes except newly-unlocked `for`-body folds
    (t90). Pinned by `bigfact_loop_establish_does_not_leak`.

Deferred: `[].concat(DYN)` in for-of (2 sites — copy-elision needs
array-proof + no-mutation proof; marginal).

Verification: lib 667/0 (+6: 5 bigfact + 1 let-arith),
c_* suites pass, 93/93 estree valid (t95/t96 pre-existing), oracle MATCH.
