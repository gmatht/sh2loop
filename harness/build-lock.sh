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
release() { rmdir "$LOCK_FILE" 2>/dev/null || rm -rf "$LOCK_FILE"; }
trap 'rm -f "$WAITERS_DIR/$my_pid"; release' EXIT
# signal the holder to let go (graceful preemption)
preempt_holder() {
  local holder
  holder=$(awk '{print $1}' "$STATUS_FILE" 2>/dev/null || true)
  if [[ -n "$holder" && "$holder" != "$my_pid" ]] && kill -0 "$holder" 2>/dev/null; then
    echo "build-lock.sh: [$role] preempting holder pid $holder (waited ${timeout}s)" >&2
    kill -TERM "$holder" 2>/dev/null || true
  fi
}

acquire() {
  local deadline=$(( $(date +%s) + timeout ))
  local escalated=0
  while true; do
    if mkdir "$LOCK_FILE" 2>/dev/null; then
      # acquired — record the holder (pid role since)
      echo "$my_pid $role $(date +%s)" > "$STATUS_FILE"
      return 0
    fi
    # stale lock? the holder died without releasing (SIGKILL, crash)
    local holder
    holder=$(awk '{print $1}' "$STATUS_FILE" 2>/dev/null || true)
    if [[ -n "$holder" && "$holder" != "$my_pid" ]] && ! kill -0 "$holder" 2>/dev/null; then
      echo "build-lock.sh: removing stale lock (holder $holder dead)" >&2
      release; rm -f "$STATUS_FILE"
      continue
    fi
    # core escalation: waited past the timeout → SIGTERM the holder once,
    # then keep trying through the grace window before failing.
    if [[ "$my_prio" -eq 0 && $(( $(date +%s) )) -ge "$deadline" && "$escalated" -eq 0 ]]; then
      preempt_holder
      escalated=1
    fi
    if [[ "$my_prio" -ne 0 && $(( $(date +%s) )) -ge "$deadline" ]]; then
      echo "build-lock.sh: [$role] timed out after ${timeout}s waiting for the build lock" >&2
      exit 1
    fi
    sleep 0.2
  done
}

acquire
trap 'rm -f "$WAITERS_DIR/$my_pid"; release; rm -f "$STATUS_FILE"' EXIT

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
"$@" &
cmd_pid=$!
trap 'kill -TERM "$cmd_pid" 2>/dev/null || true; sleep 1; kill -KILL "$cmd_pid" 2>/dev/null || true; exit 143' TERM
wait "$cmd_pid"
