#!/bin/bash
# Fast local repro of the c backend gate loop (setup_backends.sh --backend-gate c).
# Usage: harness/c_gate_repro.sh [file.sh ...]   (default: whole corpus)
set -u
ROOT=/home/llm/sh2loop
SUB=$ROOT/sh2perl
WT=$SUB/backends/c
CORE=${CORE_BIN:-$SUB/target/debug/debashc}
WBIN=$WT/target/debug/debashc
CC=cc
pass=0; fail=0; skip=0; fails=""
if [ $# -gt 0 ]; then corpus="$@"; else corpus=$(ls $SUB/examples/*.sh $ROOT/frontends/*/testdata/*.sh 2>/dev/null); fi
for f in $corpus; do
  shir=$("$CORE" --shir "$f" --raw 2>/dev/null) || { skip=$((skip+1)); continue; }
  [ -z "$shir" ] && { skip=$((skip+1)); continue; }
  bash -n "$f" 2>/dev/null || { skip=$((skip+1)); continue; }
  g_out=$(printf '%s' "$shir" | "$WBIN" --shir-in-c - 2>/dev/null) || { fail=$((fail+1)); fails="$f $fails"; continue; }
  s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2[A-Za-z_]" || true)
  if [ "$s" -gt 0 ]; then fail=$((fail+1)); fails="[STUB $s] $f $fails"; continue; fi
  printf '%s' "$g_out" > /tmp/eq_c.c
  eq_exit=1
  cc /tmp/eq_c.c -o /tmp/eq_c_bin 2>/dev/null && timeout 15 /tmp/eq_c_bin > /tmp/eq_c_out 2>/dev/null && eq_exit=0
  bash_rc=0
  timeout 15 bash "$f" > /tmp/eq_c_ref 2>/dev/null || bash_rc=$?
  if [ "$eq_exit" != 124 ] && [ "$bash_rc" != 124 ] && [ "$eq_exit" = 0 ] && [ "$bash_rc" = 0 ] \
     && diff -q /tmp/eq_c_out /tmp/eq_c_ref >/dev/null 2>&1; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); fails="$f $fails"
  fi
done
echo "PASS=$pass FAIL=$fail SKIP=$skip"
for x in $fails; do echo "  FAIL: $x"; done
