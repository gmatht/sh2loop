//! M1 link step: compile rendered C with tcc (millisecond JIT/AOT),
//! falling back along `$BASH_O4_CC` → `$CC` → `cc`/`gcc`/`clang`
//! (docs/BASH-O4.md §4.5). JIT compiles to a unique temp executable and
//! execs it (same stdio/exit/args contract as in-process JIT, with exact
//! error attribution); a primary-toolchain compile failure retries once
//! along the CC chain with a stderr note (tcc cannot parse some glibc
//! headers, e.g. <regex.h> — parity with the gcc-built corpus gate
//! requires the loud fallback, never silent, never bless).
//!
//! Link needs are derived from the render itself (substring scan):
//! `-lm` always, `-lgmp` when `<gmp.h>` is referenced, and the uu-ffi
//! runtime (`uu_run.c` + `libcoreutils_ffi.so`) when `<uu_run.h>` is
//! referenced. The sh2perl tree is located via `$BASH_O4_SH2PERL`, else
//! by walking up from the current executable (`bash-o4/target/<prof>/`
//! → workspace root → `sh2perl/`).
//!
//! THE FB0 DEVICES COME OUT OF THE SH2PERL DEPENDENCY, at COMPILE
//! TIME. `fbdev.c` (drawing) and `fbinput.c` (keyboard) are
//! `include_str!`'d from `../sh2perl/runtime/` — the one copy, the one
//! the tree edits — and materialised into the cache dir before the link
//! (see [`devices::materialize`]). A fb0 game therefore builds on a
//! machine with no sh2perl tree beside it, AND there is no second copy
//! of the device to fall out of date: the vendored `src/devices/` this
//! replaced was a byte-identical duplicate that a sh2perl-side fix had
//! to be applied to twice, in two trees, by hand.
//!
//! The sh2perl tree is still required for the uu-ffi runtime, because
//! that is a prebuilt shared library with a build step, not a source
//! file: it cannot be embedded without also embedding a `.so` per
//! architecture, which is a different trade. Set `BASH_O4_FBDEV_DIR` to
//! a `runtime/` to build against a device copy you are editing.

use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

/// A resolved C toolchain.
#[derive(Debug, Clone, PartialEq)]
pub enum Toolchain {
    /// TinyCC (JIT + AOT).
    Tcc(PathBuf),
    /// CC fallback (`cc`, `gcc`, `clang`, `$CC`): AOT only.
    Cc(PathBuf),
}

impl Toolchain {
    fn bin(&self) -> &Path {
        match self {
            Toolchain::Tcc(p) | Toolchain::Cc(p) => p,
        }
    }

    fn name(&self) -> &str {
        match self {
            Toolchain::Tcc(_) => "tcc",
            Toolchain::Cc(_) => "cc",
        }
    }
}

/// Locate the toolchain: `$BASH_O4_TCC`/`$BASH_O4_CC`/`$CC` override,
/// else `tcc`, else `cc`/`gcc`/`clang` from PATH.
pub fn find_toolchain() -> Result<Toolchain, String> {
    for key in ["BASH_O4_TCC", "BASH_O4_CC", "CC"] {
        if let Ok(v) = std::env::var(key) {
            let v = v.trim().to_string();
            if v.is_empty() {
                continue;
            }
            let first = v.split_whitespace().next().unwrap_or("tcc");
            if probe(first) {
                if key == "BASH_O4_TCC" || (!is_cc_key(key) && first.contains("tcc")) {
                    return Ok(Toolchain::Tcc(PathBuf::from(first)));
                }
                return Ok(Toolchain::Cc(PathBuf::from(first)));
            }
            return Err(format!("compiler {first:?} from ${key} not runnable"));
        }
    }
    for cand in ["tcc", "cc", "gcc", "clang"] {
        if probe(cand) {
            if cand == "tcc" {
                return Ok(Toolchain::Tcc(PathBuf::from(cand)));
            }
            return Ok(Toolchain::Cc(PathBuf::from(cand)));
        }
    }
    Err("no C compiler found (tcc/cc/gcc/clang); install tcc or set $CC".to_string())
}

fn is_cc_key(key: &str) -> bool {
    key == "BASH_O4_CC" || key == "CC"
}

// First available CC-chain compiler (`$BASH_O4_CC`/`$CC`/`cc`/`gcc`/
// `clang`), skipping a tcc that already failed (retrying it would loop
// the same error). Powers the loud fallback when the primary toolchain
// cannot compile a render (tcc cannot parse some glibc headers, e.g.
// <regex.h> — parity with the gcc-built corpus gate requires it).
pub fn find_cc_fallback(skip_tcc: bool) -> Result<Toolchain, String> {
    let mut cands: Vec<String> = Vec::new();
    for key in ["BASH_O4_CC", "CC"] {
        if let Ok(v) = std::env::var(key) {
            let v = v.trim().to_string();
            if !v.is_empty() {
                cands.push(v.split_whitespace().next().unwrap_or("cc").to_string());
            }
        }
    }
    cands.extend(["cc", "gcc", "clang"].iter().map(|s| s.to_string()));
    for c in cands {
        if skip_tcc && c.contains("tcc") {
            continue;
        }
        if probe(&c) {
            return Ok(Toolchain::Cc(PathBuf::from(c)));
        }
    }
    Err("no fallback C compiler found (cc/gcc/clang)".to_string())
}

// First line of a message (stderr notes stay one line).
fn first_line(msg: &str) -> &str {
    msg.lines().next().unwrap_or(msg).trim()
}

// The informative line of a compile error: the first line mentioning
// an error, else the first line (never the multi-line dump).
fn error_head(msg: &str) -> &str {
    for line in msg.lines() {
        let t = line.trim();
        if t.to_lowercase().contains("error") {
            return t;
        }
    }
    first_line(msg)
}

fn probe(bin: &str) -> bool {
    Command::new(bin)
        .arg("-v")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Locate the sh2perl tree (for the uu-ffi runtime sources).
pub fn find_sh2perl() -> Result<PathBuf, String> {
    if let Ok(v) = std::env::var("BASH_O4_SH2PERL") {
        let p = PathBuf::from(v);
        if p.join("runtime").join("uu_run.c").is_file() {
            return Ok(p);
        }
        return Err(format!("$BASH_O4_SH2PERL={} has no runtime/uu_run.c", p.display()));
    }
    // exe-relative discovery: <root>/bash-o4/target/<prof>/bash-O4 →
    // <root>/sh2perl/runtime/uu_run.c.
    if let Ok(exe) = std::env::current_exe() {
        let mut dir: Option<PathBuf> = exe.parent().map(|p| p.to_path_buf());
        for _ in 0..5 {
            let Some(d) = dir else { break };
            let cand = d.join("sh2perl");
            if cand.join("runtime").join("uu_run.c").is_file() {
                return Ok(cand);
            }
            dir = d.parent().map(|p| p.to_path_buf());
        }
    }
    Err("cannot locate sh2perl runtime (set $BASH_O4_SH2PERL)".to_string())
}

/// Extra link inputs derived from the rendered C text.
#[derive(Debug, Default, PartialEq)]
pub struct LinkNeeds {
    pub math: bool,
    pub gmp: bool,
    pub uu: bool,
    /// The fb0 framebuffer device (`runtime/fbdev.c`). The C backend
    /// emits `#include <fbdev.h>` and direct `fb_*` calls when a script
    /// names one of the primitives, so the link must carry the
    /// implementation — otherwise the render compiles and then fails
    /// at link time on an undefined `fb_open`.
    pub fb: bool,
    /// The keyboard half of the native device (`runtime/fbinput.c`).
    /// Its own header, so a draw-only program does NOT link the
    /// terminal/evdev code: the two devices are pulled in
    /// independently, by which header the render names.
    pub fbi: bool,
    /// The sound half (`runtime/fbsound.c`). Its own header for the
    /// same reason as the two above: a program that draws and plays
    /// must not drag in the audio code, and a program that only draws
    /// must not either. It links `-ldl` (it dlopens libasound) and
    /// `-lm`, and dlopens rather than linking libasound so a box with
    /// no sound at all still BUILDS.
    pub fbs: bool,
}

/// Why a link could not even be ATTEMPTED.
///
/// A missing device, a missing uu runtime, an unusable cache: none of
/// these is a compile error, and none of them is fixed by trying a
/// different compiler. They must not be dressed up as one — the CC
/// fallback exists for tcc failing to PARSE a render, and spending a
/// second full compile on a path that cannot work buries the one line
/// that says what is actually wrong.
#[derive(Debug)]
enum LinkSetup {
    /// The link was set up and the compiler ran; the error is the
    /// compiler's.
    CompileFailed(String),
    /// Refuse before compiling; the message is the whole answer.
    Refused(String),
}

impl LinkSetup {
    /// The message, either way.
    fn msg(&self) -> &str {
        match self {
            LinkSetup::CompileFailed(m) | LinkSetup::Refused(m) => m,
        }
    }

    /// True when trying another compiler cannot help.
    fn is_refusal(&self) -> bool {
        matches!(self, LinkSetup::Refused(_))
    }
}

impl From<String> for LinkSetup {
    fn from(e: String) -> Self {
        LinkSetup::Refused(e)
    }
}

/// Scan the render for optional-dependency references.
pub fn link_needs(c_src: &str) -> LinkNeeds {
    LinkNeeds {
        math: true, // libm is cheap and universally referenced (sqrt/time paths)
        gmp: c_src.contains("gmp.h"),
        uu: c_src.contains("uu_run.h"),
        fb: c_src.contains("fbdev.h"),
        fbi: c_src.contains("fbinput.h"),
        fbs: c_src.contains("fbsound.h"),
    }
}

/// Locate a device runtime source.
///
/// THE EMBEDDED COPY WINS, and it is the sh2perl file itself (see
/// `crate::devices`): one source of truth, so a fix to the device
/// cannot land in the tree and miss the driver, or the other way round.
///
/// A sh2perl tree, when there is one, is used ONLY as an override — set
/// `BASH_O4_FBDEV_DIR` to a `runtime/` you are actively editing and the
/// build picks that up instead. It is NOT consulted implicitly: the
/// embedded bytes are exactly the revision this binary was built from,
/// which is the thing you want to compare against, and a tree checked
/// out beside the build is whichever one happens to be there.
fn find_fbdev_src(cache_root: &Path, name: &str) -> Result<PathBuf, String> {
    if let Ok(dir) = std::env::var("BASH_O4_FBDEV_DIR") {
        let p = PathBuf::from(&dir).join(name);
        if p.is_file() {
            return Ok(p);
        }
        return Err(format!(
            "$BASH_O4_FBDEV_DIR={dir} has no {name} (unset it to use the \
             device embedded in this driver)"
        ));
    }
    let dir = crate::devices::materialize(cache_root)?;
    let p = crate::devices::source_in(&dir, name);
    if p.is_file() {
        return Ok(p);
    }
    Err(format!(
        "render references the device but {} is missing (this build of \
         bash-O4 is incomplete)",
        p.display()
    ))
}

fn find_fbdev(cache_root: &Path) -> Result<PathBuf, String> {
    find_fbdev_src(cache_root, "fbdev.c")
}

/// The WINDOW half of the fb0 device (runtime/fbwin.c).
///
/// It is part of the DRAW device, not a separate one, and that is a
/// fact about the C rather than a choice: fbdev.c's `fb_present` blits
/// the frame to the window and `fb_window_*` asks about it, so a link
/// that carries fbdev.c without fbwin.c fails at link time on four
/// undefined references. They could be made weak (so fbdev.c can link
/// alone) but tcc REJECTS an undefined weak symbol outright — measured,
/// `int f(void) __attribute__((weak));` is a hard error under tcc and
/// fine under cc — so the device is one unit. The cost on a box with no
/// X is a single dlopen("libX11.so.6") probe that fails, which is a few
/// microseconds once, and zero on a box with a framebuffer.
fn find_fbwin(cache_root: &Path) -> Result<PathBuf, String> {
    find_fbdev_src(cache_root, "fbwin.c")
}

fn find_fbinput(cache_root: &Path) -> Result<PathBuf, String> {
    find_fbdev_src(cache_root, "fbinput.c")
}

fn find_fbsound(cache_root: &Path) -> Result<PathBuf, String> {
    find_fbdev_src(cache_root, "fbsound.c")
}

/// Compile `c_file` to `out_exe` with exactly `tc` (no fallback).
/// Shared by AOT and JIT-temp compilation. `cache_root` is where the
/// fb0 device is materialised (see `crate::devices`); nothing else
/// writes there.
///
/// `LinkSetup::Refused` means the link was never attempted: a missing
/// device, a missing uu runtime, an unwritable cache. The caller
/// reports that as-is and does NOT retry another compiler.
fn compile_exe(
    tc: &Toolchain,
    c_file: &Path,
    out_exe: &Path,
    c_src: &str,
    cache_root: &Path,
) -> Result<(), LinkSetup> {
    let needs = link_needs(c_src);
    let mut cmd = Command::new(tc.bin());
    cmd.arg("-o").arg(out_exe).arg(c_file);
    if needs.math {
        cmd.arg("-lm");
    }
    if needs.gmp {
        cmd.arg("-lgmp");
    }
    let rt;
    if needs.uu {
        let sp = find_sh2perl()?;
        rt = sp.join("runtime");
        cmd.arg(rt.join("uu_run.c"));
        let so = rt.join("lib").join("libcoreutils_ffi.so");
        if !so.is_file() {
            return Err(format!(
                "render references uu_run.h but {} is missing (run runtime/build_uu_ffi.sh)",
                so.display()
            )
            .into());
        }
        cmd.arg(&so).arg("-lpthread");
        cmd.arg(format!("-Wl,-rpath,{}", rt.join("lib").display()));
        cmd.arg(format!("-I{}", rt.display()));
        cmd.arg(format!("-I{}", rt.join("lib").display()));
    }
    if needs.fb {
        // fbdev.c includes <linux/fb.h> and <sys/mman.h> and calls
        // open/ioctl/mmap — the same tcc a hello-world links against,
        // so no extra library is needed. -I is for <fbdev.h>.
        //
        // fbwin.c comes with it and needs -ldl and NOTHING else: libX11
        // is dlopen'd at RUN time, not linked, so a render builds on a
        // machine with no X11 headers at all (which is every framebuffer
        // box, every container, every CI runner) and picks a window up
        // only if the machine has a display. Linking -lX11 instead would
        // put a desktop dependency in the middle of the fb0 device.
        let fb = find_fbdev(cache_root)?;
        let dir = fb.parent().unwrap_or(Path::new(".")).to_path_buf();
        cmd.arg(&fb);
        let fbwin = find_fbwin(cache_root)?;
        cmd.arg(&fbwin);
        cmd.arg("-ldl");
        cmd.arg(format!("-I{}", dir.display()));
    }
    if needs.fbi {
        // The keyboard device: poll/termios, and on Linux an ioctl on
        // the evdev node. Same tcc, no extra library; -I for
        // <fbinput.h> (the same runtime/ dir fbdev.c lives in).
        let fbi = find_fbinput(cache_root)?;
        let dir = fbi.parent().unwrap_or(Path::new(".")).to_path_buf();
        cmd.arg(&fbi);
        cmd.arg(format!("-I{}", dir.display()));
    }
    if needs.fbs {
        // The sound device. -ldl for the dlopen of libasound, which is
        // NOT a link-time dependency on purpose: a framebuffer box has
        // no sound card and no libasound, and a program that names
        // fb_note must still build there. -I for <fbsound.h>, the same
        // runtime/ dir the other devices live in.
        let fbs = find_fbsound(cache_root)?;
        let dir = fbs.parent().unwrap_or(Path::new(".")).to_path_buf();
        cmd.arg(&fbs);
        cmd.arg("-ldl");
        cmd.arg(format!("-I{}", dir.display()));
    }
    let out = cmd
        .output()
        .map_err(|e| LinkSetup::CompileFailed(format!("{}: cannot run: {e}", tc.name())))?;
    if !out.status.success() {
        return Err(LinkSetup::CompileFailed(format!(
            "{} compile failed:\n{}",
            tc.name(),
            String::from_utf8_lossy(&out.stderr)
        )));
    }
    Ok(())
}

/// AOT: compile to `out_exe` (plus chmod). On primary-toolchain
/// compile failure, retries once along the CC chain with a stderr note.
pub fn build_aot(
    tc: &Toolchain,
    c_file: &Path,
    out_exe: &Path,
    c_src: &str,
    cache_root: &Path,
) -> Result<(), String> {
    if let Err(e) = compile_exe(tc, c_file, out_exe, c_src, cache_root) {
        // A link that was never ATTEMPTED (missing device, missing uu
        // runtime) is not a tcc problem: another compiler would fail
        // the same way, so report it instead of burning a compile.
        if e.is_refusal() {
            return Err(e.msg().to_string());
        }
        match tc {
            Toolchain::Tcc(_) => {
                let fb = find_cc_fallback(true)?;
                eprintln!(
                    "bash-O4: {} failed ({}); falling back to {}",
                    tc.name(),
                    error_head(e.msg()),
                    fb.bin().display()
                );
                compile_exe(&fb, c_file, out_exe, c_src, cache_root).map_err(|e2| {
                    format!("fallback {} also failed:\n{}", fb.name(), error_head(e2.msg()))
                })?;
            }
            _ => return Err(error_head(e.msg()).to_string()),
        }
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perm = std::fs::metadata(out_exe)
            .map_err(|e| format!("stat {}: {e}", out_exe.display()))?
            .permissions();
        perm.set_mode(0o755);
        std::fs::set_permissions(out_exe, perm)
            .map_err(|e| format!("chmod {}: {e}", out_exe.display()))?;
    }
    Ok(())
}

/// JIT-run `c_file`: compile to a unique temp executable (primary
/// toolchain, loud CC fallback on failure) and exec it with inherited
/// stdio; returns the program's exit code. Observable behavior matches
/// in-process JIT (same stdio/exit/args contract); compile+exec (rather
/// than `tcc -run`) is what makes error attribution exact — a nonzero
/// exit with no compiler diagnostics is always the PROGRAM's verdict,
/// never a hidden toolchain failure.
///
/// argv[0] emulation: the temp exe runs with argv[0] = the SCRIPT path
/// (like `bash script.sh`), never the temp path — `$0`/dirname tests
/// measure the renderer, not the cache directory (the c_gate_main.sh
/// `exec -a` convention, performed here by the driver itself).
pub fn run_jit(
    tc: &Toolchain,
    c_file: &Path,
    c_src: &str,
    prog_path: &Path,
    args: &[String],
    cache_root: &Path,
) -> Result<i32, String> {
    let tmp = c_file.with_extension(format!("jit{}", std::process::id()));
    let _ = std::fs::remove_file(&tmp);
    if let Err(e) = compile_exe(tc, c_file, &tmp, c_src, cache_root) {
        // Same rule as `build_aot`: a link that was never attempted is
        // not a toolchain problem, so do not run it twice.
        if e.is_refusal() {
            return Err(e.msg().to_string());
        }
        match tc {
            Toolchain::Tcc(_) => {
                let fb = find_cc_fallback(true)?;
                eprintln!(
                    "bash-O4: {} failed ({}); falling back to {}",
                    tc.name(),
                    error_head(e.msg()),
                    fb.bin().display()
                );
                compile_exe(&fb, c_file, &tmp, c_src, cache_root).map_err(|e2| {
                    format!("fallback {} also failed:\n{}", fb.name(), error_head(e2.msg()))
                })?;
            }
            _ => return Err(error_head(e.msg()).to_string()),
        }
    }
    let mut cmd = std::process::Command::new(&tmp);
    cmd.args(args);
    // argv[0] = script path (see doc above). arg0 is Unix-only; elsewhere
    // the temp path leaks as $0 (same as an -o binary run by path).
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        cmd.arg0(prog_path);
    }
    let st = cmd.status().map_err(|e| format!("run temp exe: {e}"))?;
    let _ = std::fs::remove_file(&tmp);
    Ok(st.code().unwrap_or(1))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn needs_detects_uu_and_gmp() {
        let n = link_needs("#include <uu_run.h>\nint main(){return 0;}");
        assert!(n.uu && n.math && !n.gmp);
        let n = link_needs("#include <gmp.h>\n");
        assert!(n.gmp && !n.uu);
        let n = link_needs("int main(){return 0;}");
        assert!(!n.uu && !n.gmp && n.math);
    }

    #[test]
    fn needs_detects_fbdev() {
        // The fb0 device is opt-in BY NAMING a primitive: the C
        // backend emits this include only when a script calls one.
        let n = link_needs("#include <fbdev.h>\nint main(){ fb_open(1,1); return 0; }");
        assert!(n.fb && n.math && !n.uu && !n.gmp);
        // A render with no fb_* call must NOT pull the device in, so
        // adding it can never change an unrelated program's link line.
        let n = link_needs("int main(){return 0;}");
        assert!(!n.fb && !n.fbi);
    }

    #[test]
    fn needs_separates_draw_from_input() {
        // The keyboard is a SEPARATE device with a SEPARATE header, so a
        // draw-only program must not link the terminal/evdev code. A
        // game that reads keys pulls both (it draws AND reads).
        let draw = link_needs("#include <fbdev.h>\nint main(){fb_open(1,1);return 0;}");
        assert!(draw.fb && !draw.fbi);
        let keys = link_needs(
            "#include <fbdev.h>\n#include <fbinput.h>\n\
             int main(){fb_open(1,1);return fb_input_line()[0];}",
        );
        assert!(keys.fb && keys.fbi);
        // The input header alone (a headless key reader) is enough on
        // its own — the two devices never drag each other in.
        let input_only = link_needs("#include <fbinput.h>\nint main(){return 0;}");
        assert!(input_only.fbi && !input_only.fb);
    }

    #[test]
    fn toolchain_found() {
        // The dev box has tcc; elsewhere any cc satisfies the fallback.
        assert!(find_toolchain().is_ok());
    }

    #[test]
    fn device_is_embedded_not_vendored() {
        // A render that names a device must find its implementation
        // with no sh2perl tree beside the binary AND with no second
        // copy of the source in this repo. Both are the properties
        // that regress quietly: point the lookup back at a tree and the
        // test still passes on this machine, because this machine has
        // one; and a re-added src/devices/ would pass every test while
        // reintroducing the duplicate this replaced.
        let dev = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("src/devices");
        assert!(
            !dev.exists(),
            "src/devices/ is back: the device is embedded from sh2perl, so a \
             second copy here can only drift from it"
        );
        // The lookup materialises from the embedded bytes, so it must
        // work with the override unset and with no tree in reach.
        let root = std::env::temp_dir().join(format!("bo4-dev-lookup-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        assert!(find_fbdev(&root).is_ok(), "the embedded device must resolve");
        assert!(find_fbwin(&root).is_ok(), "the embedded WINDOW must resolve");
        assert!(find_fbinput(&root).is_ok(), "the embedded keyboard must resolve");
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn bad_device_override_is_a_loud_error() {
        // A bad override names the variable; it never falls through to
        // the embedded copy. A build that quietly used a different
        // device than the one you named is worse than one that refuses.
        let root = std::env::temp_dir().join(format!("bo4-dev-ovr-{}", std::process::id()));
        unsafe {
            std::env::set_var("BASH_O4_FBDEV_DIR", "/nonexistent/for/test");
        }
        let e = find_fbdev_src(&root, "fbdev.c").unwrap_err();
        assert!(
            e.contains("BASH_O4_FBDEV_DIR"),
            "a bad override must name the variable, got: {e}"
        );
        unsafe {
            std::env::remove_var("BASH_O4_FBDEV_DIR");
        }
        let _ = std::fs::remove_dir_all(&root);
    }

    /// A link that was never ATTEMPTED must not be dressed up as a
    /// compile failure. The CC fallback costs a second full compile and
    /// would bury the one line naming the actual problem under
    /// "tcc failed (…); falling back to cc" — which is both a lie
    /// (tcc was never run) and slower for the case that most needs a
    /// clear message.
    #[test]
    fn refusal_is_not_a_compile_failure() {
        let refused = LinkSetup::Refused("no fbdev.c".into());
        assert!(refused.is_refusal(), "a missing device is a refusal");
        assert!(!refused.msg().contains("compile failed"));

        let failed = LinkSetup::CompileFailed("tcc compile failed:\n<regex.h>".into());
        assert!(
            !failed.is_refusal(),
            "a real compile error is exactly what the CC fallback is FOR \
             (tcc cannot parse <regex.h>); refusing it would break parity \
             with the gcc-built corpus gate"
        );
        // The note printed alongside the fallback names the FIRST line,
        // unless one says "error" — so the fallback note stays one line
        // and points at the compiler's own complaint.
        assert_eq!(error_head(failed.msg()), "tcc compile failed:");
        assert_eq!(error_head("a.c:1: error: bad\nmore"), "a.c:1: error: bad");
    }

    /// The device path really is the only thing that can refuse a
    /// draw-only link, and it does so before any compiler runs. Pinned
    /// with a REAL bad override and a real render, because the whole
    /// point is that tcc is never invoked.
    #[test]
    fn a_bad_device_refuses_before_the_compiler_runs() {
        let root = std::env::temp_dir().join(format!("bo4-dev-refuse-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let dir = root.join("work");
        std::fs::create_dir_all(&dir).expect("tmp");
        let c_file = dir.join("prog.c");
        std::fs::write(
            &c_file,
            "#include <fbdev.h>\nint main(void){ fb_open(1,1); return 0; }\n",
        )
        .expect("write");
        let out = dir.join("out");
        let c_src = std::fs::read_to_string(&c_file).unwrap();

        // The toolchain stands in for BOTH legs and records being run:
        // `tc` is the primary, and `$BASH_O4_CC` steers the fallback, so
        // the same marker catches a retry on the CC chain as well as a
        // first attempt. An invocation stays visible even though the
        // fake compiler fails — that is the point.
        let marker = dir.join("toolchain-was-run");
        let fake = dir.join("cc-that-must-not-run");
        std::fs::write(
            &fake,
            format!("#!/bin/sh\ntouch {}\nexit 99\n", marker.display()),
        )
        .expect("write fake");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&fake, std::fs::Permissions::from_mode(0o755))
                .expect("chmod");
        }
        let tc = Toolchain::Tcc(fake.clone());

        unsafe {
            std::env::set_var("BASH_O4_FBDEV_DIR", "/nonexistent/for/test");
            std::env::set_var("BASH_O4_CC", fake.to_str().unwrap());
        }
        let e = build_aot(&tc, &c_file, &out, &c_src, &root).unwrap_err();
        unsafe {
            std::env::remove_var("BASH_O4_FBDEV_DIR");
            std::env::remove_var("BASH_O4_CC");
        }

        assert!(
            e.contains("BASH_O4_FBDEV_DIR"),
            "the refusal must name the variable, got: {e}"
        );
        assert!(
            !e.contains("falling back"),
            "a refusal must not be retried on the CC chain, got: {e}"
        );
        assert!(
            !marker.exists(),
            "a compiler ran for a link that could never succeed; the \
             refusal is a setup error, not a toolchain one, so the CC \
             fallback cannot help and must not be spent on it"
        );
        assert!(!out.exists(), "nothing should have been linked");
        let _ = std::fs::remove_dir_all(&root);
    }
}
