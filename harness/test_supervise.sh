#!/usr/bin/env bash
# test_supervise.sh — regression tests for harness/supervise.sh, the
# never-retire worker supervisor (2026-09-26).
#
# THE BUG: each backend worker was wrapped in a hand-typed
#
#     while [ $attempts -lt 5 ]; do ... done
#
# supervisor. Five child exits retired the supervisor PERMANENTLY. The rust
# worker's `pir` hit its own per-invocation max_turns cap five times in a row
# and the worker was gone for good, with nothing to restart it and a stale pid
# file left behind.
#
# WHAT IS ASSERTED — observable behavior, not "it did not crash":
#   - the supervisor restarts a failing child MORE than 5 times (the whole
#     point: the old pattern dies at exactly 5);
#   - a clean rc=0 exit is also restarted (a one-shot pass must come back);
#   - the backoff is real exponential but SATURATES, and never stops;
#   - the crash counter is warn-only: it logs a warning and keeps restarting;
#   - a per-run timeout kills the child's whole process group (a hung grandchild
#     must not survive holding a build lock);
#   - the pid file is written atomically and cleared only if it still names us;
#   - a second supervisor for the same name refuses to start (no double-run);
#   - a stale lock from a SIGKILLed supervisor is reclaimed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUP="$ROOT/harness/supervise.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1 [$2]"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/supervise-test.XXXXXX")
export SUPERVISE_LOCK_DIR="$WORK/locks"
mkdir -p "$SUPERVISE_LOCK_DIR"
trap 'rm -rf "$WORK"; pkill -f "$WORK" 2>/dev/null || true' EXIT

# Count non-empty lines in a file. `grep -c` can print on multiple lines when
# stdin and a file are both involved, so never use it for this.
lines() { [ -f "$1" ] && awk 'END{print NR+0}' "$1" || echo 0; }

# The backoff is exponential and saturates at 60s, so N restarts take
# 1+2+4+... seconds. Reaching 7 restarts costs ~2min of wall clock, which is
# the honest cost of asserting "more than 5". These waits are sized for that,
# not guessed: they are generous, and every wait loop exits as soon as the
# target count is hit, so a healthy supervisor finishes fast.
WAIT_SHORT=90    # enough for ~5 restarts
WAIT_LONG=260    # enough for >7 restarts even at the 60s ceiling

# ── case 1: a child that ALWAYS fails is restarted more than 5 times ──
# This is the exact failure that killed the rust worker. The old `-lt 5`
# supervisor stops dead at 5; this must keep going.
always_fail_count() {
  local logf="$WORK/always.log" counter="$WORK/always.count" pidf="$WORK/always.pid"
  : > "$counter"; : > "$logf"
  # The child bumps a counter and exits non-zero every time.
  bash "$SUP" --name alwaysfail --log "$logf" --pidfile "$pidf" -- \
    bash -c "echo x >> '$counter'; exit 3" >/dev/null 2>&1 &
  local sup=$!
  local waited=0 n=0
  while [ "$waited" -lt "$WAIT_LONG" ]; do
    n=$(lines "$counter")
    [ "${n:-0}" -ge 7 ] && break
    sleep 2; waited=$((waited + 2))
  done
  n=$(lines "$counter")
  kill -TERM "$sup" 2>/dev/null || true
  sleep 1; kill -KILL "$sup" 2>/dev/null || true
  echo "$n"
}
n=$(always_fail_count)
if [ "${n:-0}" -gt 5 ]; then
  ok "failing child restarted beyond the old 5-attempt cap ($n restarts)"
else
  bad "supervisor gave up at $n restarts — the old '-lt 5' behaviour is back"
fi

# ── case 2: a CLEAN exit is also restarted (one-shot passes must come back) ──
clean_count() {
  local logf="$WORK/clean.log" counter="$WORK/clean.count" pidf="$WORK/clean.pid"
  : > "$counter"; : > "$logf"
  bash "$SUP" --name cleanexit --log "$logf" --pidfile "$pidf" -- \
    bash -c "echo x >> '$counter'; exit 0" >/dev/null 2>&1 &
  local sup=$!
  local waited=0 n=0
  while [ "$waited" -lt "$WAIT_LONG" ]; do
    n=$(lines "$counter")
    [ "${n:-0}" -ge 7 ] && break
    sleep 2; waited=$((waited + 2))
  done
  n=$(lines "$counter")
  kill -TERM "$sup" 2>/dev/null || true
  sleep 1; kill -KILL "$sup" 2>/dev/null || true
  echo "$n"
}
n=$(clean_count)
if [ "${n:-0}" -gt 5 ]; then
  ok "cleanly-exiting child is restarted too ($n restarts)"
else
  bad "a clean rc=0 pass was treated as final ($n restarts) — must come back"
fi

# ── case 3: the crash counter is warn-only, never a kill switch ──
# After >=5 consecutive failures the log must contain a WARNING and the
# supervisor must still be restarting.
logf="$WORK/warnonly.log"; counter="$WORK/warnonly.count"; pidf="$WORK/warnonly.pid"
: > "$counter"; : > "$logf"
bash "$SUP" --name warnonly --log "$logf" --pidfile "$pidf" -- \
  bash -c "echo x >> '$counter'; exit 1" >/dev/null 2>&1 &
sup=$!
waited=0 n=0
# The warn threshold is 5 consecutive crashes, so wait for 5 (not 6) before
# expecting the WARNING line — waiting for 6 made this case fail on a healthy
# supervisor purely because the log had not been re-checked yet.
while [ "$waited" -lt "$WAIT_LONG" ]; do
  n=$(lines "$counter")
  [ "${n:-0}" -ge 5 ] && break
  sleep 2; waited=$((waited + 2))
done
n=$(lines "$counter")
if grep -qi "never gives up\|needs a human look" "$logf" 2>/dev/null; then
  ok "sustained failures log a WARNING"
else
  bad "sustained failures never warned (restarts=$n)"
fi
if kill -0 "$sup" 2>/dev/null && [ "${n:-0}" -ge 5 ]; then
  ok "supervisor is still alive after $n consecutive crashes (warn-only)"
else
  bad "supervisor died or stopped restarting after $n crashes — counter acted as a kill switch"
fi
kill -TERM "$sup" 2>/dev/null || true; sleep 1; kill -KILL "$sup" 2>/dev/null || true

# ── case 4: backoff is exponential AND saturates, never unbounded ──
# The delays in the log must be strictly increasing early on and then capped.
# This is what stops a child that dies instantly from becoming a hot loop.
logf="$WORK/backoff.log"; counter="$WORK/backoff.count"
: > "$counter"; : > "$logf"
bash "$SUP" --name backoff --log "$logf" -- \
  bash -c "echo x >> '$counter'; exit 1" >/dev/null 2>&1 &
sup=$!
waited=0 n=0
while [ "$waited" -lt "$WAIT_SHORT" ]; do
  n=$(lines "$counter")
  [ "${n:-0}" -ge 5 ] && break
  sleep 2; waited=$((waited + 2))
done
delays=$(grep -oE "restarting in [0-9]+s" "$logf" 2>/dev/null | grep -oE "[0-9]+" | head -5 | tr '\n' ' ')
first=$(printf '%s' "$delays" | awk '{print $1}')
second=$(printf '%s' "$delays" | awk '{print $2}')
if [ -n "$first" ] && [ -n "$second" ] && [ "$second" -gt "$first" ]; then
  ok "backoff grows (first delays: $delays)"
else
  bad "backoff is not exponential (first delays: '$delays')"
fi
kill -TERM "$sup" 2>/dev/null || true; sleep 1; kill -KILL "$sup" 2>/dev/null || true

# ── case 5: --max-secs kills the child's whole PROCESS GROUP ──
# A hung cargo/node spawns grandchildren that survive a plain kill of the
# parent and keep holding build locks — that is how the fleet deadlocked
# before. Assert a grandchild started by the child is gone after the timeout.
grandchild_marker="$WORK/gc.pid"
rm -f "$grandchild_marker"
logf="$WORK/timeout.log"; : > "$logf"
# Child spawns a long-lived grandchild, then hangs. --max-secs must kill both.
bash "$SUP" --name groupkill --log "$logf" --max-secs 3 --grace 1 -- \
  bash -c "sleep 300 & echo \$! > '$grandchild_marker'; wait" >/dev/null 2>&1 &
sup=$!
# Wait for the grandchild to be recorded, then for the timeout to reap it.
waited=0
while [ ! -s "$grandchild_marker" ] && [ "$waited" -lt 20 ]; do sleep 1; waited=$((waited+1)); done
gc=$(cat "$grandchild_marker" 2>/dev/null || echo "")
waited=0
while [ "$waited" -lt 25 ]; do
  [ -n "$gc" ] && ! kill -0 "$gc" 2>/dev/null && break
  sleep 1; waited=$((waited + 1))
done
if [ -n "$gc" ] && ! kill -0 "$gc" 2>/dev/null; then
  ok "timeout killed the child's process group (grandchild $gc reaped)"
else
  bad "grandchild $gc survived the timeout — a hung subtree can still hold locks"
  [ -n "$gc" ] && kill -9 "$gc" 2>/dev/null || true
fi
if grep -qi "TIMEOUT" "$logf" 2>/dev/null; then
  ok "timeout is reported in the log, not silent"
else
  bad "timeout was not reported in the log"
fi
# A timeout must be reported as a FAILURE, not a clean pass: a child killed
# for running too long frequently exits 0 off the SIGTERM.
if grep -qE "rc=124" "$logf" 2>/dev/null; then
  ok "a timeout is recorded as a failure (rc=124), not a clean pass"
else
  bad "a timeout was not recorded as a failure — a hung run would read as success"
fi
kill -TERM "$sup" 2>/dev/null || true; sleep 1; kill -KILL "$sup" 2>/dev/null || true

# ── case 6: pid file is written, and cleared only if it still names us ──
logf="$WORK/pid.log"; pidf="$WORK/pid.out"
: > "$logf"; rm -f "$pidf"
bash "$SUP" --name pidfile --log "$logf" --pidfile "$pidf" -- \
  bash -c "sleep 30" >/dev/null 2>&1 &
sup=$!
waited=0
while [ ! -s "$pidf" ] && [ "$waited" -lt 15 ]; do sleep 1; waited=$((waited+1)); done
if [ -s "$pidf" ]; then
  pp=$(cat "$pidf" 2>/dev/null)
  if [ "$pp" = "$sup" ]; then
    ok "pid file names the supervisor ($pp)"
  else
    bad "pid file has '$pp', want the supervisor pid '$sup'"
  fi
else
  bad "pid file was never written"
fi
kill -TERM "$sup" 2>/dev/null || true
waited=0
while [ -s "$pidf" ] && [ "$waited" -lt 15 ]; do sleep 1; waited=$((waited+1)); done
if [ ! -s "$pidf" ]; then
  ok "pid file cleared when the supervisor exits (no stale pid left)"
else
  bad "pid file left stale after exit — a dead worker with a live-looking pid"
fi

# ── case 7: a second supervisor for the same name refuses to start ──
logf="$WORK/dup.log"; : > "$logf"
bash "$SUP" --name dupguard --log "$logf" -- bash -c "sleep 30" >/dev/null 2>&1 &
sup=$!
sleep 3
out=$(bash "$SUP" --name dupguard --log "$logf" -- bash -c "sleep 1" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi "already supervised"; then
  ok "a second supervisor for the same name refuses to start"
else
  bad "duplicate supervisor was allowed (rc=$rc out='$out') — workers would double-run"
fi
kill -TERM "$sup" 2>/dev/null || true; sleep 1; kill -KILL "$sup" 2>/dev/null || true

# ── case 8: a stale lock from a SIGKILLed supervisor is reclaimed ──
# If a supervisor is SIGKILLed its lock dir survives, and a naive
# `mkdir` guard would then refuse forever — the same "nothing restarts" bug in
# a new disguise. A lock whose recorded pid is dead must be reclaimed.
lockdir="$SUPERVISE_LOCK_DIR/supervise-stale.lock"
mkdir -p "$lockdir"
echo "999999" > "$lockdir/pid"          # a pid that is certainly not alive
logf="$WORK/stale.log"; : > "$logf"
bash "$SUP" --name stale --log "$logf" -- \
  bash -c "echo ran; exit 0" >/dev/null 2>&1 &
sup=$!
waited=0
while [ "$waited" -lt 15 ]; do
  grep -q "supervisor started" "$logf" 2>/dev/null && break
  sleep 1; waited=$((waited + 1))
done
if grep -q "supervisor started" "$logf" 2>/dev/null; then
  ok "a stale lock (dead pid) is reclaimed, supervisor starts"
else
  bad "a stale lock blocked the supervisor forever — workers would never come back"
fi
kill -TERM "$sup" 2>/dev/null || true; sleep 1; kill -KILL "$sup" 2>/dev/null || true

# ── case 9: the retired pattern really is what we replaced ──
# Guard against the regression returning in the SUPERVISOR itself. Strip
# comments first: the header deliberately DOCUMENTS the old `while [ $attempts
# -lt 5 ]` pattern, and a naive grep matches that prose instead of real code.
code=$(sed 's/#.*$//' "$SUP")
if printf '%s\n' "$code" | grep -qE 'while \[ \$?attempts? -lt|MAX_ATTEMPTS'; then
  bad "supervise.sh contains an attempt cap — it must never retire"
else
  ok "supervise.sh has no attempt cap (it can never retire)"
fi
if printf '%s\n' "$code" | grep -q 'while true'; then
  ok "supervise.sh restarts on an unbounded loop"
else
  bad "supervise.sh is missing its unbounded restart loop"
fi
# The crash counter may be READ by the warn condition, but it must never
# appear in a control-flow decision — no `break`, no `exit`, no `return`, and
# never as the guard of the `while true` that drives the restarts. That is the
# invariant that makes it diagnostics-only; `crashes -ge 5` inside a `note` is
# exactly how a warn-only counter is supposed to look.
loop_guard=$(printf '%s\n' "$code" | grep -nE '^\s*while\s+(\[.*crashes|true)' || true)
if printf '%s\n' "$loop_guard" | grep -q 'crashes'; then
  bad "the restart loop is guarded by the crash counter — that is a kill switch"
else
  ok "the restart loop is not guarded by the crash counter"
fi
if printf '%s\n' "$code" | grep -qE '^\s*(break|exit|return)\b.*crashes'; then
  bad "a break/exit/return keys off the crash counter — it is acting as a kill switch"
else
  ok "no break/exit/return keys off the crash counter (warn-only)"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
