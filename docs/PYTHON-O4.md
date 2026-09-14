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
| collatz | 1.8e7 | 774 ms | 892 ms (0.87x) | **12.70 ms** | **61x** |
| squares-map | 1e8 | 278 ms | **170 ms** (1.63x) | ~950 ms | ~0.3x |

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
- The two GMP rows are **Python semantics, not a backend limit**:
  Python ints are unbounded, so `s = s + i*i` past ±2^53 lowers to exact
  `mpz_t` unless the frontend can prove a width (collatz does; sumred's
  mod-chain is not narrowed because the composition hides the range).
  The GPU path is i64-exact by construction and the checksums agree.

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
