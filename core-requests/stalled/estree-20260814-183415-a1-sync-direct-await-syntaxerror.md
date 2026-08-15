# estree: A1 types a direct-call function sync but still emits `await` — SyntaxError

## NEED
When a bash function body contains ONLY direct (native-direct) calls —
e.g. `start_anim` calling `gtick` (registered via
`sh2.functions.set("gtick", __fn_gtick)` and dispatched with
`await sh2.callDirect("gtick", __fn_gtick, [])`) — the A1 types the
function as SYNC (the direct calls are sync-capable), so it emits
`sh2.functions.set("start_anim", () => { … await sh2.callDirect("gtick", …) … })`
— a non-async function containing `await`, which is a hard
`SyntaxError` at `new Function(...)` in the browser. The function must
be typed async whenever the emitted body contains an `await`, or the
direct call must be emitted WITHOUT the `await` for sync-typed bodies
(the sync-capable contract the callDirect itself documents).

## WHY
sh2runtime's mimecroft.sh replaced the action-start `$(cat /dev/time)`
(an async command substitution, which kept `start_anim` async) with the
sync clock (`gtick` + `$g_now` — the profile showed the async read was
a per-action cost). The A1 then typed `start_anim` sync and the emitted
JS stopped parsing: `SyntaxError: await is only valid in async functions
and the top level bodies of modules` at the `new Function` wrapper, so
the whole game crashed. The game-side workaround inlines the clock
(no call), but the engine's sync/async typing is inconsistent with the
emitter.

## MINIMAL-CORE-CHANGE
In the A1 emitter (otranspilerl/src/lib.rs): a function body is ASYNC
if it emits any `await` — including `await sh2.callDirect(...)`. The
sync typing must be restricted to bodies whose direct calls are emitted
synchronously (the `fn_call_sync_set` path already exists for fnCall;
callDirect needs the same). Alternatively, make the emitter mark the
function async whenever the body contains a callDirect/call — the
simplest correct fix.

## FAILING-CASE
```
$ cat > /tmp/sync-direct.sh <<'EOF'
gtick() { g_now=$EPOCHREALTIME; }
start_anim() {
  gtick
  anim_t0=$g_now
}
EOF
$ node -e "… bashToJS('/tmp/sync-direct.sh') …"   # A1 path
# emitted: sh2.functions.set("start_anim", () => {
#             await sh2.callDirect("gtick", __fn_gtick, []); …
#           })
# new Function(...) → SyntaxError: await is only valid in async functions
# expected: either async function start_anim, or callDirect WITHOUT await
```
