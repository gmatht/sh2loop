//! The fb0 devices, embedded from the sh2perl dependency.
//!
//! `fbdev.c`/`fbdev.h` (drawing) and `fbinput.c`/`fbinput.h` (keyboard)
//! are the SAME FILES `sh2perl/runtime/` holds, pulled in with
//! `include_str!`. That is the whole deduplication: one source of truth
//! for the device, and a driver that can still build a drawing render
//! with no sh2perl tree anywhere near it.
//!
//! `include_str!` is compile-time, so the sources must be bytes in the
//! binary, not a path read at run time — hence [`materialize`], which
//! writes them to the cache dir under a name that says what they are
//! and returns that dir for the link line's `-I`.
//!
//! WHY A CACHE PATH AND NOT THE SOURCE TREE: the driver may be installed
//! anywhere, and it may be installed without a writable source tree (a
//! read-only checkout, a packaged binary). The cache is the one place
//! the driver already assumes it can write, and the artefacts there are
//! derived, disposable data — exactly what the device bytes are once
//! embedded.
//!
//! WHY THE DIR NAME CARRIES A HASH: the embedded bytes change when
//! sh2perl changes, but the cache dir does not (it is a fixed location
//! for this machine). Two drivers built from two sh2perl revisions would
//! otherwise write the same path with different bytes and race each
//! other's link. The hash makes the name content-addressed, so a write
//! is only ever the same write, and a stale directory from an older
//! revision is simply never looked at again.

use std::path::{Path, PathBuf};

/// The device sources, embedded at compile time from the sh2perl
/// dependency. Paths are relative to this file, which is inside
/// `bash-o4/src/`, so `../sh2perl` resolves to the workspace's sh2perl
/// tree — the same tree the `debashl` path dependency builds against.
const FBDEV_C: &str = include_str!("../../sh2perl/runtime/fbdev.c");
const FBDEV_H: &str = include_str!("../../sh2perl/runtime/fbdev.h");
const FBWIN_C: &str = include_str!("../../sh2perl/runtime/fbwin.c");
const FBWIN_H: &str = include_str!("../../sh2perl/runtime/fbwin.h");
const FBINPUT_C: &str = include_str!("../../sh2perl/runtime/fbinput.c");
const FBINPUT_H: &str = include_str!("../../sh2perl/runtime/fbinput.h");
const FBSOUND_C: &str = include_str!("../../sh2perl/runtime/fbsound.c");
const FBSOUND_H: &str = include_str!("../../sh2perl/runtime/fbsound.h");

/// Every embedded file, as (name, text). The headers must be written
/// too: the render does `#include <fbdev.h>` and the sources do
/// `#include "fbdev.h"`, and both need a real header on disk for the C
/// compiler to find.
const ALL: [(&str, &str); 8] = [
    ("fbdev.c", FBDEV_C),
    ("fbdev.h", FBDEV_H),
    ("fbinput.c", FBINPUT_C),
    ("fbinput.h", FBINPUT_H),
    ("fbwin.c", FBWIN_C),
    ("fbwin.h", FBWIN_H),
    ("fbsound.c", FBSOUND_C),
    ("fbsound.h", FBSOUND_H),
];

/// A short, stable digest of the embedded device bytes. FNV-1a: this is
/// a cache-key component, not a security property, and it only has to
/// change when the bytes change. (The same choice as `build.rs`'s
/// pipeline revision, for the same reason.)
fn digest() -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for (name, text) in ALL {
        for b in name.as_bytes().iter().chain(text.as_bytes()) {
            h ^= *b as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
    }
    format!("{:x}", h)
}

/// The cache directory the device files live in for this build: named
/// for the CONTENT, so two builds with two sh2perl revisions write two
/// different directories and neither clobbers the other.
pub fn device_dir(cache_root: &Path) -> PathBuf {
    cache_root.join("bash-o4").join("devices").join(digest())
}

/// Write the embedded device files into `cache_root` and return the
/// directory holding them, ready for the link line's `-I`.
///
/// Idempotent and cheap: each file is written only when what is on disk
/// differs, so the common case (already materialised by an earlier
/// render) is four `read` + `cmp`s, not four rewrites. Rewriting
/// unconditionally would be harmless but would touch mtimes on every
/// link, and a tcc reading a source whose mtime is moving under it is a
/// class of problem better not invited.
pub fn materialize(cache_root: &Path) -> Result<PathBuf, String> {
    let dir = device_dir(cache_root);
    std::fs::create_dir_all(&dir).map_err(|e| format!("device mkdir {}: {e}", dir.display()))?;
    for (name, text) in ALL {
        let path = dir.join(name);
        let current = std::fs::read(&path).ok();
        if current.as_deref() == Some(text.as_bytes()) {
            continue;
        }
        // Unique temp + rename, the same discipline the artifact cache
        // uses: two drivers rendering concurrently must not truncate a
        // file the other one is compiling.
        let tmp = dir.join(format!("{name}.{}.tmp", std::process::id()));
        std::fs::write(&tmp, text).map_err(|e| format!("device write {name}: {e}"))?;
        if let Err(e) = std::fs::rename(&tmp, &path) {
            let _ = std::fs::remove_file(&tmp);
            return Err(format!("device commit {name}: {e}"));
        }
    }
    Ok(dir)
}

/// The device file a link needs by name (`fbdev.c`, `fbinput.c`), as an
/// absolute path inside `dir`.
pub fn source_in(dir: &Path, name: &str) -> PathBuf {
    dir.join(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("bo4-dev-{}-{name}", std::process::id()));
        let _ = std::fs::remove_dir_all(&d);
        d
    }

    /// The property that made this a deduplication: the bytes the driver
    /// links are the bytes sh2perl holds. Asserted by CONTENT, not by
    /// the presence of a file, because a stale vendored copy is exactly
    /// the failure this removes.
    #[test]
    fn embedded_bytes_are_the_sh2perl_files() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../sh2perl/runtime");
        for (name, text) in ALL {
            let on_disk = std::fs::read(root.join(name))
                .unwrap_or_else(|e| panic!("read sh2perl runtime/{name}: {e}"));
            assert_eq!(
                on_disk,
                text.as_bytes(),
                "embedded {name} differs from sh2perl/runtime/{name}; the \
                 driver would render with a device the tree does not have"
            );
        }
    }

    /// Not vacuously true: the two `.c` files must be the files the
    /// device really is, not two empty placeholders that any string
    /// comparison would accept.
    #[test]
    fn embedded_sources_are_the_device() {
        assert!(FBDEV_C.contains("fb_open"), "fbdev.c lost its entry point");
        assert!(FBDEV_C.contains("#include \"fbdev.h\""));
        assert!(
            FBINPUT_C.contains("fb_input_line"),
            "fbinput.c lost its reader"
        );
        assert!(FBINPUT_C.contains("#include \"fbinput.h\""));
        assert!(
            FBDEV_H.contains("FBDEV_H"),
            "fbdev.h lost its include guard"
        );
        assert!(
            FBINPUT_H.contains("FBINPUT_H"),
            "fbinput.h lost its include guard"
        );
    }

    /// A C compiler must find BOTH spellings of the include. The render
    /// uses `#include <fbdev.h>`, the device source uses
    /// `#include "fbdev.h"`; writing the header next to the source in
    /// one directory is what satisfies both, and this pins it.
    #[test]
    fn materialised_dir_links_and_guards() {
        let root = tmp("link");
        let dir = materialize(&root).expect("materialize");
        for (name, text) in ALL {
            let p = source_in(&dir, name);
            assert!(
                p.is_file(),
                "{name} was not materialised at {}",
                p.display()
            );
            assert_eq!(std::fs::read_to_string(&p).unwrap(), text);
        }
        let _ = std::fs::remove_dir_all(&root);
    }

    /// Idempotent, and it must not rewrite an unchanged file — a driver
    /// linking on every render would otherwise touch mtimes forever.
    #[test]
    fn materialise_is_idempotent_and_quiet() {
        let root = tmp("idem");
        let dir = materialize(&root).expect("first");
        let mtime = std::fs::metadata(dir.join("fbdev.c"))
            .unwrap()
            .modified()
            .unwrap();
        std::thread::sleep(std::time::Duration::from_millis(20));
        let again = materialize(&root).expect("second");
        assert_eq!(
            dir, again,
            "the directory name must be stable for one build"
        );
        let mtime2 = std::fs::metadata(dir.join("fbdev.c"))
            .unwrap()
            .modified()
            .unwrap();
        assert_eq!(mtime, mtime2, "an unchanged device file was rewritten");
        let _ = std::fs::remove_dir_all(&root);
    }

    /// A device file that went missing or was corrupted is repaired,
    /// not merely detected: a half-written file from a killed driver
    /// would otherwise fail the link with a parse error that points at
    /// the device, not at the cause.
    #[test]
    fn damaged_device_file_is_repaired() {
        let root = tmp("repair");
        let dir = materialize(&root).expect("first");
        std::fs::write(dir.join("fbinput.c"), "truncated").expect("clobber");
        materialize(&root).expect("repair");
        assert_eq!(
            std::fs::read_to_string(dir.join("fbinput.c")).unwrap(),
            FBINPUT_C,
            "a damaged device file must be rewritten from the embedded copy"
        );
        let _ = std::fs::remove_dir_all(&root);
    }

    /// The digest must track the CONTENT, so a changed device gets a new
    /// directory. (Checked against a perturbed copy of the same inputs,
    /// because the embedded bytes cannot change within one test run.)
    #[test]
    fn digest_tracks_content() {
        fn fnv(pairs: &[(&str, &str)]) -> String {
            let mut h: u64 = 0xcbf29ce484222325;
            for (n, t) in pairs {
                for b in n.as_bytes().iter().chain(t.as_bytes()) {
                    h ^= *b as u64;
                    h = h.wrapping_mul(0x100000001b3);
                }
            }
            format!("{:x}", h)
        }
        let base = ALL;
        let mut changed = ALL;
        changed[0].1 = "/* edited */";
        assert_ne!(
            fnv(&base),
            fnv(&changed),
            "a device edit must move the directory, or two builds share one"
        );
        // Stable across calls: same bytes, same name.
        assert_eq!(digest(), digest());
    }
}
