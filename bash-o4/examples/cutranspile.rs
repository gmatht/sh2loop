//! cutranspile — transpiled-CUDA vehicle: `cutranspile <script.sh> <N>
//! [--runs K] [--bind var=value...]` prints `<median_ms> <checksum>`.
//!
//! End-to-end bash→ShIR→candidacy→PTX→GPU with NO hand kernels: parses
//! the script, takes the FIRST candidate loop, emits PTX via
//! `cuda_backend`, dispatches with externs bound from CLI, reads back
//! the first output array, and checksums mod-2^32 on the host (generic
//! finish for int arrays — matches gpuleg's ArraySumMod).
//!
//! v1 scope (documented limits, loud errors otherwise):
//! - map loops only (scalar-carry vetoes — reductions stay hand-tuned);
//! - externs: exactly one auto-binds from N (the bound, e.g. `n`);
//!   multiple externs require explicit `--bind` for each;
//! - checksums the FIRST output array (multi-store loops: first wins).
//! Exit 2 + SKIP message when: no CUDA device, no candidate loop, or
//! unbindable externs (bench-opt treats 2 as skip, not failure).
use bash_o4::{cu_candidacy, cudaffi};
use debashl::cuda_backend::shir_to_cu_compute;

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
    let verdicts = cu_candidacy::analyze(&prog);
    let spec = verdicts
        .iter()
        .find_map(|v| {
            if v.is_candidate() {
                v.spec.clone()
            } else {
                None
            }
        });
    let spec = match spec {
        Some(s) => s,
        None => {
            let reasons: Vec<String> =
                verdicts.iter().map(|v| v.to_string()).collect();
            eprintln!("SKIP cutranspile: no candidate loop ({})", reasons.join("; "));
            std::process::exit(2);
        }
    };
    // Bind externs: single-extern auto-binds N; else every extern needs
    // an explicit --bind (loud refuse — never guess values).
    let mut evals: Vec<i64> = Vec::new();
    for e in &spec.externs {
        if let Some((_, v)) = binds.iter().find(|(k, _)| k == e) {
            evals.push(*v);
        } else if spec.externs.len() == 1 {
            evals.push(n as i64);
        } else {
            eprintln!("SKIP cutranspile: extern `{e}` needs --bind {e}=<i64>");
            std::process::exit(2);
        }
    }
    // Trips on host from the bound value (mirror candidacy::trips with a
    // runtime hi): span = (b - lo) + (lt ? 0 : 1); ceil(span/step).
    let bound_val = evals[0];
    let span: i128 = (bound_val as i128 - spec.lo as i128) + if spec.bound_lt { 0 } else { 1 };
    let trips: u64 = if span <= 0 {
        0
    } else {
        ((span + spec.step as i128 - 1) / spec.step as i128) as u64
    };
    let ptx = shir_to_cu_compute(&spec);
    let runner = cudaffi::CudaRunner::new().expect("runner");
    // out_lens: exact per-array sizes from the affine bounds.
    // Counter i_ ranges [lo, lo+(trips-1)*step]; idx = a*i_+b. For a>0
    // the max is at the top; a<0 decreases (negative slots guard-skip
    // in-kernel, needing no storage); a==0 is constant b. All inputs
    // (lo/step/trips/a/b) are known here — exact, no guessing.
    let top_i: i128 = if trips == 0 {
        spec.lo as i128
    } else {
        spec.lo as i128 + (trips as i128 - 1) * spec.step as i128
    };
    let out_lens: Vec<usize> = spec
        .stores
        .iter()
        .map(|st| {
            let need: i128 = if st.index_a > 0 {
                st.index_a as i128 * top_i + st.index_b as i128 + 1
            } else if st.index_a < 0 {
                st.index_a as i128 * spec.lo as i128 + st.index_b as i128 + 1
            } else {
                st.index_b as i128 + 1
            };
            need.clamp(1, i128::from(usize::MAX as u64)) as usize
        })
        .collect();
    // Scalar params: extern values then trips (emitter contract).
    let mut scalars: Vec<i64> = evals.clone();
    scalars.push(trips as i64);
    let groups = if trips == 0 {
        0
    } else {
        ((trips + spec.threads as u64 - 1) / spec.threads as u64) as u32
    };
    // Warmup (proves correctness once, outside timer).
    let checksum = if trips == 0 {
        0
    } else {
        let out = runner
            .run(&ptx, "kern", &out_lens, &scalars, groups, spec.threads)
            .expect("warmup dispatch");
        finish(&out[0])
    };
    // Timed: median dispatches + host finish each rep.
    let mut ts = Vec::new();
    for _ in 0..runs {
        let t = std::time::Instant::now();
        let c = if trips == 0 {
            0
        } else {
            let out = runner
                .run(&ptx, "kern", &out_lens, &scalars, groups, spec.threads)
                .expect("dispatch");
            finish(&out[0])
        };
        let _ = c;
        ts.push(t.elapsed().as_secs_f64() * 1000.0);
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = ts[ts.len() / 2];
    println!("{median:.3} {checksum}");

    /// mod-2^32 host checksum over one int64 array (gpuleg parity).
    fn finish(arr: &[i64]) -> u64 {
        const MOD: u64 = 4294967296;
        let mut s: u64 = 0;
        for &x in arr {
            s = (s + (x as u64) % MOD) % MOD;
        }
        s
    }
}
