#!/usr/bin/env bash
# supervise.sh — a NEVER-RETIRE supervisor for a long-running worker.
#
# THE BUG THIS REPLACES (2026-09-26). The backend workers were each wrapped in
# a hand-typed one-liner:
#
#     attempts=0; while [ $attempts -lt 5 ]; do
#       attempts=$((attempts+1))
#       bash setup_backends.sh --run-backend-worker 'rust'
#       sleep 5
#     done
#
# The `-lt 5` was meant as a harmless shell idiom, but it made the supervisor
# RETIRE PERMANENTLY after five child exits. The rust worker's `pir` hit its
# own `max_turns` cap (a per-invocation agent-loop limit inside pir, ~100
# turns) five times in a row, the loop finished, and the worker was gone for
# good with nothing to restart it. Its branch had not moved since 08-25.
#
# That is the failure mode we do not accept: a worker must NEVER die or give up
# after N attempts. Exponential backoff is fine. Dying is not.
#
# So the retry loop here is UNBOUNDED (`while true`). The crash counter is
# DIAGNOSTICS ONLY — it logs a warning once it gets suspicious and never gates
# anything. A worker that exits cleanly, one that crashes, and one that is
# killed by a timeout all just get restarted.
#
# The backoff is real exponential and GROWS WITHOUT CEILING (1,2,4,8,...) —
# no plateau, no maximum delay, no attempt limit of any kind. The loop still
# never gives up; growth is bounded only by integer range, so a worker that has
# been down for hours is retried ever more rarely while a transient crash still
# recovers in seconds.
#
# Usage:
#   supervise.sh --name NAME --log FILE [--pidfile FILE] [--max-secs N] \
#                [--grace N] -- <command...>
#
#   --name      label used in log lines (also the systemd unit name)
#   --log       append lifecycle events here
#   --pidfile   write the supervisor's own pid here (atomically)
#   --max-secs   per-run bound on the child; 0 = unbounded (default)
#   --grace     seconds to wait after a timeout-kill before restarting
#
# Exit: never, by design. It is a supervisor; it restarts the child forever.
set -uo pipefail

name=""; log=""; pidfile=""; max_secs=0; grace=5
while [ $# -gt 0 ]; do
  case "$1" in
    --name)     name="${2:?--name needs a value}"; shift 2;;
    --log)      log="${2:?--log needs a value}"; shift 2;;
    --pidfile)  pidfile="${2:?--pidfile needs a value}"; shift 2;;
    --max-secs) max_secs="${2:?--max-secs needs a value}"; shift 2;;
    --grace)    grace="${2:?--grace needs a value}"; shift 2;;
    --)         shift; break;;
    *) echo "supervise.sh: unknown option $1" >&2; exit 2;;
  esac
done
[ $# -gt 0 ] || { echo "supervise.sh: no command given after --" >&2; exit 2; }
[ -n "$name" ] || { echo "supervise.sh: --name is required" >&2; exit 2; }
log="${log:-/dev/null}"

note() { printf '[%s] %s: %s\n' "$(date +%FT%T)" "$name" "$*" >> "$log" 2>/dev/null || true; }

# ── re-entrancy guard: one supervisor per name ─────────────────────────
# Two supervisors racing on one worker double every build and fight over the
# same pid file and log. The lock is held for the supervisor's lifetime.
lockdir="${SUPERVISE_LOCK_DIR:-/tmp}/supervise-$name.lock"
mkdir -p "$(dirname "$lockdir")"
if ! mkdir "$lockdir" 2>/dev/null; then
  # Stale lock from a supervisor that was SIGKILLed? Reclaim it if the recorded
  # pid is gone. Never steal it from a live supervisor.
  holder=$(cat "$lockdir/pid" 2>/dev/null || echo "")
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    echo "supervise.sh: $name already supervised by pid $holder — not starting a second one" >&2
    exit 0
  fi
  rm -rf "$lockdir" 2>/dev/null || true
  mkdir "$lockdir" 2>/dev/null || { echo "supervise.sh: cannot claim $lockdir" >&2; exit 1; }
fi
echo $$ > "$lockdir/pid"
# Scratch flag used to tell "the child failed on its own" from "we killed it
# for exceeding --max-secs". A SIGTERM-killed child frequently exits 0, so
# $rc alone cannot distinguish the two and a timeout would read as a clean pass.
# Defined before cleanup() so the trap can always remove it.
SUPERVISE_TMOUT_FLAG="${TMPDIR:-/tmp}/supervise-timeout.$$"
rm -f "$SUPERVISE_TMOUT_FLAG" 2>/dev/null || true
cleanup() {
  rm -f "$lockdir/pid" 2>/dev/null || true
  rmdir "$lockdir" 2>/dev/null || true
  rm -f "$SUPERVISE_TMOUT_FLAG" 2>/dev/null || true
  # Clear the pid file ONLY if it still names us — never delete a successor's.
  if [ -n "$pidfile" ] && [ "$(cat "$pidfile" 2>/dev/null || echo)" = "$$" ]; then
    rm -f "$pidfile" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'note "supervisor received TERM — stopping (child will be orphaned)"; exit 143' TERM INT

# Publish our pid atomically so `kill $(cat file)` never reads a half-written
# file. The old hand-typed loops wrote nothing at all, which is why a dead
# worker left a stale pid behind with nobody to clean it.
if [ -n "$pidfile" ]; then
  tmp="$pidfile.tmp.$$"
  echo $$ > "$tmp" 2>/dev/null && mv -f "$tmp" "$pidfile" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
fi

note "supervisor started (pid $$, command: $*)"

crashes=0        # consecutive non-zero exits — DIAGNOSTIC ONLY
restarts=0       # total restarts ever — DIAGNOSTIC ONLY
delay=1          # current backoff, saturating (never gates, only paces)

while true; do
  if [ "$max_secs" -gt 0 ]; then
    # Own process group so a timeout can kill the child's whole tree: a hung
    # `cargo`/`node`/`pir` spawns grandchildren that outlive a plain kill of
    # the parent and keep holding build locks.
    setsid "$@" &
    child=$!
    timed_out=0
    ( sleep "$max_secs"
      if kill -0 "$child" 2>/dev/null; then
        echo timed_out > "$SUPERVISE_TMOUT_FLAG"
        note "TIMEOUT — child still running after ${max_secs}s (pid $child); killing its process group"
        kill -TERM -"$child" 2>/dev/null || true
        sleep "$grace"
        kill -KILL -"$child" 2>/dev/null || true
      fi ) &
    wd=$!
    wait "$child"; rc=$?
    kill -TERM -"$wd" 2>/dev/null || true
    kill "$wd" 2>/dev/null || true
    wait "$wd" 2>/dev/null || true
    # A timeout-killed child is a FAILURE, never a clean pass: the caller and
    # the log must see a non-zero status, not a silent success. The killed
    # child often exits 0 off a SIGTERM, so decide on the flag, not on $rc.
    if [ -f "$SUPERVISE_TMOUT_FLAG" ]; then
      timed_out=1; rm -f "$SUPERVISE_TMOUT_FLAG" 2>/dev/null || true
    fi
    [ "$timed_out" -eq 1 ] && rc=124
  else
    "$@" &
    child=$!
    wait "$child"; rc=$?
  fi

  restarts=$((restarts + 1))
  if [ "$rc" -eq 0 ]; then
    # A clean exit is a normal one-shot pass, not a failure. Reset the
    # consecutive-crash counter but keep the lifetime restart count.
    note "child exited rc=0 after run $restarts (clean pass) — restarting in ${delay}s"
    crashes=0
  else
    crashes=$((crashes + 1))
    note "child exited rc=$rc (consecutive crashes=$crashes, total restarts=$restarts) — restarting in ${delay}s"
    # Warn loudly, then keep going. A high crash count is a signal a human
    # wants, NOT a reason to stop supervising. Warn at 5 (the first genuinely
    # suspicious point) and then every 25 after, so a persistently broken
    # worker keeps reminding a human without flooding the log every restart.
    if [ "$crashes" -eq 5 ] || { [ "$crashes" -ge 5 ] && [ $(( (crashes - 5) % 25 )) -eq 0 ]; }; then
      note "WARNING — $crashes consecutive non-zero exits; the supervisor NEVER gives up (a dead worker is worse than a noisy one), but this needs a human look"
    fi
  fi

  # Exponential backoff that GROWS WITHOUT CEILING: 1,2,4,8,... with no cap
  # and no plateau. The delay is never allowed to become a constant, because
  # a constant delay is indistinguishable from a wedged worker — it looks
  # like "the supervisor is backing off on purpose" when in fact the backoff
  # has stopped adapting. Growth continues for as long as the child keeps
  # failing, so a worker that is permanently broken is retried ever more
  # rarely and a transient one is retried quickly, with no threshold at which
  # the policy silently changes.
  #
  # This is deliberately NOT capped at 60s (or at pir's 600s). A cap would
  # mean a worker that has been down for hours keeps being probed at a fixed
  # high rate forever, and — worse — the retry interval stops carrying
  # information about how bad the situation is. Growth is bounded only by
  # integer range; in practice the supervisor's own lifetime is the limit.
  #
  # The one thing that keeps this from being a hot spin loop is that growth
  # starts at 1s and doubles, so the FIRST few restarts are prompt (a
  # transient crash recovers in seconds) and a permanently broken child is
  # already at minutes, then hours, then days.
  delay=$((delay * 2))
  sleep "$delay"
done
