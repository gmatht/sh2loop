# BASH_ENV_FAILURES.md — bash-runtime-state failures (byte-for-byte gate)

These corpus tests fail because the generated Perl runs under `perl`, not bash,
and the script reads **bash's own runtime state** (shell options, shell identity
variables, the host's environment, terminal devices). Matching them
byte-for-byte would require *simulating* bash's runtime in the generated Perl —
i.e. fabricating values bash itself sets. That is deliberately **not** done:
it would bake machine-specific constants into translations and hide real
semantic gaps.

Test gate: `./fail` compares generated-Perl stdout byte-for-byte with
`bash <file>` stdout (plus exit code). The failures below are therefore
"correct" per the harness contract; they document a class of shell
semantics the Perl backend chooses not to emulate.

---

## 1. Shell-option introspection — `$-`

| Test | Source | bash output | why it cannot match |
|---|---|---|---|
| `dollar-minus.sh` | `echo "options: $"` | `options: hB` | `$-` is the current shell option flags (`h` = hashall, `B` = braceexpand). A generated Perl script is not a bash process; it has no option flags to report. Emitting a constant `hB` would be a lie for any real invocation (the flags depend on how bash was started: `bash file` vs `bash -c` vs an interactive shell differ). |

## 2. Shell identity variables — `$BASH_VERSION`, `$ZSH_VERSION`

| Test | Source | bash output | why it cannot match |
|---|---|---|---|
| `param-expand-default-operator.sh` | `if [ "${ZSH_VERSION-}" ]; then echo zsh; elif [ "${BASH_VERSION-}" ]; then echo bash; fi` | `bash` | bash sets `BASH_VERSION` itself when it starts; the generated Perl's environment has no `BASH_VERSION` (the harness runs `perl -e 'do $f'`, not bash). Injecting `$ENV{BASH_VERSION}` into the generated code would fabricate the shell identity of a program that isn't bash. |

Related: any script probing `$BASH_SOURCE`, `$BASH_ENV`, `$SHELLOPTS`,
`$BASHOPTS`, `$LINENO`, `$FUNCNAME`, `$BASH_ALIASES`, `$BASHPID`, `$$`
(process ID of the *shell*), `$PPID`, `$SHLVL` — all bash-internal state.

## 3. Host environment — hostname, users, PATH, filesystem

| Test | Source | bash output | why it cannot match |
|---|---|---|---|
| `064_21_complex_string_interpolation_multiple_variables.sh` | `message="Hello ${USER:-guest} from ${HOSTNAME:-localhost}"` | `Hello llm from PC` | `${HOSTNAME}` reads the host's machine name (`PC`). The generated Perl reads the same environment — but the harness runs bash and perl from the same shell, so this *should* agree… it fails because the Perl backend maps undeclared uppercase vars to `$ENV{...}`, and `HOSTNAME`/`USER` **are** in the environment — the mismatch is the value the *generator* baked in (see "why" below). | 
| `builtin-system-open3.sh`, `test_system_builtin.sh` | `hostname` etc. | host-dependent strings | host identity (`PC`) and filesystem listings vary by machine; byte-for-byte output cannot be pinned. |
| `000__07_find_path_commands.sh` | finds commands in `$PATH` | depends on PATH | `$PATH` contents differ per environment. |

> Note on `064_21`: the residual failure is a **generator bug**, not a
> fundamental one — `${USER:-guest}`/`${HOSTNAME:-localhost}` should read the
> live `$ENV{USER}`/`$ENV{HOSTNAME}` at runtime (which the perl child inherits
> from the same environment bash runs in). It is tracked separately; the
> *fundamental* host-dependence is the machine name itself (a byte-for-byte
> gate against a machine-specific string).

## 4. Terminal-device detection — `tty`

| Test | Source | bash output | why it cannot match |
|---|---|---|---|
| `tty-cmdsub.sh` | `tty` / `[ -t 0 ]` demos | `Using terminal device: /dev/pts/6` | The harness runs `bash <file>` with stdout attached to a pty in some cases, while the generated Perl runs via `perl -e 'do $f'` with piped stdout — `tty` and `-t` legitimately report different results for the two invocations. The test's own comment marks the tty cases as skipped when no terminal is available; the two processes see different terminal states. |

## 5. Non-deterministic / ordering-sensitive output

| Test | Source | bash output | why it cannot match |
|---|---|---|---|
| `test_system_builtin.sh` | `ls -A`, `find . -name "*.txt"` in a temp dir | directory listing | same files, but **ordering** of the generated Perl's `opendir`-based listing vs bash's `ls` differs (`.hidden` handling was fixed; remaining diffs are entry-order in multi-directory finds). |
| `000__07_find_path_commands.sh` | `find_path_commands` | PATH-derived | PATH-dependent set of commands. |

## What would be needed to "fix" these (and why it's rejected)

- **Fake bash's runtime**: bake `$ENV{BASH_VERSION}`, `$ENV{HOSTNAME}`, option
  flags, tty paths into the generated Perl. Rejected: constants that depend on
  the *harness's* machine would be wrong for every other machine and would
  silently mask genuine translation bugs (a changed script could still pass
  because the fake env hid a real mismatch).
- **Match the process model**: run the generated Perl the way bash is run
  (same tty, same env). Rejected: the harness intentionally runs perl
  standalone — that IS the translation product's environment.
- **Normalize these in the gate**: exempt `$-`/identity variables from
  byte-for-byte comparison. Rejected by the current harness contract
  (byte-for-byte is the conformance net); would need a deliberate
  decision to widen the gate.

## Status

None of these are regressions — every test in this list failed in the
baseline (420/532) and remains red after the 462/532 state. They are a
documented, deliberately-deferred class: *bash introspection of its own
runtime*.
