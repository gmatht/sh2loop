# estree: loop-invariant hoisting + index strength reduction in For/While bodies

## NEED

An IR-level loop pass that **hoists loop-invariant arithmetic** and
**strength-reduces the index-accumulation shape** (`idx = b*CELLS +
c*MAP_W + a` recomputed per iteration) inside `For`/`While` bodies, so
the emitted JS stops re-deriving the same products every iteration.

## WHY

MIMEcroft's render loops are the hot path:

    rf_z=0
    while [ "$rf_z" -lt "$MAP_D" ]; do
      rf_x=0
      while [ "$rf_x" -lt "$MAP_W" ]; do
        try_draw $rf_x 2 $rf_z
        try_draw $rf_x 1 $rf_z
        try_draw $rf_x 0 $rf_z
        rf_x=$((rf_x + 1))
      done
      rf_z=$((rf_z + 1))
    done

Each `try_draw` → `get_cell` re-derives `idx = b*CELLS + c*MAP_W + a`
from scratch (transform 3/4 remove the dispatch + splits, but the
arithmetic itself is re-computed). The inner `b*CELLS` and `c*MAP_W`
products are loop-invariant (CELLS, MAP_W are const); the `a`
component increments by 1. The classic transform: carry `idx` as an
accumulator (`idx += 1` per `a` step, `+= MAP_W - …` per row…), or at
minimum hoist the invariant products out of the loop and emit
`idx = (b * CELLS) + (c * MAP_W) + a` with the invariant subexprs
precomputed in the loop prologue.

## MINIMAL-CORE-CHANGE

An IR-level pass on `IrStmt::While`/`IrStmt::For`/`ForInit` bodies
(the transforms channel signature `fn(&mut Vec<IrStmt>) -> bool`):

1. **Invariant hoisting**: within a loop body, find `arith` nodes whose
   operand subtrees are loop-invariant (const vars, literals, or vars
   not assigned in the loop) and sink the pure-int products into
   `let`-style temps in the loop prologue. Conservative: only hoist
   when the operand is provably const per `var_const`/`var_types` —
   no alias risk.
2. **Strength reduction** (optional, only the clean shape): recognize
   the canonical `idx = i*K + C` recomputation where `i` increments by
   1 and K/C are loop-invariant — replace with an accumulator
   initialized once and incremented in the loop, guarded by the
   requirement that `idx` is only ever used read-only inside (no
   aliasing writes).
3. Behavior-preserving by construction (pure int arithmetic; the
   emitted byte stream of echoes is untouched — this changes only the
   JS arithmetic, not the output order). Corpus gate:
   `./fail-estree` at the trusted baseline.

## FAILING-CASE

    MAP_W=16; CELLS=256
    i=0
    while [ "$i" -lt 10 ]; do
      idx=$((i * CELLS + 3))
      echo "$idx"
      i=$((i + 1))
    done

currently emits `idx = arithEval(() => … i * CELLS + 3)` per iteration
with the multiply re-done each time; hoisted it becomes a prologue
`idx = 3` + `idx = idx + CELLS` per iteration (or the multiply kept but
`CELLS` folded to 256 — transform 6's domain; this request is the loop
structure). Output bytes identical.
