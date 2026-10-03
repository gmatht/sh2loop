#!/bin/bash
# pg-two.sh <case> — verify the generated Perl for ONE example matches bash
# byte-for-byte AND on exit code. Unlike harness/pg-one.sh this does not treat
# a non-zero exit code as a pass: ./fail compares stdout bytes AND `bash`'s exit
# code, and the `$?` propagation class only shows up when the exit code is
# checked too. pg-one.sh was reporting 8 of the 50 as passing for that reason.
#
# Usage: harness/pg-two.sh 063_11_complex_while_loop
set -u
ROOT=/home/llm/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
name="${1:?usage: $0 <example-basename>}"
EX="$ROOT/sh2perl/examples/$name.sh"
[ -f "$EX" ] || { echo "no such example: $EX"; exit 2; }

TMP=$(mktemp -d /tmp/pgtwo-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$CLI" --target pl "$EX" > "$TMP/t.pl" 2>"$TMP/gen.err"
if [ $? -ne 0 ]; then echo "GEN FAILED"; head -5 "$TMP/gen.err"; exit 1; fi
if grep -qE "system\('bash', *'[^']*'\)" "$TMP/t.pl"; then
  echo "PARSER FALLBACK (bash wrapper)"; exit 1
fi
if ! perl "$ROOT/check_qx.pl" "$TMP/t.pl" > "$TMP/qx.out" 2>/dev/null; then
  echo "CHECK_QX FAIL: $(grep -m1 FAIL "$TMP/qx.out")"
fi

setsid timeout -k 2 20 bash "$EX" > "$TMP/bash.out" 2>"$TMP/bash.err"; brc=$?
setsid timeout -k 2 20 perl -M5.010 -e \
  '$0 = shift @ARGV; my $f = shift @ARGV; do $f' "$EX" "$TMP/t.pl" \
  > "$TMP/pl.out" 2>"$TMP/pl.err"; prc=$?

ok=1
[ "$brc" != "$prc" ] && { ok=0; echo "  exit: bash=$brc perl=$prc"; }
if ! cmp -s "$TMP/bash.out" "$TMP/pl.out"; then
  ok=0
  echo "  --- diff (bash < | > perl) ---"
  diff -u "$TMP/bash.out" "$TMP/pl.out" | head -30
fi
[ -s "$TMP/pl.err" ] && { echo "  --- perl stderr ---"; head -6 "$TMP/pl.err"; }
if [ "$ok" = 1 ]; then echo "PASS $name (exit $brc)"; exit 0; fi
echo "FAIL $name"
[ "${KEEP:-0}" = 1 ] && echo "  kept: $TMP"
exit 1