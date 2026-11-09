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

## Implemented (this pass): C-ABI host path + dispatch/CPU-fallback wiring

**Blocker addressed (infrastructure):** a C-ABI Vulkan host path and runtime
dispatch/CPU-fallback wiring now exist; `--cpu-only`/default remains the exact
CPU path (byte-identical). **Not yet achieved:** GPU-enabled, oracle-equivalent
full-frame rendering for real MIMEcroft payloads (the render-time/runtime
verdict is conservative and refuses unproven state; see below).

- **Rust C-ABI host (`bash-o4`, toolkit-purity):** `src/fb_gpu_ffi.rs`, crate
  builds as `rlib+cdylib` (`target/debug/libbash_o4.so`). Exports
  `bash_o4_fb_gpu_available/open/close/draw_blocks_text/readback_bgrx/
  last_error` (catch_unwind, capability-checked, fail-closed). Reuses
  `fb_draw::RasterRunner`/`fb_frag`/`vkffi`; readback converts RGBA→BGRX
  (`RasterRunner::rgba8_to_bgrx`).
- **C runtime dispatch (`sh2perl/runtime/fbdev.c`, materialized/embedded by
  `bash-o4/src/devices.rs` at compile time):** `fb_blocks` dispatches through a
  dlopen’d C-ABI host (`BASH_O4_FB_GPU_LIB`, else `libbash_o4.so`) **only** when
  explicitly enabled and verdict-accepted; otherwise runs the unchanged
  `fb_blocks_cpu` path. `SH2_FB_CPU_ONLY=1` (and `play.sh --cpu-only`) forces
  the exact CPU path. On any load/capability/init/verdict/dispatch/readback
  failure it reports a one-time `fbdev-gpu: CPU fallback (reason: ...)` to
  stderr and falls back to CPU. GPU readback is written into `S_px`
  (0xAARRGGBB) so `fb_dump_ppm`/overlay composite/present see consistent pixels.
- **Conservative render-time/runtime verdict (correctness-first):** refuses
  (=> CPU fallback) unless `SH2_FB_GPU=1` **and** `SH2_FB_GPU_ACCEPT=blocks_proof`
  **and** no textures/overlay state that would break parity (`O_have`/textures
  refused). This proves the C-ABI/dispatch/readback path but does **not** claim
  oracle-equivalent rendering for real MIMEcroft frames (real atlas textures,
  overlay/flash HUD compositing, CRT/corrupt/fragment parity, and full payload
  state mapping still required). Refuse > guess; never silent narrowing.
- **Phase 0 oracle gate (CPU/default):** 320×240 md5 `965f7b3dad4cfd516ff637c8943681bc`
  (230415 B) and 800×600 md5 `9e247bc7f5fe65f8be1e09aef420bb41` (1440015 B)
  still match via `mimecroft-fb-play --first-frame --view ...` (CPU path).
- **Not committed in sh2perl:** `/mnt/wsl/projects/sh2loop/sh2perl/runtime/fbdev.c`
  was modified for dispatch wiring (separate repo, dirty/in-flight; no
  authorization to commit/push). `devices.rs` embeds it at bash-o4 compile time,
  and the materialized device dir is content-hashed — rebuild bash-o4 and relink
  the game to pick it up. The committed bash-o4 superproject changes depend on
  that runtime source for the new behavior.

## Remaining for full Phase 2 gate (GPU oracle-equivalent)
- Verify/lock readback byte-order contract vs `fbdev.c`/`fbwin`/`fbview` for the
  live `FB0_DEV`/present path (and composite `ov_composite` before dump where
  required for parity).
- Real atlas upload (stable layer mapping matching `fbdev.c`, crack layer 9) and
  camera/flags parity for MIMEcroft.
- `fb_overlay`/`overlay_flash` GPU or proven CPU-composite path with parity;
  extend verdict/acceptance per verb (`call`/`swap` host, `depthmask`/`uniform/*`
  refused as shaders).
- Render-time verdict integration honoring `fbdev-gpu-calls`→`fb_*` (c_backend)
  and toolkit-purity/marketplace rules; `--cpu-only`/default byte-identical.
- SPIR-V deterministic embedding/caching for the runtime path; capability veto.
- Per-frame/payload CPU-vs-GPU parity validator (Phase 0 tolerance) + fixtures
  (HUD/minimap/flash/CRT/corrupt/crack), then enable acceptance; gate
  `play.sh --no-build [--view 800x600]` GPU oracle-equivalent.

## Policy update: GPU by default (when correct)

- `fbdev.c` verdict changed to **attempt GPU by default**, but only for
  render-time verdict-accepted (**proven-correct**) frame/state. `SH2_FB_CPU_ONLY=1`
  or `SH2_FB_GPU=0` forces the exact CPU path (byte-identical). No `SH2_FB_GPU=1`
  opt-in required. Any capability/load/init/dispatch/readback failure, or any
  unproven state, refuses and falls back to CPU with a one-time clear reason
  (refuse > guess; no silent narrowing).
- Current verdict remains **conservative** (correctness-first): refuses when
  textures/overlay/composite state is present or block shading/atlas parity is
  not yet proven against fbdev.c CPU + Phase 0 oracles, so real MIMEcroft frames
  take the CPU path and remain byte-identical. `SH2_FB_GPU_ACCEPT=blocks_proof`
  is an explicit, non-oracle C-ABI dispatch test hook for proven-safe
  (untextured, no-overlay) state only. As per-frame oracle parity is gated for
  each mapping, lift acceptance there (GPU becomes the default for those proven
  frames).
- **Gate re-verified (new `mimecroft-fb-play` linked with updated fbdev.c),
  CPU/default and `SH2_FB_CPU_ONLY=1`, byte-identical to Phase 0 oracles:**
  320×240 `965f7b3dad4cfd516ff637c8943681bc` (230415 B),
  800×600 `9e247bc7f5fe65f8be1e09aef420bb41` (1440015 B).
- **Still uncommitted in sh2perl:** the verdict/runtime change is in
  `/mnt/wsl/projects/sh2loop/sh2perl/runtime/fbdev.c` (separate repo, dirty/in-
  flight, no auth to commit/push). Rebuild bash-o4 + relink the game to pick up
  (devices.rs embeds it at compile time). The running game process (if any)
  continues on its old inode until restarted.
