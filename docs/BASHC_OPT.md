# BASHC_OPT — C backend output: optimization survey (bash corpus)

Survey of the C emitted for the bash corpus (`sh2perl/examples/*.sh`
via `otranspilerl-cli <file>.sh - --target c`). All samples below compile
clean (`gcc -fsyntax-only`; only pre-existing benign `-Wall` notes:
unused `_aiN`/`_cN_*` temps, comma-expr values).

Method: generated C for 25 diverse examples (control flow, pipelines,
args, arithmetic, loops, interpolation, sys/file utilities), read the
output, listed what a peephole / renderer-level pass could remove or
tighten. Numbered items are independent work items. Status per item:
DONE (implemented in `sh2perl/src/c_backend.rs`, gate-kept) or
DEFERRED/SKIPPED (reason given). Implemented in round 1: 1, 4, 7, 9,
10, 12, 13, 14. Round 2 (items 19–29, bash-corpus survey below): 19, 20, 21, 22,
24, 25, 26, 28 DONE; 23 SUPERSEDED; 27, 29 DEFERRED (reasons given).

Measured baseline (25 files, 4723 total lines):
- **3839 lines (81%) are prelude** (runtime helpers + file-scope decls),
  only ~19% is the program.
- **61 shell-out sites** (`_sh_site_N`, each a `fork`+`exec` of `bash -c`
  at runtime), ~2.4 per file.
- 40 `_sh_is_*` file-test helpers emitted across the sample.
- 13 `atoll(` + 36 `snprintf(` calls (string↔number round-trips).

A focused illustration of the headroom: `001_simple.sh`'s 5-iteration
`echo $i` loop runs ~5x slower than `bash` itself (15ms vs 3ms), each
iteration forking a full `bash -c` to print one digit.

## A. Runtime prelude trimming

1. **All-or-nothing `need_stat` block**: one flag emits `_sh_mtime` plus
   all ~20 `_sh_is_*` file-test helpers (`-f -d -e -s -l -h -S -p -b
   -c -g -k -u -t -G -O -N -r -w -x`). `001_simple.sh` uses only `-f`
   but carries all 20 (~20 lines, each a function the linker then
   keeps). Split the flag per operator (or per used helper) so only
   referenced tests emit. Est: ~15–20 lines/program. S.
   **DONE**: `need_stat_ops: BTreeSet<String>` — each helper emits iff used; `-L` normalized to `_sh_is_l` (it previously called the never-defined `_sh_is_L`: compile break, now fixed+tested). `001`: 21 → 2 `_sh_is_` lines.
2. **Prelude share (81%)**: follow-on to item 1 — audit remaining
   always-emitted helpers (`_sh_export`, `_sh_mtime`, readline state,
   `_sh_wrap` machinery) for need-flags the same way `need_stat`/
   `need_time` already gate theirs. M.
   **DEFERRED** (open-ended audit; the remaining always-emitted helpers need individual need-flags like item 1 — mechanical follow-ups).
## B. Shell-out elimination (the fork-per-builtin tax)

3. **Unquoted words proven split-free go through the shell** (`001`:
   `echo $i` → `_sh_site_1` → `_sh_export("_SHSPLIT", _s0)` +
   `system("bash -c ...")`, per iteration). A `%lld`-formatted number
   (or a var proven free of IFS whitespace/glob chars) cannot
   word-split, so `_sh_addraw`-ing its text is exact — no export,
   no fork. `002` already proves the pattern exists: `echo "Number:
   $i"` renders native `printf("Number: %lld\n", i)` while bare
   `echo $i` shells out. Unify the two paths on provable
   split-freeness. Est: removes ~all 61 sites that are pure echo;
   order-of-magnitude on echo-heavy loops. L.
   **DEFERRED** (needs its own turn): split-freeness proofs + word-buffer path changes touch shell-eval semantics owned with the JS worker; blast radius too big to rush.
4. **`[ $i -lt 10 ]` via snprintf/atoll round-trip** (`002`):
   `snprintf(_s1, "%lld", i); return ((atoll(_s1) < atoll("10")));`
   — two conversions plus a temp to compare two ints. Numeric
   operands with numeric vars should lower to `(i < 10)` directly
   (constant-fold the literal side). Same family: `atoll("10")` of a
   constant is a missed fold everywhere. M.
   **DONE** (typed vars only): `test_num_operand` — Int var/int literal on both sides renders native `(i < 10)`; untyped keeps atoll. Sh-source vars are untyped so the gate impact there awaits item 6.
5. **Test-builtin site wrappers**: where a `[ ... ]` test does need
   the shell (string ops), the site still rebuilds the whole command
   line per evaluation. Hoist loop-invariant command text out of the
   loop (the `_sh_reset()` + literal words don't change). M.
   **SKIPPED** (not a defect: pipeline stages are external processes by design; noted as floor).
## C. Numeric homing for sh-source programs

6. **Arithmetic vars stay `char*`** (`047`: `j=1; for i in {1..5};
   j=$(($j*$i))` renders `j`/`i` as `char*` with per-iteration
   `atoll`×2 + `snprintf` + `free` + `strdup`). Both are provably
   integers (literal init, pure-arith updates). The py-sh-go path
   homes these natively via `analyze_var_types`; the sh-source path
   should run the same verdicts (or a narrow `LitInt`-init +
   arith-only-update rule). Target shape: `long long j = 1, i;
   for (i = 1; i <= 5; i++) j *= i; printf("%lld\n", j)`. L.
   **DEFERRED** (needs its own turn): investigated — sh-source `j=$(($j*$i))` lowers to opaque `arith("$j*$i")` TEXT (not structured Arith), and `$`-refs in the text mark vars store-read, defeating the lift. Fixing needs arith-text parsing + fixpoint with `numeric_lift_vars`; touches analysis the JS worker owns.
7. **Brace-seq arrays stay string arrays** (`047`:
   `static const char* _for_i_0[] = {"1",...}` + `i =
   (char*)_for_i_0[_i_i]` for `{1..5}`). A constant int seq should
   fold to a C `for` (`for (i = 1; i <= 5; i++)`), reusing the
   existing range-fold machinery. M. (Also kills the `size_t _i_i`
   index temp and the `static` table.)
   **DONE**: `seq_of_ints` — const brace-int-seq folds via the existing `seq_iter_range` path (all three consumers: native loop, Int typing, range seeding). Strictly canonical decimals only (`01`/`+5` fall back); step≠0 required; descending/letters fall back (some, e.g. `{5..1}`/`{a..c}`, were already dropped pre-change — pre-existing gaps, untouched). Int-homed brace loops run on a HIDDEN counter + per-iteration assign (not directly on the var): a direct `for (i = 1; i <= 5; i++)` leaves `i==6` where bash leaves LAST (`i==5`) — `002`'s post-loop `while [ $i -lt 10 ]` caught exactly this (missing first Counter line). Range (`$(seq)`/py-range) iters keep the direct-var form (pre-existing behavior); their latent end-value gap is item 18 below. The mark itself is gated brace-only by `assigned_non_int_vars` (any non-int-shaped assign — `i=hello`, unknown calls, non-seq headers — anywhere keeps string homing; the renderer falls back to the table path, which renders buffer-homed loop vars via `strncpy` through `emit_guarded_copy`).
8. **Final `echo $j` shells out** (`047` → `_sh_site_1`): falls out of
   items 3+6 (numeric var + split-free word ⇒ direct `printf`).
   Listed separately because it is user-visible per program run.
   M (with 3+6).

## D. Dead code / dead temps

9. **Orphaned num temp** (`002`): `static char _s0[32];
   snprintf(_s0, "%lld", i);` emitted, never read (the site does its
   own conversion). Liveness-sweep single-use `num_temp`s: if the
   temp name never appears after its definition point, drop the
   definition. S. (Also covers the `_c11_wcap`-style unused capture
   temps flagged by `-Wall`.)
   **DONE**: `drop_dead_num_temps` post-pass — orphaned `static char _sN[32]; snprintf(...)` pairs dropped when the temp is never read and the value is call-free (ident+paren call-syntax detector with keyword guard).
10. **Empty `if (!_went) { }`** (`010`): the while-status idiom with
    the store stripped but the empty branch left. Drop empty
    blocks/statements in a peephole (same family as PYC_OPT item 3's
    `drop_const_stmts`). S.
   **DONE**: dead `_went` scaffold removal inside `strip_dead_rc` (decl + set + empty test + block close, verified triple-only + same-indent matching).
11. **`_sh_rc = 0` stores where `$?` is dead** (`001` keeps 3 though
    nothing reads `$?`): tighten `strip_dead_rc` to straight-line
    tail positions (the `if`/loop-entry stores it keeps are only
    needed when a later read exists). S.
   **DEFERRED**: needs flow-sensitive rc liveness (stores dead unless a later read); `strip_dead_rc` is global on/off today. Non-trivial, real miscompile risk if wrong.
## E. Redundant guards / casts / round-trips

12. **Null-guard ternary on borrowed pointers** (`005_args`):
    `printf("Arg: %s\n", ((char*)(a) ? (char*)(a) : ""))` where `a`
    comes straight from `_sh_argv[_ai_a]` (non-NULL by exec
    convention and loop bounds). Same family as PYC_OPT item 7:
    extend the guard-drop to argv-borrowed reads. S. (Note the
    analysis is already exactly right to *borrow* here — no strdup,
    no free of an argv pointer. Keep that.)
   **DONE**: for-argv loop var proven nonnull at the assign (argv[1..argc) non-NULL by exec convention + bounds check); `printf_from_parts` tolerates word-renderer parens in the lookup. Per-statement clearing removes the proof after the loop (zero-trip safe). Verified with/without args.
13. **Repeated `getenv` in one expression** (`062_12`):
    `${USER:-...}` evaluates `getenv("USER")` five times in a single
    `snprintf` argument (test-nonempty, test-[0], value, twice more).
    Bind once to a temp (same family as PYC_OPT item 8, doubled
    assoc lookup). S/M.
   **DONE**: call-containing `var_expr` hoisted to `const char *_dN` in the -/:-/:?/=/:= arms (single evaluation; also fixes multi-run of side-effecting `${x:-$(cmd)}` defaults). Bare ident/member forms stay inline. `062_12`: 5→1 `getenv("USER")` (inner store-read duplication untouched — separate path).
14. **Const-literal vbuf dance** (`002`): the `"World"` literal is
    rendered via `static _sh_vbuf _v3; _sh_vgrow(...); for(;;)
    snprintf(...)` — a growable-buffer retry loop for a 5-char
    constant. Constant-fold all-literal interpolations to plain
    string literals. S.
   **DONE**: all-literal `Interpolate` returns `cstr` directly (rebuilt from raw Lit parts since fmt carries `%%` escapes); `"World"` now inline in the argv array.
## F. Loop-invariant code motion

15. **Loop-invariant string copies** (`010_substring_loop`):
    `${s:$i:1}` copies all of `s` into `_v1` (vgrow+strcpy) every
    iteration though `s` never changes in the loop. Hoist invariant
    source materializations out of loops (with the usual
    bail-on-write-inside). M. (Ironic next to that test's own
    anti-hoisting regression guard — the *slice* must stay put,
    the *source copy* can move.)
   **DEFERRED** (needs loop analysis + write tracking; see item 6 area).
16. **`len=${#s}` re-derivation**: bounds/lengths recomputed per
    iteration where the array/string is loop-invariant. Same
    mechanism as 15. S.
   **DEFERRED** (same mechanism as 15).
## G. Globals that could be locals

17. **File-scope loop counters and temps**: `long long i = 0;`
    (`001`) and friends are file globals though used only in `main`
    (or one function). The `fn_private`/`main_private` localization
    passes being built for the py-sh-go path apply equally here —
    `i` is currently pinned global only because the echo site reads
    it, which chains this item behind item 3 (direct printf ⇒ no
    site ⇒ localizable). Cross-item chaining noted explicitly. M.
   **DEFERRED** (chained behind item 3: vars pinned global only by site reads localize once the reads go direct).
## Non-goals (floor, not gaps)

- **Pipelines spawn real processes** (`003`: `sort`/`uniq`/`grep`
  argv vectors + popen scaffolding, 30 site/cap/pipe refs). Faithful
  external-process semantics require exec; native reimplementation
  of coreutils is out of scope. The per-stage argv arrays could drop
  their `0` terminators-counting dance, but that's noise-level.
- **`system("bash -c ...")` for genuinely dynamic code** (`eval`,
  `source`, unanalyzable expansions): the fork is the semantics.
- **`fputs(...), _sh_rc = 0` comma stores where `$?` is live**:
  required for `echo hi; echo $?` fidelity — only item 11's dead
  cases should go.

## Follow-ups found during implementation

18. **Seq-loop end value for Range iters**: `for i in $(seq 1 5)` (and
    py-sh-go `range()` loops) render `for (i = 1; i <= 5; i++)`
    directly on the var, leaving `i==6` where bash leaves `5`. Any
    post-loop read is off by one (latent today — no corpus test reads
    a seq-loop var afterwards; `002` proved the brace path needed the
    hidden counter). Fix: same hidden-counter form as item 7b, or
    prove no post-loop read. Needs care: py-sh-go golden outputs pin
    the direct form today.

## Round 2 — bash-corpus survey (arrays, case, functions, heredocs, traps)

Second survey pass over different territory (`009_arrays`,
`029_arrays_associative`, `032_control_flow_function`, `057_case`,
`062_03_complex_heredocs`, `062_09_complex_function`,
`062_14_complex_array_operations`, `064_23_traps`). Same method:
generate, read, list. Items continue the numbering (19+). Status:
all PROPOSED except where noted.

### H. Dead code (continued)

19. **Dead comma-statement `(_sh_rc = 0, 1);`** — **DONE**, with a
    soundness fix found during implementation: the drop lives inside
    `strip_dead_rc` (global rc-dead gate), NOT in `drop_const_stmts`
    (which runs regardless). First attempt dropped unconditionally
    and miscompiled `false; echo $?` (C printed `0`, bash `1`) —
    caught by a targeted probe before committing. `009`'s two
    instances correctly survive (`set -euo pipefail` keeps `$?`
    live program-wide).
   **DONE** (with a soundness fix found during implementation: dropping must live under `strip_dead_rc`'s global rc-dead gate, never in `drop_const_stmts` — first attempt miscompiled `false; echo $?` (C `0`, bash `1`), caught by probe. `009`'s two instances correctly survive, `set -e` keeps `$?` live).
20. **Empty `else { /* no default */ }`** (`057` and others): the
    case renderer emits an else with only a comment. Drop empty
    else branches (same family as item 10; the comment carries no
    semantics). S.
   **DONE**: unconditional `else { /* no default */ }` dropped (bash no-match does nothing).
21. **`(exit(1), 0);`** (`057`): comma-expr whose first element is a
    noreturn call — the `, 0` is dead. Peephole: `(noreturn-call,
    const)` → `noreturn-call;` (generalizes: any trailing constant
    after a noreturn call). S.

### I. Repeated evaluation (item-13 family)
   **DONE**: statement-position `(exit(X), 0);` → `exit(X);` (balanced + exit-first checks; nested/value forms kept).
22. **Case-subject re-evaluation** (`057`):
    `((1 < argc && argv[1]) ? argv[1] : "")` is re-emitted per
    `case` branch (4× for 4 branches). Hoist the subject to a temp
    once (same single-evaluation argument as item 13; pure reads
    only). S/M.
   **DONE**: call-free non-trivial discriminants hoist to `const char *_cdN` (bash freezes the word once — strictly more correct than per-branch re-eval, no body analysis needed). Call-containing forms keep inline behavior.
23. **argv-guard repetition in param defaults** (`062_09`):
    `${2:-default}` renders the `((2 < _sh_argc && _sh_argv[2]) ?
    ...)` guard 5×. Item 13's hoist fires only on call-containing
    expressions; extend it to non-trivial pure exprs (indexing and
    ternaries can't have side effects mid-expression, so single-eval
    hoisting is always safe — the only cost is one temp + statement
    vs N redundant reads). M.
   **SUPERSEDED by 24**: extending the hoist to pure exprs saves only nanosecond reads while risking code bloat; the visible wart (guards) is fixed at binding sites instead.
24. **Nonnull proofs for argv-guard assigns** (`062_09`):
    `param1 = ((1 < _sh_argc && ...) ? ...)` is non-NULL by
    construction, yet every later use is guarded
    (`(param1 ? param1 : "")`). Extend the item-12 nonnull proof to
    argv-guard RHS shapes (bounded index ⇒ non-NULL element). S.

### J. Constant folding (gaps)
   **DONE** (gated): null-safe shapes (`argv[N]`-guard ternary with matching indices, `(X ? X : "")`) prove the bound var at `Declare`-init (+ hoist-temp registration for chain coherence). Keeps the `fn_written` gate like all sibling inserts — function-body binds stay conservative.
25. **Fold `atoll` of constants** (`062_14` and others):
    `(int)atoll("")` (always 0) and `atoll("10")` (always 10)
    survive into output. Fold `atoll` over string literals at render
    time (empty → 0; decimal → value; non-numeric → keep `atoll`,
    preserving the coerce-to-0 semantics). S.

### K. Lowering choices
   **DONE**: `fold_atoll_consts` post-pass (`atoll("")` → `0`, `atoll("10")` → `10`; only Rust-parseable literals fold, overflow/hex/junk keep the call).
26. **Static heredocs go through shell-out** (`062_03`):
    `cat <<'EOF'` (quoted ⇒ no expansion, fully static text) renders
    as `_sh_site_0()` (fork+exec of `cat`) instead of one `fputs`
    with embedded newlines. Detect fully-static heredoc bodies and
    emit directly. M.
   **DONE**: bare `cat` + single static quoted heredoc → one `fputs` (unquoted/tab forms keep the site).
27. **Literal array elements `strdup`'d at runtime** (`009`,
    `062_14`): `arr=(one two three)` emits 3×
    `_sh_xstrdup((char*)("..."))` plus end-of-scope frees. A static
    initializer (`static char *arr[] = {...}; arr_len = 3;`) removes
    both — but frees must then skip literal slots (ownership
    tracking per index, or copy-on-first-write). Bigger + riskier;
    keep the strdup until the ownership proof exists. M (deferred
    shape noted).

28. **Join-then-slice** (`062_14`): `${arr[@]:off:len}`-shaped flows
    join ALL elements (`_sh_join_arr`) then slice the text — O(n)
    twice. Slice the index range first, join only the window. M.
   **DONE**: whole-array slice (`${arr[@]}` with absent/empty/0 off and absent/empty len) returns the join directly; explicit/negative bounds keep the slice.
29. **Argv-swap dance for liftable shell functions** (`062_09`):
    `complex_function` reads only `$1..$3`, yet every call builds
    `_sh_av0[]`, swaps `_sh_argv/_sh_argc`, calls void, restores
    (`(complex_function(), _sh_argv = _sh_sv1, ...)`). Extend the
    native-calling-convention lift to sh-source functions whose
    bodies read only `$1..$9` (the analysis exists for py-sh-go
    fns). L; touches calling convention shared with the JS worker
    — coordinate.

## Round 3 — survey (param expansion, strings, calls, loop warts)

Third pass over new territory (`007_cat_EOF`, `010_substring_loop`,
`013_parameter_expansion`, `024_parameter_expansion_case`,
`027_parameter_expansion_defaults`, `029_arrays_associative`,
`032_control_flow_function`, `041_process_substitution_mapfile`,
`047_for_arithematic`, `049_local`, `054_fibonacci`,
`058_advanced_bash_idioms`). Same method: generate, read, list.
Items continue the numbering (30+). Status: all PROPOSED except
where noted. (`054_fibonacci` is the near-optimal reference:
`uint8_t i`, hidden counter, native `a`/`b`/`temp` arith, direct
`printf("%lld ")` — the remaining nits there are file-scope `i`
(item 17) and parens noise.)

Measured (12 files): 19 dead vbuf-`.p` guards (`(_vN.p) ?
(char*)(_vN.p) : ""`); 4+ surviving `atoll("<digit>")` (an item-25
follow-up bug — see 32); 24 `(maybe ? maybe : "")` repetitions in
the 3-line `027` (see 33/34); 5 `_sh_call_fn` sites in `058` each
with a dead result guard (see 31).

### L. Dead guards (item-12/24 family, continued)

30. **Null-guard on vbuf temps** (`013`, `024`): every
    `${name^^}`/`${s%pat}`/etc. expansion ends
    `printf("%s\n", ((char*)(_vN.p) ? (char*)(_vN.p) : ""))`.
    `_vN.p` comes from `_sh_vgrow`, which NEVER returns NULL (P1
    fail-stop: OOM exits 127 inside vgrow). The guard is dead on
    every vbuf temp — drop it at the use (or mark vbuf-`.p` temps
    nonnull at creation, letting the existing guard-drop consume
    them). S.
31. **Null-guard on `_sh_call_fn` results** (`032`, `058`):
    `((char*)(_pd_...) ? ... : "")` after every captured call.
    `_sh_call_fn` returns `vb->p` and `_sh_capture_fn` vgrows first
    (then fail-stops), so the pointer is non-NULL on every return
    path (`tmpfile` failure returns the already-grown buffer).
    Same treatment as 30. S.
32. **`fold_atoll_consts` stops at the first non-foldable** (item-25
    follow-up — BUG, not just missed opt): the post-pass `break`s
    out of the line scan when the FIRST `atoll(` doesn't fold, so
    `if ((atoll((getenv(...))) > atoll("3")))` keeps `atoll("3")`
    (`058` keeps `atoll("0"/"1"/"3"/"5")`). Fix: on a
    non-foldable match, advance past its close paren and keep
    scanning the line (cursor-based loop instead of break). S +
    unit test (foldable-after-unfoldable on one line).
   **DONE**: cursor-based scan (`pos`; unfoldable matches skip to
    `close + 1`, folded ones resume after the digits — both advance
    strictly, no rescan loop). `058`: 0 surviving `atoll("<n>")`.
    Unit test `bashc_opt_item32_atoll_fold_skips_past_unfoldable`
    (fold-after-unfoldable, empty→0, unbalanced tail fail-closed).
33. **`${x:-d}`/`${x:=d}`/`${x:?d}` re-emit test+value** (`027`):
    `${maybe:-default}` renders the `maybe`-nonempty test AND the
    `maybe` value twice each (~6 guard copies/line); `:=` computes
    `(test, value)` twice (once for the assign, once for the use).
    Bind the tested value once (`const char *_d = ...` elvis-style
    temp for pure reads — item 13/22 family; the test is pure so
    single-eval is exact). Quarters the 027 lines. M.
34. **Literal-init nonnull proof** (`027`): `maybe = ""` (a
    literal — trivially non-NULL) yet every later read guards
    `(maybe ? maybe : "")`. Extend the item-24 proof to literal
    RHS shapes (`""`/any literal ⇒ non-NULL at the bind). Kills
    most of the 24 repetitions in 027 outright; the rest fall to
    33. S.

### M. Round-trip / materialization warts

35. **Num-temp materialized only to be `atoll`'d back** (`010`):
    each iteration vgrow+snprintfs `i` into `_v1`, whose SOLE use is
    `atoll(_v1.p)` as the `${s:off:1}` offset. Pass `atoll(i)`
    directly (recognize `atoll(vbuf-of-X)` → `atoll(X)` where the
    vbuf holds a prior numeric render), then item 9's sweep drops
    the orphaned pair. S/M.
36. **Comma-head rc-store strip** (`041`):
    `(_sh_rc = 0, printf("%s ", _v0.p))` — item 19 drops comma
    statements only when the TAIL is const; here the tail is
    effectful but the HEAD store is still dead under the same
    global rc-dead gate. Generalize: strip dead `_sh_rc = N`
    elements from comma heads regardless of tail shape. S.
37. **Constant conditions** (`041` mapfile `if (1)` from
    `striptail=true`): peephole `if (1) B` → `B`, `if (0) B` →
    drop (same family as item 10's empty-block drop). S.

### N. Bigger shapes (sharpened re-proposals)

38. **Static array init via runtime append loop** (`058`:
    `numbers=(1 2 3 4 5)` → 10 lines of `_ai0`/xstrdup/`len`
    dance). Item 27's shape, sharpened: append-only literal arrays
    (never element-written — the proof item 27 asked for) emit
    `static const char *tbl[] + len`, no per-slot strdup/frees.
    M (ownership proof still required — see 27).
39. **In-bounds array-read guards** (`058`):
    `num = numbers[_ai_numbers]` then `(num ? num : "")` at every
    use, though append-only slots are xstrdup'd (non-NULL) and the
    index is bounded by `numbers_len`. Gate: array never
    unset/element-cleared + index provably `< len` (the loop-index
    idiom). M (item-12/24 family; unsound for sparse arrays —
    the gate must exclude them).
40. **Single-use `$?` temp fuse** (`007`):
    `long long _q0 = _sh_rc; printf("exit: %d\n", _q0)` → inline
    `_sh_rc` as the printf arg (evaluation precedes the trailing
    `, _sh_rc = 0` store — same order, same value). S micro.
41. **Hashed direct-call temp names** (`058`:
    `_pd_x99a1_x11e8` vs cmdsubst's readable `_greet_World`).
    Unify the direct-call path on function-arg naming via
    `naming.rs` (MEANINGFUL_NAMES family). S/M readability (origin
    of the `_pd_`+hash scheme needs locating — likely the sh-source
    direct-call lowering, not the cmdsubst path).
42. **Direct sh-function calls render as capture+print** (`058`:
    `process_data "string" "Hello"` → `_sh_call_fn` + printf
    instead of a direct void call). Item-29 family: needs the
    native-call lift for sh-source fns first; the capture layer
    (tmpfile+dup2 per call!) then disappears with it. L; DEFERRED
    behind 29.
43. **Save/restore (`_sv_*`) around non-touching calls** (`058`:
    `value` saved/restored around every `process_data` call).
    Needs callee-write analysis (worker's domain). M (deferred
    shape noted).

## Round 4 — survey (misc, loops, backup, process-subst, factorize)

Fourth pass over new territory (`006_misc`, `008_simple_backup`,
`012_process_substitution`, `030_control_flow_if`,
`031_control_flow_loops`, `043_home`, `048_subprocess`,
`055_factorize`, `056_send_args`, `059_issue3`, `060_issue5`,
`061_test_local_names_preserved`). Items continue the numbering
(44+). Status: all PROPOSED except where noted. (`056`'s
`const char result[3]` printing guard-free and `059`'s argv-less
`int main(int argc)` are already-optimal reference points —
buffer-homing and unused-param elision working.)

Measured: `getenv("HOME")` 12× in `043`'s 11-line main (see 44);
the identical `$HOME/Documents` snprintf+vbuf pair built twice
(see 45); 4 more single-use `_qN = _sh_rc` temps (item-40 family:
`006`, `030`, `048`, `060`).

### O. Pure-call repetition (item-13/23 family, continued)

44. **Repeated side-effect-free calls** (`043`):
    `(getenv("HOME") ? getenv("HOME") : "")` twice PER
    comparison, 12 calls total — item 13 hoists calls only in
    default-arm position, and item 23 (extend the hoist to pure
    exprs) was SUPERSEDED before this shape was measured. Re-scope
    narrowly: bind-once hoist for repeated calls from a
    known-pure allowlist (`getenv` — same process env, no
    intervening `export`/`unset` of that name). The guard shape
    itself then falls to item 34's proof if the temp is
    literal-initialized... no — getenv can return NULL, so the
    temp keeps ONE guard at the bind, and all 12 use sites go
    bare. M.
45. **Duplicate vbuf materialization** (`043`): `$HOME/Documents`
    is snprintf-built into `_v0` (line 23) and again byte-identical
    into `_v2` (line 27). CSE across statements: reuse the first
    temp when the renderer inputs are textually identical and no
    intervening write to the temp exists (vbuf temps are
    single-producer here — the second `_sh_vgrow`+`snprintf` is
    pure waste). M.

### P. Branch/comma shape peepholes (item-10/19/20 family)

46. **Empty `else { }`** (`059`: `} else { }`): item 20 dropped
    the case-only empty else; the general `if/else` empty else
    survives. Drop empty else branches everywhere (same gate as
    20 — the branch carries no semantics). S.
47. **`else` containing only a dead rc store** (`055`:
    `} else { _sh_rc = 0; }` ×2): drop when `_sh_rc` is dead at
    that point (item-11 liveness, same global gate as 19/36);
    keep when live. S (gated).
48. **`i = (i + 1)` → `i++`** (`031`): numeric loop counters
    incremented via full arith-assign render though the
    cstyleFor path already emits `i++`. Peephole at arith-assign
    render: `v = (v + 1)` / `v = (v - 1)` with Int-homed `v` →
    `v++` / `v--`. Gate STRICTLY on Int-homed: on a `char*`,
    `j++` would be pointer arithmetic (miscompile). S micro.
49. **Trailing `, 1` in statement-position `||`/`&&` tails**
    (`012`: `(_sh_site_9() || (fputs(...), _sh_rc = 0, 1))`): the
    `or`-lowering appends `, 1` to force truthiness, meaningless
    when the statement value is discarded AND short-circuiting is
    unaffected (RHS shape never influences LHS evaluation).
    Drop the trailing `, 1` at statement position when the
    preceding element is int-typed (keep `_sh_rc = 0`, keep
    everything in value position — a masked failure there would
    be a miscompile). S micro, narrow gate.

### Q. Correctness-adjacent (leak, not just bytes)

50. **`getcwd(0, 0)` leak in `chdir` lowering** (`008`):
    `setenv("PWD", getcwd(0, 0), 1)` — the malloc'd buffer is
    copied by setenv and never freed (valgrind-definite leak,
    per `cd`). Bind to a temp and free after the setenv. S
    correctness (also kills the per-`cd` leak in long-running
    transpiled scripts).

### Already optimal (verified, no item)

- Borrowed argv reads (`a = _sh_argv[_ai_a]`, no strdup, no free of
  a non-owned pointer) and the maintained `xs_max/min/sum`
  aggregates: exactly right, including the free discipline.
- `_sh_assoc_get` never returns NULL (miss → `""`), so the bare
  `(char*)` casts on assoc reads are correct — no guard missing.
- The `freopen(/dev/null)` + unbuffered-stdout prologue fires only
  for programs with real child shells (fd-1 sharing/order) —
  native-only programs stay buffered. Correct as-is.
- `printf("Arg: %s\n", ...)` for interpolated echo with a single
  conversion: the native-printf path.
- `($#)` → `(_sh_argc - 1)` and `int main(int argc, char **argv)`
  plumbing: tight.
- Trap handling (`064_23`) shells out for dynamic trap bodies —
  correct (fork is the semantics); not an opt target.

## Suggested order

Correctness Per-item risk is low (each has a clear gate signal:
stdout-identical + `-Wall`-clean + valgrind-clean), but sequence
matters: 6 unlocks 7–8 and halves the atoll count; 3 unlocks the
localization in 17 and most of the fork tax in B; 1–2 are
mechanical prelude wins with zero semantic surface. Proposed:
1, 2 → 6, 7 → 3, 4 → 9, 10, 11 → 12, 13, 14 → 5, 15, 16 → 17.

Round 3 sequencing: 32 is a bug fix in shipped code (do first);
30+31 ride the existing guard-drop (cheap, same tests as 12/24);
34 unlocks much of 33's win (prove literals before binding
temps); 35–37, 40 are peepholes in dependency order (36 extends
19's gate, 37 extends 10's); 38–39 need ownership/bound proofs
(38 answers 27's open question); 41 is readability-only (any
time); 42–43 chain behind 29 and callee-write analysis.

Round 4 sequencing: 46–47 extend 20's gate (cheap, same tests);
48 needs the Int-homing proof first (wrong-gate risk is a
miscompile, not just missed bytes — test the `char*` negative);
44–45 are the only M items (hoist/CSE machinery); 50 is
correctness (valgrind-tainted — do alongside any touching of the
`chdir` lowering); 49 is narrowest-last (value-position masking
risk).
