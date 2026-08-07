# split-in-array-literal: `arr=($x)` never expands (parser emits raw text)

Filed by the orchestrator after probe-verifying the split settlement
(PLAN v12, item #1). The printf/echo/for-in split paths are now correct
(exec-arg unquoted expansions carry the A1 `split` marker; the emitter
inlines it natively; the runtime flattens). ONE shell construct still
drops the quoted/unquoted distinction before the IR sees it.

## NEED

`arr=($x)` (unquoted expansion inside an array literal) must lower to
`setArray("arr", [split(getVar("x"))])` — the same A1 marker as exec-arg
unquoted expansions — so the element field-splits like bash. Today it
emits `setArray("arr", [Str("$x")])` — the RAW TEXT, never expanded:
`x="a b"; arr=($x); echo ${#arr[@]}` gives `n=1` (estree) vs `n=2`
(bash). Quoted `arr=("$x")` must stay a single unquoted-free element
(`getVar` inside an Interpolate, no split).

## WHY (root cause, probe-verified)

`parser/assignments.rs: parse_array_elements` returns `Vec<String>` of
RAW token text. It strips the quotes from `DoubleQuotedString`/
`SingleQuotedString` tokens but keeps the raw text for everything else,
so `$x` (unquoted) and `"$x"` (quoted, quotes stripped) both arrive as
the string `"$x"` — the quoted/unquoted distinction is DESTROYED before
`ast_to_ir` (`Word::Array` lowering at shir.rs ~4004/4034/4059: each
element becomes `st(e)` = `IrExpr::Str(e)`).

## MINIMAL-CORE-CHANGE (the fix path)

1. `parse_array_elements` → parse each element as a real `Word` (a
   `parse_word_list`-style loop that treats `Space|Tab|Newline` as
   separators and stops at `ParenClose` — note parse_word_list itself
   breaks on Newline; multiline arrays need a variant that treats
   Newline as whitespace).
2. `Word::Array(String, Vec<Word>, Option<()>)` (ast_words.rs) + the
   `Word::array` constructor + Display (join words with a space).
3. `ast_to_ir` Word::Array sites (shir.rs 4004, 4034, 4038, 4059, 4063):
   `elements.iter().map(arg_word_ir)` — arg_word_ir already lowers
   `Word::Variable` → `split(getVar(...))` and quoted interpolation →
   single-field. Do NOT use `word_ir_quoted` (array elements field-split
   like exec args, not like assignment RHS).
4. Perl generator consumers of `Word::Array` elements (generator/words.rs
   ~186/405, simple_commands.rs 49/246/699/1327/2749,
   test_expressions.rs 1319, redirects.rs 1197/1365, mod.rs 739) — each
   element becomes the per-kind word generation (the ad-hoc raw-string
   heuristics — `starts_with("${")`, backtick detection — become real
   Word dispatch). LITERAL elements must render byte-identically to
   today (perl corpus byte-identity for the corpus's array literals).
5. The runtime setArray/setArrayAppend already splice array-valued
   elements (probe-verified) — no runtime change needed.

## FAILING-CASE

```sh
x="a b"
arr=($x)
echo "n=${#arr[@]}"
echo "${arr[0]}|${arr[1]}"
```
bash: `n=2` / `a|b`. Current estree: `n=1` / `a b|` (the element is the
raw literal `"$x"`). Same for `printf "<%s>\n" ${arr[@]}`-adjacent paths
once the element expands.

## GATE

`cd sh2perl && cargo build --bin debashc && cargo test --lib`; then the
probe above (estree == bash), the array-@ copy probe (`y=("${x[@]}")` —
already green, must stay), and the full `./fail` + `./fail-estree`
corpus (the split settlement is emitter-side for printf/echo — zero
corpus output change expected; the array-literal fix touches 1 corpus
file, 051_primes.sh, which must not regress).
