#!/bin/sh
# play.sh — launch MIMEcroft_fb.sh interactively in a window.
#
# Builds the game (if needed), opens the fbview window, and runs the
# game against it: frames go through a temp BGRX file, keypresses in
# the window flow back through the key queue. Ctrl-C (or q / Escape in
# the window) stops both.
#
# The game runs under a 4 GiB address-space cap (GAME_MEM_MIB) as
# defense-in-depth: an allocation past the cap fails and the game exits,
# instead of climbing until the OOM killer takes the machine down. The
# per-export heap leak that used to trip this cap is fixed (sh2perl
# d6ea96f31 — the export table; verified flat below), so a 127 today
# means something new, not the old growth. Override with --mem MB, or
# --mem 0 to disable the cap.
#
# Usage: ./play.sh [--scale N] [--mem MB] [--build] [--no-build] [-- <game args...>]
#   --scale N   window scale (default 2 => 640x480)
#   --mem MB    address-space cap for the game (default 4096; 0 = no cap)
#   --build     force a rebuild of the game binary first
#   --no-build  skip the build even if the binary is stale
#   -- ARGS     extra args forwarded to the game (e.g. -- --demo)

set -u

HERE=$(dirname "$0")
GAME_SRC="$HERE/MIMEcroft_fb.sh"
GAME_BIN="$HERE/target/mimecroft-fb-play"
DRIVER="$HERE/target/debug/bash-O4"
VIEWER="$HERE/tools/fbview.py"
SCALE=2
BUILD_MODE=auto
GAME_MEM_MIB=4096

while [ $# -gt 0 ]; do
  case $1 in
    --scale) SCALE=$2; shift 2 ;;
    --scale=*) SCALE=${1#--scale=}; shift ;;
    --mem) GAME_MEM_MIB=$2; shift 2 ;;
    --mem=*) GAME_MEM_MIB=${1#--mem=}; shift ;;
    --build) BUILD_MODE=force; shift ;;
    --no-build) BUILD_MODE=skip; shift ;;
    --) shift; break ;;
    -h|--help)
      echo "usage: $0 [--scale N] [--mem MB] [--build|--no-build] [-- <game args...>]"
      exit 0 ;;
    *) break ;;
  esac
done
case $GAME_MEM_MIB in
  ''|*[!0-9]*) echo "play.sh: --mem wants a whole number of MiB" 1>&2; exit 2 ;;
esac

# python viewer deps (fail fast with a useful message, not a traceback)
if ! python3 -c "import Xlib, PIL" 2>/dev/null; then
  echo "play.sh: need python3 with python3-xlib + pillow:" 1>&2
  echo "  apt install python3-xlib python3-pil   (or pip install pillow python-xlib)" 1>&2
  exit 2
fi
if [ "${DISPLAY:-}" = "" ]; then
  echo "play.sh: no X display (\$DISPLAY is empty) — the window needs one" 1>&2
  exit 2
fi

# build the game binary unless skipped (auto = rebuild when the game
# source OR the driver is newer than the binary, so the window always
# runs this tree — a renderer fix with an untouched game source must
# not keep shipping the old binary, which is how the pre-fix binary
# survived the export-table fix). The driver itself is always
# refreshed first: it embeds the sh2perl renderer, so a renderer-side
# fix with no driver-source change is still picked up.
if [ "$BUILD_MODE" = "force" ] || { [ "$BUILD_MODE" = "auto" ] && [ ! -x "$GAME_BIN" -o ! -x "$DRIVER" -o "$GAME_SRC" -nt "$GAME_BIN" -o "$DRIVER" -nt "$GAME_BIN" ]; }; then
  echo "play.sh: building the game…"
  (cd "$HERE" && cargo build --offline --bin bash-O4) || {
    echo "play.sh: driver build failed" 1>&2
    exit 1
  }
  "$DRIVER" -o "$GAME_BIN" "$GAME_SRC" || {
    echo "play.sh: game build failed" 1>&2
    exit 1
  }
fi
if [ ! -x "$GAME_BIN" ]; then
  echo "play.sh: no game binary — run with --build" 1>&2
  exit 1
fi

FB=$(mktemp /tmp/mimecroft-play-fb0.XXXXXX.bin)
KEYS=$(mktemp /tmp/mimecroft-play-keys.XXXXXX)
VIEW_LOG=$(mktemp /tmp/mimecroft-play-view.XXXXXX.log)
python3 -c "open('$FB','wb').write(bytes(320*240*4))"

cleanup() {
  echo ""
  echo "play.sh: stopping…"
  [ "${VIEW_PID:-}" != "" ] && kill "$VIEW_PID" 2>/dev/null
  [ "${GAME_PID:-}" != "" ] && kill "$GAME_PID" 2>/dev/null
  wait 2>/dev/null
  rm -f "$FB" "$KEYS" "$VIEW_LOG"
  echo "play.sh: done."
}
trap cleanup INT TERM EXIT

echo "play.sh: viewer log: $VIEW_LOG"
FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" \
  python3 -u "$VIEWER" --fb "$FB" --keys "$KEYS" --scale "$SCALE" \
  >"$VIEW_LOG" 2>&1 &
VIEW_PID=$!

# wait for the window to appear (fail fast if the viewer died).
# xdotool is a nicety, not a requirement: without it, wait on the
# viewer's "keys ->" ready line instead.
i=0
while [ "$i" -lt 100 ]; do
  if ! kill -0 "$VIEW_PID" 2>/dev/null; then
    echo "play.sh: viewer died — see $VIEW_LOG:" 1>&2
    tail -n 10 "$VIEW_LOG" 1>&2
    exit 1
  fi
  if command -v xdotool >/dev/null 2>&1; then
    if xdotool search --name "MIMEcroft (fb0 viewer)" >/dev/null 2>&1; then
      break
    fi
  elif command grep -q "keys ->" "$VIEW_LOG" 2>/dev/null; then
    break
  fi
  sleep 0.1
  i=$((i + 1))
done
tail -n 2 "$VIEW_LOG"

# Keys only reach the game when its window has X focus — typing in the
# terminal never forwards (the viewer only sees KeyPress events on its
# own window). Raise + focus the window now so the first keypress lands;
# if focus is lost later, click the window (the viewer logs every key it
# forwards as `fbview: key [x]`, so the log tells focus apart from a
# stuck game).
if command -v xdotool >/dev/null 2>&1; then
  WIN_ID=$(xdotool search --name "MIMEcroft (fb0 viewer)" 2>/dev/null | head -n 1)
  if [ "${WIN_ID:-}" != "" ]; then
    xdotool windowactivate "$WIN_ID" 2>/dev/null || true
  fi
fi

echo "play.sh: starting the game — CLICK THE GAME WINDOW first, then keys go to the game."
echo "play.sh: menu keys: arrows/WASD change settings · SPACE (not Enter) starts · q quits."
if [ "$GAME_MEM_MIB" -gt 0 ]; then
  echo "play.sh: game memory capped at ${GAME_MEM_MIB} MiB (--mem 0 disables)."
  # ulimit -v is a per-process address-space cap, applied in a subshell
  # so it cannot affect this script or the viewer. The cap makes any
  # future runaway allocation fail loudly (the game's checked allocation
  # helpers exit) instead of growing until the box wedges.
  (
    ulimit -v $((GAME_MEM_MIB * 1024)) 2>/dev/null || {
      echo "play.sh: warning: ulimit -v unavailable; running uncapped" 1>&2
    }
    exec env FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" "$GAME_BIN" "$@"
  ) &
else
  FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" "$GAME_BIN" "$@" &
fi
GAME_PID=$!

# stay until the game exits (quit from the window/terminal); the viewer
# follows via the trap. Forward nothing — Ctrl-C hits the trap too.
wait "$GAME_PID"
GAME_RC=$?
if [ "$GAME_RC" -eq 127 ] && [ "$GAME_MEM_MIB" -gt 0 ]; then
  echo "play.sh: game exited 127 after hitting its ${GAME_MEM_MIB} MiB cap." 1>&2
  echo "play.sh: the per-export heap leak that used to trip this cap is fixed" 1>&2
  echo "play.sh: (sh2perl d6ea96f31, verified flat) — so this is something new." 1>&2
  echo "play.sh: Re-launch with a larger --mem (or --mem 0 to run uncapped)" 1>&2
  echo "play.sh: to confirm, and file the growth shape." 1>&2
else
  echo "play.sh: game exited ($GAME_RC)."
fi
trap - INT TERM EXIT
cleanup
