# estree: REGRESSION — whileLoopSync emitted for a loop whose body AWAITS → infinite spin

## NEED

The parse-tree estree path (`ast_to_estree_json`) must not lower a loop
to `sh2.whileLoopSync(cond, body)` when the body contains `await`
(an `await sh2.fnCall(...)` etc.) — whileLoopSync calls `body()` WITHOUT
await (the runtime's contract: "cond + body await-free"), so the
body's increments after the await never run synchronously, the
condition never changes, and the loop SPINS, blocking the event loop
(the browser freezes; the game's texture loading hangs at
"loading block textures…").

## WHY

The mime-type texture scripts (texture-jpeg/png/octet/text — the
game's `load_tex jpeg 11` etc.) draw a 3×5 glyph with a 3×3 outline
loop whose body calls `glyph_pixel` (an `await sh2.fnCall`) and a
mid-loop `return`. The emitter chose `whileLoopSync` for these loops;
with an async body the counters never advance → infinite spin. The
game boots to "loading block textures…" and freezes. Workaround
landed in the scripts (flag-based, no mid-loop return) flips the
emitter to a native while — the emitter decision is the bug.

## MINIMAL-CORE-CHANGE

The loop lowering's sync/async decision: a loop whose body contains ANY
`await` (fnCall/exec/writeFile/capture/return-signal) must use the
ASYNC `whileLoop` (or a native async while), never `whileLoopSync`.
The `sh2.return()`/ReturnSignal inside a body must also force async.
The runtime's whileLoopSync is correct as-is (sync bodies only) — the
emitter just misclassifies.

## FAILING-CASE

    glyph_pixel() { g_on=0; }
    text_overlay() {
      x=0
      while [ "$x" -le 1 ]; do
        glyph_pixel $x 0
        x=$(( x + 1 ))
      done
    }
    text_overlay
    echo done

via the debashcl path emits `whileLoopSync` with an awaiting body →
infinite spin (no "done"). Via host bash it prints "done" in two
iterations. The emitted loop must be async (whileLoop) or native.
Corpus gate: `./fail-estree` at the trusted baseline.

## OUTCOME: implemented
Verified already fixed in the current tree: the stmt-level While / expr-level whileLoop arms gate the sync fast path on `stmts_have_await(&body)` (and `expr_has_await(&cond)`), and the fn_call_sync_set fixpoint removes any function whose body awaits (transitively), so a loop body calling an awaiting function emits the ASYNC whileLoop, never whileLoopSync. Reproduced the request's failing case with an async callee (file-redirect body) + mid-loop return: bash and estree-runner both print `done`, no spin. The `sh2.return()` ReturnSignal path also stays out of the native-while rung (lowered_stmts_have_signals). estree corpus 521/521, perl 320, cargo test --lib green.
