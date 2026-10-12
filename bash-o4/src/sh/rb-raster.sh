#!/usr/bin/env sh2perl
# rb-raster.sh — a software rasterizer for /dev/fb0, in plain bash.
#
# WHAT IT IS
#   The game's draw backend as shell functions. The scene code calls
#   rb_cube per cube (instead of appending to a payload string), rb_rect
#   per 2D HUD fill, and rb_present per frame — which writes RAW PIXELS
#   (32-bit BGRX words, row-major) to /dev/fb0. No device, no shader
#   compiler, no C library decides what a pixel looks like: this file is
#   what a pixel looks like.
#
# THE SHADERS IT FOLLOWS (not reinvents)
#   The game's fragment program is generated at startup by
#   emit_fragment_shader in /mnt/wsl/projects/jcmd/www/bin/mimecroft.sh
#   (line 1312): vcolor -> texture/128 -> CRT scanline -> crack blend ->
#   corruption streaks -> vignette -> clamp. That program is DYNAMIC: the
#   scanline/vignette exist only when CRT_ON=1, the streaks only when
#   CORRUPT_ON=1, and the vignette centre is baked from disp_w/disp_h at
#   emit time. rb_frag below runs the SAME ops in the SAME order with the
#   SAME gates, reading the same game variables (CRT_ON/CORRUPT_ON via
#   rb_frag_flags, the canvas via rb_frag_view) — so a settings change
#   re-shades the bash pixels exactly where it would have re-compiled
#   the GLSL. The canonical all-effects-on reference is
#   /examples/mimecroft-frag.sh; the vertex math (object->world->view,
#   fake perspective x*0.7/y*0.45, world-xz UVs for wide scales) is
#   /examples/mimecroft-vertex.sh. Where this file and
#   sh2perl/runtime/fbdev.c disagree, the SHADERS win — notably the
#   floor/ceiling background planes (scale 20 > 11): the vertex shader
#   tiles their texture from WORLD xz (one repeat per world unit), it
#   does not stretch one copy over the whole 20-wide box.
#
# LANGUAGE DISCIPLINE (same as the game — this file is sourced by it and
# goes through the same transpiler):
#   - arrays declared with a literal (name=(...) or name=()) before any
#     element write; indices are precomputed scalar variables
#   - function args copied to PREFIXED named variables before any use
#   - $(( ... )) never inlined inside echo strings or test brackets
#   - arithmetic keeps ONE group level: `$(( (a-b)*(c-d) ))` lowers but
#     `$(( ((a-b)*(c-d)) / e ))` (a redundant WRAPPER paren around a
#     compound numerator) falls back to a fork-per-evaluation `bash -c`
#     that returns EMPTY — measured, twice. Split wrappers into temp
#     vars; the flat game shapes (`(a*b - c*d) / N`) are safe, keep them
#   - outputs via GLOBALS (command substitution of a shell function does
#     not round-trip here); every function documents its outputs
#   - `break`/`continue` work in WHILE loops but are silently IGNORED
#     in FOR loops (measured) — structure for-loop exits as nested ifs
#   - no local / no $RANDOM / no C-style for / no(( )) statements /
#     no <<< herestrings / no pipe-into-while — while loops only
#   - array reads with a loop-varying index must NOT sit inside a
#     redirected/piped loop body (measured: they read the FIRST element
#     every iteration); rb_present therefore joins "${RFB_ROWS[*]}"
#     whole, with no loop at all — and never passes rows as process
#     arguments (measured: a 240-arg exec fails 127 after ~21s)
#
# ARITHMETIC
#   bash has 64-bit INTEGER arithmetic only and the shaders are double
#   throughout, so every quantity here is fixed point:
#     VSC = 1000000   view/world space (matches the old 1e6 scale)
#     SSC = 1000      screen space (pixels x1000)
#     UVV = 1000      texture space (uv x1000 — cube UVs are 0/1000 and
#                     floor world-xz UVs are milli-world, so both fract
#                     against 1000 and tile once per unit)
#   Coordinates stay below ~2e7 and products below ~1e13, far inside the
#   9.2e18 ceiling.
#
# THE SURFACE
#   Fixed 320x240 (RFBW/RFBH). The rasterizer is demo-speed, not
#   interactive, and 320x240 is the geometry it was measured at; the game
#   pins disp_w/disp_h to it on the simple-fb path. Rows are ASCII HEX
#   (8 chars/px, BGRX order) because bash variables cannot hold a NUL
#   byte and nearly every cleared pixel IS one; rb_present pipes the
#   whole frame through one `xxd -r -p` into the node. That pipe is the
#   ONLY place bytes exist.

RFBW=320
RFBH=240
VSC=1000000
SSC=1000
UVV=1000

RFB_PATH=""
RFB_ROWS=()
# texture store: one flat int array per channel + per-slot base/size.
# Slots mirror the game (1..8 blocks, 9 crack RGBA, 10..15 obsidian/
# chest/mime icons, 21.. label textures, 31.. mime banners).
RBTEX_R=(0)
RBTEX_G=(0)
RBTEX_B=(0)
RBTEX_A=(0)
RBTEX_TOTAL=1
RBTEX_OFF=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
RBTEX_SZ=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
RBTEX_RGBA=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
# the fragment state the dynamic shader would have baked in: effect
# switches (set from the game's CRT_ON/CORRUPT_ON) and the canvas the
# vignette centres on (set from disp_w/disp_h, like the --view arg).
RBF_CRT=0
RBF_CORRUPT=0
RBF_VW=320
RBF_VH=240
# camera state (VSC units + VSC cos/sin)
RBC_X=0
RBC_Y=0
RBC_Z=0
RBC_COS=1000000
RBC_SIN=0
RBC_SHIFT=0
# byte -> 2 hex digits (the pixel-to-row encoding without any fork)
RBHEX=(00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f 40 41 42 43 44 45 46 47 48 49 4a 4b 4c 4d 4e 4f 50 51 52 53 54 55 56 57 58 59 5a 5b 5c 5d 5e 5f 60 61 62 63 64 65 66 67 68 69 6a 6b 6c 6d 6e 6f 70 71 72 73 74 75 76 77 78 79 7a 7b 7c 7d 7e 7f 80 81 82 83 84 85 86 87 88 89 8a 8b 8c 8d 8e 8f 90 91 92 93 94 95 96 97 98 99 9a 9b 9c 9d 9e 9f a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 aa ab ac ad ae af b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 ba bb bc bd be bf c0 c1 c2 c3 c4 c5 c6 c7 c8 c9 ca cb cc cd ce cf d0 d1 d2 d3 d4 d5 d6 d7 d8 d9 da db dc dd de df e0 e1 e2 e3 e4 e5 e6 e7 e8 e9 ea eb ec ed ee ef f0 f1 f2 f3 f4 f5 f6 f7 f8 f9 fa fb fc fd fe ff)

# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/cube_tables.sh"

# ── decimals ─────────────────────────────────────────────────────────
# rb_vdec: decimal string ("2.500", "-0.5", "1") -> VSC int.
#   in:  rbv_s (the string)   out: rbv_v
# Digit-by-digit so leading-zero fractions never meet a base prefix.
rb_vdec() {
  # PADDED buffers: the backend sizes a var's C buffer from its literal
  # assignments, and the old `rbv_ip=0` fallback sized it 2 bytes with
  # an assert(strlen<=1) on the `*` branch — any 2+-digit integer part
  # ("10", "320") aborted the binary. Game decimals fit 8 digits with
  # room (coords/scales/yaw/shift are all <= 6 digits); fractions are
  # always exactly 6 (padded below). A ".5"-style empty ip keeps the
  # pad, which evaluates to 0 — the old fallback's value.
  rbv_sign=1
  rbv_ip="00000000"
  rbv_fp="00000000"
  rbv_s2=$rbv_s
  case $rbv_s2 in -*) rbv_sign=-1; rbv_s2=${rbv_s2#-} ;; esac
  case $rbv_s2 in
    *.*) rbv_ip=${rbv_s2%%.*}; rbv_fp=${rbv_s2#*.} ;;
    *)   rbv_ip=$rbv_s2; rbv_fp="000000" ;;
  esac
  if [ "$rbv_ip" = "" ]; then rbv_ip="00000000"; fi
  rbv_fp="${rbv_fp}000000"
  rbv_fv=0
  rbv_k=0
  while [ "$rbv_k" -lt 6 ]; do
    rbv_d=${rbv_fp:$rbv_k:1}
    rbv_fv=$((rbv_fv * 10 + rbv_d))
    rbv_k=$((rbv_k + 1))
  done
  rbv_v=$((rbv_sign * (rbv_ip * 1000000 + rbv_fv)))
}

# ── fixed-point trig ───────────────────────────────────────────────────
# bash has no libm; the camera yaw is degrees. Maclaurin on a 1e9 scale
# with quadrant folding. out: rbt_cos/rbt_sin (x VSC). in: rbt_deg (int).
T_SCALE=1000000000
DEG2RAD=17453292519943
DEG_RS=1000000
rb_sincos() {
  rbt_d=$rbt_deg
  rbt_d=$((rbt_d % 360))
  if [ "$rbt_d" -lt 0 ]; then rbt_d=$((rbt_d + 360)); fi
  rbt_negc=0
  rbt_negcos=0
  if [ "$rbt_d" -ge 180 ]; then rbt_d=$((rbt_d - 180)); rbt_negc=1; fi
  # supplement branch: sin(180-d)=sin(d) but cos(180-d)=-cos(d), so the
  # cosine needs its OWN negation here. Folding 150->30 and negating
  # both at the end gave cos(-30deg)=-0.866 (measured): every rotation
  # whose folded residue lands in (90,180) mirrored — the -30deg gun/
  # flash quads rendered identically under +30 and -30 records, which is
  # why reverting the gun records changed nothing. The 180-shift below
  # still negates both.
  if [ "$rbt_d" -gt 90 ]; then rbt_d=$((180 - rbt_d)); rbt_negcos=1; fi
  rbt_rad=$((rbt_d * DEG2RAD / DEG_RS))
  rbt_x=$rbt_rad
  rbt_x2=$((rbt_x * rbt_x / T_SCALE))
  rbt_term=$rbt_x
  rbt_ss=$rbt_x
  rbt_sc=$T_SCALE
  rbt_i=3
  while [ "$rbt_i" -le 17 ]; do
    rbt_den=$((rbt_i * (rbt_i - 1)))
    rbt_num=$((rbt_term * rbt_x2 / T_SCALE))
    rbt_term=$((rbt_num / rbt_den))
    rbt_term=$((0 - rbt_term))
    rbt_ss=$((rbt_ss + rbt_term))
    rbt_i=$((rbt_i + 2))
  done
  rbt_term=$T_SCALE
  rbt_i=2
  while [ "$rbt_i" -le 16 ]; do
    rbt_den=$((rbt_i * (rbt_i - 1)))
    rbt_num=$((rbt_term * rbt_x2 / T_SCALE))
    rbt_term=$((rbt_num / rbt_den))
    rbt_term=$((0 - rbt_term))
    rbt_sc=$((rbt_sc + rbt_term))
    rbt_i=$((rbt_i + 2))
  done
  if [ "$rbt_negc" -eq 1 ]; then rbt_ss=$((0 - rbt_ss)); rbt_sc=$((0 - rbt_sc)); fi
  if [ "$rbt_negcos" -eq 1 ]; then rbt_sc=$((0 - rbt_sc)); fi
  rbt_cos=$((rbt_sc / (T_SCALE / VSC)))
  rbt_sin=$((rbt_ss / (T_SCALE / VSC)))
}

# ── the surface ────────────────────────────────────────────────────────
# rb_open [PATH]: fixed 320x240 rows; the path honours $FB0_DEV.
rb_open() {
  rbo_p=$1
  if [ "$rbo_p" = "" ]; then rbo_p=${FB0_DEV:-/dev/fb0}; fi
  RFB_PATH=$rbo_p
  rbo_y=0
  while [ "$rbo_y" -lt "$RFBH" ]; do
    RFB_ROWS[$rbo_y]=""
    rbo_y=$((rbo_y + 1))
  done
  rb_clear 4278190080
}

# rb_clear ARGB-int (e.g. 4278190080 = 0xFF000000): every pixel of
# every row. Alpha is dropped — the node holds BGRX (X=00), the word
# the device's own put_px stores.
rb_clear() {
  rbc_a=$1
  rbc_r=$(( (rbc_a >> 16) & 255 ))
  rbc_g=$(( (rbc_a >> 8) & 255 ))
  rbc_b=$(( rbc_a & 255 ))
  rb_mkhex $rbc_r $rbc_g $rbc_b
  rb_mkrun $RFBW "$rb_pxhex"
  rbc_y=0
  while [ "$rbc_y" -lt "$RFBH" ]; do
    RFB_ROWS[$rbc_y]=$rb_run
    rbc_y=$((rbc_y + 1))
  done
}

# rb_mkhex R G B -> rb_pxhex (8 hex chars, BGRX device order).
rb_mkhex() {
  rbm_r=$1
  rbm_g=$2
  rbm_b=$3
  rbm_bh=${RBHEX[$rbm_b]}
  rbm_gh=${RBHEX[$rbm_g]}
  rbm_rh=${RBHEX[$rbm_r]}
  rb_pxhex="${rbm_bh}${rbm_gh}${rbm_rh}00"
}

# rb_mkrun N PAT -> rb_run: PAT repeated N times.
rb_mkrun() {
  rbm_n=$1
  rbm_p=$2
  rb_run=""
  if [ "$rbm_n" -le 0 ]; then return; fi
  rbm_blk=$rbm_p
  rbm_i=0
  while [ "$rbm_i" -lt 8 ]; do
    rbm_blk="${rbm_blk}${rbm_blk}"
    rbm_i=$((rbm_i + 1))
  done
  rbm_c=$((rbm_n / 256))
  rbm_i=0
  while [ "$rbm_i" -lt "$rbm_c" ]; do
    rb_run="${rb_run}${rbm_blk}"
    rbm_i=$((rbm_i + 1))
  done
  rbm_rem=$((rbm_n - rbm_c * 256))
  rbm_i=0
  while [ "$rbm_i" -lt "$rbm_rem" ]; do
    rb_run="${rb_run}${rbm_p}"
    rbm_i=$((rbm_i + 1))
  done
}

# rb_putrun Y X0 N PXHEX: paint N pixels of row Y from X0 (clipped).
rb_putrun() {
  rbp_y=$1
  rbp_x0=$2
  rbp_n=$3
  rbp_p=$4
  if [ "$rbp_n" -le 0 ]; then return; fi
  if [ "$rbp_y" -lt 0 ]; then return; fi
  if [ "$rbp_y" -ge "$RFBH" ]; then return; fi
  if [ "$rbp_x0" -lt 0 ]; then rbp_n=$((rbp_n + rbp_x0)); rbp_x0=0; fi
  if [ "$rbp_x0" -ge "$RFBW" ]; then return; fi
  if [ $((rbp_x0 + rbp_n)) -gt "$RFBW" ]; then rbp_n=$((RFBW - rbp_x0)); fi
  if [ "$rbp_n" -le 0 ]; then return; fi
  rbp_o=$((rbp_x0 * 8))
  rbp_len=$((rbp_n * 8))
  rbp_row=${RFB_ROWS[$rbp_y]}
  # the textured path paints 1px at a time: building the 256-px block
  # for a single pixel wastes ~2KB of garbage per pixel (~1GB/frame),
  # so short runs repeat the pattern directly.
  if [ "$rbp_n" -eq 1 ]; then
    rb_run=$rbp_p
  else
    rb_mkrun $rbp_n "$rbp_p"
  fi
  rbp_keep=$((rbp_o + rbp_len))
  RFB_ROWS[$rbp_y]="${rbp_row:0:$rbp_o}${rb_run}${rbp_row:$rbp_keep}"
}

# rb_rect X Y W H R G B: a 2D fill in device pixels (the HUD path).
rb_rect() {
  rbr_x=$1
  rbr_y=$2
  rbr_w=$3
  rbr_h=$4
  rb_mkhex $5 $6 $7
  rbr_y2=$((rbr_y + rbr_h))
  while [ "$rbr_y" -lt "$rbr_y2" ]; do
    rb_putrun $rbr_y $rbr_x $rbr_w "$rb_pxhex"
    rbr_y=$((rbr_y + 1))
  done
}

# rb_present: the frame to the node — the ONLY place bytes exist.
# The rows are joined whole ("${RFB_ROWS[*]}", no loop-varying index
# under any redirect), echoed to a temp hex file, and decoded by one
# `xxd -r -p` with a tiny argv (xxd ignores the join spaces).
rb_present() {
  if [ "$RFB_PATH" = "" ]; then return 1; fi
  # Single redirect writes over ~100KB are SILENTLY DROPPED by the
  # runtime (measured: 102401 bytes land, 204800 do not — rc stays 0),
  # and 240 rows do not fit in one exec argv either (measured: the
  # call fails 127 after ~21s). So the frame goes out in 16-row chunks
  # (~41KB each): one small echo per chunk, one small-argv xxd total.
  : > /tmp/rb-frame.hex
  rbp_y=0
  while [ "$rbp_y" -lt "$RFBH" ]; do
    rbp_chunk=""
    rbp_k=0
    while [ "$rbp_k" -lt 16 ]; do
      rbp_ry=$((rbp_y + rbp_k))
      if [ "$rbp_ry" -ge "$RFBH" ]; then break; fi
      rbp_chunk="${rbp_chunk}${RFB_ROWS[$rbp_ry]} "
      rbp_k=$((rbp_k + 1))
    done
    echo "$rbp_chunk" >> /tmp/rb-frame.hex
    rbp_y=$((rbp_y + rbp_k))
  done
  xxd -r -p /tmp/rb-frame.hex > "$RFB_PATH"
  return 0
}

# rb_dump_ppm PATH: the frame as binary P6 (the headless diagnostic).
# Rows are BGRX hex; the body needs RGB bytes, so each pixel is
# reordered (byte-swapped, still hex text) and decoded in one xxd run.
rb_dump_ppm() {
  rbd_p=$1
  echo "P6 $RFBW $RFBH 255" > "$rbd_p"
  : > /tmp/rb-dump.hex
  rbd_y2=0
  while [ "$rbd_y2" -lt "$RFBH" ]; do
    rbd_body=""
    rbd_k=0
    while [ "$rbd_k" -lt 16 ]; do
      rbd_yy=$((rbd_y2 + rbd_k))
      if [ "$rbd_yy" -ge "$RFBH" ]; then break; fi
      rbd_row=${RFB_ROWS[$rbd_yy]}
      rbd_x=0
      while [ "$rbd_x" -lt "$RFBW" ]; do
        rbd_o=$((rbd_x * 8))
        rbd_px=${rbd_row:$rbd_o:8}
        rbd_b=${rbd_px:0:2}
        rbd_g=${rbd_px:2:2}
        rbd_r=${rbd_px:4:2}
        rbd_body="${rbd_body}${rbd_r}${rbd_g}${rbd_b}"
        rbd_x=$((rbd_x + 1))
      done
      rbd_k=$((rbd_k + 1))
    done
    echo "$rbd_body" >> /tmp/rb-dump.hex
    rbd_y2=$((rbd_y2 + rbd_k))
  done
  xxd -r -p /tmp/rb-dump.hex >> "$rbd_p"
}

# ── camera ─────────────────────────────────────────────────────────────
# rb_camera X Y Z YAWDEG SHIFTDEC — world units as decimals, yaw in
# degrees (may be fractional: truncated to int, sub-degree turns are
# invisible at 320x240 and the glide still reads as motion).
rb_camera() {
  rbv_s=$1
  rb_vdec
  RBC_X=$rbv_v
  rbv_s=$2
  rb_vdec
  RBC_Y=$rbv_v
  rbv_s=$3
  rb_vdec
  RBC_Z=$rbv_v
  rbv_s=$4
  rb_vdec
  rbt_deg=$((rbv_v / 1000000))
  rb_sincos
  RBC_COS=$rbt_cos
  RBC_SIN=$rbt_sin
  rbv_s=$5
  rb_vdec
  RBC_SHIFT=$rbv_v
}

# rb_frag_flags CRT CORRUPT + rb_frag_view W H: the two facts the
# dynamic fragment program used to bake in at emit time.
rb_frag_flags() {
  RBF_CRT=$1
  RBF_CORRUPT=$2
}
rb_frag_view() {
  RBF_VW=$1
  RBF_VH=$2
}

# ── textures ───────────────────────────────────────────────────────────
# rb_tex_load IDX RPLANE GPLANE BPLANE N SIZE RGBA — the fb_texture
# signature verbatim: three space-separated int planes walked in
# parallel (this plane's cursor MOVES ON, like the C), N texels.
#   in: rbx_*   out: none (RBTEX_* store + RBTEX_OFF/SZ/RGBA)
rb_tex_load() {
  rbx_idx=$1
  rbx_rp=$2
  rbx_gp=$3
  rbx_bp=$4
  rbx_n=$5
  rbx_sz=$6
  rbx_rgba=$7
  rbx_off=$RBTEX_TOTAL
  RBTEX_OFF[$rbx_idx]=$rbx_off
  RBTEX_SZ[$rbx_idx]=$rbx_sz
  RBTEX_RGBA[$rbx_idx]=$rbx_rgba
  rbx_k=0
  while [ "$rbx_k" -lt "$rbx_n" ]; do
    case $rbx_rp in
      *" "*) rbx_rv=${rbx_rp%% *}; rbx_rp=${rbx_rp#* } ;;
      *) rbx_rv=$rbx_rp; rbx_rp="" ;;
    esac
    case $rbx_gp in
      *" "*) rbx_gv=${rbx_gp%% *}; rbx_gp=${rbx_gp#* } ;;
      *) rbx_gv=$rbx_gp; rbx_gp="" ;;
    esac
    case $rbx_bp in
      *" "*) rbx_bv=${rbx_bp%% *}; rbx_bp=${rbx_bp#* } ;;
      *) rbx_bv=$rbx_bp; rbx_bp="" ;;
    esac
    if [ "$rbx_rv" -lt 0 ]; then rbx_rv=0; fi
    if [ "$rbx_rv" -gt 255 ]; then rbx_rv=255; fi
    if [ "$rbx_gv" -lt 0 ]; then rbx_gv=0; fi
    if [ "$rbx_gv" -gt 255 ]; then rbx_gv=255; fi
    if [ "$rbx_bv" -lt 0 ]; then rbx_bv=0; fi
    if [ "$rbx_bv" -gt 255 ]; then rbx_bv=255; fi
    RBTEX_R+=("$rbx_rv")
    RBTEX_G+=("$rbx_gv")
    RBTEX_B+=("$rbx_bv")
    if [ "$rbx_rgba" -ne 0 ]; then RBTEX_A+=("$rbx_bv"); else RBTEX_A+=("255"); fi
    rbx_off=$((rbx_off + 1))
    rbx_k=$((rbx_k + 1))
  done
  RBTEX_TOTAL=$rbx_off
}

# rb_tex_sample SLOT U V (U/V milli-uv, may be negative — the floor
# planes tile from world coords): fract-wrap like the shader's
# GL_REPEAT, then the texel. out: rbx_r/rbx_g/rbx_b/rbx_a.
rb_tex_sample() {
  rbx_s=$1
  rbx_uu=$2
  rbx_vv=$3
  rbx_sz2=${RBTEX_SZ[$rbx_s]}
  rbx_fu=$rbx_uu
  while [ "$rbx_fu" -lt 0 ]; do rbx_fu=$((rbx_fu + 1000)); done
  while [ "$rbx_fu" -ge 1000 ]; do rbx_fu=$((rbx_fu - 1000)); done
  rbx_fv=$rbx_vv
  while [ "$rbx_fv" -lt 0 ]; do rbx_fv=$((rbx_fv + 1000)); done
  while [ "$rbx_fv" -ge 1000 ]; do rbx_fv=$((rbx_fv - 1000)); done
  rbx_iu=$((rbx_fu * rbx_sz2 / 1000))
  rbx_iv=$((rbx_fv * rbx_sz2 / 1000))
  rbx_bo=${RBTEX_OFF[$rbx_s]}
  rbx_ti=$((rbx_bo + rbx_iv * rbx_sz2 + rbx_iu))
  rbx_r=${RBTEX_R[$rbx_ti]}
  rbx_g=${RBTEX_G[$rbx_ti]}
  rbx_b=${RBTEX_B[$rbx_ti]}
  rbx_a=${RBTEX_A[$rbx_ti]}
}

# ── projection ─────────────────────────────────────────────────────────
# rb_tv APX APY APZ OX OY OZ SX SY SZ (ap in milli, o in VSC, s in
# milli): object -> view. out: rbv_x/rb_vy/rbv_w (micro-world).
# Matches the vertex shader: p = ap*s/1e6 + o; d = p - (cam + eye);
# rel = yaw-rotated d; w = -rel.z. The eye is C_y + 0.5 world.
rb_tv() {
  rbt_apx=$1
  rbt_apy=$2
  rbt_apz=$3
  rbt_ox=$4
  rbt_oy=$5
  rbt_oz=$6
  rbt_sx=$7
  rbt_sy=$8
  rbt_sz=$9
  rbt_wx=$((rbt_apx * rbt_sx / 1000 + rbt_ox / 1000))
  rbt_wy=$((rbt_apy * rbt_sy / 1000 + rbt_oy / 1000))
  rbt_wz=$((rbt_apz * rbt_sz / 1000 + rbt_oz / 1000))
  rbt_dx=$((rbt_wx - RBC_X / 1000))
  rbt_dy=$((rbt_wy - (RBC_Y + 500000) / 1000))
  rbt_dz=$((rbt_wz - RBC_Z / 1000))
  rbv_x=$(( (rbt_dx * RBC_COS + rbt_dz * RBC_SIN) / VSC ))
  rbv_y=$rbt_dy
  rbv_w=$(( (rbt_dx * RBC_SIN - rbt_dz * RBC_COS) / VSC ))
}

# rb_project X Y W (milli-world): view -> device pixels, KEPT at SSC
# (x1000) for the clipper and rasterizer below. ndcx = x*0.7 + shift*w
# (shift is NDC: VSC/1e6); ndcy = y*0.45; then NDC -> pixels, +y DOWN.
# The multiply by W/H comes BEFORE the final /2 so the truncation is
# at milli-pixels, and the /SSC is SKIPPED: corners stay x1000.
# 0.01 world, in MILLI (the units _tv emits: milli-world). The C
# device's W_NEAR is 0.01 for the same reason: fifty times closer than
# the nearest real surface (0.5), so no drawable cube is ever clipped,
# while a clipped vertex still divides to only ~5600px off-screen (the
# guard band trims the rest). 1000 here (= 1.0 world) ate the whole near
# field — the floor under the camera never drew.
RB_WNEAR=10
rb_project() {
  rbp_x=$1
  rbp_y=$2
  rbp_w=$3
  if [ "$rbp_w" -lt "$RB_WNEAR" ]; then rbp_w=$RB_WNEAR; fi
  rbp_ndx=$((rbp_x * 7 / 10 + RBC_SHIFT * rbp_w / 1000000))
  rbp_ndy=$((rbp_y * 45 / 100))
  rbp_sx=$(( (rbp_ndx * SSC / rbp_w + SSC) * RFBW / 2 ))
  rbp_sy=$(( (SSC - rbp_ndy * SSC / rbp_w) * RFBH / 2 ))
}

# ── the cube pipeline ──────────────────────────────────────────────────
# rb_cube OX OY OZ SX SY SZ R G B — one cube, drawn NOW in call order
# (the painter's algorithm lives in the caller, exactly as the payload
# order used to carry it). o = world decimals, s = scale decimals
# ("1", "0.7", "20"), r/g/b = 0..1 decimals. TEX/DAM come in via the
# rbc_tex/rbc_dam globals (set by the caller — $10+ positionals are
# not used in this codebase).
# Faces are depth-sorted far-to-near (the index order is a fixed face
# list, NOT a depth order).
RB_ORD=(0 0 0 0 0 0 0 0 0 0 0 0)
RB_DEP=(0 0 0 0 0 0 0 0 0 0 0 0)
rb_cube() {
  rbv_s=$1
  rb_vdec
  rbc_ox=$rbv_v
  rbv_s=$2
  rb_vdec
  rbc_oy=$rbv_v
  rbv_s=$3
  rb_vdec
  rbc_oz=$rbv_v
  rbv_s=$4
  rb_vdec
  rbc_sx=$((rbv_v / 1000))
  rbv_s=$5
  rb_vdec
  rbc_sy=$((rbv_v / 1000))
  rbv_s=$6
  rb_vdec
  rbc_sz=$((rbv_v / 1000))
  rbv_s=$7
  rb_vdec
  rbc_tr=$(( (rbv_v * 255 + 500000) / 1000000 ))
  rbv_s=$8
  rb_vdec
  rbc_tg=$(( (rbv_v * 255 + 500000) / 1000000 ))
  rbv_s=$9
  rb_vdec
  rbc_tb=$(( (rbv_v * 255 + 500000) / 1000000 ))
  if [ "$rbc_tr" -lt 0 ]; then rbc_tr=0; fi
  if [ "$rbc_tr" -gt 255 ]; then rbc_tr=255; fi
  if [ "$rbc_tg" -lt 0 ]; then rbc_tg=0; fi
  if [ "$rbc_tg" -gt 255 ]; then rbc_tg=255; fi
  if [ "$rbc_tb" -lt 0 ]; then rbc_tb=0; fi
  if [ "$rbc_tb" -gt 255 ]; then rbc_tb=255; fi
  if [ "$rbc_tex" = "" ]; then rbc_tex=-1; fi
  if [ "$rbc_dam" = "" ]; then rbc_dam=0; fi
  rbc_wide=0
  if [ "$rbc_sx" -gt 1100 ]; then rbc_wide=1; fi
  rbc_i=0
  while [ "$rbc_i" -lt 12 ]; do
    rbc_cx=0
    rbc_cy=0
    rbc_cz=0
    rbc_k=0
    while [ "$rbc_k" -lt 3 ]; do
      rbc_ii=$((rbc_i * 3 + rbc_k))
      rbc_vi=${CUBE_I[$rbc_ii]}
      rbc_p0=$((rbc_vi * 3))
      rbc_p1=$((rbc_vi * 3 + 1))
      rbc_p2=$((rbc_vi * 3 + 2))
      rbc_pv0=${CUBE_P[$rbc_p0]}
      rbc_pv1=${CUBE_P[$rbc_p1]}
      rbc_pv2=${CUBE_P[$rbc_p2]}
      rbc_cx=$((rbc_cx + rbc_pv0 * rbc_sx / 1000 + rbc_ox / 1000))
      rbc_cy=$((rbc_cy + rbc_pv1 * rbc_sy / 1000 + rbc_oy / 1000))
      rbc_cz=$((rbc_cz + rbc_pv2 * rbc_sz / 1000 + rbc_oz / 1000))
      rbc_k=$((rbc_k + 1))
    done
    rbc_cx=$((rbc_cx / 3))
    rbc_cy=$((rbc_cy / 3))
    rbc_cz=$((rbc_cz / 3))
    rbc_ddx=$((rbc_cx - RBC_X * 1000))
    rbc_ddz=$((rbc_cz - RBC_Z * 1000))
    rbc_relz=$(( (0 - rbc_ddx * RBC_SIN + rbc_ddz * RBC_COS) / VSC ))
    RB_DEP[$rbc_i]=$((0 - rbc_relz))
    RB_ORD[$rbc_i]=$rbc_i
    rbc_i=$((rbc_i + 1))
  done
  rbc_i=1
  while [ "$rbc_i" -lt 12 ]; do
    rbc_t=${RB_ORD[$rbc_i]}
    rbc_td=${RB_DEP[$rbc_t]}
    rbc_a=$((rbc_i - 1))
    while [ "$rbc_a" -ge 0 ]; do
      rbc_ao=${RB_ORD[$rbc_a]}
      rbc_ad=${RB_DEP[$rbc_ao]}
      rbc_ap1=$((rbc_a + 1))
      if [ "$rbc_ad" -lt "$rbc_td" ]; then RB_ORD[$rbc_ap1]=$rbc_ao; else break; fi
      rbc_a=$((rbc_a - 1))
    done
    rbc_ap1=$((rbc_a + 1))
    RB_ORD[$rbc_ap1]=$rbc_t
    rbc_i=$((rbc_i + 1))
  done
  rbc_b=0
  while [ "$rbc_b" -lt 12 ]; do
    rbc_fi=${RB_ORD[$rbc_b]}
    rb_face $rbc_fi
    rbc_b=$((rbc_b + 1))
  done
}

# polygon buffers (the clipped screen-space polygon + its shade and
# texture-space corners — 8 is the exact bound: 3 + 5 clip planes).
RB_PX=(0 0 0 0 0 0 0 0)
RB_PY=(0 0 0 0 0 0 0 0)
RB_PS=(0 0 0 0 0 0 0 0)
RB_PU=(0 0 0 0 0 0 0 0)
RB_PV=(0 0 0 0 0 0 0 0)
RB_QX=(0 0 0 0 0 0 0 0)
RB_QY=(0 0 0 0 0 0 0 0)
RB_QS=(0 0 0 0 0 0 0 0)
RB_QU=(0 0 0 0 0 0 0 0)
RB_QV=(0 0 0 0 0 0 0 0)

# rb_wuv VI: world-xz milli-uv of vertex VI of the current cube (the
# wide-box branch of the vertex shader: vu = ap*usc/1000 + uop).
rb_wuv() {
  rbf_wi=$1
  rbf_wp0=$((rbf_wi * 3))
  rbf_wp2=$((rbf_wi * 3 + 2))
  rbf_wpx=${CUBE_P[$rbf_wp0]}
  rbfwpz=${CUBE_P[$rbf_wp2]}
  rbf_uu=$((rbf_wpx * rbc_sx / 1000 + rbc_ox / 1000))
  rbf_vv=$((rbfwpz * rbc_sz / 1000 + rbc_oz / 1000))
}

# rb_face FI: one triangle of the current cube (reads rbc_*). Back-face
# cull (all three vertices away), near-plane clip, guard-band clip,
# then fan-triangulate into rb_tri. UVs are the cube's own CUBE_UV
# corners — EXCEPT a wide box (the floor/ceiling planes): the vertex
# shader passes WORLD xz there so the texture tiles once per unit.
rb_face() {
  rbf_fi=$1
  rbf_fn=$((rbf_fi / 2))
  rbf_nj0=$((rbf_fn * 3))
  rbf_nj1=$((rbf_fn * 3 + 1))
  rbf_nj2=$((rbf_fn * 3 + 2))
  rbf_n0=${FACE_N[$rbf_nj0]}
  rbf_n1=${FACE_N[$rbf_nj1]}
  rbf_n2=${FACE_N[$rbf_nj2]}
  rbf_nvx=$(( (rbf_n0 * RBC_COS + rbf_n2 * RBC_SIN) / VSC ))
  rbf_nvz=$(( (0 - rbf_n0 * RBC_SIN + rbf_n2 * RBC_COS) / VSC ))
  rbf_front=0
  rbf_e=0
  while [ "$rbf_e" -lt 3 ]; do
    rbf_ii=$((rbf_fi * 3 + rbf_e))
    rbf_vi=${CUBE_I[$rbf_ii]}
    rbf_p0=$((rbf_vi * 3))
    rbf_p1=$((rbf_vi * 3 + 1))
    rbf_p2=$((rbf_vi * 3 + 2))
    rbf_pv0=${CUBE_P[$rbf_p0]}
    rbf_pv1=${CUBE_P[$rbf_p1]}
    rbf_pv2=${CUBE_P[$rbf_p2]}
    rbf_fx=$((rbf_pv0 * rbc_sx / 1000 + rbc_ox / 1000 - RBC_X / 1000))
    rbf_fy=$((rbf_pv1 * rbc_sy / 1000 + rbc_oy / 1000 - (RBC_Y + 500000) / 1000))
    rbf_fz=$((rbf_pv2 * rbc_sz / 1000 + rbc_oz / 1000 - RBC_Z / 1000))
    rbf_dx=$(( (rbf_fx * RBC_COS + rbf_fz * RBC_SIN) / VSC ))
    rbf_dz=$(( (0 - rbf_fx * RBC_SIN + rbf_fz * RBC_COS) / VSC ))
    rbf_dot=$(( (rbf_nvx * rbf_dx + rbf_n1 * rbf_fy + rbf_nvz * rbf_dz) / (VSC * 1000) ))
    if [ "$rbf_dot" -ge 0 ]; then rbf_front=1; fi
    rbf_e=$((rbf_e + 1))
  done
  if [ "$rbf_front" -eq 0 ]; then return; fi
  rbf_np=0
  rbf_k=0
  while [ "$rbf_k" -lt 3 ]; do
    rbf_k2=$(( (rbf_k + 1) % 3 ))
    rbf_ij0=$((rbf_fi * 3 + rbf_k))
    rbf_ij1=$((rbf_fi * 3 + rbf_k2))
    rbf_ia=${CUBE_I[$rbf_ij0]}
    rbf_ib=${CUBE_I[$rbf_ij1]}
    rbf_s0=${CUBE_SHADE[$rbf_ia]}
    rbf_s1=${CUBE_SHADE[$rbf_ib]}
    rbf_uj0=$((rbf_ia * 2))
    rbf_vj0=$((rbf_ia * 2 + 1))
    rbf_uj1=$((rbf_ib * 2))
    rbf_vj1=$((rbf_ib * 2 + 1))
    rbf_u0=${CUBE_UV[$rbf_uj0]}
    rbf_v0=${CUBE_UV[$rbf_vj0]}
    rbf_u1=${CUBE_UV[$rbf_uj1]}
    rbf_v1=${CUBE_UV[$rbf_vj1]}
    rbf_pj0=$((rbf_ia * 3))
    rbf_pj1=$((rbf_ia * 3 + 1))
    rbf_pj2=$((rbf_ia * 3 + 2))
    rbf_qj0=$((rbf_ib * 3))
    rbf_qj1=$((rbf_ib * 3 + 1))
    rbf_qj2=$((rbf_ib * 3 + 2))
    rbf_ia0=${CUBE_P[$rbf_pj0]}
    rbf_ia1=${CUBE_P[$rbf_pj1]}
    rbf_ia2=${CUBE_P[$rbf_pj2]}
    rbf_ib0=${CUBE_P[$rbf_qj0]}
    rbf_ib1=${CUBE_P[$rbf_qj1]}
    rbf_ib2=${CUBE_P[$rbf_qj2]}
    rb_tv $rbf_ia0 $rbf_ia1 $rbf_ia2 $rbc_ox $rbc_oy $rbc_oz $rbc_sx $rbc_sy $rbc_sz
    rbf_ax=$rbv_x
    rbf_ay=$rbv_y
    rbf_aw=$rbv_w
    rb_tv $rbf_ib0 $rbf_ib1 $rbf_ib2 $rbc_ox $rbc_oy $rbc_oz $rbc_sx $rbc_sy $rbc_sz
    rbf_bx=$rbv_x
    rbf_by=$rbv_y
    rbf_bw=$rbv_w
    if [ "$rbf_aw" -gt "$RB_WNEAR" ]; then
      if [ "$rbf_np" -lt 8 ]; then
        rb_project $rbf_ax $rbf_ay $rbf_aw
        RB_PX[$rbf_np]=$rbp_sx
        RB_PY[$rbf_np]=$rbp_sy
        RB_PS[$rbf_np]=$rbf_s0
        if [ "$rbc_wide" -eq 1 ]; then rb_wuv $rbf_ia; else rbf_uu=$((rbf_u0 * 1000)); rbf_vv=$((rbf_v0 * 1000)); fi
        RB_PU[$rbf_np]=$rbf_uu
        RB_PV[$rbf_np]=$rbf_vv
        rbf_np=$((rbf_np + 1))
      fi
    fi
    rbf_cross=0
    if [ "$rbf_aw" -gt "$RB_WNEAR" ]; then
      if [ "$rbf_bw" -le "$RB_WNEAR" ]; then rbf_cross=1; fi
    else
      if [ "$rbf_bw" -gt "$RB_WNEAR" ]; then rbf_cross=1; fi
    fi
    if [ "$rbf_cross" -eq 1 ]; then
      if [ "$rbf_np" -lt 8 ]; then
        rbf_u=$(( (RB_WNEAR - rbf_aw) * 1000 / (rbf_bw - rbf_aw) ))
        rbf_ix=$((rbf_ax + (rbf_bx - rbf_ax) * rbf_u / 1000))
        rbf_iy=$((rbf_ay + (rbf_by - rbf_ay) * rbf_u / 1000))
        rb_project $rbf_ix $rbf_iy $RB_WNEAR
        RB_PX[$rbf_np]=$rbp_sx
        RB_PY[$rbf_np]=$rbp_sy
        RB_PS[$rbf_np]=$((rbf_s0 + (rbf_s1 - rbf_s0) * rbf_u / 1000))
        if [ "$rbc_wide" -eq 1 ]; then
          rb_wuv $rbf_ia
          rbf_wa=$rbf_uu
          rbf_wb=$rbf_vv
          rb_wuv $rbf_ib
          rbf_uu=$((rbf_wa + (rbf_uu - rbf_wa) * rbf_u / 1000))
          rbf_vv=$((rbf_wb + (rbf_vv - rbf_wb) * rbf_u / 1000))
        else
          rbf_ud=$((rbf_u1 - rbf_u0))
          rbf_vd=$((rbf_v1 - rbf_v0))
          rbf_uu=$((rbf_u0 * 1000 + rbf_ud * rbf_u))
          rbf_vv=$((rbf_v0 * 1000 + rbf_vd * rbf_u))
        fi
        RB_PU[$rbf_np]=$rbf_uu
        RB_PV[$rbf_np]=$rbf_vv
        rbf_np=$((rbf_np + 1))
      fi
    fi
    rbf_k=$((rbf_k + 1))
  done
  if [ "$rbf_np" -lt 3 ]; then return; fi
  # guard-band clip: 4 passes into the second buffer
  rbf_k=0
  while [ "$rbf_k" -lt 4 ]; do
    if [ "$rbf_k" -eq 0 ]; then rbf_nx=$SSC; rbf_ny=0; rbf_dd=$SSC; fi
    if [ "$rbf_k" -eq 1 ]; then rbf_nx=$((0 - SSC)); rbf_ny=0; rbf_dd=$(( (RFBW + 1) * SSC )); fi
    if [ "$rbf_k" -eq 2 ]; then rbf_nx=0; rbf_ny=$SSC; rbf_dd=$SSC; fi
    if [ "$rbf_k" -eq 3 ]; then rbf_nx=0; rbf_ny=$((0 - SSC)); rbf_dd=$(( (RFBH + 1) * SSC )); fi
    rbf_m=0
    rbf_e=0
    while [ "$rbf_e" -lt "$rbf_np" ]; do
      rbf_e2=$(( (rbf_e + 1) % rbf_np ))
      rbf_ex=${RB_PX[$rbf_e]}
      rbf_ey=${RB_PY[$rbf_e]}
      rbf_ex2=${RB_PX[$rbf_e2]}
      rbf_ey2=${RB_PY[$rbf_e2]}
      rbf_d0=$(( (rbf_ex * rbf_nx + rbf_ey * rbf_ny) / SSC + rbf_dd ))
      rbf_d1=$(( (rbf_ex2 * rbf_nx + rbf_ey2 * rbf_ny) / SSC + rbf_dd ))
      if [ "$rbf_d0" -ge 0 ]; then
        if [ "$rbf_m" -lt 8 ]; then
          RB_QX[$rbf_m]=$rbf_ex
          RB_QY[$rbf_m]=$rbf_ey
          RB_QS[$rbf_m]=${RB_PS[$rbf_e]}
          RB_QU[$rbf_m]=${RB_PU[$rbf_e]}
          RB_QV[$rbf_m]=${RB_PV[$rbf_e]}
          rbf_m=$((rbf_m + 1))
        fi
      fi
      rbf_cc=0
      if [ "$rbf_d0" -ge 0 ]; then
        if [ "$rbf_d1" -lt 0 ]; then rbf_cc=1; fi
      else
        if [ "$rbf_d1" -ge 0 ]; then rbf_cc=1; fi
      fi
      if [ "$rbf_cc" -eq 1 ]; then
        if [ "$rbf_m" -lt 8 ]; then
          rbf_cu=$((rbf_d0 * 1000 / (rbf_d0 - rbf_d1)))
          RB_QX[$rbf_m]=$((rbf_ex + (rbf_ex2 - rbf_ex) * rbf_cu / 1000))
          RB_QY[$rbf_m]=$((rbf_ey + (rbf_ey2 - rbf_ey) * rbf_cu / 1000))
          rbf_es=${RB_PS[$rbf_e]}
          rbf_es2=${RB_PS[$rbf_e2]}
          RB_QS[$rbf_m]=$((rbf_es + (rbf_es2 - rbf_es) * rbf_cu / 1000))
          rbf_eu=${RB_PU[$rbf_e]}
          rbf_eu2=${RB_PU[$rbf_e2]}
          RB_QU[$rbf_m]=$((rbf_eu + (rbf_eu2 - rbf_eu) * rbf_cu / 1000))
          rbf_ev=${RB_PV[$rbf_e]}
          rbf_ev2=${RB_PV[$rbf_e2]}
          RB_QV[$rbf_m]=$((rbf_ev + (rbf_ev2 - rbf_ev) * rbf_cu / 1000))
          rbf_m=$((rbf_m + 1))
        fi
      fi
      rbf_e=$((rbf_e + 1))
    done
    rbf_np=$rbf_m
    rbf_e=0
    while [ "$rbf_e" -lt "$rbf_np" ]; do
      RB_PX[$rbf_e]=${RB_QX[$rbf_e]}
      RB_PY[$rbf_e]=${RB_QY[$rbf_e]}
      RB_PS[$rbf_e]=${RB_QS[$rbf_e]}
      RB_PU[$rbf_e]=${RB_QU[$rbf_e]}
      RB_PV[$rbf_e]=${RB_QV[$rbf_e]}
      rbf_e=$((rbf_e + 1))
    done
    rbf_k=$((rbf_k + 1))
  done
  if [ "$rbf_np" -lt 3 ]; then return; fi
  # fan-triangulate (triangle corners via globals — 15 args would need
  # $10+ positionals)
  rbf_k=2
  while [ "$rbf_k" -lt "$rbf_np" ]; do
    rbf_k1=$((rbf_k - 1))
    rbt_x0=${RB_PX[0]}
    rbt_y0=${RB_PY[0]}
    rbt_s0=${RB_PS[0]}
    rbt_u0=${RB_PU[0]}
    rbt_v0=${RB_PV[0]}
    rbt_x1=${RB_PX[$rbf_k1]}
    rbt_y1=${RB_PY[$rbf_k1]}
    rbt_s1=${RB_PS[$rbf_k1]}
    rbt_u1=${RB_PU[$rbf_k1]}
    rbt_v1=${RB_PV[$rbf_k1]}
    rbt_x2=${RB_PX[$rbf_k]}
    rbt_y2=${RB_PY[$rbf_k]}
    rbt_s2=${RB_PS[$rbf_k]}
    rbt_u2=${RB_PU[$rbf_k]}
    rbt_v2=${RB_PV[$rbf_k]}
    rb_tri
    rbf_k=$((rbf_k + 1))
  done
}

# rb_tri: rasterize one triangle (corners in rbt_x0/y0/s0/u0/v0 .. x2..,
# the cube's tint in rbc_tr/tg/tb, texture/damage in rbc_tex/dam).
# Winding-normalised half-plane coverage + barycentric shade AND uv
# (the fragment varying). The fill coalesces same-colour runs on the
# FLAT path; the TEXTURED path paints per pixel (every pixel differs).
rb_tri() {
  rbt_area=$(( (rbt_x1 - rbt_x0) * (rbt_y2 - rbt_y0) - (rbt_y1 - rbt_y0) * (rbt_x2 - rbt_x0) ))
  rbt_area=$((rbt_area / SSC))
  if [ "$rbt_area" -eq 0 ]; then return; fi
  if [ "$rbt_area" -lt 0 ]; then
    rbt_t=$rbt_x1; rbt_x1=$rbt_x2; rbt_x2=$rbt_t
    rbt_t=$rbt_y1; rbt_y1=$rbt_y2; rbt_y2=$rbt_t
    rbt_t=$rbt_s1; rbt_s1=$rbt_s2; rbt_s2=$rbt_t
    rbt_t=$rbt_u1; rbt_u1=$rbt_u2; rbt_u2=$rbt_t
    rbt_t=$rbt_v1; rbt_v1=$rbt_v2; rbt_v2=$rbt_t
    rbt_area=$((0 - rbt_area))
  fi
  if [ "$rbt_x0" -lt "$rbt_x1" ]; then
    if [ "$rbt_x0" -lt "$rbt_x2" ]; then rbt_minx=$rbt_x0; else rbt_minx=$rbt_x2; fi
  else
    if [ "$rbt_x1" -lt "$rbt_x2" ]; then rbt_minx=$rbt_x1; else rbt_minx=$rbt_x2; fi
  fi
  if [ "$rbt_x0" -gt "$rbt_x1" ]; then
    if [ "$rbt_x0" -gt "$rbt_x2" ]; then rbt_maxx=$rbt_x0; else rbt_maxx=$rbt_x2; fi
  else
    if [ "$rbt_x1" -gt "$rbt_x2" ]; then rbt_maxx=$rbt_x1; else rbt_maxx=$rbt_x2; fi
  fi
  if [ "$rbt_y0" -lt "$rbt_y1" ]; then
    if [ "$rbt_y0" -lt "$rbt_y2" ]; then rbt_miny=$rbt_y0; else rbt_miny=$rbt_y2; fi
  else
    if [ "$rbt_y1" -lt "$rbt_y2" ]; then rbt_miny=$rbt_y1; else rbt_miny=$rbt_y2; fi
  fi
  if [ "$rbt_y0" -gt "$rbt_y1" ]; then
    if [ "$rbt_y0" -gt "$rbt_y2" ]; then rbt_maxy=$rbt_y0; else rbt_maxy=$rbt_y2; fi
  else
    if [ "$rbt_y1" -gt "$rbt_y2" ]; then rbt_maxy=$rbt_y1; else rbt_maxy=$rbt_y2; fi
  fi
  rbt_minx=$((rbt_minx / SSC))
  rbt_maxx=$((rbt_maxx / SSC + 1))
  rbt_miny=$((rbt_miny / SSC))
  rbt_maxy=$((rbt_maxy / SSC + 1))
  if [ "$rbt_maxx" -lt 0 ]; then return; fi
  if [ "$rbt_maxy" -lt 0 ]; then return; fi
  if [ "$rbt_minx" -ge "$RFBW" ]; then return; fi
  if [ "$rbt_miny" -ge "$RFBH" ]; then return; fi
  if [ "$rbt_minx" -lt 0 ]; then rbt_minx=0; fi
  if [ "$rbt_miny" -lt 0 ]; then rbt_miny=0; fi
  rbt_bw=$((RFBW - 1))
  rbt_bh=$((RFBH - 1))
  if [ "$rbt_maxx" -gt "$rbt_bw" ]; then rbt_maxx=$rbt_bw; fi
  if [ "$rbt_maxy" -gt "$rbt_bh" ]; then rbt_maxy=$rbt_bh; fi
  rbt_texd=0
  if [ "$rbc_tex" -ge 0 ]; then
    rbt_tsz=${RBTEX_SZ[$rbc_tex]}
    if [ "$rbt_tsz" -gt 0 ]; then rbt_texd=1; fi
  fi
  rbt_y=$rbt_miny
  while [ "$rbt_y" -le "$rbt_maxy" ]; do
    rbt_cy=$((rbt_y * SSC + SSC / 2))
    rbt_runx=-1
    rbt_runlen=0
    rbt_runhex=""
    rbt_x=$rbt_minx
    while [ "$rbt_x" -le "$rbt_maxx" ]; do
      rbt_cx=$((rbt_x * SSC + SSC / 2))
      rbt_e0=$(( (rbt_x1 - rbt_x0) * (rbt_cy - rbt_y0) - (rbt_y1 - rbt_y0) * (rbt_cx - rbt_x0) ))
      rbt_e1=$(( (rbt_x2 - rbt_x1) * (rbt_cy - rbt_y1) - (rbt_y2 - rbt_y1) * (rbt_cx - rbt_x1) ))
      rbt_e2=$(( (rbt_x0 - rbt_x2) * (rbt_cy - rbt_y2) - (rbt_y0 - rbt_y2) * (rbt_cx - rbt_x2) ))
      rbt_in=1
      if [ "$rbt_e0" -lt 0 ]; then rbt_in=0; fi
      if [ "$rbt_e1" -lt 0 ]; then rbt_in=0; fi
      if [ "$rbt_e2" -lt 0 ]; then rbt_in=0; fi
      if [ "$rbt_in" -eq 1 ]; then
        rbt_p0=$(( (rbt_x1 - rbt_cx) * (rbt_y2 - rbt_cy) ))
        rbt_p1=$(( (rbt_y1 - rbt_cy) * (rbt_x2 - rbt_cx) ))
        rbt_w0=$(( (rbt_p0 - rbt_p1) / rbt_area ))
        rbt_p2=$(( (rbt_x2 - rbt_cx) * (rbt_y0 - rbt_cy) ))
        rbt_p3=$(( (rbt_y2 - rbt_cy) * (rbt_x0 - rbt_cx) ))
        rbt_w1=$(( (rbt_p2 - rbt_p3) / rbt_area ))
        rbt_q0=$((rbt_w0 * rbt_s0 + rbt_w1 * rbt_s1))
        rbt_q1=$((SSC - rbt_w0 - rbt_w1))
        rbt_q2=$((rbt_q1 * rbt_s2))
        rbt_sh=$(( (rbt_q0 + rbt_q2) / SSC ))
        if [ "$rbt_sh" -lt 0 ]; then rbt_sh=0; fi
        if [ "$rbt_sh" -gt 1000 ]; then rbt_sh=1000; fi
        if [ "$rbt_texd" -eq 1 ]; then
          rbt_q0=$((rbt_w0 * rbt_u0 + rbt_w1 * rbt_u1))
          rbt_q1=$((SSC - rbt_w0 - rbt_w1))
          rbt_q2=$((rbt_q1 * rbt_u2))
          rbt_uu=$(( (rbt_q0 + rbt_q2) / SSC ))
          rbt_q0=$((rbt_w0 * rbt_v0 + rbt_w1 * rbt_v1))
          rbt_q1=$((SSC - rbt_w0 - rbt_w1))
          rbt_q2=$((rbt_q1 * rbt_v2))
          rbt_vv=$(( (rbt_q0 + rbt_q2) / SSC ))
          rbp_ftr=$rbc_tr
          rbp_ftg=$rbc_tg
          rbp_ftb=$rbc_tb
          rbp_fsh=$rbt_sh
          rbp_ftx=$rbc_tex
          rbp_fdam=$rbc_dam
          rbp_fx=$rbt_x
          rbp_fy=$rbt_y
          rbp_fu=$rbt_uu
          rbp_fv=$rbt_vv
          rb_frag
          rb_mkhex $rbp_fr $rbp_fg $rbp_fb
          # NOTE: no run-coalescing here (unlike the flat path): the
          # barycentric shade varies per pixel, so adjacent textured
          # pixels essentially never share a colour — the compare was
          # measured as pure overhead. One splice per pixel it is.
          rb_putrun $rbt_y $rbt_x 1 "$rb_pxhex"
        else
          rbt_r=$(( (rbc_tr * rbt_sh + 500) / 1000 ))
          rbt_g=$(( (rbc_tg * rbt_sh + 500) / 1000 ))
          rbt_b=$(( (rbc_tb * rbt_sh + 500) / 1000 ))
          if [ "$rbt_r" -gt 255 ]; then rbt_r=255; fi
          if [ "$rbt_g" -gt 255 ]; then rbt_g=255; fi
          if [ "$rbt_b" -gt 255 ]; then rbt_b=255; fi
          rb_mkhex $rbt_r $rbt_g $rbt_b
          if [ "$rbt_runx" -ge 0 ]; then
            if [ "$rb_pxhex" = "$rbt_runhex" ]; then
              rbt_runlen=$((rbt_runlen + 1))
            else
              rb_putrun $rbt_y $rbt_runx $rbt_runlen "$rbt_runhex"
              rbt_runx=$rbt_x
              rbt_runlen=1
              rbt_runhex=$rb_pxhex
            fi
          else
            rbt_runx=$rbt_x
            rbt_runlen=1
            rbt_runhex=$rb_pxhex
          fi
        fi
      else
        if [ "$rbt_runx" -ge 0 ]; then
          rb_putrun $rbt_y $rbt_runx $rbt_runlen "$rbt_runhex"
          rbt_runx=-1
          rbt_runlen=0
          rbt_runhex=""
        fi
      fi
      rbt_x=$((rbt_x + 1))
    done
    if [ "$rbt_runx" -ge 0 ]; then rb_putrun $rbt_y $rbt_runx $rbt_runlen "$rbt_runhex"; fi
    rbt_y=$((rbt_y + 1))
  done
}

# rb_frag: ONE pixel of the game's dynamic fragment program.
#   in: rbp_ftr/ftg/ftb (tint 0..255), rbp_fsh (shade 0..1000),
#       rbp_ftx (texture slot), rbp_fdam, rbp_fx/fy (device px),
#       rbp_fu/fv (milli-uv)
#   out: rbp_fr/fg/fb
# Order = emit_fragment_shader: texture -> CRT scanline -> crack ->
# corruption -> vignette -> clamp. The scanline/vignette exist only
# when RBF_CRT=1, the streaks only when RBF_CORRUPT=1, and the vignette
# centres on RBF_VW/RBF_VH (the --view bake).
rb_frag() {
  rbx_s=$rbp_ftx
  rbx_uu=$rbp_fu
  rbx_vv=$rbp_fv
  rb_tex_sample $rbx_s $rbx_uu $rbx_vv
  rbp_tr=$((rbp_ftr * rbp_fsh / 1000))
  rbp_tg=$((rbp_ftg * rbp_fsh / 1000))
  rbp_tb=$((rbp_ftb * rbp_fsh / 1000))
  if [ "$rbp_tr" -lt 0 ]; then rbp_tr=0; fi
  if [ "$rbp_tr" -gt 255 ]; then rbp_tr=255; fi
  if [ "$rbp_tg" -lt 0 ]; then rbp_tg=0; fi
  if [ "$rbp_tg" -gt 255 ]; then rbp_tg=255; fi
  if [ "$rbp_tb" -lt 0 ]; then rbp_tb=0; fi
  if [ "$rbp_tb" -gt 255 ]; then rbp_tb=255; fi
  rbp_fr=$((rbp_tr * rbx_r / 128))
  rbp_fg=$((rbp_tg * rbx_g / 128))
  rbp_fb=$((rbp_tb * rbx_b / 128))
  if [ "$RBF_CRT" -eq 1 ]; then
    rbp_scan=$((rbp_fy % 6))
    if [ "$rbp_scan" -eq 0 ]; then
      rbp_fr=$((rbp_fr * 90 / 100))
      rbp_fg=$((rbp_fg * 90 / 100))
      rbp_fb=$((rbp_fb * 90 / 100))
    fi
  fi
  if [ "$rbp_fdam" -gt 0 ]; then
    rbp_csz=${RBTEX_SZ[9]}
    if [ "$rbp_csz" -gt 0 ]; then
      rbx_s=9
      rbx_uu=$rbp_fu
      rbx_vv=$rbp_fv
      rb_tex_sample $rbx_s $rbx_uu $rbx_vv
      rbp_mix=$((rbp_fdam * rbx_a / 4))
      if [ "$rbp_mix" -gt 127 ]; then rbp_mix=127; fi
      rbp_fr=$((rbp_fr - (rbp_fr - rbx_r) * rbp_mix / 128))
      rbp_fg=$((rbp_fg - (rbp_fg - rbx_g) * rbp_mix / 128))
      rbp_fb=$((rbp_fb - (rbp_fb - rbx_b) * rbp_mix / 128))
    fi
  fi
  if [ "$RBF_CORRUPT" -eq 1 ]; then
    rbp_hash=$((rbp_fx * 7 + rbp_fy * 13))
    rbp_cor=$((rbp_hash % 97))
    if [ "$rbp_cor" -eq 0 ]; then
      rbp_fr=255
      rbp_fg=$((rbp_fg / 2))
      rbp_fb=$((rbp_fb / 2))
    fi
  fi
  if [ "$RBF_CRT" -eq 1 ]; then
    rbp_hw=$((RBF_VW / 2))
    rbp_hh=$((RBF_VH / 2))
    rbp_vx=$((rbp_fx - rbp_hw))
    rbp_vy=$((rbp_fy - rbp_hh))
    if [ "$rbp_vx" -lt 0 ]; then rbp_vx=$((0 - rbp_vx)); fi
    if [ "$rbp_vy" -lt 0 ]; then rbp_vy=$((0 - rbp_vy)); fi
    rbp_edge=$((rbp_vx + rbp_vy))
    if [ "$rbp_edge" -gt 450 ]; then
      rbp_dim=$((rbp_edge - 450))
      if [ "$rbp_dim" -gt 30 ]; then rbp_dim=30; fi
      rbp_fr=$((rbp_fr - rbp_fr * rbp_dim / 256))
      rbp_fg=$((rbp_fg - rbp_fg * rbp_dim / 256))
      rbp_fb=$((rbp_fb - rbp_fb * rbp_dim / 256))
    fi
  fi
  if [ "$rbp_fr" -lt 0 ]; then rbp_fr=0; fi
  if [ "$rbp_fg" -lt 0 ]; then rbp_fg=0; fi
  if [ "$rbp_fb" -lt 0 ]; then rbp_fb=0; fi
  if [ "$rbp_fr" -gt 255 ]; then rbp_fr=255; fi
  if [ "$rbp_fg" -gt 255 ]; then rbp_fg=255; fi
  if [ "$rbp_fb" -gt 255 ]; then rbp_fb=255; fi
}

# rb_trig_selftest: trig errors (VSC units) at cardinal angles.
rb_trig_selftest() {
  rbt_deg=0
  while [ "$rbt_deg" -lt 360 ]; do
    rb_sincos
    echo "$rbt_deg $rbt_cos $rbt_sin"
    if [ "$rbt_deg" -eq 0 ]; then rbt_deg=30; else
      if [ "$rbt_deg" -eq 30 ]; then rbt_deg=45; else
        if [ "$rbt_deg" -eq 45 ]; then rbt_deg=90; else
          if [ "$rbt_deg" -eq 90 ]; then rbt_deg=135; else
            if [ "$rbt_deg" -eq 135 ]; then rbt_deg=180; else
              if [ "$rbt_deg" -eq 180 ]; then rbt_deg=270; else
                if [ "$rbt_deg" -eq 270 ]; then rbt_deg=359; else rbt_deg=360; fi
              fi
            fi
          fi
        fi
      fi
    fi
  done
}

# rb_h2d HH: hex pair (00..ff) -> decimal. A 256-arm case: the only
# branch the pipeline lowers for a string->int map (no assoc arrays).
rb_h2d() {
  case $1 in
    00) rbov_d=0 ;;
    01) rbov_d=1 ;;
    02) rbov_d=2 ;;
    03) rbov_d=3 ;;
    04) rbov_d=4 ;;
    05) rbov_d=5 ;;
    06) rbov_d=6 ;;
    07) rbov_d=7 ;;
    08) rbov_d=8 ;;
    09) rbov_d=9 ;;
    0a) rbov_d=10 ;;
    0b) rbov_d=11 ;;
    0c) rbov_d=12 ;;
    0d) rbov_d=13 ;;
    0e) rbov_d=14 ;;
    0f) rbov_d=15 ;;
    10) rbov_d=16 ;;
    11) rbov_d=17 ;;
    12) rbov_d=18 ;;
    13) rbov_d=19 ;;
    14) rbov_d=20 ;;
    15) rbov_d=21 ;;
    16) rbov_d=22 ;;
    17) rbov_d=23 ;;
    18) rbov_d=24 ;;
    19) rbov_d=25 ;;
    1a) rbov_d=26 ;;
    1b) rbov_d=27 ;;
    1c) rbov_d=28 ;;
    1d) rbov_d=29 ;;
    1e) rbov_d=30 ;;
    1f) rbov_d=31 ;;
    20) rbov_d=32 ;;
    21) rbov_d=33 ;;
    22) rbov_d=34 ;;
    23) rbov_d=35 ;;
    24) rbov_d=36 ;;
    25) rbov_d=37 ;;
    26) rbov_d=38 ;;
    27) rbov_d=39 ;;
    28) rbov_d=40 ;;
    29) rbov_d=41 ;;
    2a) rbov_d=42 ;;
    2b) rbov_d=43 ;;
    2c) rbov_d=44 ;;
    2d) rbov_d=45 ;;
    2e) rbov_d=46 ;;
    2f) rbov_d=47 ;;
    30) rbov_d=48 ;;
    31) rbov_d=49 ;;
    32) rbov_d=50 ;;
    33) rbov_d=51 ;;
    34) rbov_d=52 ;;
    35) rbov_d=53 ;;
    36) rbov_d=54 ;;
    37) rbov_d=55 ;;
    38) rbov_d=56 ;;
    39) rbov_d=57 ;;
    3a) rbov_d=58 ;;
    3b) rbov_d=59 ;;
    3c) rbov_d=60 ;;
    3d) rbov_d=61 ;;
    3e) rbov_d=62 ;;
    3f) rbov_d=63 ;;
    40) rbov_d=64 ;;
    41) rbov_d=65 ;;
    42) rbov_d=66 ;;
    43) rbov_d=67 ;;
    44) rbov_d=68 ;;
    45) rbov_d=69 ;;
    46) rbov_d=70 ;;
    47) rbov_d=71 ;;
    48) rbov_d=72 ;;
    49) rbov_d=73 ;;
    4a) rbov_d=74 ;;
    4b) rbov_d=75 ;;
    4c) rbov_d=76 ;;
    4d) rbov_d=77 ;;
    4e) rbov_d=78 ;;
    4f) rbov_d=79 ;;
    50) rbov_d=80 ;;
    51) rbov_d=81 ;;
    52) rbov_d=82 ;;
    53) rbov_d=83 ;;
    54) rbov_d=84 ;;
    55) rbov_d=85 ;;
    56) rbov_d=86 ;;
    57) rbov_d=87 ;;
    58) rbov_d=88 ;;
    59) rbov_d=89 ;;
    5a) rbov_d=90 ;;
    5b) rbov_d=91 ;;
    5c) rbov_d=92 ;;
    5d) rbov_d=93 ;;
    5e) rbov_d=94 ;;
    5f) rbov_d=95 ;;
    60) rbov_d=96 ;;
    61) rbov_d=97 ;;
    62) rbov_d=98 ;;
    63) rbov_d=99 ;;
    64) rbov_d=100 ;;
    65) rbov_d=101 ;;
    66) rbov_d=102 ;;
    67) rbov_d=103 ;;
    68) rbov_d=104 ;;
    69) rbov_d=105 ;;
    6a) rbov_d=106 ;;
    6b) rbov_d=107 ;;
    6c) rbov_d=108 ;;
    6d) rbov_d=109 ;;
    6e) rbov_d=110 ;;
    6f) rbov_d=111 ;;
    70) rbov_d=112 ;;
    71) rbov_d=113 ;;
    72) rbov_d=114 ;;
    73) rbov_d=115 ;;
    74) rbov_d=116 ;;
    75) rbov_d=117 ;;
    76) rbov_d=118 ;;
    77) rbov_d=119 ;;
    78) rbov_d=120 ;;
    79) rbov_d=121 ;;
    7a) rbov_d=122 ;;
    7b) rbov_d=123 ;;
    7c) rbov_d=124 ;;
    7d) rbov_d=125 ;;
    7e) rbov_d=126 ;;
    7f) rbov_d=127 ;;
    80) rbov_d=128 ;;
    81) rbov_d=129 ;;
    82) rbov_d=130 ;;
    83) rbov_d=131 ;;
    84) rbov_d=132 ;;
    85) rbov_d=133 ;;
    86) rbov_d=134 ;;
    87) rbov_d=135 ;;
    88) rbov_d=136 ;;
    89) rbov_d=137 ;;
    8a) rbov_d=138 ;;
    8b) rbov_d=139 ;;
    8c) rbov_d=140 ;;
    8d) rbov_d=141 ;;
    8e) rbov_d=142 ;;
    8f) rbov_d=143 ;;
    90) rbov_d=144 ;;
    91) rbov_d=145 ;;
    92) rbov_d=146 ;;
    93) rbov_d=147 ;;
    94) rbov_d=148 ;;
    95) rbov_d=149 ;;
    96) rbov_d=150 ;;
    97) rbov_d=151 ;;
    98) rbov_d=152 ;;
    99) rbov_d=153 ;;
    9a) rbov_d=154 ;;
    9b) rbov_d=155 ;;
    9c) rbov_d=156 ;;
    9d) rbov_d=157 ;;
    9e) rbov_d=158 ;;
    9f) rbov_d=159 ;;
    a0) rbov_d=160 ;;
    a1) rbov_d=161 ;;
    a2) rbov_d=162 ;;
    a3) rbov_d=163 ;;
    a4) rbov_d=164 ;;
    a5) rbov_d=165 ;;
    a6) rbov_d=166 ;;
    a7) rbov_d=167 ;;
    a8) rbov_d=168 ;;
    a9) rbov_d=169 ;;
    aa) rbov_d=170 ;;
    ab) rbov_d=171 ;;
    ac) rbov_d=172 ;;
    ad) rbov_d=173 ;;
    ae) rbov_d=174 ;;
    af) rbov_d=175 ;;
    b0) rbov_d=176 ;;
    b1) rbov_d=177 ;;
    b2) rbov_d=178 ;;
    b3) rbov_d=179 ;;
    b4) rbov_d=180 ;;
    b5) rbov_d=181 ;;
    b6) rbov_d=182 ;;
    b7) rbov_d=183 ;;
    b8) rbov_d=184 ;;
    b9) rbov_d=185 ;;
    ba) rbov_d=186 ;;
    bb) rbov_d=187 ;;
    bc) rbov_d=188 ;;
    bd) rbov_d=189 ;;
    be) rbov_d=190 ;;
    bf) rbov_d=191 ;;
    c0) rbov_d=192 ;;
    c1) rbov_d=193 ;;
    c2) rbov_d=194 ;;
    c3) rbov_d=195 ;;
    c4) rbov_d=196 ;;
    c5) rbov_d=197 ;;
    c6) rbov_d=198 ;;
    c7) rbov_d=199 ;;
    c8) rbov_d=200 ;;
    c9) rbov_d=201 ;;
    ca) rbov_d=202 ;;
    cb) rbov_d=203 ;;
    cc) rbov_d=204 ;;
    cd) rbov_d=205 ;;
    ce) rbov_d=206 ;;
    cf) rbov_d=207 ;;
    d0) rbov_d=208 ;;
    d1) rbov_d=209 ;;
    d2) rbov_d=210 ;;
    d3) rbov_d=211 ;;
    d4) rbov_d=212 ;;
    d5) rbov_d=213 ;;
    d6) rbov_d=214 ;;
    d7) rbov_d=215 ;;
    d8) rbov_d=216 ;;
    d9) rbov_d=217 ;;
    da) rbov_d=218 ;;
    db) rbov_d=219 ;;
    dc) rbov_d=220 ;;
    dd) rbov_d=221 ;;
    de) rbov_d=222 ;;
    df) rbov_d=223 ;;
    e0) rbov_d=224 ;;
    e1) rbov_d=225 ;;
    e2) rbov_d=226 ;;
    e3) rbov_d=227 ;;
    e4) rbov_d=228 ;;
    e5) rbov_d=229 ;;
    e6) rbov_d=230 ;;
    e7) rbov_d=231 ;;
    e8) rbov_d=232 ;;
    e9) rbov_d=233 ;;
    ea) rbov_d=234 ;;
    eb) rbov_d=235 ;;
    ec) rbov_d=236 ;;
    ed) rbov_d=237 ;;
    ee) rbov_d=238 ;;
    ef) rbov_d=239 ;;
    f0) rbov_d=240 ;;
    f1) rbov_d=241 ;;
    f2) rbov_d=242 ;;
    f3) rbov_d=243 ;;
    f4) rbov_d=244 ;;
    f5) rbov_d=245 ;;
    f6) rbov_d=246 ;;
    f7) rbov_d=247 ;;
    f8) rbov_d=248 ;;
    f9) rbov_d=249 ;;
    fa) rbov_d=250 ;;
    fb) rbov_d=251 ;;
    fc) rbov_d=252 ;;
    fd) rbov_d=253 ;;
    fe) rbov_d=254 ;;
    ff) rbov_d=255 ;;
    *) rbov_d=0 ;;
  esac
}

# ── 2D overlay (the HUD, drawn as pixels, not records) ──────────
# The game's HUD used to be a mini-language (R/E/I/T + bare quads)
# interpreted by the C device. Splitting a multi-line payload needs
# newline patterns, which silently no-op in this pipeline (measured:
# a compiled line-splitter prints nothing) — so the producers call
# these DIRECTLY (immediate mode, like rb_cube):
#   rb_o_rect CX CY W H R G B [A]          axis-aligned NDC fill
#   rb_o_rect_rot CX CY W H DEG R G B [A]  rotated NDC fill
#   rb_o_image CX CY W H SLOT              unrotated texture blit (I)
# Erase records (E) are NO-OPs, loudly: every frame starts from a fresh
# rb_clear + world redraw, so there is no persistent layer whose stale
# cells an erase would clear — the call sites simply stop emitting.
# T records (radar triangle) are DROPPED + COUNTED (RB_OV_TDROP): the
# C device parses at most 5 fields but requires 9, so it never drew
# them either — same pixels, honestly logged.
# NDC (-1..1, +y up) -> pixels uses the C's truncation (px where the
# double lands, within float epsilon: documented ±1px vs the C device;
# the contract that matters is real-bash identity, which holds by
# construction — same code, same integers). Coverage tests pixel
# INTEGER coords (the C tests (int)(x+0.5), i.e. x itself).
# Arithmetic discipline: verified shapes only — flat chains and one
# group level (`(a*b+c*d)/N`), never a leading `(0-X)*Y` (measured:
# goes unsigned) and never a wrapper around groups (measured: empty
# shellout). Split anything else into temps first.
RB_OV_TDROP=0
RB_OV_TLOGGED=0

# rb_o_col RDEC GDEC BDEC [ADEC] (0..1 decimals): -> bytes
# rbov_fr/fg/fb/fa. Matches the C's (int)(v*255+0.5).
rb_o_col() {
  rbv_s=$1
  rb_vdec
  rbov_fr=$(( (rbv_v * 255 + 500000) / 1000000 ))
  rbv_s=$2
  rb_vdec
  rbov_fg=$(( (rbv_v * 255 + 500000) / 1000000 ))
  rbv_s=$3
  rb_vdec
  rbov_fb=$(( (rbv_v * 255 + 500000) / 1000000 ))
  rbov_fa=255
  if [ "$4" != "" ]; then
    rbv_s=$4
    rb_vdec
    rbov_fa=$(( (rbv_v * 255 + 500000) / 1000000 ))
  fi
  if [ "$rbov_fr" -gt 255 ]; then rbov_fr=255; fi
  if [ "$rbov_fg" -gt 255 ]; then rbov_fg=255; fi
  if [ "$rbov_fb" -gt 255 ]; then rbov_fb=255; fi
  if [ "$rbov_fa" -gt 255 ]; then rbov_fa=255; fi
  if [ "$rbov_fr" -lt 0 ]; then rbov_fr=0; fi
  if [ "$rbov_fg" -lt 0 ]; then rbov_fg=0; fi
  if [ "$rbov_fb" -lt 0 ]; then rbov_fb=0; fi
  if [ "$rbov_fa" -lt 0 ]; then rbov_fa=0; fi
}

# rb_o_ndc CXDEC CYDEC: NDC -> device px (rbov_px/py, ints).
rb_o_ndc() {
  rbv_s=$1
  rb_vdec
  rbov_cx=$rbv_v
  rbv_s=$2
  rb_vdec
  rbov_cy=$rbv_v
  rbov_hx=$((RFBW / 2 * 2000000))
  rbov_tx=$((rbov_cx * RFBW))
  rbov_px=$(( (rbov_tx + rbov_hx) / 2000000 ))
  rbov_hy=$((RFBH / 2 * 2000000))
  rbov_ty=$((rbov_cy * RFBH))
  rbov_py=$(( (rbov_hy - rbov_ty) / 2000000 ))
}

# rb_o_wh WDEC HDEC: NDC fractions -> half-extents in MILLI-px
# (rbov_hwm/hhm). w/h are FULL extents (the radar is 16 cells at 0.040
# = 0.64 of the width — measured against the game, not guessed).
rb_o_wh() {
  rbv_s=$1
  rb_vdec
  rbov_hwm=$((rbv_v * RFBW / 2000))
  rbv_s=$2
  rb_vdec
  rbov_hhm=$((rbv_v * RFBH / 2000))
}

# rb_o_corners DEGDEC: the 4 rotated corners about (rbov_px,rbov_py)
# with half-extents (rbov_hwm/hhm milli) -> rbov_x0..y3 (ints, rounded
# half-away-from-zero like the C). Vertex order matches the C
# ((-1,-1),(1,-1),(1,1),(-1,1)) so the coverage winding agrees.
rb_o_corners() {
  rbv_s=$1
  rb_vdec
  rbt_deg=$((rbv_v / 1000000))
  rb_sincos
  rbov_cc=$rbt_cos
  rbov_cs=$rbt_sin
  rbov_vi=0
  while [ "$rbov_vi" -lt 4 ]; do
    if [ "$rbov_vi" -eq 0 ]; then rbov_sx=-1; rbov_sy=-1; fi
    if [ "$rbov_vi" -eq 1 ]; then rbov_sx=1; rbov_sy=-1; fi
    if [ "$rbov_vi" -eq 2 ]; then rbov_sx=1; rbov_sy=1; fi
    if [ "$rbov_vi" -eq 3 ]; then rbov_sx=-1; rbov_sy=1; fi
    rbov_dxm=$((rbov_sx * rbov_hwm))
    rbov_dym=$((rbov_sy * rbov_hhm))
    rbov_tm=$((rbov_dxm * rbov_cc - rbov_dym * rbov_cs))
    rbov_exm=$((rbov_px * 1000 + rbov_tm / VSC))
    rbov_tm=$((rbov_dxm * rbov_cs + rbov_dym * rbov_cc))
    rbov_eym=$((rbov_py * 1000 + rbov_tm / VSC))
    if [ "$rbov_exm" -lt 0 ]; then rbov_ex=$(( (rbov_exm - 500) / 1000 )); else rbov_ex=$(( (rbov_exm + 500) / 1000 )); fi
    if [ "$rbov_eym" -lt 0 ]; then rbov_ey=$(( (rbov_eym - 500) / 1000 )); else rbov_ey=$(( (rbov_eym + 500) / 1000 )); fi
    if [ "$rbov_vi" -eq 0 ]; then rbov_x0=$rbov_ex; rbov_y0=$rbov_ey; fi
    if [ "$rbov_vi" -eq 1 ]; then rbov_x1=$rbov_ex; rbov_y1=$rbov_ey; fi
    if [ "$rbov_vi" -eq 2 ]; then rbov_x2=$rbov_ex; rbov_y2=$rbov_ey; fi
    if [ "$rbov_vi" -eq 3 ]; then rbov_x3=$rbov_ex; rbov_y3=$rbov_ey; fi
    rbov_vi=$((rbov_vi + 1))
  done
}

# rb_o_cover AX AY BX BY PX PY: half-plane edge test (1 covered).
# Same t1 shape as the 3D rasterizer's edge functions.
rb_o_cover() {
  rbov_ax=$1
  rbov_ay=$2
  rbov_bx=$3
  rbov_by=$4
  rbov_cx=$5
  rbov_cy=$6
  rbov_e1=$(( (rbov_bx - rbov_ax) * (rbov_cy - rbov_ay) ))
  rbov_e2=$(( (rbov_by - rbov_ay) * (rbov_cx - rbov_ax) ))
  rbov_e=$((rbov_e1 - rbov_e2))
  if [ "$rbov_e" -ge 0 ]; then rbov_hit=1; else rbov_hit=0; fi
}

# rb_o_fillquad: paint corners (rbov_x0..y3) with (rbov_fr/fg/fb/fa).
# Opaque (255) goes as whole runs; translucent blends per pixel
# against the live row (source-over, the C's formula exactly).
rb_o_fillquad() {
  if [ "$rbov_x0" -lt "$rbov_x1" ]; then
    if [ "$rbov_x0" -lt "$rbov_x2" ]; then
      if [ "$rbov_x0" -lt "$rbov_x3" ]; then rbov_minx=$rbov_x0; else rbov_minx=$rbov_x3; fi
    else
      if [ "$rbov_x2" -lt "$rbov_x3" ]; then rbov_minx=$rbov_x2; else rbov_minx=$rbov_x3; fi
    fi
  else
    if [ "$rbov_x1" -lt "$rbov_x2" ]; then
      if [ "$rbov_x1" -lt "$rbov_x3" ]; then rbov_minx=$rbov_x1; else rbov_minx=$rbov_x3; fi
    else
      if [ "$rbov_x2" -lt "$rbov_x3" ]; then rbov_minx=$rbov_x2; else rbov_minx=$rbov_x3; fi
    fi
  fi
  if [ "$rbov_x0" -gt "$rbov_x1" ]; then
    if [ "$rbov_x0" -gt "$rbov_x2" ]; then
      if [ "$rbov_x0" -gt "$rbov_x3" ]; then rbov_maxx=$rbov_x0; else rbov_maxx=$rbov_x3; fi
    else
      if [ "$rbov_x2" -gt "$rbov_x3" ]; then rbov_maxx=$rbov_x2; else rbov_maxx=$rbov_x3; fi
    fi
  else
    if [ "$rbov_x1" -gt "$rbov_x2" ]; then
      if [ "$rbov_x1" -gt "$rbov_x3" ]; then rbov_maxx=$rbov_x1; else rbov_maxx=$rbov_x3; fi
    else
      if [ "$rbov_x2" -gt "$rbov_x3" ]; then rbov_maxx=$rbov_x2; else rbov_maxx=$rbov_x3; fi
    fi
  fi
  if [ "$rbov_y0" -lt "$rbov_y1" ]; then
    if [ "$rbov_y0" -lt "$rbov_y2" ]; then
      if [ "$rbov_y0" -lt "$rbov_y3" ]; then rbov_miny=$rbov_y0; else rbov_miny=$rbov_y3; fi
    else
      if [ "$rbov_y2" -lt "$rbov_y3" ]; then rbov_miny=$rbov_y2; else rbov_miny=$rbov_y3; fi
    fi
  else
    if [ "$rbov_y1" -lt "$rbov_y2" ]; then
      if [ "$rbov_y1" -lt "$rbov_y3" ]; then rbov_miny=$rbov_y1; else rbov_miny=$rbov_y3; fi
    else
      if [ "$rbov_y2" -lt "$rbov_y3" ]; then rbov_miny=$rbov_y2; else rbov_miny=$rbov_y3; fi
    fi
  fi
  if [ "$rbov_y0" -gt "$rbov_y1" ]; then
    if [ "$rbov_y0" -gt "$rbov_y2" ]; then
      if [ "$rbov_y0" -gt "$rbov_y3" ]; then rbov_maxy=$rbov_y0; else rbov_maxy=$rbov_y3; fi
    else
      if [ "$rbov_y2" -gt "$rbov_y3" ]; then rbov_maxy=$rbov_y2; else rbov_maxy=$rbov_y3; fi
    fi
  else
    if [ "$rbov_y1" -gt "$rbov_y2" ]; then
      if [ "$rbov_y1" -gt "$rbov_y3" ]; then rbov_maxy=$rbov_y1; else rbov_maxy=$rbov_y3; fi
    else
      if [ "$rbov_y2" -gt "$rbov_y3" ]; then rbov_maxy=$rbov_y2; else rbov_maxy=$rbov_y3; fi
    fi
  fi
  if [ "$rbov_maxx" -lt 0 ]; then return; fi
  if [ "$rbov_maxy" -lt 0 ]; then return; fi
  if [ "$rbov_minx" -ge "$RFBW" ]; then return; fi
  if [ "$rbov_miny" -ge "$RFBH" ]; then return; fi
  if [ "$rbov_minx" -lt 0 ]; then rbov_minx=0; fi
  if [ "$rbov_miny" -lt 0 ]; then rbov_miny=0; fi
  rbov_bw=$((RFBW - 1))
  rbov_bh=$((RFBH - 1))
  if [ "$rbov_maxx" -gt "$rbov_bw" ]; then rbov_maxx=$rbov_bw; fi
  if [ "$rbov_maxy" -gt "$rbov_bh" ]; then rbov_maxy=$rbov_bh; fi
  if [ "$rbov_fa" -le 0 ]; then return; fi
  rb_mkhex $rbov_fr $rbov_fg $rbov_fb
  rbov_hex=$rb_pxhex
  rbov_y=$rbov_miny
  while [ "$rbov_y" -le "$rbov_maxy" ]; do
    rbov_runx=-1
    rbov_runlen=0
    rbov_x=$rbov_minx
    while [ "$rbov_x" -le "$rbov_maxx" ]; do
      rb_o_cover $rbov_x0 $rbov_y0 $rbov_x1 $rbov_y1 $rbov_x $rbov_y
      rbov_c0=$rbov_hit
      rb_o_cover $rbov_x1 $rbov_y1 $rbov_x2 $rbov_y2 $rbov_x $rbov_y
      rbov_c1=$rbov_hit
      rb_o_cover $rbov_x2 $rbov_y2 $rbov_x3 $rbov_y3 $rbov_x $rbov_y
      rbov_c2=$rbov_hit
      rb_o_cover $rbov_x3 $rbov_y3 $rbov_x0 $rbov_y0 $rbov_x $rbov_y
      rbov_c3=$rbov_hit
      rbov_in=1
      if [ "$rbov_c0" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c1" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c2" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c3" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_in" -eq 1 ]; then
        if [ "$rbov_fa" -ge 255 ]; then
          if [ "$rbov_runx" -ge 0 ]; then
            rbov_runlen=$((rbov_runlen + 1))
          else
            rbov_runx=$rbov_x
            rbov_runlen=1
          fi
        else
          if [ "$rbov_runx" -ge 0 ]; then rb_putrun $rbov_y $rbov_runx $rbov_runlen "$rbov_hex"; rbov_runx=-1; rbov_runlen=0; fi
          rb_o_blend $rbov_x $rbov_y
        fi
      else
        if [ "$rbov_runx" -ge 0 ]; then rb_putrun $rbov_y $rbov_runx $rbov_runlen "$rbov_hex"; rbov_runx=-1; rbov_runlen=0; fi
      fi
      rbov_x=$((rbov_x + 1))
    done
    if [ "$rbov_runx" -ge 0 ]; then rb_putrun $rbov_y $rbov_runx $rbov_runlen "$rbov_hex"; fi
    rbov_y=$((rbov_y + 1))
  done
}

# rb_o_blend X Y: blend (rbov_fr/fg/fb/fa) over the live pixel.
# out = (src*a + dst*(255-a)) / 255 — the C's source-over exactly.
rb_o_blend() {
  rbov_bx=$1
  rbov_by=$2
  rbov_brow=${RFB_ROWS[$rbov_by]}
  rbov_bo=$((rbov_bx * 8))
  rbov_bbh=${rbov_brow:$rbov_bo:2}
  rbov_bbl=$((rbov_bo + 2))
  rbov_bgh=${rbov_brow:$rbov_bbl:2}
  rbov_brl=$((rbov_bo + 4))
  rbov_brh=${rbov_brow:$rbov_brl:2}
  rb_h2d $rbov_bbh
  rbov_db=$rbov_d
  rb_h2d $rbov_bgh
  rbov_dg=$rbov_d
  rb_h2d $rbov_brh
  rbov_dr=$rbov_d
  rbov_ia=$((255 - rbov_fa))
  rbov_or=$(( (rbov_fr * rbov_fa + rbov_dr * rbov_ia) / 255 ))
  rbov_og=$(( (rbov_fg * rbov_fa + rbov_dg * rbov_ia) / 255 ))
  rbov_ob=$(( (rbov_fb * rbov_fa + rbov_db * rbov_ia) / 255 ))
  rb_mkhex $rbov_or $rbov_og $rbov_ob
  rb_putrun $rbov_bx $rbov_by 1 "$rb_pxhex"
}

# rb_o_rect CX CY W H R G B [A] — the bare quad + erase target...
# (erase callers were removed: full redraw needs no erases).
rb_o_rect() {
  rbov_qcx=$1
  rbov_qcy=$2
  rbov_qw=$3
  rbov_qh=$4
  rbov_qr=$5
  rbov_qg=$6
  rbov_qb=$7
  rbov_qa=$8
  rb_o_col $rbov_qr $rbov_qg $rbov_qb $rbov_qa
  rb_o_ndc $rbov_qcx $rbov_qcy
  rb_o_wh $rbov_qw $rbov_qh
  rb_o_corners 0
  rb_o_fillquad
}

# rb_o_rect_rot CX CY W H DEG R G B [A] — the R record (gun, flash).
rb_o_rect_rot() {
  rbov_qcx=$1
  rbov_qcy=$2
  rbov_qw=$3
  rbov_qh=$4
  rbov_qd=$5
  rbov_qr=$6
  rbov_qg=$7
  rbov_qb=$8
  rbov_qa=$9
  rb_o_col $rbov_qr $rbov_qg $rbov_qb $rbov_qa
  rb_o_ndc $rbov_qcx $rbov_qcy
  rb_o_wh $rbov_qw $rbov_qh
  rb_o_corners $rbov_qd
  rb_o_fillquad
}

# rb_o_image CX CY W H SLOT — the I record: unrotated texture blit
# with the texel's own alpha (0 = skip, 255 = opaque, else blend).
rb_o_image() {
  rbov_qcx=$1
  rbov_qcy=$2
  rbov_qw=$3
  rbov_qh=$4
  rbov_ts=$5
  rbov_tsz=${RBTEX_SZ[$rbov_ts]}
  if [ "$rbov_tsz" -le 0 ]; then return; fi
  rb_o_ndc $rbov_qcx $rbov_qcy
  rb_o_wh $rbov_qw $rbov_qh
  rb_o_corners 0
  rbov_denx=$((rbov_x2 - rbov_x0))
  rbov_deny=$((rbov_y2 - rbov_y1))
  if [ "$rbov_denx" -eq 0 ]; then rbov_denx=1; fi
  if [ "$rbov_deny" -eq 0 ]; then rbov_deny=1; fi
  if [ "$rbov_x0" -lt "$rbov_x2" ]; then rbov_minx=$rbov_x0; else rbov_minx=$rbov_x2; fi
  if [ "$rbov_y0" -lt "$rbov_y2" ]; then rbov_miny=$rbov_y0; else rbov_miny=$rbov_y2; fi
  if [ "$rbov_x0" -gt "$rbov_x2" ]; then rbov_maxx=$rbov_x0; else rbov_maxx=$rbov_x2; fi
  if [ "$rbov_y0" -gt "$rbov_y2" ]; then rbov_maxy=$rbov_y0; else rbov_maxy=$rbov_y2; fi
  if [ "$rbov_maxx" -lt 0 ]; then return; fi
  if [ "$rbov_maxy" -lt 0 ]; then return; fi
  if [ "$rbov_minx" -ge "$RFBW" ]; then return; fi
  if [ "$rbov_miny" -ge "$RFBH" ]; then return; fi
  if [ "$rbov_minx" -lt 0 ]; then rbov_minx=0; fi
  if [ "$rbov_miny" -lt 0 ]; then rbov_miny=0; fi
  rbov_bw=$((RFBW - 1))
  rbov_bh=$((RFBH - 1))
  if [ "$rbov_maxx" -gt "$rbov_bw" ]; then rbov_maxx=$rbov_bw; fi
  if [ "$rbov_maxy" -gt "$rbov_bh" ]; then rbov_maxy=$rbov_bh; fi
  rbov_y=$rbov_miny
  while [ "$rbov_y" -le "$rbov_maxy" ]; do
    rbov_x=$rbov_minx
    while [ "$rbov_x" -le "$rbov_maxx" ]; do
      rb_o_cover $rbov_x0 $rbov_y0 $rbov_x1 $rbov_y1 $rbov_x $rbov_y
      rbov_c0=$rbov_hit
      rb_o_cover $rbov_x1 $rbov_y1 $rbov_x2 $rbov_y2 $rbov_x $rbov_y
      rbov_c1=$rbov_hit
      rb_o_cover $rbov_x2 $rbov_y2 $rbov_x3 $rbov_y3 $rbov_x $rbov_y
      rbov_c2=$rbov_hit
      rb_o_cover $rbov_x3 $rbov_y3 $rbov_x0 $rbov_y0 $rbov_x $rbov_y
      rbov_c3=$rbov_hit
      rbov_in=1
      if [ "$rbov_c0" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c1" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c2" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_c3" -eq 0 ]; then rbov_in=0; fi
      if [ "$rbov_in" -eq 1 ]; then
        rbov_tu=$(( (rbov_x - rbov_x0) * rbov_tsz / rbov_denx ))
        rbov_tv=$(( (rbov_y - rbov_y0) * rbov_tsz / rbov_deny ))
        if [ "$rbov_tu" -lt 0 ]; then rbov_tu=0; fi
        if [ "$rbov_tv" -lt 0 ]; then rbov_tv=0; fi
        rbov_ts1=$((rbov_tsz - 1))
        if [ "$rbov_tu" -gt "$rbov_ts1" ]; then rbov_tu=$rbov_ts1; fi
        if [ "$rbov_tv" -gt "$rbov_ts1" ]; then rbov_tv=$rbov_ts1; fi
        rbx_s=$rbov_ts
        rbx_uu=$((rbov_tu * 1000 / rbov_tsz))
        rbx_vv=$((rbov_tv * 1000 / rbov_tsz))
        rb_tex_sample $rbx_s $rbx_uu $rbx_vv
        if [ "$rbx_a" -eq 0 ]; then
          rbov_skip=1
        else
          if [ "$rbx_a" -ge 255 ]; then
            rb_mkhex $rbx_r $rbx_g $rbx_b
            rb_putrun $rbov_x $rbov_y 1 "$rb_pxhex"
          else
            rbov_fr=$rbx_r
            rbov_fg=$rbx_g
            rbov_fb=$rbx_b
            rbov_fa=$rbx_a
            rb_o_blend $rbov_x $rbov_y
          fi
        fi
      fi
      rbov_x=$((rbov_x + 1))
    done
    rbov_y=$((rbov_y + 1))
  done
}

# rb_o_tdrop: the T record (radar triangle) — dropped like the C
# device drops it (parses 5, needs 9), counted here instead of
# silently. First 5 land in the audit log for the minimap milestone.
rb_o_tdrop() {
  RB_OV_TDROP=$((RB_OV_TDROP + 1))
  if [ "$RB_OV_TLOGGED" -lt 5 ]; then
    echo "T-drop $RB_OV_TDROP" >> /tmp/rb-overlay.log
    RB_OV_TLOGGED=$((RB_OV_TLOGGED + 1))
  fi
}

