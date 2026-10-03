#!/usr/bin/env bash
# pg-case.sh — reproduce ONE perl-generator corpus case the way ./fail does.
#
#   harness/pg-case.sh <example.sh> [--keep] [--target pl]
#
# Reproduces the ./fail pipeline exactly for a single test: transpile, run
# check_qx, run the generated perl, run bash, compare stdout byte-for-byte,
# compare exit codes, and print a side-by-side diff. Exits 0 on match.
#
# This is the fast inner loop: ./fail is a 555-example, multi-minute run;
# this is one example, ~1s. The failure list is triaged with it.
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
target=pl
keep=0
declare -a examples=()

for arg in "$@"; do
  case "$arg" in
    --keep)   keep=1 ;;
    --target) target="${2:-pl}"; shift ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *)  examples+=("$arg") ;;
  esac
done

if [ ${#examples[@]} -eq 0 ]; then
  echo "usage: harness/pg-case.sh <example.sh> [--keep] [--target pl]" >&2
  exit 2
fi

# Work inside a private scratch dir so a case that litters /tmp does not
# collide with a concurrent gate's, and so --keep is explicit about litter.
work=$(mktemp -d "$COMMANDCODE_SCRATCHPAD/pgcase-XXXXXX" 2>/dev/null || mktemp -d /tmp/pgcase-XXXXXX)
cleanup() { [ "$keep" = 1 ] || rm -rf "$work"; }
trap cleanup EXIT

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_LIB_PIPELINE="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

# The gate's env: the generated programs call bash-isms (grep/printf/...) the
# same way ./fail does. Keep the pipeline vars names as in ./fail.
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"

status=0
for ex in "${examples[@]}"; do
  name=$(basename "$ex")
  # ./fail runs: otranspilerl --target pl <file>
  if ! "$CLI" --target "$target" "$ex" > "$work/gen.pl" 2> "$work/gen.err"; then
    echo "=== $name: GENERATION FAILED"
    tail -5 "$work/gen.err"
    status=1
    continue
  fi

  # ./fail's fallback guard is a regex over the WHOLE stdout, but the only
  # place a real bash wrapper is ever emitted is the parser-unparseable
  # fallback in main.rs, which wraps the SOURCE PATH. Match the same shape
  # (a bare quoted path, no -c) so this helper does not report false
  # fallbacks on the __SH_RUN_EXT preamble, whose own `system('bash','-c',…)`
  # is a legitimate, stripped-before-scanning runner seam.
  if grep -qE "system\('bash', *'[^']+'\)" "$work/gen.pl"; then
    echo "=== $name: PARSER FALLBACK (bash wrapper) — generator never ran"
    status=1
    continue
  fi

  if [ -f "$root/check_qx.pl" ]; then
    if ! perl "$root/check_qx.pl" "$work/gen.pl" > "$work/qx.out" 2>&1; then
      echo "=== $name: check_qx VIOLATION"
      grep -m3 FAIL "$work/qx.out"
      status=1
      continue
    fi
  fi

  # $0 = source path (argv0 pass-through), @ARGV emptied, 5.010 features.
  perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
    "$ex" "$work/gen.pl" > "$work/perl.out" 2> "$work/perl.err"
  perl_exit=$?

  bash "$ex" > "$work/bash.out" 2> "$work/bash.err"
  bash_exit=$?

  if cmp -s "$work/perl.out" "$work/bash.out" && [ "$perl_exit" = "$bash_exit" ]; then
    echo "=== $name: PASS"
    continue
  fi

  echo "=== $name: FAIL (exit bash=$bash_exit perl=$perl_exit)"
  echo "--- stdout diff (bash vs perl) ---"
  diff "$work/bash.out" "$work/perl.out" | head -40
  if [ -s "$work/perl.err" ]; then
    echo "--- perl stderr ---"
    head -15 "$work/perl.err"
  fi
  if [ -s "$work/bash.err" ]; then
    echo "--- bash stderr ---"
    head -5 "$work/bash.err"
  fi
  status=1
done

exit $status
