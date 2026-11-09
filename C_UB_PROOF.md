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
  `c_sparse_array.rs` (28 obligations, mutants m1–m3 + the
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
- v1 (2026-10-22): initial assessment and plan; no code changed, no
  sanitizer run performed yet.

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

## 22. The decl-coverage censuses — `c_decl_coverage.rs` (51 obligations)

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

What is proved (51 verified):

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
control. The pin↔corpus mapping remains the value-level tie (pins are
UNMIRRORED in the sync's pin map by design: the probe battery +
corpus shapes are what cargo cannot run).

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

## 26. The sparse-array read faces — `c_sparse_array.rs` (28 obligations)

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

Gate-registered (`c_sparse_array.rs:28:40`); like the other `c_*`
models, an emission decision with no sync baseline — its living tie
is the pin↔probe mapping (the nine-face probe) and the source
control above.

## 27. The associative-array faces — `c_assoc_array.rs` (41 obligations)

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

Gate-registered (`c_assoc_array.rs:41:40`); like the other `c_*`
models, an emission decision with no sync baseline — its living tie
is the pin↔probe mapping (the a/b/c probe battery) and the source
control above.

## 28. The IFS joins — `c_join_ifs.rs` (54 obligations)

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
