#!/usr/bin/env bash
# start-worker.sh — launch ONE fleet worker under harness/supervise.sh,
# detached in its own session.
#
# WHY THIS EXISTS. The systemd user units (systemd/sh2*.service) are the
# documented launch path, but a fresh WSL boot has NO user systemd bus:
# `systemctl --user` returns "Failed to connect to bus: No medium found", so
# install_units.sh bails and every worker would be down until a human notices.
# This is the fallback path install_units.sh:95 documents.
#
# TWO NON-OBVIOUS REQUIREMENTS, both learned the hard way:
#
#   1. ABSOLUTE PATHS. systemd gave each unit a `WorkingDirectory=__ROOT__`;
#      supervise.sh does NOT chdir, so a bare `run_core_worker.sh` resolves to
#      nothing and the worker crash-loops rc=127 "command not found" while the
#      supervisor dutifully restarts it forever. Every command here is absolute.
#
#   2. setsid. A worker launched with plain `nohup ... &` stays in the CALLING
#      shell's session; the tool-call teardown kills the whole session silently
#      (no TERM in the log — it just vanishes). Its own session id is the test.
#
# Usage: harness/start-worker.sh <core|triage|c|perl|go|estree|rust|fish|zsh>
set -euo pipefail

ROOT=/mnt/wsl/projects/sh2loop
ENVF="$ROOT/systemd/sh2fleet.env"

name="${1:?usage: start-worker.sh <core|triage|c|perl|go|estree|...>}"

case "$name" in
  core)   LOG="$ROOT/loop-core-worker.log";   PID="$ROOT/loop-core-worker.pid"
          : > "$ROOT/loop-core-worker.log.claimed" 2>/dev/null || true
          CMD=(/mnt/wsl/projects/sh2loop/run_core_worker.sh) ;;
  triage) LOG="$ROOT/loop-triage-worker.log";  PID="$ROOT/loop-triage-worker.pid"
          CMD=(/mnt/wsl/projects/sh2loop/run_triage_worker.sh) ;;
  estree) LOG="$ROOT/loop-estree.log";         PID="$ROOT/loop-estree-worker.pid"
          CMD=(/usr/bin/perl /mnt/wsl/projects/sh2loop/main_loop_estree.pl) ;;
  c|perl|go|rust|fish|zsh)
          LOG="$ROOT/loop-backend-$name.log";  PID="$ROOT/loop-backend-$name.pid"
          CMD=(/mnt/wsl/projects/sh2loop/setup_backends.sh --run-backend-worker "$name") ;;
  *) echo "start-worker.sh: unknown worker '$name'" >&2; exit 2 ;;
esac

# Already up? The pidfile is the supervisor's own pid (supervise.sh writes it).
if [ -f "$PID" ]; then
  old=$(cat "$PID" 2>/dev/null || true)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    echo "$name: already running (supervisor pid $old)"
    exit 0
  fi
  echo "$name: stale pidfile ($old) — starting fresh"
fi

# The model rotation is keyed on WORKER_ROTATE_WORKER, set per-unit by systemd
# (`Environment=WORKER_ROTATE_WORKER=estree` etc.). The units are gone, so set
# it here to the same values — otherwise the loop calls `pir` directly, which
# ignores a stdin prompt and has no quota fallback (MODEL_ROTATION.md).
case "$name" in
  estree)          ROTATE=estree ;;
  rust|c|fish|zsh) ROTATE="$name" ;;
  *)               ROTATE="" ;;
esac

setsid bash -c '
  cd '"$ROOT"'
  set -a; . '"$ENVF"'; set +a
  '"${ROTATE:+export WORKER_ROTATE_WORKER=$ROTATE;}"'
  exec '"$ROOT"'/harness/supervise.sh \
    --name '"$name"' \
    --log '"$LOG"' \
    --pidfile '"$PID"' \
    -- '"$(printf '%q ' "${CMD[@]}")"'
' </dev/null >> "$LOG" 2>&1 &

sleep 3
pid=$(cat "$PID" 2>/dev/null || true)
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  sid=$(ps -o sid= -p "$pid" | tr -d ' ')
  echo "$name: supervisor pid=$pid sid=$sid — log: $LOG"
else
  echo "$name: FAILED to start (no live pidfile)" >&2
  tail -5 "$LOG" >&2
  exit 1
fi
