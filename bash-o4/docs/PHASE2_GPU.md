# Phase 2 — GPU raster + `rb_frag` shading (swapchain, no-readback live)

## Status (this workspace snapshot)

This worktree is a partial snapshot: oracle artifacts (`bash-o4/oracles/phase0`, `jcmd-ref`), the Phase-1 `RFB_PIX` refactor state described in historical memory, and `/tmp/fb0-phase1-work/prog.c` are not present. `bash-o4/MIMEcroft_fb.sh` here drives the fb0 device via high-level `fb_*` calls (`fb_open/blocks/present/dump/frag_flags/view`) rather than embedding the `rb_face/rb_tri/rb_frag/rb_o_blend` software rasterizer inline. Cached AOT `prog.c` files under `/root/.cache/bash-o4/*/prog.c` *do* contain the full CPU `rb_*`/`RFB_ROWS`-hex renderer (e.g. `rb_face` → `rb_tri` → `rb_frag` per covered pixel, `rb_o_blend` overlay, `rb_present`/`rb_dump_ppm` via `/tmp/rb-frame.hex` + `xxd`), so seam analysis below is grounded in generated call/state structure from those artifacts.

## Integration seam — decision driver

**Observed (generated `prog.c`):**
- **Call structure is regular and hot:** `rb_face` sets up a triangle/face state, `rb_tri` iterates the raster domain and, per fragment, writes interpolants into globals/locals (`rbp_fu/fv/fsh/...`, tex id/damage/flags context) then calls `rb_frag()`; `rb_frag` applies texturing/tint/CRT/corrupt/damage/vignette and commits the pixel (row/hex-buffer writes in the pre-Phase-1 form; linear `RFB_PIX` in the refactored form). Overlay uses `rb_o_blend`.
- **Shared mutable globals:** `RBF_CRT`, `RBF_CORRUPT`, view/dims (`RBF_VW/RBF_VH` via `rb_frag_view`), texture arrays/metadata (`RBTEX_R/G/B/A`, OFF/SZ/RGBA, slot 9 crack/damage), camera/projection state, and the framebuffer target (`RFB_ROWS` hex strings pre-Phase-1, `RFB_PIX` packed pixels Phase-1).
- **Cross-boundary state:** frame-global uniforms (CRT/corrupt/view/camera) + uploaded textures are stable per frame; per-triangle/per-fragment vary.

**Option A (recommended, explicit seam) — chosen:**
- Codegen/transpiler emits a **GPU scene/batch** contract (triangles + per-vertex interpolants: position/uv/shade/depth/damage/tex id/flags; texture resources; per-frame uniforms `RBF_CRT/RBF_CORRUPT`, view/camera) to a runtime API, analogous in role to batched `fb_blocks`.
- Runtime renders with a Vulkan graphics pipeline and **presents directly to swapchain** on the live path; on refuse/incapable/unsupported features it **falls back to CPU `rb_*` with a clear reason**.
- *Why:* contains GPU mapping to a defined, parity-testable contract instead of translating arbitrary generated C/mutable-global side effects; matches existing fbdev batch/dispatch patterns; easiest to gate against the j.cmd/JS/bash oracle and to bound precision/tolerance. Vertex/fragment stages implement oracle-derived semantics (fixed-point/edge-attribute parity, no silent narrowing).

**Option B (lower `rb_*` calls to batched draws):** feasible given regular call sites but higher risk: must faithfully model global mutable state and call-order side effects across `rb_face/rb_tri/rb_frag/rb_o_blend`. Kept as a fallback integration strategy only if scene extraction proves lossy.

## Runtime/host contract (implemented scaffolding)

- **Mode/env (project overrides win):**
  - `SH2_FB_CPU_ONLY=1` or `SH2_FB_GPU=0` ⇒ **unchanged CPU `rb_*` path** (always wins).
  - `SH2_FB_GPU_PROVE=compare` ⇒ opt-in compare mode: render GPU and compare vs oracle-correct reference/j.cmd-JS-bash using an **on-demand readback/offscreen path only** (never the live path); restore CPU on mismatch and report reason.
  - Default when GPU path is enabled and accepted: **live swapchain render+present, no readback, no compare**.
- **Fallback:** any init/capability/swapchain/SPIR-V/device failure ⇒ CPU fallback with explicit reason; never claim success on fallback.
- **Nvidia/robustness:** prefer discrete Nvidia when enumerating; tolerate mixed ICDs; honor standard `VK_ICD_FILENAMES`/`VK_DRIVER_FILES` for diagnosis and project overrides; conservative SPIR-V/Vulkan feature set; robust surface format/present-mode selection and swapchain recreate on out-of-date/suboptimal/resize; runtime capability checks before use. Lavapipe is correctness-only.

## Rendering model

- **Textures:** upload `RBTEX_R/G/B/A` (+OFF/SZ/RGBA, slot 9 crack) to GPU texture/atlas/storage (backend-dependent). Push per-frame uniforms: `RBF_CRT`, `RBF_CORRUPT`, view.
- **Vertex:** triangle data matching `rb_face/rb_tri` (positions + interpolants fu/fv/fsh/fdam/ftx/color). Match fixed-point/edge semantics or explicitly tolerance-bounded equivalent (document/measure).
- **Fragment (`rb_frag` parity, oracle-derived):** `rb_tex_sample` + fixed-point-equivalent shading + CRT scanline/vignette + damage (slot 9, `rbp_fdam`) + CORRUPT noise per Phase-0/j.cmd-JS-bash semantics; deterministic formulas preferred. Reuse/extend SPIR-V + dispatch patterns where compatible.
- **Overlay/blend (`rb_o_blend`):** subsequent pass/blend with oracle-matched semantics.
- **Present:** render to acquired swapchain image and present via window/surface (WSI) — **no** host copy/map/readback on live path. `--first-frame`/dump and compare use separate on-demand readback path.

## Files touched (scaffolding)

- `sh2perl/runtime/fbdev.{h,c}`, `fbwin.{h,c}` — GPU mode selection, fallback reporting, swapchain/present path hooks and env handling (scaffold; requires a display/WSI-capable Vulkan stack to exercise live).
- `bash-o4/src/fb_frag.rs` — shader generation helpers extended toward `rb_frag`-parity fragment logic (oracle-derived, no silent narrowing).
- `bash-o4/src/vkffi.rs` — graphics/swapchain primitives surface (extension from compute-only runner) as needed by runtime host integration.

## Verification / limitations

- **Oracle gate:** correctness must be accepted against state-aligned j.cmd/JS/bash matrix (320×240, 800×600) under explicit tolerance; this snapshot lacks the recaptured oracle matrix and deterministic state hooks for all modes (CRT/CORRUPT/flash/crack/HUD/geometry), so parity cannot be claimed here.
- **Live GPU:** not runnable/validated on Nvidia or Lavapipe in this environment; capability checks and CPU fallback are required at runtime.
- **Codegen:** `sh2perl/src/c_backend.rs` `RFB_PIX` materialization and scene/batch emission for regenerated builds remain follow-ups in the sh2perl submodule (no commit/push authority).

## Phase 3 — Transpiler/codegen wiring & cache-correctness (this pass)

### Automatic lowering / scene-batch emission (status)
- **Seam (Option A, chosen):** a single auditable GPU scene/batch contract (triangles + per-vertex interpolants uv/shade/depth/damage/tex id/flags, textures `RBTEX_*` incl. slot 9 crack, per-frame uniforms `RBF_CRT/RBF_CORRUPT`/view/camera, overlay/blend, frame lifecycle) targeting the runtime API when the GPU path is available/proven; otherwise emit the CPU `rb_*` path over the Phase-1 linear buffer. `--cpu-only` / `SH2_FB_CPU_ONLY=1` / `SH2_FB_GPU=0` force CPU unconditionally; any runtime incapability or `SH2_FB_GPU_PROVE=compare` mismatch ⇒ CPU fallback with clear reason (never a degraded/unproven GPU path).
- **Not wired in this snapshot:** no `fbdev-gpu-calls`–style transform or C-backend scene/batch emission is present/landed here (`sh2perl/src`/`c_backend.rs` unavailable; submodule dirty with no commit/push/shared-core modification authority). Lowering must be proposed/landed as a per-backend offer (PLAN §11 marketplace: backend implements/offers; acceptors accept; core single-owner not modified except agreed contract). The runtime/contract hooks above are the stable seam to target.

### Runtime + SPIR-V materialization & exe-cache correctness (implemented)
- **Device/runtime embedding:** `bash-o4/src/devices.rs` now embeds and materializes `fb_gpu.c/.h` alongside `fbdev/fbwin/fbinput/fbsound`; `content_digest()` exposed so the materialized device dir is content-addressed over the full embedded runtime set.
- **Cache key pinned to inputs affecting the binary:** `bash-o4/src/cache.rs` adds `runtime_fingerprint()` (folded into `artifact_key` via `cli.rs` opts) covering: selected fbdev runtime dir — **`BASH_O4_FBDEV_DIR` override path + contents** of all device/runtime sources (`fbdev/fbwin/fbinput/fbsound/fb_gpu` [+ uu_run if present]) **or** the embedded `devices::content_digest()`; any `fb_spv/*.spv` shaders + manifest discovered (cwd / `BASH_O4_SH2PERL`); GPU/selection envs (`SH2_FB_CPU_ONLY`, `SH2_FB_GPU`, `SH2_FB_GPU_PROVE`, `SH2_FB_GPU_ACCEPT`, `BASH_O4_FBDEV_DIR`); and link-relevant compile flags/env (`CC/CFLAGS/LDFLAGS/BASH_O4_TCC/BASH_O4_CC`). This ensures a runtime/SPIR-V/override/flag change invalidates the cached exe (no stale-cache serving). `prog.c`/ShIR, opts, toolchain and render env remain in the existing key.
- **Override honored:** `tcc.rs` continues to select the fbdev TU from `BASH_O4_FBDEV_DIR` when set (with an explicit error if required sources are missing) else from materialized embedded devices; the fingerprint now keys on that same selection so a diagnosis override cannot be masked by a stale cache entry.
- **SPIR-V/embed consistency:** no `fb_spv/*.spv`+manifest files are present in this snapshot; when added, they are fingerprinted and must remain consistent with runtime dispatch (regenerated builds must not mix old shaders with new runtime).

### Diagnostics & profiling (stable surface)
- **Fallback/selection logging (file, not stderr):** `fb_gpu` logs init/mode, ICD env hints (`VK_ICD_FILENAMES`/`VK_DRIVER_FILES`, prefer discrete Nvidia, Lavapipe correctness-only), and refusal/fallback reasons to `SH2_FB_GPU_LOG` (default `/tmp/sh2-fb-gpu.log`). Reason also queryable via `fb_gpu_reason()` / `fb_dev_gpu_reason()`.
- **Flags preserved:** `--cpu-only` / `SH2_FB_CPU_ONLY=1` / `SH2_FB_GPU=0`, `SH2_FB_GPU_PROVE=compare|off` (compare on-demand/readback only), `SH2_FB_GPU_ACCEPT` (recognized in fingerprint/mode surface).
- **Profiling hook:** `SH2_FB_GPU_PROFILE=1` enables profile log markers (e.g. present/readback/compare path events) to the same log for win/regression tracking; deeper `gspan/fd_*` + `rb_*`/present counters remain to be instrumented in the generated/prog.c and runtime as available.

### Verification
- `cc -c -D_GNU_SOURCE -I. fb_gpu.c`, `fbdev.c`, `fbwin.c` compile as objects in `sh2perl/runtime` (warnings only). No regenerated-build, GPU, Nvidia, or oracle-correctness run was performed in this snapshot; cache-invalidation behavior is implemented but not exercised end-to-end here. CPU fallback remains the authoritative path until the swapchain+rb_frag pipeline is proven oracle-equivalent.

## Phase 4 — Correctness gating & acceptance (scaffold/gating wiring, this pass)

**Oracle:** j.cmd/JS/bash (Phase 0) is the sole acceptance reference. CPU `rb_*` / legacy `fb0-cpu` captures are **not** acceptance references (`--cpu-only` is legacy-compat only, labeled). Live GPU path = swapchain/no-readback; dump/compare read back **on demand only**.

### Fallback order (Nvidia-special-cased before CPU) — runtime behavior
- On Vulkan unavailable / init or render failure / unsupported capability: probe default, then apply **Nvidia-special-cased handling** (honor `VK_ICD_FILENAMES`/`VK_DRIVER_FILES`, prefer discrete Nvidia, retry/alternate-ICD intent) and re-attempt the GPU path where a pipeline exists. Only if the Nvidia-special-cased path also fails/unproven ⇒ **clean CPU fallback** with a clear reason and the **failing step** logged (`[step:...]`). `--cpu-only` / `SH2_FB_CPU_ONLY=1` / `SH2_FB_GPU=0` always force CPU. **Refuse > guess:** never render an unproven/mismatched frame on GPU.
- Implemented in `sh2perl/runtime/fb_gpu.c`: step/reason logging (`init`/loader/Nvidia-retry/pipeline), explicit fallback reasons, counters (`present/readback/compare/fallback`) via `fb_gpu_log_counters()` to `SH2_FB_GPU_LOG` (default `/tmp/sh2-fb-gpu.log`, pid-tagged, not stderr). Current snapshot still refuses activation because the WSI/swapchain+rb_frag-parity pipeline is not proven (CPU remains authoritative).

### Compare/prove (opt-in debug)
- `SH2_FB_GPU_PROVE=compare`: on-demand readback only; compares GPU output vs the **oracle-correct reference (j.cmd/JS/bash)** path, records mismatch/max_abs/mean_abs, **restores CPU on mismatch** (`G_active=0`, fallback reason logged). Real-time default = swapchain/no-readback with **no compare**. Tolerance is applied per the explicit Phase-0 spec when running the gated matrix (not hard-coded here).

### Acceptance/parity matrix & end-to-end (not executed in this snapshot)
- **Required matrix (gated vs j.cmd/JS/bash oracle, deterministic keys/canonical state):** base + CRT + CORRUPT + flash + crack/damage (slot 9 / `rbp_fdam`) + HUD/overlay, at **320×240 & 800×600**, measured `maxd/badpx` per case, all within the explicit Phase-0 tolerance. Acceptance = oracle-equivalent (never “byte-identical to buggy CPU/legacy fb0-cpu captures”).
- **End-to-end:** `play.sh --no-build [--view 800x600]` + `--first-frame` gated against the j.cmd/JS/bash oracle set (live no-readback; dump/compare read back on demand).
- **Status:** oracle artifacts/state hooks and the proven GPU pipeline are unavailable/unrun here, so **no acceptance claim**. The runtime/driver gating (CPU-only/legacy labeled, compare-on-demand+restore, Nvidia-first fallback order with reasons, file logging, counters) is wired to support the gate once the pipeline and oracle recapture are in place.

### Perf check (post-parity only, after oracle acceptance)
- Re-measure with the same `gspan/fd_*` + `rb_*` count/present instrumentation (file-logged). Target: collapse ~1.07 s render (~815k `rb_frag`) into GPU frame time, **zero steady-state readback**, direct swapchain present. Report **real Nvidia GPU vs Lavapipe separately** (Lavapipe correctness-only). Confirm CPU fallback path and its reason are clean when triggered.
- **Status:** not run (no parity/proven pipeline). `SH2_FB_GPU_PROFILE=1` logs present/readback/compare path markers/counters to `SH2_FB_GPU_LOG`; detailed `gspan/fd_*`/`rb_*` instrumentation in generated `prog.c` remains pending.

### Verification (this pass)
- `sh2perl/runtime/{fb_gpu,fbdev,fbwin,fbinput,fbsound}.c` compile as objects with `cc -c -D_GNU_SOURCE -I.` (benign `_GNU_SOURCE` warnings). No oracle matrix, end-to-end, Nvidia/Lavapipe, or perf runs executed in this snapshot.

## Phase 5 — Perf follow-ons (gated: only after oracle parity/acceptance)

**Precondition (not met in this snapshot):** Phase 5 work applies **only after oracle parity/acceptance** vs j.cmd/JS/bash (Phase 0/4) on a proven, oracle-equivalent GPU pipeline. No oracle-accepted/proven swapchain+`rb_frag` GPU path exists here (activation refused, `refuse>guess`), so **no perf implementation or perf claims** are made.

### Targets (post-acceptance, to harden the live swapchain/no-readback path)
- **Steady-state GPU path (zero readback):** batch/retain geometry across static parts; persistent GPU buffers/ring; minimize per-frame alloc/destroy and state uploads (textures/static scene retained, per-frame uniforms/push constants only); single submit+present per frame where possible. Confirm no host readback, no `xxd`/hex/file work, no per-frame readback fence on the live display path.
- **Swapchain robustness/perf:** fast swapchain recreate on out-of-date/suboptimal/resize; present-mode tuning. Validate on the **real Nvidia** target (with Phase-2/4 Nvidia-special-cased handling/retry before CPU fallback) and **report separately** from Lavapipe (correctness-only).
- **Dump/oracle/compare isolated:** `rb_dump_ppm` / `--first-frame` and `SH2_FB_GPU_PROVE=compare` use the reference or an explicit **on-demand** readback only when requested — **never** forced by/into the live swapchain path. Compare against the oracle-correct reference / j.cmd-JS-bash.

### Current contract/status (structural, not a perf result)
- Live present path is designed as swapchain/no-readback when active; readback is on-demand only for dump/compare (`fb_gpu_readback`/compare guarded and counter-logged). CPU remains authoritative until a proven pipeline passes oracle gating.
- Perf measurement (post-parity): re-measure with `gspan/fd_*` + `rb_*` count/present instrumentation (file-logged), target collapsing ~1.07 s render (~815k `rb_frag`) into GPU frame time with zero steady-state readback; report real Nvidia vs Lavapipe separately; confirm clean CPU fallback/reason when triggered. **Not run.**

### Concrete next steps (gated on oracle parity/acceptance)
1. Achieve and gate oracle parity/acceptance (Phase 0/4 matrix vs j.cmd/JS/bash, Nvidia path proven, compare-proof restores CPU on mismatch).
2. Implement persistent buffers/ring, retained static geometry/textures, per-frame push constants/uniforms only, and single submit+present; eliminate per-frame alloc/destroy and any live-path readback/fence.
3. Add robust swapchain recreate/present-mode handling and profile on Nvidia (separately from Lavapipe); keep dump/compare strictly on-demand.
