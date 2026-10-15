# Core bug: a `case` PATTERN's `$var` references are invisible to the DCE census

**Reporter:** rust backend worker
**Severity:** silent wrong output — the variable's only store is DELETED and the
pattern is then read from the ENVIRONMENT (empty). No error, no warning.
**Affects:** EVERY backend — the store is dropped in the shared core
(`transforms/dead_store_elim.rs`), so no renderer ever sees it.

## Repro

```sh
# /tmp/cb.sh
x=bar
case bar in
  $x) echo MATCH;;
esac
```

bash prints `MATCH`. The current pipeline:

```
$ otranspilerl-cli --target shir /tmp/cb.sh | jq '[.stmts[].type]'
["Case"]                      # <- the `x=bar` Assign IS GONE, and
                              #    var_types is [] so nothing declares `x`

$ otranspilerl-cli --target shir /tmp/cb.sh | shir_render --target=rust -
fn main() {
    let __sh_case0 = "bar".to_string();
    if __sh_fnmatch("$__sh_case0", &__sh_case0)   # (this spelling is the
    ...                                            #  rust renderer's own fix)
}
# compiled and run, it prints NOTHING where bash prints MATCH
```

The `case`-pattern read is also missed by the *analysis*, not just the DCE:
`analyze_var_const` reports `x` as `Const` (1 site) while `analyze_var_types`
reports nothing, i.e. the two verdicts disagree about whether `x` is used.

## Root cause (one line, one file)

`sh2perl/src/transforms/dead_store_elim.rs`, `census_stmt`, the `Case` arm —
it walks `cl.body` but **not `cl.patterns`**:

```rust
IrStmt::Case { discriminant, clauses } => {
    census_expr(discriminant, reads, writes, escapes, escaping);
    for cl in clauses {
        for s in &cl.body {                       // <- patterns never visited
            census_stmt(s, reads, writes, escapes, escaping);
        }
    }
}
```

A case PATTERN is EXPANDED by bash before matching, and the frontends hand it
over as SOURCE TEXT (`IrCaseClause.patterns: Vec<String>`, not an `IrExpr`), so
nothing else can see it either. `# Neutral ESTree-path-only nodes carry no Perl
variables` in `ir.rs:collect_vars_in_stmt` makes the same assumption for
`IrStmt::Case { .. }` (and `Function`/`Subshell`/`Background`) — it is at least
*consistent*, but the `patterns` gap is the one that deletes a live store.

Note the lift walkers already do the right thing
(`shir.rs:lift_walk_stmt` calls `lift_mark_string_refs(p, string_ctx)` on each
pattern), which is why `x` is excluded from `var_types` — the exclusion is
correct, but then nothing DECLARES `x`, and the renderer falls through to
`std::env::var`. The DCE census is the gap.

## The patch (verified; 34 lines, one file)

In `census_stmt`'s `Case` arm, before the body walk:

```rust
for p in &cl.patterns {
    for v in dollar_names_in(p) { reads.insert(v); }
}
```

plus the helper:

```rust
/// `$name` / `${name}` references inside a case PATTERN's source text.
/// Patterns arrive as TEXT (see the census arm) and bash expands them before
/// matching, so each `$name` is a read of that variable.
fn dollar_names_in(text: &str) -> Vec<String> {
    let b = text.as_bytes();
    let mut out = Vec::new();
    let mut i = 0usize;
    while i < b.len() {
        if b[i] != b'$' { i += 1; continue; }
        i += 1;
        if i < b.len() && b[i] == b'{' {
            i += 1;
            if i < b.len() && (b[i] == b'#' || b[i] == b'!') { i += 1; }
        }
        let start = i;
        while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_') { i += 1; }
        if start < i && (b[start].is_ascii_alphabetic() || b[start] == b'_') {
            out.push(text[start..i].to_string());
        }
    }
    out
}
```

## Verification (measured through the rust backend, 560-file corpus)

With ONLY that hunk applied (no other core change), rendering
`ast_to_ir` → `transforms::apply` → `strip_cfor` → `shir_to_rust`:

| | before | after |
|---|---|---|
| corpus stdout+rc vs bash | 555/560 | 555/560 |
| non-pass files | 5 (all bash-parse-error) | 5 (identical set) |
| files whose render changes | — | 51, all extra no-op `__SH_RC.store(0, …)` |
| `x=bar; case bar in $x) echo M;; esac` | prints nothing (bash: M) | prints M |

No file regresses. The 51 render deltas are a harness artifact (my driver omits
the CLI's status-stripping passes); stdout+rc equivalence is unchanged for every
one of them.

Repro for a fixer, minimal:

```sh
printf 'x=bar\ncase bar in\n $x) echo MATCH;;\nesac\n' > /tmp/cb.sh
otranspilerl-cli --target shir /tmp/cb.sh | jq '[.stmts[].type]'   # want ["Assign","Case"]
```

## Related, worth a look while in there (NOT fixed by the patch above)

`ir.rs:collect_vars_in_stmt` treats `IrStmt::Function { .. } | IrStmt::Subshell(_)
| IrStmt::Background(_) => {}` as carrying no variables. Walking their bodies is
the obvious intent, but doing so changed `optimize_stmts` Pass 1's referenced
set and made `sh2perl/examples/utf8-non-utf8-content.sh` emit an EMPTY
`fn main()` (all three prints dropped). So that extension is NOT safe as-is and
is deliberately left out of this request — flagged here so a fixer does not
assume the `Case` fix generalises to the sibling arms.
