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
    otranspilerl::shell_to_shir(source)
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
}
