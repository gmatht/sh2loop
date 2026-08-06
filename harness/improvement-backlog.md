# Improvement backlog — candidate tasks for the estree worker (M8)

Pick one task (or find your own cheaper lowering). Each entry gives the
problem, the payoff, and the acceptance bar. The corpus at 516/516 is the
correctness oracle; `cargo test --lib` asserts determinism.

---

## Task 1 (submitted 2026-08-05): integer range analysis → native widths + BigInt escalation

**Problem — a real correctness bug, proven:**
```sh
x=9007199254740993; echo $((x+1))
```
bash prints `9007199254740994`; the current JS backend emits
`x = 9007199254740992` (the literal rounds to 2^53 as a `Number`) → wrong
answer, silently. JS `Number` is only exact to 2^53−1; bash arithmetic is
64-bit.

**Design (three directions from one `[lo, hi]` interval):**
- **narrow** (proven ⊆ small) → `u8/u16/u32/i32` — same proof, per-target width; also enables `u8` arrays and provably-non-negative array *indices*
- **default (optimistic)** → target native width: i64 for C/Rust/wasm (trivially sound — bash wraps at 64), **i53 (`Number`) for JS**
- **escalate** (proven ⊄ native) → **BigInt in JS** (`x = 9007199254740993n`, `x + 1n`, `String(x)`); i128 for C/Rust if ever needed

**Work already done (spike, apply to `src/shir.rs`):**
- `harness/range-analysis.patch` — `analyze_var_ranges` (interval lattice:
  literals, arith + - * /, copy, setVar; if/else join; loop invalidation),
  `range_width_name`, unit tests, an `#[ignore]`d corpus-width tally
  (`cargo test --lib range_analysis -- --ignored --nocapture`).
- Fixes the `Assign`-guard non-exhaustive match; `IrType` untouched
  (non-breaking; backends consult the new fn).

**Next steps (the acceptance bar for Task 1):**
1. Apply the patch; complete the `ArithAst` cases it punts on (Pow, IncDec,
   Cond, Assign, Index) with exact *wrapped* intervals — bash wraps at 2^64,
   so `$((2**62))` must come out as a precise value, not `Any`.
2. Wire `choose_width(lo, hi, target)` into the JS emitter's lifted-var
   path: proven ⊆ i53 → `Number` (today's output, byte-identical); not
   proven ⊆ i53 → `BigInt` literals/ops. The corpus must stay 516/516 and
   the 2^53 script must print the bash answer.
3. Run the corpus tally; report how many vars narrow / escalate.

**Why the worker, not the loop:** this is shared `src/shir.rs` analysis —
the exact M8 "cheapest correct lowering" mandate, and the type-narrowing is
what the static backends (C/Go/Zig) and the GLSL spike need downstream.

---

(Empty backlog — the worker is free to pick its own pattern family.)
## Task 2 (submitted 2026-08-06): full lifetime analysis — per-point bounds, copy-vs-move, allocation

**The seed is landed** (shir_passes/lifetime.rs, `VarLifetimes` in the
canonical pipeline, `--shir` `var_lifetimes`): per-variable live spans
`(first, last)` in statement positions + a conservative escape set
(array-element stores, closure captures, function returns). This task is
the **full** version — the per-point dataflow the seed deliberately
kept coarse, and the renderer decisions that consume it.

**Problem — the C backend's fixed-buffer transform is only sound with
per-point knowledge:**
1. **Per-var bound, not per-point.** `analyze_string_lengths` flips a
   var to `None` (heap) if ANY write is unbounded; a var bounded on its
   hot path loses its stack buffer globally. Live ranges give per-point
   bounds: bound the buffer where the var is live, reclaim/reuse it
   after `last`. Also shrinks the NDEBUG-truncation hazard
   (`strncpy` silently drops data when a write exceeds the bound).
2. **Copy-vs-move / alias.** Bounded vars copy (`strncpy`); unbounded
   vars alias (`char* a = b`). bash is value-semantics: a write to `b`
   after `a=$b` must not change `a`. The escape/liveness data decides:
   RHS dead after the assign → **move** (steal the buffer); both live
   and either written → **copy**; otherwise alias is safe. Today the
   draft dodges this only because every unbounded RHS is a stub that
   exits 2.
3. **Allocation placement.** The C draft has zero malloc/free. Real
   captures (`v=$(cmd)`) need heap: function-live vars → heap, free at
   `last`; loop-locals → one reused buffer per iteration; statement
   temps (interpolation, `%s` args, `c_str()`) → stack arrays. The
   existing `static char b[64]` in `c_str()` is a whole-program single
   buffer — two conversions in one expression clobber (today saved only
   because each `contains()` emits exactly one `c_str`).
4. **Function returns.** `IrStmt::Function` is still a TODO in the C
   renderer; a string-returning function needs a buffer that outlives
   the callee. The escape set IS the decision: returned vars → heap/
   copy; internal → stack. Nested `v=$(f)` is the same question.

**Payoff:** the native C path stays bash-faithful while the stub layer
lifts (the alias/truncation bugs above become reachable the moment the
runtime store or real captures land); per-point bounds recover fixed
buffers the global analysis throws away.

**Acceptance bar:**
1. `VarLifetimes` verdicts survive the ShIR JSON round-trip
   (`--shir` → `shir_json_in` → byte-identical, determinism test
   green).
2. A per-point bound consumer exists (a C-renderer probe or a unit
   test over `var_live_ranges`): a var unbounded globally but bounded
   on its live path gets a stack buffer there.
3. A move-vs-copy unit test over the escape set (`a=$b` where `b` is
   dead after → move; where `b` is written again → copy).
4. Corpus stays 516/516; `cargo test --lib` green; PERL pass count
   unchanged (the analysis is additive — it must not change any
   emission).

**Why the worker, not the loop:** shared-core dataflow (`shir_passes/`
+ `src/shir.rs`) feeding every static backend (C/Zig/Go) — the same
M8 "cheapest correct lowering" mandate as Task 1, and the
improvement-mode metric (sh2.* call sites) is untouched by design:
this is the C generator's correctness floor, not a JS speedup.
