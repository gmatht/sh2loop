# Phase 3 plan — Presentation & performance (AFTER correctness)

**Status: blocked on Phase 2 correctness.** Phase 3 must not change semantics or
default behavior. The GPU dispatch + render-time verdict + host runtime
(readback into file-backed `FB0_DEV` for `fbview`) is not wired end-to-end yet
(see `PHASE2-AUDIT.md`; key blocker: compiled C `mimecroft-fb-play` links
`fbdev.c` while Vulkan host is Rust `fb_draw`/`vkffi` — FFI/C-ABI/runtime
boundary unresolved). **No performance work should land that compromises
CPU-oracle parity or the CPU fallback.** `--cpu-only` stays byte/behavior-
identical to the CPU baseline.

## 1) Presentation — avoid readback-to-file bottleneck (compat fallback kept)

File-backed BGRX readback is correct and compatible with `play.sh` +
`tools/fbview.py` (polls `FB0_DEV` BGRX). It adds GPU→CPU copy + file/IPC
overhead per frame.

**Staged, optional (only after Phase 2 parity is green):**
- Keep **file-backed `FB0_DEV` BGRX** as the compatibility fallback (and the
  reference path for oracle/dump comparisons).
- Add direct-present options behind explicit opt-in: X11/Vulkan WSI surface
  presenter, or shared-memory/texture path that `fbview`/a small presenter can
  sample — eliminating per-frame file readback/write where available.
- `call`/`swap` remains a **host op** (present/sync), not a shader. Respect the
  same frame/ordering semantics the CPU painter relied on.

## 2) Per-frame upload optimization (only after correctness)

- Start: **host-visible coherent** buffers (simple, correct) — matches `fb_draw`
  v1 approach.
- Then (measured, parity-gated): device-local + staging, persistent-mapped ring
  buffers, update-only-dirty regions for SSBOs/atlas.
- Batch `blocks`/`overlay` into the **minimal draw/submissions per frame**.
  Respect `depthmask`/ordering semantics (host/pipeline state; `fb_frag` refuses
  `depthmask`/`uniform/*` as shader programs — they are push-constant/setup
  slots or host state).

## 3) Atlas/texture lifecycle

`fb_frag` contract: set 0 binding 1 = block atlas `sampler2DArray`, **crack
texture = atlas layer 9** (`fbdev.c` `CRACK_TEX`). Implement a host texture
manager (upload, stable layer mapping, updates) that matches `fbdev.c`’s slot
semantics exactly. Parity-check atlas sampling (NEAREST/int-exact paths
documented in `fb_frag.rs`) against CPU oracles.

## 4) Measure honestly (no claims without data)

Report **per-frame ms**, separated: (a) CPU raster, (b) GPU upload + dispatch +
render, (c) GPU readback, (d) present, at **320×240 and 800×600** on the actual
target. Use a bounded, non-interactive, deterministic frame-count harness
(steady-state; median/pXX of N frames) — `--first-frame` is not representative.
Record device/ICD (e.g. lavapipe/llvmpipe vs real GPU): **this box may use
software Vulkan (lavapipe/llvmpipe), so GPU offload may not win; measure, don’t
claim.**

**Baseline note (CPU, this session):** a quick bounded `--demo` run against
file-backed `FB0_DEV` hit the `timeout` wrapper before producing `#stats:` (so
no steady-state CPU ms/frame captured here). A proper bench mode/harness is
needed for honest CPU vs GPU numbers.

**Profitability / fallback:** keep the static trips/cost/dispatch/transfer-cost
+ margin floor logic; **small/unsuitable frames stay CPU** (zero wasted GPU work,
no dead artifacts where the trimmer/candidacy applies). Any runtime error or
missing capability ⇒ CPU fallback.

## Exit criteria
- Phase 2 parity green against `oracles/fb0-cpu/` (and added CRT/corrupt/flash/
  crack fixtures) at 320×240 and 800×600, `--cpu-only` byte-identical.
- Measured per-frame breakdown published for CPU and GPU-on/off on the real
  target; GPU default-on (if ever) justified by data or kept behind opt-in/
  profitability.
