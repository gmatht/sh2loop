# estree: REGRESSION — parse-tree path dropped the $EPOCHREALTIME read (gtick falls to the broken date fallback)

## NEED

Restore the **`$EPOCHREALTIME` read emission** in the parse-tree
estree path (`ast_to_estree_json`): the game's clock helper does

    gtick() { g_now=$EPOCHREALTIME; if [ "$g_now" != "" ]; then … else g_now=$(date +%s%N 2>/dev/null) … }

The OLD debashcl.wasm emitted `sh2.setVar("g_now", sh2.getVar(
"EPOCHREALTIME"))` (the runtime's getVar special arm returns
`Date.now()*1000` — the whole point of the arm). The current core
emits NOTHING for the read — `g_now` stays `""`, the `if` takes the
ELSE branch, and the `date +%s%N 2>/dev/null` fallback's **sync file
redirect** (`2>/dev/null`) then throws in the runtime's redirectSync
("redirection needs the async redirect bridge"). Every `bash script.sh`
run in the browser is now broken (the game, the texture generators).

## WHY

The game runs `.sh` scripts through debashcl.wasm (the parse-tree
path). Rebuilding debashcl from the current core (to land the filed
perf transforms) surfaced this: the emitted gtick lost the
EPOCHREALTIME assignment (only COMMENT references remain — the
variable is treated as an ordinary never-read name and dropped). The
runtime's EPOCHREALTIME arm (sh2runtime.js getVar) is the intended
fast path — the emitter must reach it. The date fallback's file
redirect was always unreachable before (EPOCHREALTIME worked), so its
sync-redirect refusal is secondary.

## MINIMAL-CORE-CHANGE

In the parse-tree variable-read lowering: `$EPOCHREALTIME` (and
`EPOCHREALTIME` as an assignment source) must emit the runtime read
`sh2.getVar("EPOCHREALTIME")` — treat it like the other special
variables (`$0`, `$?`, `$#`, the positionals) that the runtime
resolves, NOT as a program variable subject to DCE. The A1 path keeps
working (the runtime arm is at getVar); the parse-tree path lost it in
the recent estree refactor.

## FAILING-CASE

    gtick() { g_now=$EPOCHREALTIME; echo "$g_now"; }
    gtick

via the CURRENT core's debashcl emits no EPOCHREALTIME read → the
runtime getVar never sees the special name → `g_now` is empty (and
gtick's date fallback throws on the `2>/dev/null` sync redirect). Via
the OLD wasm it prints a µs timestamp. Both must print a timestamp.
Corpus gate: `./fail-estree` at the trusted baseline — the fix is
restoring emission the old core had; any regression is the recent
refactor's, not this restore.

## OUTCOME: implemented — `$EPOCHREALTIME`/`$EPOCHSECONDS` reads now emit `sh2.getVar("EPOCHREALTIME")` (special arm in store_var_read AND the getVar-call lowering, placed before the never-written fold and the native store read), and the harness runtime serves them (`Date.now()/1000` µs, seconds for EPOCHSECONDS). Verified: `gtick(){ g_now=$EPOCHREALTIME; echo "$g_now"; }; gtick` prints a µs timestamp via the debashcl path.
