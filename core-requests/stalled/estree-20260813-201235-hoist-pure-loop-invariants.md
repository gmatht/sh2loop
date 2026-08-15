# estree: hoist loop-invariant PURE function calls out of inner loops

## NEED

A shIR pass that **hoists a pure function call (and its derived
statements) out of a loop when the call's arguments are loop-invariant
in that loop** — the texture generators' per-column work is recomputed
for every pixel:

    while [ "$y" -lt "$SIZE" ]; do
      x=0
      while [ "$x" -lt "$SIZE" ]; do
        lat_hash $x 0 $SIZE 1        # ← depends only on x — 16× redundant
        gph=$(( lhn % 3 ))
        stripe=$(( (x + gph) % 5 ))
        coff=$(( (lhn - 128) / 5 ))
        ...
      done
    done

## WHY

The pseudorandom texture generators (`www/examples/textures/
texture-*.sh`, the game's 9+ startup textures) run ~256 pixels with
~2800 dispatched calls/closures per texture (measured 47ms/texture
transpiled). The wood texture's **column hash** `lat_hash $x 0 $SIZE 1`
(4 mods, 2 64-bit mults, 2 XOR-shifts) plus its derived
`gph`/`stripe`/`coff` depend ONLY on `x` and the const `noise_seed` —
yet run once per pixel: 16× redundant per column (240/256 wasted).
`lat_hash` is provably pure (reads only `noise_seed`, writes `lhn`);
`rand` is NOT (it advances the LCG stream) and must never be hoisted —
the purity check is the whole soundness story. The same pass benefits
`vnoise2`'s lattice hashes when a texture keeps one coordinate fixed.

## MINIMAL-CORE-CHANGE

In the transforms channel (`fn(&mut Vec<IrStmt>) -> bool`) or shir_passes:

1. **Purity table**: a callee is hoistable iff it is a user function
   whose body is pure integer computation — Assign/arith/lat_hash-style
   calls, `If` with pure bodies, NO `rand` (no call to any callee that
   mutates a program var read elsewhere), no exec/redirect/subshell.
   (The inline-pure-fns request — estree-20260813-182431 — needs the
   same purity analysis; share it.)
2. **Invariance**: for each `While`/`For` body, a statement's operand
   expressions are loop-invariant iff every variable they read is not
   assigned anywhere in the loop body (the existing
   `var_lifetimes`/write-scan machinery). A `Call` whose callee is pure
   AND whose args are invariant → hoist the call + every immediately
   following statement that reads only the call's results and
   loop-invariant vars (the dependent block: `gph`/`stripe`/`coff`
   read `lhn` + `x`) into the loop PREHEADER (before the inner loop,
   still inside the outer loop). A pure call's side effect is only its
   output var — hoisting is sound if the loop body doesn't otherwise
   read that var before the call site.
3. **Keep the inner loop when the block has side effects** (rand /
   exec / store writes a var read elsewhere) — the conservative fallback.

## FAILING-CASE

    SIZE=16
    lat_hash() { lh_x=$1; ... lhn=$(( ... )) }   # pure
    y=0
    while [ "$y" -lt "$SIZE" ]; do
      x=0
      while [ "$x" -lt "$SIZE" ]; do
        lat_hash $x 0 $SIZE 1
        gph=$(( lhn % 3 ))
        stripe=$(( (x + gph) % 5 ))
        r=$(( 128 + stripe * 10 ))
        emit
        x=$(( x + 1 ))
      done
      y=$(( y + 1 ))
    done

currently emits `lat_hash` + the `gph`/`stripe` derivation inside the
inner loop (256 calls); hoisted, the column block runs once per column
(16 calls) in the outer loop. Output bytes identical (the values are
the same for every row). Corpus gate: `./fail-estree` at the trusted
baseline — the risk is a "pure" verdict on a callee with a hidden side
effect, which the purity analysis must catch (rand is the canonical
counterexample and stays put).
