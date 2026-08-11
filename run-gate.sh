#!/usr/bin/env bash
# run-gate.sh — run a frontend gate under the SINGLE-OWNER UID, with
# voluntary locking and a shared report.
#
#   run-gate.sh <frontend> [make-target]   run the gate (or wait+share)
#   run-gate.sh --status                   show running/latest reports
#
# Why: the gate Makefiles write scratch to /tmp/*.mine and rebuild their
# binaries each run. Three DETERMINISTIC races made gates fail "
# transiently" under concurrency (each now eliminated by construction):
#
#  1. CROSS-OWNER /tmp writes — on WSL2 (real kernel, Ubuntu 24.04
#     defaults) fs.protected_regular=2 denies writing another user's
#     files in the sticky /tmp. Fixed: ONE UID owns the gates (root
#     drops to the workspace owner via su; every /tmp artifact is then
#     owned by the same UID).
#  2. BINARY-BUILD race — `make test` -> `make build` -> `rm -f; go
#     build -o` made one gate's rebuild break another gate's exec
#     (ENOENT / ETXTBSY). Fixed in the frontend Makefiles: atomic
#     conditional build (temp + rename; rebuild only when sources
#     changed).
#  3. SHARED-SCRATCH race — fixed-dir .mine files got truncated by
#     concurrent gates. Fixed in the frontend Makefiles: per-gate
#     unique scratch via mktemp -d.
#
# This wrapper adds the process-level guarantees: the voluntary global
# lock (one gate at a time) and the shared report (waiters print the
# fresh report instead of re-running).
#
# NOTE: nested gates inside a gate (cpp-sh-go's C-invariant runs
# `$(MAKE) -C ../c-sh-go test` raw) must NOT go through run-gate — the
# lock is held by the outer gate; a nested run-gate would self-deadlock.
set -euo pipefail

WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$WORKSPACE/gate-reports"
FRONTEND="${1:-}"
TARGET="${2:-test}"

if [ "$FRONTEND" = "--status" ]; then
  if [ -f "$REPORT_DIR/running.txt" ]; then
    echo "gate in progress: $(cat "$REPORT_DIR/running.txt")"
  else
    echo "no gate currently running"
  fi
  echo
  for f in "$REPORT_DIR"/*-latest.txt; do
    [ -f "$f" ] && { echo "=== $(basename "$f") ==="; cat "$f"; echo; }
  done
  exit 0
fi

[ -n "$FRONTEND" ] || { echo "usage: run-gate.sh <frontend> [make-target] | --status" >&2; exit 2; }
FE_DIR="$WORKSPACE/frontends/$FRONTEND"
[ -d "$FE_DIR" ] || { echo "run-gate: no frontend $FRONTEND" >&2; exit 2; }

mkdir -p "$REPORT_DIR"
OWNER="${GATE_OWNER:-$(stat -c %U "$WORKSPACE")}"   # single-owner UID
WHO="$(id -un)@$(hostname)"
WAIT_START=$(date +%s)
TS=$(date +%Y%m%d-%H%M%S)

# ---- acquire the global gate lock (voluntary: every gate runs through
# ---- this script; flock auto-releases on process death)
exec 9>"$REPORT_DIR/.gate.lock"
if ! flock -n 9; then
  if [ -f "$REPORT_DIR/running.txt" ]; then
    echo "[run-gate] gate in progress: $(cat "$REPORT_DIR/running.txt")" >&2
  else
    echo "[run-gate] another gate is running (lock held)" >&2
  fi
  echo "[run-gate] $WHO waiting for the gate to finish…" >&2
  flock 9
  # a report for OUR frontend appeared while we waited → share it
  if [ -f "$REPORT_DIR/$FRONTEND-latest.txt" ] && \
     [ "$(stat -c %Y "$REPORT_DIR/$FRONTEND-latest.txt")" -ge "$WAIT_START" ]; then
    echo "[run-gate] sharing the completed gate report (no re-run):" >&2
    cat "$REPORT_DIR/$FRONTEND-latest.txt"
    exit "$(grep -oP '^exit:\s*\K-?[0-9]+' "$REPORT_DIR/$FRONTEND-latest.txt" | head -1 || echo 0)"
  fi
  # no fresh report for this frontend (a DIFFERENT gate ran while we
  # waited, or the report predates our wait) — fall through and run ours
fi

# ---- clean stale gate scratch. Cross-owner leftovers in /tmp are what
# ---- fs.protected_regular denies; as root this removes every owner's
# ---- files, as a non-root owner it removes its own. Safe only once all
# ---- gates go through run-gate (the lock serializes them).
find /tmp -maxdepth 1 \( -name "*.mine" -o -name "*.out.json" -o -name "*.e.json" \
  -o -name "*.sh.out" -o -name "*.estree.out" \) -delete 2>/dev/null || true

LOG="$REPORT_DIR/$FRONTEND-$TS.log"
echo "frontend=$FRONTEND target=$TARGET user=$WHO started=$TS pid=$$" > "$REPORT_DIR/running.txt"

RUN_START=$(date +%s)
if [ "$(id -u)" = 0 ] && [ "$(id -un)" != "$OWNER" ]; then
  # root → drop to the single-owner UID so /tmp artifacts are owned by
  # the workspace owner (no cross-owner writes, no protected_regular)
  chown -R "$OWNER" "$REPORT_DIR" 2>/dev/null || true
  set +e
  su -s /bin/bash "$OWNER" -c "cd '$FE_DIR' && make '$TARGET'" > "$LOG" 2>&1
  code=$?
  set -e
  chown "$OWNER" "$LOG" 2>/dev/null || true
else
  set +e
  ( cd "$FE_DIR" && make "$TARGET" ) > "$LOG" 2>&1
  code=$?
  set -e
fi
DUR=$(( $(date +%s) - RUN_START ))

# ---- the shared report
SUMMARY=$(grep -E "match,|refused loudly|C-invariant|Error [0-9]" "$LOG" | tail -6 | tr '\n' '; ' || true)
{
  echo "frontend: $FRONTEND"
  echo "target:   $TARGET"
  echo "user:     $WHO"
  echo "started:  $TS"
  echo "duration: ${DUR}s"
  echo "exit:     $code"
  echo "log:      $LOG"
  [ -n "$SUMMARY" ] && echo "summary:  $SUMMARY"
} > "$REPORT_DIR/$FRONTEND-latest.txt"
rm -f "$REPORT_DIR/running.txt"
flock -u 9 2>/dev/null || true

echo "[run-gate] $FRONTEND gate $([ "$code" -eq 0 ] && echo PASS || echo FAIL) (${DUR}s) — report: $REPORT_DIR/$FRONTEND-latest.txt"
exit "$code"
