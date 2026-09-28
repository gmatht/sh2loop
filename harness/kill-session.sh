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

# The sweep below must not itself become a load source. The first version
# ran `ps -o sid= -p <pid>` for EVERY live pid, twice — on this box that is
# 2 x N forks per example (N=647 at the time of writing, i.e. ~1300 `ps`
# processes per invocation). A 555-example gate is 2 sides x 555 x 1300 =
# ~1.4M short-lived processes, which is precisely the fork/fork-storm load
# this wrapper exists to keep off the box. One `awk` over /proc/N/stat reads
# every pid's session in a single pass with no forks; `kill` is a builtin.
#
# /proc/N/stat layout: pid (comm) state ppid pgrp session ... — `comm` may
# contain spaces AND parentheses, so the fields are taken AFTER the LAST ')'
# rather than by splitting the whole line.
session_members() {
    awk -v want="$sid" '
        { i = 0
          for (p = 1; p <= length($0); p++) if (substr($0, p, 1) == ")") i = p
          if (!i) next
          n = split(substr($0, i + 2), f, " ")
          if (n < 4) next
          if (f[4] == want) print f[1] }        # f[4] = session
    ' /proc/[0-9]*/stat 2>/dev/null
}

if [ -n "$sid" ]; then
    self=$$
    # TERM first so a well-behaved child can clean up, then KILL on the
    # next pass. `kill` here is deliberately not a group kill: the point
    # is to catch members that are no longer in a live group.
    for p in $(session_members); do
        [ "$p" = "$self" ] && continue
        [ "$p" = "$child" ] && continue
        kill -TERM "$p" 2>/dev/null
    done
    # Give the TERM a moment, then make sure. A `while true; do sleep 1; done`
    # writer does not act on TERM while blocked in sleep, so KILL is the
    # reliable finish.
    sleep 0.2
    for p in $(session_members); do
        [ "$p" = "$self" ] && continue
        [ "$p" = "$child" ] && continue
        kill -KILL "$p" 2>/dev/null
    done
fi

exit "$rc"
