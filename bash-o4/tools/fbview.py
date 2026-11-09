#!/usr/bin/env python3
"""fbview.py — a live X11 window for the simple-framebuffer MIMEcroft port.

WHAT
    The bash-O4 simple-fb port (MIMEcroft_fb.sh on the fb0-raster branch)
    renders 320x240 BGRX pixels in bash and writes them with `xxd -r -p`
    to $RFB_PATH (default $FB0_DEV, else /dev/fb0). Nothing displays that
    file and nothing feeds the game's $MIMECROFT_KEYS queue. This viewer
    closes both gaps with NO game-logic changes:

    - display: reads the raw file and PutImages it into an X11 window
      whenever its pixels change (nearest-neighbour x2 => 640x480 via
      PIL resize), plus on Expose / MapNotify.
    - keyboard: every KeyPress in the window is translated to the game's
      own key vocabulary (w/a/s/d/q/e/r/f, digits, h/l/i/k for the
      arrows, " " for SPACE, blank line for ENTER/Return, "." for
      Escape) and APPENDED to the queue file the game's key_next()
      consumes head-first. The game picks it up on a later frame; an
      external writer appending mid-run is the documented interactive
      path.

USAGE
    fbview.py [--fb PATH] [--keys PATH] [--scale N] [--size WxH]

    --fb    raw BGRX file to watch (default $FB0_DEV, else /dev/fb0)
    --keys  key queue to append to (default $MIMECROFT_KEYS, else
            /tmp/mimecroft-keys)
    --scale integer window scale (default 2 => 640x480 at 320x240)
    --size  surface geometry WxH (default $FB0_GEOM, else 320x240) — the
            game's framebuffer is configurable, so the frame size is not
            assumed

QUIT
    Close the window, or press q / Escape in it (both are forwarded to
    the game first, so the game quits too).

NOTES
    - The viewer never writes the framebuffer, only the keys file; the
      game truncates the queue at startup, so a key pressed before the
      game starts is dropped by the game's own startup truncation.
    - Keysym mapping mirrors sh2perl/runtime/fbwin.c x_drain: Latin-1
      keysyms are the character itself (lowercased); Escape => ".",
      Left/Right/Up/Down => h/l/i/k; Return/KP_Enter => blank line.
      Anything else is dropped, like the device does.
"""
import os
import sys
import time

from PIL import Image

from Xlib import X, display

# The surface geometry of the file being watched. NOT fixed: the game
# resolves its framebuffer from $FB0_GEOM / --view / the DISPLAY row (see
# the geometry block in MIMEcroft_fb.sh), so the viewer takes the same
# size — --size WxH, else $FB0_GEOM, else 320x240 — and one frame is
# W*H*4 bytes of BGRX.
W, H = 320, 240
BPP = 4
FRAME = W * H * BPP


def resolve_fb(argv):
    for i, a in enumerate(argv):
        if a == "--fb" and i + 1 < len(argv):
            return argv[i + 1]
    return os.environ.get("FB0_DEV") or "/dev/fb0"


def resolve_keys(argv):
    for i, a in enumerate(argv):
        if a == "--keys" and i + 1 < len(argv):
            return argv[i + 1]
    return os.environ.get("MIMECROFT_KEYS") or "/tmp/mimecroft-keys"


def resolve_scale(argv):
    for i, a in enumerate(argv):
        if a == "--scale" and i + 1 < len(argv):
            try:
                return max(1, int(argv[i + 1]))
            except ValueError:
                return 2
    return 2


def parse_size(s):
    """'WxH' -> (w, h), or None when it is not a usable surface size."""
    try:
        w, h = (int(v) for v in s.lower().split("x"))
    except (ValueError, TypeError, AttributeError):
        return None
    if not (8 <= w <= 4096 and 8 <= h <= 1024):
        return None
    return w, h


def resolve_size(argv):
    """The watched surface: --size WxH > $FB0_GEOM > 320x240.

    $FB0_GEOM is the variable the game itself validates against (it is
    also how `--publish-fb0` sizes the node), so a file written by a game
    started with it is read at that size without repeating it here.
    """
    for i, a in enumerate(argv):
        if a == "--size" and i + 1 < len(argv):
            return parse_size(argv[i + 1])
        if a.startswith("--size="):
            return parse_size(a.split("=", 1)[1])
    env = os.environ.get("FB0_GEOM")
    if env:
        return parse_size(env)
    return (320, 240)


def keysym_to_game(keysym):
    """Translate an X keysym to the game's queue vocabulary (or None)."""
    if keysym == 0xFF1B:  # Escape => the game's quit key
        return "."
    if keysym == 0xFF51:  # Left
        return "h"
    if keysym == 0xFF53:  # Right
        return "l"
    if keysym == 0xFF52:  # Up
        return "i"
    if keysym == 0xFF54:  # Down
        return "k"
    if keysym in (0xFF0D, 0xFF8D):  # Return / KP_Enter => blank line
        return ""
    if 0x20 <= keysym <= 0x7E:
        c = chr(keysym).lower()
        # the vocabulary the game's case arms match: letters and digits
        # pass through (w/a/s/d/q/e/r/f move/shoot/quit, the rest are
        # ignored by the game, same as the device), space stays a space
        # (the game maps " " => space itself).
        if c == " ":
            return " "
        if c.isalnum():
            return c
        if c == ".":
            return "."
        return None
    return None


def read_frame(fb_path):
    """Read one WHOLE frame, or None.

    The game writes a frame as a truncate plus several write(2)s, so a
    read can land mid-burst and return short. That is not "no frame
    yet": retrying for a couple of milliseconds turns a torn read into
    the frame the writer finished, and a still-torn one is simply
    picked up by the next poll.
    """
    for _ in range(4):
        try:
            with open(fb_path, "rb") as f:
                data = f.read(FRAME)
        except OSError as e:
            print(f"fbview: cannot read {fb_path}: {e}", file=sys.stderr)
            return None
        if len(data) == FRAME:
            return data
        time.sleep(0.001)
    return None


def main(argv):
    global W, H, FRAME
    size = resolve_size(argv)
    if size is None:
        print("fbview: --size wants WxH (e.g. 800x600; W<=4096, H<=1024)",
              file=sys.stderr)
        return 2
    W, H = size
    FRAME = W * H * BPP
    fb_path = resolve_fb(argv)
    keys_path = resolve_keys(argv)
    scale = resolve_scale(argv)
    ww, wh = W * scale, H * scale

    if read_frame(fb_path) is None:
        print(f"fbview: {fb_path} has no full {W}x{H}x{BPP} frame yet "
              f"(start the game first)", file=sys.stderr)
        return 1

    disp = display.Display()
    screen = disp.screen()
    root = screen.root

    win = root.create_window(
        50, 50, ww, wh, 0, screen.root_depth,
        X.InputOutput, X.CopyFromParent,
        event_mask=(X.ExposureMask | X.KeyPressMask |
                    X.StructureNotifyMask),
    )
    win.set_wm_name("MIMEcroft (fb0 viewer)")
    win.set_wm_class("mimecroft", "Fbview")
    # ask to be told about a close (like fbwin.c does)
    wm_delete = disp.intern_atom("WM_DELETE_WINDOW")
    wm_protocols = disp.intern_atom("WM_PROTOCOLS")
    win.change_property(wm_protocols, disp.intern_atom("ATOM"), 32,
                        [wm_delete])
    win.map()
    gc = win.create_gc()
    disp.flush()

    print(f"fbview: {W}x{H} BGRX {fb_path} -> window {ww}x{wh} "
          f"(scale {scale}); keys -> {keys_path}", flush=True)
    print("fbview: WASD move, arrows turn, SPACE shoot, q quit",
          flush=True)

    def present_data(data):
        # The frame is already BGRX — what a 24-bit ZPixmap wants — so it
        # rides through as RGBA, whose raw codec and NEAREST resize only
        # copy. Decoding BGRX to RGB and re-encoding to BGRX (what
        # put_pil_image does for an RGB image) swizzles every pixel twice:
        # measured 9.9ms of a 31ms present against 3ms of the 15ms below.
        img = Image.frombytes("RGBA", (W, H), data)
        if scale != 1:
            img = img.resize((ww, wh), Image.NEAREST)
        raw = img.tobytes("raw", "RGBA")
        # One PutImage cannot carry the frame: python-xlib packs request
        # length/data fields with 16-bit ('H') sizes, so each chunk's
        # payload must stay well under 65535 bytes (and X11's request
        # length is 16-bit 4-byte units). Compute rows from the width so
        # large views (e.g. 800x600 = 3200 B/row) don't overflow 'H'.
        stride = ww * 4
        chunk_rows = max(1, 60000 // stride)
        for y in range(0, wh, chunk_rows):
            n = min(chunk_rows, wh - y)
            win.put_image(gc, 0, y, ww, n, X.ZPixmap, 24, 0,
                          raw[y * stride:(y + n) * stride])
        disp.flush()

    def present():
        data = read_frame(fb_path)
        if data is None:
            return
        present_data(data)
        return data

    last_data = None

    frames = 0
    # end-to-end fps: frames this window actually painted, per wall second.
    # The game's own FPS readout counts renders; this counts presents, so it
    # is the number the player sees when the viewer or the file hop is the
    # limiter.
    fps_t0 = time.monotonic()
    while True:
        # ONE RULE: paint whatever differs from what is already on screen.
        # The mtime gate this replaces could record a frame as seen while the
        # read that followed had missed it (a stat landing between the game's
        # truncate and its writes), and the frame was then dropped for good.
        # Comparing the pixels has no such blind spot and costs ~0.1ms of
        # page-cache read per poll. Measured on a loaded box: the painted rate
        # is unchanged (5-7/s) because that is how often the scene itself
        # changes; the window is 3% busy either way.
        data = read_frame(fb_path)
        if data is not None and data != last_data:
            present_data(data)
            last_data = data
            frames += 1
            now = time.monotonic()
            if now - fps_t0 >= 1.0:
                print(f"fbview: {frames} fps", flush=True)
                frames = 0
                fps_t0 = now
        while disp.pending_events():
            ev = disp.next_event()
            if ev.type == X.Expose:
                d = present()
                if d is not None:
                    last_data = d
            elif ev.type == X.MapNotify:
                d = present()
                if d is not None:
                    last_data = d
            elif ev.type == X.ClientMessage:
                if (ev.client_type == wm_protocols
                        and ev.data[0] == wm_delete):
                    print(f"fbview: window closed after {frames} "
                          f"frames", flush=True)
                    return 0
            elif ev.type == X.KeyPress:
                keysym = disp.keycode_to_keysym(ev.detail, 0)
                game_key = keysym_to_game(keysym)
                if game_key is None:
                    continue
                try:
                    with open(keys_path, "a") as f:
                        f.write(game_key + "\n")
                except OSError as e:
                    print(f"fbview: cannot write {keys_path}: {e}",
                          file=sys.stderr)
                    continue
                shown = game_key if game_key else "<enter>"
                print(f"fbview: key [{shown}]", flush=True)
                if game_key in ("q", "."):
                    print("fbview: quit key forwarded; "
                          "closing after the game exits", flush=True)
        # 4 ms, not 16: the game presents in bursts (a frame is a
        # truncate plus a handful of writes), and a 16 ms poll made the
        # mtime gate coalesce neighbouring frames into one present. The
        # poll is a stat(), so the extra wakeups cost microseconds; the
        # present itself (a few ms) is what paces the window.
        time.sleep(0.004)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
