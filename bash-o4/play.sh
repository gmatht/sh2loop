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
# Usage: ./play.sh [--scale N] [--mem MB] [--size WxH] [--native|--no-viewer]
#                  [--build] [--no-build] [-- <game args...>]
#   --native    the game draws straight into its own fbwin X11 window:
#               no temp frame file, no python viewer, no key bridge. The
#               frame leaves the process as one XPutImage instead of
#               going through a file the viewer re-reads every 4 ms.
#   --no-viewer run the normal temp-file path but do NOT start the python
#               viewer (isolates the game's file write from the viewer)
#   --scale N   window scale (default 2 => 640x480 at 320x240); viewer only
#   --mem MB    address-space cap for the game (default 4096; 0 = no cap)
#   --size WxH  framebuffer geometry (default 320x240) — sizes the temp
#               frame file, the viewer and the game ($FB0_GEOM), which is
#               the same geometry the game's DISPLAY ladder/--view resolve
#   --build     force a rebuild of the game binary first
#   --no-build  skip the build even if the binary is stale
#   -- ARGS     extra args forwarded to the game (e.g. -- --demo)

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GAME_SRC="$HERE/MIMEcroft_fb.sh"
GAME_BIN="$HERE/target/mimecroft-fb-play"
DRIVER="$HERE/target/debug/bash-O4"
VIEWER="$HERE/tools/fbview.py"
SCALE=2
BUILD_MODE=auto
GAME_MEM_MIB=4096
GEOM=""
CPU_ONLY=0
NATIVE=0
NO_VIEW=0

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
    --build) BUILD_MODE=force; shift ;;
    --no-build) BUILD_MODE=skip; shift ;;
    --cpu-only) CPU_ONLY=1; shift ;;
    --native) NATIVE=1; shift ;;
    --native=*) NATIVE=1; shift ;;
    --no-viewer) NO_VIEW=1; shift ;;
    --) shift; break ;;
    -h|--help)
      echo "usage: $0 [--scale N] [--mem MB] [--size|--view WxH] [--native|--no-viewer] [--cpu-only] [--build|--no-build] [-- <game args...>]"
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

# python viewer deps (fail fast with a useful message, not a traceback).
# --native and --no-viewer never start the viewer, so they never need PIL
# or python-xlib — and demanding them would be a lie about what runs.
if [ "$NATIVE" -eq 0 ] && [ "$NO_VIEW" -eq 0 ] && ! python3 -c "import Xlib, PIL" 2>/dev/null; then
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
  # The PLAYER's build is one-shot, so it is worth a real compiler: tcc
  # leaves the rasterizer at -O0, where MIMEcroft burns 43 ms of CPU per
  # frame at 320x240; `cc -O1` costs ~16 s once and brings that to 31 ms
  # (~28%, measured interleaved on the same generated C). The DRIVER above
  # still builds with tcc, and the corpus path never sees these variables,
  # so one-shot cells keep paying milliseconds. PLAY_CCFAST=0 (or setting
  # BASH_O4_CC/BASH_O4_CFLAGS yourself) opts out.
  if [ "${PLAY_CCFAST:-1}" = "1" ] && [ "${BASH_O4_CC:-}" = "" ] && command -v cc >/dev/null 2>&1; then
    BASH_O4_CC=cc BASH_O4_CFLAGS="${BASH_O4_CFLAGS:--O1 -fno-strict-aliasing}" \
      "$DRIVER" -o "$GAME_BIN" "$GAME_SRC" || {
      echo "play.sh: game build failed" 1>&2
      exit 1
    }
  else
    "$DRIVER" -o "$GAME_BIN" "$GAME_SRC" || {
      echo "play.sh: game build failed" 1>&2
      exit 1
          }
    fi
fi

# If no game args and no -- was given, run the default single-command GPU
# fps measurement instead of the interactive game. This is the synthetic
# reusable path: one process, many frames, setup amortized, per-phase
# timings on stderr and a mean fps summary on stdout. No PPM on stdout.
if [ "$GAME_SRC" = "" ] || [ ! -f "$GAME_SRC" ]; then
  : # no game source — will fall through to the fps path below
fi
if [ $# -eq 0 ] && [ "$GEOM" = "" ]; then
  echo "play.sh: default GPU fps measurement (synthetic reusable path)" 1>&2
  # 64x64, 20 measured frames, 2 warmup frames discarded from the mean.
  "$DRIVER" --fb-proof=fps:20 2>play_fps_stderr.log
  FP_EXIT=$?
  echo "play.sh: fps summary above; per-phase timings in play_fps_stderr.log" 1>&2
  cat play_fps_stderr.log 1>&2
  rm -f play_fps_stderr.log
  exit $FP_EXIT
fi
if [ ! -x "$GAME_BIN" ]; then
  echo "play.sh: no game binary — run with --build" 1>&2
  exit 1
fi

# The game's blocks mode (now the default draw mode) hands its world to the
# GPU host in libbash_o4.so — the library this script just built next to the
# driver. Point the runtime at it so the window gets the device path; with
# no library or no Vulkan device the game refuses once and draws on the CPU.
#
# PREFER THE OPTIMIZED HOST. The per-frame work on this side is not just
# Vulkan calls: the readback converts the whole surface (mirror + channel
# swap) every frame, and in an unoptimized build that pass alone measured
# 5.7 ms/frame at 720p against 0.5-0.6 ms optimized (same code, `cargo
# build --release --lib`). A release library is therefore preferred when
# one has been built; the debug one still works and is the zero-setup
# default.
SH2_FB_GPU_LIB=""
for _lib in "$HERE/target/release/libbash_o4.so" "$HERE/target/debug/libbash_o4.so"; do
  if [ "${SH2_FB_GPU_LIB:-}" = "" ] && [ -f "$_lib" ]; then SH2_FB_GPU_LIB="$_lib"; fi
done
if [ "${SH2_FB_GPU_LIB:-}" != "" ]; then
  export SH2_FB_GPU_LIB
  # The runtime decides whether to open the device from the environment at
  # init, so the request has to come from here (the transpiled program's
  # `export` assigns its own variable store, not the process environment).
  # --cpu-only or SH2_FB_GPU=0 in the caller's environment still wins.
  if [ "${SH2_FB_GPU:-}" = "" ] && [ "${SH2_FB_CPU_ONLY:-}" = "" ]; then
    SH2_FB_GPU=1
    export SH2_FB_GPU
  fi
fi

# The frame sink. Native mode has NO frame file at all: the surface stays
# in RAM and fbwin blits it. FB0_DEV=/dev/null is the explicit "no device
# node" marker — fb_try_dev opens it, the FBIOGET ioctl fails, and fb_open
# falls back to the RAM surface. It has to be set: leaving FB0_DEV unset
# makes fb_open adopt the REAL /dev/fb0 when the box has one (this one
# does), which would draw to the console and give the window nothing.
# The key file exists in every mode: it is the queue the window's keys are
# routed through, and an empty one costs nothing per frame.
FB=$(mktemp /tmp/mimecroft-play-fb0.XXXXXX.bin)
# A caller that set MIMECROFT_KEYS owns that queue and drives it (the bench
# harness feeds movement through it); otherwise this run mints its own and
# removes it on exit. Either way the game sees one queue file.
KEYS_OWN=0
if [ "${MIMECROFT_KEYS:-}" != "" ]; then
  KEYS=$MIMECROFT_KEYS
else
  KEYS=$(mktemp /tmp/mimecroft-play-keys.XXXXXX)
  KEYS_OWN=1
fi
VIEW_LOG=$(mktemp /tmp/mimecroft-play-view.XXXXXX.log)
[ -s "$VIEW_LOG" ] || :
if [ "$NATIVE" -eq 0 ]; then
  python3 -c "open('$FB','wb').write(bytes($FBW*$FBH*4))"
  GAME_FB="$FB"
else
  GAME_FB=/dev/null
fi

cleanup() {
  echo ""
  echo "play.sh: stopping…"
  [ "${VIEW_PID:-}" != "" ] && kill "$VIEW_PID" 2>/dev/null
  [ "${GAME_PID:-}" != "" ] && kill "$GAME_PID" 2>/dev/null
  wait 2>/dev/null
  # never rm the device marker: /dev/null is not ours to delete
  if [ "$NATIVE" -eq 0 ]; then rm -f "$FB"; fi
  if [ "$KEYS_OWN" -eq 1 ]; then rm -f "$KEYS"; fi
  rm -f "$VIEW_LOG"
  echo "play.sh: done."
}
trap cleanup INT TERM EXIT

if [ "$NATIVE" -eq 0 ] && [ "$NO_VIEW" -eq 0 ]; then
  echo "play.sh: viewer log: $VIEW_LOG"
  # THE VIEWER CANNOT SHOW A BLOCKS-MODE FRAME, and it is not the viewer's
  # fault. Sampled once a second through a live 1280x720 --demo run:
  #   frame file: size=0 for the WHOLE run (md5 of a 0-byte file, 0
  #               nonzero bytes) — not one pixel ever reached $FB;
  #   viewer window (X GetImage, 1920x1440): ONE distinct colour — 2
  #               distinct byte values, 1 distinct sampled pixel;
  #   viewer log: a single "fbview: 1 fps" line and no repaint after it.
  # WHY, in this configuration: fb_try_dev (fbdev.c:909) opens FB0_DEV and
  # needs FBIOGET_FSCREENINFO to succeed; a regular file answers ENOTTY,
  # so fb_open (fbdev.c:951) takes the RAM-only branch and S_fb_map stays
  # NULL. put_px (fbdev.c:1057) writes S_px and that mmap and nothing
  # else — fbdev.c contains no write() to the fd, only the close() in
  # fb_open's error path. The one writer of $FB was rb_present's
  # row-string path, which belongs to MIMECROFT_DRAW=pixels and is not
  # reached in blocks mode. So say this instead of leaving a blank window
  # unexplained; --native is the display that works.
  if [ "${MIMECROFT_DRAW:-blocks}" != "pixels" ]; then
    echo "play.sh: note: blocks mode never writes the frame file, so this viewer" 1>&2
    echo "play.sh:       window stays blank — use --native to play in a real window." 1>&2
  fi
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
    exec env FB0_DEV="$GAME_FB" MIMECROFT_NATIVE="$NATIVE" MIMECROFT_KEYS="$KEYS" FB0_GEOM="$GEOM" MIMECROFT_EXAMPLES="$HERE/examples" "$GAME_BIN" "$@"
  ) &
else
  FB0_DEV="$GAME_FB" MIMECROFT_NATIVE="$NATIVE" MIMECROFT_KEYS="$KEYS" FB0_GEOM="$GEOM" MIMECROFT_EXAMPLES="$HERE/examples" "$GAME_BIN" "$@" &
fi
GAME_PID=$!

# Native mode: the window belongs to the GAME (title "MIMEcroft (fb0)"), and
# it exists only once setup_webgl has run — a few seconds in. Wait for it and
# raise it, or the first keypress goes nowhere. The pattern is not the
# viewer's: xdotool --name is a regex, so "MIMEcroft .fb0" is the version
# that cannot silently depend on the parentheses round-tripping.
if [ "$NATIVE" -eq 1 ] && command -v xdotool >/dev/null 2>&1; then
  i=0
  while [ "$i" -lt 200 ]; do
    WIN_ID=$(xdotool search --name "MIMEcroft .fb0" 2>/dev/null | head -n 1)
    if [ "${WIN_ID:-}" != "" ]; then
      xdotool windowactivate "$WIN_ID" 2>/dev/null || true
      break
    fi
    if ! kill -0 "$GAME_PID" 2>/dev/null; then break; fi
    sleep 0.1
    i=$((i + 1))
  done
  if [ "${WIN_ID:-}" = "" ]; then
    echo "play.sh: no native window appeared (is DISPLAY reachable?)" 1>&2
  else
    echo "play.sh: native window $WIN_ID focused — type in the game window."
  fi
fi

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
