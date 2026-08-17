# py-sh-go: STILL failing — fix_control_flow mangles the ArrayComp IIFE's value return (t80_comp_if DIFF, gate re-failed 20:40)

## NEED

The shared core's `fix_control_flow` pass (`sh2perl/src/estree.rs`,
`Stmt::ReturnStatement { argument } if !in_arrow || !in_func` arm) must
stop rewriting the native `return __out` inside the A1 `ArrayComp`
comprehension IIFE into an `sh2.return(__out)` control-signal call. The
A1-ingress path (`shir_to_estree_json`, shir.rs:13905, used by
`debashc --shir-in-estree`) emits JS whose last IIFE statement is
`sh2.return(__out)`; `sh2.return` `Number()`s the result array to NaN
and throws `Signal { kind: 'RETURN', value: NaN }`, aborting the
program before any output.

This is the SAME defect as the earlier pending request
`core-requests/py-sh-go-20260814-203400-arraycomp-iife-return-mangled.md`
(filed 20:34). The gate re-ran at 20:40:05 and failed again — the
request is not yet implemented (verified 20:46: current worktree WIP
contains only the estree-20260814-175715 BigInt + `sh2.functions.set`
arms; no ArrayComp hunks; HEAD's `is_define` still lacks the bare-arrow
callee arm). Please implement it in this round.

## WHY

py-sh-go gate (`make test`, frontends/py-sh-go): 81/82 on the
executed-stdout phase, single failure t80_comp_if.py:

```python
# t80_comp_if.py
x = [i for i in [1, 2, 3, 4] if i > 2]
print(x[0])
print(x[1])
```

Native python3 prints `3\n4`. The frontend emits contract-correct A1
(ingress-ACCEPTED — the deserializer takes it; this is not an emit
defect):

```json
{"expr":{"args":[{"style":"DoubleQuoted","type":"Str","value":"x"},
 {"cond":{"args":[{"style":"DoubleQuoted","type":"Str","value":"\"$i\" -gt 2"}],"func":"test","purity":"Emulable","type":"Call"},
  "elem":{"args":[{"style":"DoubleQuoted","type":"Str","value":"i"}],"func":"getVar","purity":"Emulable","type":"Call"},
  "iter":{"elements":[{"style":"DoubleQuoted","type":"Str","value":"1"},{"style":"DoubleQuoted","type":"Str","value":"2"},{"style":"DoubleQuoted","type":"Str","value":"3"},{"style":"DoubleQuoted","type":"Str","value":"4"}],"type":"Array"},
  "type":"ArrayComp","var":"i"}],"func":"setArray","purity":"Emulable","type":"Call"},
 "targets":[{"indices":[],"sigil":null,"var":"x"}],"type":"Assign"}
```

But `--shir-in-estree` renders ArrayComp as a direct-call arrow IIFE
(`(() => { const __out = []; for (let __ac of [...]) { …push… }
return __out; })()` — shir.rs ~32765) and `fix_control_flow` (estree.rs
~360) converts that last `ReturnStatement` to `sh2.return(__out)`
because the pass only treats `sh2.define` / `sh2.functions.set` callees
as value-return arrow contexts (estree.rs ~509). `sh2.return`
(sh2-namespace.mjs:2997) does `Number(value)` → `Number(["3","4"])` =
NaN → throws `Signal { kind: 'RETURN', value: NaN }` → node exit 1,
stdout empty → gate DIFF.

Reproduced 20:44 against the then-current `target/debug/debashc`:
`sh2.return(__out)` in the emitted JS, runner crashes with
`Signal { kind: 'RETURN', value: NaN }`. (Note: the estree worker's
concurrent cargo builds replace target/debug/debashc mid-gate, so
probe results flip between mangled and working as the tree churns —
that flapping is a build race, not a frontend regression; the committed
sources are the authority and they still mangle.)

The frontend has no workaround: the A1 expression vocabulary (shir_json.rs)
has no expression-level loop other than `ArrayComp` (the contract node
added for py-sh-go by core request py-sh-go-comp-if), and hand-lowering
via `Arrow`/`Lambda` statement bodies hits the same mangling (their
body `ReturnStatement`s are also inside bare arrows that `is_define`
does not recognize).

## MINIMAL-CORE-CHANGE

In `fix_expr`'s `CallExpression` arm (src/estree.rs ~line 509), extend
the `is_define` computation so a callee that IS a bare
`ArrowFunctionExpression` (the comprehension IIFE — the only
direct-call arrow in shir.rs; verified by grep ~line 32734) is also a
value-return context, and propagate that flag to the CALLEE fix (the
arrow is the callee, not an argument — the existing `arguments.map(…,
is_define)` propagation never reaches it):

```rust
let is_define = match callee.as_ref() {
    // The A1 ArrayComp IIFE `(() => { …; return __out; })()` — a
    // direct-call arrow whose `return` is the VALUE channel of the
    // comprehension (mirrors the define/functions.set function arrows).
    Expr::ArrowFunctionExpression { .. } => true,
    Expr::MemberExpression { object, property, .. } => { /* existing define/set arms */ }
    _ => false,
};
Expr::CallExpression {
    callee: Box::new(fix_expr(*callee, in_arrow, in_func || is_define)),
    arguments: arguments
        .into_iter()
        .map(|a| fix_expr(a, in_arrow, if is_define { true } else { false }))
        .collect(),
    optional,
}
```

The async variant (`has_await` wraps the IIFE in an `AwaitExpression`;
shir.rs ~32807) reaches the same arm through `AwaitExpression`'s
argument fix — no extra arm needed. Regression risk is nil: a bare-arrow
callee appears nowhere else in shir.rs's emitted ESTree, and the shell
frontend never emits ArrayComp (bash loops lower to IrStmt::For), so no
corpus path changes behavior.

## FAILING-CASE

Run the frontend emit through the pipeline (the exact failing case,
minimized — no comp_if needed; plain `[i for i in [1,2,3]]` crashes
identically since the mangle hits the IIFE return regardless of cond):

```json
{"type":"Program","contract_version":1,"imports":[],"requires":[],
 "subs":[],"var_types":[{"name":"x","type":"Any"}],"stmt_lines":[],
 "stmts":[
  {"type":"Assign","targets":[{"var":"x","sigil":null,"indices":[]}],
   "expr":{"type":"Call","func":"setArray","purity":"Emulable","args":[
     {"type":"Str","value":"x","style":"DoubleQuoted"},
     {"type":"ArrayComp","var":"i",
      "iter":{"type":"Array","elements":[{"type":"Str","value":"1","style":"DoubleQuoted"},{"type":"Str","value":"2","style":"DoubleQuoted"},{"type":"Str","value":"3","style":"DoubleQuoted"},{"type":"Str","value":"4","style":"DoubleQuoted"}]},
      "elem":{"type":"Call","func":"getVar","purity":"Emulable","args":[{"type":"Str","value":"i","style":"DoubleQuoted"}]},
      "cond":{"type":"Call","func":"test","purity":"Emulable","args":[{"type":"Str","value":"\"$i\" -gt 2","style":"DoubleQuoted"}]}}]}}]}
```

`debashc --shir-in-estree /tmp/comp.json` then run the emitted JS under
harness/estree-runner.mjs: today it crashes with `Signal { kind:
'RETURN', value: NaN }` and prints nothing. Expected after the fix:
`3\n4` (node exit 0), matching `python3` on `x = [i for i in [1, 2, 3,
4] if i > 2]; print(x[0]); print(x[1])`. Frontend repro: `./py-sh-go
--shir frontends/py-sh-go/testdata/t80_comp_if.py --raw`.

## OUTCOME: implemented — fix_control_flow's return-conversion is now keyed on LOOP-BODY arrows only (the in_loop flag; estree.rs `Stmt::ReturnStatement if !in_arrow || in_loop`, with the shir.rs:14003 comment naming "the py ArrayComp IIFE"), so the ArrayComp IIFE's native `return __out` is preserved (no sh2.return mangling). Verified this round: emitted JS contains NO sh2.return inside the IIFE and the executed run prints 3/4 == python3 for the request's failing case.
