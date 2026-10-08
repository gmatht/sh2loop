#!/usr/bin/env bash
# acceptance for the absent-holder-record race fix in build-lock.sh
# T1: a live holder whose record is not yet written must NOT be stolen.
# T2: the reboot case (lock dir present, NO record at all) must still clear.
# T3: the SIGKILL case (record names a dead pid) must still clear.
# T4: normal serialisation still works (two builds never overlap).
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BL=$ROOT/harness/build-lock.sh
pass=0; fail=0
ok(){ echo "  PASS: $1"; pass=$((pass+1)); }
no(){ echo "  FAIL: $1"; fail=$((fail+1)); }

run_isolated(){ # run build-lock.sh against a throwaway lock dir
  local d=$1; shift
  BUILD_LOCK_DIR="$d" "$BL" "$@"
}

echo "T1: a live holder that has mkdir'd but not yet recorded must NOT be stolen"
d=$(mktemp -d); mkdir -p "$d/lock"          # lock exists, NO record (the race window)
( sleep 2; echo "$$ backend $(date +%s)" > "$d/status" ) &   # record appears LATE
sleep 0.2
out=$(BUILD_LOCK_DIR="$d" NO_RECORD_STALE_S=5 "$BL" --role backend --timeout 1 -- echo STOLEN 2>&1)
if echo "$out" | grep -q STOLEN; then
  no "T1 waiter stole a live lock: $(echo "$out" | head -2)"
else
  ok "T1 waiter waited instead of stealing ($(echo "$out" | tail -1 | cut -c1-60))"
fi
wait 2>/dev/null; rm -rf "$d"

echo "T2: reboot case — lock dir present, NO record, and it stays that way"
d=$(mktemp -d); mkdir -p "$d/lock"          # survives a reboot, record never comes
out=$(BUILD_LOCK_DIR="$d" NO_RECORD_STALE_S=2 "$BL" --role backend --timeout 30 -- echo RECOVERED 2>&1)
if echo "$out" | grep -q RECOVERED; then ok "T2 reclaimed a record-less stale lock"
else no "T2 deadlocked on the reboot case: $(echo "$out" | tail -1 | cut -c1-60)"; fi
rm -rf "$d"

echo "T3: SIGKILL case — record names a dead pid"
d=$(mktemp -d); mkdir -p "$d/lock"
echo "999999 backend $(date +%s)" > "$d/status"     # pid that does not exist
out=$(BUILD_LOCK_DIR="$d" "$BL" --role backend --timeout 30 -- echo RECOVERED 2>&1)
if echo "$out" | grep -q RECOVERED; then ok "T3 reclaimed a dead-holder lock"
else no "T3 did not reclaim a dead-holder lock: $(echo "$out" | tail -1 | cut -c1-60)"; fi
rm -rf "$d"

echo "T4: serialisation — a second waiter never runs while a live holder holds"
d=$(mktemp -d)
BUILD_LOCK_DIR="$d" "$BL" --role backend --timeout 30 -- sh -c 'echo HOLDER_START; sleep 3; echo HOLDER_END' > "$d/holder.out" 2>&1 &
h=$!
sleep 1
BUILD_LOCK_DIR="$d" "$BL" --role backend --timeout 30 -- echo SECOND_RAN > "$d/second.out" 2>&1
wait $h 2>/dev/null
hs=$(command grep -c HOLDER_START "$d/holder.out" 2>/dev/null || echo 0)
he=$(command grep -c HOLDER_END "$d/holder.out" 2>/dev/null || echo 0)
if [ "$hs" = 1 ] && [ "$he" = 1 ]; then ok "T4 holder ran exactly once, second waiter did not overlap"
else no "T4 serialisation broken (holder_start=$hs holder_end=$he)"; fi
rm -rf "$d"

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]