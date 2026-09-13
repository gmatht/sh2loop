//! Shader emission + SPIR-V proof (docs/BASH-O4.md §4.4/§4.8).
//!
//! The emitted GLSL for the squares loop must carry the compute shape
//! (asserted structurally here AND in `vulkan_backend` unit tests) and
//! must compile through a real SPIR-V compiler with the SPIR-V magic
//! intact. No compiler present ⇒ reported skip (CPU gates must never
//! fail on toolchain drift).

use bash_o4::{pipeline, shader};

fn squares_prog() -> debashl::ir::IrProgram {
    let a1 = pipeline::parse_to_shir("#!/bin/bash\nfor ((i=0;i<64;i++)); do a[$i]=$((i*i)); done\n");
    pipeline::parse_program(&a1).expect("ingress")
}

#[test]
fn emit_squares_glsl() {
    let prog = squares_prog();
    let glsl = shader::emit_shader(&prog, "sh_loop_main_0").expect("emit");
    assert!(glsl.contains("#version 450"), "{glsl}");
    assert!(glsl.contains("gl_GlobalInvocationID"), "{glsl}");
    assert!(glsl.contains("data_a[uint(t)] = (i_ * i_);"), "{glsl}");
    // Vetoed loops never emit (refuse > guess).
    assert!(shader::emit_shader(&prog, "sh_loop_main_7").is_err());
}

#[test]
fn spv_compiles_with_magic() {
    let prog = squares_prog();
    let glsl = shader::emit_shader(&prog, "sh_loop_main_0").expect("emit");
    let root = std::env::temp_dir().join(format!("bo4spv{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let Some(cc) = shader::find_spirv_compiler(&root) else {
        eprintln!("SKIP spv_compiles_with_magic: no SPIR-V compiler");
        let _ = std::fs::remove_dir_all(&root);
        return;
    };
    let spv = shader::compile_spv(&cc, &glsl, &root).expect("spirv");
    assert!(spv.len() >= 20, "non-trivial module");
    assert_eq!(&spv[0..4], &[0x03, 0x02, 0x23, 0x07], "SPIR-V magic");
    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn extern_const_flows_to_in_data() {
    // Outer Int vars read in the body become host-provided slots.
    let a1 = pipeline::parse_to_shir("#!/bin/bash\nk=5\nfor ((i=0;i<8;i++)); do a[$i]=$((i*k)); done\n");
    let prog = pipeline::parse_program(&a1).expect("ingress");
    let glsl = shader::emit_shader(&prog, "sh_loop_main_0").expect("emit");
    assert!(glsl.contains("//   in_data[0] = k"), "{glsl}");
    assert!(glsl.contains("data_a[uint(t)] = (i_ * in_data[0]);"), "{glsl}");
}
