//! vkbench — GPU vs CPU dispatch measurements (docs/BASH_VULKAN.md).
//!
//! Times the emitter's squares loop (`out[i] = i*i`) on Lavapipe across
//! trip counts, plus a native Rust loop doing the same work. Usage:
//! `cargo run --offline --example vkbench -- [trips...]`
//! (default sizes). Requires a Vulkan compute device + glslangValidator;
//! exits 2 with a SKIP note when absent (never fails a CPU-only box).

use bash_o4::{shader, vkffi};
use debashl::vulkan_backend::{VkArith, VkLoopSpec, VkStore};
use std::time::Instant;

fn squares(trips: u64, unroll: u32) -> VkLoopSpec {
    // Measurement knob only (default 256): VKBENCH_LOCAL_SIZE=64 ...
    let local_size_x: u32 = std::env::var("VKBENCH_LOCAL_SIZE")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(256);
    VkLoopSpec {
        id: "vkbench".into(),
        var: "i".into(),
        lo: 0,
        hi: trips as i64,
        hi_inclusive: false,
        step: 1,
        trips,
        local_size_x,
        unroll,
        externs: vec![],
        stores: vec![VkStore {
            array: "a".into(),
            index_a: 1,
            index_b: 0,
            value: VkArith::Mul(Box::new(VkArith::LoopVar), Box::new(VkArith::LoopVar)),
        }],
    }
}

fn cpu_squares(n: usize) -> Vec<i64> {
    let mut out = vec![0i64; n];
    for (i, v) in out.iter_mut().enumerate() {
        *v = (i as i64) * (i as i64);
    }
    out
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let sizes: Vec<u64> = if args.is_empty() {
        vec![1024, 16384, 65536, 262144, 1048576]
    } else {
        args.iter().map(|a| a.parse().expect("trips must be integers")).collect()
    };

    if !vkffi::has_compute_device() {
        eprintln!("SKIP vkbench: no Vulkan compute device");
        std::process::exit(2);
    }
    // Pin Lavapipe for reproducible numbers when present.
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("VK_ICD_FILENAMES").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }

    let root = std::env::temp_dir().join(format!("bo4bench{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let cc = match shader::find_spirv_compiler(&root) {
        Some(c) => c,
        None => {
            eprintln!("SKIP vkbench: no SPIR-V compiler");
            std::process::exit(2);
        }
    };

    let t0 = Instant::now();
    let runner = vkffi::ComputeRunner::new().expect("compute runner");
    let setup_ms = t0.elapsed().as_secs_f64() * 1000.0;

    println!("trips\tscalar_ms\tunroll_ms\tcpu_ms");
    for &n in &sizes {
        let ls: u64 = std::env::var("VKBENCH_LOCAL_SIZE")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(256);
        // Paired best-of-7 under identical noise: alternate scalar and
        // unrolled dispatches, keep each config's minimum (best-of, the
        // sh2runtime convention for loaded boxes).
        let mut best = [(f64::INFINITY, "scalar"), (f64::INFINITY, "unroll")];
        for u in [1u32, 4] {
            let glsl = debashl::vulkan_backend::shir_to_vk_compute(&squares(n, u));
            let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv");
            let lanes = if u == 4 { n / 4 } else { n };
            let groups = ((lanes + ls - 1) / ls) as u32;
            let out = runner.run(&spv, None, &[n as usize], groups).expect("warmup");
            assert_eq!(out[0][(n as usize) - 1], ((n - 1) as i64) * ((n - 1) as i64));
            let idx = if u == 1 { 0 } else { 1 };
            for _ in 0..7 {
                let t = std::time::Instant::now();
                let _ = runner.run(&spv, None, &[n as usize], groups).expect("dispatch");
                let ms = t.elapsed().as_secs_f64() * 1000.0;
                if ms < best[idx].0 {
                    best[idx].0 = ms;
                }
            }
        }
        let (s_ms, u_ms) = (best[0].0, best[1].0);
        let t = Instant::now();
        for _ in 0..3 {
            let v = cpu_squares(n as usize);
            assert_eq!(v[(n as usize) - 1], ((n - 1) as i64) * ((n - 1) as i64));
        }
        let cpu_ms = t.elapsed().as_secs_f64() * 1000.0 / 3.0;
        println!("{n}\t{s_ms:.3}\t{u_ms:.3}\t{cpu_ms:.3}");
    }
    eprintln!("runner setup: {setup_ms:.1} ms (once)");
    let _ = std::fs::remove_dir_all(&root);
}
