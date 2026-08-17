# shIR: the `builtin` op — one native-lowering point, all backends inherit

STATUS: OPEN — the estree worker (single core owner) implements this.
Spec + failing case below; acceptance = the corpus A1 passes
`harness/check_qx_shir.py` (exit 0) and all four backends still render
natively (no corpus regression).

## NEED

A `builtin` Call op in the A1 contract + a shared transform that rewrites
`exec("cmd", args)` → `builtin("cmd", args)` for every command in the
shared namespace contract (`harness/builtins.json`, 69 entries). The
native-lowering decision moves OUT of the renderers INTO the shIR, so the
backends become pure renderers of native A1.

## WHY

Today the A1 carries raw `exec("ls", ...)` and EACH backend re-decides
what native means — three different mechanisms for the same command:

| backend | `ls /tmp` in the A1 |
|---|---|
| estree | render-time `JS_SYNC_BUILTINS` table → `sh2.builtin("ls",...)` (a per-backend transform, estree.rs:3787) |
| rust | `__sh_run(bash -c 'ls /tmp')` — shells out |
| perl | `qx{'ls' '/tmp'}` — shells out (check_qx.pl per-backend guard) |
| c | `system(...)` — shells out |

The shared transforms that DO exist (`grep-o` → `grepMatches`, `seq-range-for`
→ `Range`) prove the mechanism: the corpus A1 passes `check_qx_shir.py`
for `grep -o` (lowered) but not for `ls`/`tr`/`grep`/pipeline-`echo`
(raw exec → backend shell-outs). Measured gap: **536/546 examples, 2738
exec-of-builtin violations** (echo 486, printf 101, rm 55, set 38, grep 33,
cd 29, exit 26, sort 24, head 23, sed 22, local 22, true 20, …).

A single shIR-level check then replaces the per-backend greps (perl's
check_qx.pl on generated perl, the rust stub-gate's bash -c blindness):
"the emitted A1 must not contain exec of a builtins.json command."

## MINIMAL-CORE-CHANGE

1. **Contract**: admit `Call { func: "builtin", args: [Str(cmd), Array(words)], purity }`
   — the deserializer (`shir_json_in.rs`) validates `cmd ∈ builtins.json`
   (or a documented ERASURE like the generics typeArgs: unknown names REFUSE).
   `builtin` joins the Call func namespace alongside `exec`, `grepMatches`,
   `param`, `split`, `capture`, `str_replace`, … (the A1's existing native
   op vocabulary — `grepMatches`/`Range` are the precedent).
2. **Transform** (transforms.rs registry, like `grep-o`): rewrite
   `exec(Str(cmd), args)` → `builtin(cmd, args)` when `cmd ∈ builtins.json`
   and the word-shaping is already done (the args are the exec's existing
   word list). Pure command substitution contexts keep their exec (the
   builtin runs inside the capture — the backend composes natively).
3. **Renderers** (per-backend, after the contract lands):
   - estree: render `builtin` → `sh2.builtin(...)` (what the render-time
     table does today — move the table to the op; delete `JS_SYNC_BUILTINS`).
   - rust: `builtin` → `__sh_builtin("cmd", args)` — the `__sh_*` runtime
     implements the ops (the machinery exists: `__sh_print_words`,
     `__sh_split_ifs`, `__sh_grepmatches`, `__sh_capture_rc`; add the
     builtin set). Raw `exec` of non-builtins keeps `bash -c`.
   - perl: `builtin` → native subs (the existing native echo/printf/cd
     renderings move from exec-dispatch to the op; the NATIVE-LOWERING.md
     ladder becomes "implement the declared ops").
   - c: `builtin` → native `_sh_*` helpers (echo → printf path already
     exists).
4. **Gate**: `harness/check_qx_shir.py` (written, in the harness) becomes
   part of the corpus gate — the A1 must be native. The per-backend
   anti-shell-out greps (check_qx.pl, the rust stub-gate's bash -c check)
   retire once the A1-level invariant holds.

## FAILING-CASE

```sh
ls /tmp
echo hi | tr a-z A-Z
x=$(grep -o z /etc/hostname)
```

Today: `debashc --shir` emits `exec("ls")`, `exec("echo")`, `exec("tr")`,
`exec("grep")` — `check_qx_shir.py` reports 4 violations; rust/perl render
bash -c / qx shell-outs; only estree decides natively (render time).

Target: the A1 carries `builtin("ls")`, `builtin("echo")`, `builtin("tr")`,
and `grepMatches` (the grep-o transform); `check_qx_shir.py` exits 0; all
four backends render native code from the native A1.

## FOLD-LIFT SPECS — the estree-only command folds that become shIR transforms

The umbrella `builtin` op covers the raw `exec`→native movement. These
further estree-only rewrites (render-time in estree.rs today, pinned by
its tests) should ALSO move into shared transforms so rust/perl inherit
them. Each: estree test | shIR target | failing case.

1. **egrep → grep -E** (`egrep_lowers_to_sync_builtin`): `exec("egrep", [PAT, FILE])`
   → `builtin("grep", ["-E", PAT, FILE])` (the estree runtime's
   `builtins.egrep = grep -E` alias). A static-foldable alias — pure
   semantics, no JS.
   Failing case: `x=$(egrep '^pattern' /dev/null)` — rust/perl shell it;
   the A1 should carry `builtin("grep", ["-E", ...])`.

2. **quiet-grep capture fold** (`quiet_grep_cmdsub_test_folds_constant`):
   a capture whose pipeline ends in `grep -q`/`grep -s` has NO observable
   stdout (the value is always "") — the enclosing value test folds to a
   constant. The A1 capture of a quiet-grep tail → constant "".
   Failing case: `[ "$(echo "$v" | grep -q p)" ]` — the test is
   constant-false; rust/perl run the pipeline per evaluation.

3. **case-cmdsub static chains** (`case_cmdsub_pattern_folds_to_static_chain`):
   a case whose pattern is a command substitution over a static command
   (uname/date/echo) folds to the static chain at compile time.
   Failing case: `case $(uname) in Linux) ...` — the discriminant is
   statically known; rust/perl should not spawn bash per match.

4. **param-default cmdsub** (`param_default_cmdsub_defaults_lower_native`):
   `x=${y:-$(echo LIT)}` — the default is a static cmdsub → the literal.
   Failing case: the default runs a bash spawn in rust/perl today.

5. **uname/pwd test-operand folds** (`uname_cmdsub_test_operand_lowers_native`):
   `[[ $(uname -r) == 5.4.* ]]` — the cmdsub operand folds to the native
   value + the glob folds to a prefix test; `[[ "$(pwd)" = ... ]]` → the
   cwd field. Depends on the `builtin` op (uname/pwd native) + the test
   fold.

Priority (by corpus gap + payoff): the umbrella builtin-lift first
(`core-requests/transforms/builtin_lift.rs` — ready to compile), then
(1) egrep, (2) quiet-grep, (3) case-cmdsub, (4) param-default, (5)
test-operands.

## VALIDATION

- `check_qx_shir.py` exit 0 over the corpus (the 2738-violation ladder
  counts down as the transform covers builtins.json, echo first — the
  largest).
- All four backend gates stay green (estree 546/546 held; rust/perl/c
  equivalence unchanged — native renderings already exist per-backend,
  they just move from exec-dispatch to the op).
- `cargo test --lib` at baseline.

## MANIFEST
prereqs: a builtins namespace table (harness/builtins.json, 69 entries —
embedded in the submodule's transforms::builtin::BUILTINS so the core
stays self-contained); the deserializer accepts func=="builtin" and
validates args[0] ∈ namespace (unknown names REFUSE — the documented
ERASURE policy); renderer entry fallbacks erase the op for non-accepting
backends.
invariant: "the emitted A1 must not contain exec of a builtins.json
command" — enforced by harness/check_qx_shir.py (structural exemptions:
Capture context — the async substitution path keeps exec; path-qualified
cmds — the external binary). Corpus-wide: 0 violations. `cargo test
--lib` green (315), perl corpus fail set unchanged, estree corpus
unchanged by construction (the rewrite happens at A1 export, not the
bash→render channel).
scope: the A1 contract carries the op for EVERY backend; the estree
backend accepts (its sync-builtin dispatch renders the op native);
perl/sh/c/go/python/java/rust/zig/js/glsl render the fallback (exec)
today — each may adopt a native arm and drop the fallback.

## OUTCOME: implemented
The `builtin` Call op + the exec-to-builtin rewrite at the A1 export
(shir_to_shir_json + raw), deserializer validation, renderer fallback
arms (9 backends) + the estree entry acceptance, the embed-path
fallback, and the check_qx_shir structural exemptions. Gates: build OK,
315/315 lib tests, check_qx_shir 0, round-trip + determinism hold.

## OFFERED-TO: estree (accepts natively), perl, sh, c, go, python,
java, rust, zig, js, glsl — the backends that shell out a builtins.json
command today get a native-lowering seam (each decides accept/reject;
rejection is safe by the self-fallback: the op renders as the exec it
came from).
