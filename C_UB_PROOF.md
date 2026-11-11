# Can Isabelle prove the C backend produces no UB?

Status: **P1, P2 and P3 mechanized and green; §2a's `ov`-flag obligation
mechanized in Verus and in Isabelle (§13); the Eq/Ne render decision and
the decimal renderers mechanized in Verus, the decimal round trip also in
Isabelle (§14); the width/buffer/arith operator/promotion/string-helper/
capture/decl-coverage/escaper/write-arm/growth-helper/sparse-array
emission decisions mechanized in Verus (§15–§29); P4 blocked on the absent
`C-Parser`/`AutoCorres` toolchain** (§12). Written 2026-10-22 against
`sh2perl/backends/c` @ `5b1524085` (`src/c_backend.rs`, 50,747 lines);
§13 added 2026-10-27, §14 added 2026-10-28.

`verif/` holds four theories (P1, P2, P3-capacity, P3-buffer) totalling 40
lemmas/theorems. A clean-room `isabelle build -d verif -b Sh2` (Isabelle
2025-2) is green with no `sorry` and no `oops`. `harness/c_gate_ubsan.sh`
is the measurement instrument behind §7.

## Short answer

**Partly — for the two layers where a theorem can actually be stated**
(width/range narrowing, fixed-buffer bounds), and **not at all** for
"the C backend produces no UB" as an end-to-end claim, because the property
depends on the `_sh_*` runtime, the frontend, and the stub fallback, none of
which is (or should be first be) in scope.

The sequencing matters more than the proof: every invariant the backend
relies on is currently an *informal comment*, and at least one of them
("a miscounted proof can only exit 127 loudly") is false for the width case.
Measure with sanitizers first; mechanize only what survives.

## 1. What "no UB" has to quantify over

Three independent layers, each with a different failure mode:

| Layer | Where | Today's status | Failure mode |
|---|---|---|---|
| **Render discipline** | `c_backend.rs` (50.7k lines, 12 `TODO(unsupported)`) | generated C respects its own invariants by construction | silent wrong value / UB |
| **Proving passes** | `var_types` + `analyze_var_ranges`/`range_width_name`, `var_lengths`, `array_caps` | conservative heuristics, 157 lines matching `conservative|proof|sound`, **none mechanized** | miscounted width **wraps silently**; miscounted cap is guarded |
| **Runtime + frontend** | `_sh_*` helpers (malloc/free, pipe/dup2/waitpid), parser, shIR lifts | unproved | segfault, hang, UB |

`docs/WHY_C_IS_HARD.md` says it plainly: *"A JS lowering bug is a wrong
value. A C lowering bug is a segfault, hang, or UB — hence sanitizer passes,
capacity guards, gate timeouts. 'Runs and prints' isn't evidence of
soundness."* The backend's own header makes the same admission for buffers:
the `assert(strlen(v) <= N)` is **debug-only**; under `NDEBUG` `strncpy`
truncates.

Quote of record (`c_backend.rs:349-352`): *"Decl and every fixed guard
consult it, so they always agree (never UB; a miscounted proof can only
exit-127 loudly)."* True for `array_caps` (guarded). **Not** true for widths:
an underestimated range produces `int32_t` arithmetic that wraps where
`long long` would not, with no guard and no exit code.

## 2. What Isabelle is genuinely good for here

### 2a. Fixed-width arithmetic (the strongest case)

Obligation, per narrowed variable `v` with conservative range `[lo, hi]`:

```
∀ s. v ∈ [lo,hi]  ⟹  eval_int32(e, s) = eval_i64(e, s) = eval_shell_intmax(e, s)
```

`HOL-Library` / `Word_Lib` supply wrap-around semirings, so the per-operator
lemmas (`+`, `-`, `*`, `<<`, `/`, `%`, negation, the `U32`/`I32`/`I64`
promotion rules) are library work, not new mathematics. The interesting
obligations are the backend's own fast arms, which are *not* trivially in
range:

- the `__builtin_add_overflow` / `__builtin_sub_overflow` /
  `__builtin_mul_overflow` checked tier (`c_backend.rs:7329-7429`) — the
  theorem is "the `ov` flag is set exactly when the exact result leaves
  `long long`", i.e. the tier's escape hatch to GMP is only taken when
  needed *and* always taken when needed;
- `_sh_isint31` (says `|v| ≤ 2^31` so `atoll` is safe and bounded `+ - *`
  cannot overflow i64) — a predicate that must be proven to imply what its
  callers assume;
- the `__int128`-to-decimal helper (a *small-int sum past i64*) and
  `need_isqrt` (exact integer sqrt for every `long long`);
- the `f32_narrow` / `i32_provable` shared transforms, which decide narrow
  types *upstream* of the C renderer and so are the real producers of these
  obligations (PLAN §11 marketplace: fixing them is a shared-core change,
  not a backend one).

Shape: formalize the interval domain once (it is small — bottom, `[lo,hi]`,
widening), generate obligations per narrowed expression from the renderer's
own analysis output, discharge by `simp` + `linarith` with a handful of
hand-proved operator lemmas. Realistically a few thousand lines of Isabelle
plus a generator.

### 2b. Buffer bounds

Obligation: `strlen(s) ≤ N` at every write into a `char v[N+1]`, from
`var_lengths`, plus "every write site is guarded or truncating". The write
sites are `snprintf`, the `(_sh_cmd[l] = c; _sh_cmd[l+1] = 0)` style appends
(`c_backend.rs:8762,8971`), and the `static char _sN[32]` num-temp buffers
whose `snprintf` bound is a format-width claim, not a length claim.

`array_caps` had the same treatment, and as of 2026-11-09 the part that
matters is mechanized: `ARR_CAP = 1024` is a CEILING, not the sizing — an
array whose census `need` reaches it is routed to the growable vec instead of
being declared as a table — and `proofs/verus/c_arr_cap.rs` proves that a
fixed table is at least as large as the literal bulk the renderer writes into
it, that anything at or above the ceiling is never a fixed table, and that the
write guard admits exactly the in-bounds writes. That last obligation caught a
real defect: the `"$@"` spread guard compared the write count against `ARR_CAP`
rather than the DECLARED cap (`c_backend.rs` `emit_set_array`), so a
proof-sized `a[3]` would have admitted four stores into it; the guard now uses
`acap`, the same number the declaration uses.

The assumption is observable rather than assumed: a `debug_assert!` at the
reset emitter refuses to emit a literal bulk larger than the declared cap, and
`harness/c-arr-cap-scan.sh` renders the example set and reports the numbers —
555 of 563 examples rendered, 72 fixed tables, largest bulk 5, largest
capacity below the ceiling 10, **0** tables whose bulk exceeds their cap. The
41 tables AT the ceiling are the deliberate unproven backstop (assoc k/v
stores, fn-return arrays) whose writes carry the exit-127 guard, i.e. the
"or the guard engages" half of the claim rather than a proved size.

### 2c. The renderer itself (optional, expensive)

Deep-embed the emitted C (`C-Parser` / AutoCorres) and prove
`render : ShIR → C_ast` structurally. Worth it only after 2a/2b, and only
with a verified compiler downstream — otherwise a theorem about the *text*
buys as much as your trust in gcc's optimiser (which is exactly where the
width-wrapping bugs would surface).

## 3. What Isabelle cannot do here

- **`_sh_*` runtime.** Measured 309 `_sh_*` calls in one corpus file
  (`harness/backend_runtime_metric.sh` header). malloc/free discipline,
  pipe/dup2/waitpid bookkeeping, fd restore, SIGPIPE. This is where the
  actual UB lives today; it is hand-written C with no spec.
- **The frontend.** Parser + shIR lifts are unproved. A theorem about a
  wrong shIR proves nothing about the shell program.
- **Stubs.** Proving the 12 `TODO(unsupported)` paths UB-free proves a
  trivially true thing about a program that doesn't do what bash does.
- **Shell semantics itself.** For programs using `eval`, `trap`, `$RANDOM`,
  signals or fork, "no UB" is only relative to a semantics you must first
  define — and PLAN's whole direction (v3+) is that bash's fork/exec is
  *copy semantics*, which is a modelling job, not a proof job.

## 4. Before any proof: measure (this is the step that pays)

The C gate already does more static checking than most transpilers —
`harness/c_gate_fast.sh:49-58` runs `cc` **and** `clang --analyze` per file,
then runs and diffs vs bash. What it does **not** do:

```
rg -n 'sanitiz|fsanitize' sh2perl/backends/c/harness/*.sh setup_backends.sh
→ (no matches)
```

No UBSan, no ASan. `docs/POSSIBLE_TESTING_IMPROVEMENTS.md` lists only
"estree-first differential fuzzing" as planned. So the informal invariants
have never been tested for violation on the corpus — and the width ones
*wrap silently*, so a stdout diff against bash will not catch them unless the
wrapped value reaches output.

### Step 0 (do this first): a `-fsanitize` gate arm

- Add `harness/c_gate_ubsan.sh` (or a `--ubsan` arm to `c_gate_fast.sh`)
  compiling with
  `cc -O1 -g -fsanitize=undefined,address -fno-sanitize-recover=all`.
- Run over the whole corpus, compare **stdout+exit code** against a normal
  build of the same render (not against bash — a UB abort is not an
  equivalence failure; it is a separate verdict class `UBSAN`).
- Two specific hypotheses to falsify, both stated as fact in comments:
  1. `array_caps`: "a miscounted proof can only exit-127 loudly" — any
     out-of-bounds write at `UBSAN` proves the guard is missing somewhere.
  2. width narrowing: any UBSan `signed integer overflow` /
     `implicit conversion` report in a narrowed (`int8..int64`) variable is
     a real silent-wrap bug today.
- Known interaction: ASan and the runtime's own `fork`/`exec`/`dup2` paths
  need `ASAN_OPTIONS=detect_leaks=0` and may need the fork paths excluded
  (`c_backend.rs` spawns helpers); start with UBSan only if ASan is noisy.
- Constraint from AGENTS.md: the gate must run under the box's guards —
  bound captures with `harness/cap-capture.pl`, wrap in
  `harness/kill-session.sh`, and don't let an infinite-loop lowering pin a
  core (the `096_head_procsub.sh` orphan class).

**Exit criterion for Step 0:** a per-file `UBSAN-CLEAN | UBSAN-FAIL <kind> |
STUB | CC-FAIL` tally, committed as `gate-reports/c-ubsan-<date>.tsv`, and a
sorted histogram of violation kinds. That histogram decides whether 2a or
2b is worth mechanizing and in what order.

### Step 0.5: shrink the width surface

If Step 0 shows the width class is live, the cheaper fixes usually beat the
proof: the `i32_provable` / `f32_narrow` transforms are the producers, and a
transitively-shared fix lands in every backend. Prefer "prove it in the
transform (and add a unit test per operator)" over "prove it in Isabelle"
until the surface stops moving — the same reasoning AGENTS.md gives for the
rust dogfood scoreboard: judge by the blocker class removed, not the total.

## 5. Staged proof plan (only what survives Step 0)

| Stage | Theorem | Files | Effort |
|---|---|---|---|
| **P1** interval domain + narrowing | store condition: a value stored at width `w` lies in `w`'s interval | `verif/P1_Narrowing.thy` | **DONE** — see §10 |
| **P2** checked tier | overflow flag set iff exact result ∉ i64 | `c_backend.rs:7303-7429` templates | **DONE** — `verif/P2_Checked.thy`, see §8 |
| **P3** length/array abstraction | `strlen ≤ N` at every write; `array_caps` sizing sound | `analyze_string_lengths`, `array_caps` (`:2732-2790`) | **DONE** — `verif/P3_Capacity.thy` + `verif/P3_Buffer.thy`, see §9 |
| **P4** renderer deep embedding | `render : ShIR → C_ast` respect the invariants | `c_backend.rs` (subset) | **blocked** — no `C-Parser`/`AutoCorres` in this distribution, see §11 |
| — | **never** claimed | `_sh_*` runtime, frontend, stubs | out of scope |

Verification of record for each stage follows the workspace rule: build in
a distinct `CARGO_TARGET_DIR`, and quote the *gate* numbers, not the proof
script's own output.

## 6. Honest summary for the operator

- **Yes**, Isabelle can prove the width-narrowing and buffer-bound
  obligations, and those are the two classes whose failure is silent.
- **No**, it cannot prove "the C backend does not produce UB", because that
  quantifies over a hand-written C runtime and an unproven frontend.
- **Order of work:** sanitizer gate → falsify-or-confirm the informal
  invariants → fix the transforms if cheap → mechanize the surviving
  invariants. Doing Isabelle first risks mechanizing a claim the code
  already violates on line one of the corpus.

## 7. Step 0 result (measured 2026-10-22)

`harness/c_gate_ubsan.sh` is the instrument. It fixes the three defects that
made the existing `c_gate_main.sh --sanitize` arm unmeasurable, and states
its own validity as **positive controls**: four deliberately-UB programs are
rendered by the C backend itself, compiled with the sanitizer, and must fire
(`signed integer overflow`, `index out of bounds`, `load of null pointer`,
`division by zero`). If any control is silent the script exits 2 and writes
no tally — a clean sweep from a probe that cannot fire is not evidence.

```
$ harness/c_gate_ubsan.sh            # gcc 13.3 (this box has no clang)
control overflow: FIRES
control oob:      FIRES
control nullderef: FIRES
control divzero:  FIRES
== verdict classes ==
    652 CLEAN
      1 STUB          parse-redirect-in-case-pattern.sh (4 sh2 callouts)
      1 CC-FAIL       063_12_complex_eval.sh (`result` undeclared)
654 files
== UBSan/ASan kinds ==   (none)
```

The per-file tally is written to `gate-reports/c-ubsan-<stamp>.tsv` and is
**machine state, not shipped**: `.gitignore:9` excludes the whole
`gate-reports/` directory, so the numbers are quoted here rather than
committed. `--warn` adds the store-side check (`TRUNC` verdict): 643 CLEAN,
9 TRUNC, 1 STUB, 1 CC-FAIL — the same 9 files as below.

**Reading of that result — and the trap in it.** A 652/652 clean sweep
retires one hypothesis and *fails to test* the other:

- **No UBSan/ASan finding anywhere** on the corpus, with the probe proven
  live. The guards the backend documents are, on this corpus, actually
  present: no OOB index into `array_caps`/`ARR_CAP`, no null load, no div0,
  no leaked-pointer use.
- **The width class is NOT measurable by sanitizers.** Narrowing in
  practice is `uint8_t` (39 decls) + `uint16_t` (8) across 36 of 654 files;
  **no signed narrow type (`int8_t`/`int16_t`/`int32_t`) occurs anywhere in
  the corpus** (word-boundary recount over all 654 renders).
  `range_width_name` tests `u8` *before* `i8`, so every non-negative range
  yields the unsigned type and the signed arms are effectively dead.
  **Unsigned** conversion is defined behaviour, so UBSan cannot fire, and a
  size-1 global store has no redzone for ASan to check. Measured with a
  control: `uint8_t i; i = 300;` prints 44 under `address,undefined` with no
  diagnostic.
- But gcc's own analysis finds **10 truncating stores in 9 corpus files**:

  ```
  gcc -O1 -Wextra -Wconversion over all 654 renders
    warning: conversion from 'long long int' to 'uint8_t' may change value   (9)
    warning: conversion from 'long long int' to 'uint16_t' may change value  (1)
  001_simple, 054_fibonacci, or-continue, eq-string-num-var, parse-brace-close,
  tsv-string-accumulate-loop, bc-native-capture, 062_01, 062_04
  ```

  Two shapes, both from the backend's own seeders (`seed_range_loop_vars`,
  `seed_isqrt_bounds`) rather than from the shared transforms:
  1. `for i in 1 2 3 4 5` seeds `i:[1,5] → uint8_t`, then the loop body does
     `i = _for_i_0[_i_i]` — a `long long` table element stored into a
     `uint8_t`. Latent, not a manifest bug (the seed is right for the loop),
     but nothing checks the *store's* range against the declared width.
  2. `result=$(( (2 + 3) * (4 - 1) + (5 ** 2) ))` emits `uint8_t result` and
     `result = 15 + _sh_pow(5,2)`. This one is **not latent**: the store is
     safe only because `_sh_pow(5,2) = 25` happens to fit an 8-bit unsigned;
     the compiler cannot see that, and with a larger literal the same shape
     stores an unchecked wrapping result.

  The mechanism behind (1) is worth naming for P1: in
  `walk_widths_expr`, an arith whose range is **unknown** widens its
  participants to `I64` (`arith_range_local` returns `None` → `arith_op_wide`
  false → force I64), but an arith whose range is **known** only *widens*
  them (`widen`), never refines their declared width. So a variable declared
  from its own seed keeps that width even when a use proves something else;
  only the unknown case is conservative.

**Measurement discipline (three traps hit, all recorded because each one
produced a confident wrong answer).** The signed/unsigned question was
measured five times before it was right:

1. `grep -oE 'int8_t'` counts the `int8_t` inside `uint8_t` — a word-boundary
   pattern is required (same family as the `grep -qF` trap in AGENTS.md);
2. `otranspilerl-cli` exits non-zero with `cannot locate the workspace root
   (set OTRANSPILER_ROOT)` when run from an ad-hoc directory, so an
   unpinned sweep renders **empty** input and reports "clean" for every
   file;
3. `n=$(… | grep -c …)` loses a pipeline's output on some of these
   renderers; counting must be `grep … | wc -l` over a stream, not
   `$(grep -c)`.

The final sweep streams every file's render into `grep -E '\bint8_t\b'`
(`verif/` is not needed for it: it is the one-liner in §7's revision note)
and is validated by an in-corpus positive control — a temporary example
containing `y=$(( 2 - x ))` must, and does, print a signed site. With that
control passing, the corpus count is **0 of 654**.

**So the Step-0 verdict is: the array-cap/buffer invariants hold on this
corpus; the width invariant is live but *unproven and unobservable by
sanitizers*.** That is a stronger reason to mechanize P1 than "sanitizers are
silent" would have been — silence here is an instrument limitation, not a
result. P1's generated obligations must therefore assert the store-side
condition (`value ∈ declared width`) explicitly, not just the variable's own
range, which is the gap class 1 above sits in.

**Two harness defects found and fixed on the way** (both would have produced
false `SAN-DIFF` verdicts on every run):
- the sandbox was one level deep, so `046_cd..sh` (body: `cd ..`) escaped it
  and listed the harness's own capture files → now two levels deep;
- the two builds ran under different paths, so a program printing `$0`
  (`057_case.sh`: `Usage: $0 …`) disagreed with itself → now one path,
  swapped between runs.

## 8. P2 mechanized (2026-10-22)

`verif/P2_Checked.thy` builds under Isabelle 2025-2 with no `sorry`
(clean-room `isabelle build -d verif -b Sh2`). It states the tier's
contract over an expression tree (`Lit`/`Add`/`Sub`/`Mul` + `eval`), which
is the shape `tiered_i64_expr` walks:

| lemma | content |
|---|---|
| `add/sub/mul_overflow_iff`, `…2` | out-of-range test = ¬ in-range test, per operator |
| `flag_reports_overflow` | ¬fits = out-of-range, for an `Add` node |
| `fast_arm_is_exact_when_flag_clear` | flag clear ⟹ the value fits |
| `subtree_overflow_forces_gmp` | overflow anywhere forces the GMP arm (the direction a *missing* check would violate) |
| `or_flag_mono`, `or_flag_zero_iff` | `ov |= …` is monotone, so "an early overflow leaves later ops on discarded values" is a theorem, not a comment |

Two modelling corrections are recorded in the file: `__` is reserved in
Isabelle identifiers (hence `builtin_add_overflow`), and `sizeof` is a
reserved token.

## 9. P3 mechanized (2026-10-22)

`verif/P3_Capacity.thy` builds green (clean-room `isabelle build -d verif
-b Sh2`, no `sorry`/`oops`). It covers the **capacity half** of P3: an
array's history is a list of `Reset`/`Append` ops, and the theory proves

| lemma | content |
|---|---|
| `length_le_volume` | the length never exceeds the volume ever added, any interleaving, any starting length — the reset case is load-bearing (a reset discards what preceded it) |
| `volume_le_capacity_when_single_reset` | total volume ≤ `max_reset + appends` **exactly** in the single-reset regime, which is what `array_fixed_caps` admits (a reset is a loop-free `setArray`); stated as a hypothesis, not assumed |
| `exec_zero_le_capacity` | the composition: the empty-array length fits the backend's capacity quantity |
| `max_combines_independent_bounds`, `min_would_be_unsound` | the index term combines by `max`, since each bounds the length independently |
| `guard_admits_in_bounds_writes`, `append_in_bounds` | a write within the declared capacity is in bounds — the property the guard checks |

**The `strlen ≤ N` half** is `verif/P3_Buffer.thy` (see §11): the
fixed-buffer contract at `c_backend.rs:18-24`, where the assert is
debug-only and `NDEBUG` truncates. Its gap is stated in the file: N's
*producer* (`analyze_string_lengths`) is Rust, and proving N correct is a
property of the shIR walk that only the `--dump-widths` bridge of
`PLAN-P1.md` §4 can discharge — what is proved is that a correct N
suffices.

One model limitation is recorded in the file: `unsigned long long`'s upper
bound (`2^64−1`) is not an `int`, so `W64u`'s interval is given the largest
representable bound and is excluded from the soundness statement by
hypothesis.

## 10. P1 mechanized (2026-10-22)

`verif/P1_Narrowing.thy` builds green (clean-room `isabelle build -d verif
-b Sh2`, no `sorry`/`oops`). The stage was recorded as blocked for most of
this session; the blocker was **tooling, not mathematics** — an
8-constructor datatype carrying two `fun`s cannot be case-split by `cases`
in this Isabelle build (`x = <ctor> ⟹ False` for the upper constructors),
reproduced at five constructors from a fresh heap. P1 therefore encodes
widths as natural-number codes chosen by the same if-chain as
`range_width_name`, which keeps the content and drops the dependency.

The theorem is the one the code relies on. **"narrow evaluation equals i64
evaluation" is vacuous** for `+`/`*` — C's usual arithmetic conversions
promote anyway. What matters is the **store condition**:

| lemma | content |
|---|---|
| `narrow_sound` | the width named for a range accepts every value in it, so the *declaration* is never the fault |
| `store_within_declared_width` | the store-side form (T3) |
| `outside_width_not_admitted_u8`/`_u16` | the direction a **missing** range check violates — exactly the 10 gcc-visible truncating stores in 9 files from §7 |
| `nonneg_never_signed` | a non-negative lower bound always picks an *unsigned* width — why UBSan could not see those stores and §7's sweep came back clean |
| `narrow_not_monotone` | a negative result: the backend cannot narrow to the tightest per-use interval; it must keep taking the max over uses |
| `arithmetic_in_interval_stays`, `store_safe_iff` | the interval containment that T1 and T3 consume |

## 11. P3_Buffer: the fixed-buffer contract (2026-10-22)

`verif/P3_Buffer.thy` builds green and closes P3's second half. The
destination is modelled as `(capacity, length)`; the two copy idioms the
renderer emits are modelled concretely:

| lemma | content |
|---|---|
| `strlen_bound_justifies_copy` | `strlen ≤ N` plus a declared capacity `N+1` makes the unbounded copy safe — the obligation the bound exists to discharge |
| `overlong_source_makes_copy_unsafe` | the converse: a mis-analysed bound makes the copy return `None`. Same shape as P1's `outside_width_not_admitted` and P2's `subtree_overflow_forces_gmp` |
| `copy_unbounded_exact`, `copy_bounded_preserves_fits` | the idioms bracket the contract: exact when safe, truncating-but-defined otherwise — **a wrong `N` is a wrong value, never UB** |
| `debug_assert_matches_contract` | the debug `assert(strlen(v) <= N)` *is* `fits_buf`, which is why removing it under `NDEBUG` changes only the failure mode |

**The gap, stated rather than papered over.** `N`'s producer,
`analyze_string_lengths` in `shir.rs`, is Rust. That `N` is *correct* — the
value really has length ≤ N at every write — is a property of the shIR walk,
not of the buffer arithmetic. Only the `--dump-widths` bridge of
`PLAN-P1.md` §4 (measure the analysis against the corpus) can discharge it.
What this theory proves is the conditional: **a correct `N` suffices.**

## 12. P4 blocked: no deep embedding toolchain (2026-10-22)

P4 was `optional` in §5 and depended on P1. P1 is now green, so the stated
dependency is satisfied — but P4 needs something that is not in this
distribution: **there is no `C-Parser`, `AutoCorres` or `Simpl`** under
`Isabelle2025-2/src/` (`src/HOL/` has no `C_Parser*`/`AutoCorres*`). Those
live in the AFP, which is not part of the tarball obtained here. Without
them there is no `C_ast` to embed `render` into, so the theorem
`render : ShIR → C_ast` cannot even be *stated*, let alone proved.

Two secondary reasons P4 would not pay even with the AFP:
- §2c already records that a theorem about the emitted *text* is only as
  good as the compiler downstream, absent a verified C compiler.
- The renderer is 50.7k lines with 12 `TODO(unsupported)` sites; embedding
  the whole of it is the "large" effort §5 estimated, for a property
  P2/P3 already pin at the arithmetic level.

Recorded as blocked rather than attempted.

## 13. §2a's `ov`-flag obligation mechanized (2026-10-27)

§2a named the first render-discipline obligation verbatim:

> the theorem is "the `ov` flag is set exactly when the exact result
> leaves `long long`", i.e. the tier's escape hatch to GMP is only taken
> when needed *and* always taken when needed

That sentence is now machine-checked, in two halves that together close it.

**Emission level — Verus, `sh2perl/proofs/verus/c_checked_arith.rs`.**
18 obligations, 0 errors, over a model of the checked tier's own logic
(`tiered_i64_expr` + `tiered_store_general` = protocol A's `ov |=` walk
with its `if (!ov)` commit; `spec_checked_expr` + `spec_checked_store` =
protocol B's `break` walk with the store line *after* the checks):

- `flag_iff_exact_exits` — THE OBLIGATION, both directions: `ov == false`
  iff every flagged node's exact value lies in i64, so the escape hatch is
  taken only when needed *and* whenever needed;
- `walk_value_sound` / `air_value_sound` — a flag-free walk *is* the
  denotation and re-establishes the range invariant;
- `commit_a_sound`, `commit_a_spill_exactly_when_needed` — `fast` is
  assigned only under `!ov`, and the GMP spill runs iff a participant was
  already promoted or some exact value left i64;
- `commit_b_sound`, `commit_b_entry_refusal`, `break_matches_flag` — the
  short-circuit protocol reports the same flag as the continue protocol,
  so one `walk` models both, and an entry refusal means no store;
- `refusal_forces_spill` — the source's `None => ov = 1` arm, pinned;
- `raw_divisor_gate` — the unflagged `/` `%` arm is reachable only under a
  positive-literal divisor, excluding both UBs of raw C division (zero
  divisor, `LLONG_MIN / -1`) *at the gate*, not at a runtime check;
- two negative controls: `unguarded_commit_ships_wrap` (delete the
  `if (!ov)` gate and MAX+1 "commits" `-2^63`) and
  `protocol_b_skips_the_overflowing_store`.

Why Verus for this half rather than Isabelle: the tier is Rust. Verus
verifies the source that *produces* the C, so the theorem is about
`tiered_i64_expr`'s actual control flow instead of a transcription of it —
a transcription could agree with itself and disagree with the compiler's
input. It is registered in `harness/verus-gate.sh` with its **exact
obligation count**, so a weakened file fails the gate even when Verus
exits 0.

**shIR level — Isabelle, `proofs/ArithIdentity/ArithWidth.thy`.** §4 of the
arithmetic denotation, building under `quick_and_dirty = false` with no
`sorry`. It defines the machine-width reading `ev64` against `ArithIdentity`'s
exact reading `ev` and proves:

- `ev64_agrees` — `air e a ⟹ ev64 e a = ev e a`: while every fold point
  holds an in-range exact value the two readings coincide, so a value the
  tier commits under `if (!ov)` **is** the shIR meaning of the tree;
- `wrap64_id` / `wrap64_range` — an in-range value is its own wrap, and
  every wrap lands back in i64, so the fast tier's value is always a legal
  `long long`, flag or no flag;
- `machine_wrap_changes_the_reading` /
  `machine_wrap_breaks_the_invariant` — the negative control: MAX+1 reads
  `2^63` exactly and `-2^63` wrapped, and `air` genuinely fails there,
  which is why the flag exists at all.

The two halves are one contract: Verus proves the *protocol* (the flag is
set exactly when needed), Isabelle proves that what the protocol lets
through *is* the denotation. Verus's `Tree::Num` is i64 by type so its
invariant skips leaves, while `arith = Num int` refines nothing, so `air`
checks literals too — the Isabelle side is deliberately the stronger
statement. `fits64` is spelled `i64_min ≤ x ∧ x < half_u64` rather than
`x ≤ i64_max` because `Main` here has neither `omega` nor `presburger` and
the strict form keeps every obligation inside `linarith`; over `int` the
two denote the same set, since `half_u64 = i64_max + 1`.

**Still open in §2a.** The obligations above are about one *rendered*
expression. The layer deciding *which* expressions get narrowed —
`var_types` / `analyze_var_ranges`, and the shared `f32_narrow` /
`i32_provable` transforms — is untouched, so §2a's per-variable statement
`∀ s. v ∈ [lo,hi] ⟹ eval_int32(e,s) = eval_i64(e,s) = eval_shell_intmax(e,s)`
remains unmechanized, as do `_sh_isint31`, the `__int128`-to-decimal
helper, `need_isqrt`, and the operator/promotion rules. §2a's "a few
thousand lines plus a generator" estimate still stands for that; nothing
here substitutes for it.

**Gates (re-run 2026-10-28).** `harness/transform-proofs.sh` → 5
checked-and-built, 1 failed: the pre-existing `proofs/` root, red on
another lane's uncommitted `Maskable.thy` at lines 251/621/800 — in a
session (`Maskable = BigIntRange +`) that imports none of this work, and
last edited 2026-10-24, before any of it. The ArithIdentity session
(`ArithIdentity` + `ArithWidth` + `ArithDec`, `quick_and_dirty = false`,
zero `sorry`), TextOps, verif and both `checked` manifests all build.
`harness/verus-gate.sh` → **43 passed, 0 failed**: all 26 models green,
including the three added here (`c_eqne_emit.rs` 11/11,
`c_checked_arith.rs` 18/18, `c_dec_str.rs` 26/26), and the sync-coverage
checks too — `verus-sync-coverage.sh:elim_trio`, which failed on 2026-10-27
because another lane's edits broke the lib's `cfg(test)` target, passes
again.

## 14. Two more render-discipline obligations mechanized (2026-10-27/28)

§1's first layer — "render discipline … silent wrong value / UB" — gains
two more of its informal comment-claims as machine-checked theorems. Both
are Verus models of the generator's OWN decision code (same rationale as
§13: the theorem is about the source that produces the C, not a
transcription of it), and the decimal half is closed on the shIR side too.

### 14a. The Eq/Ne arm — `sh2perl/proofs/verus/c_eqne_emit.rs` (11 obligations)

`expr()`'s `BinOp Eq|Ne` arm makes a two-way decision: both operands
certainly-text (`str_cmp_valued`) → a STRING compare via
`strcmp`/`_sh_sc`; otherwise a RAW `==`/`!=` on the operand emissions.
The raw arm is UB when an operand emission is a `char*` — a
pointer/integer comparison, which gcc names exactly
("warning: comparison between pointer and integer"). This is not latent:
`test-lowering`'s string-eq lift turns `[ "$i" = "2" ]` into
`Not(BinOp{Ne}, Var i, Str "2")`, and for a numeric-homed `i` (loop
counters — the common case) `str_cmp_valued(Var i)` is false while the
literal is text, so the RAW arm emits `i != "2"`.The lift itself is *not* wrong — its contract is that every backend maps
`Ne` to a string-capable inequality, and C was the one backend that did
not. The fix therefore landed in the decision, and in three sibling
render defects the fixed compare unmasked (all 2026-10-28, all in
`sh2perl/src/c_backend.rs`):

1. **the trigger** — `str_intent`: a `Str`/`Interpolate`/`Capture`
   operand now pins the string arm (or two certainly-text operands, the
   original rule), and the non-text side renders through `value_c`, the
   backend's own canonical string form, so both sides of the `strcmp`
   are `char*`;
2. **`continue`/`break` status** — bash's special builtins *succeed*, so
   they set `$? = 0` (measured); the emitters wrote no status, leaving
   the failing test's `1` through the loop's last iteration
   (`or-continue.sh` exited 1 where bash exits 0);
3. **word-for `loop_depth`** — the `for i in 1 2 3` table arm never
   incremented `loop_depth`, so every in-loop flow statement took the
   "outside a loop" branch: bare `continue;` with no status (2), and at
   two sites `_sh_rc = 1;` INSTEAD of continue/break — a silently
   dropped `break`;
4. **the chain arm's unowned store** — a statement-level
   `A || VAR="default"` (`Call{assign}` inside an and/or chain) assigned
   a string LITERAL to a free-at-exit heap var; the epilogue's
   `free(VAR)` then aborted (`munmap_chunk(): invalid pointer`,
   rc=134 — func-after-test-or.sh). Expression-position assigns to a
   heap string target now go through `_sh_sset` — the same owned store
   a statement-position assign gets — as a GNU statement-expression so
   the `||` stays lazy.

Of the five measured reds, **three now PASS the gate** (or-continue,
eq-string-num-var, func-after-test-or). The remaining two bisected to
OTHER transforms, not to this lift: 083_process_sub_missing_files ←
`process-subst` (the procsub site drops diff's stdout), 064_12 ←
`brace-fold` (`_sh_mkdir_p` segfaults in a fresh directory). Those are
separate bugs and remain open.

Measured 2026-10-27 on the 563-example corpus: 2 of 564 renders carried
the gcc warning (or-continue, eq-string-num-var), and
`harness/c_gate_main.sh` failed 5 files whose transforms-ON output
diverged from bash while the transforms-OFF output matched it.

| lemma | content |
|---|---|
| `emit_string_cmp_sound` | the strcmp arm is total (through `_sh_sc`) and equals the shIR STRING compare whenever both operands are certainly-text |
| `emit_raw_cmp_sound` | the raw arm equals the shIR NUMERIC compare whenever both operand emissions are C integers (NULL counts as 0, as C's null-pointer constant compares) |
| `raw_arm_ub_on_text` | the negative direction, stated as a theorem: a non-null `char*` operand makes the raw arm UB — the class the corpus actually hits |

### 14b. The decimal renderers — `c_dec_str.rs` (26 obligations) + `proofs/ArithIdentity/ArithDec.thy`

The backend emits two hand-rolled itoas, each carrying an unproven claim
in its own comment — and the claims are the claims §2a lists as
"not trivially in range" and §2b lists as width obligations:

- `_sh_ll2s(char *d, long long v)` (reached from `num_temp`, whose
  destination is the emitted `static char _sN[32]`): *"byte-for-byte what
  snprintf("%lld") writes for every long long (incl. LLONG_MIN)"*;
- the inline `size_t` itoa of `FieldStrip`/`FieldStripEnd` into
  `str_temp(24)`: *"a decimal string in a bounded static (size_t ≤ 20
  digits + NUL ≤ 24)"*.

**Verus half (`sh2perl/proofs/verus/c_dec_str.rs`, 26 obligations, four
mutants).** `mag_emitted_is_abs` (the emitted `-(v+1)+1` equals `|v|` for
all v) and `mag_step_fits_i64` (and `-(v+1)` lies in i64 for every v — the
reason the source is written that way; `neg_plain_overflows` refutes plain
`-v` at LLONG_MIN); `fill_is_digits` (the do-while emits LSB-first digits,
so the copied slice is MSB first); `ndigits_le_19` — THE WIDTH THEOREM, no
64-bit magnitude needs more than 19 digits, hence no index underflow in
`t[24]`; `ll2s_exact` (the bytes equal `render_ll(v)`, the `%lld`
spelling); `ll2s_capacity` (`copy_len + 1 ≤ 32`, the NUL lands inside
`num_temp`'s buffer); `size_itoa_i_bound` (`_i ≥ 3`, so the `memmove`
always carries the NUL at `b[23]`); `size_itoa_exact` (result is
`dec_digits(v)` for every u64, incl. the 20-digit maximum and the `!_v`
zero arm); `max_digits_64` (the shared width fact, proved once).

**Isabelle half (`proofs/ArithIdentity/ArithDec.thy`, §5 of the
arithmetic denotation, green under `quick_and_dirty = false`).** Until
2026-11-09 this sentence rested on a file nothing built: `ArithDec.thy` was
untracked and in no `ROOT`, so the gate never reached it. It now rides in the
`ArithIdentity` session's `theories` list (after `ArithWidth`, which it
imports) and checks in 31 s as part of that session — `ArithIdentity` 4.6 s,
`ArithWidth` 2.2 s, `ArithDec` 31.2 s, all under `quick_and_dirty = false`,
and `harness/transform-proofs.sh` rebuilds them every run. The bytes
those helpers promise are proved against the shIR denotation, not against
a model of C: `parse_dec_bytes` (the fold reader inverts `dec_bytes`),
`parse_render_id` (`parse (render v) = v` — the round trip `ll2s_exact`
points at), well-formedness (`dec_bytes_digits` digit-set,
`dec_bytes_hd45` never a sign byte), and the width lemmas:
`dec_bytes_len_i64_max` (19), `dec_bytes_len_u64_max` (20),
`dec_bytes_length_le_19`, `render_len_le_20` over the 64-bit domain — plus
the negative control `render_len_unbounded`: shell ints are unbounded, so
"≤ 20 digits" is precisely a *64-bit-domain* claim and is stated as one.

The two halves meet where `ll2s_exact` names `render_ll` and ArithDec's
`render` defines the same spelling over the denotation: Verus proves the
emitted buffer arithmetic is exact and in-bounds; Isabelle proves the
spelling round-trips and is the one bash's `printf %d` family reads.

## 15. The width store condition — `c_width_store.rs` (20 obligations)

§7's 10 gcc-visible truncating stores are the shape this model closes at
the Verus level. The backend checks nothing at the store: a var seeded
`[1,5]→u8` keeps that width while a `long long` table element is stored
into it, and `uint8_t result = 15 + _sh_pow(5,2)` is safe only because
25 happens to fit. `range_width_name` (shir.rs:16628) names 8 widths by
first-match if-chain (u8 before i8 — load-bearing for the
sanitizer-invisibility: non-negative ranges always take the unsigned
arm), `Width::from_range_name` maps back (garbage→I64, fail-closed),
`Width::widen` is max rank, and `effective_widths` + `walk_widths_expr`
fold the var's own width with every mentioning arith result's width,
forcing I64 on unknown ranges (modulo the `arith_op_wide` escape and
the comparison/side-effect-root skips, both modelled as shape
predicates).

What is proved (ranges are HYPOTHESES — T1 of P1_Narrowing.thy; the
producers stay proved in Isabelle: BigIntRange corner lemmas for `/`,
I32Provable for the estimator):

- `narrow_sound` — a value inside the analysed range fits the named
  width (P1's T1-second-half, mirrored), WITH the honest domain
  provisos the if-chain needs: `hi ≤ 2^64-1` (the U64 arm has no
  source-level upper bound), and an I64 naming is sound only when the
  range fits i64 (the else arm fires for wider ranges it cannot hold —
  the analysis must not produce them; stated, not hidden);
- `store_safe_conditional` — THE OBLIGATION (T3): under consistent
  (value-covering) ranges the widen-fold admits the store —
  `eff_fold_sound` over the max-rank fold, with the shell-domain
  premise (`fits(v, I64)`: bash arithmetic never leaves i64);
- `outside_not_admitted_u8/_i8` — the TRUNC direction (P1's lemma),
  the property the 10 gcc-visible stores violate;
- `narrow_u8_first`, `nonneg_never_signed` — the ordering pins (first-
  match names U8 though I8 would fit; lo≥0 never names signed);
- `from_range_name_total`, `unknown_forces_i64`, `op_wide_fail_closed`
  / `op_wide_fires` (the escape claims wide only on literal-out-of-i32,
  positional `$N`, wide-range var; never on unknown/unranged),
  `skip_shapes`, `widen_is_max`/`widen_lattice`/`widen_preserves_fit`;
- three fidelity pins: the 6 live shir.rs unit assertions (incl.
  `(0,2^64-1)→u64`), the c_type spellings, and the corpus TRUNC shape
  detected (own `[1,5]→U8` + unknown use forces the fold to I64 — the
  analysis had the information to stay wide; the per-store check is
  absent).

Negative control: naming `(0,100)` as I8 (ordering flipped) goes red
(19v/1e, restored to 20v/0e) — the u8-before-i8 arm is load-bearing,
not cosmetic.



- v20 (2026-10-29): **the sparse-array read family** — a nine-face
  probe through the real pipeline (shir → C → cc → bash-diff) exposed
  six red faces: `${!arr[@]}` on ANY indexed array was a cc red (the
  read-driven `assoc_arrays.insert` in THREE places flipped storage
  class while the writes stayed indexed — `arr_len undeclared, did you
  mean arr_n`), `${#arr[@]}` reported the dense extent (6 vs bash 4),
  `${arr[*]}` emitted the separator before the NULL skip (`a b c   z`),
  the for-in visited holes as empty strings, and the
  `for ((i<${#arr[@]}))` bound read
  `atoll(_sh_env("((long long)arr_len)"))` → 0 iterations for DENSE
  arrays too (never worked). Fixed in `src/c_backend.rs` (class from
  writes; `_sh_join_ikind`/`_sh_icount`/`_sh_join_idx` helpers;
  separator-after-skip; for-in hole skip; NULL-after-free in all seven
  free loops; `apply_array_counts` gained the `_sh_env("T")` wrapper
  rewrites + the element-count branch). Gate 588/56/7 → 590/54/7 with
  an EMPTY newly-failing set; two corpus files flipped green. §26,
  `c_sparse_array.rs` (45 obligations, mutants m1–m12 + the
  coverage-old pin), registered `c_sparse_array.rs:28:40`.
- v19 (2026-10-29): §22's extractor — the FIRST MECHANICAL SYNC for
  a transcription model. `harness/declcov-extract.py` extracts the
  modelled walkers' arm chains verbatim from `sh2perl/src/c_backend.rs`
  (exact arm-pattern text with guards, plus the walker calls each arm
  body carries; INV + Hoist + Veto, 8 functions incl. the veto's seq
  dispatcher), emitted into the manifest by a new
  `verus-sync-coverage.sh c_decl_coverage` dispatch — pin map: the 8
  pins → UNMIRRORED (the §22 living tie is the probe battery + corpus,
  which cargo cannot run), a region-stable sha header (a whole-file
  sha would false-fail on every other lane's c_backend edit), and a
  crate-root test filter so [exec] still compile-checks the lib.
  Baseline committed as `proofs/verus/c_decl_coverage_sync.txt`
  (140 lines), registered in `harness/verus-gate.sh` SYNCS. Negative
  control: deleting the hoist If arm's elsif-cond walk moved exactly
  its line (`collect_assigned_exprx2` → `x1`) and the region sha →
  red; restored → the baseline reproduces the live source.
  Side-repair: HEAD's `harness/verus-gate.sh` had LOST the `MODELS=(
  … )` closing paren (a registration commit), so the gate had not
  parsed since — `bash -n` green, gate runs again.

- v18 (2026-10-29): **the decl-coverage source fixes rebuilt**, plus
  one render fix the probe battery forced. The 2026-10-28 working tree
  carrying v10b's and the (0)(a)-(d) audit fixes was overwritten back
  to committed state at 23:10 (never committed — no stash, reflog, or
  surviving copy held them), so the source re-landed from the one
  artifact that survived intact and gated green: the model
  `c_decl_coverage.rs`, whose arm chains and pins are the verbatim
  spec. In `sh2perl/src/c_backend.rs`:
  1. HOIST (`collect_assigned_vars`/`_expr`): fix (0) Try arms; (a)
     elsif-cond walk; (b) For-iter walk; the While/DoWhile-cond walk;
     the Case discriminant; the Select ch/value exprs (top-level menu
     write); stmt arms for Output/DeclareArray/Die/Warn/SetChildError/
     Return(v10b #2)/WriteFile/Redirect/Pipeline/Exec; expr-position
     (c) `printf -v`, (d) `let`, v10's `param` `=`/`:=` arm, the
     raw-text `${NAME:=…}` scan (v10b #3), and the generic/BinOp/
     Interp/Array/Arrow forwarders the old `_ => {}` swallowed.
  2. INVENTORY (`collect_vars_full`/`_expr`): Try (0),
     While/DoWhile-cond, v10's `param` arm, the raw scan.
  3. STORE (`collect_store_names`/`_expr`): Try (0), the writing-param
     arm, the raw scan.
  4. VETO: `collect_param_write_targets`/`_stmt`/`_expr` re-created
     from the model's `paramw` chains and wired into
     `const_assign_rhs`'s poison set (a `${NAME:=…}` target is never
     const-liftable).
  5. `vbuf_temp` forces `need_sh` (v10b #4 — the `_sh_vbuf` typedef
     exists only inside the helper block).
  6. **RENDER FIX THE PROBES FOUND (new — not in v10b):** the `=`/`:=`
     arm's non-buf scalar path stored the default word's LITERAL
     pointer in a var the end-of-scope cleanup `free()`s
     (`is_heap_store_var`) — p13/p11/p14 printed the right bytes then
     died `munmap_chunk(): invalid pointer` (rc 134 vs bash 0) as soon
     as the census fixes made those vars declared at all. The store
     arm now `_sh_xstrdup`s the DEFAULT only (the value arm re-reads
     the var — same bytes; the double-eval count matches the old
     `(y = v, v)`). Buf'd vars already `strcpy`d; numeric vars never
     hold pointers.
  Verification: the 14-case statement-position battery
  (`/tmp/decl_probe.sh`) is **14/14** (compile + stdout vs bash);
  `c_decl_coverage.rs` re-verifies **51v/0e**; full gate measured as
  an A/B against the SAME tree with HEAD's `c_backend.rs` swapped in:
  mine **588/56/7** vs HEAD **573/71/7** — 15 files fixed (the
  undeclared-ident `cc` class these fixes target, plus the
  process-substitution trio), **zero new failing files** (one class
  change: `parse-arithmetic-extra-paren` cc→exec/diff, still red —
  known lexer-gap class); `cargo test --lib c_backend::` fails exactly
  the same 9 tests as the pre-change 00:08 baseline. The 5 reds worse
  than v17's 593/51 are all reproduced under HEAD too — other lanes'
  committed Eq/Ne + transform work landed after that measurement.

- v17 (2026-10-28): §23 — the string-literal escaper
  (`c_str_lit.rs`, 19 obligations, three mutants red at their pins →
  restored 19v/0e): FINITE-STATE C-lexer denotation + round-trip +
  per-char locality + the measured `\x`-absorption divergences as
  `emit_old` pins. THE SOURCE FIX SHIPS WITH IT: `cstr`'s two
  single-byte arms now emit 3-digit octal (greedy-hex absorption was
  live data corruption — t1/t5 stdout bytes wrong vs bash — and
  `\x01ABC` reached the out-of-range violation); probe t1-t8 8/8
  match post-fix; C gate re-run at baseline (593/51/7 plus one
  standalone-green flake under a concurrent lane's rebuild).

- v16 (2026-10-28): §22 — the decl-coverage censuses
  (`c_decl_coverage.rs`, 51 obligations, three mutants red 50v/1e,
  47v/4e, 50v/1e → restored 51v/0e): hoist-coverage invariant + veto
  exactness both directions + param/raw bridge + the measured corpus
  pins. Registered in `harness/verus-gate.sh`. Proof artifacts only;
  the six source fixes they model were v10/v10b.

- v15 (2026-10-28): §21 — capture/wrap quoting (`c_capture_wrap.rs`,
  16 obligations, bare-quote mutant red 13v/3e → restored 16v/0e):
  injection-freedom + splice shape + word-quote core + newline gate +
  status mapping total/disjoint + capture empty-arm/strip + `_sh_sc`
  NULL-safety + `"don't"`/exit-3/signal pins (length 9 corrected by
  the proof). Proof artifacts only.

- v14 (2026-10-28): §20 — the `_sh_*` string helpers
  (`c_str_helpers.rs`, 40 obligations, flipped-clamp mutant red 39v/1e
  → restored 40v/0e): shared b/e clamp total; substr/clamp edges;
  word spans + join_range; fuel-sufficient replace march + empty-pat
  identity; strip oracle-consistency + no-match identity; argv
  slice/join; split words + split_count. Proof artifacts only.

- v13 (2026-10-28): §19 — the operator/promotion rules
  (`c_op_promote.rs`, 15 obligations, refuse-to-fold mutant red 14v/1e
  → restored 15v/0e): fold = denotation, abort preservation, LL as
  pure type promotion on the range trigger (with the corrected 67108847
  reading), unsigned-gate premises exact. Proof artifacts only.

- v12 (2026-10-28): §18 — the integer-math helpers (`c_int_helpers.rs`,
  69 obligations, >10-digit mutant red 68v/1e): predicate contract with
  all refusal arms pinned + the 10-digit fold exhibited step-by-step;
  Newton descent well-defined with exact small values by direct
  unfolding (full floor stays open — fixpoint invariant); i128 branch
  contract + step-in-domain + INT128_MIN refutation + 39-digit bound by
  generated chain. Honest provisos: `*` overflow is the caller's gate;
  cross-branch magnitude identity solver-opaque. Proof artifacts only.

- v11 (2026-10-28): §17 — the arith guard + temp/spec decisions
  (`c_arith_guard.rs`, 15 obligations, negative-dividend mutant red
  14v/1e): the guarded `({r} == 0 ? 0 : …)` form is total (no SIGFPE)
  and dead exactly under the divisor proof; the unsigned
  strength-reduction equals the signed truncating op on proven-nonneg
  i64 dividends (with the shipped `-3 % 2` divergence as the negative
  control); `static char _sN[32]` + `str_temp(cap)` + `width_buf_len`
  size every stringification exactly; `num_spec`'s cast⟺`%lld`
  invariant holds with all 5 live unit assertions. Proof artifacts
  only; no transpiler source changed.

- v10 (2026-10-28): §16 — the fixed-buffer store contract
  (`c_buf_copy.rs`, 14 obligations, capture-denial mutant red 13v/1e):
  the emission side of P3's buffer half (given the analysis bound, every
  store site respects it). Proof artifacts only; no transpiler source
  changed.

- v9 (2026-10-28): §15 — the width store condition (`c_width_store.rs`,
  20 obligations, ordered-mutant red 19v/1e): T3 of P1_Narrowing.thy at
  the Verus level (consistent ranges ⟹ widen-fold admits the store),
  with the honest domain provisos (u64 unbounded above, else/I64 fires
  past i64). Proof artifacts only; no transpiler source changed.

## 16. The fixed-buffer store contract — `c_buf_copy.rs` (14 obligations)

§11 closed P3's second half (the fixed-buffer contract) conditional on
a correct N. This model closes the EMISSION side: given the analysis
bound, does every store site respect it? `buf_bound`
(c_backend.rs:11269) grants `char v[b+1]` only to proven Str vars with
b ≤ 1024 — numeric vars (integer C value: `strlen` on it is itself UB),
capture receivers (the analysis under-bounds command output: `sha256sum`
emits hash + filename, only the hash was counted), and GMP bigint vars
(unbounded by design) all stay `char*`. `emit_guarded_copy` (:11293)
emits per RHS shape: fitting unescaped literal → bare
`strncpy(dst,src,b+1)` (no assert needed — provably true; no NUL store
— strncpy pads); capture/vbuf/`sh2_` sources → `strncpy` + `dst[b]=0`
with NO assert (not reliably bounded — the assert would
false-positive; the truncation is still safe); other stringy sources →
`assert(strlen ≤ b)` + `strncpy` + `dst[b]=0` (the assert is the
debug-mode tripwire, the NUL store defines NDEBUG); non-stringy
spellings → `dst[0]=0` (never touch the pointer).

What is proved (lengths are HYPOTHESES; the model states the
store-side contract): `guarded_write_safe` (THE OBLIGATION — the grown
write always lands NUL-terminated in bounds; exact when the source
fits, truncating-but-defined otherwise); `literal_arm_exact`;
`debug_assert_matches` (the assert IS the fits predicate — P3_Buffer's
lemma, mirrored); `capture_arm_no_ub` (assert-free is still never UB —
"a wrong N is a wrong value, never UB"); `bogus_arm_clears`;
`stringy_shape_mirror` (the six-shape classifier + three refusals);
`unescaped_recognizes` (only escape-free `"…"` qualifies, strlen =
len−2); `bound_discipline` (all three denials stay `char*`; bound
requires b ≤ 1024); three pins (decl shapes, the `sha256sum`
capture-receiver-stays-`char*` shape, the `"yes"`-fast vs
`_cap_`-unguarded vs `+`-clear arm shapes).

Negative control: dropping the capture denial (bounded capture
receiver as Fixed) goes red (13v/1e, restored to 14v/0e) — the denial
is load-bearing, not conservative: the analysis demonstrably
under-bounds command output.

## 17. The arith guard + temp/spec decisions — `c_arith_guard.rs` (15 obligations)

The one site where a missing check is a CRASH, not a wrap: a raw `/ 0`
is SIGFPE. `arith`'s `/`|`%` arm (c_backend.rs:15264) takes the first
matching shape: float operand → `fmod` (no guard — NaN propagates, the
documented Python divergence); positive-literal power-of-2 divisor +
`arith_proven_nonneg(lhs)` (range says lo≥0 AND every subrange fits
i64) → strength-reduced unsigned `& mask`/`>> k`; positive-literal
divisor + proven-nonneg dividend → unsigned op (guard still needed
unless bounded-nonzero); `arith_divisor_bounded_nonzero(rhs)`
(shir.rs:10914 — nonzero literal/var, or BOUNDED-subset var whose
proven range stays strictly inside ±i64 so a wrapping render can never
overflow through zero) → bare `(l op r)` (guard dead); else →
`({r} == 0 ? 0 : (l op r))` (bash's rule: the expansion vanishes → 0).
Kept away from the tier entirely: dynamic-divisor `/` `%` (refused by
`spec_rhs_ok` — the checked-tier model), `const_arith_value` never
folding `/` `%` (a fold turns a runtime abort into a compile error),
LLONG_MIN/−1 (positive-divisor gate only).

What is proved: `guard_total` (THE OBLIGATION — the guarded form is
total: zero → 0, else the truncating quotient); `guard_matches_bare`
(nonzero ⟹ guard dead); `llong_min_gate` (LLONG_MIN/−1 still UB under
the guard — the gate is load-bearing); `unsigned_red_sound` (unsigned
= signed on nonneg i64 dividends, positive divisors); the negative
control `reduction_needs_nonneg` (the shipped `-3 % 2` shape: signed
−1 vs unsigned 1 — the comment's own executed counterexample);
`bounded_nonzero_elides`; `num_temp_fits` (`_sN[32]` holds every i64
spelling — the decimal model's ≤20+NUL bound); `str_temp_sized`
(24 for the size_t itoa, 32 for specials/strlen); `width_buf_exact`
(the I8→4 … I64/U64→21 table = chars+NUL of each widest spelling);
`num_spec_invariant` (cast ⟺ `%lld` — a casted operand never meets a
narrow format); `type_matches_sound` (var-at-w matches, Str-var and
int-literal never match, same-width-leaves arith matches);
`specials_are_int` (`# ? $` are `%d` cast-free); two pins (the 5 live
`num_spec` unit assertions; the shipped guard shape + gate + strength
predicates).

Negative control: claiming the negative dividend equals the unsigned
reduction goes red (14v/1e, restored to 15v/0e) — the nonneg proof is
load-bearing, not an optimization.

## 18. The integer-math helpers — `c_int_helpers.rs` (69 obligations)

The three helpers §2a names as render-layer obligations, with the two
hard solver lessons this file taught recorded as stated provisos, not
hidden gaps.

`_sh_isint31` (bc fast-path predicate): returns 1 ⟹ integer-shaped
with |value| ≤ 2^31 — exactly the caller contract (atoll-safe, bounded
`+ -` cannot overflow i64). All refusal arms pinned (empty, >10
digits, trailing junk, over-2^31 magnitude); the 10-digit
3000000000 fold exhibited step-by-step (one spec unfolding per push —
the only form the prover accepts on literal push-chains). Completeness
(no missed fast path on canonical text). HONEST PROVISO, found during
the proof: `*` overflow is bounded by the CALLER's digit/shape gate,
not by 2^31 alone (2147483648² > i64max) — `isint31_fast_safe` covers
`+ -` only, stated as the proviso it is.

`_sh_isqrt` (Newton floor sqrt): n ≤ 0 → 0; the descent is
well-defined on the table range (entry-step lemma + per-level average
argument, no assume — the earlier `assume` was removed when the
factored `isqrt_descend` induction closed it); exact small values
0,1,2,3,4,15,16 by direct Newton unfolding (each asserted step IS the
loop's unfolding). The FULL floor claim (r² ≤ n < (r+1)²) stays open —
needs the loop's fixpoint property (y ≥ x at exit gives the lower
bracket), same class as the analysis-side T1. The `assume` that stood
in for it is gone; the gap is a stated obligation, not a hidden one.

`_sh_i128_str` (exact __int128 → decimal): the branch the C takes
(negative → the emitted `-(v+1)+1` form, else identity), with the
cross-branch identity `0-(v+1)+1 == -v` stated as the solver-opaque
step it is (probed red even under `nonlinear_arith` — the solver keeps
`(0-v)` opaque in every rebracketing tried); the intermediate
`-(v+1)` stays in-domain (linear bounds — WHY the source avoids plain
`-v`, with the `neg_plain_overflows` refutation at INT128_MIN); no
128-bit magnitude needs more than 39 digits (generated 39-level chain
— tmp[64] never overflows); the sign/zero/digit contract via the
branch (negative arm taken / else identity — the else-arm value
disequality is NOT claimed: solver-opaque and unobserved by any
source site; "0" iff zero).

Negative control: accepting >10-digit texts (dropping the nd>10
refusal) goes red (68v/1e, restored to 69v/0e) — the digit cap is
load-bearing: without it a 19-digit text folds past 2^31 and the
predicate would bless an overflowing fast path.

## 19. The operator/promotion rules — `c_op_promote.rs` (15 obligations)

The last §2a render-layer obligation: the rules baked into every
arithmetic emission. `const_arith_value` (checked constant folding):
`+ - *` via `checked_*` (overflow bails to runtime — never a wrapped
constant), `& | ^ ~` total, NEVER `/ %` (a fold turns a runtime abort
into a compile error), shifts, `**`, comparisons. The LL-suffix
widening: out-of-i32 literals render `{n}LL` — with the CORRECTED
67108847 reading, found while writing the pin (both operands fit i32;
no LL alone — the PRODUCT range 4503596674580939 escapes i32, so the
range trigger `arith_bin_range_exceeds_i32` widens both sides via
`arith_const_wide`). The unsigned-gate premises
(`arith_proven_nonneg` + `arith_fits_i64`): untainted leaves, known
range with lo ≥ 0, every subrange fitting i64 (a wrapped-negative
intermediate would diverge even when the math range says ≥ 0),
non-u64 — each refusal arm pinned; the soundness half (unsigned ==
signed on nonneg) stays proved in `c_arith_guard.rs`.

What is proved: `fold_sound` (folded = denotation; None = runtime
path); `fold_never_traps` (Refuse never folds — abort preservation);
`fold_total_bitwise` (total ops always fold); `ll_widening_sound`
(suffix is type-only); `ll_widening_needed` + `exceeds_i32_sound`
(trigger fires iff the proven range escapes i32; unknown → miss);
`nonneg_gate_sound` (admit ⟹ the exact premises the soundness
consumes); `nonneg_gate_refusals` (all four arms); two pins (the
`2+3*4`→14 / `/`-refuses / `-(-5)`→5 / MIN-bails shapes; the LL
shapes with the corrected product reading).

House lessons recorded in the file: Verus spec-int has no `& | ^`
(bitwise is an uninterpreted oracle — agreement by construction, no
value laws claimed); spec-function calls on literal push-chains need
the sub-evaluations bound to names before the match unfolds; the
67108847 pin correction above.

Negative control: folding Refuse to a constant (compile-time abort)
goes red (14v/1e, restored to 15v/0e) — the abort-preservation rule is
load-bearing: a folded `/` would turn a runtime SIGFPE-guard into a
compile error.

## 20. The `_sh_*` string helpers — `c_str_helpers.rs` (103 obligations)

The `need_sh` runtime block's string core: the shared b/e clamp, the
byte-exact readers, the literal march, the oracle-consistent strips,
the argv words, the split spans. Each helper writes into a grown vbuf
(capacity discharged in §25 — `c_vbuf.rs`) and NUL-terminates; what
is proved is the COMPUTE side (indices in-bounds, bytes exact). What is proved (43 proof fns, 56 verified): `clamp_total` (THE
CLAMP — total and in-bounds for every off/len over every n — the
property every helper's loop depends on); `substr_exact` (byte-exact
span with the bash sign conventions); `substr_edges` (empty, past-end,
past-start, negative-len arms); `word_spans`/`join_range` (maximal
runs + join); `find_ok_holds` (the strstr march returns in-bounds
occurrences); `replace_first_exact` (splice = prefix + repl +
suffix); `replace_all_unfolds` (fuel-sufficient march step);
`replace_empty_pat` (empty pattern = identity, both forms);
`strip_pre/suf_sound` (in-bounds + oracle-consistency; greedy takes
the longest, lazy the shortest — by induction on the search
direction); `strip_no_match` (no matching affix ⟹ identity, via
per-search none-lemmas); `argv_slice/join_sound` (off≤0 includes $0,
1-based otherwise, negative len counts back); `split_sound` (words
are the maximal non-blank spans) + `split_count_sound`; pins
(substr `${s:1:3}`, replace-all `"aa"→"bb"` by the two-step march,
replace-first, the `"a b  c"` 3-word walk unfolded innermost-first).

**The positional join's FACE (2026-11-03).** `_sh_argv_join` used to
hard-code a space: right for `"$@"`, silently wrong for `$*` under
any non-default IFS. bash (MEASURED, same run): `IFS=:; set -- p q r;
v="$*"` → `p:q:r`, `v="$@"` → `p q r`; `IFS=""` → `pqr`. The helper
now takes the joiner from the CALL SITE (`*` → IFS[0], `@` → `' '`),
and the model's extension is the denotation of that face:
`ifs0(ifs)` (first char; None when IFS is empty — the NUL the emitted
`if (i > 1 && sep)` guard reads as "no separator") and
`join2(sep,a,b)` (one separator BETWEEN words). Obligations:
`argv_join_sound` (len ≤ 1 ⟹ empty — $0 is never joined — else the
sep-fold over $1..); `join_seq_sep_none` (empty IFS ⟺ the fold
CONCATENATES, by induction on the item count — the meaning of the
`&& sep` guard); the measured pins `argv_join_star_colon` (`p:q:r`),
`argv_join_star_empty` (`pqr`), `argv_join_at_face_ignores_ifs`
(`p q r` under colon IFS, and identical under the startup IFS), and
`argv_join_faces_differ` (the two faces are OBSERVABLY different under
a colon IFS — before the fix the model had no sep, so it could not
have expressed the divergence, let alone caught it); the `len ≤ 1` arm
(`argv_join_single_positional`); `ifs0_bridge` (first-char-only read,
empty ⟺ None). Battery: `harness/ifs-probe.sh` cases 27–30 are green
against bash; case 31 pins a RETAINED divergence as an xfail, never a
blessed pass — `unset IFS` (bash reverts to the startup space, the
C unset arm empties the fixed buffer, so `$*` then joins with nothing).

House lessons recorded in the file: `Seq::len()` is nat — the
int-domain helpers take int, so one `slen` cast site; spec-function
calls on literal push-chains need the sub-evaluations bound to names
before the match unfolds; the no-match identity needs the hypotheses
threaded per search (a bare assert does not fire); the word-walk pin
unfolds innermost-first with index bridges; `decreases` comes AFTER
`ensures` in a proof-fn signature (the reverse is a parse error); and
an induction over a recursive `open spec fn` needs each branch's
unfold written as an explicit assert — an EMPTY branch body leaves the
postcondition unproved even with the IH in scope.

Honest: vbuf growth now proved in §25 (`c_vbuf.rs`, under its
stated size domain); the
`fnmatch` glob ENGINE is an oracle called identically on both sides
(the case_lowering glob-arm shape); traversal per-site.

Negative control: flipping the clamp (e<b allowed, the
out-of-bounds shape) goes red (39v/1e, restored to 40v/0e) — the
clamp is load-bearing: without it a negative length reads past the
NUL.

### 20b. Field splitting is IFS-driven (2026-11-04)

The join faces (§28b) read IFS; the **split** that undoes them did not.
`_sh_split` split on space/tab/newline, hard-coded:

```c
while (*p == ' ' || *p == '\t' || *p == '\n') p++;   /* no IFS read */
```

so `IFS=':'; for w in $v` over `a::b: c` produced TWO fields where bash
produces four. Ground truth (real bash, `harness/ifs-probe.sh` 41-50):

| value | IFS | fields |
|---|---|---|
| `a::b: c` | `:` | `a`, ``, `b`, ` c` (4) |
| `:a:` | `:` | ``, `a` (leading delimiter → an EMPTY first field) |
| `a:b:` | `:` | `a`, `b` (a trailing delimiter adds nothing) |
| `:` | `:` | one empty field |
| `  a  b  ` | startup | `a`, `b` (whitespace runs collapse) |
| `a , b` | ` ,` | `a`, `b` (ws + ONE non-ws + ws is one delimiter) |
| ` a:: b ` | ` :` | `a`, ``, `b` (the space after `::` joins that delimiter) |
| `a::b` | `""` | one field (an empty IFS disables splitting) |
| `a\tb` | `' '` | one field (a tab is ordinary unless IFS lists it) |
| `a\tb` | startup | `a`, `b` |

The last two rows are why the **decl** had to change as well: bash's
startup IFS is three chars (`" \t\n"`) and the pre-fix decl held one
space, which the hard-coded splitter silently compensated for. The decl
now holds the real value; `IFS[0]` is still `' '`, so every join face
(§28, §28b) is unchanged.

Source: `_sh_split` is now driven by two membership probes
(`_sh_ifs_ws`: `' '/\t/\n` **and** listed in IFS; `_sh_ifs_nw`: listed
and not whitespace) and the loop is the POSIX delimiter-unit algorithm —
scan a body, terminate the field in place, then consume one unit
(`ws* nw? ws*`), with an empty IFS returning the whole value as one
field.

The denotation (`fields_fuel` / `ifs_fields`): `has_ch` (IFS
membership), `ifs_ws` / `ifs_nw` / `ifs_delim`, `skip_ws`,
`field_end`, `unit_after` (the delimiter unit), and the loop over an
explicit fuel. **Fuel is exact, not an approximation**: `fields_saturated`
proves any `k >= len - i` gives the same field list as `len - i`,
off the progress lemmas `skip_ws_ge/le`, `field_end_ge/le`,
`unit_after_gt/le`, `nxt_gt`.

One proof-engineering finding worth recording: `s[i]` written directly
in a recursive spec's body makes that term **stuck** whenever `i` is not
provably in range, and a stuck term means the recursive spec never
unfolds — no lemma about it can be proved, with or without
`--triggers-mode silent` (bisected on a one-file reduction: the same
function with the index hidden behind a total predicate `ws_at(s,ifs,i)`
verifies immediately). Every index inspection therefore goes through
`ws_at` / `nw_at` / `delim_at`, each guarded `i < 0` / `i >= len`
first. The `i < 0` arms also keep the specs total.

Pins `f1`-`f11` are the table above, `by (compute)` over literal
sequences; `f11` is the mutant — `blank_runs` transcribes the RETIRED
splitter (`skip_blank`/`blank_end`/`blank_count`, no IFS read) and the
obligation is that the two denotations **differ** on `a::b: c` under
`':'` (4 vs 2). Negative control: changing `f2`'s expected field list
turns the file red (91v/1e, restored to 92v/0e), so the pins are not
vacuous.

Measured: `harness/ifs-probe.sh` **53 PASS / 0 FAIL / 6 XFAIL / 0 XPASS**
(cases 41-50 are the splitter, 51-51c the `$IFS` read, 52/52b the empty
word, 53-53c the fallback slice, 32-40 the slice faces of §28b); the C corpus gate **PASS=605 FAIL=39 SKIP=7 with a
failure list byte-identical to the pre-change run**, which is the result that matters here —
`_sh_split` sits on the common unquoted-expansion path.

**One of the two adjacent gaps found here is now closed** (same
round). An IFS the program never ASSIGNED used to read `""` through the
variable face, because those reads reach `_sh_env` = `getenv`, not the
buffer the splits consume — so `$IFS` DISPLAYED a different value than
the one splitting used, and `${#IFS}` said 0 where bash says 3. Two
fixes, because the read arrives by two routes: `store_ref` returns the
bare `IFS` ident for that name (the buffer IS its store; the per-var
hoist deliberately skips it, so `has_c_decl` was false), and `_sh_env`
itself answers `"IFS"` from the buffer, which covers the shapes that
bypass the store path entirely (`${#IFS}`, `getVar`, indirect reads).
`getenv` was never the right source: bash IGNORES an inherited IFS at
startup and re-creates its three characters. Measured: `${#IFS}` = 3 and
`$IFS` renders `" \t\n"` unassigned, 1 and `":"` after `IFS=:`, and the
split of `a::b` is still `a`, ``, `b`. Model: `f12` (the startup buffer
is exactly three chars, each IFS whitespace) and `f13` (it holds nothing
else — `:`, `,`, `a` are not delimiters of it), so the value the
splitter consumes is proved to be the value the variable face publishes.

The remaining adjacent gap stays pinned as `xfail` — and it turned out
to be **out of a backend's reach**, which is worth recording precisely.
An empty UNQUOTED expansion must contribute ZERO fields (bash:
`e=""; for w in $e` iterates 0 times) while a QUOTED `""` is one empty
field; the C `for` lowering emits a one-element list for both. The two
programs lower to **byte-identical shIR**:

```json
{"type":"For","var":"w","iter":{"type":"Array","elements":[
    {"style":"DoubleQuoted","type":"Str","value":""}]}}
```

`StrStyle` is `SingleQuoted | DoubleQuoted | Command | Heredoc | Raw`
(`ir.rs:304`) — there is no value for "came from an unquoted expansion",
so the origin is already lost when a backend sees the word. Doing this
in the renderer would be a guess, and adding the variant to the shared
enum is a single-owner core change (`AGENTS.md`: the core stays
single-owner during the lowering phase; transforms are the marketplace).
So it is filed as `core-requests/c-20261104-unquoted-empty-word.md` with
the repro, the identical-shIR evidence, the minimal patch
(`StrStyle::Unquoted`, carried through the `copy_propagation`/
`interp_fold` folds) and the acceptance test. The model states the
contract that fix must meet: `f14` (an empty value splits to ZERO
fields) and `f15` (the one-element empty list the renderer emits is
provably different from it) — both `by (compute)`, so the day the fold
carries the origin, the pins are already there to check it against.
Battery case `52b` guards the half that must NOT change: a quoted empty
word stays ONE field. `_sh_arr_slice`'s own helper still splits on a
space only, so `word_spans`/`arr_slice` above keep modelling it
unchanged.

### 20c. The fallback slice is the inverse of its OWN join (2026-11-04)

`_sh_arr_slice` is the arm taken by an array whose storage the emitter
cannot walk: `array_join_all_face` produces a string and this helper
slices it back into words. The join uses IFS[0] for `${a[*]}` and a
literal space for `${a[@]}`; the helper split on a space
unconditionally, so with `IFS=:` the word COUNT was wrong:
`a=(x y z); ${a[*]:1:2}` joined to `x:y:z`, then split into ONE word and
returned the empty value (`bash`: `y:z`).

The helper now takes `sep` and splits on exactly it. Two details are
load-bearing and are stated, not assumed:

- **it is the inverse of its own join, not bash's field splitting.** The
  join only ever inserts `sep` BETWEEN words, so words = 1 + occurrences
  and `:x` is two words (`""`, `x`) while `x:` is two (`x`, `""`). That
  is the OPPOSITE of `_sh_split`, where a trailing delimiter adds
  nothing — the two functions consume different things (user text vs its
  own join) and the model keeps them apart: `sep_fields` (keeps empty
  fields) vs `ifs_fields` (§20b, drops them).
- **empty fields are kept.** The retired scan skipped leading spaces, so
  `a=("" x)` joined on `:` came back as one word.

Denotation: `sep_at`, `sep_end`, `sep_fields_fuel` (fields <= len + 1),
`sep_fields`, `arr_slice_sep` (the same b/e arithmetic as the store
arms, then the selection re-joined with `sep`). Pins: `g1` (`x:y:z` on
`:` is three words; `[1,2)` is `y:z`; `[1,1)` is `y` — the reported
defect), `g2` (the whole range round-trips, and a SPACE split of `x:y:z`
is one word — why the separator must match), `g3` (`:x` keeps its empty
field), `g4` (the default IFS is unchanged: `x y z` slices to `y z`),
`g5` (an empty join has NO fields, so any slice is the empty value).
Negative control: `g2`'s space-count flipped to 3 goes red
(`expression simplifies to 1 == 3`, restored 103v/0e).

The output FACE (`IFS[0]` for `*`, IFS[0]-else-space for `@`, §28b)
stays with the exact store-based arm `_sh_join_arr_rng`; this arm
re-joins with the separator it split on, which is the faithful round
trip for an array whose storage it cannot walk.

Measured: battery `harness/ifs-probe.sh` **53 PASS / 0 FAIL / 6 XFAIL /
0 XPASS** (cases 53-53c take the fallback through a function-local
array; with `IFS=:` the pre-fix arm returned `""` where bash returns
`q:r`); the C corpus gate **PASS=605 FAIL=39 SKIP=7, failure list
unchanged**. A TYPED array (`declare -ia`) turned out to CRASH — dense
`long long[]` storage handed to `_sh_join_arr_sep`, which walks `char
**` (ASAN: SEGV in `_sh_join_arr_sep`, read at 0x1). That is
pre-existing and independent of *this* fix, so it was pinned as
`54_xfail_dense_int_array` in the round that found it; the next section
closes it.

### 20d. The dense-value join, and closing the SIGSEGV (2026-11-04)

`declare -ia a=(1 2 3); echo "${a[*]}"` lowered to C that **compiled and
then died** (rc 139): the width analysis gives a typed array DENSE
integer storage (`long long[]`, or the narrowest width that fits the
elements, or the growable-vec pointer form), while the whole-expansion
join routed every non-assoc array through `_sh_join_arr_sep(_sh_vbuf *,
`char **a`, `size_t`, `char`)`. Slot 0 held `1`, so the helper dereferenced
`(char *)1` — ASAN reports the read at `0x1`.

**Why the fix is in the renderer and not the helper.** A `const long
long *` parameter cannot serve the site: the element type is per-array
(`long long` / `int` / `int32_t`, plus the vec form), and casting `int
*` to `long long *` reinterprets 4-byte slots as 8-byte ones. So
`array_join_all_face` emits the fold INLINE, converting each element
with `_sh_ll2s` (exact for every width; the trim pass keeps the helper
because the rendered text names it). The separator discipline is the
SAME fold the char** helper uses — `if (_jdi)` writes the separator on
every element except the first, and `sep == 0` (an empty IFS) writes
none — which is what makes this a routing change rather than a second
join. The `mpz_t[]` array-return storage shares the old type confusion;
it takes the same inline arm via `mpz_get_str` instead of falling
through to `char **`. That arm is NOT measured end-to-end (reaching it
needs a program that both lifts an array-returning function and joins
its result; no example does), and is written so the shape cannot reach
the pointer helper if one ever does.

**Denotation extension** (`c_join_ifs.rs`, §28's model): `dense_join(sep,
xs)` = `join_sep(sep, xs)` over the DENSIFIED element list, and
`dense_face(star, xs, ifs)` selects `ifs_sep(ifs)` for `[*]` and
`Some(' ')` for `[@]`. The distinction from the char** faces is the
ELEMENT LIST, not the separator: `star_join`/`at_join` take
`present(slots)` (a NULL slot IS unset), dense storage has no presence
marker so its list is `densify`'s (a zeroed slot is the integer 0).
Mutants each kill one obligation.

Pins (bash MEASURED 2026-11-04):

- `d1` — `${a[*]}` on the startup IFS is `1 2 3` (the defect itself);
- `d2` — `IFS=` joins with NOTHING (`123`), so the separator cannot be a
  literal;
- `d3` — `[@]` is a space under `IFS=:` (`1 2 3`) while `[*]` is `1:2:3`,
  and the two faces therefore DISAGREE on one array;
- `d4` — the dense list and the presence list of the same array differ
  (`7:0:9` vs `7:9`): the value half of the type confusion, and the
  obligation a future "unify the two joins" refactor fails;
- `d5` — the boundaries: zero elements join to the empty string (both
  faces), one element keeps no separator, an empty IFS on one element is
  the element;
- `d6` — the k-1 separator count, on the total length (`+2` for three
  elements on a one-char separator, `+0` for an empty IFS);
- `d7` — the dense join IS the shared fold (`dense_join(s, xs) ==
  join_sep(s, xs)`, plus the `forall` on `None`).

**Scope, stated plainly.** Verus cannot see C types, so it cannot state
"this pointer is the wrong type". Nor did the C gate catch it at compile
time: MEASURED on the gate's own compiler (GCC 13.3) the old shape is a
`-Wincompatible-pointer-types` **warning**, not an error — it compiled
and then died at runtime (rc 139); GCC 14+ promotes that diagnostic to
an error. So the type side is a RUNTIME check here, and the probe
battery is what catches it. What the model states is why the routing is
*required* rather than cosmetic (`d4`) and what the dense face must
compute (`d1`-`d3`, `d5`-`d7`). Negative control: collapsing
`dense_face`'s `[@]` arm into the IFS arm fails `d3` ("`['1',':','2',':','3'] ==
['1',' ','2',' ','3']` evaluates to false"), restored 61v/0e.

Measured: battery `harness/ifs-probe.sh` **59 PASS / 0 FAIL / 6 XFAIL /
0 XPASS** — the old `54_xfail_dense_int_array` is retired to a PASS
(`1 2 3`), 54b-54f add the faces (colon, empty IFS, `[@]`), the integer
extremes (`-1 0 -9223372036854775807`) and the dense SLICE, which takes
the §20c fallback and so also checks that the fallback's separator
agrees with the dense join's; 55 pins the REMAINING documented dense
edge, which is not a join bug: value storage has no presence marker, so
`n[0]=7; n[2]=9` is `3 7 0 9` where bash says `2 7 9` (that case was a
crash before, and is now merely the documented wrong). Nine direct
probes agree with bash except that same sparse case, and all nine are
**ASAN+UBSAN clean** (`-fsanitize=address,undefined
-fno-sanitize-recover=all`, `detect_leaks=0`) — the check that matters
for a memory defect.

Corpus gate: **PASS=606 FAIL=38 SKIP=7**. Diffing the failure NAMES
against the previous round's run (`PASS=605 FAIL=39 SKIP=7`) gives
exactly one recovered example, `064_18_array_slicing_manipulation.sh`,
and **no** new failure — and that one is the §20c fallback-slice fix,
not this one: no corpus example uses `declare -ia`, so the dense join's
corpus delta is zero by construction (it removes a crash no example
reaches, which is exactly why the probe battery is the instrument for
it). An earlier gate run (599/45/7) was taken WHILE the CLI was being
rebuilt and is invalid: seven of its failures were "stub", the signature
of a binary replaced mid-run — do not rebuild during a gate.

### 20e. Dense storage gains a presence marker; `${!arr[@]}` compiles again (2026-11-04)

The §20d round closed the type confusion but left the documented dense
edge standing: value storage has no per-slot marker, so a hole was
indistinguishable from the integer 0. Bash tracks the SET, and the
divergence was measurable in four places — count, join, keys and element
reads:

```
declare -ia n; n[0]=7; n[2]=9
  ${#n[@]}   bash 2   C 3
  ${n[*]}    bash `7 9`   C `7 0 9`
  ${!n[@]}   bash `0 2`   C `0 1 2`
  ${n[1]}    bash ""    C "0"
```

Fixed dense integer arrays now emit a parallel byte-per-slot marker
`{id}_set[{cap}] = {0}`, and every reader consults it: count is
`_sh_ccount` (a popcount over the extent), the join skips unset slots
(and rides a FIRST-PRESENT flag, since the separator can no longer be
`if (i)`), the key list is `_sh_join_idx` over the marker, and an element
read of an unset slot is EMPTY rather than `0`. Writes mark
(`{id}_set[k] = 1` at the three int store sites), `unset 'n[i]'` clears
the bit, and every reset (`arr=()`, `unset arr`, the empty literal)
memsets the marker — without that, a later write past a former hole
exposes a phantom element.

**Why the marker and not a smarter value check.** A present element can
hold 0: `declare -ia a=(0 0 0)` counts 3 and prints `0 0 0` (MEASURED),
so presence cannot be derived from the value — this is pin `e6`.

**One `${!arr[@]}` finding that is not the renderer's.** The expansion
was a hard COMPILE error before this round: `array_keys_join` forced
every var into `assoc_arrays`, so `${!n[@]}` on dense storage emitted
`n_k`/`n_v`/`n_n` — storage the decl never declared (and the assoc
classification then poisoned every later reader). It now dispatches on
the storage class (assoc key list / char** set slots / dense indices).

The FACE of that expansion is still lost upstream: `${!n[*]}` and
`${!n[@]}` lower to the SAME shIR (`param("slice", "!n", "@", "")`)
while the values face keeps its distinction, so the keys join cannot
know it was `[*]` and uses the `[@]` space (`bash` with `IFS=:`:
`0:2`). That is core territory (`shIR` lowering, single owner), filed as
[core-requests/c-20261104-keys-face.md](core-requests/c-20261104-keys-face.md)
and pinned as `56_xfail_keys_star_face`; `array_keys_join` already takes
the face, so it goes green when the face survives.

**Denotation** (`c_join_ifs.rs`): `dense_marked_join` = `join_sep` over
`present(slots)` — with the marker the dense element list IS the char**
list — so `dense_marked_face` is provably `join_face` for both faces
and any IFS (`e4`). `dense_count` = `|present|`, `dense_get` = the slot
or empty, `dense_clear` = the slot removed, `present_idx` = the set
indices ascending. Pins: `e1` the whole sparse reading, `e2`
popcount-vs-extent, `e3` keys `0 2`, `e5` `unset` removing the element,
`e6` a real 0 being present, `e7` the RETIRED extent protocol
disagreeing on the same array. Mutant: routing `dense_marked_join` back
through `densify` fails `e1`/`e4`/`e7`. Model 69v/0e.

**Scope, stated plainly.** The growable-VEC form (`static T *id` +
len/cap) and `mpz_t[]` array-return storage keep the extent rule: their
presence buffer would need the same realloc dance at every growth site,
so `dense_presence` excludes them and the documented edge survives
there. Two further divergences the probe battery exposed are pinned,
NOT caused here: `arr+=(x)` on a sparse array re-literalises the whole
array (the hole becomes a real 0), `arr+=(a b)` on a dense array drops
the appended elements, and an ARITHMETIC subscript write
(`n[$((i*2))]=5`) routes the array to assoc storage so the C does not
compile (a bare `$i` subscript works).

Measured: battery `harness/ifs-probe.sh` **65 PASS / 0 FAIL / 9 XFAIL /
0 XPASS**, rc 0 — `55_xfail_dense_sparse` retired to a PASS and 55b-55e
added (unset, key loop, reset-then-write, a real zero); six dense shapes
ASAN+UBSAN clean; corpus gate **PASS=606 FAIL=38 SKIP=7**, unchanged
from §20d (no corpus example uses `declare -ia`, so this round's corpus
delta is zero by construction and the battery is the instrument). The
battery's cc-failure branch now counts an `*xfail*` case's compile
failure as XFAIL — a pinned "the C does not compile" gap is a known
failure, not a regression.

### 20f. `arr+=(…)` on dense storage: two defects (2026-11-04)

The §20e round pinned `declare -ia a=(1 2); a+=(3 4)` as a known red.
Two separate causes, both in the renderer:

1. **The appended elements were stored but never MARKED.**
   `emit_set_array_append` emits the stores and raises `_len` but set no
   presence bits, so the count and the join (which now read the marker)
   could not see them: `2 [1 2]` against bash's `4 [1 2 3 4]`. This was
   introduced by §20e itself — the literal store sets its bit, the
   append store did not — and is exactly the class of gap the probe
   battery exists to catch (no corpus example uses `declare -ia`).
2. **The append base is the last SET element, not `_len`.** MEASURED:
   `i=(5); unset 'i[0]'; i+=(6)` appends at index **0** (bash: `1 [6]`,
   keys `0`) while `_len` is still 1; `d=(1); d[3]=9; d+=(5)` appends at
   **4** (bash `3 [1 9 5]`, keys `0 3 4`). A marked array therefore
   scans back for the last present slot, and its extent becomes
   max(base + n, `_len`) rather than `_len + n`.

Along the way the cap estimate turned out to compete with appends
instead of adding to them: `max(reset + appends, idx)` gave 4 for
`d=(1); d[3]=9; d+=(5)`, which needs 5, so the runtime guard exited 127
where bash has three elements. It is now
`max(reset, idx, counter_idx) + appends` — appends come AFTER whatever
the other terms leave. Growing a cap is always the safe direction: the
guard still exits 127 loudly if the estimate is ever short.

**Denotation** (`c_join_ifs.rs`): `last_set` (an index recursion, so the
`compute` obligations unfold), `append_base` = last_set + 1,
`append_count` = popcount + k. Pins: `f1` the five bases (dense, sparse,
emptied, literal, empty array), `f2` `_len` is NOT the base — the
emptied case is exactly where they split (using the extent would leave a
phantom slot 0, count 2 where bash says 1), `f3` the post-append count.
Mutant: `append_base := slots.len()` fails f1/f2 (`1 == 0`). Model
73v/0e.

Measured: battery **69 PASS / 0 FAIL / 9 XFAIL / 0 XPASS** —
`58_xfail_dense_append` retired to a PASS, 58b-58d added (chained
appends, append-after-unset, the cap case); the six append shapes are
ASAN+UBSAN clean; corpus gate **PASS=606 FAIL=38 SKIP=7**, unchanged
from §20e, i.e. the wider caps changed no example's verdict. Still
pinned: `arr+=(x)` on a SPARSE array (the `+=` routes the array to the
growable VEC form, which `dense_presence` excludes, so it keeps the
extent rule), and an append whose items are expansions
(`e+=($x $((x+1)))`), which falls into a malformed `bash -c` emission
(rc 2) — pre-existing and shared with string arrays.

- v10b (2026-10-28): **the decl-coverage family closed** — v10's single
  `param`-arm fix extended to every place a `${NAME:=…}` write can hide,
  plus one adjacent render defect found on the way, all in
  `sh2perl/src/c_backend.rs`:
  1. **three censuses, one invariant.** `collect_store_expr` (store census),
     `collect_assigned_expr` (the `has_c_decl` gate), and the const-lift
     veto `collect_param_write_targets` now all carry the writing-param arm
     the write-arms of the render dispatch imply — plus structural
     forwarders (`Arrow` → stmt walk; the `Case` discriminant; and
     `Exec`/`DeclareArray`/`WriteFile`/`SetChildError` stmt arms) so the
     walk reaches every position. Write ops only, mirroring v10: a
     read-only param must stay env-homed or its value is nulled out.
  2. **`Return` (the echo-return transform's `fn ${y:=…}` shape)** and the
     `fn` body's `Return(param(...))` form had no arm at all — the fn3 probe
     showed even a top-level *read* arriving as `param("", "y")`, entering
     no census.
  3. **raw-text writes** — `${y:=${z:=K}}` arrives as a single `Str`
     `"${z:=K}"` (the core keeps a param's default word as raw text) and is
     re-parsed at *emit* time by `default_word` → `heredoc_body_c`, i.e.
     AFTER the decl hoist froze its set, so the write came out aimed at an
     undeclared `z`. New `scan_raw_assigns` reads `=`/`:=` targets out of
     the raw text (skip single-quoted; skip `\$` escape) in all three
     censuses.
  4. **`_sh_vbuf` unknown type** — `vbuf_temp()` emitted
     `static _sh_vbuf _vN = {0,0};` naming a typedef that exists only under
     `if self.need_sh`. A site reaching a grow buffer with `need_sh` false
     (the native `printf`'s `${x:=…}` with `var_expr` a store ident, so no
     `_sh_env` read ever trips `need_sh`; the `char[N]` `strcpy` write the
     same) produced a C compile error mid-render. `vbuf_temp` now sets
     `need_sh = true`; the runtime trim pass keeps only referenced helpers,
     so a forced-on `need_sh` costs nothing when unreferenced.
  Verification: an 12-case probe battery (`/tmp/decl_probe.sh`) putting
  `${y:=…}` at every statement position — assign, if, while, block, sub,
  redirect, case, fn, pipeline, exec, nested, array-element — is
  **12/12 green** (compile + stdout match vs bash). Full gate
  `harness/c_gate_main.sh`: **593 pass / 51 fail / 7 skip** vs v10's
  578/66/7 — 15 fewer reds, zero new (the 9 `posix-sh-go/testdata` ccs and
  the `process-subst`/`brace-fold` exec-diffs are the pre-existing classes
  §14a already bisected away). `t04_params` freshly re-rendered still
  matches bash.

- v10 (2026-10-28): the C gate's ONE new red against the HEAD baseline
  (t04_params.sh, `cc`: `y` undeclared) root-caused to a latent decl
  gap, not to v9's changes. The rewritten `dead-store-elim`
  (`dead_store_elim.rs`, +1252) plus `copy-propagation` inlining every
  later read soundly drops `y="hello world"` — and with the Assign gone
  the C backend never declared `y`, because `${y:=assigned}` carries its
  target as a STRING arg (`Call{param}` args[1]), which pass-1
  collection only saw via Assign targets, `printf -v`, `let`, and
  `IrExpr::Var` reads. HEAD masked the gap by keeping the (dead) store.
  Fix in `sh2perl/src/c_backend.rs`: `collect_vars_expr` now collects
  `param` `=`/`:=` targets as declaration sources (the same precedent as
  `printf -v`'s), writing ops only — every other param op reads the var
  or writes a temp. Gate measured: 578 pass / 66 fail / 7 skip vs the
  HEAD baseline's 71 fails — zero new failures, the five §14a reds stay
  fixed, t04 now compiles and its stdout matches bash (rc 0/0).

- v9 (2026-10-28): the §14a hazard is FIXED IN SOURCE — four changes
  in `sh2perl/src/c_backend.rs` (the either-side string trigger with
  `value_c` stringify; `continue`/`break` status writes — bash's special
  builtins set `$? = 0`; the word-for arm's missing `loop_depth`, which
  also silently DROPPED break/continue at two sites; and owned
  `_sh_sset` stores for expression-position heap assigns, the
  func-after-test-or `free(literal)` abort). Three of the five measured
  reds now pass the C gate; the other two bisected to `process-subst`
  and `brace-fold` — separate bugs, open. The Verus model
  `c_eqne_emit.rs` now models the FIXED decision (`decide` carries the
  either-side trigger, `c_eval` is total through `value_c`'s itoa) and
  keeps the pre-fix one as `decide_old`, the mutant
  `shipped_mixed_pair_fixed_sound` drops into — still 11 verified,
  0 errors, registration unchanged.

- v8 (2026-10-28): §14 — two more render-discipline obligations
  mechanized: the Eq/Ne emission decision (`c_eqne_emit.rs`, 11) and the
  decimal renderers (`c_dec_str.rs`, 26, four mutants), with the shIR-side
  round trip and width theorems in `proofs/ArithIdentity/ArithDec.thy`.
  Both gates re-run green: `verus-gate.sh` 43 passed / 0 failed (26
  models + sync coverage; `elim_trio`'s previously failing coverage check
  is now repaired by the other lane), `transform-proofs.sh` 5
  checked-and-built / 1 pre-existing failure (`proofs/` root,
  `Maskable.thy`, another lane). Proof artifacts only; no transpiler
  source and no generated-code behaviour changed.

- v6 (2026-10-22): P3's fixed-buffer half mechanized (`verif/P3_Buffer.thy`),
  closing P3. P4 recorded as blocked on the absent `C-Parser`/`AutoCorres`
  toolchain (§12). All four theories build together, no `sorry`.

- v5 (2026-10-22): P1 mechanized and committed (`verif/P1_Narrowing.thy`);
  the datatype case-split defect is isolated and worked around, not hidden.
  All three staged theories (P1, P2, P3-capacity) build together.

- v4 (2026-10-22): P3's capacity half mechanized and committed
  (`verif/P3_Capacity.thy`); the `strlen ≤ N` half remains. P1 still red.

- v3 (2026-10-22): P2 mechanized and committed (`verif/P2_Checked.thy`,
  `verif/ROOT`); Isabelle 2025-2 obtained from `mirror.clarkson.edu`
  (tum.de unreachable) and driven headless. P1 remains red.

- v2 (2026-10-22): Step 0 executed. `harness/c_gate_ubsan.sh` added with
  live positive controls; 652/652 compiled programs sanitizer-clean; the
  width class found live-but-invisible to sanitizers (10 signed→unsigned
  truncating stores in 9 files by `-Wconversion`, incl. the
  `uint8_t = 15 + _sh_pow(5,2)` store); P1 obligation sharpened to include
  the store-side range check. Two measurement corrections: signed narrow
  types do not occur in the corpus at all. Three measurement traps had to
  be cleared to learn this (word-boundary grep; `OTRANSPILER_ROOT` making
  an unpinned sweep render empty input; `$(grep -c)` losing a pipeline),
  and the final sweep is validated by an in-corpus positive control — see
  §7's "Measurement discipline".
- v12 (2026-11-04): the flattened-subscript round — §20g. ONE classifier
  (`c_subscript.rs`, 37 obligations) now drives the declaration census and
  the store arm, pins k1-k16 are bash's measured truth table (including the
  assoc asymmetry: explicit `$((e))` keys by VALUE, a bare operator text by
  its LITERAL), and the DSE half is a liveness obligation
  (`subscript_closure` / `dead_needs_no_mention`). Fixes 59/59b-59m; battery
  81/0/9; C gate 606/38 -> 613/31 with zero new failures; ASAN clean.
- v1 (2026-10-22): initial assessment and plan; no code changed, no
  sanitizer run performed yet.

### 20g. The flattened subscript: one text, three verdicts (2026-11-04)

The core leaves an element write's subscript as TEXT inside the target
name — `n[$((i*2))]=5` arrives as `Assign{ targets: [{ var:
"n[$((i*2))]" }] }` with `indices` EMPTY — so the renderer, the
declaration census and the dead-store census each had to read that text
themselves. They disagreed, in both directions, and every disagreement was
a red the gate could not see:

| subscript          | bash (measured)     | before                                    |
|--------------------|---------------------|-------------------------------------------|
| `n[$((i*2))]`      | index 4 (`i=2`)     | **does not compile** (`n_k` undeclared)   |
| `n[i*2]`           | index 4             | assoc key `i*2` — count right, keys wrong |
| `n[$i+1]`          | index 3             | **does not compile**                      |
| `n[i]`             | index `i`           | **does not compile** (store not "known")  |
| `n["1"]`           | index 1             | assoc key `"1"`                           |
| `n[(i*3)+1]`       | index 7             | assoc key `(i*3)+1`                       |
| `a[$((i+2))]` read | `a[3]`              | read index **0** (`p` for bash `r`)       |
| `m[$((i*2))]`      | key `"2"`           | key `"0"` (empty expansion)               |
| `i=3; n[$((i))]=9` | index 3             | `i=3` **deleted** by DSE, `i` undeclared  |

The declaration census called an operator text a STRING KEY (so an int
array was declared indexed and the store wrote `n_k`), the store arm
called a bare ident a string key unless it happened to be in its own
store/type map, the read path never stripped a `$((…))` wrapper (so its
`$`-scan stopped at the `(` and the index was 0), and the assoc key path
handed `$((…))` to the heredoc word expander, which does not evaluate it
inside a subscript.

**The denotation** (`proofs/verus/c_subscript.rs`, 37 obligations).
bash has exactly two rules and they are not symmetric:

    INDEXED   the subscript is an ARITHMETIC EXPRESSION — a numeral, a
              bare name (its value, 0 when unset), `$name`, `$((e))`, or
              an operator expression. Quoting does not matter.
    ASSOC     the subscript is a STRING after EXPANSION: `$((e))` is the
              DECIMAL of its value, `$name` the variable's text, and a
              BARE operator text stays LITERAL (`m[i*2]` → key `i*2`).

That asymmetry is why the two predicates are separate —
`subscript_explicit_arith` (the assoc key) versus `subscript_arith_inner`
(the index) — and it is pinned: `k14`/`k15`/`k16` give `m[i*2]` the
literal key `i*2` and `m[$((i*2))]` the value key `2`, so one script
prints bash's `2 [i*2 2]`. A single-verdict reading of "arith" could not.

`classify` is now the ONLY verdict: from the text alone it returns
`Arith | Num | DynVar | Ident | ArithText | Word`, and BOTH consumers are
defined from it — `census_assoc` (the declarations) and `store_assoc`
(the store arm). `decl_and_store_agree` is then the invariant, with the
one side condition the source really has (`$`-prefixed texts are dynamic
indices, never assoc): the declaration can no longer promise storage the
store does not write. The retired pair is proved divergent on the measured
shapes instead of merely described: `prefix_diverges_on_ident` (`n[i]=v`:
census indexed, store assoc — the `n_k` red) and
`prefix_calls_arith_assoc` (`n[i*2]=v`: both assoc, so it compiled into a
table whose keys bash never had).

**Liveness.** The text is opaque to every IR analysis, which is a second,
quieter bug: `i=3; n[$((i))]=9` kept 2 of 3 shIR statements, because the
only mention of `i` was inside the name. `transforms/dead_store_elim.rs`
now censuses the subscript's names (`subscript_read_names` =
`string_read_names` for `$name`/`${name}` plus `arith_read_names` for the
bare runs), and the model states the obligation rather than the patch:
`subscript_closure` (a name mentioned in a subscript is in the read set)
and its contrapositive `dead_needs_no_mention` (a DEAD store mentions the
name nowhere), with `fix_was_necessary` pinning that the pre-fix set is
exactly `{n}`. The census over-approximates on purpose — an assoc table's
literal key spells a name that is not read — and that direction is stated
(`ident_key_over_approximates`): it keeps a store alive that nothing
reads, never drops one.

**Measured.** `harness/ifs-probe.sh` **81 PASS / 0 FAIL / 9 XFAIL / 0
XPASS**, rc 0: case 59 (the old `x`fail) retired, 59b-59m added — the six
indexed forms, the string-array form, both read faces, the assoc key pair,
and the store-only-in-the-text case. C corpus gate **PASS=613 FAIL=31
SKIP=7** — seven examples fixed with zero new failures (063_09, 064_21,
eq-string-num-var, func-after-or-assign, func-after-test-or, or-continue,
param-expand-default-operator), which is the DSE half: those scripts had a
store read only through an array subscript. The new shapes are ASAN+UBSAN
clean; `transforms::dead_store_elim` gained a unit test over five subscript
forms plus the no-mention control.

**Still open, pinned not papered over.** `${i}` (the core keeps the
braces): the store arm's `k.starts_with("${")` branch routes it to assoc
while the census excludes every `$`-prefixed text — `assoc_dollar_brace_remains`
proves the disagreement, which needs the core to split the subscript.
And a narrower find: an INT array's element read next to its count in one
printf lowers through the ARGV path (`_sh_idx_init(…, n, n_len)` with
`char **` where `n` is `long long[]`), which SIGSEGVs — pre-existing,
independent of the subscript work, now pinned as `60_xfail_int_argv_face`.

## 21. Capture/wrap quoting — `c_capture_wrap.rs` (16 obligations)

The injection-freedom boundary: `_sh_wrap_cmd` builds
`bash -c '<q(cmd)>'` with the `'"'"'` splice, so no byte of the
command can terminate the single-quoted word — a quoting bug here is
RCE, not a wrong value. `_sh_system_rc`/`_sh_capture` map
`system`/`popen` results (`-1 → 127`, exited → status, else 1) and
the capture strips trailing newlines with the empty-command early arm
(rc 0, not 127). The word family (`_sh_word`/`_sh_bword`/`_sh_baddq`)
shares the splice core; `_sh_addqn`/`_sh_baddqn` quote iff a newline
is present; `_sh_sc` restores NULL-safety.

What is proved (12 proof fns, 16 verified): `quote_splice_sound`
(the 5-char splice shape); `wrap_injection_free` (THE OBLIGATION —
every `'` becomes the splice, every other byte literal, so the
wrapped command parses as exactly `bash -c '<q(cmd)>'`);
`wrap_needs_bound` (the `n*2+16` first-allocation bound, honestly
scoped — worst-case all-quote input needs 5n+10, and the argv tail
re-grows per word); `word_quote_sound` (all three spellings);
`baddqn_newline_gate`; `status_mapping` (total + disjoint three
arms); `capture_empty` + `capture_strips`; `sc_null_safe`;
`quote_len`/`quote_len_agrees`/`quote_splice_lens` (length
infrastructure); pins (`"don't"` — with the length 9 the proof found,
correcting the written 8 — exit-3, signal-death→1, popen-fail→127).

House lessons: spec-call unfolding on push-chains needs the
sub-evaluations bound (the `"don't"` length needed the full
splice-length chain); strip unfolds need the last-char + subrange
bridges; the pin's 8 was wrong and the proof corrected it to 9
(d,o,n literal + 5-char splice + t) — recorded, not hidden.

Honest: vbuf growth proved in §25 (`c_vbuf.rs`); `system`/`popen`
execution is the OS contract; argv-tail gating unmodelled.

Negative control: the bare-quote splice (a `'` mapping to itself —
the injection hole: a quote in cmd terminates the word) goes red
(13v/3e — splice shape, injection-freedom, and the `"don't"` pin all
fail), restored to 16v/0e.

## 22. The decl-coverage censuses — `c_decl_coverage.rs` (54 obligations)

v10/v10b's source-level story, made checkable. The C backend runs three
independent censuses over shIR — the HOIST census (`hoist_vars`, via
`collect_store_expr`, which decides `has_c_decl` and the file-scope
decl list), the store/inventory census, and the read-routing census —
plus the CONST-LIFT VETO (`collect_param_write_targets`), and every
undeclared-variable red this month (t04, the elsif-cond-in-fn shape,
the for-iter write, the top-level select menu) was one of these walkers
missing a write's arm shape. The model transcribes all four walkers
verbatim over a datatype rendering of shIR (`Expr`/`Stmt`/`Ch` modes),
with `word_scan`/`param_gate`/`printf_v_target`/`let_target` mirroring
the emit dispatch's own shape predicates.

What is proved (54 verified):

- `coverage_s`/`coverage_x`/`coverage_e`/`coverage_seq` — THE
  OBLIGATION: every write a statement, expr, or sequence carries is
  seen by the HOIST census (`writes ⟹ col_Hoist`), established
  arm-by-arm with per-arm bridge asserts so a dropped arm in the model
  fails loudly (this is the invariant the six source fixes restored:
  after (a)-(d) hoist covers every write alone, and the union covers
  the rest);
- `veto_exact_s/e/x/seq` — the const-lift veto's set is EXACTLY the
  param/raw write positions, both directions (`col_Veto ⟺ paramw`):
  sound (no read ever vetoed — a vetoed read stays env-homed and
  loses its value) and precise (no write slips through to an
  env-homed null);
- the param/raw bridge (`paramw_s` ⟺ the writes the emit dispatch's
  `param` arm implies) tying the veto back to `writes_s`;
- pins over the measured corpus shapes: t04's `${y:=…}` params,
  while-cond `printf -v`, elsif-cond-in-fn, the echo-return
  `Return(param(…))` form, a top-level `select` menu param write,
  printf/let in fn scope (hoist standing alone — no other census is
  consulted at fn-local decl time), and the raw-text
  `${y:=${z:=K}}` default word.
- `pin_assign_chain` (v20, 2026-11-04) — the expr-position `assign`
  arm. `true && x=v || y=w` carries its write as an ARM OF A CHAIN
  EXPRESSION: no `IrStmt::Assign` ever exists, so every statement arm
  misses it, and the read of `x` resolved to `_sh_env("x")` (the
  ENVIRONMENT) while the write went to the C variable — measured: the
  echo printed an empty value for the variable it had just assigned.
  The arm takes args[0]'s BASE before the first `[` (`base_of`), keeps
  it when `is_ident` (so an element write `n[i]=v` hoists `n`, and a
  non-identifier base invents no name), then walks args — extraction
  AND recursion, the printf/let/param shape. The pin asserts the HOIST
  answer and, fidelity-both-ways, that the INVENTORY and VETO walks
  still do NOT see it: neither a decl site nor a `${NAME:=…}` position
  can be an `assign` call, so acknowledging one there would be a false
  `declared`. (`raw_hits_needs_three` is what makes that negative
  cheap: a text shorter than 3 chars has no index with `i + 2 < len`,
  so the raw-`${` existential is EMPTY rather than merely unmatched —
  no search, no `compute` blow-up. `compute` on the whole frozen walk
  chain took >10 min and produced nothing; the structural refutation
  takes milliseconds. That is the house lesson for this one.)

House lessons: the two big chain-equalities in `coverage_e`'s Call arm
must be bridged per-arm (disjunct-picking over two independent if-chains
is exactly what SMT fails at — same lesson as the earlier chain);
constructed `seq![…]` in a `decreases` position is not a subterm (use
direct field measures); `spec fn` without `open` is closed to unfolding,
which silently breaks pins; `s1(':').add(s1('='))` push-chains do not
normalize against `seq!` literals (c_width_store's warning, confirmed).

Negative controls (three one-token mutants): dropping the `let` arm
from the hoist chain goes red (50v/1e); dropping `param_gate` from the
veto-mode chain goes red (47v/4e — the veto loses every param write);
flipping `:=` out of the shared write-op gate goes red (50v/1e — the
pins die). Restored: 51v/0e each.

Honest: the walkers are modelled as transcribed from the source on
2026-10-28; traversal is per-position, not end-to-end. (Source-side:
the working tree first carrying these fixes was lost 2026-10-28 and
re-landed from this model — see v18.) **The "no mechanical extractor
bridges a transcription" proviso below is CLOSED (v19):**
`harness/declcov-extract.py` now extracts the modelled walkers' arm
chains (exact pattern text incl. guards + the walker calls each arm
body carries) from the live `c_backend.rs`, and the gate diffs them
against the committed `proofs/verus/c_decl_coverage_sync.txt` — a
dropped elsif-cond arm was caught line-exactly as the negative
control — and it caught this round's drift the same way: the source's
expr-position `assign` arm landed while the model still transcribed
the pre-fix chain, so the sync went red on exactly that line until
the model gained the arm (v20). The pin↔corpus mapping remains the
value-level tie for the other pins (UNMIRRORED by design: the probe
battery + corpus shapes are what cargo cannot run); `pin_assign_chain`
is the exception with a real unit test,
`c_backend::tests::expr_position_assign_routes_to_the_variable`, and
the sync's `[exec]` stage RUNS it. That test is a proven TRIPWIRE, not
a decoration: with the arm's guard disabled it fails and the diagnostic
prints the emitted `_sh_env("x")` read — measured both ways in this
round before the arm was restored.

## 23. The string-literal escaper — `c_str_lit.rs` (19 obligations)

`cstr` (c_backend.rs:11080) is the single funnel for every emitted C
string literal — 178 call sites including heredoc bodies AND the
printf FORMAT string built by `heredoc_body_c`. Its single-byte
escape used to be spelled `\xNN`, and C's `\x` is GREEDILY hex
(C99 6.4.4.4): `"\x01a"` lexes as ONE escape 0x1a. Measured on
2026-10-28 (probe `/tmp/cstr_probe`, cases t1-t8 compiled and diffed
vs bash): control byte + 'a' → stdout `1a` vs bash `01 61`; `"\x019"`
→ `19` vs `01 39`; `"\x01ABC"` → 0x1ABC = 7116 > 255, a
diagnostic-required range violation (invalid C). Three of six first
shapes diverged; the survivors had non-hex followers only. Fixed in
`cstr` by spelling both single-byte arms as 3-digit OCTAL (`{:03o}`):
a fixed-width octal consumes at most those 3 digits, so a following
hex-looking char stays literal — all 8 probe shapes match after the
fix; the C gate re-ran at baseline (see below).

The model's semantics extension is a LEXER DENOTATION for emitted
text: `run(t, st)` reads one char per call through the states
Normal/Esc/Hex/Oct (greedy-hex accumulation unbounded, octal capped
at 3 by a state counter, a breaking char emitted THEN reprocessed),
`flush` turns a still-open token at end-of-input into its value, and
`decode = run + flush`. The state machine is both the faithful C
lexer and what makes termination structural — the substring-jump
formulation cannot prove its own length bounds in spec context (no
spec-level assert, Z3 will not unfold the run-length recursions).

What is proved (19 verified):

- `round_trip` — THE OBLIGATION: `decode(emit(s), Normal) ==
  Some(bytes_of(s))` for every valid string (ASCII + markers): the
  bytes the C compiler puts in the program are exactly the bytes bash
  would have seen;
- `decode_char` — the per-char bridge `decode(emit_char(c) ++ b) ==
  pre(byte_of(c), decode(b))`: each emitted char is self-delimiting —
  the boundary-locality property the hex spelling violates (shown by
  the `emit_old` pins below);
- `decode_pair`/`decode_octal`/`decode_plain` — the three emission
  shapes' step chains; `oct3_value` — `{:03o}` is value-exact
  (`fold_digits(oct3(v)) == v`, 0 ≤ v ≤ 255) and its digits are
  octal; `oct3_break` — a complete token at cnt==3 emits first and
  then behaves exactly as in Normal;
- pins (`by (compute)`): the measured shapes `\001a`, `\0019`,
  `\0017` (7 is octal — still not absorbed), `\n`/`\t`/`\r`, `\"`,
  and marker byte 0xAB → `\263`;
- SHIPPED-HEX DIVERGENCE pins (negative controls): `emit_old` of
  [1,'a'] decodes to `Some([26])` not [1,97] (t1), [1,'9'] →
  `Some([25])` (t5), [1,'A','B','C'] → `None` (t7's out-of-range
  arm) — each asserted against `bytes_of`, so the model cannot drift
  from the measurement if the spelling is ever reintroduced.

House lessons: `Seq.add` associativity is not automatic — bridge with
`=~=`; one `reveal_with_fuel(run, 1)` per step beats a deep reveal
(the 5-deep unfold exploded the branch tree past the wall clock);
`by (compute)` decides every concrete pin outright (the reveal form
timed out at 450 s); digit-range facts must precede the fold unfold.

Negative controls (three one-token mutants): shipping the hex
spelling again → the `\001a` pin computes `Some([26])` and dies;
dropping oct3's MSD → the marker pin computes 15 instead of [1,55];
refusing the Esc octal arm → `None` where [1,97] was promised.
Each red at its own pin, restored to 19v/0e.

Honest: the lexing model is the C lexer over the FIXED spelling —
not a compiler; non-ASCII Unicode chars are out of `valid_c` (raw
UTF-8 passthrough is byte-identity, stated not proved); NUL
round-trips here but bash values are NUL-free; `%` doubling lives in
`heredoc_body_c`, upstream of `cstr`.

## 24. The `${name=word}` write arm — `c_write_arm.rs` (17 obligations)

The `"=" | ":="` branch of the `${...}` param renderer
(`c_backend.rs`, `match op.as_str()` in the expansion emitter) is the
one C-generator emission where the rendered expression decides, on the
spot, whether a name's storage is a fixed buffer, a heap cell the
program must own, or nothing at all. The structure it emits:

    v = (nonempty_test(name) ? <cur> : <word>);        // the value
    if is_num(name) || name empty  ->  v               // NO store
    else if buf_bound(name) = Some(b)  ->  (strcpy(buf, v), v)
    else -> (name = (test ? name : _sh_xstrdup(v)), v) // heap-owned

Four measured defects sat on this path (probe battery `/tmp/wam*`,
every probe compiled and diffed against bash):

1. GLUE (parser, FIXED): the quoted chain glued a bare `=` operator
   into the NAME — `param("", "v1=d")` — so every backend wrote a
   variable literally named `v1=d` and the probe printed
   `unset1=[] z=[]` where bash printed `unset1=[f] z=[f]`. A `/` or
   `-` inside the default word (`${v=/usr/local}`, `${v=b-c}`) was
   mis-read as the operator. Fix: ident-guarded split ahead of the
   pattern/suffix arms in BOTH parse chains
   (`parse_variable_expansion_inner`,
   `parse_parameter_expansion_content_inner`); unit tests
   `parser::words::bare_assign_tests`.
2. BOUNDS (census, FIXED): `analyze_string_lengths` collected neither
   `Declare` inits nor any `${NAME=word}` write, so `local x=1; x=`
   yielded `max_len 0` -> `char x[1]` -> `assert(strlen("1") <= 0)`
   aborts at STARTUP (wam5), and an `:=` default longer than the
   bound `strcpy`s past the buffer (wam4). Fix:
   `supplement_write_lengths` MAX-folds both store shapes into the
   core census before any consumer runs (right after
   `analyze_string_lengths`).
3. STALE FOLD (copy-propagation, FIXED): `count_stmt_assigns` never
   walked an Assign's RHS, so the write inside `v=${x:=d}` was
   invisible to def-counting, `x=""` kept count==1, and reads after
   the write folded to the pre-write literal (wam4 printed
   `colon:[d][]` for bash's `colon:[d][d]`). Fix: Assign-RHS
   recursion in `count_stmt_assigns` plus a param-write site in
   `count_expr_assigns`' Call arm (deliberately without an ident
   gate: an extra site only makes a var less foldable).
4. NORMALIZATION (known gap, PINNED — not fixed): `param_ir`
   normalizes bare `=` to `:=`, so bash's unset-only rule for
   `${n=w}` is unrepresentable downstream: with x SET-EMPTY bash
   leaves it empty (`bare:[][]`) while the C arm assigns
   (`bare:[d][d]`). Corpus impact ZERO — 0 bare-`=` shapes in 651
   corpus files (only `:=`, 3 occurrences). Proved as
   `bare_setempty_gap` rather than hidden.

Denotation extension (the "extend as convenient" half): the store
distinguishes UNSET (`None`) from SET-EMPTY (`Some("")`), and cells
carry provenance — a literal stays `Static`, the heap arm's store is
`Owned(word, id)`. `heap_valid` / `buf_valid` are the ownership
invariants: the scope-end `free` is sound only for slots the arm
actually allocated, which is exactly what the `xstrdup` adoption
buys.

What is proved (17 verified):

- `needs_eq_test` + `value_agrees` — the arm's value equals bash's
  `denote_val` for both ops (the `!test` ⇔ nonempty bridge);
- `heap_sound` (+`heap_double_eval`) — the heap arm keeps the value
  AND the ownership, and its double evaluation of the test is the
  same value each time (the invariant `t == nonempty_test(cur)` —
  without it the stated postcondition was false for arbitrary `t`);
- `buf_sound` — the fixed-buffer arm keeps the value with
  `strcpy_fits` (|src| ≤ b into `char buf[b+1]`);
- `num_sound` — the no-store arm;
- `bump_never_shrinks` + `bound_routes` — the census supplement only
  grows a bound, and after folding the word in either the name stays
  unbounded (heap path, no buffer to overflow) or the buffer FITS
  the default — including the CAP filter (beyond `cap()` = 1024 →
  None → heap);
- fidelity pins (`by (compute)`): wam5's bound, unset-`:=` assign,
  set-empty-`:=` buf, set-nonempty no-write, the double-eval
  instances, the path-word value;
- `bare_setempty_gap` — the normalization gap's exact shape;
- two in-file mutants: `mutant_static_store` (drop `xstrdup` → a
  Static literal sits in a slot the cleanup frees — `heap_valid`
  fails, the free-of-static line) and `mutant_flip_colon` (`:=`
  treated as unset-only — contradicts the denotation exactly where
  colon and bare differ).

Negative controls, measured in source (both restored; the C gate is
back at baseline 588/56/7): dropping `_sh_xstrdup` from the literal
default in `c_backend.rs` turned the gate from PASS 588 to PASS 313
(277 files red — the ownership discipline is load-bearing
corpus-wide); flipping `test_lowering`'s `:=` empty-check gate added
exactly one red (`eq_char_lit`).

Honest: `cap()` is the fixed 1024 ceiling (bigger defaults route to
the heap path rather than being proved smaller); allocation success
is assumed (OOM handling is the runtime's); the bare-`=` gap is
pinned not fixed, and `=` vs `":="` agree only when the name is
unset-or-nonempty — that half IS proved. Gate-registered
(`c_write_arm.rs:17:40`); like the other `c_*` models it is an
emission decision, so it carries no `verus-sync-coverage.sh`
baseline — its living tie is the pin↔probe mapping above.

## 25. The growth-helper family — `c_vbuf.rs` (39 obligations)

`_sh_grow`, `_sh_vgrow`, `_sh_grow_str`/`_sh_grow_<t>`,
`_sh_reserve_*` — the emitted runtime's dynamic-buffer protocol,
transcribed from c_backend.rs (≈11604 / 11619 / 11925 / 11957)
together with the five consumer shapes that lean on it:
`_sh_add`/`_sh_addc` (≈11630), `_sh_fa` (ECHO_FAST_C ≈9126), the
`snprintf_grow` loop (≈10335, the grow-until-sprintf-fits idiom
behind every vbuf temp), the vec-slot guard `while (len+1 > cap)
_sh_grow_str(&id, &id_cap)` (≈32040), and `_sh_fgets_line`
(≈12553).

WHY THIS EXISTS: §20 and §21 both shipped with "vbuf growth assumed"
in their honest sections — the one REPEATED assumption across the
C-generator models (both provisos updated above). Discharging it
also exposes the family's asymmetry: D (`_sh_reserve_*`) guards its
size arithmetic with `need > (size_t)-1 / sizeof …` BEFORE
multiplying, while A/B/C multiply and double unguarded.

THE SEMANTICS EXTENSION (the "extend as convenient" half): size_t
arithmetic made WRAP-EXPLICIT — `u64(x) = x mod 2^64` — so every
capacity theorem carries its exact domain instead of assuming
arithmetic C does not give us. Two thresholds become measured facts
(pins): `_sh_grow`'s `need * 2` wraps to 0 at need = 2^63 (cap := 0
while the caller still writes at need — `pin_grow_wrap_threshold`
exhibits the state where the fast path would later "fit" an
oversized write), and `_sh_vgrow`'s `while (ncap < need) ncap *= 2`
stalls at 2^63 (the model returns the stall as the divergence
witness; the fuel-form pin shows the RAW loop wraps to 0 — i.e. the
emitted `while` spins — at 2^63+1). Both need an exabyte-class
string: honest-unreachable, like c_width_store's range provisos.

What is proved (39 verified):

- family core: `grow_fastpath` (identity), `grow_room` (cap >= need
  + wf), `vgrow_fastpath`, `vgrow_nonnull` — THE deref-safety:
  alloc ⇔ cap ≥ 1 ⇔ p non-null whatever the input state, which is
  the reason `_sh_vgrow`'s fast path tests `&& b->p` — `vgrow_wf`,
  and `vgrow_amortized` (cap ≤ max(base, 2·need): doubling never
  over-allocates past 2×);
- appends: `add_content`/`add_wf`, `addc_wf`, `fa_matches_add` —
  content, terminator position and bounds for `_sh_add`/`_sh_addc`,
  and the two append emissions (`_sh_add`'s memcpy n+1 vs `_sh_fa`'
  s memcpy n + explicit NUL) agreeing byte-for-byte (the `+1` in
  the need is what M1 kills);
- the doubling loop: `dbl_reaches`, `dbl_cap_ok`, `dbl_bound`
  (the amortization lemma under `need ≤ 2^63`);
- `snprintf_grow`: `snpr_init_room` (size ≥ 256, p non-null for the
  first snprintf), `snpr_progress` (every non-break step strictly
  increases cap), `snpr_break_exact` (m < cap ⟹ the buffer holds
  EXACTLY the formatted value + NUL in bounds), and
  `snpr_run_props` — termination over ANY int-typed return
  sequence: within `imax - cap + 2` formatter calls the loop must
  break, because growths push cap past imax and int returns are
  capped there;
- `_sh_grow_str`: `grow_str_cap` (exact doubling + byte fit),
  `grow_str_zeroed` (fresh region entirely NULL — the
  free-of-garbage guard — plus old slots preserved), `grow_t_cap`,
  and `vecgrow_post` (the guard loop terminates under
  `len+1 ≤ 2^63` and lands with room for the following
  `id[id_len++]` store);
- `_sh_reserve_*`: `reserve_guard` (fires on oversized requests)
  and `reserve_no_wrap` (a request that passes multiplies EXACTLY —
  no wrap and NO domain proviso: the asymmetry A/B/C cannot claim);
- `_sh_fgets_line`: `fgl_capacity` (after `vgrow(n+512)` the fgets
  size is ≥ 512 and its NUL lands at cap-1 — in bounds; the
  `(int)` cast domain `cap - n ≤ imax` stated honestly) and
  `fgl_final_nul` (the final `vgrow(n+1); p[n] = 0` in bounds);
- pins: `pin_grow_wrap_threshold`, `pin_vgrow_stall`,
  `pin_raw_wrap_to_zero`, `pin_add_fresh` (a fresh `_sh_add` grows
  to exactly 2·(l+n+1)), `pin_snpr_init`.

Negative controls: three in-file mutants, each killing a named
obligation — M1 `mutant_add_no_plus1` (drop the `+1`: at the
boundary cap == l+n the fast path skips the grow and the NUL lands
one byte past the allocation; the same state under the real
`_sh_add` grows to 6 and fits), M2 `mutant_grow_str_no_zero`
(delete the zero-fill: the first fresh slot comes back Some(dangling)
where `grow_str_zeroed` promises None), M3
`mutant_reserve_unguarded` (2^61 × 8 = 2^64 wraps to 0 — the exact
request D's guard rejects). Source-level control (measured
2026-10-29): deleting the zero-fill emit line from c_backend.rs
changes the rendered C by exactly that one line (vec-probe render
diff `302d301`) but leaves the C gate at PASS=588 FAIL=56 SKIP=7 —
the deletion is corpus-UNOBSERVABLE (fresh realloc pages arrive
zeroed from the kernel and no corpus element-store frees a fresh
sparse slot before writing), so M2's in-file mutant remains the
registered control. The mutant was built to a separate
CARGO_TARGET_DIR; a neighbouring lane's rebuild picked the mutation
up in the shared binary for ~14 min — both restored (source and
shared binary verified back to the zero-fill at 13:23:58).

Honest: the allocator contract — a successful realloc preserves
bytes — is the premise here in the role `system`/`popen` plays for
§21; OOM exits 127 (an abort: defined behaviour, outside every
theorem — also why `_sh_grow` writing *cap BEFORE the realloc check
is unobservable). The formatter's VALUE is the oracle (its spelling
is §14b/§23's business); only the return/length contract is used,
and encoding error (snprintf < 0, unspecified contents in C) is
modelled break-with-unchanged-content — the emitted formats are
%s/%d-class and cannot fail. Typed-grow slots beyond ocap stay
UNINITIALIZED by design (no zero-fill): reads are len-guarded by
the render layer (c_backend.rs:11921 comment) — that guard is the
render-discipline layer's business. `_sh_fgets_line`'s loop
termination rests on fgets' file-bounded progress — stated, not
proved. Gate-registered (`c_vbuf.rs:39:40`); like the other `c_*`
models it is an emission decision, no sync baseline — its living
tie is the pin↔probe mapping (and the source control above).

## 26. The sparse-array read faces — `c_sparse_array.rs` (43 obligations)

The C backend stores an indexed array DENSE (`static char *arr[N]` +
`arr_len`, a NULL slot = an unset index) while bash's indexed array is
SPARSE: `arr=(a b c); arr[5]=z` sets four elements at {0,1,2,5}. A
nine-face probe through the real pipeline (shir → C → cc → run vs
bash) measured every read face before and after the fix; six were red:

| face | bash | C before | after |
|---|---|---|---|
| `echo "${!arr[@]}"` (ANY indexed array) | works | **cc red**: `arr_len undeclared (did you mean arr_n?)` | PASS |
| `${#arr[@]}` sparse | 4 | 6 (dense extent) | PASS |
| `${arr[*]}` | `a b c z` | `a b c   z` (separator before the NULL skip) | PASS |
| `for x in "${arr[@]}"` | a b c z | visits holes as `""` | PASS |
| `for ((i<${#arr[@]}))` bound | loops 0..3 | `atoll(_sh_env("((long long)arr_len)"))` → 0 iterations — DENSE too, never worked | PASS |

Five source changes, one invariant each side of the store — **a read
never decides storage class; a hole is never an element** (all in
`src/c_backend.rs`):

1. The read-driven `assoc_arrays.insert` removed in all three places
   that had it: `array_keys_join`, the for-in keys arm, and
   `collect_assoc_expr`'s `param` arm. The class comes from the
   WRITES (`declare -A` / string-key stores / `setArray(...,true)`);
   the keys read now dispatches like every other read: assoc →
   `_sh_join_keys`, char** → the new `_sh_join_ikind` (non-NULL slots
   ascending — exactly bash's key set), value storage → `_sh_join_idx`
   (dense; no presence marker exists).
2. `_sh_join_arr` emits the separator AFTER the NULL skip (the `_f`
   flag preserves set-but-EMPTY elements' separators: `arr=(a "" c)`
   → `a  c` on both sides); the for-in values loop skips holes —
   char** only, value storage keeps dense iteration (0 is a value).
3. `${#arr[@]}` counts elements: `array_len` and
   `apply_array_counts`' indexed branch emit `_sh_icount` for char**
   (value storage stays dense — the documented coverage edge).
4. All seven free loops NULL after free (`{ free(a[i]); a[i] = 0; }`)
   — the hole invariant's foundation: after `arr=()` no stale
   non-NULL slot can survive into a later sparse write's growth gap.
5. `apply_array_counts` gained the `_sh_env("T")` rewrites (the
   FUNCTION-call wrapper the arith/let fallbacks emit — only the
   inline-`getenv` forms were handled): without them the bare-token
   replace landed INSIDE the quoted key and the c-style-for bound
   read `atoll(getenv("((long long)arr_len)"))` = 0 forever, for
   dense and sparse arrays alike.

MEASUREMENT: full C gate 588/56/7 → **590/54/7 with the
newly-failing set EMPTY** (`comm` against the baseline FAIL list —
a net +2 cannot hide a swap). The two wins:
`parse-arithmetic-nested-array.sh` (exec/diff → PASS; it contains
`$((j+(100/${#arr[@]})))` — the arith count splice) and
`063_07_nested_if_statements.sh` (cc → PASS). The 8 failing
`c_backend` unit tests are PRE-EXISTING in this tree: only today's
edits were reverted (a scripted reverse-apply with count checks),
the suite re-run — **identical 162 passed / 8 failed both ways** —
then the file restored byte-exact (matching sha256).

CONTROL (source-level): a mutant COPY of the crate (isolated
`CARGO_TARGET_DIR` in /tmp; the shared source and binary never
touched) re-adds ONLY the `collect_assoc_expr` param-arm insert: the
keys faces p1/p7 revert to the exact original cc red
(`arr_len undeclared ... did you mean arr_n?`) while count, join,
for-in and the bound face stay green — the fix is load-bearing and
specific.

What is proved (28 verified): `icount_is_len`/`count_face` (count =
|elements|), `join_as_fold`/`fold_join_lead`/`values_face`
(separator-after-present ≡ bash's space join, empty elements and all),
`keys_as_fold`/`keys_face` (the key enumeration = the set indices,
ascending), `forin_is_elems`, `get_outside` (element reads outside
[0,len) are `""`), `free_null_clears` + `arr_set_keeps_tail` (both
state ops preserve `tail_clear`), `sparse_probe` (the canonical
vector's five faces), `coverage_new`/`coverage_old_broken` (dispatch
and decl read the SAME class field ⇒ refs ⊆ decls; the pre-fix read
flip violates it — the measured cc red), and the mutants:
`m1_join_sep_before` (the old fold yields the measured
`a b c   z`), `m2_dense_count` (6 ≠ 4), `m3_free_no_null` (a stale
freed word stays visible after reassign), plus `concat1_skip`
(singleton-concat algebra the folds rest on).

THE SEMANTICS EXTENSION: the shIR/bash indexed array — a partial map
index → word — is denoted here as `Seq<Option<Str>>` slots + `len`,
with `bash_elems` / `key_elems` / `bash_len` as the denotational
faces, `inter_ws` as the join, and `tail_clear` (every slot ≥ len is
None) as the correspondence invariant that init-`{0}`, free+NULL and
the growth gap maintain. `dec` (the decimal spelling) is
UNINTERPRETED here on purpose — byte-exact itoa is §14b's
`ll2s_exact` / ArithDec — this file pins WHICH indices appear, in
WHAT order, with WHICH separators.

HONEST EDGES (measured, NOT fixed — next increments):

- **assoc family (probe p5/p9)** — RESOLVED in §27: the newline join
  is retired (M1), `unset 'm[a]'` removes the entry (b1/b2/b3 probe
  faces green); only bash's hash ORDER remains (documented edge).
  bash's `${!m[@]}` order is hash order (unspecified — deliberately
  not chased).
- **`set -u` unbound variables (p6/p8)**: bash aborts with
  `unbound variable`, we print empty — a pre-existing set-u
  emulation gap, outside the storage family.
- **value-storage arrays**: no presence marker, so count/keys/for-in
  are dense (`dense_value_storage`) — an out-of-order write on an
  int-homed array still reports the dense extent.
- **`${arr[@]:off:len}`** slices the space-joined string: agrees with
  bash on the probe shapes, not established generally.

### 26b. The no-colon SET-NESS faces on an ELEMENT (+9, 2026-11-05)

`${arr[i]-w}` / `${arr[i]+w}` / `${arr[i]=w}` / `${arr[i]?msg}` do not
ask for a VALUE — they ask a PREDICATE: is this index an element? A
set-but-EMPTY element is an element in bash, so the predicate is
`slot.is_Some()`, and the C arms were resolving it through the value's
EMPTINESS instead. Measured (each against bash, 2026-11-05):

| program | bash | C before | C now |
|---|---|---|---|
| `a=(''); ${a[0]-z}` | `` | `z` | `` |
| `a=(''); ${a[0]+z}` | `z` | `` | `z` |
| `a=(''); ${a[0]=z}` | `` | `z` | `` |
| `a=(''); ${a[0]?b}` | ``, rc 0 | aborted | ``, rc 0 |
| `a=(); ${a[0]-z}` | `z` | `z` | `z` |
| `a=(); ${a[0]?b}` | abort, rc 1 | abort, rc 1 | abort, rc 1 |
| `n=(1 2 3); ${n[5]-z}` | `z` | `z` | `z` |
| `n=(1 2 3); ${n[2]-z}` | `3` | `3` | `3` |

The extension is `presence_override` in `param_call`: when the read is an
element under one of the four set-ness operators, the arm's test becomes
the store's own presence answer instead of the value's emptiness —

* marker arrays: `i >= 0 && i < len && _sh_pres_arr[i]`
* VALUE storage (`long long a[]`, no marker): `i >= 0 && i < len`,
  which is exact because every index below `len` holds a value
* assoc: the KEY list (below, §27)
* otherwise (a scalar, or an unknown key): the existing heap-presence
  pointer / emptiness test, unchanged

Obligations: `is_set` (bash's predicate), `pres_test` (the shipped
test), `pres_wf` (the marker byte IS `is_Some` for every real element —
the invariant the writer maintains), `value_wf` (range alone suffices
for value storage), the four denotations `f_dash`/`f_plus`/`f_assign`/
`f_question` against their renderings `c_*_pres`/`c_dash_range`, the
exactness theorems `setness_dash` / `setness_plus` / `setness_assign` /
`setness_question` / `setness_dash_value_storage`, and four mutants on
the canonical `pe()` store (`a=('')`): `m4_emptiness_is_not_setness`,
`m5_marker_is_the_difference` (drop the byte and the same store
answers `z` — the `a=()` row), `m6_plus_flips`, `m7_question_aborts_wrongly`.
The `?` face keeps its exit status: bash exits **1** for an abort in a
script file (measured; `bash -c` reports 127, which is why the model
states the file case — the corpus gate runs files).

### 26c. The `=` / `:=` faces also WRITE (+6, 2026-11-05)

bash does not only return the default word — it ASSIGNS it into the
element. The previous round yielded the word and stored nothing:

| program | bash | C before | C now |
|---|---|---|---|
| `a=(); ${a[0]=z}` then `#a`, `${a[0]}` | `1`, `z` | `0`, `` | `1`, `z` |
| `a=(); ${a[2]=z}` | `1`, `z` | exit 127 | `1`, `z` |
| `a=(''); ${a[0]=z}` | `` (set: no write) | `` | `` |
| `a=(''); ${a[0]:=z}` | `z` (colon tests EMPTINESS) | `z`, no write | `z` |

So the two faces share a WRITE but not a TEST: `=` asks "is the slot
an element" (the presence predicate above), `:=` asks "is the value
EMPTY" and therefore overwrites a present-but-empty slot. The arm
reads its test ONCE into an `int _pp` (re-testing after the store
would report "set" and return the stale read), materialises the
default only inside the guard — bash evaluates the word only when it
stores — and writes through the same helpers normal stores use
(`_sh_arr_set`, `_sh_assoc_set`).

Two analyses had to learn the shape, because a set-ness write arrives
as a PARAM EXPANSION, not an index store: `setness_write_arrays`
(veto the array out of Int storage — the measured array was
`long long a[1]`, which cannot hold `z` — and raise the fixed capacity
to the literal index, or drop it so the array takes the demand-growth
route; a dynamic key drops it).

Obligations: `assign_state` (`=` on a non-element), `colon_assign_state`
(`:=` on an empty value), `f_assign_colon` (its value denotation),
`assign_writes_the_word` (the element and the count), `assign_keeps_a_set_element`,
`colon_assign_rewrites_a_present_empty`, `assign_grows_to_the_index`
(capacity = the index), and mutants `m11_assign_without_the_store`
(the pre-fix count 0 vs 1) and `m12_colon_is_emptiness_not_presence`
(the a6 row).

Gate-registered (`c_sparse_array.rs:45:40`); like the other `c_*`
models, an emission decision with no sync baseline — its living tie
is the pin↔probe mapping (the nine-face probe) and the source
control above.

### 26d. The store reaches every storage class (+1, 2026-11-05)

The first cut of §26c stored only into FIXED-CAPACITY `char**` tables, and
that restriction was not cosmetic: `local b=()` is a demand-grown (`vec`)
`char**` whose table is allocated on demand and whose capacity lives in
`b_cap`, so the fixed-cap call `_sh_arr_set(b, &b_len, 1024, 0, v)` wrote
through a NULL pointer and **SEGFAULTED** (measured). The store now picks
the helper from the storage class, and evaluates a non-literal key ONCE
into a `long long _kx` so the presence test, the store and the value face
cannot disagree (before that, `${a[i]=z}` with `i=2` stored at 0 — the
`${!a[@]}` key face showed it):

| shape | how it stores | measured |
|---|---|---|
| fixed `char *a[N]` | `_sh_arr_set(a, &a_len, cap, i, v)` | `a=(); ${a[0]=z}` → `n=1` |
| demand-grown `char **b` | `emit_vec_index_write` (grower + cap) | `local b=(); ${b[0]=q}` inside a function → `n=1`, called twice |
| literal or dynamic key | `long long _kx` hoisted once | `i=2; ${a[i]=z}` → `n=1`, `${!a[@]}` = `2` |
| `$((i+1))` subscript | same temp | `i=1; ${a[$((i+1))]=z}` → `n=1` |
| assoc (`m[k]`, `m[$k]`) | `_sh_assoc_set` | loops over keys insert each |
| `long long a[]` (int) | **no store** — no text slot exists | pinned |

THE OVERWRITE, and why it needed a runtime change. `${a[i]:=w}` must
replace a present-but-EMPTY slot. The first attempt freed the slot inside
the store and printed **freed memory** (`a=(''); echo "${a[0]}"
"${a[0]:=z}"`): an earlier expansion of the same statement still points at
the block that was just freed. Two designs were measured before the one
that shipped:

* *defer a named temp on `pending_frees`* — does not compile inside a loop
  body (`_po4 undeclared`): that list is flushed at the statement boundary,
  outside the C block where the temp was declared.
* *copy the value before the store* — leaks, because there is no
  statement-scope free for an arbitrary temp.

Shipped: `_sh_arr_take` / `_sh_assoc_take` hand the replaced block to a
runtime TRASH list (`_sh_defer_free`), and `_sh_flush_trash()` runs after
every statement (the `stmt` wrapper) — a call, so it needs no declaration
in scope. The model states the two halves as `take_old` (the replaced value
is RETAINED for the flush) and mutant `m14_in_place_free_drops_the_read`
(the measured use-after-free).

RESIDUAL (measured, NOT fixed): a plain `${a[i]}` read is rendered INLINE,
so when it shares one argument list with a `${a[i]:=w}` that overwrites the
same slot, our read resolves at call time and sees the NEW value —
bash materialises expansions left to right (`a=(''); echo "${a[0]}"
"${a[0]:=z}"` prints `[] [z]`, we print `[z] [z]`). Fixing it means
materialising plain element reads into temps, which touches every read
site; the set-ness faces themselves are exact.

Also pinned: `x=${a[0]=z}` and `: "${a[0]=z}"` never reach the backend —
the generated C assigns the empty string with no `param` call
(pre-existing lowering gap in the assignment / no-op-command paths,
independent of these faces).

## 27. The associative-array faces — `c_assoc_array.rs` (54 obligations)

The C backend stores an associative array as two parallel DENSE arrays
plus a count (`static char *m_k[N]; char *m_v[N]; size_t m_n` via
`_sh_assoc_set/get/unset`), while bash's `declare -A` is a finite MAP
string → string with hash-order iteration. The denotational extension
(the model): the storage IS the map under

- **wf** — `keys.len() == vals.len()` AND keys pairwise distinct
  (init `{0}` plus the first-match-replace / append-only-insert paths
  preserve it), and
- **the_map** — the forward-scan fold `the_map(tail).insert(head)`.

Faces proved (each tied to a face measured red before 2026-10-30's
fixes):

| face | theorem |
|---|---|
| `${m[k]}` | `get_sound`: `_sh_assoc_get` == map lookup, `""` off the map |
| `m[k]=v` / `m[k]+=v` | `set_sound`: first-match replace or append IS map insert (+ wf + key-set postcondition) |
| `unset 'm[k]'` | `unset_sound`: `_sh_assoc_unset` == map remove, survivors in order (+ count/len + key-set postcondition) |
| `${#m[@]}` | `count_face`: `keys.len()` == bash's distinct-key count |
| `${!m[@]}` | `keys_set_face`: the key SET == dom |
| `${m[@]}` | `join_vals_sound`: the emitted fold == bash's space join |
| int-attr RMW | `int_attr_face` / M3: `declare -i n; n+=3` routes to the arithmetic arm (INTEGER level — byte-exact itoa is §18's `c_int_helpers`/`c_dec_str`) |
| homing veto | `veto_covers_param_join`: a `param("slice",…,"@")` whole-array join vetoes native `long long[]` homing (a6 SIGSEGV face) |

Four measured probes pin the scenarios (b1 string-key unset, b2
numeric-key unset, b3 interpolated key, b4 append + replace) and four
mutants each kill one obligation (M1 newline join, M2 no-op unset,
M3 concat-as-sum, M4 veto miss).

Source fixes alongside (all `sh2perl/src/c_backend.rs`):

1. `_sh_assoc_unset`'s head-frame reconstruction — survivors in
   order; the pre-fix arm had no non-numeric-key path (M2's shape).
2. The join separator — `_sh_join_arr_nl` retired for string
   contexts (M1: `echo "${m[@]}"` printed one value per line).
3. **a3 — For-iterator array state**: `sh_array_inits` collected refs
   from the loop BODY only, and `collect_array_refs_expr`'s `param`
   arm missed the split shape `param("slice", NAME, "@"|"*", LEN)` —
   the child shell never received `m`, so `for x in "${m[@]}"`
   iterated ZERO times (probe a3: empty output). Both the iter/cond
   EXPRS and the split shape are now collected.
4. **a5 — printf spread**: `printf … "${m[@]}"` in ARG position is
   bash's quoted-spread (N words with format recycling); the native
   printf joined it into ONE arg (`<1 2>` vs bash's two lines).
   `try_native_printf_into` now refuses whole-array slices (the t62
   `split` precedent — shell out, which splits correctly), and
   `sh_word`'s whole-array command-word arm — previously indexed-only
   — now expands ASSOC tables through their dense `m_v`/`m_n`
   storage as separately quoted words (the BASHC_FIX realpath loop,
   extended).

HONEST EDGES (measured, NOT chased):

- **hash ORDER**: bash iterates its own hash table, so `${m[@]}` /
  `${!m[@]}` spell the same words in an order that is not our
  insertion order. The string-level theorems pin OUR spelling, the
  set-level theorems pin the bash agreement; the probe harness
  classifies those faces SORTONLY/ORDEREDGE (a1/a2/a4/a7/b1/c5).
  Relating the spellings as multisets would need a split/join
  round-trip lemma — deliberately not claimed.
- The capacity guard (`*n < cap` → exit 127), value ownership
  (xstrdup/free), and the capacity-growth arithmetic are outside the
  model (as in §26; growth itself is discharged in §25).
- `set -u` unbound-variable abort remains the pre-existing gap.

EVALUATION DISCIPLINE is part of the model's contract: `by (compute)`
over a LET-BOUND recursion result DIVERGES (the evaluator cannot head
reduce `the_map(rks, …)` with `rks` symbolic — this hung the full run
>550 s with no output), and `.dom().len()` is uninterp for the
evaluator, so counts are stated on `.0.len()` — the `{id}_n` arm the
backend actually emits. Every compute assert therefore takes the FULL
concrete call term; set facts over literal tables compute, set facts
over symbolic tables go through the sset bridges (`sset_member`,
`distinct_cons`, `set_insert_commute`, `set_remove_insert_commute`,
`insert_remove_fresh`). The model also needs vstd's broadcast groups
opted in explicitly (`group_seq_axioms`, `group_map_lemmas`,
`group_set_lemmas` + set_lib/iset) — without them the remove axioms
and seq-length bridges are simply absent.

### 27b. KEY PRESENCE for the same four faces (+8, 2026-11-05)

The assoc twin of §26b — and the reason it needed a new runtime helper.
`_sh_assoc_get` answers `""` for a MISSING key (a non-NULL pointer to
the empty string), which is byte-identical to a present-but-EMPTY
entry, so the value pointer cannot carry set-ness at all. Measured:

| program | bash | C before | C now |
|---|---|---|---|
| `declare -A m; m[k]=; ${m[k]-z}` | `` | `z` | `` |
| `declare -A m; m[k]=; ${m[k]+z}` | `z` | `` | `z` |
| `declare -A m; ${m[k]-z}` | `z` | `z` | `z` |
| `declare -A m; m[k]=; ${m[k]?b}` | ``, rc 0 | aborted | ``, rc 0 |

The store change is `_sh_assoc_has(k, n, key)` — a scan of the key list,
emitted beside `_sh_assoc_get` — and `array_index_read` now records the
key expression it built (`assoc_key_seen`) so the set-ness operator can
call it without re-deriving the key text (explicit-arith subscripts
included). `has_is_dom` proves the scan is `dom(the_map)`, the same key
set the count and key-join faces already use. Mutants:
`m8_value_is_not_presence` (present-empty vs absent yield the SAME `""`
from `assoc_get`, yet the faces must differ), `m9_plus_reads_presence`,
`m10_question_is_presence`.

### 27c. The same faces INSERT the key (+4, 2026-11-05)

`${m[k]=w}` puts the entry in the table (`#m` 0 → 1, `${m[k]}` `w`);
`${m[k]:=w}` does the same but only when the VALUE is empty, so a
present-but-empty entry is overwritten while `=` leaves it alone.
Both go through `assoc_set` — the insert the ordinary `m[k]=w` arm
already uses — so `{id}_n` grows exactly when bash's key count does.
Obligations: `assign_table`, `colon_assign_table`, `assign_inserts_the_key`
(key present, count 1, value `w`), `assign_keeps_a_present_key`,
`colon_assign_rewrites_a_present_empty_key`, mutant `m13_assign_without_the_insert`.

REMAINING HONEST EDGE (measured, not fixed): the live store's default
word is only materialised when the guard passes, so `${a[i]=$(cmd)}`
runs `cmd` once — correct — but an array that is also written through
the ordinary `a[i]=v` arm keeps its situs; and a set-ness write on an
array whose element type is `long long` from a *later* proof-gated
analysis (numeric-observed) is demoted, i.e. the optimisation is lost
per array, not per write.

Gate-registered (`c_assoc_array.rs:54:40`); like the other `c_*`
models, an emission decision with no sync baseline — its living tie
is the pin↔probe mapping (the a/b/c probe battery) and the source
control above.

## 28. The IFS joins — `c_join_ifs.rs` (82 obligations)

The `${a[*]}` separator read and the `${a[*]:off:len}` element slice —
the faces behind 064_07's `sort` receiving ONE space-joined line, and
the slice probes c10/c16 that lost `:off:len` entirely. The
DENOTATIONAL EXTENSION: `ifs_sep(ifs)` is the FIRST char of IFS with
`""` → NO separator, and the never-assigned case IS the decl's startup
space (`char IFS[N] = " "` — bash resets inherited IFS at startup).
That last identity is exactly why `emit_var_decl` vets the const-lift
for IFS (`let ok = ok && v != "IFS"`): const-lift bakes the assigned
literal into the declaration AND suppresses the assignment statement,
so probe c09 (`a=(x y z); echo "[${a[*]}]"; IFS=:; echo "[${a[*]}]"`)
printed `x:y:z` on both lines (bash: `x y z` then `x:y:z`).

The slice denotation is PRESENCE-ORDER: `present(slots)` drops holes
and keeps set-but-empty words (`_f` tracks presence, not emptiness),
and `rng_slice` computes its bounds over the ELEMENT count — bash
ground truth, measured: `a=(a b c); a[5]=z; echo "${a[*]:1:3}"` →
`b c z` (offset/length count elements, not slot indices). The `[@]`
face joins with a space under any IFS and is PROVED independent of it
(`at_face_ignores_ifs`); `rng_whole_is_all` proves the whole-slice
short-circuit (BASHC_OPT item 28) returns exactly what the range path
would.

Fixed alongside the model (all measured red before):

1. `_sh_join_arr_sep` — `[*]` reads IFS[0] at RUNTIME (064_07:
   `IFS=$'\n' sorted=($(sort <<<"${config[*]}"))` fed sort the whole
   join as one line, so `sorted` was whatever the store returned);
2. the parser DROPPED `:off:len` from `${a[*]:off:len}` — both
   word-parse sites returned the plain-join shape
   (`param("", "a[*]")`) and the slice never reached the IR (c16:
   `[b a c]` vs bash `[a c]`). Both sites now emit
   `param("slice", "a[*]", off, len)` — the `[*]` suffix rides in the
   name so the star face survives to every backend (their slice arms
   already strip it), and `ast_words`' Display no longer double-wraps
   a subscripted variable;
3. `_sh_join_arr_rng` — a store-based ELEMENT slice for BOTH faces,
   replacing join-then-`_sh_arr_slice`, which re-split the joined
   string on a SPACE and was lossy three ways: no boundary at all
   under `IFS=$'\n'` (c10), a skipped empty LEADING element (c26:
   `a=("" x y); ${a[@]:0:2}` → bash `[ x]`, rendered `[x y]`), and an
   element CONTAINING a space splitting into extra words (c27:
   `a=("x y" z); ${a[@]:1:1}` → bash `[z]`, rendered `[y]`);
4. the IFS DECLARATION sits OUTSIDE the `need_sh` runtime block —
   `emit_var_decl` skips the name unconditionally, so the decl used to
   live only where the runtime helpers do, and `IFS=$'\n\t'` in a
   program with NO array join rendered `strncpy(IFS, …)` against an
   undeclared identifier (`parse-dollar-single-quote.sh` failed to
   COMPILE the first time the prologue decl landed inside that block;
   it is also trimmed with the runtime otherwise, which would have
   dropped the declaration while keeping the write).

Obligations: the three `ifs_sep` cases; the join faces at the measured
probes c01–c08 (default/newline/colon/empty/multichar IFS, holes,
empty element, `[@]` space); the decl veto and c09's two lines; the
slice arithmetic and probes c16–c28 (default, offset-only, negative
offset, colon, empty IFS, empty element, holes, assoc, int array,
empty-lead `[@]`, embedded-space `[@]`, holes-with-offset, `[@]` under
IFS). Five mutants each kill one obligation: m1 a hardcoded space
separator, m2 the retired join-then-space-split route (under
`IFS=$'\n'` the slice comes out EMPTY — no boundary exists), m3 the
const-lift without the veto, m4 the `[@]` face routed through IFS, m5
DENSE-index slicing (holes as empty words → `\n\nz` for `${a[*]:3}`).

Not modelled (fidelity, checked against bash): negative LENGTH. The
split is by FACE and it is exact (measured 2026-10-31):

- ARRAY faces — `${a[@]:1:-2}` and `${a[*]:1:-2}` both print
  `<script>: line N: -2: substring expression < 0` to stderr, run
  NEITHER the failing command NOR anything after it on that `;` line,
  and leave later lines running (status 1 for the aborted line).
- SCALAR — `${x:1:-2}` is ACCEPTED and end-counts (`x=abcdef` →
  `bcd`).
- `${a[@]:-2}` is not a negative offset at all: bash parses `:-` as
  the DEFAULT-value operator, so it yields the whole array.

Both C arms end-count in every case, so for the array faces the
renderer is silently wrong where bash has no value; the model states
the arithmetic only where bash has a value. Reproducing the abort is
not a one-arm fix: it needs statement-level skipping keyed on the IR's
`stmt_lines` line grouping (the C emitter does not thread line
boundaries into emission today) and an expansion-error idiom, which
the emitter has none of — its only fatal paths are the OOM/profile
`exit(127)`s. There are ZERO occurrences of a negative array length in
the corpus, so this stays a documented boundary rather than a gate
red; `${!m[*]:o:l}` key-list slices keep the pre-fix path
(the parser declines the shape); dense VALUE storage (`long long[]` /
`mpz_t[]`) keeps `_sh_arr_slice` behind the `dense_value_storage`
guard; assoc is modelled as a dense Seq (unset compacts `_v`/`_n`).

Also measured red and NOT yet fixed (neither is a face bug, so neither
is modelled — both are pinned as `xfail` cases in the battery):

- the `[@]` face in a MULTI-WORD context: bash passes one ARG PER
  ELEMENT (`printf '[%s]\n' "${a[@]}"` prints three lines) while the
  renderer joins into ONE string — the join itself is right, the
  cardinality is not (`07`, `20`);
- `for w in "${a[*]}"` lowers to `TODO(unsupported): for item type`
  and the whole loop is DROPPED (zero iterations where bash iterates
  once with the join) — a pre-existing loop-lowering gap (`19`).

Measured this round (the battery is committed as
`harness/ifs-probe.sh`, 22 cases, `CORE_BIN` overridable — it used to
live in `/tmp` and die with every restart):

- **17 PASS, 0 FAIL, 5 XFAIL, 0 XPASS** — every star face green,
  including `${a[*]:1:2}` under `IFS=':'` (which only started working
  when the face began riding in the name);
- the C gate **PASS=605 FAIL=39 SKIP=7 with a FAIL set byte-identical
  to the pre-change baseline** (`harness/c_gate_main.sh`);
- `cargo test --lib`: **the same 61 failures before and after** (a
  HEAD-vs-tree A/B on `c_backend.rs`/`words.rs`/`ast_words.rs`), i.e.
  none of them is this work;
- `c_join_ifs.rs:50:40` now **50 verified, 0 errors** (was 44 — the outcome
  layer: six new obligations for the `negative -> expansion error` arm).

Gate-registered (`c_join_ifs.rs:50:40`); like the other `c_*` models,
an emission decision with no sync baseline — the pin↔probe mapping
(`harness/ifs-probe.sh`) and the source guards above are its living
tie.

### 28b. The SLICE face is NOT the WHOLE face (2026-11-04)

§28 modelled the whole-expansion faces and assumed the SLICE took the
same joiner. Measured on real bash this round, it does not — and the
positional slice (`_sh_argv_slice`) had a hard-coded space that no
example could catch, because the default IFS *is* a space.

Ground truth (`set -- p q r s`; `a=(x y z)`; single-word/assignment
context, which is the only place the join is observable):

| expansion | `IFS=:` | `IFS=""` | default |
|---|---|---|---|
| `${*:2:2}` | `q:r` | `qr` | `q r` |
| `${@:2:2}` | `q:r` | `q r` | `q r` |
| `${a[*]:1:2}` | `y:z` | `yz` | `y z` |
| `${a[@]:1:2}` | `y:z` | `y z` | `y z` |
| `$*` / `${a[*]}` (whole) | `p:q:r` / `x:y:z` | `pqr` / `xyz` | space |
| `$@` / `${a[@]}` (whole) | **space** | space | space |

The rule, in one line: **a SLICE joins on `IFS[0]` for both faces, and
the two faces diverge only on an EMPTY IFS** — `*` concatenates (the
emitted `&& sep` guard reads the NUL), `@` falls back to a space
(bash joins the resulting multiple words, and a null IFS has no
separator, so the fallback is the space). The whole-expansion `[@]` is
the odd one out: it is space-joined unconditionally, which is exactly
why one `' '` literal served both forms and looked correct.

Two source fixes in `sh2perl/src/c_backend.rs`:

- `_sh_argv_slice(d, off, len, sep)` — the separator is written under
  `if (i > b && sep)`, so `sep == 0` inserts nothing. Both the star and
  the at face now pass `IFS[0]`, the at face as `(IFS[0] ? IFS[0] : ' ')`.
  The face had to be read from TWO places: `param("slice", NAME, "@"|"*",
  off, len)` carries it in `args[2]` (`face_star`), while a positional
  `param("slice", "*", off, len)` carries it in the NAME — reading only
  the first left `IFS=''; v="${*:2:2}"` rendering `q r` where bash gives
  `qr` (caught by the probe, not by the model).
- the two `_sh_join_arr_rng` slice call sites (`param_call` and the
  array-value arm) replaced `' '` with `(IFS[0] ? IFS[0] : ' ')` for the
  `[@]` face; `star_face` already passed `IFS[0]`.

The denotation also had to change SHAPE, not just gain a parameter:
`VOut::Val` carried a word LIST, but the emitted helper joins as it
writes, so the honest payload is the joined `Str` — `argv_out(argv, off,
len, sep)` now returns `join_seq_sep(argv_slice(…), sep)`, and the
empty/out-of-range arm is the empty STRING (the early return writes no
separator at all), which `s14` pins for both faces. New spec:
`slice_at_sep(ifs)` (array slice face) and `pos_slice_sep(star, ifs)` +
`pos_slice` (positional), each with the fallback stated as a total
function so the empty-IFS arm is a *value*, not a side condition.

Obligations added (all `by (compute)` over literal sequences):

- `c_join_ifs.rs` **50 → 54**: c17 REVISED (it had asserted the retired
  space — under `IFS=$'\n'` an `@`-slice is now `a\nc`), c33 (colon:
  `a:c`), c34 (empty IFS falls back to a space), c35 (the contrast that
  hid the bug: the same range, whole vs slice, differs under a colon
  IFS), m7 = the retired hard-coded space;
- `c_str_helpers.rs` **56 → 65**: s8/s9 (both faces `q:r` under `IFS=:`),
  s10/s11 (`qr` vs `q r` on an empty IFS), s12 (behaviour-neutral on the
  startup IFS), s13 (the faces differ ONLY on an empty IFS), s14 (guard
  order is separator-independent), s15 (open form `${*:2}` = `q:r:s`),
  m8 = the retired space.

Measured: battery `harness/ifs-probe.sh` **36 PASS / 0 FAIL / 4 XFAIL /
0 XPASS** (cases 32-40 are new; case 21 `21_xfail_at_sl_colon` left the
xfail list as `21_at_sl_colon` — an XPASS, retired); C gate **PASS=605
FAIL=39 SKIP=7**, and NO corpus example uses `${x:o:l}` at all (`grep`
over `sh2perl/examples` and the frontend testdata), so this change cannot
move that gate and its delta belongs to other work in the tree.

Not modelled, stated plainly: the `@` face still collapses to ONE word
in a multi-word context (the pre-existing cardinality gap above), so
these pins speak about the assignment/single-word context where the
join is observable; `$0` differs by construction between `bash <file>`
and the compiled binary, so the offset-0 case strips the `$0` field
rather than blessing either value.

### 28c. The CHILD-SHELL reconstruction: one array, two storage classes (2026-11-04)

§28e gave dense storage a presence marker, which made every READ face
agree with bash. The WRITE-for-a-child face was still routed by call
site rather than by storage, and it crashed.

Measured (`harness/ifs-probe.sh`, case 60):

```
declare -ia n; n[4]=5; printf "%s\n" "${n[4]}" "${#n[@]}"
  -> cc: warning: passing argument 4 of '_sh_idx_init' from incompatible
         pointer type (expected 'char **', got 'long long *')
  -> rc 139 (SEGV), ASAN: read at 0x1 in _sh_idx_init
```

`_sh_idx_init(char **a, size_t n)` skips NULLs and writes `n=(7 9)`.
Handed a `long long[]` it reads each slot as a POINTER, so it segfaults
before it can write a wrong literal. Three call sites rebuilt arrays for
a child shell — the stage-command rebuild (`$(…)`), `sh_array_inits`,
and `array_inits_for_text` — and each decided the helper itself.

The fix is one classifier in `sh2perl/src/c_backend.rs`, `idx_init_call`,
which all three sites now go through: value storage takes
`_sh_idx_init_ll(const long long *a, const unsigned char *pres,
size_t n)` — one `[%zu]=%lld ` entry per PRESENT slot (explicit index,
because a hole must not move its successors) and `pres = NULL` for the
growable-vec / mpz forms, whose extent IS the element list. `char**`
storage keeps the old helper.

**The denotation** (`c_join_ifs.rs` §g). A child shell is a fresh shell
that never saw the parent's C state, so the array it is handed is a
SEQUENCE OF (index, value) PAIRS — the bash array it denotes:

```
shell_pairs(slots, marker)   the pairs the emitted literal installs
pair_idx / pair_vals         the child's `${!n[@]}` / element list
child_join(sep, pairs)       the child's `${n[*]}`
child_count(pairs)           the child's `${#n[@]}`
```

Obligations added (section g, **+9**: 73 → 82 verified):

- `g0a_present_and_idx_align` — `present` and `present_idx` are the two
  projections of ONE pair list (equal length, by induction on the slot
  list);
- `g0_pairs_project` — the projections recover what the pairs were built
  from, so the child may be read through either;
- `g1_child_sees_exactly_the_elements` — THE ROUND TRIP: with the marker
  the child's indices are `present_idx`, its elements are `present`, its
  `${#n[@]}` is `dense_count`, and its `${n[*]}` is `dense_marked_join`
  **for every separator** (which is why a child may be handed a
  non-default IFS);
- `g2_measured_sparse_child` — the measured array: pairs
  `([0]=7, [2]=9)`, count 2, join `7 9` / `7:9`;
- `g3_without_the_marker_the_child_invents_elements` — the MUTANT: drop
  the marker and the literal becomes the extent list, so the child
  reports count 3 and `7 0 9`. A refactor that removes the `pres`
  parameter fails here;
- `g4a_no_holes_is_the_extent` + `g4_dense_storage_needs_no_marker` — the
  side condition that makes `pres == NULL` legitimate: on a hole-free
  array the extent list IS the element list, so the two reconstructions
  agree (`declare -ia n=(1 2); n+=(3)`, case 60c);
- `g5_unmarked_parent_and_child_agree_with_each_other` — CONSISTENCY IS
  NOT CORRECTNESS, and this is the sharpest obligation in the section:
  without the marker the parent's extent join and the child's literal
  agree (`7 0 9` on both sides), so no parent/child differential test
  can find the defect; both simply contradict bash (`7 9`). The marker
  is owed to BASH, not to internal agreement. It also pins that the
  dense join's element source is the VALUE list (`zeroed`), not the
  empty-word `densify` (`7  9`) — the two are separately dominated (e7);
- `g6_dispatch_is_class_determined` — the dispatch is a function of the
  STORAGE CLASS alone (`helper_for`), the two helper images are
  disjoint, and on a sparse array the two reconstructions carry
  different element lists, so the wrong helper can never be silently
  right.

Scope, stated plainly: ONE storage class is not covered by the dispatch
— the `mpz_t[]` array-return storage. It is a function-local temp
produced by a call lowering rather than a name in the store, so it does
not reach the three sites today; if it ever does it needs its own helper
(reading `mpz_t` slots as `long long` or as pointers are both wrong),
which is why `idx_init_call` says so in place.

The C signature mismatch is not Verus' to see —
on the gate's compiler (GCC 13.3, MEASURED) it is only a
`-Wincompatible-pointer-types` WARNING, so the bug COMPILED and then
died at runtime; GCC 14+ promotes it to an error. What is proved is the
value fact that makes the mix-up wrong rather than ill-typed (g3/g6).
The probe battery is the instrument for the type half: cases
`60_int_argv_face`, `60b_int_argv_sparse` (the hole must reach the
child), `60c_int_argv_vec` (no marker), `60d_int_argv_neg`.

Measured after the fix: battery `harness/ifs-probe.sh` **85 PASS / 0
FAIL / 8 XFAIL / 0 XPASS**, rc 0 (case 60 retired from the xfail list).
Nothing in the corpus exercises `declare -ia` in an argv position, so
the gate cannot move on this change; the battery is the instrument.


## 29. The redirect reorder and the word quoter — `c_redirect.rs` (46 obligations)

```
    verus --triggers-mode silent --rlimit 40 c_redirect.rs
    -> verification results:: 46 verified, 0 errors
```

**What is proved.** Standalone model of the C backend's REDIRECT
EMISSION and WORD QUOTING (`c_backend.rs` redirect arm + `_sh_word`):

- `fd_parse` — the emitted fd prefix parses back to the fd it was
  rendered from (the `unwrap_or(1)` + empty-prefix rule);
- `quote_roundtrip` / `esc_in_sq` — THE WORD QUOTING: the bytes the
  child shell word-parses out of `_sh_word(v)` are exactly `v`, for
  every string; the `'`-splice walks `'` `"` `'` `"` `'` back into Sq.
  `m1` is the negative control: the UNescaped spelling loses everything
  after an embedded `'` (the word closes early);
- `raw_arm_no_quotes` — the dup/close arm (`2>&1`, `2>&-`) emits NO
  quote characters; `m2` shows what quoting it would produce
  (`>&'1'` names a file in bash);
- `heredoc_last_forced` — appending a non-heredoc after a heredoc frag
  moves the terminator (`ends_with(a+b, d) == ends_with(b, d)` under
  `|d| <= |b|`, the guard the proof exposed: without it the claim is
  false — `pre` itself can end in the delimiter); `m3` computes the
  concrete `cat <<EOF` + `0< 'in.txt'` pair;
- `commute_here` + `fold_commute`/`fold_concat` + `reorder_safe` — THE
  REORDER THEOREM: if `safe(rds)` (no non-heredoc touching fd 0 at or
  after the FIRST heredoc) then `emit_order` — non-heredocs in source
  order, heredocs last — preserves the fd table for EVERY starting
  table;
- `n1_fd0_conflict` — the side condition is NECESSARY, not decorative:
  at fd 0 the two orders disagree for every starting table. MEASURED
  2026-11-01 (`/tmp/redprobe`): `bash src1.sh` (`cat <<EOF < in.txt`)
  → FROM_FILE, the generated C → FROM_HEREDOC, and the swapped src2
  agrees in both;
- `n2_close_is_a_file` — MEASURED: `echo hi 2>&-` and `echo hi 2>-`
  render byte-identical C (the IR has no Close mode, `ir.rs:569`), so
  the close source diverges from bash by construction (rc 1 vs a file
  named `-`);
- `flip_safe_mono` / `flip_frame` / `first_here_*` — the process-sub
  flip pass preserves safety: `is_here` pointwise, `first_here` by
  extensionality, monotone under the flip.

**Model defect found by the proof (fixed).** `reads0` covered only
`W|R|Rplus`, but `written` matches `W|Wc|A|R|Rplus` before consulting
the dup form — a `Wc`/`A` Rd whose target is `&0` had
`reads0 == false` while `written` still read `t.get(0)`, so
`written_frame`'s frame rule was provably FALSE. `reads0` now covers
exactly the modes `written` consults (strictly more conservative for
`safe`/`touches0`, i.e. the sound direction).

**Evaluation discipline.** `by (compute)` over `run` with a symbolic
state diverges — measured spinning in the verifier's interpreter
thread for >15 minutes, the same discipline `c_assoc_array.rs` records
for let-bound recursion results. The quoter proves through the
structural `run_one` + `run_concat` chain instead; ground `skip`/
index facts on seq literals are stated as explicit asserts (they do
not normalize on their own inside a recursive call).

**Scope.** Word splitting by the child beyond the quoting layer is
bash's contract; `exec`-style and process-substitution redirects beyond
`is_ps_read` are out of scope; `ends_with_concat` is guarded
(`|suf| <= |s|`) — the unguarded form is refuted in-file. Gate-
registered (`c_redirect.rs:46:40`); like the other `c_*` models it has
no sync baseline — the pin↔probe mapping (`/tmp/redprobe`, 2026-11-01)
is its living tie.

## 30. Static `eval` inlining — `c_eval_inline.rs` (20 obligations)

```
    verus --triggers-mode silent --rlimit 40 c_eval_inline.rs
    -> verification results:: 20 verified, 0 errors
```

**What is proved.** A literal `eval '<text>'` denotes the statements of
`<text>` and nothing else — so `shir_to_c` now splices them into the IR
*before* the analyses (`static_eval_stmts` + `expand_static_evals`)
instead of lowering the text at render time (`try_static_eval`, which
stays as the fallback for a dynamic argument or a text the core parser
rejects).

The model is a program FLATTENED to the in-order leaf sequence the
analyses fold over, each leaf tagged with how many literal-eval texts
enclose it (`0` = top level, `k` = inside `k` texts, `-1` = inside an
opaque `eval "$x"`). Splicing is then exactly "retag to 0", which is why
the flat view is faithful — the leaves keep their position. Every fold is
a recursion on an int cursor into that one sequence, so each obligation
is a definitional unfold:

- `expansion_preserves_meaning` / `assigned_invariant` — the rewrite
  moves neither an effect nor a store target (the licence);
- `census_is_exact` (under `dyn_free`) and `fixed_census_is_complete` —
  **the fix**: after the pre-pass the census IS the set of stores, so
  every store target is declared. The pre-fix census differs by exactly
  one clause (`stores_top`: a store declares only at depth 0);
- `opaque_never_over_declares` — the pre-fix census only ever MISSES,
  never over-declares, so its failure mode is one-sided and cannot
  manufacture a false "declared" behind which a real bug hides;
- `witness_063_12` — the measured program: `assigned` has `result`,
  the pre-fix census does not, the fixed one does;
- `route_var` / `route_env` — the SECOND symptom from the same cause.
  The read was at top level the whole time; it was the census that could
  not see the store, so `route` demoted `$result` to `_sh_env("result")`
  (the environment — a different storage from the shell variable the
  store wrote). This is why a mid-body declaration would not have been a
  fix: the decl and the routing are the same fold;
- `dyn_eval_not_covered` — the honest scope: an opaque text is left
  exactly as found, and is *still* invisible to the census;
- `expand_idempotent` — the pre-pass reaches a fixpoint, so its depth
  bound is a safety valve against a text that evals itself, not a
  semantic parameter.

**Measured.** `harness/render-all.sh` renders every corpus source (651
files) with a given CLI, so a renderer change can be byte-diffed against
the previous build: **649 of 651 files identical**, and the two that
differ are the two the change is aimed at —
`063_12_complex_eval` (now `char* result = NULL;`, `(result ? result :
"")`, `free(result)`; the gate verdict goes `cc` → **PASS**) and
`063_hard_to_parse` (same statement order, verdict unchanged at
`stub:3`). C corpus gate **PASS=614 FAIL=30 SKIP=7**.

**Scope, stated plainly.** The model abstracts names to indices and
records NO value flow: it says the census sees the right NAMES, not that
the spliced statements compute the right values — value correctness here
is bash's semantics of the same text, which the gate compares directly.
An `eval` whose word is not a single literal (a variable, a substitution,
several words) is deliberately untouched by the pre-pass: `static_eval_stmts`
returns `None` and the render-time path keeps whatever it did before.

## 31. `unset` on a scalar, the census that decides, and SET-NESS — `c_unset_scalar.rs` (27 obligations)

```
    verus --triggers-mode silent --rlimit 40 c_unset_scalar.rs
    -> verification results: 27 verified, 0 errors
```

**What is proved.** A bash variable is not a value: it is a PARTIAL map.
`None` (unset) is not `Some("")` (set to the empty string), and bash tells
them apart. The C generator stores a scalar one of two ways, and only one of
them can carry the distinction:

```
STRING storage   char *x       — carries a Str; `unset` clears it to "" / NULL
INT storage      long long x   — carries a NUMBER. There is no spelling of
                                 "unset" in it. `unset` emitted NOTHING.
```

Measured 2026-11-04, each program `x=5; unset x` then one line:

| expansion | bash | C (before) |
|---|---|---|
| `echo "[${x:-gone}]"` | `[gone]` | `[5]` |
| `echo "[$x]"` | `[]` | `[5]` |
| `echo $((x+1))` | `1` | `6` |
| `echo "[${x-unset}]"` | `[unset]` | `[5]` |

The fix is one predicate ([c_backend.rs](sh2perl/src/c_backend.rs),
`demote_unset_scalars` / `unset_scalar_census`, run from `shir_to_c` right
after the stringy demotion): a scalar the program `unset`s is removed from
the Int verdicts, so it lives in string storage, where the state exists.

**The quotient.** String storage cannot represent `None` separately from
`Some("")` — both are the same bytes. `quot` is that identification, and the
obligations say what it preserves and what it provably cannot:

- `q_plain`, `q_len`, `q_arith`, `q_colon_default`, `q_colon_plus` — agree
  with bash for EVERY state, by construction: these faces test EMPTINESS,
  which the quotient keeps. That is the fix's whole target, and it is why
  the fix is a storage-kind demotion and not a presence bit.
- `q_dash_default_unset`, `q_dash_plus_unset` — the half of the no-colon
  faces that `unset` completes (`${x-w}` after an unset is `w`; measured).
- `no_face_separates` — **the residual is impossible, not unfinished**: no
  function of the quotient can give different answers for `None` and
  `Some("")`, while bash's `${x-w}` does. `dash_gap_is_the_set_to_empty_case`
  is the witness, and it is PRE-EXISTING and unrelated to `unset`
  (measured: `x=""; echo "[${x-w}]"` → C `[w]`, bash `[]`, before this round
  and after it). Any future attempt to "finish" `${x-w}` inside string
  storage has to add state, and this theorem says so.
- `pref_int_keeps_the_value`, `pref_int_arith` — the pre-fix divergence on
  the measured numbers (an int store keeps the VALUE across `unset`), which
  is what made every face wrong at once.
- `demote_is_a_kind_change`, `demote_hits_the_right_names`,
  `element_and_flag_are_not_scalar_unsets` — the census. The numeric-only-
  mutation exception (`let x=…`, `printf -v x`) is proved non-decorative, and
  an element unset (`n[k]`) / a flag (`-v`, `-f`, `-n`) is proved not to
  demote the scalar (that is a storage-CLASS question, answered elsewhere).

**The census walk (why a missing arm was a soundness hole).** §3 models the
DECISION; the decision is only as good as its INPUT. `demote_unset_scalars`
demotes a name that an emptiness face reads when no assignment to it is
unconditional, and the face collector was a hand-written `match` over `IrStmt`
whose tail was `_ => {}` — with no `Output` arm. But `printf '%s' "${x:-}"`
lowers to `IrStmt::Output { value }`, not to `Expr(Call)`, so the face was
invisible, `x` was never classified possibly-unset, and it stayed Int-homed.
Measured 2026-11-05:

| program | bash | C (before) |
|---|---|---|
| `r=$(echo hi) \|\| { x=$?; }` then `printf "%s=%s" x "${x:-}"` | `x=` | `x=0` |
| the same with `echo "[${x:-}]"` | `[]` | `[]` — **always right** |

The `echo` twin is the point: the WORD carries a face in both; only the
carrier differed. Two corpus files were failing exactly here
(`parse-dollar-paren-or.sh`, `parse-dollar-paren-pipe.sh`).

The fix is the walk itself: `for_each_stmt_expr` lists **every** `IrStmt`
variant, so the `_` arm is gone and a new variant is a compile error rather
than a silent hole. §4 of the model states it:

- `narrow_walk_misses_the_output_face` — the bug: the same word is seen
  through `Expr` and missed through `Out`, so the narrow walk is not even
  carrier-independent (proved as an inequality).
- `full_walk_sees_it_through_every_carrier` — the fix: both carriers are
  seen, and each agrees with `word_sees` on the word; the exhaustive walk IS
  carrier-independent.
- `plain_read_is_not_a_face` — why the census stays narrow: a `$x` read does
  not test set-ness, so it must not demote (Int is the fast path, and the
  census only spends string storage where bash can tell a difference).
- `exhaustive_walk_is_what_makes_the_demotion_sound` — the composition with
  §3: demoted ⇒ the read is the exact string face; not demoted ⇒ the read can
  only be the number `"0"`, which is not bash's empty string.

**Negative control.** Restoring the missing arm IN THE MODEL (`sees`'
`St::Out` arm → `false`) turns §4 red on exactly the three positive
obligations: **16 verified, 3 errors**; the unmodified file is 19/0. The
source-side control is the fix itself: before it, `vc.sh`, `p1.sh` and
`vc2.sh` all differed from bash (`x=0` / `x=[0]`), after it all three are
byte-identical.

**Blast radius, measured.** Instrumenting the pass (`SH2_DEBUG_DEMOTE=1`)
over all 651 corpus sources, the EXHAUSTIVE walk fires on **34 files** (the
narrow one fired on 3, and 31 of those 34 were silently mis-homed). Every one
of them is green except the two that became green here, so the extra demotions
cost storage kind, not verdicts:
`t70_unset.sh` (the target — gate `exec/diff` → **PASS**),
`064_hard_to_generate.sh` (verdict unchanged, `exec/diff` for unrelated
reasons) and `typeset-cmdsub.sh` (unchanged, `stub:14`). Every other source
keeps exactly the storage it had.

**A second defect the model forced out.** `seq_write_str_var` — the "write a
numeric value into a string variable" arm — aliased a STATIC `snprintf`
scratch buffer into the variable. For a heap-owning `char*` that hands the
exit teardown (and every later `free(old)`) a pointer it must not free, so
`x=5; unset x; let x=x+1; echo "$x"` printed the right value and then died
with `free(): invalid pointer`. It now stores through `_sh_sset`, the same
helper an ordinary `x="5"` uses, so the slot is heap-owned or NULL — the
invariant every free site assumes.

**SET-NESS vs EMPTINESS — the no-colon family.** §5 is the *other* distinction
bash makes on the same storage. The colon is the whole difference:

```
${v-w}    w unless v is SET        set-to-empty -> ""
${v+w}    w iff v is SET           set-to-empty -> w
${v=w}    like ${v-w}, AND assigns set-to-empty -> "" (no assign)
${v:-w}   w unless v is NON-EMPTY  set-to-empty -> w
${v:+w}   w iff v is NON-EMPTY     set-to-empty -> ""
```

Measured 2026-11-05:

| program | bash | C |
|---|---|---|
| `x=""; printf "[%s]" "${x-w}"` | `[]` | `[w]` |
| `x=""; printf "[%s]" "${x+w}"` | `[w]` | `[]` |
| `unset x; printf "[%s]" "${x=w}"` | `[w]` then `w` | `[]`, x still unset |
| `x=""; printf "[%s]" "${x:-w}"` | `[w]` | `[w]` — right (emptiness is what `:-` means) |

The **data was not the obstacle**: a heap scalar here is `char *x = NULL` and
`unset` is `free(x); x = NULL`, so the pointer already IS a presence bit. The
**operator** was: the parser folded `${x-w}` into `${x:-w}` (both arrived as
`param(":-", "x", "w")`), so the exact arm was unreachable, and `${x=w}`
arrived as `param("", "x=w")` — a "variable" named `x=w`, rendered as a
child-shell lookup. §5 proves both halves:

- `presence_renderings_are_exact` — with presence, all three faces are exact
  for EVERY state (so a fix exists, and the residual is reachability).
- `emptiness_render_fails_on_set_empty` — the shipped arm is wrong on exactly
  the measured inputs; `emptiness_is_right_on_the_unset_half` — why it looked
  right (only the `None` half coincides, which is what §1's `quot` identifies).
- `collapse_loses_the_colon` and `no_renderer_of_the_collapsed_ir_is_exact` —
  the impossibility, at the IR: because `${x-w}` and `${x:-w}` reach the
  renderer as the SAME input, any renderer exact for `:-` is necessarily wrong
  for `-` on `Some("")`. No C-side patch could fix it; it needed a new operator
  spelling in the AST/shIR contract, which PLAN §11 makes an **offer** across
  backends. (`collapse(Op::Plus) == Op::Plus` is proved too: the `+` family
  already carried its colon, which is why half of this family was
  renderer-only.)

**The spelling landed.** The theorem above is why the fix went into the AST
rather than the arm, and it now holds as history:

- `ParameterExpansionOperator` gained `DefaultValueNoColon` /
  `AssignDefaultNoColon`; the parser stopped folding (a bare `=` branch was
  added — `${v=w}` used to arrive as a variable named `v=w`); the shIR encoder
  emits distinct `-` and `=` ops next to the already-distinct `+`.
- The C renderer's `-`/`+`/`=` arms test the **raw heap pointer**, not
  `store_ref`'s null-guarded read (which erases exactly the presence being
  asked about) and not `[0]` (the non-emptiness test). The `:+` arm was
  missing for store vars altogether — it fell through to a plain read
  (`x=v; ${x:+w}` printed `v`, bash `w`) — and now tests non-emptiness.
- Three storage vetoes make presence representable: a set-ness read keeps the
  name off a fixed buffer (`buf_bound`), off the `const` lift (a non-NULL
  literal initializer would claim "set"), and out of Int
  (`demote_unset_scalars` now demotes these names unconditionally, since `0`
  is a value, not "unset").
- `every_spelling_is_exact` states the result per spelling, including that
  `-` and `:-` now DIFFER on set-to-empty — the state that was unreachable.

Measured after: all **fifteen** state × face combinations (unset /
set-to-empty / set-non-empty × `-`, `+`, `=`, `:-`, `:+`) are byte-identical
to bash, and `${v=w}` stores its default (`unset x; ${x=w}; echo "$x"` → `w`;
it used to print nothing with `x` still unset). The corpus gate is
**625 PASS / 19 FAIL / 7 SKIP with a byte-identical FAIL list** — the parser
and storage-kind changes regress nothing across the 651 sources (re-measured
after each of the four spellings).

**The four members, and the `?` face.** The family is complete: `-`, `+`,
`=`, `?` each carry their own op, so the renderer can be exact for all eight
state × face pairs. The last one is an *error* face, not a substitution, so
its denotation is a predicate — and the colon is again the whole difference:

| program | bash | C (before) |
|---|---|---|
| `x=""; printf "[%s]" "${x?boom}"; echo after` | `[]after`, rc 0 | aborts, rc 1 |
| `x=""; printf "[%s]" "${x:?boom}"` | aborts, rc 1 | aborts, rc 1 (right) |
| `unset x; printf "[%s]" "${x?boom}"` | aborts, rc 1 | aborts, rc 1 (right) |

`question_keeps_the_colon` states the pre-fix collapse and the single state
where the merged predicates disagree; `question_spelling_is_exact` states that
the shipped test — the heap pointer being NULL — IS bash's condition, while
`colon_question_errors` keeps the emptiness one. The arm also gained a
`getenv`-presence case for environment-only names, and both now match bash on
stdout **and exit status** across all eight measured cases.

**Negative control.** `collapse(Op::Dash)` → `Op::Dash` (i.e. "pretend the
parser keeps the colon") still turns §5's impossibility red on its dependent
obligations: **23 verified, 2 errors**; the file is 27/0 (`Op::Question` → itself reddens `question_keeps_the_colon` too).

**Corpus.** C gate **625 PASS / 19 FAIL / 7 SKIP** (was 623/21/7). The FAIL
list was diffed both ways: exactly two files left it,
`parse-dollar-paren-or.sh` and `parse-dollar-paren-pipe.sh` (the `||` and `|`
twins of the measured program), and **no file joined it**.

**Still open, pinned.** The no-colon faces on an ARRAY ELEMENT
(`${a[0]-z}`, `${a[1]+y}`) do not reach the operator machinery at all: the
legacy word parser returns `param("badsub", "a[0]-z")` for them (measured
2026-11-05, PRE-EXISTING — the colon form `${a[0]:-z}` is parsed and correct).
The store already tracks element presence (`_sh_pres_a[i]`), so the render
side has what it needs; the gap is the parser bank. `printf -v x %d 9` is
wrong on BOTH storages
(measured: with Int storage it prints the old value; the string path
truncates a heap pointer into the integer). That is why `printf -v` targets
are excluded from the demotion rather than converted: demoting them only
moves the failure. It is a separate gap in the `printf -v` arm.

## 32. `printf -v` writes TEXT — `c_printf_v.rs` (22 obligations)

```
    verus --triggers-mode silent --rlimit 40 c_printf_v.rs
    -> verification results: 22 verified, 0 errors
```

**What the builtin does.** `printf -v NAME fmt args…` stores the FORMATTED
OUTPUT: an arbitrary string. `%s` copies an argument verbatim, `%03d` pads,
`%x` spells another radix. Three analyses in the pipeline assumed a scalar's
value is a NUMBER, and each produced its own divergence (measured 2026-11-04/05):

```text
  program                                  bash     C (before)
  n=1; printf -v n '%d' 7; echo "n=[$n]"   n=[7]    n=[1]     ← READ folded
  x=5; let x=x+1; printf -v x '%d' 9       x=[9]    x=[176]   ← uint8_t got the pointer
  printf -v s '%s' aaaa…(40)               s=aaaa   (trunc)   ← char s[2] bound
```

**The three defects, one classification.** A `-v` target is a partial-map,
text-valued name — the same family the `unset` round (§31) demoted on ABSENCE:

1. **the const census** (`shir::analyze_var_const`, consumed by the
   copy-propagation transform) counted assignment SITES and had no `-v` arm, so
   `n` looked single-write; every later read was replaced by the stale literal
   and the `echo` line was *emitted as the constant* `printf("%s\n", "n=[1]")`;
2. **the storage-kind verdict** called the target Int — a number cannot spell
   `"abc"`, and a width-narrowed one could not even hold the `%d` result
   (`uint8_t x` received a `char*`: `176`);
3. **the length bound** came from the other writes, so `char n[2]` was sized by
   `n=1` and the formatted write either truncated or overflowed.

Fixes: the transform counts the `-v` write (a transform, not the single-owner
core — offered, see the marketplace rule); the C-side demotion census treats a
`-v` target as text-valued and removes its Int verdict; the bound is dropped
(unknown ⇒ heap `char *`, which the arm's `_sh_xstrdup` store already is). A
fourth, smaller one fell out: the `strcpy(name, tmp.p)` arm had **no `;`**, so
the first time it became reachable (a buffer-bound target) cc rejected the
program — `expected ';' before '}' token`.

**The denotation.** `Str` / `atoll` (bash's arithmetic reading) / `canon` (the
canonical decimal spelling); two storages, `SStr` (keeps the text) and `SInt`
(keeps `atoll`); `observed(k, t)` is what a READ sees. Then:

- `str_face_is_the_identity`, `arith_face_is_atoll_either_way` — string storage
  is faithful on the text face AND inert on the arithmetic face, which is why
  demotion cannot break `$((x+1))`;
- `int_face_loses_padding` (`"004"` → `"4"`), `int_face_loses_text`
  (`"abc"` → `"0"`), `int_store_faithful_iff_canonical` — **the general form**:
  an int store is faithful exactly on canonical spellings, and `printf` writes
  whatever the format says. So the fix is a storage-kind DEMOTION, not a wider
  integer: no width makes `"abc"` a number.
- `narrow_witness_is_not_the_value` — the measured `176 ≠ 9`, pinned as a
  witness. **Not derived**: the model has no address space, so the claim "the
  narrow store held the pointer's bits" is measurement, stated as such.
- `printf_v_bound_is_unbounded`, `a_run_len`, `heap_keeps_any_text` — the
  formatted write has no static bound (for every `k` a longer `%s` exists), so
  a bound taken from the other writes is unsound; the heap copy keeps any text.
- `census_after_the_fix` (+ `census_aux`, `sites_true_push`,
  `sites_pre_fix_push`) — the fixed census counts exactly the extra `-v` writes:
  `sites_pre_fix(ev) + sites_true(filter_printfv(ev)) == sites_true(ev)`;
- `pre_fix_fold_is_unsound` — the measured divergence as a witness: one assign
  plus one `-v` is TWO writes, the pre-fix census says one, and the two values
  are different bytes (`"7"` vs `"1"`); `single_write_fold_is_sound` — the
  other direction: with one write the substitution is faithful, so the census
  fix is the whole story;
- `demotion_composes` — the `unset` and `-v` censuses agree on the survivor set
  and only ever remove Int verdicts, so they compose in either order.

**Negative controls (two mutants, both red at the right obligation).** Restoring
the pre-fix counter makes `pre_fix_fold_is_unsound` fail with `1 == 2` — the
census witness itself. Making `SInt` read back its input makes
`int_face_loses_padding` fail with `array_view(['0','0','4']) == push('4')` —
the padding witness. Restored: 22v/0e.

**Corpus, A/B on the same binary pair.** The C gate went **623 PASS / 21 FAIL /
7 SKIP** against the pre-round **622 / 22 / 7**: `000__04h_complex_examples.sh`
moved to PASS and **no file newly fails** (full FAIL list diffed both ways). The
shared-transform half was re-gated for every backend that consumes it: `./fail`
**560/3** and `fail-estree` **estree 562/1** — both unchanged from before this
round (the 3 perl failures are the pre-existing `063_hard_to_parse`,
`064_11_complex_test_expressions`, `064_hard_to_generate`).

**Tripwire.** `copy_propagation::tests::printf_v_is_a_write_site` asserts the
surviving `getVar` read: with the arm's guard disabled it FAILS (the read folds
to the stale literal and no `getVar` remains in the list). Measured both ways,
restored.

## 33. `let` under a glob-marked word, the arith ERROR path, the EXPANDED word, and the multi-word LIST, and ARRAY element 0 — `c_let_scope.rs` (38 obligations)

```
    verus --triggers-mode silent --rlimit 40 c_let_scope.rs
    -> verification results: 38 verified, 0 errors
```

**The failure, and why it is the interesting kind.** The core marks every
unquoted word that *could* pathname-expand with a `\x01SH2GLOB\x01` prefix. So
`let u=u*2` reaches the C renderer as `\x01SH2GLOB\x01u=u*2`, which is not
arithmetic; both native paths declined it (`parse_arith` on the marked text,
`let_render` after that) and the arm fell back to its last resort:

```c
static int _sh_site_0(void) {
  _sh_ll2s(_s0, (long long)(u)); _sh_export("u", _s0);   /* push the value DOWN */
  _sh_reset();
  _sh_addraw("(( \001SH2GLOB\001u=u*2 ))");               /* marker leaked */
  return !_sh_system_rc();                                /* no write-back */
}
```

MEASURED 2026-11-05: `u=7; let u=u*2; echo "[$u]"` printed **`[7]`** where bash
prints `[14]` — and exit status 0. **A write in a child does not exist in the
parent**: `let` is a pure assignment form, so the child-site fallback is not a
slow path, it is a no-op with a success status. That is the semantic fact the
model records, and it is why the fix had to make the native path *total* for
assignment text rather than merely preferred.

**Fix.** `strip_glob` before the arithmetic parse (the marker is a flag on the
word, never part of its value), plus a NATIVE-PARSE fallback for the assignment
shape: when `let_render` declines, try `parse_arith` and render the AST. The
fallback is additive by construction — it runs only where the child site used to
run, so every shape that rendered before renders identically. Probe (ad-hoc,
compiled and diffed against bash): `u=u*2`, `u+2`, `u*=2`, `i++`,
`"u = u * 2"`, `"u=u*2"` and `"u = u*2"` all match; the quoted `*`-forms were
already green, which is the control that isolates the MARKER as the cause
(quoting removes it and only then did the older paths fire). C gate unchanged at
623/21/7, no file newly failing.

**The denotation.** A store is a finite map `Name → Str`; a program writes it in
one of two MODES — `Native` writes the parent, `Child` writes a fork that is
discarded when the process exits (`after`); `visible` is what the parent reads
next, `status` the reported success. Obligations:

- `child_write_is_invisible` — the parent's value is `u7()` whatever the child
  computed: the measured `[7]`;
- `modes_disagree` — on any assignment of a fresh value the two modes differ, so
  a fallback between them is a correctness choice;
- `child_site_reports_success_without_effect` — the child reports success *and*
  leaves the store alone, which is exactly why the defect was silent;
- `strip_recovers_the_text` (`strip(marked(t)) == t`), `marked_text_is_not_arithmetic`
  (`marked(t)[0] == '\x01'`, so the child's bash text was garbage);
- `every_assignment_shape_is_native` — the licence: no `let` assignment shape
  maps to `Child` any more;
- `fallback_is_additive` — the native parse runs iff `let_render` declined.

### The ERROR path — an arith error aborts the store (fixed, 2026-11-05)

`let` is not always a store: bash evaluates the arithmetic first, and a division
by zero is an ERROR that aborts the evaluation where it stands. The assignment
never happens and the builtin reports failure. MEASURED, all three against bash:

```
    u=7; let u=u/0    ->  [7] rc=1      (was [0] rc=1)
    u=7; (( u=u/0 ))  ->  [7] rc=1      (was [0] rc=1)
    u=7; let u=u/2    ->  [3] rc=0      (control)
```

The renderer's divider is deliberately TOTAL — `(r == 0 ? 0 : l / r)`, because C
would SIGFPE — so the value `0` is a lie that only the STORE can repair. The fix
is therefore at the store, in the one place that can see the error before
codegen: `arith_static_zero_divisor` walks the AST for a `/`/`%` whose divisor
folds to a constant zero (`const_arith_value` never folds `/` itself, so the
divisor is tested on its own), and

- the `let` arith-assignment arm (`ArithAst::Assign`, `op == "="`) yields `0`
  and emits **no store** — the `let` arm turns that `0` into `_sh_rc = 1`, which
  is bash's status;
- the statement hook at the top of `fn stmt` (an `IrStmt::Assign` whose RHS is
  an `Arith`) emits `_sh_rc = 1;` and no store, BEFORE the speculative-shadow
  arm, whose store has the same defect.

Both consult the SAME predicate, which is what makes them unable to disagree.

**The denotation.** Arithmetic is now explicitly PARTIAL: `Outcome = Val(i) |
Err`, `ev_div(l, r)` is `Err` at `r == 0`, `rendered_div` is total and yields
`0` there, and `after_outcome` gives the store the `Err` case's identity:

- `semantics_errors_on_zero` — the semantics has no value at a zero divisor;
- `render_is_total_where_semantics_errors` — the divergence in one line: the
  renderer has a value exactly where the semantics has none;
- `detection_is_sound` — `detects(Some(0)) ==> ev_div(l, 0) == Err`;
- `error_aborts_the_store` — `after_outcome(_, st, n, v, Err) == st`, for BOTH
  modes (the abort is not about fork-at-all: nothing is written);
- `error_status_is_one` — `Err` and `Val(0)` agree on status 1, which is why
  yielding 0 for an error still reproduces bash's exit status;
- `detection_is_incomplete` — the honest limit: a divisor that is zero only at
  RUN time is `None` to the detector, so that store still fires with the
  rendered `0` while bash aborts. Stated, not papered over;
- `both_sites_share_one_predicate` — one predicate, two sites.

**Still open, and pinned.** (a) the runtime-zero divisor above; (b)
`u=$(( u/0 ))` is FATALLY fatal in bash — the shell exits and nothing after it
runs — where the total divider continues; the store is now skipped either way,
but the abort is not modelled.

### The EXPANDED word — the family the `${#a[@]}` pin was a symptom of

The pin said "`${#a[@]}` is an `Interpolate`, not a `Str`, so it reaches the
child site". Probing the family showed the pin was one instance of something
larger: **no** expanded `let` word reached the native paths, and the arm's
last-resort was not even the child site in every case but the builtin's no-op
tail — `_sh_rc = 0`, nothing stored. MEASURED against bash:

```
    a=(1 2 3); let n=${#a[@]}        bash [3]   C [0]
    a=(1 2 3); let n=${#a[@]}+1      bash [4]   C [0]
    x=4;       let n=$x              bash [4]   C [0]
    x=4;       let n=$x*2            bash [8]   C [0]
    x=4;       let n=${x}*2          bash [8]   C [0]
    x=5;       let n=x-1             bash [4]   C [4]   (bare name: always worked)
```

The word arrives as `Interpolate([lit "n=", getVar(x), lit "*2"])`. bash expands
it and parses the RESULT as arithmetic, so the emitter can put the same
reference in front of the arith parser — provided the spelling is one the
parser accepts. It is NOT `${x}`: `parse_arith` refuses `$`-prefixed operands
on purpose (bash expands them as *text* first, which is why an unset `$j` in
`$(( $j * 2 ))` is a syntax error rather than a 0 read), so a `$` spelling
declines and the statement is dropped. A **bare name** is the faithful form —
bash's arith evaluator resolves a variable, and recursively a value that is
itself a name, exactly what the expansion-then-parse does. `${#a[@]}` stays
textual and is rewritten to the C count read by `subst_array_counts` before the
parse.

Two guards make that reconstruction honest rather than optimistic:

- **delimitation** — `let n=$x1` is ONE word (`$x1`), so a name followed by a
  literal that starts with a name character refuses;
- **the HOME** — the native store assigns the C *ident*, while `store_read`
  answers `_sh_env(name)` for a var that is not registered (`store` / type
  verdict). Those are different homes: a Str-homed `n` written natively and read
  through `_sh_env` prints `""`. MEASURED 2026-11-05, `x=2; y=3; let n=$x+$y;
  echo "[$n]"` → `[]` where bash prints `[5]`, once an earlier `let` in the same
  file had reached the child site. Registering the var instead of gating was
  tried and is WORSE — the reads flip onto an ident whose declaration is NULL
  and the binary aborts (`atoll(NULL)`); measured. So the route is gated on
  `store_read`'s own predicate and otherwise declines to the child site it
  already used, which cannot make a wrong shape worse.

**Five more obligations:** `name_read_agrees_with_expansion` (the expansion's
value and the bare-name arith read agree, for a value that is not itself a
name), `arith_read_unfolds` / `arith_read_of_empty_is_empty` (the chain is
followed and anchored), `reconstruction_has_no_dollar`, and the home pair
`store_is_sound_when_homes_agree` + `native_store_requires_the_ident_home` with
`gate_is_conservative` (the decline lands on `after(Child, st, …) == st`).

**Measured after the fix:** the six-shape probe matches bash exactly; the
control `let n=x-1` (a bare name, which always worked) still matches; `let
n=$x1` still refuses (and now prints `[]` like bash instead of the site's
`0` —  bash's message goes to stderr, which the gate does not compare).

**Corpus.** C gate **623 PASS / 21 FAIL / 7 SKIP**, FAIL list byte-identical to
the previous run (`diff` of both lists: empty), so the widened native route
takes no corpus program down a new path.

### MULTI-WORD `let` — a LIST, and the status of its LAST word

`let` takes one or more expressions, evaluates them left to right (each one's
stores landing) and reports the truth of the **last**. The arm rendered
`items.first()` only, so the tail vanished and the status came from the wrong
word. MEASURED against bash:

```
    let a=1 b=2      [1][2] rc=0   C [1][2] rc=0   (core transform already
                                                     splits pure-assignment lists)
    let c=3 0        [3] rc=1      C [3] rc=0      ← the `0` never evaluated
    let d=0 4        [0] rc=0      C [0] rc=1      ← first word's verdict
    let e=5 e=e+1    [6] rc=0      C [6] rc=0
```

Only the MIXED list was wrong, because `build_assigns` (transforms/arith_forms.rs)
refuses a whole list when any word is not an assignment — so `let c=3 0` survives
as one `builtin let` call with two words, and that is exactly the shape the
first-word rule mangled.

**Fix.** The per-word renderer is factored into `let_word_c(expr, with_rc,
allow_site)` — the same code the single-word arm used, now reachable per word —
and a multi-word call is rendered as a comma list: each word's stores land in
order, and the last one leaves its verdict in `_sh_rc`. A word that cannot be
rendered natively falls the WHOLE call back to the single-word path, because a
child site inside a comma list is a fork whose write never returns (that would
be a new instance of the §33 defect).

**A compile error found on the way.** The `${#a[@]}` branch returned before the
home gate, so `a=(1 2 3); let n=${#a[@]}` with a Str-homed `n` emitted a store to
an ident no declaration exists for:

```
    k.c:1120: error: 'n' undeclared (first use in this function)
```

The gate now covers both branches (`let_home_ok`), so that shape compiles and
declines to the child site instead of failing the build. A wrong value is
recoverable; a build that does not compile is not.

**Six more obligations:** `status_of_words` (the list's status is the last
word's), `status_is_not_the_first_word` (a witness where the first-word rule is
wrong in BOTH directions, so it is not a special case of the right rule),
`status_is_the_last_word`, `words_store` / `words_compose_left_to_right` +
`composed_store_reads_back` (the second word reads the first word's write, which
`let e=5 e=e+1` → 6 requires) and `empty_list_is_failure`.

**Measured after the fix:** all five shapes above match bash; the earlier probes
(the six-shape expanded-word battery, the div-by-zero battery) still match.

**Corpus.** C gate **623 PASS / 21 FAIL / 7 SKIP**, FAIL list byte-identical to
the previous run.

### An ARRAY name in arithmetic is ELEMENT 0

bash denotes element 0 for an array name on both sides. The generator wrote the
C ident and read it as a decayed pointer:

```
    a=(1 2 3); let a=9      bash [9][3][3]   C  did not compile
    a=(1 2 3); let a+=4     bash [5][3]      C  did not compile
    a=();      let a=5      bash [5][1]      C  did not compile
    a=(1 2 3); let b=a+1    bash b=3         C  b=1   (pointer → 0)
```

`error: assignment to expression with array type` — the worst failure class,
for an int array and a word array alike. The write now goes to element 0 and
leaves the other elements and the length alone (a fresh array grows to one
element), a compound op reads element 0 first, and the read is presence-guarded
so `atoll` never sees a NULL word slot.

**The part worth proving is OWNERSHIP.** The statement path already implements
the documented subscript-0 rule (`emit_array_assign` with key `"0"`), so when a
`let` word is split into a statement both mechanisms would store. The first
version did, and `a=(1 2 3); let a+=4` printed `[9]` where bash prints `[5]`:
the second store re-evaluated `a[0] + 4` **after** the first had written 5.
The arith arm therefore stores only under a `let_owns_store` flag (set by the
`let` renderer) and is value-only otherwise.

**Five obligations:** `name_ignores_every_other_element` (only index 0 is
reachable through the name), `read_is_the_element_not_the_array` (the measured
reads, including empty → 0), `store_writes_only_element_zero` (element 0 set,
neighbours and length preserved, empty array → length 1), `double_store_compounds`
— the `[9]` witness as arithmetic, `a0 + 2*rhs` — and `one_owner_only`.

**Measured after the fix:** all six array shapes match bash, and the seven-probe
sweep (`t`, `m`, `r`, `s1`, `n1`, `ar`, `am`) is byte-identical to bash.

**Corpus.** C gate **623 PASS / 21 FAIL / 7 SKIP**, FAIL list byte-identical to
the previous run.

**The ASSOCIATIVE case.** `declare -A m=([a]=1); let m=5` sets the STRING key
`"0"` (bash `[1][5]`). The statement path's element writer already does that; the
arith arm had to become value-only there too, because `m = …` on a k/v/n table is
`error: 'm' undeclared` (measured). Inside a multi-word list no statement owns
that store, so that one shape is `mark_todo`-refused loudly instead of silently
dropped.

**Still open, pinned.** The Str-homed target above; a reconstructed word
containing a *subscript* read or a command substitution (not on the whitelist, so
it declines); an assoc array assigned inside a multi-word `let` (refused, marked).

**Corpus.** C gate **623 PASS / 21 FAIL / 7 SKIP** — the same totals as the
previous round, so the detector fires on no live corpus shape. The `let`-marker fix is invisible to the
corpus because no example writes an unquoted `let` containing `*`; it is a
real-program hazard, which is why it is pinned by the probe rather than by a
corpus file. The error-path fix touches every arith assignment statement, so the
gate is the check that the detector never fires on a live shape.

## 34. Expansion ORDER, the `set --` split, and the two word erasures — `c_expand_order.rs` (32 obligations)

### Expansion ORDER: a `${a[i]:=w}` store is visible only to the LATER words

bash expands a command's words **left to right**, each against the store as it
stands at that position, so a store is visible to every later face and to no
earlier one. The generator rendered a plain element read as an INLINE
expression while the store's statements were emitted as the later word was
rendered — so the argument vector evaluated the read *after* the store:

```
    a=('');  echo "[${a[0]}] [${a[0]:=z}]"     bash [] [z]    C [z] [z]
    a=();    echo "[${a[0]}] [${a[0]:=z}]"     bash [] [z]    C [z] [z]
    a=('');  echo "[${a[0]}${a[0]:=z}]"        bash [z]       C [zz]
    declare -A m; m[k]=; echo "[${m[k]}] [${m[k]:=z}]"   bash [] [z]   C [z] [z]
    a=('');  f() { echo "[${a[0]}] [${a[0]:=z}]"; }; f    bash [] [z]   C [z] [z]
```

The fix is `snap_elem`: when a statement contains an ASSIGN-style element
expansion (`${a[i]:=w}` / `${a[i]=w}`), every plain element read of that
statement is materialised into a statement temp **at the point it is rendered**,
which is before the store's statements. Statements with no such store are
untouched (a false positive would be free — `snapshot_is_identity_without_a_store`).

**Two carrier holes, both found by a red probe after the first fix.** The
"does this statement store" scan is a hand-written walk, and `printf FMT a b`
FOLDS to `IrStmt::Output` while a shell function's `echo` body arrives as
`Return(Some(..))` — neither was in the walk, so the flag stayed false for
probe 31 and probe 14. Widen
(`Output`/`Return`/`Exit`/`SetChildError`/`Die`/`Try`/`WriteFile`/`Warn`/
`Exec`/`Pipeline`/`Background`/`ForInit`), measured by re-running the battery.
This is the same shape as §26d's `narrow_walk_misses_the_output_face`: a
hand-written `match` is only as good as its arms.

**`set --` was dropping the split.** An unquoted expansion is a LIST of fields
and the core marks it `split(...)`, but `value_c` forwards only the inner value
and the `set --` arm appended one word per source word:

```
    x='a b';  set -- $x;        echo "$# [$1] [$2]"   bash 2 [a] [b]   C 1 [a b]
    x=' ';    set -- $x X;      echo "$# [$1]"        bash 1 [X]       C 2 []
    x='a::b'; IFS=:; set -- $x; echo "$# [$1][$2][$3]" bash 3 [a][][b]  C 1 [a::b][][]
    x='a b';  set -- $x $x;     echo "$#"             bash 4           C 2
```

The positional vector is now a GROWABLE one (`char **` + `_sh_wgrow`), since one
source word can become arbitrarily many positionals — the old `char *av[n+1]`
was sized by the source word count. Each `split` word is copied into a vbuf and
handed to `_sh_split` (the IFS helper the `for` arm already uses), which keeps
the whitespace/delimiter distinction: runs of blanks collapse and empty fields
vanish, while each non-whitespace IFS char delimits exactly one field.

**Obligations: `c_expand_order.rs`, 36 verified, 0 errors, 3 mutants.** The
denotational extension is the face list (`Read` / `ColonStore` / `AssignStore`)
folded left to right; the theorems are the six measured rows, the arity law
(a store contributes a word, `words_len_is_faces_len`), the pre-fix protocol
stated as a mutant (`m1_hoisted_store` prints `[z] [z]`), the carrier hole as a
mutant (`m2_narrow_walk`), the two splitting rules with `m3_one_rule_for_both`
proving they are not interchangeable, and the erasure that keeps the last row
open (`arrayindex_arrives_unsplit`). Evaluation discipline: the store is a
`Seq<Option<Str>>`, not a `Map` — `by (compute)` over a Map-returning recursion
diverges on this toolchain (a 400 s timeout, not a failure), and a `let`-bound
recursion result diverges too, so every concrete row takes the full call term.

**Measured on the RESTORED tree** (the pre-restore run read 18 of 28, all ten
misses being the read-after-store rows, because the recovered `:=` round was
still missing then). Ordering battery (01-14, 21-34): **26 of 28** rows match
bash — every read-before-store row, every read-after-store row, `printf` (31),
the nested function (14/30), `case`, capture, `if`, the loop, the arith key and
the three-word/same-word shapes. The two misses are:

- `28_arith_key` is a **CC-FAIL** (`a=(""); i=0; … ${a[$((i+1))]}`): a
  pre-existing declaration/homing bug for an arithmetic subscript with an
  offset, not an ordering bug — it fails to compile, so it never reaches a
  comparison.
- `32_unquoted` is the quotedness erasure proved at the end of this section
  (`set -- ${a[0]} ${a[0]:=z}` — the unquoted array element contributes one
  empty word where bash contributes none).

Splitting battery (rebuilt after the restart): **4 of 7** with the pass as it
stood, **5 of 7** once the fix below landed. The misses are pinned erasures,
not split-rule bugs: `06_array_elem`
(`a=(''); set -- ${a[0]}` → C 1 / bash 0) is the missing `split` marker on an
array element, and `07_quoted_kept` prints `[unset]` for `${1-unset}` on a
SET-but-empty positional — the already-documented `-` / `:-` operator collapse
of `c_unset_scalar.rs`, visible here because a positional is just another
scalar. The rows that exercise the rule itself all pass: `x='a b'` → 2,
`x=' '` → 0, `IFS=:; x='a::b'` → 3, `set -- $x $x` → 4, `set -- "" a` → 2,
`set -- "$x"` with `x=''` → 1.

**Residuals, pinned (both are IR erasures, not renderer bugs).**

- An unquoted `${a[i]}` reaches the backend as a bare `arrayIndex`: the parser
  emits no `split` marker, so `a=(''); set -- ${a[0]}` is C 1 word / bash 0, and
  no renderer of that IR can split it (the word is indistinguishable from a
  quoted one — `arrayindex_arrives_unsplit`).
- A compile-time-constant `$x` folds to a bare `Str`, likewise unmarked.
  **No longer true for an EMPTY value — see the fix below.**

**The QUOTEDNESS erasure (model §6), proved — the same bit, one level down.** The
first residual is not an array bug at all; it is the word node missing the
bit that says whether the source word was quoted. The measurement is a byte
comparison of the IR, and the two spellings are identical while bash
 disagrees:

```
    z="";  set -- $z       bash 0 words   IR  ["--", Str ""]
    z="";  set -- "$z"     bash 1 word    IR  ["--", Str ""]    IDENTICAL
    x="";  set -- $x a     bash 1 word    IR  ["--", Str "", Str "a"]
           set -- "" a     bash 2 words   IR  ["--", Str "", Str "a"] IDENTICAL
```

The model states this as a collapse (`to_ir` maps both spellings of
`Spelling::{QuotedWord, UnquotedExpansion}` onto the same `Word::Bare`) plus
the theorem it implies: `no_renderer_of_collapsed_words_is_exact` — given any
`g` exact for the quoted spelling (the renderer we shipped), `g` is wrong for
the unquoted spelling of the empty value, with the witness pinned to the
measured pair (1 vs 0). `kept_flag_makes_it_exact` shows the contract change
is SUFFICIENT as well as necessary (a renderer reading the flag is exact for
both spellings and for `"a b"`), which is what makes this an OFFER under
PLAN §11 rather than an unfinished C arm. `const_fold_is_the_same_erasure`
records that `x=""` (the constant fold that deletes the variable) is this
same collapse, not a third one. Evaluation discipline: the witness is written
as the full `s_empty()` term at every use — a `let`-bound term is the shape
that faults `assert_by_compute` on this toolchain (`exceeded maximum
recursion depth`, once, before the rewrite).

**The fix — the marker IS the quotedness bit (landed 2026-11-05).** The
collapse had a single author, and it was not the renderer:
`sh2perl/src/shir_passes/split_fold.rs` folded `split(w)` → `w` on
WHITESPACE-FREEDOM alone. That is unsound exactly where this section proves it
must be: for a no-space `w`, `split(w)` is the identity only when `w` is
NON-EMPTY (the empty value is zero fields, the bare word one). The pass now
requires BOTH verdicts, `expr_nospace` and a new `expr_nonempty` (a non-empty
literal, an `Int`/arith read — canonical decimal text — a `${#x}` length, or a
template literal with a non-empty part), so:

- the marker SURVIVES on an unquoted expansion of a possibly-empty value, and
  the renderer's existing `split` arms are then exact — no C-side change at
  all (`marker_is_the_quotedness_bit`, `fix_is_exact_for_both_spellings`);
- the optimization is NOT lost: every word the verdict proves non-empty still
  folds, which is why the corpus renders do not move
  (`fold_retained_on_nonempty_constants`);
- §6's impossibility stays in the model as the PRE-FIX statement that
  justifies the second verdict — a whitespace-only test is not a conservative
  approximation, it is a measurably wrong rewrite
  (`fold_is_sound_iff_nonempty` shows the one case it cannot see).

MEASURED after the fix, on the binary built from this tree:

```
    x="";  set -- $x a      C 1   bash 1     (was 2)
    x="";  set -- $x        C 0   bash 0     (was 1)
    x="";  set -- "$x"      C 1   bash 1     (unchanged)
    e="";  for w in $e      C 0   bash 0     (was 1 — one empty iteration)
    e="";  printf '<%s>\n' $e X   C <X>        (unchanged, argv face)
```

Ten-row empty-expansion probe: **10 of 10** (for-in ×4, argv ×4, echo ×2),
including the quoted controls (`"$e"` still one word) and `printf`'s argv face.
Ordering battery unchanged at **26 of 28**; splitting battery **5 of 7** (the
two misses are the array-element erasure and the `${1-unset}` collapse above).

Blast radius, measured rather than argued — this is a SHARED pass (PLAN §11):
`harness/c_gate_main.sh` **625 PASS / 19 FAIL / 7 SKIP** with a FAIL list and a
reason histogram BYTE-IDENTICAL to the pre-fix run (10 `stub:4`, 5 `exec/diff`,
2 `stub:3`, 1 `stub:14`, 1 `stub:1`); `./fail` **563 passed, 0 failed out of
563**; `./fail-estree` **563 passed, 0 failed** on BOTH its Perl and ESTree
legs. The pass's own unit suite grew to 12 (`nospace_is_not_nonempty`,
`keeps_split_of_empty_literal`,
`folds_split_with_a_nonempty_part`, and the funnel test now pins the measured
`x=""; set -- $x` shape).

**The IFS battery, and one xfail retired.** `harness/ifs-probe.sh` now reads
**85 PASS / 1 FAIL / 7 XFAIL / 0 XPASS** (was 85/0/8/0). The retirement is case
`52`, the empty-for-loop this section's fix makes correct (`e=""; for w in $e`
is ZERO iterations) — its xfail is gone from the script and the case runs as a
plain PASS. The one FAIL, `10_holes_slice`
(`a=(a b c); a[5]=z; v="${a[*]:1:3}"` → bash `[b c z]`, C `[b c]`), is NOT this
round's: the program's shIR contains ZERO `split` nodes (every expansion in it
is quoted), so the fold cannot reach it, and it fails identically on a binary
built BEFORE the `dead_store_elim` restore below. It is a sparse-array SLICE
divergence (the presence-order `[*]:off:len` face, `c_join_ifs.rs`'s
`_sh_join_arr_rng` territory) in the shared tree — recorded here as the next
target rather than papered over, and RETIRED in §35 (the battery now reads
86 PASS / 0 FAIL / 7 XFAIL).

**A second reverted file, restored.** The same rollback that took
`c_backend.rs` also reverted `src/transforms/dead_store_elim.rs`, losing the
`c_subscript.rs` §20g LIVENESS half (`subscript_read_names` /
`arith_read_names`: a FLATTENED subscript keeps its references as text, so
`i=1; n[$((i*2))]=5` judged `i` never-read and DSE dropped its only store —
the renderer then named an undeclared var and `cc` failed). With the file
restored from the pre-rollback snapshot the IFS battery's nine `(cc)`
failures (59k/59l/59m/59/59c/59g/59i/…) all clear; the file diff against the
working tree was 150 removed vs 2 added lines, i.e. the working copy was
strictly behind. `./fail` 563/563 and the C gate 625/19/7 above were re-measured
AFTER this restore, so both numbers describe the final tree.

**Corpus.** `harness/c_gate_main.sh` with `CORE_BIN` set to the binary built
from the restored source: **625 PASS / 19 FAIL / 7 SKIP**, and the FAIL list is
byte-identical to the 13:05 baseline taken BEFORE the rollback (same 19 files,
same reasons: ten `stub:N`, nine `exec/diff`). So the whole session's C work,
recovered and rebuilt, is corpus-equivalent to the state it was measured in.

That is not the number the earlier `c-gate-repro.sh` path produces, and the
difference is a harness fact worth recording: that script renders through a
dedicated `c_backend` binary whose output `#include <uu_run.h>`, and its plain
`cc "$base.c" -o "$base.bin"` has neither `-I$SUB/runtime` nor
`-lcoreutils_ffi`, so 65 cells report `FAIL compile` that `c_gate_main.sh`
(which passes `UU_INC`/`UU_LIBS`) compiles clean. Quote `c_gate_main.sh`.

The twelve corpus files that mention `set --` or an element `:=` are
output-identical under this round's binary and the pre-round one, which is why
neither change moves a corpus cell.

**Tree state — the rollback, and its recovery.** The checkout is SHARED and a
concurrent worker reverted `sh2perl/src/c_backend.rs` to `1445f283b` at 17:37
while this round was running (`git status` clean, 2,470,051 bytes = `HEAD:`), and
the rollback also took the uncommitted MODEL extensions with it. It is
recoverable and was recovered: `git fsck --lost-found` still held the pre-rollback
snapshot as dangling commit `7cba3b7fc` ("On (no branch): temp2", 17:32), whose
`src/c_backend.rs` is 2,585,965 bytes — the whole session's C work, including
this round's ordering snapshot — plus `+324` lines of `c_join_ifs.rs`, `+413` of
`c_sparse_array.rs`, `+267` of `c_assoc_array.rs` and `+157` of
`c_decl_coverage.rs`. Those six files were restored from it verbatim; nothing
else was touched, so other workers' current edits stand.

Why the work is uncommitted at all is the standing instruction: `AGENTS.md`
requires an explicit path list per commit and this tree carries everyone's
in-flight edits, so an uncommitted file is one `git checkout` away from
evaporating. A commit of the six files above would have made this section
unnecessary.

**The probes after the restore: 26 of 28.** The two misses are:

- `set -- ${a[0]} ${a[0]:=z}` — the unquoted `${a[i]}` erasure pinned below
  (bash 1 positional, C 2).
- `${a[$((i+1))]}` — `long long _ak1 = i+1;` with **no C declaration of `i`**
  (cc: `'i' undeclared`). Reproduced with the *previous* binary and with no
  `:=` in the program at all (`a=(1 2); i=0; echo "${a[$((i+1))]}"`), so it is
  not this family: `dyn_key_c` asks `arith_var_value`, which returns
  `c_ident("i")` because `is_num("i")` holds, while the declaration census
  homed `i` in the STORE — the homed/decl disagreement `c_decl_coverage.rs`
  exists to count. Left red and recorded rather than papered over with a cast.

So the accountability this session can stand behind today is: the ORDERING model
and its two source hooks are in the tree and verify; everything §26d and the
earlier `c_*` sections measured needs its source and its model extension
re-landed before those numbers describe the shipped binary again.

## 35. The sparse SLICE window — `[*]`/`[@]` `off:len` has bounds of two different kinds (2026-11-05)

`10_holes_slice` was left red by §34 as the next target: `a=(a b c); a[5]=z;
v="${a[*]:1:3}"` gives bash `[b c z]` and gave C `[b c]`. Its shIR contains zero
`split` nodes and every expansion in it is quoted, so no word-level fold can
reach it; it is the presence-order slice face (`_sh_join_arr_rng`).

**The measured rule.** An (off, len) grid over four sparse shapes — 476 rows,
both faces, offsets −7..6, lengths 0..9 and omitted — pins it, and the two
bounds are of DIFFERENT KINDS:

```
  OFFSET   indexes SLOTS.  Negative counts slots back from last_index+1.
           Out of range is EMPTY — never a clamp to the first/last element.
  LENGTH   counts PRESENT ELEMENTS, scanned forward from that slot —
           holes are skipped and do NOT spend the length.
```

So `:1:3` on `a[5]=z` is `b c z` (three elements from slot 1), `: -4:1` is `c`
(slot 6−4 = 2), and `:6` is empty because there is no slot 6 in a 6-slot array
even though there are four elements. The pre-fix helper bounded the window by
`b + len` *slots*, and counted a negative offset in *elements*; both are now
single-measurement facts rather than readings.

**The fix is three lines of the emitted helper plus the model.**

```c
  long long b = off < 0 ? ((off < -(long long)n) ? -1 : (long long)n + off) : off;
  if (b < 0 || b >= (long long)n) { empty }
  if (len < 0) { "substring expression < 0"; exit(1); }
  for (size_t i = (size_t)b; i < n; i++) {
    if (!a[i]) continue;              /* a hole costs a SLOT, not the length */
    if (taken >= len) break;          /* the length counts PRESENT elements  */
    …
    taken++;
  }
```

Guard order matters and is modelled: `b` out of range is EMPTY *before* the
negative-length error, because bash's empty result for a bad offset is not an
expansion error even when `len < 0` (`c31_out`: `a=(a b c);
"${a[*]:9:-1}"` → empty, rc 0 in bash and in C) while an in-range one is
(`c30_out`: `:1:-1` → `-1: substring expression < 0`, rc 1 both sides).
Re-measured 2026-11-05 on this binary, including the sparse `:1:-2`.

**What the model had, and what it lacked.** `c_join_ifs.rs` already carried a
`rng_slice` that stated the right rule — and the shipped helper was written
before it, so the model never contradicted the code. Stating the rule is not
the obligation; the obligation is the ROW. The model now keeps the retired
window as an executable transcription (`slot_window`, the `b + len` slot
bound) and states the measured rows as the obligations where the two disagree:

| obligation | row | bash | retired |
|---|---|---|---|
| `mw1_holes_do_not_spend_the_length` | `a[5]=z`, `:1:3` | `b c z` | `b c` |
| `mw2_leading_holes_are_skipped_not_counted` | `a[3]=x; a[7]=y`, `:0:2` | `x y` | EMPTY |
| `mw3_offset_indexes_slots_not_elements` | `a[5]=z`, `: -4:1` / `: -2:1` | `c` / `z` | `a` / `c` |
| `mw4_out_of_slot_range_is_empty` | `:6`, `: -7` | EMPTY | clamped |
| `mw5_length_counts_elements_from_the_start_slot` | `a[3]=x; a[7]=y`, `:0:1` / `:3:1` / `:4:2` | `x` / `x` / `y` | EMPTY / EMPTY / `y` |
| `mw6_both_faces_agree_after_the_fix` | `:1:3` under IFS=` ` / `:` | `b c z` / `b:c:z` | same rule, one helper |

`c_join_ifs.rs` is **92 verified, 0 errors** (was 82). The gate row now expects
92, and its comment records the mixed-bounds rule and the six measured rows, so
the next reader sees that this family's denotation is two rules and not one.

**Measured after the fix, on the binary built from this tree.** A 136-row
probe — the four sparse shapes × 17 (off, len) specs × both faces, each row run
in bash and as a compiled C binary with `rc` compared too — reads
**136 of 136**. `10_holes_slice` is green in the battery, which is why it is no
longer listed as an open divergence in §34.

**Blast radius, measured.** `harness/c_gate_main.sh` on the same binary reads
**625 PASS / 19 FAIL / 7 SKIP**, and both the FAIL list and the reason
histogram are byte-identical to the §34 baseline (10 `stub:4`, 5 `exec/diff`,
2 `stub:3`, 1 `stub:14`, 1 `stub:1`). `harness/ifs-probe.sh` moves from
85/1/7/0 to **86 PASS / 0 FAIL / 7 XFAIL / 0 XPASS** — the one FAIL is the case
this section retires, and no xfail changed state.

**Not modelled, still.** A slice on assoc storage (`${m[*]:1:2}` keys/values),
and `${!arr[*]:off:len}` — the key list's slice — which the CORE still drops the
face of for assoc (case 56); both are separate faces with their own bound rules,
not consequences of this one.

## 36. The ASSOC and KEY faces — three join rules, a one-based slice, and a collapsed `!` family (2026-11-05)

§35 closed the indexed slice. This round took the faces around it that the
model had never measured: the assoc value join, the key join, the assoc slice,
and the `!` family as a whole.

**The measurement trap that hid two of these.** Every earlier reading of the
assoc join was taken through `echo "${m[*]}"`, where a MULTI-WORD expansion is
re-joined by `echo` itself with spaces. That makes a wrong separator and a
one-word collapse look identical. Re-measured in a **one-word context** (an
assignment — `v="${m[*]}"`), bash says:

```
  IFS=:  ${a[*]}   = p:q:r      ${a[@]}   = p q r      ${a[*]:0:2} = p:q   ${a[@]:0:2} = p:q
  IFS=:  ${m[*]}   = x:x        ${m[@]}   = x x        ${m[*]:0:2} = x:x   ${m[@]:0:2} = x:x
  IFS=   ${m[*]}   = xx         ${m[*]:0:2} = xx       ${m[@]:0:2} = x x
  IFS=:  ${!a[*]}  = 0:1:2      ${!a[@]}  = 0:1:2      ${!k[*]} = b:a      ${!k[@]} = b:a
  IFS=   ${!a[*]}  = 012        ${!a[@]}  = 0 1 2      ${!k[*]} = ba       ${!k[@]} = c b
  IFS=:  ${m[*]:1:2} = x:x      `${m[*]:0:1}` = x       `:1:1` = x    `:2:1` = x (2nd element)
  ${m[*]:9:1} = EMPTY  ${m[*]:-9:1} = the WHOLE list   ${m[*]:1:-1} = error rc 1
```

Three separate rules fall out, and the shipped code got all three wrong:

| face | bash | shipped before |
|---|---|---|
| assoc value `[*]` | IFS[0], empty IFS concatenates | hardcoded NEWLINE |
| assoc value `[@]` | a SPACE, even under `IFS=:` | hardcoded NEWLINE |
| key face, both faces, both storages | IFS[0]; `[@]` falls back to a SPACE on an empty IFS | unconditional space for assoc, space for every `[@]` |
| assoc slice | see below | joined the store and sliced the STRING → `${m[*]:1:2}` rendered EMPTY |

**The assoc slice is bash's own quirk, and it is not the indexed rule.** A
POSITIVE offset is ONE-BASED: `:0:1` and `:1:1` both take the first element,
`:2:1` the second (measured on 2-, 3- and 5-element maps, so it is not a hash
ordering artefact — the element COUNT is what shifts). An offset past the end
is EMPTY; a NEGATIVE offset is `n + off` **clamped at 0** (`: -9` on three
elements is the whole list, never empty); the length counts elements; and a
negative length is the expansion error, but only for an IN-RANGE offset (the
same guard order as the indexed helper). The emitted `_sh_assoc_rng` is that
rule and nothing else, and the dispatch sends assoc slices to it instead of
through `_sh_arr_slice`.

**Why 064_07 passed while the join was wrong.** The retired assoc join was a
hardcoded newline, introduced so a `sort` pipeline could sort individual
values. It is the `[*]` rule for exactly ONE IFS — a newline — and 064_07 is
the example that sets it:

```sh
IFS=$'\n' sorted=($(sort <<<"${config[*]}"))   # examples/064_07_…sh:10
```

So the example was green for the reason the code was wrong. Reading IFS[0]
keeps that line byte-identical and fixes every other IFS; `nl_join` in the
model keeps the retired fold as an executable transcription and `k2` proves
both halves (`nl_join ≠ star_join` under the startup and colon IFS,
`nl_join == star_join` under a newline IFS). The helper itself is deleted —
nothing called it. Model: **104 verified, 0 errors** (was 92), with k1a-k1d,
k2, k3 and a1-a6.

**The `!` family is one collapsed node, and that is a PROOF, not a gap.** Five
spellings lower to the same shIR (`--target shir --raw`, measured):

```
  ${!a[*]}  ${!a[@]}  ${!a[*]:1:2}  ${!a[@]:1:2}  ${!a[1]}   ->  param("slice","!a","@","")
```

Face, bounds and even the subscript are gone, while bash gives four different
behaviours: the whole list (`0 1 2`), an ERROR for both slice spellings
(`p q r: invalid variable name`, rc 1 — the slice INDIRECTS the joined VALUE
list; it is not a key slice at all), and EMPTY for `${!a[1]}`. So no renderer
of that node is exact — `k1c` proves it with the `[@]` reading as the only
hypothesis available, and `k1d` pins the exactness DOMAIN that still holds: the
shipped rule is exact for `[@]` under every IFS and for `[*]` whenever IFS is
non-empty (they coincide there), leaving ONE row — `${!a[*]}` with an empty
IFS — as the cost of the erasure. That is why `ifs-probe` case 56 could be
RETIRED this round (it measures the non-empty-IFS row) even though the node is
still collapsed. The contract fix is filed as
`core-requests/c-20261105-keys-face-collapse.md`, with the two shapes that
would close it.

**Measured after the fixes, on the binary built from this tree.** A 28-row
assoc/key probe — equal values where order must not matter, key rows comparing
the separator, error rows comparing rc as well — reads **25 of 28**: the three
misses are the two proved-erasure rows (empty-IFS `[*]` keys) and bash's
`file: line N:` stderr prefix on the error rows (the same cosmetic delta as
every other C-backend error). `harness/ifs-probe.sh` **87 PASS / 0 FAIL /
6 XFAIL / 0 XPASS** (was 86/0/7/0; case 56 retired, no xfail changed state).
`harness/c_gate_main.sh` **625 PASS / 19 FAIL / 7 SKIP**, FAIL list and reason
histogram byte-identical to §35 — so the three join changes move no corpus cell,
including 064_07 and 029 (which sorts `${!map[@]}`).

**Still not modelled.** The `[@]` face as a LIST OF WORDS: bash expands
`printf '<%s>' "${a[@]}"` to N arguments and `set -- "${a[@]}"` to N
positionals, while the C renderer emits ONE joined word (measured: 3 vs 1 for
`a=(1 2 3)`, and 2 vs 1 for an assoc). That is a renderer-wide contract
(`at_join` is provably the space join, so it is exact only in a single-word
position), it needs a push-per-element path at all three argv sites, and it is
the next increment rather than a one-face patch.
