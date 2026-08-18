# Shir native shell-out reduction — status & declaration-builtins TODO

`fail-shir` measures how much work the shIR renderer still **delegates to
`bash -c`**. The progress signal is now three numbers (see `fail-shir`):

```
SHIR: 306 shell-out call sites across 127 files
SHIR: 12999 shell-out body bytes, ~499 estimated forks
```

- **call sites** — number of `system('bash', '-c', …)` sites (the gate).
- **body bytes** — total length of the `bash -c` bodies (a size proxy;
  shrinking a body is progress even when the site count is unchanged).
- **est forks** — 1 + one per `|` / `&&` / `||` / `;` / `$(` token per body
  (an approximate process-fork count; a `yes | head` body ≫ an `echo hi`).

Gating (the site count) is unchanged; body-bytes/forks are additive signals.

## Lowered to native so far (verified byte-equal vs bash)

| feature | renderer site | effect |
|---|---|---|
| `grep -q PAT FILE` (test position) | `ir.rs try_native_grep_test` | read file + `index`; sound because `-q` is quiet |
| `grep -q PAT FILE && echo A \|\| echo B` | `ir.rs native_grep_chain` | native `if/else`; sound when bodies are literal echoes |
| `printf '%s\n' ARG \| grep PAT >/dev/null` | `shir.rs single_line_payload` | treats `printf %s\n` as echo-equivalent in the contains lift |
| `printf LITERAL \| sort[-nrf] \| head/tail -c N \| wc -L/-l` | `ir.rs native_literal_pipeline` | literal payload → pure in-Perl split/sort/substr/length |
| `cat <<'EOF' … EOF` | `ir.rs native_cat_heredoc` | print the heredoc body |

Cumulative: **325 → 306** sites, **14063 → 12999** body bytes, **~530 → ~499** forks.
Each change refuses (falls back to `bash -c`) whenever semantics would
change (regex patterns, `-c/-l/-m` flags, non-literal inputs, extra
redirects) — never a behavior change, only a shell-out → native win.

## TODO — declaration builtins (`declare` / `typeset` / `unset`)

The biggest remaining cluster (~47 sites: `typeset 19, unset 18, declare 10`)
and the highest-risk: these builtins carry real variable semantics, and
`unset` ≠ `undef` while `typeset` attributes change meaning.

### Why they still shell out
`shir.rs try_declare_stmt` (see the `command_to_ir` decl gate) already
converts plain `local/declare/typeset VAR=VAL` into an `IrStmt::Declare`.
But it returns `None` for the **flag forms**, which therefore fall through
to `builtin(…)` → `exec …` → `bash -c`:

```sh
declare -A map                 # -A: associative-array declaration
declare -a arr=( "item1" "item2" )
typeset -i n=42                # -i: integer-arithmetic scalar
typeset -r rovar=immutable     # -r: readonly
typeset -x myexport=value      # -x: export
typeset -n ref=original        # -n: nameref (variable alias)
unset maybe                    # not a flag form — why does it shell out?
```

### Sub-tasks
1. **`declare -A NAME` (no initializer)** → an empty assoc declaration, and
   **`declare -a NAME=( … )`** → `IrStmt::DeclareArray` with elements, so
   the perl/estree renderers emit `my %NAME;` / `my @NAME = (…);` (the
   `DeclareArray` infra already exists — `ir.rs` renders it at 2160/6962).
   The COUPLED requirement: later `name[k]=v` writes must be treated as
   assoc vs indexed consistently (the array's type must be carried to the
   setter path).
2. **`typeset -i n=<literal>`** → `Declare` with integer semantics; a
   literal RHS lowers to `$n = <int>`.
3. **`typeset -r`** → assign the value, ignore the readonly attribute
   (perl cannot enforce it; refusing is the alternative).
4. **`typeset -x NAME=val` / `declare -x` / `export`** → the existing
   `EnvExport`/export path (shir.rs 4474 already lists `export`).
5. **`typeset -n ref=original`** → nameref is the hard one; a `setVar`-to-
  -alias or refuse (do not silently mis-assign).
6. **`unset VAR`** → native unset: `undef $x` for scalars, `delete %a{k}`
   / `undef @a` for arrays, `delete $ENV{x}` for exported; and the
   `${var+x}` "is-set" reads must be consistent with the unset state.
7. Factor the flag parsing into a small shared helper in `try_declare_stmt`
   (flag string → attribute struct) used by both `ast_to_ir` and the
   renderer, so all backends agree.

### Validation (mandatory, per corpus file)
Run the **behavior gate** and require no regression on the affected files:
`009_arrays`, `029_arrays_associative`, `058_advanced_bash_idioms`,
`062_14`, `062_hard_to_lex`, `063_02`, `063_hard_to_parse`,
`064_07`, `064_20`, `064_hard_to_generate`, `070_gnuisms_thorough`,
`013_parameter_expansion`, `027_parameter_expansion_defaults`, and
`typeset-cmdsub.sh`. Also run the estree gate on the same prefix (assoc
arrays are a shared-true).

```
./fail 009   # and each file above, plus ./fail-estree 009
```

Do **not** land any declaration-builtin change without this per-file
`./fail`/`./fail-estree` hygiene — this is exactly the class where a
"native" rewrite silently changes behavior.

## Other candidates (lower value / higher effort ordered)
- `ls … | grep <pattern> | wc -l` / `ls -1 … | grep -v <pat>` (multi-stage
  fs+regex pipelines; `sort -1`/filename-list semantics matter).
- `sort FILE` / `sort -n | tail -n 5` (file-input sorts).
- `cat FILE | sort | uniq -c | sort -n -r`, `cat FILE | tr … | grep …`
  (file-input cat pipelines; needs `uniq -c` counting).
- `cmp FILE1 FILE2` (a coreutils polyfill already exists in `sh_backend.rs`).
