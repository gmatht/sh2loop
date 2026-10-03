#!/usr/bin/env bash
# The single most valuable statistic for this gate: how many failing examples
# produce Perl that DOES NOT EVEN COMPILE.
#
# A file that fails `perl -c` writes nothing and exits 0 under the gate's
# `do $__f`, so it surfaces as a plain "stdout mismatch" — indistinguishable
# from a formatting bug, but with a whole-program blast radius. One bad line
# costs every construct in the example, so this class is worth far more per
# fix than a content diff.
#
#   harness/pg-compile-census.sh [name...]   (defaults to the 57-failure list)
set -uo pipefail
root=/home/llm/sh2loop
cli="$root/otranspilerl/target/debug/otranspilerl-cli"
list="$root/.pg-triage-fails.txt"

[ $# -gt 0 ] && list=/dev/null && printf '%s\n' "$@" > /tmp/pg-census-names.$$
names=$( [ -s /tmp/pg-census-names.$$ ] && cat /tmp/pg-census-names.$$ || cat "$list" )
rm -f /tmp/pg-census-names.$$

bad=0; ok=0; tot=0
declare -A byerr
for n in $names; do
  ex="$root/sh2perl/examples/$n"
  [ -f "$ex" ] || continue
  tot=$((tot+1))
  pl="/tmp/pgcen.$$.$n.pl"
  timeout 60 sh -c "\"$cli\" --target pl \"$ex\" 2>/dev/null" > "$pl"
  if [ ! -s "$pl" ]; then echo "$n	NO-GENERATED"; continue; fi
  # `perl -c` is queried for its EXIT STATUS, not its text — the generated
  # preamble emits a runtime `warn` ("uu-ffi .so … not found") that lands on
  # STDERR as the FIRST line, so taking `head -1` of the output classified 23
  # healthy files as broken AND hid the real error on the line after it.
  # The error is the first line matching a perl -c diagnostic; the warn is not
  # one, so it is skipped rather than allowed to mask the real failure.
  if perl -M5.010 -c "$pl" >/dev/null 2>"$pl.cerr"; then
    ok=$((ok+1))
  else
    bad=$((bad+1))
    msg=$(command grep -m1 -E '^(Missing|Bareword|Global|String|syntax error|Empty|Invalid|Perl (strict|internal)|Can.t (locate|use)|Possible|Unescaped|Empty|Attempt)' "$pl.cerr")
    [ -n "$msg" ] || msg=$(head -1 "$pl.cerr")
    # Normalise to the error's own class so similar bugs group together.
    key=$(printf '%s' "$msg" | sed -e 's/ at \/.*//' -e "s/\"[^\"]*\"/X/g" \
          -e 's/line [0-9]*//' -e 's/[0-9]\+/N/g')
    byerr["$key"]=$(( ${byerr["$key"]:-0} + 1 ))
    printf '%s\t%s\n' "$n" "$msg"
  fi
  rm -f "$pl" "$pl.cerr"
done

echo
echo "=== perl -c census: $bad do NOT compile, $ok compile, of $tot ==="
echo "=== error classes ==="
for k in "${!byerr[@]}"; do printf '%3d  %s\n' "${byerr[$k]}" "$k"; done | sort -rn
