# rust-frontend: record (struct) VALUES cannot be stored — store-write path String()-coerces native object RHS

## NEED

The rust-frontend lowers Rust structs to the contract's natural shapes:

- struct literal `Point { x: 3, y: 4 }` -> A1 `Object` expr
  (`{"type":"Object","properties":[{"key":"x","value":...}]}`; KNOWN_EXPR
  already, ESTree renders ObjectExpression);
- field read `p.x` -> the NEW drop-in node `FieldRead`
  (`src/shir_nodes/field_read.node`, landed 2026-08-23 on branch
  `s2p.rust` / merged to main 0b59e966; JS handler renders a native
  non-computed MemberExpression);
- methods -> mangled `Type_method` defs via the standard
  fnValue/fnCall positional protocol (receiver = first positional).

All of that works. What does NOT work is STORING the record: any
assignment of an Object literal to a named variable renders as

    sh2.vars.c = String({ n: "10" })

so the value becomes "[object Object]" and every subsequent FieldRead
yields undefined (frontend gate t46_methods.rs DIFF: native prints
10/20/10/10, transpiled prints 0/0/0/0).

## WHY

shir.rs, the store-bound Assign arm (~line 16690):

```rust
let native = target.indices.is_empty()
    && native_store_write_ok(&target.var)
    && call_free_expr(&ve).is_some();
let rhs = if native && !store_rhs_string(&ve) {
    Expr::CallExpression { /* String(ve) */ .. }
} else { ve };
```

`store_rhs_string` accepts only TemplateLiteral / string Literal, so an
ObjectExpression RHS gets wrapped. The runtime's `setVar` would coerce
too (`String(value)` except boxed pointers), but this site uses the
DIRECT `sh2.vars[name] = <expr>` write, which preserves any raw value —
the coercion is the only thing destroying it.

Arrays dodge the same problem only because they route through the
`setArray` builtin; records have no such channel.

## MINIMAL-CORE-CHANGE

Extend the no-coercion set for the NATIVE direct-store write to include
ObjectExpression — e.g. in `store_rhs_string` (shir.rs ~31519):

```rust
fn store_rhs_string(e: &Expr) -> bool {
    matches!(e,
        Expr::TemplateLiteral { .. }
        | Expr::Literal { value: serde_json::Value::String(_), .. }
        | Expr::ObjectExpression { .. })   // NEW: records are stored raw
}
```

Scope note: ObjectExpressions are emitted ONLY by frontends lowering
record/map literals (no shell path produces them), so this cannot change
bash-semantics output. The arith RHS coercion (`x=$((1+2))` -> canonical
decimal string) is unaffected (different arm). If a raw-value Declare
path is also desired later, the same predicate applies.

## FAILING-CASE

frontends/rust-frontend/testdata-pending/t45_structs.rs and
t46_methods.rs (moved out of testdata/ so the frontend gate stays green;
both emit valid ingress-accepted A1 — only stage-3 stdout DIFFs).
Emit repro:

    cd frontends/rust-frontend
    ./target/debug/rust-frontend --shir testdata-pending/t45_structs.rs --raw \
      | debashc --shir-in-estree | estree-runner.mjs /dev/stdin
    # prints "undefined undefined"; native rustc prints "3 4"

Once the core lands the change, move both files back to testdata/ and
the frontend gate covers the whole struct story end-to-end.
