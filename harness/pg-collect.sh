#!/bin/bash
# Collect the bash-vs-perl diff for every failing example, into one file per
# example under $OUT, plus a one-line shape summary, so a failure list can be
# clustered by root cause instead of guessed at.
#
# Usage: harness/pg-collect.sh <file-with-one-example-per-line> [outdir]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIST=$1
OUT=${2:-/tmp/pgcollect}
rm -rf "$OUT"; mkdir -p "$OUT"
: > "$OUT/_summary.tsv"
while read -r name; do
  case "$name" in ''|'#'*) continue ;; esac
  n=${name%.sh}
  ex="$ROOT/sh2perl/examples/$n.sh"
  [ -f "$ex" ] || continue
  if ! "$ROOT/harness/pg-one.sh" "$n.sh" --diff > "$OUT/$n.txt" 2>&1; then :; fi
  if command grep -q 'STDOUT: MATCH' "$OUT/$n.txt"; then
    printf '%s\tPASS\n' "$n" >> "$OUT/_summary.tsv"
    continue
  fi
  ex_line=$(command grep -o 'bash exit=[0-9]* *perl exit=[0-9]*' "$OUT/$n.txt" | head -1)
  bc=$(echo "$ex_line" | sed -n 's/.*perl exit=\([0-9]*\).*/\1/p')
  # classify the shape: first differing line pair, normalised
  shape=$(sed -n '/^@@/,$p' "$OUT/$n.txt" | grep -E '^[-+]' | grep -vE '^(\+\+\+|---)' | head -2 \
          | tr '\n' '|' | cut -c1-160)
  printf '%s\tFAIL\t%s\t%s\n' "$n" "$bc" "$shape" >> "$OUT/_summary.tsv"
done < "$LIST"
echo "wrote $OUT/_summary.tsv"
