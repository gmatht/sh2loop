//! C-ABI FFI for the fb0 Vulkan host path (Phase 2).
//!
//! Loaded by the compiled C runtime (`fbdev.c`, materialized from
//! `sh2perl/runtime/`) via dlopen when GPU dispatch is explicitly enabled.
//! Default/`--cpu-only` paths never require this library. Every entry
//! point is capability-checked and fails closed (returns an error / CPU
//! fallback signal) — never guesses, never silently narrows precision.
//!
//! The compiled C binary links `fbdev.c`; the Vulkan host is Rust
//! (`fb_draw`/`vkffi`/`fb_frag`). This C-ABI boundary is the Phase 2
//! unblocker for driving that host from the standalone runtime.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::Mutex;

use crate::fb_draw::{PushConstants, RasterRunner};
use crate::vkffi;

/// Deterministic embedded SPIR-V (runtime path): precompiled from the canonical
/// fb_frag GLSL sources (raw `glslangValidator -V`, see src/fb_spv/manifest.json),
/// content-hashed and committed. No runtime compiler/temp dir — stable, cached in
/// the binary. Refuse > guess if loading fails (impossible for embedded bytes).
mod fb_spv {
    pub const BLOCKS_VERT: &[u8] = include_bytes!("fb_spv/blocks.vert.spv");
    pub const BLOCKS_FRAG: &[u8] = include_bytes!("fb_spv/blocks.frag.spv");
    pub const OVERLAY_VERT: &[u8] = include_bytes!("fb_spv/overlay.vert.spv");
    pub const OVERLAY_FRAG: &[u8] = include_bytes!("fb_spv/overlay.frag.spv");
}

struct GpuState {
    runner: RasterRunner,
    width: u32,
    height: u32,
    atlas_img: u64,
    atlas_mem: u64,
    atlas_view: u64,
    // Deterministic embedded SPIR-V (cached in binary; no runtime compile).
    bv: &'static [u8],
    bf: &'static [u8],
    ov: &'static [u8],
    of_: &'static [u8],
    last_err: CString,
}

static ERR: Mutex<Option<CString>> = Mutex::new(None);

fn set_err(msg: impl Into<String>) {
    let s = msg.into();
    if let Ok(mut g) = ERR.lock() {
        *g = CString::new(s.replace('\0', "")).ok();
    }
}

fn state_err(st: &mut GpuState, msg: impl Into<String>) {
    let s = msg.into();
    st.last_err = CString::new(s.replace('\0', "")).unwrap_or_else(|_| CString::new("gpu error").unwrap());
}

/// 1 if a Vulkan GRAPHICS-capable device is detectable (runtime capability
/// probe for the fb0 raster path), else 0. Cheap probe; no runner created.
/// Veto (refuse > guess) => caller takes the exact CPU path.
#[no_mangle]
pub extern "C" fn bash_o4_fb_gpu_available() -> c_int {
    if vkffi::has_graphics_device() { 1 } else { 0 }
}

/// Copy the last error string into `buf` (NUL-terminated, truncated). Returns
/// bytes written excluding NUL, or 0 if none.
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_last_error(buf: *mut c_char, len: usize) -> c_int {
    if buf.is_null() || len == 0 {
        return 0;
    }
    let msg = ERR.lock().ok().and_then(|g| g.clone());
    let bytes = msg.as_ref().map(|c| c.as_bytes()).unwrap_or(b"");
    let n = bytes.len().min(len.saturating_sub(1));
    ptr::copy_nonoverlapping(bytes.as_ptr(), buf as *mut u8, n);
    *buf.add(n) = 0;
    n as c_int
}

fn embedded_shaders() -> (&'static [u8], &'static [u8], &'static [u8], &'static [u8]) {
    (fb_spv::BLOCKS_VERT, fb_spv::BLOCKS_FRAG, fb_spv::OVERLAY_VERT, fb_spv::OVERLAY_FRAG)
}

/// The host quad the generated stage pair draws, as the bridge sees it.
/// `stage_ref` derives the pair's CPU reference from these same numbers,
/// so the reference and the dispatch cannot describe different quads.
pub(crate) const STAGE_QUAD_POS: [[f64; 2]; 4] = [
    [-1.0, -1.0],
    [1.0, -1.0],
    [1.0, 1.0],
    [-1.0, 1.0],
];
pub(crate) const STAGE_QUAD_UV: [[f64; 2]; 4] = [
    [0.0, 0.0],
    [1.0, 0.0],
    [1.0, 1.0],
    [0.0, 1.0],
];
pub(crate) const STAGE_QUAD_SHADE: f64 = 1.0;
pub(crate) const STAGE_QUAD_UNIFORM_OBJ_POS: f64 = 0.0;
pub(crate) const STAGE_QUAD_UNIFORM_SCALE: f64 = 1.0;
pub(crate) const STAGE_QUAD_UNIFORM_BLOCK_COLOR: f64 = 1.0;

pub(crate) fn grey_atlas() -> (Vec<u8>, u32, u32) {
    // Deterministic default atlas (matches --fb-proof): 10 layers, 4x4,
    // grey 128 identity + crack layer 9. Real texture upload can be added
    // once slot-mapping parity is proven.
    let mut atlas = Vec::with_capacity(10 * 4 * 4 * 4);
    for layer in 0..10u32 {
        for _ in 0..16 {
            if layer == 9 {
                atlas.extend_from_slice(&[200, 100, 50, 0]);
            } else {
                atlas.extend_from_slice(&[128, 128, 128, 255]);
            }
        }
    }
    (atlas, 10, 4)
}

/// Open a GPU raster runner for `w`×`h`. Returns an opaque handle or null on
/// failure (capability/init/SPIR-V error). Default atlas + compiled shaders are
/// installed; callers may draw then read back BGRX.
#[no_mangle]
pub extern "C" fn bash_o4_fb_gpu_open(w: c_int, h: c_int) -> *mut c_void {
    let res = catch_unwind(AssertUnwindSafe(|| -> Result<*mut c_void, String> {
        if !(1..=4096).contains(&w) || !(1..=4096).contains(&h) {
            return Err(format!("gpu open: invalid size {w}x{h}"));
        }
        if !vkffi::has_graphics_device() {
            return Err("runtime capability veto: no Vulkan graphics device/queue (fb0 raster needs graphics)".to_string());
        }
        let (bv, bf, ov, of_) = embedded_shaders();
        let mut runner = RasterRunner::new(w as u32, h as u32)?;
        let (atlas, nlayers, size) = grey_atlas();
        let (atlas_img, atlas_mem, atlas_view) = runner.upload_atlas(&atlas, nlayers, size)?;
        let st = Box::new(GpuState {
            runner,
            width: w as u32,
            height: h as u32,
            atlas_img: atlas_img as u64,
            atlas_mem: atlas_mem as u64,
            atlas_view: atlas_view as u64,
            bv,
            bf,
            ov,
            of_,
            last_err: CString::new("").unwrap(),
        });
        Ok(Box::into_raw(st) as *mut c_void)
    }));
    match res {
        Ok(Ok(p)) => p,
        Ok(Err(e)) => {
            set_err(e);
            ptr::null_mut()
        }
        Err(_) => {
            set_err("gpu open panicked");
            ptr::null_mut()
        }
    }
}

/// Close a handle returned by `bash_o4_fb_gpu_open`. Null is a no-op.
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_close(handle: *mut c_void) {
    if handle.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        drop(Box::from_raw(handle as *mut GpuState));
    }));
}

fn mk_push(
    cam_x: f32, cam_y: f32, cam_z: f32, cos_yaw: f32, sin_yaw: f32, shift: f32,
    view_w: f32, view_h: f32, flags: u32,
) -> PushConstants {
    PushConstants {
        cam0: [cam_x, cam_y, cam_z, cos_yaw],
        cam1: [sin_yaw, shift, view_w, view_h],
        cfg: [flags as i32, 0, 0, 0],
    }
}

/// Upload/replace the atlas (real texture data). `rgba` is RGBA8 bytes,
/// length must be `nlayers*size*size*4`. Stable layer mapping: slot == layer,
/// crack is layer 9 (fbdev.c CRACK_TEX). Uniform `size` across layers.
/// Returns 0 on success, nonzero on error (caller keeps prior atlas / falls back).
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_upload_atlas(
    handle: *mut c_void, rgba: *const u8, rgba_len: usize, nlayers: u32, size: u32,
) -> c_int {
    if handle.is_null() || rgba.is_null() {
        set_err("upload_atlas: null");
        return -1;
    }
    let res = catch_unwind(AssertUnwindSafe(|| -> Result<(), String> {
        let want = (nlayers as usize) * (size as usize) * (size as usize) * 4;
        if rgba_len != want {
            return Err(format!("upload_atlas: len {rgba_len} != {nlayers}x{size}x{size}x4={want}"));
        }
        if !(1..=10_000).contains(&nlayers) || !(1..=256).contains(&size) {
            return Err(format!("upload_atlas: bad nlayers/size {nlayers}/{size}"));
        }
        let bytes = std::slice::from_raw_parts(rgba, want);
        let st = &mut *(handle as *mut GpuState);
        let (img, mem, view) = st.runner.upload_atlas(bytes, nlayers, size)?;
        let old_img = st.atlas_img;
        let old_mem = st.atlas_mem;
        let old_view = st.atlas_view;
        st.atlas_img = img as u64;
        st.atlas_mem = mem as u64;
        st.atlas_view = view as u64;
        st.runner.release_atlas(old_img as _, old_mem as _, old_view as _);
        Ok(())
    }));
    match res {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            let st = &mut *(handle as *mut GpuState);
            state_err(st, e.clone());
            set_err(e);
            -1
        }
        Err(_) => { set_err("upload_atlas panicked"); -1 }
    }
}

/// Parse `fb_blocks` text payload (11 whitespace-separated fields per line:
/// x y z sx sy sz r g b tx dam) into packed CubeRec words (12 f32 each:
/// x,y,z,sx, sy,sz,r,g, b,tx,dam,pad). Render-time verdict: malformed lines
/// are refused (caller must CPU-fallback the frame) rather than guessed.
///
/// UNITS: the payload's scale is in WORLD UNITS (1 = a full block); the
/// vertex stage takes MILLI (`corner.x * sc.x / 1000000.0`, matching
/// `usc_*`). fbdev converts once, at the same boundary —
/// `draw_cube(v[0], v[1], v[2], v[3] * 1000.0, …)` in fbdev.c — and this
/// parser must do the same. It did not, so every payload drawn through
/// the GPU path was 1000x too small: the second witness (scale 1) rendered
/// ZERO pixels on the GPU while the CPU drew its cubes, which is what the
/// parity gate was reporting.
fn parse_blocks_payload(payload: *const c_char) -> Result<Vec<f32>, String> {
    if payload.is_null() {
        return Err("blocks payload null".to_string());
    }
    let s = unsafe { CStr::from_ptr(payload) }
        .to_str()
        .map_err(|_| "blocks payload not utf-8".to_string())?;
    let mut out: Vec<f32> = Vec::new();
    for (ln, line) in s.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let mut it = line.split_whitespace();
        let mut v = [0f64; 11];
        let mut n = 0usize;
        for slot in &mut v {
            let Some(tok) = it.next() else { break };
            *slot = tok
                .parse::<f64>()
                .map_err(|e| format!("blocks line {ln}: bad field {tok:?}: {e}"))?;
            n += 1;
        }
        if n != 11 || it.next().is_some() {
            return Err(format!("blocks line {ln}: expected 11 fields, got !=11"));
        }
        // CubeRec (12 f32): (x,y,z,sx)(sy,sz,r,g)(b,tx,dam,pad)
        // scale world units -> milli, exactly as fbdev.c's fb_blocks does.
        out.push(v[0] as f32); out.push(v[1] as f32); out.push(v[2] as f32);
        out.push((v[3] * 1000.0) as f32);
        out.push((v[4] * 1000.0) as f32); out.push((v[5] * 1000.0) as f32);
        out.push(v[6] as f32); out.push(v[7] as f32);
        out.push(v[8] as f32); out.push(v[9] as f32); out.push(v[10] as f32); out.push(0.0f32);
    }
    Ok(out)
}

/// fbdev's payload convention is **-z-forward**: the eye sits at `cam_z` and
/// looks toward decreasing z (`to_view` keeps `w = dx*sin - dz*cos = -rel.z`
/// as the depth). The graphics pipeline's vertex stage is **+z-forward**
/// (`w = rel.z`; the convention of `tests/fb_dispatch.rs` and `--fb-proof`,
/// and the one baked into the byte-pinned SPIR-V in `src/fb_spv/`).
///
/// This adapter therefore reflects the whole scene through the origin in the
/// xz plane — camera x/z and every record's x/z, plus the camera shift — which
/// is an exact isometry: depth stays monotone in distance, the same surfaces
/// stay in front, and the rendered image is the point reflection (both axes
/// mirrored) of the CPU frame. `readback_bgrx` un-mirrors it, so a caller gets
/// the CPU-oriented, top-down frame and a byte comparison against fbdev is
/// meaningful.
///
/// Doing it here rather than in the shader is deliberate: the SPIR-V is
/// precompiled and content-pinned (`src/fb_spv/manifest.json`) and this box has
/// no SPIR-V compiler, so a source-only shader edit would make the GLSL
/// disagree with the bytes that actually execute.
fn reflect_scene(records: &mut [f32], cam_x: &mut f32, cam_z: &mut f32, shift: &mut f32) {
    *cam_x = -*cam_x;
    *cam_z = -*cam_z;
    *shift = -*shift;
    for rec in records.chunks_exact_mut(12) {
        rec[0] = -rec[0]; // x
        rec[2] = -rec[2]; // z
    }
}

/// Draw parsed `fb_blocks` payload. Returns 0 on success (GPU frame ready for
/// readback into the host buffer), nonzero on any error/capability/refusal —
/// caller MUST fall back to CPU for correctness (never guess). Camera/flags are
/// the host's current state (from `fb_set_camera`/`fb_frag_flags` globals).
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_draw_blocks_text(
    handle: *mut c_void,
    payload: *const c_char,
    cam_x: f32, cam_y: f32, cam_z: f32, cos_yaw: f32, sin_yaw: f32, shift: f32,
    view_w: f32, view_h: f32, flags: u32,
) -> c_int {
    if handle.is_null() {
        set_err("draw_blocks: null handle");
        return -1;
    }
    let res = catch_unwind(AssertUnwindSafe(|| -> Result<(), String> {
        let st = &mut *(handle as *mut GpuState);
        let mut records = parse_blocks_payload(payload)?;
        if records.is_empty() {
            // Empty payload is valid (nothing drawn); clear-equivalent not
            // implied here — host decides. Refuse to guess scene state.
            return Err("blocks: empty payload (refused)".to_string());
        }
        let (mut cx, mut cz, mut sh) = (cam_x, cam_z, shift);
        reflect_scene(&mut records, &mut cx, &mut cz, &mut sh);
        let push = mk_push(cx, cam_y, cz, cos_yaw, sin_yaw, sh, view_w, view_h, flags);
        st.runner
            .draw_blocks(&st.bv, &st.bf, &records, &push, st.atlas_view)
    }));
    match res {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            let st = &mut *(handle as *mut GpuState);
            state_err(st, e.clone());
            set_err(e);
            -1
        }
        Err(_) => {
            set_err("draw_blocks panicked");
            -1
        }
    }
}

/// Read back the current color image into `out` as **BGRX** bytes (B,G,R,255
/// per pixel, row-major, top-down), length must be >= w*h*4. Returns 0 on
/// success, nonzero on error (caller must CPU-fallback / not use output).
///
/// Both axes are mirrored here: the scene arrived through `reflect_scene`'s
/// point reflection and the vertex stage writes up-positive y into Vulkan's
/// down-positive NDC, so the target is the 180°-rotated image. Undoing exactly
/// that rotation is what makes the output comparable to fbdev's surface, pixel
/// for pixel (no sampling, no interpolation — an index permutation).
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_readback_bgrx(
    handle: *mut c_void, out: *mut u8, out_len: usize,
) -> c_int {
    if handle.is_null() || out.is_null() {
        set_err("readback: null");
        return -1;
    }
    let res = catch_unwind(AssertUnwindSafe(|| -> Result<(), String> {
        let st = &mut *(handle as *mut GpuState);
        let need = (st.width as usize) * (st.height as usize) * 4;
        if out_len < need {
            return Err(format!("readback: out_len {out_len} < {need}"));
        }
        let rgba = st.runner.readback()?;
        let bgrx = RasterRunner::rgba8_to_bgrx(&rgba);
        {
            let (w, h) = (st.width as usize, st.height as usize);
            for y in 0..h {
                for x in 0..w {
                    let src = ((h - 1 - y) * w + (w - 1 - x)) * 4;
                    let dst = (y * w + x) * 4;
                    ptr::copy_nonoverlapping(bgrx.as_ptr().add(src), out.add(dst), 4);
                }
            }
        }
        Ok(())
    }));
    match res {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            let st = &mut *(handle as *mut GpuState);
            state_err(st, e.clone());
            set_err(e);
            -1
        }
        Err(_) => {
            set_err("readback panicked");
            -1
        }
    }
}

/// Render a screen-aligned quad through a **generated** stage pair whose
/// SPIR-V the compiler embedded in the calling C. The pair is compiled at
/// build time from the lift's bound shaders (never hand-written here), so
/// this entry point only supplies the vertex stream and push constants the
/// bridge contract defines. Returns 0 on a real dispatch, -1 otherwise.
#[no_mangle]
pub unsafe extern "C" fn bash_o4_fb_gpu_draw_stages_spv(
    handle: *mut c_void,
    vspv: *const u8,
    vlen: usize,
    fspv: *const u8,
    flen: usize,
) -> c_int {
    if handle.is_null() || vspv.is_null() || fspv.is_null() || vlen < 4 || flen < 4 {
        set_err("draw_stages: null/empty stage SPIR-V");
        return -1;
    }
    let res = catch_unwind(AssertUnwindSafe(|| -> Result<(), String> {
        let st = &mut *(handle as *mut GpuState);
        let v = std::slice::from_raw_parts(vspv, vlen);
        let f = std::slice::from_raw_parts(fspv, flen);
        // One screen-aligned quad, aPosition/aShade/aUv (8 f32 per
        // vertex), built from the constants `stage_ref` derives the CPU
        // reference from — one source for both halves of the comparison.
        let mut verts: Vec<f32> = Vec::with_capacity(48);
        for i in [0usize, 1, 2, 0, 2, 3] {
            let p = STAGE_QUAD_POS[i];
            let uv = STAGE_QUAD_UV[i];
            verts.extend_from_slice(&[
                p[0] as f32,
                p[1] as f32,
                0.0,
                STAGE_QUAD_SHADE as f32,
                STAGE_QUAD_SHADE as f32,
                STAGE_QUAD_SHADE as f32,
                uv[0] as f32,
                uv[1] as f32,
            ]);
        }
        let mut push = crate::fb_draw::PushConstants {
            cam0: [0.0; 4],
            cam1: [0.0; 4],
            cfg: [0; 4],
        };
        // uObjPos/uScale/uBlockColor in world units; the generated vertex
        // stage applies fbdev's milli conversion itself.
        let raw = &mut push as *mut crate::fb_draw::PushConstants as *mut f32;
        let (op, sc, bc) = (
            STAGE_QUAD_UNIFORM_OBJ_POS as f32,
            STAGE_QUAD_UNIFORM_SCALE as f32,
            STAGE_QUAD_UNIFORM_BLOCK_COLOR as f32,
        );
        for (i, w) in [op, op, op, sc, sc, sc, bc, bc, bc].iter().enumerate() {
            *raw.add(i) = *w;
        }
        // INTO the frame, not instead of it: a stage split is one more
        // draw in the frame the blocks pass already started.
        st.runner.draw_stages_over(v, f, &verts, &push, st.atlas_view)
    }));
    match res {
        Ok(Ok(())) => 0,
        Ok(Err(e)) => {
            set_err(&e);
            -1
        }
        Err(_) => {
            set_err("draw_stages panicked");
            -1
        }
    }
}
