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
DEFERRED/SKIPPED (reason given). Implemented this round: 1, 4, 7, 9,
10, 12, 13, 14.

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
   **DONE**: `seq_of_ints` — const brace-int-seq folds via the existing `seq_iter_range` path (all three consumers: native loop, Int typing, range seeding). Strictly canonical decimals only (`01`/`+5` fall back); step≠0 required; descending/letters fall back (some, e.g. `{5..1}`/`{a..c}`, were already dropped pre-change — pre-existing gaps, untouched). Int-homed brace loops run on a HIDDEN counter + per-iteration assign (not directly on the var): a direct `for (i = 1; i <= 5; i++)` leaves `i==6` where bash leaves LAST (`i==5`) — `002`'s post-loop `while [ $i -lt 10 ]` caught exactly this (missing first Counter line). Range (`$(seq)`/py-range) iters keep the direct-var form (pre-existing behavior); their latent end-value gap is item 18 below.
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

## Suggested order

Correctness Per-item risk is low (each has a clear gate signal:
stdout-identical + `-Wall`-clean + valgrind-clean), but sequence
matters: 6 unlocks 7–8 and halves the atoll count; 3 unlocks the
localization in 17 and most of the fork tax in B; 1–2 are
mechanical prelude wins with zero semantic surface. Proposed:
1, 2 → 6, 7 → 3, 4 → 9, 10, 11 → 12, 13, 14 → 5, 15, 16 → 17.
