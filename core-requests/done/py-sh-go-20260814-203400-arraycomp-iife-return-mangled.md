# py-sh-go: fix_control_flow mangles the ArrayComp IIFE's value return — every comprehension crashes the ESTree oracle

## NEED

The shared core's `fix_control_flow` pass (`sh2perl/src/estree.rs`) must
stop rewriting the `return` inside the ArrayComp comprehension IIFE into
an `sh2.return()` control-signal call. The A1 `ArrayComp` node — rendered
by `expr_to_estree` in `src/shir.rs` as a direct-call arrow IIFE
(`(() => { ...; return __out; })()`, the only bare-arrow callee in the
whole file) — is currently unexecutable end-to-end: `debashc
--shir-in-estree` emits JS whose final statement of the IIFE is
`sh2.return(__out)`, which `Number()`s the result array to NaN and
throws `Signal { kind: 'RETURN', value: NaN }`, aborting the program
before any output.

## WHY

py-sh-go's gate (`make test`, frontends/py-sh-go) is 81/82 on the
executed-stdout phase; the single failure is t80_comp_if.py:

```
# t80_comp_if.py
x = [i for i in [1, 2, 3, 4] if i > 2]
print(x[0])
print(x[1])
```

Native python3 prints `3\n4`. The frontend emits (contract-correct,
ingress-ACCEPTED — the A1 deserializer takes it) the A1 comprehension
`ArrayComp` node inside `setArray`:

```json
{"type":"Assign","targets":[{"var":"x","sigil":null,"indices":[]}],
 "expr":{"type":"Call","func":"setArray","purity":"Emulable","args":[
   {"type":"Str","value":"x","style":"DoubleQuoted"},
   {"type":"ArrayComp","var":"i",
    "iter":{"type":"Array","elements":[{"type":"Str","value":"1","style":"DoubleQuoted"},{"type":"Str","value":"2","style":"DoubleQuoted"},{"type":"Str","value":"3","style":"DoubleQuoted"},{"type":"Str","value":"4","style":"DoubleQuoted"}]},
    "elem":{"type":"Call","func":"getVar","purity":"Emulable","args":[{"type":"Str","value":"i","style":"DoubleQuoted"}]},
    "cond":{"type":"Call","func":"test","purity":"Emulable","args":[{"type":"Str","value":"\"$i\" -gt 2","style":"DoubleQuoted"}]}}]}}
```

But `--shir-in-estree` then crashes: `shir_to_estree` renders ArrayComp
as the IIFE arrow whose last statement is a native
`ReturnStatement { argument: __out }` (shir.rs:32765), and the
`fix_control_flow` pass (estree.rs:369, `Stmt::ReturnStatement { .. } if
!in_arrow || !in_func` → `sh2.return(args)`) converts it to
`sh2.return(__out)` — the pass only knows two value-return arrow
contexts, the `sh2.define` / `sh2.functions.set` function arrows
(estree.rs:512). `sh2.return()` (sh2-namespace.mjs:2997) is the shell
`return` builtin: it does `Number(value)` (exit-status semantics), so
`Number(["3","4"])` = NaN, then throws the RETURN control Signal:

```
Signal { kind: 'RETURN', value: NaN }
```

→ node exits 1, stdout empty → gate DIFF.

Why not a frontend workaround: the A1 Call vocabulary DOES have
`setArrayAppend` (py-sh-go emits it for `a += [...]`, t56) and For
stmt (t20), so a loop-based lowering is *technically* expressible — but
it is rejected: ArrayComp is the contract's only comprehension form,
added for py-sh-go by core request py-sh-go-comp-if-20260813-215131
(done/), and testdata/t80_comp_if.py exists precisely to exercise it
(coverage example 'comp_if'). Hand-lowering comprehensions to loops
would mask the core bug (leaving ArrayComp unexecutable for any
emitter), and coverage-gap.sh would re-report 'A1 node ArrayComp' every
cycle. The emitted A1 is contract-correct and ingress-ACCEPTED — the
defect is entirely in the core's A1→ESTree pipeline (fix_control_flow
mangling the IIFE the core itself generates).

## MINIMAL-CORE-CHANGE

In `fix_expr`'s `CallExpression` arm (src/estree.rs, ~line 502), extend
the `is_define` computation so a callee that IS a bare
`ArrowFunctionExpression` (the comprehension IIFE — the only
direct-call arrow in shir.rs; verified by grep, line 32734) is also a
value-return context, and propagate that flag to the CALLEE fix (the
arrow is the callee, not an argument — the existing `arguments.map(...,
is_define)` propagation never reaches it):

```rust
let is_define = match callee.as_ref() {
    // The A1 ArrayComp IIFE `(() => { ...; return __out; })()` — a
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

(If preferred, keep `in_func || is_define` only for the callee — the
ArrayComp IIFE takes no arguments, so the arguments map is unaffected
in practice.) The async variant (`has_await` wraps the IIFE in an
AwaitExpression; shir.rs:32807) reaches the same arm through
`AwaitExpression`'s argument fix — no extra arm needed. Regression risk
is nil: a bare-arrow callee appears nowhere else in shir.rs's emitted
ESTree, and the shell frontend never emits ArrayComp (bash loops lower
to IrStmt::For), so no corpus path changes behavior.

## FAILING-CASE

Regression evidence: the same pipeline passed at 14:08 (gate log: `OK
t80_comp_if.py (stdout match)`, 76/77) and broke by 20:40 (81/82, DIFF)
— the break tracks the current oracle binary (rebuilt 20:16 from this
tree) and/or harness; regardless of which side flipped, the CURRENT
checked-out core + harness deterministically crashes (repro below).

Reproduce (the exact failing case above, minimized — no comp_if needed;
the plain `[i for i in [1,2,3]]` crashes identically since the mangle
hits the IIFE return regardless of the cond):

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

Run `debashc --shir-in-estree /tmp/comp.json` then the emitted JS under
the estree runner: today it crashes with `Signal { kind: 'RETURN',
value: NaN }` and prints nothing. Expected after the fix: `3\n4` (node
exit 0), matching `python3` on the source `x = [i for i in [1, 2, 3, 4]
if i > 2]; print(x[0]); print(x[1])`.

## OUTCOME: rejected: superseded by py-sh-go-20260814-204800-arraycomp-iife-return-mangled (identical defect; fixed by the in_loop-keyed fix_control_flow rework — the ArrayComp IIFE keeps its native return — and re-verified this round: 3/4 == python3).
