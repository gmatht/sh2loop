//! `--emit-shader`: GLSL450 for one candidate loop + SPIR-V check.
//!
//! Stage ⑥ of docs/BASH-O4.md §4.2: candidacy supplies the `VkLoopSpec`,
//! `debashl::vulkan_backend` renders it, and (when present) the SPIR-V
//! compiler (`glslangValidator -V`, system or manifest-cached) proves the
//! shader is real. Dispatch (⑦/⑧) is M3-remaining; this stage asserts the
//! exact bytes a future dispatch would upload.

use debashl::ir::IrProgram;

/// Find candidate `id` and render its shader. Errors when the id is
/// unknown or vetoed (refuse > guess — never emit a vetoed loop).
pub fn emit_shader(prog: &IrProgram, id: &str) -> Result<String, String> {
    let verdicts = crate::candidacy::analyze(prog);
    for v in &verdicts {
        if v.id == id {
            if !v.is_candidate() {
                return Err(format!("{id} is not a candidate: {v}"));
            }
            let spec = v.spec.as_ref().ok_or_else(|| format!("{id}: no lowered spec"))?;
            return Ok(debashl::vulkan_backend::shir_to_vk_compute(spec));
        }
    }
    Err(format!("unknown loop id {id:?}"))
}

/// Locate a SPIR-V compiler: `$BASH_O4_GLSLANG`, else `glslangValidator`
/// on PATH, else the manifest cache. Returns None when absent (callers
/// skip the SPIR-V leg with a note — never fail a CPU gate on toolchain
/// drift).
pub fn find_spirv_compiler(cache_root: &std::path::Path) -> Option<std::path::PathBuf> {
    if let Ok(v) = std::env::var("BASH_O4_GLSLANG") {
        let p = std::path::PathBuf::from(&v);
        if p.is_file() {
            return Some(p);
        }
    }
    if probe_bin("glslangValidator") {
        return Some(std::path::PathBuf::from("glslangValidator"));
    }
    let cached = cache_root.join("bash-o4-fetch").join("glslang");
    let bin = cached.join("bin").join("glslangValidator");
    if bin.is_file() {
        return Some(bin);
    }
    None
}

fn probe_bin(bin: &str) -> bool {
    std::process::Command::new(bin)
        .arg("--version")
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Compile GLSL to SPIR-V (`-V`), returning the SPIR-V bytes.
pub fn compile_spv(
    compiler: &std::path::Path,
    glsl: &str,
    workdir: &std::path::Path,
) -> Result<Vec<u8>, String> {
    let src = workdir.join("loop.comp");
    let out = workdir.join("loop.spv");
    std::fs::write(&src, glsl).map_err(|e| format!("spv workdir: {e}"))?;
    let st = std::process::Command::new(compiler)
        .arg("-V")
        .arg(&src)
        .arg("-o")
        .arg(&out)
        .output()
        .map_err(|e| format!("spirv compiler: cannot run: {e}"))?;
    if !st.status.success() {
        return Err(format!(
            "spirv compile failed:\n{}",
            String::from_utf8_lossy(&st.stderr)
        ));
    }
    std::fs::read(&out).map_err(|e| format!("spirv readback: {e}"))
}
