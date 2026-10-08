#!/usr/bin/env bash
# Classify every current perl-generator corpus failure by its FIRST observable
# symptom, so fixes can be chosen by cluster size instead of by guesswork.
#
#   harness/pg-triage-classify.sh [fail-list]
#
# Input list: one bare example name per line (default: /tmp/pg-now-fails.txt).
# Output:     "<tag> <name>" per line on stdout; tallies on stderr.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIST=${1:-/tmp/pg-now-fails.txt}

while read -r line; do
  # tolerate "name [perl] — stdout mismatch" as well as a bare name
  f="${line%% *}"
  [ -z "$f" ] && continue
  d=$(bash "$ROOT/harness/pg-one-case.sh" "$f" 2>&1)

  tag="OTHER"
  case "$d" in
    *"Can't exec"*|*"No such file or directory"*) tag="exec-seam-builtin" ;;
    *"unknown util"*)                           tag="ffi-unknown-util" ;;
    *"is not a function"*|*"command not found"*) tag="eval-not-in-shell" ;;
    *"Use of uninitialized"*)                   tag="uninit-warn" ;;
    *"not found"*)                               tag="cmd-not-found" ;;
    *"syntax error"*|*"Bareword"*)              tag="perl-syntax" ;;
  esac

  # secondary signal: does the generated program shell out to bash at all?
  if command grep -q "system('bash'" <<<"$d"; then :; fi
  echo "$tag $f"
done < "$LIST"
