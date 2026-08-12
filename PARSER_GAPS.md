# Parser Gaps — do the frontend examples cover the parsers' features?

The frontends' **own parsers** are almost all hand-rolled recursive-descent
Go (the ANTLR4 architecture in `plan-antlr-go.md` was never implemented —
the vendored `.g4` files are stubs; see `frontends/coverage/README.md`).
Only three use real parser libraries: rust-frontend (syn), cpp-sh-go
(tree-sitter-cpp), powershell-sh-go (tree-sitter-powershell). Hand-rolled
parsers have **no enumerated node inventory**, so "parser features" can't be
measured from inside — the honest measure is an **external source of truth**:
the official ANTLR grammars (grammars-v4) and PPI for Perl. This file records
what those checks found and what remains.

## The two checks

| tool | source of truth | frontends | reports |
|---|---|---|---|
| `frontends/coverage/antlr-coverage.sh` §3 | custom `antlr-sh/POSIX.g4` (grammars-v4 has no POSIX grammar) + official grammars-v4 **Python3** (vendored), **golang**, **c** (fetched; stubbed semantic superclasses) | posix-sh-go, py-sh-go, go-sh, c-sh-go | `RULE-UNEXERCISED` — grammar rules no example enters |
| `frontends/coverage/ppi-coverage.pl` | **PPI** (the de-facto Perl parser, `PPI::*` node classes) | perl-sh-go | `RULE-UNEXERCISED` — PPI node classes no example enters |

Reproduce:

```sh
bash frontends/coverage/antlr-coverage.sh          # sections 1–3
perl frontends/coverage/ppi-coverage.pl frontends/perl-sh-go/testdata/*.pl
```

Both parse every testdata example with the external grammar and report the
grammar rules / node classes **no example exercises**. Each unexercised rule
is a language construct the examples don't cover — then judge expressibility
against the frontend's subset and the executed-stdout gate (REFUSE > GUESS;
see GOOD_EXAMPLES.md), and add an example for the expressible ones. A
proposed example that fails the **oracle** (stdout mismatch) is a frontend
**lowering bug**, recorded in `frontends/coverage/bugs-<lang>.txt` — never
blessed, never silently dropped.

## Status per frontend (2026-08-12)

### posix-sh-go — 22/22 rules, 80/80 parse-clean, ZERO gaps
The custom POSIX.g4 had **six grammar bugs** that hid coverage (fixed in
`antlr-sh/POSIX.g4`): `compound_list` allowed only ONE `and_or` (multi-command
loop bodies like `echo x; i=$((i+1)); done` failed), `case_command` only took
a `WORD` discriminant with no separators after `in`, `=`/`!` weren't valid
words (broke `[ "$X" = "1" ]` and `[ ! -n ... ]`), redirect targets were
WORD-only (`> "$f"` failed), and backticks weren't allowed inside DQUOTE.
The earlier "unexercised: until_command case_command case_item pattern" was
the grammar's fault, not the examples'. With the fixes the examples cover
every rule.

### go-sh — 67/106 rules, 78/78 parse-clean (oracle-wrapped)
**Two real gaps found and closed** (both pass the gate):
- `importDecl`/`importSpec`/`importPath` — no example had an `import`
  statement → added `t76_import.go`.
- `arrayType`/`arrayLength` — examples only used `[]int` slices, never fixed
  `[N]T` arrays → added `t77_fixed_array.go`.

Remaining unexercised rules probed **by-design**: `constDecl`, `structType`,
`methodDecl`, `pointerType`, `breakStmt`/`continueStmt`, `gotoStmt`,
`selectStmt`/`sendStmt`/`goStmt`/`deferStmt`, `typeSwitch`, `typeAssertion`,
`interfaceType`/`channelType`, `functionType` — the go-sh subset
(`frontends/go-sh/go-sh.go` header) has none of these.

### py-sh-go — 45/119 rules, 71/71 parse-clean (official Python3 grammar)
The 74 unexercised rules are all **by-design** (probed): `classdef`, `try_stmt`
/`except_clause`, `lambda`, `decorator`, `break_stmt`/`continue_stmt`,
`import_from`, `assert_stmt`/`raise_stmt`/`del_stmt`/`pass_stmt`,
`nonlocal_stmt`, `with`… (with IS exercised), extended slices (`sliceop` —
`a[1:2:3]` refuses; `a[1:3]` is covered by t37/t66), `match_stmt` (3.10
patterns), `yield`, `async`, `global`(exercised). No clean expressible gap
remains.

### c-sh-go — 60/117 rules, 78/79 parse-clean (official c grammar, stubs)
The official grammar's `CLexerBase`/`CParserBase` run gcc + a symbol table;
they're **stubbed** with lookahead type-keyword predicates (in
`antlr-coverage.sh`) — `sizeof(type)`/`(int)` casts resolve; only
`t26_varargs.c` fails (needs `<stdarg.h>` preprocessing).

The interesting unexercised rules **parse in the frontend but lower BROKEN**
(silent drops — the executed-stdout oracle fails, so these are lowering bugs
for the c-sh-go worker, not example gaps):
- `typeQualifier` (`const`/`volatile`) — `const int x = 5;` emits NO assign
  (x read as unset) — the declarator init is dropped.
- `enumSpecifier` — `enum { A, B } e = B;` drops the init.
- `typedefName` — `typedef int myint; myint x = 7;` drops the init.
- `predefinedConstant` — `__LINE__` lowers to `getVar("__LINE__")` (unset →
  empty; gcc prints the line number).

Cleanly refused (by-design): designated initializers `{[1]=5}`, inline asm,
GNU `__attribute__`, `_Generic`, `_Static_assert`, `_Atomic`/`typeof`/
`alignas`, K&R declaration forms.

### perl-sh-go — 26/76 PPI classes, 68/68 parse-clean (PPI)
**One real gap closed**: `PPI::Token::Quote::Single` — no example used a
single-quoted string → added `t70_quoted_single.pl` (gate green). The
`$`-free subset lowers correctly; a single-quoted string **containing `$`**
is mis-lowered (interpolated) — recorded as a bug.

The PPI check surfaced a **number-literal bug cluster** (all parse, all lower
wrong — recorded in `bugs-perl-sh-go.txt`, oracle-verified):
- float `1.5` → concat `'1'.'5'` (prints 15)
- hex `0x1F` → 0; octal `077` → 77 (decimal); exp `1e3` → 1
- `q()` quote operator → function call to `q`
- `$#array` (last index) → bogus `Call("a", [elements…])`

By-design refusals: `use`/`require` (`Statement::Include`), `package`, `qw()`,
POD, `BEGIN`/`Scheduled`, labels, prototypes, attributes, `[]`/`{}` ref
constructors, `tr///`, casts.

### zsh / fish / bat — no external grammar exists
grammars-v4 has no zsh, fish, or batch grammars (and no POSIX — hence the
custom `.g4`). For these the only signal remains the A1-node proxy in
`coverage-gap.sh` (documented proxy: the hand-rolled parsers have no node
inventory, so observable output = the A1 they emit). A future external truth
could be tree-sitter grammars (tree-sitter-zsh/fish/cmd) or a hand-written
grammar like POSIX.g4.

## Hand-off: bugs the workers should fix

- **c-sh-go** (`frontends/coverage/bugs-c-sh-go.txt` does not exist yet —
  add it): const/enum/typedef/volatile declarator inits silently dropped;
  `__LINE__`/`__FILE__` read as unset vars.
- **perl-sh-go** (`bugs-perl-sh-go.txt`): number-literal cluster, `q()`,
  `$#array`, single-quote-`$` interpolation.

## Related

- `frontends/coverage/README.md` — the coverage tool suite (parser-coverage,
  coverage-gap, antlr-coverage §1–3) and the results table.
- `frontends/coverage/coverage-gap.sh` — the A1-node proxy + syn-node
  coverage (rust-frontend), the workers' per-cycle hook.
- `GOOD_EXAMPLES.md` (sh2perl) — how to write examples that pin a construct.
- `frontends/plan-antlr-go.md` — why the fleet was supposed to be ANTLR.
