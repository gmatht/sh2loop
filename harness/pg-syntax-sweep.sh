#!/usr/bin/env bash
# Classify generated Perl by COMPILE status. A compile error in the generated
# file is the highest-yield failure class: `perl -e 'do FILE'` dies at
# COMPILE time, prints nothing to stdout, and exits 0 — so the gate reports it
# as a silent stdout mismatch with no hint on stderr.
# Usage: harness/pg-syntax-sweep.sh <scratchdir-with-*.pl>
set -uo pipefail
d=$1
for f in "$d"/*.pl; do
  n=$(basename "$f" .sh.pl)
  err=$(perl -c "$f" 2>&1 | command grep -v 'uu-ffi' | command grep -v 'syntax OK' | command grep -E '^(Bareword|Missing|Ambiguous|Global|syntax error|Unterminated|Empty string|String found|.*Compilation|.*error)' | head -2 | tr '\n' ' ')
  if [ -n "$err" ]; then printf 'FATAL\t%-50s %s\n' "$n" "$err"; fi
done
