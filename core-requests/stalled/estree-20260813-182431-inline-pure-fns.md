# estree: inline pure leaf functions — kill the per-call async fnCall dispatch

## NEED

The ESTree renderer should **inline pure, non-recursive leaf functions**
(map_get/map_set/get_cell/set_cell/bhp_get/bhp_inc/add_bhp in
www/bin/mimecroft.sh) into their call sites, so the emitted code reads
the array directly instead of going through the `sh2.fnCall` async
dispatch.

## WHY

MIMEcroft's per-frame render loop calls `try_draw` 768×/frame; each
`try_draw` calls `get_cell` → `map_get` (and `mime_at` → `mime_color` →
`mime_tex_of`), i.e. ~1500–2300 `await sh2.fnCall(...)` dispatches per
frame. Each dispatch is an async `fns.get(name)` lookup + `scriptArgs`
swap + `String(...)` arg coercion — measured **2× a direct call**, and
the args are wrapped in `String(x).split(/\s+/).filter(...)` (**21×** a
plain value, transform 4). The leaf functions are pure: body is
assignments + `map[$i]=…`/`${map[$i]}` array access + `$(( ))`, no
subprocess, no redirect, no recursion, no subshell. Emitting
`get_cell $a $b $c` as `idx = b*CELLS + c*MAP_W + a; gv = map[idx]`
inlined (with the fnCall positional protocol preserved) removes 2
dispatches + 6 split/filter coercions per block.

## MINIMAL-CORE-CHANGE

An IR-level inline pass (shir_passes or the transforms channel —
`fn(&mut Vec<IrStmt>) -> bool`):

1. Collect `IrStmt::Function { name, body, .. }` candidates: body is a
   subset of PURE stmts (Assign, `setVar`/`arrayIndex`/`getVar`/`arith`
   Expr calls, `If` with pure bodies), no `Redirect`/`Subshell`/
   `Background`/`Pipeline`/`Exec`/`Goto`, and the function is never
   called recursively (a call to its own name anywhere → not a
   candidate).
2. Substitute each `Call { func: name, args }` site with the body,
   mapping the positional params (`$1`… — the body's leading
   `name=$1`-style Assigns the renderer already lifts to JS params) to
   the call's args; name-collide by prefixing locals with the fn name
   (the game already uses unique per-function scratch names).
3. Delete the Function stmt once no call sites remain (the renderer's
   `sh2.functions.set` registration goes with it).
4. Honesty rule: a call site whose args are not scalar literals /
   plain vars (e.g. word-splittable) must keep the word-split
   semantics — inline only when the substitution is provably
   text-closed, else leave the fnCall.

## FAILING-CASE

No correctness failure — a performance escalation. Repro of the
emission (current):

    map_get() { gi=$1; gv=${map[$gi]}; }
    get_cell() { a=$1; b=$2; c=$3; idx=$((b * 16 + c * 16 + a)); map_get $idx; }
    x=5; y=2
    get_cell $x 0 $y
    echo "$gv"

emits `await sh2.fnCall("get_cell", [String(x).split(/\s+/).filter(w =>
w.length > 0), "0", ...])` + a nested `fnCall("map_get", …)` — two async
dispatches + six split/filter coercions for one array read. Inlined it
is `idx = 5*16 + 0*16 + 2; gv = map[idx]`. Corpus gate: `./fail-estree`
must stay at the trusted baseline; the render-loop numbers (MIMEcroft
`gspan "render"` ≈ 48ms/frame of async dispatches) are the target.

## SUPERSEDED: inline-pure-fns
## REASON: The request's core ask — the IR-level inline pass (fn(&mut Vec<IrStmt>) -> bool) — landed in the shared core as src/transforms/inline_pure_fns.rs (marketplace offer accepted sh2perl e242948 "contract op + transform (build + invariants green)", fixed da233c3; canonical workspace record core-requests/transforms/done/inline-pure-fns.rs). The estree worker's remaining steps — registering it in transforms::all() + the renderer-side fnCall hooks — are its own acceptance gate, not a new bundle.
