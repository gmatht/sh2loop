# Phase 2 audit: MIMEcroft fb0 emissions vs GpuOp/fb_frag coverage

Status: **audit/integration map** (Phase 2 groundwork). Does **not** enable GPU
dispatch. CPU path remains the semantic reference; `--cpu-only` must stay
byte-identical to baseline.

## Runtime boundary (target, file-backed / fbview mode)

For `play.sh` (`FB0_DEV`/`$RFB_PATH` = raw BGRX file, `fbview.py` polls it):
**host owns data & presentation**. Intended path:
1. Parse/consume frame GpuOp stream (blocks/overlay records, uniforms/cam/cfg,
   depthmask, `call`/`swap`/present).
2. Upload SSBOs/atlas/push constants; render offscreen via `fb_frag` pipelines
   (`fb_draw::RasterRunner` / Vulkan), with capability/runtime-failure fallback
   to CPU.
3. Read back and **write RGBA→BGRX into the same `FB0_DEV` buffer region/stride
   `fbview` expects** (W*H*4). `call`/`swap` remains a host op (present/sync),
   not a shader.

## Current pipeline (C target, MIMEcroft compiled by bash-O4)

- `sh2perl` transforms: `fbdev-gpu` lifts static `/dev/fb0` (and `/dev/webgl`)
  writes → `IrStmt::Ext(GpuOp{device,verb,slot,payload,id})`; `fbdev-gpu-batch`
  merges consecutive same-verb ops; `fbdev-gpu-elim` removes exact duplicates;
  **`fbdev-gpu-calls` (C target only, gated in `transform_applies`)** rewrites a
  mapped `GpuOp` into `IrStmt::Expr(Call{exec, fb_<verb>, [payload]})` when
  payload is "direct-ok".
- Mapped by `fbdev-gpu-calls` (slot must be empty, payload direct-ok): `blocks`
  → `fb_blocks`, `overlay` → `fb_overlay`, `overlay_flash` → `fb_overlay_flash`.
  Refused/kept as `GpuOp`: `call`/`swap` (`fb_present` has status polarity),
  `depthmask`, `uniform/*` (slot/register), `texture`, unknown verbs, non-direct
  payloads.
- C backend: `fb_call_opt` renders `fb_*` as in-process calls (links `fbdev.c`/
  `fbwin.c` via bash-O4/tcc). Unmapped `GpuOp` falls back to `fopen/fputs` of
  the original device-path write (correctness firewall).
- CPU raster/runtime: `sh2perl/runtime/fbdev.c` (`fb_blocks`, `fb_overlay`,
  `fb_overlay_flash`, `fb_present`, `fb_open` honors `FB0_DEV`/geometry).

## MIMEcroft_fb.sh emission audit (fb0-raster)

- `rb_frag_flags $CRT_ON $CORRUPT_ON` (e.g. ~3778, ~3807) and `rb_frag_view` feed
  fragment/uniform state; actual device writes go through the rb raster path /
  `fb_*`-reachable shapes. Direct `/dev/fb0/` echo forms are the lifting target;
  compiled path commonly reaches `fb_blocks`/overlay calls.
- World: "ONE batched payload per frame" via `fb_blocks` (~4441/4882).
- 2D overlay/HUD: batched `fb_overlay` payload (~4963).
- `call`/`swap`/present, `depthmask`, `uniform/*`, texture uploads, camera state:
  **host/runtime ops or push-constant/setup slots**, not `fb_frag` draw programs
  (`fb_frag.rs` explicitly refuses `call`, `depthmask`, `uniform/*` as shader
  programs; crack is atlas layer 9).

## fb_frag support (verdict boundary)

Supported shader pairs: `/dev/fb0/blocks` → blocks vert+frag; `/dev/fb0/overlay`
(and `overlay`/flash record shapes as applicable to overlay pipeline) → overlay
vert+frag. **Refused (render-time verdict = CPU/fallback, never guess):**
`call`/`swap` (present, host), `depthmask` (pipeline/push state), `uniform/*`
(push-constant/slot), and any unsupported verb/shape/precision/capability.

## Phase 2 remaining implementation work (high level)

1. **Render-time verdict for `GpuOp` / fb ops (marketplace rule).** In the C
   backend/acceptor: when Vulkan/fb0-GPU renderer **accepts** a supported verb
   (blocks/overlay path, with required capabilities), emit host dispatch
   call/sites; otherwise **refuse and keep CPU/file-write or `fb_*` rendering**.
   Toolkit-purity: Vulkan specifics in `bash-o4`/fb backend modules; avoid
   baking Vulkan into shared IR core. `fbdev-gpu-calls` rewrites hot verbs
   before c_backend sees `GpuOp` — verdict may need to apply at that layer or
   via runtime dispatch under `fb_*` (see FFI constraint).
2. **Host dispatch + readback.** `bash-o4/src/fb_draw.rs` + `vkffi.rs` provide
   offscreen Vulkan raster (`RasterRunner`) and RGBA readback; add RGBA→BGRX
   readback/write path matching `FB0_DEV` file layout (`W*H*4`) for fbview.
   Enforce runtime capability checks and CPU fallback on any failure.
3. **FFI/linking constraint (key).** Compiled `mimecroft-fb-play` links C
   runtime (`fbdev.c`, found/linked by `bash-o4/src/tcc.rs`; overridable via
   `BASH_O4_FBDEV_DIR`). `fb_draw`/Vulkan is Rust. Making standalone compiled C
   dispatch to Rust Vulkan requires a C-ABI library/FFI, embedding Vulkan host
   in C, or a helper boundary — non-trivial; must preserve `--cpu-only` and
   default byte-identical behavior. Do **not** regress CPU path.
4. **SPIR-V embedding/caching.** Embed or deterministically hash/fetch SPIR-V
   artifacts like the cache pipeline (pin compiler flags, stable ids). Gate on
   acceptance.
5. **Parity validator.** For captured per-frame payloads, CPU-raster reference
   vs GPU render, full-frame compare with Phase 0 tolerance (`oracles/fb0-cpu/
   README.md`).
6. **Gate.** `./play.sh --no-build [--view 800x600]` with GPU enabled produces
   oracle-equivalent frames from `FB0_DEV`/dump (HUD/minimap/flash/CRT paths as
   fixtures exist); `--cpu-only` byte/behavior-identical to CPU baseline.

## Safety rules
- Default/`--cpu-only` = current CPU behavior, byte-identical to oracles.
- No Vulkan/unsupported capability/runtime error ⇒ CPU fallback, clear reason.
- Refuse > guess; never silent precision narrowing.
