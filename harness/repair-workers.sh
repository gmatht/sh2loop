#!/usr/bin/env bash
# harness/repair-workers.sh — restart fleet supervisors that died.
#
# WHY THIS EXISTS (2026-10-10). The six fleet supervisors are being SIGKILLed
# every ~30-60 min by an unidentified external killer: no OOM (all oom_kill
# counters zero, systemd-oomd inactive), no disk/pids pressure, no supervise
# exit line (SIGKILL leaves none — an exited supervisor always logs), stale
# locks + pidfiles left behind. Ruled out, with evidence: the orphan reaper
# (narrow example-path patterns + live-gate ancestry check), kill-session.sh
# (session-scoped, skips self), cgroup.kill (no users in fleet code), my own
# tool-call teardown (separate sessions — the long-lived perl supervisor is
# the control group), the zellij watcher (dead since 09-23). A second operator
# IS present on the box (their /tmp/estree-watch.sh), but no kill mechanism
# was found on their side either.
#
# Until the killer is found, bound every outage to the cron interval instead
# of the hours a dead worker costs today. This does NOT diagnose: it restarts.
# Deaths are logged with timestamps (worker + last-seen pid) so the kill
# pattern stays measurable — see /tmp/estree-watch.log for the estree-only
# 5s-resolution table that timed the 12:38 kill to a 5s window.
#
# SAFETY (no duplicates, ever):
#   - start-worker.sh refuses when the pidfile names a live supervisor, and
#     supervise.sh's lockdir refuses a second supervisor per name.
#   - If the supervisor is dead but the WORKER BODY somehow still runs
#     (orphan), this script does NOT start a second copy — it logs ORPHAN and
#     leaves it for a human. Two loops on one worktree fight over builds/git.
#
# Usage: repair-workers.sh [--install-cron]
# Cron:  */5 * * * * /mnt/wsl/projects/sh2loop/harness/repair-workers.sh >>/mnt/wsl/projects/sh2loop/loop-repair.log 2>&1
set -u

ROOT=/mnt/wsl/projects/sh2loop
LOG="$ROOT/loop-repair.log"
# EXPERIMENT 2026-10-10 (CONCLUDED — hypothesis eliminated): estree ran
# aliased via /tmp/sv-estree.sh (no 'supervise' substring) 13:48-13:51 and
# died on the same ~3 min cadence with identical silence, so the killer does
# NOT match on the supervisor name. Symlink removed, estree back in the list.
WORKERS="core triage c perl go estree"

if [ "${1:-}" = "--install-cron" ]; then
  line="*/5 * * * * $ROOT/harness/repair-workers.sh >>$LOG 2>&1"
  cur="$(crontab -l 2>/dev/null || true)"
  new="$(printf '%s\n' "$cur" | command grep -v 'repair-workers.sh' | command grep -v '^$' || true)"
  printf '%s\n%s\n' "$new" "$line" | command grep -v '^$' | crontab -
  echo "installed crontab entry:"
  crontab -l | command grep 'repair-workers.sh'
  exit 0
fi

note() { printf '[%s] repair: %s\n' "$(date +%FT%T)" "$*" >> "$LOG" 2>&1 || true; }

# worker_body_pids <pattern> — pids whose cmdline contains the pattern,
# excluding self, supervisors, and in-flight launchers.
worker_body_pids() {
  local pat="$1" p pid cmd out=""
  for p in /proc/[0-9]*; do
    pid=${p#/proc/}
    [ "$pid" = "$$" ] && continue
    [ -r "$p/cmdline" ] || continue
    # A pid can vanish between the readability guard and the read (this box
    # churns pids constantly). Use cat (not a shell redirect) so a vanishing
    # pid fails silently inside cat instead of the shell reporting the
    # failed redirect itself.
    cmd=$(cat "$p/cmdline" 2>/dev/null | tr '\0' ' ' 2>/dev/null)
    [ -n "$cmd" ] || continue
    case "$cmd" in *"$pat"*) ;; *) continue ;; esac
    case "$cmd" in *supervise.sh*|*start-worker.sh*) continue ;; esac
    out="$out $pid"
  done
  echo "$out"
}

pidfile_for() {
  case "$1" in
    core)   echo "$ROOT/loop-core-worker.pid" ;;
    triage) echo "$ROOT/loop-triage-worker.pid" ;;
    estree) echo "$ROOT/loop-estree-worker.pid" ;;
    *)      echo "$ROOT/loop-backend-$1.pid" ;;
  esac
}

body_pattern_for() {
  case "$1" in
    core)   echo "run_core_worker.sh" ;;
    triage) echo "run_triage_worker.sh" ;;
    estree) echo "main_loop_estree.pl" ;;
    *)      echo "--run-backend-worker $1" ;;
  esac
}

for w in $WORKERS; do
  pf=$(pidfile_for "$w")
  old=$(cat "$pf" 2>/dev/null || true)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    continue  # supervisor alive — nothing to do, stay quiet
  fi
  orphans=$(worker_body_pids "$(body_pattern_for "$w")")
  if [ -n "$orphans" ]; then
    note "$w supervisor dead (pidfile said ${old:-none}) but worker body still alive on pid(s):$orphans — ORPHAN, not starting a duplicate"
    continue
  fi
  if out=$("$ROOT/harness/start-worker.sh" "$w" 2>&1); then
    note "$w was DOWN (pidfile said ${old:-none}) — restarted: $(echo "$out" | tail -1)"
  else
    note "$w was DOWN (pidfile said ${old:-none}) — RESTART FAILED: $(echo "$out" | tail -3 | tr '\n' '|')"
  fi
done
