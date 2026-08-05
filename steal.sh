#!/usr/bin/env bash
# steal.sh — the DESKTOP side of remote work-stealing.
#
# When this machine is IDLE, steal a FRACTION of the server's worker
# slots — the whole tasks (the gate+pi loops) run HERE ("worker, pi and
# all": this machine's own `pi` drives the LLM sessions). Return the
# work when:
#   * this machine's load rises (the desktop user is using it), or
#   * the user cancels (touch ~/.steal-cancel, or SIGINT/SIGTERM), or
#   * the max-lease duration elapses.
#
# The lease has a HEARTBEAT: steal.sh renews it every HEARTBEAT_MIN;
# if the server stops hearing from us (or has spare compute), it reaps
# the lease and restarts the workers locally.
#
# Usage:
#   steal.sh --server <host> [--fraction 0.8] [--allow-estree] \
#            [--load-max 1.5] [--max-min 180]
#
# Requirements on this machine: git, ssh (key to the server), a working
# `pi`, enough RAM/disk for a clone per stolen slot.

set -u
SERVER="" FRACTION=0.8 ALLOW_ESTREE=0 LOAD_MAX=1.5 MAX_MIN=180 HEARTBEAT_MIN=5
while [ $# -gt 0 ]; do
  case "$1" in
    --server) SERVER="$2"; shift 2;;
    --fraction) FRACTION="$2"; shift 2;;
    --allow-estree) ALLOW_ESTREE=1; shift;;
    --load-max) LOAD_MAX="$2"; shift 2;;
    --max-min)  MAX_MIN="$2"; shift 2;;
    --heartbeat-min) HEARTBEAT_MIN="$2"; shift 2;;
    *) echo "unknown: $1"; exit 1;;
  esac
done
[ -n "$SERVER" ] || { echo "need --server <host>"; exit 1; }
awk -v f="$FRACTION" 'BEGIN { exit !(f > 0) }' || { echo "fraction must be > 0"; exit 1; }

CANCEL="$HOME/.steal-cancel"
rm -f "$CANCEL"
trap 'touch "$CANCEL"' INT TERM

command -v pi >/dev/null 2>&1 || { echo "no `pi` on this machine — install/alias pi first"; exit 1; }

load_ok() {
  local l; l=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
  awk -v l="$l" -v m="$LOAD_MAX" 'BEGIN { exit !(l < m) }'
}

echo "[$(date +%FT%T)] steal: checking load (max $LOAD_MAX)..."
load_ok || { echo "desktop busy (load $(awk '{print $1}' /proc/loadavg)) — no steal"; exit 0; }

# ── 1. lease ceil(FRACTION * free) slots ────────────────────────────
ESTREE_FLAG=""; [ "$ALLOW_ESTREE" = 1 ] && ESTREE_FLAG="--allow-estree"
echo "[$(date +%FT%T)] steal: leasing $FRACTION of the free slots..."
LEASED=$(ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --lease-fraction $FRACTION $(hostname) $ESTREE_FLAG" \
          | grep "^leased " | awk '{print $2}')
[ -n "$LEASED" ] || { echo "no free slots on $SERVER"; exit 0; }
echo "[$(date +%FT%T)] steal: leased: $(echo $LEASED | tr '\n' ' ')"

cleanup() {
  for l in $LEASED; do
    ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --release $l" >/dev/null 2>&1 || true
  done
  echo "[$(date +%FT%T)] steal: released all leases"
}
trap cleanup EXIT

# ── 2. fetch the workspace once (the root + the pinned submodule) ───
WORK=$(mktemp -d)
echo "[$(date +%FT%T)] steal: cloning $SERVER..."
git clone -q "ssh://$SERVER/nvme/ai/sh2loop" "$WORK/ws" 2>/dev/null || { echo "clone failed"; exit 1; }
cd "$WORK/ws" || exit 1
git submodule update --init sh2perl >/dev/null 2>&1

# a worker function: the SAME gate+pi loop, run for one leased slot
run_slot() {
  local l="$1"
  git -C sh2perl checkout "backend/$l" 2>/dev/null || git -C sh2perl checkout -b "backend/$l" 2>/dev/null
  git -C sh2perl worktree add "sh2perl/backends/$l" "backend/$l" 2>/dev/null || true
  local fail_count=0
  while true; do
    [ -f "$CANCEL" ] && { echo "[$(date +%FT%T)] steal($l): cancelled"; return; }
    load_ok || { echo "[$(date +%FT%T)] steal($l): desktop load rose — returning"; return; }
    if bash "$WORK/ws/setup_backends.sh" --backend-gate "$l" >> "$WORK/loop-$l.log" 2>&1; then
      fail_count=0
      git -C "$WORK/ws/sh2perl" add -A 2>/dev/null || true
      git -C "$WORK/ws/sh2perl" commit -m "steal($l): gate pass (from $(hostname))" 2>/dev/null || true
      echo "[$(date +%FT%T)] steal($l): gate GREEN"
    else
      fail_count=$((fail_count+1))
      echo "[$(date +%FT%T)] steal($l): gate FAILED ($fail_count/3) — invoking THIS machine's pi"
      bash "$WORK/ws/setup_backends.sh" --pi-fix-backend "$l" 2>> "$WORK/loop-$l.log" || true
      if [ "$fail_count" -ge 3 ]; then
        fail_count=0; sleep 600
      fi
    fi
    sleep 120
  done
}

# ── 3. run the loops + the heartbeat ────────────────────────────────
for l in $LEASED; do
  run_slot "$l" >> "$WORK/steal-$l.out" 2>&1 &
done

# the heartbeat: renew every HEARTBEAT_MIN so the server doesn't reap us
HB_MIN=$((HEARTBEAT_MIN * 60))
STARTED=$(date +%s)
while true; do
  # stop conditions: cancel / load / max-duration
  [ -f "$CANCEL" ] && { echo "[$(date +%FT%T)] steal: cancelled by the user"; break; }
  load_ok || { echo "[$(date +%FT%T)] steal: desktop load rose — returning"; break; }
  [ $(( $(date +%s) - STARTED )) -ge $((MAX_MIN * 60)) ] && { echo "[$(date +%FT%T)] steal: max lease reached"; break; }
  # heartbeat every slot
  for l in $LEASED; do
    ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --heartbeat $l $(hostname)" >/dev/null 2>&1 || true
  done
  sleep "$HB_MIN"
done
# stop the slot loops (the workers return via their own check next iteration)
for l in $LEASED; do touch "$CANCEL"; done

# ── 4. return the work: bundles + release ───────────────────────────
sleep 5  # let the slot loops notice the cancel + commit
cd "$WORK/ws" || exit 1
for l in $LEASED; do
  echo "[$(date +%FT%T)] steal: bundling $l..."
  git -C sh2perl add -A 2>/dev/null || true
  git -C sh2perl commit -m "steal($l): return (from $(hostname))" 2>/dev/null || true
  SUB_BUNDLE="$WORK/sub-$l.bundle"
  git -C sh2perl bundle create "$SUB_BUNDLE" "backend/$l" >/dev/null 2>&1 || true
  scp -q "$SUB_BUNDLE" "$SERVER:/tmp/steal-sub-$l.bundle" 2>/dev/null || true
done
git bundle create "$WORK/root.bundle" master >/dev/null 2>&1 || true
scp -q "$WORK/root.bundle" "$SERVER:/tmp/steal-root.bundle" 2>/dev/null || true
for l in $LEASED; do
  ssh "$SERVER" "bash /nvme/ai/sh2loop/coordinator.sh --apply $l /tmp/steal-sub-$l.bundle /tmp/steal-root.bundle; rm -f /tmp/steal-sub-$l.bundle" >/dev/null 2>&1 || true
done
rm -f "$WORK/root.bundle"
echo "[$(date +%FT%T)] steal: work returned to $SERVER ($(echo $LEASED | tr '\n' ' '))"
rm -rf "$WORK"
