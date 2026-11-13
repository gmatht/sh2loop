
## OUTCOME: implemented — already landed: `store_rhs_string` (src/shir.rs:51062) now exempts `Expr::ObjectExpression`, so a record literal assigned through the native direct-store write is preserved raw instead of being String()-coerced to "[object Object]". Pinned by `store_rhs_string_exempts_only_strings_and_records`, which also asserts a NUMBER literal is still coerced (the arith-RHS path is unaffected). Safe for bash semantics because no shell path emits ObjectExpression.

## OUTCOME: implemented — confirmed landed this round as part of sh2perl `22083e1c4`
(`store_rhs_string` exempts `Expr::ObjectExpression`), pinned by
`store_rhs_string_exempts_only_strings_and_records`, which passes.
