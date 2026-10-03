#!/usr/bin/env bash
# Print the exact generated line perl rejects for a failing example.
# Usage: harness/pg-whycompile.sh <example.sh> [...]
set -uo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
for n in "$@"; do
  ex="$root/sh2perl/examples/$n"
  d=$(mktemp -d "${TMPDIR:-/tmp}/whyc.XXXXXX")
  "$CLI" --target pl "$ex" >"$d/t.pl" 2>/dev/null
  echo "######## $n"
  perl -c "$d/t.pl" 2>&1 | command grep -v 'uu-ffi' | command grep -v 'syntax OK' | head -3
  ln=$(perl -c "$d/t.pl" 2>&1 | command grep -v 'uu-ffi' | sed -n 's/.*at GEN line \([0-9]*\).*/\1/p' | head -1)
  ln=${ln:-$("$CLI" --target pl "$ex" 2>/dev/null | wc -l)}
  if [ -n "${SHOW:-}" ]; then
    sed -n "$((ln-3)),$((ln+1))p" "$d/t.pl" | cat -n
  fi
  cp "$d/t.pl" "$root/tmp_run/gen.$n.pl" 2>/dev/null || true
  rm -rf "$d"
done
