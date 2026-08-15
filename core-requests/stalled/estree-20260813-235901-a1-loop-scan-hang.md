# estree: A1 path — the radar-base scan (hud_build_static) loops forever in the full game

## NEED

Fix the **A1 path** (`shir.rs shir_to_estree_json`, otranspilerl.wasm)
loop termination for the game's radar-base scan: running the full
mimecroft through `lib.transpile(src,"sh","js")` (the runShellScript
path) hangs in `hud_build_static`'s nested get_cell scan — the loop
never terminates (the z/x counters keep going past MAP_D/MAP_W), while
ISOLATED nested scans with identical source terminate correctly.

## WHY

The game cannot run on otranspilerl.wasm (the unified wasm with all
the landed perf transforms) until this hangs — the browser's `.sh`
path is wired to the legacy debashcl, and the debashcl rebuild is
separately blocked (the EPOCHREALTIME regression). The A1 path should
be the game's engine (it has native tests, typed lowering, inlining);
the hang blocks that.

## MINIMAL-CORE-CHANGE

Reproduce the hang and find the desync: the full game's
`hud_build_static` (`while [ "$dm_x" -lt "$MAP_W" ]; do while [ "$dm_z"
-lt "$MAP_D" ]; do get_cell $dm_x 1 $dm_z; ...`) emits counters that
look native (`dm_x < MAP_W`, `dm_z = dm_z + 1`) but the loop runs
forever — likely a typed-lifting store/native desync triggered by the
game's scale (many vars / the get_cell→map_get array path), the same
family as the arrayIndex lifted-key fixes (182438/182439). Isolated
nested scans with the same shape terminate — so bisect the full game
down (remove functions until the hang appears) to pin the trigger
(get_cell's map_get? a specific var name? the lifted set size?).

## FAILING-CASE

    bash mimecroft.sh (headless) via lib.transpile(src,"sh","js")

hangs in the radar-base scan — a repeated `get_cell [x,"1",z]` fnCall
trace with z advancing past 16 forever (no `done`). The same script
runs to completion via debashcl (the parse-tree path) and via host
bash. Both paths must complete; the A1 path is the target engine.
Corpus gate: `./fail-estree` at the trusted baseline.
