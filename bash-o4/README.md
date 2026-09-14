# bash-O4 — bash → C → CUDA/Vulkan (-O4 driver)

`bash-O4` is the optimizing compiler driver of docs/BASH-O4.md:
bash source → ShIR → C → native execution via `tcc` (millisecond
JIT/AOT), with GPU-candidacy analysis (`--check`), GLSL-450 shader
emission (`--emit-shader`), and a hash-pinned library fetch cache.

There are three GPU vehicles, deliberately separate:

| vehicle | path | state |
|---|---|---|
| `cutranspile` | bash → ShIR → candidacy → **PTX** → CUDA, no hand kernels | working; this is the *transpiled* CUDA claim |
| `cudabench` | handwritten PTX → CUDA | the hand-kernel reference the transpiled leg is measured against |
| `gpuleg`/`vkbench` | handwritten GLSL → SPIR-V → **Vulkan** | working, but the only device here is Lavapipe (software) |
| `bash-O4 --gpu` | same `cu_run` vehicle as `cutranspile` | working: `--gpu[=auto\|force\|off] --n N [--runs K] [--bind VAR=VAL]` |

All three drivers now reach the transpiled-GPU path through the same
`bash_o4::cu_run` vehicle, with the **same flags**: `--gpu` is an
explicit opt-in, so a bare `bash-O4 prog.sh` (and `--cpu-only`) always
stay on the CPU path; `--gpu=auto` dispatches when a candidate resolves
and otherwise falls back to the CPU path; `--gpu=force` exits 3 when
nothing can dispatch. `harness/gpu_gate.sh` therefore uses `--cpu-only`
for its CPU leg and asserts the `--gpu` leg's checksum against bash's
stdout whenever it actually dispatches.

The shared flag surface lives in `bash-o4/src/flags.rs` (one parser,
one help block) and `tests/flag_parity.rs` drives both binaries to pin
it — before that the two drivers had drifted apart (two private
`GpuMode` enums, `--gpu` meaning different things, and
`--n/--runs/--bind/--help` missing from bash-O4 entirely).

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
`--cpu-only`/`--no-gpu`, `--gpu[=auto|force|off]`, `--n N`, `--runs K`,
`--bind VAR=VAL`, `-h`/`--help`, `-V`/`--version`,
`--fetch-libs[=ask|auto|off]`, `--cache-dir PATH`, `--offline`,
`--prefetch`, `--audit-fetch`, `-O0|-Og|-O2|-Os|-Oz|-O3|-O4`,
`--true64|--no-true64`, `--verbose`.

Exit codes: 0 (or the JIT program's own code), 1 compile/lower error,
2 usage, 3 `--gpu=force` with nothing dispatchable, 4 fetch refusal.
Unknown flags are usage errors (2) in every driver.

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

`--check` reports **both** candidacies, labelled, because they answer
different questions: `GLSL` is what `--emit-shader` renders, `MAP`/`RED`/`SEQ`
is what `--gpu` dispatches.  The CUDA section is byte-identical to
python-O4's, so the flag means the same thing in every driver.

```
GLSL candidate sh_loop_main_0 (main[0]: i in 0..1024 step 1 trips=1024)
GLSL veto sh_loop_main_1 (main[3]: s): scalar-carry
MAP  veto cu_loop_main_0 (main[2]: i): scalar-carry
RED  candidate cu_red_main_0 (main[2]: i in 0..n(<) step 1)
SEQ  veto cu_red_main_0 (main[2]: i): non-seq-body
GLSL_CANDIDATES=1 GLSL_LOOPS=2
CUDA_CANDIDATES=1
```

Only the GLSL half used to be printed, and the trailing count was a bare
`CANDIDATES=`, so `squares-map` — which offloads fine — reported
`CANDIDATES=0`.  The two counts are now distinct names.

The verdict *sets* legitimately differ per front end: the shell path runs
`fuse-fill-consume` before candidacy, so a fill+consume pair is one `RED`
candidate there, while a frontend A1 that has not been through that transform
still shows the separate `MAP` and `RED` loops (both offload).

The CPU map candidacy accepts counted loops (`for i in {a..b}`,
`for ((...))`, ranges) whose bodies are independent affine
`arr[a*i+b] = arith(+,-,*)` stores over i64-proven values. Vetoes name
the first failing rule (`scalar-carry`, `body-host-io`,
`non-counted-cond`, …).

`cutranspile` additionally runs the **CUDA** candidacies
(`cu_candidacy::analyze` / `analyze_reduce` / `analyze_seq`), which
accept:

- **map** — one or more independent affine stores (multi-store fills
  are fine: the CUDA map path always accepted them);
- **reduce** — a single scalar accumulate `acc + X` / `acc * X` /
  `(acc+X)%m` / `(acc+X)&mask` with `m ≤ 2³²`, plus array reads
  (`X = a[i]`) when a fusable map produces that array;
- **seq** — a *sequential* per-lane kernel: a lane-nest is an outer
  counted loop whose body is private seeds, one data-dependent `while`
  chain and one accumulate (Collatz). Soundness rests on
  `shir_passes::lane_private` proving the chain's state is
  lane-private (ordered init dominance, chain writes dominated by
  those inits, accumulate only in the tail), so each outer iteration
  can run whole in one lane and the per-lane results tree-reduce.

Map + reduce over the same iteration space **fuse**: one kernel
writes the array, the next reads it, and only the partials cross back.

## python-O4 (Python front end)

The same -O4 machinery also drives Python: `python-O4 prog.py` runs
`prog.py` through the workspace's py-sh-go frontend to A1 shIR, then
reuses this crate's C render + tcc JIT/AOT (CPU) and CUDA
candidacy/PTX dispatch (`--gpu`, the shared `cu_run` vehicle).
`-h/--help` and `-V/--version` report usage and the version.

```sh
cargo build --bin python-O4
./target/debug/python-O4 prog.py            # JIT-run (CPU)
./target/debug/python-O4 --check prog.py    # map/reduce/seq candidacy
./target/debug/python-O4 --gpu --n 1000000000 prog.py
```

Bench: [`bench/bench-py.py`](bench/bench-py.py) — Python sources in
`bench/py/`, results in [`bench/README-py.md`](bench/README-py.md).
Transpiled Python now reaches **×293** of `gcc -O3` on a 1e9
mod-reduction (3.55 ms) and ×61 on branchy Collatz; the CPU legs are
native i64 too (`--exact-i64` plus a generalized loop-versioning plan),
so sumred is 1.18 s vs `gcc -O3`'s 1.04 s where it used to be 67.5 s in
GMP. Design, results and the **release-readiness checklist** are in
[`docs/PYTHON-O4.md`](../docs/PYTHON-O4.md) (§8).

## Transpiled CUDA (`cutranspile`)

```sh
cargo build --example cutranspile
./target/debug/examples/cutranspile bench/sh/squares-map.sh 100000000 --runs 5
# -> "<median_ms> <checksum>"
```

Prints a timing line on success, `SKIP ...` + exit 2 when there is no
device, no runnable shape, or an extern that needs an explicit
`--bind VAR=VAL` (never a guessed value). The checksum is the reduced
scalar, so it checks byte-for-byte against the C leg.

Measured (`bench/bench-opt.sh`, minimum over 3 runs on a shared box;
see `bench/README.md` for the method and the full table):

| problem | N | handwritten PTX (`cuda`) | transpiled (`cuda-tx`) | ratio |
|---|---|---|---|---|
| sumred | 1B | 0.004 s | 0.004 s | 1.0× |
| squares-map | 100M | 0.001 s | 0.001 s | ~1× |
| collatz | 18M | 0.013 s | 0.014 s | 1.08× |

i.e. bash → ShIR → PTX lands within ~10% of hand-tuned PTX on a map+reduce
fusion, a masked reduction and a sequential branchy chain, with
byte-identical checksums. Relative to `gcc -O3` on the same problems
the transpiled CUDA leg is 277×/326×/98× (the GPU is doing 10⁹–10¹⁰
items where the CPU does 10⁸).

`--check` reports the CUDA verdicts too (`MAP`/`REDUCE`/`SEQ`/`veto
<reason>`), so a SKIP is always explained by a named rule.

## Testing

```sh
cargo test --offline            # unit + integration (parity, gates below)
bash ../harness/gpu_gate.sh     # differential gate: bash vs --cpu-only vs --gpu (transpiled)
bash ../harness/c_gate_main.sh  # C backend corpus gate
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
M5 (parallel reductions) is done on the CUDA side (`cu_candidacy` +
`cuda_backend` + `cu_run`), including sequential lane-nests, and the
`bash-O4` driver now dispatches it in-process (`--gpu`), with the same
flag surface as `python-O4`. The Vulkan backend still only runs
*handwritten* shaders (the generated-code host split `_sh_gpu_*` is the
remaining M3 item), so `--gpu` reaches CUDA, not Vulkan.

Deviations from the design are recorded in the design doc.

## Known limitations (read before quoting a number)

- **Vulkan here is Lavapipe** — a software rasteriser. The `gpu` column
  is a *scaffold* measurement (and `squares-map`-class maps move 800 MB
  each way over shared RAM), so it understates real hardware by a wide
  margin. The `cuda`/`cuda-tx` columns are the real-GPU numbers.
- **`tcc` cannot parse glibc `<regex.h>`**, so scripts using regex
  builtins fall back to `cc`/`gcc`/`clang` with a stderr note. The
  fallback is loud, never silent; the `bo4-tcc` bench row is therefore
  not a universal "tcc compiles everything" claim.
- **The C backend keeps a fixed array-capacity backstop** (`ARR_CAP`,
  1024) for arrays it cannot prove the size of. Counter-routed fills
  bypass it when the index maximum is proven; anything else is capped
  and the GPU path (which sizes by trip count) can accept shapes the
  CPU path cannot. `./fail`'s sparse-`${#a[@]}` slot-vs-set divergence
  is pre-existing and unrelated.
- **`./fail` (the Perl-backend corpus gate) is not green** — it sits at
  a pre-existing 260/552 failure baseline owned by a different
  workstream (the ESTree/Perl migration). The green gates for *this*
  work are `c_gate_main.sh` (637/0/7) and `gpu_gate.sh` (545/0/7);
  announce those, not `./fail`.
- **`hash` has no handwritten GPU reference**, so its `cuda-tx` row
  gates only against the C checksum. Adding hand kernels for the new
  shapes is open work; the transpiled leg is not yet *proven* optimal
  there, only correct and fast.
- **Benchmarks ran on a shared 8-CPU laptop** (load average 7–10 from
  concurrent builds). Quoted figures are per-leg minima over 3 runs;
  ratios are stable, absolute seconds are indicative. Reproduce with
  the commands in `bench/README.md` before quoting absolutes.
