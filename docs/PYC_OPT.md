# PYC_OPT — C backend output: optimization survey + implementation log

Survey of the C emitted for the Python corpus (`frontends/py-sh-go/testdata/*.py`
via `otranspilerl-cli <test>.py <out>.c --target c`). All samples below compile
clean (`gcc -fsyntax-only`).

Method: generated C for 16 tests spanning literals → dicts → bigint factor
(t14, t16, t17, t19, t20, t22, t24, t29, t30, t40, t46, t51, t52, t69, t73, t86),
read the output, listed what a peephole / renderer-level pass could remove or
tighten. Numbered items are independent work items.

## Implementation status

Each item below is marked DONE (implemented in `sh2perl/src/c_backend.rs`,
gate-kept) or DEFERRED (reason given). Verification per batch: `cargo test
--lib c_backend` (61 tests), the shell C gate `harness/c_gate_main.sh`
(held at baseline PASS=592 FAIL=45 SKIP=7 — the 45 are pre-existing
shell-feature gaps, fail set byte-identical before/after), and 17
Python→C snapshots (compile + run, stdout md5-identical to pre-change
baselines). Commits (submodule, `c_backend.rs` only):

- `4c99cd6d` items 1+2 · `a1d56b86` items 3,7,8,14 · `ae3da0f4` include
  triggers (20/21) · `ef9ce236` items 4,15,16 · `cf05bb3a` item 9 ·
  `626cf1cb` item 19.

Round 2 (items 23–46, same verification; unit tests now 69, snapshots 19,
gate re-verified at PATH level — an early basename-based comparison
collapsed all fail paths to `diff` and compared counts only; the `*.paths`
files carry full paths. One full-gate flake observed (`heredoc-
singlequote-span.sh`, passes solo, CWD-sharing `x.py` litter under
parallel load — since cleaned). Round-2 work is UNCOMMITTED: another
worker has 1200+ lines of uncommitted `c_backend.rs` changes in the tree,
so per-author commits are impossible without sweeping their work in.

## A. Dead code / redundant constructs

1. **Do/while residue on plain `while`** (t19): `while i < 3:` emits
   `{ int _went = 0; while (...) { _went = 1; ... } if (!_went) { } }`.
   The flag + empty `if` are dead for a test-first loop — emit a bare `while`.
   **DONE**: call-free `While` conds emit a `_sh_rc = 0;` pre-set (no flag, no
   per-iteration store, no branch); `strip_dead_rc` removes the store when `$?`
   is dead. Conds with calls and all `whileLoop` sites keep `_went` (a site
   tail runs `_sh_system_rc()` per evaluation — a pre-set would be overwritten
   by the failing cond itself; the gate caught this).
2. **Duplicate initialization** (t19, t29, t86): `long long i = 0;` followed by
   `i = 0;`; `uint8_t x = 0; x = 1;`; `static long long _i_sqrt_n = 0;` then
   reassigned. Drop the second store (or the initializer when provably
   overwritten on all paths).
   **DONE**: `fold_init_store` post-pass merges `T v = 0;`/`T v;` with the first
   same-indent straight-line `v = K;` (K constant, no mentions between,
   non-static scalar).
3. **Dead comma statements** (t73): `(_sh_rc = 0, 1);` — constant expression
   statement; delete. Same family: `, _sh_rc = 0` tacked onto `printf` (item 9).
   **DONE**: `drop_const_stmts` post-pass removes `1;`-style constant statements
   (covers the `(_sh_rc = 0, 1);` → `1;` residue when rc is dead).
4. **Unused argv array** (t22): `char *_sh_av0[2]; _sh_av0[0] = "f";` built for a
   zero-arg call `(f(), _sh_rc == 0);` — omit the array when arity is 0 (and
   drop the discarded `, _sh_rc == 0` comparison).
   **DONE**: the `_sh_av` array is emitted only in the argv-swapping call path
   (lifted and `pos_const` calls never read it).

## B. Redundant parens / casts / guards

5. **Double parens + redundant casts** (t16: `if ((x == 1))`; t86:
   `(i < _i_sqrt_nv)`, `((n) % i)`, `(long long)(i)` where `i`/`n` are already
   `long long`). Strip no-op parens; drop same-type casts.
   **DEFERRED**: purely cosmetic — `gcc -O` folds them, zero runtime impact.
6. **Per-iteration zero-guard** (t86): `((i == 0 ? 0 : ((n) % i)) == 0)` — `i`
   starts at 1 so the guard is dead; hoist/prove it once or drop it.
   **DEFERRED**: needs induction-variable proof (nonzero init, monotonic step,
   no body writes) at the div/mod emitter; a missed write-path = SIGFPE.
   The `arith_divisor_bounded_nonzero` hook is the right place when the
   analysis exists.
7. **Null-guard ternary on non-null strings** (t20):
   `((char*)(n) ? (char*)(n) : "")` — plus a double cast. The value cannot be
   NULL here; emit `n` (or at most one cast).
   **DONE** (with 8): `printf_from_parts` skips the `%s` guard for
   `is_nonnull_helper_call` (`_sh_assoc_get`/`_sh_arr_get` — every path
   returns `""`), which also single-evaluates the call.
8. **Doubled assoc lookup** (t73): `_sh_assoc_get(d_k, d_v, d_n, "b")` evaluated
   twice in one `printf` (once for the ternary test, once for the value).
   Bind once to a temp.
   **DONE** (with 7 — guard removal single-evaluates; no temp needed).

## C. Loop strength-reduction

9. **Bound temp + strict compare** (t86):
   `_i_sqrt_nv = (_i_sqrt_n + 1); for (i = 1; (i < _i_sqrt_nv); i++)`
   → `for (i = 1; i <= _i_sqrt_n; i++)` (fold `+1` into `<=`, drop the temp).
   **DONE**: `bound_plus1` hoist-fold rewrites `tmp = Y + 1` … `while (V < tmp)`
   → `while (V <= Y)` (adjacent or lookahead over stmts mentioning neither;
   Y a cheap Var/Num unwritten in body; tmp used exactly twice; bash arith is
   integers so `< Y+1` ⟺ `<= Y`), and `fold_range_pair` accepts `<=` so the
   C-`for` lift still fires.
10. **Grow-check per push** (t86): `while (len + 1 > cap) grow` emitted before
    EACH of two consecutive pushes → ensure capacity for 2 once.
   **DEFERRED**: needs ShIR-level batching of consecutive same-array appends;
   the per-push branch is predictable and cheap. Skip.
11. **Inner array re-declared per outer iteration** (t40):
    `static const long long _for_j_1[] = {1, 2};` sits inside the outer loop
    body → hoist to function scope (or share one table).
   **DEFERRED**: `static const` tables cost nothing at runtime (compile-time);
   hoisting is cosmetic. Skip.
12. **Copy-then-use loop var** (t40/t51): `i = _for_i_0[_i_i]; printf(..., i)` →
    iterate the element directly (or a loop-local), skipping the global copy.
   **DEFERRED**: one load/store per iteration; removing it needs loop
   restructuring. Negligible. Skip.
13. **Loop-var widths** (t40/t51): outer `uint8_t i` (global!) vs inner
    `long long j`; narrow globals risk overflow and force `%hhu` conversions.
    Prefer function-local `long long`/`int` counters (also fixes item 2's
    duplicate init as a side effect).
   **DEFERRED** (with 22): widths are owned by the active range-narrowing
   analysis with tests pinning narrow types — needs its owner, not a peephole.

## D. Output / string handling

14. **`system("bash -c 'echo ...'")` for plain prints** (t73 — biggest fish):
    `print(d["a"])` lowers to `_sh_reset(); _sh_word("echo"); ...;
    _sh_system_rc()` (process spawn per line). Route side-effect-free
    `echo`-of-words to direct `printf`/`fputs` like t46/t69 already do.
   **DONE**: `echo_native_ok` + `parts_of` accept bare `Index` words (the Python
   frontend's unsplit single value; shell split forms arrive as
   `split`/`arrayIndex` calls and stay shell-out). t73's prints are now direct
   `printf`, which also let `trim_sh_runtime` + `strip_dead_rc` fire (98→38
   lines).
15. **Assert-per-use on known strings** (t24/t30/t69):
    `if (a) assert(strlen(a) <= 3);` before every use, and
    `assert(strlen((char*)("yes")) <= 3)` on literals. Literals are provable
    at render time → `_Static_assert` once or omit; drop the `if (a)` guard
    for non-null consts.
   **DONE** (partial): `emit_bound_asserts` skips `const_lifted` vars
   (immutable, literal fits by construction); `emit_guarded_copy` drops the
   assert for fitting unescaped literals. Tripwires on mutable buffers stay.
16. **`strncpy(y, ..., 3 + 1); y[3] = '\0'`** (t30): fold `3 + 1` → `4`; the
    explicit NUL is redundant after `strncpy` padding (or use `memcpy` + NUL).
   **DONE**: capacity folded at emit (`4`); the NUL store is elided when the
   source is a fitting unescaped literal (strncpy pads).
17. **Positive note — keep**: fused `printf("%s-%s\n", "a", "b")` (t46) and
    `printf("value=%hhu\n", x)` (t69) are already optimal; don't regress these.

## E. Prelude / runtime bloat

18. **Whole shell-out runtime even when unused** (t73): `_sh_cmd`/`_sh_wrap`
    buffers, `_sh_grow/_sh_add/_sh_word/_sh_reset`, `_sh_wrap_cmd`,
    `_sh_system_rc` (~60 lines) emitted wholesale. Tree-shake per used helper
    (t73 needs assoc get/set + one print path, not `bash -c`).
   **DONE** (verified, no new code): the existing `trim_sh_runtime` drops it
   once genuinely unused — t73 (item 14) proves the path end to end.
19. **Fixed 1024-entry parallel assoc arrays** (t73):
    `char *d_k[1024]` for a 2-key dict + linear scan + `strdup` per set.
    Size the tables from the static key set (or a small-VEC growth scheme).
   **DONE**: assoc decls and all five `_sh_assoc_set` call sites use
   `array_cap(var)` (existing proof map; over-approximate and fail-stop,
   unproven stays 1024). t73: `d_k[2]`/`d_v[2]` with cap-2 guards.
20. **Unconditional I/O setup + include block**: `freopen("/dev/null","w",stderr)`
    + `setvbuf(...,_IONBF,...)` and `#include <stdlib.h> <limits.h> <errno.h>`
    (plus `<unistd.h>/<sys/wait.h>`/GMP when any feature keys them in) land in
    every file whether used or not. Gate each on actual use.
   **DONE** (includes): trigger matching is now boundary-aware (`sqrt(` no
   longer matches `_sh_isqrt(`, `read(` no longer matches `fread(`) —
   false-kept `math.h`/`unistd.h` drop. `freopen`/`setvbuf` were already
   conditional (1/16 samples).
21. **Mid-file `#include <math.h>`** (t86, line 15, after code has started):
    hoist all includes into the top preamble block.
   **DONE** (by removal): unused `math.h` is now dropped, so the misplacement
   no longer manifests. Reordering the block for the still-using case is
   cosmetic — left alone.

## F. Types across the board

22. **Narrow `uint8_t` for values/counters** (`x = 7`, loop `i`, `x = 1` in
    t69/t51/t29 with `%hhu`): prefer `int`/`long long` locals; narrower types
    buy nothing here and risk overflow + conversion noise (see items 12–13).
   **DEFERRED** (with 13 — owner's analysis).

## Suggested order (value/effort)

1. Item 14 (spawn-per-print) — dominates runtime where it fires.
2. Items 1–4 (dead code) — trivially safe, shrink everything.
3. Items 5–9 (parens/casts/guards) — peephole-level, no semantics risk.
4. Items 9–13 (loops) — needs range/arith context in the renderer.
5. Items 18–21 (prelude) — per-feature usage flags in the renderer.
6. Items 15–17, 22 (strings/types) — needs verdict plumbing; do last.

## Round 2 — further opportunities (surveyed after round-1 implementation, not implemented)

Fresh read of current output over a wider spread (t21, t23, t25, t26, t28,
t31, t37, t38, t41, t47, t48, t55–t58, t60, t71, t72, t87, t92, plus re-reads
of t20/t52). Numbering continues (23–45). Nothing below is implemented.

## G. Null-guard generalization (follow-ups to 7/8)

23. **Ternary-both-nonnull** (t23, t52): `((char*)(((1 < _sh_argc &&
    _sh_argv[1]) ? _sh_argv[1] : "")) ? ... : "")` — the inner ternary's
    branches are both non-null (true branch guarded by its own condition),
    so the outer guard is dead. Needs a tiny expression non-nullness lattice
    (ternary with both branches non-null → non-null; guarded-deref →
    non-null), not just call-name matching.
   **DONE** (narrow): `guarded_deref_nonnull` proves `(C) ? P : ""` non-null
   when P appears verbatim as a top-level `&&`-conjunct of a pure C
   (`(P == 0)`-style false friends excluded) and collapses the guard to a
   single `(char*)(X)` (single evaluation).
24. **Array idents are non-null** (t28, t37, t38, t60): `(a ? a : "")`,
    `(s ? s : "")`, `(_s0 ? ... : "")` on `char[N]` fixed buffers and
    `static char _sN[32]` num_temps — arrays never decay to NULL. t47 already
    prints a const array bare, so the knowledge exists in one path but not
    the others.
   **DONE**: `store_ref` returns bare idents for `buf_bound` vars (fixed
   `char[N]`); `num_temp_bufs` membership skips the guard for `_sN` temps.
25. **`if (arr)` is dead-true** (t60: `if (__t0) assert(...)`) — same family
    as 24, in test position.
   **DONE**: `emit_bound_asserts` drops the wrapper for `buf_bound` vars
   (keeps the bare assert as tripwire).
26. **Unify guard elision**: the `x ? x : ""` guard is emitted by several
    emitters (printf args, test operands, strlen args, substr args), each
    with different incomplete non-null knowledge. One `nonnull_expr(v)`
    predicate consulted everywhere replaces per-site special cases (7/8/23/
    24/25 as instances).
   **PARTIAL**: 23/24/25 done as targeted rules; full unification (flow
   facts 27, helper audits 28) remains.
27. **Flow extension** (harder; t20, t52): `n` assigned from a non-null table
    immediately dominates its print, but the `nonnull` set doesn't flow into
    loop bodies. Needs dominating-assign flow, not just declaration facts.
   **DEFERRED** (needs flow analysis).
28. **Renderer-emitted helpers audit** (harder; t37, t52): `_sh_capture_fn`,
    `_sh_substr`, join helpers return non-null by construction (`vgrow`
    aborts; `tmpfile`-failure path still returns a grown buffer). Each needs
    a one-time source audit, then they join the nonnull set and all call
    sites shed guards — same shape as the 7/8 getter fix, inter-procedural.
   **DEFERRED** (audits not done).

## H. Constant evaluation at emit

29. **Constant conditions** (t25: `if ((1 < 2))`) — side-effect-free constant
    comparisons fold at emit; drop the dead `if` (and dead `else` branch).
   **DONE**: `fold_const_branch` evaluates pure const conds (numeric
   consts/const_vars, decidable string tests) and keeps only the live
   branch; const-false `while` vanishes.
30. **Pure libc calls on literals** (t26: `strcmp("a", "a")`) — fold
    `strcmp`/`strlen`/`memcmp` of all-literal args (no side effects,
    deterministic). Generalizes 29.
   **DONE** (via the literal-test-string arm of the same fold).
31. **`atoll` of numeric literals** (t92: `(long long)atoll((char*)("3"))`,
    repeated 6× per element) — fold to `3LL`. Large size win where aggregates
    multiply it.
   **DONE**: `store_int_item_c` folds numeric strings (non-numeric and
   overflowing fall through to `atoll`, preserving its clamp).
32. **Const-propagated branches** (t31): `const x = 2; if (x == 1) … elif
    (x == 2) …` — the tested var is `const_lifted` with a known literal, so
    evaluate the comparisons at emit and keep only the live branch.
   **DONE** (via `const_rhs` in the same fold; t31's chain → one `fputs`).

## I. Redundant temporaries / copies

33. **num_temp+print fusion** (t38): `snprintf(_s0, … "%lld" …); printf("%s",
    _s0)` with a single use → `printf("%lld", …)` directly. Needs a
    single-use check on the temp.
   **DONE**: `num_temp_src` records the `(long long)(…)` expr; single-use
   (exactly decl+snprintf, snprintf last) fuses to `%lld`.
34. **Substr input copy** (t37): `_sh_substr` needs an output vbuf, but the
    input is copied to `_v0` even when the source is a stable const array —
    pass stable lvalues directly (input is only read).
   **DONE**: bare-ident sources skip the stabilizing copy (composes with 24:
   the guard removal turns the source into a bare ident).
35. **GMP copy-then-op** (t87): `mpz_set(t, x); mpz_add(r, t, y)` →
    `mpz_add(r, x, y)` where the op's aliasing rules allow it (add/sub/mul
    permit `rop == op1`; div/mod/pow restricted). Needs a per-op audit.
   **DEFERRED** (audit not done).
36. **GMP temp pool** (t87): statement-scoped mpz temps (5 for 3 prints) can
    reuse 2 temps with liveness. Needs temp-liveness across statements.
   **DEFERRED**.
37. **Print-sinking** (t60: strncpy-temp-print → `fputs` per branch). Classic
    tail-duplication; only wins when branches are single prints — size
    tradeoff, measure before doing.
   **DEFERRED** (size tradeoff; unmeasured).

## J. Calls / argv / save-restore

38. **Return-valued functions via capture** (t52 — biggest round-2 fish):
    `greet` (`return "hello " + name`) is captured through
    `_sh_capture_fn` (tmpfile + dup2 per call!) plus `_sh_call_fn` argv
    machinery (~40 helper lines). Extend the lifted-fn detection to
    single-`return EXPR` bodies → direct value return, deleting the capture
    path for such functions.
    **BLOCKED (attempted, reverted)**: the scan extension works (greet lifts
    to `char *x = greet(arg)`), but `pending_frees` flushes only at
    top-level-statement boundaries, so a lifted-value temp declared inside
    a loop body is freed after the loop — out of scope (compile error) and
    a per-iteration leak. Prerequisite is item 46.
39. **Discarded pure comparisons keep `$?` alive** (t22, t41):
    `(f(), _sh_rc == 0);` — the comparison is pure and its value discarded,
    yet `==` counts as an rc read and pins the whole dead-rc machinery.
    `(f(), _sh_rc == 0);` → `f();` may cascade into `strip_dead_rc`.
   **DONE**: `trim_discarded_rc_cmp` runs before `strip_dead_rc`
   (`(f(), _sh_rc == 0);` → `f();`).
40. **Dead argv save/restore on last call** (t23: `_sh_sv1/_sh_sc2` never read
    after) — drop when no later argv reads. Narrow; post-pass shaped.
   **DEFERRED** (needs comma surgery + use analysis; narrow).

## K. Arrays (follow-ups to 19)

41. **Constant-index writes shouldn't poison sizing** (t55: `a[1] = "X"` →
    `a[1024]`): cap = max(bulk, max-literal-index + 1) when all indices are
    literal/bounded. Currently ANY `indexed_write` forces 1024.
   **DONE**: literal non-negative indices raise `lit_index_max`; dynamic
   poisons; assoc-flagged arrays skip literal sizing (numeric assoc keys
   are extra string keys); all indexed `_sh_arr_set` sites use
   `array_cap` (decl/guard agreement).
42. **Static bulk-literal init** (t21/t56/t57/t72/t92): all-literal bulks →
    `static T a[N] = {...}` initializer + len, deleting the per-element
    stores, guards, atolls (with 31), and the `_ai0` counter.
   **DEFERRED** (fragile multi-line surgery for a register-resident counter;
   diminishing returns after 31/43).
43. **Proven-capacity store guards** (t56/t57/t72): skip `if (i >= cap)` when
    the sizing proof covers the array and the index is provably in range
    (literal / `_ai` counter pattern). Pair with 42.
   **DONE**: bulk-fill per-store guards skipped when the cap is proven
   (unproven keeps them).
44. **`static T v = 0;` → `static T v;`** (t56/t57/t72/t92 `_len` decls) —
    static storage is zero-initialized; the explicit `= 0` is always dead.
    (The separate `= 0` STORE still needs once-execution proof — not claimed.)
   **DONE** (`static` keyword preserved — an early version dropped it and
   changed linkage/lifetime; caught by inspection).
45. **strdup-of-literal into never-mutated arrays** (t56: `a[i] =
    _sh_xstrdup("a")`) → store the literal directly. Needs escape analysis
    (no later writes, no `free` of elements) — harder.
   **DEFERRED**.

46. **Free placement for heap temps in compound bodies (found while
    attempting 38, not implemented)**: `pending_frees` flushes only at
    top-level-statement boundaries (`program()`), so any native value-call
    temp created inside a loop/branch body is freed after the enclosing
    construct — out of scope when the temp is block-scoped (compile error)
    and a leak otherwise. Flushing per inner statement needs an audit that
    no temp lives across statements (the Assign move-removal path suggests
    it holds, but use-after-free is invisible to the plain gate — validate
    under `--sanitize` before attempting).
