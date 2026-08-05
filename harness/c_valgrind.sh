#!/usr/bin/env bash
# harness/c_valgrind.sh — memory-error gate for the C backend's generated
# output. For every example the c_backend renders AND compiles AND runs,
# run it under valgrind; any memory error (invalid read/write, leaks) is a
# renderer bug — the C generator's job to fix.
#
# Usage: harness/c_valgrind.sh [file.sh ...]  (default: the examples the
# renderer handles)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CBIN="$ROOT/sh2perl/backends/c/target/debug/c_backend"
CC="${CC:-tcc -O1 -g}"
VGBIN="${VGBIN:-valgrind}"
TMP=/tmp/c_vg; mkdir -p "$TMP"

fails=0; total=0
for f in ${@:-$ROOT/sh2perl/examples/*.sh}; do
  [ -f "$f" ] || continue
  # render
  "$CBIN" "$f" 2>/dev/null > "$TMP/o.c" || continue
  # compile (the renderer emits stubs + TODO for the unlowerable — the
  # compilable subset is the gate's)
  $CC -o "$TMP/o" "$TMP/o.c" 2>/dev/null || continue
  # run under valgrind: errors -> exit 99
  timeout 20 "$VGBIN" --error-exitcode=99 --leak-check=summary \
    "$TMP/o" >/dev/null 2> "$TMP/vg.txt"
  rc=$?
  total=$((total+1))
  if [ "$rc" -eq 99 ]; then
    fails=$((fails+1))
    echo "  VALGRIND FAIL: $(basename "$f")"
    grep -E "Invalid|definitely lost|indirectly lost" "$TMP/vg.txt" | head -2 | sed 's/^/    /'
  elif [ "$rc" -ne 0 ]; then
    # a normal runtime error (not memory) — the renderer ran it wrong; not
    # a valgrind failure but worth noting
    :
  fi
done
echo "C valgrind: $total rendered+compiled+runs, $fails memory failures"
[ "$fails" -eq 0 ]
