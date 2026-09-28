#!/bin/bash
# harness/kill-session.sh — run a command in its own session, then make sure
# NOTHING from that session survives it.
#
# WHY THIS EXISTS. Both corpus gates used to invoke an example as
#
#     timeout N bash example.sh
#
# and hardened that to
#
#     setsid timeout -k 2 N bash example.sh
#
# which is better but STILL leaks. Measured on 2026-09-28: 8 concurrent runs
# of 096_head_procsub.sh through the setsid form left 3–8 orphans per batch
# under the gate's real load, and they accumulated to fill sh2gates'
# pids.max (1024), after which every gate reported ~551/555 failures with
# "Can't fork" — a measurement that read as a catastrophic code regression.
#
# The mechanism, established by tracing a survivor's ancestry:
#
#   1. setsid gives the run its own process group and session.
#   2. 096_head_procsub.sh is `head <(while true; do echo .; sleep 1; done)`.
#      `head` exits after 10 lines, closing the read end of the pipe.
#   3. Under this fleet SIGPIPE is IGNORED (systemd sets IgnoreSIGPIPE=yes
#      and every worker inherits it), so the writer does not die of EPIPE —
#      it keeps looping. Its parent bash has already exited, so the kernel
#      REPARENTS it to init/systemd.
#   4. A reparented process is in no group that `timeout` can signal. The
#      group leader is already dead by the time -k would fire, so the sweep
#      finds nothing to kill and the writer runs forever.
#
# So process-group teardown cannot fix this class: the survivor outlives the
# group. What DOES work is matching on the SESSION, which the orphan keeps
# (reparenting changes the parent, not the session), and killing after the
# command has been reaped.
#
# Usage: harness/kill-session.sh <command> [args...]
# Exits with the command's status. Best-effort: if /proc is unreadable the
# command still runs and still reports its own status — a missing sweep must
# never turn a passing example into a failing one.
set -u

if [ $# -eq 0 ]; then
    echo "kill-session.sh: no command given" >&2
    exit 2
fi

# setsid puts the command in a new session; $! is the setsid process, which
# execs the command, so it carries the same SID.
setsid "$@" &
child=$!

# Read the SID from the child itself rather than assuming, and retry briefly:
# the child may not have called setsid(2) yet when we look.
sid=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sid=$(ps -o sid= -p "$child" 2>/dev/null | tr -d ' ')
    [ -n "$sid" ] && break
    sleep 0.05
done

wait "$child"
rc=$?

if [ -n "$sid" ]; then
    self=$$
    for p in /proc/[0-9]*; do
        [ -r "$p/stat" ] || continue
        pid=${p#/proc/}
        [ "$pid" = "$self" ] && continue
        [ "$pid" = "$child" ] && continue
        s=$(ps -o sid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ "$s" = "$sid" ] || continue
        # TERM first so a well-behaved child can clean up, then KILL on the
        # next pass. `kill` here is deliberately not a group kill: the point
        # is to catch members that are no longer in a live group.
        kill -TERM "$pid" 2>/dev/null
    done
    # Give the TERM a moment, then make sure. A `while true; do sleep 1; done`
    # writer does not act on TERM while blocked in sleep, so KILL is the
    # reliable finish.
    sleep 0.2
    for p in /proc/[0-9]*; do
        [ -r "$p/stat" ] || continue
        pid=${p#/proc/}
        [ "$pid" = "$self" ] && continue
        [ "$pid" = "$child" ] && continue
        s=$(ps -o sid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ "$s" = "$sid" ] || continue
        kill -KILL "$pid" 2>/dev/null
    done
fi

exit "$rc"
