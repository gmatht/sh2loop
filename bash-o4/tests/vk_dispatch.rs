//! M3 dispatch proof (docs/BASH-O4.md §4.4/§4.8).
//!
//! A real compute dispatch on a real Vulkan device: the emitter's GLSL
//! for the squares loop is compiled to SPIR-V and dispatched, and every
//! lane is asserted (`out[i] == i*i`, plus an extern-const variant).
//! Lavapipe (software Vulkan) is pinned when present so CI needs no GPU.
//! No device at all ⇒ reported skip (CPU gates must never fail on
//! hardware drift); a PRESENT device that miscomputes FAILS loudly.

use bash_o4::{shader, vkffi};
use debashl::vulkan_backend::{VkArith, VkLoopSpec, VkStore};

fn pin_lavapipe() {
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("BASH_O4_VK_ICD").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }
    // vkffi honors VK_ICD_FILENAMES via the loader; BASH_O4_VK_ICD lets
    // operators pin a different ICD without touching the environment.
    if let Ok(icd) = std::env::var("BASH_O4_VK_ICD") {
        std::env::set_var("VK_ICD_FILENAMES", icd);
    }
}

fn squares_spec() -> VkLoopSpec {
    VkLoopSpec {
        id: "sh_loop_main_0".into(),
        var: "i".into(),
        lo: 0,
        hi: 1024,
        hi_inclusive: false,
        step: 1,
        trips: 1024,
        local_size_x: 256,
        unroll: 1,
        externs: vec![],
        stores: vec![VkStore {
            array: "a".into(),
            index_a: 1,
            index_b: 0,
            value: VkArith::Mul(Box::new(VkArith::LoopVar), Box::new(VkArith::LoopVar)),
        }],
    }
}

fn scaled_spec() -> VkLoopSpec {
    VkLoopSpec {
        id: "sh_loop_main_1".into(),
        var: "i".into(),
        lo: 0,
        hi: 256,
        hi_inclusive: false,
        step: 1,
        trips: 256,
        local_size_x: 256,
        unroll: 1,
        externs: vec!["k".into()],
        stores: vec![VkStore {
            array: "b".into(),
            index_a: 1,
            index_b: 0,
            value: VkArith::Mul(
                Box::new(VkArith::LoopVar),
                Box::new(VkArith::ExtVar("k".into())),
            ),
        }],
    }
}

#[test]
fn dispatch_proof_on_device() {
    if !vkffi::has_compute_device() {
        eprintln!("SKIP dispatch_proof_on_device: no Vulkan compute device");
        return;
    }
    pin_lavapipe();
    // Re-check under the pinned ICD (a present-but-broken loader must
    // not silently pass: require the device again).
    if !vkffi::has_compute_device() {
        eprintln!("SKIP dispatch_proof_on_device: pinned ICD has no device");
        return;
    }
    let root = std::env::temp_dir().join(format!("bo4vk{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();

    let cc = shader::find_spirv_compiler(&root).expect("dispatch needs glslangValidator");
    let runner = vkffi::ComputeRunner::new().expect("compute runner");

    // Case 1: out[i] = i*i over 1024 lanes (4 workgroups of 256).
    let glsl = debashl::vulkan_backend::shir_to_vk_compute(&squares_spec());
    let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv squares");
    let out = runner.run(&spv, None, &[1024], 4).expect("dispatch squares");
    assert_eq!(out.len(), 1);
    assert_eq!(out[0].len(), 1024);
    for (i, v) in out[0].iter().enumerate() {
        assert_eq!(*v, (i as i64) * (i as i64), "lane {i}");
    }

    // Case 2: host-provided extern (in_data[0] = k = 7).
    let glsl = debashl::vulkan_backend::shir_to_vk_compute(&scaled_spec());
    let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv scaled");
    let out = runner.run(&spv, Some(&[7]), &[256], 1).expect("dispatch scaled");
    assert_eq!(out.len(), 1);
    assert_eq!(out[0].len(), 256);
    for (i, v) in out[0].iter().enumerate() {
        assert_eq!(*v, (i as i64) * 7, "lane {i}");
    }

    // Case 3: two output arrays in one dispatch (shared pipeline/descriptors).
    let multi = debashl::vulkan_backend::VkLoopSpec {
        id: "sh_loop_main_2".into(),
        var: "i".into(),
        lo: 0,
        hi: 64,
        hi_inclusive: false,
        step: 1,
        trips: 64,
        local_size_x: 256,
        unroll: 4,
        externs: vec![],
        stores: vec![
            debashl::vulkan_backend::VkStore {
                array: "a".into(),
                index_a: 1,
                index_b: 0,
                value: debashl::vulkan_backend::VkArith::Mul(
                    Box::new(debashl::vulkan_backend::VkArith::LoopVar),
                    Box::new(debashl::vulkan_backend::VkArith::LoopVar),
                ),
            },
            debashl::vulkan_backend::VkStore {
                array: "b".into(),
                index_a: 1,
                index_b: 0,
                value: debashl::vulkan_backend::VkArith::Add(
                    Box::new(debashl::vulkan_backend::VkArith::LoopVar),
                    Box::new(debashl::vulkan_backend::VkArith::Num(1)),
                ),
            },
        ],
    };
    let glsl = debashl::vulkan_backend::shir_to_vk_compute(&multi);
    let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv multi");
    let out = runner.run(&spv, None, &[64, 64], 1).expect("dispatch multi");
    assert_eq!(out.len(), 2);
    for (i, v) in out[0].iter().enumerate() {
        assert_eq!(*v, (i as i64) * (i as i64), "a lane {i}");
    }
    for (i, v) in out[1].iter().enumerate() {
        assert_eq!(*v, (i as i64) + 1, "b lane {i}");
    }

    let _ = std::fs::remove_dir_all(&root);
}
