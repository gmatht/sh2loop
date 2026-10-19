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
///
/// - `O0` → faithful preset; `O3`/`O4` → speed preset (dual loops,
///   slots, split-sets); everything else → the CLI no-flag default.
///
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
    // Worktree-local shIR->shIR speed win (no shared-core edits):
    // generalise the JS-only `compile()` LICM-lite to the C path.
    // `shir_passes::loop_opt::hoist_loop_invariants` (leading pure +
    // invariant run -> loop prologue; renderer-agnostic, fixpoint,
    // idempotent) runs for JS via `otranspilerl::compile` but nothing
    // on the C path calls it (`ingest` runs restructure/strip/fold only;
    // the older `hoist-loop-invariants` registry transform fires only on
    // top-level loops, missing the function-internal `rb_tri` x/y nest
    // where the game burns per-pixel slot-loads). Run it here on the A1
    // before render. O3/O4 only, so Og/O0 stay byte-identical to the CLI
    // (the `emit_c_matches_otranspilerl_cli` contract); `SH2_NO_LOOP_OPT=1`
    // kills it (validation, like `SH2_NO_INT_ELEM=1`); ingress failure
    // falls back to the unmodified A1 so a transform problem can never
    // fail a render that would otherwise work.
    let hoisted: Option<String> = if (opt_level == "O3" || opt_level == "O4")
        && std::env::var("SH2_NO_LOOP_OPT").as_deref() != Ok("1")
    {
        match debashl::shir_json_in::shir_json_to_ir(a1) {
            Ok(mut prog) => {
                let hoisted = debashl::shir_passes::loop_opt::hoist_loop_invariants(&mut prog);
                // Scalar copy-cycle Int seeding (worktree-local): vars
                // whose assigns are all int-valued under transparent-copy
                // semantics (the rb_tri swap cycle rbt_x1=$rbt_x2/$rbt_t,
                // the loop bounds, the shade, the fragment bridge) home as
                // `long long` so the per-pixel nest does direct integer
                // loads instead of snprintf/strdup/atoll per access. Only
                // proposes (demote_stringy_ints re-validates at C ingest),
                // same O3/O4 gate and graceful-degradation contract as the
                // hoist above.
                let seeded = crate::int_cycles::seed_int_cycles(&mut prog);
                // Trivial word-split elimination (shared shIR→shIR,
                // `shir_passes::split_fold`): `split[e] → e` when `e` is
                // provably IFS-whitespace-free (Int-typed / no-space-
                // tagged vars, numeric exprs, spaceless literals) and the
                // program may not set a custom IFS. The C renderer then
                // reads such args natively through its ordinary arms
                // instead of stringifying them and parsing the buffer
                // back (the atoll round trips in value_ll). Off with
                // SH2_NO_SPLIT_FOLD=1 (validation, like the hoist's
                // SH2_NO_LOOP_OPT), same graceful-degradation contract.
                let folded = std::env::var("SH2_NO_SPLIT_FOLD").as_deref() != Ok("1")
                    && debashl::shir_passes::split_fold::fold_trivial_splits(&mut prog);
                if hoisted || seeded || folded {
                    Some(debashl::shir_json::shir_to_shir_json(&prog))
                } else {
                    None
                }
            }
            Err(_) => None,
        }
    } else {
        None
    };
    let a1_ref = hoisted.as_deref().unwrap_or(a1);
    otranspilerl::render(a1_ref, "c")
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
