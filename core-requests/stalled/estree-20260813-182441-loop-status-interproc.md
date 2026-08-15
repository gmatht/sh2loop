# estree: interprocedural loop-status deadness — elide the __sh2_loop_ran/__sh2_loop_last tracking

## NEED

Extend `LOOP_STATUS_DEAD` (shir.rs `mark_loop_status_deadness`, ~11800)
**interprocedurally**: a loop whose status (`$?` after the loop) is
provably unobserved should skip the `let __sh2_loop_ran = false,
__sh2_loop_last = 0` / `__sh2_loop_ran = true` /
`__sh2_loop_last = sh2.lastExit` /
`sh2.lastExit = __sh2_loop_ran ? __sh2_loop_last : 0` machinery the
emitter adds to every `While` (93 sites in the mimecroft build).

## WHY

The game's per-block scan loop (`mime_at`) runs up to MIME_CAP=12
iterations and is called ~768×/frame; the render loops
(`while [ "$rf_z" -lt "$MAP_D" ]`) run 16×16/frame. Every iteration
pays `__sh2_loop_last = sh2.lastExit` (a store read + write) and the
loop wrapper pays the ran/last bookkeeping, yet the status is dead in
the common cases:

1. **fnCall/callDirect-dispatched functions** — the runtime's
   `sh2.fnCall`/`callDirect` set `lastStatus` from the function's JS
   RETURN value (`lastStatus = r === false ? 1 : 0`), overwriting any
   `sh2.lastExit` the body wrote. A function whose last statement is a
   loop and whose body never reads `$?` after the loop → the tracking
   is dead. `mime_at` is only ever called via `sh2.fnCall` → dead.
2. **Top-level loops whose status is never read** — the render loops'
   status feeds only the loop-exit `sh2.lastExit` write; if the
   following statements never read `$?`, dead.

## MINIMAL-CORE-CHANGE

The analysis already exists per-loop (pointer-keyed `LOOP_STATUS_DEAD`,
set by `mark_loop_status_deadness` + `walk_lastexit_liveness`); it is
conservative for function-final loops. Add:

1. A call-site scan (the emitter already computes
   `fn_call_sync_set`/`DIRECT_FN_CALLS` — reuse the same walk): for
   each Function, the set of call sites by kind (fnCall/callDirect vs
   exec/direct-define). If ALL sites are fnCall/callDirect AND the
   function body reads `$?` nowhere after the loop, mark the loop's
   status dead (fnCall's return-status overwrite makes the inner write
   unobservable). `exec`-dispatched functions (which do NOT overwrite
   on an undefined return) keep the tracking.
2. The emitter already skips the ran/last machinery for
   `LOOP_STATUS_DEAD` loops — this request only widens the dead set.

## FAILING-CASE

    mime_count=3
    mime_at() {
      i=0
      while [ "$i" -lt "$mime_count" ]; do
        i=$((i + 1))
      done
      # nothing reads $? after the loop; fnCall overwrites the status
    }
    mime_at
    echo done

currently emits the full `__sh2_loop_ran`/`__sh2_loop_last` block for
the loop (4 statements + per-iteration capture) even though `mime_at`
is fnCall-dispatched and nothing reads `$?`. Elided: `{ let i = 0;
while (i < 3) { i = i + 1; } }`. Output bytes identical; the corpus
gate (`./fail-estree`) judges — the risk is a function whose exit
status IS read via exec/`$?`, which the call-site scan must keep.
