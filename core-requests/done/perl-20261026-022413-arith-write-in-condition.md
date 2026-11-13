# perl: A1 folds a stale literal across an arithmetic write that sits in a CONDITION

## NEED

`copy_propagation` (the A1 `Const`/copy fold, `src/transforms/copy_propagation.rs`)
must not replace a read of a variable with its literal when the program writes
that variable through an ARITHMETIC expression in a **condition** — an `if` /
`elif` / `while` / `until` condition, or either operand of a `&&` / `||` chain
in such a condition.

## WHY

`count_stmt_assigns` walks a branch/loop BODY but drops the CONDITION:

```rust
IrStmt::If { then, elsifs, else_, .. } => { … }          // `cond` (and elsif `cond`) never counted
IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => { … }   // `cond` never counted
```

`count_expr_assigns` *does* classify `builtin("let", [ … ])` (`classify_builtin_writes`
→ `str_maybe_read_vars`), and `(( i++ ))` as a top-level statement
(`IrStmt::Expr`) counts correctly — but reached through a condition the write is
invisible, so the variable keeps `count == 1`, stays `Def::Literal`, and every
later read is replaced by the literal.

This is unrecoverable downstream: by the time a backend sees the A1 the write is
already GONE from the word — no renderer can lower the read back to a variable.
Every backend (c, rust, go, perl, …) inherits the wrong value.

Measured through the perl worktree renderer, 2026-10-26:

```console
$ cat b.sh
i=0
if (( i++ )); then :; fi
echo "i=$i"

$ otranspilerl-cli --target shir b.sh | jq '.stmts[-1].expr.args[1].elements[0]'
{"parts": [{"kind": "lit", "text": "i="},
           {"expr": {"style": "DoubleQuoted", "type": "Str", "value": "0"},
            "kind": "expr"}],          # <-- literal, the `getVar("i")` read is gone
 "type": "Interpolate"}

$ bash b.sh        →  i=1
$ <render> | perl  →  i=0
```

Contrast — the same write as a STATEMENT keeps the read (`getVar`), so the
trigger is precisely "the write is in a condition":

```console
$ cat a.sh
i=0
(( i++ ))
echo "i=$i"        # A1: {"func": "getVar", "args": [{"value": "i"}]}   ✓
```

Reproduced with `(( i++ ))`, `(( i+=2 ))` and `(( i = i + 1 ))`; with the write in
the condition of `if`, `while`, and either side of `&&` / `||`; and it is NOT a
`const_prop` (`shir_passes::optimize`) effect — that pass only folds
`VarKind::Const`, and `analyze_var_const` correctly reports `Vec<…>`-kind `Var`
for `i` here (`classify_builtin` handles `let`). The stale literal is introduced
by the copy-propagation transform's def count.

## MINIMAL-CORE-CHANGE

`src/transforms/copy_propagation.rs`, `count_stmt_assigns` — count the
conditions it currently skips (bodies are already walked):

```rust
IrStmt::If { cond, then, elsifs, else_ } => {
    count_expr_assigns(cond, counts, values, false, dynamic);
    for s in then { count_stmt_assigns(s, counts, values, false, dynamic); }
    for (c, b) in elsifs {
        count_expr_assigns(c, counts, values, false, dynamic);
        for s in b { count_stmt_assigns(s, counts, values, false, dynamic); }
    }
    for s in else_ { count_stmt_assigns(s, counts, values, false, dynamic); }
}
IrStmt::While { cond, body } => {
    count_expr_assigns(cond, counts, values, false, dynamic);
    for s in body { count_stmt_assigns(s, counts, values, false, dynamic); }
}
IrStmt::DoWhile { body, cond, .. } => {
    for s in body { count_stmt_assigns(s, counts, values, false, dynamic); }
    count_expr_assigns(cond, counts, values, false, dynamic);
}
```

`top = false` on purpose: a condition may run zero times, so it is a write site
(`count >= 2` ⇒ not `Const`) but never a foldable top-level def. No new analysis
is needed — `count_expr_assigns` already routes `builtin("let", …)` through
`classify_builtin_writes`, so this only stops the walk from dropping the node.

The same `..` else also hides `IrStmt::Case`'s discriminant (`Case { clauses, .. }`);
that one is conservative in the other direction (`$x` never folded) and is NOT
part of this request.

## FAILING-CASE

```bash
# b.sh
i=0
if (( i++ )); then :; fi
echo "i=$i"
```

Expected (bash): `i=1`. A1 today: the echo's word is `Str "0"` → every backend
prints `i=0`.

Second failing case (chain operand — same walk, condition position):

```bash
i=0
(( i++ )) && true
echo "i=$i"          # bash: i=1
```

Corpus impact: none of the 651 files observes it (the perl gate is 644/644 green
on the corpus either way), so this is a latent wrong-output bug rather than a
gate failure — but it is silent, and it produces a WRONG value rather than a
missing one, so a width check will never see it.

Verification after the change: `otranspilerl-cli --target shir b.sh` must carry
`{"func":"getVar","args":[{"value":"i"}]}` in the echo, and
`harness/backend_runtime_metric.sh perl` / the perl gate must be unchanged on the
corpus (no file there depends on the folded value).

## OUTCOME: implemented
