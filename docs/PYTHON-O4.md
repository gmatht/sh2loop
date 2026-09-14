# python-O4 — Python → C → CUDA

> Status: **first landing.** `bash-o4/target/debug/python-O4` exists and
> runs; the Python bench (`bench/bench-py.py`) is green on its agreement
> gate; the transpiled-CUDA leg beats `gcc -O3` by **~150x** on
> mod-reductions and **~60x** on branchy Collatz, and is documented as
> **map-only (readback-bound)** on `squares-map` (see §6 Gaps). This is
> the Python member of the `-O4` driver family (`docs/BASH-O4.md`); the
> same generic stages are reused, only the front end differs.

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

Stage ② is the only Python-specific lowering:

- **`py::normalize_counted`** rewrites `for i in range(N)`'s canonical
  `i = 0; while i < N: …; i += 1` into the core's `ForInit` node. The
  condition must drive the counter, so Collatz's inner
  `while v > 1: … s = s + 1` stays a `While` (the sequential-lane
  classifier needs it) — pinned by
  `py::tests::candidacy::nested_while_only_outer_loop_converts`.
- **`py::normalize_appends`** rewrites the CPython-valid
  `a = []; for i in range(N): a.append(v)` into the affine indexed store
  `a[i] = v` the map candidacy sizes (refuses unless there is exactly
  one append site, no other write, an empty init, and a 0/+1 counted
  loop). Same source, all legs.
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
| sumred | 1e9 | 572 ms | 67480 ms (GMP) | **3.76 ms** | **152x** |
| collatz | 1.8e7 | 774 ms | 892 ms | **12.70 ms** | **61x** |
| squares-map | 1e8 | ~280 ms | 27433 ms (GMP) | **~270 ms** (fused) | ~1x |

- The CUDA times match the *bash* `cutranspile` vehicle on the same
  shapes (sumred 4.07 ms, collatz 13.79 ms): the Python frontend's A1
  reaches the same kernels.
- `squares-map` is **fused** now (map + reduce, partials only read back)
  rather than map-only, but it is transfer/allocation-bound: 800 MB of
  device traffic plus an 800 MB device allocation per dispatch, so it
  lands at parity with C. That is the physics of the problem on shared
  RAM, not a lowering gap (the session's own `bench-opt.sh` note records
  the same for the hand kernels).
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
2. **CPU bigint rows** (sumred, squares-map): exact but GMP-slow. The
   fix is a range/narrowing proof for the mod-chain shape (the frontend
   composes the modulo before its interval analysis can bound it).
3. **Whole-program host split** is the same open M3 item as bash-O4: the
   GPU leg is a per-loop offload vehicle printing the offloaded loop's
   checksum, not a general `--gpu` codegen.
4. **squares-map allocation**: the fused vehicle `cuMemAlloc`s the
   800 MB output per dispatch (inside the timed loop). Pre-allocating /
   caching the device buffer would recover most of the ~270 ms (a
   vehicle-level optimisation, not a lowering one).

## 7. V2 backlog

non-pow2 floor-mod reduce op; device-buffer reuse in `cu_run`;
proven-nonneg range propagation through mod compositions; string
containment in py-sh-go; `sys.argv` (so the driver stops substituting
`N` in-source); PGO/width seeding for the CPU bigint rows.
