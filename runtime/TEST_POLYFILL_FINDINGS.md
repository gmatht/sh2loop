# Test-polyfill findings — why `test` is blocked (2026-08-27)

The `test` polyfill (the self-containment keystone — every `[[ ]]` in
the polyfill lowers to `sh2.test`) is **blocked by transpiler
limitations on char-level logic**. This doc records the findings for a
future transpiler fix or a different tokenizer strategy.

## What works (verified byte-identical to bash)

- **Tokenizer** (in isolation): splits test expressions into tokens —
  quoted regions, operators (`==` `!=` `=` `<` `>` `-a` `-o` `!`),
  parens, glob words. Uses case statements with escaped patterns /
  char classes for the char checks.
- **Parser + evaluator** (in isolation): recursive descent with SHARED
  GLOBALS (statement calls, not `$(...)` substitution — a subshell
  forks the index/result state, and the native-echo path bypasses
  captureSync). Handles `-a`/`-o`/`!`/parens/`-z`/`-n`/`==`/`!=`/`<`/`>`
  with glob matching via `globMatch`.
- **Integration fails**: the tokenizer stops early in the CAPTURE
  context (`toks=$(tokenizeTest ...)`) after a quoted `!` token when
  more input follows — a break/continue signal interaction between the
  nested while loops (word loop + quote loop) inside captureSync.

## The blockers (transpiler limitations)

1. **The runtime's test treats QUOTED operator chars as operators.**
   `[[ "$c" == "(" ]]`, `[[ "$c" == "!" ]]`, `[[ "$c" == "=" ]]` all
   mis-tokenize (the runtime's tokenizer checks the raw char before
   quote handling). Char-level comparisons against operator chars
   cannot be expressed in test strings.

2. **The transpiler's case lowering keeps quotes in patterns.**
   `case "$c" in ' '|'('|'!'|'=')` emits the patterns WITH quotes
   (`["' '", "'('", ...]`) — never matching. Only ESCAPED patterns
   work: `\*` `\?` `\[` `\\` `\=` `\"` `\'` `\<` `\>` and char classes
   `[\(\)]` `[x!]` (with disambiguation). NOT working: `\ ` `\(` `\)`
   `\!` (wrong regexes emitted).

3. **`done` is a reserved word.** `done=1` inside a case arm is
   mis-emitted as `sh2.exec("done=1", [])` (an external command).
   Rename to `qdone` etc.

4. **`strCompare` breaks on operator-char operands.** Its `[[ "$a" ==
   "$b" ]]` mis-tokenizes when b is `=`/`<`/`>`/`!`/`(`/`)`. The
   quoted-var case pattern `case "$c" in "$v")` works instead.

5. **`${#p}` in test strings fails** (the runtime's test doesn't
   handle it) — use `(( plen > 1 ))`.

6. **Nested `${rest:0:${#close}}` slices break the parser** —
   precompute lengths into vars.

7. **`[[ $(fn) == "1" ]]` lowers to a runtime test with a literal
   `$(...)`** — capture into a variable first.

8. **The native-echo path bypasses captureSync** — the parser's
   shared-global structure avoids `$(...)` for state, but the
   tokenizer's `$(tokenizeTest ...)` capture in the test function
   hits the break/continue interaction (blocker above).

## The path forward

- **Transpiler fix (landed 2026-08-27, sh2perl 448e78d):** native
  lowering for quoted-literal test operands — `has_unquoted_paren`
  (quote-aware paren scan), `try_native_compound_test` refuses only
  GROUPING parens, `split_test_connector` skips single-quoted regions
  (the `'('` in `\'('\'` was counted as grouping depth, hiding the
  `-a`/`-o` connector). `[[ "$c" == '(' || "$c" == ')' ]]` now lowers
  to `String(c) === "(" || String(c) === ")"` — verified byte-identical
  to bash on all quoted operator chars `(` `)` `!` `=` `<` `>` space
  `"` `'` `\` and compound `&&`/`||`/`!=` mixes; `cargo test --lib`
  386/386.
- **Remaining blocker:** the tokenizer STOPS in the capture context
  (`toks=$(tokenizeTest ...)`) after a quoted `!` token when more input
  follows — a break/continue signal interaction in the nested while
  loops inside `captureSync` (the tokenizer's own `[[ ]]` conditions
  are case statements now, so this is the capture/break interaction,
  not the operator-char issue).
- **Or defer:** the polyfill's own conditions could avoid `[[ ]]`
  entirely (use the string primitives + case), shrinking the test
  polyfill's scope to the adapter's needs.

## Status

- 17 polyfill functions landed (basename, dirname, strLen,
  strHasPrefix/Suffix, contains, strSlice, strCompare, strIndex/
  LastIndex, strCount, strReplaceAll, strContainsAny, joinSep,
  globMatch, caseMatch, param) — all byte-identical to bash.
- `test` blocked by the above; `brace` (dynamic-groups case) and the
  param limitations (extglob, nocasematch, `:=`/`:?`, `$ref`-expansion)
  remain.
