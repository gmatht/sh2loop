# Verus proofs of the transforms

Where the project stands on proving its shIR→shIR transforms correct with
[Verus](https://github.com/verus-lang/verus): what is proven, how much the
proofs are worth, what is not proven, and what to prove next.

The per-proof detail lives in `sh2perl/proofs/verus/README.md` (one section
per file: theorem, negative control, scope). This file is the overview: the
inventory, the rigor accounting, and the priority order. The sibling
framework is Isabelle (`sh2perl/proofs/README.md`, `proofs/ArithIdentity`,
`proofs/ForRecovery`, `sh2perl/docs/fm/`); §(c) marks Isabelle coverage so
the two are not double-counted. The tier language (Tier 1/2/3) comes from
`docs/transform-verification.md`.

Status snapshot (measured 2026-10-24; three C-generator rows added 2026-10-28):

| proof file | target | obligations | status |
|---|---|---|---|
| `proofs/verus/interval.rs` | `transforms/i32_provable.rs` (`arith_bounds`) | 5 verified, 0 errors | **RETIRED** — target never landed, see P0(iv) |
| `proofs/verus/i32_bounds_exec.rs` | same, exec-carrying full-enum form | 7 verified, 0 errors | **RETIRED** — target never landed, see P0(iv) |
| `proofs/verus/optimize_stmts.rs` | `src/ir.rs::optimize_stmts` Pass 1 | 8 verified, 0 errors | committed `84bb46cb7`, local-only |
| `proofs/verus/dead_fn_elim.rs` | `transforms/dead_fn_elim.rs` Passes 1–4 | 25 verified, 0 errors | committed `46ec35566`, local-only |
| `proofs/verus/dead_store_elim.rs` | `transforms/dead_store_elim.rs` core | 45 verified, 0 errors | committed `dbd0a5562`, local-only |
| `proofs/verus/redundant_store_elim.rs` | `transforms/redundant_store_elim.rs` (fixed) | 53 verified, 0 errors | landed, gated — see P1 |
| `proofs/verus/copy_propagation.rs` | `transforms/copy_propagation.rs` (substitution core) | 27 verified, 0 errors | local-only — see P3 |
| `proofs/verus/function_purity.rs` | `transforms/function_purity.rs` (verdict) | 41 verified, 0 errors | local-only — see P4 |
| `proofs/verus/test_lowering.rs` | `transforms/test_lowering.rs` (Tier-1 leaves) | 25 verified, 0 errors | local-only — see P5 |
| `proofs/verus/string_folds.rs` | `interp_fold` + `default_empty_fold` (string folds) | 11 verified, 0 errors | local-only — see P6 |
| `proofs/verus/arith_folds.rs` | `arith_normalize` + `bc_float_clean` (arith identities) | 11 verified, 0 errors | local-only — see P6 |
| `proofs/verus/test_folds.rs` | `test_simplification` (self-comparison table) | 7 verified, 0 errors | local-only — see P6 |
| `proofs/verus/capture_folds.rs` | `const_capture_fold` + `text_capture_fold` | 15 verified, 0 errors | local-only — see P6 |
| `proofs/verus/list_folds.rs` | `brace_fold` + `affix_strip_fold` (list/affix) | 12 verified, 0 errors | local-only — see P6 |
| `proofs/verus/textop_folds.rs` | `text_ops` pure literal arms | 15 verified, 0 errors | local-only — see P6 |
| `proofs/verus/not_folds.rs` | `not_identity` (double-negation + rust-gated flip) | 13 verified, 0 errors | local-only — see P7 |
| `proofs/verus/const_cmp_folds.rs` | `const_str_cmp_fold` (literal Eq/Ne + Not-wrapped + globMatch) | 14 verified, 0 errors | local-only — see P8 |
| `proofs/verus/array_len_fold.rs` | `transforms/array_len_fold.rs` (`fold`) | 10 verified, 0 errors | landed, gated — see P2 |
| `proofs/verus/const_status_cond.rs` | `transforms/const_status_cond.rs` (7-row table) | 35 verified, 0 errors | landed, gated — see P2 |
| `proofs/verus/elim_trio.rs` | `const_condition_elim` + `unreachable_after_exit` + `merge_init_assignments` | 22 verified, 0 errors | landed, gated — see P9 |
| `proofs/verus/slice_identity.rs` | `transforms/slice_identity.rs` (zero-offset fold) | 10 verified, 0 errors | landed, gated — see P10 |
| `proofs/verus/case_lowering.rs` | `transforms/case_lowering.rs` (dispatch) | 29 verified, 0 errors | landed, gated — see P10 |
| `proofs/verus/elseif_flatten.rs` | `transforms/else_if_flatten.rs` (chain) | 22 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/seq_range.rs` | `transforms/seq_range_for.rs` (seq words) | 11 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/ternary_desugar.rs` | `transforms/ternary_desugar.rs` (cond normalize) | 9 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/c_eqne_emit.rs` | **C generator**: `c_backend.rs` `expr()` Eq\|Ne arm (`str_cmp_valued` decision) | 11 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §14a |
| `proofs/verus/c_checked_arith.rs` | **C generator**: `c_backend.rs` checked i64 tier (`tiered_i64_expr` / `tiered_store_general` + spec arm) | 18 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §13 |
| `proofs/verus/c_dec_str.rs` | **C generator**: `_sh_ll2s` + the inline `size_t` itoa it emits | 26 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §14b |
| `proofs/verus/c_width_store.rs` | **C generator**: `Width` + `width_of_var`/`effective_widths` store condition | 20 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §15 |
| `proofs/verus/c_buf_copy.rs` | **C generator**: `buf_bound` + `emit_guarded_copy` store contract | 14 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §16 |
| `proofs/verus/c_arith_guard.rs` | **C generator**: arith `/%` guard + `num_temp`/`str_temp` + `num_spec` | 15 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §17 |
| `proofs/verus/c_int_helpers.rs` | **C generator**: `_sh_isint31` + `_sh_isqrt` + `_sh_i128_str` | 69 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §18 |
| `proofs/verus/c_op_promote.rs` | **C generator**: const-fold + LL widening + unsigned-gate premises | 15 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §19 |
| `proofs/verus/c_str_helpers.rs` | **C generator**: `_sh_*` string helpers (substr/replace/arr_slice/strip/argv/split) | 40 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §20 |
| `proofs/verus/c_capture_wrap.rs` | **C generator**: capture/wrap quoting (injection-freedom + status mapping) | 16 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §21 |

470 active obligations total (482 with the 12 retired i32 obligations), 0 errors,
every active model with checked failing mutants (see §(b).3 — 25 mutants over
23 models; the retired exec form carries its postcondition on the executable
function itself instead). The last three rows are models of the C
GENERATOR's own emission decisions, not of a shIR→shIR transform; they sit
in the same gate but are counted separately from the 470 above — +244
obligations (11/18/26/20/14/15/69/15/40/16, each with its own failing mutants or negative
controls, all re-verified under the pinned binary 2026-10-28), for 714
gated active obligations in total. Their proofs, and why Verus rather than
Isabelle fits them (the target is Rust that *produces* the C), are in
`C_UB_PROOF.md` §13–§14. The eight pre-existing counts — and
their seven mutants — were independently reproduced on 2026-10-24 with the
pinned binary (see §(b).3); the three new counts (27/41/25) and their three
mutants were checked the same day in the same session; the P9 trio count
(22) and its mutant (19v/3e) were checked 2026-10-26 in the landing session,
and the three branch counts (53/10/35) were re-verified on the landed files
the same day — no re-proof, byte-identical to the pushed branches.

Correction (2026-10-24), retired 2026-10-26 — see §(d) P0(iv): the two i32
models' target, `arith_bounds`, is absent from `src/` — and from every commit
in recorded history. The live estimator is `arith_abs_bound`/`arith_is_i32`,
proved in Isabelle (`I32Provable.thy`). The two Verus files still verify
(12 green obligations about a superseded design — re-checked after the
retirement banner, still 5/7), but their fidelity premise is void, not stale —
and the sync extractor has no target (its FATAL on the live tree was
verified live: correct behavior, wrong reason to celebrate). They are out of
the gate (`harness/verus-gate.sh` MODELS) and out of the active totals above.
All eight were run under Verus `0.2026.10.18.7d82994` with
rust toolchain `1.99.1` (`--triggers-mode silent --rlimit 40`, `--rlimit 60`
for the exec form and const-status-cond, `--rlimit 80` for redundant-store-elim). The pinned binary lives at
`/opt/verus-0.2026.10.18.7d82994/verus` (re-fetch
`release/0.2026.10.18.7d82994` x86-linux if it ever goes missing). Still no gate runs
these files — re-running one is a manual command from the README, and a
`harness/verus-gate.sh` now exists and is green (Tier 0, landed 2026-10-24):
it re-runs the eight models with exact-count assertions (exit 1 on count
mismatch or Verus error, exit 2 if the binary is absent — never read
"not installed" as green) plus an empty sync registry with a comment
explaining why nothing is registered. The remaining hardening item is pushing
the three local-only proof commits so the gate means the same thing on a
fresh clone
item (P0 in §(d)).

## (a) Which transforms have been proven correct with Verus

Strictly speaking, none — §(b) explains why "proven" needs scare quotes
here. What exists is five checked soundness **models**, one per target:

**1. `i32_provable` — `arith_bounds` interval soundness (`interval.rs`, 5).**
The obligation the renderers need: a marked node's value lies in its
computed interval, and the interval is inside i32's `[-2^31, 2^31-1]`.
Covers the constructors the analysis touches with the exact operator rules
(`+`/`-`/`*`/unary `-`/ternary hull). Carve-outs: it says nothing about the
emitted C (see `C_UB_PROOF.md`), and `i32_provable` currently has no
renderer consumer — the verdict changes no emitted byte. This is also the
proof Isabelle could *not* do: the Isabelle version of the product corner
bound stalled on unfolding `min`/`max`, while Verus's `nonlinear_arith`
discharges it once the four-corner disjunction is supplied.

**2. Same obligation, exec-carrying full-enum form (`i32_bounds_exec.rs`, 7).**
Duplicates `arith_bounds` over the real `ArithAst` shape (all ten
constructors, including `Assign`/`IncDec`/`Index`/`Other`) with the
postcondition ON the executable function — `(found, lo, hi)` triple instead
of `Option`, explicit guards instead of `?`. Two mechanical rewrites
separate it from the source (match-on-`&str` → if-chains,
`then_some` → explicit if); 30 recorded probes found the working shape
(tuple postconditions over self-built values prove nothing; `checked_*`
crosses into `as int` via vstd specs). Strongest artifact of the five, and
still a duplicate, not an annotation (see §(b).1).

**3. `optimize_stmts` Pass 1 — self-assign + unused-`Declare` elim
(`optimize_stmts.rs`, 8).** Note the target is *not* in `transforms/` but
`src/ir.rs:15768`: the `is_self_assignment` filter and the init-less
`Declare` filter with the `collect_referenced_vars` census. Theorem:
elimination preserves the final store from any closed start state (every
referenced name bound). The model pins the census subtlety empirically —
the real census counts a `Declare`'s *own* names as references, so a lone
`Declare[x]` is KEPT — and Pass 0.5 folding is out of scope (separate
constant-fold obligation).

**4. `dead_fn_elim` (`dead_fn_elim.rs`, 25).** Passes 1–4 over def/call/other
statements with interned names: a def survives iff its name occurs as a
literal anywhere. Theorem: elimination preserves the call trace (externals
included) at every fuel bound — hence for unbounded runs. Worklist dispatch
with first-def-wins lookup; the `KEEP_VARIABLES` hatch is a parameter.
Known gap, flagged not proved: the real `collect_expr_strs` skips
`InterpPart::Lit` fragments, so a function referenced *only* through a
concatenated literal is dropped by the real code but kept by the model —
the model is conservative (superset keep-set), and the proof covers every
drop the model makes.

**5. `dead_store_elim` core (`dead_store_elim.rs`, 45).** Read/write census,
purity gate, and purge over store + observable-trace semantics. Theorem:
purging dead stores preserves the event trace and every live variable's
final value from any closed start store. Induction invariant is
live-agreement plus trace equality. Deliberate reductions: the Const guard
is modelled as single-write; dynamic writes make the dead set empty
(uniform outcome, no special case); the escapes set is not modelled
(checked arm-by-arm to be redundant with reads); indexed targets,
case-pattern/`Str`-embedded/`[*]`-IFS/`Ext` reads, and nested-statement
recursion are out of scope — the model covers exactly the droppable scalar
class over flat sequences. **This proof already paid for itself:** modelling
it exposed the soundness bugs in the sibling `redundant_store_elim.rs`
that item 6's effort fixed and proved (plus a third found during that
effort).

**6. `redundant_store_elim` (`redundant_store_elim.rs`, 53).** A scalar
store `x=A` at `i` drops iff a later scalar store to `x` overwrites it
with a clean middle and a clean justifier. Theorem: purging is
observationally exact — same trace, same value for every variable.
Proof is a shadow argument (dropped-then-overwritten vars are
unobservable; chains end at kept stores). Covers the FIXED pass: three
soundness holes repaired in the same effort (arith side effects,
index reads, Str-embedded reads — each with failing-first regression
tests), and both fix-mutants go red. Out of scope, all flagged:
`Ext`-node reads (another worker's uncommitted arm at time of writing),
case-pattern text, env-dump builtins in captures, nested-statement
recursion (same scan per function body), multi-target assigns. Seven
fidelity pins, all mirrored (3 in-module bug tests, cascade + observer
+ index-read in `pin_mirrors.rs`). Branch `verus-rse`, on GitHub,
unmerged pending the `Ext`-WIP owner's rebase (overlapping `expr_reads`
hunk, both keep-direction).

**7. `array_len_fold` (`array_len_fold.rs`, 10).** The `fold()` node
rewrite with refuse-on-doubt guards. Theorem: folding preserves the
evaluated value (element count of the same array binding) from any
store. Both spellings evaluate against the same binding, so the fold
is a renaming with identical denotation; the guards only ensure the
slice spelling MEANS element count. Guard order mirrors the code.
Identifier-ness is an oracle; traversal is out of scope (per-node
theorem). Eight pins, all shape-mirrored 1:1 in-module (dead_fn_elim
precedent — no `pin_mirrors.rs` addition needed).

**8. `const_status_cond` (`const_status_cond.rs`, 35).** The 7-row
restructuring table with refusals. Theorem: rewriting preserves the
(status, print-trace) run from any start status at every fuel bound.
Execution threads the header's bash exit-status rules (body-never-ran
reports 0, taken-body reports last status, untaken-if reports 0);
(fuel, size)-lexicographic induction with two general loop lemmas
covering entry and tails uniformly. Eleven pins: all 7 rows as
shapes, words/elsifs/non-const refusals, plus a fuel-2 behavior run.
Two mutants go red (dropped prepend 31/3, wrong collapse status
33/1). `do…while` omitted (refused in code, nothing to refuse);
StatusZero is observably `([], 0)`. All shape pins mirrored 1:1
in-module (11 tests); the behavior pin is model-internal.

**9. `copy_propagation` (`copy_propagation.rs`, 27).** The substitution
core: single-def table (parameter, with a soundness precondition tying
each entry to the program's unique literal write), the def-before-read
gate, and the read-site fold. Theorem: folding preserves the run
(final store and event trace) from any closed start store. The
induction is single-store (both sides from the same store — full step
equality threads through, since pointwise store agreement cannot prove
`Map` `==`); the invariant is `prefix_ok` (every already-executed def
holds its literal value), and the two-write contradiction
(`count == 1` rules out the second writer) is the lemma that makes the
prefix survive a step. Six fidelity pins mirror the transform's own
tests (fold-after-def, refuse-before-def, multi-def count, copy-def
unfolded, opaque-statement refusal, both-reads fold). The gate-dropping
mutant goes red (25/2). Copy defs, arith/string-digit gates,
`param-const-fold`, `AffixStrip`, quoted-`Interpolate` defs: all out of
scope (the same core; the extensions reuse this gate).

**10. `function_purity` (`function_purity.rs`, 41).** The verdict
predicates and the call-graph fixpoint: purity as the meet over the
`Impure < Emulable < Pure` lattice, per-statement meets, calls as
callee-verdict meet arg-purities. Theorem: under a consistent table, a
Pure verdict means an empty event trace at every fuel and an Emulable
verdict means a capturable-only trace at every fuel. The fixpoint
iteration is not modelled; the theorem takes a consistent table as a
parameter (the real loop's limit satisfies it by construction), and
consistency has three load-bearing conjuncts (recomputation never
drops below the verdict, verdicts land in the lattice, keys are
defined names — dropping any one admits a concrete unsound table, all
found during the proof: the `v[f] = 5`-for-undefined-`f` class makes
`Call(f, [])` compute Pure yet dispatch a `RunCall`). Seven fidelity
pins mirror the verdict's behavior (pure-assign body, Output-is-Emulable,
Other-is-Impure, unknown-callee-Impure, pure-call, impure-arg taint,
pure-runs-silent). The Output-as-Pure mutant goes red (39/2). The
`inline_pure_fns` consumer is out of scope (Tier-3-flavored).

**11. `test_lowering` Tier-1 leaves (`test_lowering.rs`, 25).** The
per-leaf value preservation of the four lowering families — nonempty
(`-n`/`-z`), string equality (`==`/`=`/`!=` as `Not(Ne)`/`Ne`),
numeric comparison (six ops over i64-range ints), glob-affix
(`strHasPrefix`/`contains`/`strHasSuffix` + negations) — over
`Seq<char>` strings with var/literal operands. Theorem: each lowered
leaf evaluates to the same boolean as the source test text, from any
closed store (plus operand-level top lemmas). The full pass obligation
needs statement semantics; these leaves are the Tier-1 carve-out.
Eight fidelity pins mirror the transform's own tests. The
dropped-`Not` mutant goes red (24/1) — the perl-numeric-`==` bug the
`Not(Ne)` encoding exists to avoid. Status liveness, cond position,
nocasematch, compounds, self-recursion: all out of scope (Tier-3).

**12. P9 ELIM trio (`elim_trio.rs`, 22).** Three per-pass soundness
obligations over store + observable-trace semantics, proved 2026-10-26 and
gate-registered (`elim_trio.rs:22:40`): (a) `const_condition_elim`
pruning (constant-`If` to the taken branch, `While(false)` drop,
`DoWhile(false)` to its body) preserves the run; (b)
`unreachable_after_exit` truncation after a direct `Exit` preserves the run
(the abort flag makes the tail unobservable; nested exits never deaden the
outer list); (c) `merge_init_assignments` adjacent-pair folding under the
literal-default + pure-RHS + no-self-read gates preserves the run (the
default store is overwritten before any read observes it). Eight fidelity
pins (UNMIRRORED by design — suite-less sources); the inverted-branch
mutant goes red (19v/3e). `eval_cond` string parsing, the census gates as
parameters, and the `Exit`-producer firing gap (no shell-lowering producer
constructs `IrStmt::Exit`/`Return` today — same dead-path class as
`for_recovery`) are out of scope / flagged. Coverage sync registered
(`verus-sync-coverage.sh:elim_trio`).

**13. `slice_identity` (`slice_identity.rs`, 10).** The zero-offset fold:
`param("slice", NAME, OFF, LEN)` with a plain-identifier NAME, literal
`OFF` in `{"", "0"}` and absent/empty `LEN` folds to the plain read and
denotes the same string from any store. Eight fidelity pins mirror the
transform's own tests (three fold shapes, real-offset/length refusals
including the `"0"`-length-is-empty rule, non-identifier refusal,
no-change report); the dropped-identifier-gate mutant goes red (9v/1e)
while the value theorem holds — the pin, not the lemma, is load-bearing
(the array-len-fold offset-guard shape). Identifier-ness is an oracle;
traversal is per-node (array_len_fold precedent).

**14. `case_lowering` (`case_lowering.rs`, 29).** Per-pattern value
preservation (Exact as `Not(Ne)`, affixes as the shared primitives, Glob
via the shared-engine oracle called identically on both sides) plus the
dispatch theorem: the if/elif chain with catch-all-as-else and
dropped post-catch-all selects the same branch as the source case for
every subject. Fourteen fidelity pins mirror 13 of the transform's 16
unit tests (the dropped-tail shape is model-internal); the Prefix-lowered-
to-Suffix mutant goes red (27v/2e). Quote classification is parsing
(classified input, Refused = whole-case refusal); nocasematch is a
parameter; the impure-subject bind is identical-value substitution;
traversal is per-site. Firing: 38/563 on `--target rs` (0/563 on `--target
pl` by the `perl`-vs-`pl` gate naming — measured).

**15. `else_if_flatten` (`elseif_flatten.rs`, 22).** Collapsing
`else { if (no elsifs of its own) }` into the parent's `elsifs` —
repeatedly, so any depth lands in one vector — preserves the selected
body under every valuation. Conditions are opaque predicate ids (the
rule is structural; the source flattens through `BinOp(And)`
conditions). The chain loop is fuel-bounded (fuel = If count, strictly
dropping per firing step) with first-hit scan lemmas. Four fidelity
pins mirror the 4 unit tests; the dropped-else-body mutant goes red
(18v/4e). Status threading is out of scope (Tier-3).

**16. `seq_range_for` (`seq_range.rs`, 11).** Rewriting
`for v in $(seq …)` to bare `Range{start, end}` preserves the
iterated integer list (1-arg from 1, 2-arg as-is, descending = empty on
both sides). Eight fidelity pins mirror the 8 unit tests (two lift
shapes, descending-is-empty, step/float/leading-zero refusals,
body-write/setVar-write refusals, huge-span refusal); the accept-step-
forms mutant goes red (9v/2e). Literal parsing and the shape match are
inputs; the body-write scan is a parameter; backend Range consumption
is renderer contract.

**17. `ternary_desugar` (`ternary_desugar.rs`, 9).** Rewriting the C
frontend's `ternary(cond, a, b)` to `Ternary{cond, then, else}` with the
normalized `test`/`arith` condition — plus the standalone
`testArith(s)`-to-`arith(s)` normalization — preserves the selected
branch (the engines are shared-oracle calls, the case_lowering glob-arm
shape). Six fidelity pins record the mapping table; UNMIRRORED — the
transform has no unit suite (suite-less source, recorded). The
test-string-routed-to-arith mutant goes red (8v/1e). The `is_test_string`
split is parsing; the estree-path exemption is placement; traversal is
per-site. Ingress-only (fires on C-frontend input, 0/563 in-registry by
construction).

## (b) How rigorous this is, and how closely it matches the real code

**1. Every artifact is a hand-duplicated model, not a proof of the code.**
Verus cannot take a crate dependency on the 17k-line `sh2perl` crate, so
each file re-states the transform's logic (shrunk to a core calculus: three
statement shapes, interned names, structural purity) with the theorem on
top. Nothing in the toolchain ties the model to `src/` — the five files
and the five implementations can drift apart silently, which is exactly the
failure mode the exercise exists to catch.

**2. What ties exist are empirical or pending, not mechanical.**
Per file: *fidelity pins* — properties checked against the running code
before modelling (the `Declare`-keeps-itself census behavior, elim keep/drop
examples, six purge scenarios); see the `*_pins` lemmas. *Pending:*
`harness/verus-sync.sh` (staged, uncommitted) regenerates a marked SYNCED
region of the exec proof from `i32_provable.rs` and fails loudly when the
source outgrows its extractor patterns — but the generated
`i32_bounds_sync.rs` does not exist yet and no gate runs `--check`. Until
that lands, "the model matches the code" is a statement about the day each
file was written, reviewed by re-reading.

**3. The obligations are not vacuous — every transform model has a checked mutant (25 mutants over 23 models), plus the C-generator mutants.**
Interval with a wrong product corner: 4 verified, 1 error. `Assign` writing
a constant: 7 verified, 1 error. Inverted keep rule: 23 verified, 2 errors.
Dropped purity gate: 43 verified, 2 errors. Restored `Arith(_) => true`
purity lie: 51 verified, 2 errors. Restored index-blind `stmt_reads`:
51 verified, 2 errors. Dropped `"@"`-offset guard: 9 verified, 1 error.
Dropped command prepend: 31 verified, 3 errors. Wrong collapse status:
33 verified, 1 error. Dropped def-before-read gate: 25 verified, 2 errors.
Output-as-Pure verdict: 39 verified, 2 errors. Dropped `Not` on Eq:
24 verified, 1 error. Multi-part interpolate first-lit fold: 9 verified, 2 errors.
Dropped 0+X canonicalization: 10 verified, 1 error. `-le` folds false:
4 verified, 3 errors. `And` needs one status-0 arm: 13 verified, 2 errors.
Dropped brace prefix: 11 verified, 1 error. Flipped case direction:
14 verified, 1 error. Wrong Lt complement (Lt->Le): 11 verified, 2 errors. Inverted Eq fold:
12 verified, 2 errors. Inverted taken-branch selection (prune `if true` to else):
19 verified, 3 errors. Dropped plain-ident gate (fold any name):
9 verified, 1 error. Prefix lowered to suffix: 27 verified, 2 errors.
Dropped else-body in the splice: 18 verified, 4 errors. Accepted step form:
9 verified, 2 errors. Test-string routed to arith: 8 verified, 1 error. Flipped width order
(narrow (0,100) as I8): 19 verified, 1 error. Dropped capture denial
(bounded capture receiver as Fixed): 13 verified, 1 error.
Unsigned-reduction-on-negative (shipped -3 shape as equal):
14 verified, 1 error. Dropped >10-digit refusal (accept long text):
68 verified, 1 error. Allow-Refuse-to-fold (compile-time abort):
14 verified, 1 error. Flipped-clamp (e<b allowed): 39 verified, 1 error.
Bare-quote splice (injection hole): 13 verified, 3 errors.
C-generator mutants are
recorded per-model in `C_UB_PROOF.md` §13–§21 (unguarded commit ships
wrap, intended-UB pair is UB, four one-token decimal mutants, flipped
width order), all restored and re-checked green under the pinned
binary. Every mutant was restored and
re-checked green — and the pre-existing reproductions were
re-run independently on 2026-10-24 with the pinned binary, matching the
documented numbers exactly (4v/1e, 7v/1e, 23v/2e, 43v/2e, 51v/2e, 51v/2e, 9v/1e, 31v/3e, 33v/1e against clean
baselines of 5/8/25/45/53/53/10/35/35); the P3/P4/P5 mutants were checked
the same day against clean baselines of 27/41/25, plus the six P6 mutants
against clean baselines of 11/11/7/15/12/15 and the P7 mutant against a
clean baseline of 13 and the P8 mutant against a clean baseline of 14,
plus the P9 trio mutant against a clean baseline of 22 (checked 2026-10-26),
plus the P10/P11 mutants against clean baselines of 10/29/22/11/9 (all checked
2026-10-26: slice non-ident gate 9v/1e, case Prefix-to-Suffix 27v/2e, elseif
dropped-else 18v/4e, seq-range step-accept 9v/2e, ternary engine-swap 8v/1e),
plus sabotage-tested coverage
syncs for all ten synced models (guard renamed / pin renamed / unknown
model all FATAL loudly; executed-test sabotage names the broken fragment
via `exec <pin>: FAIL`).
Executed-test totals in the committed baselines: copy_propagation 6/6
PASS, test_lowering 9/9 PASS, string_folds 7/7 PASS, capture_folds 6/6
PASS, list_folds 6/6 PASS, textop_folds 3/3 PASS, slice_identity 8/8
PASS, case_lowering 13/13 PASS, elseif_flatten 4/4 PASS, seq_range 8/8
PASS, function_purity /
arith_folds / test_folds / elim_trio / ternary_desugar pins UNMIRRORED-by-design (analysis-only or
suite-less sources — recorded, not claimed).
The retired file (`i32_bounds_exec.rs`) has no
recorded mutant; its anti-vacuity argument is structural instead — the postcondition
constrains the executable function's actual return triple over all ten
`ArithAst` constructors, a shape 30 failed probes showed is easy to get
vacuously wrong and hard to get right. There are no `admit()`s and no
`assume(...)`s in the three new files (the single trust axiom remains
`assume_specification[i128::checked_neg]` in the retired exec-form file — a stdlib
spec, standard vstd practice).

**4. The theorems are Tier-1 shaped, and the Tier-1 boundary is load-bearing.**
Each proof states verdict-soundness or trace/store-equality over IR-shaped
data with an explicit environment contract (`closed_for`, `env_sound`-style
premises) — no shell semantics anywhere, consistent with
`docs/transform-verification.md`'s Tier 1. None of them is Tier 3
(`⟦f(p)⟧ = ⟦p⟧` over real shell meaning); per that doc, Tier 3 is out of
reach until a statement semantics exists in-tree (Smoosh offers a reference
semantics and differential oracle, not a foundation — its 96
`target_rep`s are OCaml-only, so neither the Coq nor the Isabelle backend
emits anything). The 2026-10-24 pin audit scores the living tie per model
— pins are the empirical half of fidelity, real tests are what keeps them
honest after the modelling session ends:

| model | pins | mirrored in real tests? | cargo result |
|---|---|---|---|
| `optimize_stmts` | 4 scenarios (`declare_pins`) | **no** — one-time empirical check only | — |
| `dead_fn_elim` | 3 (`elim_pins`) | **yes, exactly** (`removes_uncalled_fn_keeps_called_and_indirect`) + ForInit extra | 3 green |
| `dead_store_elim` | 6 pins | **partial** — 5 keep-side boundary tests green; lone-drop, read-later, impure-RHS, multi-write, dyn-freeze unmirrored | 5 green |
| `redundant_store_elim` | 7 pins | **yes, all** — 3 bug scenarios in-module (side-effecting arith, index read, Str-embedded `$x` + scanner units); cascade + observer + index-read in `pin_mirrors.rs` | 3 + 3 green |
| `array_len_fold` | 8 pins | **yes, all, in-module** — 4-arg, 3-arg, plain-name, numeric-offset, non-empty-length, non-ident-base, bad-arity, folded-counts (15 in-module tests incl. traversal) | 8 green |
| `const_status_cond` | 11 pins | **yes, all shapes, in-module** — all 7 rows + words/elsifs/non-const refusals (11 in-module tests); fuel-2 behavior pin is model-internal (the theorem at f=2) | 10 green |
| i32 ×2 | n/a | **RETIRED** — target absent, out of gate (P0(iv)) | n/a |
| `elim_trio` | 8 pins (cce×4 / uae×2 / mia×2) | UNMIRRORED by design — none of the three sources has per-rule unit tests (const_condition_elim tests only the `eval_cond` refusals, never the pruning) | recorded, not claimed |
| `slice_identity` | 8 pins (3 folds / 4 refusals / runtime) | **yes, all** — each pin mirrors a named `slice_identity.rs` test (zero_offset…, empty_offset…, length_absent…, real_offset/length, array_and_positional, transform_reports_false) | 8/8 PASS in committed sync baseline |
| `case_lowering` | 14 pins (dispatch + bind + refusal shapes) | **yes, all-but-one** — 13 pins mirror named `case_lowering.rs` tests; post-catch-all-dropped is model-internal | 13/13 mapped PASS in committed sync baseline |
| `elseif_flatten` | 4 pins (flatten / chain / refusal / live value) | **yes, all** — each pin mirrors a named `else_if_flatten.rs` test | 4/4 PASS in committed sync baseline |
| `seq_range` | 8 pins (lift shapes + 5 refusals) | **yes, all** — each pin mirrors a named `seq_range_for.rs` test | 8/8 PASS in committed sync baseline |
| `ternary_desugar` | 6 pins (mapping table + branch) | UNMIRRORED by design — the transform has no unit suite | recorded, not claimed |
| `copy_propagation` | 6 pins (fold/keep/drop/opaque/multi) | **yes, all, in-module-adjacent** — each pin mirrors a named `copy_propagation.rs` test (folds_read_after_def, refuses_read_before_def, refuses_multi_def, folds_copy_rhs, refuses_background_read, folds_both_reads_in_one_stmt) | named tests green (in-module suite) |
| `function_purity` | 7 pins (body verdicts, call/arg rules, silent run) | **partial** — pins mirror verdict behavior described in prose (no per-verdict unit tests in `function_purity.rs`; the analysis is consumer-tested via `inline_pure_fns`) | n/a (analysis-only, no unit suite) |
| `test_lowering` | 8 pins (leaf shapes + negation + numeric) | **yes, all, in-module-adjacent** — each pin mirrors a named `test_lowering.rs` test (nonempty/string-eq/numeric-glob-affix families) | named tests green (in-module suite) |
| `string_folds` | 7 pins (single-lit/single-expr/multi/gates) | **yes, all** — each pin mirrors a named `interp_fold.rs` / `default_empty_fold.rs` test (single_literal…, single_expr…, multi_part…, empty_default…, array_homed…, nounset_gate…) | 7/7 PASS in committed sync baseline |
| `arith_folds` | 7 pins (three rules + refusals + bc) | UNMIRRORED by design — neither `arith_normalize.rs` nor `bc_float_clean.rs` has a unit suite | recorded, not claimed |
| `test_folds` | 4 pins (true/false ops + runtime) | UNMIRRORED by design — `test_simplification.rs` has no unit suite | recorded, not claimed |
| `capture_folds` | 6 pins (strip/join/empty/chains) | **yes, all** — each pin mirrors a named `const_capture_fold.rs` test (frontend_constant…, multi_word…, folds_true…, or_chain…, chain_status…, other_command…) | 6/6 PASS in committed sync baseline |
| `list_folds` | 6 pins (expand/splice/strip) | **yes, all** — each pin mirrors a named `brace_fold.rs` / `affix_strip_fold.rs` test | 6/6 PASS in committed sync baseline |
| `textop_folds` | 6 pins (strlen/case/substr/basename) | **partial** — strlen/case pins mirror named `text_ops.rs` tests; substr/basename pins are model-internal computations | 3/3 mapped PASS in committed sync baseline |
| `not_folds` | 8 pins (double/single/consistency/flips/runtime) | **yes, all-but-one** — 7 pins mirror named `not_identity.rs` tests (folds_double_not, single_not_is_untouched, unbalanced_inner_not_is_refused, flips_negated_comparison, flips_ordering_comparisons); outer-inconsistency is model-internal | 7/7 mapped PASS in committed sync baseline |
| `const_cmp_folds` | 9 pins (equal/ne/int/glob/style/mixed/dynamic/wrapped/globmatch) | **yes, all** — each pin mirrors a named `const_str_cmp_fold.rs` test (folds_equal_literals, folds_int_literals, refuses_glob_rhs, refuses_dynamic_and_mixed_operands, refuses_command_style, folds_globmatch_with_literal_pattern, folds_wrapped_exact_cond) | 9/9 mapped PASS in committed sync baseline |

**5. Compared with the Isabelle line, Verus is stronger per-lemma and weaker
as a gate.** Isabelle's mirrors are also hand-duplicates ("mirrored
VERBATIM"), but they are built by `harness/transform-proofs.sh` — 6
sessions green, sabotage-tested — while Verus, until 2026-10-24, had no
gate and no binary on the box (now: `harness/verus-gate.sh`, green on all
locally-present models, and `/opt/verus-0.2026.10.18.7d82994`; still no
manifest `proof:` lines). The three branch-pending FAILs are landed in-tree
2026-10-26 (`redundant_store_elim`, `array_len_fold`, `const_status_cond`
re-verified at 53/10/35 on the landed files — no re-proof).
Conversely the retired Verus file `i32_bounds_exec.rs` carries
an executable function with a postcondition, and `interval.rs`
discharges nonlinear arithmetic the Isabelle automation needed hand-holding
for. The honest summary: 470 checked obligations over 23 active models whose
fidelity ranges from pinned-and-mirrored (`dead_fn_elim`,
`redundant_store_elim`, `array_len_fold`, `const_status_cond`,
`copy_propagation`, `test_lowering`, `string_folds`, `capture_folds`,
`list_folds`, `not_folds`, `const_cmp_folds`, `slice_identity`,
`case_lowering`, `elseif_flatten`, `seq_range`) through partially-pinned
(`dead_store_elim`, `optimize_stmts`, `function_purity`, `textop_folds`,
`arith_folds`, `test_folds`, `elim_trio` — all-UNMIRRORED by design,
suite-less sources — plus `ternary_desugar`, same)
— see the audit table in point 4. The two `i32` models (12 obligations)
are retired, out of the gate and the totals.

**6. What "verified" does not mean.** It does not mean the target has no UB
(`C_UB_PROOF.md` is a separate, still-open obligation, P4 blocked on the
absent C-Parser/AutoCorres toolchain). It does not mean the renderer honors
the verdict (`i32_provable` has no consumer — zero references outside its
own file, verified 2026-10-24). It does not mean the pass
fires — see the `for-recovery` lesson in §(d). It does not mean the
model's target exists: the i32 models verify green over a function absent
from every recorded commit (see the §(a) correction). And re-running does
not check the statement — Verus proves the lemma as written; whether the
lemma means what the README claims is human-audit territory, which is why
the pin-to-test mapping in P0(iii) matters more than another green run.

## (c) Which transforms have not been proven correct

Tier 3 (semantic preservation over real shell meaning): **nothing**, by
design — see §(b).4. What follows is the Tier-1 inventory: every transform
and analysis with a verdict-shaped obligation, marked V (Verus model),
I (Isabelle session), T2 (property laws + differential only). The laws in
`tests/transform_laws.rs` (determinism, idempotence, forbidden-shape,
render-invariance) cover every registered transform structurally — that is
the baseline everything below also has.

| transform / analysis | class | status | note |
|---|---|---|---|
| `div_mod_pow2` | analysis (non-neg verdict) | **I** + manifest | `proof/` next to the offer; negative control kept |
| `arith_identity` | value folds + error guards | **I** | 29 lemmas; guards proved load-bearing by refutation |
| `for_recovery` | loop recovery | **I (trace only)** | iteration-trace identity; **proved path unreachable for shell input** (parser wraps operands in `Arith`) — true theorem, dead contract |
| `i32_provable` | analysis (`abs_bound` + `arith_bounds`) | **I** (`abs_bound`/`is_i32`) + **V-retired** (`arith_bounds`, 2 files) | Verus pair retired P0(iv) — target never landed; Isabelle `abs_bound` stands |
| `dead_fn_elim` | elimination | **V** (Passes 1–4) | Lit-fragment census gap flagged, not proved |
| `dead_store_elim` | elimination | **V** (core) | droppable scalar class only; found 2 real bugs next door |
| `optimize_stmts` (`ir.rs`) | elimination (Pass 1) | **V** | Pass 0.5 folding separate, unproved |
| `bigint_range` (`shir_passes`) | analysis | **I** | pre-fix twin refuted in-file (`v0_not_sound`) |
| `interval` (`shir_passes`) | analysis (floor walk) | **I** | imports BigIntRange; release-wrap `*` arm fixed with proof |
| `text_ops` (wc part) | node lowering | **I** (`docs/fm/TextOps`) | `lowered_wc_sound`; pre-fix emission recorded refuted |
| `maskable` (`shir_passes`) | analysis | uncommitted WIP | theory file untracked, session wired in an uncommitted `proofs/ROOT` edit (which the `proofs/` gate build would then attempt); build status unknown, not in the measured gate set |
| `redundant_store_elim` | elimination | **V** (fixed pass, 53) | landed in-tree, gated; 3 soundness fixes landed with it (source-level Ext-WIP rebase still pending) |
| `copy_propagation` | propagation | **V** (substitution core, 27) | same census/purge shape as the proved elims |
| `function_purity` | analysis (verdict) | **V** (verdict soundness, 41) | verdict gates `inline_pure_fns` — wrong verdict = miscompile |
| `inline_pure_fns` | inlining | T2 | needs purity + call preservation (Tier-3-flavored) |
| `const_status_cond` | const fold | **V** (7-row table, 35) | landed in-tree, gated; all shape pins mirrored in-module |
| `array_len_fold` | const fold | **V** (`fold`, 10) | landed in-tree, gated; all pins mirrored in-module |
| `test_lowering` | lowering | **V** (Tier-1 leaves, 25) + T2 (rest) | **fires most (43/562)**; full obligation needs statement semantics — leaves proved, rest Tier-2 |
| `const_condition_elim` | const fold | **V** (`elim_trio`, cce) + T2 (rest) | per-node pruning proved P9; `eval_cond` string parsing out of scope; 0/563 isolated, **3/563 in-pipeline** (measured 2026-10-26 — upstream passes mint the consts) |
| `counted_arith_forinit`, `counted_while_forinit` | loop recovery | T2 | same dead-path defect class as `for_recovery` — check firing first |
| `slice_identity`, `affix_strip_fold` | folds | T2 (`affix` in **V** `list_folds`; `slice` below) | zeros verified as correct refusals, not bugs — see P10 |
| everything else in `src/transforms/` (44 files: `arith_forms`, `arith_normalize`, `background_decide`, `bc_float_clean`, `brace_fold`, `builtin*` (3), `capture_node_fold`, `cat_read`, `const_capture_fold`, `default_empty_fold`, `direct_calls`, `echo_return`, `escape_classes`, `f32_narrow`, `fbdev_gpu*` (4), `fuse_fill_consume`, `grep_o`, `grep_pcre`, `hoist_loop_invariants`, `interp_fold`, `isolate_accumulate`, `loop_return_lift`, `planner`, `process_subst`, `shir_native_stmt`, `shir_pipeline_native`, `split_set`, `str_chop_cursor`, `stray_reserved_word`, `string_accumulator`, `sub`, `sync_ok_loops`, `test_simplification`, `text_capture_fold`, `text_ops_planner`, `type_query`, `typeset_attrs`, `append_to_store`) | mixed | T2 | laws + differential only; most never fire in isolation on the corpus |
| `unreachable_after_exit` | elimination | **V** (`elim_trio`, uae) | per-node truncation proved P9; 0/563 both modes — only the BAT frontend constructs `Exit`/`Return` (shell `exit` lowers to a builtin call); starved by producer absence, not wiring |
| `merge_init_assignments` | elimination | **V** (`elim_trio`, mia) | adjacent-pair merge proved P9 under literal/pure/no-self-read gates; 0/563 both modes — FIRES on synthetic `declare x=0` + `x=6` input (mechanics verified live) |
| `slice_identity` | fold | **V** (`slice_identity`, 10) | zero-offset fold proved P10; fires 0/563 shell (synthetic witnesses) |
| `case_lowering` | lowering | **V** (dispatch, 29) + T2 (rest) | dispatch proved P10; full obligation needs statement semantics |
| `else_if_flatten` | restructuring | **V** (chain, 22) | branch-selection proved P11; structural rule |
| `seq_range_for` | loop recovery | **V** (word list, 11) | seq-words identity proved P11; fires on `for-in-seq` shapes |
| `ternary_desugar` | lowering | **V** (cond normalize, 9) | branch-selection proved P11; ingress-only (C frontend) |
| `shir_passes` analyses (`lifetime`, `loop_opt`, `numstr`, `numeric_observed`, `scc`, `strip`, `used_before_decl`, …) | analyses/passes | T2 (mostly) | no verdict-soundness theorems; obligations unexamined per-pass |

## (d) Priority order (importance × feasibility)

**P0 — land what is proven before proving anything new.** Status 2026-10-24:
`harness/verus-gate.sh` exists and is green (Tier 0: the five models
re-verified with exact-count checks, exit 0; sync registry empty by
design — see below). Landed 2026-10-24: (i) DONE — the three Verus
commits are on GitHub (pushed with `fm-wc-semantics2`, now at `b46a316e4`);
(iii) DONE — `sh2perl/tests/pin_mirrors.rs`, 9 regression tests mirroring
the previously-unmirrored pins (optimize 4 + DSE drop-side 5), all green,
committed and pushed in the same branch update. `dead_fn_elim`'s three
pins were already exactly mirrored and green. (ii) DONE — the
`.verus-rse` `redundant_store_elim` fix (now THREE soundness holes: the
two P1 named plus a `$name`-in-`Str` blind spot found during the work,
each with failing-first tests) with its proof (53 obligations, two
fix-mutants red) is committed on branch `verus-rse` (`7e317c61`, pushed),
merged with current main, registered in the gate (sixth entry,
`redundant_store_elim.rs:53:80`), and its 7 pins are all mirrored
(3 in-module + cascade/observer/index-read in `pin_mirrors.rs`, 12
green). LANDED 2026-10-26: the three proof files are copied in-tree
(`proofs/verus/redundant_store_elim.rs`, `array_len_fold.rs`,
`const_status_cond.rs`) and re-verified at 53/10/35 on the landed files —
no re-proof, byte-identical to branches `verus-rse` (`7e317c61`) and
`verus-p2` (`68d20941`); gate MODELS entries already present, now backed by
files. The main worktree holds another worker's uncommitted `IrExpr::Ext`
arm in the same `redundant_store_elim.rs` source file — overlapping
hunk, both keep-direction; the Ext owner rebases onto the gitlink bump
(source-level merge still pending, proof file unaffected).
(iv) DONE 2026-10-26 — the two i32 models are RETIRED: bannered in-file,
removed from `harness/verus-gate.sh` MODELS, excluded from the active totals
(still verify at 5/7 as superseded-design records). `verus-sync.sh` stays
unregistered (nothing to sync — a permanently-red sync entry is noise,
not signal).

**P1 — `redundant_store_elim`.** DONE — see P0(ii): the fixed version is
proved (shadow argument, observationally exact), with all three bug
scenarios as pins and both fix-mutants as negative controls. LANDED
2026-10-26 (file in-tree, gate green at 53). What remains
is the source-level mechanical merge once the Ext WIP lands, not another proof.

**P2 — `const_status_cond`, `array_len_fold`.** DONE — both proved on
branch `verus-p2` (`68d20941`, pushed): array-len-fold value
preservation (10 obligations, offset-guard mutant red at 9/1) and
const-status-cond restructuring preservation over fuel-bounded
trace/status (35 obligations, two mutants red at 31/3 and 33/1). All
shape pins mirrored 1:1 in-module (dead_fn_elim precedent — no
`pin_mirrors.rs` additions); both registered in the gate
(`array_len_fold.rs:10:40`, `const_status_cond.rs:35:60`). LANDED 2026-10-26
(files in-tree, re-verified at 10/35 — no conflicting WIP in either file).

**P2 — `const_status_cond`, `array_len_fold`.** They fire on the real corpus
(8 and 9 files of 562 — nearly the only ones that do), their obligations
are pure value-preservation over literals (no state, no census, no fuel),
and the proofs are small enough to be the first *new* gated Verus
proofs (the gate exists; it currently guards the five old models).
Feasibility is the point: bank two green,
gated proofs on live passes.

**P3 — `copy_propagation`.** DONE — proved 2026-10-24
(`copy_propagation.rs`, 27 obligations, gate-registered
`copy_propagation.rs:27:40`): substitution soundness over a
parameterized single-def table with the def-before-read gate, single-store
induction with `prefix_ok`, six fidelity pins mirroring the transform's
own tests, gate-dropping mutant red at 25/2. Coverage sync registered
(`verus-sync-coverage.sh:copy_propagation`, baseline
`copy_propagation_sync.txt`, sabotage-tested incl. executed tests:
inverting a mapped test's expectation yields `exec <pin>: FAIL` naming
the fragment). Copy defs, arith gates,
`param-const-fold`, `AffixStrip`, quoted-`Interpolate` defs out of scope
(same core; the extensions reuse this gate).

**P4 — `function_purity` verdict soundness.** DONE — proved 2026-10-24
(`function_purity.rs`, 41 obligations, gate-registered
`function_purity.rs:41:40`): Pure ⟹ empty trace, Emulable ⟹
capturable-only trace, at every fuel, under a consistent table (three
load-bearing conjuncts: recomputation floor, lattice bound, defined
keys — each guards a concrete unsound-table class found during the
proof). Seven fidelity pins; Output-as-Pure mutant red at 39/2. Coverage
sync registered (`verus-sync-coverage.sh:function_purity`, baseline
`function_purity_sync.txt`, sabotage-tested). Full
inline preservation stays out (Tier-3).

**P5 — Tier-1 sub-obligations out of `test_lowering`.** DONE — proved
2026-10-24 (`test_lowering.rs`, 25 obligations, gate-registered
`test_lowering.rs:25:40`): per-leaf value preservation for the four
lowering families (nonempty, string-eq as `Not(Ne)`/`Ne`, numeric six-op,
glob-affix + negations) over `Seq<char>` strings, from any closed store.
Eight fidelity pins; dropped-`Not` mutant red at 24/1 (the
perl-numeric-`==` bug). Coverage sync registered
(`verus-sync-coverage.sh:test_lowering`, baseline `test_lowering_sync.txt`,
sabotage-tested). Status liveness, cond position, nocasematch,
compounds stay out (Tier-3).

**P6 — VALUE-FOLD sweep.** DONE — six files proved 2026-10-25, all green
with checked mutants and gate-registered with exact counts:
`string_folds.rs` (interp-fold single-literal + default-empty-fold
empty-default identity, 11 obligations, multi-part mutant red at 9/2),
`arith_folds.rs` (arith-normalize three identities + bc-float-clean
finite strip, 11 obligations, dropped-canonicalization mutant red at
10/1), `test_folds.rs` (self-comparison eight-op table, 7 obligations,
wrong-collapse mutant red at 4/3), `capture_folds.rs` (newline strip +
echo join + status-0 chains + text spans, 15 obligations, loosened-And
mutant red at 13/2), `list_folds.rs` (brace splice + literal affix
strips, 12 obligations, dropped-prefix mutant red at 11/1),
`textop_folds.rs` (case map + substr + GNU basename, 15 obligations,
flipped-case mutant red at 14/1) — 71 new obligations (352 total).
Firing adjudicated per pass before proving: interp-fold 297/563,
brace-fold 25/563, const-capture-fold 13/563, default-empty-fold
28/563, text-capture-fold 2/563, text-ops 180/563 (C target) all fire;
test-simplification 0/562 but fires on synthetic self-comparison input
(mechanics verified live); arith-normalize runs at frontend ingress, not
the registry (0/562 is a probe artifact — rule + refusals proved);
bc-float-clean targets the mimecroft corpus (absent here — rule proved
for its documented target); affix-strip-fold 0/562 on shell (offered to
rs/java targets — target-gated); slice-identity zeros are correct
refusals (not proved); str-chop-cursor needs the cursor-window demo as
firing witness (deferred to P7/P8 scale); sub is a placeholder module.
Coverage syncs registered for all six (baselines committed, sabotage-
tested, mapped tests executed: 7+6+6+3 PASS, arith/test_folds pins
UNMIRRORED — suite-less sources, recorded).

**Explicitly deprioritized.** `for_recovery` / `counted_arith_forinit`: prove nothing until the firing defect is fixed —
the repo's own lesson is that a green proof over an unreachable path is a
true theorem about a dead contract. Backend emitters (`fbdev_gpu*`,
`shir_native_stmt`, …): no semantics to state preservation against, and
`text_ops`' provable fragment is already done. `process_subst` /
`background_decide`: process and exec semantics are Tier 3, no model will
make them Tier 1. New Isabelle-vs-Verus framework debates: the split is
settled empirically (nonlinear arithmetic → Verus; everything gated →
Isabelle); revisit only when a lemma resists both.

Rule for everything above, inherited from `docs/transform-verification.md`:
**check that a pass fires before proving it, ship the negative control with
the proof, and give every new model a sync story on day one.**

**P7 — `not_identity`.** DONE — proved 2026-10-25
(`not_folds.rs`, 13 obligations, gate-registered
`not_folds.rs:13:40`): double-negation fold (duplication-consistency
gated) + rust-gated six-op comparison flip under the exact-complement
hypothesis (the Perl Eq-numeric/Ne-string asymmetry is the documented
counterexample for why the flip needs scoping). Eight fidelity pins,
wrong-complement mutant red at 11/2. Coverage sync registered
(`verus-sync-coverage.sh:not_folds`, baseline committed, sabotage-
tested, 7/7 mapped tests PASS).

**P8 — `const_str_cmp_fold`.** DONE — proved 2026-10-25
(`const_cmp_folds.rs`, 14 obligations, gate-registered
`const_cmp_folds.rs:14:40`): literal `Eq`/`Ne` (plain styles,
glob-free RHS), unconditional int/int, the flip-free wrapped
`Not(Ne)` exact_cond (sound on every target — no operator renders),
and `globMatch` with a literal pattern, all folded to the denoting
`Bool`. Nine fidelity pins, inverted-Eq mutant red at 12/2. Coverage
sync registered (`verus-sync-coverage.sh:const_cmp_folds`, baseline
committed, sabotage-tested — a compiling-but-wrong glob check yields
3 named `exec FAIL`s — 9/9 mapped tests PASS).

**P9 — ELIM trio.** DONE — proved 2026-10-26 (`elim_trio.rs`, 22
obligations, gate-registered `elim_trio.rs:22:40`): `cce_sound` (taken-branch
pruning, while-false drop, dowhile-to-body), `uae_sound` (post-`Exit` tail
truncation under abort semantics), `mia_sound` (adjacent literal-default +
pure-RHS pair merge). Eight fidelity pins, all UNMIRRORED by design
(suite-less sources — recorded, not claimed); inverted-branch mutant red
at 19/3. Coverage sync registered (`verus-sync-coverage.sh:elim_trio`,
baseline committed). The file needed repair before registration (fourth
run_abort arg, stray `fuel` requires, misplaced `by` block, mutual-recursion
decreases) — fixed, re-verified 22/0, mutant re-checked.

**P10 — `slice_identity`, `case_lowering`.** DONE — proved 2026-10-26
(`slice_identity.rs`, 10 obligations, `case_lowering.rs`, 29
obligations; gate-registered `slice_identity.rs:10:40`,
`case_lowering.rs:29:40`): zero-offset fold denotation identity under
the exact gate conjunction (non-ident-gate mutant red at 9/1, pin-
load-bearing as in array_len_fold); case dispatch preservation
(per-pattern denotation + first-match-wins chain, Prefix-to-Suffix
mutant red at 27/2). Eight pins mirror the slice tests 1:1;
fourteen pins mirror 13 of the 16 case tests (dropped-tail shape is
model-internal). Coverage syncs registered for both (baselines
committed). Firing adjudicated before proving: slice 0/563 on shell
(synthetic unit witnesses only — the test_folds precedent);
case fires 38/563 on `--target rs` (measured sweep; 0/563 on `--target pl` by gating).

**P11 — `else_if_flatten`, `seq_range_for`, `ternary_desugar`.** DONE —
proved 2026-10-26 (`elseif_flatten.rs`, 22 obligations,
`seq_range.rs`, 11 obligations, `ternary_desugar.rs`, 9 obligations;
gate-registered `elseif_flatten.rs:22:40`, `seq_range.rs:11:40`,
`ternary_desugar.rs:9:40`): else-chain collapse preserves the selected
body under every valuation (fuel-bounded loop over the strictly
dropping If count, first-hit scan lemmas; dropped-else mutant red at
18/4); seq-to-Range preserves the iterated integer list (accept-step
mutant red at 9/2); ternary cond normalization preserves the selected
branch (engine-swap mutant red at 8/1). Four pins mirror the 4
else-if tests; eight pins mirror the 8 seq tests; six ternary pins
are UNMIRRORED (no unit suite — recorded). Coverage syncs registered
for all three (baselines committed). Firing adjudicated before
proving (measured sweep; ternary is ingress-only by construction).

**P12 — `shir_passes` + `counted_*`: obligations examined, firing
checked 2026-10-26.** Each pass below states its Tier-1 obligation as
examined (not proved): the `invariant:` one-liner a future model must
carry, plus the firing signal measured this session. Rule (unchanged):
no model until the invariant is written AND a firing witness exists.

| pass | Tier-1 obligation (examined) | firing signal |
|---|---|---|
| `lifetime` | live-span soundness: every read of `v` lies inside its computed span; the escape bit over-approximates retention (missed escape = aliased buffers) | analysis (verdict consumed by C fixed-buffer transform); 12 unit tests |
| `loop_opt` | hoist preservation: moving the leading maximal pure invariant run to the prologue preserves the iteration trace (leading-run, no-control-escape, invariance gates) | rewrite; 7 unit tests; corpus sweep: TBD (channel: shared A1 pipeline) |
| `numstr` | seeding soundness: the vars × params fixpoint marks exactly the numerically-seeded cells | analysis; 10 unit tests |
| `numeric_observed` | int-homing soundness: a numeric-observed cell is never text-observed (every read reaches output through numeric coercion) | analysis; 11 unit tests |
| `scc` | cluster soundness: the reported SCCs are exactly the call-graph cycles (eligibility fixpoint over mutual recursion) | analysis; 6 unit tests |
| `strip` | strip preservation: removing the stripped nodes preserves the run | rewrite; 1 unit test |
| `used_before_decl` | uninit soundness: a flagged read is definitely uninitialized on every path (conservative dataflow) | analysis; 11 unit tests |
| `counted_arith_forinit` | recovery preservation: structured-Arith counted-`while` + trailing `v+=1`/`v++` denotes the same iteration as `ForInit` (`$?`-read veto, no counter write/escape) | rewrite; 6 unit tests; shell-corpus sweep 2026-10-26: 0/563 (frontend-shape CONFIRMED for shell input — shell `[ $i -lt N ]` conds are `test` calls, never `Arith` (only `while ((…))` qualifies; the 2 corpus files with those refuse on body/step gates, correctly); 0/563 isolated AND in-pipeline) |
| `counted_while_forinit` | same for shell `BinOp`/text conds | rewrite; 0/563 isolated AND in-pipeline pre-fix (Arith-wrap defect, witnessed live on 031) — FIXED 2026-10-26: `counter_step` now also accepts `Arith(Bin{Var,+/- ,Num≠0})`, the exact shell lowering of `i=$((i±1))`, mirroring the BinOp arm (same purity, same nonzero gate); 7 new unit tests (failing-first verified); **9/563 fire** (IR-level ForInit gain, all ./fail-green); C backend consumes the ForInit in its standard scoped form |

Explicitly not Tier-1 and not attempted: `process_subst` /
`background_decide` (process/exec semantics are Tier-3), `fbdev_gpu*` /
`shir_native_stmt` emitters (no semantics to state preservation
against), `inline_pure_fns` (needs call preservation — Tier-3, see
P4). Firing-channel caveat found during the P10/P11 sweeps: the CLI
passes target `"pl"` for `--target pl`, but the registry gates name
`"perl"` (case-lowering, text-ops-planner, capture-node-fold, …) —
so those gates refuse in the `./fail` perl pipeline and firing must be
measured per accepting target (`--target rs` for case-lowering). No code
changed for this (fleet-wide naming; filed as an observation, not a
fix in this effort).
