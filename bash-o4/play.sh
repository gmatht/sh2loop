#!/bin/sh
# play.sh — launch MIMEcroft_fb.sh interactively in a window.
#
# Builds the game (if needed), opens the fbview window, and runs the
# game against it: frames go through a temp BGRX file, keypresses in
# the window flow back through the key queue. Ctrl-C (or q / Escape in
# the window) stops both.
#
# Usage: ./play.sh [--scale N] [--build] [--no-build] [-- <game args...>]
#   --scale N   window scale (default 2 => 640x480)
#   --build     force a rebuild of the game binary first
#   --no-build  skip the build even if the binary is stale
#   -- ARGS     extra args forwarded to the game (e.g. -- --demo)

set -u

HERE=$(dirname "$0")
GAME_SRC="$HERE/MIMEcroft_fb.sh"
GAME_BIN="$HERE/target/mimecroft-fb-play"
VIEWER="$HERE/tools/fbview.py"
SCALE=2
BUILD_MODE=auto

while [ $# -gt 0 ]; do
  case $1 in
    --scale) SCALE=$2; shift 2 ;;
    --scale=*) SCALE=${1#--scale=}; shift ;;
    --build) BUILD_MODE=force; shift ;;
    --no-build) BUILD_MODE=skip; shift ;;
    --) shift; break ;;
    -h|--help)
      echo "usage: $0 [--scale N] [--build|--no-build] [-- <game args...>]"
      exit 0 ;;
    *) break ;;
  esac
done

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

# build the game binary unless skipped (auto = rebuild when the source
# is newer than the binary, so the window always runs this tree)
if [ "$BUILD_MODE" = "force" ] || { [ "$BUILD_MODE" = "auto" ] && [ ! -x "$GAME_BIN" -o "$GAME_SRC" -nt "$GAME_BIN" ]; }; then
  echo "play.sh: building the game…"
  (cd "$HERE" && cargo build --offline --bin bash-O4) || {
    echo "play.sh: driver build failed" 1>&2
    exit 1
  }
  "$HERE/target/debug/bash-O4" -o "$GAME_BIN" "$GAME_SRC" || {
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
FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" "$GAME_BIN" "$@" &
GAME_PID=$!

# stay until the game exits (quit from the window/terminal); the viewer
# follows via the trap. Forward nothing — Ctrl-C hits the trap too.
wait "$GAME_PID"
GAME_RC=$?
echo "play.sh: game exited ($GAME_RC)."
trap - INT TERM EXIT
cleanup
