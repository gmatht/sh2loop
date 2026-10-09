#!/usr/bin/env bash
# build-lock.sh — the single choke point for cargo builds: a priority lock
# in front of cargo (PLAN §11.8). Cargo's own target-dir lock is blocking
# FIFO with no policy; this wrapper adds priority, timeouts, graceful
# preemption, and diagnostics, and lets the CORE builds share one target
# dir (dep dedup) without the "Blocking waiting for file lock" churn that
# forced the per-worktree target-core/target split.
#
# Usage:
#   build-lock.sh [--role core|frontend|backend] [--timeout N] [--grace N] \
#                 [--share-target DIR] -- <cargo args...>
#
#   --role          priority class. core preempts after --timeout
#                   (SIGTERM the holder + grace); frontend/backend wait up
#                   to --timeout then fail loudly (never preempt).
#   --timeout       seconds this build may wait before escalation
#                   (core default 120, others 1800).
#   --grace         seconds a preempted holder gets after SIGTERM before
#                   we retry acquisition (default 30).
#   --share-target  set CARGO_TARGET_DIR to DIR for this build (default:
#                   $ROOT/sh2perl/target — the main checkout's dir, so the
#                   estree loop and the backend gates' CORE builds dedupe
#                   deps. Worktree builds pass --share-target "$g_wt/target"
#                   (their bin name collides with the main otranspilerl-cli, so they
#                   keep their own dir).
#
# Env: BUILD_LOCK_HELD=1 (internal re-entrancy guard — a nested
#      build-lock.sh call runs the command directly, no deadlock).
#
# Exit: the cargo command's exit code; 2 on usage; 1 on lock timeout.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_DIR="${BUILD_LOCK_DIR:-$ROOT/.build-lock}"
LOCK_FILE="$LOCK_DIR/lock"
STATUS_FILE="$LOCK_DIR/status"

role="backend"
timeout=""
grace=30
# Seconds a lock dir must be observed WITHOUT a holder record before it is
# reclaimed as stale. Long enough to cover the mkdir->record window of a
# live acquirer (see the race note in acquire()), short enough that the two
# real recoveries — a SIGKILLed holder and the reboot case — still clear on
# the next poll or two. Override for a test.
NO_RECORD_STALE_S="${NO_RECORD_STALE_S:-5}"
share_target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) role="${2:?--role needs a value}"; shift 2;;
    --timeout) timeout="${2:?--timeout needs a value}"; shift 2;;
    --grace) grace="${2:?--grace needs a value}"; shift 2;;
    --share-target) share_target="${2:?--share-target needs a value}"; shift 2;;
    --) shift; break;;
    *) echo "build-lock.sh: unknown option $1" >&2; exit 2;;
  esac
done

[[ $# -gt 0 ]] || { echo "build-lock.sh: no command given after --" >&2; exit 2; }

# priority classes (0 = highest)
prio() {
  case "$1" in
    core) echo 0;;
    frontend) echo 1;;
    backend) echo 2;;
    *) echo 3;;
  esac
}

if [[ -z "$timeout" ]]; then
  if [[ "$role" == "core" ]]; then timeout=120; else timeout=1800; fi
fi

# Re-entrancy: we already hold the lock (a build script nested inside a
# locked cargo build) — run the command directly, cargo's own per-dir lock
# is uncontended (only one cargo runs at a time).
if [[ "${BUILD_LOCK_HELD:-}" == "1" ]]; then
  exec "$@"
fi

mkdir -p "$LOCK_DIR"
my_pid=$$
my_prio=$(prio "$role")

# Waiter registration (diagnostics: who is waiting and since when).
WAITERS_DIR="$LOCK_DIR/waiters"
mkdir -p "$WAITERS_DIR"
echo "$role $(date +%s)" > "$WAITERS_DIR/$my_pid"
release() { rm -rf "$LOCK_FILE" 2>/dev/null || rmdir "$LOCK_FILE" 2>/dev/null || true; }
trap 'rm -f "$WAITERS_DIR/$my_pid"; release' EXIT
# signal the holder to let go (graceful preemption)
#
# NEVER PREEMPT A CORE HOLDER WITH A CORE WAITER. The core role is the only
# one that preempts at all, and it is also the role that builds on a 180s
# budget. Two core-role callers therefore deadlock *into a kill*: the waiter
# waits out its 180s, then SIGTERMs the holder — which is the estree loop
# ITSELF whenever the loop's own build gate holds the lock while a second
# core-role build queues behind it. The loop dies mid-gate with no exit line,
# because the TERM arrives while it is inside a backtick (Perl runs the
# command in a forked child but the signal still lands on the loop's pid, and
# the loop has no TERM handler) — logged as nothing at all, which reads
# exactly like "the estree worker vanished for no reason".
#
# Measured 2026-10-10: the supervised estree worker was started five times and
# died five times, every death inside a gate, with no "child exited" line from
# supervise.sh (a supervisor restart that never happens) and no DEATH-PROBE
# output — i.e. SIGKILL- or TERM-with-no-trap. The lock's own `status` file
# named the holder and `preempt_holder` was the only TERM sender on the box.
#
# The escalation exists to break a *backend* build that is hogging the lock,
# and the prio comparison already expresses that: core (0) outranks backend
# (2). Preempting another core-role holder buys nothing — the two waiters are
# peers, and the "winner" is whichever started first. It only destroys work.
# So: preempt only a strict lower-priority holder, and let a peer keep the
# lock. The waiter still gives up after timeout+grace with a named error, so
# a genuine lock wedge is still reported rather than spun on.
preempt_holder() {
  local holder holder_role
  holder=$(awk '{print $1}' "$STATUS_FILE" 2>/dev/null || true)
  holder_role=$(awk '{print $2}' "$STATUS_FILE" 2>/dev/null || true)
  if [[ -n "$holder" && "$holder" != "$my_pid" ]] && kill -0 "$holder" 2>/dev/null; then
    if [[ "$holder_role" == "core" && "$role" == "core" ]]; then
      echo "build-lock.sh: [$role] not preempting holder pid $holder — it is also role '$holder_role' (a peer, not a subordinate); the core role must never SIGTERM the estree loop that holds this lock" >&2
      return 0
    fi
    echo "build-lock.sh: [$role] preempting holder pid $holder (waited ${timeout}s)" >&2
    kill -TERM "$holder" 2>/dev/null || true
  fi
}

acquire() {
  local deadline=$(( $(date +%s) + timeout ))
  local escalated=0
  # How long a lock dir with NO holder record must be observed before it is
  # treated as stale and reclaimed (seconds). See the "no holder record"
  # branch below: without this the mkdir->record window is a STEAL window.
  local no_record_since=""
  while true; do
    if mkdir "$LOCK_FILE" 2>/dev/null; then
      # acquired — record the holder (pid role since). The record is written
      # INSIDE the lock dir when possible so mkdir and the record are created
      # as close together as the filesystem allows; the sibling $STATUS_FILE
      # copy is kept for back-compat with readers that expect it there.
      echo "$my_pid $role $(date +%s)" > "$LOCK_FILE/holder" 2>/dev/null || true
      echo "$my_pid $role $(date +%s)" > "$STATUS_FILE"
      return 0
    fi
    # stale lock? the holder died without releasing (SIGKILL, crash, or a
    # reboot that wiped the whole process table).
    #
    # TWO ways a lock is stale, and the original check only caught the first:
    #   1. the status record names a process that is no longer alive
    #   2. there is NO usable status record at all (empty or missing file)
    # (2) is the reboot case and it was a REAL deadlock, not a theoretical
    # one: the lock dir survived the reboot, the status file came back empty
    # (it is truncated/absent), so the old `-n "$holder"` guard short-
    # circuited, and the lock was never released. Every worker then polled
    # here forever — the core build and eight backend gates sat blocked for
    # 20+ minutes with an idle box.
    #
    # The comment that used to sit here ("a lock dir with no record cannot
    # belong to a live holder of THIS lock") was WRONG, and the belief
    # embedded in it is what caused the steal below.
    #
    # THE ABSENT-RECORD RACE (fixed 2026-10-03).
    #
    # Winning the lock is two steps: `mkdir $LOCK_FILE` (line above) and
    # then writing the holder record. Between them the lock dir EXISTS but
    # carries NO record, and this branch used to read that as "dead holder"
    # and reclaim it — so a waiter arriving in that window STOLE the lock
    # from a live holder. Reproduced deterministically: with a holder that
    # had mkdir'd but not yet recorded, a `build-lock.sh` waiter logged
    # "removing stale lock ... (no holder record)" and then acquired the
    # lock, and TWO cargo builds ended up sharing one target dir. A
    # partially-written target is not a compile error, so it surfaced
    # downstream as an intermittent "core build FAILED" / "probe failed" in
    # the backend workers — a build break that did not exist in the source.
    #
    # A missing record is therefore NOT sufficient to reclaim on the first
    # sighting. Age it: only treat a record-less lock as stale once it has
    # been seen record-less for $NO_RECORD_STALE_S continuously. That
    # preserves the ORIGINAL two recoveries (a SIGKILLed holder, and the
    # reboot case where the dir survives with an empty record) — both of
    # which stay record-less far longer than the grace — while making the
    # mkdir->record window impossible to steal.
    local now_s=$(( $(date +%s) ))
    local holder_rec
    holder_rec=$(awk '{print $1}' "$STATUS_FILE" 2>/dev/null || true)
    if [[ -z "$holder_rec" && ! -s "$LOCK_FILE/holder" ]]; then
      if [[ -z "$no_record_since" ]]; then
        no_record_since=$now_s
      elif (( now_s - no_record_since >= NO_RECORD_STALE_S )); then
      echo "build-lock.sh: removing stale lock at $LOCK_FILE (no holder record for ${NO_RECORD_STALE_S}s — dead holder, reboot, or a foreign flock holder; this path is ours alone)" >&2
      release; rm -f "$STATUS_FILE"
      no_record_since=""
      continue
      fi
    else
      no_record_since=""
    fi
    if [[ -n "$holder_rec" && "$holder_rec" != "$my_pid" ]] && ! kill -0 "$holder_rec" 2>/dev/null; then
      echo "build-lock.sh: removing stale lock (holder $holder_rec dead)" >&2
      release; rm -f "$STATUS_FILE"
      no_record_since=""
      continue
    fi
    # core escalation: waited past the timeout → SIGTERM the holder once,
    # then keep trying through the grace window before failing.
    #
    # The core role previously had NO timeout exit: once it escalated, it
    # looped forever. That is why the gate's `cargo test --lib` came back with
    # EMPTY output and no `test result:` line — not a hung test at all, a
    # build-lock that was still spinning on the lock. The gate read that
    # correctly ("no lib-test summary (hung or crashed)") but the diagnosis
    # was wrong, and nothing in the log named the lock. Core now gives up after
    # timeout + grace, and says so, so a lock problem is never again reported
    # as a test-suite hang.
    if [[ "$my_prio" -eq 0 && $(( $(date +%s) )) -ge "$deadline" && "$escalated" -eq 0 ]]; then
      preempt_holder
      escalated=1
    fi
    if [[ "$my_prio" -eq 0 && $escalated -eq 1 && $(( $(date +%s) )) -ge "$((deadline + grace))" ]]; then
      echo "build-lock.sh: [$role] timed out after ${timeout}s (+${grace}s grace) waiting for the build lock; a foreign flock-style holder is not preemptible — giving up so the caller sees a lock error, not a silent empty run" >&2
      exit 1
    fi
    if [[ "$my_prio" -ne 0 && $(( $(date +%s) )) -ge "$deadline" ]]; then
      echo "build-lock.sh: [$role] timed out after ${timeout}s waiting for the build lock" >&2
      exit 1
    fi
    sleep 0.2
  done
}

acquire
# The EXIT trap must also take down the WATCHDOG (defined further down, once
# a command is actually running). Without that, every exit path other than
# the intended one — set -e firing, a signal, any early return after the
# watchdog starts — orphaned a subshell that then slept for the full
# MAX_BUILD_SECS with nothing left to kill it.
#
# The cost was a self-inflicted fork bomb. 165 live watchdog subshells, ~190
# new ones per minute, filled sh2gates to its pids.max (1024); pids.events
# recorded 5808+ refused forks; and every gate then reported ~551/555
# failures with "Can't fork, trying again" — a measurement that read as a
# catastrophic code regression and was really an exhausted process table.
#
# `${watchdog_pid:-}` because this trap is installed BEFORE the watchdog
# exists, and the trap must stay valid for the whole lifetime of the script.
cleanup() {
  if [ -n "${watchdog_pid:-}" ]; then
    # TERM, then KILL the watchdog's process group, then reap it.
    #
    # KILL is not optional here. When the watchdog is FIRING it is sitting in
    # `sleep "$grace"` between its own TERM and KILL of the command group, and
    # a shell blocked in `sleep` does not act on TERM until the sleep returns —
    # so a TERM-only cleanup is silently dropped on exactly the path where
    # cleanup matters most (a hung build, the case the watchdog exists for).
    # Measured with the fix in place: a clean command, a failing command, and
    # a watchdog-killed command together orphan 1 watchdog; the TERM-only
    # version orphaned one per firing.
    #
    # The `sleep 0.1` gives the TERM a moment to work before KILL, so a
    # well-behaved watchdog exits cleanly rather than always being KILLed.
    kill -TERM -"$watchdog_pid" 2>/dev/null || kill -TERM "$watchdog_pid" 2>/dev/null || true
    local _i=0
    while [ $_i -lt 5 ]; do
      kill -0 "$watchdog_pid" 2>/dev/null || break
      sleep 0.1
      _i=$((_i+1))
    done
    kill -KILL -"$watchdog_pid" 2>/dev/null || kill -KILL "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  fi
  rm -f "$WAITERS_DIR/$my_pid"
  release
  rm -f "$STATUS_FILE"
}
trap cleanup EXIT

# shared target: default to the main checkout's dir (core dedup); an
# explicit CARGO_TARGET_DIR in the environment wins.
if [[ -n "$share_target" ]]; then
  export CARGO_TARGET_DIR="$share_target"
elif [[ -z "${CARGO_TARGET_DIR:-}" ]]; then
  export CARGO_TARGET_DIR="$ROOT/sh2perl/target"
fi
export BUILD_LOCK_HELD=1

# run the command as a child so a preemption SIGTERM reaches the actual
# build (the holder's cargo child is killed, the lock released, and the
# preempting core build can proceed instead of blocking on cargo's own
# per-dir lock behind an orphaned build).
#
# WATCHDOG (added 2026-09-26): a hung TEST is not a hung build. libtest runs
# each test on its own thread inside ONE test binary; if a test spins forever
# (we hit exactly this — rust_backend::inline_print_words looping in
# str::find), the binary never exits, `wait` below never returns, and this
# wrapper holds the single build lock for the whole fleet. Worse, when the
# spawning cargo is killed the test binary is ORPHANED to init and keeps
# spinning — so killing the parent does not free the lock, only killing the
# process GROUP does.
#
# So: put the command in its own process group, bound it by MAX_BUILD_SECS
# (default 15 min — a normal full build+test is ~10-60s, and even a COLD
# full-corpus rebuild is a few minutes, so 15 min is far above any legitimate
# run and far below an overnight wedge), and on overrun kill the GROUP, not
# just the child. The lock is then released by the EXIT trap and the next
# waiter proceeds. The timeout is reported loudly: a build that needs longer
# is a real signal too, not something to mask.
MAX_BUILD_SECS="${MAX_BUILD_SECS:-900}"
# FD HYGIENE (2026-09-26): close every inherited fd >= 3 for the children
# below. This wrapper is invoked from inside `( flock 9 ... ) 9>"$WORKSPACE/
# .gate.lock"`, so fd 9 — THE GATE LOCK — is inherited by anything we spawn.
# An orphaned survivor then holds the gate lock with no work to do, and every
# backend worker blocks on flock with an idle box. That happened for real:
# a leftover watchdog `sleep 900` whose parent build-lock had already exited
# held .gate.lock and stalled the c backend gate for ~50 min. The watchdog
# and the build itself need NO inherited fds, so close them.
#
# STDOUT IS THE OTHER HALF OF THAT BUG (2026-09-26, same incident). Closing
# fds >= 3 is NOT enough, because the survivor also held the caller's PIPE:
# build-lock runs inside the perl/estree loops' `open(my $fh, '-|', ...)`
# backtick, so the watchdog inherited the pipe's WRITE end. When build-lock
# exited, `kill "$watchdog_pid"` killed the watchdog subshell but not the
# `sleep` it was blocked in — and that sleep kept the pipe open for the full
# MAX_BUILD_SECS, so the reader blocked in sysread long after the build was
# done. The estree loop's `fail-estree --metric` sat frozen (I/O counters
# flat, wchan anon_pipe_read) for half of every iteration.
#
# So the watchdog runs under `setsid` (its own process group, so killing the
# group reaches the `sleep`) and redirects stdout to /dev/null: it must never
# be able to hold a caller's pipe open, whatever the caller's fd 1 is. Its
# diagnostics stay on stderr, which callers read with 2>&1. The build child
# is deliberately NOT changed — it legitimately owns the caller's stdout,
# which is what a backtick is reading.
setsid bash -c 'for f in $(seq 3 32); do eval "exec ${f}>&-" 2>/dev/null || true; done; exec "$@"' _ "$@" &
cmd_pid=$!
trap 'kill -TERM -"$cmd_pid" 2>/dev/null || true; sleep 1; kill -KILL -"$cmd_pid" 2>/dev/null || true; exit 143' TERM
setsid bash -c '
  for f in $(seq 3 32); do eval "exec ${f}>&-" 2>/dev/null || true; done
  exec >/dev/null
  sleep "$1"
  if kill -0 "$2" 2>/dev/null; then
    echo "build-lock.sh: [$3] WATCHDOG — command still running after $1s (pid $2); killing process group. A hung TEST looks like this." >&2
    kill -TERM -"$2" 2>/dev/null || true
    sleep 5
    kill -KILL -"$2" 2>/dev/null || true
  fi
' _ "$MAX_BUILD_SECS" "$cmd_pid" "$role" &
watchdog_pid=$!
wait "$cmd_pid"
rc=$?
kill -TERM -"$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true
# A watchdog kill means the lock must NOT be recorded as a clean release:
# the caller needs to see a failure, not a silent success.
exit "$rc"
