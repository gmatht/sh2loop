#!/usr/bin/env bash
# go_seam_hist.sh — per-FUNCTION histogram of the go renderer's runtime seam.
#
# backend_runtime_metric.sh answers "how many runtime calls does go still make"
# with a single total. That total cannot say WHICH helper is responsible, so it
# cannot say which construct to lower next. This script renders the same corpus
# through the same worktree bin and prints a descending count per seam function,
# plus the files each one appears in.
#
# Usage: harness/go_seam_hist.sh [corpus-glob]
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
GO_SHIR_RENDER="$ROOT/sh2perl/backends/go/target/debug/shir_render"
# the go seam, verbatim from harness/backend_runtime_metric.sh
SEAM='s2s|capRun|capCmd|capCmdRaw|runCmd|redirRun|redirCap'

CORPUS=("${1:-$ROOT/sh2perl/examples}"/**/*.sh)
# bash 4 globstar off by default in some shells; fall back to a flat glob
[ -e "${CORPUS[0]}" ] || CORPUS=("$ROOT"/sh2perl/examples/*.sh)

[ -x "$CLI" ] || { echo "missing $CLI" >&2; exit 1; }
[ -x "$GO_SHIR_RENDER" ] || { echo "missing $GO_SHIR_RENDER (cargo build --bin shir_render)" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
files=0
for f in "${CORPUS[@]}"; do
    [ -f "$f" ] || continue
    shir=$("$CLI" --target shir "$f" 2>/dev/null) || continue
    [ -n "$shir" ] || continue
    base=$(echo "$f" | sed 's|/|_|g')
    printf '%s' "$shir" | "$GO_SHIR_RENDER" --target=go - > "$tmp/$base.go" 2>/dev/null || continue
    [ -s "$tmp/$base.go" ] || continue
    files=$((files + 1))
done

total=$(cat "$tmp"/*.go 2>/dev/null | grep -oE "$SEAM" | wc -l)
echo "files rendered: $files"
echo "total seam calls: $total"
echo
# one line per function: count, then how many FILES use it
cat "$tmp"/*.go 2>/dev/null | grep -oE "$SEAM" | sort | uniq -c | sort -rn |
  while read -r n fn; do
    fcount=$(grep -lE "(^|[^A-Za-z_0-9])${fn}\(" "$tmp"/*.go 2>/dev/null | wc -l)
    printf '%8d  %-12s  in %4d files\n' "$n" "$fn" "$fcount"
  done
