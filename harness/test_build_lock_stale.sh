#!/usr/bin/env bash
# test_build_lock_stale.sh — regression tests for build-lock.sh's STALE-LOCK
# reclaim and its wait-timeout behaviour (2026-09-27).
#
# FLAKY UNDER LOAD (measured 2026-10-03). The case "core preempts a live
# recorded holder and proceeds" gives core only `--timeout 5 --grace 3`,
# i.e. an 8s budget to SIGTERM a holder, wait out the grace, and re-acquire.
# On this 16-core box at load ~23 it fails roughly 1 run in 5 — and it fails
# IDENTICALLY against the pre-2026-10-03 build-lock.sh, so it is NOT a
# regression from the absent-record-race fix (5 runs each, isolated lock
# dirs: current 4/5, pre-fix 4/5). The steal-race fix cannot affect this
# path: for a RECORDED holder the new branch is skipped entirely.
# Treat a single red here as load noise unless it persists across runs or
# appears together with a real behaviour failure.
#
# THE BUG. build-lock.sh serialises builds with `mkdir "$LOCK_FILE"`, and
# records the holder in a SIBLING file ($STATUS_FILE). When the lock dir exists
# with no readable holder record it used to take the "non-empty but no record —
# leaving it alone" branch and keep polling, on every iteration, until its own
# timeout.
#
# That made the lock permanently unusable to any waiter, because a foreign
# `flock 9 9>...lock` user (exactly how the backend gates serialise) leaves a
# non-empty file at that path and never writes $STATUS_FILE — so the record is
# permanently absent and the "leave it alone" branch is taken forever.
#
# OBSERVED SYMPTOM, and why it was so confusing: the core gate's
# `cargo test --lib` came back with EMPTY output — no `test result:` line at
# all — because the command never ran. The gate read that correctly and logged
# "no lib-test summary (hung or crashed)", so the diagnosis pointed at a
# spinning TEST. It was a lock problem the whole time, and nothing in the log
# named the lock. Reproduced deterministically by holding the path with a plain
# `flock`: 317s and empty output, versus 2.5s with a clean summary uncontended.
#
# Two fixes are pinned here:
#   1. a lock dir with no holder record is RECLAIMED (this script owns the path);
#   2. the core role now has a timeout exit (timeout + grace) instead of
#      spinning forever after preemption, so a lock problem is never again
#      reported as a silent empty run.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/harness/build-lock.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bl-stale.XXXXXX")
trap 'rm -rf "$WORK"; pkill -f "$WORK" 2>/dev/null || true' EXIT

# A private lock dir so the live fleet's .build-lock is never touched. Each
# case needs its own, so make one explicitly rather than via a function (a
# `d=$(lockdir)` would be fine, but calling it bare in a subshell loses the
# value and `set -u` catches it).
newlock() { printf '%s\n' "$WORK/lock-$1-$$"; }

# ── case 1: a foreign flock holder must NOT starve a waiter forever ──
# This is the regression. Hold the lock path with a plain `flock` (which, like
# the backend gates, writes no holder record) and require that a build-lock
# waiter still gets to run its command.
d=$(newlock c1); mkdir -p "$d"
( exec 9>"$d/lock"; flock 9; sleep 40 ) &
holder=$!
sleep 1
t0=$(date +%s)
out=$(BUILD_LOCK_DIR="$d" timeout 90 bash "$LOCK" --role backend -- true 2>&1)
rc=$?
t1=$(date +%s)
waited=$((t1 - t0))
kill -TERM "$holder" 2>/dev/null || true
if [ "$rc" -eq 0 ] && [ "$waited" -lt 60 ]; then
  ok "a foreign flock holder does not starve the waiter (rc=0 after ${waited}s)"
else
  bad "waiter was starved by a foreign flock holder (rc=$rc after ${waited}s)"
fi

# ── case 2: the reclaim is announced, not silent ──
# A reclaim that produces no diagnostic is how the original bug hid for hours.
d=$(newlock c2); mkdir -p "$d/lock"      # lock dir present, NO status file
out=$(BUILD_LOCK_DIR="$d" timeout 60 bash "$LOCK" --role backend -- true 2>&1)
if printf '%s' "$out" | command grep -qF "removing stale lock"; then
  ok "a record-less lock dir is reclaimed with a diagnostic"
else
  bad "no reclaim diagnostic — a silent reclaim would hide the cause again"
fi

# ── case 3: the lock actually works (two holders serialise) ──
# A reclaim must not let two builds run at once. Hold the lock the way this
# script does (mkdir + status) and confirm a second waiter does NOT barge in.
d=$(newlock c3a); mkdir -p "$d"
BUILD_LOCK_DIR="$d" bash "$LOCK" --role backend -- sleep 12 &
first=$!
sleep 2
# The first holder is live and has a status record, so the second must WAIT.
t0=$(date +%s)
BUILD_LOCK_DIR="$d" bash "$LOCK" --role backend -- true 2>/dev/null
t1=$(date +%s)
second_waited=$((t1 - t0))
wait "$first" 2>/dev/null || true
if [ "$second_waited" -ge 5 ]; then
  ok "a live holder with a status record is respected (second waited ${second_waited}s)"
else
  bad "second build barged in after ${second_waited}s — the lock does not serialise"
fi

# ── case 4: a DEAD holder's lock is reclaimed promptly ──
# A holder killed with SIGKILL never runs its EXIT trap, so its lock dir and
# status record survive. The next waiter must reclaim it rather than hang.
d=$(newlock c3); mkdir -p "$d"
BUILD_LOCK_DIR="$d" bash "$LOCK" --role backend -- sleep 300 &
victim=$!
sleep 2
kill -KILL "$victim" 2>/dev/null || true
sleep 1
t0=$(date +%s)
out=$(BUILD_LOCK_DIR="$d" timeout 60 bash "$LOCK" --role backend -- echo RECLAIMED 2>&1)
t1=$(date +%s)
waited=$((t1 - t0))
if printf '%s' "$out" | command grep -qF "RECLAIMED" && [ "$waited" -lt 30 ]; then
  ok "a SIGKILLed holder's lock is reclaimed (${waited}s)"
else
  bad "a dead holder's lock was not reclaimed (${waited}s, out='$(printf '%s' "$out" | tail -1)')"
fi

# ── case 5: core PREEMPTS a live holder rather than hanging on it ──
# Core is the preempting role: past its timeout it SIGTERMs the holder and takes
# the lock. That is the designed behaviour and it must be preserved — a core
# build must not queue behind a backend gate indefinitely.
d=$(newlock c5); mkdir -p "$d"
BUILD_LOCK_DIR="$d" bash "$LOCK" --role backend -- sleep 400 &
holder=$!
sleep 2                                  # let it take the lock and write the record
t0=$(date +%s)
out=$(BUILD_LOCK_DIR="$d" timeout 200 bash "$LOCK" --role core --timeout 5 --grace 3 -- echo CORE_RAN 2>&1)
rc=$?
t1=$(date +%s)
waited=$((t1 - t0))
kill -TERM "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
if [ "$rc" -eq 0 ] && printf '%s' "$out" | command grep -qF "CORE_RAN"; then
  ok "core preempts a live recorded holder and proceeds (${waited}s)"
else
  bad "core did not preempt a live holder (rc=$rc after ${waited}s)"
fi
if printf '%s' "$out" | command grep -qF "preempting holder"; then
  ok "the preemption is reported, so it is never a silent stall"
else
  bad "the preemption produced no diagnostic"
fi

# ── case 6: the core wait loop always TERMINATES (no infinite spin) ──
# The old core loop escalated and then spun FOREVER, which is what turned a
# lock problem into an empty-output "hung test" report: the command never ran
# and the gate read the blank result as a hung suite. Whatever the holder does,
# the waiter must terminate inside its timeout+grace budget and say why — never
# block a caller indefinitely and never return blank without a diagnostic.
#
# A holder that ignores SIGTERM is the only state where the timeout EXIT (as
# opposed to preemption) is reachable, so that is what is simulated.
d=$(newlock c6); mkdir -p "$d"
# traps '' TERM makes this subshell immune to the SIGTERM core sends on
# escalation, so preemption cannot free the lock and the timeout path is taken.
bash -c "trap '' TERM; exec sleep 400" &
holder=$!
sleep 1
mkdir -p "$d/lock"
echo "$holder backend $(date +%s)" > "$d/status"   # a LIVE, recorded holder
t0=$(date +%s)
out=$(BUILD_LOCK_DIR="$d" timeout 120 bash "$LOCK" --role core --timeout 3 --grace 2 -- echo SHOULD_NOT_RAN 2>&1)
rc=$?
t1=$(date +%s)
waited=$((t1 - t0))
kill -KILL "$holder" 2>/dev/null || true
wait "$holder" 2>/dev/null || true
# 3s timeout + 2s grace = ~5s. The old code spun to the 120s cap.
if [ "$waited" -lt 60 ]; then
  ok "the core wait loop terminates instead of spinning (${waited}s, rc=$rc)"
else
  bad "the core wait loop spun for ${waited}s — the infinite loop is back"
fi
# The only legitimate outcomes: it timed out WITH a diagnostic, or it preempted
# and ran. A silent no-output return is exactly the failure being fixed.
if printf '%s' "$out" | command grep -qE "timed out|preempting"; then
  ok "the lock stall is reported with a reason (not a silent empty run)"
else
  bad "no diagnostic naming the lock (out='$(printf '%s' "$out" | tail -1)')"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
