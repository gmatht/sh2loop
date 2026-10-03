#!/usr/bin/env bash
# Bisect a generated .pl: run the first N lines under perl and report which
# prefix still runs cleanly. Usage: bisect.pl.sh <gen.pl> <src.sh> [maxline]
set -uo pipefail
pl=$1; src=$2; max=${3:-$(wc -l <"$pl")}
w=$(mktemp -d "${TMPDIR:-/tmp}/bisect.XXXXXX")
lo=1; hi=$max
# find smallest N such that perl errors/dies on the prefix
check() {
  local n=$1
  { head -"$n" "$pl"; echo 'print STDERR "REACHED";'; } >"$w/b.pl"
  local out rc
  out=$( cd "$w" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$src" "$w/b.pl" 2>&1 )
  rc=$?
  printf '%s' "$out" | command grep -q 'REACHED'
}
while [ $lo -lt $hi ]; do
  mid=$(( (lo+hi)/2 ))
  if check "$mid"; then lo=$((mid+1)); else hi=$mid; fi
done
echo "first bad line: $lo"
sed -n "$((lo-4)),$((lo+2))p" "$pl" | cat -n
echo "--- stderr at that prefix:"
{ head -"$lo" "$pl"; echo 'print STDERR "REACHED";'; } >"$w/b.pl"
( cd "$w" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$src" "$w/b.pl" 2>&1 | command grep -v 'uu-ffi' | head -8 )
rm -rf "$w"
