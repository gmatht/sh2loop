#!/usr/bin/env python3
"""fbview.py — a live X11 window for the simple-framebuffer MIMEcroft port.

WHAT
    The bash-O4 simple-fb port (MIMEcroft_fb.sh on the fb0-raster branch)
    renders 320x240 BGRX pixels in bash and writes them with `xxd -r -p`
    to $RFB_PATH (default $FB0_DEV, else /dev/fb0). Nothing displays that
    file and nothing feeds the game's $MIMECROFT_KEYS queue. This viewer
    closes both gaps with NO game-logic changes:

    - display: reads the raw file and PutImages it into an X11 window at
      ~30Hz (nearest-neighbour x2 => 640x480 via PIL resize), plus on
      Expose / MapNotify.
    - keyboard: every KeyPress in the window is translated to the game's
      own key vocabulary (w/a/s/d/q/e/r/f, digits, h/l/i/k for the
      arrows, " " for SPACE, blank line for ENTER/Return, "." for
      Escape) and APPENDED to the queue file the game's key_next()
      consumes head-first. The game picks it up on a later frame; an
      external writer appending mid-run is the documented interactive
      path.

USAGE
    fbview.py [--fb PATH] [--keys PATH] [--scale N]

    --fb    raw BGRX file to watch (default $FB0_DEV, else /dev/fb0)
    --keys  key queue to append to (default $MIMECROFT_KEYS, else
            /tmp/mimecroft-keys)
    --scale integer window scale (default 2 => 640x480)

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
    try:
        with open(fb_path, "rb") as f:
            data = f.read(FRAME)
    except OSError as e:
        print(f"fbview: cannot read {fb_path}: {e}", file=sys.stderr)
        return None
    if len(data) < FRAME:
        return None
    return data


def main(argv):
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

    def present():
        data = read_frame(fb_path)
        if data is None:
            return
        img = Image.frombytes("RGB", (W, H), data, "raw", "BGRX", 0, 1)
        if scale != 1:
            img = img.resize((ww, wh), Image.NEAREST)
        win.put_pil_image(gc, 0, 0, img)
        disp.flush()

    mapped = False
    last_mtime = -1.0
    frames = 0
    try:
        last_mtime = os.stat(fb_path).st_mtime
    except OSError:
        pass
    while True:
        try:
            mt = os.stat(fb_path).st_mtime
        except OSError:
            mt = last_mtime
        if mapped and mt != last_mtime:
            present()
            last_mtime = mt
            frames += 1
        while disp.pending_events():
            ev = disp.next_event()
            if ev.type == X.Expose:
                present()
            elif ev.type == X.MapNotify:
                mapped = True
                present()
                try:
                    last_mtime = os.stat(fb_path).st_mtime
                except OSError:
                    pass
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
        time.sleep(0.033)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
