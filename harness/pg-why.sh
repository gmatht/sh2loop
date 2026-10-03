#!/usr/bin/env bash
# pg-why.sh — for each named example, print the generator's stderr and the
# generated Perl's runtime stderr. Diagnostic only; the gate stays ./fail.
#
#   harness/pg-why.sh <ex1.sh> <ex2.sh> ...
set -u
root=/home/llm/sh2loop
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"

for ex in "$@"; do
  t="$root/sh2perl/examples/$ex"; [ -f "$t" ] || t="$ex"
  d=$(mktemp -d /tmp/pgwhy.XXXXXX)
  ( cd "$root/sh2perl/examples" && setsid timeout -k 2 20 bash "$t" >"$d/b.out" 2>"$d/b.err" ); brc=$?
  timeout 20 "$CLI" --target pl "$t" >"$d/t.pl" 2>"$d/gen.err"; grc=$?
  ( cd "$root/sh2perl/examples" && setsid timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$t" "$d/t.pl" >"$d/p.out" 2>"$d/p.err" ); prc=$?

  echo "==================== $ex  gen=$grc bash=$brc perl=$prc  bytes b=$(wc -c <"$d/b.out") p=$(wc -c <"$d/p.out")"
  [ -s "$d/p.err" ] && { echo "--- perl stderr ---"; head -6 "$d/p.err"; }
  [ -s "$d/gen.err" ] && { echo "--- gen stderr ---"; head -4 "$d/gen.err"; }
  echo "dir: $d"
done
