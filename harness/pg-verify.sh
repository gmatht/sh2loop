#!/bin/bash
# Unit-test harness for the textual post-pass fixes in perl_generator_fixed
# that live in the sh2perl crate. `cargo test` covers the pure functions;
# this script checks the END-TO-END shape (generate → run → byte compare) for
# named corpus examples, so a fix that compiles but never fires is caught.
#   usage: harness/pg-verify.sh <example.sh> [example.sh ...]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
pass=0; fail=0
for n in "$@"; do
  ex="$ROOT/sh2perl/examples/$n"
  [ -f "$ex" ] || ex="$ex.sh"
  d=$(mktemp -d /tmp/pgv-XXXXXX)
  export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
  export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
  export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"
  if ! "$CLI" --target pl "$ex" >"$d/t.pl" 2>"$d/g.err"; then
    printf 'FAIL %-46s GENFAIL %s\n' "$n" "$(head -1 "$d/g.err")"; fail=$((fail+1)); rm -rf "$d"; continue
  fi
  if ! perl -c "$d/t.pl" >/dev/null 2>"$d/s.err"; then
    printf 'FAIL %-46s SYNTAX  %s\n' "$n" "$(sed -n '2p' "$d/s.err" | sed "s|$d/t.pl|GEN|")"
    fail=$((fail+1)); rm -rf "$d"; continue
  fi
  ( cd "$d" && setsid timeout -k 2 20 bash "$ex" ) >"$d/b.out" 2>/dev/null; brc=$?
  ( cd "$d" && setsid timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$ex" "$d/t.pl" ) >"$d/p.out" 2>"$d/p.err"; prc=$?
  if cmp -s "$d/b.out" "$d/p.out" && [ "$brc" = "$prc" ]; then
    printf 'PASS %-46s\n' "$n"; pass=$((pass+1))
  else
    printf 'FAIL %-46s B=%sB P=%sB bash=%s perl=%s  %s\n' "$n" \
      "$(wc -c <"$d/b.out")" "$(wc -c <"$d/p.out")" "$brc" "$prc" \
      "$(diff "$d/b.out" "$d/p.out" | command grep -E '^[<>]' | head -2 | tr '\n' ' ')"
    fail=$((fail+1))
  fi
  rm -rf "$d"
done
echo "---- pass=$pass fail=$fail"
[ "$fail" -eq 0 ]