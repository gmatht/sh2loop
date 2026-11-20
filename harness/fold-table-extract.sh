#!/usr/bin/env bash
# fold-table-extract.sh — emit the fold table that optimize_fold.rs models,
# read out of the live source (sh2perl/src/ir.rs).
#
#   OUT_TMP=/tmp/x ./harness/fold-table-extract.sh >/dev/null
#
# Why: optimize_fold.rs is a transcription of `fold_bin_op` / `fold_un_op`
# (and `pow_wrapping`'s shape). The coverage checker cannot bridge that —
# the fold tables have no unit suite to pin against — so this extractor
# emits the table itself: every arm's op literal, guard and body, plus the
# model arm each op maps to. The gate diffs the output against
# sh2perl/proofs/verus/optimize_fold_sync.txt, so a new/renamed/reguarded
# arm in the source fails until the model (and this map) is updated.
#
# This is drift detection, not code generation: the model's arms are
# still written by hand because Rust's `wrapping_*` ops and Verus spec
# integers do not share a source language. VERUS.md records that limit.
#
# Exit: 0 table emitted; 1 a mapped op vanished from the source or the
# model (the extractor outgrew the change — fix the map, do not hand-edit
# the baseline).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$root/sh2perl/src/ir.rs"
MODEL="$root/sh2perl/proofs/verus/optimize_fold.rs"
OUT="${OUT_TMP:-/dev/stdout}"

fail() { echo "fold-table-extract: FATAL: $*" >&2; exit 1; }

[ -f "$SRC" ] || fail "missing source $SRC"
[ -f "$MODEL" ] || fail "missing model $MODEL"

# Extract every literal-op match arm of one function: op, guard, body.
arms() { # $1 = "fn name" marker, $2 = next fn marker
  awk -v a="$1" -v b="$2" '
    $0 ~ a { inside = 1; next }
    $0 ~ b { inside = 0 }
    inside && /^ *"[^"]+"( if .*)? => / {
      line = $0
      sub(/^ +/, "", line)
      sub(/,$/, "", line)
      # squeeze interior whitespace so a reflow does not read as drift
      gsub(/[ \t]+/, " ", line)
      print line
    }
  ' "$SRC"
}

# op literal -> model arm, the same names optimize_fold.rs uses.
model_arm() {
  case "$1" in
    "+") echo "Op::Add" ;;
    "-") echo "Op::Sub" ;;
    "*") echo "Op::Mul" ;;
    "/") echo "Op::Div" ;;
    "%") echo "Op::Mod" ;;
    "**") echo "Op::Pow" ;;
    "&") echo "Op::BitAnd" ;;
    "|") echo "Op::BitOr" ;;
    "^") echo "Op::BitXor" ;;
    "<<") echo "Op::Shl" ;;
    ">>") echo "Op::Shr" ;;
    "&&") echo "Op::And" ;;
    "||") echo "Op::Or" ;;
    *) echo "Op::Unknown" ;;
  esac
}

{
  echo "# optimize_fold table — GENERATED from sh2perl/src/ir.rs; do not edit."
  echo "# Regenerate: OUT_TMP=<file> harness/fold-table-extract.sh >/dev/null"
  echo
  bin="$(arms '^fn fold_bin_op' '^fn fold_un_op')"
  un="$(arms '^fn fold_un_op' 'fn fold_arith_ast')"
  [ -n "$bin" ] || fail "no arms extracted from fold_bin_op"
  [ -n "$un" ] || fail "no arms extracted from fold_un_op"

  echo "[bin] fold_bin_op"
  while IFS= read -r line; do
    printf 'arm %s\n' "$line"
  done <<< "$bin"
  echo
  echo "[un] fold_un_op"
  while IFS= read -r line; do
    printf 'arm %s\n' "$line"
  done <<< "$un"
  echo
  echo "[model] op -> arm (presence checked)"
  while IFS= read -r line; do
    op="$(printf '%s' "$line" | sed -E 's/^"([^"]+)".*/\1/')"
    arm="$(model_arm "$op")"
    command grep -q -- "$arm =>" "$MODEL" \
      || fail "source arm $op has no model arm $arm in optimize_fold.rs"
    printf 'op %s -> %s: present\n' "$op" "$arm"
  done <<< "$bin"
} > "$OUT" || exit 1

# Shape facts of pow_wrapping: the loop the pow_sq model mirrors.
command grep -q 'while e > 0' "$SRC" || fail "pow_wrapping loop shape changed (while e > 0)"
command grep -q 'acc = acc.wrapping_mul(b)' "$SRC" || fail "pow_wrapping accumulator multiply changed"
command grep -q 'b = b.wrapping_mul(b)' "$SRC" || fail "pow_wrapping squaring changed"
echo "guard pow_wrapping squaring shape: PRESENT" >> "$OUT"
command grep -q "ArithAst::Cond { test" "$SRC" || fail "fold_arith_ast Cond arm missing"
echo "guard fold_arith_ast cond recursion: PRESENT" >> "$OUT"
