# posix-sh-go: pipeline inside a capture leaks to real stdout — the native-echo-pipe fold skips the ECHO_SINK_DEPTH gate

## NEED

`x=$(echo one; echo two | wc -l)` — the `;`-sequence capture whose LAST
statement is a pipeline — prints the pipeline's output ("1") to the REAL
stdout BEFORE `x=one`, instead of capturing it. The posix-sh-go gate's
`t03_pipeline.sh` is red on it (87/88; a pre-existing divergence, fails
on baseline — not a frontend regression).

## WHY

`src/shir.rs` `expr_to_estree`'s `func == "pipeline"` arm calls
`try_native_echo_bc_stmt` and `try_native_echo_pipe_stmt` — folds that
emit a DIRECT `process.stdout.write` of the folded text — WITHOUT the
`ECHO_SINK_DEPTH == 0` check that every other native-echo lowering
follows (echo/printf at lines ~15126/15893/15903). Inside a capture
arrow the fd-1 target is a capture buffer; the direct write bypasses it.

Isolated (all verified against `debashc file --estree` + the runner):
- `x=$(echo two | wc -l)`       → x=1 ✓ (pipeline alone in capture)
- `x=$(echo one; echo two)`     → x=one\ntwo ✓ (`;` sequence)
- `x=$(echo one; echo two | wc -l)` → BROKEN: prints "1" then x=one
  (the pipeline's output leaks; the capture only got "one")

## MINIMAL-CORE-CHANGE

In `src/shir.rs`, the `if func == "pipeline"` arm (~line 31903), wrap the
two direct-write folds in `if *ECHO_SINK_DEPTH.lock().unwrap() == 0 { ... }`
(bc fold + echo_pipe fold). When the depth is > 0 the pipeline stays on
the runtime path (pipeline/pipelineSync write the last stage through the
CURRENT fd-1 target — capture-aware). The tr/grep/cut folds route through
runtime helpers (fdTargets-aware) and need no gate.

The exact patch was prepared but could not be applied: `src/shir.rs` is
root-owned (chowned 2026-08-15 01:08 by a previous pi session; mtime
01:08) and the workspace owner (llm) has no sudo. This also blocks the
estree worker's own pi fix loop — please restore llm ownership of
`sh2perl/src/shir.rs` when a root-capable process is available.

## FAILING-CASE

`frontends/posix-sh-go/testdata/t03_pipeline.sh` (the `count=$(echo one;
echo two | wc -l)` line) — gate: `make -C frontends/posix-sh-go test`
→ `DIFF t03_pipeline.sh (stdout mismatch)`:
native:  `count=one` then `1`; transpiled: `1` then `count=one`.

## OUTCOME: implemented — the `func == "pipeline"` arm wraps BOTH direct-write folds (try_native_echo_bc_stmt + try_native_echo_pipe_stmt) in `if *ECHO_SINK_DEPTH.lock().unwrap() == 0` (shir.rs ~32016, with the posix-sh-go t03 comment); inside a capture (depth > 0) the pipeline stays on the runtime path, whose pipeline/pipelineSync write through the capture-aware fd-1 target. Verified this round: `count=$(echo one; echo two | wc -l)` transpiled output == bash exactly. (Also: src/shir.rs ownership was restored to llm — the request's chown blocker is resolved.)
