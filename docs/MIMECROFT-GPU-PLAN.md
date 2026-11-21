# MIMEcroft GPU transposition — name-free plan

Status: **proposal, not started** (2026-11-21). Tracked here so it can be
approved, split into missions, and checked against its own gates. It
supersedes the sketch in `docs/BASH_VULKAN.md` §4.4 for the *graphics*
leg (that document remains the authority on the compute leg).

## 1. Goal

Make `bash-o4/MIMEcroft_fb.sh` draw through native GPU operations —
one render pass with hardware rasterisation, a real fragment shader, an
atlas, and a readback/present step — instead of rebuilding 76,800
pixel strings per frame in `rb_tri` + `rb_frag` + `rb_putrun` +
`rb_present`.

The hard constraint, from review of the first draft of this plan:

> **The compiler may name interfaces, never programs.**

No transform, pass, backend or runtime hook in `sh2perl/` may match on
`rb_tri`, `rb_frag`, `MIMEcroft`, `rb_*` or any game global. The
existing core already follows this where it matters:
`sh2perl/src/transforms/fbdev_gpu_hexrun.rs:85–105` walks every
`IrStmt::Function { name, body, .. }` and tests the **body's shape**;
the literals `"rb_mkrun"` / `"rb_putrun"` occur only in its test
fixtures (`:817`, `:847`) and in `str_splice_fold.rs:362`.
`fbdev_gpu*.rs` match **device verbs**. This plan keeps that property
and adds the gates that prove it.

## 2. The naming rule

### 2.1 Names that are allowed (interfaces)

| Name set | Source of truth | Why it is not program coupling |
|---|---|---|
| `/dev/fb0/{blocks,overlay,overlay_flash,uniform,call,depthmask}` | `sh2perl/runtime/fbdev.h`, `sh2perl/runtime/fbdev.c`; lifted by `fbdev_gpu.rs` (`DEVICE_ROOTS`, `:76`), `fbdev_gpu_batch.rs` (`BATCHABLE_VERBS`) | Plan 9 device ABI; closed lists are REFUSE > GUESS |
| `fb_*` primitives (`fb_blocks`, `fb_overlay`, `fb_present`, …) | `sh2perl/runtime/fbdev.h` | device ABI |
| `frag_x/frag_y/vcolor_{r,g,b}/uv_x/uv_y/tex_*/cr_*`, `putb`; `ap_*/ash_*/auv_*/ucp_*/ucy_*/uop_*/usc_*/ublk_*/uov` → `vp_*/vc_*/vu_*` | `sh2perl/src/glsl_backend.rs` bridge contract (`sh2glsl` header) | shader-language interface; compiles *any* bash program written against it |
| `CubeRec` / `OvRec` field layouts, atlas slot = layer, crack = layer 9 | `bash-o4/src/fb_frag.rs` (transcribed from `fbdev.c:278`, `:830–846`) | device payload schema (see §7, optional generalisation) |
| a stage entry when one must be selected explicitly | caller: CLI flag or source directive (precedent: `sh2glsl --vertex`) | user-supplied, not compiler-supplied |

### 2.2 Names that are forbidden

`rb_*`, `MIME*`, `RFB_*`, `RBTEX_*`, `SCOS/SSIN`, and any other
identifier of the program under compilation — in `sh2perl/src/**`
outside comments, docs and test fixtures.

### 2.3 Rule of thumb

If a match needs the program's name, the match is wrong: either the
semantics belong to a device/interface (move them to the device
boundary), or the pattern is structural (match the IR shape), or the
user must declare the entry.

## 3. Current state (what already exists)

Graphics half is largely built for the **device-protocol** form of the
renderer, not for the software-rasterizer form:

- `bash-o4/src/fb_frag.rs` — GLSL450 vertex+fragment pairs for the
  `blocks` and `overlay` verbs: cube tables (byte-identical transcriptions
  of `fbdev.c`), integer `frag_pixel`, crack in atlas layer 9, painter
  order, push-constant camera (`cam0/cam1/cfg`).
- `bash-o4/src/fb_draw.rs` — `RasterRunner`: offscreen colour+depth
  target, blocks pipeline (depth on) and overlay pipeline (src-alpha),
  atlas `sampler2DArray` upload, readback. Exercised by
  `bash-o4/tests/fb_dispatch.rs` (lavapipe-pinned, pixels asserted
  against a Rust transcription of `frag_pixel`) and `--fb-proof`.
- `bash-o4/src/fb_gpu_ffi.rs` + `sh2perl/runtime/fb_gpu.{c,h}` — the
  C-ABI seam (`bash_o4_fb_gpu_open/upload_atlas/draw_blocks_text/
  readback_bgrx`, embedded SPIR-V, `SH2_FB_GPU` env contract,
  present/readback/compare counters). **Gap:** `fb_gpu.c` is a Phase-2
  scaffold — nothing in `fbdev.c` calls it, and its own header states the
  `rb_face`/`rb_tri`/`rb_frag` parity pipeline is missing.
- `sh2perl/src/transforms/fbdev_gpu*.rs` — lift device writes to
  `GpuOp`, batch, rewrite to `fb_blocks`/`fb_overlay` (dormant for
  `MIMEcroft_fb.sh`, which no longer writes the protocol).
- `sh2perl/src/bin/sh2glsl.rs` + `glsl_backend.rs` — bash → GLSL ES 1.00
  fragment/vertex compilers keyed on the bridge contract.

What `MIMEcroft_fb.sh` does today: `rb_clear` (`:1997`), `rb_rect`
(`:2077`), `rb_cube`/`rb_face`/`rb_project` (`:2329–2765`), `rb_tri`
(`:2765`), `rb_frag` + `rb_tex_sample` (`:2270–3015`), 2D HUD
`rb_o_*` (`:3330–3855`) and `draw_*` (`:4982–6250`), `rb_present`
(`:2094`) as row strings → hex → `xxd` → the node.

Box state (2026-11-21): `vulkaninfo --summary` enumerates Intel UHD
(CML GT2), NVIDIA RTX 2070 Super, and llvmpipe; there is no
display/WSI, so the deliverable here is offscreen dispatch + readback
(still real `vkCmdDraw`).

## 4. Design: cut at "geometry on the CPU, pixels on the GPU"

Per-frame geometry is small (≤ ~300 cubes × 12 vertices); the cost is
per-pixel shading with overdraw. So the vertex/cull/control loops stay
in bash, and only rasterisation + shading + compositing move to the GPU.

### 4.1 Per-stage interface matching (no program names)

| Stage | Identified by | Anchor |
|---|---|---|
| camera/trig | push-constant slots (`cam0/cam1/cfg`) set through `uniform/*` device writes | `fb_frag.rs` §"Descriptor + push-constant contract" |
| vertex (cube, world-xz UV, `x·0.7/y·0.45`) | vertex bridge set `ap_*/ash_*/auv_*/ucp_*/ucy_*/uop_*/usc_*/ublk_*/uov` → `vp_*/vc_*/vu_*` | `glsl_backend.rs` bridge tables; `sh2glsl --vertex` |
| raster | **not recognised** — records carry `sx sy sz` and the GPU rasterises | `fb_frag` blocks vertex stage |
| fragment | reads fragment bridges, writes `putb` | `glsl_backend.rs:362–382` |
| HUD / 2D | `overlay` verb records (`OvRec`: centre, size, angle, colour, alpha, texture) | `fbdev_gpu_calls.rs` verb map |
| textures | `texture` device writes / host atlas upload; slot = layer | `fbdev.h` `fb_texture`, `fb_frag` atlas contract |
| present | `call` verb with `swap`; host op, refused by the shader map | `fb_frag.rs` §"Verb → artifact map" |

If a rasterizer lift is ever required (route B, §6 phase 3), it matches
**shape**, not names: a bounding-box loop nest over two pixel counters
containing three sign tests of linear forms in `(x,y)` and a per-pixel
sampler call. The lift is accepted only with a negative control (§5.3).

## 5. Gates that pin name-freedom

### 5.1 Static guard

`harness/` check: no forbidden identifier (`rb_`, `MIME`, `RFB_`,
`RBTEX_`, `SCOS`, `SSIN`) in `sh2perl/src/**` outside comment lines and
test modules. Fails the gate on introduction, not on review.

### 5.2 Rename test (the real proof)

Take `bash-o4/MIMEcroft_fb.sh`, rewrite every function/global matching
`rb_*` (and game globals) to a neutral prefix (`zz_`), run the pipeline,
and require:

1. identical transform/lift decisions (same `SH2_TRANSFORMS` diagnostics
   / `--dump-shir` structure modulo identifiers), and
2. byte-identical GPU frames for the phase-1 matrix.

A transform keyed on a name fails this immediately. It must be part of
the gate, not a one-off experiment.

### 5.3 Negative controls

- A function **named** like the lifted one but with a different body must
  not be lifted.
- A function with a **different name** but the real body must be lifted.
- The raster-shape matcher must reject a loop nest that lacks the third
  edge test (documented refusal, not a silent pass).

## 6. Phases

### Phase 0 — oracle and parity harness (no GPU)

Capture reference frames from the current software path
(`--first-frame`, `--first-frame-3d`, `FB_DUMP` PPMs) over the matrix:
320×240 / 480 / 600 / 720 / 1080 / 1440, CRT on/off, CORRUPT on/off,
minimap 0/1/2, labels on/off, menu frames, both sound modes. Commit
hashes plus a few PPMs.

New `harness/gpu-frame-parity.sh`: run a leg, byte-diff, report per-case
diff counts, and enforce an **explicit** tolerance class (§7.3).
*Acceptance:* harness goes red on a deliberately perturbed frame;
green on an identical leg; runs in the existing gate budget.

### Phase 1 — payload backend in the game (device protocol)

`MIMECROFT_DRAW=blocks|pixels`, default `pixels` (the transpiler test
case is unchanged). In `blocks` mode `rb_cube`/`rb_o_rect`/`rb_o_image`
append records (blocks line: `x y z sx sy sz r g b tx dam`; overlay:
`OvRec` fields), `rb_present` writes the batched payload then `swap`.
Atlas built from `RBTEX_R/G/B/A` (slot = layer, crack = 9) and uploaded
once per `tex_ver`.

*Acceptance:* `fbdev.c`'s CPU `fb_blocks`/`fb_overlay` reproduces the
`pixels` frames within the documented tolerance at every matrix point;
the shell corpus gate and both `--cpu-only` paths are unchanged; no new
identifier enters `sh2perl/`.

### Phase 2 — wire the GPU dispatch

`fbdev.c` calls `fb_gpu.c` when `SH2_FB_GPU=1`; `fb_gpu.c` calls
`bash_o4_fb_gpu_*`; blocks + overlay passes, atlas upload, readback to
BGRX, CPU fallback on any failure (`bash_o4_fb_gpu_available`,
`fb_gpu_reason`). SPIR-V is already embedded, so no `glslangValidator`
is required at runtime.

*Acceptance:* parity vs phase-1 CPU-device frames is **0 diff** at every
matrix point; no-Vulkan and `--cpu-only` runs stay green;
`tests/fb_dispatch.rs` and `--fb-proof` unchanged; `SH2_FB_GPU_PROFILE`
counters show zero fallbacks on the parity matrix.

### Phase 3 — rasterizer lift (optional, separate mission)

New `raster-gpu` pass: journal `GpuDraw` node (triangle + attributes),
integer fragment-shader mode in `glsl_backend` keyed on the bridge
contract, `present` node. Emits through the existing `fb_gpu` C-ABI.
The shader must replicate, and each item gets a pinned test vector:
`SSC=1000` pixel centres (`x*SSC + SSC/2`), inclusive fill (`e ≥ 0` after
winding normalisation), painter order (no depth test, submission order),
tint through the 127/1000 scales, truncating `/` and `%`, clamps,
`rb_tex_sample`'s fract-wrap, corruption hash `(x·7 + y·13) % 97 == 0`,
CRT `y % 6 == 0`, vignette on `RBF_VW`/`RBF_VH`, and `rb_text_cell`'s
4-corner coverage AA. Intermediates reach ~2⁴⁰ (edge-function products),
so the shader uses 64-bit explicit-arithmetic types as
`vulkan_backend.rs` does.

*Acceptance:* byte-exact vs phase-1 device-CPU frames; vs the bash
rasterizer either 0 diff or the documented tolerance only; rename test
green; performance recorded.

### Phase 4 — performance and documentation

Frame-time table (bash `rb_tri`+`rb_frag`+`rb_present` vs dispatch +
readback), lavapipe and hardware **labelled separately**; update
`docs/BASH_VULKAN.md`, `docs/BASH-O4.md` §4.4, `PLAN.md` §11.14, and
note that `fb_gpu.c`'s parity pipeline is live.

## 7. Honest limitations

1. **No display/WSI here.** "Native GPU" means an offscreen render pass
   plus readback; live swapchain present remains host work (`fb_present`
   owns it). Numbers must say "offscreen readback".
2. **Float vs fixed point.** The device CPU renderer and the shaders
   agree by transcription + `fb_dispatch.rs`; the bash rasterizer's
   integer truncation differs at tie cases. The oracle must be named
   explicitly: device CPU for the GPU path, bash rasterizer for the
   transpiler path. No claim of byte parity between bash and the float
   GPU pipeline without the integer shader of phase 3.
3. **Tolerance.** `0` diff for GPU-vs-device-CPU. For GPU-vs-bash, a
   documented per-channel budget is allowed only at the float
   transcription points named in `fb_frag.rs` (tint `r·255+.5`, UV lerp,
   overlay rounding). The harness prints the class it applied; silently
   widening it is a gate failure.
4. **`fb_gpu.c` is a scaffold.** Nothing calls it today and its header
   admits the parity pipeline is missing; phase 2 must add the call
   sites, phase 3 the raster parity (or route through the Rust host).
5. **Program-side blockers are inherited.** `docs/NATIVE-MIMECROFT-BLOCKER.md`
   and `INVESTIGATION-lifted-var-array-index.md` record known
   miscompiles. Route A (phases 0–2) avoids `rb_tri`/`rb_putrun`
   entirely; route B depends on those functions lowering correctly.
6. **Payload schema is device-shaped.** `CubeRec`/`OvRec` describe a
   cube renderer and HUD quads. Generalising to a generic attribute
   record is possible but breaks `fbdev.c`'s ABI; out of scope unless
   another program needs it.
7. **Atlas stays CPU-generated.** Textures, glyph masks, labels and
   mode-generated textures remain bash (deterministic LCG seeds); the
   GPU receives one uploaded atlas per `tex_ver`.

## 8. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Lifted semantics silently differ (fill rule, order, AA) | phase 0 oracle + pinned per-feature test vectors + negative controls |
| Name-coupling creeps back in | static guard + rename test in the gate, both failing loudly |
| GPU unavailable (no ICD, CI) | embedded SPIR-V, `bash_o4_fb_gpu_available`, CPU fallback; gates report skip, not pass |
| Payload protocol drift between script and device | one writer (`rb_present`), one parser (`fbdev.c`), parity gate compares the two renderers directly |
| Scope creep into the compiler | phases 0–2 are game + runtime only; phase 3 is its own mission with its own approval |

## 9. Decisions needed before phase 1

1. Approve route A (phases 0–2) as its own mission, with phase 3
   deferred to a separate mission.
2. Choose the tolerance class for phase 1 (recommended: `0` diff
   GPU-vs-device-CPU; documented budget GPU-vs-bash).
3. Confirm the hardware target: lavapipe for CI parity, 2070S only for
   clearly-labelled perf runs after a real graphics pipeline initialises.
