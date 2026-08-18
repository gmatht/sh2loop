# Investigation: implementing the `builtin` shIR op for each backend

Status: **investigation** (no code landed). Read-as-is: facts + a recommended
implementation strategy for the "new shIR builtins".

## 0. What "new shIR builtins" means here

The `builtin` Call op is the shared A1 native-lowering point — the answer to
"each backend re-decides what native means." It is **already implemented in the
core and at the A1 layer** (done/`shir-builtin-op-20260816.md`):

- Contract: `Call { func: "builtin", args: [Str(cmd), Array(words)], purity }`;
  the deserializer validates `cmd ∈ builtins.json` (69 entries) and REFUSES
  unknown names (`src/shir_json_in.rs`).
- Transform: `src/transforms/builtin.rs` rewrites `exec("cmd", args)` →
  `builtin(...)` at A1 export. `fallback_builtin_to_exec` (line 294) is the
  §11 "(refuse > guess) render at the backend's entry" self-fallback.
- Gate (A1 dimension): `harness/check_qx_shir.py` — "the emitted A1 must not
  contain exec of a builtins.json command" (structural exemptions: Capture
  context, path-qualified `/bin/…`, Var-sourced commands).

**The gap is entirely in the backends.** Verified empirically with the canonical
failing case:

```sh
ls /tmp
echo hi | tr a-z A-Z
x=$(grep -o z /etc/hostname)
```

- `debashc --shir` already emits `builtin("ls")`, `builtin("tr")`,
  `builtin("grep")` → `check_qx_shir.py` exits 0 (A1 is native).
- `debashc --shir-in-perl` still shells out: `system('bash','-c',
  q{'echo' 'hi' | 'tr' 'a-z' 'A-Z'})` — the perl renderer erased `builtin`
  back to `exec` and shelled out.

## 1. The acceptance matrix today

| backend | entry fallback | renders `builtin` natively? |
|---|---|---|
| estree (core, `src/shir.rs`) | no | **YES** — `sh2.builtin("cmd", args)` (sync dispatch, `is_async_call`/`try_native_*`; `JS_SYNC_BUILTINS` table for the sync/async twin bridge) |
| perl (`ir.rs`/`perl_backend.rs:151`) | yes | NO — `fallback_builtin_to_exec` → `qx{}` / `system('bash',...)` |
| go (`go_backend.rs:172`) | yes | NO — fallback → `exec_expr`/`redirRun` |
| c (`c_backend.rs:235`) | yes | NO (partial: some `exec \|\| builtin` arms already exist at 2050/2401, but the entry still erases) |
| rust (`rust_backend.rs:71`) | yes | NO — fallback → `__sh_run(bash -c …)` |
| python / java / sh / zig / js / glsl | yes | NO |

So out of 11 renderers, 10 still shell out a builtins.json command that the A1
has already declared native. **This is the work.**

## 2. The two distinct kinds of "builtin work" — pick per command

The single most important design finding: builtins do NOT all belong in the
same layer. Split them into two families and route each family to the mechanism
that matches.

### Family A — A1-level fold transforms (shared, all backends inherit)

A builtin belongs here iff its lowering is **backend-independent** and
observable purely as an A1-shape change (static alias / constant fold / static
test fold). These are implemented ONCE in the shared crate as transforms,
offered + bisected per backend gate (the v30 per-backend bisect pattern,
`bisect-transforms.pl` + `DEBASHC_TRANSFORMS`), not in any renderer.

From the manifest's fold-lift list — these are exactly the "new shIR builtins"
that are cross-backend:

1. **egrep → `builtin("grep", ["-E", PAT, FILE])`** — static alias (estree
   `builtins.egrep = grep -E`). Pure A1 rewrite.
2. **quiet-grep capture fold** — a capture whose pipeline ends in `grep -q/-s`
   has no observable stdout; the enclosing value test folds to a constant "".
3. **case-cmdsub static chains** — `case $(uname) in …` folds the
   statically-known discriminant to the static chain.
4. **param-default static cmdsub** — `${y:-$(echo LIT)}` → the literal.
5. **uname/pwd test-operand folds** — `[[ $(uname -r) == 5.4.* ]]` → native
   value + glob→prefix test.

Note the precedent: these are exactly where the shared transform mechanism
already pays off (`grep -o` → `grepMatches`, `seq-range-for` → `Range`). None of
these need per-language runtime code — every backend gets them at once, gated
per-backend by acceptance.

### Family B — per-backend runtime ops (the bulk of `builtins.json`)

A builtin belongs here iff it needs **runtime semantics** (syscall/fs, string
formatting, output, cwd, exit status): echo, printf, ls, tr, sed, grep (non-o),
head/tail, wc, sort, rm/mv/cp/cd/pwd/read/export/local/unset/declare, etc.
There is no shared way to render these — each backend needs its own native op
implementation. This is the estree pattern (`sh2.builtin`) generalized, and the
rust backends' `__sh_*` op machinery (`__sh_print_words`, `__sh_split_ifs`,
`__sh_grepmatches`, `__sh_capture_rc`) is the existing seam.

## 3. Recommended implementation for per-backend (Family B)

The current entry line
`crate::transforms::builtin::fallback_builtin_to_exec(&mut prog)` is a blunt
all-or-nothing erase. Replace it with a **per-backend allowlist + native arm**
structure, so acceptance is gradual, each arm is independently verifiable, and
the §11 accept/reject + bisect model is respected:

1. **Delete the blanket `fallback_builtin_to_exec` at entry** and instead keep
   an explicit "STILL-SHELLING-OUT" set per backend (small and shrinking).
2. Add a `"builtin" => self.builtin_call(args)` arm in the Call renderer that
   dispatches to the backend's **existing native emulations** (they already
   live at exec-dispatch today — this just moves the dispatch key from `exec`
   to `builtin`). For names not yet native, recurse into the erasure for that
   name only.
3. **Gate each adoption** with the existing fail-shir metric (end-to-end
   shell-out count) as the controller, and check_qx_shir / the backend's own
   gate for no regression. A backend may only drop the fallback for a name it
   renders without spawning bash.

Concrete per-backend starting points (from the existing native machinery, so
this is migration, not greenfield):

- **perl** (`shir_to_perl`): native echo/printf/cd/export/pwd already render at
  exec-dispatch (`ir.rs:4102+`, `emit_echo`, printf, cd, pwd). Move those to a
  `"builtin"` arm; perl is the `./fail` flagship gate, so this is the
  highest-value first adoption. Then extend toward the check_qx_shir ladder
  order (echo fitst — the largest tally).
- **go**: has native declare/echo-ish paths + `exec_expr`. Add
  `"builtin" => self.builtin_expr(args)`; keep `redirRun` only for
  not-yet-native names (`source`, `eval`, `command`, `type`).
- **c**: the `exec || builtin` arms already exist at 2050/2401 — the seam is
  mostly wired; complete the native `_sh_*` helper set and stop the entry erase
  for native names (it currently defeats those arms).
- **rust**: the highest lift (today `bash -c`). The `__sh_*` op machinery is the
  seam — implement `__sh_builtin("cmd", args)` natively per adopted name.
- **python / java / sh / zig / js**: partial emulations exist (sh already
  POSIX-natives many, e.g. `let`, `local -i`); add a `"builtin"` arm and port
  the whitelist set.
- **glsl**: a shader backend that never renders commands meaningfully — keep
  the erasure for essentially the whole set; no native arms (honest refusal).

## 4. Rules / guardrails that bind this work

- **Contract, not code coupling** (PLAN §1.2): backends stay pure renderers of
  the A1 op set; the op name set (`builtins.json` embedded as
  `transforms::builtin::BUILTINS`) is the single interface. No backend may
  re-decide native-ness at render time for a name the A1 already declared.
- **No regression blessing** (AGENTS): a backend drops the fallback for a name
  only when the end-to-end render matches bash; every new native arm is added
  as a corpus pin, never to hide a true shell-out.
- **Single-owner core + marketplace** (§11): Family A transforms live in the
  shared crate (`src/transforms/`), are OFFERED, and take effect for a backend
  only on that backend's acceptance (bisect); Family B renderer arms are the
  backend's own render-time verdicts and need no core change.
- **estree table retirement**: once the op is the canonical point (it is), the
  estree `JS_SYNC_BUILTINS` render-time table becomes redundant and should be
  deleted per the manifest — the op carries what the table did.

## 5. Suggested sequencing (effort-aware)

1. **Family A first** (highest payoff-per-effort, one impl, all backends):
   land the 5 fold transforms as shared offers + per-backend bisect. This
   closes the static/substitution builtins across every backend at once.
2. **perl adopts the op** (highest corpus value): move its existing native
   echo/printf/cd/export/pwd from exec-dispatch to a `builtin` arm; keep the
   explicit still-shelling-out set; watch `./fail` for regressions.
3. **go → c → sh → python/java/js/zig → rust → glsl**, in order of existing
   native surface. rust is last (highest lift, and its `bash -c` stub gate is
   already the documented honest gap).
4. **retire** the blanket `fallback_builtin_to_exec` per backend as its
   still-shelling-out set empties; delete estree's `JS_SYNC_BUILTINS`; promote
   check_qx_shir.py into the corpus gate (it already is the A1 invariant).
5. Update PLAN.md (status + revision) when each backend lands — per AGENTS.md.

## 7. Extension status & the typed-backend blocker (session 2)

Follow-up on "Migrate": the **Perl** backend migration is landed and committed
(submodule `bcd9864` / gitlink-bump `8449b43e`): the renderer accepts the `builtin`
op with no erasure, honors it at every exec-dispatch site, and gains a native
`echo … | tr SET1 SET2` transliteration fold (`try_native_echo_tr_pipeline`, unit
pin `echo_tr_pipeline_renders_native_transliterate`). Verified byte-identical vs
HEAD (546/546), `./fail` 299/247 unchanged, debashl lib 36 pre-existing failures
(no new).

**Extending to a typed backend (Go experiment) revealed the real blocker is in the
CORE analysis, not the renderers.** Removing the erasure globally and adding
`builtin` to Go's renderer dispatch changed Go's var typing (`var x string` →
`var x any`) because the typed backends re-run `shir.rs::analyze_var_types`
(and friends) on the now-un-erased A1, and several of those analysis helpers key
solely on `func == "exec"`:

- `string_lift_vars` → `collect_native_arith_sources` (`shir.rs` ~29519) — the
  main offender (dropped arith capture vars to `any`).
- `analyze_var_nospace` (~4220), `analyze_big_i53` (~5565/5708), `cond_bound` /
  `walk_stmt_ranges` (range analysis ~6052/6576), `collect_arith_ref_set_vars`
  (~12908) — the same exec-only pattern.

Many sites already use `matches!(func, "exec" | "builtin")` (numeric_lift_vars,
analyze_var_const, classify_builtin, analyze_string_lengths), so the normalization
is mechanical and idempotent. Fixing all exec-only analysis sites to accept
`builtin` (the op and `exec` have identical arg shape) is the **prerequisite** for
migrating go/c/python/java/rust/zig/js/sh. Without a complete audit it is NOT
byte-preserving (the Go experiment left 4 `string→any` residuals for
capture/heredoc-assigned vars), and validating each typed backend's runtime
correctness needs its native-stub harness.

The Go/shir experiment was reverted to keep the tree byte-identical (only the
verified Perl migration ships). Extending typed backends = (1) complete the core
analysis op-normalization table above, (2) re-run the per-backend byte-diff to 0,
(3) then land each backend's renderer `builtin` arms + drop its erasure.

## 8. Session-3 probe: op-normalize / run-passes-before-lift (result: correct but not byte-preserving)

Applied the suggested fixes to the typed-backend blocker and measured each:

1. **Run the passes before the lift** — already the case at export
   (`shir_to_shir_json` computes var_types/lengths/const/lifetimes/nospace BEFORE
   `transforms::builtin::transform`, so the A1 JSON carries pre-lift results).
2. **Respect those pre-lift results instead of recomputing on the lifted A1**: added
   `if prog.var_types.is_empty()` guards around the typed backends' in-process
   `analyze_var_types` recomputes (go/c/glsl/js/python/rust/zig; c also guarded its
   var_lengths/var_const recomputes). This is exactly the
   "run those passes before the builtin lift" directive.

**Measured result — NOT a no-op.** The guards changed 4-5 typed backends on
arith/`let`-heavy examples (`062_11_mixed_arithmetic`, `062_hard_to_lex`,
`092_for_arith_func`, `case-pattern-paren`): go=4, c=5, js=4, rust=4, zig=4,
while python=0, sh=0, glsl=0. Root cause: the backends' in-process
`analyze_var_types(&prog)` recompute on the erased (exec) IR produces DIFFERENT
var verdicts than the `--shir`-serialized ones for arith/`let` programs — the two
analysis invocations are not yet consistent. So neither op-normalizing every
analysis site nor honoring pre-lift results is byte-preserving for the typed
backends until that --shir vs recompute inconsistency is reconciled.

Renderer-layer divergence compounds it: Go still branches differently on the op
for `let`/heredoc/var-collection even with the dispatch arms + correct analysis
(`result = 1` → `result = "1"`, heredoc → fmt.Print + st=0, extra var decls).

**Disposition:** all typed-backend experiments (go migration, the 7 guards)
were reverted to keep every backend byte-identical; only the verified Perl
migration ships (submodule `bcd9864`, in current HEAD). The typed-backend
migration is a real, multi-layer effort (analysis-consistency first, then
renderer op-branching per backend) — not a mechanical erasure-drop.

## 9. Open question worth settling before coding

Should a backend's "still shelling-out set" live (a) as a compile-time constant
in its renderer (fast, but duplicated per backend), or (b) shared in
`transforms::builtin` as a per-backend manifest (single table, reused by
check_qx_shir for per-backend verdicts, but more plumbing)? Recommendation: **(b)**
— one shared table keyed by backend, so the gate can report "perl still shells
out {sed, sort, wc}" and the A1 invariant and the renderer use the same source
of truth. This mirrors the §11 per-backend manifest idea and avoids three
copies of the ladder (estree table, renderer code, gate).

## Evidence trail

- Probe (this session): `/tmp/builtin_probe.sh`; A1 native (check_qx_shir 0);
  perl render still emits `system('bash','-c',…)` for `echo | tr`.
- Entry fallbacks: `perl_backend.rs:151`, `go_backend.rs:172`, `c_backend.rs:235`,
  `rust_backend.rs:71`, `python_backend.rs:373`, `java_backend.rs:36`,
  `sh_backend.rs:472`, `zig_backend.rs:133`, `js_backend.rs:80`,
  `glsl_backend.rs:410`.
- estree native: `src/shir.rs` (`"builtin" =>` dispatch, `try_native_*`,
  `JS_SYNC_BUILTINS` at `estree.rs:3787` via `await_sync_fn_calls`).
- Transform + fallback: `src/transforms/builtin.rs` (`BUILTINS`, `is_builtin`,
  `fallback_builtin_to_exec:294`).
- Gates: `harness/check_qx_shir.py` (A1 invariant), `fail-shir`
  (end-to-end shell-out metric + `.shir_failures.tsv`).
- Spec: done/`shir-builtin-op-20260816.md` (incl. fold-lift specs);
  PLAN.md §11 marketplace, v30 bisect.
