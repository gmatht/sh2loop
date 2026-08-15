# estree: shared A1-level optimizer — single-def (SSA-style) const/copy propagation + dead-store elimination

## NEED

A shared **program-level** optimization pass in debashl — `shir_passes::const_prop(&mut IrProgram) -> bool` — that runs on the neutral A1 **before any backend renders**, so all nine renderers (estree, c, go, perl, python, rust, sh, zig, glsl) emit code without the literal variable copies, constant re-assignments, and never-read intermediates they emit today.

The shIR **already computes the metadata this pass needs** — `analyze_var_const` (src/shir.rs:4087, `IrProgram.var_const`: `Const` = exactly one static assignment site, not in a loop/function body, no runtime-store/arith/index/eval writes) and `analyze_var_ranges` / `var_lifetimes`. No backend consumes them. The pass is a consumer, not new analysis.

## WHY

Renderers are literal statement→code translators with zero value analysis. The GLSL backend's own output for `examples/mimecroft-frag.sh` shows the shape every backend has:

    g_frag_x = int(gl_FragCoord.x);     // input bridge (renderer-seeded)
    ...
    g_fx = g_frag_x;                    // ← copy, never re-assigned (var_const: Const)
    g_fy = g_frag_y;                    // ← copy
    g_hash = ((g_fx) * (7)) + ((g_fy) * (13));
    g_corrupt = ((g_hash) - ((97)) * ((g_hash) / (97)));   // ← hash is a dead intermediate
    ...
    g_r = (255);                        // ← const, single-def in its branch

Five copy lines, a dead `hash` intermediate, and constant assignments survive into the emitted code because no shared pass folds them. Each of the nine backends re-implementing ad-hoc folding is the wrong shape — one A1 pass fixes all of them, and it also cleans the ESTree corpus (MIMEcroft's per-frame render loop is full of `x=$((…))` chains feeding single-use vars).

The pass composes with the backend-local work already done for GLSL (dead runtime DCE + scalar promotion): the A1 pass kills the copies/consts at the source, the backend handles the rest.

## MINIMAL-CORE-CHANGE

### 1. The pass — `shir_passes::const_prop(&mut IrProgram) -> bool` (returns whether it changed anything; keep it idempotent)

Modeled on the `analyze_var_const` verdict machinery (reuse it: `Const` vars are the only candidates). Walk the whole program (top-level stmts + `IrStmt::Function` bodies). Per candidate var, in two phases:

**Phase A — collect.** For every `Const` var, find its single def site and every read site. Def forms that qualify:
- `IrStmt::Assign { targets: [t], expr }` with `t.indices.is_empty()` and `t.sigil` none;
- `IrStmt::Declare { vars: [name], init: Some(expr) }`;
- `setVar("name", expr)` Expr calls with a literal name.
Reads: `IrExpr::Var`, `IrExpr::Ident`, `getVar("name")` (literal name), bare names inside `arith(...)`/`test(...)` strings (the same name parsing `collect_test_vars` uses).

**Phase B — rewrite, with these HONESTY rules (each is a corpus-regression trap):**

1. **Dominance/order.** Only fold when the def textually precedes every read in the same straight-line block with **no intervening conditional (`If`/`Case`/`While`/`For`/`DoWhile`), function boundary, `&&`/`||` chain, or command substitution** between them. Anything else → leave the var alone. (bash read-before-write is the empty string; a read inside `$(...)` or a branch may execute before the def or not at all.)
2. **Copy propagation.** Def value is a **bare** `IrExpr::Var(y)`/`IrExpr::Ident(y)` (no `${y:-def}`, no quoting, no interpolation): replace every qualifying read of `x` with the same read of `y`, drop the def. `y` does NOT need to be Const — but if `y` is itself Const and gets folded, re-fold the alias chain to a fixpoint (iterate to a fixed point; the pass is idempotent).
3. **Constant propagation.** Def value is `IrExpr::Int(n)`, or `IrExpr::Str(s)` where `s` parses as an integer (and the read site is a **numeric** context — `arith`, numeric test operand, `IrExpr::Arith` — never substitute a numeric literal into a string context where quoting matters). Replace qualifying reads with the literal; drop the def.
4. **Dead-store elimination.** A `Const` var with zero qualifying reads (and zero NON-qualifying reads — i.e. no reads at all anywhere) → drop the def statement. If a non-qualifying read exists (branch/order violation), keep everything.
5. **Never touch:** any var with an indexed write (`arr[i]=v`), any `arith` compound write (`x+=1`, `x++`, `((x=…))` — the `arith_written` set), runtime stores (`read`/`readarray`/`mapfile`/`unset`), `eval`/`source`/`.` anywhere in the program (poisons everything, like `analyze_var_const`'s `dynamic` flag), `export`/`readonly` vars, vars read via `${x:-default}` or any non-bare expansion, and vars whose def involves word-splitting (the def expr must be a single bare value). Arrays are entirely out of scope.

### 2. Wiring — call it at the A1-ingress points, right after the existing `strip_cfor`, so every render path gets it:

- `sh2perl/src/wasi_api.rs:248` and `:277` (the debashcl C-ABI render paths);
- `sh2perl/src/shir.rs:11725` (the `shir_to_estree_json` path — the estree corpus exercises this);
- `otranspilerl/src/lib.rs` `render()` (next to `restructure_goto_only` + `strip_cfor` — the unified all-backend pipeline).

(Do NOT route through the `core-requests/transforms` channel — `fn(&mut Vec<IrStmt>)` lacks the program metadata and the ingress timing; this is a `shir_passes` pass.)

### 3. Tests + gate

Add unit tests in `shir_passes` for: copy fold + alias-chain fixpoint, const fold in numeric context only, read-before-write refusal, branch-intervening refusal, dead-store drop, `arr[i]=` refusal, eval-poisoning refusal, idempotence (second run returns false). Gate: `./fail-estree` must stay at the trusted baseline. Target repro: `sh2glsl` on the frag shader below should no longer emit `g_fx = g_frag_x;` / `g_fy = g_frag_y;` and should fold the `hash` chain.

## RELATED REQUESTS (composition, not conflict)

This batch already carries three narrower requests that this one **generalizes or composes with** — implement this one first, then re-check theirs against it:

- `estree-20260813-182434-const-fold-arith.md` — folds arith over the const pool (MAP_W, CELLS, …). Those pool vars ARE single-def-with-literal-defs, so this request's rule 3 covers them; their extra `$(( ))`-elision half is a renderer-emission concern, unaffected.
- `estree-20260813-182435-dce-dead-vars.md` — dead-store elimination for never-read vars (estree store syncs). This request's rule 4 covers the single-def never-read case at the A1; theirs handles multi-def / lifetime-based cases + the estree `sh2.setVar` slot cleanup.
- `estree-20260813-182437-typed-lowering-var-types.md` — orthogonal (typed lowering); no interaction.

## FAILING-CASE

Source (the essence of `examples/mimecroft-frag.sh`):

    fx=$((frag_x))
    fy=$((frag_y))
    r=$((vcolor_r))
    scan=$((fy % 6))
    if [ "$scan" -eq 0 ]; then
      hash=$((fx * 7 + fy * 13))
      corrupt=$((hash % 97))
      if [ "$corrupt" -eq 0 ]; then r=255; fi
    fi
    putb $r

Current GLSL emission (verbatim shape):

    g_fx = g_frag_x;
    g_fy = g_frag_y;
    g_r = g_vcolor_r;
    g_scan = ((g_fy) - (((6)) * ((g_fy) / ((6)))));
    if ((g_scan == (0))) {
        g_hash = ((((g_fx) * ((7)))) + (((g_fy) * ((13)))));
        g_corrupt = ((g_hash) - (((97)) * ((g_hash) / ((97)))));
        if ((g_corrupt == (0))) {
            g_r = (255);
        }
    }
    out_buf[0] = g_r;

After the pass, the estree/glsl renderers should never see `fx`/`fy` (folded into `frag_x`/`frag_y`), `hash` (folded into `corrupt`, then dead-store-dropped), or the branch-local `r = 255` const re-assignment where provably safe. The estree corpus analog: MIMEcroft's `x=$((a + b)); y=$((x * 2))` chains in the per-frame render loop.
