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
