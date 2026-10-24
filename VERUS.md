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

Status snapshot (measured 2026-10-24):

| proof file | target | obligations | status |
|---|---|---|---|
| `proofs/verus/interval.rs` | `transforms/i32_provable.rs` (`arith_bounds`) | 5 verified, 0 errors | committed `e95ad012`, **on GitHub** |
| `proofs/verus/i32_bounds_exec.rs` | same, exec-carrying full-enum form | 7 verified, 0 errors | committed `2c0e035d`, **on GitHub** |
| `proofs/verus/optimize_stmts.rs` | `src/ir.rs::optimize_stmts` Pass 1 | 8 verified, 0 errors | committed `84bb46cb7`, local-only |
| `proofs/verus/dead_fn_elim.rs` | `transforms/dead_fn_elim.rs` Passes 1–4 | 25 verified, 0 errors | committed `46ec35566`, local-only |
| `proofs/verus/dead_store_elim.rs` | `transforms/dead_store_elim.rs` core | 45 verified, 0 errors | committed `dbd0a5562`, local-only |
| `proofs/verus/redundant_store_elim.rs` | `transforms/redundant_store_elim.rs` (fixed) | 53 verified, 0 errors | branch `verus-rse` (`7e317c61`), **on GitHub**, unmerged — see P0(ii) |

143 obligations total, 0 errors, five of the six with checked failing
mutants (see §(b).3; the sixth, the exec form, carries the postcondition on
the executable function itself instead). All six counts — and all five
mutants — were independently reproduced on 2026-10-24 with the pinned
binary (see §(b).3).

Correction, same date: the two i32 models' target, `arith_bounds`, is
absent from `src/` — and from every commit in recorded history. The live
estimator is `arith_abs_bound`/`arith_is_i32`, proved in Isabelle
(`I32Provable.thy`). The two Verus files still verify (12 green obligations
about a superseded design), but their fidelity premise is void, not stale —
and the sync extractor has no target (its FATAL on the live tree was
verified live: correct behavior, wrong reason to celebrate). §(d) P0 records
what follows from this. All six were run under Verus `0.2026.10.18.7d82994` with
rust toolchain `1.99.1` (`--triggers-mode silent --rlimit 40`, `--rlimit 60`
for the exec form, `--rlimit 80` for redundant-store-elim). The pinned binary lives at
`/opt/verus-0.2026.10.18.7d82994/verus` (re-fetch
`release/0.2026.10.18.7d82994` x86-linux if it ever goes missing). Still no gate runs
these files — re-running one is a manual command from the README, and a
`harness/verus-gate.sh` now exists and is green (Tier 0, landed 2026-10-24):
it re-runs the six models with exact-count assertions (exit 1 on count
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

**3. The obligations are not vacuous — five files have a checked mutant.**
Interval with a wrong product corner: 4 verified, 1 error. `Assign` writing
a constant: 7 verified, 1 error. Inverted keep rule: 23 verified, 2 errors.
Dropped purity gate: 43 verified, 2 errors. Restored `Arith(_) => true`
purity lie: 51 verified, 2 errors. Restored index-blind `stmt_reads`:
51 verified, 2 errors. Every mutant was restored and
re-checked green — and every one of those reproductions was
re-run independently on 2026-10-24 with the pinned binary, matching the
documented numbers exactly (4v/1e, 7v/1e, 23v/2e, 43v/2e, 51v/2e, 51v/2e against clean
baselines of 5/8/25/45/53/53). The sixth file (`i32_bounds_exec.rs`) has no
recorded mutant; its anti-vacuity argument is structural instead — the postcondition
constrains the executable function's actual return triple over all ten
`ArithAst` constructors, a shape 30 failed probes showed is easy to get
vacuously wrong and hard to get right. There are no `admit()`s; the single trust axiom is
`assume_specification[i128::checked_neg]` (a stdlib spec, standard vstd
practice — the boundary where verification stops and the compiler's contract
starts).

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
| i32 ×2 | n/a | moot — target absent | n/a |

**5. Compared with the Isabelle line, Verus is stronger per-lemma and weaker
as a gate.** Isabelle's mirrors are also hand-duplicates ("mirrored
VERBATIM"), but they are built by `harness/transform-proofs.sh` — 6
sessions green, sabotage-tested — while Verus, until 2026-10-24, had no
gate and no binary on the box (now: `harness/verus-gate.sh`, green, and
`/opt/verus-0.2026.10.18.7d82994`; still no manifest `proof:` lines).
Conversely the Verus files carry
executable functions with postconditions (`i32_bounds_exec.rs`) and
discharge nonlinear arithmetic the Isabelle automation needed hand-holding
for. The honest summary: 143 checked obligations over six models whose
fidelity ranges from pinned-and-mirrored (`dead_fn_elim`,
`redundant_store_elim`) through
partially-pinned (`dead_store_elim`, `optimize_stmts`) to void (`i32` ×2)
— see the audit table in point 4.

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
| `i32_provable` | analysis (`abs_bound` + `arith_bounds`) | **I** (`abs_bound`/`is_i32`) + **V** (`arith_bounds`, 2 files) | split across frameworks by automation fit |
| `dead_fn_elim` | elimination | **V** (Passes 1–4) | Lit-fragment census gap flagged, not proved |
| `dead_store_elim` | elimination | **V** (core) | droppable scalar class only; found 2 real bugs next door |
| `optimize_stmts` (`ir.rs`) | elimination (Pass 1) | **V** | Pass 0.5 folding separate, unproved |
| `bigint_range` (`shir_passes`) | analysis | **I** | pre-fix twin refuted in-file (`v0_not_sound`) |
| `interval` (`shir_passes`) | analysis (floor walk) | **I** | imports BigIntRange; release-wrap `*` arm fixed with proof |
| `text_ops` (wc part) | node lowering | **I** (`docs/fm/TextOps`) | `lowered_wc_sound`; pre-fix emission recorded refuted |
| `maskable` (`shir_passes`) | analysis | uncommitted WIP | theory file untracked, session wired in an uncommitted `proofs/ROOT` edit (which the `proofs/` gate build would then attempt); build status unknown, not in the measured gate set |
| `redundant_store_elim` | elimination | **V** (fixed pass, 53) | branch `verus-rse`, on GitHub, unmerged — Ext-WIP rebase pending; 3 soundness fixes landed with it |
| `copy_propagation` | propagation | T2 | same census/purge shape as the proved elims |
| `function_purity` | analysis (verdict) | T2 | verdict gates `inline_pure_fns` — wrong verdict = miscompile |
| `inline_pure_fns` | inlining | T2 | needs purity + call preservation (Tier-3-flavored) |
| `const_status_cond` | const fold | T2 | **fires on corpus (8/562)** |
| `array_len_fold` | const fold | T2 | **fires on corpus (9/562)** |
| `test_lowering` | lowering | T2 | **fires most (43/562)** but needs statement semantics; only sub-lemmas are Tier-1-shaped |
| `const_condition_elim` | const fold | T2 | fires only via pipeline order, not in isolation |
| `counted_arith_forinit`, `counted_while_forinit` | loop recovery | T2 | same dead-path defect class as `for_recovery` — check firing first |
| `slice_identity`, `affix_strip_fold` | folds | T2 | zeros verified as correct refusals, not bugs |
| everything else in `src/transforms/` (49 files: `arith_forms`, `arith_normalize`, `background_decide`, `bc_float_clean`, `brace_fold`, `builtin*` (3), `capture_node_fold`, `case_lowering`, `cat_read`, `const_capture_fold`, `default_empty_fold`, `direct_calls`, `echo_return`, `else_if_flatten`, `escape_classes`, `f32_narrow`, `fbdev_gpu*` (4), `fuse_fill_consume`, `grep_o`, `grep_pcre`, `hoist_loop_invariants`, `interp_fold`, `isolate_accumulate`, `loop_return_lift`, `merge_init_assignments`, `planner`, `process_subst`, `seq_range_for`, `shir_native_stmt`, `shir_pipeline_native`, `split_set`, `str_chop_cursor`, `stray_reserved_word`, `string_accumulator`, `sub`, `sync_ok_loops`, `ternary_desugar`, `test_simplification`, `text_capture_fold`, `text_ops_planner`, `type_query`, `typeset_attrs`, `unreachable_after_exit`, `append_to_store`) | mixed | T2 | laws + differential only; most never fire in isolation on the corpus |
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
green). NOT yet merged to the main line: the main worktree holds another
worker's uncommitted `IrExpr::Ext` arm in the same file — overlapping
hunk, both keep-direction; the Ext owner rebases onto the gitlink bump.
Remaining: (iv) retire-or-retarget the two i32 models: their target never landed, so
`verus-sync.sh` has nothing to sync — do NOT register it in the gate
(a permanently-red sync entry is noise, not signal). A seventh model
without (iv) is a seventh thing silently rotting.

**P1 — `redundant_store_elim`.** DONE — see P0(ii): the fixed version is
proved (shadow argument, observationally exact), with all three bug
scenarios as pins and both fix-mutants as negative controls. What remains
is the mechanical merge once the Ext WIP lands, not another proof.

**P2 — `const_status_cond`, `array_len_fold`.** They fire on the real corpus
(8 and 9 files of 562 — nearly the only ones that do), their obligations
are pure value-preservation over literals (no state, no census, no fuel),
and the proofs are small enough to be the first *new* gated Verus
proofs (the gate exists; it currently guards the five old models).
Feasibility is the point: bank two green,
gated proofs on live passes.

**P3 — `copy_propagation`.** Classic substitution soundness over the same
read-census the elim proofs already formalize; the model should transfer
almost mechanically. Importance is structural (wrong propagation corrupts
every downstream consumer), feasibility is high.

**P4 — `function_purity` verdict soundness.** The verdict gates
`inline_pure_fns`, so an unsound verdict is a miscompile, not a missed
optimization — the highest *severity* on this list. The verdict itself is
a structural predicate (Tier-1-shaped, feasible); full inline preservation
is Tier-3 and stays out. Prove the verdict, pin the inliner to it.

**P5 — Tier-1 sub-obligations out of `test_lowering`.** It fires most
(43/562) but its full obligation needs statement semantics. Carve what is
Tier-1-shaped instead — e.g. literal-operand `TestExpr` evaluation, the
same class as the proved `arith_identity` folds — and prove those. Do not
attempt the pass whole; that is the Tier-3 trap.

**Explicitly deprioritized.** `for_recovery` / `counted_arith_forinit` /
`counted_while_forinit`: prove nothing until the firing defect is fixed —
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
