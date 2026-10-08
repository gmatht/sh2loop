#!/bin/bash
# Classify the perl-generator corpus failures: for each, generate the Perl,
# run it, and print the first diff hunk + first perl stderr line. The point is
# to see the failure CLASSES, not 56 separate diffs.
#
# Usage: harness/pg-classify.sh [outdir]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT=${1:-/tmp/pgclass}
mkdir -p "$OUT/gen" "$OUT/run"
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

one() {
  local ex="$1" n d
  n=$(basename "$ex" .sh); d="$OUT/run/$n"
  [ -f "$OUT/gen/$n.pl" ] && return
  mkdir -p "$d"
  ( cd "$d" && timeout 20 bash "$ex" >bash.out 2>bash.err ); echo $? >"$d/bash.exit"
  timeout 20 "$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target pl "$ex" \
      >"$OUT/gen/$n.pl" 2>"$OUT/gen/$n.err"
  if [ $? -ne 0 ]; then echo GENFAIL >"$d/verdict"; return; fi
  if command grep -qE "system\('bash',\s*'[^']*'\)" "$OUT/gen/$n.pl"; then echo FALLBACK >"$d/verdict"; return; fi
  ( cd "$d" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' \
      "$ex" "$OUT/gen/$n.pl" >pl.out 2>pl.err ); echo $? >"$d/pl.exit"
  local v=PASS
  cmp -s "$d/bash.out" "$d/pl.out" || v=OUT
  [ "$(cat "$d/bash.exit")" = "$(cat "$d/pl.exit")" ] || v="$v+EXIT"
  echo "$v" >"$d/verdict"
}
export -f one
export ROOT OUT

# Corpus = every example, or just the names in a file (PG_ONLY=<file>).
if [ -n "${PG_ONLY:-}" ]; then
  sed 's#.*/##' "$PG_ONLY" | sed 's/\.sh$//' | sed "s#^#$ROOT/sh2perl/examples/#; s#\$#.sh#" \
    | xargs -P 8 -I{} bash -c 'one "$@"' _ {}
else
  ls "$ROOT/sh2perl/examples"/*.sh | xargs -P 8 -I{} bash -c 'one "$@"' _ {}
fi

echo "=== verdict counts"
cat "$OUT"/run/*/verdict | sort | uniq -c | sort -rn
echo
echo "=== failures: <verdict> <name>  ||  <stderr-or-diff>"
for d in "$OUT"/run/*/; do
  v=$(cat "$d/verdict"); [ "$v" = PASS ] && continue
  n=$(basename "$d")
  err=$(head -1 "$d/pl.err" 2>/dev/null | cut -c1-100)
  d1=$(diff "$d/bash.out" "$d/pl.out" 2>/dev/null | sed -n '2,3p' | cut -c1-100 | tr '\n' '|')
  printf '%-10s %-46s %s\n' "$v" "$n" "${err:-$d1}"
done
echo "(outdir $OUT)"
