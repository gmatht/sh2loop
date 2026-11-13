# c: nested brace alternatives are flattened — `BraceItem::Compound` is encoded but never constructed

## NEED

`shir::range_analysis_tests::nested_brace_alternatives_are_compound_groups`
(src/shir.rs:57086) is a **shared-core** test that FAILS on `backend/c`. It asserts
`a{x/{p,q},y}z` → `ax/pz ax/qz ayz`; the renderer emits `ax/z apz aqz ayz`.

The cause is in the PARSER, not in the c renderer. `src/parser/words.rs` never
builds `BraceItem::Compound`, so the `{"product": …}` encoding that
`brace_item_json` (src/shir.rs:18215) emits for a Compound is **dead code** — no
path ever produces it. Every nested-brace alternative is flattened into a sibling
`BraceItem::Nested`, which is the very bug commit `9cf3e952d` ("brace expansion:
nested alternatives are cartesian factors, not siblings") set out to fix. That
commit landed the ENCODING half (the `product` JSON + all the render-side
`product` handling) but the PARSER half that was supposed to group each
alternative's parts into a Compound is not present in this tree.

This is not c-specific: every backend reads the same shIR from `ast_to_ir`, so
every in-process renderer loses the nesting. c is simply the one whose gate
currently fails on it.

## WHY — exact location

`src/parser/words.rs:4888-4898`, inside `parse_brace_expansion`:

```rust
Some(Token::BraceOpen) => {
    flush_acc(&mut items, &mut acc);
    let nested = parse_brace_expansion(lexer)?;
    if let Word::BraceExpansion(be, _) = nested {
        items.push(BraceItem::Nested(Box::new(be)));   // <-- sibling, not a factor
    } else {
        return Err(ParserError::InvalidSyntax(
            "Expected brace expansion from nested brace".to_string(),
        ));
    }
}
```

The enclosing loop's only accumulator is `acc: Option<String>` (flushed by
`flush_acc` at words.rs:4775 as a `BraceItem::Literal`). There is no
per-alternative PARTS accumulator, so:

- a nested brace is pushed straight onto `items` as a sibling alternative;
- surrounding text is flushed as its own `Literal` alternative;
- a comma (words.rs:4899) or `}` (words.rs:4786) just flushes and breaks.

Result for `a{x/{p,q},y}z`, inner group = `[{"product":[["x/"],[{"nested":["p","q"]}]]},"y"]`.
Observed IR (dumped via `{:#?}` on `ast_to_ir`):

```
Json(Array [ Array [
    String("x/"),
    Object { "nested": Array [ String("p"), String("q") ] },
    String("y"),
]])
```

— a FLAT three-element sibling list. Expected is one alternative carrying a
Compound: `[{"product":[["x/"],[{"nested":["p","q"]}]]}, "y"]`.

`BraceItem::Compound` is constructed NOWHERE in `src/` (the only `Compound`
occurrences in `src/parser/` are zero; the hits in `ast_words.rs:256/405/571`
and `shir.rs:18215` are all CONSUMERS of the variant).

## MEASUREMENT

The c renderer's own `brace_expand` / `brace_group_items` / `brace_nested_items`
are CORRECT — fed the right JSON they produce the right answer. Unit-checked
directly:

```
EXPAND = ["ax/pz", "ax/qz", "ayz"]
```

for `brace(pre="a", Json([[{"product":[["x/"],[{"nested":["p","q"]}]]},"y"]]),
Json([]), suf="z")`. So the renderer needs no change; only the parser does.

Core test result (unmodified tree):

```
$ cargo test --lib nested_brace_alternatives_are_compound_groups
test shir::range_analysis_tests::nested_brace_alternatives_are_compound_groups ... FAILED
panicked at src/shir.rs:57093:13:
missing "ax/pz" in C:
    printf("%s\n", "ax/z apz aqz ayz");
```

Corpus cell (`sh2perl/examples/064_26_nested_brace_alternatives.sh`), which is
committed specifically to pin this behaviour ("A brace level's comma-separated
alternatives may each contain a nested brace; the nested group is a cartesian
FACTOR of that alternative, not another sibling alternative"):

```
bash: ax/pz ax/qz ayz
c:   ax/z apz aqz ayz
```

7 of that file's 8 lines are already correct; line 1 and line 3
(`{src/{main,test},docs}/{a,b}`) diverge for the same reason.

Full lib suite on this worktree: **1042 passed, 8 failed**. Two of the eight are
this brace pair (`nested_brace_alternatives_are_compound_groups`,
`brace_prefix_does_not_glue_a_separate_word`); the other six
(`estree::tests::assignment_lowers_to_setvar`,
`estree::tests::nested_param_default_chain_lowers_to_getvar_ternaries`,
`ir::tests::echo_tr_pipeline_renders_native_transliterate`,
`ir::tests::incdec_stmt_renders_increment`,
`ir::tests::redirect_pid_target_env_binding`,
`ir::tests::redirect_var_target_and_emulated_reads`) live in files this worker
has not touched and are reported here only for completeness — they may share a
root cause or may be unrelated; I did not diagnose them.

## MINIMAL-CORE-CHANGE

In `parse_brace_expansion` (src/parser/words.rs), add a PARTS accumulator
alongside `acc` and flush it as one `BraceItem::Compound` at each
alternative boundary (comma and closing brace), instead of pushing each part
directly onto `items`:

- `BraceOpen`: `parse_brace_expansion` → `BraceItem::Nested` pushed onto the
  current alternative's PARTS (not onto `items`);
- identifier/range/literal text: appended to the same PARTS;
- `Token::Comma` and `Token::BraceClose`: flush PARTS as
  `BraceItem::Compound(parts)` (collapsing to a bare `Literal` when the
  alternative has exactly one part, so the existing single-part encodings —
  plain `String`, `{"range": …}`, `{"nested": …}` — are byte-identical and the
  639 currently-passing cells do not churn);
- the "range in a multi-alternative brace stays literal" rule
  (`{1..3,7..9}` → `1..3 7..9`, currently handled at shir.rs:18374/18418 and in
  `brace_nested_items`'s `lone_range` check) must keep working under the new
  grouping.

The AST/renderer sides already handle `Compound` (ast_words.rs:256/405/571,
shir.rs:18215, and each renderer's `product` arm), so this is confined to the
parser plus the flush points.

## FAILING-CASE

```bash
# src/shir.rs:57087 (core test, currently failing)
echo a{x/{p,q},y}z          # bash: ax/pz ax/qz ayz ; core IR: ax/z apz aqz ayz
echo '{a,{b,c}}d'           # bash: ad bd cd
echo '{src/{main,test},docs}/{a,b}'
#   bash: src/main/a src/main/b src/test/a src/test/b docs/a docs/b
```

Corpus cell: `sh2perl/examples/064_26_nested_brace_alternatives.sh`
(gate bucket `FAIL stdout`).

## NOTE — NOT FILED HERE: the second c gate failure is a c-backend bug

For completeness, since both were visible in the same gate run:
`examples/063_20_final_complex_construct.sh` and `063_hard_to_parse.sh` fail
`rc(2 vs 0)` and that one is NOT a core defect. It is a c-backend exec-fallback
lowering defect — the fallback re-serializes arithmetic it should have lowered
(`i+++1`, `result[i]=$(( result[i] + $(wc -l …) ))` → `result[i]=`), emitting a
`bash -c` string that is a syntax error. It stays in the c worktree and is not
part of this request.

## OUTCOME: implemented — the parser's Compound grouping is present again (`acc_to_compound`/`flush_current`, restored by e6fcc5610). `cargo test --lib nested_brace_alternatives_are_compound_groups` PASSES and `064_26_nested_brace_alternatives.sh` renders `ax/pz ax/qz ayz`, matching bash.
