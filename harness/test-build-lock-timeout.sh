#!/usr/bin/env bash
# Regression check for the backend gate's core-BUILDABILITY PROBE
# (setup_backends.sh, the `core build FAILED` branch).
#
# The defect: the probe invoked build-lock.sh with NO --timeout, so it
# inherited build-lock's 1800s BACKEND default — twice the 900s the enclosing
# wait loop is allowed in total. A probe queued behind the estree worker's core
# build could not return inside the budget, so the loop never completed a cycle
# and could only fall through to the trap. Measured 2026-10-01: all four backend
# workers logged "probe failed" every 60s for 15 straight minutes and trapped,
# while the core compiled clean in 60s — a LOCK wait misreported as a build
# break, and the log never named the lock.
#
# Two halves, because either alone is a test that cannot fail:
#   1. the call site must bound the probe's lock wait by the remaining budget;
#   2. build-lock.sh must honour an EXPLICIT --timeout against a foreign holder
#      (and say so), so bounding it actually changes the outcome.
set -uo pipefail
ROOT=/home/llm/sh2loop
rc=0

# --- half 1: the call site is bounded ------------------------------------
probe_line=$(grep -n 'build-lock.sh" --role backend --timeout' "$ROOT/setup_backends.sh" | head -1)
if [ -z "$probe_line" ]; then
  echo "FAIL: the buildability probe still passes no --timeout to build-lock.sh,"
  echo "      so it inherits the 1800s default and can overrun the 900s budget."
  rc=1
else
  echo "ok: probe is bounded at the call site (line ${probe_line%%:*})"
  if ! grep -q 'probe_timeout=\$(( CORE_DIRTY_WAIT_S - core_waited ))' "$ROOT/setup_backends.sh"; then
    echo "FAIL: the probe timeout is not derived from the REMAINING budget."
    rc=1
  else
    echo "ok: probe timeout tracks the remaining loop budget"
  fi
fi

# --- half 2: build-lock honours it, loudly ------------------------------
D=/tmp/locktest-$$
rm -rf "$D"; mkdir -p "$D"
mkdir "$D/lock"
echo $$ > "$D/status"
start=$(date +%s)
BUILD_LOCK_DIR="$D" "$ROOT/harness/build-lock.sh" --role backend --timeout 60 -- true >"$D/out" 2>&1
brc=$?
end=$(date +%s)
elapsed=$(( end - start ))
rmdir "$D/lock" 2>/dev/null || true

if [ "$brc" -eq 0 ]; then
  echo "FAIL: the probe acquired a lock still held by a live foreign process"
  rc=1
elif [ "$elapsed" -gt 120 ]; then
  echo "FAIL: probe waited ${elapsed}s — --timeout 60 was ignored"
  rc=1
elif ! grep -q 'timed out' "$D/out"; then
  echo "FAIL: no 'timed out' diagnostic — a silent failure reads as a build break"
  rc=1
else
  echo "ok: bounded at ${elapsed}s with an explicit timeout diagnostic"
fi

rm -rf "$D"
[ "$rc" -eq 0 ] && echo "PASS: probe is bounded and the bound is honoured"
exit $rc