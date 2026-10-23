//! P2 artifact cache (docs/BASH-O4.md §4.2 step ⑨, §3 item 11).
//!
//! Layout: `<cache>/bash-o4/<hexkey>/prog.c` + `prog.exe` + `meta.json`,
//! where the key is SHA-256 over (ShIR text, opt flags, gpu mode,
//! relevant render env, toolchain id). A C hit skips re-rendering; an
//! exe hit additionally skips recompilation. The exe is exactly as fresh
//! as the C it was built from (same key — a stale binary is impossible
//! for the same reason a stale render is). Default root:
//! `$XDG_CACHE_HOME` or `~/.cache`, overridable with `--cache-dir`.
//! `BASH_O4_NO_EXE_CACHE=1` bypasses the exe layer (keeps C caching).

use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

/// Per-process temp-file discriminator.  Combined with the pid this makes
/// every cache temp path unique, which is what lets concurrent writers
/// race safely (see `cached_c`).
static TMP_SEQ: AtomicU64 = AtomicU64::new(0);

/// Resolve the cache root: explicit dir > `$XDG_CACHE_HOME` > `~/.cache`.
pub fn cache_root(explicit: Option<&str>) -> PathBuf {
    if let Some(d) = explicit.filter(|s| !s.is_empty()) {
        return PathBuf::from(d);
    }
    if let Ok(xdg) = std::env::var("XDG_CACHE_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg);
        }
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    PathBuf::from(home).join(".cache")
}

/// Render-relevant environment captured into the cache key (a render that
/// depends on these must not be reused across different values).
pub(crate) fn render_env_key() -> String {
    let keys = [
        "SH2_UU_FFI",
        "SH2_SPLIT_SETS",
        "SH2_TRANSFORMS",
        "SH2_TRUE64",
        "SH2_NO_TAKE_FIELD",
        "SH2_NO_GROWTH",
        // C-backend A/B validation switches (a render cached under one
        // value must never be served for another):
        // native operand lift (value_num_dollar / test_numeric_cmp /
        // test_value_dollar) and the Case/Select clause fn-hoist walker.
        "SH2_NO_NATIVE_LIFT",
        "SH2_CASEWALK_OFF",
        // shared numstr vars×params seeding (sh2perl shir_passes/numstr
        // → Int var_types seeds), the null-guard stable-substr copy
        // elision, the in-place string store, and the take-field
        // in-place remainder store:
        "SH2_NO_NUMSTR",
        "SH2_NO_MIXED_ABI",
        "SH2_NO_STABLE_SUBSTR",
        "SH2_NO_SSET",
        "SH2_NO_TAKE_SSET",
        // the driver-fed absorb table (which external commands lower to
        // sh2_uu_run/sh2_uu_capture instead of bash -c): the feed and its
        // kill switch both change render output, so both key the render
        // (pipeline::feed_absorb_table sets the feed BEFORE render).
        "SH2_ABSORB_CMDS",
        "SH2_NO_ABSORB",
        // ── Superset capture: EVERY other env var the render path reads
        // (audit: env::var over sh2perl/src). Policy matches parse_key's
        // doc: an extra input only costs a miss; a missing one risks a
        // stale HIT — the failure class this function exists to prevent
        // ("landing backend fixes without bumping served stale renders,
        // twice"). Includes assumption gates, pass kill switches and
        // profile inputs that change generated C…
        "SH2_ASSUME_ARITH_NATIVE",
        "SH2_ASSUME_ARITH_VARS",
        "SH2_ASSUME_ARRAY_SLICE",
        "SH2_ASSUME_CFOR",
        "SH2_ASSUME_ENV",
        "SH2_ASSUME_HOME",
        "SH2_ASSUME_I53",
        "SH2_ASSUME_INTDECL",
        "SH2_ASSUME_LOCAL_SCOPE",
        "SH2_ASSUME_NO_ENV",
        "SH2_ASSUME_OBSERVED_WIDTHS",
        "SH2_ASSUME_PARAM_DEFAULTS",
        "SH2_ASSUME_SUBSCRIPT_KEYS",
        "SH2_ASSUME_TMPDIR",
        "SH2_NO_SCANFIX",
        "SH2_NO_SPLIT_FOLD",
        "SH2_NO_ARRAY_MIGRATE",
        "SH2_NO_INT_ELEM",
        "SH2_LIST_VEC",
        "SH2_DUAL_LOOPS",
        "SH2_BC_NATIVE",
        "SH2_ARGV0",
        "SH2_LIBRARY",
        "SH2_PERL_RC_DROP",
        "SH2_TARGET_UNSET_ALL",
        "SH2_PROBE",
        "SH2_PROFILE",
        "SH2_PROFILE_IN",
        "SH2_PROFILE_WIDE",
        // …plus the diagnostic/profile-OUT gates: setting one must not
        // serve another run's cached render either (and they are never
        // set in normal runs, so they contribute a constant).
        "SH2_A1_JSON",
        "SH2_ARRAY_DEBUG",
        "SH2_TEMP_DEBUG",
        "SH2_PROFILE_OUT",
        "SH2_DEBUG_WRITE",
        "SH2_DBG_ARR",
        "SH2_DBG_BIGINT",
        "SH2_DBG_FREE",
        "SH2_DBG_HOIST",
        "SH2_DBG_PARAMS",
        "SH2_DBG_PL",
        "SH2_DBG_SO",
        "SH2_DBG_VARS",
        "SH2_DBG_VR",
        "SH2_DBG_W",
        "SH2_DEBUG_DECL",
        "SH2_DEBUG_DEMOTE",
        "SH2_DEBUG_INT_ELEM",
        "SH2_DEBUG_NUMOBS",
        "SH2_DEBUG_NUMSTR",
        "SH2_DEBUG_PARSER",
        "SH2_DEBUG_PAT",
        "SH2_DEBUG_PGFIX",
        "SH2_DEBUG_REC",
        "SH2_DEBUG_SVARS",
        "SH2_T",
    ];
    let mut parts = Vec::new();
    for k in keys {
        parts.push(format!("{k}={}", std::env::var(k).unwrap_or_default()));
    }
    parts.join(";")
}

/// Renderer revision: BUMP ON ANY RENDER-AFFECTING CHANGE (backend
/// fixes, profile mapping, new native arms). The artifact cache key
/// includes it, so fixed renders can never hide behind stale entries.
/// History: 1 = initial M1; 2 = opt-profile mirroring; 3 = true64-safe
/// default + split-temp/hoist/array fixes; 4 = LIC bound hoist;
/// 5 = let_compare arith sides; 6 = split-in-place for-in arm;
/// 7 = native numeric reads (bare `$name`/`$((…))` resolve without the
/// num_temp/atoll round trip; numeric `test` compares lift each
/// operand; test operands expand whole-`$name` words — MIMEcroft demo
/// -43% snprintf, -21% atoll); 8 = Case/Select clause vars reach the
/// fn-local hoist (case-assigned globals were undeclared) + bigint
/// const-name sign sanitization + store-read decl guard; 9 = shared
/// numstr vars×params seeding (with the GpuOp payload exemption —
/// render-loop counters like MIMEcroft's `dt_i` home to long long)
/// + null-guard stable-substr source-copy elision (drops a per-slice
/// strlen+strcpy of the whole source string); 10 = the `_sh_sset`
/// in-place string store (reuses the old buffer when the new value
/// fits instead of xstrdup+free per store); 11 = take-field blocks
/// store their field/remainder through `_sh_sset` — the remainder is
/// a suffix of the source var's own buffer, so the split loop's
/// per-token xstrdup of the whole remaining payload became one
/// in-place move (a rev bump of its own: 10 and 11 both landed after
/// shipping and change default render output).
/// (Mid-session lesson: landing backend fixes without bumping served
/// stale pre-fix renders from the cache — twice. The build-time
/// git-state rev below now covers it automatically; keep this bumped
/// too for nogit environments.)
/// 12 = per-position native ABI for void lifts: mixed
/// `long long | char *_pN` signatures (numstr-proven numeric positions
/// keep `long long` even when a sibling slot is text), the demote
/// (var, position) guard for positional-copy seeds, and the param-leg
/// upgrade of already-Str positional copies — SH2_NO_NUMSTR still
/// disables the whole seed leg.
/// 13 = string Eq/Ne renders as strcmp in the C backend: C's `==`/`!=`
/// on two `char*` compares ADDRESSES, so every shared-case-lowered
/// Exact pattern (`BinOp{Ne}(subject, Str)`) was vacuously
/// pointer-inequality — MIMEcroft's `case $lso_name in jpeg|png|…)`
/// never matched native (32px where bash picks 64), its texture cache
/// never hit, and four child-bash texture generators re-ran EVERY run
/// (87.9% of demo CPU in child bash). Both operands must be
/// certainly-text shapes (getVar/Var/Str/Interpolate/Capture/…) or the
/// numeric path stands.
///
/// rev 14: the strcmp operands are wrapped in the `_sh_sc` NULL-guard
/// helper (literals stay bare). A string-homed global read before its
/// first assignment is a NULL char*, and strcmp(NULL, s) segfaulted at
/// startup on mime-new (AVX strcmp, rdi=0, straight from main) — the
/// pointer compare this replaced was NULL-safe only by accident.
pub const RENDERER_REV: u32 = 14;

// Content-addressed at BUILD time (see build.rs): HEAD SHAs + dirt hash
// of the workspace and the sh2perl submodule. Uncommitted edits change
// the key (safe direction: miss, never stale-hit).
include!(concat!(env!("OUT_DIR"), "/pipeline_rev.rs"));

/// SHA-256 hex of bytes.
pub fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    hex_of(&h.finalize())
}

fn hex_of(digest: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(digest.len() * 2);
    for b in digest {
        s.push(HEX[(b >> 4) as usize] as char);
        s.push(HEX[(b & 15) as usize] as char);
    }
    s
}

/// Compute the artifact key for (ShIR, options, toolchain). The
/// renderer revision is folded in (see RENDERER_REV).
pub fn artifact_key(shir: &str, opts: &str, toolchain_id: &str) -> String {
    let mut h = Sha256::new();
    h.update(format!("bash-o4-cache-r{RENDERER_REV}:{PIPELINE_REV}\0").as_bytes());
    h.update(shir.as_bytes());
    h.update([0]);
    h.update(opts.as_bytes());
    h.update([0]);
    h.update(render_env_key().as_bytes());
    h.update([0]);
    h.update(toolchain_id.as_bytes());
    hex_of(&h.finalize())
}

/// A cached render: the C text plus whether it was a hit.
pub struct Cached {
    pub c_src: String,
    pub hit: bool,
    pub dir: PathBuf,
}

/// Key inputs for the ShIR (parse) layer: everything `shell_to_shir`
/// can observe — source bytes, code rev, and every env var the
/// frontend or the parse-time transforms consult. Superset by design
/// (an extra input only costs a miss; a missing one risks a stale
/// hit). Covers `render_env_key` (the gated transforms read
/// `SH2_TRANSFORMS`) plus the one-off vars transforms consult
/// (`KEEP_VARIABLES`, `SH2_T`, the `SH2C_DEBUG`/`SHIR_ECHO_DEBUG`
/// debug gates) and the frontend's workspace discovery
/// (`OTRANSPILER_ROOT`).
pub fn parse_key(source: &str) -> String {
    let mut h = Sha256::new();
    h.update(format!("bash-o4-shir-r{RENDERER_REV}:{PIPELINE_REV}\0").as_bytes());
    h.update(source.as_bytes());
    h.update([0]);
    h.update(render_env_key().as_bytes());
    h.update([0]);
    for k in [
        "KEEP_VARIABLES",
        "SH2_T",
        "SH2C_DEBUG",
        "SHIR_ECHO_DEBUG",
        "OTRANSPILER_ROOT",
    ] {
        h.update(format!("{k}={}\0", std::env::var(k).unwrap_or_default()).as_bytes());
    }
    hex_of(&h.finalize())
}

/// A cached text artifact (ShIR layer): the text plus hit flag and dir.
pub struct CachedText {
    pub text: String,
    pub hit: bool,
    pub dir: PathBuf,
}

/// Fetch-or-compute a text artifact under `<root>/bash-o4/<key>/<file>`.
/// Same atomicity/race contract as `cached_c` (unique-temp + rename;
/// the loser serves the winner's bytes). `meta_tag` labels the marker
/// (`"shir"` for the parse layer).
pub fn cached_text(
    root: &Path,
    key: &str,
    file: &str,
    meta_tag: &str,
    build: impl FnOnce() -> Result<String, String>,
) -> Result<CachedText, String> {
    let dir = root.join("bash-o4").join(key);
    let c_file = dir.join(file);
    let meta = dir.join("meta.json");
    if c_file.is_file() && meta.is_file() {
        let text =
            std::fs::read_to_string(&c_file).map_err(|e| format!("cache read: {e}"))?;
        return Ok(CachedText { text, hit: true, dir });
    }
    let text = build()?;
    std::fs::create_dir_all(&dir).map_err(|e| format!("cache mkdir: {e}"))?;
    let tmp = unique_tmp(&dir, file);
    std::fs::write(&tmp, &text).map_err(|e| format!("cache write: {e}"))?;
    if let Err(e) = std::fs::rename(&tmp, &c_file) {
        let _ = std::fs::remove_file(&tmp);
        return match std::fs::read_to_string(&c_file) {
            Ok(text) => Ok(CachedText { text, hit: true, dir }),
            Err(_) => Err(format!("cache commit: {e}")),
        };
    }
    let meta_txt = format!(
        "{{\"key\":{key:?},\"kind\":{meta_tag:?},\"sha256\":{:?},\"created\":{}}}",
        sha256_hex(text.as_bytes()),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    );
    let meta_tmp = unique_tmp(&dir, "meta.json");
    std::fs::write(&meta_tmp, meta_txt).map_err(|e| format!("cache meta: {e}"))?;
    if std::fs::rename(&meta_tmp, &meta).is_err() {
        let _ = std::fs::remove_file(&meta_tmp);
    }
    Ok(CachedText { text, hit: false, dir })
}

/// Fetch-or-store the rendered C for `shir`. `render` runs only on a miss.
pub fn cached_c(
    root: &Path,
    key: &str,
    shir: &str,
    render: impl FnOnce() -> Result<String, String>,
) -> Result<Cached, String> {
    let dir = root.join("bash-o4").join(key);
    let c_file = dir.join("prog.c");
    let meta = dir.join("meta.json");
    if c_file.is_file() && meta.is_file() {
        let c_src =
            std::fs::read_to_string(&c_file).map_err(|e| format!("cache read: {e}"))?;
        return Ok(Cached { c_src, hit: true, dir });
    }
    let c_src = render()?;
    std::fs::create_dir_all(&dir).map_err(|e| format!("cache mkdir: {e}"))?;
    // Atomic store.  The temp name MUST be unique per writer: the previous
    // shared `prog.c.tmp` let two concurrent drivers (gpu_gate runs 8 jobs,
    // each now doing several driver invocations) truncate and write the same
    // file, after which the loser's `rename` failed with ENOENT and the
    // driver exited 1 — a spurious FAIL with no miscompiled program behind
    // it.  Unique temp + "loser reads the winner" makes the race benign, and
    // the content is identical anyway (same key ⇒ same render).
    let tmp = unique_tmp(&dir, "prog.c");
    std::fs::write(&tmp, &c_src).map_err(|e| format!("cache write: {e}"))?;
    if let Err(e) = std::fs::rename(&tmp, &c_file) {
        let _ = std::fs::remove_file(&tmp);
        // Lost the race, or a filesystem without rename semantics: fall
        // back to whatever is now committed — never to an error.
        return match std::fs::read_to_string(&c_file) {
            Ok(c_src) => Ok(Cached { c_src, hit: true, dir }),
            Err(_) => Err(format!("cache commit: {e}")),
        };
    }
    let meta_txt = format!(
        "{{\"key\":{key:?},\"shir_sha256\":{:?},\"created\":{}}}",
        sha256_hex(shir.as_bytes()),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    );
    // `meta.json` is only an informational marker (and part of the hit
    // test), so it gets the same atomic treatment to avoid a reader seeing
    // a truncated marker.
    let meta_tmp = unique_tmp(&dir, "meta.json");
    std::fs::write(&meta_tmp, meta_txt).map_err(|e| format!("cache meta: {e}"))?;
    if std::fs::rename(&meta_tmp, &meta).is_err() {
        let _ = std::fs::remove_file(&meta_tmp);
    }
    Ok(Cached { c_src, hit: false, dir })
}

/// A temp path in `dir` that no other writer can be using: pid + a
/// per-process counter disambiguate concurrent processes *and* concurrent
/// threads within one process.
fn unique_tmp(dir: &Path, stem: &str) -> PathBuf {
    let n = TMP_SEQ.fetch_add(1, Ordering::Relaxed);
    dir.join(format!("{stem}.{}.{}.tmp", std::process::id(), n))
}

/// A cached executable: the path to run (JIT) or copy (AOT) plus whether
/// it was a hit.
pub struct ExeHit {
    pub path: PathBuf,
    pub hit: bool,
}

/// Present, non-empty, and executable — the whole hit test. A killed
/// writer can only leave the temp file (never the committed name —
/// publish is atomic rename), so anything failing this is rebuilt.
fn is_valid_exe(p: &Path) -> bool {
    let Ok(m) = std::fs::metadata(p) else {
        return false;
    };
    if !m.is_file() || m.len() == 0 {
        return false;
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if m.permissions().mode() & 0o111 == 0 {
            return false;
        }
    }
    true
}

/// Fetch-or-build the compiled executable for a cache entry: `prog.exe`
/// next to `prog.c`, under the same content key (ShIR + opts + env +
/// toolchain + renderer rev), so it is exactly as fresh as the cached C.
/// `build` compiles to the path it is given. Concurrent writers race
/// safely via unique-temp + rename (same pattern as `cached_c`); the
/// loser serves the winner's bytes. Returns `Err` when the layer is
/// disabled (`BASH_O4_NO_EXE_CACHE=1`) or the build/commit fails — the
/// caller then takes the uncached path (compile to a temp exe and run),
/// so a cache problem can never fail a run that would otherwise work.
pub fn cached_exe(dir: &Path, build: impl FnOnce(&Path) -> Result<(), String>) -> Result<ExeHit, String> {
    if std::env::var("BASH_O4_NO_EXE_CACHE").map(|v| v == "1").unwrap_or(false) {
        return Err("exe cache disabled".into());
    }
    let exe = dir.join("prog.exe");
    if is_valid_exe(&exe) {
        return Ok(ExeHit { path: exe, hit: true });
    }
    let tmp = unique_tmp(dir, "prog.exe");
    build(&tmp)?;
    if !is_valid_exe(&tmp) {
        let _ = std::fs::remove_file(&tmp);
        return Err("compiler produced no executable".into());
    }
    if let Err(e) = std::fs::rename(&tmp, &exe) {
        let _ = std::fs::remove_file(&tmp);
        // Lost the race: serve the winner's bytes when valid.
        if is_valid_exe(&exe) {
            return Ok(ExeHit { path: exe, hit: true });
        }
        return Err(format!("exe cache commit: {e}"));
    }
    Ok(ExeHit { path: exe, hit: false })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn concurrent_writers_never_fail_or_return_partial_content() {
        // Regression: a shared `prog.c.tmp` made parallel drivers clobber
        // each other's temp file, and the loser's rename failed (ENOENT) —
        // `bash-O4 --gpu <prog>` exited 1 with no bad program involved.
        // gpu_gate's 8-way parallelism surfaced it as a single spurious
        // FAIL that moved between files on each run.
        let root = std::env::temp_dir().join(format!("bo4-cache-race-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let want = "/* rendered */\nint main(void){return 0;}\n";
        let mut hs = Vec::new();
        for _ in 0..16 {
            let root = root.clone();
            hs.push(std::thread::spawn(move || {
                // Distinct render bodies would be a key collision; all 16
                // threads share one key on purpose, so they race.
                cached_c(&root, "deadbeef", "shir", || Ok(want.to_string()))
                    .map(|c| c.c_src)
            }));
        }
        for h in hs {
            let got = h.join().expect("thread panicked");
            assert_eq!(got.expect("cached_c must never fail on a race"), want);
        }
        // And a subsequent read is a clean hit with identical bytes.
        let again = cached_c(&root, "deadbeef", "shir", || {
            panic!("must be a cache hit")
        })
        .expect("hit");
        assert!(again.hit);
        assert_eq!(again.c_src, want);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn key_is_deterministic_and_sensitive() {
        let k1 = artifact_key("a1", "opts", "tcc");
        assert_eq!(k1, artifact_key("a1", "opts", "tcc"));
        assert_eq!(64, k1.len());
        assert_ne!(k1, artifact_key("a2", "opts", "tcc"));
        assert_ne!(k1, artifact_key("a1", "other", "tcc"));
    }

    #[test]
    fn sha256_matches_system_tool() {
        // Oracle: the system sha256sum over the same bytes.
        let out = std::process::Command::new("sha256sum")
            .arg("/bin/sh")
            .output();
        let Ok(out) = out else { return };
        if !out.status.success() {
            return;
        }
        let want = String::from_utf8_lossy(&out.stdout);
        let want = want.split_whitespace().next().unwrap_or("");
        let bytes = std::fs::read("/bin/sh").expect("read");
        assert_eq!(sha256_hex(&bytes), want);
    }

    #[test]
    fn parse_key_is_deterministic_and_source_sensitive() {
        // NOTE: no env-sensitivity test here on purpose — flipping
        // process-global env vars is unsound with parallel tests (other
        // tests read SH2_*). The folding loop above is review-verified.
        let k1 = parse_key("echo hi");
        assert_eq!(k1, parse_key("echo hi"));
        assert_eq!(64, k1.len());
        assert_ne!(k1, parse_key("echo bye"));
    }

    #[test]
    fn shir_miss_then_hit() {
        let root = std::env::temp_dir().join(format!("bo4-shir-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let mut calls = 0;
        let r1 = cached_text(&root, "k", "shir.json", "shir", || {
            calls += 1;
            Ok::<_, String>("A1".to_string())
        })
        .expect("miss");
        assert!(!r1.hit && r1.text == "A1" && calls == 1);
        let r2 = cached_text(&root, "k", "shir.json", "shir", || {
            calls += 1;
            Ok::<_, String>("A2".to_string())
        })
        .expect("hit");
        assert!(r2.hit && r2.text == "A1" && calls == 1);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn exe_miss_builds_then_hit_serves() {
        let root = std::env::temp_dir().join(format!("bo4-exe-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).expect("mkdir");
        let mut calls = 0;
        let r1 = cached_exe(&root, |dst| {
            calls += 1;
            std::fs::write(dst, b"fake-exe").map_err(|e| e.to_string())?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut p = std::fs::metadata(dst).expect("stat").permissions();
                p.set_mode(0o755);
                std::fs::set_permissions(dst, p).expect("chmod");
            }
            Ok(())
        })
        .expect("miss builds");
        assert!(!r1.hit && calls == 1);
        let r2 = cached_exe(&root, |_| {
            calls += 1;
            Ok(())
        })
        .expect("hit");
        assert!(r2.hit && calls == 1);
        assert_eq!(r2.path, r1.path);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn exe_empty_file_rebuilds() {
        // A killed writer's leftover (or any corruption): zero-length or
        // non-executable files are misses, never served.
        let root = std::env::temp_dir().join(format!("bo4-exe-empty-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(&root).expect("mkdir");
        std::fs::write(root.join("prog.exe"), b"").expect("write");
        let mut calls = 0;
        let r = cached_exe(&root, |dst| {
            calls += 1;
            std::fs::write(dst, b"x").map_err(|e| e.to_string())?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut p = std::fs::metadata(dst).expect("stat").permissions();
                p.set_mode(0o755);
                std::fs::set_permissions(dst, p).expect("chmod");
            }
            Ok(())
        })
        .expect("rebuild");
        assert!(!r.hit && calls == 1);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn cache_miss_then_hit() {
        let root = std::env::temp_dir().join(format!("bo4test{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let mut calls = 0;
        let r1 = cached_c(&root, "k", "shir", || {
            calls += 1;
            Ok::<_, String>("C1".to_string())
        })
        .expect("miss");
        assert!(!r1.hit && r1.c_src == "C1" && calls == 1);
        let r2 = cached_c(&root, "k", "shir", || {
            calls += 1;
            Ok::<_, String>("C2".to_string())
        })
        .expect("hit");
        assert!(r2.hit && r2.c_src == "C1" && calls == 1);
        let _ = std::fs::remove_dir_all(&root);
    }
}
