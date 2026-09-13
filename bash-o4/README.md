# bash-O4 — bash → C → Vulkan (-O4 driver)

`bash-O4` is the optimizing compiler driver of docs/BASH-O4.md:
bash source → ShIR → C → native execution via `tcc` (millisecond
JIT/AOT), with GPU-candidacy analysis (`--check`), GLSL-450 shader
emission (`--emit-shader`), and a hash-pinned library fetch cache.
GPU *dispatch* is not yet wired: `--gpu=auto` compiles CPU-only today;
`--gpu=force` exits 3.

## Build & quickstart

```sh
cargo build --offline                # needs the workspace crates.io cache only
./target/debug/bash-O4 prog.sh       # JIT-run (exit code = program's)
./target/debug/bash-O4 -o prog prog.sh
./target/debug/bash-O4 --check prog.sh        # candidacy report
./target/debug/bash-O4 --emit-shader sh_loop_main_0 prog.sh
./target/debug/bash-O4 --emit-c prog.sh       # debug: CPU C source
```

The driver reuses the exact `otranspilerl-cli --target c` pipeline
(same ShIR, same opt-profile globals, same C text) and links what the
render references (`-lm`, `-lgmp`, the uu-ffi runtime). `tcc` is
primary; a tcc compile failure (e.g. glibc `<regex.h>`, which tcc
cannot parse) retries once via `cc/gcc/clang` with a stderr note —
loud fallback, never silent.

## Flags (see `bash-O4` usage for the full list)

`-o FILE`, `--emit-c`, `--emit-shader ID`, `--check`, `--dump-shir`,
`--cpu-only`/`--no-gpu`, `--gpu=auto|force|off`,
`--fetch-libs[=ask|auto|off]`, `--cache-dir PATH`, `--offline`,
`--prefetch`, `--audit-fetch`, `-O0|-Og|-O2|-Os|-Oz|-O3|-O4`,
`--true64|--no-true64`, `--verbose`.

Exit codes: 0 (or the JIT program's own code), 1 compile/lower error,
2 usage, 3 `--gpu=force` with nothing dispatchable, 4 fetch refusal.

Notes:

- **Safe arithmetic by default.** Unlike `otranspilerl-cli -O3`
  (which sets true64 off), bash-O4 keeps true-64-bit mode on at every
  level; `--no-true64` / `$SH2_TRUE64=0` opts out. Observed C output is
  unchanged today (the flag is ESTree-path machinery), but the posture
  is safe for future width proofs.
- **argv[0].** JIT programs run with argv[0] = script path (the driver
  performs the `c_gate_main.sh` `exec -a` convention itself), so `$0`
  tests measure the renderer.
- **Cache.** `$XDG_CACHE_HOME`/`~/.cache` (or `--cache-dir`):
  `bash-o4/<key>/prog.c` + `meta.json` (key = ShIR + opts + render env
  + toolchain + renderer revision — bumped on any render-affecting
  change, so stale entries can never hide a fix) and `bash-o4-fetch/`
  (manifest artifacts + `audit.log`).

## GPU candidacy (`--check`)

```
candidate sh_loop_main_0 (main[0]: i in 0..1024 step 1 trips=1024)
veto sh_loop_main_1 (main[3]: s): scalar-carry
CANDIDATES=1 LOOPS=2
```

v1 accepts counted loops (`for i in {a..b}`, `for ((...))`, ranges)
whose bodies are independent affine `arr[a*i+b] = arith(+,-,*)` stores
over i64-proven values. Vetoes name the first failing rule
(`scalar-carry`, `body-host-io`, `non-counted-cond`, …). Scalar
accumulates need a parallel reduction (M5) and stay CPU.

## Testing

```sh
cargo test --offline            # unit + integration (parity, gates below)
bash ../harness/gpu_gate.sh     # differential gate: bash vs --cpu-only vs --gpu=auto
```

`tests/vk_dispatch.rs` dispatches a real compute shader on a real
Vulkan device (Lavapipe pinned when present; reported skip with no
device, loud failure on miscompute). `tests/shader_spv.rs` proves the
emitted GLSL compiles via `glslangValidator` (skipped if absent).

## Status vs docs/BASH-O4.md §4.9

M1 (driver+tcc+cache) and M2 (candidacy+`--check`) done; M4
(fetch/cache/manifest) done except real shaderc pins; M3 done through
GLSL emission + SPIR-V proof + on-device dispatch proof, with the
generated-code host split (`_sh_gpu_*` in `c_backend`) remaining.
Deviations from the design are recorded in the design doc.
