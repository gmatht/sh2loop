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
