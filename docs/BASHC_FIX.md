# BASHC equivalence failures — triage and fix strategy

Date: 2026-09-12. Gate: `harness/c_gate_main.sh` → **PASS=592 FAIL=45 SKIP=7**
at triage; **PASS=625 FAIL=12 SKIP=7** after §4.11 (zero regressions;
051 flaky-slow, 062 gate-parallel flake).
Corpus: `sh2perl/examples/*.sh` + `frontends/*/testdata/*.sh` via the
**sh frontend** (bash→shIR→C). All 45 verdicts are `exec/diff`: the C
renders, compiles, runs — but stdout/exit differs from bash. No stubs
(the renderer claims full lowering everywhere — these are silent
divergences, the most dangerous kind).

Method: per-file repro (render → `cc -lgmp -lm` → run both sides, diff)
under `/tmp/bfix/<name>/`, plus C-source inspection. Three failures are
compile errors, one is a segfault, one is a hang; the rest are output deltas.

## 1. Headline counts

| Class | Files | Fix location | Fixes |
|---|---|---|---|
| Gate artifacts (exit-0 requirement, exported `tmp`, `$0`/CWD) | 6 | `harness/c_gate_main.sh` | 6 passes, zero renderer risk |
| `return`-as-`printf` in statement-called functions | 3 | `c_backend.rs` Return arm | 3 |
| Capture-id mangler passes `-` through (`_cf_--flag…`, cc error) | 3 | capture-id mangling | 3 |
| `&&`/`\|\|` chain: `_sh_rc` clobbered, dead branch runs | 2+ | and/or chain codegen | 2+ |
| If-no-else leaves condition status (POSIX: must be 0) | 2–3 | If arm epilogue | 2–3 |
| `diff`/pipeline/procsub exit status lost (`done:`/`exit:`) | 3 | status propagation | 3 |
| head+procsub lifecycle (`head -10` no-cut, infinite-producer hang) | 3–4 | procsub/head runtime | 3–4 |
| Native-builtin word splitting skipped (`printf`, …) | 1–2 | native builtin paths | 1–2 |
| Array `[*]` join / assoc composite keys | 2 | array expansion | 2 |
| Shell-out env sync (`bash -c` wrap sees empty shell vars) | 1–2 | `_sh_export`/wrap | 1–2 |
| `typeset -i/-l/-u` attributes ignored | 1 | declare/typeset | 1 |
| bc-native var-operand capture + `bc -s` exit | 2 | bc lowering | 2 |
| grep emulation / `echo -e` (`-E` alternation, `-i` status) | 2 | grep/echo native | 2 |
| `tr [:class:]` not mapped | 2 | tr native | 2 |
| Herestring feeding (`cat <<<`, `upper:`, exit) | 3 | herestring | 3 |
| Arith edges (empty operands→0, div-by-zero, quoted garbage→number) | 3 | arith eval | 3 |
| `type`/`declare -F` introspection | 1 | type builtin | 1 |
| Glob no-match (literal vs empty element) | 1 | glob expansion | 1 |
| Case empty-pattern match | 1 | case codegen | 1 |
| `realpath` exec fails 127 | 1 | external exec | 1 |
| `local`d fn freeing borrowed argv strings (SEGV) | 1 | fn epilogue ownership | 1 |
| Invalid-UTF8 byte passthrough | 1 | byte handling | 1 |
| TTY-dependent (`tty`, `script`) | 1 | — (environmental) | 0 |

(Files spanning two classes counted once: 018 is `&&`-chain *and*
grep-status; 058 is `||`-fallback *and* assoc-grid; 062 is tr-class
*and* quoted-arg-arith. Unique failing files: 45.)

## 2. The classes (evidence)

### 2.1 Gate artifacts — 6 files, fix the gate
- `t83_exit.sh`: both sides print `before`, both exit 3. Gate demands
  exit 0 → unpassable by construction.
- `echo-with-escaped-backtick[.sh,-and-quotes.sh]`: both exit 1, stdout
  identical. Same cause.
- `parse-bracket-subshell-pipe.sh`: bash cannot parse it (exit 1, empty
  stdout); C renders an empty program (exit 0, empty stdout). Stdout
  matches; exits can't.
- `parse-comment-in-brace.sh`: stdout matches, but the gate
  `export`s lowercase `tmp` (its own temp dir). bash inherits it, so
  `${tmp:-}` prints the gate dir; the C binary inits the local to NULL
  and prints empty. **Gate bug first** (rename to `_c_gate_tmp` and stop
  exporting it); exposes a real renderer gap second (C ignores inherited
  env for unassigned locals — §4.3).
- `qx-var-builtin-cd.sh`: script `cd`s to its own dirname (`$0`-based);
  C's `$0` is `./bin`. `$0`/CWD class (with 057_case's `Usage: $0` line —
  057 also exits 1, so it sits in both buckets).

### 2.2 `return` echoes to stdout — 3 files
`id-cmdsub.sh`, `readonly-cmdsub.sh` (same `capture()` helper ending in
`return ${ec}`), `051_primes.sh` (`is_prime` ending in `return 0/1`,
called as a statement). shIR is correct (`Return` node); the C arm
emits `(_sh_rc = 0, printf("%s\n", …))` — the echo-return-lift for
capture context fires unconditionally, even for statement calls, so
every call leaks `0`/`1` lines. One fix in the Return arm (statement
context must not print) clears all three.

### 2.3 Capture ids containing `--` — 3 files, won't compile
`063_09…`, `063_19…`, `063_hard_to_parse.sh`: `static _sh_vbuf
_cf_--flag1_x1926_-abc_vb` — the capture-id mangler hex-encodes UTF-8
but passes `-` through, so shell words like `--flag` become invalid C.
Mangle `-` (one function) and all three compile.

### 2.4 `&&`/`||` chains mis-evaluate — 2+ files
`018_grep_params.sh`: `grep -i … && echo OK || echo FAIL` prints **both**
OK and FAIL — the `||` arm runs despite the `&&` arm succeeding
(`_sh_rc` clobbered between links, or the chain associated wrong).
`058_advanced_bash_idioms.sh`: `$(stat … || echo "File not found")`
yields empty — the `||` fallback never fires. Same codegen area; audit
all and/or-chain shapes (`a && b || c`, chains in cmdsub, chains in
pipelines) with sibling tests per shape.

### 2.5 If-without-else status — 2–3 files
POSIX: false condition + no else → status **0**. C propagates the
condition's status: `interactive-test-minus-t.sh` (`test -t 1` false →
`exit: 1`, want `0`) and `ps-system-call.sh` (`ps -C …` miss → `done:
1`, want `0`) are confirmed instances; `064_01…` (`done:` after
`diff`, §2.6) may share it. Fix in the If epilogue (reset on the
false/no-else path); re-run the full gate — this semantic is load-bearing.

### 2.6 Exit status through diff/pipelines/procsub — 3 files
`process-substitution.sh` (`diff <(…) <(…)` → `exit: 0`, want 1),
`064_01…` (same idiom → `done: 0`, want 1). The diff/procsub
composition loses the exit code. (Distinct from §2.5: the status is
*produced* wrong, not merely propagated.)

### 2.7 head + process substitution — 3–4 files
`096_head_procsub.sh`: `head <(while true…)` **hangs** (124) — the C
side never terminates the producer (SIGPIPE lifecycle).
`064_09…`: `paste <(…) <(…) | head -10` prints 46 extra lines — `head`
doesn't truncate procsub input. `064_hard_to_generate.sh` §15 (sort |
head -5 to file) and `063_11…` (`… | head -n` feeding `while read`)
lose lines the same way. One lifecycle fix (producer teardown on
consumer exit + truncation through the procsub fd path) addresses the
hang and the data bugs together. The hang is the highest-severity item
in this report (gate timeout, not just wrong bytes).

### 2.8 Native builtins skip field splitting — 1–2 files
`t62_word_split.sh`: `printf "<%s>\n" $x` prints `<a b>` (want `<a>\n<b>`);
the `for w in $x` loop in the same file splits correctly. The native
printf path ignores the unquoted-split marker. Audit every native
builtin path for the same bypass (echo? test?).

### 2.9 Array join / assoc keys — 2 files
`064_07…`: `${config[*]}` on an assoc arrives as 3 lines (want 1
space-joined) — star-join broken. `058…` §5: `${matrix[$i,$j]}`
composite assoc keys read empty (grid prints blank) — key
encoding/lookup, possibly plus `{0..2}` brace expansion (verify which).

### 2.10 Shell-out env sync — 1–2 files
`t03_pipeline.sh`: `echo "hello $name" | tr …` printed `HELLO ` (want
`HELLO WORLD`). FIXED (79f99563): two stacked causes — (1) dead-store-elim
census lacked Pipeline/ForInit/Try arms, dropping `name="world"` as dead;
(2) const-lifted site-export read getenv (empty) instead of the C ident.
Both site-export getVar paths now prefer the const ident. The `bc-native-
capture` var-operand gap (§2.12) is the same disease via a different path
(pending).

### 2.11 typeset attributes ignored — 1 file
`typeset-cmdsub.sh`: FIXED except -n/-f (79f99563). Sticky attr map
(i/l/u/r/x) merged at every declare assign + bare decl; -i evals assigns
arithmetically (declare + plain Assign divert), -l/-u runtime-fold via
temp+loop, -x auto-exports (pending queue flushed post-command + Assign
stickiness), -F lists function names, -p prints `declare -<attrs>` in bash
order (a A i r x l u). Capacity finalizer now includes lit_index_max via
max() (bare `typeset -a arr` + indexed writes sized [1] → exit 127).
REMAINING: -n nameref (needs alias analysis), -f definition print (needs
source-text retention).

### 2.12 bc — 2 files
`bc-native-capture.sh`: static exprs fold correctly, but
`sum=$(echo "$sum + $i" | bc)` (var operands) yields empty — the native
fold covers literals only and the fallback produces nothing.
`070_cmp_basic.sh`: `bc -s` exit-status edge. Same lowering area.

### 2.13 grep / echo -e — 2 files
`019_grep_regex.sh`: `grep -E "error|warning"` output missing (pattern
with quoted `|` vs pipeline splitting? vs `-e` handling?). `018…`
also shows `-c`/`-l`/`-m` status lines diverging. Forensics needed per
flag; start with `-E` alternation and `-e` interpretation.

### 2.14 tr classes — 2 files
`062_hard_to_lex.sh` (`tr '[:lower:]' '[:upper:]'` leaves `hello`
unchanged) and `063_18…` (`tr '[:upper:]' '[:lower:]'`, empty result).
POSIX-class mapping in the native tr path.

### 2.15 Herestrings — 3 files
`070_gnuisms_thorough.sh` (`cat <<< "hello herestring"` → nothing),
`063_18…` (nested cmdsub + `${var^^}` in `<<<` → nothing),
`parse-herestring.sh` (`exit: 1`, want 0). Content feeding + resulting
status.

### 2.16 Arithmetic edges — 3 files
`parse-arithmetic-extra-paren.sh` (`$(((a+b)/(c+d)))`, all unset:
bash div-by-zero → empty; C → `0`).
`parse-dollar-in-arithmetic.sh` (empty `$1`/`$2`: C prints an extra `0`
line). `062…` (`sed` stage over `test"quote` → `4176`: quoted-arg
mangling into arith — verify mechanism). Each is small; group them as
one arith-robustness pass with oracle tests (bash error text goes to
stderr, but the *value/exit* effects are observable).

### 2.17–2.22 Singles (one fix each, no spanning)
- `parse-eval-multiline.sh`: `type fn | head -1` missing (`type`
  introspection gap).
- `000__04h…`: `files=($(ls *.sh …))` → count 1 with empty name (want
  0) — unmatched-glob semantics (literal-pattern-to-ls vs empty
  element). Decide nullglob-vs-literal once, in the glob lowering.
- `parse-redirect-in-case-pattern.sh`: empty scrutinee vs empty
  cmdsub pattern should match (`match` missing).
- `realpath-cmdsub.sh`: C's `realpath` invocation exits 127 while the
  system binary works — external-exec path bug (argv? PATH?).
- `063_15…`: **SEGV** — fn epilogue `free(x); free(y)` on `local`
  strings borrowed from argv. Ownership tracking for function locals
  (the highest-severity memory bug in the list; run the corpus under
  `--sanitize` after fixing — several latent siblings may exist).
- `utf8-non-utf8-content.sh`: raw byte `xe9` → bash passes through,
  C substitutes differently. Byte-vs-char policy decision.
- `063_04…`: one extra blank line (cmdsub inside `${var:-…}` default).
- `tty-cmdsub.sh`: needs a terminal (`tty`, `script`) — environmental;
  document as gate-env requirement, not a renderer bug.

## 3. Recommended strategy (in order)

1. **Gate fixes first (6 passes, ~an hour, zero product risk).**
   Compare exit codes instead of requiring 0 (`eq_exit == bash_rc`
   plus stdout diff); rename `tmp`→`_c_gate_tmp` and don't export it;
   invoke the binary with the script as argv0 (or normalize `$0` in
   the comparison) so `$0`/CWD tests measure the renderer, not the
   harness. Never bless: each change must turn its files green, not
   excuse them.
2. **Single-point multi-file renderer fixes (est. ~12 files, 4 fixes).**
   In order of leverage: capture-id `-` mangling (§2.3, lifts 3
   compile errors) → Return-no-print (§2.2, 3 files) → If-no-else
   status (§2.5, 2–3) → and/or-chain `_sh_rc` (§2.4, 2+). Each fix
   ships with sibling tests covering every shape of the construct
   (the policy: when a test finds broken behavior, write the related
   tests first).
3. **Subsystem passes, hungriest first:** procsub/head lifecycle incl.
   the 096 hang (§2.7) → fn-local ownership/SEGV + a `--sanitize`
   sweep (§2.17) → shell-out env sync (§2.10) → native-builtin
   splitting + array join (§§2.8–2.9) → status propagation (§2.6) →
   typeset/bc/grep/tr/herestring emulations (§§2.11–2.15) → arith
   edges (§2.16) → singles (§2.17).
4. **Process rules that hold throughout:** one root cause → write the
   sibling tests → fix → full gate (592 must not move except upward);
   `export`-namespace hygiene in the harness (this report's §2.1
   `tmp` leak is the template — audit all exported lowercase names);
   environmental tests (`tty`, locale bytes) get an explicit
   gate-env section, not silent red.

## 4. Fix log (2026-09-12 — 14 fixed, 0 regressed: 592/45/7 → 606/31/7)

### 4.1 Gate fixes (6 files, `harness/c_gate_main.sh` only)
- Exit codes compared instead of required-zero (`eq_exit == bash_rc`;
  124 still fails): `t83_exit` (3/3), `echo-with-escaped-backtick`
  ×2 (1/1) now pass. Distinct `FAIL $f cc` verdict added (was buried
  in `exec/diff`).
- `tmp` → `_c_gate_tmp`, no longer exported: `parse-comment-in-brace`
  passes (was env-pollution failure).
- Binary runs under `exec -a $script` (argv0 = script path, like
  `bash $f`): `057_case` (Usage line) and `qx-var-builtin-cd`
  (dirname-$0 cd) pass.
- CORRECTION to §2.1: `parse-bracket-subshell-pipe` does NOT pass
  under exit-compare (C exits 0, bash exits 1 — it rejects the
  syntax). Reclassified: sh-frontend strictness gap, still red.

### 4.2 Capture-id mangling (1 file + unblock)
- `src/naming.rs` `abbrev_arg_name`: verbatim arms now
  identifier-sanitize (`--flag` → `__flag`; negatives, spaces too),
  per the MEANINGFUL_NAMES contract. `063_19` passes; `063_09` and
  `063_hard_to_parse` compile (their remaining diffs are separate
  bugs below). Unit test `verbatim_args_stay_identifiers` added.

### 4.3 Operators over array elements (1 file)
- `param_call`: `${arr[i]<op>}` (op ≠ `""`/slice) now reads the
  element into a `_pe` temp and runs the scalar op machinery
  (`param_array`'s element arm dropped op — `key=${args[i]#--}` kept
  dashes, over-counting assoc keys 5-vs-4). `063_09` passes.
  Known limits: `:=`/`=` won't store back; element-slice keeps old path.
- Supporting fixes found along the way: `dollar_brace_args` now
  parses subscript+op in text (`${default[@]:0:2}` printed literally);
  `array_declared` snapshot + empty-read short-circuit for arrays
  first seen after decl emission (discovery-order hole — unset arrays
  have no storage).

### 4.4 `return` status + echo gate (3 files)
- `Return` arm: status is now the value (`_sh_rc = atoll(v)` — was
  forced 0, so `if f` was true for `return 1`: 051 listed composites).
  Echo kept (it IS the fnValue/capture value channel) but gated on a
  new `_sh_noecho` counter set by statement/condition callers in
  `exec_call` (bash `return` prints nothing; content echoes
  unaffected). `051_primes`, `id-cmdsub`, `readonly-cmdsub` pass.
- First attempt (drop echo globally) regressed 17 function-value
  tests → reverted to the gate design. Zero regressions in final.

### 4.5 If-no-else status (2 files)
- Synthesized `else { _sh_rc = 0; }` when no else exists (POSIX:
  false + no-else → 0). `interactive-test-minus-t`, `ps-system-call`
  pass. `064_01` does NOT (its `done:` is diff-exit loss, §2.6 — open).

### 4.6 `&&`/`||` operand truthiness (1 file + partial)
- Generic BinOp And/Or join now renders operands with
  `value_discarded=false`, so echo/printf operands take the truthy
  `, 1` tail (was discarded-form `, _sh_rc = 0` = always-false:
  `ok && echo || echo` printed both). `018_grep_params` passes;
  058's `File info` line fixed (grid remains — assoc subsystem).
  Only echo-family reads the flag, so pure-test operands unaffected.

### 4.7 Incidental (concurrent workers' in-flight code, kept minimal)
- `fold_atoll_consts` byte-scan panicked on non-ASCII lines
  (`line[i..]` mid-char): switched to `b[i..]` byte pattern (ASCII
  patterns can't match mid-char). Owner's logic untouched.
- Item-7b seq-range refactor left `cmp` undefined (stray `}` removed,
  one pure `let cmp` line restored). Owner's structure untouched.
- Item-13's `expr_has_call` landed complete (earlier neutralize is
  gone — owner rewrote it with the helper).

### 4.8 Shared-tree note (read this if your fix "disappears")
During this work, BASHC_OPT round 2 (human commit `7e32d451`)
landed over the uncommitted fixes and silently reverted most of §4.2–
§4.6 (Return/noecho, if-else, chain flag, param divert, brace/text
routing, array-declared guards, profiling). Survivors: naming
sanitize, owned-store strdup, procsub detector/arms. All wiped fixes
were re-applied onto the new HEAD and re-verified (608/29/7, zero
regressions) — then committed (`assistant/bashc-fixes`) so the next
overwrite is an explicit conflict, not silent loss. Lesson: commit
BASHC fixes the moment they verify; uncommitted work in `c_backend.rs`
has a half-life measured in hours.

### 4.9 Flakes and non-fixes
- `051_primes` is correctness-fixed but takes 12s serially (bc
  subprocess per candidate) vs the 15s gate timeout → flips red
  under parallel load. Needs the bc-native var path or a slow-test
  timeout, not more correctness work.
- One full-gate run showed 600/33/11 (4 extra SKIPs + 1 FAIL) from
  parallel-load flake; reruns converge to 605–606/31–32/7.
- `063_hard_to_parse` went from cc-error to 2-line diff (remaining:
  `${!prefix*[@]}` bad-substitution semantics + `tr [:class:]` —
  subsystems, §2.14/§2.17).

### 4.10 Second wave (623/14/7, zero regressions vs 618)
- t03_pipeline: dead-store-elim census lacked Pipeline/ForInit/Try
  arms (dropped `name="world"`); const-lifted site-export read getenv
  instead of the C ident. Both fixed.
- typeset-cmdsub (partial): sticky -i/-l/-u/-r/-x map; -i arith-eval,
  -l/-u runtime fold, -x auto-export (pending queue + Assign stick),
  -F names, -p `declare -attrs` (bash order aAi rxl u); capacity now
  includes lit_index_max (bare `typeset -a` + indexed writes sized
  [1] → exit 127). Left: -n nameref, -f definitions (needs source).
- 064_09/019/064_hard: pipeline stages with list operators grouped
  in `{ ...; }` (`paste && cleanup | head` parsed as `paste &&
  (cleanup|head)` — head starved).
- parse-herestring/063_18: native herestring requires a read-loop
  (bare `grep <<< str` rendered plainly, dropping `<<<`).
- realpath: `${arr[@]}` command word split per-element (was joined,
  exec'd as one filename → 127); `$'\\x00'` pattern → empty (`**`);
  `$$` is main PID (was per-child, breaking `$$` temp files).
- 063_11: procsub producer redirect flipped to write (frontend emits
  producer `< <(p)` as (fd 0, r); first r+__ps_ per temp writes).
- 062: stringly-wins demotion (Int var assigned `$(...)` → Str;
  was uint16_t truncating pointers to garbage). Numeric-text Str
  (`n="1"`) stays Int (exact `-?digits`).
- REGRESSION caught+fixed: test-string-arith-in-brackets broke when
  demote demoted `n="1"` (Str RHS); numeric-text exemption restores
  it. 062 passes standalone + single-gate but flakes red in full
  parallel gate (infra, binary verified correct).

### 4.11 Third wave (625/12/7, zero regressions)
- 058: composite assoc keys (`matrix[$i,$j]`) interpolate via
  InterpPart+value_c (was getenv("i,$j") → empty).
- parse-invalid-redirect: native `exec N>&M / N>file` (dup2/open
  in-process; child-shell `exec` loses fds). fcntl.h detection.
- parse-bracket (partial): `[[ ]]` for command-subst tests (`[ -n ]`
  true vs `[[ -n ]]` false on vanishing expansion). Exit-code still
  red — `return _sh_rc` reverted (exposes 8 latent status bugs).
- 062 (product-fixed): stringly demotion verified standalone ×3 and
  single-gate, but still red in full parallel gate (infra flake).
- Documented gaps (not fixed): expansion-failure→skip-command
  (063_04/063_hard `${!...}`, parse-arith-extra-paren div-zero,
  parse-dollar `$N` lexer quirk), eval-defined functions
  (parse-eval-multiline), dynamic case patterns calling script fns
  (parse-redirect-in-case), non-UTF8 passthrough (utf8), tty
  capture helper, typeset -n/-f, pipeline/subshell status (§2.6).

## 5. Representation policy (decided 2026-09-12)

**Stringly-until-proven-numeric.** No boxed/dynamic value type exists
and none will be built: unproven variables stay `char*` (faithful to
bash, which stores nearly everything as strings), `long long`/`mpz_t`/
narrow widths reward proof, conversions happen at use sites. A tagged
union was considered and rejected: shell strings are canonical
(`"007"` must survive), so a union either converts on every read
(same cost as today, plus a tag check) or converts-and-replaces
(lossy — corrupts values); only dual-field caching would pay, at the
cost of sync discipline across all emitted code. Reopen only on:
(1) storage-time attributes (`typeset -i/-l/-u` need assign-time
coercion), or (2) profiled atoll/snprintf round-trip heat.

## 6. Open forensics (not yet root-caused, flagged not blessed)
- 019 `-E` alternation: pattern-vs-pipeline-split vs echo-`-e` — two
  hypotheses, one experiment (`--target shir` dump of the pattern word).
- 062 `4176`: trace the quoted arg through sed-stage lowering.
- Renderer env inheritance for unset vars (§2.1 fallout): bash sees
  exported-unset vars, C inits NULL. Fixing this changes observable
  behavior corpus-wide — it needs its own A/B gate run, *after* the
  §3.1 gate fix removes the pollution that currently masks it.
- 058 grid: composite assoc key vs `{0..2}` — bisect by rendering each
  in isolation.
