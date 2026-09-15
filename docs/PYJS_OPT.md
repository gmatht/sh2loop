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

## Round 9 — concat/join String-elision, walker coverage, literal concat (2026-09-12)

`String(E) + "lit"` ≡ `E + "lit"` for every non-Symbol value (identical
ToString; no Symbol emitter exists and the runtime returns only
strings/numbers/bigints/arrays/objects) — so every print wrapper folds
regardless of E's type. Same argument elides pre-stringified
`[...].join(sep)` elements.

25. **Concat-side String elision** (`String(E)+"\n"` → `E+"\n"`, both
    sides; sibling must be a string literal — a dynamic sibling could
    mean numeric `+`). **DONE** in `drop_redundant_string_wraps`' Binary
    arm (recurse-first ordering so `String("")+"\n"` → `"\n"` in one
    pass). t03/t40/t48 print wrappers gone. +2 unit tests (drop + dynamic
    veto). One over-specific shell test updated (`echo_single_arg...`
    pinned `String(i)`; its no-join/no-array core holds — now pins the
    folded shape, Round-1 precedent).
26. **Join-element elision** (`[String(a),…].join(sep)` → `[a,…].join`).
    **DONE** (all-element-String arrays only; holes/spreads veto). t40
    `[i, j].join`. +1 test (+1 nested-through-Binary test that exposed
    the walker gap below).
27. **Walker coverage fixes** (found via t40/t75 survivors): drop's
    `stmts()` skipped `for`/`for-of`/`do`/`try`/`switch` bodies and its
    `expr()` skipped assignments (hiding arrow bodies in sequences).
    **FIXED** (local rules need no facts — plain recursion; Assignment
    arm added). +1 literal-concat test below.
28. **String-literal concat fold** (`"a"+"b"` → `"ab"`; numeric folds
    excluded — JS/Rust float-formatting divergence risk). **DONE**
    (5 lines in the Binary arm). t75 `write("\n")`. +1 test.

Corpus `String(` calls: 12 → 10, all audited necessities (numeric
`lastExit`/counters, unknown for-of elements/array slots, store-guard
temps, map params).

Verification: lib 673/0 (+5: 3 micro-rules + 1 nested + 1 lit-concat),
c_* suites pass, 93/93 estree valid (t95/t96 pre-existing), oracle MATCH.

## Round 10 — single-use let inline, template fold, concat reorder (2026-09-12)

Sweep: 87 `let` inits, 41 single-read — most inline cleanly once the init
fold merges first (`let x = ""; x = "world"` must merge before inline sees
a single write).

29. **Single-use `let` inline** (`let v = pure-E; ...; use(v)` → `use(E)`,
    decl dropped): strict purity, exactly one program-wide read + zero
    writes (position-aware counter: non-computed properties, params,
    labels excluded; object/spread/new/throw/do/labeled-break walked
    precisely), decl+use in the same plain-block list, unconditional
    read position (short-circuited/call-optional/closure/branch spots
    vetoed; `a.v` properties never count), no dep writes between, global
    `eval`/`Function` veto (string-held references invisible), and
    binding-worthy inits stay bound (array/object literals — the native
    migration's product per `array_lowering_is_conservative`; function
    values). **DONE**: `inline_single_use_lets` (runs after
    `fold_let_init_store`, before the string-drop so exposed literals
    fold; snapshot-per-list counting for borrowck, staleness sound).
    Corpus lets 99→71 (t02 → `write("world\n")`, t14 → `write(3+"\n")`).
    +4 unit tests (fold, multi-read/impure vetoes, write-nesting).
    Two shell shape pins updated (longoption, interpolation — expansions
    still evaluated, now constant-folded; core no-param/no-getVar holds;
    Round-1/9 precedent with execution proof).
30. **Static template fold** (`` `--x=${"test"}` `` → `"--x=test"`; null
    cooked vetoed — invalid escapes throw). **DONE** (in the drop pass;
    completes the longoption chain). +1 test.
31. **Concat-rule reorder** (recurse-first so `String("")+"\n"` chains
    to `"\n"` in one pass). **DONE** (no behavior change otherwise).

Deferred: if-to-ternary branch temps (2 sites, t60 `__t0` — needs
abrupt-completion vetting); duplicated `s.indexOf` (t70 — needs temp
introduction, opposite direction); imod→`%` (needs nonzero proof).

Verification: lib 679/0 (+6: 4 inline + 1 template + 1 carried),
c_* suites pass, 93/93 estree valid (t95/t96 pre-existing), oracle MATCH.

## Round 11 — template+literal concat fold (2026-09-12)

Sweep: 30 `` `..` + "lit" `` sites (mostly prints). Folding the literal
into the template's tail/head quasi removes a concat per site and chains
with inline (t13 → `write("hi world\n")`, t24 → `write("foobar\n")`).

32. **Template+literal concat** (`` `a${x}` + "\\n" `` → `` `a${x}\\n` ``,
    both sides; string literals only — numeric formatting risk excluded).
    Cooked appends verbatim; raw re-escapes (`\\`, backtick, `${`, newline,
    CR). The template still evaluates (no throw removed — unlike the
    static fold, which keeps its null-cooked veto). **DONE** in the drop
    Binary arm (recurse-first chains `String("")+"\\n"` fully). +1 test.
    Remaining corpus `+` are arithmetic or necessary dynamic concats
    (t64's `(ternary)+"\\n"` — no wrapper exists to drop).

Note: base `a8ef8126` carries one pre-existing lib failure
(`c_backend numeric_reduction_assign_reads_aggregate_natively` — fails on
the clean base too; C-aggregate worker domain, untouched).

Verification: lib 681/0 (+1; 1 pre-existing C failure unchanged),
c_* suites pass, 93/93 estree valid (t95/t96 pre-existing), oracle MATCH.

## Round 12 — bare `v||0` elision on number facts (2026-09-12)

N1 facts are non-NaN numbers, for which `v||0` is identity (`0||0`
is `0`). Strings (`""||0` is `0`) and bigints (`0n||0` is `0`) are
correctly excluded — the rule consults number facts only.

33. **Bare-guard elision** (`BigInt(i||0)` → `BigInt(i)`, preserving the
    conversion unlike the bigint-guard fold). **DONE** (extends N1's hit;
    `for (let i = 1; …)` inits establish via the loop-scope fix).
    t89 loop guards gone; t91's accumulator folds its `||0` while keeping
    `BigInt()` (first-iteration safe); t90's string-sourced `i`
    (`Number(string)` may be NaN) correctly kept — the analysis
    distinguishes native counters from parsed strings. +1 unit test.

Known-red (NOT this round): worker's in-flight C refactor (1700-line
`c_backend.rs` rewrite, base `692b189f`) redesigned the isqrt pipeline
(`long long sh2_isqrt(void)` + mpz bigint vs the `uint32_t _sh_isqrt`
narrowing) — `tests/c_isqrt.rs` fails 3/3 (2 pre-existing on the clean
base, 1 mine targeting the old design). Estree side fully green (below);
C-isqrt needs worker's update to the new design. Unrelated pre-existing
lib failure `numeric_reduction_assign_reads_aggregate_natively` (same).
Never blessed, never weakened — handoff to worker.

Verification: lib 682/0 (+1; 1 pre-existing C failure unchanged),
c_fn_locals/params pass, 93/93 estree valid (t95/t96 pre-existing),
oracle MATCH.

## Round 13 — compound assigns, `!isNaN` collapse (2026-09-12)

Sweep: 8 `v = v op K` accumulators/counters + t80's duplicated numeric
guard (`!isNaN(Number(G)) && Number(G) > 2`).

34. **Compound-assign fold** (`s = s + n` → `s += n`, all arithmetic /
    bitwise / shift / logical ops): exact shorthand for plain identifier
    targets (no double-evaluated getters — members excluded). **DONE**:
    `fold_compound_assign` deep pass (cosmetic; identical codegen).
    8 sites (t19/t29/t48/t59/t71/t74/t97/t98). +2 unit tests (fold +
    mismatch veto).
35. **`!Number.isNaN(N) && N <cmp> K` → `N <cmp> K`**: NaN compares false
    under `< > <= >= == ===` (so the guard is redundant); `!=`/`!==`
    excluded (NaN is unequal). N side-effect-free (dropping the guard
    removes one evaluation) + direct comparison operand (syntactic
    equality). **DONE** in the drop Logical arm (shared-view helper +
    re-dispatch; `side_effect_free`/`expr_eq` top-level helpers). t80's
    per-element duplicate guard gone. +2 tests (collapse + `!=` veto).

Deferred (narrow): `[].concat` copies (t52 needs body-purity,
t91 needs fresh-proof — one combined copy-elision rule, marginal);
`v ?? D` on facts (member chains dominate); general temp-hoist CSE
(t53/t70 duplicates — needs temp introduction).

Verification: lib 686/0 (+4; 1 pre-existing C failure unchanged),
c_fn_locals/params pass, 93/93 estree valid (t95/t96 pre-existing),
oracle MATCH.

## Round 14 — const folding + inline into tests (2026-09-12)

Sweep: t25's `if (1 < 2)`, t85's orphaned `let`, scattered constant
guards. Dead-let sweep prototyped then REMOVED (net-negative): the only
corpus site needs it after inline orphans, but write-only bindings are
exactly what the lifting pins protect (`x = 5` native lift,
`x=$(echo hi)` value pin) — shell state stays bound, period. t85 keeps
one dead line; inline (below) handles the live chains.

36. **Const-expression fold** (exact integer arithmetic with |r| < 1e21
    so Rust/JS print identically — div/mod-by-zero vetoed, no bitwise
    (ToInt32-wrap vs saturate), no non-integers (float-format risk);
    comparisons, `!`, `&&`/`||` with side-effect-free skipped arms,
    unary minus, const ternaries; `if (true/false)` → body/else-or-drop,
    `while (false)` → drop). **DONE**: `fold_const_exprs` (deep,
    fixpoint-per-node, branch folding with re-processing; second call
    after inline for newly-exposed constants). t25 → bare block.
    +3 unit tests (fold, branch, div-zero veto).
37. **Inline into test positions** (`if`/`while`/`do`/`for` tests): tests
    evaluate unconditionally at statement execution, so `let x = 5; if
    (x > 0)` → `if (5 > 0)` → const → body (the t25 chain). **DONE**
    (read/replace extended; same straight-line vetting). Chained-let
    unit test added (t87-style `x→y→use` folds fully).

Verification: lib 690/0 (+4 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass, 93/93 estree valid (t95/t96 pre-existing),
oracle MATCH. Both shell shape pins hold strict (no test updates this
round — the DCE scare resolved by removing the pass, not weakening).

## Round 15 — survey only, no implementation (2026-09-12)

Sweep of all 95 tests at `pyjs-r14` output. The post-pass corpus is
nearly exhausted (71 lets, 10 `String(`, guards folded); remaining
leads measured below. Nothing implemented this round.

36. **Literal copy-prop, multi-read (RECOMMENDED next): t18/t31.** `x = 3`
    / `x = 2` (literals, never reassigned, read 2–3× in elif tests) —
    substituting the literal folds comparisons (`3 == 1` → false) and
    dead branches (t18 → `write("many")` alone). Design: `let v = LITERAL`
    (string/number/bool/null — no deps, pure; `-0`/`NaN` can't be
    literals so no identity subtleties), writes==0 program-wide (reuse
    inline's write discipline incl. for-of/for-init/update), reads
    dominated (same list after decl + nested plain blocks/loops/branches
    after; function/arrow bodies vetoed — forward/dynamic calls could
    read before decl (TDZ throw vs substituted value)), global
    `eval`/`Function` veto, non-computed properties/keys/params/labels
    excluded. Drop decl after substituting all reads; const/branch folds
    chain downstream (run before `fold_const_exprs`, or re-run const
    after — Round-14 precedent). Scattered literal single-sites fold
    with it. Est. ~120 lines reusing inline machinery + ~4 unit tests
    (multi-read fold, write veto, closure veto, shadowing veto).
37. **Fact-powered `==` → `===` (minor, bundlable): 8 sites** (t18/t31
    elif chains and friends). Same-domain comparisons (`N1==N1`,
    `S1==S1`, `B1==B1`, same-typeof literals) skip coercion with
    identical semantics. Needs fact consultation at the comparison
    (facts live in three separate passes — either a fourth micro-pass
    over `==` with its own literal/domain check, or extend one fact
    pass to also rewrite comparisons). Cosmetic + micro-perf only.
    Est. ~30 lines + 2 tests. Recommend bundling with item 36 (both
    consume the same elif chains: copy-prop first, strict-eq second).
38. **Store/JS duality (NO ACTION — worker lifting domain): t35.**
    `let r = null` (dead JS binding) beside live `sh2.vars.r` store
    cell. Which namespace serves reads is the lifter's decision;
    post-passes must not second-guess it (Round-14 lesson: the sweep
    died on exactly these pins). Documented, untouched.
39. **`_g` status dance (NO ACTION — contract): 14 sites.** `(sh2._g = E,
    sh2.lastExit = _g ? 0 : 1, _g)` per condition preserves `$?`; each
    element load-bearing (item-14 contract). Untouched.
40. **Program assessment: diminishing returns from here.** After items
    36–37, every remaining opportunity needs worker-domain analysis:
    dynamic dispatch (calling convention), native arrays in fn scope +
    int-typed arrays (migration/type system), running-min O(n²) and
    imod→`%` (loop/range analysis), BigInt hoisting (liveness),
    Horner const-fold (frontend), temp-hoist CSE (temp introduction),
    if-ternary (2 sites), `[].concat(DYN)` (2 sites), `[E].flat().join`
    (1 site). The estree post-pass program is complete for what local
    rewrites can prove; further wins come from analyses, not peepholes.

## Round 16 — literal copy-prop + string equality (2026-09-12)

Implemented Round-15 items 36 (+ const-string-equality in place of the
`===` rewrite it subsumes: same-typeof literal `==` needs no coercion,
so fold directly to bool).

41. **Literal copy-prop** (`let v = L`, L literal, writes==0, dominated
    reads → substitute all + drop decl; closures/pre-decl reads veto
    (TDZ); global eval veto; rollback on veto (no half-folded state);
    precise Object/Spread/New arms + Literal no-op). **DONE**:
    `prop_literal_consts` (after drop2, before const2; snapshot counts).
    t18/t31 elif chains collapse fully (`{ write("many") }`). +3 tests
    (multi-read, write veto, closure veto). Debug note: an early version
    vetoed on every literal (`_` arm) — caught by corpus diff, fixed +
    pinned by the same tests.
42. **String/bool literal equality** (`"a"=="a"` → `true`; mixed types
    never folded (coercion); relational string ops excluded (lone-
    surrogate ordering edge — valid-Unicode equality is exact)).
    **DONE** in const's Binary arm. +1 test.
43. **Const branch fixpoint** (found via t18): branch folding checked
    tests before child recursion folded them (`x == 1` unfolded at
    check time). **FIXED**: per-statement fixpoint (JSON-compared;
    strictly shrinking folds terminate). Pinned by elif-collapse test.

Verification: lib 695/0 (+5 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass (c_isqrt red = worker isqrt redesign, Round-12
handoff stands), 93/93 estree valid (t95/t96 pre-existing), oracle MATCH.

## Round 17 — survey only, no implementation (2026-09-12)

Sweep at `pyjs-r15` output. Headline: a walker-coverage gap with
behavioral proof (t71's for-body `total = total + i` missed while
t59's while-body `i += 1` folds). Audit of every pass walker below.

44. **Walker-coverage completion (RECOMMENDED next).** `fold_compound_assign`
    and `fold_const_exprs` descend into Expression/Block/If/While bodies
    only — `for`/`for-of`/`do`/`try`/`switch` bodies fall to `_` skip
    (verified textually, both passes). The fix is plain recursion for
    these fact-free passes (round-9 drop precedent; r8 loop-soundness
    concerns don't apply — no facts cross scopes): t71 folds, `try`/
    `switch` bodies gain const/compound coverage. Same treatment for the
    fact passes' *candidate discovery* is NOT needed (they already clone
    into loops, r8). For `inline_single_use_lets` and
    `prop_literal_consts`, extend to loop-body *lists* (decl+use both
    inside one iteration body is per-iteration straight-line — same
    argument as same-list folding; cross-boundary stays vetoed), but
    keep vetoing `try`/`switch`/functions there (throw-swallowing and
    deferred-execution change evaluation fate — `let v = BigInt("abc")`
    in a try block must not move past it). `try`/`switch` bodies for
    compound/const are safe (operator-form change evaluates identically;
    dropping never-executed `if (false)`/`while (false)` removes no
    throw). Est. ~40 lines + behavioral tests shaped like t71 (for-body
    compound) and t25-in-a-loop (const branch in for-body).
45. **Loop-status bookkeeping (NO ACTION — worker domain): 24 mentions.**
    `__sh2_loop_ran`/`__sh2_loop_last` + post-loop ternary per
    while-read/until loop (t19/t59/t61/t74) preserves `$?`. Collapsing
    needs loop-body-tail analysis (t61's body always ends `lastExit = 0`)
    plus `$?`-liveness — the `mark_lastexit_dead` family owns it.
46. **`_g` negation chains (NO ACTION — contract): t59.**
    `while ((_g = i >= 3 ? 1 : 0, lastExit = ..., !_g))` tests exit codes,
    not just booleans (bash `until` semantics). Untouched.
47. **Assessment update.** Round-15 item 40 stands, narrowed: after the
    walker completion (44) + copy-prop/strict-eq (36–37), the local
    program is done. Everything else on the deferred list needs
    worker-domain analyses (call convention, migration/type system,
    loop/range, liveness, frontend) — no further peepholes recommended
    after this round's item.

## Round 18 — walker-coverage completion (2026-09-12)

Implemented Round-17 item 44.

48. **Fact-free full recursion**: `fold_compound_assign` and
    `fold_const_exprs` now descend into `for`/`for-of`/`do`/`try`/
    `switch` bodies (+ Object/Spread/New/Function expression positions).
    t71's for-body `total = total + i` folds (`t59` parity). No
    soundness interaction (no facts cross scopes — the r8 concern
    doesn't apply; `try` bodies safe: operator-form changes evaluate
    identically, dropped `if (false)` never executed).
49. **Loop-body lists for inline/copyprop**: both walks rewritten from
    index-paths (Block-only) to direct recursion (plain/branch/loop
    bodies; `try`/`switch`/functions still vetoed — throw-fate and
    deferred execution). Decl+use in one iteration body is
    per-iteration straight-line (same argument as same-list folding).
    Copyprop's global `eval` veto refined from whole-program bail to
    precise recursion first (a `for` anywhere had vetoed everything —
    caught by the new loop test, not corpus).
    +3 behavioral tests (compound/inline/copyprop loop bodies).

Verification: lib 698/0 (+3 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass (c_isqrt red = standing handoff), 93/93 estree
valid (t95/t96 pre-existing), oracle MATCH.

## Round 19 — facts into `sh2.arithEval` arrows (2026-09-12)

t86/t88's per-division `(Number(n) || 0)` sits inside `sh2.arithEval(() =>
...)` — vetoed as deferred execution. But `arithEval` invokes its
argument immediately and synchronously (namespace: `const v = f()` in
try) with a fresh arrow (no aliasing, exactly-once) — same timing and
values as straight-line code, so current facts hold inside.

50. **Immediate-arrow facts.** `sh2.arithEval(() => BODY)` (direct arrow
    argument only; stored arrows stay vetoed) processes BODY with
    current facts: Block bodies via cloned `stmts` (inner establishments
    stay local), expr bodies via `expr`. Outer-fact invalidation by body
    writes needs no new machinery — the statement kill-scans already
    check arrow bodies precisely (Round-6 refinement). Applied to all
    three fact passes uniformly. t86/t88 hot-loop guards gone (2→1, the
    entry source). +2 unit tests (immediate folds, deferred vetoed).
    Follow-ups (no corpus value today): IIFEs (same immediacy argument),
    `captureSync` arrows (sync unverified for this purpose), S1/B1
    arrows (same code path added uniformly — fires when shapes arise).

Verification: lib 700/0 (+2 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass (c_isqrt red = standing handoff), 93/93 estree
valid (t95/t96 pre-existing), oracle MATCH.

## Round 20 — positional-arg guards via call graph (2026-09-12)

`sh2.positional[K] ?? D` guards missing args. `fnCall` provisions the
frame (`this.positional = flat`, verified); `callDirect` does not touch
it — so only `fnCall` calls inform verdicts.

51. **Call-graph defaults.** Per singly-defined, inline-arrow function
    (identifier-bound arrows may alias into direct calls — gated out;
    `functions.get("f")` value-escape poisons that name, non-literal
    poisons all; dynamic `fnCall` names poison all; redefinitions and
    body writes to `positional` bail): every call supplies non-nullish
    literal/template at K → drop guard; no call supplies K → use D;
    else keep. Identifier args (t52's loop var — needs element typing)
    and zero-call functions (t75's `first`) correctly kept. t23/t76
    fold (4 sites). **DONE**: `fold_positional_defaults` (census +
    verdicts + frame-local rewrite, nested frames skipped). +3 tests
    (drop, default, mixed veto). Debug note: a level-mismatch in the
    frame matcher silently disabled everything — caught only by asserting
    counts, fixed + pinned.

Verification: lib 703/0 (+3 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass (c_isqrt red = standing handoff), 93/93 estree
valid (t95/t96 pre-existing), oracle MATCH.

## Round 21 — if-ternary temps, block-assign merge, pure methods (2026-09-12)

Survey: t60's `__t0` if-temps (2 sites) + t30's const-collapsed
`let y = ""; { y = "yes"; }` fallout. Design first (below), then built.

52. **If-ternary temp fold** (`let T = I; if (C) T = A; else T = B;
    use(T)` → `use(C ? A : B)`, decl+if dropped; else-less `if (C) T = A`
    → `use(C ? A : I)`): single-assign branches only (no other effects
    to order), writes==2 (1 else-less) + reads==1, INIT pure (dropped
    unread), C/A/B/I side-effect-free (single evaluation preserved;
    same throw-ordering standard as inline — pure means no effects).
    **DONE**: `fold_if_ternary` post-pass (same-list decl/if/use;
    straight-line use vetting + substitution shared with inline
    patterns). t60 ×2 fold (S1 conditional-establish already covers any
    wrappers). +3 unit tests (fold, else-less, multi-read veto).
53. **Block-assign merge** (`let v = Z; { v = K; }` single-stmt block →
    pair-fold): the block is unconditional straight-line with no scope
    effects (no decls inside) — unwrap to adjacent pair and reuse
    `fold_let_init_store` gates verbatim. **DONE** (normalization inside
    fold_let; t30 → `let y = "yes"` → inline → `write("yes")`). +1 test.
54. **Pure-method calls** (needed by 52's `("hello world").includes(..)`
    test): `side_effect_free` gains Member calls with property in the
    pure-method set (string/array non-mutating, non-throwing subset —
    repeat/pad excluded as before) and recursive receiver checks
    (`foo().slice()` still vetoes). **DONE** (shared helper; isNaN rule
    benefits consistently). +1 test (method-call purity).

Verification: lib 706/0 (+6 net; 1 pre-existing C failure unchanged),
c_fn_locals/params pass (c_isqrt red = standing handoff), 93/93 estree
valid (t95/t96 pre-existing), oracle MATCH.
