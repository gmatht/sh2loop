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

# ── join the throttled IO slice ──────────────────────────────────────────
#
# WHY THIS IS HERE AND NOT ONLY IN THE UNITS. The io.max caps on the single
# virtio queue only bind processes that are actually IN sh2-io.slice. A
# systemd unit can ask for that with Slice=, but the fleet is not always
# started by systemd: the workers also run from hand-typed zellij panes, which
# are all in /init.scope. With every worker in init.scope the slice sat at
# procs=0 and the 200 MB/s cap guarded nothing at all.
#
# So the supervisor puts ITSELF in the slice, and the child inherits it. That
# covers every launch path at once: systemd units, zellij panes, cron, or a
# bare `supervise.sh` on a terminal. (Verified that a process may migrate
# itself from /init.scope into /sys/fs/cgroup/sh2.slice/sh2-io.slice by writing
# its own pid to that cgroup's cgroup.procs.)
#
# It is best-effort on purpose. If the slice is missing, or this box has no
# cgroup v2 io controller, or we lack permission, the supervisor must still
# run the worker -- refusing to start a worker because a THROTTLE is
# unavailable inverts the priority. The worst case of not finding the slice is
# exactly the status quo: no throttle, no crash.

SH2_IO_SLICE="${SH2_IO_SLICE:-sh2-io.slice}"

join_io_slice() {
  # systemd nests X.slice under a parent slice named after the leading
  # component, so sh2-io.slice lives under /sys/fs/cgroup/sh2.slice/. Search
  # rather than guess, and search at most two levels deep.
  local cg=""
  for cand in "/sys/fs/cgroup/system.slice/$SH2_IO_SLICE" \
              "/sys/fs/cgroup/$SH2_IO_SLICE" \
              "/sys/fs/cgroup/sh2.slice/$SH2_IO_SLICE"; do
    [ -d "$cand" ] && { cg="$cand"; break; }
  done
  [ -n "$cg" ] || cg=$(find /sys/fs/cgroup -maxdepth 2 -type d -name "$SH2_IO_SLICE" 2>/dev/null | head -1)
  if [ -z "$cg" ]; then
    note "IO slice $SH2_IO_SLICE not found — running unthrottled (same as before this existed)"
    return 0
  fi
  if echo $$ > "$cg/cgroup.procs" 2>/dev/null; then
    note "joined IO slice: $cg -> $(cat "$cg/io.max" 2>/dev/null | tr '\n' ' ')"
  else
    note "could not join IO slice $cg (permission denied?) — running unthrottled"
  fi
}

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

# Stop the child when the supervisor is told to stop.
#
# WHY (2026-09-28). This used to be
#   trap 'note "... (child will be orphaned)"; exit 143' TERM INT
# i.e. it announced the orphaning and then did it. `systemctl stop` on a
# worker unit therefore left the WORKER RUNNING: the supervisor exited, the
# unit went to `failed`, and the child — a main_loop_*.pl, a
# setup_backends.sh gate, a whole fail-estree run — kept writing to the
# shared repo with nothing supervising it. Stopping six units left six
# orphaned writers alive, which is what made "stop the workers" silently
# fail; I only found them because the shared checkout's HEAD kept moving
# after every unit reported stopped.
#
# A never-retire supervisor must still be able to STOP. The backoff loop
# below restarts the child unconditionally, so on TERM we kill the child's
# whole process group and exit without giving the loop another turn —
# otherwise the supervisor would dutifully restart what it just killed.
on_term() {
  note "supervisor received TERM — stopping child and exiting"
  stop_child
  exit 143
}

# Wait for the child, but stay interruptible.
#
# WHY NOT `wait "$child"` (2026-09-28). A bare `wait` in a shell script BLOCKS
# signal handling: bash does not run the TERM trap until the wait returns, and
# the wait does not return until the child exits. So a supervisor told to stop
# sat in do_wait for as long as its child lived — with a child that ignores
# TERM, forever. The trap body never got to run, so the TERM handler I added
# (which is what stops the child) could never fire: a deadlock between "wait
# for the child" and "stop the child".
#
# Polling with `kill -0` breaks that cycle. It is a tiny busy-ish loop, but
# the sleep interval is 0.2s, so the cost is a handful of `kill -0` calls per
# second of a worker's runtime — nothing next to a cargo build — and in
# exchange the supervisor is always responsive to TERM/INT, which is the
# whole point of supervising something.
# Sets the global CHILD_RC rather than echoing it: `$(wait_child ...)` would
# run this in a command-substitution SUBSHELL, and that subshell inherits the
# TERM/INT traps. A `systemctl stop` signals the process group, so the
# subshell receives the TERM, runs the stop handler itself, and dies still
# holding the parent's wait — leaving the real supervisor hung in do_wait
# with its child untouched. (Reproduced: TERM to one supervisor left all
# three processes alive, and the log showed the "stopping" line never
# printed from the parent.) Assigning to a global keeps the loop in the
# parent shell, where the trap belongs.
CHILD_RC=0
wait_child() {
  local pid="$1"
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.2
  done
  # The child has exited; reap it so it does not linger as a zombie. `wait`
  # is safe here precisely because the child is already gone, so it returns
  # immediately.
  wait "$pid" 2>/dev/null
  CHILD_RC=$?
}

# Kill the child's process group, escalating TERM -> KILL. The child is
# started under `setsid` when --max-secs is set (so it has its own group);
# otherwise it shares ours and we must NOT group-kill, or the signal would
# reach the supervisor too. getpgid is unavailable in POSIX sh, so compare
# the child's pgid with our own.
stop_child() {
  [ -n "${child:-}" ] || return 0
  local cpgid opgid
  cpgid=$(ps -o pgid= -p "$child" 2>/dev/null | tr -d ' ')
  opgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
  if [ -n "$cpgid" ] && [ -n "$opgid" ] && [ "$cpgid" != "$opgid" ]; then
    # The child owns its process group (the --max-secs setsid path), so one
    # group signal reaches its whole tree.
    kill -TERM -"$cpgid" 2>/dev/null || true
  else
    kill -TERM "$child" 2>/dev/null || true
  fi

  # Give it a moment to die cleanly, then make sure. An orphaned gate that
  # ignores TERM is exactly the case that must not survive us.
  local i=0
  while [ $i -lt 20 ]; do
    kill -0 "$child" 2>/dev/null || break
    sleep 0.25
    i=$((i+1))
  done

  # KILL the whole subtree, not just the child.
  #
  # In the shared-pgid case a group kill is not available — the supervisor is
  # in that group, so `kill -KILL -$pgid` would kill us before the children.
  # Signalling each descendant individually is the only way to take the tree
  # down without taking ourselves with it, and it is necessary: a stuck gate
  # routinely leaves grandchildren (a `while true` writer, a cargo child, a
  # node runner) that outlive their parent and keep writing to disk. Killing
  # the child alone is what left those running in the first place.
  local sig=KILL
  if kill -0 "$child" 2>/dev/null; then
    note "child $child did not exit on TERM — killing its process tree"
  else
    sig=TERM
  fi
  if [ -n "$cpgid" ] && [ -n "$opgid" ] && [ "$cpgid" != "$opgid" ]; then
    kill -"$sig" -"$cpgid" 2>/dev/null || true
  fi
  # Walk the subtree depth-first, deepest first, so a parent cannot spawn
  # fresh children while we are signalling it. Snapshot the pid list once:
  # re-globbing /proc during the walk races with processes exiting.
  local kids k
  kids=$(subtree_of "$child")
  for k in $(echo "$kids" | tac); do
    kill -"$sig" "$k" 2>/dev/null || true
  done
  kill -"$sig" "$child" 2>/dev/null || true

  # Confirm the tree is actually gone rather than assuming the signal landed.
  local j left=""
  for j in $(seq 1 20); do
    left=$(subtree_of "$child")
    [ -z "$left" ] && break
    for k in $left; do kill -KILL "$k" 2>/dev/null || true; done
    sleep 0.25
  done
  left=$(subtree_of "$child")
  [ -n "$left" ] && note "WARNING: descendants of $child survived stop: $(echo $left)"
  return 0
}

# All living descendants of a pid, one per line (depth-first, parents before
# children). Reads /proc directly: `pgrep -P` is a fork per level and `ps
# --ppid` is not portable, and this runs in a recovery path where the system
# is already under stress. The child's own pid is NOT included.
subtree_of() {
  local root="$1" p pid out=""
  for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    [ -r "$p/stat" ] || continue
    # ppid is field 4, but comm (field 2) may contain spaces and parens, so
    # split on the LAST ')' rather than assuming a clean field layout.
    local ppid
    ppid=$(sed 's/.*) //' "$p/stat" 2>/dev/null | awk '{print $2}')
    [ -n "$ppid" ] || continue
    if [ "$ppid" = "$root" ]; then
      out="$out $pid"
      local sub
      sub=$(subtree_of "$pid")
      [ -n "$sub" ] && out="$out $sub"
    fi
  done
  echo $out
}

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
# NAME THE DEATH (2026-10-10). A supervisor that vanishes WITHOUT an exit line
# is indistinguishable from one that never started: the pidfile goes stale and
# the log's last entry is the worker's own output. That ambiguity cost hours —
# the estree and core workers were each restarted five-plus times while the
# cause was invisible, because the only exits that logged were TERM (via
# on_term) and a child exit inside the restart loop.
#
# `$?` is the exit status at the moment the trap starts; 143/130 mean a TERM/INT
# that bypassed on_term, and anything else is an abrupt end (a SIGKILL leaves
# NO trace at all, which is itself the diagnosis: an empty trailing line means
# "killed, not exited").
#
# ONE EXIT TRAP ONLY (bugfix 2026-10-10): this used to read
#   trap exit_trace EXIT
#   trap cleanup EXIT
# but bash does NOT stack same-signal traps — the second REPLACES the first
# (POSIX: setting a trap replaces the existing action). exit_trace therefore
# NEVER RAN, and *every* supervisor death looked like a SIGKILL, including
# ordinary TERM exits whose "received TERM" note had failed. The combined
# trap below restores the intended behavior: the trace runs first (so `$?`
# is still the triggering status), then cleanup.
exit_trace() {
  local st=$?
  note "supervisor EXITING rc=$st (uptime ${SECONDS}s, restarts=$restarts) — if this is the last line and the process is gone, it was killed, not stopped"
}
trap 'exit_trace; cleanup' EXIT
trap 'on_term' TERM INT

# Publish our pid atomically so `kill $(cat file)` never reads a half-written
# file. The old hand-typed loops wrote nothing at all, which is why a dead
# worker left a stale pid behind with nobody to clean it.
if [ -n "$pidfile" ]; then
  tmp="$pidfile.tmp.$$"
  echo $$ > "$tmp" 2>/dev/null && mv -f "$tmp" "$pidfile" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
fi

note "supervisor started (pid $$, command: $*)"

# Join the throttled IO slice now that the lock is held and note() works, so
# the slice membership and this line land in the same log region.
join_io_slice

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
    wait_child "$child"; rc=$CHILD_RC
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
    wait_child "$child"; rc=$CHILD_RC
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
