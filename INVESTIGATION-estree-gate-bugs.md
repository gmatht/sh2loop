# INVESTIGATION: ESTree gate semantic bugs (070 whitelist + 5 stdout mismatches)

Diagnosis of the 6 failing ESTree gates at `545/6` (98.9%). Confirmed
PRE-EXISTING — none of the 6 tests define `contains`/`strHasPrefix`/
`strHasSuffix`, so the remaining-optimizations goal's guard relaxation
(Item 1) cannot affect them, and the pass count was `545/6` before those
commits too.

Status: ALL SIX FIXED. The estree gate is now `551/0` (100.0%); the perl
gate improved `268/283` → `269/282` (no regressions).

## Fixed: 070_gnuisms_thorough.sh — gate whitelist gap

- Symptom: `gate: FAIL: callee not in sh2.* whitelist: eachLine`
- Root cause: the transpiler lowers `while read`-over-file to
  `sh2.eachLine(...)` (`src/shir.rs:19461`, `src/transforms/cat_read.rs`).
  The runtime implements it (`harness/sh2-namespace.mjs:2684`) but the
  static allowlist in `harness/estree_gate.pl` omitted it (listed `line`,
  `walkLines`, `readLine`, `pipelineInputLines` but not `eachLine`).
- Fix: added `eachLine` to the whitelist. Verified: structural gate PASS
  and runner output byte-identical to bash (63 lines).

## Bug 1: 054_fibonacci.sh — copy-propagation folds loop-mutated vars (FIXED)

- Symptom: bash `0 1 1 2 3 5 8 13 21 34 55 89 144 233 377 610 987 1597 2584 4181`;
  estree `0 1 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18`.
- Root cause: `src/transforms/copy_propagation.rs` `count_assigns` counted
  only TOP-LEVEL assignments — it never recursed into loop/if/function
  bodies. `b` (assigned `b=1` top-level AND `b=$temp` inside the loop) was
  wrongly treated as single-def with value `"1"`, so `a=$b` folded to
  `a=1` and the loop's `b=$temp` was treated as a dead store.
- Fix: `count_assigns` now recurses into every nested statement body
  (If/For/While/DoWhile/ForInit/Function/Subshell/Background/Block/
  Select/Redirect/Case/Pipeline/Try) and expression-nested bodies
  (Arrow/Lambda/ArrayComp), plus arith subexpressions.

## Bug 2: unset-var-empty-string-test.sh — const-condition-elim misreads quoted $var (FIXED)

- Symptom: bash `unset-is-empty` + `zero-len`; estree only `unset-is-empty`
  (the second `if [ -z "$never_set2" ]` was eliminated).
- Root cause: `src/transforms/const_condition_elim.rs` `eval_test` checked
  `!w.starts_with('$')` for `-z`/`-n` operands — but the quoted word
  `"$never_set2"` starts with `"`, so `-z "$never_set2"` was evaluated as
  the literal `-z "\"$never_set2\""` (non-empty → false) and the `if` was
  pruned.
- Fix: the `$`-check is now `contains('$')` (anywhere in the operand) for
  `-z`/`-n` and the `[a op b]` numeric form.

## Bug 3: 079_heredoc_interpolation.sh — dead-store-elim drops heredoc-read var (FIXED)

- Symptom: bash `Hello world`; estree `Hello ` (missing `world`).
- Root cause: `src/transforms/dead_store_elim.rs` `census_expr` scanned
  Str nodes for `$name` refs ONLY inside Call args. The heredoc target
  (`cat << EOF` with `Hello $name` → `Str("Hello $name\n")` with
  `interpolate:true`) is a Redirect target — a bare Str — so `$name` was
  never counted as a read of `name`, and `name="world"` was DSE-dropped.
- Fix: `census_expr` now scans bare `Str` nodes via `string_read_names`.

## Bug 4: arith-array-index-expr.sh — dead-store-elim misses arith index reads (FIXED)

- Symptom: bash `40 40 50`; estree `20 40 50` (first value wrong).
- Root cause: `dead_store_elim.rs` `arith_census` for `ArithAst::Index`
  inserted the ARRAY name as a read but never walked the INDEX expression.
  `i` in `arr[i]` was judged never-read, `i=1` was DSE-dropped, and the
  index rendered as the empty-string never-written read → `arr[0]`.
- Fix: `arith_census` now walks the index `key` expression.

## Bug 5: 064_07_complex_array_operations.sh — `${map[@]}` read the keys (FIXED)

- Symptom: bash `Config: 8080 admin localhost`; estree `Config: host port user`
  (the assoc KEYS instead of VALUES).
- Root cause: the runtime's `arrayItems` returns KEYS for assoc arrays
  (designed for `${!map[@]}`), but the transpiler lowered `${map[@]}`
  (VALUES) to `arrayItems` too — and the runtime's `param("slice", name,
  "@")` branch also called `arrayItems`.
- Fix: added a runtime `arrayValues` method (VALUES for both array kinds);
  the transpiler's `${arr[@]}` swaps (`src/shir.rs` whole-array + slice
  forms) and the runtime's param slice `@` branch now use `arrayValues`;
  `lower_native_arrays` (`src/estree.rs`) classifies/rewrites `arrayValues`
  reads like `arrayItems`; `arrayValues` added to the gate whitelist.
