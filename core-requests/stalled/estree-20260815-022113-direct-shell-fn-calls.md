# estree: rewrite normalized shell-function call sites to direct JS calls (texture-generator hot path)

## NEED
After `normalizeFunctions` (estree.js) converts `sh2.functions.set("f", arrow)`
registrations into native `function f(...)` declarations, every CALL SITE
is still dispatched as `await sh2.fnCall("f", [args])` (or the sync
`sh2.callDirect("f", __fn_f, [args])`) — paying the runtime dispatch
(function-table lookup, scriptArgs save/restore, argument stringifying, a
Promise) per call. Add a post-normalize pass that rewrites the call sites
of known native functions to direct calls (`await f(args)` for async,
`f(args)` for sync), unwrapping the word-list argument coercion
(`X.split(/\s+/).filter(w => w.length > 0)`) back to the raw string the
function's params expect.

Two adjacent correctness fixes are included:
- `writeBuiltinOutput` (estree.js) only matched the BARE
  `sh2.builtin("printf", [fmt])` statement — the async-region lowering
  emits `await sh2.builtin(...)` (the TSV header printf), whose return
  was DISCARDED → the transpiled texture generators' TSV payload was
  empty (the flaky "blocks render flat" path). Unwrap the awaited form.
- `printf -v NAME …` assigns to a variable and prints NOTHING —
  `writeBuiltinOutput` wrapped it into `process.stdout.write(...)`,
  corrupting the PPM byte builder (the emitted `process.stdout(sh2.builtin(...))`
  form) and producing `$oc` literals. Exclude the -v form.

## WHY
The transpiled texture generation (sh2runtime/examples/textures/texture-*.sh
run through `bash2js` in the browser) is dominated by the per-pixel helper
chain: `vnoise2` → `lat_hash` / `smooth_w`, called ~8× per pixel (32×32
= 1024 pixels). Measured on texture-stone.sh (`--tsv --size 32 --seed
20240812`, the game's exact invocation):
- fnCall dispatches: **4628 → 5** per texture with the pass
- clean wall time: **136ms → 64ms (2.1×)** on the game's TSV path
- output byte-identical to host bash (11995 bytes; 5/5 textures checked:
  dirt, stone, grass, water, wood)

Without the `writeBuiltinOutput` awaited-form fix the TSV payload is
empty (the `probe_ok` printf -v succeeds → the header printf takes the
`await sh2.builtin` path → discarded), so the game's textures come back
empty and blocks render flat — the exact flake the original
`writeBuiltinOutput` comment describes.

## MINIMAL-CORE-CHANGE
In `sh2runtime/src/lower.js` (canonical; the workspace's
`harness/lower.js` is a partial copy — sync after review):
- add `directShellFnCalls(program)`: collect FunctionDeclaration
  names + async flags; rewrite every `sh2.exec`/`sh2.fnCall`/
  `sh2.callDirect` call (awaited or bare) of a known name to a direct
  call, with the `shellFnCallInfo` helper (name + args array; args at
  index 2 for callDirect) and `unwrapWordList` (strip the
  split/filter coercion, incl. the `String(x).split(...)` form).
  Conservative: skip targets whose body has an explicit `return N`
  (the adapter keeps propagating $?).
- wire it into `estreeToJsMapped` (estree.js) right after
  `normalizeFunctions`.
In `sh2runtime/src/estree.js`:
- `writeBuiltinOutput`: match the awaited form
  (`await sh2.builtin(...)` → unwrap → wrap the bare call) and skip
  `printf -v` (no stdout output).
The change is emission-only (the sh2runtime estree→JS side); the wasm's
estree JSON is untouched.

## FAILING-CASE
```
# sh2runtime/examples/textures/texture-stone.sh (the game's exact invocation)
node -e "… bashToJS('examples/textures/texture-stone.sh') … run with args --tsv --size 32 --seed 20240812"
# emitted JS (before): await sh2.fnCall("lat_hash", [String(vn_wx).split(/\s+/).filter(w => w.length > 0), …])
# emitted JS (after):  lat_hash(sh2.vars.vn_x0 ?? (sh2.env.vn_x0 ?? ""), …, vn_wx, vn_wy)
# 4628 fnCall dispatches per texture → 5; TSV payload byte-identical to host bash
```

## OUTCOME: rejected: target is `sh2runtime/src/lower.js` + `sh2runtime/src/estree.js` — sh2runtime is NOT in this workspace (separate repo; the workspace `harness/lower.js` is a stale non-canonical partial copy not exercised by ./fail-estree). The `directShellFnCalls` rewrite + `writeBuiltinOutput` awaited-form fixes are the estree/sh2runtime worker's domain — no shared-core change can land or gate them here.
