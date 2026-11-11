# Phase 4 plan — Broaden scope carefully (OPTIONAL, after Phases 2–3 correctness)

**Status: not started / blocked.** Extend GPU scope **only** when a verb/state has
a proven, oracle-tested shader/host mapping and passes render-time verdict with
CPU fallback. Do **not** guess mappings. Phase 2 parity and guardrails come
first; Phase 3 is performance/presentation after correctness.

## Scope (only with proven oracle-tested mappings)

- **`blocks`/`overlay`/`overlay_flash`/crack:** covered by the fb0 fragment path
  (`fb_frag`: `blocks` + `overlay`; crack = atlas `sampler2DArray` layer 9). Any
  expansion (CRT/corrupt state) must be fixture-oracled at 320×240 and 800×600.
- **`uniform/*` / camera / config:** host/pipeline state → **push constants/UBOs**
  (matches `fb_frag` push layout `cam0/cam1/cfg`/uniform slots). `fb_frag`
  currently **refuses `uniform/*` as shader programs**; keep as setup/dispatch
  state, not fragment codegen.
- **`depthmask` / blend / ordering:** **pipeline state** and draw ordering that
  preserves CPU-painter semantics. `fb_frag` refuses `depthmask` as a shader
  program; `fbdev-gpu-calls` leaves it unmapped (c_backend `GpuOp` fallback).
- **`call`/`swap`/present:** **host ops only** (sync/present) — never shaders.
  `fbdev-gpu-calls` refuses `call`/`swap` (status/polarity boundary).
- **`texture` uploads / atlas:** host texture manager with **stable layer mapping
  matching `fbdev.c` slot semantics exactly** (crack = layer 9). Parity-check
  NEAREST/int-exact sampling.
- **Real `/dev/fb0` mmap and native X11 presenter paths:** host-side
  presentation; shaders do not mmap/open windows. Keep file-backed `FB0_DEV`
  compatibility fallback.
- **Whole-program `--gpu` map/reduce kernels:** revisit only after the fb0
  fragment path is stable. May share `cu_run`/dispatch machinery conceptually,
  but it is a **separate acceptance problem** from fb0 (different oracles,
  candidacy, and verdicts) — do not conflate.

## Architectural boundary (required)

- **Transforms propose `GpuOp`; renderers give the render-time verdict** (per
  PLAN §11 marketplace / toolkit-purity). Vulkan specifics, SPIR-V embedding,
  descriptor/upload/dispatch, and presenter code live in `bash-o4`/fb backend
  driver modules (`fb_frag`, `fb_draw`, `vkffi`/runtime), **not in the shared IR
  core**. Shared `sh2perl` core is single-owner/dirty here — do not modify it
  casually; cross-cutting verdict wiring needs explicit coordination.
- Verdict = accept only proven, capability-checked shapes; otherwise **refuse →
  CPU fallback**. Never guess; never silent i64/precision narrowing; runtime
  capability checks.

## Risks & mitigations

| Risk (highest first) | Mitigation |
|---|---|
| Misrendering (float vs int transcription, y-flip/CRT phase, UV/overlay rounding, depth/painter differences) | Fixed CPU oracles (`oracles/fb0-cpu/`), added CRT/corrupt/flash/crack fixtures, per-frame/payload parity harness, refuse unsupported verbs, CPU fallback always available. |
| fbview/file-backed readback overhead erases gains | Correctness first with readback; direct-present/SHM path later (Phase 3), measured. |
| No real GPU / llvmpipe slower than CPU | Capability check + profitability/`--cpu-only` + measure before defaulting to GPU. |
| i64/precision & device limits | Explicit capability veto, never silent narrowing. |
| Architectural bleed (Vulkan in shared core) | Vulkan/host-dispatch in `bash-o4` backend/driver; transforms propose, renderers verdict. |

## Prerequisites / exit expectations
- Phase 2 gate green (GPU oracle-equivalent at 320×240/800×600, `--cpu-only`
  byte-identical) and Phase 3 measurements/presentation decisions grounded in
  data. Each newly accepted verb/state gets its own oracle, parity test, and
  refusal/fallback coverage.
