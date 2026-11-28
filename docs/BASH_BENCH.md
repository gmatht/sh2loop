# BASH_BENCH — every benchmark for transpiled bash, and how to reproduce it

Living inventory of the benchmarks that measure **bash → another language →
run**, plus the runtime conventions those programs choose between (uutils
in-process vs fork/exec vs capture vs threaded). Each section gives the
harness, what it measures, the published numbers with their provenance, and
the exact command.

Re-checked on **2026-11-27** on this box (Intel i7-10875H, 8C/16T, Linux
7.0.0-44, gcc 15.2). Load during the captures ranged 0.5–9 (each table
says which); rows taken on another box/date say so. Fresh captures from this
session are committed next to their harness:
`bash-o4/bench/results-*-2026-11-27.tsv`, `benchmarks/uu-ffi/results-*.csv`,
`benchmarks/uu-conventions/results.csv`, `20261127_shellbench_fork_exec_only.md`
(workspace root, one level up from this file).

Paths in this document: commands are run **from the workspace root** (the
parent of `docs/`), so `bash-o4/bench/bench.sh` means `<root>/bash-o4/bench/bench.sh`.
Captures written by this work live at the root or next to their harness.

---

## 0. Index

| # | Benchmark | Harness | Baseline | Transpiled side | Status |
|---|---|---|---|---|---|
| 1 | CPU: bash vs transpiled C vs handwritten C | `bash-o4/bench/bench.sh` | bash, gcc -O3 | bash-O4 (tcc, gcc -O3) | fresh (no `tcc` here → `bo4-tcc` via `cc`) |
| 2 | Optimised scale: C/GPU/CUDA at ~1 s | `bash-o4/bench/bench-opt.sh` | gcc -O3 | bash-O4, transpiled CUDA | fresh (GPU/Vulkan SKIPs) |
| 3 | Autoshaderisation (bash → GPU) | `gpuleg` / `cudabench` / `cutranspile` (via §2) | gcc -O3, hand PTX | bash → PTX (`cuda-tx`) | fresh |
| 3a | **Where autoshaderised bash beats `gcc -O3`** (no bash leg, large N) | `cutranspile` + `bench/c/*.c` | gcc -O3 | bash → PTX | fresh |
| 4 | `sqrt1337` + Collatz (the showcase kernels) | §1, §2, `bench_sqrt.sh` | bash/dash | C, JS, PTX | fresh |
| 5 | **uutils calling conventions** | `benchmarks/uu-ffi/*`, `benchmarks/uu-conventions/` | fork+exec | in-proc / capture / threaded | fresh |
| 6 | Shellbench micro-suite (fork/exec-bound) | `bench.sh` | bash, dash | transpiled JS/C | fresh (bash/dash/js complete; C partial) |
| 7 | Shellbench report (2026-08-06) | `bench.sh` | bash, dash | transpiled JS/C | historical |
| 8 | JavaScript i64/u64/BigInt | `benchmarks/i64/*` | JS Number | BigInt / typed arrays | re-verified (node 22) |
| 9 | Python → C | `docs/PY_BENCH.md` | CPython, Cython | py-sh-go → C | historical (harness present, needs `go`) |
| 10 | Non-speed measurements | `fail`, `fail-estree`, `harness/c_gate_main.sh`, `harness/estree-contract.mjs`, `harness/pg-classify.pl`, `harness/pg-seam-sweep.pl`, `harness/backend_runtime_metric.sh`, `harness/rust-dogfood.sh`, `tests/coreutils/*` | — | — | listed so they are **not** mistaken for benchmarks (§10) |
| 14 | **Installer** for every toolchain gap above: `harness/install-bench-toolchain.sh` | — | — | — | see §14 |

**Status key.** *fresh* = re-run this session, numbers below are this box.
*historical* = recorded on a different box/date, kept for the shape of the
result; re-run before quoting. *partial* = the suite runs but one column has
gaps, each named in the section.

Toolchain assumed (checked below): `cc`/`gcc`, `perl`, `python3`, `bash`,
`dash`. **Not** present on this box: `tcc` (so the `bo4-tcc` column was
taken with `cc` — a *driver* column, not a tcc-codegen column), `node`,
`glslangValidator`, `shir_render` (the c worktree binary), `go`, `zig`;
`rustc` exists but the frontends that benchmark it are not buildable here.
Sections note what degrades to `SKIP`/`ERR` without each.

---

## 1. CPU suite — bash vs transpiled C vs handwritten C

**Harness** `bash-o4/bench/bench.sh` (`--runs N --save FILE --problem NAME`;
env `RUNS`, `TIMEOUT`). **What it measures** four legs at one fixed N per
problem:

| leg | how |
|---|---|
| `bash` | real bash (the floor reference) |
| `bo4-tcc` | `bash-O4 -o` — generated C compiled by `tcc` (the default driver path). This box has no `tcc`, so `bash-O4` fell back to `cc`: read the column as "driver path", not "tcc codegen" |
| `bo4-gcc` | `bash-O4 --emit-c` recompiled with `gcc -O3` (isolates backend quality from compiler quality) |
| `gcc-O3` | handwritten C (`bench/c/*.c`) + `gcc -O3` (the ceiling) |

**Gate** stdout **and** exit code must byte-agree across the legs, else the
row fails loudly and prints no number. Each problem:

`bench/sh/*.sh` — these are the actual bash sources, so they are also the
input if you want to point a different backend at them:

```sh
addsum.sh     n=$1; s=0; for ((i=0;i<n;i++)); do s=$((s+i)); done; echo $s
squares.sh    … s=$((s + i*i)) …
hash.sh       … a=$(( (i*53) % 256 )); b=$(( (i*89) % 256 )); s=$(( (s + a*31 + b*17) % 256 ))
twoarr.sh     … for: a[$i]=$((i*i)); b[$i]=$((i+1)) … then s=$(((s + a[i]*b[i]) & 0xFFFFFFFF))
collatz.sh    … v=$(((k*37+3)%251)); while ((v>1)); do if ((v%2==0)); then v=$((v/2)); else v=$((3*v+1)); fi; s=$((s+1)); done
sqrt1337.sh   for i in `seq 1 10000`; do if echo $((i*i)) | grep 1337 …; then echo $i; fi; done
```

**Fresh capture** (2026-11-27, `RUNS=3`, ms; every row also in
`bash-o4/bench/results-cpu-2026-11-27.tsv` as `problem,N,leg,ms,ns_item,speedup_vs_bash`):

| problem | N | bash | bo4-tcc | bo4-gcc | gcc-O3 |
|---|---:|---:|---:|---:|---:|
| addsum | 1M | 3407 | 11.3 (303×) | 8.4 (407×) | 9.2 |
| addsum32 | 46340 | 152 | 7.5 (20×) | 11.3 (13×) | 11.4 |
| squares | 1M | 3619 | 9.9 (366×) | 9.6 (378×) | 8.6 |
| hash | 1M | 9535 | 17.6 (543×) | 15.2 (627×) | 15.9 |
| twoarr | 200K | 4797 | 9.1 (530×) | 8.5 (561×) | 10.6 |
| collatz | 500 | 232 | 8.4 (28×) | 8.0 (29×) | 8.5 |
| sqrt1337 | 10K | 8824 | 5.5 (1611×) | 12.7 (697×) | 5.3 |

(speedups vs bash in parentheses.) Three rows deserve a note, and none is
a "transpiler beats C" claim:

- **`twoarr` beats handwritten `gcc -O3` (8.5 vs 10.6 ms)** because
  `fuse-fill-consume` deletes the intermediate arrays the reference keeps
  and makes one pass where the reference makes two — an algorithmic win,
  not codegen.
- **`sqrt1337`'s `bo4-gcc` column is 2.3× slower than the driver column**
  (12.7 vs 5.5 ms) on the same generated C, from the same `cc`. With no
  `tcc` on this box both columns are the same compiler, so this is not
  codegen: it is a sub-10 ms row on a loaded box (the 2026-09-14 capture
  has it the other way, 12.4 vs 14.1 ms). Treat every sub-10 ms row as
  startup/string noise and compare it relatively, never as a third
  significant figure.
- `addsum32`'s ratio (13×) is small only because the bash leg is short
  (N is chosen so the *sum* fits int32); the absolute C time is 5–11 ms.

The 2026-09-14 capture (i7-10875H, gcc 13.3, with `tcc` — a different
install) is in `bash-o4/bench/README.md` with the full discussion of
`tcc` vs `gcc`, the width story (`addsum` vs `addsum32`), and which shIR
transform carries which row.

**Reproduce**

```sh
cd bash-o4
RUNS=3 bash bench/bench.sh --save /tmp/bo4.tsv          # all seven
RUNS=2 bash bench/bench.sh --problem collatz            # one problem
# bo4-tcc needs tcc on PATH; bo4-gcc/gcc-O3 need gcc.
```

Known environment coupling: `bash-O4` finds the sh2perl tree through
`BASH_O4_SH2PERL` (the harness sets it). `sqrt1337`'s **bash** leg and
`collatz` (all legs) are timed **once** by design (`TIMEOUT` defaults to
600 s): the bash leg of `sqrt1337` is 10,000 forks (~9 s here) and once ran
a fork-per-iteration pathology at 300× interpreter cost.

---

## 2. Optimised-scale suite — C, Vulkan, CUDA at ~1 s

**Harness** `bash-o4/bench/bench-opt.sh` (same flags; `RUNS` default 3,
`TIMEOUT` 900). No bash leg by design: at steady-state N the interpreter
cannot finish inside the measurement window — that gap is *why* the
transpiler exists.

| leg | what it is |
|---|---|
| `gcc-O3` | handwritten C + `gcc -O3` — CPU ceiling (reference for every speedup in this table) |
| `bo4-gcc` | **TRANSPILED** `bash-O4 --emit-c` + `gcc -O3` (same compiler as the ceiling ⇒ the ratio is backend quality) |
| `gpu` | handwritten GLSL → SPIR-V → Vulkan (`gpuleg`) + host finish. Needs `glslangValidator` + a Vulkan ICD |
| `cuda` | handwritten PTX block templates (`cudabench`) + host finish. Needs a CUDA device |
| `cuda-tx` | **TRANSPILED** bash → ShIR → candidacy → PTX (`cutranspile`), no hand kernels |

Gate: every *running* leg's checksum must byte-agree (and exit codes).

**Fresh capture** (2026-11-27, `RUNS=3`, `bash-o4/bench/results-opt-2026-11-27.tsv`):

| problem | N | gcc-O3 (s) | bo4-gcc (×) | cuda-tx (×) | gpu / cuda |
|---|---|---|---|---|---|
| sumred | 1e9 | 0.601 | 0.618 (1.0×) | 0.003 (**213×**) | SKIP (no glslangValidator) |
| squares-map | 1e8 | 0.340 | 0.070 (**4.8×**) | ~0 (n/a) | SKIP |
| twoarr | 5e7 | 0.360 | 0.035 (**10.4×**) | 0.000 (n/a) | — (no hand kernel) |
| collatz | 1.8e7 | 0.600 | 0.649 (0.9×) | 0.013 (**44.7×**) | SKIP |

Read it honestly: `squares-map`/`twoarr` beat the handwritten ceiling by an
*algorithmic* win (`fuse-fill-consume` deletes an unobservable intermediate
array), not better codegen; `collatz` is a compute-bound branchy loop where
the CPU backend is at parity and the GPU is 45× ahead; `sumred` is near
parity because its accumulator is `u64`.

**Environment behaviour (fixed this session).** `gpuleg` *panics* without
`glslangValidator` (`need glslangValidator`, exit 101) — that used to abort
the whole suite on problem #1, so the CUDA and CPU rows that would have run
fine were never reached. The Vulkan leg now **SKIPs with the reason**
(gpu and cuda, which share the device probe), like the CUDA leg already did
for a missing device.

**Reproduce**

```sh
cd bash-o4
RUNS=3 bash bench/bench-opt.sh --save /tmp/opt.tsv        # whole table
RUNS=3 bash bench/bench-opt.sh --problem twoarr           # one problem
RUST_BACKTRACE=1 bash bench/bench-opt.sh --problem collatz 2>&1 | tail -20
```

Preconditions per leg: `gcc` always; `glslangValidator` + `VK_ICD_FILENAMES`
(Lavapipe works) for `gpu`; `/dev/nvidia*` for `cuda` and `cuda-tx`;
`cargo build --examples` in `bash-o4` for all three example binaries.

---

## 3. Autoshaderisation — bash → GPU, and how candidates are chosen

The GPU columns of §2 **are** the autoshaderisation benchmark: `cuda-tx`
consumes the *unmodified* bash in `bench/sh/` and the transpiler decides
whether the loop is a candidate. Candidacy (the rule `bash-O4 --check`
reports; `docs/BASH-O4.md` §4.3) requires, in order, shape (counted loop
with a bounded trip count), purity (integer arith + locals + affine array
access; veto on exec/pipeline/subshell/capture/function calls/assoc/string
ops), width (i64-proven, never silently i32), memory (affine indexing,
bounded output) and profitability (`trips × body_cost > dispatch + 2 ×
transfer`). Each accepted loop gets a stable ID and a verdict.

**Inspect a candidacy verdict** (no device needed):

```sh
cd bash-o4
target/debug/bash-O4 --check bench/sh/sumred.sh
target/debug/bash-O4 --check bench/sh/collatz.sh
target/debug/bash-O4 --emit-shader <ID> bench/sh/sumred.sh   # the GLSL450 compute shader
```

**Transpiled kernels on their own, with timing and checksum:**

```sh
cd bash-o4
cargo build --examples
target/debug/examples/cutranspile bench/sh/sumred.sh 1000000000 --runs 3   # "<median ms> <checksum>"
target/debug/examples/cudabench sumred 1000000000 --runs 3                # hand PTX, same shape
target/debug/examples/gpuleg   sumred 1000000000 --runs 3                 # Vulkan
```

`cutranspile`/`cudabench` exit **2** with a reason when there is no device
(`SKIP`), `gpuleg` needs `glslangValidator` (§2).

**The payoff table is §3a** — where this actually beats `gcc -O3`, by how
much, and where it loses.

**What the numbers say:** the transpiled CUDA leg is within ~10% of
hand-written PTX on the three shapes that have both (1.0–1.1×, checked at
scale in `docs/BASH_VULKAN.md` §8/§10a/§11), because the transforms —
`fuse-fill-consume`, `isolate-accumulate`, `lane_private` — are what turn a
bash loop into a lane-parallel kernel at all (before them, candidacy vetoed
`squares-map` for `scalar-carry`, `hash` for `non-single-accumulate` and
`collatz` for `no candidate loop`).

---

## 3a. Where autoshaderised bash beats `gcc -O3` — and by how much

§3 says how a loop becomes a candidate; this section is the payoff table.
**No bash or dash leg anywhere below** — every number is CPU vs GPU at a
size chosen so the comparison is about throughput, not about an
interpreter. The CPU reference is handwritten C at `gcc -O3` (the ceiling
§1 measures the transpiler against), plus the transpiled C column where it
is the fairer reference.

N is pushed to where the GPU's advantage is bandwidth, not dispatch: the
smallest row here (1e9) is ~1000× the ~1e5–1e6-trip breakeven modelled in
`docs/BASH-O4.md` §4.7, and the largest goes another 100× (`sumred` at
1e11); `collatz` stays at 1.8e8 seeds because each seed is a dependent
chain (measured: 44.7 inner steps per seed on average), so its *work* is
~8e9 steps.

Captured 2026-11-27 with `cutranspile` (`--runs 5`; the driver prints the
**median of 5 kernel reps**, and each row's best of 3 driver invocations is
quoted, because the box is shared and a single invocation varies up to 2×):

| problem (bash source) | N | `gcc -O3` (handwritten) | best `bo4-gcc` | **transpiled CUDA** | GPU vs `gcc -O3` | checksum |
|---|---:|---:|---:|---:|---:|---|
| `squares-map` | 1e9 | 3.93 s | 0.67 s (transpiled *C* wins too) | **2.02 ms** | **~1950×** | agrees |
| `sumred` | 1e9 | 0.70 s | 0.63 s | **2.75–4.3 ms** | **~200×** | agrees |
| `sumred` | 1e10 | 6.9 s | 17.6 s | **~30 ms** | **~230×** | **differs by design** (see below) |
| `collatz` | 1.8e8 | 5.8–6.4 s | 6.4 s | **62–70 ms** | **~95×** | agrees |
| `hashred` (`s = (s + i*i*7) & 0xFFFFFFFF`) | 1e9 | 0.84 s | 0.66 s | **2.8–4.4 ms** | **~250×** | agrees |
| `hashred` | 1e10 | 8.1 s | — | **~29 ms** | **~280×** | agrees |

Ranges are the spread across repeated driver invocations, not error bars:
the driver reports the median of 5 kernel reps, and the *spread* is the
first-call overhead (a cold first dispatch adds ~0.7 ms — 26% of the
`sumred`-1e9 row), which is exactly the launch cost at §4.7 that the
1e10 rows make irrelevant.

`hashred` is a one-line variant of `bench/sh/hash.sh` (written for this
section, kept at `bash-o4/bench/sh/hashred.sh`) because the exact
`hash.sh` mix — two `%256` chains feeding a third — is **vetoed** by
candidacy (`non-single-accumulate`); the variant is the same
"accumulate into a masked register" shape that a GPU wants.

### What actually produces the win

1. **It is not codegen, it is the transform ladder.** `squares-map` at 1e9
   is faster in transpiled *C* (0.67 s) than in handwritten C (3.93 s) —
   `fuse-fill-consume` deletes the 8 GB intermediate array the reference
   materialises, so the reference is memory-bound and the transpiled
   program is not. The same transform is what makes the loop a GPU
   candidate at all: without it, candidacy vetoes `squares-map`
   (`scalar-carry`).
2. **Bandwidth, not instructions, is the ceiling.** On this device the
   GPU leg scales linearly with N — `sumred` 1e9 → 3.3 ms, 1e10 → 30 ms,
   1e11 → 4.9 s — so the jump from 1e9 to 1e10 costs 10× the time, not
   1000× the launch overhead. That scaling is the evidence that the
   small-N rows are not launch latency.
3. **Branchy irregular work is the biggest qualitative gap.** `collatz` is
   unvectorisable — the CPU does one dependent chain at a time and `gcc
   -O3` is already at its floor (5.8 s at 1.8e8); the GPU runs each seed's
   chain in its own lane (62–70 ms vs 5.8 s ≈ 95×).

### Where the GPU *loses* — the honest half

- **`sumred` at 1e10 is a case where the GPU hides bad CPU codegen.**
  The transpiled C leg is *slower* than the handwritten one (17.6 s vs
  6.9 s): the transpiled accumulator is `u64` with a mask
  per element (masked arithmetic, exact), where the handwritten reference
  lets `gcc` narrow and vectorise; the GPU leg (30 ms) does not care.
  Read the column as "for a GPU-bound loop the CPU code quality stops
  mattering", not as a codegen win — and as a reminder that the GPU table
  is not a claim about the CPU backend.
- **CPU agreement past N = 3,037,000,500 is impossible for `sumred`**:
  `i*i` wraps negative in signed 64-bit, so the signed-CPU and masked-GPU
  paths *provably* diverge. At 1e10 the legs print different checksums
  and both are right for their own arithmetic; the scaling claim stands on
  linearity, not on agreement. `collatz` and `squares-map` have no such
  horizon (O(1) memory, never wrap) and agree at every N quoted.
- **Small N belongs to the CPU.** Candidacy only accepts a loop whose
  modelled `trips × body_cost > dispatch + 2 × transfer` pays
  (`docs/BASH-O4.md` §4.3/§4.7): breakeven is ~1e5–1e6 trips on this
  device, and below ~1e4 trips the GPU always loses. `sumred` at 1e8 is
  0.35 ms of GPU against 0.06 s of CPU — still a win, but the ratio is
  already shrinking with size.
- **Transfer-bound maps on an iGPU/software device lose outright**
  (`docs/BASH_VULKAN.md` §8: `squares-map` 6× slower on Lavapipe). This
  box has a real RTX 2070 Super; a box without one does not get these
  numbers, and the Vulkan legs `SKIP` (§14).

### Which bash loops are even eligible

The `squares-map`/`sumred`/`collatz`/`hashred` shapes are the ones that
survive the five-step candidacy rule (§3): counted loop with a bounded
trip count, integer-only body with affine array indexing, no
exec/pipeline/capture/function call, i64-proven width, bounded output.
Everything else stays on the CPU by construction — that is why this
section can be short and large-N: `exec`, pipes, `eval`, string work and
fork/exec-bound scripts are not GPU-eligible at any size, and their
comparison is §5/§6, not here.

### Reproduce

```sh
cd bash-o4 && cargo build --examples

# the transpiled GPU leg: prints "<median ms> <checksum>"
target/debug/examples/cutranspile bench/sh/sumred.sh     1000000000  --runs 5
target/debug/examples/cutranspile bench/sh/squares-map.sh 1000000000 --runs 5
target/debug/examples/cutranspile bench/sh/collatz.sh    180000000   --runs 5
target/debug/examples/cutranspile bench/sh/hashred.sh    1000000000  --runs 5

# the CPU reference (same source, gcc -O3) and the transpiled C leg
gcc -O3 bench/c/sumred.c -o /tmp/sumred_hand
target/debug/bash-O4 --emit-c bench/sh/sumred.sh > /tmp/sumred.c
gcc -O3 /tmp/sumred.c -lm -o /tmp/sumred_bo4
/usr/bin/time -f %e /tmp/sumred_hand 1000000000

# whole-table version (CPU + CUDA legs, checksums gated, ~1 s scale)
bash bench/bench-opt.sh --problem sumred
bash bench/bench-opt.sh --problem squares-map

# candidacy verdict for any of them (no device needed):
target/debug/bash-O4 --check bench/sh/hashred.sh
target/debug/bash-O4 --check bench/sh/hash.sh      # vetoed: non-single-accumulate
```

`cutranspile` exits **2** with a reason when the shape is vetoed or there
is no CUDA device, so a table that silently loses a row cannot happen. The
checksum on each row is what makes it a benchmark rather than a
microbenchmark: a fast-but-wrong kernel prints a different number and the
gate in `bench-opt.sh` fails the row.

**Two harness caveats this section had to work around**, both worth knowing
before reading a `cuda-tx` cell:

- `bench-opt.sh` times the `cuda-tx` leg twice: once with `--runs 1` for
  the checksum gate (line 217) and once with `--runs "$RUNS"` for the
  table (line 248) — so at `RUNS=3` the cell is the median of 3 kernel reps
  and includes the cold first dispatch. The table above quotes `--runs 5`
  and takes the best of 3 invocations, which is the *warm* median and runs
  2–3× lower on the small rows (`sumred` 1e9: 4.1 ms cold vs 2.8 ms
  warm). Both are real; they answer different questions (first-dispatch
  latency vs steady-state throughput).
- The same suite's own 2026-11-28 re-run at its default N is committed as
  `bash-o4/bench/results-opt-2026-11-28-s3a.tsv`: `sumred` 1e9
  `gcc-O3` 0.657 s / `bo4-gcc` 0.659 s / `cuda-tx` 0.003 s (229×),
  `squares-map` 1e8 0.395 / 0.076 / ~0, `collatz` 1.8e7 0.641 / 0.704 /
  0.012 (52×). Those are the *1 s-scale* rows; §3a's table pushes N to
  1e9–1e11 precisely so the comparison is not launch-bound. Its `gpu`
  (Vulkan) legs SKIP on this box (no `glslangValidator`), so only the CUDA
  leg is measured here.

## 4. The two showcase kernels: `sqrt1337` and Collatz

### 4.1 `sqrt1337` — "a pipeline per iteration" → one native `strstr`

The script (verbatim in `bash-o4/bench/sh/sqrt1337.sh` and
`sh2perl/sqrt1337.sh`; answers `3657`, `5598`, `7165`):

```bash
for i in `seq 1 10000`; do
  if echo $((i*i)) | grep 1337 > /dev/null 2> /dev/null; then echo $i; fi
done
```

| implementation | time | speedup | source |
|---|---:|---:|---|
| bash | 8.82 s | 1× | §1 fresh |
| dash | 9.08 s | 1× | `bench.sh` sqrt block, fresh |
| bash-O4 → tcc | 5.48 ms | **1611×** | §1 fresh |
| bash-O4 → gcc -O3 | 12.7 ms | 697× | §1 fresh (see the sqrt1337 row note in §1) |
| handwritten C -O3 | 5.27 ms | 1675× | §1 fresh |
| transpiled C, 2026-09-14 box | 12.4 ms | 1484× | `bash-o4/bench/README.md` |
| transpiled JS (estree) | 0.27 s | ~50× | `20260806_shellbench.md` (historical; needs node) |

The win is lowering: `seq` → counted loop, `$((i*i))` → integer multiply,
`echo … | grep` → `strstr`. Two shell sites remain in the whole program.

**Reproduce**

```sh
cd bash-o4
target/debug/bash-O4 -o /tmp/sqrt1337 bench/sh/sqrt1337.sh
time /tmp/sqrt1337                                  # 3657 5598 7165
time bash bench/sh/sqrt1337.sh                      # ~9 s

# dash / auto-JS / hand-JS / C side by side (needs node for the JS rows)
SRC=$PWD/bench/sh/sqrt1337.sh bash ../bench_sqrt.sh
# every backend that can render it (skips what is not built):
bash ../show_sqrt_langs.sh
```

`bench_sqrt.sh` and `show_sqrt_langs.sh` were **repaired this session**
(they pointed at a CLI path that no longer exists, `sh2perl/otranspilerl/…`,
and used a `file --perl` / `--target estree` flag spelling the current CLI
no longer accepts; both now use `--target pl` / `--estree`, and the C arm
uses the c worktree's `shir_render`). Without `node` the JS rows are `ERR`;
`bench_sqrt.sh` still exits at its verification step if the hand-written JS
or C binary under `/tmp/sqrtbench` is missing — build those first
(`HAND_JS=… C_BIN=…` override the paths).

### 4.2 Collatz — branchy, sequential inner chain

```bash
n=$1; total=0
for ((k=0;k<n;k++)); do v=$(( (k*37+3) % 251 )); s=0
  while ((v > 1)); do if ((v % 2 == 0)); then v=$((v/2)); else v=$((3*v+1)); fi; s=$((s+1)); done
  total=$((total+s)); done; echo $total
```

Two different benchmarks use it, and that is the point:

| configuration | bash | bo4-tcc | bo4-gcc | gcc -O3 | transpiled CUDA |
|---|---:|---:|---:|---:|---:|
| N=500 (§1, one run each) | 232 ms | 8.42 ms | 7.99 ms | 8.52 ms | — |
| N=1.8e7 (§2, ~0.6 s) | too slow to measure | — | 0.649 s (0.9× of C) | 0.600 s | 0.013 s (**45×**) |

At N=500 the row exists to catch a *regression*: `if ((v % 2 == 0))` used
to fork `bash -c` per inner iteration (~25k forks, 300× the interpreter);
the `let_compare` arith-operand arm lowers it natively, and the single-run
policy makes any return of the pathology immediately visible. At 1.8e7 the
row is the GPU showcase — a branchy, unvectorisable loop is exactly what a
single scalar thread does worst and a GPU does best.

**Reproduce:** §1 (`--problem collatz`) and §2 (`--problem collatz`).

---

## 5. uutils calling conventions — concurrent, threaded, fork/exec, capture

Three layers, because they answer different questions:

1. **Runtime micro-benchmark** — `benchmarks/uu-ffi/`: one invocation at a
   time (`bench.c`), and the capture / threaded conventions
   (`bench-concurrency.c`).
2. **End-to-end through the transpiler** — `benchmarks/uu-conventions/`:
   bash → C, for both the in-process and the `SH2_UU_FFI=0` fork/exec
   render of the *same source*.
3. **Corpus-level effect** — how many sites even take the in-process path
   (`UU-FFI.md` §10.2: shell-out sites 1674 → 1492, −11%, 552-file A/B).

### 5.1 The conventions, and which one a transpiled program actually reaches

| convention | where it lives | reached by a transpiled program? |
|---|---|---|
| **fork/exec** | `system("bash -c …")` sites | Yes — the fallback (`SH2_UU_FFI=0`, globs, env-prefixes, commands outside the absorb table) |
| **in-process plain run** | `_sh_uu_run` → `sh2_uu_run` → `uu_run(util, argc, argv)` | Yes — default rendering of `sort F`, `wc -l F`, … |
| **in-process capture** | `_sh_uu_capture` → pipe + **per-call reader thread** | Yes — `v=$(sort …)`, and the perl backend's temp-file variant behind `__sh_uu_capture` |
| **threaded / concurrent** (`cmd &`, `xargs -P`, `wait`) | nothing in the C backend | **No** — no `pthread_create` is emitted for background jobs. Measured at the runtime level only (§5.3) |
| **multicall / busybox-style dispatch** | the runtime resolves the utility from `argv[0]` (`sh2_uu_run` takes the basename: `strrchr('/')`), so a script naming `sort` and a script naming `/path/sort` take the *same* in-process path — verified: `--target c` emits `_sh_uu_av = {"sort", …}` in both. The distro image (`coreutils-ffi-multicall`, 116 hard links) and `/usr/bin/coreutils` are the *fork* arm's binaries in §5.2 | Yes — as a plain run; the distinction is only which binary a fork would have exec'd |
| **capture-by-temp-file** | perl backend (`__sh_uu_capture`) | Yes, for `--target pl` — no thread, so it is the convention to use where threads are unavailable (`UU-FFI.md` §6) |

`sh2_uu_capture`'s reader thread is the one *thread* in the C backend's
generated program; it is per-call, not concurrent (see §5.3 for why it
cannot be shared).

### 5.2 Runtime numbers — `benchmarks/uu-ffi/`

Input 200 lines / 2.2 KB (`input.txt`), same argv and same sink on every
arm. **Capture vs fork** (fresh, median of 5 × 200):

| arm | `wc -l` | `sort` | `grep -c .` |
|---|---:|---:|---:|
| `fork` + `execv` + read pipe | 950 µs | 887 µs | 955 µs |
| `sh2_uu_capture` (pipe + drain thread) | **57 µs** | **227 µs** | **160 µs** |
| `sh2_uu_run` to /dev/null (no capture, floor) | 22 µs | 192 µs | 118 µs |

**Plain run vs fork**, three ways (this session, 3 × 500, `results.csv`);
the *lower* of this session's two recordings, because the box was busy for
the second (see the ratio note below):

| arm | `wc -l` | `sort` | `grep -c .` |
|---|---:|---:|---:|
| fork+exec GNU (`gnuwc`, `gnusort`, `grep`) | 1955 µs | 1467 µs | 1836 µs |
| fork+exec uutils multicall | 4077 µs | 5317 µs | (no binary here) |
| in-process `sh2_uu_run` | **37.8 µs** | **385 µs** | **110–266 µs** |

**Read the ratios, not the absolutes** — this table moved by ~2.2× between
the early session (load ≈0.6) and this re-record (load ≈8.9, 40 min later),
*on the fork arms more than on the in-process ones*. Against the early
session: GNU fork `wc` 858→1955 µs, uutils fork `wc` 1959→4077 µs,
in-process `wc` 17.8→37.8 µs. So the recorded **ratios** are:

| util | vs GNU fork | vs uutils fork |
|---|---:|---:|
| `wc -l` | 17–52× | 54–108× |
| `sort` | 3.8–4.4× | 14× |
| `grep -c .` | 7–8× | (no binary) |

and the *first* recorded session (2026-11-27, load 4.7–14.0, 15 trials)
published 46–51× / 103–122× (`wc`), 4.2–5.0× / 15–24× (`sort`), 7.9–8.7×
(`grep`) — the same range. Quote the range and the conditions.
**Fork floor**: `/bin/true` through fork+exec is 0.45–1.28 ms per call on
this box across sessions (`exec-floor.txt`; 0.45 ms at load ≈0.7, 1.07 ms
at load ≈11, 1.28 ms at load ≈18) — a large part of every fork column, and
the clearest statement of why the absolute fork numbers are load-bound.

**3.9 MB capture** (beyond the 64 KiB pipe buffer; `results-big.csv`,
median of 3 × 30; the same run at load ≈0.7 gave 3.09 vs 0.39 ms/call):
fork+pipe 2.9 ms/call vs `sh2_uu_capture` 0.39 ms/call, identical 3.9 MB
payloads. This is the case the concurrent drain exists for — the naive
run-then-read sequence deadlocks here (`UU-FFI.md` §3).

### 5.3 Threaded — `bench-concurrency.c threads`

N worker threads, each calling `uu_run` back-to-back on a private fd-1
sink; 3 trials × 300 calls per worker (`results-threads.csv`).

| util | 1 thread | 2 threads | 4 threads |
|---|---:|---:|---:|
| `wc -l` | 20.8 µs / 48 k/s | 22.3 µs / 90 k/s | 24.1 µs / **166 k/s** |
| `grep -c .` | 110 µs / 9.1 k/s | 119 µs / 17 k/s | 124 µs / **32 k/s** |
| `sort` | 184 µs / 5.4 k/s | 186 µs / 11 k/s | 262 µs / **15 k/s** |

Per-call cost stays within 1.0–1.4× while aggregate throughput scales
2.0× (2 threads) and 2.8× (`sort` 2→4), 3.5× (`wc` 2→4). `sort` at 4
threads is the interesting cell: +42% per call (allocator contention in
its per-call setup) yet still 2.8× aggregate.

Three things this harness *established* about the threaded convention
(the first two are properties of the conventions rather than of uutils;
the third is a timing trap any threaded harness will hit):

- **`sh2_uu_capture` is not thread-safe by construction**: it redirects
  fd 1 process-wide. Two concurrent captures would interleave. Any future
  concurrent-capture convention needs per-thread state.
- **`uu_run` writes through stdio**, and this box's glibc takes its
  *lock-free single-thread* fast path once a program calls
  `setvbuf(stdout, …)` (the C backend emits exactly that). The first
  thread that touches stdio after threads exist either serialises on the
  stdout lock or aborts ("a printf deadlock was detected"). Each worker
  must therefore own fd 1 (a private sink) and must never restore it.
- **A `dup2`-based redirection + a clock read gave a 6 ms-stale time**,
  which reported a 6.5 ms loop as 29 µs per call — the failure mode to
  guard against in any threaded timing harness. The harness now times
  inside the redirect and reports the slowest worker's own loop.

Also fixed in `bench.c` itself: the in-process loop used a helper that
returns on the **first** non-zero exit, so a legitimately non-matching
`grep` (rc 1) would have measured one invocation and reported `iters`.
It now runs every iteration and reports non-zero exits in a `nonzero`
column.

### 5.4 End-to-end through the transpiler — `benchmarks/uu-conventions/`

Same bash sources, two renders of the *same* program, compiled `cc -O2`,
stdout gated against bash (`results.csv`, median of 3 × 1000):

| script | convention | uu leg (µs/call) | fork leg (µs/call) | ratio | stdout |
|---|---|---:|---:|---:|---|
| `sort.sh` | plain run `sort F` | 293 | 2252 | **7.7×** | same |
| `wc.sh` | plain run `wc -l F` | 22 | 2821 | **128×** | same |
| `sort-capture.sh` | capture `v=$(sort -r F)` + plain `wc` | 336 | 6315 | **18.8×** | same |

(An earlier run of the same command at load ≈0.5 gave 294/2317, 24/2205 and
388/4492 — the `fork` leg is the one that moves with load, which is the
point.)

The in-process leg is the default render (emitted `_sh_uu_run` /
`_sh_uu_capture` count 1 / 1 / 2); the fork leg is `SH2_UU_FFI=0` (count
0), i.e. the `bash -c` sites the in-process path replaces.

### 5.5 Reproducing §5

```sh
# --- runtime: single invocation, capture, threaded, big capture ---------
cc -O3 -o /tmp/bench-uu-ffi benchmarks/uu-ffi/bench.c \
   sh2perl/runtime/uu_run.c -I sh2perl/runtime -L sh2perl/runtime/lib \
   -lcoreutils_ffi -lpthread -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm
/tmp/bench-uu-ffi 500 3 benchmarks/uu-ffi/input.txt      # CSV matrix
/tmp/bench-uu-ffi --exec /bin/true 2000                  # fork+exec floor
/tmp/bench-uu-ffi --dump wc benchmarks/uu-ffi/input.txt /tmp/wc.out
cmp /tmp/wc.out <(gnuwc -l benchmarks/uu-ffi/input.txt)   # the agreement gate

cc -O3 -o /tmp/bench-uu-conc benchmarks/uu-ffi/bench-concurrency.c \
   sh2perl/runtime/uu_run.c -I sh2perl/runtime -L sh2perl/runtime/lib \
   -lcoreutils_ffi -lpthread -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm
/tmp/bench-uu-conc capture 5 200 benchmarks/uu-ffi/input.txt
/tmp/bench-uu-conc threads 3 300 4 benchmarks/uu-ffi/input.txt
/tmp/bench-uu-conc big     3  30 100000 /tmp/scratch.txt

# --- parity gates (correctness, not speed) -----------------------------
sh2perl/runtime/tests/parity_vs_bash.sh          # in-proc vs GNU, byte-identical
OTRANSPILER=$PWD/otranspilerl/target/debug/otranspilerl-cli \
  sh2perl/runtime/tests/c_backend_uu_ffi.sh      # default vs SH2_UU_FFI=0 vs bash
sh2perl/runtime/tests/parity_perl_uu_ffi.sh      # perl FFI arm vs fallback vs bash

# --- end to end through the transpiler ---------------------------------
bash benchmarks/uu-conventions/run.sh 1000
```

Prerequisites: `sh2perl/runtime/lib/libcoreutils_ffi.so` (build with
`sh2perl/runtime/build_uu_ffi.sh` when missing; it needs the out-of-tree
`uu-ffi` crate and rustc ≥ 1.88). The uutils **fork** arm needs the distro
multicall binary (`/usr/lib/cargo/bin/coreutils/wc` by default, override
`UUBENCH_UUTILS_WC`); the GNU arms `gnuwc`/`gnusort`/`grep` (`UUBENCH_GNU_*`).

---

## 6. Shellbench micro-suite — fork/exec-bound workloads

**Harness** `./bench.sh` (workspace root). It extracts the `#bench`
sections of a [shellbench](https://github.com/shellspec/shellbench) clone,
wraps each in an N-iteration loop calibrated so bash takes `CAL_MS` (300),
then times the *same* runner under bash, dash, transpiled JS
(`--target js` + `harness/sh2-namespace.mjs`) and transpiled C (the c
worktree's renderer, gated on stdout vs bash).

This is the only suite whose *design target* is the fork/exec / builtin
boundary: shellbench's sections are `assign`, `cmp`, `count`, `eval`,
`func`, `null`, `output`, `stringop1-4`, `subshell` — the work bash does
inside the interpreter plus the subprocesses it spawns.

**Reproduce**

```sh
harness/install-bench-toolchain.sh --node --shellbench   # missing pieces (§14)
cal() { :; }   # nothing else is needed when gcc/node/perl are present
CAL_MS=300 ./bench.sh                                    # all 12 samples, ~25 min
SHELLBENCH_DIR=/tmp/shellbench ./bench.sh /tmp/shellbench/sample/stringop1.sh
```

**Fresh captures** (2026-11-27, `CAL_MS` 80–300 because the box carried
load 5–20, 4–5 samples per run; bash/dash/js columns are complete — all 69
benches are in `../20261127_shellbench_fork_exec_only.md`; the **C column was
re-captured separately** for the 13 benches of `null`/`assign`/`count`/`func`
and is complete for those). ops/s, higher is better; `sh2[a b c]` = the JS
leg's `sh2.*` call-site tally (`harness/sh2stat.pl`: async / sync /
unsupported):

| bench | bash | dash | js | transpiled C | sh2[…] |
|---|---:|---:|---:|---:|---|
| `null:: command` | 140 k | 140 k | 139 k | **9.5 M** | 0 0 0 |
| `null:define function` | 97 k | 245 k | 96 k | **8.5 M** | 0 0 0 |
| `assign:local var (typeset)` | 74 k | 139 k | 97 k | **9.4 M** | 1 0 0 |
| `assign:variable` | 96 k | 244 k | 140 k | **9.1 M** | 1 0 0 |
| `null:assign variable` | 97 k | 131 k | 95 k | **4.7 M** | 0 0 0 |
| `count:increment` | 138 k | 2.9 k | 140 k | **8.4 M** | 1 0 0 |
| `count:typeset -i` | 62 k | 120 k | 24 k | **2.2 M** | 1 0 0 |
| `func:func` | 35 k | 124 k | 24 k | **2.0 M** | 1 0 0 |
| `cmp:[[ ]]` | 124 k | 66 k | **557 k** | — | 0 0 0 |
| `subshell:no subshell` | 203 k | 561 k | **993 k** | — | 0 0 0 |
| `output:print` | 778 | 30 k | 208 | — | 2 1 0 |
| `stringop2:substr 1 builtin` | 89 k | **14.6 M** | 175 k | — | 0 0 0 |
| `stringop4:str subst all builtin` | 96 k | **33.6 M** | 36 k | — | 0 0 0 |
| `stringop2:substr 1 echo \| cut` | 126 | 134 | **8.6 k** | — | 1 0 0 |
| `subshell:external command` | 1.4 k | 2.2 k | **15.6 k** | — | 2 1 0 |
| `sqrt1337` (whole script) | 17.6 s | 10.6 s | 0.064 s | **7.6 ms** | — |

What it says (and it is the same story as 2026-08-06, now measured):

- **Transpiled C is 15–200× over bash** on the benches it compiles: 2–9.5 M
  ops/s against bash's 35–140 k. The `sqrt1337` pipeline (10 k forks) is
  7.6 ms vs 17.6 s.
- **JS wins where the lowering is native** (`sh2[0 0 0]`): 1.4–5× over bash
  on `cmp`/`subshell:no subshell`/`brace`, and it *ties or beats* bash on
  most `assign`/`count`/`null` rows.
- **JS loses where dash's C builtins rule**: parameter expansion
  (`${v:0:1}` 14.6 M, `${v//p/r}` 33.6 M ops/s) is **60–1700×** the JS
  runtime. That is the bar, not a regression.
- **Fork/exec-bound rows are where transpiling pays most**:
  `echo | cut` 126/s → 8.6 k/s, `subshell:external command` 1.4 k/s →
  15.6 k/s, `eval:command subs` 932/s → 6.0 k/s.
- **Two honest reds**: `output:print` (JS 208/s vs bash 778/s — the
  `sh2[2 1 0]` runtime does the printing) and `assign:positional params`
  (JS 24 k/s vs bash 62 k — `sh2[1 0 0]`). Neither was blessed; they are
  in the table.
- **dash outliers**: `count:increment` 2.9 k/s (vs bash 138 k) — dash, not
  the transpiler, and a reminder never to read one column alone.

**Harness state — four real bugs fixed this session, one open:**

- The stale CLI path (`sh2perl/otranspilerl/…`) and the `file --estree`
  flag spelling: the CLI is `otranspilerl/target/debug/otranspilerl-cli`,
  there is no `file` subcommand, and the current CLI reads `--estree` as a
  *filename* (every JS cell was silently `ERR`). The JS leg now renders
  `--target shir | - --target estree` for the tally and `--target js` for
  the runnable program.
- The `#bench` extractor anchored on `^#bench` while the marker is
  **indented** inside each section's function wrapper — every sample
  yielded **zero benches** and the table printed an empty body. Fixed.
- `sqrt1337` read `~/sqrt1337.sh` (absent): every leg exited 127 in 1.5 ms
  and the table showed a bogus "0.0 s speed run". Now
  `sh2perl/sqrt1337.sh` (`SRC=` overrides).
- The C column: `run_c` never linked `-lgmp`/`-lm`, so every bench that
  constant-folds emitted `mpz_*` and **failed to link**, reported as a bare
  `ERR` — and there was no `shir_render` binary on this box at all. Fixed:
  the column now renders through the CLI's own in-process C backend
  (`--target c`, the renderer `harness/c_gate_main.sh` exercises) and links
  `-lgmp -lm`. Note the trap that cost a round trip: `--target shir |
  <external shir_render>` is **not** equivalent — the A1 ingress loses type
  verdicts without the renderer's own passes, and the `string length` bench
  rendered `var = _s1` (a pointer stored into a `long long`).
- **Open**: `assign:positional params` and `string length` still do not
  compile through the C backend (the former prints `ERR`, the latter is the
  `var = _s1` miscompile above), and `null:undefined variable` prints `ERR`
  for a `set -u` shape. Those are C-backend gaps to fix, not harness bugs.

The 552-example gates (`./fail`, `./fail-estree`) are *not* a substitute:
they measure correctness, not time (§10).

Both captures are in one file: `../20261127_shellbench_fork_exec_only.md` (the
name is historical — it was first taken while the C column was still `ERR`;
the C re-capture is appended there).

## 7. Shellbench report — 2026-08-06 (historical)

`20260806_shellbench.md` records the one full run: 69 benches across the 12
samples, timed under bash, dash, transpiled JS and transpiled C with
`gcc -O3` and `tcc -O0…-O3`. Headlines to re-check rather than quote:

- 17/69 benches rendered cleanly through the C backend and matched bash:
  **~35–43 M ops/s vs bash's ~137–175 k**, ~290×.
- 52/69 were honestly **WRONG** (outside the then-draft lowable subset:
  positional params, external `cut`/`sed`/`expr`, command substitution,
  `eval`, string tests, real subshells/pipelines) — never blessed, reported
  WRONG by the output gate.
- JS beat bash almost everywhere except where the lowering routes through
  the `sh2.*` runtime (parameter substitution `${v//p/r}`: bash 2.7–3.6×
  faster than JS; `expr substr` 1.9×; `print` 5×), and dash's C builtins
  beat the JS runtime 60–780× on string ops.
- `gcc -O3` and `tcc -O0…-O3` were within noise of each other on these
  micro-loops.
- `sqrt1337`: bash 14.5 s, dash 13.3 s, JS 0.27 s (~50×).

Re-run it with §6 once `/tmp/shellbench` and `node` are available; expect
the WRONG count to have fallen a lot (the C backend's lowable subset has
grown since, e.g. uu-ffi absorption of `sort`/`wc`/`cat`/`sed`/`awk`/`grep`).

## 8. JavaScript i64 / u64 / BigInt — `benchmarks/i64/`

Not bash benchmarks, but they pin the *homes* the estree backend picks for
bash's 64-bit integers (bash arithmetic is i64, JS `Number` is f64). Read
`benchmarks/i64/BinInt64.md` for the findings. **Re-verified 2026-11-27 with
node v22.23.5** (this box; the document's numbers came from node 24):

| op (ns/op) | plain `BigInt` | `BigInt64Array` load→compute→store | plain `Number` |
|---|---:|---:|---:|
| add | 10.54 | **1.66** | 1.12 |
| mul | 3.32 | **1.94** | 1.11 |
| div | 17.27 | 12.41 | **5.53** |

- The **typed-array int64 path survives the node-version change**: ~6×
  plain `BigInt` for add (1.66 vs 10.54), 1.7× for mul. That is the
  ordering the estree i64 homing relies on.
- **i64 and u64 cost the same** (`add-i64` 1.39 vs `add-u64` 1.41 ns/op in
  separate processes — the document's rule that mixing both in one process
  produces a spurious 10–20× penalty still holds).
- **u32 shares the int32 lane**: in `u32bench.mjs`, a `Uint32Array` cell
  read/write is 1.46 ns/op, a *plain* `BigInt` add 5.50, `BigInt64Array`
  1.30, `f64` 1.01 — the 32-bit typed array is not slower than the 64-bit
  one, and either is ~4× cheaper than a plain `BigInt` on every element.
- **The i64 fast path only survives inside the array** (`bench_bigint_final`):
  `typedRMW` 1.31 ns/op vs the same loop with the value observed every
  iteration 5.69 — materialising a `BigInt` costs ~4.4 ns and undoes the win.

Reproduce (needs `node` — now installed by §14):

```sh
cd benchmarks/i64
node bench_int_vs_float.mjs        # the document's numbers
node bench_bigint_final.mjs
node bench_u64_vs_i64.mjs add-i64  # ONE case per process (see the header)
node u32bench.mjs
node verify_bigint.mjs
```

`i64bench.mjs` additionally wants `/tmp/i64bench/ops.wasm` — build it with
`make` in `benchmarks/i64/` (rule added this session: `ops.c` → wasm32 with a
wasm clang, then copied to the absolute path the script reads); `h2h.mjs` wants `h2h_tcc.wasm`, which is **not built by anything in
the tree** (the file reads it relative to the CWD) — `nativecmp.c` is the
C half of that head-to-head. Both of those need a wasm/tcc build step before
they run; the five scripts listed above run as-is.

## 9. Python frontend — `docs/PY_BENCH.md`

`sh2perl/frontends/py-sh-go/profile_example/` (Python → A1 →
`otranspilerl --target c` → native C) against CPython and Cython, with
duration calibration, best-of-N, RSS and a startup floor. The harness is
present (installed by §14) but **cannot run on this box**: it needs the
py-sh-go frontend binary, which is a **Go** program
(`frontends/py-sh-go/Makefile`, ANTLR4+Go), and `go` is not installed. Its
two scripts also hard-code the superproject's `ROOT/frontends/py-sh-go/`
path (the sibling layout the workspace used before `frontends` became a
submodule), so the paths need `PYG=`/`TD=` overrides pointing at
`sh2perl/frontends/py-sh-go/` even once Go exists. Historical (2026-09-15 box):
`rolling_hash` 29×, `sum_squares` 43×, `bignum_mul` 3.4× (both sides on
GMP), line-I/O 3× vs CPython; py-sh-go ties typed Cython and beats
Cython-pure everywhere. Reproduce with §6 of that document
(`bench_vs_cpython.sh`, `bench_cython.sh`).

---

## 10. Measurements that are NOT speed (and must not be read as such)

These are the numbers people most often mistake for benchmark results:

| tool | measures | why it is not a benchmark |
|---|---|---|
| `./fail` | 552 examples, generated Perl vs bash stdout | correctness gate |
| `./fail-estree` | perl + estree legs vs bash, with the `sh2.*` op contract pre-flight (`node harness/estree-contract.mjs`) | correctness gate; also measures the sh2.* *call-site count* (a lowering signal, not time) |
| `harness/c_gate_main.sh` | generated C vs bash, optionally under ASan/UBSan/TSan | correctness + memory safety |
| `harness/pg-classify.pl`, `harness/pg-seam-sweep.pl` | *which* failures are parser fallbacks / which builtins get exec'd | triage |
| `harness/backend_runtime_metric.sh` | calls into each backend's own runtime namespace (`_sh_*`, `__sh_*`, `sh2.*`) | API size, not speed (the script says so) |
| `harness/rust-dogfood.sh` | how many `sh2perl/src/*.rs` functions the rust frontend lowers | progress on *blocker classes*, not time |
| `tests/coreutils/gate`, `tests/coreutils/metric` | 650-script coreutils corpus verdicts | correctness |
| `harness/c_seam_profile.sh` | `_sh_*` helper call sites in emitted bodies | frequency ranking |
| `docs/transform-verification.md` | transform conformance (Verus/proof lane) | proof, not timing |

`benchmarks/uu-ffi` *site counts* are in the same family: `UU-FFI.md`
§10.2's "1674 → 1492 shell-out sites (−11%), 30 files" is a **render-count
change** — it says the in-process path is *reached*, which is why §5's
timings are needed to say it is *worth* reaching.

---

## 11. Method rules these harnesses follow (copy them)

1. **Agreement before numbers.** Every suite above gates output (and exit
   code, or a checksum at scale) against the reference *before* printing a
   time. A fast-but-wrong leg prints `WRONG`/`FAIL`, never a number.
2. **Same work per column.** One synthesized runner/source is executed by
   every leg; N is fixed per problem (§1, §2) or calibrated once (§6,
   `bench_sqrt.sh`, §9).
3. **Interleave or rotate the legs** (both uu-ffi harnesses alternate arm
   order per trial) so a drifting load average cannot favour one arm.
4. **Read ratios, not absolutes.** The box carries other load (it is a WSL
   host running a dozen agent workers); a single CPU-leg timing moved up to
   4× between suite runs. Every suite here reports a median/best-of-N and
   the discussion is about ratios.
5. **A skip must say why.** A missing device/toolchain prints
   `SKIP (reason)` — or the table lies by omission (§2's Vulkan fix).
6. **A harness that measures nothing must fail loudly.** §6's extractor
   printed an empty table for months; §5.3's first version reported 29 µs
   per call for a 6.5 ms loop. Both now have evidence fields (bench count,
   `sink_bytes`, `calls_ok`) that would have caught it.

---

## 12. Environment, and what degrades without it

Checked on this box (`command -v`): `cc`/`gcc` ✅, `perl` ✅, `python3` ✅,
`bash` ✅, `dash` ✅, `rustc` ✅ (but no buildable rust-frontend benchmark),
CUDA ✅ (`/dev/nvidia*`, `nvidia-smi`), and after §14: `node` ✅,
`frontends` ✅, `/tmp/shellbench` ✅. Missing: `tcc` (`bo4-tcc` is really
`bo4-cc` — the driver column), `glslangValidator` (Vulkan legs `SKIP`),
`go`, `zig`, `cython` (`docs/PY_BENCH.md` §5 needs it).

Box-health notes that affect timing: the host is shared with a dozen agent
workers and a page-cache/writeback guard set (see `AGENTS.md` **Box-health
guards**); `sh2workers`/`sh2gates` are capped at `memory.high` 8G/9G and
IO at 32 MB/s per cgroup. A build or a large `sort` in another worktree is
visible in these tables — prefer the committed ratios over a single fresh
run.

## 13. Reproduce everything, in order

```sh
# 0   missing pieces (idempotent; see 14)
harness/install-bench-toolchain.sh --check
harness/install-bench-toolchain.sh          # node, C column check, shellbench, frontends

# build the toolchain once
(cd otranspilerl && cargo build --bin otranspilerl-cli)
(cd bash-o4 && cargo build --bin bash-O4 && cargo build --examples)
sh2perl/runtime/build_uu_ffi.sh            # only when libcoreutils_ffi.so is missing

# 1-2 + 4.2  CPU and optimised suites (needs tcc for the tcc column)
(cd bash-o4 && RUNS=3 bash bench/bench.sh && RUNS=3 bash bench/bench-opt.sh)

# 3   autoshaderisation candidacy (no device needed to inspect)
(cd bash-o4 && target/debug/bash-O4 --check bench/sh/collatz.sh)

# 3a  autoshaderised bash vs gcc -O3 at large N (GPU; needs a CUDA device)
(cd bash-o4 && cargo build --examples && \
 for p in sumred squares-map collatz hashred; do \
   target/debug/examples/cutranspile bench/sh/$p.sh \
     $(case $p in sumred) echo 1000000000;; squares-map) echo 1000000000;; \
        collatz) echo 180000000;; hashred) echo 1000000000;; esac) --runs 5; done)

# 4.1 sqrt1337 showcase (node optional: the JS rows are skipped without it)
SRC=$PWD/bash-o4/bench/sh/sqrt1337.sh bash bench_sqrt.sh
bash show_sqrt_langs.sh

# 5   uutils conventions: runtime, then end-to-end through the transpiler
bash benchmarks/uu-conventions/run.sh 1000
#     (runtime harness build lines are in §5.5)
sh2perl/runtime/tests/parity_vs_bash.sh

# 6   shellbench (~25 min for all 12 samples; corpus via the installer above)
./bench.sh
./bench.sh /tmp/shellbench/sample/stringop2.sh        # one sample

# 8-9 JS i64 and Python frontend (need node / cython respectively)
(cd benchmarks/i64 && node bench_int_vs_float.mjs)
(cd sh2perl/frontends/py-sh-go/profile_example && ./check_cpython_parity.sh)
```

---

## 14. Installing the missing toolchain — `harness/install-bench-toolchain.sh`

§12's gaps are provisionable; the ones that are *not* (system packages) say
so instead of failing quietly.

```sh
harness/install-bench-toolchain.sh --check     # what is present / missing
harness/install-bench-toolchain.sh             # all four steps
harness/install-bench-toolchain.sh --node      # one step
```

Each step is idempotent and ends in a PASS/SKIP/FAIL line, so a step that
silently did nothing cannot read as done.

| step | what it does | state after this session |
|---|---|---|
| `--node` | downloads the latest v22.x **linux-x64/arm64** tarball from nodejs.org, verifies it against `SHASUMS256.txt`, installs under `~/.local/<ver>/` and symlinks `~/.local/bin/node` (no root) | **installed** v22.23.5 — the JS columns of §1/§4.1/§6/§8 now run |
| `--shellbench` | `git clone --depth 1` shellbench into `/tmp/shellbench` | **installed** — 12 samples; §6's 69 benches ran |
| `--frontends` | `git submodule update --init frontends`, then a plain-clone fallback | **cloned at HEAD `b2ed44f`** — see the caveat below |
| `--bench-c` | verifies what the §6 C column actually needs: the CLI's `--target c` plus **libgmp** headers; renders one sample and compiles+runs it | **verified** — this (with the §6 fix) turned the C column from `ERR` to numbers |

**`frontends` caveat (real, not incidental).** The superproject pins
`frontends` at `de7f53d3…`, which the frontends remote **no longer serves**
(`git ls-remote` finds nothing for it; the submodule checkout fails). The
installer therefore clones HEAD (`b2ed44f`) and prints the mismatch. The
benchmark harness (`sh2perl/frontends/py-sh-go/profile_example/`) is present
and complete at that commit, but **record which commit you benchmarked** —
the pinned tree cannot be reconstructed from that remote. The proper fix is
a gitlink bump in `sh2perl` to a served commit.

Two further gaps keep §9 from running even with the checkout in place:
the py-sh-go frontend is a **Go** program (no `go` here — see below), and
both PY_BENCH scripts resolve `ROOT/frontends/py-sh-go/...` (the pre-submodule
sibling layout) instead of `sh2perl/frontends/...`, so they need `PYG=`/`TD=`
overrides.

**Not installed, on purpose:** `tcc`, `glslangValidator`, `go`, `zig`,
`cython` are system packages and this box has **no passwordless sudo**. The
installer never invokes sudo (a password prompt would hang an agent run);
it probes with `timeout 5 sudo -n true` and skips. Ask for them out of band
(the workspace `request_root` flow) — until then `bo4-tcc` stays a `cc`
column, the Vulkan legs `SKIP`, and `PY_BENCH` §5 cannot run.
