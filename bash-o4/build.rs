//! Build-time pipeline revision: content-address the renderer code so
//! fixed renders can never hide behind stale cache entries (found live,
//! twice: corrected renders lost to hits because a human forgot the
//! manual REV bump). The key folds in, per repo (workspace + sh2perl
//! submodule):
//!   - HEAD SHA (committed code),
//!   - `git diff HEAD` bytes (tracked modifications, EXACT content — a
//!     mere paths-list misses edits to already-dirty files),
//!   - untracked files as (path, size, mtime) (mtime catches content
//!     change cheaply; same basis as cargo/make themselves).
//! Untracked misses direction: a change always alters the key (miss,
//! never stale-hit). `BAZO4_REV_FALLBACK` ("nogit") covers gitless
//! environments; the manual `RENDERER_REV` in cache.rs remains as a
//! second component. Computed once at build time, never on the hot path.
use std::process::Command;

fn git(dir: &str, args: &[&str]) -> Option<Vec<u8>> {
    let out = Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Some(out.stdout)
}

fn fnv(data: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in data {
        h ^= *b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

/// Untracked files under `dir` as `path\0size\0mtime` records. Sizes and
/// mtimes come from a single `git status` + metadata pass (no content
/// reads — target/ and friends are gitignored and never listed).
fn untracked_record(dir: &str) -> Vec<u8> {
    let mut rec = Vec::new();
    let status = match git(dir, &["status", "--porcelain=v1", "--untracked-files=all"]) {
        Some(s) => s,
        None => return b"nostatus".to_vec(),
    };
    let text = String::from_utf8_lossy(&status);
    for line in text.lines() {
        // porcelain v1: XY SP path (possibly "old -> new" for renames)
        let p = line.get(3..).unwrap_or("");
        let p = p.split(" -> ").last().unwrap_or(p);
        // Only regular files we can stat; skip the .git internals noise.
        if p.starts_with(".git/") || p == ".git" {
            continue;
        }
        // Strip the quote wrapping git applies to special paths.
        let p = p.strip_prefix('"').and_then(|s| s.strip_suffix('"')).unwrap_or(p);
        let full = format!("{dir}/{p}");
        match std::fs::metadata(&full) {
            Ok(md) if md.is_file() => {
                rec.extend_from_slice(p.as_bytes());
                rec.push(0);
                rec.extend_from_slice(md.len().to_string().as_bytes());
                rec.push(0);
                rec.extend_from_slice(
                    format!("{:?}", md.modified().unwrap_or(std::time::UNIX_EPOCH)).as_bytes(),
                );
                rec.push(0);
            }
            _ => {
                rec.extend_from_slice(p.as_bytes());
                rec.push(0);
            }
        }
    }
    rec
}

fn main() {
    let root = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
    let sub = format!("{root}/../sh2perl");
    let mut key = Vec::new();
    for dir in [&root, &sub] {
        // HEAD SHA (empty when gitless).
        key.extend_from_slice(
            &git(dir, &["rev-parse", "HEAD"]).unwrap_or_else(|| b"nogit".to_vec()),
        );
        key.push(0);
        // Exact tracked modifications.
        key.extend_from_slice(&git(dir, &["diff", "HEAD", "--"]).unwrap_or_default());
        key.push(0);
        // Untracked inventory.
        key.extend_from_slice(&untracked_record(dir));
        key.push(0);
    }
    let rev = format!("{:x}", fnv(&key));
    let out = std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("pipeline_rev.rs");
    std::fs::write(&out, format!("pub const PIPELINE_REV: &str = {rev:?};\n")).unwrap();
    // Re-run triggers (emitting ANY rerun-if-changed disables cargo's
    // default package watching, so list everything affecting renders):
    // own + dependency sources (content edits), VCS pointers (checkout
    // switches, submodule moves).
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/");
    println!("cargo:rerun-if-changed=../sh2perl/src/");
    println!("cargo:rerun-if-changed=../otranspilerl/src/");
    println!("cargo:rerun-if-changed=../.git/HEAD");
    println!("cargo:rerun-if-changed=../sh2perl/.git");
}
