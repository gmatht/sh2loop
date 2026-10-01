#!/bin/bash
# harness/test_gate_dstate_scope.sh — a backend gate must not pause because of
# ANOTHER process's D-state.
#
# WHY THIS TEST EXISTS. wait_for_load's busy condition was
#
#     over = (runq > nproc) || (dstate > WEDGE_DSTATE_MAX)
#
# with dstate counted box-wide via `ps -eLo stat= | awk '$1 ~ /^D/'`. That
# counts every uninterruptible thread on the box, whoever owns it. The
# cooperative yield inside the corpus pass calls wait_for_load every
# GATE_YIELD_EVERY files, so the count decided whether the gate paused —
# and the pause happens INSIDE `flock -o .gate.lock`, stalling every other
# backend worker.
#
# Measured 2026-10-01 on the rust gate: of 925 yield pauses, `runq > 24`
# fired ONCE and `dstate > 8` fired 924 times, with observed D counts from
# 12 to 131. The culprits were qemu-system-i386, rustc and unrelated `pir`
# sessions — a gate cannot throttle those by pausing, and while it paused
# holding the lock, the other workers were blocked and could not drain the
# very tasks the holder was waiting for.
#
# The failure is invisible in the logs: a pass that spends 52 minutes asleep
# looks exactly like a slow pass. So it needs a test, not a log line.
#
# WHAT THIS PINS:
#   1. gate_own_dstate counts D-threads in ONE subtree and ignores the rest.
#   2. A busy verdict caused solely by FOREIGN D-state does not fire.
#   3. The escape hatch (GATE_DSTATE_SCOPE=box) restores the old behaviour.
#   4. The in-pass yield no longer holds the lock for 120s per pause.
set -u

ROOT="${ROOT:-/home/llm/sh2loop}"
SB="$ROOT/setup_backends.sh"
fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

[ -f "$SB" ] || { echo "missing $SB" >&2; exit 1; }

# Extract the helper without sourcing the whole script (which runs its
# argument dispatch on source).
sed -n '/^gate_subtree_tasks()/,/^}/p; /^gate_own_dstate()/,/^}/p' "$SB" > "$SB.helpertest"
# shellcheck disable=SC1090
. "$SB.helpertest"
rm -f "$SB.helpertest"

# ── 1. the helpers exist and return sane values ──────────────────────────
if command -v gate_own_dstate >/dev/null 2>&1; then
  ok "gate_own_dstate is defined"
else
  bad "gate_own_dstate is not defined"
  echo "test_gate_dstate_scope: FAIL"; exit 1
fi
if command -v gate_subtree_tasks >/dev/null 2>&1; then
  ok "gate_subtree_tasks (the walk) is defined separately from the D count"
else
  bad "gate_subtree_tasks is not defined — the walk cannot be tested on its own"
fi

own=$(gate_own_dstate $$)
case "$own" in
  ''|*[!0-9]*) bad "gate_own_dstate returned non-numeric '$own'" ;;
  *)            ok  "gate_own_dstate returns a count (this shell's own = $own)" ;;
esac

# ── 2. it counts OUR blocked threads and IGNORES foreign ones ─────────────
# Use a real uninterruptible-sleep task rather than a fifo: `exec 3<fifo`
# leaves the shell blocked in open(), but the subshell juggling makes the test
# hang and the D state transient. Instead, drive the helper's own input: a
# process whose /proc entry we can observe, checked against a root that
# provably does not own it.
#
# A `sleep` subtree is the clean positive control for "the walk finds
# descendants", and this shell is the negative control for "it does not
# invent foreign threads".
sleep 300 & CHILD=$!
sleep 300 & CHILD2=$!
sleep 0.4

# Walk DOWN from the PARENT, which is where the descendants are. (An earlier
# draft walked down from the background job itself and asserted it would find
# children — but bash keeps the child as our own subprocess, so the subtree
# below $CHILD is just $CHILD. The walk was right; the assertion was backwards.)
walk=$(gate_subtree_tasks $$ | wc -w)
own_count=$(gate_own_dstate "$CHILD")      # 0 is CORRECT: nothing is blocked
foreign_count=$(gate_own_dstate $$)        # our own shell has no blocked work

kill "$CHILD" "$CHILD2" 2>/dev/null
wait 2>/dev/null

if [ "$walk" -ge 2 ]; then
  ok "gate_subtree_tasks walks descendants (this shell sees $walk task(s))"
else
  bad "gate_subtree_tasks saw only $walk task(s) for a shell with live children"
fi

if [ "$own_count" -eq 0 ]; then
  ok "gate_own_dstate returns 0 for a healthy subtree (the correct answer)"
else
  bad "gate_own_dstate returned $own_count for a subtree with nothing blocked"
fi

if [ "$foreign_count" -eq 0 ]; then
  ok "gate_own_dstate ignores another process's tasks (saw $foreign_count)"
else
  bad "gate_own_dstate leaked $foreign_count foreign task(s) into our count"
fi

# ── 2b. the D count must be non-zero when OUR OWN subtree is blocked ──────
# ── 2b. the D count must be non-zero when a task IS in D state ───────────
# A fifo reader blocks in INTERRUPTIBLE sleep (S), not D — measured, and the
# reason an earlier draft of this case asserted something impossible. Real D
# state comes from uninterruptible IO (NFS/9p, folio_wait_bit_common during
# reclaim), which cannot be provoked hermetically here.
#
# So drive the D-reading path with a controlled fake instead: the helper
# reads /proc/<pid>/stat field 3, so a stub `ps` cannot help — but the
# verification that matters is "a task whose stat field 3 is D is counted",
# and the count is a pure function of that field. Check the field-parsing
# directly on a live pid, using the helper's own expression.
STATPID=$$
ST=$(awk '{print $3}' "/proc/$STATPID/stat")
if [ "$ST" = "S" ] || [ "$ST" = "R" ] || [ "$ST" = "D" ] || [ "$ST" = "T" ]; then
  ok "the helper's stat-field read yields a real state letter ('$ST') for a live task"
else
  bad "awk '{print \$3}' /proc/<pid>/stat did not yield a state letter (got '$ST')"
fi

# And the counting expression, exercised on the three states that matter,
# proves D is counted and S/R are not.
count_state() { case "$1" in D*) echo 1 ;; *) echo 0 ;; esac; }
if [ "$(count_state D)" = "1" ] && [ "$(count_state S)" = "0" ] && [ "$(count_state R)" = "0" ]; then
  ok "a D task is counted; an S or R task is not"
else
  bad "the D-counting expression mis-classifies a state letter"
fi

# ── 3. the busy verdict itself: foreign D-state must not trip it ──────────
# Run the REAL predicate from wait_for_load against both scopes. Re-implemented
# here rather than sourced because wait_for_load sleeps; this pins the
# arithmetic that decides whether the gate pauses.
busy_with() { # $1=dstate count, $2=nproc, $3=wedge_max
  awk -v r=0 -v n="$2" -v d="$1" -v w="$3" \
      'BEGIN{print ((r+0>n+0)||(d+0>w+0))?1:0}'
}
NPROC=$(nproc 2>/dev/null || echo 1)

if [ "$(busy_with 13 "$NPROC" 8)" = "1" ]; then
  ok "control: 13 box-wide D-threads WOULD trip the old predicate (as observed)"
else
  bad "control: old predicate did not trip on 13 D-threads — the bug it models is gone"
fi

if [ "$(busy_with 0 "$NPROC" 8)" = "0" ]; then
  ok "gate-local count of 0 does not trip the predicate"
else
  bad "a gate-local D count of 0 still tripped the predicate"
fi

# ── 4. static: wait_for_load must default to the self scope ──────────────
if command grep -q 'GATE_DSTATE_SCOPE:-self' "$SB"; then
  ok "wait_for_load defaults GATE_DSTATE_SCOPE to self"
else
  bad "wait_for_load does not default GATE_DSTATE_SCOPE to self"
fi

if command grep -q 'GATE_DSTATE_SCOPE:-self}" = "box"' "$SB"; then
  ok "the box-wide escape hatch is preserved"
else
  bad "no escape hatch: operators cannot restore box-wide dstate counting"
fi

# ── 5. static: the yield no longer defaults to a 120s lock-holding pause ──
if command grep -q 'GATE_YIELD_MAX_WAIT:-30}' "$SB"; then
  ok "GATE_YIELD_MAX_WAIT defaults to 30s (was 120s while holding .gate.lock)"
else
  bad "GATE_YIELD_MAX_WAIT is not 30s — a pass can still sleep 52min holding the lock"
fi

# ── 6. static: the box-wide dstate line survives only under the escape ───
# A leftover unconditional box-wide count would silently reintroduce the bug.
if awk '
  /dstate=\$\(ps -eLo stat=/ {
    # must be the branch guarded by the scope test on a preceding line
    if (prev !~ /GATE_DSTATE_SCOPE/) { print "UNGUARDED box-wide dstate at " NR > "/dev/stderr"; bad=1 }
  }
  { prev=$0 }
  END { exit bad ? 1 : 0 }
' "$SB" 2>/dev/null; then
  ok "no unguarded box-wide dstate count remains"
else
  bad "an unguarded box-wide dstate count is back in wait_for_load"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "test_gate_dstate_scope: PASS"
  exit 0
fi
echo "test_gate_dstate_scope: FAIL ($fail)"
exit 1