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
use crate::shader;
use crate::vkffi;

struct GpuState {
    runner: RasterRunner,
    width: u32,
    height: u32,
    atlas_view: crate::fb_draw::VkImageView,
    // SPIR-V cached once (deterministic for fixed GLSL sources).
    bv: Vec<u8>,
    bf: Vec<u8>,
    ov: Vec<u8>,
    of_: Vec<u8>,
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

/// 1 if a Vulkan compute-capable device is detectable, else 0. Cheap probe;
/// does not create a runner.
#[no_mangle]
pub extern "C" fn bash_o4_fb_gpu_available() -> c_int {
    if vkffi::has_compute_device() { 1 } else { 0 }
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

fn build_shaders() -> Result<(Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>), String> {
    let cache_root = crate::cache::cache_root(None);
    let dir = std::env::temp_dir().join(format!("bo4gpu{}", std::process::id()));
    let _ = std::fs::create_dir_all(&dir);
    let cc = shader::find_spirv_compiler(&cache_root)
        .ok_or_else(|| "no SPIR-V compiler (need glslangValidator)".to_string())?;
    let bv = crate::fb_frag::compile_stage(&cc, &crate::fb_frag::blocks_vertex(), &dir, "vert")?;
    let bf = crate::fb_frag::compile_stage(&cc, &crate::fb_frag::blocks_fragment(), &dir, "frag")?;
    let ov = crate::fb_frag::compile_stage(&cc, &crate::fb_frag::overlay_vertex(), &dir, "vert")?;
    let of_ = crate::fb_frag::compile_stage(&cc, &crate::fb_frag::overlay_fragment(), &dir, "frag")?;
    let _ = std::fs::remove_dir_all(&dir);
    Ok((bv, bf, ov, of_))
}

fn grey_atlas() -> (Vec<u8>, u32, u32) {
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
        if !vkffi::has_compute_device() {
            return Err("no Vulkan device".to_string());
        }
        let (bv, bf, ov, of_) = build_shaders()?;
        let mut runner = RasterRunner::new(w as u32, h as u32)?;
        let (atlas, nlayers, size) = grey_atlas();
        let (_img, atlas_view) = runner.upload_atlas(&atlas, nlayers, size)?;
        let st = Box::new(GpuState {
            runner,
            width: w as u32,
            height: h as u32,
            atlas_view,
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

/// Parse `fb_blocks` text payload (11 whitespace-separated fields per line:
/// x y z sx sy sz r g b tx dam) into packed CubeRec words (12 f32 each:
/// x,y,z,sx, sy,sz,r,g, b,tx,dam,pad). Render-time verdict: malformed lines
/// are refused (caller must CPU-fallback the frame) rather than guessed.
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
        out.push(v[0] as f32); out.push(v[1] as f32); out.push(v[2] as f32); out.push(v[3] as f32);
        out.push(v[4] as f32); out.push(v[5] as f32); out.push(v[6] as f32); out.push(v[7] as f32);
        out.push(v[8] as f32); out.push(v[9] as f32); out.push(v[10] as f32); out.push(0.0f32);
    }
    Ok(out)
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
        let records = parse_blocks_payload(payload)?;
        if records.is_empty() {
            // Empty payload is valid (nothing drawn); clear-equivalent not
            // implied here — host decides. Refuse to guess scene state.
            return Err("blocks: empty payload (refused)".to_string());
        }
        let push = mk_push(cam_x, cam_y, cam_z, cos_yaw, sin_yaw, shift, view_w, view_h, flags);
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
/// Byte-order contract vs `fbdev.c`/`fbview.py` must be verified for the live
/// `FB0_DEV` path (Phase 2 integration gate).
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
        ptr::copy_nonoverlapping(bgrx.as_ptr(), out, need);
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
