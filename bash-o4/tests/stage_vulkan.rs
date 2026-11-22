//! Generated bridge-contract stages → Vulkan GLSL 450 → SPIR-V.
//!
//! The lift binds a program's C2/C3 stage functions to GLSL (ES 1.00 today).
//! A Vulkan pipeline cannot consume ES, so `fb_frag::stage_vulkan_glsl`
//! lowers the *compiler's own output* to 450 and this test compiles that
//! result with the pinned glslang. Nothing here is hand-written GLSL: the
//! source of truth is the fixture parsed by the same front end `--check`
//! uses.

use std::path::PathBuf;

use bash_o4::fb_frag::{self, Stage};

fn compiler(cache: &std::path::Path) -> Option<PathBuf> {
    if let Some(c) = bash_o4::shader::find_spirv_compiler(cache) {
        return Some(c);
    }
    let policy = if std::env::var("SH2_FB_SPV_FETCH").as_deref() == Ok("1") {
        bash_o4::fetch::FetchPolicy::Auto
    } else {
        bash_o4::fetch::FetchPolicy::Ask
    };
    match bash_o4::fetch::ensure_toolchain(cache, "glslang", policy) {
        Ok(c) => Some(c),
        Err(e) => {
            eprintln!("stage_vulkan: SKIP — no SPIR-V compiler ({e})");
            None
        }
    }
}

fn bound_stages() -> (String, String) {
    let src = include_str!("../../sh2perl/tests/fixtures/gpu_lift/two-quads.sh");
    let cmds = debashl::Parser::new(src).parse().expect("fixture parses");
    let mut prog = debashl::shir::ast_to_ir_raw(&cmds);
    prog.var_types = debashl::shir::analyze_var_types(&prog);
    let verdicts = debashl::shir_passes::gpu_lift::analyze(&prog);
    let mut vert = None;
    let mut frag = None;
    for v in &verdicts {
        if let debashl::shir_passes::gpu_lift::GpuLiftVerdict::Site {
            kind,
            shader: Some(sh),
            ..
        } = v
        {
            match kind {
                debashl::shir_passes::gpu_lift::LiftKind::Vertex => vert = Some(sh.glsl.clone()),
                debashl::shir_passes::gpu_lift::LiftKind::Fragment => frag = Some(sh.glsl.clone()),
                _ => {}
            }
        }
    }
    (vert.expect("vertex site"), frag.expect("fragment site"))
}

#[test]
fn generated_stage_pair_lowers_and_compiles() {
    let cache = bash_o4::cache::cache_root(None);
    let Some(cc) = compiler(&cache) else {
        return;
    };
    let (vert_es, frag_es) = bound_stages();
    let work = std::env::temp_dir().join(format!("stage_vk.{}", std::process::id()));
    std::fs::create_dir_all(&work).unwrap();

    let vert = fb_frag::stage_vulkan_glsl(&vert_es, Stage::Vertex).expect("vertex lowering");
    let frag = fb_frag::stage_vulkan_glsl(&frag_es, Stage::Fragment).expect("fragment lowering");

    // The lowering must be a real transform, not a pass-through.
    assert!(vert.starts_with("#version 450"));
    assert!(vert.contains("layout(location=0) in vec3 aPosition;"), "{vert}");
    assert!(vert.contains("layout(location=0) out highp vec4 vColor;"), "{vert}");
    assert!(!vert.contains("attribute "), "{vert}");
    assert!(frag.contains("layout(location=0) in highp vec4 vColor;"), "{frag}");
    assert!(frag.contains("uniform sampler2D uTex;"), "{frag}");
    assert!(frag.contains("texture("), "{frag}");
    assert!(frag.contains("sh_frag_color"), "{frag}");

    let vspv = fb_frag::compile_stage(&cc, &vert, &work, "vert").expect("vertex SPIR-V");
    let fspv = fb_frag::compile_stage(&cc, &frag, &work, "frag").expect("fragment SPIR-V");
    assert!(vspv.len() > 4 && fspv.len() > 4, "empty SPIR-V");
    let _ = std::fs::remove_dir_all(&work);
    eprintln!(
        "stage_vulkan: generated pair compiled (vert {} bytes, frag {} bytes)",
        vspv.len(),
        fspv.len()
    );
}

/// Lavapipe: build the pipeline from the *generated* stage pair and draw a
/// screen-aligned quad through the device vertex-stream layout. Proves the
/// runner can express a generated-stage pipeline end to end (no hand-written
/// shader anywhere).
#[test]
fn generated_stage_pair_draws_through_a_real_pipeline() {
    let cache = bash_o4::cache::cache_root(None);
    let Some(cc) = compiler(&cache) else {
        return;
    };
    let (vert_es, frag_es) = bound_stages();
    let vert = fb_frag::stage_vulkan_glsl(&vert_es, Stage::Vertex).unwrap();
    let frag = fb_frag::stage_vulkan_glsl(&frag_es, Stage::Fragment).unwrap();
    let work = std::env::temp_dir().join(format!("stage_vk_draw.{}", std::process::id()));
    std::fs::create_dir_all(&work).unwrap();
    let vspv = fb_frag::compile_stage(&cc, &vert, &work, "vert").unwrap();
    let fspv = fb_frag::compile_stage(&cc, &frag, &work, "frag").unwrap();

    // Same ICD pin as fb_dispatch: lavapipe is the tested, software-only
    // device (and the one CI can rely on).
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("BASH_O4_VK_ICD").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }
    if let Ok(icd) = std::env::var("BASH_O4_VK_ICD") {
        std::env::set_var("VK_ICD_FILENAMES", icd);
    }
    let (w, h) = (64u32, 48u32);
    let mut runner = match bash_o4::fb_draw::RasterRunner::new(w, h) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("stage_vulkan: SKIP draw — no graphics device ({e})");
            return;
        }
    };
    let atlas = vec![128u8; 16 * 16 * 4 * 4]; // 4 layers, opaque grey
    let (_, _, atlas_view) = runner.upload_atlas(&atlas, 4, 16).expect("atlas");

    // Screen-aligned quad, milli semantics: aPosition ±1 → ap_* = ±1000 →
    // vp_* = ±700 with vp_w = 1000 → NDC ±0.7 (the rasteriser's w divide).
    let quad = [
        [-1.0f32, -1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0],
        [1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0],
        [1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, -1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0],
        [1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        [-1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0.0, 1.0],
    ];
    let verts: Vec<f32> = quad.iter().flatten().copied().collect();
    // push block: uObjPos, uScale, uBlockColor (vec3 each, milli at *1000)
    let mut push = bash_o4::fb_draw::PushConstants {
        cam0: [0.0; 4],
        cam1: [0.0; 4],
        cfg: [0; 4],
    };
    // The stage converts *1000 itself (fbdev's milli convention), so
    // scale/colour are 1.0 world units, object at the origin.
    PushConstantsWords::set(&mut push, &[0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]);
    runner
        .draw_stages(&vspv, &fspv, &verts, &push, atlas_view)
        .expect("stage draw");
    let px = runner.readback().expect("readback");
    let lit = px
        .chunks_exact(4)
        .filter(|p| p[0] != 0 || p[1] != 0 || p[2] != 0)
        .count();
    eprintln!("stage_vulkan: {lit} lit pixels through the generated-stage pipeline");
    assert!(
        lit > 0,
        "generated-stage pipeline drew nothing (clear colour only)"
    );
    let _ = std::fs::remove_dir_all(&work);
}

/// The push-constant block is `[f32; 4] + [f32; 4] + [i32; 4]`; the
/// generated stages' `push_constant` block is 3 `vec3`s, so the first nine
/// floats carry obj/scale/colour.
struct PushConstantsWords;
impl PushConstantsWords {
    fn set(p: &mut bash_o4::fb_draw::PushConstants, words: &[f32; 9]) {
        let raw = p as *mut bash_o4::fb_draw::PushConstants as *mut f32;
        for (i, w) in words.iter().enumerate() {
            unsafe { *raw.add(i) = *w }
        }
    }
}

/// Minimal isolation harness (retained as evidence): one binding, one
/// attribute, a trivial pass-through shader pair — nothing from the fb
/// bridge. If THIS faults in `vkCreateGraphicsPipelines`, the binding
/// state/FFI is at fault rather than the generated stage interface.
#[test]
fn minimal_vertex_binding_pipeline() {
    let cache = bash_o4::cache::cache_root(None);
    let Some(cc) = compiler(&cache) else {
        return;
    };
    let vert = "#version 450\nlayout(location = 0) in vec3 p;\nvoid main() { gl_Position = vec4(p, 1.0); }\n";
    let frag = "#version 450\nlayout(location = 0) out vec4 c;\nvoid main() { c = vec4(1.0); }\n";
    let work = std::env::temp_dir().join(format!("stage_min.{}.", std::process::id()));
    std::fs::create_dir_all(&work).unwrap();
    let vspv = fb_frag::compile_stage(&cc, vert, &work, "vert").unwrap();
    let fspv = fb_frag::compile_stage(&cc, frag, &work, "frag").unwrap();
    let mut runner = match bash_o4::fb_draw::RasterRunner::new(8, 8) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("stage_vulkan: SKIP minimal — no device ({e})");
            return;
        }
    };
    runner
        .precompile_stages(&vspv, &fspv)
        .expect("minimal pipeline create");
    eprintln!("stage_vulkan: minimal binding pipeline created");
    let _ = std::fs::remove_dir_all(&work);
}

#[test]
fn unmapped_contract_names_refuse_the_lowering() {
    let bad = "attribute vec3 aNope;\nvoid main() { gl_Position = vec4(0.0); }\n";
    let e = fb_frag::stage_vulkan_glsl(bad, Stage::Vertex).expect_err("must refuse");
    assert_eq!(
        e,
        "stage-pair-unmappable: unmapped vertex attribute 'aNope'",
        "refusal reason must be stable"
    );
}

/// The host-split half: the fixture's generated C carries the pair's SPIR-V
/// and the `_sh_gpu_stages` call beside `_sh_gpu_blocks`, and the CPU path is
/// still emitted. Requires the pinned glslang at build time; without it the
/// split is refused, so the assertion is skipped only in that case.
#[test]
fn emitted_c_carries_the_stage_split() {
    let cache = bash_o4::cache::cache_root(None);
    if compiler(&cache).is_none() {
        eprintln!("stage_vulkan: SKIP emitted-c — no SPIR-V compiler");
        return;
    }
    let src = include_str!("../../sh2perl/tests/fixtures/gpu_lift/two-quads.sh");
    let a1 = bash_o4::pipeline::parse_to_shir(src);
    let c = bash_o4::pipeline::render_c(&a1).expect("render");
    assert_eq!(c.matches("_sh_gpu_stages(").count(), 1, "one stage split");
    assert_eq!(c.matches("_sh_gpu_blocks(").count(), 1, "one draw split");
    assert!(c.contains("_sh_stage_vspv"), "embedded vertex SPIR-V");
    assert!(c.contains("_sh_stage_fspv"), "embedded fragment SPIR-V");
    assert!(c.contains("fb_blocks("), "CPU firewall still emitted");
    // The CPU counterpart is DERIVED from the stage functions; the fixture
    // carries no record of its own (it used to hand-place an overlay).
    assert!(
        c.contains("fb_stage_ref(0, 0, 700, 450, 14, 14, 14)"),
        "derived stage reference missing:\n{c}"
    );
    assert!(!c.contains("fb_overlay("), "the fixture must not hand-place a CPU record");
    eprintln!("stage_vulkan: emitted C carries _sh_gpu_stages beside _sh_gpu_blocks");
}

/// The stage reference is computed by evaluating the bound stage functions,
/// for BOTH witnesses, with no fixture-specific path — and a pair the
/// evaluator cannot cover is refused instead of being given a made-up one.
#[test]
fn stage_reference_is_derived_from_the_stage_functions() {
    for (name, src, want) in [
        (
            "two-quads.sh",
            include_str!("../../sh2perl/tests/fixtures/gpu_lift/two-quads.sh"),
            "fb_stage_ref(0, 0, 700, 450, 14, 14, 14)",
        ),
        (
            "hud-bar.sh",
            include_str!("../../sh2perl/tests/fixtures/gpu_lift/hud-bar.sh"),
            "fb_stage_ref(175, -125, 550, 300, 9, 19, 40)",
        ),
    ] {
        let a1 = bash_o4::pipeline::parse_to_shir(src);
        let mut prog = bash_o4::pipeline::parse_program(&a1).expect("ir");
        prog.var_types = debashl::shir::analyze_var_types(&prog);
        let (vert, frag) = stage_fn_names(&prog);
        let r = bash_o4::stage_ref::derive(&prog, &vert, &frag)
            .unwrap_or_else(|e| panic!("{name}: derivation refused: {e}"));
        let call = bash_o4::stage_ref::c_call(&r);
        assert_eq!(call, want, "{name}: derived reference");
    }

    // Uncovered: the fragment reads a per-pixel bridge, so no single-colour
    // rectangle can be its CPU counterpart. The compiler must say why.
    let src = include_str!("../../sh2perl/tests/fixtures/gpu_lift/refuse-fragx.sh");
    let a1 = bash_o4::pipeline::parse_to_shir(src);
    let mut prog = bash_o4::pipeline::parse_program(&a1).expect("ir");
    prog.var_types = debashl::shir::analyze_var_types(&prog);
    let (vert, frag) = stage_fn_names(&prog);
    let err = bash_o4::stage_ref::derive(&prog, &vert, &frag).expect_err("frag_x must refuse");
    assert!(err.starts_with(bash_o4::stage_ref::REFUSE), "{err}");
    assert!(err.contains("frag_x"), "{err}");
    eprintln!("stage_vulkan: uncovered pair refused: {err}");
}

/// The vertex stage's x is negated into the frame's convention (the runner
/// reads the target back with a 180° permutation). Two-quads is symmetric in
/// x, so only hud-bar can catch a regression here.
#[test]
fn vertex_stage_x_is_mirrored_into_the_frame_convention() {
    let (vert_es, _frag_es) = bound_stages();
    let vert = fb_frag::stage_vulkan_glsl(&vert_es, Stage::Vertex).expect("vertex lowering");
    assert!(vert.contains("void sh_stage_main()"), "{vert}");
    assert!(
        vert.contains("gl_Position.x = -gl_Position.x;"),
        "the frame's x convention is not applied:\n{vert}"
    );
}

fn stage_fn_names(prog: &debashl::ir::IrProgram) -> (String, String) {
    let mut vert = None;
    let mut frag = None;
    for v in debashl::shir_passes::gpu_lift::analyze(prog) {
        if let debashl::shir_passes::gpu_lift::GpuLiftVerdict::Site {
            kind,
            site,
            shader: Some(_),
        } = v
        {
            let name = site.strip_prefix("fn:").unwrap_or(&site).to_string();
            match kind {
                debashl::shir_passes::gpu_lift::LiftKind::Vertex => vert = Some(name),
                debashl::shir_passes::gpu_lift::LiftKind::Fragment => frag = Some(name),
                _ => {}
            }
        }
    }
    (vert.expect("vertex site"), frag.expect("fragment site"))
}

/// Out-of-process parity: the fixture's SH2_FB_GPU=0 and SH2_FB_GPU=1 PPMs
/// are byte-identical, and the GPU run's log shows the stage dispatch.
#[test]
fn fixture_parity_and_stage_path_evidence() {
    // Cargo only exports CARGO_BIN_EXE_<name> for `cargo test` runs that
    // build binaries; fall back to the sibling executable so the parity
    // test also runs under a plain `cargo test --test`.
    let exe = std::env::var("CARGO_BIN_EXE_bash-O4")
        .map(PathBuf::from)
        .ok()
        .filter(|p| p.is_file())
        .or_else(|| {
            // tests run from target/debug/deps, the binary from
            // target/debug — check both.
            std::env::current_exe().ok().and_then(|p| {
                let deps = p.parent()?;
                let top = deps.parent()?;
                [deps.join("bash-O4"), top.join("bash-O4")]
                    .into_iter()
                    .find(|q| q.is_file())
            })
        });
    let Some(exe) = exe else {
        eprintln!("stage_vulkan: SKIP parity — bash-O4 binary not built");
        return;
    };
    let cache = bash_o4::cache::cache_root(None);
    if compiler(&cache).is_none() {
        eprintln!("stage_vulkan: SKIP parity — no SPIR-V compiler");
        return;
    }
    let dir = std::env::temp_dir().join(format!("stage_parity.{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let lib = dir.join("libbash_o4.so");
    // The host library sits beside the test binary in target/debug.
    let built_lib = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/debug/libbash_o4.so");
    if built_lib.is_file() {
        std::fs::copy(&built_lib, &lib).expect("copy lib");
    }
    let base = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../sh2perl/tests/fixtures/gpu_lift");
    let cache_dir = std::env::var("XDG_CACHE_HOME").unwrap_or_else(|_| cache.display().to_string());

    // Two independent witnesses dispatch and present GPU pixels that match
    // their CPU firewall exactly; the refusal witness emits no split at all.
    parity_for(&exe, &lib, &cache_dir, &base.join("two-quads.sh"), &dir, true);
    parity_for(&exe, &lib, &cache_dir, &base.join("hud-bar.sh"), &dir, true);
    parity_for(&exe, &lib, &cache_dir, &base.join("refuse-fragx.sh"), &dir, false);
    let _ = std::fs::remove_dir_all(&dir);
}

/// Run one fixture with the GPU off and on and assert what its log and its
/// two PPMs may say. `stage` is whether a verified stage dispatch must exist.
fn parity_for(
    exe: &std::path::Path,
    lib: &std::path::Path,
    cache: &str,
    fixture: &std::path::Path,
    dir: &std::path::Path,
    stage: bool,
) {
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    let tag = fixture.file_stem().unwrap().to_string_lossy().to_string();
    let cpu_ppm = dir.join(format!("{tag}-cpu.ppm"));
    let gpu_ppm = dir.join(format!("{tag}-gpu.ppm"));
    let log = dir.join(format!("{tag}-gpu.log"));
    let run = |gpu: bool, out: &PathBuf| -> std::process::Output {
        let mut cmd = std::process::Command::new(exe);
        cmd.arg(fixture).arg("--").arg(out);
        cmd.env("SH2_FB_GPU", if gpu { "1" } else { "0" });
        cmd.env("XDG_CACHE_HOME", cache);
        if gpu {
            cmd.env("SH2_FB_GPU_LIB", lib);
            cmd.env("SH2_FB_GPU_LOG", &log);
            if std::env::var("BASH_O4_VK_ICD").is_err() && std::path::Path::new(LVP).is_file() {
                cmd.env("VK_ICD_FILENAMES", LVP);
            }
        }
        cmd.output().expect("run bash-O4")
    };
    let cpu = run(false, &cpu_ppm);
    let gpu = run(true, &gpu_ppm);
    assert!(cpu.status.success(), "{tag}: CPU run failed: {}", String::from_utf8_lossy(&cpu.stderr));
    assert!(gpu.status.success(), "{tag}: GPU run failed: {}", String::from_utf8_lossy(&gpu.stderr));
    let a = std::fs::read(&cpu_ppm).unwrap();
    let b = std::fs::read(&gpu_ppm).unwrap();
    assert!(a == b, "{tag}: PPMs differ: {} vs {} bytes", a.len(), b.len());
    let logtext = std::fs::read_to_string(&log).unwrap_or_default();
    let stage_lines: Vec<&str> = logtext.lines().filter(|l| l.contains("stage-dispatch")).collect();
    if stage {
        assert_eq!(stage_lines.len(), 1, "{tag}: stage dispatch not logged:\n{logtext}");
        // The stage frame must pass the parity gate, not be rescued by the
        // CPU fallback: the compare line is the gate's own verdict, so
        // asserting on it is what distinguishes "the GPU frame matched" from
        // "the CPU frame was kept (and the PPMs agree because both are CPU)".
        assert!(
            logtext.contains("GPU frame matches the CPU firewall (0 differing px, max_abs=0)"),
            "{tag}: stage frame did not pass the parity gate:\n{logtext}"
        );
        assert!(
            !logtext.contains("differs from the CPU frame"),
            "{tag}: the stage frame still differs from the CPU firewall:\n{logtext}"
        );
        assert!(
            logtext.contains("dispatch:") && logtext.contains("dispatched=1 mismatch=0"),
            "{tag}: the frame was not dispatched from GPU pixels:\n{logtext}"
        );
        eprintln!(
            "stage_vulkan: {tag} parity byte-identical ({} bytes); {}",
            a.len(),
            stage_lines[0]
        );
    } else {
        // Refused at compile time: no stage split, so nothing dispatches and
        // nothing can be counted as a match. The PPMs agree because the CPU
        // frame is the frame — exactly what a veto means.
        // The BLOCKS split may still dispatch (that is its own, verified
        // draw); what must not happen is a stage dispatch, because the pair
        // has no CPU reference to be verified against.
        assert!(stage_lines.is_empty(), "{tag}: an uncovered pair dispatched:\n{logtext}");
        assert!(
            !logtext.contains("drawn into the frame"),
            "{tag}: an uncovered stage pair reached the GPU:\n{logtext}"
        );
        eprintln!("stage_vulkan: {tag} refused (no stage split), PPMs identical");
    }
    for l in logtext.lines().filter(|l| l.contains("verify") || l.contains("dispatch:") || l.contains("refused:")) {
        eprintln!("stage_vulkan: {tag}: {l}");
    }
}
