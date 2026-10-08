#!/bin/bash
# harness/reap-orphan-examples.sh — bound the residue left by corpus examples
# that outlive their runner.
#
# WHY THIS EXISTS. 096_head_procsub.sh is
#     head <(while true; do echo .; sleep 1; done)
# so the writer is a process-substitution child. Both corpus gates run each
# example under harness/kill-session.sh, which sweeps the run's SESSION after
# the command is reaped — measured: 4 concurrent runs leave 0 orphans. So the
# gate's own runs are clean.
#
# Two producers are not, and neither is fixable by editing a gate:
#
#   1. RESIDUE from before that wrapping existed. Observed 2026-09-28: 77
#      orphans aged up to 5h, most reparented to init, some blocked in
#      __wait_on_buffer on a deleted inode (the gate's File::Temp CLEANUP
#      removed the scratch tree while a straggler still held an fd into it).
#   2. AN AI AGENT running an example ad-hoc to debug it. Caught in the act:
#      a fresh 096 whose parent was `pir` (pid 73309), not a gate. A model's
#      shell_command cannot be intercepted by a script, so this cannot be
#      prevented here — only cleaned up.
#
# Neither blocks correctness: they cost pids, and at ~85 the process table
# still has headroom. They matter because the documented failure is
# pids.max (1024) exhaustion, after which every gate reports ~551/555
# failures with "Can't fork" — a measurement that reads as a catastrophic
# code regression.
#
# WHAT IT DOES. Kills only processes that are unambiguously a corpus example:
# the command line must name a file under a sh2perl examples/ or testdata/
# directory. That is narrow on purpose — a reaper that guesses wrong kills
# someone's work, and this runs unattended.
#
# Usage: harness/reap-orphan-examples.sh [--dry-run]
#        harness/reap-orphan-examples.sh --install-cron   # (re)install the
#           10-minute crontab entry, deriving every path from THIS file's
#           location. Run this after the workspace moves: the entry is
#           machine state (not in git), so a stale absolute path in it fails
#           silently and the orphan bound stops working. Added 2026-10-08,
#           after the /home/llm/sh2loop -> /mnt/wsl/projects/sh2loop move
#           left the documented entry pointing at a nonexistent directory.
set -u

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
WS="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "--install-cron" ]; then
  line="*/10 * * * * $SELF >/dev/null 2>>$WS/loop-orphan-reap.log"
  # Replace any existing entry for this script; keep every other line.
  cur="$(crontab -l 2>/dev/null || true)"
  new="$(printf '%s\n' "$cur" | command grep -v 'reap-orphan-examples.sh' | command grep -v '^$' || true)"
  printf '%s\n%s\n' "$new" "$line" | command grep -v '^$' | crontab -
  echo "installed crontab entry:"
  crontab -l | command grep 'reap-orphan-examples.sh'
  exit 0
fi

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# Only these shapes. Anything else is left alone.
# NOTE: no `$` anchor — the example path is usually a MIDDLE argument
# (`sh -c 'kill-session.sh' timeout 20 perl ... '<path>' '<tmp>' 2>...`), so
# the cmdline continues past it. Match the path as a quoted/space-delimited
# argument instead.
pattern="sh2perl/(examples|backends/[a-z-]+/examples|frontends/[^/]+/testdata)/[A-Za-z0-9_.-]+\.sh"

killed=0; kept=0; dry_killed=0
self=$$
now=$(date +%s)

for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    [ "$pid" = "$self" ] && continue
    # A pid can vanish between the glob and the read (this box churns ~60
    # pids/min), and `tr` is a CHILD: the shell reports the redirect failure
    # itself, so silencing tr's stderr is not enough. Guard on readability
    # first, and drop the whole iteration quietly if it still disappears.
    [ -r "$p/cmdline" ] || continue
    cmd=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    [ -n "$cmd" ] || continue
    # The corpus example must be an ARGUMENT of the running command. A shell
    # `case` glob cannot express this pattern (the alternation + `\.` are
    # mangled — it matched nothing), so use grep -E, which is unambiguous.
    printf '%s' "$cmd" | grep -qE "$pattern" || continue
    # never touch a live gate's own example run: if the parent is a running
    # fail/fail-estree it is doing legitimate work right now. Only orphans
    # (reparented to init/systemd) or ones under an agent are candidates.
    ppid=$(awk '{i=0;for(q=1;q<=length($0);q++) if(substr($0,q,1)==")") i=q
                   split(substr($0,i+2),f," "); print f[3]}' "$p/stat" 2>/dev/null)
    pcomm=$(ps -o comm= -p "${ppid:-0}" 2>/dev/null | tr -d ' ')
    # A gate's example is in flight while the GATE runs — the immediate parent
    # is the sh -c / kill-session wrapper, not the gate itself, so matching on
    # the parent's name is not enough: walk up and look for a live gate.
    anc=$ppid; gated=0
    for _ in 1 2 3 4 5 6; do
        [ -z "$anc" ] || [ "$anc" = 1 ] && break
        ac=$(ps -o comm= -p "$anc" 2>/dev/null | tr -d ' ')
        case "$ac" in
            fail|fail-estree|setup_backends.sh) gated=1; break ;;
        esac
        anc=$(awk '{i=0;for(q=1;q<=length($0);q++) if(substr($0,q,1)==")") i=q
                       split(substr($0,i+2),f," "); print f[3]}' "/proc/$anc/stat" 2>/dev/null)
    done
    if [ "$gated" = 1 ]; then kept=$((kept+1)); continue; fi
    etime=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    etime=${etime:-0}
    # Very young: it may be mid-dispatch by a gate that has not forked its
    # wrapper yet. Give it a grace period.
    if [ "$etime" -lt 300 ]; then
        kept=$((kept+1)); continue
    fi
    if [ "$DRY" = 1 ]; then
        echo "  would kill pid=$pid age=${etime}s ppid=$ppid($pcomm) :: $(echo "$cmd" | cut -c1-70)"
        dry_killed=$((dry_killed+1))
        continue
    fi
    # TERM, then KILL: a `while true; do sleep 1; done` writer does not act
    # on TERM while blocked in sleep, so KILL is the reliable finish.
    kill -TERM "$pid" 2>/dev/null
    sleep 0.2
    kill -KILL "$pid" 2>/dev/null
    echo "$(date +%FT%T) reaped orphan corpus example pid=$pid age=${etime}s ppid=$ppid($pcomm) :: $(echo "$cmd" | cut -c1-80)" >&2
    killed=$((killed+1))
done

if [ "$DRY" = 1 ]; then
    echo "reap-orphan-examples: $dry_killed would be killed, $kept left alone (dry run)"
else
    echo "reap-orphan-examples: $killed killed, $kept left alone"
fi
