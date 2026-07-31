# tests/coreutils — GNU coreutils corpus regression tests (red, fix later)

In July 2026 the GNU coreutils test suite (git HEAD `c4bf1d4`, 650 test
scripts in `tests/**/*.sh`, ~41k lines) was run through `debashc` as a
real-world corpus probe. 646/650 parse to Perl — the 4 parse failures are
exactly the parser-bug repros below, and the source/ESTree gaps are
semantic (they parse, but mis-compile). Per the workspace workflow,
**tests were added first**; fixes land later (each test goes green when
its fix lands).

Run: `./fail-coreutils [prefix]` (same gate as `./fail`, but over this
dir) — or `FAIL_CORPUS=tests/coreutils ./fail`.

Full-corpus coverage: `./tests/coreutils/metric` (fetches the checkout
on demand, records parse + ESTree unsupported coverage over all 650).

These tests are **red by design**. Never bless or allowlist them — that
would hide a transpiler bug (AGENTS.md guardrail).

## Tests

| Test | Documents (coreutils source) | Current failure |
|---|---|---|
| `coreutils-chmod-for-case-var.sh` | `for case in $cases` — `case` as a for-loop variable name is a parser keyword collision | `Unexpected token: Case at 1:1` |
| `coreutils-df-case-escaped-paren.sh` | case pattern with escaped paren `sync\(*` (no trailing `*)` alternative) | `Invalid syntax: Expected ')' after case pattern` |
| `coreutils-printf-env-prefix-if.sh` | env-var-prefixed variable command in an if condition (`if POSIXLY_CORRECT=1 $prog ...`) | `Lexer error: Unexpected character: $` |
| `coreutils-dd-cmdsub-digit-suffix.sh` | digit directly after a command-substitution `)` / brace `}` (`long_multiplier=$(... )1`) misparsed as a redirect fd | `Invalid syntax: Invalid redirect operator` |
| `source-inline.sh` | `. file` / `source file` are not inlined by the Perl backend; sourced definitions are lost | stdout mismatch (bash sources, Perl doesn't) |
| `check-estree-default-param.sh` | `${var:=default}` (and `:-`/`:?`/`:+`) lowers to `sh2.unsupported` in the ESTree emitter — the dominant gap (645/650 scripts, from `. "${srcdir=.}/tests/init.sh"`) | exits 1 while `sh2.unsupported` is emitted |

## Fix targets

- `src/parser/*` — keyword handling for `for` variable names; case-pattern
  parsing of `\(`/`\)`; env-prefix + variable command in `if` conditions;
  digit following `)`/`}` in a word.
- `src/ir.rs` / Perl generator — inline `. file` / `source file` (the
  generated `system('.', ...)` fails at runtime).
- `src/estree.rs` — lower the default-value parameter-expansion family
  (`:=`, `:-`, `:?`, `:+`) instead of `sh2.unsupported`.

## Why check_qx misses the `source` gap

check_qx.pl flags `qx{}`/`system()` calls whose command is a known
builtin. For `. ./lib.sh` the emitter generates:

```perl
my $__cmd_0 = '.';
$main_exit_code = $CHILD_ERROR = system($__cmd_0, './lib.sh') >> 8;
```

Two static-analysis holes hide it:

1. The command name is stored in a scalar variable (`$__cmd_0`), and the
   system() patterns only match a *literal* quoted command inside the call
   (Pattern 3), `bash -c` wrappers (Pattern 3b), or `system(@array)`
   (Pattern 3c). Unlike `qx{$var}` (Pattern 2), there is no tracker for
   the `system($__cmd_N, ...)` scalar form.
2. The builtin list has `source` but not its POSIX alias `.`, so even a
   statically visible `system('.', ...)` would not match.

So check_qx is a heuristic gate (catches "generator shelled out a builtin
instead of emitting native Perl"), not a source-inlining checker; the
runtime breakage is only caught by the stdout-vs-bash comparison in
`source-inline.sh`.

## Notes

- Every coreutils test starts with `. "${srcdir=.}/tests/init.sh"`; the
  suite itself depends on the gnulib `init.sh` (present in release
  tarballs, generated in git checkouts) and on built binaries at `./src`.
  Running the full suite end-to-end needs source-inlining first (see
  `source-inline.sh`), then an exit-code + file-state comparison mode in
  `fail` (coreutils tests signal via exit code/files, not stdout).
- Minor: a truncated `if (a && b) 2>/dev/null; then` (EOF without `fi`)
  reports a bogus `Unexpected character: ?` instead of an end-of-input
  error (parser error-reporting robustness; no dedicated test).
- The coreutils checkout used for the probe was kept out of the repo
  (shallow clone, `tests/` tree only); re-fetch with
  `git clone --depth 1 https://git.savannah.gnu.org/git/coreutils.git`.
