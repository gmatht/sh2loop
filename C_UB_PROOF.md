# Can Isabelle prove the C backend produces no UB?

Status: **P1, P2 and P3 mechanized and green; §2a's `ov`-flag obligation
mechanized in Verus and in Isabelle (§13); the Eq/Ne render decision and
the decimal renderers mechanized in Verus, the decimal round trip also in
Isabelle (§14); P4 blocked on the absent
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
literal is text, so the RAW arm emits `i != "2"`. Measured 2026-10-27 on
the 563-example corpus: 2 of 564 renders carry the gcc warning, and
`harness/c_gate_main.sh` fails 5 files whose transforms-ON output diverges
from bash while the transforms-OFF output matches it (`or-continue`
rc=1, `func-after-test-or` rc=134 abort on UB, plus three of the same
decision class).

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
arithmetic denotation, green under `quick_and_dirty = false`).** The bytes
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
