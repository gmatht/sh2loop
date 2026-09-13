//! P2 artifact cache (docs/BASH-O4.md §4.2 step ⑨, §3 item 11).
//!
//! Layout: `<cache>/bash-o4/<hexkey>/prog.c` + `meta.json`, where the key
//! is SHA-256 over (ShIR text, opt flags, gpu mode, relevant render env,
//! toolchain id). A hit skips re-rendering (compilation itself stays
//! millisecond-scale and always re-runs, so stale binaries are
//! impossible). Default root: `$XDG_CACHE_HOME` or `~/.cache`,
//! overridable with `--cache-dir`.

use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

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
fn render_env_key() -> String {
    let keys = ["SH2_UU_FFI", "SH2_SPLIT_SETS", "SH2_TRANSFORMS", "SH2_TRUE64"];
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
/// default + split-temp/hoist/array fixes.
pub const RENDERER_REV: u32 = 3;

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
    h.update(format!("bash-o4-cache-r{RENDERER_REV}\0").as_bytes());
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
    // Atomic store: temp file + rename (concurrent gates must never read
    // a half-written prog.c).
    let tmp = dir.join("prog.c.tmp");
    std::fs::write(&tmp, &c_src).map_err(|e| format!("cache write: {e}"))?;
    std::fs::rename(&tmp, &c_file).map_err(|e| format!("cache commit: {e}"))?;
    let meta_txt = format!(
        "{{\"key\":{key:?},\"shir_sha256\":{:?},\"created\":{}}}",
        sha256_hex(shir.as_bytes()),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0)
    );
    std::fs::write(&meta, meta_txt).map_err(|e| format!("cache meta: {e}"))?;
    Ok(Cached { c_src, hit: false, dir })
}

#[cfg(test)]
mod tests {
    use super::*;

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
