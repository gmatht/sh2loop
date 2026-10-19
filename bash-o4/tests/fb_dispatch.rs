//! fb0 fragment-leg dispatch proof (PLAN §11.14, `fb_frag` + `fb_draw`).
//!
//! The emitted `blocks`/`overlay` GLSL pairs are compiled to SPIR-V and
//! dispatched into an offscreen image on a real Vulkan device
//! (lavapipe pinned — CI needs no GPU), and the read-back pixels are
//! asserted against a Rust transcription of `frag_pixel`
//! (`sh2perl/runtime/fbdev.c:278`) fed with the SAME atlas bytes.
//! No device at all ⇒ reported skip (CPU gates must never fail on
//! hardware drift); a PRESENT device that misrenders FAILS loudly.

use bash_o4::{fb_draw, fb_frag, shader, vkffi};

fn pin_lavapipe() {
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("BASH_O4_VK_ICD").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }
    if let Ok(icd) = std::env::var("BASH_O4_VK_ICD") {
        std::env::set_var("VK_ICD_FILENAMES", icd);
    }
}

const W: u32 = 64;
const H: u32 = 64;
const ATLAS_LAYERS: u32 = 10;
const ATLAS_SIZE: u32 = 4;

/// 10 layers of 4×4 RGBA8: layers 0–8 solid mid-grey (128 — so
/// `tr*tex/128` is the identity and the tint path is pinned exactly),
/// layer 9 (crack) solid with alpha 0 (damage = 0 in this scene, so
/// the crack path stays off but the layer exists per the contract).
fn test_atlas() -> Vec<u8> {
    let mut v = Vec::with_capacity((ATLAS_LAYERS * ATLAS_SIZE * ATLAS_SIZE * 4) as usize);
    for layer in 0..ATLAS_LAYERS {
        for _ in 0..(ATLAS_SIZE * ATLAS_SIZE) {
            if layer == 9 {
                v.extend_from_slice(&[200, 100, 50, 0]);
            } else {
                v.extend_from_slice(&[128, 128, 128, 255]);
            }
        }
    }
    v
}

/// Camera at the origin, yaw 0, no shift, 64×64 view, no effects.
fn test_push() -> fb_draw::PushConstants {
    fb_draw::PushConstants {
        cam0: [0.0, 0.0, 0.0, 1.0],
        cam1: [0.0, 0.0, W as f32, H as f32],
        cfg: [0, 0, 0, 0],
    }
}

/// One red cube at (0, 0.5, 2), scale 2000 (milli): world x∈[-1,1],
/// y∈[-0.5,1.5], z∈[1,3]. Front face fills ~44×29 px around (32,32).
/// CubeRec (x,y,z,sx)(sy,sz,r,g)(b,tx,dam,pad).
fn red_cube() -> Vec<f32> {
    vec![
        0.0, 0.5, 2.0, 2000.0, 2000.0, 2000.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    ]
}

/// Full-screen opaque green quad (fractions: centre 0,0 extent 2,2).
/// OvRec (cx,cy,wfrac,hfrac)(r,g,b,a)(rot,0,0,0).
fn green_quad() -> Vec<f32> {
    vec![0.0, 0.0, 2.0, 2.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
}

/// `frag_pixel` transcribed (fbdev.c:278): grey-128 atlas, red tint,
/// shade 1000, no damage, no CRT, no corrupt. `tr*tex/128` with
/// tex = 128 is the identity, so the oracle is exact.
fn oracle_frag_pixel(tr: i32, tg: i32, tb: i32, shade: i32) -> (i32, i32, i32) {
    let (mut tr, mut tg, mut tb) = (tr * shade / 1000, tg * shade / 1000, tb * shade / 1000);
    tr = tr.clamp(0, 255);
    tg = tg.clamp(0, 255);
    tb = tb.clamp(0, 255);
    (tr * 128 / 128, tg * 128 / 128, tb * 128 / 128)
}

fn px(pixels: &[u8], x: u32, y: u32) -> (u8, u8, u8, u8) {
    let o = ((y * W + x) * 4) as usize;
    (pixels[o], pixels[o + 1], pixels[o + 2], pixels[o + 3])
}

fn compile_pair(
    cc: &std::path::Path,
    dir: &std::path::Path,
    vert_glsl: &str,
    frag_glsl: &str,
    tag: &str,
) -> (Vec<u8>, Vec<u8>) {
    let v = fb_frag::compile_stage(cc, vert_glsl, dir, "vert").expect("vertex SPIR-V");
    let f = fb_frag::compile_stage(cc, frag_glsl, dir, "frag").expect("fragment SPIR-V");
    assert!(v.len() > 4 && f.len() > 4, "{tag}: empty SPIR-V");
    (v, f)
}

#[test]
fn blocks_dispatch_matches_oracle() {
    pin_lavapipe();
    if !vkffi::has_compute_device() {
        eprintln!("SKIP blocks_dispatch_matches_oracle: no Vulkan device");
        return;
    }
    if !vkffi::has_compute_device() {
        eprintln!("SKIP blocks_dispatch_matches_oracle: pinned ICD has no device");
        return;
    }
    let root = std::env::temp_dir().join(format!("bo4fb{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let cc = shader::find_spirv_compiler(&root).expect("dispatch needs glslangValidator");

    let (v_spv, f_spv) = compile_pair(
        &cc,
        &root,
        &fb_frag::blocks_vertex(),
        &fb_frag::blocks_fragment(),
        "blocks",
    );
    let mut runner = fb_draw::RasterRunner::new(W, H).expect("raster runner");
    let (_img, view) = runner
        .upload_atlas(&test_atlas(), ATLAS_LAYERS, ATLAS_SIZE)
        .expect("atlas upload");
    runner
        .draw_blocks(&v_spv, &f_spv, &red_cube(), &test_push(), view)
        .expect("blocks dispatch");
    let pixels = runner.readback().expect("readback");
    assert_eq!(pixels.len(), (W * H * 4) as usize);

    // Centre (32,32): inside the front face. Red tint (255,0,0);
    // the camera-facing (+z, near) face carries shade 800, so the
    // oracle value is 255*800/1000 = 204, g = b = 0.
    let (r, g, b, a) = px(&pixels, 32, 32);
    assert_eq!(a, 255, "opaque framebuffer alpha");
    let (er, eg, eb) = oracle_frag_pixel(255, 0, 0, 800);
    assert_eq!(
        (r, g, b),
        (er as u8, eg as u8, eb as u8),
        "centre pixel is exactly the CPU oracle"
    );
    // Corner (0,0): outside the cube — the CLEAR colour (0,0,0,1).
    assert_eq!(
        px(&pixels, 0, 0),
        (0, 0, 0, 255),
        "clear colour outside the cube"
    );
    assert_eq!(px(&pixels, W - 1, H - 1), (0, 0, 0, 255));

    // Determinism: a second identical dispatch reads back identical.
    runner
        .draw_blocks(&v_spv, &f_spv, &red_cube(), &test_push(), view)
        .expect("blocks dispatch again");
    let pixels2 = runner.readback().expect("readback again");
    assert_eq!(pixels, pixels2, "dispatch is deterministic");

    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn overlay_dispatch_blends_over_blocks() {
    // pin FIRST: has_compute_device creates + destroys a probe
    // instance, and two lavapipe instances in one process segfault
    // on teardown (same destroy-order class as the runner Drop).
    pin_lavapipe();
    if !vkffi::has_compute_device() {
        eprintln!("SKIP overlay_dispatch_blends_over_blocks: no Vulkan device");
        return;
    }
    if !vkffi::has_compute_device() {
        eprintln!("SKIP overlay_dispatch_blends_over_blocks: pinned ICD has no device");
        return;
    }
    let root = std::env::temp_dir().join(format!("bo4fbo{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let cc = shader::find_spirv_compiler(&root).expect("dispatch needs glslangValidator");

    let (bv, bf) = compile_pair(
        &cc,
        &root,
        &fb_frag::blocks_vertex(),
        &fb_frag::blocks_fragment(),
        "blocks",
    );
    let (ov, of_) = compile_pair(
        &cc,
        &root,
        &fb_frag::overlay_vertex(),
        &fb_frag::overlay_fragment(),
        "overlay",
    );
    let mut runner = fb_draw::RasterRunner::new(W, H).expect("raster runner");
    let (_img, view) = runner
        .upload_atlas(&test_atlas(), ATLAS_LAYERS, ATLAS_SIZE)
        .expect("atlas upload");
    runner
        .draw_blocks(&bv, &bf, &red_cube(), &test_push(), view)
        .expect("blocks dispatch");
    runner
        .draw_overlay(&ov, &of_, &green_quad(), &test_push(), view)
        .expect("overlay dispatch");
    let pixels = runner.readback().expect("readback");

    // Opaque green quad covers everything: every pixel is (0,255,0).
    for (x, y) in [(0, 0), (32, 32), (W - 1, H - 1), (5, 60)] {
        assert_eq!(
            px(&pixels, x, y),
            (0, 255, 0, 255),
            "opaque green at ({x},{y})"
        );
    }

    let _ = std::fs::remove_dir_all(&root);
}
