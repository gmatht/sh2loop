# General-purpose GPU lift — contract freeze (P0)

Status: **P0–P4 implemented** (2026-11-21/22). P0 (this document, the
second witness, the rename/static gates), P1 (the verdict layer), P2
(the shader binding), P3 (the emitted host split + dispatch) and P4
(present/readback) exist and have been RUN. A recognised draw/present
site in the second witness executes on the GPU, with the CPU call
always emitted and the CPU frame kept whenever the GPU frame does not
match it. P5 (oracle matrix) and P6 (perf) are **not started** — see §8.
No speedup is claimed: see §8.

Companion: `docs/MIMECROFT-GPU-PLAN.md` is the game-side route-A mission.
This document is the compiler capability it reuses; neither supersedes
the other.

## 1. What "general purpose" means here

A lift is general when the compiler matches **contracts that already exist
in the tree**, not the program under compilation. Four:

| | Contract | Recognised by | Owner of the names |
|---|---|---|---|
| C1 | draw submission | `/dev/fb0/{blocks,overlay,overlay_flash}` writes | `sh2perl/runtime/fbdev.h`; lifted by `transforms/fbdev_gpu.rs` |
| C2 | vertex stage | reads `ap_*/ash_*/auv_*/ucp_*/ucy_*/uop_*/usc_*/ublk_*/uov`, writes `vp_*/vc_*/vu_*` | `glsl_backend.rs` (`sh2glsl --vertex`) |
| C3 | fragment stage | reads `frag_x/frag_y/vcolor_*/uv_*/tex_*/damage/cr_*`, writes `putb` | `glsl_backend.rs` (`sh2glsl`) |
| C4 | present | `/dev/fb0/call` with a `swap` payload | `fbdev.h`; refused by `fbdev_gpu_calls.rs` (non-void) |

Every name in that table is an **interface** name — a device verb or a
shader-language bridge. None is an identifier of the program being
compiled. That is the whole naming rule (`MIMECROFT-GPU-PLAN.md` §2):
the compiler may name interfaces, never programs.

The lift is the **binding**: C2+C3 become a graphics pipeline, C1+C4
become dispatch and present. Recognition is structural — a function's
read set, write set, effect set — so a program is a witness only by the
shape of its stages.

## 2. The verdict layer (P1)

`sh2perl/src/shir_passes/gpu_lift/mod.rs`, analysis-only: it returns
verdicts and mutates nothing. `bash-O4 --check` prints one line per site
under a `GPU` label plus `GPU_SITES=<accepted>`; the compute leg's loop
verdicts (`candidacy.rs`) use the same vocabulary through
`GpuLiftVerdict::compute_site`/`compute_veto`.

`GPU_SPLITS=<n>` is printed next to it and counts **what codegen
actually splits**, by counting the calls in the emitted C itself: one
`_sh_gpu_blocks(...)` per accepted `blocks` draw submission and one
`_sh_gpu_stages(...)` per emitted stage split. Present (C4) is an
observation point, not a split: the backend emits `_sh_gpu_flush()`
before `fb_present`/`fb_dump_ppm`. `overlay`/`overlay_flash` are
accepted C1 sites but codegen emits them as plain `fb_overlay(...)`
calls, so they appear in `GPU_SITES` and **not** in `GPU_SPLITS`. A
bound C2/C3 pair counts only when the split was really emitted — SPIR-V
compiled **and** a CPU reference derived (`stage_ref`); a pair the
compiler cannot cover emits neither call and stays in `SITES` only. The
counter therefore cannot rise without an emitted call behind it, and
the gap between the two numbers is a measurement, not an inference.

```text
candidate fragment fn:quad_fragment (glsl 2140 bytes)
candidate vertex   fn:quad_vertex   (glsl 1904 bytes)
candidate draw     fn:draw_two_quads/blocks
candidate present  fn:draw_two_quads/call
veto      fragment fn:shade: uniform-inputs (RBF_CRT)
```

Kinds: `compute | vertex | fragment | draw | present`. A `Site` means
"this would lift"; a `Veto` means "stage-shaped, refused, for this
reason". Nothing is rewritten into the program — no backend changes
behaviour, which is what makes P1 safe to ship before P3.

## 3. The shader binding (P2)

An accepted stage is rendered by the existing front end
(`glsl_backend::shir_to_glsl_opts`), with the options `sh2glsl` documents:
ES 1.00, `color_out` for a fragment stage, `vert_out` for a vertex stage,
`tex_size: 16`, `max_view: 800`.

Two rules keep the emitted text compilable:

- **Closure.** Every read must be a bridge, an output of the same stage,
  or a local the body writes. A read that is none of those is either
  `uniform-inputs` (the program assigns it outside every stage — a
  per-frame uniform) or `unclosed-reads` (nothing binds it). Both refuse,
  because today's front end declares bridges and not uniforms: emitting
  the shader would name an undeclared identifier.
- **Callees.** A called helper is included only when it is pure and
  itself closed over the same bridges (`impure-callee`,
  `callee-unbound` otherwise).

Note honestly: P2's output is *the same function* `sh2glsl` runs, so the
regression value is determinism + rename stability, not an independent
byte-for-byte oracle. The pinned gate is
`witness_shaders_are_bound_and_deterministic`.

## 4. Refusal catalogue (stable strings)

| reason | meaning |
|---|---|
| `params-unsupported` | named parameters, or a positional (`$1`) read: a stage's inputs come from bridges |
| `impure-body` | first host effect: `exec`, `pipeline`, `file-write`, `output`, `capture`, `subshell`, `asm`, `host-status`, … |
| `mixed-stages` | writes both `putb` and `vp_*/vc_*/vu_*` |
| `float-precision` | a var of the stage is typed `Float` — the device path's UV is integer by contract (`PLAN.md` §11.14 records the `double` blocker); a float here is a silent-widening guess |
| `writes-bridge-input` | the body assigns a bridge the host seeds |
| `unclosed-reads` | reads a name nothing binds |
| `uniform-inputs` | reads a program global assigned outside every stage (liftable at P3, with slots) |
| `impure-callee` / `callee-unbound` | a helper is not shader-shaped |
| `shader-emit-failed` | the front end produced no text |
| `present-not-swap` | a `call` payload that is not `swap` |

`uniform-inputs` is a refusal, not an acceptance; it exists so phase 3's
workload is visible instead of hidden inside a generic veto.

## 5. The second witness (P0) — and the first witness's honest score

`sh2perl/tests/fixtures/gpu_lift/two-quads.sh` — two shaded textured
quads, written only against C2/C3 plus one C1/C4 drawer. It is not a
game, not a copy of one, and shares no identifier with the first
witness. The acceptance claim for this mission is that this file goes
through P1 and P2 **with zero compiler edits**.

Measured, not assumed: `bash-O4 --check bash-o4/MIMEcroft_fb.sh`
reports **`GPU_SITES=0`** today. That is correct for this snapshot and
worth recording, because it corrects the plan's own sketch:

- the program's drawing path is the software rasterizer (`rb_*` writing
  pixels), not the device protocol — `fb_blocks` occurs only in its
  comments, and no `fb_*` primitive is called;
- its fragment stage is program code (`rb_frag` over program globals),
  not bridge-contract code: `putb` and `frag_x` appear **zero** times in
  `bash-o4/MIMEcroft_fb.sh` (the C fragment is `fbdev.c:frag_pixel`).

So the first witness contributes no C1–C4 site until either the
MIMEcroft plan's phase 1 (`MIMECROFT_DRAW=blocks`, device payload) or
route B (rasterizer shape synthesis, deferred) lands. Generality for
this mission rests on the second witness, which is exactly why the plan
made it a gate instead of a nice-to-have.

## 6. What dispatches now (P3/P4), and what is refused

### 6.1 The emitted split

`c_backend.rs` emits the split **at the accepted draw site**, not in a
side table, so the CPU call is present in the generated C by
construction:

```c
/* two-quads.sh, --emit-c */
(((_sh_gpu_blocks("0 0 0 1 1 1 1 0 0 0 0\n8 0 0 1 1 1 0 1 0 0 0")) ? (void)0
   : (void)(fb_blocks("0 0 0 1 1 1 1 0 0 0 0\n8 0 0 1 1 1 0 1 0 0 0"))));
...
_sh_rc = (_sh_gpu_flush(), (fb_dump_ppm(path)));
```

`fb_present()` is wrapped the same way when it survives into the render.
It does not survive in this witness — the device transform eliminates a
present that has nothing to present — which is exactly why `GPU_SPLITS`
counts draws and not presents. The payload is a single-value word by
`fb_word_one_value`'s gate, so evaluating it in both arms has no side
effects; the flush is a comma expression, so the primitive's own status
value is byte-for-byte what it was before.

### 6.2 The runtime

`sh2perl/runtime/fb_gpu.c` now holds the emitted call sites:

- `_sh_gpu_blocks(payload)` — 1 means the GPU took the draw (CPU call
  skipped, payload remembered for a CPU replay); 0 means the CPU call
  runs. It refuses with a stable reason on: no host library, missing
  `bash_o4_fb_gpu_*` symbols, no Vulkan graphics device, a refused
  device open, or a refused draw. A frame is **all-or-nothing**: after
  one refusal every later site in the frame is CPU, so a frame can never
  be half GPU and half CPU.
- `_sh_gpu_flush()` — emitted before anything can observe the frame.
  It reads the GPU frame back and reconciles it with the device surface;
  on any failure it replays the queued payloads through `fb_blocks`, so
  the frame exists even when the GPU path died after taking the draws.

A generated program is a **separate executable** (tcc compiles and
execs it), so the Rust host is reached by `dlopen`, not by a link-time
symbol: `SH2_FB_GPU_LIB` names the shared library and defaults to
`libbash_o4.so` (the soname cargo builds). `bash-O4` links
`fb_gpu.c` only when the render names `<fb_gpu.h>`, which the backend
emits only when it actually split a call — a program with no accepted
site links exactly what it linked before.

**Dispatch is opt-in: `SH2_FB_GPU=1`.** Unset and `=0` are CPU runs, and
they are *different* refusals with different reasons ("you never asked"
vs "you turned it off"), because a device being present must never
change a program's output on its own.

### 6.3 The refusal is loud, and it names itself

A refusal is only useful if it is visible. Every runtime refusal sets one
stable reason string, writes it to the log (`SH2_FB_GPU_LOG`, default
`/tmp/sh2-fb-gpu.log`), and — when the run asked for the GPU
(`SH2_FB_GPU=1`) or for a log — prints it to **both** stdout and stderr as
`fb_gpu: REFUSED: <reason>`, flushed.

Both streams, because neither works alone: a render with shell-out sites
silences its own stderr in `main` (`freopen("/dev/null", "w", stderr)`),
which is exactly the second witness — so a stderr-only refusal was
invisible there (measured). A plain CPU run (no `SH2_FB_GPU`, no log env)
prints nothing and writes no line, so this can never change an ordinary
run's stdout. The frame/data output is untouched: only the diagnostic
line is added, and only in a run that explicitly enabled the GPU.

The log distinguishes the two outcomes by tag, never by a number a reader
has to interpret:

- `dispatch: frame … dispatched=N` — a verified GPU frame was used.
- `refused: no GPU frame: <reason>` / `refused: frame … reason=<reason>` —
the CPU frame is the output. A refused frame never logs `dispatch`.

| reason (stable, verbatim) | when |
|---|---|
| `GPU not enabled (set SH2_FB_GPU=1) [step:init] -> CPU path` | `SH2_FB_GPU` unset |
| `GPU disabled (SH2_FB_GPU=0) [step:init] -> CPU path` | `SH2_FB_GPU=0` |
| `CPU-only forced (SH2_FB_CPU_ONLY=1) [step:init]` | `SH2_FB_CPU_ONLY=1` |
| `GPU host library not loadable (<path>; set SH2_FB_GPU_LIB to libbash_o4.so) [step:host_dlopen]: <dlerror>` | missing/invalid `SH2_FB_GPU_LIB` (default `libbash_o4.so` not on the loader path) |
| `GPU host library is missing the bash_o4_fb_gpu_* symbols [step:host_symbols]` | a library that loads but is not the host |
| `GPU host reports no Vulkan graphics device [step:device_probe] -> CPU fallback` | no graphics-capable device (e.g. `VK_ICD_FILENAMES` pointing nowhere) |
| `GPU device open refused <w>x<h> [step:device_open]: <host error>` | the host refused the runner |
| `draw refused by GPU host [step:draw_blocks]: <host error>` | per-draw refusal (e.g. malformed payload) |
| `GPU frame differs from the CPU frame (<N> px, max_abs=<M>) [step:verify] -> CPU frame kept` | the parity gate (currently 8 px — see §6.5) |
| `readback buffer allocation failed [step:readback]` / `GPU readback refused [step:readback]: <host error>` | readback failure |

### 6.4 Measured refusal matrix

The second witness, `SH2_FB_GPU=1`, each configuration compared against
the `SH2_FB_GPU=0` PPM (9229 bytes):

| configuration | exit | PPM | first printed line |
|---|---|---|---|
| `SH2_FB_GPU` unset | 0 | identical | `fb_gpu: REFUSED: GPU not enabled (set SH2_FB_GPU=1) [step:init] -> CPU path` |
| `SH2_FB_GPU=0` | 0 | identical | `fb_gpu: REFUSED: GPU disabled (SH2_FB_GPU=0) [step:init] -> CPU path` |
| `SH2_FB_GPU_LIB=/nonexistent/libbash_o4.so` | 0 | identical | `… GPU host library not loadable (…): … No such file or directory` |
| `SH2_FB_GPU_LIB=/etc/hostname` | 0 | identical | `… GPU host library not loadable (/etc/hostname; …): /etc/hostname: file too short` |
| `VK_ICD_FILENAMES=/nonexistent-icd.json` | 0 | identical | `… GPU host reports no Vulkan graphics device [step:device_probe] -> CPU fallback` |
| valid host + device | 0 | identical | `… GPU frame differs from the CPU frame (8 px, max_abs=77) [step:verify] -> CPU frame kept` |

Every row exits 0, every PPM is byte-identical to the CPU run, and every
row's log line is tagged `refused:`, never `dispatch:`.

### 6.5 The parity gate is the default

The GPU fragment/raster implementation is a second implementation of
fbdev's rules. Two real bugs were found and fixed by running it against
the device (both made the GPU frame *blank*, not merely different):

- **Units.** The `fb_blocks` payload's scale is in WORLD units and
  `fbdev.c` converts once (`v[3] * 1000.0`, milli) before `draw_cube`.
  The GPU parser passed it through unscaled, so every witness cube was
  rendered 1000× too small and the GPU frame had zero lit pixels.
  Fixed in `fb_gpu_ffi.rs::parse_blocks_payload`.
- **Handedness and y orientation.** fbdev's payload is −z-forward
  (`to_view` keeps `w = -rel.z`); the graphics vertex stage is
  +z-forward (the convention of `tests/fb_dispatch.rs`, `--fb-proof`
  and the byte-pinned SPIR-V). The FFI now reflects the scene exactly
  (camera x/z and shift, every record's x/z — a point reflection) and
  the readback un-mirrors both axes; that is an index permutation, not
  a tolerance. The shader source is unchanged because there is no
  SPIR-V compiler on this box and the embedded bytes are pinned.

After those fixes the frame is geometrically right and **8 of 3072
pixels still differ**, all in row 27. This one is *not* fixed:

| pixel | CPU | GPU |
|---|---|---|
| (30..33, 27), (59..62, 27) | `quad 1` (bottom face, shade 500 → `0x80`) | `quad 3` (side face, shade 800 → `0xcc`) |
| row 26 and (63, 27) | `quad 3`/`quad 4` (`0xcc`) | same |

Measured by instrumenting the device through `BASH_O4_FBDEV_DIR` and
logging face and colour per pixel, not inferred. Cause: fbdev's
rasteriser keeps a pixel when *every* half-plane test is `>= 0`
(`tri_covers`), so at the cube's shared bottom-front edge the bottom
face and the side face **both** cover the boundary pixel, and painter
order leaves the bottom face's colour. Vulkan's top-left rule assigns
that shared edge to exactly one triangle — the side face — so its
colour wins. No pipeline state changes coverage (painter order and
depth both read the same coverage), so this cannot be closed without
either a compute/software rasteriser that reimplements the `>= 0` rule
or a change to fbdev's fill rule (which would alter the CPU device's
own pixels and its byte parity with bash). The gate therefore stays
strict and refusing; nothing is masked, widened or skipped. So a
GPU-enabled run compares its read-back frame against the CPU frame for
the same payloads and **keeps the CPU frame** on a mismatch, with the
reason `GPU frame differs from the CPU frame (N px, max_abs=M)
[step:verify] -> CPU frame kept`. `SH2_FB_GPU_PROVE=raw` opts into the
GPU-authoritative frame; that switch is the only difference, and it is
not the shipping default until the shaders reach byte parity.

### 6.6 Measured end to end with a device

```text
$ bash-O4 --check sh2perl/tests/fixtures/gpu_lift/two-quads.sh
GPU candidate draw fn:draw_two_quads/fb:fb_blocks
GPU candidate present fn:draw_two_quads/fb:fb_present
GPU candidate vertex fn:quad_vertex (glsl 2254 bytes)
GPU candidate fragment fn:quad_fragment (glsl 1132 bytes)
GPU_SITES=4
GPU_SPLITS=2

$ bash-O4 --check sh2perl/tests/fixtures/gpu_lift/hud-bar.sh
GPU candidate draw fn:draw_bar/fb:fb_blocks
GPU candidate present fn:draw_bar/fb:fb_present
GPU candidate vertex fn:bar_vertex (glsl 2024 bytes)
GPU candidate fragment fn:bar_fragment (glsl 921 bytes)
GPU_SITES=4
GPU_SPLITS=2

$ SH2_FB_GPU=0 bash-O4 <witness> -- /tmp/cpu.ppm     # 9229 bytes
$ SH2_FB_GPU=1 SH2_FB_GPU_LIB=bash-o4/target/debug/libbash_o4.so \
    bash-O4 <witness> -- /tmp/gpu.ppm               # 9229 bytes
$ cmp /tmp/cpu.ppm /tmp/gpu.ppm                     # identical, both

# two-quads.sh — /tmp/gpu-gpu.log, then the PPM comparison
stage-dispatch: generated stage pair dispatched (vert=5392 frag=2700 bytes; drawn into the frame)
step: step=verify detail=GPU frame matches the CPU firewall (0 differing px, max_abs=0) -> GPU frame presented
dispatch: frame 64x48 draws=1 dispatched=1 mismatch=0 refusals=0 fallback=0 reason=(none)
cmp: identical 9229/9229 bytes

# hud-bar.sh — /tmp/gpu-gpu.log, then the PPM comparison
stage-dispatch: generated stage pair dispatched (vert=4916 frag=2272 bytes; drawn into the frame)
step: step=verify detail=GPU frame matches the CPU firewall (0 differing px, max_abs=0) -> GPU frame presented
dispatch: frame 64x48 draws=1 dispatched=1 mismatch=0 refusals=0 fallback=0 reason=(none)
cmp: identical 9229/9229 bytes
```

Two real Vulkan passes run per witness: the blocks draw and the generated
stage pair. The stage pass **loads** the colour target (it is one more
draw in the frame, not a frame reset), and the parity gate compares the
readback against the CPU firewall for the same frame.

That CPU frame is derived by the compiler, not by the program. `stage_ref`
evaluates the SAME bound stage functions the SPIR-V was compiled from —
the host's fixed quad (aPosition ±1, aShade 1, aUv 0/1, uObjPos 0,
uScale 1, uBlockColor 1), the bridge seeds the shader front end emits
(`vcolor_* = int(vColor.* × 127)`, texels from the build-time atlas) — and
reports the rectangle and colour the pair draws. It emits
`fb_stage_ref(...)` beside `_sh_gpu_stages(...)`:

```text
# two-quads.sh --emit-c — the emitted stage-split call site, verbatim
    _sh_rc = (fb_stage_ref(0, 0, 700, 450, 14, 14, 14), _sh_gpu_stages(_sh_stage_vspv, sizeof _sh_stage_vspv, _sh_stage_fspv, sizeof _sh_stage_fspv), _sh_gpu_flush(), ((fb_present()) - 1));

# hud-bar.sh --emit-c — the emitted stage-split call site, verbatim
    _sh_rc = (fb_stage_ref(175, -125, 550, 300, 9, 19, 40), _sh_gpu_stages(_sh_stage_vspv, sizeof _sh_stage_vspv, _sh_stage_fspv, sizeof _sh_stage_fspv), _sh_gpu_flush(), ((fb_present()) - 1));

# occurrences in each emitted C (_sh_gpu_blocks( / _sh_gpu_stages( / fb_stage_ref()
two-quads: 1 / 1 / 1      hud-bar: 1 / 1 / 1      refuse-fragx: 1 / 0 / 0
```

Neither fixture carries a number for it: there is no `fb_overlay` in
either the C or the source, and the second witness is an off-centre bar
with a different scale on each axis and a non-grey colour, so nothing
about the first witness's numbers could produce the second's.

**The second witness found a real bug.** The runner reads the target back
through a 180° index permutation (`readback_bgrx`), because the blocks
pipeline reflects its scene to match fbdev's handedness. A stage quad is
not reflected that way — a stage need not be odd in x — so `hud-bar`'s bar
(=0.175 NDC) landed 11 px LEFT of centre while its CPU reference was right
of it (`308 px, max_abs=68`). The first witness is symmetric in x and
cannot see this. The 450 lowering now applies the frame's x convention to
the stage's OUTPUT (`sh_stage_main()` + `gl_Position.x = -gl_Position.x`),
and both witnesses pass with `0 differing px`.

#### The refusal witness, measured

`refuse-fragx.sh` binds a fragment stage that reads `frag_x` (a per-pixel
bridge the reference cannot represent), and draws one cube:

```text
$ bash-O4 --check sh2perl/tests/fixtures/gpu_lift/refuse-fragx.sh
GPU candidate draw fn:draw_edge/fb:fb_blocks
GPU candidate present fn:draw_edge/fb:fb_present
GPU candidate vertex fn:edge_vertex (glsl 1371 bytes)
GPU candidate fragment fn:edge_fragment (glsl 767 bytes)
GPU_SITES=4
GPU_SPLITS=1

$ bash-O4 --emit-c sh2perl/tests/fixtures/gpu_lift/refuse-fragx.sh >/dev/null
bash-O4: stage-reference-uncovered: the stage reads 'frag_x', which the stage host does not supply

$ SH2_FB_GPU=0 ... refuse-fragx.sh -- /tmp/cpu.ppm     # 9229 bytes
$ SH2_FB_GPU=1 ... refuse-fragx.sh -- /tmp/gpu.ppm     # cmp: identical to the CPU PPM

# /tmp/gpu-gpu.log
refused: frame 64x48 draws=1 dispatched=0 mismatch=1 refusals=0 fallback=0 reason=GPU frame differs from the CPU frame (4 px, max_abs=77) [step:verify] -> CPU frame kept
```

The pair is still an analysed site (`SITES=4`) but emits no
`_sh_gpu_stages(` and no `fb_stage_ref(`, so `SPLITS=1`: the split
counter is taken from the C, not from the analysis. The frame refuses
rather than matching because that lone cube hits the fill-rule
divergence of §6.5 (4 px, max_abs 77) — and the refusing run keeps the
CPU frame, which is why the two PPMs are identical while the GPU frame is
discarded. The two dispatching witnesses keep their cubes off that edge
class (and the bar's quad covers the sliver the lone cube exposes); the
divergence itself is open, and a payload that hits it refuses rather than
being counted as a match.

### 6.7 What is still refused

- **Vertex/fragment stage dispatch is landed, with a stated coverage
  boundary.** The compiler compiles the bound C2/C3 pair at build time,
  embeds the SPIR-V, derives the pair's CPU reference (`stage_ref`),
  emits both calls; the host builds a pipeline from those bytes, draws the
  quad into the frame, and the flush verifies it against the reference
  before presenting. What is NOT covered, and refuses by name instead of
  guessing:
  - a vertex output that is not an axis-aligned NDC rectangle (a rotated
    or non-affine quad has no rectangle to compare against);
  - `vColor` varying across the quad, or a fragment reading a per-pixel
    bridge (`frag_x`/`frag_y`, `uv_*`), `cr_*` or `damage` — the
    reference is one colour, so a per-pixel stage would be a guess;
  - a texture layer that is not uniform in the build-time atlas (the
    runtime may upload a different one).
  `refuse-fragx.sh` is the gate: the compiler prints
  `stage-reference-uncovered: the stage reads 'frag_x', ...`, emits NO
  split, and `--check` reports `GPU_SPLITS=1` for a program with a bound
  pair — the counter never counts a dispatch that cannot be verified.
- **`fb_overlay`/`fb_overlay_flash` dispatch.** Emitted as CPU calls;
  the overlay pipeline exists (`fb_draw::draw_overlay`) but the payload
  contract is not bound through the host split.
- **Shader parity.** The 8-pixel fill-rule mismatch above: real,
  measured, localised and not faked away — it is why the parity gate
  defaults on, and it needs a software rasteriser (or a changed device
  fill rule) rather than a tolerance.
- **Uniform slots** (`uniform-inputs`), unchanged: a stage that reads a
  program global assigned outside every stage still refuses by name.
- **No speedup is claimed.** The parity gate still computes the CPU frame,
  so a GPU-enabled run does strictly more work; what the split buys today
  is that the presented frame is GPU-produced *and* verified against a
  compiler-derived reference. Performance is P6, not this milestone.

## 7. Gates

- `harness/gpu-rename.sh` — runs the `gpu_lift` test set (witness,
  rename, negative controls) then the static guard. The rename test
  rewrites every identifier the witness owns to a `zz_` prefix and
  requires identical verdicts and identical shader text modulo that
  prefix.
- `harness/gpu-static-guard.sh` — no `rb_`, `MIME`, `RFB_`, `RBTEX_`,
  `SCOS`, `SSIN` in `sh2perl/src/**` outside comment lines and
  `#[cfg(test)]` modules. Fails on introduction, not on review.

  **The tree did not satisfy this rule when the gate landed.**
  `c_backend.rs` carries rasterizer fast paths written against one
  program: `rb_clear`/`rb_putrun`/`rb_present` special cases, `RFB_PIX`/
  `RFB_ROWS` array hooks, an `RBTEX` prefix test. Measured debt is
  budgeted in `harness/gpu-static-guard.allow` (11 `rb_`, 16 `RFB_`, 1
  `RBTEX`, 1 `MIME` line). The gate passes at budget with the debt
  printed, and fails on any NEW coupling (a count over budget or an
  unlisted file). That is a ratchet, not an exemption: shrinking a
  count is always allowed and lowers the budget in the same commit; the
  deletion of those fast paths is tracked as follow-up work, not
  pretended away.
- Negative controls in the same test set: an impure stage refuses
  (`impure-body`); the same body under a neutral name lifts; an unbound
  read refuses; a mixed stage refuses; a non-`swap` `call` is a
  `present-not-swap` veto, not silence.
- Neutrality: P1/P2 touch no renderer, so the corpus gate and both
  `--cpu-only` paths are unchanged by construction. The `GPU` lines in
  `--check` are additive; `tests/check.rs` and `tests/flag_parity.rs`
  assert format, not equality. The split itself is opt-in by contract:
  with `SH2_FB_GPU=0` or on any refusal the emitted CPU call runs, and
  the disabled run links the same runtime either way.
- Split/codegen agreement: `GPU_SPLITS` is counted FROM the emitted C —
  one `_sh_gpu_blocks(` per accepted `blocks` draw plus one
  `_sh_gpu_stages(` per emitted stage split. Measured: both witnesses
  `_sh_gpu_blocks(`=1, `_sh_gpu_stages(`=1, `fb_stage_ref(`=1,
  `GPU_SPLITS=2`, `GPU_SITES=4`; `refuse-fragx` `_sh_gpu_stages(`=0,
  `fb_stage_ref(`=0, `GPU_SPLITS=1` while the pair is still an analysed
  site. A site counted in SPLITS with no emitted call behind it would be
  a lie, and counting the C is what makes that impossible.
- Tooling: `--test fb_dispatch` and `--test fb_spv_regen` need a
  SPIR-V compiler. `glslang 16.6.0` is now **pinned** (manifest entry
  `glslang`, Linux x86_64 release tarball, sha256 re-verified on every
  use, unpacked to `<cache>/bash-o4-fetch/glslang/bin/glslangValidator`
  by a `toolchain` entry). `SH2_FB_SPV_FETCH=1` lets a test fetch it;
  `--prefetch --fetch-libs=auto` warms it for CI. With the pinned
  compiler present `fb_dispatch` runs lavapipe for real and passes
  (§6.6); without one it reports the missing compiler rather than
  passing silently. `--test flag_parity` still needs
  `sh2perl/frontends/py-sh-go`, which this checkout does not contain.
- Embedded-byte drift: `harness/fb-spv-check.sh` recompiles the four
  shaders from `fb_frag.rs` and byte-compares them with
  `src/fb_spv/*.spv`; a flipped byte fails with both sha256s
  (`harness/fb-spv-check.sh --update` regenerates files and
  `manifest.json`). 16.6.0 reproduces the committed bytes exactly, so
  the pin does not change what the runtime executes.

## 6.8 Stage dispatch (C2/C3): what is missing, precisely

A bash program's stages are *recognised and bound* (`--check` prints
`GPU candidate vertex fn:quad_vertex (glsl 2254 bytes)` and the
fragment one) but they are **not dispatched**, and the reason is not a
wiring gap — the bound text is not compilable for Vulkan at all:

```
$ glslangValidator -V -S vert /tmp/stages/vert.glsl
ERROR: #version: ES shaders for SPIR-V require version 310 or higher
ERROR: vert.glsl:5: 'attribute' : Reserved word.
$ glslangValidator -V -S frag /tmp/stages/frag.glsl
ERROR: #version: ES shaders for SPIR-V require version 310 or higher
ERROR: frag.glsl:6: 'varying' : Reserved word.
```

Two of the three blockers are now cleared and tested:

- **Dead string stores are eliminated at the source.** A stage body like
  `fx=$frag_x` (never read) lowered to `cat(itos(g_frag_x), ivec2(0, 0))`
  with no string runtime emitted, so the text compiled under no compiler.
  `glsl_backend` now tracks read variables (`read_vars`, never fed by
  assignment targets) and drops a non-numeric store whose target is never
  read. No `cat`/`itos`/`s_tab` appear in the bound stages, and the
  shader stays rename-invariant.
- **Generated stages lower to Vulkan GLSL 450 and compile.**
  `fb_frag::stage_vulkan_glsl` maps the emitted ES to 450 —
  `attribute`→`layout(location=N) in` in the device vertex-stream order
  (`aPosition`0, `aShade`1, `aUv`2), `varying`→`layout(location=N)
  out|in` (`vColor`0, `vUv`1), plain uniforms→one `push_constant` block,
  `sampler2D`→`set=0,binding=0`, `texture2D`→`texture`,
  `gl_FragColor`→`layout(location=0) out vec4`. It is total-or-refuse:
  an unmapped attribute/varying is an error, not a silent drop.
  `tests/stage_vulkan.rs` compiles the *compiler's own* witness pair
  through it with the pinned glslang (vert 5208 B, frag 2700 B) — no
  hand-written 450 shader sits beside generated text.

The runner now has the stage-pipeline plumbing: `fb_draw` declares
vertex input (one interleaved buffer, stride 32: `aPosition` vec3 @0,
`aShade` vec3 @12, `aUv` vec2 @24), resolves `vkCmdBindVertexBuffers`,
compiles a `stage_pipe` lazily from the pair's SPIR-V and draws it with
`draw_stages` into the same colour target `draw_blocks` uses. It **draws on lavapipe**: a screen-aligned quad through the generated
pair produced 968 lit pixels (`stage_vulkan: generated_stage_pair_draws`).
Two real bugs were found on the way, both ours:

- `VkVertexInputCreateInfo` was missing `#[repr(C)]`, so Rust laid it out
  sType@24 / pBindings@8 (40 bytes) and the driver read a count and a
  pointer from the wrong offsets → SIGSEGV in
  `vkCreateGraphicsPipelines` whenever a binding was supplied. A layout
  test (`fb_draw::layout_tests`) pins 48 bytes, sType@0, flags@16,
  count@20, pBindings@24, attrCount@32, pAttrs@40.
- The stage pipeline inherited the overlay's alpha blend, but the
  bridge's `putb` has no alpha byte (out_buf[3] = 0), so a correct frame
  blended to black. Blocks and stage pipelines are now opaque; only the
  overlay pipeline (kind 1) blends.

Milli→clip needs no conversion: the emitted vertex stage writes
homogeneous coordinates with `vp_w = 1000`, and the rasteriser's w
divide yields NDC = vp_x/1000 — measured by the quad drawing at
|NDC| = 0.7 for ap_±1000 with scale/colour supplied as world units
(the stage's own `int(u*1000.0)` is fbdev's milli convention).

Earlier evidence of the fault (before the ABI fix):

```
$ cargo test --test stage_vulkan generated_stage_pair_draws -- --ignored --nocapture
step: drawing
 dbg: modules ok attrs=true
 dbg: set layout ok
 dbg: pipe layout ok
process didn't exit successfully: …stage_vulkan… (signal: 11: SIGSEGV)

# same pipeline with vertex input disabled (with_attrs=false):
$ … --nocapture
dbg: pipe layout ok / stage pipe ready / recorded
step: readback ok
stage_vulkan: 0 lit pixels through the generated-stage pipeline   (no attributes ⇒ no vertices)
```

The test is `#[ignore]`d with that reason, so the suite stays honest:
the pipeline-with-attributes path is written but cannot be exercised
on this driver until the crash is understood (the attribute structs are
Vulkan-sized and `s_type` is 19; a 0-attribute pipeline of the same
shaders builds and dispatches, so the fault is specifically the vertex
input state in lavapipe).

The remaining gap is the dispatch side, not the shader:

1. **Pipeline + host split.** There is no `_sh_gpu_stages` emission yet;
   `draw_stages` exists but no generated C calls it. An unmappable stage
   pair refuses through `stage_vulkan_glsl` with a stable, prefixed
   reason (`stage-pair-unmappable: unmapped vertex attribute '<name>'`,
   asserted exactly by `tests/stage_vulkan`), and binds nothing.
2. **A CPU oracle for the acceptance fixture.** The fixture must compute
   the maths the CPU path already computes (`fb_blocks`/`frag_pixel`);
   until such a fixture exists, `--check` keeps counting only the draw
   split, and a pair without a CPU reference must veto, not dispatch.

Historically, before those fixes the bound stages were GLSL ES 1.00
(`attribute`, `varying`, `gl_FragColor`, mandatory `precision`), and
`glslangValidator -V` refused them outright (below). The lowering above
is what removes that refusal; the pipeline work is what remains.

1. **A Vulkan emission mode** in the sh→GLSL backend: `#version 450`,
   `layout(location=N)` on every stage input/output, uniform data in a
   push-constant or UBO block, `texture()` instead of `texture2D`, and
   `layout(location=0) out vec4` instead of `gl_FragColor`. This is a
   front-end feature, not a rewrite of the lift.
2. **A vertex-input model.** The device payload is cube records; the
   bridge contract reads per-vertex `aPosition/aShade/aUv` plus camera
   uniforms. The host must expand records into the same 24-vertex
   stream the device uses and bind it, otherwise the stage has nothing
   to run on.
3. **A CPU oracle for arbitrary stages — DECIDED.** The CPU has no
   implementation of a user-written stage pair, and a per-fixture oracle
   is not a compiler capability. The answer is the compiler-side
   evaluator in `stage_ref`: it runs the bound stage functions over the
   host's fixed quad and reports the rectangle and colour as the pair's
   CPU implementation. It covers stage pairs whose output is an
   axis-aligned rectangle of one colour with constant varyings and no
   per-pixel or non-uniform texture reads, and it REFUSES the rest by
   name (`stage-reference-uncovered: ...`) so those pairs never dispatch.
   The GPU-authoritative mode (`SH2_FB_GPU_PROVE=raw`) remains an
   explicit switch, never the default.

`--check` now reports exactly what codegen emitted: two witnesses read
`GPU_SITES=4 GPU_SPLITS=2`, and the uncovered pair reads
`GPU_SITES=4 GPU_SPLITS=1`. That is not under-reporting — the counter is
taken from the calls in the generated C.

## 8. What is deferred (and why)

- **Speedup.** None is demonstrated, and none is claimed. The parity
  gate deliberately still computes the CPU frame (it is the oracle), so
  a GPU-enabled run does strictly more work than a CPU-only one. P6's
  perf work is the measurement that must come before any number.
- **P5 oracle matrix.** Byte parity only for the integer shader;
  lavapipe and hardware labelled separately.
- **Uniform slots.** `uniform-inputs` is the gate that tells P3 how much
  workload it unblocks: a stage that reads a program global assigned
  outside every stage refuses by that name instead of failing later on an
  undeclared GLSL identifier. The control for it is synthetic
  (`host_global_is_reported_as_a_uniform`) because no witness in this
  snapshot has a bridge-contract stage yet — see §5.
- **P5 oracle matrix / perf.** Unchanged from `MIMECROFT-GPU-PLAN.md`
  §6: byte parity only for the integer shader, lavapipe and hardware
  labelled separately.
- **G2 (rasterizer shape synthesis).** Not attempted; each shape class
  needs its own law. No approximation may stand in for the integer fill
  rule, painter order, AA or fixed-point UV — a shape that cannot be
  reproduced exactly refuses.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                