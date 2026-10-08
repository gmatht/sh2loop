#!/usr/bin/env bash
# pg-triage-all.sh — run harness/pg-one.sh over every FAIL in a gate run and
# bucket each one into a CLASS, so "fix the biggest class" is a decision the
# harness answers instead of a guess.
#
#   harness/pg-triage-all.sh [gate-out] [outdir]
#
# Defaults to .perlgen-gate.out (what run_perl_generator_worker.sh classifies).
# Per-example artifacts land in the outdir; classes.tsv is
# class <TAB> bash_rc <TAB> perl_rc <TAB> example, sorted deterministically.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
GATE="${1:-$ROOT/.perlgen-gate.out}"
OUT="${2:-$ROOT/tmp_run/pg-triage-all}"
PAR="${PG_TRIAGE_PAR:-4}"
mkdir -p "$OUT"

# Sorted by name: the outdir is committed as triage evidence in some runs, and
# an unstable order would make every rerun a noisy diff.
command grep '  FAIL:' "$GATE" \
  | sed -e 's/^  FAIL: //' -e 's/ \[perl\].*$//' \
  | sort -u > "$OUT/names.txt"
echo "== $(wc -l < "$OUT/names.txt") examples from $GATE -> $OUT"

one() {
  local ex="$1"
  # A few examples fork a producer that outlives the 20s cap (096), so the
  # per-example budget is bounded well above it: one hung example must not
  # stall the sweep.
  timeout 120 "$ROOT/harness/pg-one.sh" "$ex" --diff > "$OUT/$ex.txt" 2>&1
  echo "harness_rc=$?" >> "$OUT/$ex.txt"
}
export -f one
export ROOT OUT

xargs -a "$OUT/names.txt" -P "$PAR" -I{} bash -c 'one "$@"' _ {}

: > "$OUT/classes.tsv"
while read -r ex; do
  f="$OUT/$ex.txt"
  if [ ! -f "$f" ]; then
    printf '%s\t%s\t%s\t%s\n' "harness-aborted" - - "$ex" >> "$OUT/classes.tsv"
    continue
  fi
  bash_rc=$(command grep -o 'bash exit=[0-9]*' "$f" | head -1 | cut -d= -f2)
  pl_rc=$(command grep -o 'perl exit=[0-9]*' "$f" | head -1 | cut -d= -f2)
  if [ -z "$bash_rc" ] || [ -z "$pl_rc" ]; then
    cls="no-verdict (generation failed)"
  elif [ "$bash_rc" != "$pl_rc" ]; then
    cls="exit-code ${bash_rc}->${pl_rc}"
  elif command grep -q 'perl stderr:' "$f"; then
    cls="perl-runtime-error"
  elif command grep -q 'STDOUT: MISMATCH' "$f"; then
    cls="stdout-mismatch"
  else
    cls="other"
  fi
  printf '%s\t%s\t%s\t%s\n' "$cls" "${bash_rc:--}" "${pl_rc:--}" "$ex" >> "$OUT/classes.tsv"
done < "$OUT/names.txt"

echo
echo "== class counts =="
cut -f1 "$OUT/classes.tsv" | sort | uniq -c | sort -rn
echo
echo "== per example: class <TAB> bash_rc <TAB> perl_rc <TAB> example =="
sort -t"$(printf '\t')" -k4,4 "$OUT/classes.tsv"
echo
echo "artifacts: $OUT"