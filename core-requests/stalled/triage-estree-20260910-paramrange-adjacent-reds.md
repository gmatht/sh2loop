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

## OUTCOME: progress — triaged all six items against current HEAD; two are now false, one is real but blocked, three are out of core scope. (1) estree:: unit tests: 3 of the 6 named tests no longer exist (last_exit_hoist_tests / migrated_passes_tests suites are gone); the 3 that DO exist (assignment_lowers_to_setvar, direct_call_bridges_getvar_positional_reads, direct_call_bridges_param_positional_reads) fail against the uncommitted shared-core WIP described in rust-20260930-031500, not against a committed regression. (2) The sh frontend A1 DIFF is the sh frontend worker's, never reaches shir emission. (3) t86 array-migration refusal is the store-only-native owner's prologue/naming invariants. (4) --library shape-based export detector is already FIXED and landed in otranspilerl/src/lib.rs. (5) embed_english_and_backtick_flags is the perl embed worker's. (6) C factors_len duplicate-arm fix is already FIXED and landed. Remaining core work: re-run the 3 estree:: tests once the positional-bridge WIP is committed.

## OUTCOME: progress — item (1), the only piece that is shared-core, is now resolvable:
the blocking WIP has LANDED. `rust-20260930-031500`'s named-params fix committed as
sh2perl `22083e1c4`, and `./fail-estree` is at the trusted baseline (554/555, the 1 is the
pre-existing `064_hard_to_generate.sh`). Re-measured the 3 estree:: unit tests this round:
`direct_call_bridges_getvar_positional_reads` and `direct_call_bridges_param_positional_reads`
STILL FAIL, and `assignment_lowers_to_setvar` still fails. But they are not blocked on the
WIP any more — they now fail against committed code with a clean attribution: all 16
remaining `cargo test --lib` failures sit in `c_backend::tests`, `estree::tests`, `ir::tests`,
`perl_generator_fixed::pgf_tests`, `rust_backend::tests` and one `shir::range_analysis_tests`
(perl-output assertion) — every one of them a file another worker is actively editing, and I
proved the shir one is not mine by reverting my own diff and watching it fail identically.
Zero failures in the suites I own.

REMAINING: re-run the 3 estree:: tests once the estree worker (pid 1655661, running this same
core prompt) commits its src/estree.rs debug/positional work, then decide whether
`direct_call_bridges_*` are genuinely broken or just stale expectations against landed code.
Items (2)-(6) in the original file need no core action: (4) and (6) are already FIXED per
their own markers, (2)/(5) belong to the sh-frontend and perl-embed workers, (3) to the
store-only-native owner.

## OUTCOME: progress
The blocking WIP the previous two rounds named has cleared, and the whole item-(1)
re-check this round produced a clean attribution with NO core work of mine left on it.

`cargo test --lib` is now **1097 passed / 8 failed**, down from 16 failures at the last
measurement and from 14 on the branch the rust worker measured. The three estree:: tests
item (1) named resolve as follows, and I confirmed each by running it:

- `direct_call_bridges_getvar_positional_reads` and
  `direct_call_bridges_param_positional_reads` — **GREEN**. The fix landed in sh2perl
  `9f4c6b8a8` (a structural AST walk replacing the impossible `contains("sh2.positional")`
  substring probe) and was filed separately as `rust-20260930-235900.md`; that request is
  now closed implemented. These two were never a lowering defect, as that request argued.
- `assignment_lowers_to_setvar` — still red, and it is the estree lowering's, not the
  positional bridge's. It fails at src/estree.rs:7208 on
  `json3.contains("\"type\":\"AssignmentExpression\"")` for `x=$(echo hi)`: the pure-echo
  capture now folds straight to a bare literal, so there is no AssignmentExpression left
  to see. The same test's own next assertion (`json3.contains("\"value\":\"hi\"")`) is
  what actually pins the contract. This is a lowering-shape drift in a file the live
  estree worker is editing (main_loop_estree.pl, pid 2387614) — I did not touch estree.rs.

So item (1) is down to ONE test, owned by the estree worker's in-flight shape work, not
by the param-range pass and not by me. Items (2)-(6) still need no core action and are
unchanged: (4) `--library` shape-based export and (6) the C `factors_len` duplicate arm
were already FIXED by their own markers; (2) the sh-frontend A1 DIFF is the sh frontend
worker's; (5) `embed_english_and_backtick_flags` is the perl embed worker's; (3) the
t86 array-migration refusal is the store-only-native owner's prologue/naming invariants.

REMAINING for the next round: whoever owns the estree capture-lowering shape decides
whether `x=$(echo hi)` should still emit an AssignmentExpression or whether the test
should assert the folded literal directly. Nothing here blocks the corpus — estree is
557/557.

## OUTCOME: progress — the last core-owned item (item 1) is now DIAGNOSED precisely; one line remains, unlandable this round
This is the 4th pass over this file. Items (2)-(6) still need no core action and
are unchanged — do not re-derive them: (2) sh frontend worker, (3)
store-only-native owner, (4) `--library` export already FIXED, (5) perl embed
worker, (6) C `factors_len` duplicate arm already FIXED.

**Item (1) narrowed from "3 failing tests" to exactly ONE, and I found its cause
by execution this round.** The two `direct_call_bridges_*` tests are GREEN (fixed
upstream, previously filed separately). The survivor is `assignment_lowers_to_setvar`
(`src/estree.rs:7193`), and the failure is a **STALE TEST EXPECTATION, not a
lowering defect** — the opposite of what the previous round assumed ("lowering-
shape drift owned by the estree worker"):

```
$ printf 'x=$(echo hi)\n' > /tmp/echo_cap.sh
$ otranspilerl-cli -O3 --target estree /tmp/echo_cap.sh
{"type":"Program","sourceType":"module","body":[]}
```

`x` is never read, so the whole capture is dead code and is correctly eliminated
— an empty body at BOTH `-O0` and `-O3`. The test asserts
`json3.contains("\"type\":\"AssignmentExpression\"")`, which can therefore never
hold. The lowering itself is fine: give `x` a live read and every assertion in
that block passes —

```
$ printf 'x=$(echo hi)\ny=$x\necho $y\n' > /tmp/echo_cap2.sh   # → AssignmentExpression
                                                                #   right: Literal "hi"
                                                                #   no join, no setVar
```

which is exactly the contract the test's own next assertion (`"value":"hi"`) is
meant to pin.

**The fix is therefore a test edit, not a lowering edit**: assert the folded
literal on a *live* `x` (the `y=$x; echo $y` form), or drop the `json3`
`AssignmentExpression` assertion and keep `"value":"hi"` + the `!join` /
`!setVar` guards, which are the real contract.

**WHY NOT LANDED THIS ROUND — mechanical, not judgement.** `cargo test --lib`
does not compile on this tree: `cargo build` fails with 5 errors, all in
`perl_generator_fixed.rs` (an unfinished `hashes` refactor; full diagnosis filed
on perl-20261002-023041.md this round). Editing an assertion I cannot execute
would be landing an unverified test change, and this file has already spent four
rounds oscillating on this one test. I also want to be explicit about a limit: I
verified the DCE and the live-read behaviour through the **CLI**, not through
`to_json` (the unit test's own helper) — those could differ in the opt pipeline.
That is the one check the next round must run first: `to_json("x=$(echo hi)")`.

Corpus this round: **ESTREE 557/557, gate rc=0; PERL 504/557.**

## OUTCOME: progress — items (1)–(6) are now ALL resolved or attributed; the 5th pass closes the file

Do not re-derive items (2)–(6); they were re-checked and need no core action:
(2) the sh-frontend A1 DIFF is the sh frontend worker's and never reaches shir emission;
(3) the t86 array-migration refusal is the store-only-native owner's prologue/naming
invariants; (4) the `--library` shape-based export detector and (6) the C `factors_len`
duplicate arm were already FIXED per their own markers; (5) `embed_english_and_backtick_flags`
is the perl embed worker's.

**Item (1) — the `estree::` unit reds this file tracked for five rounds — is CLOSED.**
`cargo test --lib` is **1125 passed / 5 failed** this round (5 failures, not the 6 named in
§1 and not the 16 measured two rounds ago). Resolution, by re-running each named test:

- `direct_call_bridges_getvar_positional_reads` / `direct_call_bridges_param_positional_reads`
  — GREEN; fixed upstream in sh2perl `9f4c6b8a8` and filed separately. Never a lowering defect.
- `assignment_lowers_to_setvar` — GREEN; landed in sh2perl `bd610e24e`. The test asserted
  `to_json("x=$(echo hi)")` contains an `AssignmentExpression`, which can never hold because
  `x` is never READ so the write is correctly DCE'd (empty body at both -O0 and -O3). The
  test now uses the live-read form `x=$(echo hi); y=$x; echo $y`, pinning the same contract on
  a program where the write is observable.
- `last_exit_hoist_tests::*` and `migrated_passes_tests::*` — the suites no longer exist.
- The 5 survivors are all in files another worker holds: `c_backend::p1_strdup_checked_at_call_sites`
  and four `ir::` tests (`echo_tr_pipeline_`, `incdec_stmt_`, `redirect_pid_target_`,
  `redirect_var_target_`) — the last three are in the file I edited this round, so I checked
  them explicitly: they fail identically with my diff stashed, i.e. pre-existing and not mine.

The `## OUTCOME: progress` notes from rounds 1–4 each recorded that the next step was "re-run
once the blocking WIP landed". That WIP has landed and the re-run is done; §1 needs no further
core work and this file should not be re-fed for it.

**Separately, a genuine core defect fell out of the same investigation and is now LANDED**
(sh2perl `9711baeda`): `render_param` (`src/ir.rs:4266`) had no `+` and no `:+` arm, so
`${v+w}` fell through to the catch-all and rendered the VARIABLE, dropping the payload word —
`E=; echo "${E+d}"` printed `[]` where bash prints `[d]`, and because `test -n "${V+x}"` is a
setness TEST, the branch could invert outright. This is the same file family as the §1 reds
and was invisible to §1 because the corpus cell (`variable-plus-operator.sh`) passes on its
own verdict. Two unit tests added, both failing without the arms; ESTREE 557/557, PERL
506/557, `fail-shir` rc=0. Filed in full on
`core-requests/stalled/perl-generator-20261001-202305.md`, whose remaining half is one line
in the perl-generator worker's file.

## OUTCOME: rejected: closed — every item is resolved or belongs to another owner; do not re-feed this file

Sixth and final pass. I re-verified each item against current HEAD rather than trusting the
five prior notes, and this file should now be retired from the stalled queue.

- **§1 (the `estree::` unit reds) — CLOSED, verified by execution.** All three originally
  named tests pass: `assignment_lowers_to_setvar` (landed `bd610e24e`; it had asserted an
  unsatisfiable shape — `x=$(echo hi)` is DCE'd because `x` is never read, so no
  AssignmentExpression can exist), and `direct_call_bridges_{getvar,param}_positional_reads`
  (landed `9f4c6b8a8`, a structural walk replacing an impossible substring probe).
  `last_exit_hoist_tests` / `migrated_passes_tests` no longer exist as suites.
- **§2** the sh-frontend A1 DIFF is the sh frontend worker's; it never reaches shir emission.
- **§3** the t86 array-migration refusal is the store-only-native owner's prologue/naming
  invariants, not the param-range pass.
- **§4** `--library` shape-based export detection IS in `otranspilerl/src/lib.rs:1374`
  ("detected by SHAPE, not by the `__fn_` prefix"). Fixed.
- **§5** `embed_english_and_backtick_flags` — I re-ran it this round: **GREEN** (1 passed).
  No longer outstanding.
- **§6** the C `factors_len` duplicate empty `else if vec_arrays {}` arm is **gone** (0
  occurrences in `src/c_backend.rs`). Fixed.

Gates this round: estree **557/557** rc=0, `fail-shir` rc=0, PERL 512/557 (trusted 71).
