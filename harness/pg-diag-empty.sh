#!/usr/bin/env bash
# Diagnostic sweep over the "silent" failure class: the generated Perl
# produces NO output, so the cause is not a formatting bug. For each example,
# report the generator's own stderr, perl -c status, and the runtime stderr.
#   harness/pg-diag-empty.sh <name>...
set -uo pipefail
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cli="$root/otranspilerl/target/debug/otranspilerl-cli"

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

for n in "$@"; do
  ex="$root/sh2perl/examples/$n"
  [ -f "$ex" ] || { echo "== $n MISSING"; continue; }
  d=$(mktemp -d "/tmp/pgdiag.${n}.XXXXXX")
  timeout 60 sh -c "\"$cli\" --target pl \"$ex\" 2>\"$d/gen.err\"" > "$d/test.pl"
  rc=$?
  echo "== $n  (gen rc=$rc, pl bytes=$(wc -c <"$d/test.pl"))"
  [ -s "$d/gen.err" ] && { echo "   -- gen.err:"; head -3 "$d/gen.err" | sed 's/^/      /'; }
  if ! perl -M5.010 -c "$d/test.pl" >/dev/null 2>"$d/c.err"; then
    echo "   -- COMPILE ERROR:"; head -3 "$d/c.err" | sed 's/^/      /'
  fi
  bash "$ex" >"$d/bash.out" 2>/dev/null; bexit=$?
  timeout 60 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
    "$ex" "$d/test.pl" >"$d/perl.out" 2>"$d/perl.err"; pexit=$?
  echo "   exit bash=$bexit perl=$pexit | stdout bash=$(wc -c <"$d/bash.out") perl=$(wc -c <"$d/perl.out")"
  if [ -s "$d/perl.err" ]; then
    echo "   -- perl.err:"; head -4 "$d/perl.err" | sed 's/^/      /'
  fi
  echo "   $d"
done
