# estree: pure-int case → const lookup table (hardness/texture_of/block_color/mime_tex_of)

## NEED

A lowering that converts a **pure integer/char case-chain** into a
**const lookup table** indexed by the discriminant — the classic
switch-to-table transform. The game's per-block colour/texture
functions (`hardness`, `texture_of`, `mime_tex_of`, `block_color`,
`glyph_index`) are literal-arm case chains on int/char discriminants,
called ~768×/frame (per block), and each arm currently emits a
`Number(x) === Number(2)` or `String($sh_case) === "2"` compare + the
lastExit dance.

## WHY

`texture_of` (per block): 5 arms `to_t===2→"1", 4→"2", 5→"3", 6→"4",
7→"5", else "0"` — an array `const TEX_OF = [0,0,1,0,2,3,4,5]` plus
`tx = TEX_OF[to_t] ?? "0"` is one indexed read vs ~15 ops of
Number-compares + lastExit writes. `hardness` (per damaged block):
`2→2, 3→3, 5→2, 6→2, else 1` — `HARDNESS = [1,1,2,3,1,2,2,1]`.
`block_color` (per block): 7 arms of three colour strings →
`const COL = [[…],[…],…]`. `glyph_index` (per HUD char): A-Z → index —
a lookup or a map. Same emission for every backend that renders Case
with literal arms (the C/go backends benefit too).

## MINIMAL-CORE-CHANGE

An IR-level pass (shir_passes or the transforms channel): for an
`IrStmt::Case` (or the if-chain a small case lowered to) whose
discriminant is an Int-typed var/expr and whose clause patterns are
all **integer literals** with a known bounded domain:

1. Build the table: `const <fn>_TAB = [v0, v1, …]` (max pattern value +
   guard for gaps; default = the else arm value).
2. Rewrite each clause assignment to `TAB[disc] ?? default` (a single
   indexed read + nullish fallback; the `|| default` for out-of-range).
3. Gate: only when the discriminant's `var_types` verdict is Int (a
   Str discriminant keeps the string chain — the runtime's string
   compare semantics are authoritative) and the arms are pure
   assignments/returns (no side effects, no breaks out of an outer
   loop — a `case` inside a loop with `break` semantics must stay).

## FAILING-CASE

    hardness() { case $1 in
      2) h=2 ;; 3) h=3 ;; 5) h=2 ;; 6) h=2 ;; *) h=1 ;;
    esac }
    x=3
    hardness $x
    echo "$h"

currently emits the `const $sh_case` + 5-arm `String($sh_case) === "2"`
chain (5 compares + lastExit writes per call); with the table:
`h = HARDNESS[3] ?? 1` (HARDNESS = [1,1,2,3,1,2,2,1]) → 3. Output
identical; corpus gate (`./fail-estree`) judges. Composes with
request …-inline-pure-fns (the table read inlines into the hot loop).
