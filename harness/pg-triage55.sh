#!/usr/bin/env bash
# Triage the Perl-generator failure list into clusters.
#
#   harness/pg-triage55.sh <list-file> [jobs]
#
# For each example: run the exact ./fail pipeline (pg-one-case.sh), then emit a
# COMPACT signature = the first differing line pair + the first perl-stderr
# line + the first failing construct in the generated Perl. The signature is
# what clusters; the diff volume is what buries the answer.
#
# Output: one TSV row per case, deterministic order (sorted by example name).
set -u
ROOT=/home/llm/sh2loop
LIST=${1:?usage: pg-triage55.sh <list-file> [jobs]}
JOBS=${2:-4}

sigs=$(mktemp /tmp/pg-sigs.XXXXXX)
raw=$(mktemp -d /tmp/pg-triage.XXXXXX)

one() {
  local name=$1 out=$2
  local d
  d=$(DIFFLINES=6 PG_KILLSESSION=1 timeout 120 bash "$ROOT/harness/pg-one-case.sh" "$name" 2>&1)
  local verdict pass dirstderr firstdiff sig
  verdict=$(printf '%s\n' "$d" | command grep -o 'PASS\|FAIL' | head -1)
  pass=${verdict:-TIMEOUT}
  ddir=$(printf '%s\n' "$d" | command grep -o 'dir=/tmp/[^ ]*' | head -1 | cut -d= -f2-)
  dirstderr=''
  if [ -n "$ddir" ] && [ -s "$ddir/perl.err" ]; then
    dirstderr=$(head -1 "$ddir/perl.err" | tr '\t' ' ' | cut -c1-90)
  fi
  # First stdout-diff pair, collapsed to one cell.
  firstdiff=''
  if [ "$pass" = FAIL ]; then
    firstdiff=$(printf '%s\n' "$d" \
      | command sed -n '/^--- stdout diff/,/^--- perl stderr/p' \
      | command sed -n '3,4p' | command tr '\n' '|' | command tr '\t' ' ' | cut -c1-110)
  fi
  # The first construct in the GENERATED perl that smells wrong: a q{} or
  # quoted span carrying raw Perl control flow into a shell text position.
  sig=''
  if [ "$pass" = FAIL ] && [ -n "$ddir" ] && [ -f "$ddir/gen.pl" ]; then
    sig=$(command grep -o "q{[^}]\{0,60\}do { my [^}]\{0,40\}" "$ddir/gen.pl" 2>/dev/null | head -1 | cut -c1-70)
    [ -z "$sig" ] && sig=$(command grep -o "printf(\"%q\"\|printf(\"%s\", [0-9]\|coreutils-ffi: unknown\|invalid conversion\|isn't numeric" "$ddir/gen.pl" "$ddir/perl.err" 2>/dev/null | head -1 | cut -c1-70)
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$pass" "$firstdiff" "$dirstderr" "$sig" "$ddir" > "$out"
}
export -f one
export ROOT

# Accept EITHER a bare-name list or a ./fail-style `FAIL: <name>.sh [perl]`
# report; strip to example names and sort (deterministic TSV).
command grep -o '[^ ]*\.sh' "$LIST" 2>/dev/null \
  | command sed 's/^\[//; s/\]$//' \
  | command grep -v '^FAIL' \
  | sort -u > "$raw/names"
total=$(wc -l < "$raw/names")
echo "# triaging $total cases, $JOBS parallel" >&2

xargs -a "$raw/names" -I{} -P "$JOBS" -I{} \
  env SIGDIR="$raw" bash -c 'one "$1" "$SIGDIR/sig.$1"' _ {} 2>/dev/null

# Merge in sorted order, so the TSV is byte-stable across runs.
: > "$sigs"
while read -r n; do
  [ -f "$raw/sig.$n" ] && cat "$raw/sig.$n" >> "$sigs"
done < "$raw/names"

column -t -s$'\t' "$sigs" 2>/dev/null || cat "$sigs"
echo "### raw: $sigs  artifacts: $raw"