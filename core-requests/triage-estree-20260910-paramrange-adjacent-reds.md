# Triage 2026-09-10 — pre-existing reds adjacent to the param-range work

Scope: the interprocedural param-range pass (`strip_proven_nonzero_guard`,
`sh2perl/src/shir.rs`, wired into `shir_to_estree` after the param-read
hoist). The pass itself is green: 7 new unit tests pass; py 90/90, pl
68/68, go 118/118 stdout gates pass; t86 output with the dropped `|| 0`
is byte-exact vs python3; `--library` keeps the guard (verified).

The reds below are NOT from this pass (verified by file/function
isolation — the pass only adds `shir.rs` hoist-section code plus one
pipeline call; none of the failing tests reach it). Filed, not blessed.
Owners as noted.

## 1. `estree::` unit tests: 6 failures (pre-existing)

- `estree::last_exit_hoist_tests::{sqrt1337_lifts_from_if_branches_then_loop,loop_hoist_vetoed_for_empty_range,top_level_if_common_tail_lifted}`
- `estree::migrated_passes_tests::{dead_flags_dropped_except_program_last,dead_flags_unwrap_one_element_sequences}`
- `estree::tests::assignment_lowers_to_setvar`

All exercise `src/estree.rs` lowering directly (`to_json` helpers /
`hoist_last_exit` / migrated passes). `estree.rs` is untouched by the
param-range work (`git diff --name-only` here shows only `shir.rs` plus
the dirty `backends/c` pointer). Recent `estree.rs` commits are the
native-array-twin work (`504b8d49`, `5ff4e084`) — the lowered shapes
changed under these tests' expectations. Owner: whoever owns the
estree lowering / lastExit-tail hoist. Do not weaken the tests; update
the lowering or the expectations, then confirm green.

## 2. sh gate: `t01_echo.sh` frontend-vs-core shir DIFF (pre-existing)

`frontends/posix-sh-go make test` fails at the first file comparing
`./posix-sh-go --shir` output against the core
`--source-lang sh --target shir` output. This is a frontend/core
contract gap (the known `t03_pipeline.sh` shir-pipeline-native×DCE red
family), entirely before the ESTree backend. Owner: sh frontend worker
/ core pipeline. The param-range pass never sees shir emission.

## 3. t86 array migration refuses: `append_not_inert` (store-only owner)

With current HEAD, `array_analyze_decide(factors)` refuses t86 with
`str=4 exp=4 isolated=true` but `append_not_inert`. Root cause, traced
through `array_decide`:

- append `[i]` needs `counters[i]`, but the module-top prologue now
  emits `let …, i = null` (`i` is module-bound, so the top-level `null`
  write is visible and `null` is not a Num/inert-Str write →
  `saw && ok` is false).
- independently, the param-read hoist now runs before migration and
  introduces `const __p1n`, a new name inside append elements that the
  counter proof does not recognize (harmless today only because
  `Math.*` call elements take the `pure_result` early-true path).

So the C worker's prologue/naming changes moved t86 out from under the
migration's proof. This is the store-only-native owner's call (their
feature, their invariants): either teach the counter scan that a
`null`-initialized module prologue declarator is declaration noise
(flow shows `i = 1` dominates the appends), or migrate before the
prologue/hoist names exist. Left untouched here per toolkit/ownership
policy — the param-range pass is independent of it (verified: the
`|| 0` drop is byte-exact with or without array migration).

## 4. `--library` exports nothing for plain-named functions — FIXED here

`apply_library` (`otranspilerl/src/lib.rs`) only exports `__fn_`-prefixed
defines (`n.starts_with("__fn_")`), but `is_plain_fn_name_safe` now binds
clean names directly (`const all_factors = (p1) => …`, kept as a
VariableDeclaration yet never added to the export list;
`FunctionDeclaration` nodes are kept but likewise never exported).
`t86.lib.mjs` imports as `{}`. The `SH2_LIBRARY` guard itself works
(library output keeps `Number(p1) || 0` — verified), and the `--help` /
`apply_library` docs were corrected to promise guards-kept instead of
call-site specialization. Fixed here by detecting defines by SHAPE
instead of prefix (`FunctionDeclaration` with Identifier id, any
declarator with Identifier id + arrow/function init, `N = arrow/fn`
assignments; driver calls/prints/value-rebinds still drop) with legacy
`__fn_x` behavior preserved (exports stripped). 4 new unit tests
(`library_exports_*`, `library_driver_only_has_no_export`); live
`t86.lib.mjs` imports `{ all_factors }` and returns correct factors with
the `|| 0` guard kept (library mode). The shape-based detector covers all
four emission shapes deliberately, since the in-flight param-lift renames
keep shifting the exact shape.

## 5. `otranspilerl` unit: `embed_english_and_backtick_flags` (perl owner)

Asserts `--embed-perl --english` preserves English.pm names
(`$INPUT_RECORD_SEPARATOR`/`$OS_ERROR`); currently emits `$CHILD_ERROR`.
Pure perl-fragment path, untouched by the `--library`/ESTree work (the
lib.rs diff here is help text, the `SH2_LIBRARY` guard, `apply_library`,
and its tests — none reach the embed path). Pre-existing; owned by the
perl embed worker.

## 6. C `factors_len` undeclared (duplicate empty `else if`) — FIXED here

t86 `-O3 --target c` stopped compiling: the body used growable-vec
form (`_sh_grow_str(&factors, &factors_cap)`, `factors[factors_len]`)
with no declaration anywhere. Root cause: a botched branch duplication
in the file-scope array-decl chain — `else if vec_local` appeared twice
with an EMPTY `else if vec_arrays {}` between them, and the empty arm
shadowed the real vec emitter below (first match wins), silently
dropping every growable string-vec declaration. Removed the two dead
duplicate arms (10-line deletion, no behavior change for any other
branch). t86 C compiles clean again; at runtime it now reaches
`TODO sh2.isqrt` (was: `TODO sh2.sortedJoinMerge`) — the remaining stubs
are the C worker's native-lowering backlog, not this bug.
