#!/usr/bin/env bash
# Render the whole corpus through the perl backend and tally check_qx
# violations by (builtin, file). Prints a sorted frequency table.
# Usage: qx-tally.sh [max_files]
set -uo pipefail
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
WT=$ROOT/sh2perl/backends/perl
R=$ROOT/otranspilerl/target/debug/otranspilerl-cli
G=$WT/target/debug/shir_render
OUT=${1:-/tmp/qx-tally}
MAX=${2:-0}

corpus=$(ls "$ROOT"/sh2perl/examples/*.sh "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)
rm -rf "$OUT"; mkdir -p "$OUT"
n=0
for f in $corpus; do
  n=$((n+1))
  if [ "$MAX" -gt 0 ] && [ "$n" -gt "$MAX" ]; then break; fi
  b=$(basename "$f")
  shir=$("$R" --target shir "$f" 2>/dev/null) || continue
  [ -z "$shir" ] && continue
  bash -n "$f" 2>/dev/null || continue
  printf '%s' "$shir" | "$G" --target=perl - > "$OUT/$b.pl" 2>/dev/null || continue
done
echo "rendered $n corpus files into $OUT"