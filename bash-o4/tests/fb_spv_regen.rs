//! Embedded SPIR-V ↔ GLSL source drift gate (bash-o4/src/fb_spv).
//!
//! The runtime and `--fb-proof` execute the bytes committed in
//! `src/fb_spv/*.spv`; the GLSL that is supposed to produce them lives in
//! `fb_frag.rs`. Until now nothing tied the two together, so a shader fix
//! could land without the bytes (or vice versa) and every gate would stay
//! green. This test compiles each shader from source with the pinned
//! glslang (manifest entry `glslang`, fetched + sha256-verified + unpacked
//! through `fetch`) and byte-compares the result with the committed file.
//!
//! Modes:
//!   * default        — regenerate and compare; mismatch FAILS with both
//!                      sizes and sha256s.
//!   * SH2_FB_SPV_UPDATE=1 — rewrite `src/fb_spv/*.spv` and `manifest.json`
//!                      (compiler string, sizes, sha256) from source.
//!
//! No compiler reachable ⇒ the test reports SKIP and passes, matching the
//! suite's rule that missing tooling must not fake a green: the comparison
//! it would have made is simply not made, and the skip is visible.

use std::path::{Path, PathBuf};

fn spv_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("src/fb_spv")
}

fn shaders() -> Vec<(&'static str, &'static str, String)> {
    vec![
        ("blocks.vert.spv", "vert", bash_o4::fb_frag::blocks_vertex()),
        ("blocks.frag.spv", "frag", bash_o4::fb_frag::blocks_fragment()),
        ("overlay.vert.spv", "vert", bash_o4::fb_frag::overlay_vertex()),
        ("overlay.frag.spv", "frag", bash_o4::fb_frag::overlay_fragment()),
    ]
}

fn sha256_hex(bytes: &[u8]) -> String {
    use sha2::Digest;
    let mut h = sha2::Sha256::new();
    h.update(bytes);
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

fn compiler_version(compiler: &Path) -> String {
    std::process::Command::new(compiler)
        .arg("--version")
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).lines().next().unwrap_or("").trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "glslangValidator".to_string())
}

fn write_manifest(dir: &Path, compiler: &Path) {
    // Keep the existing key order/shape; only the values are regenerated.
    let mut body = String::new();
    body.push_str("{\n");
    body.push_str(&format!(
        "  \"compiler\": {},\n",
        serde_json::to_string(&compiler_version(compiler)).unwrap()
    ));
    body.push_str("  \"flags\": [\n    \"-V\"\n  ],\n");
    body.push_str("  \"mode\": \"raw-glslang (no spirv-opt), deterministic embed\",\n");
    body.push_str("  \"shaders\": {\n");
    let entries = shaders();
    for (i, (file, _, _)) in entries.iter().enumerate() {
        let bytes = std::fs::read(dir.join(file)).unwrap_or_default();
        body.push_str(&format!(
            "    {}: {{\n      \"bytes\": {},\n      \"sha256\": {}\n    }}{}\n",
            serde_json::to_string(file).unwrap(),
            bytes.len(),
            serde_json::to_string(&sha256_hex(&bytes)).unwrap(),
            if i + 1 == entries.len() { "" } else { "," }
        ));
    }
    body.push_str("  }\n}\n");
    std::fs::write(dir.join("manifest.json"), body).unwrap();
}

#[test]
fn embedded_spv_matches_its_source() {
    let dir = spv_dir();
    let cache = bash_o4::cache::cache_root(None);
    let compiler = match bash_o4::shader::find_spirv_compiler(&cache) {
        Some(c) => c,
        None => match bash_o4::fetch::ensure_toolchain(
            &cache,
            "glslang",
            // `SH2_FB_SPV_FETCH=1` opts into downloading the pinned asset
            // (CI); otherwise the default `ask` policy refuses without a
            // TTY, and the test reports the skip.
            if std::env::var("SH2_FB_SPV_FETCH").as_deref() == Ok("1") {
                bash_o4::fetch::FetchPolicy::Auto
            } else {
                bash_o4::fetch::FetchPolicy::Ask
            },
        ) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("fb_spv_regen: SKIP — no SPIR-V compiler ({e})");
                return;
            }
        },
    };
    let update = std::env::var("SH2_FB_SPV_UPDATE").map(|v| v == "1").unwrap_or(false);
    let work = std::env::temp_dir().join(format!("fb_spv_regen.{}", std::process::id()));
    std::fs::create_dir_all(&work).expect("spv workdir");

    let mut problems = Vec::new();
    for (file, ext, src) in shaders() {
        let got = match bash_o4::fb_frag::compile_stage(&compiler, &src, &work, ext) {
            Ok(b) => b,
            Err(e) => panic!("fb_spv_regen: {file}: compiler rejected its own source:\n{e}"),
        };
        let committed_path = dir.join(file);
        if update {
            std::fs::write(&committed_path, &got).expect("spv update write");
            eprintln!("fb_spv_regen: updated {file} ({} bytes)", got.len());
            continue;
        }
        let want = match std::fs::read(&committed_path) {
            Ok(b) => b,
            Err(e) => {
                problems.push(format!("{file}: unreadable: {e}"));
                continue;
            }
        };
        if got != want {
            problems.push(format!(
                "{file}: DRIFT — source compiles to {} bytes sha256 {}, committed is {} bytes sha256 {}",
                got.len(),
                sha256_hex(&got),
                want.len(),
                sha256_hex(&want)
            ));
        }
    }
    let _ = std::fs::remove_dir_all(&work);
    if update {
        write_manifest(&dir, &compiler);
        eprintln!("fb_spv_regen: manifest.json rewritten");
        return;
    }
    assert!(
        problems.is_empty(),
        "embedded SPIR-V does not match fb_frag.rs:\n  {}\nrun with SH2_FB_SPV_UPDATE=1 to regenerate",
        problems.join("\n  ")
    );
}
