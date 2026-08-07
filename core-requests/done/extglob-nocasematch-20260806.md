# extglob/nocasematch: [[ ]] pattern semantics lost in the test-cond string

## NEED

`ast_to_ir` flattens `[[ $x == PATTERN ]]` test conditions to a plain
string (`"$f1==!(*.min).js"`, `"$word==\"foo\""`) with no marker for:
- `[[ ]]` vs `[ ]` (different operators/semantics),
- extglob patterns (`!(*.min)`, `@(a|b)`, `+(x)`) — needs `shopt -s
  extglob`,
- nocasematch (`shopt -s nocasematch` makes `==` case-insensitive).

The Perl/ESTree renderers must reverse-engineer all three from the
string text (the Perl renderer has a heuristic `!(*.P).S` → ends-with-S
&& not-P+S, and a runtime `$__nocasematch` flag — both approximations
that fail on general extglobs).

Minimal contract: add a per-test marker to `IrStmt::If`/`While` conds
(or a new field on the test Call): e.g. `IrExpr::Call { func: "test",
args: [Str(text), Str("[[")] }` — the second arg tags the bracket style
(and extglob/nocasematch are already visible as `shopt` Calls in the
statement stream). A backend that can't lower the tag keeps its current
behavior; the tag is additive.

## WHY

Corpus files blocked (~4 deterministic + the general `[[ ]]` family):
010_pattern_matching.sh, 037_pattern_matching_extglob.sh,
038_pattern_matching_nocase.sh, 057_case.sh (case patterns with
extglob), plus every `[[ $x == glob ]]` that a renderer heuristic
misses. The Perl renderer's `!(*.P).S` rule is the worked example of the
hack: it handles `!(*.min).js` but nothing else.

## MINIMAL-CORE-CHANGE

In `ast_to_ir`'s test-cond lowering (src/shir.rs), when the source used
`[[ ]]` (the parser knows — `TestExpression` vs `[[ ]]`), append a
second arg to the emitted `test` Call:

```rust
IrExpr::Call {
    func: "test".into(),
    args: vec![IrExpr::Str(text, StrStyle::DoubleQuoted),
               IrExpr::Str("[[" .into(), StrStyle::DoubleQuoted)],
    ...
}
```

(`[ ]` keeps the current single-arg shape; the JSON contract accepts the
extra arg — the deserializer passes `args` through.)

## FAILING-CASE

```sh
#!/bin/bash
shopt -s extglob nocasematch
f1="file.js"; f2="THING.MIN.JS"
[[ $f1 == !(*.min).js ]] && echo f1-ok
[[ $f2 == !(*.min).js ]] || echo f2-filtered
[[ $f1 == FILE.JS ]] && echo ci-match
```

Current: the extglob tests rely on the renderer's `!(*.P).S` heuristic
(`f1` works, general patterns don't), and `ci-match` needs the
`$__nocasematch` runtime flag. With the tag, a backend lowers
`[[ ]]`+extglob+nocasematch properly: `($x =~ /^(?!.*\.min)\.js$/i)`
style.
