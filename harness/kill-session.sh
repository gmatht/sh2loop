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

# ── equivalence-gate CWD stabilization ──────────────────────────────────
# The c and perl arms of `setup_backends.sh --backend-gate` run BOTH sides of
# the equivalence verdict inside a per-cell scratch:
#
#     (cd "$eq_scratch" && kill-session.sh <cmd>)      # the translation
#     (cd "$eq_scratch" && kill-session.sh bash "$f")  # the reference
#
# with eq_scratch = `mktemp -d "$WORKSPACE/.eq_scratch_$$.XXXXXX"` — a DIRECT
# CHILD OF THE SHARED WORKSPACE ROOT. That root churns continuously while the
# fleet runs (workers create/remove scratch and log directories in it;
# measured 29 link-count changes per minute on this box). `ls -la` prints the
# `..` entry, i.e. THAT root's link count and mtime, so the C run and the bash
# run — milliseconds apart — disagree whenever the root changed between them
# and a FAITHFUL translation is scored EQUIV-FAIL. Measured on
# 062_hard_to_lex.sh (`ls -la | grep "^d" | head -5`) under controlled churn:
# 15/25 runs red; the only difference was the `..` link count (77 vs 78).
#
# Fix: run one level deeper, in `$scratch/.sh2run/run`. BOTH sides move
# together, so every observable (the CWD's contents, the files each side
# creates, `$PWD`, `cd ..`) stays exactly as before — but now `..` is
# `.sh2run`, created by whichever side runs first and REUSED by the second, so
# its link count and mtime are identical for both. `.sh2run/run` lives inside
# the gate's own scratch, so it is deleted with it: nothing new leaks into the
# workspace and no pass-boundary bookkeeping is needed.
#
# Scoped strictly to the gate's scratch shape (its basename is
# `.eq_scratch_*`): every other caller of this wrapper — the sh/rust/zsh arms,
# chimera-gate.sh, batch-triage.sh, the perl triage helpers — runs from a
# caller-chosen CWD and is untouched.
case "${PWD##*/}" in
    .eq_scratch_*)
        if mkdir -p "$PWD/.sh2run/run" 2>/dev/null; then
            cd "$PWD/.sh2run/run" 2>/dev/null || true
        fi
        ;;
esac

# setsid puts the command in a new session; $! is the setsid process, which
# execs the command, so it carries the same SID.
setsid "$@" &
child=$!

# The SID is $child, and probing for it is pure cost.
#
# `setsid` in a non-interactive shell is not a process-group leader, so it does
# NOT fork: it calls setsid(2) IN PLACE, which makes the child the new session
# leader — so SID == the child's pid by construction. The orphan keeps that
# session after the leader is reaped (reparenting changes the parent, not the
# session), so the child's pid still names the session the sweep must close.
#
# This used to VERIFY that with a 10-iteration probe (`ps -o sid= -p $child`,
# sleep 0.05 between attempts) and fall back to $child when the probe came
# back empty. That probe was the single most expensive thing in the
# equivalence gate, and it could only ever return $child:
#
#   true (instant)   probe= 787 ms  iters=10
#   sleep 0.3        probe=  34 ms  iters= 1
#   sleep 1          probe=  27 ms  iters= 1
#
# A command that finishes in 3ms is reaped BEFORE the probe's first `ps`, so
# it always burned all ten iterations (10 `ps` forks + 10x 0.05 sleeps) to
# learn nothing. The cost scales with the example, not the workload: the
# corpus runs this wrapper TWICE per example (the translation and the bash
# reference), so a 648-example pass paid 2 x 648 x ~790ms ~= 17 minutes of
# pure process-spawn overhead — the whole reason a rust gate took 26-122 min
# when its actual work measured 46s.
#
# One probe, then $child. The single `ps` costs ~18ms and still catches the
# only case the loop was written for (setsid genuinely not having called
# setsid(2) yet); the retry could not add information, because the value it
# converges on is already known.
sid=$(ps -o sid= -p "$child" 2>/dev/null | tr -d ' ')
[ -n "$sid" ] || sid="$child"

wait "$child"
rc=$?

# The member list must be read in ONE pass. The first version ran
# `ps -o sid= -p <pid>` for EVERY live pid, twice — on this box that is
# 2 x N forks per example (N=647 at the time of writing, i.e. ~1300 `ps`
# processes per invocation): precisely the fork/fork-storm load this wrapper
# exists to keep off the box. One `ps -e` covers every pid, and the `awk`
# only compares the session column.
#
# `ps -e -o sid=,pid=,stat=` (sid, pid, state) rather than the old
# single-pass awk over /proc/[0-9]*/stat: that awk was FLAKY — it reported an
# empty session ~1 scan in 5 even while the members were alive — so the
# sweep below broke out early and skipped the kill on one side but not the
# other. Measured: 6/6 runs with ps, 32/40 with the /proc awk. A verdict
# oracle cannot be built on a scan that misses live processes at random.
#
# Zombies are excluded: they are already dead, killing them is a no-op, and
# counting one as a live member makes the settle loop below spin.
session_members() {
    ps -e -o sid=,pid=,stat= 2>/dev/null | awk -v want="$sid" '$1 == want && $3 != "Z" { print $2 }'
}

if [ -n "$sid" ]; then
    self=$$
    members=$(session_members)
    if [ -n "$members" ]; then
        # Terminate the whole session in ONE pass, with no dwell between TERM
        # and KILL. The dwell was an ASYMMETRY an equivalence gate can SEE:
        # bash defers SIGTERM while it is blocked in a child — an orphan like
        # `(sleep 1; echo a)&` keeps running through the dwell, writes `a` to
        # the capture file, and only then dies — while the C side, whose
        # orphan is a plain fork, dies on TERM at once and writes nothing.
        # want.txt then ended in `a` and got.txt did not, and
        # 048_subprocess.sh flaked on exactly that. `kill` here is
        # deliberately not a group kill: the point is to catch members that
        # are no longer in a live group.
        for p in $members; do
            [ "$p" = "$self" ] && continue
            [ "$p" = "$child" ] && continue
            kill -TERM "$p" 2>/dev/null
            kill -KILL "$p" 2>/dev/null
        done
        # Nothing from the session may outlive the sweep: a straggler would
        # still be writing to the capture file while the caller reads and
        # diffs it, which is the same race one level down. Bounded and
        # fail-open — a missing sweep must never hang the gate.
        _i=0
        while [ "$_i" -lt 10 ]; do
            [ -z "$(session_members)" ] && break
            sleep 0.05
            _i=$((_i + 1))
        done
    fi
fi

exit "$rc"
