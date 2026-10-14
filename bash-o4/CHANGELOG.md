# `-O4` driver changelog

Covers the whole `-O4` driver family — `bash-O4` and `python-O4` are two front
ends over one pipeline (`ShIR` → C via tcc, or → PTX via the CUDA candidacy),
sharing one flag surface (`bash-o4/src/flags.rs`) and one dispatch vehicle
(`bash_o4::cu_run`).

## Unreleased — fb0 fragment dispatch loop (PLAN v52)

Closes the emit-half §11.14 called "remains": the `fb_frag` static
GLSL450 pairs (`blocks`/`overlay`) now dispatch offscreen on a real
Vulkan device (Lavapipe-pinned).

### Added

- **`fb_draw::RasterRunner`** (`bash-o4/src/fb_draw.rs`): offscreen
  color+depth target, atlas upload (crack = layer 9), blocks (36-vert
  list, depth on) + overlay (6-vert list, src-alpha) graphics
  pipelines, push constants, readback. Struct layouts verified against
  `vulkan_core.h` (gcc sizeof probe).
- **`tests/fb_dispatch.rs`**: blocks centre pixel == Rust oracle of
  `frag_pixel` (204,0,0 for shade-800 red) + clear corners +
  determinism; overlay opaque green full-screen. Reported skip with no
  device, loud failure on misrender.
- **`--fb-proof[=WxH]`**: the proof scene through the real binary as a
  P6 PPM (translucent-green-over-red exercises the blend path).

### Fixed

- Two emitter bugs the missing dispatch hid (both pinned by
  strengthened unit tests): `gl_InstanceID`/`VertexID` are OpenGL names
  — Vulkan wants `gl_InstanceIndex`/`VertexIndex`; `fy`/`fz` missed the
  `/1e6` milli divisor and exploded verts to ±50000.
- Lavapipe teardown faults found + documented (pool/framebuffer/
  render-pass freed pool-last / cached / device-leaked by design).

Verified 2026-10-12: `cargo test --offline --test fb_dispatch` 2/2 ok,
`--fb-proof=64x64` rc=0 12301-byte P6, `--emit-shader fb-blocks` rc=0.

### Fixed

- **Grass (and every) texture rendered one row + black**
  (`MIMEcroft_fb.sh` `rb_tex_load`, mirrored in
  `src/sh/rb-raster.sh`): the loop ran `N` times where the
  `fb_texture` contract (`sh2perl/runtime/fbdev.c`: `total = n*n`)
  loads `N*N` texels, so a 32×32 texture uploaded 32 texels and
  every sample past the first row read unset (black) slots.
- **Textured surfaces ~2× overbright** (same files, `rb_cube` +
  `rb_frag`): the tint ran at 0..255 with a 255 clamp, but the
  canonical fragment shader (`examples/mimecroft-frag.sh`:
  `vcolor = int(vColor*127)`, `out = vcolor*tex/128`, max 253, no
  upper clamp) quantizes tint×shade to 0..127. Grass (white tint)
  blew out to 255; now byte-exact vs the shader chain on 1120/1120
  probed (tint, shade, texel) combinations, and the grass band
  shares its palette with the oracle frame.
- **Settings menu never displayed in fbview** (`MIMEcroft_fb.sh`
  `settings_menu`/`preview_frame`, 2026-10-14): `draw_settings_menu`
  drew the card into the rows with no present, and every loop iteration
  then wiped it — `preview_frame` ends in `render_frame` (whose first
  op is `rb_clear`) + `rb_present`, the no-preview branch in
  `rb_clear` + `rb_present` — so the file and the window showed the
  bare 3D scene while the menu existed only as terminal echoes.
  `preview_frame` now renders without presenting; the loop tail
  composites once per iteration (3D-or-clear → `draw_settings_card` →
  single `rb_present`). The card draw is split out of
  `draw_settings_menu` (terminal echoes stay once-per-call, safe from
  the 20Hz loop). Verified live: window shows the SETTINGS card over
  the AI preview, SPACE dismisses into the game, in-game frames keep
  presenting (fb hash changes frame to frame).
- **fbview froze on any missed mtime** (`tools/fbview.py`): the window
  repainted only when the fb file's mtime changed, so a coarse
  timestamp or a stalled-then-resumed game left a stale window with no
  recovery. A 1Hz re-read tick now re-presents whenever the pixels
  actually differ (Exposes feed the same pixel-compare path).

### Added

- **`./play.sh`: one-command interactive play** (2026-10-14): builds
  the game if stale (`--build` forces, `--no-build` skips), opens the
  fbview window, runs the game against it (frames via a temp BGRX
  file, window keys back through the queue), and cleans up both plus
  all temp files on exit. ` -- --demo` auto-plays for a smoke test;
  `--scale N` sizes the window. Verified live: menu card over the 3D
  in the window, SPACE in the window dismisses into the game, q quits
  cleanly (game + launcher exit 0, no stray processes or temp files).

### Still open (unchanged)

- The `_sh_gpu_*` host split in generated C; the proof scene is not a
  program payload.

### Performance (offered, sh2perl 22e354c33 — int-element array homing)

- **Transpiled-C game frame: 462ms → 181ms (scene 428ms → 158ms)**
  measured `MIMEcroft_fb --demo` (`#stats avg`, two runs 194/181ms).
  New C-local pass (`SH2_NO_INT_ELEM=1` kills it, C backend only):
  int-store + dense + join-free arrays home as native `long long[]`
  (polygon/texture-index buffers that the shared analysis kept
  `char*`), element-readers and pure-arith temps seed `Int`.
  Frame pixels 99.9987% identical (1 adjacent-texel edge pixel);
  oracle agreement unchanged within tree drift. Unit tests: zero new
  failures. Offered per §11 marketplace (workspace gitlink not bumped
  here — see PLAN.md §11.14). Remaining gap to the ~7ms JS oracle:
  per-pixel argv marshal (int-param ABI), RBTEX texel-parse modeling +
  per-triangle slot-load LICM, row-buffer accumulation.

## 0.1.1 — 2026-09-14

Transpiled GPU (CUDA) reaches parity with hand-written kernels, and the
CPU backend closes the last known codegen gap.

### Added

- **Transpiled CUDA** (`cutranspile` / `bash_o4::cu_run`): bash → ShIR →
  candidacy → PTX → CUDA with **no hand kernels**. `cutranspile
  <script.sh> <N>` prints `<median_ms> <checksum>`; `SKIP …` + exit 2
  when there is no device, no runnable shape, or an extern that needs an
  explicit `--bind VAR=VAL` (values are never guessed).
- **CUDA candidacies** (`cu_candidacy`): *map* (one or more independent
  affine stores), *reduce* (`acc+X`, `acc*X`, `(acc+X)%m`,
  `(acc+X)&mask`, optionally reading an array a fusable map produces),
  and *seq* (a sequential per-lane kernel). Map+reduce over the same
  iteration space **fuse** into two kernels with one array and a
  partials-only readback.
- **Sequential lane-nests** (`shir_passes::lane_private`): a shared
  privatization analysis proving an outer iteration is independent
  (ordered init dominance, chain writes dominated by those inits,
  accumulate only in the tail, pure tests), so one lane can run a whole
  `while` chain — this is what makes `collatz` dispatchable.
- **`fuse-fill-consume`**: a covering array-fill loop plus a same-space
  consumer becomes one loop with the fill's RHS forwarded, and the fill
  and its materialization are deleted. Now handles **multi-store** fills
  (one binding per array).
- **`isolate-accumulate`**: single-use loop-private temporaries fold into
  a self-referential tail, isolating one accumulate statement.
- **Shared maskable / unsigned lowering** (`shir_passes::maskable`) with
  loop versioning: `% 2^k` lowers to `& (2^k-1)` on a verified fast path
  (dividend provably non-negative and nowrap) with a signed slow path.
- **`python-O4`**, a Python front end reusing the same C render, `tcc`
  JIT/AOT and CUDA dispatch (`--gpu`).
- **Vulkan**: per-dispatch pipeline cache (compiled pipeline set keyed by
  SPIR-V hash) and an optional `spirv-opt -O` post-pass.
- **Benchmarks** (`bench/bench.sh`, `bench/bench-opt.sh`) with an
  agreement gate — no row is printed unless every running leg's checksum
  byte-agrees — and the `twoarr`, `hash` cases.
- Build-time content-addressed cache revision (HEAD SHAs + dirt hash of
  the workspace and the sh2perl submodule), so uncommitted edits force a
  cache *miss* rather than serving a stale pre-fix render.

### Measured (see `bench/README.md` for the method)

Per-leg minimum over 3 suite runs of 5 reps, on a shared 8-CPU box.

| problem | N | gcc-O3 | bo4-gcc | cuda (hand) | cuda-tx (transpiled) |
|---|---|---|---|---|---|
| sumred | 1B | 1.107 s | 1.028 s (1.1×) | 0.004 s | 0.004 s (**1.0×**) |
| squares-map | 100M | 0.326 s | 0.115 s (2.8×) | 0.001 s | 0.001 s (**~1×**) |
| twoarr | 50M | 0.423 s | 0.066 s (6.4×) | — | 0.001 s |
| collatz | 18M | 1.365 s | 1.178 s (1.2×) | 0.013 s | 0.014 s (**1.08×**) |

- The **transpiled CUDA leg is level with hand-tuned PTX** (1.0–1.1×) on
  all three shapes that have both, with byte-identical checksums.
- The C column's 2.8×/6.4× on `squares-map`/`twoarr` is **algorithmic**:
  fusion deletes an unobservable intermediate array, so bash-O4 makes one
  pass where the reference makes two. It is not a codegen claim.

### Fixed

- Signed `%` blocking strength reduction (the previous round's identified
  ~2× gap), via the shared maskable analysis + versioning.
- Loop-invariant bound hoisting (LIC), worth ~4–6× on bound-variable loops.

### Open release decisions (not code)

- **Licensing is undeclared.** `bash-o4` links the `sh2perl` core, whose
  `LICENSE` states GPL-3 *with an additional Apache-2.0 permission* for named
  paid-work recipients and their subrecipients. That has no single SPDX id, so
  `Cargo.toml` deliberately carries no `license`/`license-file` key rather than
  a wrong one. Decide before publishing (probably `license-file` pointing at a
  copy of `../sh2perl/LICENSE`).
- **Not `cargo publish`-able**: `../sh2perl` and `../otranspilerl` are path
  dependencies and the frontends build separately.
- **`tcc` is a runtime dependency** for the default (JIT) path, with a loud
  cc/gcc/clang fallback; it is not vendored.

### Known limitations

Recorded in full under "Known limitations" in `README.md` and section 7
of `docs/BASH-O4.md`. The short list:

- Vulkan here is **Lavapipe** (software); the `gpu` column is a scaffold
  measurement, not a hardware claim.
- `tcc` cannot parse glibc `<regex.h>`; the driver falls back to
  `cc`/`gcc`/`clang` **loudly** (never silently).
- The C backend keeps a fixed array-capacity backstop (`ARR_CAP`, 1024)
  for arrays whose size it cannot prove.
- `--gpu` offloads **one loop**, not the whole program: the kernel's trip
  count comes from `--n`/`--bind`, so a loop whose bound the driver cannot
  supply (a function-local) is vetoed by the candidacy, and a program outside
  the single-integer-output contract reports the offloaded loop's checksum
  rather than its stdout. The whole-program host split is the open M3 item.
- `hash` has no hand-written GPU kernel: its `cuda-tx` row is
  correct-and-fast, not proven-optimal.
- `./fail` (Perl corpus) sits at a pre-existing 260/552 baseline owned by
  the ESTree/Perl workstream. The gates for this work are
  `harness/c_gate_main.sh` (637/0/7) and `harness/gpu_gate.sh` (545/0/7).
- Benchmarks ran on a shared box (load average 7–10 on 8 CPUs); ratios
  are stable, absolute seconds are indicative.

## 0.1.0 — 2026-09-13

Initial M1/M2/M4: the `bash-O4` driver (tcc JIT/AOT, artifact cache,
hash-pinned library fetch), GPU-candidacy analysis (`--check`), GLSL-450
shader emission (`--emit-shader`) with SPIR-V proof, and the C/Vulkan
gates.
