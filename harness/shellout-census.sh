#!/bin/bash
# harness/shellout-census.sh — the remaining runtime dependency on bash,
# measured. Every helper below spawns a child `bash`; a program that emits one
# of them cannot run without bash on PATH, so the count is the roadmap of
# un-lowered bodies (eval, command, trap, and command substitutions whose text
# the backend could not reconstruct).
#
#   ./harness/shellout-census.sh           per-program list + summary
#   ./harness/shellout-census.sh --quiet   summary only
#   ./harness/shellout-census.sh --json    {"programs":N,"clean":M,"helpers":{...}}
#
# The renderer is the core CLI (`--target rs`); no build, no execution.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
EX="$ROOT/sh2perl/examples"
[ -x "$CLI" ] || { echo "census: CLI missing: $CLI (build otranspilerl-cli)" >&2; exit 2; }

HELPERS="capture cap_bytes capture_rc run spawn bg run_traps"
quiet=0; json=0
for a in "$@"; do
  case "$a" in
    --quiet) quiet=1 ;;
    --json) json=1 ;;
    *) echo "census: unknown argument $a" >&2; exit 2 ;;
  esac
done

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
total=0; clean=0
for f in "$EX"/*.sh; do
  name=$(basename "$f" .sh)
  out=$("$CLI" --target rs "$f" 2>/dev/null)
  total=$((total + 1))
  used=""
  for h in $HELPERS; do
    if printf '%s' "$out" | command grep -q "__sh_${h}("; then
      used="$used $h"
      echo "H $h" >> "$tmp"
    fi
  done
  if [ -z "$used" ]; then
    clean=$((clean + 1))
  else
    echo "$name:$used" >> "$tmp.prog"
  fi
done

if [ "$json" = 1 ]; then
  printf '{"programs":%d,"clean":%d,"helpers":{' "$total" "$clean"
  sep=""
  for h in $HELPERS; do
    n=$(command grep -c "^H $h$" "$tmp" 2>/dev/null || true)
    printf '%s"%s":%d' "$sep" "$h" "${n:-0}"
    sep=","
  done
  printf '}}\n'
  exit 0
fi

if [ "$quiet" = 0 ]; then
  sort "$tmp.prog" 2>/dev/null
  echo
fi
echo "shell-out census: $total programs, $clean spawn no bash, $((total - clean)) do"
for h in $HELPERS; do
  n=$(command grep -c "^H $h$" "$tmp" 2>/dev/null || true)
  [ "${n:-0}" -gt 0 ] && printf '  %-12s %s\n' "$h" "$n"
done
exit 0
