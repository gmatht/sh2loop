# py-sh-go: A1 MethodCall node exists in the contract but the ESTree renderer panics on it — method calls are inexpressible through the gate

## NEED
The shared core must render the A1 **`MethodCall`** expr node (already
part of the A1 contract: `frontends/shir-contract/schema.json`
`"exprs"` vocabulary and the deserializer arm at
`sh2perl/src/shir_json_in.rs:923`, which maps
`{"type":"MethodCall","object":<expr>,"method":<str>,"args":[<expr>...]}`
to `IrExpr::MethodCall { obj, method, args }`). The ESTree renderer
(`expr_to_estree` in `sh2perl/src/shir.rs`) has NO arm for
`IrExpr::MethodCall` — it falls into the catch-all
`unreachable!("Perl-only IR expression reached the ESTree renderer")`
(src/shir.rs:32573). The Perl backend already renders the node
(`$obj->method(args)`, src/ir.rs:5366) and the python/go/zig backends
match it; only the ESTree path is missing.

MINIMAL-CORE-CHANGE: add an `IrExpr::MethodCall { obj, method, args }`
arm to `expr_to_estree` that lowers to the JS member call:

```rust
Expr::CallExpression {
    callee: Box::new(Expr::MemberExpression {
        object: Box::new(expr_to_estree(obj)),
        property: Box::new(Expr::Identifier { name: method.clone() }),
        computed: false,
        optional: false,
    }),
    arguments: args.iter().map(expr_to_estree).collect(),
    optional: false,
}
```

The ESTree-side analysis passes (`estree.rs` `fix_expr` /
`lower_expr` / `expr_read`) already handle the resulting
MemberExpression/CallExpression shapes, and `harness/estree-runner.mjs`
executes native member calls (the runtime itself is full of
`String(s).slice(...)` / `sh2.arrayIndex(...)` chains), so the
executed-stdout oracle needs no harness change. The renderer arm is
the whole core-side change; which methods a frontend MAY emit (JS
String.prototype equivalents like `trim`/`toUpperCase`/`split`/
`replace`, or a runtime mapping for Python-only names) is a
frontend-side emit decision that lands later.

## WHY
The coverage hook (`frontends/coverage/worker-coverage-step.sh` →
`coverage-gap.sh`, the A1-node proxy for py-sh-go's hand-rolled
parser) reports `A1 node MethodCall` as a construct no testdata
example exercises (verified 2026-08-14:
`bash frontends/coverage/coverage-gap.sh py-sh-go` lists
`A1 node MethodCall`). The reason no example exists: the frontend
cannot express it — no lowering path emits the node
(`frontends/py-sh-go/main.go` `methodIR` lowers every Python method
call onto the Call forms the ESTree runtime already supports:
`.strip()`/`.stdout` → identity, `.removeprefix`/`.removesuffix`/
`.replace`/`.upper` → `Call("param", ...)`, `.get` →
`Call("arrayIndex", ...)`, `.join` → `Call("join", ...)`), and a
testdata example that DID emit a `MethodCall` node would fail the
gate deterministically: `make test`'s executed-stdout oracle
(`harness/frontend-stdout.sh` → `debashc --shir-in-estree` →
`harness/estree-runner.mjs`) panics on the node before the runner
ever sees it.

This is NOT a by-design subset refusal: Python method calls are a
supported construct (t34_cmdsub `.stdout.strip()`, t70_str_methods
`.upper()/.split()`, t72_len_append `.append()`, t73_dict `.get()`),
the frontend has no FRONTEND.md, and the exclusion ledger
(`frontends/coverage/refused-py-sh-go.txt`, 70 grammar-rule entries)
contains no MethodCall entry. The frontend lowers onto Call forms only
because the ESTree target cannot render the contract's own node —
the shared-core gap, escalated here per core-requests/README.md.
Precedent: the `star_expr` request
(core-requests/done/py-sh-go-star-expr-20260813-221910.md) followed
the same pattern (construct in the subset, no lowering path, contract
missing/blocked the shape → escalate); here the contract already has
the node, only the renderer arm is missing.

## MINIMAL-CORE-CHANGE
One arm in `expr_to_estree` (src/shir.rs, ~line 30548) for
`IrExpr::MethodCall { obj, method, args }`, lowering to
`CallExpression(MemberExpression(object, Identifier(method)), args)`
as sketched in NEED. No contract change (schema.json / shir_json.rs /
shir_json_in.rs already round-trip the node — verified: the
deserializer accepts the shape and the panic occurs only in
`expr_to_estree`), no harness change. The existing "Perl-only" list in
that match shrinks by one node. Regression surface: the bash corpus
never produces MethodCall, so the arm is dead for `./fail`/`./fail-estree`
inputs — safe by construction; the frontend fleet's executed-stdout
gates then accept the node end-to-end.

The frontend side (a `methodIR` path emitting the generic node — e.g.
for `.strip()`/`.upper()` on a plain variable, or for methods outside
the current whitelist) is py-sh-go's own fix and lands after the
renderer has the arm; the coverage worker retries the gap
automatically once this request completes (core-pending-py-sh-go.txt
re-entry + pruning cycle).

## FAILING-CASE
Minimal Python program (python3 runs it fine):

```python
s = " hello "
print(s.strip())
```

stdout: `hello`.

The A1 the frontend WOULD emit for the generic method-call lowering
(the node the contract already defines):

```json
{
  "type": "Program",
  "contract_version": 1,
  "imports": [],
  "requires": [],
  "stmt_lines": [],
  "var_types": [],
  "subs": [],
  "stmts": [
    {
      "type": "Expr",
      "expr": {
        "type": "Call",
        "func": "echo",
        "args": [
          {
            "type": "MethodCall",
            "object": {"type": "Var", "name": "s", "sigil": null},
            "method": "strip",
            "args": []
          }
        ]
      }
    }
  ]
}
```

Current behavior (verified 2026-08-14 against the checked-out core):

    $ ./sh2perl/target/debug/debashc --shir-in-estree /tmp/mc.json > /dev/null
    thread 'main' panicked at src/shir.rs:32573:18:
    internal error: entered unreachable code: Perl-only IR expression
    reached the ESTree renderer: MethodCall { obj: Var("s", None),
    method: "strip", args: [] }
    exit=101

So no testdata example can cover `A1 node MethodCall`: the frontend's
own gate (ingress acceptance passes — the deserializer accepts the
node — but the executed-stdout oracle's `--shir-in-estree` conversion
panics) fails deterministically until the renderer arm lands.

## OUTCOME: implemented — expr_to_estree gained the IrExpr::MethodCall arm
(CallExpression(MemberExpression(object, Identifier(method)), args)) +
regression test (methodcall_renders_member_call); the request's failing-case
JSON now renders (was exit=101 panic) and a full Assign+exec("echo",[MethodCall])
program executes through estree-runner.mjs matching python3 (s.trim() → "hello").
Committed as 7365746; estree gate stays 521/521, cargo test --lib 293 passed.
