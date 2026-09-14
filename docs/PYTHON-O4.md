# python-O4 — Python → C → CUDA

> Status: **first landing + CPU narrowing.** `bash-o4/target/debug/python-O4` exists and
> runs; the Python bench (`bench/bench-py.py`) is green on its agreement
> gate; the transpiled-CUDA leg beats `gcc -O3` by **~290x** on
> mod-reductions and **~60x** on branchy Collatz, and is documented as
> **map-only (readback-bound)** on `squares-map` (see §6 Gaps). This is
> the Python member of the `-O4` driver family (`docs/BASH-O4.md`); the
> same generic stages are reused, only the front end differs.
>
> **CPU gap closed (§2.4).** The mod-reduction and map rows used to run
> in GMP (sumred 67.5 s, squares-map 27.4 s at `--scale opt`) because
> the frontend proved integer ranges against the JS Number bound (2^53),
> so anything wider was wrapped in its bigint marker. `--exact-i64`
> proves against the signed-i64 ceiling for C-only callers, and the
> shared versioning plan now accepts the frontend's *structured*
> condition as well as the shell's text one. sumred CPU is now 1.18 s
> (was 67.5 s) and squares-map 0.17 s (was 27.4 s).
>
> **B1 fixed (§8.1): exact loop-carried integers.** The straight-line
> range proof used to narrow an unprovable loop-carried accumulator to
> i64, so `factorial(30)` silently wrapped; it is exact now
> (a loop-growth guard plus a `x % m → [0,m-1]` range rule and a
> C-backend mixed-accumulator fix). The cost: collatz's growing `v` is
> now correctly GMP on the **CPU** leg (154 s at 1.8e7 vs 892 ms when it
> was unsoundly i64); the CUDA leg is unchanged at 12.70 ms.

## 1. The binary

```
python-O4 [options] program.py [-- args...]

  -o FILE              AOT native executable (tcc), do not run
  --emit-c             print the rendered C (debug)
  --check              CUDA-candidacy report (map/reduce/seq verdicts)
  --dump-shir          print the A1 shIR JSON
  --gpu[=auto|force|off]  dispatch a TRANSPILED kernel; prints
                       `<median_ms> <checksum>`
  --n N, --runs K, --bind VAR=VAL
  -O0..-O4, --true64/--no-true64, --verbose, --cache-dir
```

Pipeline (identical to bash-O4 after stage ①):

```
① .py ──frontends/py-sh-go──▶ A1 shIR   (the workspace's Python frontend)
② analyses  ─ the Python frontend's counted-while shape is recovered as
               IrStmt::ForInit (py::normalize_counted); map/reduce see a
               cast-stripped view, the sequential-lane analysis the raw one
③ CPU  render (debashl C backend) → tcc JIT/AOT   (`-o`, default)
④ GPU  candidacy → PTX → CUDA driver API dispatch (`--gpu`, cu_run)
```

Stage ② is mostly Python-specific *policy*, not new lowering: the
counted-loop and append normalisation are the SHARED shIR transforms
`counted-arith-forinit` and `append-to-store`, wired into the frontend
A1 ingress so **every backend** gets them (see
[`docs/TRANSFORMS-SQUARES-MAP.md`](TRANSFORMS-SQUARES-MAP.md));
python-O4 just calls the same two transforms on its candidacy view.
Only the cast-stripped i64 view is driver-local:

- **shared `counted-arith-forinit`** recovers `IrStmt::ForInit` from the
  structured-Arith counted while (`for i in range(N)`). The condition
  must drive the counter, so Collatz's inner `while v > 1: … s = s + 1`
  stays a `While` (the sequential-lane classifier needs it).
- **shared `append-to-store`** rewrites the CPython-valid
  `a = []; for i in range(N): a.append(v)` into the affine indexed store
  `a[i] = v` the map candidacy sizes.
- **`py::a1_without_casts`** gives map/reduce a cast-stripped i64 view
  (below).

Stage ④ shares **`bash_o4::cu_run`** (extracted from the `cutranspile`
example): mode selection (fused / reduce-only / seq / map-only), extern
binding, PTX emission and dispatch. No hand kernels.

## 2. What the Python frontend needed

Two additive `cu_candidacy` arms (the shell frontend never emits these
shapes, so the bash gates are unaffected):

1. **Structured conditions.** py-sh-go emits `Arith(Bin{<, i, N})` where
   the shell frontend emits `builtin("let", ["i<n"])` text.
   `cond_dyn_bound` gained the structured arm.
2. **Identity casts.** py-sh-go wraps integer-domain reads/moduli in
   `Cast(Int64, …)` (its bigint exactness marker). `lower_arith` and the
   reduce value lowerer treat the cast as identity (the CUDA model is
   signed i64), and `python-O4` feeds map/reduce a cast-stripped A1 view
   (`py::a1_without_casts`) so the mask-plan AST walk sees bare `Num`
   divisors and bare counter `Var`s. Without the strip, `sumred` renders
   `rem.s64` and runs ~15x slower (60 ms vs 3.8 ms at N=1e9) — pinned by
   `py::tests::candidacy::cast_stripped_view_enables_mask_plan`.
3. **Floor-mod composition.** Python's sign-correct `%` makes the
   frontend emit `((A % m) + m) % m` whenever the dividend's sign is
   unproven. For pow2 `m` that expression is exactly `A & (m-1)` for
   every sign (the bitwise low bits *are* the nonnegative residue), so
   the reduce shape classifier unwraps it to the existing `MaskAdd`
   vehicle — no PTX change, no nonneg proof. This is what enables the
   **fused** `squares-map` map+reduce (map-only readback lost to C).
   Pinned by `py::tests::candidacy::floor_mod_composition_lowers_to_mask`.

### 2.4 The CPU narrowing (new)

Reaching the same kernels was not enough: the *CPU* rows ran in GMP.
Three changes, all generic except the flag:

- **`--exact-i64`** (py-sh-go). `intDom` decided "native int" vs "bigint"
  against **2^53** (the JS Number bound), so `i*i` for `i<1e9` (1e18) and
  the mod-2^32 accumulator were typed bigint and the C backend homed them
  in `mpz_t`. For a C-only caller the exact bound is **2^63-1**
  (signed i64); the flag raises it. Proven-huge still homes in GMP.
- **Array-element reads** (py-sh-go). `intDom` had no `SubscriptE` arm, so
  `s + a[i]` fell to the "big" default even when the list's recorded
  element domain was int (`squares-map`). It now consults `setElemDom`.
- **Structured conditions** (debashl `counter_reserve_loop`). The
  versioning plan parsed only the shell frontend's `builtin("let",
  ["i<n"])` TEXT. py-sh-go emits `Arith(Bin{<, Var i, Var n})`, so its
  loops were never versioned (no unsigned fast arm). The extraction now
  accepts both shapes (and unwraps identity `Cast(Int64)`). This is
  "make bash-O4's optimisation more general": the plan is a generic
  lowering, so every frontend that emits a structured counted loop gets
  it. Pinned by `counter_reserve_loop_accepts_structured_cond`.

Measured: sumred `pyo4-gcc` 67480 ms → **1175 ms** (gcc-O3 1041 ms);
squares-map `pyo4-gcc` 27433 ms → **170 ms**. The shell corpus is
unaffected (`c_gate_main.sh`: 637 PASS / 0 FAIL / 7 SKIP) because the
shell frontend still takes the text path.

The sequential-lane analysis keeps the *unstripped* view: `cu_run::run`
takes two IR views (`prog` for `analyze_seq`, `prog_flat` for
map/reduce). Shell callers pass the same value twice.

Also fixed in the frontend (found by this work, regression-tested by the
py-sh-go gate 95/95):

- **`a[i] % K` nil-panicked** `arithIRDom`: the `*SubscriptE` arm
  returned an expression-shaped `subscriptIR` result with no `"ast"`, and
  the enclosing `BinOpE` type-asserted it. The arm now builds the A1
  arith `Index` node for `NameE[...]` and keeps the `subscriptIR`
  fallback for idioms like `int(os.environ["N"])`.

## 3. Bench

`bench/bench-py.py` is the Python port of `bench.sh`/`bench-opt.sh`:
same problems, same medians, same agreement gate (every running leg's
stdout must match), same legs — except every leg is a *Python* program
fed to `python-O4`:

| leg | meaning |
|---|---|
| `cpython` | real CPython (floor reference) |
| `pyo4-tcc` | `python-O4 -o` (rendered C via tcc) |
| `pyo4-gcc` | the same rendered C via `gcc -O3` (backend quality) |
| `gcc-O3` | handwritten C from `bench/c/` (CPU ceiling) |
| `pyo4-gpu` | `python-O4 --gpu` (TRANSPILED Python→ShIR→PTX dispatch) |

Problem sources are `bench/py/*.py` — translations of `bench/sh/*.sh`.
`--scale fast` (small N, CPython included) checks correctness; `--scale
opt` (bench-opt N, ~1 s CPU legs, CPython dropped) measures steady state.

### Results (`--scale opt`, runs=3, RTX 2070 Super / WSL, gcc 13.3)

| problem | N | gcc-O3 | python-O4 CPU (gcc) | python-O4 GPU | GPU vs C |
|---|---:|---:|---:|---:|---:|
| sumred | 1e9 | 1041 ms | **1175 ms** (0.89x) | **3.55 ms** | **293x** |
| collatz | 1.8e7 | 774 ms | ~154 s (GMP, exact) | **12.70 ms** | **61x** |
| squares-map | 1e8 | 278 ms | **170 ms** (1.63x) | ~950 ms | ~0.3x |

- **collatz's CPU row is GMP now, and that is the correct result.** Its
  inner `v = 3*v+1` grows without a provable bound, so narrowing it to
  i64 (the 892 ms it used to measure) was the B1 miscompile class: some
  inputs would overflow silently. Exactness costs ~170x on that leg; the
  GPU leg (i64-exact by construction) is unaffected, and recovering the
  CPU speed needs overflow-guarded i64→GMP tiering (§8.1 B1 follow-up).

- The CUDA times match the *bash* `cutranspile` vehicle on the same
  shapes (sumred 4.07 ms, collatz 13.79 ms): the Python frontend's A1
  reaches the same kernels.
- **squares-map's CPU leg is now faster than the handwritten C** (1.63x)
  because the shared `fuse-fill-consume` transform forwards the
  single-append fill into its same-index consumer, so the 800 MB
  materialisation disappears *on the CPU path*. The CUDA leg still
  materialises (it is the map vehicle) and is transfer-bound, so the
  two legs no longer do identical work — the source is shared, the
  lowering is not. Read that row as "CPU > C because it does less",
  not as a kernel-quality claim.
- The old GMP rows are gone: `python-O4` now emits native `long long`
  for both. Before the fix the same rows were 67480 ms / 27433 ms.
- `python-O4` fast-scale CPU rows are ~1–3 ms at 1e6 (tcc JIT includes
  compile; AOT binaries are faster) vs CPython's 114–330 ms.
- The old “GMP rows are Python semantics, not a backend limit” note is
  **superseded**: both CPU rows are native now (§2.4). A *proven*-huge
  value (a real `2**100`) still homes in GMP, but the frontend can also
  **over-narrow a loop-carried accumulator it cannot bound** — see §8
  B1, a release blocker. Every bench shape is provably bounded, so the
  agreement gate does not exercise that class.

## 4. Exit codes

`0` success / the program's own code, `1` compile/lower error, `2` usage,
`3` `--gpu=force` with no dispatchable shape or no device.

## 5. Layering (toolkit purity)

`bash-o4`'s lib is the generic `-O4` machinery: `pipeline` (C render),
`tcc`, `cache`, `cudaffi`, `cu_candidacy`, and the new `cu_run`. The
shell front end is `src/cli.rs` + `src/main.rs`; the Python front end is
`src/py.rs` + `src/main_py.rs`. Nothing Python-specific leaks into the
generic modules (`cu_run` takes an `IrProgram` and a bound value and
knows nothing about `.py`), and nothing shell-specific leaks into
`py.rs`.

## 6. Gaps (honest, not blessed)

1. **`sqrt1337`.** py-sh-go v1 has no string containment
   (`"1337" in str(x)` / `.find`), so the valid Python translation is
   kept as documentation and the driver reports SKIP. The CPU string
   lowering (bash-O4's `strstr` showcase) has no Python front end yet.
2. **CPU bigint rows — RESOLVED (§2.4).** Both are native now:
   `--exact-i64` lets the frontend prove the mod-chain within i64, and
   the versioning plan versions the structured-condition loop, so the
   unsigned fast arm (bash-O4's vehicle) applies to the Python A1 too.
   sumred 67.5 s → 1.18 s; squares-map 27.4 s → 0.17 s. Values whose
   true range exceeds i64 (a real `2**100`) still home in GMP — that is
   Python semantics, not a gap.
3. **Whole-program host split** is the same open M3 item as bash-O4: the
   GPU leg is a per-loop offload vehicle printing the offloaded loop's
   checksum, not a general `--gpu` codegen.
4. **squares-map allocation**: the fused vehicle `cuMemAlloc`s the
   800 MB output per dispatch (inside the timed loop). Pre-allocating /
   caching the device buffer would recover most of the ~270 ms (a
   vehicle-level optimisation, not a lowering one).

## 7. V2 backlog

non-pow2 floor-mod reduce op; device-buffer reuse in `cu_run`;
string containment in py-sh-go; `sys.argv` (so the driver stops
substituting `N` in-source); PGO/width seeding for the remaining CPU
rows (hash is 0.84x, `pyo4-tcc` is tcc-codegen-bound).

## 8. Release readiness

What is green today: the bench agreement gate (all legs byte-agree),
bash-o4's own tests, the py-sh-go gate (95/95), and the shell C corpus
(637/0/7). B1 (Python exactness for loop-carried ints) is **fixed**;
the remaining blockers are packaging/process (B2–B5) rather than
miscompiles.

### 8.1 Blockers (fix before a release)

**B1. Silent miscompile of unproven loop-carried Python ints — FIXED.**

The frontend's range proof was single-pass: inside a loop `intDom` saw
the range from the *pre-loop* assignment, and its unknown-range fallback
was optimistic (`"int"`). An accumulator with no provable bound was
homed in i64 / JS Number / Perl NV and overflowed:

```python
f = 1
for i in range(1, 30):
    f = f * i
print(f)     # CPython 8841761993739701954543616000000
```

Three changes make it exact (all verified):

1. **Loop-growth guard** (`growsUnbounded`): a variable assigned inside a
   loop (tracked by `loopDepth`) whose RHS is a self-referential
   `*`/`**`/`<<`, or `v` appearing twice additively (`v = v + v`), is
   forced to the bigint domain. A top-level modulo is bounded and is not
   growth. `factorial(30)` and `s = s*3` are exact now; `s = s + i`,
   collatz's `s += 1`, addsum, squares and sumred stay native.
2. **`x % m → [0, m-1]` from the divisor alone** (`rangeOf`): a
   loop-carried dividend no longer hides the bound, which is what keeps
   a mod-bounded accumulator (`sumred`) provably i64.
3. **C-backend mixed-accumulator fix**: `analyze_bigint_vars` recorded
   only the *first* assignment per variable, so a var assigned a plain
   arith once and a `Cast(Int64)` arith later was declared `long long`
   while the later store rendered `mpz_add(v,…)`. It now records every
   assignment, and a bigint-homed target always renders through
   `bigint_into`. Pinned by `mixed_bigint_assignment_homes_the_var`.

Verification: `testdata` gate 95/95, shell C corpus 637/0/7,
`unbounded_loop_accumulator_is_exact_bounded_stays_native` (py.rs),
and the bench agreement gate (all checksums still byte-agree).

Residual, honestly:

- **Performance.** An unprovable loop-carried growth is exact but GMP:
  collatz CPU 892 ms → ~154 s. Recovering it needs **overflow-guarded
  tiering** — compute in i64 with `__builtin_*_overflow` and spill to
  GMP on the first violation (the `SH2_ASSUME_OBSERVED_WIDTHS`
  `__int128`+GMP tier is the prototype). That is the next perf item, not
  a correctness one.
- **Additive accumulators** (`s = s + i` in a loop) are still narrowed
  to i64 when the per-iteration operand has a known range; they can in
  principle exceed i64 for an astronomically long loop. Closing that
  needs the same overflow guard (or a trip-count bound). Documented, not
  claimed sound.

**B2. The artifact cache can serve stale C across backend upgrades.**
`cache::artifact_key` folds bash-o4's `RENDERER_REV:PIPELINE_REV` and
the rendered A1, but **not** the `debashl`/`otranspilerl` revision. A
backend change (e.g. the loop-versioning generalization in §2.4) does
not bump those constants, so a warm cache keeps the old render after
an upgrade. Fold the backend build id/revision into the key (the
profiler already does the equivalent with `source_hash`).

**B3. No differential corpus gate for python-O4.**
The only python-O4 correctness gate is the 8-problem bench agreement
gate plus bash-o4's unit tests. The py-sh-go gate is ESTree-only and
`c_gate_main.sh` is shell-only. Add a corpus runner that transpiles
`frontends/py-sh-go/testdata/*.py` through `python-O4` CPU, runs it,
and diffs stdout with CPython — the harness pattern already exists
(`frontends/py-sh-go/profile_example/check_cpython_parity.sh`, 94/95);
wire it to `python-O4` and run it in CI. It would have caught B1.

**B4. Packaging and CLI surface.**
- `-h/--help` now prints usage and exits 0; `-V/--version` reports the
  crate version. (Both landed with this doc.)
- The driver shells out to the `py-sh-go` binary (`$PY_SH_GO`, else a
  workspace-relative path). A release artifact must ship/build it, and
  the missing-frontend path (exit 1, clear message) must be tested on
  a machine without the source tree.
- No install/package target; `Cargo.toml` says `0.1.1` while the docs
  say “first landing”.
- `--gpu=auto` degrades cleanly and `--gpu=force` exits 3 with no
  device; add a **no-driver** CI case (the dev box always has one).

**B5. Shared-core test reds must be triaged.**
`sh2perl` `cargo test --lib` is 797 passed / 7 failed (6 `estree`
pre-existing per PLAN v43, plus `numeric_reduction_assign_reads_aggregate_natively`,
which reproduces with the recent c_backend work reverted — a worker
transform regression). A release should not ship with red core tests;
fix or bless-with-issue explicitly.

### 8.2 Should fix (quality / coverage)

- **`sqrt1337` has no Python leg.** py-sh-go v1 lacks string
  containment / `.find`, so the `strstr` showcase is SKIP.
- **GPU is a per-loop offload vehicle** that prints the offloaded
  loop's checksum — not a general `--gpu` codegen. The whole-program
  host split is the open M3 item shared with bash-O4.
- **`squares-map` re-`cuMemAlloc`s the output every dispatch**; caching
  the device buffer would recover most of the ~950 ms.
- **`pyo4-tcc` (the default JIT/`-o` path) is 0.04x** — that is tcc
  codegen, not the lowering. Either default `-o` to `cc`/`gcc` or say
  so in the usage line.
- **`hash` is 0.84x**; **non-pow2 floor-mod** reduce op is unimplemented.
- **`sys.argv` in the frontend**, so callers stop substituting `N`
  in-source or needing `--bind`.

### 8.3 The gate to keep green

- `bash-o4/bench/bench-py.py` agreement gate: every running leg
  byte-agrees on checksums (fast and opt scales).
- `bash-o4` `cargo test` (lib 50 + the `tests/` integration targets).
- py-sh-go gate: 95/95 over the corpus, **default** 2^53 bound (the
  `--exact-i64` path is opt-in and cannot change it).
- `harness/c_gate_main.sh`: 637 PASS / 0 FAIL / 7 SKIP (the shell
  frontend still takes the text-condition path; the sanitize pass is
  available for memory/UB checks).
- New pins from the CPU work:
  `counter_reserve_loop_accepts_structured_cond` (c_backend),
  `exact_i64_keeps_bounded_mod_chain_native` and
  `unbounded_loop_accumulator_is_exact_bounded_stays_native` (py.rs),
  `mixed_bigint_assignment_homes_the_var` (c_backend).

### 8.4 Correct but slower (not blockers)

- A *proven*-huge value (`2**100`) homes in GMP — exact, ~15x slower
  than `__int128`; the profile-guided width tier can narrow it.
- `--exact-i64` is sound **relative to the existing range proofs**: it
  only widens the “proven” branch, so it cannot create B1 (which exists
  at the default bound too).
