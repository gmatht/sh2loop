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
bash frontends/coverage/rules-gap.sh <lang>        # the worker-loop gap list
```

Both parse every testdata example with the external grammar and report the
grammar rules / node classes **no example exercises**. Each unexercised rule
is a language construct the examples don't cover — then judge expressibility
against the frontend's subset and the executed-stdout gate (REFUSE > GUESS;
see GOOD_EXAMPLES.md), and add an example for the expressible ones. A
proposed example that fails the **oracle** (stdout mismatch) is a frontend
**lowering bug**, recorded in `frontends/coverage/bugs-<lang>.txt` — never
blessed, never silently dropped.

### Wired into the worker loop

The frontend workers' coverage hook (`worker-coverage-step.sh`) now asks pi
for one example per **external-grammar rule gap first** (`rules-gap.sh`:
grammars-v4 rules / POSIX subset / PPI classes, ledger- and noise-filtered),
falling back to the A1-node proxy / syn kinds (`coverage-gap.sh`) where no
external grammar exists (zsh/fish/bat/zig/powershell/cpp) or none is
reported. So the fleet grinds toward *every expressible rule exercised*,
with each by-design refusal or lowering bug ledgered once
(`refused-<lang>.txt` / `bugs-<lang>.txt`) so the next cycle moves on. A pi
failure (nonzero rc, no file) is NOT ledgered — the gap is retried.

### Refused-refresh: the ledgers shrink as the frontends grow

A by-design refusal is only legitimate while the frontend's subset boundary
is static — and the frontends grow every cycle. At the idle point (fresh
gaps exhausted) `worker-coverage-step.sh` now re-proposes ledgered refusals
against the CURRENT frontend, rate-limited (one per `REFUSE_REFRESH_INTERVAL`,
default 1 day) and cursor-rotated (see `frontends/coverage/REFUSED-REFRESH.md`
for the design and the outcome table). A re-check that now EMITs drops the
entry from `refused-<lang>.txt`; a still-refusal keeps it; an escalation or
an oracle mismatch migrates it (refused → core-pending / bugs). So the
refused lists are a *current* subset boundary, not a graveyard: `wc -l
frontends/coverage/refused-<lang>.txt` is the shrink metric.

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

## Why each refusal (the reason categories)

"By-design" covers four different reasons, and the honest label for each
construct matters — a worker fixing it needs to know whether it's a
lowering bug, a missing subset item, or an A1 extension request:

1. **A1-EXTENSION (core request)** — the A1 shIR is shell-shaped
   (string/array store, no type system, no concurrency, no
   compile-time phase). A construct whose semantics *need* a type
   system, struct member layout, goroutines/channels, exception
   propagation, or a compile-time step can't be lowered with today's
   nodes — **but the frontend can request the A1 be extended**: append
   `core-requests/<fe>-<timestamp>.md` (NEED / WHY /
   MINIMAL-CORE-CHANGE / FAILING-CASE, per `core-requests/README.md`)
   and the estree worker (single owner of the shared core) implements
   it. Proven: c-sh-go's c-mem-slice2 and c-multi-return requests
   extended the A1/runtime (PLAN.md v20); two go-sh requests are
   pending right now. The estree worker mediates conflicts and may
   reject requests that don't serve the corpus.
2. **SUBSET-NOT-IMPLEMENTED** — the subsets are corpus-driven: each
   construct lands by pinning the core's exact A1 shape + a passing
   example (GOOD_EXAMPLES.md). Constructs with no shell-corpus
   counterpart were never pinned, so the parser refuses (fail-loud) or
   chokes rather than half-parse. These are *frontend-implementable* —
   no core change needed (the A1 already has the node: e.g.
   `Break`/`Continue` exist and c-sh-go emits them; py/go/perl just
   never wired them).
3. **MIS-LOWERED (a bug, not a refusal)** — the frontend *parses* the
   construct and exits 0 but emits the wrong shape; the executed-stdout
   oracle fails. Recorded in `bugs-<lang>.txt`; the worker must fix the
   lowering. Corrected during this audit: py `True`→`Str("1")`;
   c-sh-go const/enum/typedef/volatile inits dropped; `__LINE__`;
   perl number/q()/`$#` cluster.
4. **NO-OP / LEXER-DETAIL** — `compilationUnit`/`single_input`/`eval_input`
   (alternate start rules), `encoding_decl` (source-encoding comment),
   abstract base classes (PPI::Element/Node/Token). Not constructs.

### go-sh — 106 official-grammar rules, 39 unexercised

| unexercised | category | why |
|---|---|---|
| `constDecl` | 2 | Go const is a compile-time typed binding; the store is runtime string vars — would need const-folding the frontend never implemented |
| `typeDecl`/`typeSpec`/`aliasDecl`/`typeDef`/`typeParameters`/`typeParameterDecl`/`typeElement`/`typeTerm`/`typeArgs` | 1 | the type system + generics: the A1 store has no types; type decls have no runtime semantics, generics need call-site substitution |
| `structType`/`fieldDecl`/`embeddedField` | 1 | struct layout + member access need member offsets the pointer/array model doesn't carry |
| `interfaceType`/`methodSpec`/`functionType` | 1 | type-level abstractions with no runtime form |
| `methodDecl`/`receiver` | 1 | a method binds a function to a *receiver type*; the function model has no receiver concept |
| `pointerType` | 2 | the core's mem seam exists (c-sh-go uses sh2.mem) but go-sh never implemented pointer semantics |
| `breakStmt`/`continueStmt` | 2 | **parser choke** (`expected assignment operator, got }`), not a clean refusal — the loop lowering (for→While/Range) never emitted Break/Continue, though the A1 has the nodes |
| `gotoStmt`/`labeledStmt` | 2 | **parser choke**; Go's jump-into-block restrictions would need analysis; not implemented (contrast c-sh-go, which *did* land Goto/Label) |
| `selectStmt`/`commClause`/`commCase`/`recvStmt`/`sendStmt`/`goStmt`/`channelType` | 1 | goroutines/channels/select are process-model semantics; the A1's `Background` is shell backgrounding, unrelated |
| `typeSwitchStmt`/`typeSwitchGuard`/`typeCaseClause`/`typeSwitchCase`/`typeList`/`typeAssertion` | 1 | dispatch on *type* — needs the type system |
| `deferStmt` | 1 | LIFO stack-unwind at scope exit — no A1 node, would need a runtime construct |
| `fallthroughStmt` | 2 | Go switch fallthrough: go-sh's switch→if-chain lowering never implemented the keyword (c-sh-go's switch lowering merges fallthrough arms) |

### py-sh-go — 119 official-grammar rules, 74 unexercised

| unexercised | category | why |
|---|---|---|
| `classdef`/`decorator`/`decorators`/`decorated` | 1 | classes/instances/methods and higher-order wrapping — the A1 has `Function` (shell fn) but no class model |
| `try_stmt`/`except_clause` | 1 | exceptions: the A1 has `Die` (exit-with-message) but no catch/propagation — shell has no try/catch; the closest analogue (trap-ERR) isn't in the A1 |
| `lambda`/`lambdef`/`lambdef_nocond` | 2 | anonymous closures — the A1 has `Arrow` (lambda body) but py-sh-go's function model never implemented closures; shell has none |
| `async_funcdef`/`async_stmt`/`yield`/`yield_expr`/`yield_arg`/`comp_iter`/`comp_for`/`comp_if` | 1 | generators/async — coroutine semantics, no A1 channel |
| `break_stmt`/`continue_stmt` | 2 | clean refusal (`unsupported expression statement`) — the loop lowering never wired the (existing) A1 Break/Continue |
| `import_from`/`import_as_name`/`import_as_names` | 2 | plain `import` IS exercised; `from x import y` and aliasing were never pinned |
| `assert_stmt`/`raise_stmt`/`del_stmt`/`pass_stmt`/`nonlocal_stmt` | 2/1 | assert/raise = exception model; del = unset (the core's unset is a `Call`, not a stmt); pass = no-op (the parser refuses rather than drop — no Nop stmt); nonlocal = closure scoping |
| `match_stmt` + the 30 `patterns` rules | 1 | Python 3.10 structural pattern matching — entirely new dispatch semantics |
| `sliceop` (extended `a[1:2:3]`) | 1 | step slices: the shell param-slice idiom has no step; `a[1:3]` maps (t37/t66), `a[1:3:2]` can't |
| `annassign`/`varargslist`/`vfpdef`/`tfpdef`/`star_expr`/`star_named_expressions`/`testlist_star_expr` | 2 | type annotations and `*args` splatting — no type system; the fnCall positional model doesn't splat |
| `complex_number`/`signed_number`/`real_number`/`imaginary_number` | 1 | complex literals `1j` — no complex in the string store |
| `single_input`/`eval_input`/`encoding_decl` | 4 | REPL/eval start rules + the encoding comment — not constructs |

### c-sh-go — 117 official-grammar rules, 57 unexercised

| unexercised | category | why |
|---|---|---|
| `designation`/`designatorList`/`designator`/`gnuArrayDesignator`/`gnuIdentifier` | 2 | designated inits `{[1]=5}`/`{.x=1}`: the array/struct init model is positional; designated addressing isn't implemented (refuses: `unexpected token in expression`) |
| `asmDefinition`/`asmStatement`/`asmOperand`/`asmClobbers`/`asmQualifier`… | 1 | raw assembler — target-specific, and the estree runtime can't execute it |
| `attributeDeclaration`/`attributeSpecifierSequence`/`attribute*`/`gnuAttribute*`/`gccDeclaratorExtension` | 1 | compiler directives (`__attribute__`, packed/aligned/noreturn) — no runtime meaning in the A1 |
| `genericSelection`/`genericAssocList`/`genericAssociation` | 1 | C11 `_Generic` — compile-time type dispatch |
| `staticAssertDeclaration` | 1 | `_Static_assert` — a compile-time check, no compile-time phase |
| `atomicTypeSpecifier`/`typeofSpecifier`/`typeofSpecifierArgument`/`alignmentSpecifier`/`functionSpecifier`/`typeQualifierList`/`typeName`/`abstractDeclarator`/`directAbstractDeclarator`/`typedefName` | 1/2 | the C11 type surface beyond int/char/pointers; `const`/`volatile`/`enum`/`typedef` actually PARSE but mis-lower (bugs, recorded) — the rest refuse |
| `enumSpecifier`/`enumTypeSpecifier`/`enumeratorList`/`enumerator`/`enumerationConstant` | 3 | enums parse but the init is silently dropped — lowering bug, not refusal |
| `predefinedConstant` | 3 | `__LINE__`/`__FILE__` parse but lower as `getVar("__LINE__")` (unset) — bug |
| `declarationList`/`identifierList` | 4 | pre-ANSI K&R function/declaration syntax — no modern need |
| `exprList` | 4 | comma-expression contexts (generic/init) — no standalone construct |
| `vcSpecificModifer` | 4 | MSVC `__declspec` — nonstandard |
| `compilationUnit` | 4 | alternative start rule, not a construct |

### perl-sh-go — 76 PPI classes, 50 unexercised (bases excluded)

| unexercised | category | why |
|---|---|---|
| `Statement::Include` (`use`/`require`) | 2 | module loading: the A1 schema HAS a `Require` node — perl-sh-go just never implemented it (implementable) |
| `Statement::Package` | 1 | namespace switching — the A1 has no namespace model |
| `Token::QuoteLike::Words` (`qw()`) | 2 | **parser choke** (`expected (, got ident qw`) — the quote-like token family never landed |
| `Token::Pod` | 2 | POD doc blocks — the parser skips `#` comments but never learned to skip `=pod`..`=cut` |
| `Statement::Scheduled` (`BEGIN`/`END`) | 1 | compile-time phase — the A1 is a runtime statement sequence |
| `Token::Label` | 2 | perl-sh-go never implemented goto/labels (contrast c-sh-go) |
| `Token::Prototype` | 2 | prototypes change call-site argument semantics (scalar/list context) — the call model is fixed |
| `Token::Attribute` | 4 | declaration metadata, no runtime meaning |
| `Structure::Constructor` (`[]`/`{}` refs), `Token::Cast` (`@{...}`), `Token::ArrayIndex` (`$#a`), `Token::QuoteLike::Regexp` (`tr///`), `Token::Quote::Literal` (`q()`) | 3/2 | the reference model: perl references need a mem/pointer seam (the core has sh2.mem for C) that perl-sh-go never implemented — and where it *parses* (`q()`, `$#a`) it mis-lowers (bugs, recorded) |
| `Token::Number::Float/Hex/Octal/Binary/Exp/Version` | 3 | number variants parse but mis-lower (1.5→concat, 0x1F→0, 077→77, 1e3→1) — bugs |
| `Token::Quote::Single` | — | **closed**: t70 lands the `$`-free subset; `$`-containing single quotes mis-lower (bug) |

### zsh / fish / bat
No external grammar exists (grammars-v4 has none) — no per-rule refusal
list. The A1-proxy gaps there are the same categories: shell-only A1
nodes in non-shell frontends (CONTRACT), constructs lowered to other
nodes (e.g. unary→`Bin`, do-while→`While`), or parser chokes on
unimplemented subset items. A future external truth: tree-sitter
zsh/fish/cmd grammars.

## Hand-off: bugs the workers should fix

- **c-sh-go** (`frontends/coverage/bugs-c-sh-go.txt` does not exist yet —
  add it): const/enum/typedef/volatile declarator inits silently dropped;
  `__LINE__`/`__FILE__` read as unset vars.
- **perl-sh-go** (`bugs-perl-sh-go.txt`): number-literal cluster, `q()`,
  `$#array`, single-quote-`$` interpolation.
- **py-sh-go** (`bugs-py-sh-go.txt`): `True`/`False` lower to `Str("1")`/
  `Str("0")`.

## Escalating the A1-EXTENSION items

The category-1 rows are not blocked on the frontends — they're requests
waiting to be filed. To make a construct expressible, append
`core-requests/<fe>-<timestamp>.md`:

```markdown
# <fe>: <one-line summary>

## NEED
What the A1 must gain (node type + fields, serialization shape in
shir_json.rs / shir_json_in.rs, deserializer support).

## WHY
The failing case / Unsupported reason that prompted this.

## MINIMAL-CORE-CHANGE
The smallest change to the core that satisfies NEED.

## FAILING-CASE
A minimal source snippet (in <fe>'s language) that currently fails.
```

The estree worker (`main_loop_estree.pl`) polls `core-requests/*.md`,
mediates conflicts, and implements them — so e.g. Go's `select`/
channels, Python's `try`/`except`, or C's designated initializers become
*requestable* A1 extensions, not dead ends. The worker may reject a
request that doesn't serve the corpus (that's the mediation).

## Related

- `frontends/coverage/README.md` — the coverage tool suite (parser-coverage,
  coverage-gap, antlr-coverage §1–3) and the results table.
- `frontends/coverage/rules-gap.sh` — the worker-loop gap list: external-
  grammar rule gaps per frontend (ledger- and noise-filtered), preferred
  over the A1 proxy by `worker-coverage-step.sh`.
- `frontends/coverage/coverage-gap.sh` — the A1-node proxy + syn-node
  coverage (rust-frontend), the workers' fallback gap source.
- `GOOD_EXAMPLES.md` (sh2perl) — how to write examples that pin a construct.
- `frontends/plan-antlr-go.md` — why the fleet was supposed to be ANTLR.
