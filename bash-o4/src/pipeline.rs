//! M1 pipeline: bash source → ShIR A1 (+A2) → C source.
//!
//! Reuses the exact CLI pipeline (`otranspilerl::shell_to_shir` +
//! `otranspilerl::render(_, "c")` with the `c` transform target set), so
//! `bash-O4 --emit-c` output is byte-identical to
//! `otranspilerl-cli --target c`. No fork of core logic.

use std::path::Path;

/// Read a shell source file. Byte-preserving decode: valid UTF-8 passes
/// through; each invalid byte becomes a U+F800+byte PUA marker — EXACTLY
/// the `read_source` decode in `otranspilerl/src/lib.rs` (which the C
/// backend's raw-byte re-emission expects; plain `from_utf8_lossy`
/// U+FFFD replacement corrupted `utf8-non-utf8-content.sh`). The decode
/// is replicated (not called) because that function is private and
/// carries a literal-source fallback bash-O4 must not inherit (a missing
/// program file is always an error here).
pub fn read_source(path: &Path) -> Result<String, String> {
    let bytes =
        std::fs::read(path).map_err(|e| format!("cannot read {}: {e}", path.display()))?;
    Ok(decode_bytes(&bytes))
}

/// Byte-preserving decode (mirror of otranspilerl's `read_source`).
fn decode_bytes(bytes: &[u8]) -> String {
    match String::from_utf8(bytes.to_vec()) {
        Ok(s) => s,
        Err(_) => bytes
            .iter()
            .map(|&b| {
                if b < 0x80 {
                    b as char
                } else {
                    char::from_u32(0xF800 + b as u32).unwrap_or('\u{FFFD}')
                }
            })
            .collect(),
    }
}

/// Parse bash source to ShIR A1 JSON (with A2 annotations attached).
pub fn parse_to_shir(source: &str) -> String {
    // The C target must be selected BEFORE parsing, not at render time:
    // `transforms::apply` runs inside `shell_to_shir`, so a target set
    // only in `render_c_with` arrives after every target-gated transform
    // (fbdev-gpu-calls, text-ops-planner) has already been skipped.
    debashl::transforms::set_target(Some("c"));
    otranspilerl::shell_to_shir(source)
}

/// Parse with the ShIR layer cache: same text, but a repeat run serves
/// the stored A1 instead of re-parsing (~8 s for a game-sized script).
/// Falls back to direct parse when the cache is unusable, so a cache
/// problem can never fail a run that would otherwise work. The key
/// (`cache::parse_key`) folds the source bytes, the code rev, and every
/// env var the frontend/transforms consult.
pub fn parse_to_shir_cached(source: &str, cache_root: &std::path::Path) -> (String, bool) {
    let key = crate::cache::parse_key(source);
    match crate::cache::cached_text(cache_root, &key, "shir.json", "shir", || {
        Ok(parse_to_shir(source))
    }) {
        Ok(t) => (t.text, t.hit),
        Err(_) => (parse_to_shir(source), false),
    }
}

/// Render A1 JSON to C. Mirrors the CLI's `c` target exactly: transform
/// target selection PLUS the opt-profile globals `cli()` sets (without
/// them the render silently differs — e.g. split-set handling of `$1`
/// `$2` — breaking the byte-identical-to-CLI contract).
///
/// v1 profile mapping (behavior firewall: levels never change stdout or
/// exit codes; the level only selects the CLI's documented preset and is
/// recorded in the cache key):
/// - `O0` → faithful preset; `O3`/`O4` → speed preset (dual loops,
///   slots, split-sets); everything else → the CLI no-flag default.
/// Arithmetic is true-64-bit by DEFAULT (safe): `set_true64(true)`
/// unless explicitly opted out (`--no-true64` / `$SH2_TRUE64=0`). The
/// `false` setting is an unsafe optimisation (silently wrong past
/// ±2^53 on paths that consult it) and is never the default here.
/// An explicit `true64` override wins, exactly like `--true64`.
pub fn render_c(a1: &str) -> Result<String, String> {
    render_c_with(a1, "Og", None)
}

/// `render_c` with an explicit `-O` level and `--true64` override.
pub fn render_c_with(a1: &str, opt_level: &str, true64: Option<bool>) -> Result<String, String> {
    debashl::transforms::set_target(Some("c"));
    match opt_level {
        "O0" => {
            debashl::shir::set_true64(true);
            debashl::shir::set_dual_loops(Some(false));
            debashl::shir::set_slots_enabled(false);
            debashl::shir::set_split_sets(Some(false));
        }
        "O3" | "O4" => {
            // NOTE: the CLI's -O3 sets true64(false); bash-O4 keeps
            // true64(true) — false is an unsafe optimisation.
            debashl::shir::set_true64(true);
            debashl::shir::set_dual_loops(Some(true));
            debashl::shir::set_slots_enabled(true);
            debashl::shir::set_split_sets(Some(true));
        }
        _ => {
            // Safe default: true 64-bit unless explicitly opted out.
            let t64 = std::env::var("SH2_TRUE64").map(|v| v != "0").unwrap_or(true);
            debashl::shir::set_true64(t64);
            debashl::shir::set_dual_loops(Some(false));
            debashl::shir::set_slots_enabled(false);
            debashl::shir::set_split_sets(Some(false));
        }
    }
    if let Some(t) = true64 {
        debashl::shir::set_true64(t);
    }
    otranspilerl::render(a1, "c")
}

/// Full M1 codegen: file → C source. Returns (a1_json, c_source).
pub fn file_to_c(path: &Path) -> Result<(String, String), String> {
    let src = read_source(path)?;
    let a1 = parse_to_shir(&src);
    let c = render_c(&a1)?;
    Ok((a1, c))
}

/// Parse A1 JSON back into a typed program (for candidacy / inspection).
pub fn parse_program(a1: &str) -> Result<debashl::ir::IrProgram, String> {
    debashl::shir_json_in::shir_json_to_ir(a1)
}

/// Candidate discovery + table feed for the C backend's absorb table
/// (which external commands lower to `sh2_uu_run`/`sh2_uu_capture`
/// instead of a fork/exec `bash -c`; `c_backend::UU_BUILTIN_CMDS` is the
/// always-on base). Runs on the A1 the compile already holds — no
/// re-parse — collects the statically-NAMED commands from exec/capture
/// sites, bounds them by the built `.so`'s availability stamp
/// (`runtime/build_uu_ffi.sh --ensure` grows the helper only when the
/// request exceeds the stamp, and is a cached no-op otherwise; an
/// uncompiled util is rc 127 at runtime per uu_ffi.h, so an UNCOVERED
/// name is never fed), and publishes the extras (covered − builtin) as
/// `SH2_ABSORB_CMDS` — the renderer unions them onto its builtin set, so
/// an empty feed changes nothing and a discovery miss can only fail to
/// WIDEN, never to shrink. `SH2_NO_ABSORB=1` short-circuits the whole
/// driver side (and the render kill switch ignores the feed too).
/// Returns the fed extras for verbose logging; the feed is keyed into
/// the render cache via `cache::render_env_key`.
pub fn feed_absorb_table(a1: &str) -> Vec<String> {
    if std::env::var("SH2_NO_ABSORB").is_ok() {
        return Vec::new();
    }
    let prog = match parse_program(a1) {
        Ok(p) => p,
        Err(_) => return Vec::new(),
    };
    let mut cands: std::collections::BTreeSet<String> = Default::default();
    let mut defs: std::collections::BTreeSet<String> = Default::default();
    collect_absorb_candidates(&prog.stmts, &mut cands, &mut defs);
    // Script-defined functions are NOT absorb candidates: bash resolves
    // them before any external command of the same name (the renderer's
    // `_ if self.functions.contains(&cmd)` arm also precedes the uu
    // fallback), so a def'd name can never reach the uu path — and
    // asking `--ensure` to grow the `.so` for `draw_text`-style names
    // would be a doomed build request on every compile.
    cands.retain(|c| !defs.contains(c));
    // Bare simple names only: a path form (`/bin/ls`) never matched the
    // builtin set and keeps its shell site (refuse > guess).
    cands.retain(|c| {
        !c.is_empty()
            && c
                .chars()
                .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '_' | '.' | '-' | '+'))
    });
    if cands.is_empty() {
        return Vec::new();
    }
    let sp = match crate::tcc::find_sh2perl() {
        Ok(p) => p,
        Err(_) => return Vec::new(),
    };
    let stamp_path = sp.join("runtime").join("lib").join("uu-ffi.features");
    // No stamp → nothing has established what the built `.so`
    // dispatches: feed nothing (availability is never guessed).
    let mut avail: std::collections::BTreeSet<String> =
        match std::fs::read_to_string(&stamp_path) {
            Ok(s) => s.split_whitespace().map(str::to_string).collect(),
            Err(_) => return Vec::new(),
        };
    if !cands.iter().all(|c| avail.contains(c)) {
        // Helper build (CACHED): --ensure rebuilds only when the request
        // exceeds the stamp, then rewrites the stamp file. We re-read the
        // STAMP afterwards — never parse the command's stdout, which on a
        // real (non-cached) grow is the full cargo build log. A refusal
        // (crate unavailable / undeclared feature) is data: the stamp then
        // still bounds the feed to what the `.so` dispatches.
        let _ = std::process::Command::new("bash")
            .arg(sp.join("runtime").join("build_uu_ffi.sh"))
            .arg("--ensure")
            .arg(cands.iter().cloned().collect::<Vec<_>>().join(" "))
            .output();
        if let Ok(s) = std::fs::read_to_string(&stamp_path) {
            let grown: std::collections::BTreeSet<String> =
                s.split_whitespace().map(str::to_string).collect();
            if !grown.is_empty() {
                avail = grown;
            }
        }
    }
    let extras: Vec<String> = cands
        .iter()
        .filter(|c| avail.contains(*c))
        .filter(|c| !debashl::c_backend::UU_BUILTIN_CMDS.contains(&c.as_str()))
        .cloned()
        .collect();
    if extras.is_empty() {
        return Vec::new();
    }
    // SAFETY: every extra is confirmed present in the stamp above, so the
    // absorbed call can never hit an uncompiled util (rc 127) at runtime.
    std::env::set_var("SH2_ABSORB_CMDS", extras.join(","));
    extras
}

/// Static command names reachable from exec/capture sites — the absorb
/// table's candidate set (`out`) — plus every script-defined function
/// name (`defs`), which the caller subtracts (a def shadows an external
/// command of the same name, so it can never be an absorb site).
/// Conservative recursion over the statement containers and expression
/// carriers; anything not walked is simply not discovered, which can
/// only fail to WIDEN the feed (the builtin union keeps its absorption),
/// never to widen it wrongly.
fn collect_absorb_candidates(
    stmts: &[debashl::ir::IrStmt],
    out: &mut std::collections::BTreeSet<String>,
    defs: &mut std::collections::BTreeSet<String>,
) {
    use debashl::ir::{IrExpr, IrStmt};
    fn expr(e: &IrExpr, out: &mut std::collections::BTreeSet<String>) {
        match e {
            IrExpr::Call { func, args } => {
                if matches!(func.as_str(), "exec" | "builtin" | "capture" | "captureWords") {
                    if let Some(IrExpr::Str(c, _)) = args.first() {
                        out.insert(c.clone());
                    }
                }
                for a in args {
                    expr(a, out);
                }
            }
            IrExpr::Array(items) => {
                for i in items {
                    expr(i, out);
                }
            }
            IrExpr::BinOp { lhs, rhs, .. } => {
                expr(lhs, out);
                expr(rhs, out);
            }
            IrExpr::Interpolate(parts) => {
                for p in parts {
                    if let debashl::ir::InterpPart::Expr(x) = p {
                        expr(x, out);
                    }
                }
            }
            _ => {}
        }
    }
    fn expr_opt(e: Option<&IrExpr>, out: &mut std::collections::BTreeSet<String>) {
        if let Some(e) = e {
            expr(e, out);
        }
    }
    for s in stmts {
        match s {
            IrStmt::Exec { cmd, args, .. } => {
                expr(cmd, out);
                for a in args {
                    expr(a, out);
                }
            }
            IrStmt::Expr(e) | IrStmt::Output { value: e, .. } => expr(e, out),
            IrStmt::Assign { expr: e, .. } => expr(e, out),
            IrStmt::Declare { init, .. } => expr_opt(init.as_ref(), out),
            IrStmt::If {
                cond,
                then,
                elsifs,
                else_,
            } => {
                expr(cond, out);
                collect_absorb_candidates(then, out, defs);
                for (c, b) in elsifs {
                    expr(c, out);
                    collect_absorb_candidates(b, out, defs);
                }
                collect_absorb_candidates(else_, out, defs);
            }
            IrStmt::While { cond, body } | IrStmt::DoWhile { cond, body, .. } => {
                expr(cond, out);
                collect_absorb_candidates(body, out, defs);
            }
            IrStmt::For { iter, body, .. } => {
                expr(iter, out);
                collect_absorb_candidates(body, out, defs);
            }
            IrStmt::ForInit {
                init,
                cond,
                step,
                body,
            } => {
                collect_absorb_candidates(init, out, defs);
                expr(cond, out);
                collect_absorb_candidates(step, out, defs);
                collect_absorb_candidates(body, out, defs);
            }
            IrStmt::Block(b) | IrStmt::Subshell(b) | IrStmt::Background(b) => {
                collect_absorb_candidates(b, out, defs)
            }
            IrStmt::Function { name, body, .. } => {
                // A defined function shadows any external command of the
                // same name — record it so the caller can subtract it.
                defs.insert(name.clone());
                collect_absorb_candidates(body, out, defs)
            }
            IrStmt::Case {
                discriminant,
                clauses,
            } => {
                expr(discriminant, out);
                for c in clauses {
                    collect_absorb_candidates(&c.body, out, defs);
                }
            }
            IrStmt::Select { clauses } => {
                for c in clauses {
                    collect_absorb_candidates(&c.body, out, defs);
                }
            }
            IrStmt::Redirect { inner, .. } => collect_absorb_candidates(inner, out, defs),
            IrStmt::Pipeline { stages, .. } => {
                for stage in stages {
                    collect_absorb_candidates(stage, out, defs);
                }
            }
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn emit_c_matches_otranspilerl_cli() {
        // The M1 contract: identical C to the reference CLI path.
        let src = "#!/bin/bash\necho hello $1\nexit 3\n";
        let a1 = parse_to_shir(src);
        let via_lib = render_c(&a1).expect("render");
        debashl::transforms::set_target(Some("c"));
        let via_render = otranspilerl::render(&a1, "c").expect("render2");
        assert_eq!(via_lib, via_render);
        assert!(via_lib.contains("hello"), "program text survives:\n{via_lib}");
    }

    #[test]
    fn render_keeps_all_positionals() {
        // Regression pin: without the CLI's opt-profile globals the
        // render silently dropped `$2` (split-set state). Both argv
        // slots must survive.
        let src = "#!/bin/bash\necho hello $1 $2\n";
        let a1 = parse_to_shir(src);
        let c = render_c(&a1).expect("render");
        assert!(c.contains("_sh_argv[1]"), "lost $1:\n{c}");
        assert!(c.contains("_sh_argv[2]"), "lost $2:\n{c}");
    }

    #[test]
    fn parse_program_round_trips() {
        let a1 = parse_to_shir("#!/bin/bash\nx=1\necho $x\n");
        let prog = parse_program(&a1).expect("ingress");
        assert!(!prog.stmts.is_empty());
    }

    #[test]
    fn absorb_candidates_cover_function_bodies_and_exclude_defs() {
        // Discovery must reach exec sites INSIDE function bodies (most
        // of a real script's commands live there), and must record the
        // script's own function names for subtraction: bash resolves a
        // defined function before any external command of the same name
        // (the renderer's `functions.contains(&cmd)` arm likewise
        // precedes the uu fallback), so a def'd name can never be an
        // absorb site — feeding one to build_uu_ffi.sh --ensure would
        // be a doomed grow request on every compile.
        let src = "#!/bin/bash\nhelper() { cut -d, -f1 data.csv; }\nhelper\nls -l data.csv\n";
        let a1 = parse_to_shir(src);
        let prog = parse_program(&a1).expect("ingress");
        let mut cands: std::collections::BTreeSet<String> = Default::default();
        let mut defs: std::collections::BTreeSet<String> = Default::default();
        collect_absorb_candidates(&prog.stmts, &mut cands, &mut defs);
        assert!(cands.contains("cut"), "function-body site discovered: {cands:?}");
        assert!(cands.contains("ls"), "top-level site discovered: {cands:?}");
        assert!(defs.contains("helper"), "def name recorded: {defs:?}");
        cands.retain(|c| !defs.contains(c));
        assert!(!cands.contains("helper"), "def'd name subtracted: {cands:?}");
    }

    #[test]
    fn string_case_pattern_compares_by_content_not_pointer() {
        // Regression pin (RENDERER_REV 13): the shared case lowering
        // feeds `BinOp{Ne}(subject, Str)` for Exact patterns, and C's
        // `!=` on two `char*` compares ADDRESSES — always unequal — so
        // `case $v in jpeg)` NEVER matched in native while `*)`
        // caught everything. Measured on MIMEcroft: the 64px size arm
        // never fired, the texture cache keys could never hit, and four
        // child-bash texture generators re-ran every run (87.9% of demo
        // CPU). The C backend must render a string Ne as strcmp.
        let src = "#!/bin/bash\nf() { case $1 in jpeg) echo SIXTYFOUR;; *) echo other;; esac; }\nf jpeg\nf stone\n";
        let a1 = parse_to_shir(src);
        let c = render_c(&a1).expect("render");
        assert!(
            !c.contains("!= \"jpeg\"") && !c.contains("== \"jpeg\""),
            "string literal compared by POINTER (must be strcmp/fnmatch):\n{c}"
        );
        assert!(
            c.contains("strcmp(") || c.contains("fnmatch("),
            "no content-compare primitive in the render:\n{c}"
        );
    }
}
