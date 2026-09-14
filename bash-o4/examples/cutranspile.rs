//! cutranspile — transpiled-CUDA vehicle: `cutranspile <script.sh> <N>`
//! [--runs K] [--bind var=value...]` prints `<median_ms> <checksum>`.
//!
//! End-to-end bash→ShIR→candidacy→PTX→GPU with NO hand kernels. Modes,
//! preferred in order (first that applies wins):
//! - **fused**: a map candidate filling array A plus a reduce candidate
//!   reading A over the identical iteration space — one array alloc,
//!   map kernel, reduce kernel, partials readback only (no array
//!   roundtrip). Checksum = reduced scalar (== program output for
//!   map+reduce problems).
//! - **reduce-only**: a reduce candidate with no array reads (e.g.
//!   sumred) — partials + host finish. Checksum = reduced scalar.
//! - **map-only**: a map candidate — full array readback + host
//!   mod-2^32 checksum (readback-bound by construction; reduction
//!   fusion is what removes it).
//! v1 scope (loud SKIP otherwise): single-extern auto-bind from N;
//! multiple externs need explicit `--bind` each; reduce with array reads
//! and no fusable map refuses (cannot materialize host-side values).
//! Exit 2 + SKIP message when: no CUDA device, no runnable shape, or
//! unbindable externs (bench-opt treats 2 as skip, not failure).
use bash_o4::{cu_candidacy, cudaffi};
use debashl::cuda_backend::{shir_to_cu_compute, shir_to_cu_reduce, CuLoopSpec, CuReduceSpec};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("usage: cutranspile <script.sh> <N> [--runs K] [--bind var=value...]");
        std::process::exit(2);
    }
    let (script, n): (String, u64) = (args[0].clone(), args[1].parse().expect("N"));
    let mut runs = 3;
    let mut binds: Vec<(String, i64)> = Vec::new();
    let mut i = 2;
    while i < args.len() {
        if args[i] == "--runs" {
            runs = args[i + 1].parse().expect("runs");
            i += 1;
        } else if args[i] == "--bind" {
            let kv = &args[i + 1];
            let (k, v) = kv.split_once('=').expect("--bind var=value");
            binds.push((k.to_string(), v.parse().expect("bind value")));
            i += 1;
        }
        i += 1;
    }
    if !cudaffi::has_cuda_device() {
        eprintln!("SKIP cutranspile: no CUDA device");
        std::process::exit(2);
    }
    let src = std::fs::read_to_string(&script).expect("script");
    let prog = {
        let json = otranspilerl::shell_to_shir(&src);
        debashl::shir_json_in::shir_json_to_ir(&json).expect("ingress")
    };
    let map_spec = cu_candidacy::analyze(&prog)
        .into_iter()
        .find_map(|v| if v.is_candidate() { v.spec.clone() } else { None });
    let red_spec = cu_candidacy::analyze_reduce(&prog)
        .into_iter()
        .find_map(|v| {
            if matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate) {
                v.spec.clone()
            } else {
                None
            }
        });
    // Mode selection.
    enum Mode {
        Fused(CuLoopSpec, CuReduceSpec),
        Reduce(CuReduceSpec),
        Map(CuLoopSpec),
    }
    let mode: Mode = match (map_spec, red_spec) {
        (Some(m), Some(r))
            if r.arrays.iter().any(|a| m.stores.iter().any(|s| &s.array == a))
                && same_space(&m, &r) =>
        {
            Mode::Fused(m, r)
        }
        (_, Some(r)) if r.arrays.is_empty() => Mode::Reduce(r),
        (Some(m), _) => Mode::Map(m),
        (_, Some(_)) => {
            eprintln!("SKIP cutranspile: reduce reads arrays with no fusable map");
            std::process::exit(2);
        }
        (None, None) => {
            eprintln!("SKIP cutranspile: no candidate loop");
            std::process::exit(2);
        }
    };
    let runner = cudaffi::CudaRunner::new().expect("runner");
    // Warmup + timed driver (median over runs; each rep re-dispatches).
    let run_once = |runner: &cudaffi::CudaRunner| -> i64 {
        match &mode {
            Mode::Map(m) => run_map(runner, m, n, &binds),
            Mode::Reduce(r) => run_reduce(runner, r, n, &binds, None),
            Mode::Fused(m, r) => run_fused(runner, m, r, n, &binds),
        }
    };
    let checksum = run_once(&runner);
    let mut ts = Vec::new();
    for _ in 0..runs {
        let t = std::time::Instant::now();
        let _ = run_once(&runner);
        ts.push(t.elapsed().as_secs_f64() * 1000.0);
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = ts[ts.len() / 2];
    println!("{median:.3} {checksum}");

    /// Identical iteration spaces (coverage-exact fusion).
    fn same_space(m: &CuLoopSpec, r: &CuReduceSpec) -> bool {
        m.var == r.var
            && m.lo == r.lo
            && m.bound_var == r.bound_var
            && m.bound_lt == r.bound_lt
            && m.step == r.step
    }
}

/// Bind a spec's externs: single-extern auto-binds N, else every extern
/// needs an explicit `--bind` (loud refuse — never guess values).
fn bind_externs(externs: &[String], n: u64, binds: &[(String, i64)]) -> Vec<i64> {
    let mut evals = Vec::new();
    for e in externs {
        if let Some((_, v)) = binds.iter().find(|(k, _)| k == e) {
            evals.push(*v);
        } else if externs.len() == 1 {
            evals.push(n as i64);
        } else {
            eprintln!("SKIP cutranspile: extern `{e}` needs --bind {e}=<i64>");
            std::process::exit(2);
        }
    }
    evals
}

/// Trips from a bound value (mirror candidacy::trips with runtime hi).
fn trips_of(lo: i64, bound: i64, lt: bool, step: i64) -> u64 {
    let span: i128 = (bound as i128 - lo as i128) + if lt { 0 } else { 1 };
    if span <= 0 {
        0
    } else {
        ((span + step as i128 - 1) / step as i128) as u64
    }
}

/// Map mode: dispatch fill kernel, read back first array, host checksum.
fn run_map(
    runner: &cudaffi::CudaRunner,
    m: &CuLoopSpec,
    n: u64,
    binds: &[(String, i64)],
) -> i64 {
    let evals = bind_externs(&m.externs, n, binds);
    // Bound value is externs[0] by construction.
    let trips = trips_of(m.lo, evals[0], m.bound_lt, m.step);
    if trips == 0 {
        return 0;
    }
    // Exact output sizes from affine bounds (mirror of the sizing rule:
    // max index + 1 per array).
    let top_i: i128 = m.lo as i128 + (trips as i128 - 1) * m.step as i128;
    let out_lens: Vec<usize> = m
        .stores
        .iter()
        .map(|st| {
            let need: i128 = if st.index_a > 0 {
                st.index_a as i128 * top_i + st.index_b as i128 + 1
            } else if st.index_a < 0 {
                st.index_a as i128 * m.lo as i128 + st.index_b as i128 + 1
            } else {
                st.index_b as i128 + 1
            };
            need.clamp(1, i128::from(usize::MAX as u64)) as usize
        })
        .collect();
    let mut scalars = evals;
    scalars.push(trips as i64);
    let groups = ((trips + m.threads as u64 - 1) / m.threads as u64) as u32;
    let ptx = shir_to_cu_compute(m);
    let out = runner
        .run(&ptx, "kern", &out_lens, &scalars, groups, m.threads)
        .expect("map dispatch");
    const MOD: u64 = 4294967296;
    let mut s: u64 = 0;
    for &x in &out[0] {
        s = (s + (x as u64) % MOD) % MOD;
    }
    s as i64
}

/// Reduce mode (standalone): partials + host finish seeded with init.
/// `shared` optionally carries pre-allocated array handles (fused mode).
fn run_reduce(
    runner: &cudaffi::CudaRunner,
    r: &debashl::cuda_backend::CuReduceSpec,
    n: u64,
    binds: &[(String, i64)],
    shared: Option<&[(String, cudaffi::CUdeviceptr)]>,
) -> i64 {
    use debashl::cuda_backend::CuReduceOp;
    let evals = bind_externs(&r.externs, n, binds);
    // Bound value: the reduce spec's bound var binds like map externs —
    // single-extern auto правило covers bound-only; else explicit.
    // (Reduce specs carry bound_var but not in externs; bind it here.)
    let bound_val: i64 = binds
        .iter()
        .find(|(k, _)| k == &r.bound_var)
        .map(|(_, v)| *v)
        .unwrap_or_else(|| {
            if r.externs.is_empty() && evals.is_empty() {
                // No externs at all: bound takes N (the common shape).
                n as i64
            } else {
                eprintln!(
                    "SKIP cutranspile: reduce bound `{}` needs --bind",
                    r.bound_var
                );
                std::process::exit(2);
            }
        });
    let trips = trips_of(r.lo, bound_val, r.bound_lt, r.step);
    if trips == 0 {
        return r.acc_init;
    }
    let groups =
        ((trips + r.threads as u64 * r.block_items - 1) / (r.threads as u64 * r.block_items)) as u32;
    let ptx = debashl::cuda_backend::shir_to_cu_reduce(r);
    // Param contract: arrays..., partials, externs..., trips.
    let partials = runner.alloc_array(groups as usize).expect("partials");
    let mut bufs: Vec<cudaffi::CUdeviceptr> = Vec::new();
    for a in &r.arrays {
        if let Some(shared) = shared {
            if let Some((_, h)) = shared.iter().find(|(nm, _)| nm == a) {
                bufs.push(*h);
                continue;
            }
        }
        eprintln!("SKIP cutranspile: reduce reads array `{a}` with no shared buffer");
        std::process::exit(2);
    }
    bufs.push(partials);
    let mut scalars = evals;
    scalars.push(trips as i64);
    runner
        .run_buffers(&ptx, "kern", &bufs, &scalars, groups, r.threads)
        .expect("reduce dispatch");
    let parts = runner
        .read_array(partials, groups as usize)
        .expect("partials readback");
    runner.free_array(partials);
    finish_reduce(&r.op, r.acc_init, &parts)
}

/// Host finish for reductions (seeded with init; per-partial folding —
/// no overflow at any step by the fit bounds). Signed i64 throughout
/// (matches bash `echo` and `%lld` exactly, including negatives; the
/// bench rows stay nonneg so cross-leg text agrees regardless).
fn finish_reduce(op: &debashl::cuda_backend::CuReduceOp, init: i64, parts: &[i64]) -> i64 {
    use debashl::cuda_backend::CuReduceOp;
    match op {
        CuReduceOp::Add => {
            let mut s = init;
            for &x in parts {
                s = s.wrapping_add(x);
            }
            s
        }
        CuReduceOp::Mul => {
            let mut s = init;
            for &x in parts {
                s = s.wrapping_mul(x);
            }
            s
        }
        CuReduceOp::Min => {
            let mut s = init;
            for &x in parts {
                s = s.min(x);
            }
            s
        }
        CuReduceOp::Max => {
            let mut s = init;
            for &x in parts {
                s = s.max(x);
            }
            s
        }
        CuReduceOp::ModAdd { modulus } => {
            // Signed fold (bash semantics through wrap regions; Rust %
            // on negatives truncates like C).
            let mut s = init;
            for &x in parts {
                s = s.wrapping_add(x) % (*modulus);
            }
            s
        }
        CuReduceOp::MaskAdd { mask } => {
            // Bitwise (exact for all inputs, no overflow concern on the
            // low bits; intermediates fit by the mask bound).
            let mut s = init;
            for &x in parts {
                s = (s.wrapping_add(x)) & (*mask);
            }
            s
        }
    }
}

/// Fused mode: map kernel writes device arrays (kept), reduce kernel
/// reads them, partials only cross back. No array roundtrip.
fn run_fused(
    runner: &cudaffi::CudaRunner,
    m: &CuLoopSpec,
    r: &debashl::cuda_backend::CuReduceSpec,
    n: u64,
    binds: &[(String, i64)],
) -> i64 {
    // Map side: bind, size, dispatch with persistent arrays.
    let evals = bind_externs(&m.externs, n, binds);
    let trips = trips_of(m.lo, evals[0], m.bound_lt, m.step);
    if trips == 0 {
        return r.acc_init;
    }
    let top_i: i128 = m.lo as i128 + (trips as i128 - 1) * m.step as i128;
    // Distinct arrays across map stores (1:1 by veto, but dedupe safely).
    let mut anames: Vec<String> = Vec::new();
    for st in &m.stores {
        if !anames.contains(&st.array) {
            anames.push(st.array.clone());
        }
    }
    let mut handles: Vec<(String, cudaffi::CUdeviceptr)> = Vec::new();
    for st in &m.stores {
        let need: i128 = if st.index_a > 0 {
            st.index_a as i128 * top_i + st.index_b as i128 + 1
        } else if st.index_a < 0 {
            st.index_a as i128 * m.lo as i128 + st.index_b as i128 + 1
        } else {
            st.index_b as i128 + 1
        };
        let len = need.clamp(1, i128::from(usize::MAX as u64)) as usize;
        handles.push((st.array.clone(), runner.alloc_array(len).expect("map array")));
    }
    let mut scalars = evals;
    scalars.push(trips as i64);
    let groups = ((trips + m.threads as u64 - 1) / m.threads as u64) as u32;
    let map_ptx = shir_to_cu_compute(m);
    {
        let bufs: Vec<cudaffi::CUdeviceptr> = handles.iter().map(|(_, h)| *h).collect();
        runner
            .run_buffers(&map_ptx, "kern", &bufs, &scalars, groups, m.threads)
            .expect("map dispatch");
    }
    // Reduce side over the SAME handles (no roundtrip).
    let out = run_reduce(runner, r, n, binds, Some(&handles));
    for (_, h) in handles {
        runner.free_array(h);
    }
    // run_reduce already finished on host; return its checksum.
    // (It re-reads bound/externs itself — consistent values.)
    out
}
