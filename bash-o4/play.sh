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
# Usage: ./play.sh [--scale N] [--mem MB] [--size WxH] [--build] [--no-build] [-- <game args...>]
#   --scale N   window scale (default 2 => 640x480 at 320x240)
#   --mem MB    address-space cap for the game (default 4096; 0 = no cap)
#   --size WxH  framebuffer geometry (default 320x240) — sizes the temp
#               frame file, the viewer and the game ($FB0_GEOM), which is
#               the same geometry the game's DISPLAY ladder/--view resolve
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
GEOM=""
CPU_ONLY=0
FBWIN_DIRECT=${FBWIN_DIRECT:-0}
BENCH_MODE=0
BENCH_GEOM="${BENCH_GEOM:-160x120}"
BENCH_FRAMES="${BENCH_FRAMES:-300}"

FORWARD_ARGS=""
while [ $# -gt 0 ]; do
  case $1 in
    --scale) SCALE=$2; shift 2 ;;
    --scale=*) SCALE=${1#--scale=}; shift ;;
    --mem) GAME_MEM_MIB=$2; shift 2 ;;
    --mem=*) GAME_MEM_MIB=${1#--mem=}; shift ;;
    --size) GEOM=$2; shift 2 ;;
    --size=*) GEOM=${1#--size=}; shift ;;
    --view)
      # size the viewer/frame file for an exact --view WxH (the game also
      # accepts a ladder width, but only WxH gives an unambiguous size);
      # always forward to the game.
      case ${2:-} in
        *x*) GEOM=$2 ;;
      esac
      FORWARD_ARGS="$FORWARD_ARGS $1 $2"; shift 2 ;;
    --view=*)
      case ${1#--view=} in
        *x*) GEOM=${1#--view=} ;;
      esac
      FORWARD_ARGS="$FORWARD_ARGS $1"; shift ;;
    --fbwin-direct) FBWIN_DIRECT=1; shift ;;
    --bench|--benchmark) BENCH_MODE=1; FBWIN_DIRECT=1; shift ;;
    --build) BUILD_MODE=force; shift ;;
    --no-build) BUILD_MODE=skip; shift ;;
    --cpu-only) CPU_ONLY=1; shift ;;
    --) shift; break ;;
    -h|--help)
      echo "usage: $0 [--bench] [--fbwin-direct] [--scale N] [--mem MB] [--size|--view WxH] [--cpu-only] [--build|--no-build] [-- <game args...>]"
      exit 0 ;;
    *) break ;;
  esac
done
# re-attach forwarded play.sh-parsed args (e.g. --view) ahead of the rest
if [ "$FORWARD_ARGS" != "" ]; then
  # shellcheck disable=SC2086
  set -- $FORWARD_ARGS "$@"
fi
case $GAME_MEM_MIB in
  ''|*[!0-9]*) echo "play.sh: --mem wants a whole number of MiB" 1>&2; exit 2 ;;
esac

# the surface geometry: the same ceiling the game/rasterizer enforce
FBW=320
FBH=240
case $GEOM in
  "") ;;
  *x*) FBW=${GEOM%x*}; FBH=${GEOM#*x}
       case $FBW in ''|*[!0-9]*) echo "play.sh: --size wants WxH (e.g. 800x600)" 1>&2; exit 2 ;; esac
       case $FBH in ''|*[!0-9]*) echo "play.sh: --size wants WxH (e.g. 800x600)" 1>&2; exit 2 ;; esac
       if [ "$FBW" -gt 4096 ] || [ "$FBH" -gt 1024 ]; then
         echo "play.sh: --size W<=4096 and H<=1024 (the rasterizer's row store)" 1>&2; exit 2
       fi ;;
  *) echo "play.sh: --size wants WxH (e.g. 800x600)" 1>&2; exit 2 ;;
esac

if [ "$CPU_ONLY" = "1" ]; then
  export SH2_FB_CPU_ONLY=1
fi

# python viewer deps only for Python-viewer path
if [ "$FBWIN_DIRECT" != "1" ] && [ "$BENCH_MODE" != "1" ]; then
  if ! python3 -c "import Xlib, PIL" 2>/dev/null; then
    echo "play.sh: need python3 with python3-xlib + pillow:" 1>&2
    echo "  apt install python3-xlib python3-pil   (or pip install pillow python-xlib)" 1>&2
    exit 2
  fi
  if [ "${DISPLAY:-}" = "" ]; then
    echo "play.sh: no X display (\$DISPLAY is empty) — the window needs one" 1>&2
    exit 2
  fi
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
  # The PLAYER's build is one-shot, so it is worth a real compiler: tcc
  # leaves the rasterizer at -O0, where MIMEcroft burns 43 ms of CPU per
  # frame at 320x240; `cc -O1` costs ~16 s once and brings that to 31 ms
  # (~28%, measured interleaved on the same generated C). The DRIVER above
  # still builds with tcc, and the corpus path never sees these variables,
  # so one-shot cells keep paying milliseconds. PLAY_CCFAST=0 (or setting
  # BASH_O4_CC/BASH_O4_CFLAGS yourself) opts out.
  if [ "${PLAY_CCFAST:-1}" = "1" ] && [ "${BASH_O4_CC:-}" = "" ] && command -v cc >/dev/null 2>&1; then
    BASH_O4_CC=cc BASH_O4_CFLAGS="${BASH_O4_CFLAGS:--O3 -fno-strict-aliasing}" \
      "$DRIVER" ${PLAY_GPU:+--gpu} -o "$GAME_BIN" "$GAME_SRC" || {
      echo "play.sh: game build failed" 1>&2
      exit 1
    }
  else
    "$DRIVER" ${PLAY_GPU:+--gpu} -o "$GAME_BIN" "$GAME_SRC" || {
      echo "play.sh: game build failed" 1>&2
      exit 1
    }
  fi
fi
if [ ! -x "$GAME_BIN" ]; then
  echo "play.sh: no game binary — run with --build" 1>&2
  exit 1
fi


# --bench: viewerless, direct fb0-emulation-in-transpiled-code path.
# Runs the compiled game demo and prints #stats (fps/frametimes) end-to-end.
if [ "$BENCH_MODE" = "1" ]; then
  GEOM="$BENCH_GEOM"
  FB0_DEV="${FB0_DEV:-/dev/null}"
  echo "play.sh: bench mode (viewerless direct path) geom=$GEOM frames=$BENCH_FRAMES dev=$FB0_DEV"
  trap - INT TERM EXIT
  exec env -i PATH="$PATH" HOME="${HOME:-/root}" TERM="${TERM:-dumb}" \
    FBWIN_DIRECT=1 FBWIN=1 FB0_GEOM="$GEOM" FB0_DEV="$FB0_DEV" \
    MIMECROFT_DEMO=1 MIMECROFT_BENCH=1 MIMECROFT_VSYNC=0 MIMECROFT_BENCH_FRAMES="$BENCH_FRAMES" \
    "$GAME_BIN" --demo "$@"
fi

FB=$(mktemp /tmp/mimecroft-play-fb0.XXXXXX.bin)
KEYS=$(mktemp /tmp/mimecroft-play-keys.XXXXXX)
VIEW_LOG=$(mktemp /tmp/mimecroft-play-view.XXXXXX.log)
python3 -c "open('$FB','wb').write(bytes($FBW*$FBH*4))"

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

if [ "$FBWIN_DIRECT" = "1" ]; then
  echo "play.sh: viewerless direct path (fb0 emulation/presentation in transpiled runtime); bypassing Python viewer"
  FB0_DEV="${FB0_DEV:-/dev/null}"
else
  echo "play.sh: viewer log: $VIEW_LOG"
  FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" \
    python3 -u "$VIEWER" --fb "$FB" --keys "$KEYS" --scale "$SCALE" \
    --size "${FBW}x${FBH}" >"$VIEW_LOG" 2>&1 &
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
fi

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
if [ "$FBWIN_DIRECT" = "1" ]; then
  if [ "$GAME_MEM_MIB" -gt 0 ]; then
    (
      ulimit -v $((GAME_MEM_MIB * 1024)) 2>/dev/null || {
        echo "play.sh: warning: ulimit -v unavailable; running uncapped" 1>&2
      }
      exec env FBWIN_DIRECT=1 FBWIN=1 FB0_GEOM="$GEOM" "$GAME_BIN" "$@"
    ) &
  else
    FBWIN_DIRECT=1 FBWIN=1 FB0_GEOM="$GEOM" "$GAME_BIN" "$@" &
  fi
else
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
      exec env FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" FB0_GEOM="$GEOM" "$GAME_BIN" "$@"
    ) &
  else
    FB0_DEV="$FB" MIMECROFT_KEYS="$KEYS" FB0_GEOM="$GEOM" "$GAME_BIN" "$@" &
  fi
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
