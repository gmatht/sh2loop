# estree: A1 lift analysis misses `$var` in Interpolate exec args — store writes desync (player teleports to (0,0))

## NEED

`numeric_lift_vars` (shir.rs) must mark a var **store-read** when a
`$var` reference appears inside an **Interpolate** argument of a
runtime call (exec etc.). Today `mark_str_args` only recurses into
`IrExpr::Str` / `Array` / `Object` — an Interpolate arg (how a quoted
`"$ax1"` arg is represented) is skipped, so the var is NOT marked
store-read, gets LIFTED (module `let`), and any store write elsewhere
(an `ax1=$1` positional copy inside a function → `sh2.setVar`) desyncs:
every read of the lifted binding sees the stale module value (0).

## WHY

The game's animation state (`ax0/ax1/az0/az1/ay0/ay1`) breaks on the
A1 path: `start_anim() { ax1=$4; … }` writes the STORE, but
`compute_display`'s glide math and the anim-completion read the
LIFTED module bindings (stale 0). Result: the camera never glides
(stuck at cell 0,0 — the indestructible border → the 3D view is
blank), and the completion writes `px=0 pz=0` — the player teleports
to the top-left corner and the turn arrow never rotates. Minimal
repro:

    ax1=0
    set_t() { ax1=$1; }
    set_t 7
    echo "ax1=$ax1"

emits `sh2.setVar("ax1", 7)` in set_t but reads `ax1` (module native,
0) at the echo → prints `ax1=0`, must print `ax1=7`.

## MINIMAL-CORE-CHANGE

In `numeric_lift_vars`'s `mark_str_args` (and the string-lift twin),
recurse into `IrExpr::Interpolate(parts)` — for each part, if it is a
Lit containing `$refs` or an Expr that is a `getVar`, mark the name
store-read (`mark_string_refs`/`mark_store_refs`). Also consider the
`param("", "name")` form the same way. The var must then stay
store-bound (reads emit `sh2.vars.ax1`), keeping the function's
store write consistent.

## FAILING-CASE

    ax1=0
    set_t() { ax1=$1; }
    set_t 7
    echo "ax1=$ax1"

via the A1 path prints `ax1=0` (the store write is invisible to the
lifted read). Via host bash / the parse-tree path it prints `ax1=7`.
Corpus gate: `./fail-estree` at the trusted baseline — the fix makes
more vars store-bound (fewer native lifts), which must not regress
the corpus; the game (mimecroft via otranspilerl) is the target.

## OUTCOME: rejected: conflicts with the landed per-function local-scope lift (fish-sh-go-20260806-145000/150200, commit 7f56280 — `local i=3; echo "i=$i"` must stay a native `let`, its unit test asserts no setVar; a blanket Interpolate store-read marking breaks 6 lib tests incl. local_scope_shadows_outer_binding) AND the real desync is on the otranspilerl A1 path (otranspilerl/src/lib.rs has its OWN lift analysis — no numeric_lift_vars call, so a shir.rs mark_str_args fix never reaches it; the shared-core bash frontend already outputs ax1=7 on the repro, verified 2026-08-16). Belongs to the estree worker (otranspilerl), not the shared core.
