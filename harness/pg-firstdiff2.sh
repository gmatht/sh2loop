#!/bin/bash
# For each name on stdin: run the case and print ONLY the first changed
# line pair plus the surrounding source, so N cases fit in one screen.
# usage: names | harness/pg-firstdiff2.sh
set -u
ROOT=/home/llm/sh2loop
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"

while read -r n; do
  [ -n "$n" ] || continue
  ex="$ROOT/sh2perl/examples/$n"
  # names may arrive bare or with the .sh suffix already attached
  [ -f "$ex" ] || ex="$ex.sh"
  [ -f "$ex" ] || { echo "### $n NOFILE"; continue; }
  d=$(mktemp -d /tmp/pgfd-XXXXXX)
  if ! timeout 60 "$CLI" --target pl "$ex" >"$d/t.pl" 2>"$d/g.err"; then
    echo "### $n GENFAIL: $(head -1 "$d/g.err")"; rm -rf "$d"; continue
  fi
  if ! perl -c "$d/t.pl" >/dev/null 2>"$d/s.err"; then
    echo "### $n SYNTAX: $(sed -n '2p' "$d/s.err" | sed "s|$d/t.pl|GEN|")"; rm -rf "$d"; continue
  fi
  ( cd "$d" && setsid timeout -k 2 20 bash "$ex" ) >"$d/b.out" 2>/dev/null; brc=$?
  ( cd "$d" && setsid timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$ex" "$d/t.pl" ) >"$d/p.out" 2>"$d/p.err"; prc=$?
  if cmp -s "$d/b.out" "$d/p.out" && [ "$brc" = "$prc" ]; then echo "### $n PASS"; rm -rf "$d"; continue; fi
  echo "### $n  exit bash=$brc perl=$prc  (B $(wc -c <"$d/b.out") / P $(wc -c <"$d/p.out"))"
  echo "    stderr: $(head -1 "$d/p.err" | sed 's|/tmp/commandcode[^ ]*/||' | cut -c1-100)"
  diff "$d/b.out" "$d/p.out" | command grep -E '^[<>]' | head -4 | sed 's/^/    /'
  rm -rf "$d"
done