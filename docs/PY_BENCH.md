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

Status: living document. Numbers below are from one capture on the dev
box (2026-09-14, Python 3.12.3, gcc 13.3.0, Cython 3.0.8) and are
*indicative*, not a gate — see §7 for why absolute numbers move.

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
total 95   match 94   mismatch 1  (t91_set_sum_fallback)   emit fail 0  cc fail 0
```

`t91` is a **C-backend** gap (a set with one bigint element: the C sum
accumulator is not exact for that shape); the frontend itself passes
95/95 through the ESTree backend. Known gaps are listed in the script
so a *new* mismatch fails the run, and a resolved one is reported
("known gap RESOLVED — remove from KNOWN_GAPS") rather than silently
tolerated.

## 4. CPython vs transpiled C

`bench_vs_cpython.sh` (capture: `TARGET_SECS=5 REPS=2`):

```
sizes: sum_squares=10000000  rolling_hash=20000000  bignum_mul=300000  io=6000000 lines

rolling_hash (20000000)          time(s)   rss(MB)   speedup
  CPython                          5.420      10.1      1.0x
  C                                0.165       1.6     32.9x

sum_squares (10000000)           time(s)   rss(MB)   speedup
  CPython                          2.711     392.8      1.0x
  C                                0.088      79.1     30.9x

bignum_mul (300000 x*=3 from 2**100)
  CPython                          5.275      10.2      1.0x
  C (GMP)                          2.483       2.2      2.1x

app.py (io/6000000 lines)
  CPython                          5.032     515.3      1.0x
  C                                2.236     322.9      2.3x
```

Read the shapes, not one number:

- **Scalar recurrence** (`rolling_hash`, non-foldable modulo loop):
  ~33× faster, 6× less RAM. This is CPython's boxed-`PyLong` +
  bytecode-dispatch cost, which the C loop simply doesn't pay.
- **Vector + wide aggregate** (`sum_squares`): ~31×, 5× less RAM. The
  C uses a native `long long` vector and an **exact `__int128` sum**;
  CPython allocates 10 M `PyLong`s.
- **Bigint** (`bignum_mul`): only ~2×. Both sides call GMP / CPython's
  big-int, which are in the same league; the win is memory (5×) and, in
  the Cython table, startup. This is the honest counterweight to 33×.
- **Line I/O** (`app.py`): ~2.3×, 1.6× less RAM. Both read lines and
  store two growable lists; the win here is smaller and dominated by
  parsing/alloc, not arithmetic.

## 5. Cython: pure and typed

`bench_cython.sh` (capture: `TARGET_SECS=5 REPS=2`):

```
sizes: rolling_hash=16000000  sum_squares=10000000  bignum_mul=300000  io=6000000 lines

startup floor (empty program)    time(s)   rss(MB)   speedup
  CPython                          0.052       0.0      1.0x
  Cython (embedded)                0.057       0.0      0.9x
  py-sh-go C                       0.001       0.0     47.6x

rolling_hash (16000000)          time(s)   rss(MB)   speedup
  CPython                          4.305      10.1      1.0x
  Cython (pure)                    4.779      10.9      0.9x
  Cython (typed)                   0.135      10.9     32.0x
  py-sh-go C                       0.130       1.7     33.2x

sum_squares (10000000)           time(s)   rss(MB)   speedup
  CPython                          2.901     394.2      1.0x
  Cython (pure)                    3.012     395.2      1.0x
  Cython (typed)                       -         -   n/a (no __int128)
  py-sh-go C                       0.064      78.4     45.3x

app.py (io/6000000 lines)        time(s)   rss(MB)   speedup
  CPython                          7.828     515.2      1.0x
  Cython (pure)                   11.414     516.2      0.7x
  Cython (typed)                   1.701     333.0      4.6x
  py-sh-go C                       1.729     324.7      4.5x

bignum_mul (300000 x*=3 from 2**100)
  CPython                          6.252      10.2      1.0x
  Cython (pure)                    8.549      11.2      0.7x
  Cython (typed)                   1.831      11.4      3.4x
  py-sh-go C (GMP)                 2.834       2.2      2.2x
```

### What this says

1. **Cython-pure is not faster than CPython on any shape** (0.7–1.0×).
   Compiling to C does not help while values stay boxed `PyLong`s and
   every operation still crosses the C-API. Cython is a *typed*
   compiler; without types it is CPython at C speed with extra
   indirection.
2. **Typed Cython wins only after a human rewrites the hot code** with
   `cdef` types (and, for bigint, hand-binds GMP via
   `cdef extern from "gmp.h"`). Where it applies it is fast — it *ties
   py-sh-go* on `rolling_hash` (0.135 vs 0.130) and on I/O (1.701 vs
   1.729), which is the expected result for two compilers emitting the
   same C.
3. **The differentiators for py-sh-go are what it does without help:**
   - it infers the types (no annotations), so it wins on the shapes
     where Cython-pure is slow;
   - it starts in **~1 ms** vs Cython's **~57 ms** (it does not link
     libpython) — a 48× floor that dominates short programs;
   - it stays at **~2 MB** RSS on bigint vs Cython's ~11 MB (again no
     interpreter runtime);
   - it emits an **exact `__int128` aggregate** for `sum(xs)` that
     hand-typed Cython cannot express without GMP (hence the `n/a`).
4. **Typed Cython does edge out py-sh-go on bigint time** (1.83 vs
   2.83 s) — see §8, finding B: that is a codegen quality gap, not a
   fundamental one, and it is fixable.

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

The benchmark earned its keep by surfacing four real issues. Three are
fixed; one (B) is open. The most serious — E, a silent miscompile of
valid Python — was found here and is now fixed (`docs/PYTHON-O4.md` §8.1
B1 records the residual performance cost).

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
(~154 s vs the unsound 892 ms); it is now recovered by the
**speculative dual arm** — an i64 fast arm with `__builtin_*_overflow`
stores and an exact GMP replay on the cold overflow flag — at ~2.1 s,
still exact (`docs/PYTHON-O4.md` §8.1 B1).

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
  Python compute loops to CUDA (`python-O4`, ~60–150x over `gcc -O3` on
  its microbenches); folding a GPU row into this table would show the
  same source running across CPU and GPU backends.
