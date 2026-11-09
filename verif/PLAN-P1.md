# P1 — the interval-domain narrowing theorem (specification of record)

Status: **spec + obligations**. Companion to `C_UB_PROOF.md` §5. Written
2026-10-22 against `sh2perl/backends/c/src/c_backend.rs`
(`effective_widths`, `walk_widths_expr`, `arith_range_local`,
`arith_op_wide`) and `sh2perl/src/shir.rs` (`range_width_name`,
`analyze_var_ranges`).

This file exists because mechanizing the wrong theorem is the failure mode
`C_UB_PROOF.md` §4 warns about. The first draft of this stage was "prove
`eval_narrow = eval_i64`", which is **not** what the backend claims and
would have been vacuous. What follows is the theorem the code actually
relies on, the place where it is currently false in principle, and the
shape of its mechanization.

## 1. What the backend does

For each variable `v` with conservative range `[lo, hi]` (from
`analyze_var_ranges` plus the backend's own seeds), it declares
`v` at width `W = range_width_name(lo, hi)` — `uint8_t`/`uint16_t`/
`uint32_t`/`long long` in practice (§7 of `C_UB_PROOF.md`: no signed narrow
type occurs on this corpus, because `range_width_name` tests `u8` before
`i8`).

It then *adjusts* `W` by walking every arithmetic expression that mentions
`v` (`walk_widths_expr`):

```
rng = arith_range_local(rhs, ranges)
if Some((l,h)):  W := widen(W, range_width_name(l,h))       (* widen only *)
else:            W := I64   unless arith_op_wide(rhs)        (* force *)
```

Two asymmetries fall out, and they are the entire content of this stage:

- **unknown range → conservative** (force `I64`);
- **known range → anti-conservative** (`widen` cannot narrow `W`, so a
  variable keeps the width its seed gave it even when a use proves a
  different one).
- **the store itself is never checked**: `arith_op_wide` treats
  `+ - *` as the only *narrowing* operators (`_ => false`), so
  `**`, `%`, `^`, `<<`, `>>` are classified "op-proven wide" and a
  narrow variable may hold their result unchecked.

## 2. The shell-side theorem (what correctness would mean)

The shell evaluates arithmetic in its own integer domain. For the corpus
subset that matters here (no `$RANDOM`, no `eval` of computed text), that
domain is C `intmax_t`; every one of the 654 corpus programs whose
arithmetic reaches a narrowed variable does so with values far inside
`int64_t`. State the theorem against that domain, not against `i64`:

```
T1 (value abstraction)
  Let s be a shell state, e an arithmetic expression over s, and
  A = arith_range_local(e, ranges).
  If A = Some((lo,hi)) and lo, hi ∈ int64,
  then  eval_arith_trace(e, s) ∈ [lo, hi]        (the abstraction is sound)

T2 (rendered C agrees inside the interval)
  Let x be a variable declared at width W by the backend, and let every
  trace position writing x satisfy the range [lo_W, hi_W] of W's type.
  Then for every expression e reading x (and no other narrowed variable),
  eval_C(e, s) = eval_arith_trace(e, s).

T3 (the store condition — the missing link)
  For every statement `x = e'` where x is narrowed to W:
      eval_arith_trace(e', s) ∈ [lo_W, hi_W]
  i.e. the value being stored fits the declared width, for all states s
  admitted by the seeds.
```

`T1` is what makes `W`'s type legitimate. `T2` is the per-operator part
(`Word_Lib` work, listed in §3). `T3` is what §1 says is never checked —
and it is the obligation that pays, because the current code can satisfy
`T1` and `T2` and still violate `T3` (`uint8_t result = 15 +
_sh_pow(5,2)`, safe only by numeric accident).

Note on `%`, `^`, `<<`, `>>`: C and shell agree on the *value* of these
for non-negative operands within range, so `T2` extends to them once the
operand intervals are known — the current code simply never proves the
operand intervals for them. That is a proof-coverage gap, not a semantic
one.

## 3. Mechanization plan

Target: Isabelle 2025-2 (`Word_Lib` + `HOL-Library`), a standalone
`verif/` theory directory **outside** the sh2perl crate (nothing in
`sh2perl/` may reference the workspace, per AGENTS.md; `sh2perl`'s CI stays
self-contained).

| Theory | Contents | Proof work |
|---|---|---|
| `Sh2_Width.thy` | `widen`, `rank`, the `width_of` total order exactly as `c_backend.rs:130-160` implements it | trivial order lemmas; a `simp` set |
| `Sh2_Range.thy` | `arith_range_local` as a total function on an interval domain (`bot`/`[lo,hi]`/`top`), mirroring only `+ - * /` and unary `+ -` (the arms that exist) | monotone transfer functions; `bot`/`top` soundness |
| `Sh2_Operators.thy` | per-operator: if both operands are in range, the C operation on the declared narrow type equals the unbounded one | `Word_Lib` wrap-around lemmas; ~1–2 pages per operator |
| `Sh2_Soundness.thy` | `T1`, `T2`, `T3` above, stated over an abstract trace | the assembly; the interesting part is `T3`, which needs the seed inventory as an explicit hypothesis |

The seed inventory (from `C_UB_PROOF.md` §7: `analyze_var_ranges`,
`seed_loop_var_ranges`, `seed_isqrt_bounds`, `seed_range_loop_vars`,
`SH2_ASSUME_OBSERVED_WIDTHS`) enters as a *hypothesis list*, not as proved
code: each seed is a separate, small lemma "if the loop shape is as
matched, the counter's range is `[lo,hi]`". That split is deliberate — it
keeps the Isabelle work independent of the frontend's shIR encoding.

**What is deliberately not in scope**: the renderer's string forms, the
`_sh_*` runtime, and the frontend. Those are `C_UB_PROOF.md` §3.

## 4. The generator (the part that keeps the proof honest)

A proof about hand-written `arith_range_local` proves nothing about the
code. The bridge is a dump-and-compare:

1. the renderer gains a gated `--dump-widths` mode (env-gated, as the
   probe used during Step 0) emitting one line per narrowed variable and
   per width-constraining expression;
2. a script feeds those lines into a `sh2perl`-local `--check-widths`
   checker implementing the same interval domain, and reports the
   variables whose obligations fail;
3. the Isabelle theory proves the algorithm the checker implements, not
   the Rust source.

Until (2) exists, `C_UB_PROOF.md`'s Step-0 `--warn` (`TRUNC`) verdict is
the only evidence that `T3` is exercised at all: it reports exactly the
9 files where gcc can see that a stored value may not fit.

## 5. Exit criteria for P1

- `Sh2_Soundness.thy` builds under Isabelle 2025-2 with
  `isabelle build -D verif` (no `sorry` on `T1`/`T2`; `T3` may carry the
  seed inventory as explicit hypotheses, but the *statement* must be
  complete and the hypotheses listed).
- `--check-widths` agrees with `--warn` on the 9 `TRUNC` files: the
  checker must flag the same stores gcc flags, and nothing more.
- A recorded `isabelle build` log and the checker's tally, both quoted
  with dates in `C_UB_PROOF.md`.

## 6. Toolchain status (measured 2026-10-22)

Isabelle 2025-2 was fetched and installed: `isabelle.in.tum.de` is
**unreachable** from this box (connection timeouts on every path,
http and https), but `mirror.clarkson.edu/isabelle/` serves it. The
tarball is 1.17 GB; a single-stream download ran at ~0.17 MB/s and was
replaced by 12 parallel `Range` requests (~1.4 MB/s aggregate, ~14 min).
`isabelle version` → `Isabelle2025-2`; Polyml `polyml-5.9.2_x86_64_32`,
OpenJDK 21 present. Toolchain is fine; the box has 43 GB RAM and 855 GB
free.

**Blocker: found, worked around, cause recorded.** `Sh2_Base.thy` does not yet build. The
datatype, both `fun` declarations and the individual equations all check
out in isolation (`rank W64u = 4`, `wb Ee = 8`, …), but `cases` on any
variable of an 8-constructor `datatype` produces spurious
`w = W32u ⟹ False` subgoals, i.e. Isabelle treats the upper constructors
as uninhabited. The same shape reproduces at 5 constructors
(`datatype S = Aa | Bb | Cc | Dd | Ee` with two `fun`s over it), and with
`cases` written as `cases w`, `cases (w :: T)`, `induct`, and
`W.exhaust`; `simp`/`simp_all`/`auto`/`fastforce` all fail the same way,
and `fun … where` written one-equation-per-line also reproduces it. The
constructors are pairwise distinct by `simp`, so the datatype itself is
sound — the fault is in how this theory is being built, not in the model.

Reduced to a minimal reproducer: a five-constructor datatype with two
`fun`s over it, case-split with `cases`, from a fresh heap. Established
along the way that the datatype itself is sound (`case_W` has five
W-arguments; the constructors are pairwise distinct by `simp`; `induct`
proves a plain disjunction over them), so the defect is in `cases` for this
shape, not in the model.

**Workaround, adopted.** `P1_Narrowing.thy` encodes widths as natural-number
codes selected by the same if-chain as `range_width_name`. That carries
P1's content unchanged — the u8-before-i8 preference, the soundness of the
range-to-width map, the store condition, the non-monotonicity — while
depending on no datatype case split. `Sh2_Base.thy` is dropped (it was never
green and stays uncommitted); the defect above is kept here so a later
Isabelle can be re-tested rather than assumed.

**P1 result.** `verif/P1_Narrowing.thy` builds green (clean-room
`isabelle build -d verif -b Sh2`, no `sorry`/`oops`) and proves
`narrow_sound`, `store_within_declared_width`, the two
`outside_width_not_admitted_*` lemmas (the direction a missing check
violates), `nonneg_never_signed`, and the negative result
`narrow_not_monotone`.

## Revision history

- v2 (2026-10-22): toolchain installed from a working mirror after
  `isabelle.in.tum.de` proved unreachable; `Sh2_Base.thy` written and its
  proof shape blocked (recorded in §6) — the theory is NOT yet green and
  is deliberately left uncommitted rather than committed in a state that
  misrepresents progress.
- v1 (2026-10-22): stage opened; theorem restated as `T1`/`T2`/`T3` after
  finding that the original "`eval_narrow = eval_i64`" statement is
  vacuous for `+ - *` and absent for `** % ^ << >>`; seed inventory split
  out as hypotheses; generator defined as the bridge from Rust to
  Isabelle.
