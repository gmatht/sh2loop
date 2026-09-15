//! Generic transpiled-CUDA vehicle (`cu_run`).
//!
//! The dispatch half of the `cutranspile` example, extracted so every
//! frontend driver can share it: given an `IrProgram` (from ANY frontend
//! — bash or py-sh-go) plus the bound value `n`, select a mode and
//! dispatch a transpiled kernel through the CUDA driver API, returning
//! (median ms, checksum). No hand kernels: the PTX comes from
//! `cuda_backend` on the candidacy specs.
//!
//! Modes, preferred in order (first that applies wins):
//! - **fused**: a map candidate filling array A plus a reduce candidate
//!   reading A over the identical iteration space — one array alloc,
//!   map kernel, reduce kernel, partials readback only.
//! - **reduce-only**: a reduce candidate with no array reads.
//! - **seq**: a sequential-lane reduce (nested while chain, e.g. Collatz)
//!   — the Reduce vehicle dispatches it unchanged.
//! - **map-only**: a map candidate — full array readback + host
//!   mod-2^32 checksum (readback-bound by construction).
//!
//! `Skip` mirrors the example's exit-2 contract: no device / no runnable
//! shape / unbindable externs are skips, never failures.

use crate::{cu_candidacy, cudaffi};
use debashl::cuda_backend::{shir_to_cu_compute, shir_to_cu_reduce, CuLoopSpec, CuReduceSpec};
use debashl::ir::IrProgram;

/// Why a program was skipped (caller maps this to exit 2).
#[derive(Debug, Clone)]
pub enum Skip {
    NoDevice,
    NoCandidate(String),
    Unbindable(String),
    /// Device/runtime failure at dispatch (e.g. device OOM on a large
    /// fused array): a clean skip, never a crash — the CPU path stays
    /// correct and `--gpu=auto` falls back to it.
    Runtime(String),
}

impl std::fmt::Display for Skip {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Skip::NoDevice => write!(f, "no CUDA device"),
            Skip::NoCandidate(r) => write!(f, "no runnable shape ({r})"),
            Skip::Unbindable(r) => write!(f, "{r}"),
            Skip::Runtime(r) => write!(f, "dispatch: {r}"),
        }
    }
}

enum Mode {
    Fused(CuLoopSpec, CuReduceSpec),
    Reduce(CuReduceSpec),
    Map(CuLoopSpec),
}

/// Select a mode and dispatch, timing `runs` repetitions (median ms).
///
/// Two IR views are accepted: `prog_flat` feeds the map/reduce candidacy
/// (a frontend may wrap arith in `Cast(Int64, …)` markers that hide
/// pow2 divisors from the mask plan — the driver's flat view strips
/// them), while `prog` feeds the sequential-lane analysis, which keys on
/// those same markers. Shell-frontend callers pass the same value twice.
pub fn run(
    prog: &IrProgram,
    prog_flat: &IrProgram,
    n: u64,
    binds: &[(String, i64)],
    runs: usize,
) -> Result<(f64, i64), Skip> {
    if !cudaffi::has_cuda_device() {
        return Err(Skip::NoDevice);
    }
    let map_spec = cu_candidacy::analyze(prog_flat)
        .into_iter()
        .find_map(|v| if v.is_candidate() { v.spec.clone() } else { None });
    let red_spec = cu_candidacy::analyze_reduce(prog_flat).into_iter().find_map(|v| {
        if matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate) {
            v.spec.clone()
        } else {
            None
        }
    });
    // Sequential-lane reductions (collatz chains): array-free specs with
    // a seq_prelude — the Reduce vehicle dispatches them unchanged.
    let seq_spec = cu_candidacy::analyze_seq(prog).into_iter().find_map(|v| {
        if matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate) {
            v.spec.clone()
        } else {
            None
        }
    });
    let red_spec = seq_spec.or(red_spec);
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
            return Err(Skip::NoCandidate("reduce reads arrays with no fusable map".into()));
        }
        (None, None) => return Err(Skip::NoCandidate("no candidate loop".into())),
    };
    let runner = cudaffi::CudaRunner::new().map_err(|_| Skip::NoDevice)?;
    let run_once = |runner: &cudaffi::CudaRunner| -> Result<i64, Skip> {
        match &mode {
            Mode::Map(m) => run_map(runner, m, n, binds),
            Mode::Reduce(r) => run_reduce(runner, r, n, binds, None),
            Mode::Fused(m, r) => run_fused(runner, m, r, n, binds),
        }
    };
    let checksum = run_once(&runner)?;
    let mut ts = Vec::new();
    for _ in 0..runs.max(1) {
        let t = std::time::Instant::now();
        let _ = run_once(&runner)?;
        ts.push(t.elapsed().as_secs_f64() * 1000.0);
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    Ok((ts[ts.len() / 2], checksum))
}

/// Identical iteration spaces (coverage-exact fusion).
fn same_space(m: &CuLoopSpec, r: &CuReduceSpec) -> bool {
    m.var == r.var
        && m.lo == r.lo
        && m.bound_var == r.bound_var
        && m.bound_lt == r.bound_lt
        && m.step == r.step
}

/// Bind a spec's externs: single-extern auto-binds N, else every extern
/// needs an explicit `--bind` (loud refuse — never guess values).
fn bind_externs(externs: &[String], n: u64, binds: &[(String, i64)]) -> Result<Vec<i64>, Skip> {
    let mut evals = Vec::new();
    for e in externs {
        if let Some((_, v)) = binds.iter().find(|(k, _)| k == e) {
            evals.push(*v);
        } else if externs.len() == 1 {
            evals.push(n as i64);
        } else {
            // Never guess a value (refuse > guess): the caller turns
            // this into an exit-2 skip with the missing bind named.
            return Err(Skip::Unbindable(format!(
                "extern `{e}` needs --bind {e}=<i64>"
            )));
        }
    }
    Ok(evals)
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
) -> Result<i64, Skip> {
    let evals = bind_externs(&m.externs, n, binds)?;
    let trips = trips_of(m.lo, evals[0], m.bound_lt, m.step);
    if trips == 0 {
        return Ok(0);
    }
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
    let mut m_fast = m.clone();
    if let Some(t) = m.mask_thresh {
        if t == i128::MAX || (t >= 0 && (n as u128) <= (t as u128)) {
            m_fast.mask_fast = true;
        }
    }
    let ptx = shir_to_cu_compute(&m_fast);
    let out = runner
        .run(&ptx, "kern", &out_lens, &scalars, groups, m.threads)
        .map_err(Skip::Runtime)?;
    const MOD: u64 = 4294967296;
    let mut s: u64 = 0;
    for &x in &out[0] {
        s = (s + (x as u64) % MOD) % MOD;
    }
    Ok(s as i64)
}

/// Reduce mode (standalone): partials + host finish seeded with init.
fn run_reduce(
    runner: &cudaffi::CudaRunner,
    r: &CuReduceSpec,
    n: u64,
    binds: &[(String, i64)],
    shared: Option<&[(String, cudaffi::CUdeviceptr)]>,
) -> Result<i64, Skip> {
    let evals = bind_externs(&r.externs, n, binds)?;
    let bound_val: i64 = binds
        .iter()
        .find(|(k, _)| k == &r.bound_var)
        .map(|(_, v)| *v)
        .unwrap_or(n as i64);
    let trips = trips_of(r.lo, bound_val, r.bound_lt, r.step);
    if trips == 0 {
        return Ok(r.acc_init);
    }
    let groups =
        ((trips + r.threads as u64 * r.block_items - 1) / (r.threads as u64 * r.block_items)) as u32;
    let mut r_fast = r.clone();
    if let Some(t) = r.mask_thresh {
        if t == i128::MAX || (t >= 0 && (n as u128) <= (t as u128)) {
            r_fast.mask_fast = true;
        }
    }
    let ptx = shir_to_cu_reduce(&r_fast);
    let partials = runner.alloc_array(groups as usize).map_err(Skip::Runtime)?;
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
        .map_err(Skip::Runtime)?;
    let parts = runner
        .read_array(partials, groups as usize)
        .map_err(Skip::Runtime)?;
    runner.free_array(partials);
    Ok(finish_reduce(&r.op, r.acc_init, &parts))
}

/// Host finish for reductions (seeded with init; per-partial folding).
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
            let mut s = init;
            for &x in parts {
                s = s.wrapping_add(x) % (*modulus);
            }
            s
        }
        CuReduceOp::MaskAdd { mask } => {
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
    r: &CuReduceSpec,
    n: u64,
    binds: &[(String, i64)],
) -> Result<i64, Skip> {
    let evals = bind_externs(&m.externs, n, binds)?;
    let trips = trips_of(m.lo, evals[0], m.bound_lt, m.step);
    if trips == 0 {
        return Ok(r.acc_init);
    }
    let top_i: i128 = m.lo as i128 + (trips as i128 - 1) * m.step as i128;
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
        handles.push((st.array.clone(), runner.alloc_array(len).map_err(Skip::Runtime)?));
    }
    let mut scalars = evals;
    scalars.push(trips as i64);
    let groups = ((trips + m.threads as u64 - 1) / m.threads as u64) as u32;
    let map_ptx = shir_to_cu_compute(m);
    {
        let bufs: Vec<cudaffi::CUdeviceptr> = handles.iter().map(|(_, h)| *h).collect();
        runner
            .run_buffers(&map_ptx, "kern", &bufs, &scalars, groups, m.threads)
            .map_err(Skip::Runtime)?;
    }
    let out = run_reduce(runner, r, n, binds, Some(&handles));
    for (_, h) in handles {
        runner.free_array(h);
    }
    out
}
