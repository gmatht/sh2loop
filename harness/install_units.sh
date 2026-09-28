#!/usr/bin/env bash
# install_units.sh — install the sh2loop worker units as USER systemd units.
#
# WHY USER units: the fleet runs as an unprivileged user in a container-ish
# box with no system-level systemd session, and `systemctl --user` is running.
# The checked-in units previously described User=ai and /nvme/ai/sh2loop —
# neither exists here — so they were inactive everywhere while the real workers
# ran from hand-typed zellij panes with no restart safety net.
#
# Each unit runs its worker under harness/supervise.sh, which restarts on an
# unbounded loop, so a worker never needs a human to bring it back.
#
# Usage:
#   install_units.sh [--user]           # install + enable + start (default)
#   install_units.sh --user --no-start  # install + enable only
#   install_units.sh --user --status     # show what is installed/running
#   install_units.sh --user --stop       # stop + disable the units
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNITDIR="$ROOT/systemd"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# The per-worker units live in systemd/; the two top-level files are kept at
# the repo root for continuity with the original layout.
UNITS=(
  "$UNITDIR/sh2core.service"
  "$UNITDIR/sh2estree.service"
  # sh2perlloop.service is NOT here: it was removed 2026-09-29 with
  # main_loop_rust.pl. Listing it would re-deploy a unit whose ExecStart
  # points at a deleted script — and systemd respawns it, so the loop
  # would come back on the next install.
  "$UNITDIR/sh2backend-c.service"
  "$UNITDIR/sh2backend-perl.service"
  "$UNITDIR/sh2backend-rust.service"
  "$ROOT/sh2loop.target"
  "$UNITDIR/sh2estree.service"
)

# The fleet aggregator is a .target, not a .service: a target carries no
# ExecStart, and a *.service without one is refused by systemd.
TARGETS=(sh2loop.target)

action=install
while [ $# -gt 0 ]; do
  case "$1" in
    --user) shift;;
    --no-start) action=install-nostart; shift;;
    --status)  action=status; shift;;
    --stop)    action=stop; shift;;
    *) echo "install_units.sh: unknown option $1" >&2; exit 2;;
  esac
done

if ! command -v systemctl >/dev/null; then
  echo "install_units.sh: systemctl not found — cannot install units" >&2; exit 1
fi
if ! systemctl --user is-system-running >/dev/null 2>&1; then
  echo "install_units.sh: no user systemd session (systemctl --user not running)." >&2
  echo "  Fall back to: harness/supervise.sh --name X --log F -- <command>" >&2
  exit 1
fi

case "$action" in
status)
  echo "== installed units ($DEST) =="
  ls -1 "$DEST"/sh2*.service 2>/dev/null || echo "  (none installed)"
  echo
  echo "== runtime state =="
  for u in sh2core sh2estree sh2backend-c sh2backend-perl sh2backend-rust sh2loop.target; do
    printf '  %-20s %s\n' "$u" "$(systemctl --user is-active "$u.service" 2>/dev/null)"
  done
  exit 0
  ;;
stop)
  for u in "${TARGETS[@]}" sh2core sh2estree sh2backend-c sh2backend-perl sh2backend-rust; do
    systemctl --user stop "$u.service" 2>/dev/null || true
    systemctl --user disable "$u.service" 2>/dev/null || true
  done
  echo "stopped + disabled."
  exit 0
  ;;
esac

mkdir -p "$DEST"
echo "== validating units =="
bad=0
for u in "${UNITS[@]}"; do
  [ -f "$u" ] || { echo "  MISSING $u"; bad=1; continue; }
  if systemd-analyze verify "$u" >/dev/null 2>&1; then
    echo "  ok   $(basename "$u")"
  else
    echo "  WARN $(basename "$u") (verify reported issues)"
    systemd-analyze verify "$u" 2>&1 | head -3
  fi
done

echo "== installing to $DEST =="
for u in "${UNITS[@]}"; do
  [ -f "$u" ] || continue
  base=$(basename "$u")
  # sh2estree.service exists in two places; the systemd/ one is canonical.
  if [ -f "$UNITDIR/$base" ] && [ "$u" = "$ROOT/$base" ]; then
    cp "$UNITDIR/$base" "$DEST/$base"
  else
    cp "$u" "$DEST/$base"
  fi
  echo "  installed $base"
done
systemctl --user daemon-reload

echo "== enabling =="
for u in "${UNITS[@]}"; do
  [ -f "$u" ] || continue
  systemctl --user enable "$(basename "$u")" >/dev/null 2>&1 || true
done

if [ "$action" = "install-nostart" ]; then
  echo "installed + enabled (not started)."
  exit $bad
fi

echo "== starting =="
for u in "${UNITS[@]}"; do
  [ -f "$u" ] || continue
  systemctl --user start "$(basename "$u")" 2>&1 | head -2
done
sleep 2
echo
echo "== state =="
for u in sh2core sh2estree sh2backend-c sh2backend-perl sh2backend-rust sh2loop.target; do
  printf '  %-20s %s\n' "$u" "$(systemctl --user is-active "$u.service" 2>/dev/null)"
done
