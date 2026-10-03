#!/usr/bin/env bash
# pg-class.sh — one line per example: the FIRST line of the generated Perl's
# runtime stderr (the usual root-cause signal: a Perl compile error, a
# die-on-unsupported, an ambiguous-subname warning that changes behavior).
# Groups nothing; it just hands back the error text for triage.
#
#   harness/pg-class.sh <ex1.sh> <ex2.sh> ...      (or names on stdin)
set -u
root=/home/llm/sh2loop
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
[ $# -gt 0 ] || set -- $(cat)
cd "$root/sh2perl/examples" || exit 1
for ex in "$@"; do
  t="$ex"; [ -f "$t" ] || t="$ex.sh"
  d=$(mktemp -d /tmp/pgclass.XXXXXX)
  timeout 20 "$CLI" --target pl "$t" >"$d/t.pl" 2>/dev/null
  ( setsid timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$t" "$d/t.pl" >"$d/p.out" 2>"$d/p.err" )
  printf '%-52s ' "$ex"
  head -1 "$d/p.err" | cut -c1-150
  echo "  (dir $d)"
  rm -rf "$d"
done
