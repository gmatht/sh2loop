#!/bin/bash
# ground-regress.sh — regression test for the fb0 ground (dirt floor) render.
#
# Reproduces the "ground (without grass) doesn't display correctly" failure:
# rb_tri used to interpolate texture UVs LINEARLY in screen space, but the
# oracle device (WebGL — like every GPU) interpolates varyings
# PERSPECTIVE-correct. On the floor planes (20-wide quads at a grazing
# angle) the two mappings pick different texels on most rows: linear crawls
# through ~15 v-texel rows over the whole screen while the correct mapping
# wraps through ~32 like the oracle (measured 108/117 floor rows differ).
#
# The test feeds ONE triangle with a steep depth gradient straight into
# rb_tri (no camera, no maze, no oracle stills needed) and asserts the
# sampled texel at a probe pixel whose answer differs between the mappings:
#   screen-linear U -> texel column 0 -> RED   (253,0,0)
#   perspective U   -> texel column 1 -> GREEN (0,253,0)
# (253, not 255: the fragment scale tops out at vcolor*255/128 = 253.)
# With the bug, the probe pixel is red; fixed, it is green.
#
# Corner setup mirrors what rb_face now stores in RB_PU/PV/PW: uv/w and 1/w
# at RBF_PCK=1000000 fixed point (u=1000 milli at w=100 -> 10000000).
#
# Usage: bash ground-regress.sh; exit 0 = pass, 1 = fail. ~25s under bash.
set -u
cd "$(dirname "$0")"
. ../src/sh/rb-raster.sh

# 2x1 texture: column 0 = pure red, column 1 = pure green.
rb_tex_load 8 "255 0" "0 255" "0 0" 2 2 0
if [ "${RBTEX_SZ[8]}" != "2" ]; then echo "FAIL: texture slot 8 did not load"; exit 1; fi

rb_open /tmp/ground-regress.bin

# One triangle, kept at SSC: P0=(0,0) P1=(200,0) P2=(0,200) px.
# View depths: W0=W1=100 (near), W2=10000 (far) — the steep gradient that
# separates linear from perspective-correct interpolation.
# U: 0 at P0/P2, 1000 (full tile) at P1; V=0 everywhere (single texel row).
# Shade: 1000 at every corner (vcol 127); tint white (rbc_ur/ug/ub=1000).
rbt_x0=0;        rbt_y0=0;        rbt_s0=1000; rbt_u0=0;                 rbt_v0=0; rbt_w0=$((1000000 / 100))
rbt_x1=200000;   rbt_y1=0;        rbt_s1=1000; rbt_u1=$((1000*1000000 / 100)); rbt_v1=0; rbt_w1=$((1000000 / 100))
rbt_x2=0;        rbt_y2=200000;   rbt_s2=1000; rbt_u2=0;                 rbt_v2=0; rbt_w2=$((1000000 / 10000))
rbc_tr=255; rbc_tg=255; rbc_tb=255
rbc_ur=1000; rbc_ug=1000; rbc_ub=1000
rbc_tex=8; rbc_dam=0
RBF_CRT=0; RBF_CORRUPT=0
rb_tri

# probe pixel (80,40): barycentric (395,402,203)/1000.
# linear U = 402 -> fract 402 -> iu = 402*2/1000 = 0 -> RED texel.
# correct U = 503 -> iu = 503*2/1000 = 1 -> GREEN texel.
# (rows hold BGRX hex: green (0,253,0) encodes as 00fd0000.)
probe=${RFB_ROWS[40]:640:8}
rb_mkhex 0 253 0
if [ "$probe" = "$rb_pxhex" ]; then
  echo "PASS: probe pixel is green (perspective-correct UV)"
  exit 0
else
  rb_mkhex 253 0 0
  if [ "$probe" = "$rb_pxhex" ]; then
    echo "FAIL: probe pixel is red (screen-linear UV) — ground texels are wrong"
  else
    echo "FAIL: probe pixel is '$probe' (expected green $rb_pxhex)"
  fi
  exit 1
fi
