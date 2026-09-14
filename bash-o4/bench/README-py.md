# bench-py — python-O4 vs CPython vs pure C

Driver: [`bench-py.py`](bench-py.py) (`--scale fast|opt`, `--runs N`,
`--problem NAME`, `--save FILE`; `RUNS`/`TIMEOUT`/`PYTHON_O4`/`CC` env).

The Python counterpart of [`bench.sh`](bench.sh) /
[`bench-opt.sh`](bench-opt.sh): same problems, same median timing, same
**agreement gate** (every running leg's stdout must byte-agree before any
number is reported). The difference is the input: every leg is a Python
program fed to `python-O4`.

```
bench/py/<name>.py  --(py-sh-go)-->  A1 shIR  --(python-O4)-->  C (tcc/gcc)
                                                     └--candidacy-->  PTX→GPU
```

## Legs

| leg | meaning |
|---|---|
| `cpython` | real CPython (floor reference; skipped at `--scale opt`) |
| `pyo4-tcc` | `python-O4 -o` (default driver path: rendered C via tcc) |
| `pyo4-gcc` | the same rendered C recompiled with `gcc -O3` (backend quality) |
| `gcc-O3` | handwritten C from `bench/c/` (CPU ceiling) |
| `pyo4-gpu` | `python-O4 --gpu` (TRANSPILED Python→ShIR→PTX dispatch) |

`pyo4-gcc` vs `gcc-O3` isolates backend quality; `pyo4-tcc` vs `pyo4-gcc`
the tcc-codegen signal; `pyo4-gpu` vs `gcc-O3` is the prize.

## Problems (`py/`, `c/`)

| problem | N (fast / opt) | shape |
|---|---|---|
| `addsum` | 1M / 1M | `s += i` (i64 accumulate) |
| `addsum32` | 46340 | same source, int32-exact sum |
| `squares` | 1M / 1M | `s += i*i` |
| `hash` | 1M / 1M | per-record mix mod 256 |
| `collatz` | 500 / 18M | branchy while+if/else (sequential-lane reduce) |
| `sumred` | 1M / 1B | mod-2^32 accumulate of `i*i` |
| `squares-map` | 10k / 100M | materialise `a[i]=i*i`, then checksum |
| `sqrt1337` | — | string containment — **SKIP** (py-sh-go v1 gap) |

`N` is substituted into the source's `N = …` line by the driver. The
GPU leg uses the same source as every other leg: `python-O4` rewrites a
counted loop's single `a.append(v)` into the affine store `a[i] = v` for
the candidacy view, so the CPython-valid append source is also the
GPU-candidacy shape (`docs/PYTHON-O4.md` §2).

## Results (`--scale opt`, runs=1, RTX 2070 Super / WSL, gcc 13.3)

| problem | N | gcc-O3 | pyo4-gcc | pyo4-gpu | GPU vs C |
|---|---:|---:|---:|---:|---:|
| sumred | 1e9 | 1041 ms | 1175 ms (0.89x) | **3.55 ms** | **293x** |
| collatz | 1.8e7 | 1005 ms | **687 ms** (speculative, exact — 1.46x C) | **13.9 ms** | **72x** |
| squares-map | 1e8 | 278 ms | **170 ms** (1.63x) | ~950 ms | ~0.3x |

All checksums byte-agree across legs. `pyo4-gpu` reproduces the bash
`cutranspile` times on the same shapes (4.07 ms / 13.79 ms), i.e. the
Python frontend reaches the same kernels.

Fast scale (`--scale fast`, CPython included) is for correctness, not
throughput: at 1e6 the GPU legs are launch-dominated (0.2-0.3 ms) and
the CPU legs ~1-5 ms vs CPython 1100-1700 ms.

### Reading the numbers

- **The GPU win is on reductions.** A 1e9-trip mod-reduce and an
  18M-trip branchy Collatz chain beat the handwritten C ceiling by
  293x / 61x — the two things a single scalar thread does worst.
- **collatz's CPU row is GMP now, and that is correct**: its inner
  `v = 3*v+1` is not provably bounded (the test workload's actual peak is
  9232), so the old 892 ms i64 leg
  was the B1 miscompile class (silent overflow for some inputs). The
  CUDA leg is i64-exact by construction and unchanged. Recovery needs
  overflow-guarded i64→GMP tiering (`docs/PYTHON-O4.md` §8.1 B1).
- **The other CPU legs are no longer GMP.** The mod-reduce and map rows used
  to run 67480 ms / 27433 ms in GMP because the frontend proved integer
  ranges against the JS Number bound (2^53). With `--exact-i64` (prove
  against signed i64) plus the generic versioning plan accepting the
  frontend's structured condition, they run native: **1175 ms** and
  **170 ms**. The CUDA path is i64-exact by construction and agrees.
- **`squares-map` CPU beats the handwritten C (1.63x) by doing less
  work**: the shared `fuse-fill-consume` transform forwards the
  single-append fill into its same-index consumer, so the 800 MB
  materialisation disappears on the CPU path. The CUDA leg still
  materialises (it is the map vehicle) and is transfer-bound — the
  source is shared, the lowering is not. Read that row as "CPU > C
  because it does less", not as a kernel-quality claim.
- **`pyo4-tcc` is tcc-codegen-bound** (0.04x); it is the default
  `python-O4 -o` path, so use `gcc` when measuring backend quality.
- Sub-10 ms rows are startup-dominated; compare the `opt` rows.

## Reproducing

```sh
cd bash-o4 && cargo build --bin python-O4
python3 bench/bench-py.py                            # fast, all problems
python3 bench/bench-py.py --scale opt --problem sumred
python3 bench/bench-py.py --scale opt --save results-py.tsv
```

`TIMEOUT` (default 900) caps each run, so a hung leg fails loudly.
