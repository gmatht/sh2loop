#!/usr/bin/env bash
# test_build_lock_watchdog.sh — regression tests for the build-lock watchdog's
# process/fd leaks (the 2026-09-26 "nothing progresses" incident).
#
# THE BUG: build-lock.sh spawns a watchdog subshell that `sleep`s for
# MAX_BUILD_SECS. Two leaks let that sleep outlive build-lock and wedge the
# fleet:
#
#   1. FD LEAK (fixed in ee31f442): the watchdog inherited fd 9 — the caller's
#      `flock 9` GATE LOCK — so a survivor held the gate lock with no work to
#      do. Every backend worker blocked in `flock 9` on an idle box for ~50min.
#
#   2. STDOUT LEAK (fixed here): closing fds >= 3 did NOT close fd 1, and the
#      loops call build-lock inside a `open(my $fh, '-|', ...)` backtick. The
#      watchdog therefore held the PIPE's write end. `kill "$watchdog_pid"`
#      killed the subshell but not the `sleep` inside it, so the pipe stayed
#      open for the full MAX_BUILD_SECS and the reader blocked in sysread long
#      after the build finished. Observed live: the estree loop's
#      `fail-estree --metric` frozen with flat /proc/PID/io counters and
#      wchan=anon_pipe_read for ~20min, i.e. half of every iteration lost.
#
# WHAT IS ASSERTED — observable behavior, not "it did not crash":
#   - A reader on a pipe gets EOF promptly after build-lock exits, even though
#     MAX_BUILD_SECS is far in the future. This is the exact symptom the fleet
#     showed, so it is the thing the test pins.
#   - No `sleep` descendant survives build-lock's exit.
#   - The watchdog never holds an inherited fd >= 3 (the gate-lock fd), and
#     never holds the caller's stdout.
#   - The build child's OWN stdout is still inherited (a backtick is reading
#     it) — so the fix did not over-correct into silence.
#   - The watchdog still kills a genuinely hung command (its whole point).
#
# Everything runs on throwaway temp dirs and a private BUILD_LOCK_DIR, so
# nothing here touches the live fleet's lock.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/harness/build-lock.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1 [$2]"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bl-watchdog.XXXXXX")
trap 'rm -rf "$WORK"; pkill -P $$ sleep 2>/dev/null || true' EXIT

# A private lock dir so the live fleet's .build-lock is never touched.
export BUILD_LOCK_DIR="$WORK/lockdir"
mkdir -p "$BUILD_LOCK_DIR"

# ── case 1: the caller's PIPE gets EOF promptly (the exact fleet symptom) ──
# Read build-lock's stdout through a pipe and time how long EOF takes. With a
# 60s watchdog the buggy version keeps the pipe open for ~60s; the fixed
# version returns as soon as the command does. The gap between the two is
# what makes the timing meaningful, so the watchdog must be much longer than
# any legitimate build here (`true` is instant).
pipe_eof_seconds() {
  local secs="$1"
  python3 - "$LOCK" "$BUILD_LOCK_DIR" "$secs" <<'PY'
import os, subprocess, sys, time
lock, lockdir, maxsecs = sys.argv[1], sys.argv[2], sys.argv[3]
env = dict(os.environ, BUILD_LOCK_DIR=lockdir, MAX_BUILD_SECS=maxsecs)
t0 = time.time()
# stdout=PIPE: the reader is a pipe, exactly like the loops' backtick.
p = subprocess.Popen(["bash", lock, "--role", "backend", "--", "true"],
                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
p.stdout.read()          # blocks until EVERY writer closes the pipe
p.wait()
print(int((time.time() - t0) * 10) // 1 / 10)   # one decimal place
PY
}

t=$(pipe_eof_seconds 60)
# The command (`true`) takes ~0.1s and the watchdog is 60s, so EOF must land
# well under the watchdog. Allow generous headroom for a loaded box but stay
# far below 60: if the pipe were held, this would read ~60.
if awk -v t="$t" 'BEGIN{exit !(t < 10)}'; then
  ok "pipe EOF after build-lock exit (${t}s, watchdog 60s)"
else
  bad "pipe held open by the watchdog after build-lock exit (${t}s, want <10s)"
fi

# ── case 2: no `sleep` descendant survives build-lock's exit ──
# The bug was specifically that `kill <subshell>` left the inner `sleep`
# alive, and that sleep is what held the caller's pipe (asserted structurally
# in case 3) and the gate lock. An orphan is reparented to init, so it cannot
# be found by looking at this shell's children — instead assert the
# OBSERVABLE consequence: no process anywhere still holds the write end of a
# pipe that this wrapper opened, and no `sleep MAX_BUILD_SECS` the wrapper
# started is still running. A correct reap leaves neither.
orphan_watchdog_sleep() {
  local before after new waited mark=1471
  # A watchdog window unique to THIS case, so a survivor can only be ours and
  # a `sleep` from another case can never be mistaken for one. Match the
  # trailing argument exactly, not as a substring (`1471` vs `14710`).
  _sleeper_pids() { ps -eo pid,args 2>/dev/null | grep -E "sleep +$mark\$" | awk '{print $1}' | sort; }
  before=$(_sleeper_pids)
  BUILD_LOCK_DIR="$BUILD_LOCK_DIR" MAX_BUILD_SECS="$mark" \
    bash "$LOCK" --role backend -- true >/dev/null 2>&1
  waited=0
  while [ "$waited" -lt 10 ]; do
    after=$(_sleeper_pids)
    new=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | tr '\n' ' ')
    [ -z "$new" ] && { echo ""; return; }
    sleep 1
    waited=$((waited + 1))
  done
  # Leave nothing behind for the next case, whatever the verdict.
  for p in $new; do kill -9 "$p" 2>/dev/null || true; done
  echo "$new"
}
leftover=$(orphan_watchdog_sleep)
if [ -z "$(printf '%s' "$leftover" | tr -d '[:space:]')" ]; then
  ok "no orphaned watchdog sleep survives"
else
  bad "orphaned watchdog sleep left running: $(printf '%s' "$leftover" | tr '\n' ' ')"
  # Clean up so a failure does not leak into later cases.
  printf '%s' "$leftover" | tr -d '[:space:]' | xargs -r kill -9 2>/dev/null || true
fi

# ── case 3: the watchdog holds neither an inherited fd >= 3 nor stdout ──
# Reproduce the gate-lock shape: the caller holds fd 9 via flock, then runs
# build-lock with the build itself hanging so the watchdog stays alive to
# inspect. The build child and the watchdog are BOTH `sleep 600`, so they are
# told apart by fd: the build child legitimately owns the caller's pipe, the
# watchdog must own neither that pipe nor the inherited gate-lock fd9.
watchdog_fds() {
  python3 - "$LOCK" "$BUILD_LOCK_DIR" <<'PY'
import os, subprocess, sys, time, fcntl
lock, lockdir = sys.argv[1], sys.argv[2]
# Caller holds an flock on fd 9 and hands the child a pipe on fd 1 — the
# exact shape of the workers' `( flock 9 ... ) 9>lock` plus a backtick.
gate = open(os.path.join(lockdir, "gate.lock"), "w+")
fcntl.flock(gate, fcntl.LOCK_EX | fcntl.LOCK_NB)
gatefd = gate.fileno()
r, w = os.pipe()
env = dict(os.environ, BUILD_LOCK_DIR=lockdir, MAX_BUILD_SECS="600")
p = subprocess.Popen(["bash", lock, "--role", "backend", "--", "sleep", "600"],
                     stdout=w, stderr=subprocess.DEVNULL, env=env, pass_fds=(gatefd,))
os.close(w)
time.sleep(2.5)                      # let the watchdog reach its sleep
pids, seen = [p.pid], set()
while pids:
    cur = pids.pop()
    kids = subprocess.run(["pgrep", "-P", str(cur)],
                          capture_output=True, text=True).stdout.split()
    for k in kids:
        if k in seen:
            continue
        seen.add(k)
        pids.append(k)
report = []
for pid in sorted(seen | {str(p.pid)}):
    try:
        links = {fd: os.readlink(f"/proc/{pid}/fd/{fd}")
                 for fd in os.listdir(f"/proc/{pid}/fd")}
    except OSError:
        continue
    cmd = open(f"/proc/{pid}/cmdline", "rb").read().replace(b"\0", b" ").decode().strip()
    if "sleep" not in cmd:            # only report the sleeps
        continue
    report.append(f"{pid}|fd1={links.get('1','none')}|fd9={links.get('9','none')}")
print(";".join(report))
# Tear down carefully. The wrapper shares OUR process group, but build-lock
# puts its children in their own (setsid), so those must be signalled by
# their group while the wrapper itself is signalled by pid. Never killpg on
# anything still in our own group — that would signal the test itself.
mygroup = os.getpgid(0)
for pid in sorted(seen | {str(p.pid)}, key=int):
    try:
        pg = os.getpgid(int(pid))
        if pg != mygroup:
            os.killpg(pg, 9)
        else:
            os.kill(int(pid), 9)
    except OSError:
        pass
p.kill(); p.wait()
PY
}
report=$(watchdog_fds)
# Two sleeps are expected: the BUILD child (must own the pipe, fd1) and the
# WATCHDOG (must own neither fd1 nor fd9). Classify by fd1.
watchdog_line=$(printf '%s' "$report" | tr ';' '\n' | grep -v 'fd1=pipe:' | grep -v '^$' | head -1)
build_line=$(printf '%s' "$report" | tr ';' '\n' | grep 'fd1=pipe:' | head -1)
if [ -z "$report" ]; then
  bad "could not observe the watchdog to inspect (test cannot assert)"
elif [ -z "$watchdog_line" ]; then
  bad "watchdog not found in the process tree: $report"
elif printf '%s' "$watchdog_line" | grep -qE '\|fd1=pipe:'; then
  bad "watchdog still holds the caller's pipe on fd1: $watchdog_line"
elif printf '%s' "$watchdog_line" | grep -q 'fd9=[^n]'; then
  bad "watchdog still holds the inherited gate-lock fd9: $watchdog_line"
else
  ok "watchdog holds neither the caller's pipe (fd1) nor the gate lock (fd9)"
fi
# The build child MUST still be on the pipe — proof we did not over-correct.
if [ -n "$build_line" ]; then
  ok "build child still owns the caller's stdout (no over-correction)"
else
  bad "build child lost the caller's stdout: $report"
fi

# ── case 4: the BUILD CHILD still owns stdout (no over-correction) ──
# The fix must silence the WATCHDOG only. If it also silenced the build,
# every `$(...)`/backtick caller in the loops would receive no output at all —
# a silent-failure worse than the hang. Assert real stdout still arrives.
got=$(BUILD_LOCK_DIR="$BUILD_LOCK_DIR" MAX_BUILD_SECS=600 \
        bash "$LOCK" --role backend -- echo PIPELINE_STILL_WORKS 2>/dev/null)
check "build child stdout still reaches the caller's pipe" "$got" "PIPELINE_STILL_WORKS"

# ── case 5: the watchdog still kills a genuinely hung command ──
# Its whole reason to exist. A command that outlives MAX_BUILD_SECS must be
# killed and the wrapper must report failure, not a clean exit.
t0=$(date +%s)
set +e
BUILD_LOCK_DIR="$BUILD_LOCK_DIR" MAX_BUILD_SECS=2 \
  bash "$LOCK" --role backend -- sleep 600 >"$WORK/hang.out" 2>"$WORK/hang.err"
rc=$?
set -e
t1=$(date +%s)
waited=$((t1 - t0))
if [ "$rc" -ne 0 ]; then
  ok "hung command is killed, wrapper reports failure (rc=$rc, ${waited}s)"
else
  bad "hung command returned success (rc=0) — the watchdog did not fire"
fi
# It must be bounded by the watchdog window, not unbounded: give it room for
# the TERM+5s+KILL path but far below the 600s the child asked for.
if [ "$waited" -lt 30 ]; then
  ok "hung command killed promptly (${waited}s, watchdog 2s)"
else
  bad "hung command took ${waited}s to die (watchdog 2s) — the kill is too slow"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
