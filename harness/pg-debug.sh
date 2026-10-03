#!/usr/bin/env bash
# Keep a generated perl program around and re-run it under a debug harness, so
# a class can be traced with print/strace instead of guessed at from the diff.
#
#   harness/pg-debug.sh <example.sh>
#
# Emits:
#   /tmp/pgdbg-<name>.pl   the generated program
#   /tmp/pgdbg-<name>.out  stdout + stderr of the run, interleaved
# Exits with the perl exit code so a class can be reproduced standalone.
set -u
ROOT=/home/llm/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
EX="$1"
[ -n "$EX" ] || { echo "usage: $0 <example.sh>"; exit 2; }
case "$EX" in
  /*) ;;
  */*) EX="$ROOT/$EX" ;;
  *)   EX="$ROOT/sh2perl/examples/$EX" ;;
esac
[ -f "$EX" ] || { echo "no such example: $EX"; exit 2; }
name=$(basename "$EX" .sh)
out="/tmp/pgdbg-$name"

export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$CLI" --target pl "$EX" > "$out.pl" || { echo "GEN FAILED"; exit 1; }

echo "== bash reference =="
( cd "$(dirname "$EX")" && setsid timeout -k 2 20 bash "./$(basename "$EX")" ) 2>&1 | sed 's/^/  bash| /'
echo "  bash rc=${PIPESTATUS[0]:-?}"

echo "== perl =="
perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$EX" "$out.pl" 2>&1 | sed 's/^/  pl  | /'
rc=${PIPESTATUS[0]}
echo "  perl rc=$rc"
echo
echo "program: $out.pl   (edit it and re-run with: perl -M5.010 -e '\$0=shift; do shift' '$EX' '$out.pl')"
exit "$rc"