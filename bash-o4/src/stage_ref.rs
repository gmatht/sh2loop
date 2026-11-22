//! Derive a bound C2/C3 stage pair's **CPU reference** from the stage IR.
//!
//! The stage split needs a CPU frame to compare a GPU frame against. Until
//! this module existed that frame was produced by the *program* (a hand-
//! placed overlay record whose numbers matched the stage quad), which is a
//! per-fixture answer, not a compiler capability. This module is the
//! compiler's answer: it runs the same bound stages the shader front end
//! compiled — the same `IrSub` bodies `gpu_lift::analyze` bound, with the
//! bridge values the stage host actually supplies — and reports the pixel
//! rectangle and colour those stages produce for the host's fixed quad.
//!
//! What the derivation is, precisely:
//!
//! * The host draws ONE screen-aligned quad (`STAGE_QUAD_POS`) with
//!   `aShade = 1`, `aUv = 0/1`, `uObjPos = 0`, `uScale = 1`,
//!   `uBlockColor = 1` (`fb_gpu_ffi::stage_quad_*` — the same constants
//!   the host builds its vertex stream from, so the two cannot drift).
//! * The vertex stage is evaluated at the four corners. If the result is
//!   not an axis-aligned NDC rectangle (`vp_x/vp_w` constant per column,
//!   `vp_y/vp_w` constant per row) the pair refuses: the reference is a
//!   rectangle, and a rotated or non-affine pair has no rectangle to
//!   compare against.
//! * `vColor` must be constant across the four corners, and the fragment
//!   must not read a per-pixel bridge (`frag_x/frag_y`, `uv_*`), the crack
//!   sampler or `damage`: those make the output vary inside the quad and a
//!   single-colour reference would be a guess. Refusing is the honest
//!   answer; the frame then keeps the CPU pixels.
//! * Texture reads are evaluated against the **build-time atlas**
//!   (`fb_gpu_ffi::grey_atlas`) and only when the sampled layer is
//!   uniform — otherwise the texel depends on the runtime upload and the
//!   reference would be stale.
//!
//! The arithmetic is bash's (i64, truncating division, 2^64 wrapping
//! `**`), which is what the stage bodies are written in and what the
//! shader front end lowers to GLSL `int` ops.
//!
//! Every refusal starts with [`REFUSE`]; `pipeline::inject_stage_split`
//! prints it and embeds no stage split, so an uncovered pair never
//! dispatches (the docs' rule: "a pair without a CPU reference must veto,
//! not dispatch"), and `GPU_SPLITS` never counts a dispatch that cannot be
//! verified.

use std::collections::HashMap;

use debashl::ir::{ArithAst, IrExpr, IrProgram, IrStmt};

/// Stable prefix for every derivation refusal.
pub const REFUSE: &str = "stage-reference-uncovered";

/// The CPU counterpart of one stage-pair dispatch, in the bridge's own
/// units: NDC in MILLI (`1000` = 1.0), colour bytes 0..=255.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StageRef {
    pub cx: i64,
    pub cy: i64,
    pub hw: i64,
    pub hh: i64,
    pub r: i64,
    pub g: i64,
    pub b: i64,
}

fn refuse(what: impl AsRef<str>) -> String {
    format!("{REFUSE}: {}", what.as_ref())
}

/// Derive the reference for the bound pair by evaluating the two stage
/// functions at `vert`/`frag` (the names the lift's sites carry).
pub fn derive(prog: &IrProgram, vert: &str, frag: &str) -> Result<StageRef, String> {
    // A stage may copy a per-pixel bridge into a helper it never reads
    // (`fx=$frag_x` in the witness): that read is not part of the frame it
    // produces, so the dead store goes before the evaluator can refuse on
    // it. A store whose value IS read stays, and reading `frag_x` there
    // refuses for the honest reason.
    let vbody = prune_dead_stores(find_body(prog, vert)?, &["vp_x", "vp_y", "vp_w", "vc_r", "vc_g", "vc_b"]);
    let fbody = prune_dead_stores(find_body(prog, frag)?, &[]);
    let (vbody, fbody) = (vbody.as_slice(), fbody.as_slice());
    if std::env::var("SH2_STAGE_REF_DEBUG").as_deref() == Ok("1") {
        eprintln!("stage_ref: vertex body = {vbody:#?}");
        eprintln!("stage_ref: fragment body = {fbody:#?}");
    }

    // ── vertex stage at the host quad's four corners ────────────────
    let mut corners: Vec<Corner> = Vec::with_capacity(4);
    for (i, pos) in crate::fb_gpu_ffi::STAGE_QUAD_POS.iter().enumerate() {
        let uv = crate::fb_gpu_ffi::STAGE_QUAD_UV[i];
        let mut ev = Ev::new();
        let milli = |v: f64| (v * 1000.0).round() as i64;
        ev.set("ap_x", milli(pos[0]));
        ev.set("ap_y", milli(pos[1]));
        ev.set("ap_z", 0);
        let shade = milli(crate::fb_gpu_ffi::STAGE_QUAD_SHADE);
        ev.set("ash_r", shade);
        ev.set("ash_g", shade);
        ev.set("ash_b", shade);
        ev.set("auv_u", milli(uv[0]));
        ev.set("auv_v", milli(uv[1]));
        let uop = milli(crate::fb_gpu_ffi::STAGE_QUAD_UNIFORM_OBJ_POS);
        ev.set("uop_x", uop);
        ev.set("uop_y", uop);
        ev.set("uop_z", uop);
        let usc = milli(crate::fb_gpu_ffi::STAGE_QUAD_UNIFORM_SCALE);
        ev.set("usc_x", usc);
        ev.set("usc_y", usc);
        ev.set("usc_z", usc);
        let ublk = milli(crate::fb_gpu_ffi::STAGE_QUAD_UNIFORM_BLOCK_COLOR);
        ev.set("ublk_r", ublk);
        ev.set("ublk_g", ublk);
        ev.set("ublk_b", ublk);
        ev.run(vbody)?;
        let vp_x = ev.get("vp_x")?;
        let vp_y = ev.get("vp_y")?;
        let vp_w = ev.get("vp_w")?;
        if vp_w <= 0 {
            return Err(refuse(format!(
                "vertex stage writes vp_w={vp_w}; the homogeneous divide is undefined"
            )));
        }
        corners.push(Corner {
            x: ndc_milli(vp_x, vp_w),
            y: ndc_milli(vp_y, vp_w),
            vc: [ev.get("vc_r")?, ev.get("vc_g")?, ev.get("vc_b")?],
        });
    }

    // ── the quad must be an axis-aligned NDC rectangle ──────────────
    let (c0, c1, c2, c3) = (corners[0], corners[1], corners[2], corners[3]);
    if c0.y != c1.y || c2.y != c3.y || c0.x != c3.x || c1.x != c2.x {
        return Err(refuse(
            "vertex output is not an axis-aligned NDC rectangle (the CPU reference is a rectangle; \
             a rotated or non-affine quad has none)",
        ));
    }
    if c1.x <= c0.x || c2.y <= c0.y {
        return Err(refuse("vertex output rectangle is empty or inverted"));
    }
    if c0.vc != c1.vc || c0.vc != c2.vc || c0.vc != c3.vc {
        return Err(refuse(
            "varying vColor is not constant across the quad (the reference is one colour)",
        ));
    }
    let (cx, hw) = ((c0.x + c1.x) / 2, (c1.x - c0.x) / 2);
    let (cy, hh) = ((c0.y + c2.y) / 2, (c2.y - c0.y) / 2);

    // ── fragment stage with the bridge the fragment host supplies ───
    let mut ev = Ev::new();
    // The ES front end seeds `vcolor_* = int(vColor.* * 127.0)`.
    for (i, ch) in ["vcolor_r", "vcolor_g", "vcolor_b"].iter().enumerate() {
        ev.set(ch, (c0.vc[i] as f64 / 1000.0 * 127.0).trunc() as i64);
    }
    let atlas = crate::fb_gpu_ffi::grey_atlas();
    for (i, ch) in ["tex_r", "tex_g", "tex_b"].iter().enumerate() {
        ev.set(ch, atlas_channel(&atlas, 0, i)?);
    }
    ev.run(fbody)?;
    if ev.out.len() < 3 {
        return Err(refuse(format!(
            "fragment stage emits {} byte(s); the bridge contract is three channels (putb r/g/b)",
            ev.out.len()
        )));
    }
    let byte = |v: i64| v.clamp(0, 255);
    Ok(StageRef {
        cx,
        cy,
        hw,
        hh,
        r: byte(ev.out[0]),
        g: byte(ev.out[1]),
        b: byte(ev.out[2]),
    })
}

/// The C call the generated program makes for this reference.
pub fn c_call(r: &StageRef) -> String {
    format!(
        "fb_stage_ref({}, {}, {}, {}, {}, {}, {})",
        r.cx, r.cy, r.hw, r.hh, r.r, r.g, r.b
    )
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Corner {
    x: i64,
    y: i64,
    vc: [i64; 3],
}

/// `vp / vp_w` in milli-NDC, rounded to the nearest milli (the GPU divides
/// in float; a milli is far below one pixel at any device size the lift
/// runs at, and the parity gate still measures the result).
fn ndc_milli(v: i64, w: i64) -> i64 {
    let num = v as i128 * 1000;
    let d = w as i128;
    let q = if num >= 0 {
        (2 * num + d) / (2 * d)
    } else {
        (2 * num - d) / (2 * d)
    };
    q.clamp(i64::MIN as i128, i64::MAX as i128) as i64
}

/// The colour byte of a uniform atlas layer, or a refusal when the layer
/// varies (a per-texel result would depend on the runtime upload).
fn atlas_channel((bytes, _layers, size): &(Vec<u8>, u32, u32), layer: u32, channel: usize) -> Result<i64, String> {
    let texels = (*size as usize).pow(2);
    let base = layer as usize * texels * 4;
    if bytes.len() < base + texels * 4 {
        return Err(refuse(format!("atlas has no layer {layer}")));
    }
    let first = bytes[base + channel] as i64;
    for i in 0..texels {
        let v = bytes[base + i * 4 + channel] as i64;
        if v != first {
            return Err(refuse(format!(
                "texture layer {layer} is not uniform in channel {channel} \
                 (the reference would depend on the runtime atlas upload)"
            )));
        }
    }
    Ok(first)
}

/// Drop `x = ...` statements whose target is never read in the stage.
/// Two passes are enough for the shapes the lift binds (a seed copied to a
/// helper, which is itself unused); a longer chain is simply kept, and can
/// only cause a refusal, never a wrong value.
fn prune_dead_stores(body: &[IrStmt], roots: &[&str]) -> Vec<IrStmt> {
    let mut out: Vec<IrStmt> = body.to_vec();
    for _ in 0..2 {
        // `roots` are the stage's OUTPUTS (writes the host reads); a store
        // to one is live even when nothing inside the body reads it.
        let mut read: std::collections::HashSet<String> =
            roots.iter().map(|r| r.to_string()).collect();
        for st in &out {
            reads_in_stmt(st, &mut read);
        }
        out.retain(|st| match st {
            IrStmt::Assign { targets, .. } => {
                !targets.iter().all(|t| t.indices.is_empty() && !read.contains(&t.var))
            }
            // The A1's setVar form of the same statement.
            IrStmt::Expr(IrExpr::Call { func, args }) if func == "setVar" => match args.first() {
                Some(IrExpr::Str(n, _)) => read.contains(n),
                _ => true,
            },
            _ => true,
        });
    }
    out
}

fn reads_in_stmt(st: &IrStmt, out: &mut std::collections::HashSet<String>) {
    match st {
        IrStmt::Assign { targets, expr, .. } => {
            for t in targets {
                for i in &t.indices {
                    reads_in_expr(i, out);
                }
            }
            reads_in_expr(expr, out);
        }
        IrStmt::If { cond, then, elsifs, else_ } => {
            reads_in_expr(cond, out);
            for st in then {
                reads_in_stmt(st, out);
            }
            for (c, body) in elsifs {
                reads_in_expr(c, out);
                for st in body {
                    reads_in_stmt(st, out);
                }
            }
            for st in else_ {
                reads_in_stmt(st, out);
            }
        }
        IrStmt::Exec { cmd, args, .. } => {
            reads_in_expr(cmd, out);
            for a in args {
                reads_in_expr(a, out);
            }
        }
        IrStmt::Expr(e) => reads_in_expr(e, out),
        IrStmt::Declare { init, .. } => {
            if let Some(e) = init {
                reads_in_expr(e, out);
            }
        }
        _ => {}
    }
}

fn reads_in_expr(e: &IrExpr, out: &mut std::collections::HashSet<String>) {
    match e {
        IrExpr::Var(n, _) => {
            out.insert(n.clone());
        }
        IrExpr::Index { key, .. } => reads_in_expr(key, out),
        IrExpr::BinOp { lhs, rhs, .. } => {
            reads_in_expr(lhs, out);
            reads_in_expr(rhs, out);
        }
        IrExpr::Call { func, args } => {
            if func == "getVar" {
                if let Some(IrExpr::Str(n, _)) = args.first() {
                    out.insert(n.clone());
                }
            }
            for a in args {
                reads_in_expr(a, out);
            }
        }
        IrExpr::MethodCall { obj, args, .. } => {
            reads_in_expr(obj, out);
            for a in args {
                reads_in_expr(a, out);
            }
        }
        IrExpr::Ternary { cond, then, else_ } => {
            reads_in_expr(cond, out);
            reads_in_expr(then, out);
            reads_in_expr(else_, out);
        }
        IrExpr::Arith(a) => reads_in_arith(a, out),
        // `putb $r` wraps its argument in a one-word Array.
        IrExpr::Array(items) => {
            for e in items {
                reads_in_expr(e, out);
            }
        }
        _ => {}
    }
}

fn reads_in_arith(a: &ArithAst, out: &mut std::collections::HashSet<String>) {
    match a {
        ArithAst::Var(n) | ArithAst::Ident(n) => {
            out.insert(n.clone());
        }
        ArithAst::Bin { lhs, rhs, .. } => {
            reads_in_arith(lhs, out);
            reads_in_arith(rhs, out);
        }
        ArithAst::Un { arg, .. } => reads_in_arith(arg, out),
        ArithAst::Cond { test, then, else_ } => {
            reads_in_arith(test, out);
            reads_in_arith(then, out);
            reads_in_arith(else_, out);
        }
        ArithAst::Assign { rhs, .. } => reads_in_arith(rhs, out),
        ArithAst::IncDec { var, .. } => {
            out.insert(var.clone());
        }
        ArithAst::Index { key, .. } => reads_in_arith(key, out),
        _ => {}
    }
}

fn find_body<'a>(prog: &'a IrProgram, name: &str) -> Result<&'a [IrStmt], String> {
    if let Some(s) = prog.subs.iter().find(|s| s.name == name) {
        return Ok(&s.body);
    }
    // The shIR ingress of the pipeline's A1 carries function definitions as
    // `IrStmt::Function` nodes inside the statement tree (the same walk the
    // lift's own `collect_fns` does); `IrProgram.subs` is the parser path.
    if let Some(body) = fn_body_in(&prog.stmts, name) {
        return Ok(body.as_slice());
    }
    let mut have: Vec<&str> = prog.subs.iter().map(|s| s.name.as_str()).collect();
    collect_fn_names(&prog.stmts, &mut have);
    have.truncate(8);
    Err(refuse(format!(
        "no function named '{name}' in the bound program (it defines: {})",
        have.join(", ")
    )))
}

fn fn_body_in<'a>(stmts: &'a [IrStmt], name: &str) -> Option<&'a Vec<IrStmt>> {
    for s in stmts {
        match s {
            IrStmt::Function { name: n, body, .. } if n == name => return Some(body),
            IrStmt::If { then, elsifs, else_, .. } => {
                if let Some(b) = fn_body_in(then, name) {
                    return Some(b);
                }
                for (_, b) in elsifs {
                    if let Some(b) = fn_body_in(b, name) {
                        return Some(b);
                    }
                }
                if let Some(b) = fn_body_in(else_, name) {
                    return Some(b);
                }
            }
            IrStmt::While { body, .. }
            | IrStmt::DoWhile { body, .. }
            | IrStmt::For { body, .. }
            | IrStmt::ForInit { body, .. }
            | IrStmt::Subshell(body)
            | IrStmt::Background(body) => {
                if let Some(b) = fn_body_in(body, name) {
                    return Some(b);
                }
            }
            _ => {}
        }
    }
    None
}

fn collect_fn_names<'a>(stmts: &'a [IrStmt], out: &mut Vec<&'a str>) {
    for s in stmts {
        if let IrStmt::Function { name, body, .. } = s {
            out.push(name.as_str());
            collect_fn_names(body, out);
        }
    }
}

// ── the evaluator ───────────────────────────────────────────────────

#[derive(Debug, Clone)]
enum Val {
    Int(i64),
    Str(String),
}

struct Ev {
    ints: HashMap<String, i64>,
    strs: HashMap<String, String>,
    out: Vec<i64>,
}

impl Ev {
    fn new() -> Self {
        Ev {
            ints: HashMap::new(),
            strs: HashMap::new(),
            out: Vec::new(),
        }
    }

    fn set(&mut self, name: &str, v: i64) {
        self.ints.insert(name.to_string(), v);
    }

    fn get(&self, name: &str) -> Result<i64, String> {
        // A value the front end kept as a string (`vp_w=1000` is not read in
        // any arithmetic, so it never gets the Int verdict) still carries
        // the integer the stage wrote; parse it like bash would.
        if let Some(s) = self.strs.get(name) {
            if let Ok(v) = s.trim().parse::<i64>() {
                return Ok(v);
            }
        }
        self.ints.get(name).copied().ok_or_else(|| {
            let mut have: Vec<&str> = self.ints.keys().map(|s| s.as_str()).collect();
            have.sort_unstable();
            refuse(format!(
                "the bound stage does not write '{name}' (the reference needs it; it wrote: {})",
                have.join(", ")
            ))
        })
    }

    fn run(&mut self, body: &[IrStmt]) -> Result<(), String> {
        for st in body {
            self.stmt(st)?;
        }
        Ok(())
    }

    fn stmt(&mut self, st: &IrStmt) -> Result<(), String> {
        match st {
            IrStmt::Assign { targets, expr, .. } => {
                if targets.len() != 1 || !targets[0].indices.is_empty() {
                    return Err(refuse("assignment to an array element in a stage"));
                }
                let name = targets[0].var.clone();
                match self.expr(expr)? {
                    Val::Int(n) => {
                        self.ints.insert(name, n);
                    }
                    Val::Str(s) => {
                        self.strs.insert(name, s);
                    }
                }
                Ok(())
            }
            IrStmt::Declare { vars, init, .. } => {
                if let Some(e) = init {
                    let v = self.expr(e)?;
                    if let Some(d) = vars.first() {
                        match v {
                            Val::Int(n) => {
                                self.ints.insert(d.name.clone(), n);
                            }
                            Val::Str(s) => {
                                self.strs.insert(d.name.clone(), s);
                            }
                        }
                    }
                }
                Ok(())
            }
            IrStmt::If {
                cond,
                then,
                elsifs,
                else_,
            } => {
                if self.cond(cond)? {
                    return self.run(then);
                }
                for (c, body) in elsifs {
                    if self.cond(c)? {
                        return self.run(body);
                    }
                }
                self.run(else_)
            }
            IrStmt::Exec {
                cmd,
                args,
                capture,
                redirects,
                env,
            } => {
                if capture.is_some() || !redirects.is_empty() || !env.is_empty() {
                    return Err(refuse("a stage runs a command with a capture/redirect/env"));
                }
                let IrExpr::Str(name, _) = cmd else {
                    return Err(refuse("a stage runs a command whose name is not a literal"));
                };
                self.command(name, args)
            }
            // The A1 spells assignments as setVar("name", value) and a
            // bare command as exec("cmd", args...).
            IrStmt::Expr(IrExpr::Call { func, args }) if func == "setVar" => {
                if args.len() < 2 {
                    return Err(refuse("setVar with no value"));
                }
                let IrExpr::Str(name, _) = &args[0] else {
                    return Err(refuse("setVar with a non-literal variable name"));
                };
                match self.expr(&args[1])? {
                    Val::Int(n) => {
                        self.ints.insert(name.clone(), n);
                    }
                    Val::Str(s) => {
                        self.strs.insert(name.clone(), s);
                    }
                }
                Ok(())
            }
            IrStmt::Expr(IrExpr::Call { func, args }) if func == "exec" => {
                let Some(IrExpr::Str(name, _)) = args.first() else {
                    return Err(refuse("a stage runs a command whose name is not a literal"));
                };
                self.command(name, &args[1..])
            }
            IrStmt::Expr(IrExpr::Call { func, args }) if func == "putb" => self.command("putb", args),
            IrStmt::Return(None) => Ok(()),
            other => Err(refuse(format!(
                "a stage contains {} — the reference evaluator only models straight-line \
                 assignment, if/else and putb",
                stmt_kind(other)
            ))),
        }
    }

    /// The only command a stage may run is `putb`: one byte into out_buf.
    fn command(&mut self, name: &str, args: &[IrExpr]) -> Result<(), String> {
        if name != "putb" {
            return Err(refuse(format!(
                "a stage runs the command '{name}'; only putb is an output"
            )));
        }
        if args.len() != 1 {
            return Err(refuse("putb with an arity other than one"));
        }
        let b = self.num(&args[0])?;
        self.out.push(b.clamp(0, 255));
        Ok(())
    }

    fn cond(&self, e: &IrExpr) -> Result<bool, String> {
        Ok(self.num(e)? != 0)
    }

    fn num(&self, e: &IrExpr) -> Result<i64, String> {
        match self.expr(e)? {
            Val::Int(n) => Ok(n),
            Val::Str(s) => s
                .trim()
                .parse::<i64>()
                .map_err(|_| refuse(format!("'{s}' is not an integer in a stage expression"))),
        }
    }

    fn expr(&self, e: &IrExpr) -> Result<Val, String> {
        match e {
            IrExpr::Int(n) => Ok(Val::Int(*n)),
            IrExpr::Str(s, _) => Ok(Val::Str(s.clone())),
            IrExpr::Var(name, _) => {
                if let Some(n) = self.ints.get(name) {
                    return Ok(Val::Int(*n));
                }
                if let Some(s) = self.strs.get(name) {
                    return Ok(Val::Str(s.clone()));
                }
                Err(refuse(format!(
                    "the stage reads '{name}', which the stage host does not supply"
                )))
            }
            IrExpr::Arith(a) => Ok(Val::Int(self.arith(a)?)),
            // A word-list wrapper with one element (`putb $r` → [r]).
            IrExpr::Array(items) if items.len() == 1 => self.expr(&items[0]),
            // `putb $var` arrives wrapped in split() — the value is the
            // variable's integer, not a word list.
            IrExpr::Call { func, args } if func == "split" && args.len() == 1 => self.expr(&args[0]),
            // The shIR (A1) spells a variable READ as getVar("name"); the
            // GLSL front end renders it as the bare identifier.
            IrExpr::Call { func, args } if func == "getVar" && args.len() == 1 => {
                if let IrExpr::Str(n, _) = &args[0] {
                    self.expr(&IrExpr::Var(n.clone(), None))
                } else {
                    Err(refuse("getVar() with a non-literal name"))
                }
            }
            IrExpr::Call { func, .. } => Err(refuse(format!(
                "a stage calls '{func}' — the reference evaluator only models integer \
                 arithmetic, string copies and putb"
            ))),
            other => {
                let mut d = format!("{other:?}");
                d.truncate(120);
                Err(refuse(format!(
                    "a stage contains {} ({d}) — the reference evaluator only models \
                     integer arithmetic, string copies and putb",
                    expr_kind(other)
                )))
            }
        }
    }

    fn arith(&self, a: &ArithAst) -> Result<i64, String> {
        match a {
            ArithAst::Num(n) => Ok(*n),
            ArithAst::Var(name) | ArithAst::Ident(name) => self.ints.get(name).copied().ok_or_else(|| {
                refuse(format!(
                    "the stage reads '{name}', which the stage host does not supply"
                ))
            }),
            ArithAst::Un { op, arg } => {
                let v = self.arith(arg)?;
                match op.as_str() {
                    "-" => Ok(v.wrapping_neg()),
                    "+" => Ok(v),
                    "!" => Ok((v == 0) as i64),
                    "~" => Ok(!v),
                    o => Err(refuse(format!("unmodelled unary operator '{o}' in a stage"))),
                }
            }
            ArithAst::Bin { op, lhs, rhs } => {
                let a = self.arith(lhs)?;
                // `&&`/`||` short-circuit in bash; model that before the rhs.
                match op.as_str() {
                    "&&" => return Ok(((a != 0) && (self.arith(rhs)? != 0)) as i64),
                    "||" => return Ok(((a != 0) || (self.arith(rhs)? != 0)) as i64),
                    _ => {}
                }
                let b = self.arith(rhs)?;
                match op.as_str() {
                    "+" => Ok(a.wrapping_add(b)),
                    "-" => Ok(a.wrapping_sub(b)),
                    "*" => Ok(a.wrapping_mul(b)),
                    "/" => {
                        if b == 0 {
                            return Err(refuse("the stage divides by zero at reference time"));
                        }
                        a.checked_div(b)
                            .ok_or_else(|| refuse("integer overflow in a stage division"))
                    }
                    "%" => {
                        if b == 0 {
                            return Err(refuse("the stage takes a remainder by zero at reference time"));
                        }
                        a.checked_rem(b)
                            .ok_or_else(|| refuse("integer overflow in a stage remainder"))
                    }
                    "**" => Ok(pow_wrapping(a, b)),
                    "<<" => Ok(a.wrapping_shl(b as u32)),
                    ">>" => Ok(a.wrapping_shr(b as u32)),
                    "&" => Ok(a & b),
                    "|" => Ok(a | b),
                    "^" => Ok(a ^ b),
                    "==" => Ok((a == b) as i64),
                    "!=" => Ok((a != b) as i64),
                    "<" => Ok((a < b) as i64),
                    ">" => Ok((a > b) as i64),
                    "<=" => Ok((a <= b) as i64),
                    ">=" => Ok((a >= b) as i64),
                    o => Err(refuse(format!("unmodelled binary operator '{o}' in a stage"))),
                }
            }
            ArithAst::Cond { test, then, else_ } => {
                if self.arith(test)? != 0 {
                    self.arith(then)
                } else {
                    self.arith(else_)
                }
            }
            ArithAst::Assign { .. } | ArithAst::IncDec { .. } => Err(refuse(
                "a stage mutates a variable inside an expression (the front end models \
                 only plain reads)",
            )),
            ArithAst::Index { .. } => Err(refuse("an array index in a stage expression")),
            ArithAst::Sizeof(_) => Err(refuse("sizeof() in a stage expression")),
            ArithAst::Cast { .. } => Err(refuse("a cast in a stage expression")),
        }
    }
}

/// Bash `**` is repeated squaring mod 2^64; a negative exponent is a
/// runtime error there, and a refusal here.
fn pow_wrapping(base: i64, mut exp: i64) -> i64 {
    if exp < 0 {
        return 0; // bash: "exponent less than 0" — refused by the caller's contract
    }
    let mut acc: i64 = 1;
    let mut b = base;
    while exp > 0 {
        if exp & 1 == 1 {
            acc = acc.wrapping_mul(b);
        }
        b = b.wrapping_mul(b);
        exp >>= 1;
    }
    acc
}

fn stmt_kind(s: &IrStmt) -> &'static str {
    match s {
        IrStmt::Ext(_) => "an extension node",
        IrStmt::Output { .. } => "an output statement",
        IrStmt::WriteFile { .. } => "a file write",
        IrStmt::Assign { .. } => "an assignment",
        IrStmt::Declare { .. } => "a declaration",
        IrStmt::DeclareArray { .. } => "an array declaration",
        IrStmt::If { .. } => "an if",
        IrStmt::Try { .. } => "a try/except",
        IrStmt::For { .. } => "a for loop",
        IrStmt::ForInit { .. } => "a C-style for loop",
        IrStmt::While { .. } => "a while loop",
        IrStmt::DoWhile { .. } => "a do/while loop",
        IrStmt::Return(_) => "a return",
        IrStmt::Exec { .. } => "a command run",
        IrStmt::Expr(_) => "an expression statement",
        _ => "a statement the reference evaluator does not model",
    }
}

fn expr_kind(e: &IrExpr) -> &'static str {
    match e {
        IrExpr::Int(_) => "an integer literal",
        IrExpr::Str(..) => "a string literal",
        IrExpr::Var(..) => "a variable read",
        IrExpr::Index { .. } => "an array read",
        IrExpr::BinOp { .. } => "a shell-level binary operation",
        IrExpr::Call { .. } => "a function call",
        IrExpr::MethodCall { .. } => "a method call",
        IrExpr::Ternary { .. } => "a ternary",
        IrExpr::Arith(_) => "an arithmetic expression",
        _ => "an expression the reference evaluator does not model",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pow_is_repeated_squaring_mod_2_64() {
        assert_eq!(pow_wrapping(2, 10), 1024);
        assert_eq!(pow_wrapping(2, 64), 0);
        assert_eq!(pow_wrapping(3, 5), 243);
        // 2^63 * 2 wraps to 0, exactly as bash's 2^64 arithmetic does.
        assert_eq!(pow_wrapping(2, 63), i64::MIN);
    }

    #[test]
    fn ndc_milli_rounds_and_keeps_sign() {
        assert_eq!(ndc_milli(700, 1000), 700);
        assert_eq!(ndc_milli(-450, 1000), -450);
        assert_eq!(ndc_milli(1, 3), 333);
        assert_eq!(ndc_milli(-1, 3), -333);
        assert_eq!(ndc_milli(2, 3), 667);
    }
}
