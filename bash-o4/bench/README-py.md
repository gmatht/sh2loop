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

## Results (`--scale opt`, runs=3, RTX 2070 Super / WSL, gcc 13.3)

| problem | N | gcc-O3 | pyo4-gcc | pyo4-gpu | GPU vs C |
|---|---:|---:|---:|---:|---:|
| sumred | 1e9 | 572 ms | 67480 ms (GMP) | **3.76 ms** | **152x** |
| collatz | 1.8e7 | 774 ms | 892 ms | **12.70 ms** | **61x** |
| squares-map | 1e8 | ~280 ms | 27433 ms (GMP) | ~270 ms (fused) | ~1x |

All checksums byte-agree across legs. `pyo4-gpu` reproduces the bash
`cutranspile` times on the same shapes (4.07 ms / 13.79 ms), i.e. the
Python frontend reaches the same kernels.

Fast scale (`--scale fast`, CPython included) is for correctness, not
throughput: at 1e6 the GPU legs are launch-dominated (0.2–0.3 ms) and
the CPU legs ~1–3 ms vs CPython 114–330 ms.

### Reading the numbers

- **The GPU win is on reductions.** A 1e9-trip mod-reduce and an
  18M-trip branchy Collatz chain beat the handwritten C ceiling by
  152x / 61x — the two things a single scalar thread does worst.
- **`squares-map` is fused** (map + reduce, partials only read back) and
  lands at parity with C: it is transfer/allocation-bound (800 MB of
  device traffic + an 800 MB device allocation per dispatch on shared
  RAM). The `bench-opt.sh` note records the same for the hand kernels —
  that row is physics, not a lowering gap.
- **The GMP rows are Python semantics**: unbounded ints past ±2^53 lower
  to exact `mpz_t` unless a width is provable (collatz's ranges are;
  sumred's mod-chain composition hides them). The CUDA path is i64-exact
  by construction and agrees.
- Sub-10 ms rows are startup-dominated; compare the `opt` rows.

## Reproducing

```sh
cd bash-o4 && cargo build --bin python-O4
python3 bench/bench-py.py                            # fast, all problems
python3 bench/bench-py.py --scale opt --problem sumred
python3 bench/bench-py.py --scale opt --save results-py.tsv
```

`TIMEOUT` (default 900) caps each run, so a hung leg fails loudly.
