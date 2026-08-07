# argv0-tests — the `$0` conformance suite

`$0` is invocation state (argv[0]), not a program constant. A translated
script must report **its own invocation path**, exactly like the original —
`bash script.sh` and the translated `script.sh` agree because they see the
same argv0. There is no single "right output" for `$0`; it depends on how
the script is run. That is why the stdout-match corpus (which blesses one
canonical invocation per example) cannot, on its own, pin `$0` semantics —
and why this suite runs every script under **three argv0s** and requires
every backend to agree with bash on each one.

## Contract under test

- `echo "$0"` — the full invocation path as given
- `${0##*/}`, `${0#/}` — basename / prefix-strip forms
- `dirname "$0"` — the invocation directory (a basename-only argv0 → `.`)
- `cd "$(dirname "$0")"` — self-location must track argv0
- usage lines / `$0` comparisons — the same value bash sees
- argv0 *renaming* — output tracks the invocation name, never the source's
  name (this is what catches a baked-in constant)

## The three argv0 scenarios

| kind | invocation | argv0 bash sees | `dirname "$0"` |
|---|---|---|---|
| `abs` | `bash $WORK/<t>/deep/nested/script.sh` | full absolute path | `…/deep/nested` |
| `base` | `(cd $WORK/<t>/base && bash script.sh)` | `script.sh` | `.` |
| `ren`  | `(cd $WORK/<t>/renamed && bash renamed.sh)` | `renamed.sh` | `.` |

Each scenario is materialized as a real file path, so `bash` and the `sh`
backend run an actual file at that argv0 (the estree/perl backends receive
the identical argv0 string via `--name` / the run wrapper).

## Backends

- `bash` — reference (runs the original source at the materialized argv0)
- `sh` — the sh backend renderer (`--shir-in-sh`), executed with argv0
  aligned via `sh -c '. /dev/fd/3' "$argv0" 3< render` (POSIX-safe argv0
  override: the render is sourced from fd 3, stdin stays untouched)
- `estree` — `debashc file --estree` + `harness/estree-runner.mjs --name`
- `perl` — the corpus generator + the same `do` wrapper `./fail` uses
  (`$0 = shift @ARGV; … do $__f`), so the corpus path is what's tested

The corpus's own `$0`-centric examples (`057_case.sh` usage line,
`qx-var-builtin-cd.sh` self-location) are referenced from the suite, not
duplicated — their multi-argv0 behavior is pinned here while they stay in
the corpus for single-invocation coverage.

## Run

```sh
harness/argv0-tests/run.sh            # all backends, both semantics
harness/argv0-tests/run.sh --only=sh,estree
harness/argv0-tests/run.sh --verbose
```

Exit 0 = the `$0` contract holds for every backend on every argv0, in BOTH
semantics (pass-through + source-name).

## The two selectable semantics

`$0` has two defensible meanings depending on the product context — they are
selected with `debashc --argv0-source <name>`:

1. **argv0 pass-through (default, no flag).** The translated script reports
   its OWN invocation path, exactly like the original. The harness supplies
   argv0 at run time (estree-runner `--name`/`--source`, the `do` wrapper,
   the sh gate's argv0 alignment). This is what a faithful POSIX port wants.
2. **source-name (`--argv0-source <name>`).** The translated program
   identifies as the ORIGINAL bash file `<name>`, whatever the executor's
   temp/artifact file is called. Perl bakes `$0 = '<name>'`; `--estree` emits
   a leading `sh2.argv0 = '<name>'` assignment. This is what a translation
   PRODUCT wants — the JS shell executing foo.sh should say "foo.sh", not
   the temporary JS file name.

The suite's `source` legs verify the bake beats all three argv0s (the
program reports `<name>` no matter how it is invoked). The sh backend
cannot assign `$0` in POSIX, so source-mode there is runtime-only: the gate
supplies argv0 = the source path when running the render.

## Guardrails

- **Never** bless a mismatch: a failure here means a backend is not doing
  argv0 pass-through (e.g. a hardcoded source name, or a harness that runs
  the two interpreters with different argv0s).
- The incidental-`$0` corpus examples (lexer/param-expansion tests where
  `$0` was just a convenient variable) were rewritten to deterministic
  variables — the corpus stays stdout-pure; only `$0`-centric scripts live
  in both places.
