#!/usr/bin/env bash
# pg-triage44.sh — run the perl-generator corpus failures through pg-case.sh
# and bucket them by the shape of the stdout diff, so the biggest fixable
# class is chosen from evidence instead of from example names.
#
#   harness/pg-triage44.sh [case-list-file]
#
# One line per case: <verdict>\t<example>\t<diffline-count>\t<first-diff-line>
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
list="${1:-$root/harness/perl_gen_backlog.txt}"

ex=""

while IFS= read -r name; do
  [ -n "$name" ] || continue
  case "$name" in \#*) continue ;; esac
  f="$root/sh2perl/examples/$name"
  if [ ! -f "$f" ]; then
    printf 'MISSING\t%s\t-\tno example file\n' "$name"
    continue
  fi
  out=$(bash "$root/harness/pg-case.sh" "$f" 2>&1)
  if printf '%s' "$out" | grep -q 'OK'; then
    printf 'PASS\t%s\t0\t(now green)\n' "$name"
    continue
  fi
  # Count the diff payload lines, and capture the first changed line.
  n=$(printf '%s\n' "$out" | grep -c '^[<>]')
  first=$(printf '%s\n' "$out" | grep -m1 '^[<>]' | cut -c1-90)
  printf 'FAIL\t%s\t%s\t%s\n' "$name" "$n" "$first"
done < "$list"