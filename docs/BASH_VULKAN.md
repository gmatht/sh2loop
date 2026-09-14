# BASH→Vulkan: generated-code investigation, optimisations, improvements

Status: investigation + implemented optimisations (2026-09-13). Companion
to `docs/BASH-O4.md` §4.4/§4.7/§4.9(M3/M5). Scope: what the emitter
(`sh2perl/src/vulkan_backend.rs`) and the host runner
(`bash-o4/src/vkffi.rs`) generate for real bash loops, measured on
Lavapipe (software Vulkan 1.4, llvmpipe) + `glslangValidator` 15.1.0,
and what we changed as a result. All numbers are wall-clock on this
box; lavapipe runs on the same CPU it is compared against, so ratios —
not absolutes — are the portable finding.

## 1. What the pipeline generates today

Candidacy (`bash-o4 --check`) accepts counted loops whose bodies are
independent affine `arr[a*i+b] = arith(+,-,*)` stores over i64-proven
values, e.g. `for ((i=0;i<1024;i++)); do a[$i]=$((i*i)); done`:

```glsl
#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_a { int64_t data_a[]; };
const uint64_t TRIPS = 1024u;
void main() {
  uint64_t t = gl_GlobalInvocationID.x;
  if (t >= TRIPS) return;
  int64_t i_ = int64_t(t);
  data_a[uint(t)] = (i_ * i_);
}
```

(SPIR-V verified with `spirv-dis`/`spirv-val`; dispatch verified lane by
lane in `tests/vk_dispatch.rs`.)

## 2. Measured baseline (before this round)

`squares` loop, per-dispatch ms (5 reps, warmup discarded) vs a native
Rust loop doing identical work:

| trips | GPU (old) | CPU loop | winner |
|---|---|---|---|
| 1K | 1.62 | 0.03 | CPU 57× |
| 16K | 1.89 | 0.28 | CPU 7× |
| 64K | 2.14 | 1.42 | CPU 1.5× |
| 256K | 5.83 | 5.47 | tie |
| 1M | 15.9 | 33.4 | GPU 2.1× |
| 4M | 45.4 | 113.7 | GPU 2.5× |

GPU time is nearly FLAT below 64K ⇒ ~1.5 ms fixed per-dispatch cost
dominates: the runner recreated shader module + pipeline + layouts +
pool + set + command pool/buffer + fence on EVERY call (plus a dummy
1-slot `in_data` buffer even with zero externs). Crossover ≈ 250K.

End-to-end program context (same box): bash 1M scalar accumulate
4.9 s vs bash-O4 (tcc C) 0.036 s (136× — the CPU story alone is
dramatic); bash 100K array-squares 0.6 s. Note the C backend's fixed
array cap fails past ~1K elements (`sh2c: capacity exceeded`) where
the GPU path sizes SSBOs by trips (4M verified) — large arrays are a
GPU advantage independent of speed.

Fair-baseline correction: the table above compares GPU array-*writes*
(+8 MB readback) against a CPU *register accumulate* (no stores) —
that flatters the CPU. Handwritten C that also writes `out[i]=i*i`
and sums it back: **6.0 ms at 1M** (and its store loop *does*
vectorise). The honest lavapipe gap is ~2× (11.4 vs 6.0), not ~4×.

SPIR-V anatomy findings (`spirv-dis` on the squares shape):

1. Dead ALU: `i_ = LO + t*STEP` compiled to `IMul(t,1)` + `IAdd(0,·)`
   for the common lo=0/step=1 case (glslang doesn't fold them).
2. A `uint64_t` invocation index is illegal for `[]` (spec) — the
   `uint(t)` conversion is mandatory, not stylistic.
3. `restrict` on SSBO blocks compiles to real `Restrict` decorations
   (sound here: distinct host allocations, read-only input).
4. `spirv-opt -O`: −28% blob size with dead-ALU folding on this shape.

## 3. Implemented this round (with measurement arcs)

9. **Unroll (4 lanes/invocation), with a negative result kept honest.**
   First attempt (straightline blocks, shared mutable counter) LOST
   everywhere (64K: 1.29→2.30 ms) — more than noise. The hand-written
   loop-form probe won (~1.25×), so the emitter uses loop form with
   per-element guards (exact tails for any trip count; candidacy sets
   unroll=4 iff trips % 4 == 0, where guards provably never fire).
   Paired best-of-7 scalar-vs-unroll (same noise window):

   | trips | scalar | unroll | CPU loop |
   |---|---|---|---|
   | 16K | 0.98 | 1.14 | 0.35 |
   | 64K | 1.38 | 0.95 | 1.56 |
   | 256K | 2.46 | 2.61 | 7.90 |
   | 1M | 7.91 | 7.34 | 23.8 |

   Wash to +45%, size-dependent (small loops pay base math + guards
   for too few lanes). Kept: exact-tiling unroll is never wrong, and
   on real GPUs fewer waves + identical coalescing is strictly less
   scheduler pressure (the lavapipe numbers understate that case).
10. **Block reduction (M5 ceiling probe, not shipped).** Per-workgroup
    tree reduction in shared memory → 4096 partial sums → host finish:
    **7.1 ms at 1M** vs 11.4 scalar-full-readback vs 6.0 fair-C. Reading
    back 32 KB instead of 8 MB nearly closes the gap — this is the
    documented path for scalar accumulates (M5), mirroring the
    sh2runtime block-reduction design. (Side catch: the first probe
    "failure" was my hardcoded oracle confusing 2^20 with 10^6 —
    per-group assertions exonerated the kernel; oracles are computed
    now, never hardcoded.)

Effect of items 2–6 + 9 (same shapes, same box):

| trips | GPU before | GPU after | CPU loop |
|---|---|---|---|
| 1K | 1.62 | 0.77 | 0.03 |
| 16K | 1.89 | 0.90–1.14 | 0.29 |
| 64K | 2.14 | 0.95–1.29 | 1.09 |
| 256K | 5.83 | 2.6–4.1 | 5.69 |
| 1M | 15.9 | 7.3–11.4 | 33.4 |
| 4M | 45.4 | 38.4 | 113.7 |

(Ranges = across runs on a shared box; paired best-of-7 above is the
controlled comparison. Fixed cost ≈ 1.5 ms → ≈ 0.7 ms; crossover
≈ 250K → ≈ 100K.)

## 4. Implemented this round (mechanics)

1. **Off-by-one fix (correctness).** Brace `{a..b}` and `Range`
   (which renders as `$(seq lo hi)`) are INCLUSIVE — the C backend's
   `<=` is the oracle — but candidacy counted them exclusive,
   silently dropping the last lane on dispatch. Now inclusive; the
   old test had blessed the wrong value and was corrected.
2. **Peephole.** Identity bounds emit no arithmetic (`i_ = int64_t(t)`,
   `LO + int64_t(t)`, `int64_t(t) * STEP` as applicable).
3. **Conditional `InBuf`.** No externs ⇒ no input buffer at all
   (binding 0 becomes the first output). Shared binding rule,
   documented in emitter + runner.
4. **`restrict` on all buffer blocks** (aliasing facts for the driver).
5. **Tunable `local_size_x`** (`VkLoopSpec` field, default 256).
   Sweep at 1M lanes: 32→17.8, 64→14.9, 128→21.3, 256→16.3,
   512→20.7 ms (box noise ≈ ±20%; no significant sensitivity on
   lavapipe). 256 stays the portable default; the knob exists for
   per-device tuning.
6. **Pipeline/descriptor/command caching** (single-entry, SPIR-V-hash
   keyed): module, layouts, pipeline, pool, set, command pool/buffer
   persist across `run()` calls; per dispatch stays buffers +
   descriptor writes + re-record + submit. Effect below.
7. **N-output runner.** `run()` takes `Option<&[i64]>` input +
   `&[usize]` output lens (was: exactly 1+1); multi-store dispatch
   proven by test (2 arrays, all lanes asserted).
8. **`spirv-opt -O` + `spirv-val` gate** in `compile_spv` when present,
   raw-bytes fallback otherwise (CPU gates never fail on toolchain
   drift).
9. **`vkbench` example** (`cargo run --example vkbench`) — the
   measurement harness behind every table here, incl. a
   `VKBENCH_LOCAL_SIZE` knob.

Effect of 2–6 (same shapes, same box):

| trips | GPU before | GPU after | CPU loop |
|---|---|---|---|
| 1K | 1.62 | 0.77 | 0.03 |
| 16K | 1.89 | 0.90 | 0.29 |
| 64K | 2.14 | 1.29 | 1.09 |
| 256K | 5.83 | 4.09 | 5.69 |
| 1M | 15.9 | 11.4 | 33.4 |
| 4M | 45.4 | 38.4 | 113.7 |

Fixed cost ≈ 1.5 ms → ≈ 0.7 ms (buffers+descriptors+submit+fence+
transfers remain); crossover ≈ 250K → ≈ 100K; 4M speedup 2.5× → 2.7×.

(The §3 table above is canonical; an earlier duplicate is removed.)

## 5. Rejected (with rationale)

- **uint32 fast path.** Would halve ALU/bandwidth on weak GPUs, but
  bash integers are i64-wrap: lowering to u32 needs per-value range
  proofs through the (not yet written) host split. The width firewall
  (never silently narrow) forbids it until those proofs exist. The
  proof obligation is recorded; the emitter stays i64-total.
- **Push constants for externs.** Saves one buffer/descriptor for a
  few externs, but needs `VkPushConstantRange` + `vkCmdPushConstants`
  FFI for an effect lost in lavapipe noise. Revisit with multi-extern
  shapes on real hardware.
- **Bounds-check elimination.** One predicated compare per lane;
  unmeasurable. The check stays (GPU OOB writes corrupt; CPU OOB is
  merely UB — the GPU must be *stricter*, not looser).

## 6. Deferred (designed, not built)

- **Reduction (M5 scalar accumulates).** `s=$((s+i))` is the most
  common loop shape and currently vetoed (`scalar-carry`). Portable
  design: per-workgroup tree reduction in shared memory → partials
  buffer of `ceil(trips/local)` int64s → second tiny dispatch (same
  runner, second emitter shape) or host finish. Exact for integers
  (no float-associativity hazard); empty range yields the identity;
  overflow wraps mod 2^64 = bash parity. Needs the host split first.
- **Counted-`while` recovery** (`i=0; while ((i<n)); do …; i++`):
  candidacy skips `While` silently today; the init/cond/inc pattern
  match is straightforward future work.
- **Persistent buffer pools + device-local/staging** (P3): the runner
  allocates per call; pools need size-class management. Transfers are
  host-visible-coherent today (portable; discrete GPUs want staging).
- **PGO floors.** Static `GPU_FLOOR` policy belongs to dispatch
  (§4.7: measured lavapipe crossover ≈ 100K post-optimisation, vs the
  doc's 1e5–1e6 estimate — consistent); counters come with real
  programs, not the bench.
- **Multi-entry pipeline cache.** Single-entry thrashes on alternating
  shapes; size it per hot loop when the host split lands.

## 7. Tests pinning this round

`vulkan_backend` unit (peephole ×3, binding shift, determinism),
`vk_dispatch` (squares + extern-const + NEW two-array dispatch, all
lanes asserted on-device), `shader_spv` (SPIR-V magic through the
optimizer), `vkbench` (tables above), candidacy inclusive-range tests.
`gpu_gate` 545/0/7 and `c_gate` 637/0/7 unchanged throughout.

## 8. Optimised-only bench (`bench-opt.sh`): bash→Vulkan vs gcc-O3

`bash-o4/bench/bench-opt.sh` drops the bash leg (too slow for
steady-state scale) and compares optimised implementations at N
calibrated so the slower leg lands ~1s: `gcc-O3` (handwritten),
`bo4-gcc` (generated + gcc -O3, skipped with documented reasons where
the CPU backend cannot scale), `gpu` (`gpuleg` dispatch + host
finish). Speedups vs `gcc-O3`; checksums agree across running legs.

| problem | N | gcc-O3 | bo4-gcc | gpu |
|---|---|---|---|---|
| sumred | 1B | 0.617 | 1.388 (0.4×) | **0.236 (2.6×)** |
| squares-map | 100M | 0.147 | SKIP (array-cap) | 0.959 (0.2×) |
| collatz | 18M | 1.008 | 1.377 (0.7×) | **0.533 (1.9×)** |

- **bash→Vulkan beats gcc-O3 2–2.6×** where the shape fits the
  machine: thread-parallel reductions (sumred block kernel) and
  branchy high-intensity loops (collatz — unvectorisable,
  maximally thread-parallel; the `%`-test fork pathology that once
  made it untranspilable is fixed, so it now runs all three legs).
  These are the two things a single scalar thread does worst.
- **Transfer-bound maps lose ~6× on lavapipe** (squares-map: 800 MB
  out + 800 MB back on shared RAM vs vectorised memcpy-speed CPU).
  Discrete GPUs with real bandwidth flip that row; the bench keeps it
  to say so honestly.
- **Backend gap closed 7× → ~1.5× along the way** (LIC bound hoist in
  `c_backend`, same session): addsum bo4-gcc 21.8 → 3.9 ms. The
  remainder is signed-`%` blocking strength reduction (hand-editing
  the generated `% 2^32` to `&` matches handwritten speed; a
  native-`for` rewrite measured identical) — i.e. the next backend
  item is proven-nonnegative → unsigned lowering, not loop
  reshaping. Full story in `bash-o4/bench/README.md`.
- **The bo4 skips are findings.** `squares-map` exceeds fixed array
  caps; `collatz` needs per-iteration forks. The opt bench keeps both
  visible instead of averaging them away.

## 9. Discrete GPUs: UHD (no), NVIDIA Vulkan (blocked), NVIDIA CUDA (yes)

Box survey 2026-09-14: **no Intel UHD hardware** (`lspci` shows only
Microsoft Basic Render Driver endpoints; intel ICDs installed but
deviceless) — UHD shaders are not an option here, definitively.
An **RTX 2070 Super 8GB sits behind WSL** (`nvidia-smi`: driver 566.36,
CUDA 12.7) — but **no Vulkan path reaches it**: gfxstream, nouveau and
virtio ICDs all fail init (`VK_ERROR_INITIALIZATION_FAILED`), and
dmesg shows ongoing `dxgkio_query_adapter_info: Ioctl failed: -2`
(the WSL host GPU-graphics channel is down; WSLg/X11 itself is up).
No proprietary NVIDIA ICD and no Dozen (`libvulkan_dzn` absent) are
installed. Unblocking Vulkan-on-NVIDIA needs host-side repair (or
Mesa packages) — nothing in-guest to fix.

**CUDA bypasses it entirely** (proven end-to-end, driver API only, no
toolkit): `cuInit` + device enum + alloc/HtoD + hand-written PTX JIT
(`sm_75`, grid-stride i64 vector-add) + launch + DtoH: 100M elements
in **17 ms, 0 mismatches, exact checksums** (~95× the loaded-box
single-thread CPU at 1621 ms). `nvidia-smi` confirms live GPU.
Two WSL-CUDA pitfalls, both diagnosed by bisection and worth knowing
for the backend: (1) unversioned `cuMemAlloc` resolves to a stub —
use explicit `_v2` symbols everywhere; (2) the PTX parser rejects
multi-line entry headers (keep `.visible .entry f(...)` single-line)
and user regs shadowing specials (`%tid` vs `%tid.x` — rename).
Follow-up (scoped, not started): a CUDA backend (PTX emitter +
`cuffi` mirroring `vkffi`) would put the 2070 behind every bench
reduction at ~10–50×; lavapipe numbers throughout this doc are the
floor, not the ceiling.
