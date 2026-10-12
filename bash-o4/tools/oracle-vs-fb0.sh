#!/bin/bash
# oracle-vs-fb0.sh — the Oracle-vs-fb0 demonstration, one command.
#
# Captures frame 1 from BOTH renderers of the same game moment (same
# seed, same maze, same spawn, no input, no menu) and puts them side by
# side:
#   left  = fb0:  this work-copy's bash rasterizer (rb_* -> /dev/fb0)
#   right = JS oracle: jcmd's August capture (WebGL, SwiftShader)
#
# Usage:
#   ./tools/oracle-vs-fb0.sh [--out DIR] [--view]
#     --out DIR  where to write frames + compare (default /tmp/oracle-fb0)
#     --view     also open the side-by-side in ffplay on :0
#
# What "same moment" means: the fb0 build runs its own --first-frame
# flag (dump frame 1 as PPM, quit). The oracle side reuses jcmd's
# archived frame1-A/B PNGs (tmp/shots6) — captured 2026-08-20 by the
# SCREENSHOT_SIMILARITY.md recipe (Playwright + Chromium + SwiftShader,
# SPACE past the menu, `ready.` + 2s, gl.readPixels 800x600). Those two
# agree 99.99%, so either is a valid oracle still.
#
# Caveats (read before quoting a number):
# - The oracle PNGs predate the October reseed/crack/texture work; the
#   level-1 maze is pinned byte-identical, but HUD/labels may drift.
# - The backends-sh-fb0 work-copy carries UNCOMMITTED fixes vs its HEAD
#   (cull sign+divisor, gun/flash rotation sign, texture-plane leading
#   space, label redirect quoting). The demo builds the work-copy, not
#   a clean checkout — that is the point (show the fixed frame).
set -u
OUT=/tmp/oracle-fb0
VIEW=0
for a in "$@"; do
  case $a in
    --out=*) OUT=${a#--out=} ;;
    --view) VIEW=1 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown flag $a" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"
cd "$(dirname "$0")/.."

echo "== 1/4 build driver =="
cargo build --offline 2>&1 | tail -n 2

echo "== 2/4 fb0 frame-1 (work-copy bash rasterizer) =="
./target/debug/bash-O4 --cache-dir "$OUT/cache" -o "$OUT/mimecroft_fb" MIMEcroft_fb.sh 2>&1 | tail -n 2
: > "$OUT/keys"
rm -f "$OUT/fb0-frame1.ppm"
FB_DUMP= MIMECROFT_KEYS="$OUT/keys" \
  timeout -k 5 400 "$OUT/mimecroft_fb" --first-frame "$OUT/fb0-frame1.ppm" \
  < /dev/null > "$OUT/fb0.log" 2>&1
rc=$?
if [ ! -f "$OUT/fb0-frame1.ppm" ]; then echo "FATAL: no fb0 frame (rc=$rc)"; tail -n 10 "$OUT/fb0.log"; exit 1; fi
echo "wrote $OUT/fb0-frame1.ppm ($(wc -c < "$OUT/fb0-frame1.ppm") bytes)"

echo "== 3/4 oracle frame-1 (jcmd August capture) =="
JCMD=${JCMD:-/mnt/wsl/projects/jcmd}
for f in frame1-A.png frame1-B.png; do
  if [ ! -f "$JCMD/tmp/shots6/$f" ]; then echo "FATAL: missing $JCMD/tmp/shots6/$f" >&2; exit 1; fi
done
python3 - "$JCMD" "$OUT" <<'EOF'
import struct, sys, zlib
jcmd, out = sys.argv[1], sys.argv[2]
def read_png(p):
    d = open(p, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n', p
    w, h = struct.unpack('>II', d[16:24])
    assert (d[24], d[25]) == (8, 6), (p, d[24], d[25])
    raw = b''
    pos = 8
    while pos < len(d):
        ln = struct.unpack('>I', d[pos:pos + 4])[0]
        if d[pos + 4:pos + 8] == b'IDAT':
            raw += d[pos + 8:pos + 8 + ln]
        pos += 12 + ln
    px = zlib.decompress(raw)
    stride = w * 4
    out = bytearray()
    prev = bytearray(stride)
    i = 0
    for _ in range(h):
        f = px[i]; i += 1
        line = bytearray(px[i:i + stride]); i += stride
        if f == 1:
            for k in range(4, stride): line[k] = (line[k] + line[k - 4]) & 255
        elif f == 2:
            for k in range(stride): line[k] = (line[k] + prev[k]) & 255
        elif f == 3:
            for k in range(stride):
                a = line[k - 4] if k >= 4 else 0
                line[k] = (line[k] + ((a + prev[k]) >> 1)) & 255
        elif f == 4:
            for k in range(stride):
                a = line[k - 4] if k >= 4 else 0
                b = prev[k]; c = prev[k - 4] if k >= 4 else 0
                p_ = a + b - c
                pa, pb, pc = abs(p_ - a), abs(p_ - b), abs(p_ - c)
                line[k] = (line[k] + (a if (pa <= pb and pa <= pc) else (b if pb <= pc else c))) & 255
        elif f != 0:
            raise Exception(f'{p}: filter {f}')
        out += line
        prev = line
    return w, h, bytes(out)
for n in ('frame1-A', 'frame1-B'):
    w, h, px = read_png(f'{jcmd}/tmp/shots6/{n}.png')
    assert (w, h) == (800, 600), (n, w, h)
    rgb = bytearray()
    for y in range(240):
        sy = y * h // 240
        for x in range(320):
            sx = x * w // 320
            o = (sy * w + sx) * 4
            rgb += bytes((px[o], px[o + 1], px[o + 2]))
    open(f'{out}/oracle-{n}-320.ppm', 'wb').write(b'P6\n320 240\n255\n' + bytes(rgb))
    print(f'wrote {out}/oracle-{n}-320.ppm')
EOF

echo "== 4/4 compare + side-by-side =="
python3 - "$OUT" <<'EOF'
import re
import sys
from collections import Counter
out = sys.argv[1]
def body(p):
    d = open(p, 'rb').read()
    m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', d)
    assert m, p
    return d[m.end():]
fb0 = body(f'{out}/fb0-frame1.ppm')
oa = body(f'{out}/oracle-frame1-A-320.ppm')
ob = body(f'{out}/oracle-frame1-B-320.ppm')
assert len(fb0) == len(oa) == len(ob) == 320 * 240 * 3
PX = 320 * 240
def pct(a, b):
    return 100.0 * sum(1 for p in range(PX) if a[3 * p:3 * p + 3] == b[3 * p:3 * p + 3]) / PX
print(f'oracle-A vs oracle-B pixels: {pct(oa, ob):.2f}% (expect ~99.99)')
print(f'fb0       vs oracle-A pixels: {pct(fb0, oa):.2f}%')
for name, px in (('fb0', fb0), ('oracle-A', oa)):
    cc = Counter(px[o:o + 3] for o in range(0, len(px), 3))
    print(f'{name} colours: {len(cc)} top: {[(t.hex(), round(100 * n / PX, 1)) for t, n in cc.most_common(4)]}')
img = bytearray()
for y in range(240):
    img += fb0[y * 320 * 3:(y + 1) * 320 * 3] + oa[y * 320 * 3:(y + 1) * 320 * 3]
open(f'{out}/side-by-side.ppm', 'wb').write(b'P6\n640 240\n255\n' + bytes(img))
print(f'wrote {out}/side-by-side.ppm (left=fb0, right=oracle)')
EOF

if [ "$VIEW" -eq 1 ]; then
  DISPLAY=:0 nohup ffplay -alwaysontop -window_title "fb0LEFT-oracleRIGHT" \
    -x 1280 -y 480 "$OUT/side-by-side.ppm" > "$OUT/ffplay.log" 2>&1 &
  sleep 4
  DISPLAY=:0 xwininfo -children -root 2>&1 | sed -n '7,10p'
fi
echo "done: $OUT"
