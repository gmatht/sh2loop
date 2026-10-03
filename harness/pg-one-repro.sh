#!/usr/bin/env bash
# Reproduce ONE corpus example through the same path ./fail uses:
#   otranspilerl-cli --target pl  ->  perl (argv0 = source path)   vs   bash
# Prints bash/perl stdout+exit side by side and a unified diff.
# Usage: harness/pg-one-repro.sh <example-basename> [--keep]
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
name=$1
keep=${2:-}
ex="$root/sh2perl/examples/$name"
[ -f "$ex" ] || { echo "no such example: $ex" >&2; exit 2; }

# pid-suffixed scratch: an exit trap must never remove another process's dir
d=$(mktemp -d "${TMPDIR:-/tmp}/pg-one.XXXXXX")
trap 'command grep -q . "$d"/*.pl 2>/dev/null || true; [ -n "$keep" ] || rm -rf "$d"' EXIT

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$root/otranspilerl/target/debug/otranspilerl-cli" --target pl "$ex" >"$d/test.pl" 2>"$d/gen.err"
gen_rc=$?
if [ $gen_rc -ne 0 ] || [ ! -s "$d/test.pl" ]; then
  echo "== GENERATOR FAILED rc=$gen_rc"
  sed -n '1,20p' "$d/gen.err"
  exit 3
fi

bash "$ex" >"$d/bash.out" 2>"$d/bash.err"; bash_rc=$?
perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$ex" "$d/test.pl" \
  >"$d/perl.out" 2>"$d/perl.err"; perl_rc=$?

echo "== bash exit=$bash_rc   perl exit=$perl_rc"
if cmp -s "$d/bash.out" "$d/perl.out" && [ "$bash_rc" = "$perl_rc" ]; then
  echo "== PASS (stdout identical, exit identical)"
  exit 0
fi

echo "== bash stdout ($(wc -c <"$d/bash.out") bytes) | perl stdout ($(wc -c <"$d/perl.out") bytes)"
echo "---- first diff ----"
diff -u "$d/bash.out" "$d/perl.out" | sed -n '1,40p'
if [ -s "$d/perl.err" ]; then
  echo "---- perl stderr (first 15) ----"
  sed -n '1,15p' "$d/perl.err"
fi
[ -n "$keep" ] && echo "== kept: $d"
exit 1