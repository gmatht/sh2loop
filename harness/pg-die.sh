#!/usr/bin/env bash
# pg-die.sh — which failing examples die on the unsupported-redirect stub?
#   harness/pg-die.sh <ex1.sh> <ex2.sh> ...
set -u
root=/home/llm/sh2loop
ot=$root/otranspilerl/target/debug/otranspilerl-cli
EX="$root/sh2perl/backends/perl/examples"

for name in "$@"; do
  src="$EX/$name"
  [ -f "$src" ] || continue
  d=$(mktemp -d "/tmp/pgd2.${name%.sh}.XXXXXX")
  timeout 25 "$ot" --target pl "$src" >"$d/t.pl" 2>/dev/null
  if grep -q 'shIR redirect not yet supported' "$d/t.pl"; then
    n=$(grep -c 'shIR redirect not yet supported' "$d/t.pl")
    ln=$(grep -n 'shIR redirect not yet supported' "$d/t.pl" | head -1 | cut -d: -f1)
    total=$(wc -l <"$d/t.pl")
    printf '%-50s DIES  x%s at_line=%-5s total_lines=%s\n' "$name" "$n" "$ln" "$total"
  else
    printf '%-50s no-die\n' "$name"
  fi
  rm -rf "$d"
done