#!/bin/bash
# Per-file C-render debug: render, compile, run, diff vs bash.
set -u
ROOT=/home/llm/sh2loop
CORE=${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}
WBIN=$ROOT/otranspilerl/target/debug/otranspilerl-cli
for f in "$@"; do
  echo "════════ $f"
  shir=$("$CORE" "$f" --source-lang sh --target shir --raw 2>/dev/null) || { echo "  (no shir)"; continue; }
  printf '%s' "$shir" | "$WBIN" - --target c > /tmp/dbg.c 2>/tmp/dbg.err
  rc=$?
  if [ $rc -ne 0 ]; then echo "  RENDER FAIL rc=$rc: $(head -3 /tmp/dbg.err)"; continue; fi
  if grep -qE "TODO\(unsupported\)|sh2[A-Za-z_]" /tmp/dbg.c; then echo "  STUBS: $(grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_]' /tmp/dbg.c)"; fi
  if ! cc /tmp/dbg.c -o /tmp/dbg 2>/tmp/cc.err; then echo "  CC FAIL: $(head -3 /tmp/cc.err)"; continue; fi
  timeout 15 /tmp/dbg > /tmp/dbg.out 2>/dev/null; c_rc=$?
  timeout 15 bash "$f" > /tmp/dbg.ref 2>/dev/null; b_rc=$?
  if [ "$c_rc" = 124 ]; then echo "  C TIMEOUT"; continue; fi
  if diff -q /tmp/dbg.out /tmp/dbg.ref >/dev/null 2>&1; then
    echo "  MATCH (rc c=$c_rc b=$b_rc)"
  else
    echo "  DIFF (rc c=$c_rc b=$b_rc):"
    diff /tmp/dbg.out /tmp/dbg.ref | head -10 | sed 's/^/    /'
  fi
done
