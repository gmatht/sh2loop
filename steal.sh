#!/usr/bin/env bash
# steal.sh — the DESKTOP side of remote work-stealing.
#
# When this machine is IDLE, steal a worker slot from the server — the
# whole task (the gate+pi loop) runs HERE ("worker, pi and all": this
# machine's own `pi` binary drives the LLM sessions). Return the work
# (commits + WIP) to the server when:
#   * this machine's load rises (the desktop user is using it), or
#   * the user cancels (touch ~/.steal-cancel, or SIGINT/SIGTERM), or
#   * the max-lease duration elapses.
#
# Usage:
#   steal.sh --server <host> [--lang <lang>] [--load-max 1.5] [--max-min 180]
#   touch ~/.steal-cancel   # cancel from anywhere
#
# Requirements on this machine: git, ssh (key to the server), a working
# `pi` (the same CLI the server's loops use), enough RAM/disk for a clone.

set -u
SERVER="" LANG_PREF="" LOAD_MAX=1.5 MAX_MIN=180
while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER="$2"; shift 2;;
    --lang)   LANG_PREF="$2"; shift 2;;
    --load-max) LOAD_MAX="$2"; shift 2;;
    --max-min)  MAX_MIN="$2"; shift 2;;
    *) echo "unknown: $1"; exit 1;;
  esac
done
[ -n "$SERVER" ] || { echo "need --server <host>"; exit 1; }

CANCEL="$HOME/.steal-cancel"
rm -f "$CANCEL"
trap 'touch "$CANCEL"' INT TERM

# ── the desktop's own pi must exist (worker, pi and all) ─────────────
if ! command -v pi >/dev/null 2>&1; then
  echo "no `pi` on this machine — the stolen worker cannot drive LLM sessions. Install/alias pi first."
  exit 1
fi

load_ok() { # true when the desktop is idle enough to keep the work
  local l; l=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
  awk -v l="$l" -v m="$LOAD_MAX" 'BEGIN { exit !(l < m) }'
}

echo "[$(date +%FT%T)] steal: checking load (max $LOAD_MAX)..."
load_ok || { echo "desktop busy (load $(awk '{print $1}' /proc/loadavg)) — no steal"; exit 0; }

# ── 1. lease a slot ─────────────────────────────────────────────────
if [ -n "$LANG_PREF" ]; then
  LANG="$LANG_PREF"
  echo "stealing slot: $LANG"
  ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --lease $LANG $(hostname)" || { echo "lease failed"; exit 1; }
else
  # ask the server for any free slot
  LANG=$(ssh "$SERVER" "for l in c go python rust zig py-sh-go go-sh posix-sh-go perl-sh-go; do bash /nvme/ai/sh2loop/coordinator.sh --status | grep -q \"\$l.*free\" && { echo \$l; break; }; done")
  [ -n "$LANG" ] || { echo "no free slot on $SERVER"; exit 0; }
  echo "leased free slot: $LANG"
  ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --lease $LANG $(hostname)" || exit 1
fi

cleanup() { # always release the lease on exit
  ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --release $LANG" >/dev/null 2>&1 || true
  echo "[$(date +%FT%T)] steal: released $LANG"
}
trap cleanup EXIT

# ── 2. fetch the workspace (root + the pinned submodule) ────────────
WORK=$(mktemp -d)
echo "[$(date +%FT%T)] steal: cloning $SERVER..."
git clone -q "ssh://$SERVER/nvme/ai/sh2loop" "$WORK/ws" 2>/dev/null \
  || { echo "clone failed"; exit 1; }
cd "$WORK/ws" || exit 1
git submodule update --init sh2perl >/dev/null 2>&1
# the worker's branch + the worktree (the gate expects backends/<lang>)
git -C sh2perl checkout "backend/$LANG" 2>/dev/null || git -C sh2perl checkout -b "backend/$LANG" 2>/dev/null
git -C sh2perl worktree add "sh2perl/backends/$LANG" "backend/$LANG" 2>/dev/null || true

# ── 3. run the worker loop HERE (gate → pi-fix → commit) ────────────
fail_count=0
while true; do
  # return conditions checked every iteration:
  [ -f "$CANCEL" ] && { echo "[$(date +%FT%T)] steal: cancelled by the desktop user"; break; }
  load_ok || { echo "[$(date +%FT%T)] steal: desktop load rose — returning"; break; }
  [ "$(find "$CANCEL" -mmin +$MAX_MIN 2>/dev/null | wc -l)" -ge 0 ] || true
  # max-lease duration (use a marker file with a timestamp instead)
  if [ -f "$WORK/started" ]; then :; else touch "$WORK/started"; fi
  if [ "$(($(date +%s) - $(stat -c %Y "$WORK/started")))" -ge $((MAX_MIN * 60)) ]; then
    echo "[$(date +%FT%T)] steal: max lease ($MAX_MIN min) reached — returning"; break
  fi

  # the same failure-driven loop the server's workers run
  if bash "$WORK/ws/setup_backends.sh" --backend-gate "$LANG" >> "$WORK/loop.log" 2>&1; then
    fail_count=0
    # commit scoped changes (the worktree + harness)
    changes=$(git -C "$WORK/ws" status --porcelain 2>/dev/null \
              | awk '/^.. /{print $2}' \
              | awk -v d="$WORK/ws/sh2perl/backends/$LANG" '$0 ~ "^"d || $0 ~ /^harness\//' || true)
    if [ -n "$changes" ]; then
      git -C "$WORK/ws" add $changes 2>/dev/null || true
      git -C "$WORK/ws" commit -m "steal($LANG): gate pass (from $(hostname))" 2>/dev/null || true
    fi
    # the submodule side (the branch's renderer work)
    cd "$WORK/ws/sh2perl" || exit 1
    git add -A 2>/dev/null || true
    git commit -m "steal($LANG): gate pass (from $(hostname))" 2>/dev/null || true
    echo "[$(date +%FT%T)] steal($LANG): gate GREEN"
  else
    fail_count=$((fail_count+1))
    echo "[$(date +%FT%T)] steal($LANG): gate FAILED ($fail_count/3) — invoking THIS machine's pi"
    bash "$WORK/ws/setup_backends.sh" --pi-fix-backend "$LANG" 2>> "$WORK/loop.log" || true
    if [ "$fail_count" -ge 3 ]; then
      echo "[$(date +%FT%T)] steal($LANG): trapped — backing off"
      fail_count=0
      sleep 600
    fi
  fi
  sleep 120
done

# ── 4. return the work: bundles + release ───────────────────────────
cd "$WORK/ws" || exit 1
echo "[$(date +%FT%T)] steal: bundling the work..."
SUB_BUNDLE="$WORK/sub.bundle"; ROOT_BUNDLE="$WORK/root.bundle"
git -C sh2perl bundle create "$SUB_BUNDLE" "backend/$LANG" >/dev/null 2>&1 || true
git bundle create "$ROOT_BUNDLE" master >/dev/null 2>&1 || true
scp -q "$SUB_BUNDLE" "$SERVER:/tmp/steal-sub-$LANG.bundle" 2>/dev/null || true
scp -q "$ROOT_BUNDLE" "$SERVER:/tmp/steal-root-$LANG.bundle" 2>/dev/null || true
ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --apply $LANG /tmp/steal-sub-$LANG.bundle /tmp/steal-root-$LANG.bundle; rm -f /tmp/steal-sub-$LANG.bundle /tmp/steal-root-$LANG.bundle" >/dev/null 2>&1 || true
echo "[$(date +%FT%T)] steal: work returned to $SERVER (slot $LANG)"
rm -rf "$WORK"
