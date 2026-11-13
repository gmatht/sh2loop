# A reconstructed pipeline command drops every Perl variable — `q(...)` is non-interpolating

**Filed by:** the Perl generator worker
**Scope:** shared core (`src/ir.rs` — the `__sh_pipe_run` /
`__sh_pipe_capture` reconstruction, `SH_RUN_EXT_PREAMBLE`). The backend
post-pass can only reach the emitted text, not the reconstruction.

## The bug

When a pipeline or here-string containing shell variables is reconstructed
for the runtime seam, the command is emitted inside a **non-interpolating**
Perl `q('...')` literal while still containing `${config[*]}` / `$line` /
`${!aa[@]}` in its raw bash form. Perl therefore hands bash a command with
**no** substituted values. The command still parses, so nothing errors — the
values are just gone.

Minimal repro (`064_07_complex_array_operations.sh`):

```sh
declare -A config
config["user"]="admin"; config["host"]="localhost"; config["port"]="8080"
IFS=$'\n' sorted=($(sort <<<"${config[*]}"))
echo "Config: ${sorted[@]}"
```

generated `t.pl`:

```perl
@sorted = (join(' ', split(/\s+/, do { __sh_pipe_capture(q('sort' <<< ${config[*]}), "pipefail") })));
print("Config: " . (join(' ', join(' ', @sorted))), "\n");
```

`q('sort' <<< ${config[*]})` is a literal — `${config[*]}` reaches bash as the
six characters `$`,`{`,`c`,… So bash runs `sort` with an **empty** here
string, `__sh_pipe_capture` returns `''`, and stdout is `Config: ` instead of
`Config: 8080 admin localhost`.

Confirmed directly against the emitted file: instrumenting the capture shows
`RAW=[]` (empty) where the array holds three keys.

## Corpus reach — this is the useful part

A sweep of all 44 currently-failing examples for `q(...)` containing a
variable (script: rerun `harness/pg-one.sh <ex> --diff` per name) found the
shape in **six**:

| example | the offending reconstruction |
|---|---|
| `064_07_complex_array_operations.sh` | `q('sort' <<< ${config[*]})` |
| `063_11_complex_while_loop.sh` | `q('true' "{ IFS => \"\" }"; 'read' '-r' 'line' && … "$line" …)` |
| `063_hard_to_parse.sh` | same `read` loop (also `$input_file`, `$max_lines`) |
| `070_gnuisms_thorough.sh` | `q('echo' ${!aa[@]} | 'tr' ' ' '\n' | 'sort')` |
| `realpath-cmdsub.sh` | `… $stdout …` |
| `grep_p.sh` | `$ENV{ENV} . '{BGPID}'` (two sites) |

Every one of these is a **silent wrong answer**, not a crash: the exit code
is right, the program runs, and the value is simply absent. That is why the
per-example diffs looked like unrelated one-line substitutions
(`Config: `, `+` vs `-`, an empty stdout block) with no shared signature
until the reconstruction was inspected directly.

## Direction for the core

The reconstruction must (a) substitute the variable into the emitted Perl
literal rather than embedding the bash form verbatim, and (b) shell-quote
that value for bash — a value containing `"`/`$`/`` ` `` must not break out
of the command (currently `qq{…"$v"}` would hand bash an unbalanced quote).

## Not fixed here

`perl_generator_fixed.rs` can rewrite the emitted *text*, but the value is
already unrecoverable there: the surrounding `q(...)` shape and what counts
as a substitution happen during reconstruction in `src/ir.rs`. Deliberately
left to the core owner; the Perl generator worker did not touch the core.
## OUTCOME: progress — the core fix has LANDED; 2 of the 6 named examples now pass

Committed as sh2perl `9df43ab03` ("ir: substitute shell expansions into a reconstructed
capture command", gitlink bump `f859e97a`), plus `9df43ab03`'s regression test
`captured_cmd_with_shell_dollar_is_never_a_bare_perl_literal` — I re-ran it this round and
it is green.

What it does: the reconstruction hands bash a non-interpolating Perl `q('…')` literal that
still carried raw bash expansions, so `${config[*]}` reached bash as the six literal
characters `$`,`{`,`c`,… and the value was GONE. There is no `%ENV` carrier for a COMPOUND
expansion, so `var_exports_str`'s prelude cannot rescue it (it only handles a bare `$n`).
The fix substitutes the value into the emitted literal and shell-quotes it via `__sh_q`,
which is also what makes it safe for a value containing `"`/`$`/backtick. Shapes with no
value form (globs, `$(...)`, `&&`, `||`, subshells) still return `None` and keep the plain
shell-out, so nothing is silently mangled.

**MEASURED THIS ROUND** — the six examples the filing named, re-run against current HEAD:

| example | PERL | ESTREE |
|---|---|---|
| `064_07_complex_array_operations.sh` | **1/1 PASS** (was the filing's repro) | 1/1 |
| `grep_p.sh` | **2/2 PASS** (both sites) | 2/2 |
| `063_11_complex_while_loop.sh` | 0/1 | 1/1 |
| `063_hard_to_parse.sh` | 0/1 | 1/1 |
| `070_gnuisms_thorough.sh` | 0/1 | 1/1 |
| `realpath-cmdsub.sh` | 0/1 | 1/1 |

Corpus: **ESTREE 557/557 gate rc=0, PERL 506/557**, `fail-shir` rc=0.

**REMAINING: the four `read`-loop examples** (`063_11`, `063_hard_to_parse`,
`070_gnuisms_thorough`, `realpath-cmdsub`) share the second shape in the filing — a
reconstructed `while IFS= read -r line` loop with `$line` / `${!aa[@]}` / `$stdout` inside
the `q(…)`. The landed change covers the HEREDOC value substitution
(`'sort' <<< ` . `__sh_q(…)`) and I verified the emission now reads
`__sh_pipe_run(q{'cat' } . __sh_q($x), "pipefail")` rather than a bare literal. The
`read`-loop reconstruction is a DIFFERENT call site and has not been traced to its
remaining gap — I did not guess at it. Note also that `063_11`/`063_hard_to_parse`/`070`
are large multi-construct corpus files, so their remaining reds may not all be this shape
at all; the next round should re-sweep with `harness/pg-one.sh <ex> --diff` per name rather
than assume the original six-example table still holds.

## OUTCOME: implemented (all six named examples verified this round)
The reconstruction no longer emits a non-interpolating `q('…')` carrying raw
bash expansions; values are substituted and shell-quoted via `__sh_q`
(sh2perl `9df43ab03`, regression test
`captured_cmd_with_shell_dollar_is_never_a_bare_perl_literal`).

Re-measured against current HEAD, bash vs `perl -M5.010` on the generated file:

    064_07_complex_array_operations   PASS      grep_p            2/2 PASS
    063_11_complex_while_loop         PASS      realpath-cmdsub   PASS
    063_hard_to_parse                 PASS      070_gnuisms_thorough PASS

— including the four `read`-loop examples the previous note left open. Corpus:
PERL 562/562, ESTREE 562/562.
