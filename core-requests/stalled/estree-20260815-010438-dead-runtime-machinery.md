# estree: dead runtime-machinery elimination for hot scripts (native-array `$var` indexes, arithEval wrapper, test-chain status deadness)

Performance transforms for the ESTree backend's generated code — the
mimecroft.sh hot frame loop (`while [ "$quit" -eq 0 ] && [ "$hp" -gt 0 ]
&& [ "$license" -gt 0 ] && [ "$treasures_left" -gt 0 ]; do … done`)
currently emits ~1.7k `sh2._g` + ~1.3k `sh2.lastExit` writes, 99
`sh2.arithEval` callbacks, and per-frame `sh2.arrayIndex` dispatches for
constant arrays. Each transform below removes a piece of dead runtime
machinery that the analysis can prove unobservable.

## NEED

Four independent core changes (all gate-safe; each verified against the
ESTree corpus + `__mime-test` + `__shell-regression` in a working tree):

### 1. Native-array lowering: accept `$var` indexes (src/estree.rs)

`lowerNativeArrays` (estree.rs ~1619) folds `sh2.setArray("arr", […])`
into `let arr = […]` + native reads ONLY for literal non-negative
integer indexes; a computed `$name` index (`DIR_X[$yaw]` — the game's
direction tables, read every frame) marks the array `index_bad` → the
reads stay `sh2.arrayIndex("DIR_X", "$yaw")` dispatches.

MINIMAL-CORE-CHANGE:
- `array_read_index` (estree.rs ~1999): for a string index matching
  `parse_dollar_var` (`$yaw` → `yaw`), return a new `NativeIdx::Var(name)`
  instead of None.
- `native_element_read`: the Var arm emits `String(<name>[Number(sh2.vars.<var> ?? "")] ?? "")` — the runtime's `arrayIndex` `$var`-expansion is byte-equivalent (`String(v[Number(expand("$var"))] ?? "")`), minus the dispatch + operand-expansion machinery.
- the collection phase (`arrayIndex` arm ~1400): a `$var` string index is a read (push `read_stmt_idxs`), NOT `index_bad` (same for the `getVar("arr[$i]")` form via `parse_var_arg_str`).

### 2. Native-array lowering: allow reads inside script functions (src/estree.rs)

The decision filter bans `!a.in_fn` — any read inside a script-function
arrow disqualifies the whole array. The game's `DIR_X`/`DIR_Z` are read
in `shoot()` as well as the frame loop, so the tables never go native.

MINIMAL-CORE-CHANGE: drop the `!a.in_fn` filter. It is redundant for
safety: the order guard (`read_stmt_idxs` all after the setArray — a
`let __fn_` is in the TDZ until its declaration, so a function defined
after the `let` init cannot run before it) and the `declared` guard (any
bare identifier use of the name anywhere — including a function local
declarator that would shadow the native binding — already disqualifies).

### 3. arithEval dead-wrapper elimination (src/shir.rs)

`arith_has_div_mod` (~shir.rs 12171) counts ANY `/` or `%` in an
arithmetic AST, so the whole expression stays wrapped in
`sh2.arithEval(() => …)` even when every divisor is a provably-nonzero
numeric literal (which cannot abort). The game's `seed = seed * 48271 %
2147483647` is one such dead wrapper (99 `arithEval`s across the game).

MINIMAL-CORE-CHANGE: in `arith_has_div_mod`'s Bin arm, count a div/mod
only when `!arith_is_nonzero(rhs)` — the per-operator native path
(`arith_to_estree`'s Bin arm) already emits plain native JS for a
nonzero-constant divisor, so the wrapper is dead weight. The wrapper
stays for a variable divisor (`% rd_m` — could be 0, must abort).

### 4. Test-condition status deadness for `&&`/`||` chains (src/shir.rs)

`compute_test_cond_deadness` (~shir.rs 915) marks an if/while condition
dead (drops the `(sh2._g = t, sh2.lastExit = …, sh2._g)` status seq)
only for a SINGLE `test` Call; a `&&`/`||` chain of tests (the game's
frame-loop guard) keeps the statused form — `native_and_or` emits
`(l, lastExit === 0 ? (r, …) : false)` per operand.

MINIMAL-CORE-CHANGE:
- `is_pure_test_chain`: an And/Or/Not tree whose leaves are all `test`
  calls (a test's VALUE equals its exit status, so a native JS `&&`/`||`
  matches bash).
- `compute_test_cond_deadness`: use `is_pure_test_chain` for the If/While
  condition checks.
- `native_and_or_unstatused`: the plain `Expr::LogicalExpression`
  `&&`/`||`; the And/Or BinOp emission uses it when
  `TEST_UNSTATUSED_DEPTH > 0` (the dead-condition context).
- the `test` emission: inside `&&`/`||` AND `TEST_UNSTATUSED_DEPTH > 0`,
  use `try_native_test_unstatused` (not the statused form).
- `test_cond_write_is_dead`: recompose STRUCTURALLY for pure test-chains
  (authoritative over the pointer-keyed cache — the transform
  machinery's ast_to_ir hook can overwrite the statics with a different
  program's analysis, leaving a stale LIVE verdict; end_live=true is the
  conservative choice — a writer-free arm/body keeps the cond statused,
  a trailing lastExit writer makes the backward scan false regardless).
- the ASYNC `whileLoop` fallback (the game's main loop is async — device
  reads): the cond arrow must pre-lower the cond with the dead treatment
  as an expression arrow (`r#async: true`, `ArrowBody::Expr`), not the
  statement-form arrow which skips it.

## WHY

The mimecroft.sh hot loop is the browser demo's frame path. The
transforms reduce the generated code's runtime machinery: `sh2._g` refs
~1748 → ~1364, `sh2.lastExit` ~1348 → ~1173, `sh2.arithEval` 99 → 44,
and the frame-loop guard becomes a plain
`while (quit === 0 && hp > 0 && license > 0 && treasures_left > 0)`
with zero per-test `_g`/`lastExit` writes. The keepVariables REPL/script
split (whole scripts pass `{ repl: false }` — the wasm's native arrays
stay native) is a browser-side companion (src/estree.js
`keepVariables(program, knownArrays, { repl })` + the runShellScript /
bashToJS callers) and is NOT part of this core request.

## FAILING-CASE

```sh
# the mimecroft frame-loop guard — currently lowers to the nested
# (sh2._g = quit === 0, sh2.lastExit = …, sh2._g), lastExit === 0 ?
# (… hp > 0 …) : false chain
quit=0; hp=1; license=1; treasures_left=1
while [ "$quit" -eq 0 ] && [ "$hp" -gt 0 ] && [ "$license" -gt 0 ] && [ "$treasures_left" -gt 0 ]; do
  sleep 0.05
done
```

After transforms 1-2: `DIR_X=(0 1 0 -1); yaw=2; fx=${DIR_X[$yaw]}`
lowers to `let DIR_X = ["0","1","0","-1"]` + a native
`String(DIR_X[Number(sh2.vars.yaw ?? "")] ?? "")` read (no
`sh2.arrayIndex`). After 4: the while guard is
`while (quit === 0 && hp > 0 && license > 0 && treasures_left > 0)`.

## EVIDENCE

- `fail-estree` baseline unchanged (the transforms are pure dead-code
  removal; the corpus gate stayed green in the working tree).
- `__mime-test.mjs` + `__shell-regression.mjs` (sh2runtime) both PASS
  with the transforms applied.
- The game's own per-frame breakdown: `other` 5ms/f (was inflated to
  76ms/f under the async probe stub — the real loop machinery is the
  `_g`/`lastExit`/`arithEval`/`arrayIndex` churn this request removes).

## OUTCOME: implemented
All four transforms landed and are gate-green:
1. native-array `$var` indexes — `NativeIdx::Var` in `array_read_index` + `native_element_read` (estree.rs ~2104-2118, commit b5ae282);
2. the `!a.in_fn` filter dropped (estree.rs ~1740, with the safety rationale inlined: TDZ-order + `declared` shadow guard);
3. `arith_has_div_mod` counts a div/mod only when `!arith_is_nonzero(rhs)` (shir.rs ~12466, commit 86f24fc);
4. test-chain status deadness — `is_pure_test_chain` + `TEST_UNSTATUSED_DEPTH` + `native_and_or_unstatused` (shir.rs 343/928, commit b5ae282), incl. the async `whileLoop` expr-arrow pre-lower.
estree 546/546 at baseline. The browser-side `keepVariables({ repl: false })` split remains sh2runtime/estree-worker scope (explicitly excluded by the request).
