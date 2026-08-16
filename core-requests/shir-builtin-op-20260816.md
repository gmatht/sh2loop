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

## VALIDATION

- `check_qx_shir.py` exit 0 over the corpus (the 2738-violation ladder
  counts down as the transform covers builtins.json, echo first — the
  largest).
- All four backend gates stay green (estree 546/546 held; rust/perl/c
  equivalence unchanged — native renderings already exist per-backend,
  they just move from exec-dispatch to the op).
- `cargo test --lib` at baseline.
