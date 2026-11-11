# Walkthrough — making MIMEcroft_fb.sh playable (2026-10-13)

Verbatim transcript of the real session: built binary shows a live
window and responds to keypresses. Every counted or quoted line below
was re-run before committing (a count taken once from a piped grep is
not evidence).

## 1. The starting point

This worktree (`fb0-raster` branch) carries the simple-framebuffer port
of the game: `MIMEcroft_fb.sh` renders 320x240 BGRX pixels in bash and
writes them with one `xxd -r -p` per present to `$RFB_PATH`, and reads
keys head-first from the `$MIMECROFT_KEYS` queue file. No window, no
live keyboard. The master copy (`/mnt/wsl/projects/sh2loop/bash-o4/`)
drives the native `fbdev.c` device with an X11 window instead — a
different port, not a newer version of this file.

Goal: a live window showing the game's frames, with keypresses reaching
the game — with NO game-logic changes, so the oracle frame-1 gate stays
green.

## 2. Device primitives lower + link + run (probe)

A probe script naming the device primitives lowers to in-process calls
(`--emit-c` shows `fb_open(320, 240)`, `fb_window_key()`,
`fb_input_line(...)`, `fb_present()`, `fb_dump_ppm(...)` — no
`bash -c` sites) and links against the embedded `fbdev.c`/`fbwin.c`:

```
$ ./target/debug/bash-O4 -o /tmp/fbwin-hold /tmp/fbwin-hold.sh
$ FBWIN=1 timeout 12 /tmp/fbwin-hold
WINDOW-YES
FRAME1-DONE
$ xdotool search --name "MIMEcroft"
14680065
```

The window opens live. Key vocabulary probe (keys sent with
`xdotool key --window $WIN <key>`, 0.5s apart):

```
GOT-KEY=[w]
GOT-KEY=[q]
GOT-KEY=[h]        <- Left arrow
GOT-KEY=[l]        <- Right arrow
GOT-KEY=[i]        <- Up arrow
GOT-KEY=[k]        <- Down arrow
GOT-KEY=[.]        <- Escape
```

Full vocabulary verified: letters, arrows (`h/l/i/k`), Escape (`.`).
Two measured caveats: `x_drain` delivers ONE key per call (a burst sent
in the same 50ms window coalesces — human-speed keypresses all arrive),
and `SPACE`/`Return`/digits never arrive through `fb_window_key`
(`x_drain` only forwards `a-z` + `.`).

## 3. The bridge: tools/fbview.py (223 lines)

Rather than re-porting the game to the native device (which would void
the oracle gate this branch exists to hold), the bridge is a viewer:

- display: reads the raw BGRX file and `PutImage`s it into an X11
  window at ~30Hz (PIL `NEAREST` x2 => 640x480), plus on Expose/Map.
- keyboard: every KeyPress is translated to the game's own queue
  vocabulary (`w/a/s/d/q/e/r/f`, digits, `h/l/i/k`, `" "` for SPACE,
  blank line for ENTER, `"."` for Escape) and APPENDED to the queue
  file `key_next()` consumes head-first — the game's documented
  interactive path (`echo w >> "$MIMECROFT_KEYS"`).

```
$ python3 -c "import ast; ast.parse(open('tools/fbview.py').read()); print('fbview syntax ok')"
fbview syntax ok
$ FB0_DEV=/tmp/fbview-test.bin MIMECROFT_KEYS=/tmp/fbview-test-keys python3 -u tools/fbview.py --scale 2
fbview: 320x240 BGRX /tmp/fbview-test.bin -> window 640x480 (scale 2); keys -> /tmp/fbview-test-keys
fbview: WASD move, arrows turn, SPACE shoot, q quit
$ xdotool search --name "MIMEcroft"
14680064
$ xwininfo -id 14680064 | head -n 12
Window id: 0xe00000 "MIMEcroft (fb0 viewer)"
  Width: 640
  Height: 480
  Depth: 24
  Visual Class: TrueColor
```

Key-forwarding check against the synthetic frame (keys sent `--window`,
0.8s apart — the earlier SPACE/arrow failures were a bad `--delay`
syntax and unfocused typing, not the viewer):

```
fbview: key [w]
fbview: key [ ]
fbview: key [<enter>]
fbview: key [h]
fbview: key [.]
```

## 4. Playable run: game + viewer together

```
$ python3 -c "open('/tmp/play-fb0.bin','wb').write(bytes(320*240*4))"
$ FB0_DEV=/tmp/play-fb0.bin MIMECROFT_KEYS=/tmp/play-keys python3 -u tools/fbview.py --scale 2 &
$ FB0_DEV=/tmp/play-fb0.bin MIMECROFT_KEYS=/tmp/play-keys FBWIN=1 /tmp/mimecroft_fb &
  ...texture generation (~2min, one-off per /tmp cache)...
  ready.
```

Frame 0 check (game rendering into the file the viewer mirrors):

```
nonblack pixels: 73602 / 76800
```

Movement + shoot (`w w w`, turn, shoot — 3-4s apart for the ~2.7s
transpiled frame time):

```
fbview: key [w]
fbview: key [w]
fbview: key [w]
fbview: key [h]
fbview: key [w]
fbview: key [ ]
```

The framebuffer hash changed after the moves (`f1b1e9e9...` ->
`8c819fb4...` -> `9c709ddd...`), the queue file was fully consumed
(empty = the game ate every key), and frames
`/tmp/play-frame0/1/2.png` show the view shifting.

Quit:

```
fbview: key [q]
fbview: quit key forwarded; closing after the game exits
== Quit at level 1. Score 0 — 0 artifacts this level. ==
#stats: frames=489 time=75604ms avg=154ms/frame
GAME DONE
```

488-489 frames played, clean quit through the window, `GAME DONE` +
stats. The game is playable: live window, keys move/shoot/quit.

## 5. Gates still green

No game file changed (the 4 dirty files are pre-existing comment-only
edits — verified with `git diff HEAD`, 8 lines in the game file, all
comment prose). The oracle gate runs the work-copy end to end:

```
$ bash tools/oracle-vs-fb0.sh --out=/tmp/oracle-fb0-verify
oracle-A vs oracle-B pixels: 99.99% (expect ~99.99)
fb0       vs oracle-A pixels: 33.17%
done: /tmp/oracle-fb0-verify
$ bash tools/ground-regress.sh
PASS: probe pixel is green (perspective-correct UV)
```

oracle sanity 99.99%, fb0-vs-oracle 33.17% = the branch baseline
(untouched — this change adds only `tools/fbview.py`), perspective
regress green.

## 6. What this is not

- Not a re-port to the native device: the game still renders in bash
  and still reads the queue file. The viewer is the window + keyboard
  the port was missing.
- Not fast: ~154ms/frame average (2.7s first frame, texture generation
  ~2min one-off). Playable means responsive to keys, not 60fps.
- The window keys that never arrive through `fb_window_key`
  (SPACE/ENTER/digits) arrive fine through the queue file — which is
  why the viewer appends to the file instead of calling the device.
