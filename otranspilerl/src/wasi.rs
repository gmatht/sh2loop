//! C-ABI exports for otranspilerl (the WASM / any-embedder library ABI).
//!
//! Same memory contract as `debashl::wasi_api`: every `otranspilerl_*`
//! string export returns a pointer into linear memory at a NUL-terminated
//! UTF-8 buffer laid out as `[u32 data_len LE][data][0]` (the returned
//! pointer points at `data`; `otranspilerl_str_len` / `otranspilerl_free`
//! manage it). Inputs are written into memory obtained from
//! `otranspilerl_alloc`. Results are JSON envelopes so any consumer can
//! parse them:
//!
//! ```json
//! {"ok":true,"output":"..."}   /   {"ok":false,"error":"..."}
//! ```
//!
//! The full in-process path — shell source → A1 → any of the nine backend
//! renderers — is available. The non-shell *frontends* (py/c/pl/zsh/fish/
//! go → A1) and the `--run` node exec require a process-spawning host and
//! return a clear error here; feed those through `otranspilerl_render`
//! with the frontend's A1 JSON instead.

use std::alloc::{alloc, dealloc, Layout};
use std::path::PathBuf;
use std::ptr::null_mut;
use std::slice;

/// Allocate a `[u32 len][data][0]` buffer and return a pointer to `data`.
fn alloc_string(s: &str) -> *mut u8 {
    let bytes = s.as_bytes();
    let n = bytes.len();
    let total = 4 + n + 1;
    let layout = Layout::from_size_align(total, 4).expect("valid layout");
    // Safety: total >= 5 so `alloc` is well-defined; the layout here
    // exactly matches the one reconstructed in `otranspilerl_free`.
    let ptr = unsafe { alloc(layout) };
    if ptr.is_null() {
        return null_mut();
    }
    unsafe {
        *(ptr as *mut u32) = (n as u32).to_le();
        ptr.add(4).copy_from_nonoverlapping(bytes.as_ptr(), n);
        *ptr.add(4 + n) = 0;
        ptr.add(4)
    }
}

fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn ok_json(output: &str) -> String {
    format!(r#"{{"ok":true,"output":{}}}"#, json_escape(output))
}

fn err_json(e: &str) -> String {
    format!(r#"{{"ok":false,"error":{}}}"#, json_escape(e))
}

fn take_input(ptr: *const u8, len: usize) -> String {
    if ptr.is_null() || len == 0 {
        return String::new();
    }
    // Safety: the caller passes a valid pointer/length pair.
    let bytes = unsafe { slice::from_raw_parts(ptr, len) };
    String::from_utf8_lossy(bytes).into_owned()
}

/// Reactor entry point: runtimes that require it (e.g. Node's `node:wasi`)
/// call `_initialize` once before allowing wasi imports to be used.
#[no_mangle]
pub extern "C" fn _initialize() {}

/// `otranspilerl_alloc(len) -> *mut u8` — reserve `len` payload bytes in
/// linear memory as a `[u32 len][data][0]` buffer for the embedder to fill
/// (input strings, CLI args). Free with `otranspilerl_free`.
#[no_mangle]
pub extern "C" fn otranspilerl_alloc(len: usize) -> *mut u8 {
    if len == 0 {
        return null_mut();
    }
    let total = 4 + len + 1;
    let layout = Layout::from_size_align(total, 4).expect("valid layout");
    // Safety: same layout contract as alloc_string/otranspilerl_free.
    let ptr = unsafe { alloc(layout) };
    if ptr.is_null() {
        return null_mut();
    }
    unsafe {
        *(ptr as *mut u32) = (len as u32).to_le();
        *ptr.add(4 + len) = 0;
        ptr.add(4)
    }
}

/// `otranspilerl_version() -> *mut u8` — `"otranspilerl <version>"`.
#[no_mangle]
pub extern "C" fn otranspilerl_version() -> *mut u8 {
    alloc_string(&ok_json(&format!("otranspilerl {}", crate::VERSION)))
}

/// `otranspilerl_shir(input, input_len)` — shell source → neutral A1 shIR
/// JSON (the `--shir` path, in-process).
#[no_mangle]
pub extern "C" fn otranspilerl_shir(input: *const u8, input_len: usize) -> *mut u8 {
    let input = take_input(input, input_len);
    alloc_string(&ok_json(&crate::shell_to_shir(&input)))
}

/// `otranspilerl_render(a1, a1_len, lang, lang_len)` — A1 shIR JSON →
/// target source, in-process. `lang` is the bare target name.
#[no_mangle]
pub extern "C" fn otranspilerl_render(
    a1: *const u8,
    a1_len: usize,
    lang: *const u8,
    lang_len: usize,
) -> *mut u8 {
    let a1 = take_input(a1, a1_len);
    let lang = take_input(lang, lang_len);
    match crate::render(&a1, &lang) {
        Ok(out) => alloc_string(&ok_json(&out)),
        Err(e) => alloc_string(&err_json(&e)),
    }
}

/// `otranspilerl_transpile(input, input_len, src_lang, src_lang_len,
/// tgt_lang, tgt_lang_len)` — shell (or A1) source → target source. Only
/// the in-process languages (`sh`, `shir`) are wired here; the others
/// need the frontend process spawn.
#[no_mangle]
pub extern "C" fn otranspilerl_transpile(
    input: *const u8,
    input_len: usize,
    src_lang: *const u8,
    src_lang_len: usize,
    tgt_lang: *const u8,
    tgt_lang_len: usize,
) -> *mut u8 {
    let input = take_input(input, input_len);
    let src_lang = take_input(src_lang, src_lang_len);
    let tgt_lang = take_input(tgt_lang, tgt_lang_len);
    match src_lang.as_str() {
        "shir" => match crate::render(&input, &tgt_lang) {
            Ok(out) => alloc_string(&ok_json(&out)),
            Err(e) => alloc_string(&err_json(&e)),
        },
        "sh" | "" => {
            let a1 = crate::shell_to_shir(&input);
            match crate::render(&a1, &tgt_lang) {
                Ok(out) => alloc_string(&ok_json(&out)),
                Err(e) => alloc_string(&err_json(&e)),
            }
        }
        other => alloc_string(&err_json(&format!(
            "source language {other:?} requires the frontend process spawn, \
             not available in this build; feed the frontend's A1 JSON via \
             otranspilerl_render"
        ))),
    }
}

/// `otranspilerl_glsl(input, input_len)` — shell → **GLSL ES 1.00 render
/// fragment** (the MIMEcroft shader pipeline): the bash program becomes a
/// fragment shader with the frag_x/frag_y/vcolor/uv/tex/crack bridges
/// (debashl::glsl_backend), so the browser compiles bash-authored
/// shaders in-process — the `sh2glsl` command in the shell.
#[no_mangle]
pub extern "C" fn otranspilerl_glsl(input: *const u8, input_len: usize) -> *mut u8 {
    let input = take_input(input, input_len);
    match debashl::Parser::new(&input).parse() {
        Ok(commands) => {
            let prog = debashl::shir::ast_to_ir_raw(&commands);
            let glsl = debashl::glsl_backend::shir_to_glsl_opts(
                &prog,
                &debashl::glsl_backend::ShGlslOptions {
                    es100: true,
                color_out: true,
                vert_out: false,
                tex_size: 16,
                max_view: 800,
            },
            );
            alloc_string(&ok_json(&glsl))
        }
        Err(e) => alloc_string(&err_json(&format!("{e}"))),
    }
}

/// `otranspilerl_glslv(input, input_len)` — shell → **GLSL ES 1.00 render
/// VERTEX shader** (the other half of the MIMEcroft pipeline): the bash
/// program becomes a vertex shader with the ap_*/ash_*/auv_*/ucp_*/
/// ucy_*/uop_*/usc_*/ublk_*/uov input bridges and the vp_*/vc_*/vu_*
/// outputs — `sh2glsl --vertex` in the shell.
#[no_mangle]
pub extern "C" fn otranspilerl_glslv(input: *const u8, input_len: usize) -> *mut u8 {
    let input = take_input(input, input_len);
    match debashl::Parser::new(&input).parse() {
        Ok(commands) => {
            let prog = debashl::shir::ast_to_ir_raw(&commands);
            let glsl = debashl::glsl_backend::shir_to_glsl_opts(
                &prog,
                &debashl::glsl_backend::ShGlslOptions {
                    es100: true,
                    color_out: false,
                    vert_out: true,
                    tex_size: 16,
                    max_view: 800, // the sh2runtime device canvas is 800×600
                },
            );
            alloc_string(&ok_json(&glsl))
        }
        Err(e) => alloc_string(&err_json(&format!("{e}"))),
    }
}

/// `otranspilerl_cli(args, args_len)` — the full CLI, args newline-joined.
/// Returns `{"exit":N,"output":"...","stderr":"..."}`. File I/O follows
/// WASI preopens; frontends/`--run` need a process-spawning host.
#[no_mangle]
pub extern "C" fn otranspilerl_cli(args: *const u8, args_len: usize) -> *mut u8 {
    let args = take_input(args, args_len);
    let args: Vec<String> = if args.is_empty() {
        Vec::new()
    } else {
        args.split('\n').map(|s| s.to_string()).collect()
    };
    let root = crate::workspace_root()
        .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")));
    let (code, out, err) = crate::cli_captured(&root, &args);
    let body = format!(
        r#"{{"exit":{code},"output":{},"stderr":{}}}"#,
        json_escape(&out),
        json_escape(&err)
    );
    alloc_string(&body)
}

/// `otranspilerl_str_len(ptr) -> u32` — payload length in bytes (excludes NUL).
#[no_mangle]
pub extern "C" fn otranspilerl_str_len(ptr: *const u8) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    // Safety: `ptr` came from `otranspilerl_*` → the u32 prefix is present.
    unsafe { u32::from_le(*(ptr.sub(4) as *const u32)) }
}

/// `otranspilerl_free(ptr)` — release a buffer returned by an export.
#[no_mangle]
pub extern "C" fn otranspilerl_free(ptr: *mut u8) {
    if ptr.is_null() {
        return;
    }
    // Safety: `ptr` came from `otranspilerl_*` → same layout as `alloc_string`.
    unsafe {
        let n = u32::from_le(*(ptr.sub(4) as *const u32)) as usize;
        let total = 4 + n + 1;
        let layout = Layout::from_size_align(total, 4).expect("valid layout");
        dealloc(ptr.sub(4), layout);
    }
}
