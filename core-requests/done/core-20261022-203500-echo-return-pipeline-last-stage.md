# echo-return lifts a pipeline's LAST stage → the pipeline's output is lost

Filed by: an ad-hoc investigation session (2026-10-22). NOT committed — see
"Landing" below; the tree was mid-flight from several concurrent workers.

## Symptom (reproduced, bash vs estree)

```sh
f() { echo "x"; }
f                          # fine: prints x
y=$(f)                     # fine: y=x
y=$(echo hi | f)           # BUG: y=""   (bash: y=x)
y=$(f | cat)               # BUG: y=""   (bash: y=x)
```

Also hits `echo ARGS | grep -o P` when the grep lifts to the A1
`grepMatches` op and is the LAST stage of a `$( ... )` pipeline.

## Cause

`sh2perl/src/transforms/echo_return.rs`. `echo-return` rewrites every call
site of an eligible (pure, single-echo) function to the value-returning
convention:

* statement position → `expr_to_estree` wraps `fnValue(..)` in an `echo`
  (pass 3, `rewrite_call_stmt`);
* **value position** → `rewrite_stmt` / `rewrite_expr_calls` replace the
  bare call with `fnValue(..)` directly (no echo — correct for `$(f)`).

`rewrite_stmt`'s two bare-call arms (the `builtin|exec` arm and the
`exec|fnCall` arm) fire for EVERY bare call in a function body, including a
call that is the **last stage of a pipeline**. In `sh2.pipelineSync` the
last stage runs against the CALLER's fd-1 (`saved[1]` — "the last stage
must write through the current fd-1 sink"), so a stage that returns a value
instead of echoing writes nothing: the stage's output is silently dropped.

`rewrite_call_stmt`'s `Pipeline` arm had the same gap for the capture-assign
wrapper (`Assign { expr: Capture { expr: Arrow([pipeline(..)]) } }`), which is
the shape `x=$(... | f)` actually reaches the transforms as.

## Why the existing guards do not catch it

`body_echo_ok` / `loop_body_states` reason about the CALLEE's own body. The
caller side has no notion of "is this call in value position?", and a
pipeline's last stage is the one position where a bare call is NOT.

## Proposed fix (prototype written, verified, NOT landed)

* `fn last_stage_is_call(stages, eligible)` — a predicate for "the pipeline's
  last stage is one bare call to an eligible function".
* `rewrite_stmt(st, changed, eligible, keep_pipeline_last)` — the two
  bare-call → `Return` arms are skipped when the flag is set.
* `rewrite_call_stmt`'s `Pipeline` arm descends into non-last stages only;
  the `Assign { Capture { Arrow([pipeline]) } }` wrapper is recognised and
  routed through the same skip.
* The `is_pipeline_with_last_call` helper also accepts the capture-assign
  wrapper (checking only the expr, to satisfy the borrow checker inside the
  `Assign` match arm).

A prototype patch is at `/tmp/echo_return.fixed.rs` on the session box (and
the same edits are described above); on the last-good committed tree
(49e1b8e8) it compiles. It did NOT fix the symptom end-to-end on the then
current binary, because the emitter ALSO lowers the last stage to
`sh2.fnCall(...)` (which echoes into the CALLER's fd — the capture buffer —
not the pipeline's sink), and that lowering lives in the estree emitter, not
in this transform. **Who emits that `fnCall` was not pinned down**: it is not
`rewrite_call_stmt` (instrumented: never reached for that statement) and not
the `transforms::all()` chain replayed in-process. Pinning it is the first
task for whoever picks this up — instrument `expr_to_estree`'s
`exec`→`try_native_fn_call` arm (`SYNC_FN_CALLS`/`try_native_fn_call`) as the
next suspect.

## Landing

Blocked by tree state, not by the analysis: at filing time `sh2perl/src`
carried uncommitted concurrent edits (`fish_backend.rs` missing `params`,
`wasi.rs`/`wasi_api.rs` mismatch, an untracked `transforms/slice_identity.rs`
referenced from a modified `transforms.rs`), so the tree does not build and
a submodule commit from an ad-hoc session would race four workers. Land it
through the normal core path (core worker / core-request) once the tree is
green.

## OUTCOME: implemented

Fixed in sh2perl 7c4473312. Two gaps: (1) the shell path lowers a pipeline to
`Call { func: "pipeline", args: [Array([Arrow…])] }`, which `rewrite_call_stmt`
never visited, so stage calls were left bare; (2) the LAST stage is the
pipeline's output sink, so a bare call there (now a value-returning `fnCall`)
wrote nothing — it is rewritten to `exec("echo", [fnValue("f", [args])])`.
Evidence: `y=$(echo hi | f)` and `y=$(f | cat)` now match bash ("x", not "");
pinned by `pipeline_last_stage_echoes_the_value`, which fails with the new arms
disabled. ./fail-estree 562/562 PERL + 562/562 ESTREE.
