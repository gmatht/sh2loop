# estree: dead-store elimination for never-read variables (drop setVar/store syncs)

## NEED

The ESTree path should eliminate **dead stores**: assignments and
`sh2.setVar`/`sh2.vars.x = …` store syncs for variables that are never
read (or whose stored value is never observed), using the A1's existing
`var_lifetimes`/`var_const` annotations — and drop the corresponding
`let` bindings + store slots.

## WHY

The mimecroft contract declares 238 top-level vars; a large fraction
are written-never-read scratch (the per-function `*_tmp` names, the
`g_*` timing accumulators). Every one costs a `let` binding, a store
slot, and a `setVar`/`sh2.vars.x = "…"` write in the emitted JS — 96
`sh2.setVar` + 469 `sh2.vars.` writes counted statically, many of them
in the hot path (`g_*` timing accumulators are incremented per frame).
The `var_lifetimes` array already reports each var's first/last stmt
range and `escapes` flag (469 entries, 28 escapes in mimecroft) — a
var whose stmts are all writes and never a read is dead.

## MINIMAL-CORE-CHANGE

1. In the IR/emitter (shir.rs/estree.rs): compute a per-var READ set
   (getVar/arrayIndex/Var operands — the existing analyses already
   walk the same shapes; var_lifetimes gives first/last, add
   reads-vs-writes). A var with zero reads → drop its Declare/Assign
   statements, its top-level `let` binding, and any store write.
2. Careful with the edges: a var read inside a StringInterpolation, a
   test, a capture, or an exported/`env`-visible name (the `escapes`
   flag) is a READ — only provably-dead vars are removed; `sh2.setArray`
   syncs for arrays with no element reads likewise.
3. Keep the `$?`/lastExit protocol intact — DCE only touches variable
   stores, never the status machinery (transform 5's domain).

## FAILING-CASE

    x=5
    x=$((x + 1))    # dead: never read
    echo hi

currently emits `let x = "5"; x = sh2.arithEval(…)` (or `sh2.vars.x =
"5"`) — two stores for a value nothing observes. With DCE the stores
(and the `let`) disappear and only `echo hi` remains. Corpus gate:
`./fail-estree` at the trusted baseline — the risk is a store that
LOOKS dead but is read through a string-context alias (interpolation/
array flatten), which the read-set walk must catch.
