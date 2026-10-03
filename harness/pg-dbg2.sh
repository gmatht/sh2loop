#!/usr/bin/env bash
# Fast per-example reproducer for the Perl generator.
#   pg-dbg2.sh <example.sh> [example.sh ...]
# Prints: gen status, check_qx status, diff of expected(bash) vs actual(perl).
set -u
root=/home/llm/sh2loop
ot=$root/otranspilerl/target/debug/otranspilerl-cli
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

for ex in "$@"; do
  case "$ex" in
    /*) src=$ex ;;
    *)  src=$(ls "$root"/sh2perl/backends/perl/examples/"$ex" \
                 "$root"/sh2perl/examples/"$ex" 2>/dev/null | head -1) ;;
  esac
  [ -n "$src" ] && [ -f "$src" ] || { echo "== $ex: NOT FOUND"; continue; }
  name=$(basename "$src")
  d=$(mktemp -d "/tmp/pgd.${name}.XXXXXX")

  timeout 25 "$ot" --target pl "$src" >"$d/test.pl" 2>"$d/gen.err"
  gs=$?
  if [ $gs -ne 0 ] || [ ! -s "$d/test.pl" ]; then
    echo "== $name: GEN FAILED (exit $gs)"; sed 's/^/    /' "$d/gen.err" | head -5
    echo "    dir=$d"; continue
  fi
  # same marker the gate greps (fail line 175): system('bash', '<path>')
  if grep -qE "system\('bash',\s*'[^']*'\)" "$d/test.pl"; then
    echo "== $name: PARSER FALLBACK (bash wrapper)"; echo "    dir=$d"; continue
  fi

  qx=ok
  if [ -f "$root/check_qx.pl" ]; then
    timeout 25 perl "$root/check_qx.pl" "$d/test.pl" >"$d/qx.out" 2>/dev/null
    [ $? -ne 0 ] && qx=FAIL
  fi

  # bash reference
  ( cd "$d" && timeout 25 bash "$src" >"$d/bash.out" 2>"$d/bash.err" ); bexit=$?
  # perl generated
  ( cd "$d" && timeout 25 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$src" "$d/test.pl" >"$d/perl.out" 2>"$d/perl.err" ); pexit=$?

  echo "== $name: gen=ok qx=$qx bash_exit=$bexit perl_exit=$pexit"
  if ! cmp -s "$d/bash.out" "$d/perl.out" || [ "$bexit" != "$pexit" ]; then
    echo "    dir=$d"
    diff -u "$d/bash.out" "$d/perl.out" 2>&1 | head -"${DIFFLINES:-40}" | sed 's/^/    /'
    [ -s "$d/perl.err" ] && { echo "    -- perl stderr --"; sed 's/^/    /' "$d/perl.err" | head -8; }
  fi
done