# BAD_EXAMPLES.md — corpus examples that are bad to gate a transpiler against

Which of the examples that **most backends fail** are genuinely useful tests, and
which are testing things of debatable value? This document answers that for the
sh2perl examples corpus. The companion file `BAD_EXAMPLES_DATA.tsv` has the
per-example verdict matrix.

**Scope of "bad"** — three common complaints about a gate are *not* treated as
bad here:

* **Hang-prone examples are wanted.** `yes | head`, `head <(while true; ...)`
  are deliberate hang-robustness probes; the gate's per-test timeout is the
  mechanism. Keeping them is correct (see §"Hang robustness").
* **Machine-dependent output is acceptable.** The gate compares the translation
  against *the same machine's* bash (`bash file` run from the same CWD, same
  env), so `/etc/passwd` line counts, `uname`, `$USER`, dpkg state, etc. are
  consistent for both sides. A translator that reads host state the way bash
  does passes; one that doesn't fails — that is a real signal, not noise.
* **External GNU-tool behavior is important.** Real bash scripts lean on
  grep/diff/cmp/comm/sed/tr constantly; a translator must reproduce that, so
  tests that pin it are valuable even though the *expected text* is a function
  of this machine's GNU coreutils release.

What remains "bad" is narrower and structural: examples whose reference output
is **empty** (the gate can only assert "prints nothing"), whose expected output
**cannot be reproduced by any faithful translation** (bash's own runtime state),
whose expected output is a function of the **mutable workspace** rather than the
script, or whose **script is simply broken** (unset vars, an undefined
command/function) so its output is an accident of bash's error handling.

## TL;DR

Of the **149 examples that fail on ≥6 of the 7 non-js/estree backends** (c, go,
sh, python, rust, zig, java — js and perl render the whole corpus; estree
passes 523/532):

* **~44 are bad test subjects** (empty/vacuous reference, must-fabricate bash
  state, workspace-mutable expected output, broken scripts, deliberate syntax
  errors).
* **~13 are borderline** — unfocused mega-tests (real semantics, no
  diagnosability; keep but split).
* **~92 are genuinely useful** — real semantics, deterministic, and only
  failing because the backends genuinely lag (estree passes them). This
  includes the hang probes, the host-state readers, and the GNU-tool tests.

The dividing line matters because a transpiler gate that fails on the first
group is not measuring translation quality — it is measuring whether the
translator happens to reproduce this machine's bash-5.2.21 + GNU-coreutils
behavior byte-for-byte.

**MOVED (2026-08-12)** — the deliberate-syntax-error set now lives in
`sh2perl/examples.bad/deliberate-syntax-errors/` and the bash-runtime-state
set in `sh2perl/examples.bad/bash-runtime-state/` (git mv — history kept,
content unchanged). They are out of the `fail` corpus glob for exactly the
reasons in the tables below; the syntax-error files keep their parser-
robustness purpose as structural checks, not stdout diffs. Categories C
(workspace-mutable) and E (broken) stay in the corpus because they ARE
fixable (hermetize with mktemp; initialize/define/pass-args) — see
Recommendations. The `echo-with-escaped-backtick*` pair is fixable only at
the ORACLE level (their feature is stderr routing): keep, and make the gate
compare stderr.

**FIXED (2026-08-12)** — the C (workspace-mutable) and E
(broken/vacuous) sets are repaired in the corpus (submodule aef921a):
unset vars initialized, the undefined function defined, dangling heredoc
closed, real fixtures supplied, and the three CWD-dependent tests made
hermetic (mktemp dir + cd, never the mutable workspace). All 31 now
produce deterministic non-empty bash output. The `echo-with-escaped-
backtick*` pair now emits its message to stdout (where the gate can see
it; the `exit 1` stays — stdout-only gates don't compare rc). The gzip
trio (complex-command-substitution / double-paren-subshell /
nested-subshell-paren) dropped their fd-racing structure for a
deterministic nested-cmdsub over real gzip fixtures; the fd-redirect
parse pin lives in parse-dollar-paren-pipe.sh. utf8-non-utf8-content.sh
unchanged (passes; toolchain-sensitive).

## How "fails on most backends" was measured

* Corpus: `sh2perl/examples/*.sh` (532) + `frontends/*/testdata/*.sh` (84) = 614.
* Per backend, each file is rendered through the worktree renderer
  (`--shir-in-<lang>` or `<lang>_backend`), the render must contain no
  `sh2.*`/TODO stubs, and when compiled+run its **stdout must byte-match
  `bash <file>`** (stderr ignored on both sides) — the
  `setup_backends.sh --backend-gate` oracle. Renders with stubs fail too.
* Machine/versions at measurement (2026-08-12, sh2perl `c2d5cf6`): GNU bash
  5.2.21, GNU coreutils (Debian). Estree verdicts from `.estree_failures.tsv`
  (523/532 pass; estree's own 9 fails are the grep runtime gap, the CWD `find`,
  two mega-tests, and one real parser gap).
* Verdicts on the 614: **c 438 pass**, **go 396**, **sh 498**, rust 48,
  python/zig/java ≈0 render-clean (stub-based). "Fails on most backends" =
  FAIL on ≥6 of the 7 measured backends → **149 examples**; 74 of them fail on
  all 7. All but 9 of those 149 pass estree.

## Why an example is bad to gate against (the oracle's real blind spots)

The gate's only assertion is "stdout equals `bash file`'s stdout". Under that
oracle an example is a bad test when:

1. **The reference output is empty / vacuous** — the test passes if the
   translator prints nothing, no matter how wrong the translation is (and fails
   if it prints anything, even correctly). This is the largest class.
2. **The reference output is bash's own runtime state** — `$-`, `$BASH_VERSION`
   — a translated program is not a bash process; matching means *fabricating*
   bash's state (the estree path passes `dollar-minus.sh` by baking the
   constant `hB` — a lie for any other invocation of bash).
3. **The reference output is a function of the mutable workspace** — `find .`,
   `grep -r .`, CWD globs. Both sides run in the same CWD, but the *expected
   output changes as the workspace evolves* (someone adds a `.sh` file and the
   reference text changes), and the reference backend itself cannot match it
   (estree fails `000__07`).
4. **The script itself is broken** — unset vars, an undefined command or
   function, missing required args — so its output is bash's *error handling*,
   an accident, not the feature the filename claims to exercise.
5. **The script is a deliberate syntax error** — bash exit 2, no stdout;
   "translate it the way bash does" is not well-defined, and the useful
   property (parser must not crash on bad input) is not what a stdout diff
   checks. Estree passes only via a special exit-2 fallback artifact.

Not included: host-state dependence per se, GNU-tool version dependence, and
hang-proneness — per the scope note above.

## A. Deliberate syntax errors — bash exit 2, empty stdout

Bash rejects these scripts; the reference stdout is empty. The genuinely useful
property (the parser must not crash on bad input) is not what a stdout diff
checks — any translator that prints nothing passes, any that prints something
fails, regardless of merit. Estree passes only via its exit-2 fallback artifact
for parse failures. These are better served by structural checks
(`harness/check_ast.pl`-style) or explicit "must reject with exit 2" assertions
than by stdout-vs-bash.

| example | bash says | why it's a bad test |
|---|---|---|
| `parse-error-doublesemicolon.sh` | `syntax error near unexpected token ';;'` | `;;` outside case — deliberate syntax error |
| `parse-double-semicolon.sh` | same | trailing `;;` after the `esac` |
| `parse-unexpected-end-of-input.sh` | `syntax error: unexpected end of file` | unterminated `if true; then` |
| `parse-unexpected-parenclose.sh` | `syntax error near unexpected token ')'` | stray `)` outside any subshell |
| `parse-paren-after-do.sh` | `syntax error: unexpected end of file` | `for ...; do {` then EOF |
| `parse-parameter-expansion-eof.sh` | `unexpected EOF while looking for matching '"'` | unterminated `"${var:?unset"` |
| `parse-unexpected-braceclose.sh` | `syntax error near unexpected token '}'` | stray `}` outside any block |
| `parse-unterminated-heredoc.sh` | *(no error)* | unterminated heredoc makes bash **swallow the rest of the file** as heredoc body (expanding `$?` in it); error-recovery behavior, context/version-sensitive |

## B. Bash-runtime state that no faithful translation can produce

The reference output is bash reporting on itself; a translation is not a bash
process. Matching requires fabricating constants that are wrong for any other
invocation (estree already does this for `$-`).

| example | the artifact | why it's a bad test |
|---|---|---|
| `dollar-minus.sh` | `echo "options: $"` → `hB` | `$-` is the option flags of *this* bash invocation (interactive / `bash -c` / `bash file` all differ). Estree passes by baking `hB` — a machine/invocation-specific lie. |
| `param-expand-default-operator.sh` | `[ "${BASH_VERSION-}" ]` → `bash` | the reference is bash asserting its own identity; a translated program is not bash, and "detect that I'm bash" is not translatable semantics |
| `tty-cmdsub.sh` | `tty` demos incl. hardcoded `/dev/pts/2` `/dev/pts/3` `/dev/pts/4` "owned by user 'ai' on this system" | hardcoded device paths that need not exist on another machine; the demo's output is the terminal state of the host, not the script's logic |

Note what is *not* in this list: `$0`-in-output (`057_case.sh`, `qx-var-builtin-cd.sh`)
is translatable — the translation product can carry the original script path as
its argv[0] (the estree path does exactly this via `sh2.argv0` and passes them).
`readonly`/`typeset` builtin demos are real semantics. Those are in the useful
section.

## C. Workspace-mutable expected output (not just host-dependent)

Same-machine host state is fine (scope note). These are different: the expected
output is a listing of the *workspace itself*, which changes every time the
repo changes — and the reference backend cannot even match it.

| example | the artifact | why it's a bad test |
|---|---|---|
| `000__07_find_path_commands.sh` | `find . -name "*.sh" -type f` over the CWD | at measurement the reference is a **7 569-line listing of the workspace**; it changes whenever any `.sh` file is added/removed; estree fails it too |
| `017_grep_context.sh` | `grep -r . --include="*.txt"` + creates `temp_file*.txt` in the CWD | expected output depends on the CWD's current `.txt` files; also writes into the shared workspace |
| `064_19_complex_pattern_matching_extended_globs.sh` | `for file in *.{txt,log,dat}` globs the CWD | with no matches the glob stays literal and the case matches the literal `*.txt` names — the output silently depends on what else is in the CWD |

## E. Broken / vacuous scripts — the output is an accident of bash's error handling

Either the reference stdout is empty (the only assertion is "print nothing"),
or the script never executes the feature its filename claims. None of the
"same machine / same tools" arguments rescue these: the script is broken, so
there is no feature being tested. Fixing them (initialize vars, define the
function, pass args, close heredocs) converts most of them into good tests.

| example | what actually happens |
|---|---|
| `array-assignment-variable-subscript.sh` | `$i` unset → arithmetic error in `${FilesystemOptions[(2*$i)-1]}` → empty stdout, exit 1 |
| `param-expand-question.sh`, `question-param-expand.sh` | `${var:?...}` with `var` unset → error to stderr, exit 1, empty stdout |
| `redirect-in-arithmetic.sh` | `${arr[1]>2}` is bad substitution → exit 1, empty stdout |
| `checkqx-qx-var-mv.sh` | `mv -Z` on nonexistent files → exit 1, empty stdout (nothing asserted) |
| `double-bracket-pipeline.sh` | no args → both `[[ ]]` false → empty stdout |
| `lexer-char-minus.sh` | `set -e` + failing `test "a" = "b"` → the script exits before the real assertion |
| `at-in-test.sh` | extglob off → `@(pattern)` is a literal → trivially false → just "parsed OK" |
| `at-var-default.sh`, `dollar-at-default-quoted.sh` | no args → `${@:-""}` → empty stdout |
| `063_11_complex_while_loop.sh` | `$input_file`/`$max_lines` unset → the loop reads nothing → empty stdout |
| `063_19_complex_function_call.sh` | calls `complex_function`, which is **never defined** → "command not found" → empty stdout |
| `064_11_complex_test_expressions.sh` | no args → `[[ "$1" ... ]]` false → empty stdout |
| `parse-samefile-operator.sh` | `$A`/`$B` unset → `test "" -ef ""` errors → exit 1, empty stdout |
| `parse-test-semicolon.sh` | unset `$var`/`$file` → every test false → empty stdout (the comment even mislabels it a syntax error — it isn't) |
| `parse-heredoc-or-dangling.sh` | dangling `||` after a heredoc — murky, version-sensitive parsing; empty stdout |
| `heredoc-redirects-same-line.sh` | `(cmd) <<EOF ...` — `cmd` is an undefined command; only the heredoc+redirect *parse* is exercised |
| `complex-command-substitution.sh`, `double-paren-subshell.sh`, `nested-subshell-paren.sh`, `parse-dollar-paren-pipe.sh` | `gzip -cdfq -- "$file1"` with `$file1`/`$file2` unset — the gzip never runs; parse-only value (the fd-race in the original `parse-dollar-paren-pipe` form is even documented inside the file) |
| `063_01_deeply_nested_arithmetic.sh` | all operands unset → division by zero → result empty; the echo prints a broken value |
| `031_control_flow_loops.sh` | the `while` condition uses unset `$i` → `[ -lt 10 ]` errors → the "loop example" never loops; output is an accident |
| `047_for_arithematic.sh` | unset `j` → `$((j*i))` is always 0 — the intended accumulation never happens; output "0" |
| `echo-with-escaped-backtick.sh`, `echo-with-escaped-backtick-and-quotes.sh` | all output goes to stderr (`>&2`); reference stdout is empty — the gate can only catch "stdout pollution", never "message lost" |
| `heredoc-binary-data.sh` | needs an interpreter arg; run bare it exits 4 with "Interpreter must be the command line argument." — it never tests what it claims |
| `utf8-non-utf8-content.sh` | source contains a raw ISO-8859-1 byte; byte-for-byte output depends on how each toolchain carries invalid-UTF8 through parse → render → run |
| `param-expand-hash.sh`, `param-expand-hash-sameline.sh` | `MAXWAIT` unset collapses `[ ${MAXWAIT% *} -gt ${MAXWAIT#* } ]` to `[ -gt ]`, which is vacuously **true** (one-arg `[` = non-empty test) — "compare done" is an accident; the parse pin is real but the runtime is meaningless |

## Borderline: low-diagnosability mega-tests (real semantics, keep but split)

These bundle dozens of constructs; when they fail there is no signal about
*which* construct broke. They do test real semantics, so they are not bad
tests — they are just poor *work items*: the failure-driven workers cannot act
on "the mega-test failed". Prefer the focused tests they are made of, and keep
at most one end-to-end smoke test.

| example | notes |
|---|---|
| `058_advanced_bash_idioms.sh` | nested loops/arrays/case — **estree fails it too** |
| `062_hard_to_lex.sh` | lexer edge cases + `$USER`/`$HOME` (estree fails it too) |
| `063_hard_to_parse.sh`, `064_hard_to_generate.sh` | `064_hard_to_generate` mixes `/etc/passwd`, `uname`, `hostname`, traps into one file |
| `070_gnuisms_thorough.sh` | every bashism + GNU coreutils flag at once (self-documents as a "thorough" sweep) |
| `000__03_file_manipulation_commands.sh`, `000__04e_file_manipulation.sh`, `000__04h_complex_examples.sh` | whole-command-category backtick demos (cp/mv/touch/... in one file) |
| `064_02_nested_brace_expansions.sh` | a single echo expanding `file_{a..z}_{1..10,20,30..40}.{txt,log,dat}` → a ~1000-word line |
| `012_process_substitution.sh`, `064_01_complex_nested_subshells.sh`, `064_09_process_substitution_pipeline.sh`, `064_17_complex_while_loop_nested_conditionals.sh` | multi-feature bundles (each would be several focused tests) |

## Not bad — the failures are real backend gaps (keep, keep red)

These fail on most backends because the backends genuinely lag, not because the
test is wrong. Estree passes them (or fails them for a *real* gap — noted).
They should stay in the corpus and stay red until the backends implement the
feature.

### Hang robustness (deliberately wanted)
* `065_yes_head_while.sh` — `yes | head -n100 | while read ...`: an infinite
  producer; a buffering translator must stream and terminate, not buffer and
  hang. The gate's 15s timeout is the assertion.
* `096_head_procsub.sh` — `head <(while true; do echo .; sleep 1; done)`: same.

### Host-state readers (fine on a same-machine gate)
* `/etc/passwd`-based: `091_while_pipe_var.sh`, `064_01`, `064_09`, `064_14_nested_command_substitution_arithmetic.sh` (`wc -l < /etc/passwd`), `064_17`
* machine identity: `064_21_complex_string_interpolation_multiple_variables.sh` (`${USER}`/`${HOSTNAME}`), `064_22_function_returning_complex_data_structures.sh` (`uname`,
  `hostname`, `$USER`), `id-cmdsub.sh`
* system databases/tools: `question-in-singlequote.sh`, `parse-db-status-fmt.sh`
  (`dpkg-query` — Debian-only, but this gate is Debian), `realpath-cmdsub.sh`,
  `parse-bracket-subshell-pipe.sh` (`service lightdm status`), `keyword-in-arg.sh`
  (`dd if=/dev/zero`, GNU `stat -c%s`)
* Caveat: these are not hermetic — a cross-machine CI would need a fixture
  environment (mktemp dir + generated /etc data). For this gate, both sides
  read the same host, so the comparison is valid.

### GNU-tool behavior (important — bash leans on these in practice)
* grep family: `016_grep_basic.sh`, `018_grep_params.sh`, `019_grep_regex.sh`,
  `039_process_substitution_here.sh`, `101_pipeline_failure_grep.sh`,
  `012_process_substitution.sh` — **estree fails all six** (its runtime lacks a
  native `grep`): a real gap, not a bad test. `017_grep_context.sh` is the
  exception (C: CWD-mutable).
* `040_process_substitution_comm.sh`, `042_process_substitution_advanced.sh`,
  `083_process_sub_missing_files.sh` — comm/diff/paste via process substitution
* `070_cmp_basic.sh` — GNU `cmp` message formats; note it uses *fixed*
  `/tmp/cmp_*.txt` names, so give it unique scratch (POSSIBLE_TESTING_
  IMPROVEMENTS.md #4)
* `041_process_substitution_mapfile.sh` — `mapfile`/`readarray` (bash 4+
  builtin)
* `bc-native-capture.sh` — GNU bc scale-0 semantics (estree matches by
  compiling `src/bc.rs` against "real GNU bc 77/77" — a captured tool behavior;
  pin the expected text as a fixture if bc drifts)
* Caveat: expected text is coreutils-version-specific; record bash/coreutils
  versions with each gate result (POSSIBLE_TESTING_IMPROVEMENTS.md #7) so tool
  drift is distinguishable from regressions.

### `$0` / builtin semantics (translatable — estree passes them)
* `057_case.sh` (usage line embeds `$0`), `qx-var-builtin-cd.sh` (`dirname
  "$0"`) — pass via argv0 handling (`sh2.argv0`); `readonly-cmdsub.sh`,
  `typeset-cmdsub.sh` — real bash builtin semantics.

### Real semantics (the core backlog)
* **Algorithms / arithmetic**: `051_primes.sh`, `054_fibonacci.sh`,
  `055_factorize.sh`, `061_test_local_names_preserved.sh`,
  `062_14_complex_array_operations.sh`, `bench-increment.sh`,
  `arith-postfix-status.sh` (postfix `((i++))` status semantics),
  `arithmetic-bracket-old-syntax.sh` (deprecated `$[...]`), `let-builtin.sh`,
  `let-plusassign.sh`, `declare-let-keyword.sh`,
  `dollar-positional-arithmetic.sh`, `t75_arith_compound.sh`
* **Parameter/array/brace/heredoc semantics**: `063_03_nested_command_substitutions.sh` (nested cmdsub),
  `063_04_complex_parameter_expansion.sh`, `063_05_heredoc_with_complex_content.sh`, `063_09_complex_function_parameter_handling.sh`, `063_12_complex_eval.sh` (eval), `063_14_complex_redirects.sh`, `064_03_complex_parameter_expansion.sh`, `064_07_complex_array_operations.sh`
  (assoc arrays, hash-order handled by sorting), `064_18_array_slicing_manipulation.sh` (array slicing),
  `064_20_nested_subshells_environment_variables.sh` (subshell env), `064_08_heredocs_with_variable_interpolation.sh` (quoted heredoc — note: writes
  `config.txt` into the CWD; give it scratch), `075_eval_complex.sh`,
  `076_brace_expansion_mixed.sh` (mixed list+range braces are a
  bash-version-subtle edge), `079_heredoc_interpolation.sh`,
  `cat-heredoc-pipeline.sh`, `heredoc-with-redirect-same-line.sh`,
  `heredoc-unclosed.sh` (misnamed — the heredoc is actually closed; real
  subshell+heredoc+redirect test), `071_while_ifs_read.sh`,
  `088_while_read_ifs_sort.sh`, `087_function_cmd_sub.sh`,
  `064_23_complex_error_handling_traps.sh` (trap ERR/EXIT — real semantics; the
  trap body uses `$LINENO` and a fixed `/tmp/064_23_temp_*` cleanup, so give it
  scratch)
* **The parse-\* family that is actually valid bash** (parser-gap pins with
  real output): `parse-array-plusassign.sh`, `parse-at-slice.sh`,
  `parse-at-slice-param.sh`, `parse-arithmetic-nested-array.sh`,
  `parse-arithmetic-extra-paren.sh`, `parse-dollar-brace-hash-hash.sh`,
  `parse-dollar-in-arithmetic.sh`, `parse-dollar-single-quote.sh`,
  `parse-dollars-in-string.sh`, `parse-eval-multiline.sh`,
  `parse-heredoc-dollar-paren.sh`, `parse-heredoc-eof-unexpected.sh`,
  `parse-heredoc-paren.sh`, `parse-heredoc-redirect-chain.sh`,
  `parse-invalid-redirect.sh`, `parse-longoption-with-dollar.sh` (real parser
  gap — **estree fails it too**), `parse-multi-command-while-condition.sh`,
  `parse-paren-close.sh`, `parse-redirect-clobber.sh`,
  `parse-redirect-in-case-pattern.sh`, `parse-substring-double-colon.sh`,
  `parse-variable-default-with-quotes.sh`, `parse-dollar-at-default.sh`,
  `dollar-at-with-default.sh`, `process-substitution.sh` (diff over procsub)
* **Frontend testdata** (focused, deterministic): `t03_pipeline.sh`,
  `t61_while_read.sh`, `t62_word_split.sh`, `t63_array_split.sh`,
  `t66_array_slice.sh`, `t75_arith_compound.sh`
* `050_test_ls_star_dot_sh.sh` — hermetic glob test (tempdir, known files:
  dotfile-glob semantics — a real gap)

## Recommendations

1. **Fix the broken scripts (E)**: initialize the variables, define the
   function, pass the args, close the heredocs — then the claimed feature
   actually executes and most of these become good tests.
2. **Fix the oracle for empty-reference tests (A/E)**: assert exit codes and
   stderr, or add an explicit echo marker (GOOD_EXAMPLES.md §6); a test whose
   reference is empty cannot verify anything. Move pure parser-robustness
   probes (bash-rejected scripts) to structural checks
   (`harness/check_ast.pl`-style) instead of stdout-vs-bash.
3. **Rewrite bash-runtime tests (B) to be translatable**: assert the
   *semantics* with the value injected by the harness — never bake constants
   like `hB`.
4. **Make workspace-mutable tests hermetic (C)**: run in `mktemp -d` with
   generated fixtures (as `050_test_ls_star_dot_sh.sh` already does); no
   `find .`/`grep -r .`/CWD globs against the live workspace.
5. **Keep the hang, host-state, and GNU-tool tests**, but record
   bash/coreutils versions with each gate result and use unique scratch
   (`070_cmp`'s fixed `/tmp/cmp_*.txt`), so tool drift and workspace drift are
   distinguishable from regressions.
6. **Split the mega-tests (borderline)** into the focused tests they are made
   of; keep at most one end-to-end smoke test.
7. **Use PASS-set monotonicity, not counts** (POSSIBLE_TESTING_IMPROVEMENTS.md
   policy 2): a new failure on a *good* example is the roadmap; a failure on a
   bad example should be fixed or removed, not chased.
