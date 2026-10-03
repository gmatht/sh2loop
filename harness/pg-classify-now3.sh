#!/usr/bin/env bash
# pg-classify-now3.sh — cluster the CURRENT perl-generator gate failures by the
# FIRST differing line of the bash-vs-perl stdout diff.
#
# Rationale: the 46 failures are not 46 bugs. Both the empty-"$*"-iteration
# family and the heredoc family are single-root-cause with many members, so
# fixing by count-of-failures wastes effort. Classifying by the first diff line
# collapses them into the handful of distinct shapes worth fixing, and shows
# how many failures each root-cause fix would retire at once.
#
# Usage:  harness/pg-classify-now3.sh [gate-out-file]
#         harness/pg-classify-now3.sh --live     # transpile+run each failing case
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

gate_out="${1:-$root/.perlgen-gate.out}"
live=0
[ "${1:-}" = "--live" ] && { live=1; gate_out=""; }

CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_LIB_PIPELINE="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

work=$(mktemp -d "${COMMANDCODE_SCRATCHPAD:-/tmp}/pgclass-XXXXXX")
trap 'rm -rf "$work"' EXIT

# gate-out -> one example name per line
if [ "$live" = 0 ]; then
  names=$(sed -n 's/^  FAIL: \(.*\)\.sh \[perl\].*/\1/p' "$gate_out" | sort -u)
else
  names=$(ls "$root/sh2perl/examples"/*.sh | xargs -n1 basename | sed 's/\.sh$//')
fi

declare -A class_count=()
declare -A class_members=()
total=0

for n in $names; do
  ex="$root/sh2perl/examples/$n.sh"
  [ -f "$ex" ] || continue
  if ! "$CLI" --target pl "$ex" > "$work/g.pl" 2> "$work/g.err"; then
    key="GEN-FAILED"
  elif grep -qE "system\('bash', *'[^']+'\)" "$work/g.pl"; then
    key="PARSER-FALLBACK"
  elif ! perl "$root/check_qx.pl" "$work/g.pl" > "$work/qx" 2>&1; then
    key="QX-VIOLATION"
  else
    # argv0 pass-through, exactly as ./fail runs it
    setsid timeout -k 2 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
      "$ex" "$work/g.pl" > "$work/p.out" 2> "$work/p.err"
    pe=$?
    setsid timeout -k 2 20 bash "$ex" > "$work/b.out" 2> "$work/b.err"
    be=$?
    if cmp -s "$work/p.out" "$work/b.out" && [ "$pe" = "$be" ]; then
      continue   # passes in isolation => an interference/flakiness class
    fi
    if [ "$pe" != "$be" ]; then
      key="EXIT bash=$be perl=$pe"
    else
      # Group by the perl runtime's OWN first error, not the diff offset.
      # Two cases whose outputs diverge at different lines both land in one
      # "DIFF:2c2"-style bucket — grouping by offset groups siblings, never
      # root causes. The stderr fingerprint is the root cause.
      key="DIFF:$(awk 'NF{print; exit}' "$work/p.err" 2>/dev/null | cut -c1-70)"
      [ -n "$key" ] || key="DIFF:$(diff "$work/b.out" "$work/p.out" 2>/dev/null | head -1 | cut -c1-70)"
    fi
  fi
  total=$((total + 1))
  class_count["$key"]=$(( ${class_count["$key"]:-0} + 1 ))
  class_members["$key"]="${class_members[$key]:-} $n"
done

echo "failing total: $total"
echo
printf '%-72s %s\n' "CLASS (perl stderr fingerprint, else first diff)" "N"
printf '%.0s-' {1..84}; echo
# `set -u` + an empty associative array is an error in some bash builds, and
# `${class_count[$k]}` on an unset key is too; initialise both under one name.
for k in "${!class_count[@]}"; do
  printf '%-72s %s\n' "$k" "${class_count[$k]:-0}"
done | sort -k2 -rn
echo
echo "=== members per class ==="
for k in "${!class_count[@]}"; do
  [ "${class_count[$k]:-0}" -lt 2 ] && continue
  echo "--- ${class_count[$k]}x  $k"
  echo "${class_members[$k]}" | tr ' ' '\n' | sed 's/^/      /' | sed '/^ *$/d'
done