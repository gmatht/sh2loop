#!/usr/bin/env bash
# Classify the Perl GENERATOR corpus failures: which are the generator's
# fault (emitted Perl that runs but disagrees with bash), which are the
# shared core's (parser fallback to a bash wrapper / generate failure), and
# which are transient.
#
#   harness/pg-class2.sh [gate-log] [prefix]
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

log=${1:-/tmp/pg-full-gate.log}
prefix=${2:-}
one="$root/harness/pg-one3.sh"

list=$(mktemp /tmp/pglist-XXXXXX); trap 'rm -f "$list"' EXIT
command grep -oE '^  FAIL: [^ ]+ \[perl\]' "$log" | awk '{print $2}' | sort -u >"$list"
if [[ -n $prefix ]]; then grep "$prefix" "$list" >"$list.2" && mv "$list.2" "$list"; fi
[[ -s $list ]] || { echo "no perl failures in $log" >&2; exit 2; }

gen=(); core=(); other=()
while read -r t; do
  [[ -z $t ]] && continue
  r=$("$one" "$t" 2>&1)
  if grep -q "PARSER FALLBACK" <<<"$r" || grep -q "GENERATE FAILED" <<<"$r"; then
    core+=("$t")
  elif grep -qE 'stdout: IDENTICAL' <<<"$r" && grep -qE 'exit: perl=([0-9]+) bash=\1$' <<<"$r"; then
    other+=("$t")
  else
    gen+=("$t")
  fi
  printf '.'
done <"$list"
echo
echo "generator: ${#gen[@]}   core(parser/gen failure): ${#core[@]}   now-passing: ${#other[@]}"
printf '%s\n' "${gen[@]}"  >"$root/.pg-gen-fail.txt"
printf '%s\n' "${core[@]}" >"$root/.pg-core-fail.txt"
printf '%s\n' "${other[@]}" >"$root/.pg-nowpass.txt"
echo "--- generator-owned (${#gen[@]}) ---"; cat "$root/.pg-gen-fail.txt"
echo "--- core parse/gen failure (${#core[@]}) ---"; cat "$root/.pg-core-fail.txt"
echo "--- now passing (${#other[@]}) ---"; cat "$root/.pg-nowpass.txt"
