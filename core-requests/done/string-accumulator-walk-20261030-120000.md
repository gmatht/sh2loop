# string-accumulator: the read walks are exhaustive and refuse-first (BUGS_FOUND #11)

**To:** the string-accumulator / C-backend owner
**From:** the transform-proof lane (Isabelle adjudication of MIMEcroft's passes)
**Status:** LANDED on main (2026-11-09) — replayed 3-way onto the tree and
extended to `Try` `excepts`/`else_body`/`finally_body` and `Select` clause
bodies; 11 module tests green, failing-first re-verified

## What was wrong

`expr_read_walk` and `read_walk` ended in `_ => {}` catch-alls:

* no `IrExpr::Arith` arm — `n=$(( tsv + 0 ))` inside the accumulator's loop
  body is invisible, so the verdict still fires and a renderer may lower the
  append to a chunk array while the rest of the body keeps reading the value
  the variable last held;
* no `IrStmt` arms for `Redirect`, `Block`, `Subshell`, `Background`,
  `Pipeline`, `Declare`, `DeclareArray`, `ForInit`, `DoWhile`, `Try`,
  `Case`, `Function`, `Select`, `Asm`, `Shaderize` — a read behind any of
  those carriers was invisible too.

Measured on MIMEcroft it is not theoretical: `c_backend.rs` re-walks the
tree with `acc_vars_tree` and tracks four accumulators (`blk_p`, `tup_rp`,
`tup_gp`, `tup_bp`; 15 `_alen_` mirror sites). Those four escape only
because none of their loop bodies reads itself through `$(( ))`.

## The fix (branch `pir-acc-walk` lineage, commit b7344a7ee on 12b304ddf)

* `arith_read_walk` — `Var`/`Ident` reads, `Index` keys, `Assign`/`IncDec`
  name mentions; every `ArithAst` arm named.
* `expr_read_walk` — the missing `IrExpr` arms (`Capture`, `Arrow`,
  `Lambda`, `RawExpr`, `Regex`, `ArrayComp`); `Ext` refuses.
* `read_walk` — every statement list is visited via one carrier vector; no
  wildcard arm, so a new `IrStmt` variant is a compile error here.
* `self_append_vars` — recurses into `If`/nested loops and treats
  `continue` as a non-write surface (it skips the rest of the iteration);
  every other statement form still refuses the body.

## Verification (run on the branch)

* `cargo test --lib transforms::string_accumulator` — 11 passed.
* Failing-first: restoring `IrExpr::Arith(_) => {}` turns
  `an_arith_read_of_the_accumulator_refuses_the_verdict` red; the control
  `the_same_loop_without_the_arith_read_still_fires` stays green.
* `harness/transform-proofs.sh` — `OK proofs/StringAccumulator`
  (18 lemmas, `the_fix_is_load_bearing` is the same statement).

## Why it is NOT on main

The main tree's `src/transforms/string_accumulator.rs` carries a large
uncommitted expansion (`acc_vars_tree`, `lower`, the callee write-set work)
on top of `12b304ddf`. Re-landing means replaying the three hunks onto the
tree walk: `read_walk`/`expr_read_walk`/`arith_read_walk` are the same
functions there, and `acc_vars_tree` already reuses `self_append_vars`, so
the recursion fix applies unchanged. Nothing in this offer depends on the
uncommitted code.

**Requested action:** apply the walk hunks to the current tree, keep the 5
new tests, and re-run `cargo test --lib transforms::string_accumulator`.

## Re-landed (2026-11-09)

Applied to the current tree. `self_append_vars` had already been widened
here, so `git apply --3way` conflicted on that hunk only. The tree had also
grown two carriers the patch left body-only — `Try { excepts, else_body,
finally_body }` and `Select { clauses }` — so both are now walked, including
each `excepts[i].match_expr` and each clause's `ch`/`value`.

* `cargo test --lib transforms::string_accumulator` — 11 passed (the 6
  pre-existing tests plus the 5 from this offer).
* Failing-first, re-measured on a snapshot: reverting
  `IrExpr::Arith(a) => arith_read_walk(a, var, found),` to
  `IrExpr::Arith(_) => {}` gives 9 passed, 2 failed —
  `an_arith_read_of_the_accumulator_refuses_the_verdict` and
  `refuses_mid_loop_read` — with `the_same_loop_without_the_arith_read_
  still_fires` green.
