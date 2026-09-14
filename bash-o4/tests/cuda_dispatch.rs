//! CUDA dispatch test: emitter output actually JITs and runs on-device.
//! Skips cleanly without a CUDA device (like vk_dispatch without Vulkan).
//! Small N only (correctness, not throughput — bench-opt measures that).

use bash_o4::cudaffi;
use debashl::cuda_backend::{CuArith, CuLoopSpec, CuStore};

fn squares_spec() -> CuLoopSpec {
    CuLoopSpec {
        id: "cu_test_squares".to_string(),
        var: "i".to_string(),
        lo: 0,
        bound_var: "n".to_string(),
        bound_lt: true,
        step: 1,
        threads: 256,
        externs: vec!["n".to_string()],
        mask_thresh: None,
        mask_fast: false,
        stores: vec![CuStore {
            array: "a".to_string(),
            index_a: 1,
            index_b: 0,
            value: CuArith::Mul(
                Box::new(CuArith::LoopVar),
                Box::new(CuArith::LoopVar),
            ),
        }],
    }
}

#[test]
fn dispatch_proof_on_device() {
    if !cudaffi::has_cuda_device() {
        eprintln!("SKIP dispatch_proof_on_device: no CUDA device");
        return;
    }
    let runner = cudaffi::CudaRunner::new().expect("cuda runner");
    let spec = squares_spec();
    let ptx = debashl::cuda_backend::shir_to_cu_compute(&spec);
    // 1024 trips, externs [n=1024] + trips: out[i] = i*i per lane.
    // (Scalar params are [externs..., trips] per the emitter contract.)
    let out = runner
        .run(&ptx, "kern", &[1024], &[1024, 1024], 4, 256)
        .expect("dispatch squares");
    assert_eq!(out.len(), 1);
    assert_eq!(out[0].len(), 1024);
    for (i, v) in out[0].iter().enumerate() {
        assert_eq!(*v, (i as i64) * (i as i64), "lane {i}");
    }
}

#[test]
fn dispatch_extern_value() {
    if !cudaffi::has_cuda_device() {
        eprintln!("SKIP dispatch_extern_value: no CUDA device");
        return;
    }
    let runner = cudaffi::CudaRunner::new().expect("cuda runner");
    // out[i] = i*k with extern k=7 (bound n=256 for trips).
    let mut spec = squares_spec();
    spec.externs = vec!["n".to_string(), "k".to_string()];
    spec.stores[0].value = CuArith::Mul(
        Box::new(CuArith::LoopVar),
        Box::new(CuArith::ExtVar("k".to_string())),
    );
    let ptx = debashl::cuda_backend::shir_to_cu_compute(&spec);
    let out = runner
        .run(&ptx, "kern", &[256], &[256, 7, 256], 1, 256)
        .expect("dispatch scaled");
    assert_eq!(out.len(), 1);
    assert_eq!(out[0].len(), 256);
    for (i, v) in out[0].iter().enumerate() {
        assert_eq!(*v, (i as i64) * 7, "lane {i}");
    }
}
