# Can Isabelle prove the C backend produces no UB?

Status: **assessment + staged plan**. No sanitizer pass, no proof obligation
and no mechanized invariant exists today. Written 2026-10-22 against
`sh2perl/backends/c` @ `5b1524085` (`src/c_backend.rs`, 50,747 lines).

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

`array_caps` gets the same treatment: `ARR_CAP = 1024` is the unproven
default (`c_backend.rs:786`), and the "sizing from proofs: max literal reset
bulk + bounded appends" claim (`:350-352`) is exactly a length abstraction to
mechanize.

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
| **P3** length/array abstraction | `strlen ≤ N` at every write; `array_caps` sizing sound | `analyze_string_lengths`, `array_caps` (`:2732-2790`) | **DONE (capacity half)** — `verif/P3_Capacity.thy`, see §9 |
| **P4** renderer deep embedding | `render : ShIR → C_ast` respect the invariants | `c_backend.rs` (subset) | large |
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

**Not yet covered:** the `strlen ≤ N` half (the fixed-buffer transform at
`c_backend.rs:20-24`, where `assert` is debug-only and `NDEBUG` truncates).
That needs a string-length abstraction over the shIR, not a capacity
combinatorics argument, and is the remaining P3 work.

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

## Revision history

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
- v1 (2026-10-22): initial assessment and plan; no code changed, no
  sanitizer run performed yet.
