#!/usr/bin/env bash
# stub_measure2.sh — count GENUINE TODO/stub markers (sh2.* runtime calls and
# TODO(unsupported)) that each backend emits when rendering sh2perl/examples.
# Excludes harmless header strings like "sh2perl" / "sh2sh". Diagnostic only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$ROOT/sh2perl"
BIN="$SUB/otranspilerl/target/debug/otranspilerl-cli"
CORPUS="${1:-$SUB/examples}"
LANGS="${2:-c go python rust zig sh java js perl}"

for lang in $LANGS; do
  files=0; stubs=0; err=0
  for f in "$CORPUS"/*.sh; do
    shir=$("$BIN" --shir "$f" --raw 2>/dev/null) || { continue; }
    [ -z "$shir" ] && continue
    out=$(printf '%s' "$shir" | "$BIN" "--shir-in-$lang" - 2>/dev/null) || { err=$((err+1)); continue; }
    # genuine stub markers: sh2.* function calls (sh2_exec/sh2GetVar/...)
    # and TODO(unsupported) markers
    s=$(printf '%s' "$out" | grep -oE 'sh2[A-Za-z_]+\(|TODO\(unsupported\)' | grep -v '^sh2perl(' | wc -l)
    [ "$s" -gt 0 ] && files=$((files+1))
    stubs=$((stubs+s))
  done
  echo "$lang: stub_calls=$stubs files_with_stubs=$files render_errors=$err"
done
