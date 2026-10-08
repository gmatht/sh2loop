#!/bin/bash
# Re-check a list of corpus examples through the single-example repro and
# print one PASS/FAIL line each, so a handed-down failure list can be tested
# for staleness in one batch.
#
# Usage: harness/pg-check-list.sh <file-with-one-example-per-line>
#        harness/pg-check-list.sh -            # read the list from stdin
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIST=${1:--}
pass=0; fail=0; missing=0
while read -r name; do
  case "$name" in ''|'#'*) continue ;; esac
  # strip a trailing .sh if present; pg-one resolves the bare name
  n=${name%.sh}
  if [ ! -f "$ROOT/sh2perl/examples/$n.sh" ]; then
    echo "MISSING  $n"; missing=$((missing+1)); continue
  fi
  if out=$("$ROOT/harness/pg-one.sh" "$n.sh" 2>&1); then :; fi
  if echo "$out" | command grep -q 'STDOUT: MATCH'; then
    echo "PASS  $n"; pass=$((pass+1))
  else
    echo "FAIL  $n  $(echo "$out" | command grep -o 'bash exit=[0-9]* *perl exit=[0-9]*' | head -1)"
    fail=$((fail+1))
  fi
done < "$LIST"
echo "---- pass=$pass fail=$fail missing=$missing ----"
