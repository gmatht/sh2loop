# core bug: DSE deletes stores observed only through `export NAME` (A1 builtin-call shape)

## NEED
`shir_passes/optimize.rs::collect_decl_guard` must recognize declaration
builtins in the A1 builtin-Call shape, not just the legacy Exec+string
shape. Offered from the C-backend worktree (branch backend/c, commit
a56544bc) — the fix is already written and verified there; the core owner
can take it verbatim or re-derive.

## FAILING-CASE
```bash
SHELL_VAR="Hello World"
export SHELL_VAR
perl -e 'print "Shell variable: $ENV{SHELL_VAR}\n"'   # or any child reader
```
(example: sh2perl/examples/045_shell_calling_perl.sh)

## EVIDENCE
- `X="…"` lowers to IrStmt::Assign; `export X` lowers to
  `Expr(Call{func:"builtin", args:[Str("export"), Array([Str("X")])]})`.
- `dead_store_elim` sees zero READS of X (the only read happens inside a
  child process via the environment) → deletes the Assign.
- collect_decl_guard guards only `IrStmt::Exec` whose string arg starts
  with "declare/export/readonly/typeset" — the A1 Call shape falls into
  its `_ => {}` arm.
- C backend gate: 045_shell_calling_perl regressed the moment the
  optimize pass joined the --shir-in-c ingest pipeline.

## FIX (verified in backend/c a56544bc)
Extend collect_decl_guard with an `IrStmt::Expr(IrExpr::Call{func,..})
if func == "exec" | "builtin"` arm: when cmd is export/declare/readonly/
typeset, guard every non-flag, non-`=`-containing word operand.
lib tests stay green; c gate returns to expected tally.
