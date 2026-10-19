//! fb_frag — GLSL450 fragment leg for fb0 device writes.
//!
//! ## Need
//!
//! MIMEcroft draws by writing structured text to `/dev/fb0` (the Plan 9
//! model): `echo "$blk_p" > /dev/fb0/blocks` per frame. The `fbdev-gpu`
//! transform family lifts those writes into `GpuOp` nodes, and every
//! backend today renders the node as the original file write — while the
//! real work happens per-pixel in C inside `runtime/fbdev.c`
//! (`frag_pixel`, ~115 ms/frame). This module is the other half of that
//! pipeline: the autoshaderiser step that lowers `GpuOp` verbs onto
//! fragment shaders, so a backend with a GPU leg can dispatch instead of
//! rasterizing on the CPU.
//!
//! ## What it emits (static programs — no per-frame specialization)
//!
//! The payload is runtime data (a `getVar` expression, not text), so the
//! shaders are FIXED programs compiled once; per frame the host uploads
//! the payload bytes plus uniforms and dispatches. Two pipelines:
//!
//! ```text
//! blocks   vertex + fragment   one instance per cube record
//! overlay  vertex + fragment   one instance per HUD rect record
//! ```
//!
//! Verb → artifact map (`call`/`swap` is present — a host op;
//! `depthmask`/`uniform/*` are push-constant slots, not programs;
//! anything else is refused):
//!
//! ```text
//! /dev/fb0/blocks          blocks GLSL pair
//! /dev/fb0/overlay[/flash] overlay GLSL pair
//! /dev/fb0/call            refused (present is host work)
//! /dev/fb0/depthmask       refused (push-constant bit)
//! /dev/fb0/uniform/...     refused (push-constant slot)
//! ```
//!
//! ## Descriptor + push-constant contract (shared with the future host)
//!
//! ```text
//! set 0, binding 0   Blocks SSBO  (readonly CubeRec array)
//! set 0, binding 1   block atlas  (sampler2DArray, game slot = layer)
//! set 0, binding 2   OvRecs SSBO   (readonly, overlay pipeline only)
//! push cam0          xyz, cos(yaw)      (host converts; cf C_cos)
//! push cam1          sin(yaw), shift, view_w, view_h
//! push cfg           flags bit0 crt, bit1 corrupt; spare ×2
//! ```
//!
//! The crack texture is NOT a separate binding: `CRACK_TEX` is layer 9
//! of the same atlas (`fbdev.c` CRACK_TEX), sampled from `atlas`.
//!
//! ## Transcription notes (fbdev.c → GLSL, every deviation documented)
//!
//! - Tables are byte-identical transcriptions: CUBE_P (`:830`),
//!   CUBE_SHADE (`:841`), CUBE_I (`:846`), CUBE_UV (`:204`).
//! - View math mirrors `to_view`/`draw_cube` (`:1379`): milli corner ×
//!   world scale, recenter (eye is `C_y + 0.5`), yaw rotate
//!   (`dx = fx·cos + fz·sin`, `dz = -fx·sin + fz·cos`), project
//!   (`ndcx = x·0.7 + shift·w`, `ndcy = y·0.45`, `w` clamped to
//!   `W_NEAR = 0.01`).
//! - Depth: the device has no depth buffer (painter's algorithm). The
//!   shader writes a standard Vulkan `[0,1]` perspective depth over
//!   `[W_NEAR, DEPTH_FAR]` with the depth test on: identical visible
//!   pixels for opaque (the crack blends in-shader, like the device),
//!   painter order irrelevant. No culling in v1 (depth resolves;
//!   exact GPU culling needs winding verification against an oracle).
//! - `frag_pixel` (`:278`) is ported in INTS: texels are byte-exact
//!   under NEAREST filtering, so int math is bit-exact with the
//!   device — including the overflow bleed (`(508<<16)` keeps
//!   `0xFC0000`, replicated with wrapping `uint` arithmetic).
//! - Float transcription points (verify against the PPM oracle at
//!   integration): tint `r·255+.5` (f32 rounding at `.5` boundaries),
//!   UV interpolation (float vs the device's double lerp at texel
//!   edges), overlay corner rounding (device rounds to int pixels).
//! - Overlay coords are FRACTIONS (post-`fmt_*`), rotated in pixel
//!   space for aspect correctness (`ov_corners`, `:401`:
//!   `ex = px + dx·ca − dy·sa`, `ey = py + dx·sa + dy·ca`); NDC is
//!   `px/W·2−1`, `1−py/H·2` (mirrors `ndc_to_px`, `:392` — y-down).
//!   Erase (`E`) records are host scissor-clears, not shading.
//! - Device y-down vs `gl_FragCoord` y-up: scanline/CRT/vignette math
//!   uses flipped `py = H−1−frag_y` (a same-phase flip would shift the
//!   CRT bands on even-height canvases).
//!
//! ## What stays on the CPU (this does NOT obsolete fbdev.c)
//!
//! Surface lifecycle (`fb_open`/`resize`), display backends (real
//! `/dev/fb0` mmap, X11, RAM+PPM), texture uploads, overlay
//! compositing, presentation pacing, the no-GPU fallback, input and
//! sound all stay host-side — shaders cannot mmap, open windows, or
//! run where there is no GPU (like this box). What migrates is the
//! per-pixel fragment compute. See PLAN.md §11 marketplace notes.

use debashl::ir::{IrExpr, IrProgram, IrStmt};

/// Shared push-constant block (both pipelines) + descriptor contract.
/// `vec4`-packed: foolproof std430 alignment, no padding surprises.
pub fn push_constants_glsl() -> String {
    let mut s = String::new();
    s.push_str(
        r#"// Host contract (shared with the future `_sh_gpu_*` dispatch):
//   set 0, binding 0  Blocks SSBO  (readonly CubeRec array)
//   set 0, binding 1  block atlas   (sampler2DArray, game slot = layer)
//   set 0, binding 2  OvRecs SSBO   (readonly, overlay pipeline only)
//   crack texture = atlas layer 9 (fbdev.c CRACK_TEX).
layout(push_constant) uniform Push {
  vec4 cam0; // xyz, cos(yaw_deg)      (host converts; cf C_cos)
  vec4 cam1; // sin(yaw), shift, view_w, view_h
  ivec4 cfg; // flags bit0 crt, bit1 corrupt; spare, spare
};
"#,
    );
    s
}

/// `blocks` vertex stage: one instance per cube record, 36 verts.
/// Transcribed from `draw_cube`/`project` (fbdev.c:1275/1209).
pub fn blocks_vertex() -> String {
    let mut s = String::new();
    s.push_str("#version 450\n");
    s.push_str("// bash-O4 fbdev-gpu: `blocks` vertex stage.\n");
    s.push_str(&push_constants_glsl());
    s.push_str(
        r#"// Tables transcribed byte-identical from runtime/fbdev.c
// (CUBE_P:830, CUBE_SHADE:841, CUBE_I:846, CUBE_UV:204).
const int CUBE_I[36] = int[36](
  0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7,
  8, 9, 10, 8, 10, 11, 12, 13, 14, 12, 14, 15,
  16, 17, 18, 16, 18, 19, 20, 21, 22, 20, 22, 23);
const int CUBE_P[72] = int[72](
  -500, 500, 500, 500, 500, 500, 500, 500, -500,
  -500, 500, -500, -500, -500, 500, 500, -500, 500,
  500, -500, -500, -500, -500, -500, -500, 500, 500,
  500, 500, 500, 500, -500, 500, -500, -500, 500,
  -500, -500, -500, 500, -500, -500, 500, 500, -500,
  -500, 500, -500, 500, -500, 500, 500, 500, 500,
  500, 500, -500, 500, -500, -500, -500, -500, 500,
  -500, 500, 500, -500, 500, -500, -500, -500, -500);
const int CUBE_SHADE[24] = int[24](
  1000, 1000, 1000, 1000, 500, 500, 500, 500,
  600, 600, 600, 600, 800, 800, 800, 800,
  800, 800, 800, 800, 600, 600, 600, 600);
const vec2 CUBE_UV[24] = vec2[24](
  vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 1),
  vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 1),
  vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 1),
  vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 1),
  vec2(1, 1), vec2(1, 0), vec2(1, 0), vec2(0, 1),
  vec2(0, 1), vec2(0, 0), vec2(1, 0), vec2(0, 1));
// Cube record: 11 payload doubles as vec4s —
struct CubeRec { vec4 a; vec4 b; vec4 c; }; // (x,y,z,sx)(sy,sz,r,g)(b,tx,dam,pad)
layout(std430, set = 0, binding = 0) readonly buffer Blocks { CubeRec rec[]; };
const float WNEAR = 0.01;        // fbdev.c:1180 W_NEAR
const float DEPTH_FAR = 100000.0; // no device far plane; depth range (see docs)
layout(location = 0) out vec3 vTint;
layout(location = 1) out float vShade;
layout(location = 2) out vec2 vUv;
layout(location = 3) flat out int vTex;
layout(location = 4) flat out int vDmg;
void main() {
  uint cube = gl_InstanceIndex;
  uint k = gl_VertexIndex; // 0..35, drawn non-indexed
  uint vi = uint(CUBE_I[k]);
  CubeRec R = rec[cube];
  vec3 centre = R.a.xyz;
  vec3 sc = vec3(R.a.w, R.b.x, R.b.y);
  vec3 corner = vec3(float(CUBE_P[vi * 3u]), float(CUBE_P[vi * 3u + 1u]), float(CUBE_P[vi * 3u + 2u]));
  // to_view, fbdev.c:1379 (milli corner x world scale, recenter, yaw)
  float fx = corner.x * sc.x / 1000000.0 + centre.x - cam0.x;
  float fy = corner.y * sc.y / 1000000.0 + centre.y - (cam0.y + 0.5);
  float fz = corner.z * sc.z / 1000000.0 + centre.z - cam0.z;
  float dx = fx * cam0.w + fz * cam1.x;
  float dz = -fx * cam1.x + fz * cam0.w;
  float w = max(dz, WNEAR); // bug-compatible near clamp (see docs)
  float ndx = dx * 0.7 + cam1.y * w;
  float ndy = fy * 0.45;
  // Vulkan [0,1] depth over [WNEAR, DEPTH_FAR]
  float A = DEPTH_FAR / (DEPTH_FAR - WNEAR);
  float B = -DEPTH_FAR * WNEAR / (DEPTH_FAR - WNEAR);
  gl_Position = vec4(ndx, ndy, A * w + B, w);
  vTint = vec3(R.b.z, R.b.w, R.c.x);
  vShade = float(CUBE_SHADE[vi]) / 1000.0;
  vUv = CUBE_UV[vi];
  vTex = int(R.c.y);
  vDmg = int(R.c.z);
}
"#,
    );
    s
}

/// `blocks` fragment stage: `frag_pixel` ported to ints (fbdev.c:278).
/// Texels are byte-exact under NEAREST filtering, so int math matches
/// the device bit-for-bit — including the overbright pack bleed
/// (replicated with wrapping `uint` arithmetic, not clamped).
pub fn blocks_fragment() -> String {
    let mut s = String::new();
    s.push_str("#version 450\n");
    s.push_str("// bash-O4 fbdev-gpu: `blocks` fragment stage.\n");
    s.push_str(&push_constants_glsl());
    s.push_str(
        r#"layout(set = 0, binding = 1) uniform sampler2DArray atlas;
const int CRACK_LAYER = 9; // fbdev.c CRACK_TEX (crack lives in the atlas)
layout(location = 0) in vec3 vTint;
layout(location = 1) in float vShade;
layout(location = 2) in vec2 vUv;
layout(location = 3) flat in int vTex;
layout(location = 4) flat in int vDmg;
layout(location = 0) out vec4 o;
void main() {
  ivec4 tx = ivec4(texture(atlas, vec3(vUv, float(vTex))) * 255.0);
  int tr = int(vTint.x * 255.0 + 0.5); // draw_cube's (int)(r*255+.5)
  int tg = int(vTint.y * 255.0 + 0.5);
  int tb = int(vTint.z * 255.0 + 0.5);
  int sh = int(vShade * 1000.0);
  tr = tr * sh / 1000;
  tg = tg * sh / 1000;
  tb = tb * sh / 1000;
  if (tr < 0) tr = 0;
  if (tr > 255) tr = 255;
  if (tg < 0) tg = 0;
  if (tg > 255) tg = 255;
  if (tb < 0) tb = 0;
  if (tb > 255) tb = 255;
  int r = tr * tx.r / 128;
  int g = tg * tx.g / 128;
  int b = tb * tx.b / 128;
  // device y-down vs gl_FragCoord y-up: scanline/CRT/vignette math uses
  // the flipped row (a same-phase flip shifts CRT bands on even heights)
  int px = int(gl_FragCoord.x);
  int py = int(cam1.z) - 1 - int(gl_FragCoord.y);
  if ((cfg.x & 1) != 0) {
    if (py % 6 == 0) { r = r * 90 / 100; g = g * 90 / 100; b = b * 90 / 100; }
    int vx = px - int(cam1.z) / 2; if (vx < 0) vx = -vx;
    int vy = py - int(cam1.w) / 2; if (vy < 0) vy = -vy;
    int edge = vx + vy;
    if (edge > 450) {
      int dim = edge - 450; if (dim > 30) dim = 30;
      r = r - r * dim / 256; g = g - g * dim / 256; b = b - b * dim / 256;
    }
  }
  if (vDmg > 0) {
    ivec4 ck = ivec4(texture(atlas, vec3(vUv, float(CRACK_LAYER))) * 255.0);
    int mix = vDmg * ck.a / 4;
    if (mix > 127) mix = 127;
    r = r - (r - ck.r) * mix / 128;
    g = g - (g - ck.g) * mix / 128;
    b = b - (b - ck.b) * mix / 128;
  }
  if ((cfg.x & 2) != 0) {
    int hash = px * 7 + py * 13;
    if (hash % 97 == 0) { r = 255; g = g / 2; b = b / 2; }
  }
  if (r < 0) r = 0;
  if (g < 0) g = 0;
  if (b < 0) b = 0;
  // device pack parity, incl. overbright bleed: (508<<16) keeps 0xFC
  // and green overflow increments red (fbdev.c put_px packing).
  // Alpha is OPAQUE (the device stores BGRX — no alpha channel — so
  // the Vulkan target's alpha is 1.0, never the pack value / 255).
  uint packed = (uint(r) << 16u) | (uint(g) << 8u) | uint(b);
  o = vec4(vec3(float((packed >> 16u) & 0xFFu), float((packed >> 8u) & 0xFFu), float(packed & 0xFFu)) / 255.0, 1.0);
}
"#,
    );
    s
}

/// `overlay` vertex stage: HUD rects as instanced quads (one instance
/// per record, 4 verts as a strip). Coords are FRACTIONS (post-`fmt_*`),
/// rotated in pixel space for aspect correctness (`ov_corners`,:401:
/// `ex = px + dx*ca - dy*sa`, `ey = py + dx*sa + dy*ca`), then mapped
/// with the `ndc_to_px` inverse (`:392`). Erase (`E`) records are host
/// scissor-clears, not shading; `I`/`T` records are a documented
/// follow-up (dynamic texture slots).
pub fn overlay_vertex() -> String {
    let mut s = String::new();
    s.push_str("#version 450\n");
    s.push_str("// bash-O4 fbdev-gpu: `overlay` vertex stage.\n");
    s.push_str(&push_constants_glsl());
    s.push_str(
        r#"// Normalized by the host: g=(cx,cy,wfrac,hfrac), c=(r,g,b,a 0..1),
// d=(rot_deg, 0,0,0). Bare quads arrive with rot 0.
struct OvRec { vec4 g; vec4 c; vec4 d; };
layout(std430, set = 0, binding = 2) readonly buffer OvRecs { OvRec rec[]; };
layout(location = 0) out vec4 vCol;
void main() {
  OvRec R = rec[gl_InstanceIndex];
  // 6 verts as a triangle LIST (not a strip): lavapipe rasterizes a
  // 4-vert strip's second triangle with a subtly wrong interpolant
  // (measured: uniform vCol came out pixel-varying on tri1), while a
  // list of two explicit triangles is exact. Both triangles share
  // the TL→BR diagonal and wind the same way: k=0..2 → (TL,TR,BR),
  // k=3..5 → (BR,BL,TL).
  uint k = gl_VertexIndex;
  // Two triangles sharing the TL→BR diagonal: k=0..2 → corners
  // (TL,TR,BR), k=3..5 → (BR,BL,TL). Corner order per triangle is
  // (diagonal-start, off-diagonal, diagonal-end) so BOTH triangles
  // wind the same way (a list has no strip parity flip; a (TL,BR,BL)
  // second triangle would wind backwards and misinterpolate —
  // measured: the half-quad + diagonal-alpha fault).
  // q: 0,1,2,2,3,0.
  uint q = (k == 3u) ? 2u : ((k == 4u) ? 3u : ((k == 5u) ? 0u : k));
  float cxp = (R.g.x * 0.5 + 0.5) * cam1.z;
  float cyp = (0.5 - R.g.y * 0.5) * cam1.w;
  float hw = R.g.z * cam1.z * 0.5;
  float hh = R.g.w * cam1.w * 0.5;
  float rad = R.d.x * 3.14159265 / 180.0;
  float ca = cos(rad), sa = sin(rad);
  float sx = (q == 0u || q == 3u) ? -1.0 : 1.0;
  float sy = (q < 2u) ? -1.0 : 1.0;
  float dx = sx * hw, dy = sy * hh;
  float px = cxp + dx * ca - dy * sa;
  float py = cyp + dx * sa + dy * ca;
  gl_Position = vec4(px / cam1.z * 2.0 - 1.0, 1.0 - py / cam1.w * 2.0, 0.0, 1.0);
  vCol = R.c;
}
"#,
    );
    s
}

/// `overlay` fragment stage: flat color; blending enabled host-side
/// (src-alpha, matching the layer composite at present).
pub fn overlay_fragment() -> String {
    let mut s = String::new();
    s.push_str("#version 450\n");
    s.push_str("// bash-O4 fbdev-gpu: `overlay` fragment stage.\n");
    s.push_str(&push_constants_glsl());
    s.push_str(
        r#"layout(location = 0) in vec4 vCol;
layout(location = 0) out vec4 o;
void main() { o = vCol; }
"#,
    );
    s
}

/// Find the first device write for `verb` — a `GpuOp` lifted from
/// `echo … > /dev/fb0/<verb>` (any depth), or the equivalent in-process
/// `fb_blocks`/`fb_overlay`/`fb_overlay_flash` call (what the writes
/// become under the C target's `fbdev-gpu-calls` transform) — and emit
/// its GLSL pair. Returns `(vertex_src, fragment_src)`.
///
/// Refusals (REFUSE > GUESS): unknown verbs, `call` (present is host
/// work), `depthmask`/`uniform/*` (push-constant slots, not programs),
/// and programs with no matching write at all.
pub fn emit_fb_shader(prog: &IrProgram, verb: &str) -> Result<(String, String), String> {
    let (vertex, fragment) = match verb {
        "blocks" => (blocks_vertex(), blocks_fragment()),
        "overlay" | "overlay_flash" => (overlay_vertex(), overlay_fragment()),
        "call" => {
            return Err("fb-dev-gpu: `call` is present (host work), not a shader".into());
        }
        "depthmask" => {
            return Err("fb-dev-gpu: `depthmask` is a push-constant bit, not a shader".into());
        }
        v if v.starts_with("uniform") => {
            return Err("fb-dev-gpu: `uniform/*` is a push-constant slot, not a shader".into());
        }
        other => return Err(format!("fb-dev-gpu: unknown verb {other:?}")),
    };
    let found = find_device_write(&prog.stmts, verb);
    let mut vertex = vertex;
    let mut fragment = fragment;
    match found {
        Some(id) => {
            let note = format!("// dispatch site {id} (docs/BASH-O4.md §4.4 `_sh_spv_<id>`)\n");
            vertex.insert_str("#version 450\n".len(), &note);
            fragment.insert_str("#version 450\n".len(), &note);
        }
        None => {
            return Err(format!(
                "fb-dev-gpu: no write to /dev/fb0/{verb} (or fb_* equivalent) in this program"
            ));
        }
    }
    Ok((vertex, fragment))
}

/// First matching device-write id: `GpuOp{device, verb}` or the
/// equivalent `fb_*` call. Recursive over composite bodies (same
/// layering as the fbdev-gpu transforms).
fn find_device_write(stmts: &[IrStmt], verb: &str) -> Option<String> {
    for st in stmts {
        if let Some(id) = find_device_write_stmt(st, verb) {
            return Some(id);
        }
    }
    None
}

fn fb_call_verb(cmd: &str) -> Option<&'static str> {
    match cmd {
        "fb_blocks" => Some("blocks"),
        "fb_overlay" | "fb_overlay_flash" => Some("overlay"),
        _ => None,
    }
}

fn find_device_write_stmt(st: &IrStmt, verb: &str) -> Option<String> {
    match st {
        IrStmt::Ext(n) if n.tag() == "GpuOp" => {
            let op = n.as_any().downcast_ref::<debashl::shir_nodes::GpuOp>()?;
            if (op.device == "/dev/fb0" || op.device == "/dev/webgl") && op.verb == verb {
                return Some(op.id.clone());
            }
            None
        }
        IrStmt::Expr(IrExpr::Call { func, args }) if func == "exec" || func == "builtin" => {
            let [IrExpr::Str(cmd, _), IrExpr::Array(_)] = args.as_slice() else {
                return None;
            };
            if fb_call_verb(cmd) == Some(verb) {
                return Some(format!("fb_{cmd}"));
            }
            None
        }
        IrStmt::Block(b)
        | IrStmt::Function { body: b, .. }
        | IrStmt::While { body: b, .. }
        | IrStmt::For { body: b, .. }
        | IrStmt::ForInit { body: b, .. }
        | IrStmt::DoWhile { body: b, .. } => find_device_write(b, verb),
        IrStmt::Subshell(b) | IrStmt::Background(b) => find_device_write(b, verb),
        IrStmt::If {
            then: b,
            elsifs,
            else_,
            ..
        } => find_device_write(b, verb)
            .or_else(|| {
                elsifs
                    .iter()
                    .find_map(|(_, eb)| find_device_write(eb, verb))
            })
            .or_else(|| find_device_write(else_, verb)),
        IrStmt::Pipeline { stages, .. } => stages
            .iter()
            .find_map(|stage| find_device_write(stage, verb)),
        _ => None,
    }
}

/// Compile one GLSL stage to SPIR-V (`glslangValidator -V`), returning
/// the SPIR-V bytes. Stage-aware sibling of `shader::compile_spv`
/// (which hardcodes the `.comp` compute shape): `ext` is `vert` or
/// `frag`. Same conventions otherwise — errors propagate (a broken
/// emitter must fail loudly here, never silently serve CPU fallback).
pub fn compile_stage(
    compiler: &std::path::Path,
    glsl: &str,
    workdir: &std::path::Path,
    ext: &str,
) -> Result<Vec<u8>, String> {
    let src = workdir.join(format!("fb.{ext}"));
    let out = workdir.join(format!("fb.{ext}.spv"));
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn push_layout_names_camera_and_flags() {
        let p = push_constants_glsl();
        for want in ["cam0", "cam1", "cfg", "binding 0", "binding 1", "binding 2"] {
            assert!(p.contains(want), "push layout missing {want}:\n{p}");
        }
    }

    #[test]
    fn blocks_vertex_has_tables_and_projection() {
        let v = blocks_vertex();
        assert!(v.starts_with("#version 450\n"), "version first");
        // byte-identical tables (spot-check the load-bearing values)
        assert!(v.contains("0, 1, 2, 0, 2, 3"), "CUBE_I head");
        assert!(v.contains("-500, 500, 500"), "CUBE_P head");
        assert!(v.contains("1000, 1000, 1000, 1000, 500"), "CUBE_SHADE head");
        assert!(v.contains("gl_InstanceIndex"), "one instance per cube");
        assert!(v.contains("gl_Position"), "clip output");
        // to_view/project transcription (fbdev.c:1379/1209)
        assert!(v.contains("(cam0.y + 0.5)"), "eye half-block offset");
        assert!(v.contains("0.7"), "ndcx factor");
        assert!(v.contains("0.45"), "ndcy factor");
        // milli-corner × world scale on ALL THREE axes (fbdev.c
        // to_view divides each by 1e6 — a missing divisor on y/z
        // explodes verts to ±50000 and fills the screen; caught by
        // the fb_dispatch proof, pinned here).
        assert_eq!(
            v.matches("/ 1000000.0").count(),
            3,
            "milli divisor on x, y, z:\n{v}"
        );
        assert!(v.contains("WNEAR"), "near clamp");
        assert!(v.contains("DEPTH_FAR"), "depth range");
        assert!(v.contains("CubeRec"), "record struct");
    }

    #[test]
    fn blocks_fragment_ports_frag_pixel() {
        let f = blocks_fragment();
        assert!(f.starts_with("#version 450\n"), "version first");
        assert!(f.contains("sampler2DArray"), "atlas sampling");
        assert!(f.contains("CRACK_LAYER"), "crack slot binding");
        // frag_pixel constants, transcribed (fbdev.c:278)
        assert!(f.contains("/ 128"), "tint scale");
        assert!(f.contains("/ 1000"), "shade scale");
        assert!(f.contains("% 97"), "corrupt hash modulus");
        assert!(f.contains("% 6"), "CRT scanline modulus");
        assert!(f.contains("450"), "vignette threshold");
        assert!(f.contains("gl_FragCoord"), "pixel coords");
        assert!(f.contains("0xFFu"), "pack parity mask");
        assert!(
            f.contains("layout(location = 0) out vec4 o"),
            "color output"
        );
    }

    #[test]
    fn overlay_pair_covers_quads() {
        let (v, f) = (overlay_vertex(), overlay_fragment());
        assert!(v.contains("OvRec"), "record struct");
        assert!(v.contains("cos(rad)"), "rotation");
        assert!(v.contains("gl_InstanceIndex"), "one instance per rect");
        // 6-vert triangle list (not a 4-vert strip): lavapipe
        // misinterpolates the strip's second triangle (the
        // fb_dispatch + --fb-proof diagonal-alpha fault).
        assert!(v.contains("(k == 3u) ? 2u"), "k-to-corner fold");
        assert!(f.contains("o = vCol"), "flat color");
    }

    fn gpu_op_prog(device: &str, verb: &str) -> IrProgram {
        IrProgram {
            imports: vec![],
            requires: vec![],
            stmts: vec![IrStmt::Ext(Box::new(debashl::shir_nodes::GpuOp {
                device: device.to_string(),
                verb: verb.to_string(),
                slot: String::new(),
                payload: IrExpr::Str("p".to_string(), debashl::ir::StrStyle::DoubleQuoted),
                id: "sh_gpu_dev_0".to_string(),
            }))],
            subs: vec![],
            var_types: vec![],
            stmt_lines: vec![],
            var_lengths: vec![],
            var_const: vec![],
            var_lifetimes: vec![],
            var_nospace: vec![],
            var_storage: vec![],
            var_bash_env: vec![],
        }
    }

    #[test]
    fn emit_finds_gpu_op_and_call_spellings() {
        // GpuOp spelling (echo … > /dev/fb0/blocks, pre-calls-transform)
        let (v, f) =
            emit_fb_shader(&gpu_op_prog("/dev/fb0", "blocks"), "blocks").expect("blocks must emit");
        assert!(v.contains("gl_InstanceIndex") && f.contains("sampler2DArray"));
        // fb_* call spelling (post-calls-transform IR)
        let mut prog = gpu_op_prog("/dev/fb0", "overlay");
        prog.stmts = vec![IrStmt::Expr(IrExpr::Call {
            func: "exec".to_string(),
            args: vec![
                IrExpr::Str(
                    "fb_overlay".to_string(),
                    debashl::ir::StrStyle::DoubleQuoted,
                ),
                IrExpr::Array(vec![IrExpr::Str(
                    "x".to_string(),
                    debashl::ir::StrStyle::DoubleQuoted,
                )]),
            ],
        })];
        let (v, _) = emit_fb_shader(&prog, "overlay").expect("overlay must emit");
        assert!(v.contains("OvRec"));
    }

    #[test]
    fn emit_refuses() {
        // unknown verb
        assert!(emit_fb_shader(&gpu_op_prog("/dev/fb0", "blocks"), "frobnicate").is_err());
        // host-side verbs are not shaders
        for v in ["call", "depthmask"] {
            assert!(
                emit_fb_shader(&gpu_op_prog("/dev/fb0", v), v).is_err(),
                "{v} must refuse"
            );
        }
        // no matching write anywhere
        assert!(emit_fb_shader(&gpu_op_prog("/dev/fb0", "blocks"), "overlay").is_err());
        // non-device paths never match
        assert!(emit_fb_shader(&gpu_op_prog("/dev/null", "blocks"), "blocks").is_err());
    }

    #[test]
    fn spirv_validates_when_toolchain_present() {
        let Some(cc) = crate::shader::find_spirv_compiler(&crate::cache::cache_root(None)) else {
            eprintln!("SKIP: no SPIR-V compiler; GLSL structure asserted above");
            return;
        };
        let dir = std::env::temp_dir().join(format!("bo4fb{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        for (src, ext) in [
            (blocks_vertex(), "vert"),
            (blocks_fragment(), "frag"),
            (overlay_vertex(), "vert"),
            (overlay_fragment(), "frag"),
        ] {
            let spv = compile_stage(&cc, &src, &dir, ext).expect("emitted GLSL must compile");
            assert!(spv.len() > 4, "empty SPIR-V for {ext}");
            assert_eq!(
                &spv[..4],
                &[0x03, 0x02, 0x23, 0x07],
                "SPIR-V magic for {ext}"
            );
        }
        let _ = std::fs::remove_dir_all(&dir);
    }
}
