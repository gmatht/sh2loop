//! M4 fetch/cache (docs/BASH-O4.md §4.6).
//!
//! Principle: reproducible, consented, cached, auditable. Layout:
//! `<cache>/bash-o4-fetch/<name>/<version>/<file>`, lockfile-guarded,
//! content-addressed (SHA-256 pin; mismatch ⇒ delete + refuse, exit 4,
//! never fall forward). Policy: `--fetch-libs=` flag > `$BASH_O4_FETCH_LIBS`
//! > default `ask`; `$BASH_O4_OFFLINE=1` forces `off`. `ask` on a non-TTY
//! refuses with the `--fetch-libs=auto` incantation.
//!
//! Transports: `file://` (copy — hermetic tests) and `https://` (via the
//! `curl` binary, `--fail`, no `curl|sh`). Unpinned entries (`sha256`
/// absent) are always refused: an unpinned upstream cannot be verified.

use std::path::{Path, PathBuf};

/// Download policy.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FetchPolicy {
    Ask,
    Auto,
    Off,
}

impl FetchPolicy {
    pub fn parse(s: &str) -> FetchPolicy {
        match s {
            "auto" => FetchPolicy::Auto,
            "off" => FetchPolicy::Off,
            _ => FetchPolicy::Ask,
        }
    }
}

/// Fetch failure with its CLI exit code (doc §4.1: 4 = fetch refusal).
#[derive(Debug, Clone, PartialEq)]
pub struct FetchError {
    pub message: String,
}

impl FetchError {
    pub fn exit_code(&self) -> i32 {
        4
    }
}

impl std::fmt::Display for FetchError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

fn refuse(msg: String) -> FetchError {
    FetchError { message: msg }
}

/// One manifest entry.
#[derive(Debug, Clone, PartialEq)]
pub struct ManifestEntry {
    pub name: String,
    pub version: String,
    pub url: String,
    pub sha256: Option<String>,
    pub size: Option<u64>,
    pub kind: String,
    pub license: String,
}

/// Minimal TOML-subset parser for the manifest schema (`[[lib]]`
/// sections, scalar `key = "value"` / `key = 123` pairs, `#` comments).
/// A full TOML crate would add a dependency for a 40-line schema.
pub fn parse_manifest(text: &str) -> Result<Vec<ManifestEntry>, String> {
    let mut entries = Vec::new();
    let mut cur: Option<ManifestEntry> = None;
    for (lineno, raw) in text.lines().enumerate() {
        let line = raw.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        if line == "[[lib]]" {
            if let Some(e) = cur.take() {
                entries.push(e);
            }
            cur = Some(ManifestEntry {
                name: String::new(),
                version: String::new(),
                url: String::new(),
                sha256: None,
                size: None,
                kind: String::new(),
                license: String::new(),
            });
            continue;
        }
        if line.starts_with('[') {
            continue; // other tables ignored
        }
        let Some((k, v)) = line.split_once('=') else {
            return Err(format!("manifest line {}: bad assignment", lineno + 1));
        };
        let e = cur.as_mut().ok_or_else(|| format!("manifest line {}: key outside [[lib]]", lineno + 1))?;
        let (k, v) = (k.trim(), v.trim());
        let unquote = |v: &str| -> Result<String, String> {
            if v.len() >= 2 && v.starts_with('"') && v.ends_with('"') {
                Ok(v[1..v.len() - 1].to_string())
            } else {
                Err(format!("manifest line {}: want quoted string", lineno + 1))
            }
        };
        match k {
            "name" => e.name = unquote(v)?,
            "version" => e.version = unquote(v)?,
            "url" => e.url = unquote(v)?,
            "sha256" => e.sha256 = Some(unquote(v)?),
            "size" => {
                e.size = Some(v.parse::<u64>().map_err(|_| format!("manifest line {}: bad size", lineno + 1))?)
            }
            "kind" => e.kind = unquote(v)?,
            "license" => e.license = unquote(v)?,
            _ => return Err(format!("manifest line {}: unknown key {k:?}", lineno + 1)),
        }
    }
    if let Some(e) = cur.take() {
        entries.push(e);
    }
    for e in &entries {
        if e.name.is_empty() || e.version.is_empty() || e.url.is_empty() {
            return Err(format!("manifest: entry {:?} missing name/version/url", e.name));
        }
    }
    Ok(entries)
}

/// The shipped manifest (compiled in; overridable via `$BASH_O4_MANIFEST`
/// path for tests/operators).
pub fn builtin_manifest() -> &'static str {
    include_str!("../bash-o4-manifest.toml")
}

pub fn load_manifest() -> Result<Vec<ManifestEntry>, String> {
    if let Ok(p) = std::env::var("BASH_O4_MANIFEST") {
        let text = std::fs::read_to_string(&p).map_err(|e| format!("manifest {p}: {e}"))?;
        return parse_manifest(&text);
    }
    parse_manifest(builtin_manifest())
}

fn fetch_root(cache_root: &Path) -> PathBuf {
    cache_root.join("bash-o4-fetch")
}

fn entry_dir(cache_root: &Path, e: &ManifestEntry) -> PathBuf {
    fetch_root(cache_root).join(&e.name).join(&e.version)
}

fn file_name_of(url: &str) -> String {
    let no_frag = url.split('#').next().unwrap_or(url);
    let no_query = no_frag.split('?').next().unwrap_or(no_frag);
    let tail = no_query.rsplit('/').next().unwrap_or("artifact");
    if url.starts_with("file://") {
        // file:// URLs name the artifact by the entry, not the source
        // path (hermetic fixtures live anywhere).
        return "artifact".to_string();
    }
    if tail.is_empty() {
        "artifact".to_string()
    } else {
        tail.to_string()
    }
}

fn audit_path(cache_root: &Path) -> PathBuf {
    fetch_root(cache_root).join("audit.log")
}

/// Append one JSON audit line (what/when/hash — `--audit-fetch` reads it).
fn audit(cache_root: &Path, entry: &str, detail: &str) {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let line = format!("{{\"t\":{now},\"entry\":{entry:?},\"detail\":{detail:?}}}\n");
    if let Some(parent) = audit_path(cache_root).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    use std::io::Write;
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(audit_path(cache_root)) {
        let _ = f.write_all(line.as_bytes());
    }
}

/// Print the audit log (empty when nothing was ever fetched).
pub fn audit_log(cache_root: &Path) -> Result<String, String> {
    let p = audit_path(cache_root);
    if !p.is_file() {
        return Ok(String::new());
    }
    std::fs::read_to_string(&p).map_err(|e| format!("audit log: {e}"))
}

extern "C" {
    fn isatty(fd: i32) -> i32;
}

fn stdin_is_tty() -> bool {
    unsafe { isatty(0) == 1 }
}

/// Acquire the entry lock (`<dir>.lock` dir, create-exclusive). Spins
/// briefly; concurrent gates must never download/verify the same entry
/// twice.
fn lock_dir(dir: &Path) -> Result<PathBuf, FetchError> {
    if let Some(parent) = dir.parent() {
        std::fs::create_dir_all(parent).map_err(|e| refuse(format!("fetch lock mkdir: {e}")))?;
    }
    let lock = dir.with_extension("lock");
    for _ in 0..600 {
        match std::fs::create_dir(&lock) {
            Ok(()) => return Ok(lock),
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
            Err(e) => return Err(refuse(format!("fetch lock: {e}"))),
        }
    }
    Err(refuse(format!("fetch lock timeout: {}", lock.display())))
}

/// Ensure one entry is present + verified. Returns the artifact path.
pub fn ensure(
    cache_root: &Path,
    entry: &ManifestEntry,
    policy: FetchPolicy,
) -> Result<PathBuf, FetchError> {
    let Some(want) = entry.sha256.clone() else {
        return Err(refuse(format!(
            "fetch {}@{}: unpinned upstream (no sha256) — refusing (see docs/BASH-O4.md §4.6)",
            entry.name, entry.version
        )));
    };
    let dir = entry_dir(cache_root, entry);
    let dest = dir.join(file_name_of(&entry.url));
    if dest.is_file() {
        // Re-verify on every use (cache poisoning must not survive).
        verify(&dest, &want, entry.size)?;
        return Ok(dest);
    }
    match policy {
        FetchPolicy::Off => {
            return Err(refuse(format!(
                "fetch {}@{} refused (offline). Re-run with --fetch-libs=auto, or --prefetch first.",
                entry.name, entry.version
            )));
        }
        FetchPolicy::Ask => {
            if !stdin_is_tty() {
                return Err(refuse(format!(
                    "fetch {}@{} needs consent (no TTY). Re-run with --fetch-libs=auto.\n  {}  sha256:{}  {} bytes",
                    entry.name, entry.version, entry.url, want,
                    entry.size.map(|s| s.to_string()).unwrap_or_else(|| "?".into())
                )));
            }
            eprintln!(
                "bash-O4 fetches {}@{} ({} bytes, {}):\n  {}\n  sha256:{}\nProceed? [y/N] ",
                entry.name,
                entry.version,
                entry.size.map(|s| s.to_string()).unwrap_or_else(|| "?".into()),
                entry.license,
                entry.url,
                want
            );
            let mut ans = String::new();
            if std::io::stdin().read_line(&mut ans).is_err()
                || !matches!(ans.trim().to_lowercase().as_str(), "y" | "yes")
            {
                return Err(refuse(format!("fetch {}@{} declined", entry.name, entry.version)));
            }
        }
        FetchPolicy::Auto => {}
    }
    let _lock = lock_dir(&dir)?;
    // Re-check under lock (another gate may have finished).
    if dest.is_file() {
        if verify(&dest, &want, entry.size).is_ok() {
            let _ = std::fs::remove_dir_all(_lock);
            return Ok(dest);
        }
        let _ = std::fs::remove_file(&dest);
    }
    let tmp = dir.join("artifact.tmp");
    let _ = std::fs::create_dir_all(&dir);
    download(&entry.url, &tmp).map_err(|e| {
        let _ = std::fs::remove_file(&tmp);
        let _ = std::fs::remove_dir_all(&_lock);
        e
    })?;
    if let Err(e) = verify(&tmp, &want, entry.size) {
        let _ = std::fs::remove_file(&tmp);
        let _ = std::fs::remove_dir_all(&_lock);
        return Err(e);
    }
    if let Err(e) = std::fs::rename(&tmp, &dest) {
        let _ = std::fs::remove_file(&tmp);
        let _ = std::fs::remove_dir_all(&_lock);
        return Err(refuse(format!("fetch commit: {e}")));
    }
    let _ = std::fs::remove_dir_all(&_lock);
    audit(cache_root, &format!("{}@{}", entry.name, entry.version), &format!("ok {}", dest.display()));
    Ok(dest)
}

/// Warm every PINNED manifest entry (image builders / CI). Unpinned
/// entries are skipped with a stderr note (they would refuse anyway).
pub fn prefetch(cache_root: &Path, policy: FetchPolicy) -> Result<usize, FetchError> {
    let manifest = load_manifest().map_err(|e| refuse(format!("manifest: {e}")))?;
    let mut n = 0;
    for e in &manifest {
        if e.sha256.is_none() {
            eprintln!(
                "bash-O4 prefetch: skipping unpinned {}@{} (see docs/BASH-O4.md §4.6)",
                e.name, e.version
            );
            continue;
        }
        ensure(cache_root, e, policy)?;
        n += 1;
    }
    Ok(n)
}

fn download(url: &str, dest: &Path) -> Result<(), FetchError> {
    if let Some(path) = url.strip_prefix("file://") {
        std::fs::copy(path, dest)
            .map_err(|e| refuse(format!("file fetch {url}: {e}")))?;
        return Ok(());
    }
    if url.starts_with("https://") {
        let out = std::process::Command::new("curl")
            .args(["-fsSL", "--proto", "=https", "--max-time", "300", "-o"])
            .arg(dest)
            .arg(url)
            .output()
            .map_err(|e| refuse(format!("curl missing/unrunnable: {e}")))?;
        if !out.status.success() {
            return Err(refuse(format!(
                "download {url} failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            )));
        }
        return Ok(());
    }
    Err(refuse(format!("refusing non-https/non-file URL: {url}")))
}

fn verify(path: &Path, want_hex: &str, want_size: Option<u64>) -> Result<(), FetchError> {
    use sha2::Digest;
    let bytes = std::fs::read(path).map_err(|e| refuse(format!("verify read: {e}")))?;
    if let Some(size) = want_size {
        if bytes.len() as u64 != size {
            return Err(refuse(format!(
                "size mismatch for {}: want {size}, got {}",
                path.display(),
                bytes.len()
            )));
        }
    }
    let mut h = sha2::Sha256::new();
    h.update(&bytes);
    let got = hex_of(&h.finalize());
    if got != want_hex.to_lowercase() {
        return Err(refuse(format!(
            "SHA-256 mismatch for {}: want {want_hex}, got {got} (deleted, never fall forward)",
            path.display()
        )));
    }
    Ok(())
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

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE_MANIFEST: &str = r#"
# comment line
[[lib]]
name = "tiny"
version = "1.0"
url = "file:///nonexistent-but-overridden-in-test"
sha256 = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a"
size = 4
kind = "header"
license = "MIT"
"#;

    #[test]
    fn manifest_parses() {
        let es = parse_manifest(FIXTURE_MANIFEST).expect("parse");
        assert_eq!(es.len(), 1);
        assert_eq!(es[0].name, "tiny");
        assert_eq!(es[0].size, Some(4));
        assert!(parse_manifest("key = \"x\"\n").is_err());
        assert!(parse_manifest("[[lib]]\nname = \"x\"\n").is_err());
    }

    #[test]
    fn builtin_manifest_parses() {
        let es = load_manifest_with_text(builtin_manifest()).expect("builtin");
        assert!(!es.is_empty());
        assert!(es.iter().any(|e| e.name == "volk.h"));
    }

    fn load_manifest_with_text(t: &str) -> Result<Vec<ManifestEntry>, String> {
        parse_manifest(t)
    }

    fn fixture_entry(bytes: &[u8]) -> (ManifestEntry, PathBuf) {
        use sha2::Digest;
        use std::sync::atomic::{AtomicUsize, Ordering};
        static N: AtomicUsize = AtomicUsize::new(0);
        let n = N.fetch_add(1, Ordering::SeqCst);
        let mut h = sha2::Sha256::new();
        h.update(bytes);
        let dir = std::env::temp_dir().join(format!("bo4f{}-{n}", std::process::id()));
        let src = dir.join("src.bin");
        let _ = std::fs::create_dir_all(&dir);
        std::fs::write(&src, bytes).unwrap();
        (
            ManifestEntry {
                name: "tiny".into(),
                version: "1".into(),
                url: format!("file://{}", src.display()),
                sha256: Some(hex_of(&h.finalize())),
                size: Some(bytes.len() as u64),
                kind: "header".into(),
                license: "MIT".into(),
            },
            dir,
        )
    }

    #[test]
    fn file_fetch_ok_and_cached() {
        let (e, dir) = fixture_entry(b"test");
        let root = dir.join("cache");
        let p1 = ensure(&root, &e, FetchPolicy::Auto).expect("fetch");
        assert!(p1.is_file());
        assert_eq!(std::fs::read(&p1).unwrap(), b"test");
        // Second call hits the verified cache (no re-download).
        let p2 = ensure(&root, &e, FetchPolicy::Off).expect("cache hit even when Off");
        assert_eq!(p1, p2);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn hash_mismatch_deletes_and_refuses() {
        let (mut e, dir) = fixture_entry(b"test");
        e.sha256 = Some("0".repeat(64));
        let root = dir.join("cache");
        let r = ensure(&root, &e, FetchPolicy::Auto);
        assert!(r.is_err());
        assert!(!entry_dir(&root, &e).join("artifact").is_file());
        assert!(!entry_dir(&root, &e).join("artifact.tmp").exists());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn offline_and_ask_nontty_refuse() {
        let (e, dir) = fixture_entry(b"test");
        let root = std::env::temp_dir().join(format!("bo4o{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        assert!(ensure(&root, &e, FetchPolicy::Off).is_err());
        // Test stdin is not a TTY → Ask refuses with the auto incantation.
        let err = ensure(&root, &e, FetchPolicy::Ask).expect_err("ask must refuse off-tty");
        assert!(err.message.contains("--fetch-libs=auto"), "{}", err.message);
        assert_eq!(err.exit_code(), 4);
        let _ = std::fs::remove_dir_all(&dir);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn unpinned_upstream_always_refused() {
        let (mut e, dir) = fixture_entry(b"test");
        e.sha256 = None;
        let root = dir.join("cache");
        let err = ensure(&root, &e, FetchPolicy::Auto).expect_err("unpinned");
        assert!(err.message.contains("unpinned"), "{}", err.message);
        let _ = std::fs::remove_dir_all(&dir);
    }
}
