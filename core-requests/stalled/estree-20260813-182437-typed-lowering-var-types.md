# estree: typed lowering — consume var_types (numeric lift + native int arrays) for the JS backend

## NEED

The ESTree backend should use the A1's **`var_types`** verdicts (122 Int
/ 116 Str in the mimecroft contract — already computed by
`analyze_var_types` and carried in the A1 JSON) to emit **native JS
numbers** for Int vars and **native number arrays** for Int arrays,
instead of the all-strings store protocol. The runtime side of the
contract is ALREADY LANDED in the sh2runtime repo (fast-path
`expandOperand`/`arrayIndex`/`setVar` — commit c5f5999); this request
is the Rust emitter half only.

## WHY

The mimecroft render loop (16×16×3 = 768 `try_draw`/frame) is built
entirely of string-typed arithmetic: every read re-derives
`Number(x ?? (sh2.vars.x ?? (sh2.env.x ?? "")))` (541 `Number(` calls
statically), every arith is `sh2.arithEval(() => …)` (53), every array
read is `sh2.arrayIndex("map", "$gi")` (36 → ~800/frame). Measured
against plain JS: `arrayIndex` on a string array is **18×** an
Int32Array read; the `arithEval` closure is 2.7× plain int math; the
fnCall arg split is 21×. The `numeric_lift_vars` machinery exists and
emits `let x = 0` + native `x = expr` for the vars it proves — but it is
too conservative for game code: a var referenced in a string context
(`[ "$rf_x" -lt "$MAP_W" ]`, `echo "$x"`) is marked store-read and never
lifts, so the mimecroft ints all stay strings. The A2 `var_types` tells
us the truth and is currently ignored by the estree path.

## MINIMAL-CORE-CHANGE

1. **Consult `var_types` in `numeric_lift_vars`** (shir.rs ~11650): an
   `Int` verdict from A2 lets a var lift **even when** the conservative
   string-context scan would mark it store-read — gated by the corpus
   (the risk is a var whose string interpolation must see a bash string
   that an int verdict would mis-type; the A2 verdict is conservative
   per var and the corpus judges). Keep the `escapes`/store-sync
   semantics: a lifted var's read in a `$var` string context emits
   `String(x)` (the emitter already has this for lifted vars).
2. **Native int arrays** (extend the existing native-array fold in
   estree.rs ~1090): when `var_types` says an array's elements are Int
   and every write is an Int literal / native arith, emit a real JS
   number array (`let map = [0, 0, …]` or `new Int32Array(n)`), and
   extend the fold's `arrayIndex` guard (currently literal-index-only)
   to accept a **lifted-var key** (`sh2.arrayIndex("map", gi)` →
   `map[gi]`) — the key's native binding is in scope at the read site.
3. The `$(( ))` emission: a pure-int expression whose operands are
   lifted (native bindings) emits the native expression — no
   `arithEval` closure, no `Number()`. (Independent fold: const vars
   from `var_const` fold to literals — request estree-…-const-fold.)

The runtime needs NO changes from the worker — `sh2.vars` accepts
numbers (String-coerced at the boundary), `arrayIndex` returns raw
elements, and the native-array fold bypasses the store entirely.

## FAILING-CASE

    MAP_W=16; MAP_D=16
    CELLS=$((MAP_W * MAP_D))
    map=(0 1 2 3 4 5 6 7)
    map_get() { gi=$1; gv=${map[$gi]}; }
    i=0
    while [ "$i" -lt 4 ]; do
      map_get $i
      echo "$gv"
      i=$((i + 1))
    done

currently emits `let i = "0"`, `sh2.arithEval(() => …)` for every
`$(( ))`, `sh2.arrayIndex("map", "$gi")` per read (store round-trip +
string coercion), and `Number(sh2.vars.i ?? …)` in the loop test. With
typed lowering: `let i = 0`, native `i < 4` / `i + 1`, `map[gi]` (or at
minimum `` `${gi}` ``), and `echo "$gv"` interpolates `String(gv)`.
Output bytes identical; the corpus gate (`./fail-estree` at the trusted
baseline) judges. The performance target is mimecroft's
`gspan "render"` (≈48ms/frame of async dispatches today).
