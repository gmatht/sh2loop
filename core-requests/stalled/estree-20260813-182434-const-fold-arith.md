# estree: constant folding over the A1 (arith + const pool) and native $(( )) elision

## NEED

Two related folds at the A1/ESTree boundary:

1. **Constant folding**: evaluate `Arith`/`arith` nodes whose operands
   are all Int literals or const vars (the A1 `var_const` pool — 25
   Const entries in the mimecroft contract: MAP_W, MAP_D, CELLS, AIR,
   STONE, …) at compile time, emitting the folded int literal.
2. **Native `$(( ))` elision**: emit `$(( ))` in assignment/argument
   position as a plain int expression instead of the
   `sh2.arithEval(() => (Number(x ?? (sh2.env.x ?? "")) || 0) * 48271 %
   2147483647)` closure, when the expression is pure int
   (Int-typed operands only).

## WHY

The generated JS re-computes constants at runtime: `CELLS = MAP_W *
MAP_D` (16×16, recomputed once — fine), but the hot loops recompute the
full index arithmetic `b * CELLS + c * MAP_W + a` per cell with
string-typed operands (`Number(b ?? (…)) || 0` each), and rand()'s LCG
`seed = sh2.arithEval(() => (Number(seed ?? (sh2.env.seed ?? "")) || 0)
* 48271 % 2147483647)` wraps a pure-int multiply in a closure + String
coercion — measured **2.7×** plain int math (41ms vs 15ms per 2M). With
the `var_types` (122 Int) + `var_const` (25 Const) verdicts already in
the contract, both folds are decidable at emission.

## MINIMAL-CORE-CHANGE

1. A fold pass over `Arith` nodes (the existing `crate::bc::eval` /
   `parse_arith` machinery already evaluates literal arith — reuse
   it): replace a pure-literal `Arith` (all leaves Int literals or
   Const-verdict vars whose value is known) with `Int(folded)`; fold
   the assignments that initialise Const vars so the pool is usable.
2. In the `$(( ))` statement/argument emission (shir.rs → estree.rs):
   when the expression is pure Int (all operands Int-typed per
   `var_types`, no getVar-of-unknown, no capture), emit the native
   expression (`x * 48271 % 2147483647`) instead of
   `sh2.arithEval(() => …)` — the runtime's arithEval String() is only
   needed when the result feeds a string word.

## FAILING-CASE

    MAP_W=16; MAP_D=16
    CELLS=$((MAP_W * MAP_D))
    x=5; y=2
    idx=$((y * CELLS + x))
    echo "$idx"

currently emits `idx = sh2.arithEval(() => (Number(y ?? …) || 0) *
CELLS + (Number(x ?? …) || 0))` with `CELLS` left as a runtime
multiply. Folded: `CELLS = 256` once, `idx = y * 256 + x` native (the
Number/closure removal across the board is transform 1's typed
lowering; this request is the pure-int fold + arithEval elision on top
of it — independent and behavior-preserving). Corpus gate:
`./fail-estree` at the trusted baseline.
