# fb0 CPU-path correctness oracles (Phase 0)

These files are **CPU-path** reference outputs for the fb0/MIMEcroft render
pipeline. They exist to lock correctness **before** any GPU dispatch is enabled
or changed: a GPU/`fb_frag` path must match the appropriate CPU oracle within
the tolerance defined below (**refuse > guess** on mismatch — never silently
accept a misrender).

## Captured oracles

| File | Size | State | md5 | bytes | How generated (CPU path) |
|---|---:|---|---|---:|---|
| `f1-320x240.ppm` | 320×240 P6 | MIMEcroft frame 1 (`--first-frame`), default settings (CRT_OFF, CORRUPT_OFF), deterministic | `965f7b3dad4cfd516ff637c8943681bc` | 230415 | `env MIMECROFT_KEYS=/tmp/fb0-oracle/keys ./bash-o4/target/mimecroft-fb-play --first-frame <out.ppm> --view 320x240` |
| `f1-800x600.ppm` | 800×600 P6 | MIMEcroft frame 1 (`--first-frame`), default settings, deterministic | `9e247bc7f5fe65f8be1e09aef420bb41` | 1440015 | same, `--view 800x600` |

Capture context (this baseline): built from `backends-sh-fb0` `fb0-raster`
(e88ecc2e-dirty at capture) with `sh2perl` 3dbb05ec4-dirty; `mimecroft-fb-play`
599880 B, 2026-11-09. Re-capture command (from `backends-sh-fb0/bash-o4`):

```sh
mkdir -p /tmp/fb0-oracle && : > /tmp/fb0-oracle/keys
env MIMECROFT_KEYS=/tmp/fb0-oracle/keys ./target/mimecroft-fb-play --first-frame /tmp/f1-320x240.ppm --view 320x240
env MIMECROFT_KEYS=/tmp/fb0-oracle/keys ./target/mimecroft-fb-play --first-frame /tmp/f1-800x600.ppm --view 800x600
```

## States still requiring deterministic CPU fixtures (follow-up)

Phase 0 calls for fixed scenes/frames covering **overlay/flash, crack,
CRT/corrupt flags**. Frame 1 exercises the base/HUD path but not all of these:
- `CRT_ON`/`CORRUPT_ON` default off and are normally toggled via the settings
  menu (see `MIMEcroft_fb.sh`: `CRT_ON`/`CORRUPT_ON`, `rb_frag_flags`); capture
  needs a scripted-state hook/arg/env or a driven menu sequence.
- **flash** is transient (muzzle lifetime); **crack** depends on damage state.
- fb0 **overlay/flash records** appear in gameplay/HUD paths; capture with
  deterministic gameplay state/seed+input script.

Until those fixtures exist, treat CRT/corrupt/flash/crack GPU parity as
**unverified** (no oracle ⇒ no claim). Add fixtures here with the same
manifest fields before enabling GPU dispatch for those paths.

## Tolerance policy (GPU vs CPU oracle)

- **CPU is the semantic reference.** Any Vulkan init/device/pipeline/dispatch/
  upload/readback error, unsupported capability, `--cpu-only`/`--no-gpu`, or no
  ICD ⇒ take the CPU path. GPU is an optimization, never a semantic change.
- **Refuse > guess.** Unsupported verb/capability/precision/format ⇒ veto or
  CPU fallback with a clear reason (`--check`/`--verbose`), never a silent
  wrong render.
- **Never silently narrow precision** (docs lesson: e.g. i64 requirements).
  Require explicit capabilities at runtime init (not compile time); if absent,
  veto/fallback.
- **Comparison (frame/PPM, RGB):**
  - **Bit-exact** required where `fb_frag.rs`/`fbdev.c` math is documented as
    int/texel-exact under NEAREST (e.g. texel sampling identity, int tint/shade
    paths as transcribed) and for deterministic non-effect content.
  - **Epsilon allowed (per-channel, unless tightened by evidence)** for
    documented float transcription points: tint `r·255+.5` rounding at `.5`
    boundaries, UV interpolation (float vs device double at texel edges),
    overlay corner/rounding, and scanline/CRT/vignette y-flip/phase-sensitive
    math (`py = H−1−frag_y`). Start with max abs diff ≤ 2 per channel and 0
    pixels exceeding it except at those edges; tighten/relax only with measured
    oracle evidence, never to hide a real misrender.
  - A mismatch outside tolerance is a **FAIL** (block dispatch enablement for
    that path). Record the diff image/stats.

## fb_frag proof scene note

`bash-O4 --fb-proof[=WxH]` dispatches the `fb_frag` blocks/overlay fragment pair
via Vulkan and prints P6 (GPU path; exits 2 with no Vulkan device). A full
**CPU** rasterizer for that exact synthetic scene is not yet in-tree (tests
carry a partial Rust `oracle_frag_pixel`, not full geometry). Lock a lavapipe/
device-produced `--fb-proof` reference as a parity target separately, and/or
add a CPU raster harness, before treating proof-scene GPU output as verified.

## Runtime guardrails (to enforce in fb GPU integration)

- Honor `--cpu-only`/`--no-gpu`/`--gpu=off`: no fb GPU dispatch.
- Check capabilities at runtime init (not compile time): Vulkan device present,
  graphics/compute as required, `sampler2DArray`, SSBO/push-constant limits
  sufficient for the `fb_frag` contract, and any required i64/explicit
  arithmetic features; **veto/fallback with a reason** if missing.
- On **any** runtime Vulkan failure (init, pipeline, shader/module, memory,
  descriptor, upload, dispatch/draw, barrier, readback), fall back to the CPU
  path for that operation/frame path as designed — never present corrupted
  partial output. (Wiring belongs in Phase 1/2; this manifest states the rule.)
