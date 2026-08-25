#!/usr/bin/env bash
# stub_measure.sh — count TODO/sh2.* stub markers each backend emits when
# rendering sh2perl/examples. Diagnostic only; does not gate anything.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$ROOT/sh2perl"
BIN="$SUB/target/debug/debashc"
CORPUS="${1:-$SUB/examples}"
LANGS="${2:-c go python rust zig sh java js perl}"

total=0
for lang in $LANGS; do
  files=0; stubs=0; err=0
  for f in "$CORPUS"/*.sh; do
    shir=$("$BIN" --shir "$f" --raw 2>/dev/null) || { continue; }
    [ -z "$shir" ] && continue
    out=$(printf '%s' "$shir" | "$BIN" "--shir-in-$lang" - 2>/dev/null) || { err=$((err+1)); continue; }
    s=$(printf '%s' "$out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_]' || true)
    [ "$s" -gt 0 ] && files=$((files+1))
    stubs=$((stubs+s))
  done
  echo "$lang: stub_markers=$stubs files_with_stubs=$files render_errors=$err"
  total=$((total+stubs))
done
echo "TOTAL stubs: $total"
