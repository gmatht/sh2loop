# Parser Review — the frontend fleet, the ANTLR4 grammars, and what our examples exercise

Date: 2026-08-11. Snapshot — the workspace is live (background workers
churn binaries and corpora); re-run `frontends/coverage/parser-coverage.sh`
and `frontends/coverage/antlr-coverage.sh` for current numbers. All raw
per-file results: `frontends/coverage/results/*.tsv`.

The two questions this reviews:
1. How much of each source language do the frontends' parsers actually
   ingest, over real corpora?
2. The ANTLR4 grammars in the tree — what node types do they define, and
   how many of them do our examples actually exercise?

---

## 1. Per-frontend parser coverage

Method (see `frontends/coverage/README.md`): run each frontend's binary
(`--shir file --raw`) over a real corpus and classify every file —
**EMIT** (valid A1 JSON out), **BAD-EMIT** (exit 0 but no JSON — a bug),
**REFUSE** (clean subset refusal — parser worked), **PARSE-ERR** (parser
choked), **CRASH** (stack overflow/panic).

| frontend | corpus | EMIT | BAD-EMIT | REFUSE | PARSE-ERR | CRASH |
|---|---|---|---|---|---|---|
| sh (posix-sh-go) | `sh2perl/examples/*.sh`, 532 bash | **478 (89.8%)** | **44** | 0 | 0 | **10** |
| c (c-sh-go) | c-sh-go testdata, 79 | 79 (100%) | 0 | 0 | 0 | 0 |
| cpp (cpp-sh-go) | cpp testdata, 13 | 6 (46.2%) | 0 | 6 | 1 | 0 |
| go (go-sh) | the fleet's own Go, 91 | 66 (72.5%) | 0 | 2 | 23 | 0 |
| py (py-sh-go) | workspace py + testdata, 76 | 68 (89.5%) | 0 | 1 | 7 | 0 |
| pl (perl-sh-go) | workspace Perl, 88 | 66 (75.0%) | 0 | 2 | 20 | 0 |
| rust (rust-frontend) | sh2perl core .rs, 40 (library crates) | 0 (0%) | 0 | **40** | 0 | 0 |
| fish / zsh / bat | own testdata, 75/75/47 | 98.7 / 100 / 100% | 0 | 0 | 1 | 0 |

Notes:
- **rust's 0 EMIT is the subset, not the parser**: every file is a clean
  REFUSE at the v0.1 "only `fn main`" item gate — the syn parser handled
  all 40 real files (parser engagement 100%). Its main-bearing testdata
  emits 13/13.
- The Go/Python/Perl PARSE-ERR remainders are those frontends'
  shell-flavored subset walls on real-world code.

### 1.1 Two real bugs the review surfaced (both posix-sh-go-specific)

The core `debashc` handles every one of these files fine — the bugs are
in posix-sh-go's port of the parser, and no existing gate catches them:

- **44 BAD-EMIT files**: the parser prints `Parse error: …` to stderr
  but **exits 0 with empty stdout**. Any pipeline that trusts the exit
  code treats a parse failure as success (the byte-equality gate only
  catches it via the empty-vs-JSON diff). Fix: parse errors must exit
  nonzero.
- **10 CRASH files**: a **Go stack overflow** (`goroutine stack exceeds
  1000000000-byte limit`) on command-substitution/backtick-heavy inputs
  (`000__04a_basic_command_substitution.sh`, `sed-backtick.sh`,
  `qx-scalar-var-with-builtin.sh`, …) — unbounded recursion in the
  parser.

Both are actionable worker food: pin them in posix-sh-go's testdata as
asserted-failing gap pins (the `harness/check_ast.pl` KNOWN-AST-GAP
pattern — count as failures, print RESOLVED and leave when fixed; never
blessed).

---

## 2. The ANTLR4 grammars — node types defined vs exercised by our examples

### 2.1 Ground truth: only one grammar pair is real

| grammar | state | rules |
|---|---|---|
| `py-sh-go/grammars/Python3Lexer.g4` + `Python3Parser.g4` | real, vendored from grammars-v4 (Bart Kiers, 2014) | **119 parser rules, 129 token rules** |
| **syn** (crate, used by rust-frontend) | **real and in use** — the rust-frontend's parser | **132 AST node kinds** (40 Expr, 16 Item, 4 Stmt, 17 Pat, 15 Type, 9 Lit, 28 BinOp, 3 UnOp) |
| **tree-sitter** | **planned, not in use** — zero code in the tree; CPP_PLAN §1–§2 calls for it for C/C++; cpp-sh-go runs a provisional hand-rolled tokenizer until it lands | n/a |
| `frontends/coverage/antlr-sh/POSIX.g4` | written for this review (the plan's "custom .g4" for POSIX sh) | **21 parser rules, 43 token rules** |
| `posix-sh-go/grammars/POSIX.g4` | **stub** (14 lines; antlr4: "`package` came as a complete surprise") | 0 |
| `go-sh/grammars/GoLexer.g4` + `GoParser.g4` | **stubs** | 0 |
| `perl-sh-go/grammars/Perl.g4` | **stub** | 0 |

### 2.2 The measurement: which node types our examples emit

Method: parse every example with the generated parser; for **parse-clean
files** (zero lexer+parser errors), record every parser rule entered in
the parse tree (the CST node types) and every token type consumed.
Harness: `frontends/coverage/antlr-sh/Rules.java`.

| grammar | node types defined | exercised by our examples | never exercised |
|---|---|---|---|
| Python3 (parser rules) | 119 | **53 (44.5%)** | 66 |
| Python3 (token rules) | 129 | 51 | 78 |
| POSIX custom (parser rules) | 21 | **17 (81%)** | 4 |
| POSIX custom (token rules) | 43 | 35 | 8 |

### 2.3 Python3 — the exercised corner is the shell-flavored subset

Hot rules (the spine our examples live on): `not_test` (2121 hits),
`or_test` (2046), `test` (1997), `name` (1663), `trailer` (869 — calls,
attributes, indexing), `stmt`/`simple_stmt` (640/464), `if_stmt` (96),
`return_stmt` (37). That is: assignments, prints, calls, if/while/for,
functions — the exact surface the py-sh-go frontend lowers.

The **66 never-exercised rules** are the whole modern-Python surface the
shell-flavored examples avoid, i.e. the frontend's natural refuse
surface: classes (`classdef`, `class_pattern`), `match` + the entire
pattern family (~20 rules), comprehensions/star expressions, lambdas,
decorators, async (`async_funcdef`, `async_stmt`), imports
(`import_from`…), `raise`/`del`/`nonlocal`/`assert`/`break`/`yield`,
slicing with step (`sliceop`), complex/imaginary literals.

### 2.4 POSIX — the 4 unexercised rules are a grammar gap, not a corpus gap

`case_command`, `case_item`, `pattern`, `until_command` never fire. The
corpus *does* contain `case` — but the clean files' case statements use
quoted discriminants (`case "$x" in`), and the grammar's
`CASE WORD IN` requires a bare word. So the 81% is the grammar's ceiling
on this corpus modulo a one-rule fix, and `until` is simply absent from
the clean subset.

### 2.5 syn — the rust-frontend's parser (real, in use)

syn's "node types" are its typed AST kinds. Method: parse every file
with syn and walk the typed AST counting kinds per category
(`frontends/coverage/syn-coverage/`). Corpus: sh2perl core + CLI (40
real Rust files) + rust-frontend testdata (24 example files) — 65
files, all parsed.

| category | defined (syn 2.0.119) | exercised (65 files) | exercised (testdata only) |
|---|---|---|---|
| Expr | 40 | 30 (75%) | 18 (45%) |
| Item | 16 | 11 (69%) | **1 (6%)** |
| Stmt | 4 | 4 (100%) | 3 |
| Pat | 17 | 14 (82%) | 3 (18%) |
| Type | 15 | 12 (80%) | **1 (7%)** |
| Lit | 9 | 7 (78%) | 3 (33%) |
| BinOp | 28 | 21 (75%) | 13 (46%) |
| UnOp | 3 | 3 (100%) | 2 |
| **total** | **132** | **102 (77%)** | **44 (33%)** |

The real corpus exercises 77% of syn's vocabulary — a *broad* corner:
the core is a full Rust program (enums, impls, traits, closures,
pattern matches, slices, pointers). The frontend's own testdata — the
v0.1 shell-flavored examples — sits in a *narrow* corner (33%): one
Item kind (`Fn`), one Type kind (`Path`), 18 of 40 Expr kinds.

The 30 kinds never exercised by the real corpus are the surface the
rust-frontend can refuse without losing anything it processes:
`async`/`await`/`yield`, raw pointers and address-of (`RawAddr`),
`unsafe` blocks aside, unions, trait aliases, `extern crate`, foreign
modules, `Group`/`Verbatim`/`Infer`, `Lit::CStr`, and the bit-shift /
bit-xor operator family (`Shl`, `Shr`, `BitXor`, `BitOr`, …).

### 2.6 tree-sitter — planned, not in use: nothing to measure yet

There is **zero tree-sitter code in the workspace** (no bindings in any
go.mod, nothing in the Go module cache, no Rust `tree-sitter` crate
use). It exists only as CPP_PLAN's specification for the C/C++
frontend: tree-sitter-c/tree-sitter-cpp grammars + a shared Go walker,
shipped as a self-contained wasm binary (the cgo/wasm constraint,
CPP_PLAN §2). Until that lands, the C++ frontend's *actual* parser is
the provisional hand-rolled tokenizer (keyword refusal + C desugar),
which is what §1 measures: cpp-sh-go 6/13 EMIT, 6 REFUSE, 1 PARSE-ERR
over its own testdata.

Measuring tree-sitter coverage (the same defined-vs-exercised
analysis) is a follow-up that requires first adopting a binding
(`smacker/go-tree-sitter` or the Rust `tree-sitter` crate) and the
tree-sitter-c/cpp grammars — the grammar-node analysis can then reuse
the `Rules.java` approach with node-kind strings instead of rule names.

### 2.7 What this means (all parser technologies)

- **The examples occupy a small corner of the grammar surface.** The
  hand-rolled frontends don't need to implement 119 node types — they
  need the ~53 the examples exercise, plus a refusal path for the rest.
  That is exactly what they do, and the coverage numbers in §1 confirm
  it: py-sh-go emits A1 for 89.5% of the corpus, and the ANTLR
  parse-clean rate over the same corpus is 97.4% (the grammar parses
  more than the subset lowerer can emit).
- **The node-type analysis doubles as the refuse list.** The 66
  unexercised Python3 rules are a ready-made, measured inventory of what
  a py frontend worker may refuse without losing corpus coverage.
- **The 59.1%-vs-89.8% sh comparison** (ANTLR POSIX parse-clean vs
  posix-sh-go EMIT over the same 532 bash examples) is the quantified
  reason the fleet is hand-rolled: ANTLR's POSIX ceiling on bash is 30
  points below the hand-rolled parser, and that's parse-only — no A1
  emission.
- **syn is the opposite shape from ANTLR.** ANTLR's grammar is a
  superset of the examples (parses 97.4% but only parses); syn is the
  exact typed grammar of Rust, and the real corpus exercises 77% of it
  — a broad corner, because the corpus includes the sh2perl core
  itself. The frontend's own examples sit in a narrow 33% corner
  (one Item kind, one Type kind), which is precisely the v0.1 subset
  rust-frontend refuses around.
- **tree-sitter is unmeasured by definition** — it has no code in the
  tree yet; its measurement method is ready (the Rules.java pattern)
  for when CPP_PLAN's C/C++ grammar work lands.

---

## 3. Action items

1. **posix-sh-go exit-code bug** (BAD-EMIT ×44): parse errors must exit
   nonzero. Frontend-scoped; pin 2–3 repros in its testdata.
2. **posix-sh-go stack overflow** (CRASH ×10): unbounded recursion on
   command substitution. Pin the crash repros; fix the recursion.
3. **POSIX grammar `case` fix** (only if the grammar is kept): allow a
   quoted discriminant (`case "$x" in`).
4. **Wire the coverage tsvs into the workers** as the improvement-mode
   queue (`frontends/coverage/results/*.tsv`), and start the posix-sh-go
   worker — no workers are currently running.
5. **ANTLR decision record**: the measured numbers (this doc + the
   coverage README) are the answer to "why not ANTLR for sh" — do not
   re-litigate without new grammar evidence.
6. **syn**: the rust-frontend already refuses everything outside its
   44-kind testdata corner; the measured 30 never-exercised kinds are
   the ready-made refuse list. No action needed — the v0.1 subset is
   consistent with the data.
7. **tree-sitter**: nothing to do until the CPP_PLAN C/C++ grammar work
   lands; the review provides the measurement method (Rules.java
   pattern) for when it does.
