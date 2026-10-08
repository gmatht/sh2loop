#!/bin/bash
# Reproduce one corpus example through the perl generator and diff.
# Usage: harness/pg-repro.sh <example-name.sh> [--show]
# Mirrors ./fail's pipeline: otranspilerl --target pl -> perl -M5.010 -> compare
# stdout+exit against bash.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EX="$ROOT/sh2perl/examples/$1"
[ -f "$EX" ] || { echo "no such example: $EX"; exit 2; }
NAME=$(basename "$EX")
T=$(mktemp -d /tmp/pgrepro.XXXXXX)
trap 'rm -rf "$T"' EXIT

SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so" \
SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so" \
UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall" \
  timeout 20 "$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target pl "$EX" > "$T/gen.pl" 2>"$T/gen.err"
if [ $? -ne 0 ]; then echo "GEN FAILED"; cat "$T/gen.err"; exit 1; fi

if command grep -qE "system\('bash',\s*'[^']*'\)" "$T/gen.pl"; then echo "PARSER FALLBACK (bash wrapper)"; exit 1; fi

(cd "$T" && timeout 20 bash "$EX" > "$T/bash.out" 2>/dev/null); bexit=$?
(cd "$T" && timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$EX" "$T/gen.pl" > "$T/pl.out" 2>"$T/pl.err"); pexit=$?

echo "bash exit=$bexit  perl exit=$pexit"
if cmp -s "$T/bash.out" "$T/pl.out"; then
  echo "STDOUT MATCH"
else
  echo "STDOUT MISMATCH:"
  diff <(cat -A "$T/bash.out") <(cat -A "$T/pl.out") | head -60
fi
[ -s "$T/pl.err" ] && { echo "--- perl stderr:"; head -10 "$T/pl.err"; }
if [ "${2:-}" = "--show" ]; then echo "=== generated perl:"; cat -n "$T/gen.pl"; fi
exit 0
