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
