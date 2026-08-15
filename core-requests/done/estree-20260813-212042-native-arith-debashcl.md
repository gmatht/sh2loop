# estree: native $(( )) arithmetic on the debashcl path — kill arithEval closures + idiv/imod calls

## NEED

The **parse-tree estree path** (`estree.rs ast_to_estree_json`) should
emit native JS arithmetic for `$(( ))` expressions instead of wrapping
every operation in `sh2.arithEval(() => sh2.imod/Number(…))` closures
and `sh2.idiv`/`sh2.imod` runtime calls — mirroring the A1 path's
native arith emission (`LIFTED_NUMERIC`/`native_arith_text`, request
estree-…-typed-lowering).

## WHY

The debashcl build of the texture generators and the game wraps EVERY
arithmetic operation: 37 static `sh2.arithEval(() => …)` closures +
60 `sh2.idiv/imod` runtime calls in the game, ~12 closures per pixel in
the texture loops. Each `arithEval` allocates a closure, re-derives
`Number(sh2.getVar(x) ?? …)` for every operand (a store round-trip per
read), and `sh2.idiv(a, b)` is a runtime function call per division.
Measured: the closure form is **2.7×** plain int math, and each store
read (`setVar`/`getVar` + `Number`) is ~5× a native binding read. The
A1 path already emits `x = (Number(a)||0) * 4 + (Number(b)||0)` with
lifted vars — the debashcl path never got the lift machinery.

## MINIMAL-CORE-CHANGE

In `ast_to_estree_json`'s arith lowering:

1. **Native expression**: for an `$(( ))` whose operands are quoted
   refs/literals/nested arith (the common case — the emitter already
   has the operand read form), emit the JS expression directly:
   `x = (Number(v)||0) + (Number(w)||0)` — no `arithEval` closure.
   Keep the closure only for operands that need the runtime's
   expansion (unquoted words, `${x:0:1}`-style refs, command
   substitution).
2. **Native idiv/imod**: emit `Math.trunc((a) / (b))` / `(a) - (b) *
   Math.trunc((a) / (b))` inline instead of `sh2.idiv(a, b)` /
   `sh2.imod(a, b)` — bash's `%`/`/` are truncation-toward-zero; the
   runtime's idiv/imod implement exactly that; the native form removes
   the call (and the `Number(…)` re-coercion the runtime does).
3. **Store sync**: the result still lands via `setVar`/`sh2.vars.x`
   (the debashcl store protocol) unless the var is liftable — the
   lift analysis (estree-…-typed-lowering) is the follow-up; this
   request is the closure/call elimination only, fully behavior-
   preserving.

## FAILING-CASE

    i=0
    while [ "$i" -lt 16 ]; do
      i=$(( i + 1 ))
    done

currently emits `sh2.setVar("i", sh2.arithEval(() => (Number(sh2.getVar(
"i")) || 0) + 1))` per iteration — a closure + two store round-trips.
Native: `sh2.setVar("i", (Number(sh2.vars.i ?? (sh2.env.i ?? "")) || 0)
+ 1)` (or `i = i + 1` once lifted). Output identical; the texture
per-pixel loops (~12 closures/pixel) and the game's `gspan "render"`
are the targets. Corpus gate: `./fail-estree` at the trusted baseline.

## OUTCOME: implemented — same root: the debashcl path is shir_to_estree (M3 reroute), which emits native arith. Verified on the request's failing case (`i=$(( i + 1 ))`): the emitted assignment is native `i = i + 1` (lifted binding), zero `arithEval` closures, zero `setVar`/`idiv`/`imod` runtime calls, and estree-runner output matches bash. Corpus gate: estree 521/521 at the trusted baseline.
