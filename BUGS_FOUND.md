# Bugs found by the Verus and Isabelle proofs

Every entry below is a defect in shipped-or-staged IR code that a proof
effort exposed, with the file that machine-checks it and the fix status.
Mutants and negative controls (deliberately broken copies that must go
red) are the anti-vacuity story, not bugs — they are listed in VERUS.md
§(b).3 and omitted here. So are *near-finds*: model-level unsound tables
the source already guarded against (P4's `v[f]=5`-for-undefined-`f`
class), harness-pattern tightenings, and concurrent workers' transient
breakage. This file is only about defects in the product.

## Confirmed product bugs (open)

### 11. `string_accumulator`: `expr_read_walk`/`read_walk` miss `Arith` (and other) reads
**Found by:** Tier-1 adjudication of the 11 parked transforms (2026-10-29) —
in-process probe via `ast_to_ir_raw` + direct transform call, no new
Isabelle session (deprioritized with measurements; the load-bearing
claims here are Tier-3).
**Defect:** the verdict's read-side walkers end in `_ => {}` catch-alls
with no `IrExpr::Arith` arm (`ArithAst::Var` reads invisible), and
`read_walk` has no `Redirect`/`Block`/`Pipeline`/`DeclareArray`/
`Function`/etc. arms. Witness (live, measured):
`tsv=""; i=0; while [ $i -lt 3 ]; do tsv="$tsv$x"; n=$(( tsv + 0 ));
i=$(( i + 1 )); done; echo "$tsv"` still yields
`Accumulator { var: "tsv", … }` from both `acc_vars_tree` and the cached
`accumulators()` verdict; the D-control (same program minus the arith
read) also fires, so the arith read is proven invisible to the walk.
**Contained today (why not fixed here, transform owner's call):**
(a) the js/estree `lower()` never runs end-to-end on the shell-source
CLI path — the CLI renders estree from target-unset cached A1 via
`shell_to_shir`, and `ingress_normalize` never calls
`string_accumulator::lower` (measured: ESTREE DIFF on the D-control via
the direct render path only; the arith witness shows none, and on
`bash-o4/MIMEcroft_fb.sh` `--target estree` is byte-identical with the
pass on and off, 0 `__acc_` marks);
(b) for the witness, the C consumer refuses via independent gates
(`escape_classes` Store/Local + 10 further vetoes; `SH2_DBG_ACC`
measured 0 tracked).
**Reach is larger than the corpus count suggests** (measured 2026-10-30):
the C consumer does NOT use the top-level `accumulators()` verdict — it
calls `acc_vars_tree` on `prog.stmts` and every `sub.body`
(`c_backend.rs:9837`), a *tree* walk, and on `MIMEcroft_fb.sh` that
tracks four accumulators (`tup_bp`, `tup_gp`, `blk_p`, `tup_rp`, 15
`_alen_` mirror sites), zero of which the top-level verdict reports. So
the walker this bug is in is on a live, non-corpus code path; corpus
`examples/` impact is 1/563 (`tsv-string-accumulate-loop.sh`), whose
body has no mid-loop exotic reads, and MIMEcroft escapes only because
its four accumulators have no `$(( ))` self-read (`tup_n=$((tup_n+1))`
is a different var; `lt_payload="$lt_payload …"` is refused by
`self_append_vars`, not proved safe).
**Fix (owner call):** one match arm each in `expr_read_walk`
(recurse `ArithAst`) + `read_walk` (the missing statement forms), or
delegate both to the shared shir descent; plus a failing-first
regression test in the module's `#[cfg(test)]` (the `n=$(( tsv+0 ))`
witness shape). A Tier-1 `verdict ⟹ all-writes-self-appends`
Isabelle session would certify exactly this fix once it lands —
proving it against the current walkers would certify the hole.

## Confirmed product bugs (fixed)

### 1. `redundant_store_elim`: `expr_pure` claims `Arith(_) => true`
**Found by:** modelling `dead_store_elim` in Verus (`dead_store_elim.rs`,
45 obligations) — its `arith_pure` correctly rejects `Assign`/`IncDec`
while the sibling pass's `expr_pure` did not.
**Defect:** an arithmetic RHS with side effects (`x=5; y=$((x=1)); …`)
was judged pure, so the store could be purged across a write.
**Fix:** corrected the predicate; failing-first regression test added;
proved in the same effort (`redundant_store_elim.rs`, 53 obligations,
fix-mutant red). Branch `verus-rse`, on GitHub, unmerged pending the
`Ext`-WIP rebase.

### 2. `redundant_store_elim`: `stmt_reads` ignores target indices on `Assign`
**Found by:** same Verus modelling session as (1).
**Defect:** `x=5; arr[x]=1; x=6` dropped the live store `x=5` — the read
of `x` through the index was invisible to the census.
**Fix:** same as (1) — corrected, regression-tested, proved.

### 3. `redundant_store_elim`: `$name`-in-`Str` blind spot
**Found by:** the same effort, third hole discovered during the work.
**Defect:** a `$name` reference inside a `Str` node was not counted as a
read, so a store feeding only a string-embedded expansion could be purged.
**Fix:** same as (1) — corrected, regression-tested, proved.

### 4. `i32_provable`: leaf-only bound accepted `2^29 * 2^29 * 2^29` as I32
**Found by:** Isabelle (`proofs/I32Provable/I32Provable.thy`) — the first
proof attempt failed on the false positive and the failure is recorded,
not papered over.
**Defect:** the estimator checked literals (`|n| < 2^30`) and operators
(`+ - *` only) but never composed the bound, marking a value-2^87
compound as I32. The manifest's invariant line had claimed "the estimate
is monotone, so a false positive is impossible by construction" — no
estimate existed to be monotone.
**Fix:** `arith_abs_bound` now composes a per-node bound and refuses as
soon as it would leave i32; the 2^87 counterexample stays in the theory
file next to the soundness theorem. (The deprecated interval estimator
`arith_bounds` that the two Verus i32 models cover never landed in `src/`
— superseded, not fixed.)

### 5. BigInt-range analysis: three soundness gaps in the pre-fix pass
**Found by:** Isabelle (`proofs/BigIntRange/BigIntRange.thy` — `v0_range`
reproduces the pre-fix arms verbatim, `v0_not_sound` is the
machine-checked counterexample set).
**Defects:** (1) `%` took min/max of the four interval corners — false
for floor-mod, whose value set the corners miss; (2) `//` took corner
min/max without refusing divisor ranges straddling 0, where floor-div
jumps at the pole; (3) `Cast` ignored float-typed casts, whose value
the pipeline cannot read as an integer.
**Fix:** corner loops replaced/refusals added; `bigint_range_sound` is
the fixed pass's obligation, checked green.

### 6. `text_ops` wc lowering: `length + 1` counted lines
**Found by:** Isabelle (`sh2perl/docs/fm/TextOps/ShIR_TextOps_Base.thy`).
**Defect:** the pre-fix emission counted `length(text) + 1` where bash
counts newlines (`strlen_plus_one_is_not_line_count`, with the general
`line_count_is_not_length_plus_one` behind it).
**Fix:** the line arm is the newline count; `lowered_wc_sound` is the
checked obligation, the pre-fix emission stays in-file as a refuted
statement.

### 7. `hoist_loop_invariants`: 0-trip loops hoist unconditionally
**Found by:** modelling `hoist_loop_invariants` in Verus
(`hoist_loop_invariants.rs`, 22 obligations) — the whole-loop
induction failed at n = 0, and the failure is real, not a model
artifact.
**Defect:** the transform hoists the leading invariant run before the
loop with no trip-count guard, but at 0 trips the original runs
nothing while the hoisted prologue runs: `while false; do y = 5;
done` leaves `y` unbound under bash and assigns `y = 5` after the
transform (verified live against the transform: it reports changed
and emits the hoisted Assign plus an empty loop). Any live-after read
of the hoisted var diverges on a 0-trip loop.
**Fix:** UNFIXED (open) — the transform owner decides (trip-guard the
hoist, or restrict to do-while/known-live shapes). The model covers
exactly the sound fragment (n >= 1, every production firing runs
many trips); `pin_zero_trip_diverges` is the failing-first shape.

## Guard-load-bearing refutations (the code was already right; the proofs
show exactly which guard carries the soundness)

### 8. `arith_identity`: `x - x → 0` needs `no_err x`
**File:** `proofs/ArithIdentity/ArithIdentity.thy` (`no_err_guard_needed_for_sub_self`).
With an error-raising `x` (`(1/0) - (1/0)`) the original is `None` and
the rewritten `0` is `Some 0` — the fold would swallow the error. The
guard is what makes the shipped rewrite sound.

### 9. `arith_identity`: `x * 0 → 0` needs `no_err x`
**File:** same (`no_err_guard_needed_for_mul_zero`). `(1/0) * 0` is
`None`; the fold would give `Some 0`. Module's own example.

### 10. `arith_identity`: `0 / x` needs `n > 0`
**File:** same (`positive_divisor_guard_needed`). `0 / 0` is `None` —
the regression the module header records as FIXED.

## Non-bugs recorded for honesty

- **`for_recovery` + `counted_arith_forinit` + `counted_while_forinit`:**
  green Isabelle proof over a path unreachable for shell input (the
  parser wraps operands in `Arith`). True theorem, dead contract —
  deliberately listed as deprioritized, not as bugs.
- **`slice_identity` / `affix_strip_fold` zeros:** verified as correct
  refusals (non-identity shapes, target-gated offers), not defects.
- **`str_chop_cursor`:** proved (`str_chop_cursor.rs`, 17 obligations)
  this session — the non-bug line above is superseded; the firing
  witness (MIMEcroft per-pixel rasterizer, measured 28% self-time)
  is in the transform header.
- **P4 consistency conjuncts / P6 mutants / coverage-checker patterns:**
  proof-design and harness findings, sources already safe.

## Parked-transform firing census (the denominator for "is proving it worth it")

Measured 2026-10-30 over `sh2perl/examples/*.sh` (563 files) — in-process
`ast_to_ir_raw` + one transform at a time, and re-run on the fully
optimised IR — plus `bash-o4/MIMEcroft_fb.sh` (293 commands → 279 stmts)
where the corpus number under-sells the pass. Full-pipeline `apply()` counts
are included because several passes only see post-optimisation shapes.

| transform | corpus fires | MIMEcroft (raw / post-pipeline) | tier |
|---|---|---|---|
| `fuse-fill-consume` | 0/563 | no / no | Tier 3 (loop-fusion trace) |
| `isolate-accumulate` | 0/563 | no / no | Tier 3 (inlining value) |
| `string-accumulator` | 1/563 top-level verdict; **C tree walk (`acc_vars_tree`) tracks 4 vars on MIMEcroft** | no / no (top-level) | Tier 1 fragment = the walker in bug 11; lowering Tier 3 |
| `sync-ok-loops` | 43 files / 52 verdicts | **19 sync + 1 batch verdicts**, 0 emitted-byte change | criterion 2 Tier 1 (conservative-by-construction); criteria 1/3 Tier 3 |
| `background-decide` | 0 (10 `Background` nodes over 7 files, none classified) | no / no | Tier 3 (fork/thread semantics) |
| `inline-pure-fns` | 0/563 over 59 Function-def files | no / no | Tier 3-flavored (needs `function_purity` + call preservation) |
| `process-subst` | 16/563 (pipeline only, never raw) | **yes / —** (pipeline) | Tier 3 (filesystem/path-arg) |
| `for-recovery` | 0/563 | no / no | Tier 1 DONE (`proofs/ForRecovery`, dead contract) |
| `type-query` | 1/563 (`parse-eval-multiline.sh`) | no / no | Tier 1-trivial (58-entry builtin table) |
| `planner` | not registered in `transforms::all()` | — | mechanism, not a transform |
| `sub` | returns `false` unconditionally | — | placeholder |

Consequences recorded, not acted on: (1) the `string-accumulator`
read-walker hole (bug 11) sits on a live C path and is the only one of the
eleven whose fix a Tier-1 Isabelle session should certify; (2) nothing in
this list is a Verus target — the two-loop fusion and whole-program shape
analyses need loop traces, which the C generator rows already show Verus is
for, but their obligations are Tier 3; (3) `sync-ok-loops` computes 20
MIMEcroft verdicts that change no emitted byte, so a proof of its walker
would guard an inert gate until the renderer hooks land.
