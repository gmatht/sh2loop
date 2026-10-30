#!/usr/bin/env bash
# verus-gate.sh — re-run every checked Verus model and the sync --check.
#
#   ./harness/verus-gate.sh                # verify all models + sync status
#   ./harness/verus-gate.sh --list         # show what would be checked
#
# Two things are checked, because the proofs have two failure modes:
#
#   1. MODELS — each standalone proof file re-verified with the pinned
#      binary, asserting the EXACT obligation count (`N verified, 0 errors`).
#      The count check is the point: a model that verifies fewer lemmas
#      than claimed (a weakened file) must fail even though Verus exits 0.
#      An entry is `file:expected:rlimit`; a `+` joins files verified as
#      one crate (the Tier-1 i32 pair: generated sync output + hand proof).
#
#   2. SYNC — for every registered extractor, regenerate to temp and diff
#      against the committed baseline. Two drivers: the legacy
#      regenerating extractor (`verus-sync.sh`, whose `--check` tail was
#      missing so the check lives here and the generator stays untouched)
#      and the coverage checker (`verus-sync-coverage.sh <model>`), which
#      re-derives each P3/P4/P5 model's pin<->test mapping and mirrored
#      guard predicates from the live source and emits a canonical
#      manifest. A missing baseline is a loud SKIP (Tier 1 pending),
#      never green-by-absence.
#
# Exit: 0 every model green and every registered sync clean;
#       1 any model count mismatch / Verus error / sync drift;
#       2 the Verus binary is absent (nothing was verified — do NOT read
#         that as green).
#
# Env: VERUS_BIN (default /opt/verus-0.2026.10.18.7d82994/verus),
#      RUSTUP_HOME/CARGO_HOME (defaults match the README), VERUS_TIMEOUT
#      (seconds per file, default 600).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PV="$root/sh2perl/proofs/verus"
VERUS_BIN="${VERUS_BIN:-/opt/verus-0.2026.10.18.7d82994/verus}"
export RUSTUP_HOME="${RUSTUP_HOME:-/root/.rustup}"
export CARGO_HOME="${CARGO_HOME:-/root/.cargo}"
TIMEOUT="${VERUS_TIMEOUT:-600}"
PIN="0.2026.10.18.7d82994"

# file(s):expected-verified:rlimit — `+` = verify as one crate.
# NOTE: `interval.rs` / `i32_bounds_exec.rs` are RETIRED (see VERUS.md §(a)
# correction and §(d) P0(iv)): their target `arith_bounds` never landed —
# the live estimator is `arith_abs_bound`, proved in Isabelle
# (`I32Provable.thy`). Kept in-tree as superseded-design records, not gated.
MODELS=(
  "optimize_stmts.rs:8:40"
  "dead_fn_elim.rs:25:40"
  "dead_store_elim.rs:45:40"
  "redundant_store_elim.rs:53:80"
  "array_len_fold.rs:10:40"
  "const_status_cond.rs:35:60"
  "copy_propagation.rs:27:40"
  "function_purity.rs:41:40"
  "test_lowering.rs:25:40"
  "string_folds.rs:11:40"
  "arith_folds.rs:11:40"
  "test_folds.rs:7:40"
  "capture_folds.rs:15:40"
  "list_folds.rs:12:40"
  "textop_folds.rs:15:40"
  "not_folds.rs:13:40"
  "const_cmp_folds.rs:14:40"
  "elim_trio.rs:22:40"
  "slice_identity.rs:10:40"
  "case_lowering.rs:29:40"
  "elseif_flatten.rs:22:40"
  "seq_range.rs:11:40"
  "ternary_desugar.rs:9:40"
  # P12 — the two VERDICT analyses with a stateable Tier-1 obligation
  # and a firing consumer. escape-classes: the census->class decision
  # (`class_of`) over the C renderer's local-vs-store predicate
  # (`c_backend.rs:9929`): Local implies unmarked (no dynamic key, no
  # whole-array position) and single-scope, so a native binding cannot
  # be defeated by an indexed access; any mark forbids Local. f32-narrow:
  # the exactness-preserving form table (`combine`'s non-literal arm) and
  # the `operand_exact` round-trip rule that decides `cdef float` /
  # `Math.fround` homes.
  "escape_classes.rs:14:40"
  "f32_narrow.rs:8:40"
  # The C generator's own Eq/Ne emission decision (c_backend.rs `expr()`
  # + `str_cmp_valued`) — the first model aimed at a RENDER decision
  # rather than a shared shIR->shIR pass. Proves the strcmp arm total,
  # the raw arm sound under both-int operands, and pins the measured
  # mixed pair (numeric-homed var vs string literal, the string-eq lift's
  # `[ "$i" = "2" ]`) as UB under the shipped two-armed decision.
  "c_eqne_emit.rs:11:40"
  # The C generator's checked i64 arithmetic tier — the overflow-flag
  # protocol of both fast arms (`__builtin_*_overflow` walk, the gated
  # commit, the spill/break escape hatches). This is C_UB_PROOF.md §2a's
  # named obligation verbatim: the ov flag is set exactly when an exact
  # result leaves i64, so the GMP escape hatch is taken only when needed
  # and whenever needed. Includes the MAX+1 negative controls (an
  # unguarded commit ships the wrapped -2^63).
  "c_checked_arith.rs:18:40"
  # The C generator's DECIMAL RENDERERS — the hand-rolled itoas it emits:
  # `_sh_ll2s` into num_temp's `static char _sN[32]`, and the inline
  # `size_t` itoa of FieldStrip/FieldStripEnd into str_temp(24). Proves
  # the two comment-claims C_UB_PROOF.md §2a/§2b name: byte-for-byte the
  # `%lld` spelling over the whole i64 domain (incl. LLONG_MIN), and the
  # write bound `strlen <= cap` for both destinations. Width theorem by
  # monotonicity + computed digit counts of 2^63 and 2^64-1. Four
  # one-token mutants, each killing a named obligation.
  "c_dec_str.rs:26:40"
  # The C generator's width-of-var / effective-widths store condition
  # (sh2perl/src/c_backend.rs `Width` + `width_of_var`/`effective_widths`
  # over `range_width_name` in sh2perl/src/shir.rs:16628). Proves the
  # store-side obligation T3 of P1_Narrowing.thy: under consistent
  # (value-covering) ranges the widen-fold admits the store; the TRUNC
  # direction (outside the declared interval is not admitted); the
  # fail-closed arms (unknown range -> I64, garbage name -> I64);
  # `arith_op_wide` fail-closed/fires; the walk skip shapes. Includes
  # the honest domain provisos (u64 arm unbounded above; else/I64 arm
  # fires past i64 — the analysis must not produce such ranges).
  "c_width_store.rs:20:40"
  # The C generator's fixed-buffer store decision
  # (sh2perl/src/c_backend.rs `buf_bound` + `emit_guarded_copy` over the
  # length analysis). Proves the store-side contract: the grown write
  # (strncpy cap=b+1 + dst[b]=0) always lands NUL-terminated in bounds
  # (exact when the source fits, truncating-but-defined otherwise); the
  # debug assert IS the fits predicate; the assert-free capture arm is
  # still never UB; the non-stringy arm never touches the pointer; all
  # three denials (numeric/capture/bigint) stay `char*`; the sha256sum
  # under-bound shape is detected (capture receiver with bound 64 still
  # renders `char*`).
  "c_buf_copy.rs:14:40"
  # The C generator's arith /% guard + num-temp/str-temp + num-spec
  # decisions (sh2perl/src/c_backend.rs `arith`'s `/`|`%` arm + `num_temp`
  # + `str_temp` + `num_spec`/`expr_type_matches` + `width_buf_len`, over
  # `arith_divisor_bounded_nonzero` in sh2perl/src/shir.rs:10914).
  # Proves: the guarded `({r} == 0 ? 0 : …)` form is total (no SIGFPE)
  # and dead exactly when the divisor is proven (positive literal or
  # bounded-nonzero); the unsigned strength-reduced arm equals the
  # signed truncating op on nonneg dividends (with the shipped -3
  # negative control); LLONG_MIN/-1 stays gated; `static char _sN[32]`
  # + `str_temp(cap)` + `width_buf_len` size every stringification
  # exactly; `num_spec`'s cast⟺%lld invariant holds with the type-match
  # rules and the 5 live unit assertions.
  "c_arith_guard.rs:15:40"
  # The C generator's operator/promotion rules
  # (sh2perl/src/c_backend.rs `const_arith_value` + LL-suffix widening +
  # `arith_bin_range_exceeds_i32` + the unsigned-gate premises
  # `arith_proven_nonneg`/`arith_fits_i64`). Proves the fold equals the
  # denotation (checked ops agree or bail -- never a wrapped constant),
  # Refuse never folds (abort preservation), LL is a pure type
  # promotion keyed on the range trigger (with the corrected 67108847
  # reading: operands fit i32, the PRODUCT range escapes it), and the
  # unsigned gate admits exactly the shapes the soundness needs
  # (untainted, known nonneg range, i64-fitting, non-u64 -- each
  # refusal arm pinned).
  "c_op_promote.rs:15:40"
  # The C generator's integer-math helpers it emits
  # (sh2perl/src/c_backend.rs `_sh_isint31` + `_sh_isqrt` + `_sh_i128_str`).
  # Proves the predicate contract (1 ==> |value| <= 2^31, each refusal arm
  # pinned, 10-digit fold exhibited step-by-step); the Newton descent
  # well-defined on the table range with exact small values by direct
  # unfolding (full floor stays open — needs the fixpoint invariant);
  # the i128 branch contract (emitted form vs identity per branch, step
  # stays in-domain, INT128_MIN refutation, 39-digit bound by generated
  # chain, sign/zero/digit contract). Honest provisos: `*` overflow is
  # the caller's gate, not 2^31 alone; the cross-branch magnitude
  # identity is solver-opaque (probed red even under nonlinear_arith).
  "c_int_helpers.rs:69:40"
  # The C generator's `_sh_*` string helpers it emits
  # (sh2perl/src/c_backend.rs `need_sh` runtime block).
  # Proves the shared b/e clamp total and in-bounds; substr byte-exact
  # with the bash sign conventions + edge arms; arr_slice element
  # semantics (same clamp over the word index) with the find/march
  # contract; replace-all first-hit splice + fuel-sufficient unfold +
  # empty-pat identity; strip pre/suf soundness (oracle consistency,
  # greedy/longest vs lazy/shortest) with the no-match identity;
  # argv slice/join soundness; split word spans + split_count.
  # Honest: vbuf growth assumed (P3); fnmatch engine is an oracle.
  "c_str_helpers.rs:40:40"
  # The C generator's capture/wrap quoting
  # (sh2perl/src/c_backend.rs `_sh_wrap_cmd` + `_sh_system_rc` +
  # `_sh_capture` + the word-quoting family). Proves injection-freedom
  # (every `'` becomes the 5-char splice; the wrapped command parses as
  # exactly `bash -c '<q(cmd)>'`), the splice shape, the word-quote
  # core, the newline gate, the status mapping (total + disjoint:
  # -1->127, exited->status, else 1), capture empty-arm + strip
  # semantics, `_sh_sc` NULL-safety, and the `"don't"`/exit-3/signal
  # pins (with the corrected length 9, found by the proof).
  # Honest: vbuf growth assumed; system/popen execution is the OS
  # contract; argv-tail gating unmodelled.
  "c_capture_wrap.rs:16:40"
  # The C generator's DECL-COVERAGE censuses — the three collect_*
  # walkers (hoist / file-scope inventory / read-routing) over
  # (sh2perl/src/c_backend.rs `collect_store_expr`, `collect_assigned_vars`,
  # `hoist_vars`), their VETO exactness, and the param/raw write bridge.
  # Proves the invariant this session's six source fixes restore: every
  # write a walker's arm-shape misses is caught by the others (coverage
  # is the union in practice and hoist alone after fixes (a)-(d)), the
  # const-lift veto set is exactly the param/raw write positions (sound
  # AND precise), and pins the measured corpus shapes (t04 params,
  # while-cond printf, elsif-cond-in-fn, return-collect, select-menu
  # param write, printf/let in fn scope). Three one-token mutants, each
  # killing a named obligation.
  "c_decl_coverage.rs:51:40"
  # The C generator's STRING-LITERAL ESCAPER (sh2perl/src/c_backend.rs
  # `cstr`, the single funnel for every emitted literal incl. printf
  # format strings). Models the C lexer as a finite-state machine over
  # one char per step (`run`/`flush`) and proves round-trip: decode of
  # the emitted literal equals the source bytes for every valid string,
  # via the per-char boundary-locality bridge. Pins the measured shapes
  # (\001a, \0019, \0017 digit followers, named escapes, marker
  # \263) and carries the SHIPPED \x hex divergences as `emit_old`
  # negative controls: 0x1a-for-2-bytes (t1), 0x19 (t5), the
  # out-of-range arm (t7). Three negative-control pins inside the file.
  "c_str_lit.rs:19:40"
  # The C generator's WRITE ARM — the `"=" | ":="` branch of the
  # `${...}` param renderer (c_backend.rs expansion emitter), with the
  # two gates that make it safe: `param_write_target` (census) and the
  # length-census supplement `supplement_write_lengths`. Extended
  # denotation: UNSET vs SET-EMPTY + provenance-carrying cells
  # (Static / Owned(word,id)). Proves the three rendered arms
  # value-correct against bash (`value_agrees`, `heap_sound`,
  # `buf_sound`, `num_sound`), the heap arm's OWNERSHIP (the xstrdup
  # adoption is what makes the scope-end free sound — mutant A drops
  # it), the bounds routing (`bump_never_shrinks` + `bound_routes`,
  # strcpy_fits under the 1024 CAP), and PINS the one known
  # normalization gap (`bare_setempty_gap`: bare `=` normalizes to
  # `:=` downstream — 0 corpus occurrences) rather than hiding it.
  # Two in-file mutants + six measured-shape pins; the source defects
  # fixed alongside (parser glue, length census, copy-prop RHS walk)
  # are C_UB_PROOF.md §24.
  "c_write_arm.rs:17:40"
  # The C backend's GROWTH-HELPER FAMILY — the emitted vbuf protocol
  # that §20/§21 listed as an assumption ("vbuf growth assumed"):
  # `_sh_grow` / `_sh_vgrow` (doubling) / `_sh_grow_str` (+zero-fill)
  # / `_sh_reserve_*` (guarded), the `_sh_add`/`_sh_addc`/`_sh_fa`
  # appends, the `snprintf_grow` loop, the vec-slot guard, and
  # `_sh_fgets_line`'s capacity/NUL discipline. Size_t arithmetic is
  # wrap-EXPLICIT (u64 = x mod 2^64), so every capacity theorem
  # carries its exact domain: fast-path identity, cap >= need after
  # growth, alloc <=> cap >= 1 <=> p non-null deref-safety,
  # byte-exact appends (the `+1` in the need), doubling termination
  # under need <= 2^63 with the amortization bound cap <= max(base,
  # 2*need), snprintf-loop termination over ANY int-typed return
  # sequence (within imax - cap + 2 calls), grow_str's zero-fill +
  # old-slot preservation, and reserve's guard=>no-wrap
  # UNCONDITIONALLY — the asymmetry A/B/C cannot claim. Pins the
  # exact wrap thresholds (2^63 stall / wrap-to-0) and carries three
  # mutants (drop the +1, drop the zero-fill, drop the reserve
  # guard) — C_UB_PROOF.md §25.
  "c_vbuf.rs:39:40"
  "c_sparse_array.rs:28:40"
  # Store-forward sweep (Tier-1): counted-loop append -> indexed store
  # (append_to_store.rs 590 lines). Per-trip + whole-loop induction
  # under the guard-verdict oracles (exactly-one site, empty init, no
  # other write, counted +1 loop, known bound, 1:1, no escapes): each
  # rewritten store at counter k pushes the same value the append
  # would. 7 unit-test pins + multi-element structural refusal +
  # runtime agreement. Mutant (no-other-write dropped) red 18v/2e.
  "append_store.rs:20:40"
  # Store-forward sweep (Tier-1): set[int] -> small/big partitions
  # (split_set.rs 958 lines). isSmallInt routing preserves set
  # semantics: membership agreement (contains_push/insert_contains
  # lemmas) + sorted-join merge agreement. 4 unit-test pins + dedup +
  # runtime agreement. Mutant (gate dropped) red 12v/2e.
  "split_set.rs:14:40"
  # Store-forward sweep (Tier-1): echo-return passes 2-4 under an
  # eligible-set parameter (echo_return.rs 1556 lines). Body echo ->
  # Return + call-site echo(fnValue) preserve statement/capture/
  # last-stage bytes and status. 6 unit-test pins + bare-shape
  # negative control. Mutant (bare fnValue at stmt) red 10v/3e.
  # Pass 1 (SCC fixpoint) + pass 4 (case-pattern hoist) are
  # parameters — SCC soundness is the verdict-analyses sweep.
  "echo_return.rs:13:40"
  # Arith-lowering sweep (Tier-1): let-arg text -> Assign/IncDec
  # arith -> Assign stmt (arith_forms.rs 489 lines). The structured
  # Assign updates the store exactly like the let-exec's evaluation;
  # the compound read-modify-write keeps the old value. 15 unit-test
  # pins. Mutant (x+=E as x=E) red 14v/1e. Fires on ((..))/let
  # shapes (14+ corpus files).
  "arith_forms.rs:15:40"
  # Arith-lowering sweep (Tier-1): init + counter-while + trailing
  # step -> ForInit (counted_while_forinit.rs 547 lines). The ForInit
  # runs the same iteration trace under the guard conjunction
  # (adjacent init, nonzero-literal step both spellings, clean prefix
  # and cond). 7 unit-test pins + trace agreement + nonzero-gate
  # load-bearing. Mutant (zero step accepted) red 12v/1e. Fires
  # 9/563 in-pipeline.
  "counted_while_forinit.rs:13:40"
  # Verdict-analyses sweep (Tier-1): SCC contract over the call graph
  # (scc.rs 450 lines). Reported sets are strongly connected,
  # disjoint, covering, and maximal (no cross-set merge); the
  # condensation is acyclic (echo_return's fixpoint termination).
  # Collect-callees walk as oracle. 6 unit-test pins + pair lemmas.
  # Mutant (merged claim across acyclic edge) red 20v/1e.
  "scc.rs:21:40"
  # Verdict-analyses sweep (Tier-1): must-defined dataflow
  # (used_before_decl.rs 1497 lines). Meet soundness, def transfer,
  # flag soundness, loop-entry fallback. Census/traversal as
  # parameters. 10 pins mirror the 11 unit tests. Mutant (union meet)
  # red 13v/2e.
  "used_before_decl.rs:15:40"
  # Verdict-analyses sweep (Tier-1): mask_threshold soundness
  # (maskable.rs 430 lines). Square bracket by compute, linear
  # inversion via lemma_mul_inequality, divisor/pow2 gates; shape
  # classifiers and isqrt as oracles. 6 unit-test pins. Mutant
  # (le-arm off-by-one) red 10v/2e.
  "maskable.rs:12:40"
  # Verdict-analyses sweep (Tier-1): span coverage + consumption
  # liveness + escape-conservatism (lifetime.rs 1190 lines). Census
  # walk as oracle. 10 pins mirror the 12 unit tests. Mutant (shrunk
  # span) red 12v/2e.
  "lifetime.rs:14:40"
  # Verdict-analyses sweep (Tier-1): seed-table consistency
  # (numstr.rs 1180 lines). Pinned stability, var/position soundness
  # under earned sets, revalidate removal-only. Fixpoint and
  # classifiers as parameters. 6 pins mirror the 10 unit tests.
  # Mutant (verdict needs no justification) red 9v/2e.
  "numstr.rs:11:40"
  # Verdict-analyses sweep (Tier-1): marked ==> all-uses-numeric
  # (numeric_observed.rs 1155 lines). Chain-veto propagation,
  # per-slot contract. Census/fixpoint as parameters. 6 pins mirror
  # the 11 unit tests. Mutant (text-observed marked) red 8v/2e.
  "numeric_observed.rs:10:40"
  # String/cursor sweep (Tier-1): Interpolate -> StrSplice
  # denotation identity (str_splice_fold.rs 372 lines). Fold-gate
  # conjunction as premises; the join-unwrap; the repl middle.
  # 8 unit-test pins + value identity. Mutant (gates dropped) red
  # 9v/2e.
  "str_splice_fold.rs:11:40"
  # String/cursor sweep (Tier-1): grab/strip cursor dynamics
  # (str_chop_cursor.rs 2253 lines). Field identity, strict advance
  # past the delimiter, init-0 default; five read-law premises as
  # oracles. 11 unit-test pins. Mutant (cursor lands on delimiter)
  # red 16v/1e.
  "str_chop_cursor.rs:17:40"
  # Loop-hoist (Tier-1): leading invariant run -> prologue
  # (hoist_loop_invariants.rs 1167 lines). Pointwise store agreement
  # under the five gates; n >= 1 proviso (the proof found a REAL
  # 0-trip soundness hole — prologue runs while the original runs
  # nothing; see BUGS_FOUND.md 7, open). 8 unit-test pins. Mutant
  # (gate without invariant_reads) red 19v/3e.
  "hoist_loop_invariants.rs:22:40"
  # Suites-then-proofs trio (Tier-1): capture-of-pure-function ->
  # direct call (direct_calls.rs 255 lines); statement cat ->
  # ForEachLine (cat_read.rs 171 lines); grep -o shapes ->
  # grepMatches (grep_o.rs 237 lines). Unit suites were written first
  # (4/6/6 green, ed4b3184f). The three models below were RE-AUTHORED
  # on 2026-10-30 after the originals were lost from the working tree
  # with the rest of the sweep files: per-rewrite value models with the
  # purity / no-redefinition premises stated as lemmas (direct_calls,
  # 19), the argv parse + line-stream obligations over the plain and
  # numbered forms (cat_read, 18), and the argv table + match
  # enumeration rename (grep_o, 19). Load-bearing guards are refuted
  # in-file (direct_calls' two premise lemmas; cat_read's argv refusals;
  # grep_o's flag/operand refusals).
  "direct_calls.rs:19:40"
  "cat_read.rs:18:40"
  "grep_o.rs:19:40"
  # Carrier-canonicalization (Tier-1): payload-free Exec in a command
  # carrier -> canonical exec call (exec_call_fold.rs 384 lines).
  # Per-site payload preservation + idempotence; carrier flag as
  # parameter; 4 unit-test pins. Mutant (cleanup refusal dropped)
  # red 7v/1e.
  "exec_call_fold.rs:8:40"
  # Part-canonicalization (Tier-1): frozen-literal Expr part -> Lit +
  # adjacent-Lit merge (interp_lit_merge.rs 494 lines). Concat
  # denotation identity via whole-seq cons lemmas; style gate as data;
  # 6 unit-test pins. Mutant (Command style folds) red 23v/1e.
  "interp_lit_merge.rs:24:40"
  # ForInit-lowering (Tier-1): ForInit -> Block(init + While) with the
  # step spliced before both continue spellings (strip.rs 307 lines).
  # Splice-shape identity over fuel-bounded loop combinators; 5
  # unit-test pins. Lands with a soundness fix (legacy continue now
  # splices). Mutant (step before Break) red 11v/2e.
  "strip.rs:13:40"
)

# extractor:baseline — the generator script and the file it must reproduce.
# Three coverage extractors (one per P3/P4/P5 model) plus the deliberately
# empty i32 slot: `verus-sync.sh` targets `arith_bounds`, a function ABSENT
# from src/ (never landed in recorded history — see VERUS.md §(a): the i32
# interval estimator was superseded by `arith_abs_bound`, proved in
# Isabelle). It correctly FATALs on the live tree, and a permanently-red
# sync entry is noise, not signal, so it stays unregistered. The coverage
# checker instead verifies live correspondence: every model pin maps to a
# source test via a committed alias table, and every mirrored guard
# predicate still exists in the source. To register another model: add
# "harness/verus-sync-coverage.sh:<model>:sh2perl/proofs/verus/<model>_sync.txt"
# (the checker dispatches on $MODEL… see check_sync_cov below) AND commit
# the generated baseline; the gate regenerates and diffs.
# (The older models are deliberate reductions, not transcriptions —
# no mechanical extractor can bridge a shrunken calculus, except through
# the same pin<->test mapping this checker enforces. Their living tie
# remains the pin<->test mapping audited in VERUS.md §(b).)
SYNCS=(
  "harness/verus-sync-coverage.sh:copy_propagation:sh2perl/proofs/verus/copy_propagation_sync.txt"
  "harness/verus-sync-coverage.sh:function_purity:sh2perl/proofs/verus/function_purity_sync.txt"
  "harness/verus-sync-coverage.sh:test_lowering:sh2perl/proofs/verus/test_lowering_sync.txt"
  "harness/verus-sync-coverage.sh:string_folds:sh2perl/proofs/verus/string_folds_sync.txt"
  "harness/verus-sync-coverage.sh:arith_folds:sh2perl/proofs/verus/arith_folds_sync.txt"
  "harness/verus-sync-coverage.sh:test_folds:sh2perl/proofs/verus/test_folds_sync.txt"
  "harness/verus-sync-coverage.sh:capture_folds:sh2perl/proofs/verus/capture_folds_sync.txt"
  "harness/verus-sync-coverage.sh:list_folds:sh2perl/proofs/verus/list_folds_sync.txt"
  "harness/verus-sync-coverage.sh:textop_folds:sh2perl/proofs/verus/textop_folds_sync.txt"
  "harness/verus-sync-coverage.sh:not_folds:sh2perl/proofs/verus/not_folds_sync.txt"
  "harness/verus-sync-coverage.sh:const_cmp_folds:sh2perl/proofs/verus/const_cmp_folds_sync.txt"
  "harness/verus-sync-coverage.sh:elim_trio:sh2perl/proofs/verus/elim_trio_sync.txt"
  "harness/verus-sync-coverage.sh:slice_identity:sh2perl/proofs/verus/slice_identity_sync.txt"
  "harness/verus-sync-coverage.sh:case_lowering:sh2perl/proofs/verus/case_lowering_sync.txt"
  "harness/verus-sync-coverage.sh:elseif_flatten:sh2perl/proofs/verus/elseif_flatten_sync.txt"
  "harness/verus-sync-coverage.sh:seq_range:sh2perl/proofs/verus/seq_range_sync.txt"
  "harness/verus-sync-coverage.sh:ternary_desugar:sh2perl/proofs/verus/ternary_desugar_sync.txt"
  "harness/verus-sync-coverage.sh:escape_classes:sh2perl/proofs/verus/escape_classes_sync.txt"
  "harness/verus-sync-coverage.sh:f32_narrow:sh2perl/proofs/verus/f32_narrow_sync.txt"
  "harness/verus-sync-coverage.sh:append_store:sh2perl/proofs/verus/append_store_sync.txt"
  "harness/verus-sync-coverage.sh:split_set:sh2perl/proofs/verus/split_set_sync.txt"
  "harness/verus-sync-coverage.sh:echo_return:sh2perl/proofs/verus/echo_return_sync.txt"
  "harness/verus-sync-coverage.sh:arith_forms:sh2perl/proofs/verus/arith_forms_sync.txt"
  "harness/verus-sync-coverage.sh:counted_while_forinit:sh2perl/proofs/verus/counted_while_forinit_sync.txt"
  "harness/verus-sync-coverage.sh:scc:sh2perl/proofs/verus/scc_sync.txt"
  "harness/verus-sync-coverage.sh:used_before_decl:sh2perl/proofs/verus/used_before_decl_sync.txt"
  "harness/verus-sync-coverage.sh:maskable:sh2perl/proofs/verus/maskable_sync.txt"
  "harness/verus-sync-coverage.sh:lifetime:sh2perl/proofs/verus/lifetime_sync.txt"
  "harness/verus-sync-coverage.sh:numstr:sh2perl/proofs/verus/numstr_sync.txt"
  "harness/verus-sync-coverage.sh:numeric_observed:sh2perl/proofs/verus/numeric_observed_sync.txt"
  "harness/verus-sync-coverage.sh:str_splice_fold:sh2perl/proofs/verus/str_splice_fold_sync.txt"
  "harness/verus-sync-coverage.sh:str_chop_cursor:sh2perl/proofs/verus/str_chop_cursor_sync.txt"
  "harness/verus-sync-coverage.sh:hoist_loop_invariants:sh2perl/proofs/verus/hoist_loop_invariants_sync.txt"
  # (direct_calls / cat_read / grep_o have no sync baseline: their
  # sources are suites-less, and a baseline without an executed pin
  # would be green-by-absence. Their model pins are recorded UNMIRRORED
  # in VERUS.md §(b).4. Re-add the three entries when a unit suite lands.)
  "harness/verus-sync-coverage.sh:exec_call_fold:sh2perl/proofs/verus/exec_call_fold_sync.txt"
  "harness/verus-sync-coverage.sh:interp_lit_merge:sh2perl/proofs/verus/interp_lit_merge_sync.txt"
  "harness/verus-sync-coverage.sh:strip:sh2perl/proofs/verus/strip_sync.txt"
  # c_decl_coverage: the FIRST TRANSCRIPTION model in this list — its
  # checker does not just pin guards, it EXTRACTS the modelled walker
  # arm chains (patterns + guards + callee sets) from c_backend.rs and
  # diffs them (harness/declcov-extract.py), closing §22's honest
  # proviso about unbridged transcriptions.
  "harness/verus-sync-coverage.sh:c_decl_coverage:sh2perl/proofs/verus/c_decl_coverage_sync.txt"
)

if [ "${1:-}" = "--list" ]; then
  echo "models:"; printf '  %s\n' "${MODELS[@]}"
  echo "syncs:"; printf '  %s\n' "${SYNCS[@]}"
  exit 0
fi
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# //;s/^#//'
  exit 0
fi

if [ ! -x "$VERUS_BIN" ]; then
  echo "verus-gate: no Verus binary at $VERUS_BIN (set VERUS_BIN) — nothing verified" >&2
  exit 2
fi
# Capture-then-match: a streamed `verus --version | grep -q` races SIGPIPE
# under load (grep exits at first match, verus dies writing the rest,
# pipefail turns that into a false negative).
verus_version=$("$VERUS_BIN" --version 2>&1 || true)
if [[ "$verus_version" != *"$PIN"* ]]; then
  echo "verus-gate: WARNING: binary is not the pinned $PIN — counts were measured with the pin" >&2
fi

pass=0; fail=0; skip=0
check_model() { # $1=entry
  # NOTE: one `local` per line — a single `local a=.. b=$a` expands every
  # word before binding anything, which trips `set -u` (bash 5.2).
  local entry="$1"
  local filespec="${entry%%:*}"
  local rest="${entry#*:}"
  local expect="${rest%%:*}"
  local rl="${rest##*:}"
  local -a files=()
  local f
  IFS='+' read -ra parts <<< "$filespec"
  for f in "${parts[@]}"; do files+=("$PV/$f"); done
  local label="${filespec//+/, }"
  local out rc n e
  out=$(timeout "$TIMEOUT" "$VERUS_BIN" --triggers-mode silent --rlimit "$rl" "${files[@]}" 2>&1) || rc=$?
  rc=${rc:-0}
  n=$(printf '%s\n' "$out" | grep -Eo '^verification results:: [0-9]+ verified' | grep -Eo '[0-9]+' | tail -1 || true)
  e=$(printf '%s\n' "$out" | grep -Eo '^verification results:: [0-9]+ verified, [0-9]+ errors?' | grep -Eo '[0-9]+ errors?' | grep -Eo '^[0-9]+' || true)
  if [ "$rc" -eq 0 ] && [ "${n:-}" = "$expect" ] && [ "${e:-}" = "0" ]; then
    echo "OK    $label — $n verified, 0 errors (expected $expect)"
    pass=$((pass+1))
  else
    echo "FAIL  $label — got '${n:-?} verified, ${e:-?} errors' rc=$rc (expected $expect verified, 0 errors)" >&2
    printf '%s\n' "$out" | tail -15 >&2
    fail=$((fail+1))
  fi
}

check_sync() { # $1=extractor $2=baseline(rel to root)
  local gen="$root/$1" base="$root/$2"
  local name="${1##*/}"
  [ -x "$gen" ] || { echo "SKIP  $name — generator not executable"; skip=$((skip+1)); return 0; }
  if [ ! -f "$base" ]; then
    echo "SKIP  $name — baseline $2 absent (Tier 1 pending, NOT green-by-absence)"
    skip=$((skip+1)); return 0
  fi
  local tmp; tmp=$(mktemp)
  local rc=0
  OUT_TMP="$tmp" "$gen" >/dev/null 2>"$tmp.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL  $name — generator errored (source outgrew the extractor?)" >&2
    tail -8 "$tmp.err" >&2; rm -f "$tmp" "$tmp.err"
    fail=$((fail+1)); return 0
  fi
  if diff -q "$base" "$tmp" >/dev/null 2>&1; then
    echo "OK    $name — baseline reproduces the live source"
    pass=$((pass+1))
  else
    echo "FAIL  $name — baseline drifted from the live source:" >&2
    diff "$base" "$tmp" 2>&1 | head -20 >&2
    fail=$((fail+1))
  fi
  rm -f "$tmp" "$tmp.err"
}

check_sync_cov() { # $1=script $2=model $3=baseline(rel to root)
  local gen="$root/$1" model="$2" base="$root/$3"
  local name="verus-sync-coverage.sh:$model"
  [ -x "$gen" ] || { echo "SKIP  $name — generator not executable"; skip=$((skip+1)); return 0; }
  if [ ! -f "$base" ]; then
    echo "SKIP  $name — baseline $3 absent (Tier 1 pending, NOT green-by-absence)"
    skip=$((skip+1)); return 0
  fi
  local tmp; tmp=$(mktemp)
  local rc=0
  # Strip the volatile sha header (source/proof revisions are tracked by
  # git, not by the manifest) before diffing: only pin/guard/count facts
  # must reproduce. A fact change still fails loudly.
  OUT_TMP="$tmp" "$gen" "$model" >/dev/null 2>"$tmp.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL  $name — generator errored (source outgrew the checker?)" >&2
    tail -8 "$tmp.err" >&2; rm -f "$tmp" "$tmp.err"
    fail=$((fail+1)); return 0
  fi
  if diff <(command grep -v "^# source sha:" "$base") <(command grep -v "^# source sha:" "$tmp") >/dev/null 2>&1; then
    echo "OK    $name — pin/guard facts reproduce the live source"
    pass=$((pass+1))
  else
    echo "FAIL  $name — correspondence drifted from the live source:" >&2
    diff <(command grep -v "^# source sha:" "$base") <(command grep -v "^# source sha:" "$tmp") 2>&1 | head -20 >&2
    fail=$((fail+1))
  fi
  rm -f "$tmp" "$tmp.err"
}

echo "== verus-gate: models =="
for m in "${MODELS[@]}"; do check_model "$m"; done
echo "== verus-gate: sync =="
if [ "${#SYNCS[@]}" -eq 0 ]; then
  echo "(no sync extractors registered)"
fi
for s in "${SYNCS[@]}"; do
  # three-field entries (script:model:baseline) go to the coverage driver;
  # two-field entries (script:baseline) to the legacy regenerating driver.
  rest="${s#*:}"
  if [[ "$rest" == *:* ]]; then
    check_sync_cov "${s%%:*}" "${rest%%:*}" "${rest##*:}"
  else
    check_sync "${s%%:*}" "$rest"
  fi
done
echo "verus-gate: $pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
