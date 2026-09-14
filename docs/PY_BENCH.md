# PY_BENCH — how effective is the Python→C transpiler?

**Scope.** Measures the `py-sh-go` frontend (Python source → A1 shIR →
`otranspilerl --target c` → native C) against CPython and against
Cython, on the same source and workload. It answers two questions
separately:

1. *Does the transpiled code compute the right thing?* (differential
   correctness, §3)
2. *Is it faster, and better than the obvious alternative?* (wall time
   + peak RSS, §4–§5)

Everything is reproducible from
`frontends/py-sh-go/profile_example/`; §6 has the by-hand commands.

Status: living document. The §3–§5 captures are from the dev box
(2026-09-15, Python 3.12.3, gcc 13.3.0, Cython 3.0.8) and are
*indicative*, not a gate — see §7 for why absolute numbers move. The
shared C-backend profile/width work (`docs/PYTHON-O4.md` §2.4, §8.1)
landed after earlier captures and is reflected here.

---

## 1. What is actually being measured

The pipeline is:

```
app.py --py-sh-go--> A1 shIR JSON --otranspilerl --target c--> app.c --gcc -O2--> app
```

The A1 shIR is the contract between frontend and backend (PLAN.md §1),
so the C is generated from a language-neutral IR, not from a
Python-specific code path. The comparison targets are:

| column | how it is produced | annotations needed |
|---|---|---|
| CPython | `python3 app.py` | — |
| Cython (pure) | `cython --embed -3 app.py` | none |
| Cython (typed) | a hand-written `.pyx` with C types | all of them |
| py-sh-go C | the pipeline above | none |

Cython is the fair yardstick: it is also a source-to-C compiler for the
same input language. The typed columns are deliberately written to be
the *ceiling* — the I/O one does the same growable `char**`+`strdup`
list upkeep as `app.py`, and the bigint one binds GMP by hand because
Cython has no native big-int.

## 2. Method

- **Correctness first.** Every implementation's stdout is compared with
  CPython before it is timed; a mismatch aborts the row.
- **Duration calibration.** Workload sizes are *not* fixed: the harness
  bisects a single constant until the **CPython baseline** lands in
  `[0.8·T, 1.25·T]` seconds, with `TARGET_SECS` clamped to the
  documented **1–100 s** band (default 5 s). All implementations then
  run the same source at the same N. This is why the reported N differs
  between runs (`rolling_hash` ×20 000 000 here, ×6 000 000 there):
  machine speed is calibrated away, not assumed.
- **Best-of-N.** Each cell is the best of `REPS` runs (default 3; the
  captures below used 2 for time). The calibration probes use a single
  run because `REPS` would make bisection too slow.
- **Resident memory.** Peak RSS from `/usr/bin/time -f %M`, one run.
- **Startup is reported separately.** Cython `--embed` links and
  initialises libpython, so it has a large fixed cost that has nothing
  to do with the compiled loop. Printing the empty-program floor first
  stops that cost being mistaken for throughput.
- **Compiler levels:** both sides `-O2` for the C benchmark; the typed
  `.pyx` files carry `boundscheck=False, wraparound=False,
  initializedcheck=False, cdivision=True` and are compiled `-O2`
  (`CFLAGS_CY` overrides).

## 3. Correctness: the whole frontend corpus vs CPython

`check_cpython_parity.sh` runs every `frontends/py-sh-go/testdata/*.py`
through Python → A1 → C, compiles, executes, and diffs stdout with
CPython:

```
total 95   match 92   mismatch 3   emit fail 0  cc fail 0  timeout 0
  t91_set_sum_fallback        known C-backend gap (in KNOWN_GAPS)
  t86_factor, t88_factor53    NEW — concurrent core-worker regression
```

- `t91` is a **C-backend** gap (a set with one bigint element: the C sum
  accumulator is not exact for that shape).
- `t86`/`t88` are **not** the profiler/width work: they reproduce with
  the recent C-backend changes reverted, and the frontend A1 is
  byte-identical across those versions. Their `int(n**0.5)` isqrt call
  reaches an `sh2_stub` in the shared renderer — a regression from the
  concurrent `isolate-accumulate` / `fuse-fill-consume` / `shir_passes`
  WIP in the tree. They are left **red on purpose** (never blessed): it
  is a real correctness bug for whoever owns that WIP.

The frontend itself passes **95/95** through the ESTree backend (the
py-sh-go gate). Known gaps are listed in the script
so a *new* mismatch fails the run, and a resolved one is reported
("known gap RESOLVED — remove from KNOWN_GAPS") rather than silently
tolerated.

## 4. CPython vs transpiled C

`bench_vs_cpython.sh` (capture: `TARGET_SECS=3 REPS=2`):

```
sizes: sum_squares=10000000  rolling_hash=16000000  bignum_mul=300000  io=8000000 lines

rolling_hash (16000000)          time(s)   rss(MB)   speedup
  CPython                          2.712      10.1      1.0x
  C                                0.100       1.6     27.1x

sum_squares (10000000)           time(s)   rss(MB)   speedup
  CPython                          1.608     392.5      1.0x
  C                                0.038      78.3     42.0x

bignum_mul (300000 x*=3 from 2**100)
  CPython                          3.267      10.2      1.0x
  C (GMP)                          1.318       2.2      2.5x

app.py (io/8000000 lines)
  CPython                          3.152     684.7      1.0x
  C                                0.977     429.9      3.2x
```

Read the shapes, not one number:

- **Scalar recurrence** (`rolling_hash`, non-foldable modulo loop):
  ~27× faster, 6× less RAM. This is CPython's boxed-`PyLong` +
  bytecode-dispatch cost, which the C loop simply doesn't pay (the C
  backend versions the counted loop too — `docs/PYTHON-O4.md` §2.4).
- **Vector + wide aggregate** (`sum_squares`): ~42×, 5× less RAM. The
  C uses a native `long long` vector and an **exact `__int128` sum**;
  CPython allocates 10 M `PyLong`s.
- **Bigint** (`bignum_mul`): only ~2.5×. Both sides call GMP / CPython's
  big-int, which are in the same league; the win is memory (5×) and, in
  the Cython table, startup. This is the honest counterweight to 27–42×.
- **Line I/O** (`app.py`): ~3.2×, 1.6× less RAM. Both read lines and
  store two growable lists; the win here is smaller and dominated by
  parsing/alloc, not arithmetic.

## 5. Cython: pure and typed

`bench_cython.sh` (capture: `TARGET_SECS=3 REPS=2`):

```
sizes: rolling_hash=16000000  sum_squares=10000000  bignum_mul=300000  io=8000000 lines

startup floor (empty program)    time(s)   rss(MB)   speedup
  CPython                          0.030       0.0      1.0x
  Cython (embedded)                0.031       0.0      1.0x
  py-sh-go C                       0.000       0.0     63.0x

rolling_hash (16000000)          time(s)   rss(MB)   speedup
  CPython                          2.643      10.1      1.0x
  Cython (pure)                    3.119      11.0      0.8x
  Cython (typed)                   0.084      11.1     31.4x
  py-sh-go C                       0.091       1.7     29.1x

sum_squares (10000000)           time(s)   rss(MB)   speedup
  CPython                          1.438     394.0      1.0x
  Cython (pure)                    1.809     395.4      0.8x
  Cython (typed)                       -         -   n/a (no __int128)
  py-sh-go C                       0.033      78.0     44.1x

app.py (io/8000000 lines)        time(s)   rss(MB)   speedup
  CPython                          2.909     683.8      1.0x
  Cython (pure)                    5.419     685.5      0.5x
  Cython (typed)                   0.960     439.3      3.0x
  py-sh-go C                       0.907     430.8      3.2x

bignum_mul (300000 x*=3 from 2**100)
  CPython                          2.797      10.1      1.0x
  Cython (pure)                    2.903      11.2      1.0x
  Cython (typed)                   0.845      11.4      3.3x
  py-sh-go C (GMP)                 1.249       2.1      2.2x
```

### What this says

1. **Cython-pure is not faster than CPython on any shape** (0.5–1.0×).
   Compiling to C does not help while values stay boxed `PyLong`s and
   every operation still crosses the C-API. Cython is a *typed*
   compiler; without types it is CPython at C speed with extra
   indirection.
2. **Typed Cython wins only after a human rewrites the hot code** with
   `cdef` types (and, for bigint, hand-binds GMP via
   `cdef extern from "gmp.h"`). Where it applies it is fast: it *ties*
   py-sh-go on `rolling_hash` (0.084 vs 0.091, within run noise) and
   py-sh-go edges it on I/O (0.907 vs 0.960), the expected result for two
   compilers emitting the same C.
3. **The differentiators for py-sh-go are what it does without help:**
   - it infers the types (no annotations), so it wins on the shapes
     where Cython-pure is slow;
   - it starts in **<1 ms** vs Cython's **~31 ms** (it does not link
     libpython) — a 63× floor that dominates short programs;
   - it stays at **~2 MB** RSS on bigint vs Cython's ~11 MB (again no
     interpreter runtime);
   - it emits an **exact `__int128` aggregate** for `sum(xs)` that
     hand-typed Cython cannot express without GMP (hence the `n/a`).
4. **Typed Cython edges out py-sh-go on bigint time** (0.845 vs
   1.249 s) — see §8, finding B: a codegen quality gap (an aliasing copy
   plus `mpz_mul` where `mpz_mul_ui` would do), not a fundamental one.

## 6. Reproducing by hand

All commands run from the workspace root unless noted. `$CLI` is the
backend CLI; the frontend is a Go binary.

### 6.1 Build the toolchain

```sh
cd otranspilerl && cargo build --bin otranspilerl-cli && cd ..
cd frontends/py-sh-go && make build && cd ../..
```

### 6.2 Transpile one app and run it

```sh
cd frontends/py-sh-go
CLI=../../otranspilerl/target/debug/otranspilerl-cli

# Python -> A1 shIR (the `--raw` byte-equality contract)
./py-sh-go --shir profile_example/bench/rolling_hash.py --raw > /tmp/app.shir.json

# A1 -> C. Run from inside the workspace (or export OTRANSPILER_ROOT=$PWD/../..)
"$CLI" - --target c < /tmp/app.shir.json > /tmp/app.c

# C -> binary. -lgmp is harmless when unused; required for bigint.
cc -O2 -o /tmp/app /tmp/app.c -lgmp

python3 profile_example/bench/rolling_hash.py   # reference
/tmp/app                                        # must print the same
```

`--target shir` echoes the A1 back; `--target js|go|rs|zig|java|pl|py`
renders other backends from the same IR if you want a cross-target check.

### 6.3 Compile the same app with Cython

```sh
# pure: no annotations
cython --embed -3 bench/rolling_hash.py -o /tmp/cy.c
cc -O2 -o /tmp/cy /tmp/cy.c $(python3-config --includes) $(python3-config --ldflags --embed)

# typed: a hand-written .pyx (see profile_example/bench/cython/)
cython --embed -3 bench/cython/rolling_hash_typed.pyx -o /tmp/cyt.c
cc -O2 -o /tmp/cyt /tmp/cyt.c $(python3-config --includes) $(python3-config --ldflags --embed)

# bigint typed additionally needs -lgmp (it binds GMP by hand)
```

`python3-dev` (for `Python.h`) and `cython` are required; both are
present in the dev image.

### 6.4 Time it the way the harness does

```sh
# best-of-5 wall time, high resolution (µs), stdout discarded
for i in 1 2 3 4 5; do /usr/bin/time -f "%e" /tmp/app >/dev/null; done
# or the harness timer, which measures a subprocess precisely:
python3 - <<'PY'
import subprocess, time
best = min(
    (lambda t0: (subprocess.run(["/tmp/app"], stdout=subprocess.DEVNULL), time.perf_counter()-t0)[1])(time.perf_counter())
    for _ in range(5))
print(f"{best:.6f}")
PY

# peak RSS in kB
/usr/bin/time -f "%M" /tmp/app >/dev/null
```

### 6.5 Run the calibrated suites

```sh
cd frontends/py-sh-go/profile_example

./check_cpython_parity.sh                 # correctness, 95-file corpus
TARGET_SECS=5 REPS=3 ./bench_vs_cpython.sh # CPython vs C
TARGET_SECS=5 REPS=3 ./bench_cython.sh     # + Cython pure/typed
```

Useful knobs (all env):

| var | default | meaning |
|---|---|---|
| `TARGET_SECS` | 5 | CPython baseline target, clamped to 1..100 s |
| `REPS` | 3 | best-of-N per cell (calibration probes are single-run) |
| `CC` / `CFLAGS` / `CFLAGS_CY` | `cc` / `-O2` / `-O2` | compilers |
| `LIST_CAP` | 10000000 | `sum_squares` cap (10 M boxed ints ≈ 1 GB) |
| `IO_CAP` | 20000000 | I/O line cap (memory guard) |
| `OUT` | `out/{bench,cython}` | artifacts: `.c`, `.json`, `.pyx`, logs |

Each generated row keeps the exact `.c` that ran, so a surprising number
can be traced to the code, and the calibration sizes are printed at the
top of every run.

## 7. Why the numbers wobble (and how not to be fooled)

- **Shared machine.** The dev box also runs other agents/builds; a
  `cargo build` in another worktree can double a wall time. Best-of-N
  mitigates but does not remove this. Treat ratios as the signal, not
  the third decimal.
- **Calibration probes are single-run**, so the final N can land just
  outside the band (e.g. `sum_squares` is capped at `LIST_CAP=10M`, so
  its CPython time is ~2.7 s even at `TARGET_SECS=5`).
- **Memory-heavy shapes are capped** for the same reason: CPython at
  10 M ints is already ~390 MB, and 6 M stored lines ~515 MB.
- **Startup is a real cost, not noise.** It is reported explicitly; for
  programs that exit in milliseconds it dominates everything else.
- **Do not compare a `-O2` C row with an `-O3` typed row**; keep
  `CFLAGS_CY=CFLAGS`.
- The harness **retries the A1→C step** because the shared
  `otranspilerl-cli` binary can be relinked by concurrent workers
  mid-run; a transient there is not a benchmark result.

## 8. Findings from building this (open work)

The benchmark earned its keep by surfacing five real issues. Three are
fixed (A, D, E); two are open (B, C). The most serious — E, a silent
miscompile of valid Python — was found here and is now fixed, and the
performance it cost has since been recovered (`docs/PYTHON-O4.md` §8.1
B1): the exact build is now *faster* than the unsound one.

**A. Fixed — `long long` int-array sum wrapped.** At 10 M elements the C
`sum(xs)` printed `1291890006563070912` where CPython printed
`333333283333335000000`. The native int-array aggregate was `long long`.
It now accumulates in `__int128` (exact for any memory-sized i64 array,
`M·2^64 < 2^127`) and prints through `_sh_i128_str`. Recorded in the
parity suite and by the `sum_squares` row.

**B. Open — bigint multiply is not `mpz_mul_ui`.** For `x = x * 3` the
backend emits

```c
mpz_set(_bigint_tmp_1, x);
mpz_mul(x, _bigint_tmp_1, _bigint_3);
```

two GMP calls plus an aliasing copy, where typed Cython emits
`mpz_mul_ui(x, x, 3)` — one call. That is most of the 1.83 s vs 2.83 s
gap in the bigint row. Proposed: when one operand is a small literal
constant, emit `mpz_mul_ui`/`mpz_add_ui`/`mpz_sub_ui`, and drop the
copy when the target aliases the left operand (GMP allows `a = a * b`).

**C. Open — computed int lists fall back to a string vec.** `sum(xs)`
licenses the C backend to home `xs` as a native vector. Replace the
reduction with an explicit accumulator

```python
xs = []
total = 0
for i in range(N):
    xs.append(i * i)
    total = (total + i * i) % 1000000007
```

and `xs` becomes `char **` with `snprintf` + `strdup` per element
(measured ~0.37 s vs ~0.05 s at the sizes above): a 25× regression on a
program that should be identical. The fix is in the int-array analysis
(home an array as native when every element is int-domain and it is
never used as text), not in the benchmark.

**D. Fixed earlier — profile visibility** (`docs/PROFILING.md`,
`docs/DUAL_LOOPS.MD` §4). The profiler's value bucket
saturated because the *instrumented* build wrapped first; a wide probe
(`SH2_PROFILE_WIDE`) plus bucket 17 now distinguishes 64 / 128 /
arbitrary, letting the build pick `__int128` instead of GMP
(`profile_example/run_width_demo.sh`).

**E. Fixed — unproven loop-carried ints overflowed.** The frontend's
range proof is straight-line, so a loop-carried accumulator it could not
bound was typed native and silently wrapped — in the **default** path,
not only under a profile flag:

```python
f = 1
for i in range(1, 30):
    f = f * i
print(f)     # CPython 8841761993739701954543616000000
```

The transpiled C printed `-7055958792655077376`. Fixed by (1) a
loop-growth guard (`growsUnbounded`) that forces a self-multiplying
loop-carried accumulator to the exact bigint domain, (2) the
`x % m → [0, m-1]` range rule firing from the divisor alone (so
mod-bounded accumulators stay native), and (3) a C-backend fix that a
mixed plain/bigint variable is declared and stored consistently as
`mpz_t`. `factorial(30)` is exact now; sumred/addsum/squares stay
native. Genuinely unprovable growth (collatz) was exact-but-GMP
(~154 s vs the unsound 892 ms); it is now recovered by a **speculative
dual arm** and lands at **687 ms (1.46x the handwritten C)**, still
exact (`docs/PYTHON-O4.md` §8.1 B1). The recovery was stepwise: an i64
fast arm with a one-compare affine overflow check (and
`__builtin_*_overflow` for the general case) plus an exact GMP replay on
the cold flag, a native store for i64-provable bigint assignments, and
speculation at the **outer** loop (so the i64<->mpz handoff is paid
once).

## 9. Non-goals and next yardsticks

- Not a gate: timing is informational (repo testing policy). The
  correctness harness (§3) is the gate-able part.
- **Numba** (`@njit`) and **PyPy** would test the same loop against a
  JIT rather than an ahead-of-time compiler — the missing row.
- **Cross-target**: the same A1 already renders C/Go/Rust/Zig/Java/
  Perl/Python/JS; a "one app → N languages, same stdout, time each"
  table would demonstrate the universal-shIR value rather than C alone.
- **Coverage, not pass/fail**: classify refusals vs miscompiles per
  Python construct, and run the stdin-using corpus files with inputs.
- **Embedding**: `main()` startup and RSS for a short-lived process
  (already ~1 ms / ~2 MB here) is a product-level claim worth its own
  table.
- **GPU**: the in-tree `docs/PYTHON-O4.md` path already transpiles
  Python compute loops to CUDA (`python-O4`: 293x on a 1e9 mod-reduce,
  72x on Collatz, over `gcc -O3`); folding a GPU row into this table
  would show the same source running across CPU and GPU backends.
