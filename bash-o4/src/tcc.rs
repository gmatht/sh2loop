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
}

/// Scan the render for optional-dependency references.
pub fn link_needs(c_src: &str) -> LinkNeeds {
    LinkNeeds {
        math: true, // libm is cheap and universally referenced (sqrt/time paths)
        gmp: c_src.contains("gmp.h"),
        uu: c_src.contains("uu_run.h"),
    }
}

/// Compile `c_file` to `out_exe`. Extra args: `-lm` as needed, uu/GMP
/// wiring when referenced.
/// Compile `c_file` to `out_exe` with exactly `tc` (no fallback).
/// Shared by AOT and JIT-temp compilation.
fn compile_exe(
    tc: &Toolchain,
    c_file: &Path,
    out_exe: &Path,
    c_src: &str,
) -> Result<(), String> {
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
            ));
        }
        cmd.arg(&so).arg("-lpthread");
        cmd.arg(format!("-Wl,-rpath,{}", rt.join("lib").display()));
        cmd.arg(format!("-I{}", rt.display()));
        cmd.arg(format!("-I{}", rt.join("lib").display()));
    }
    let out = cmd.output().map_err(|e| format!("{}: cannot run: {e}", tc.name()))?;
    if !out.status.success() {
        return Err(format!(
            "{} compile failed:\n{}",
            tc.name(),
            String::from_utf8_lossy(&out.stderr)
        ));
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
) -> Result<(), String> {
    if let Err(e) = compile_exe(tc, c_file, out_exe, c_src) {
        match tc {
            Toolchain::Tcc(_) => {
                let fb = find_cc_fallback(true)?;
                eprintln!(
                    "bash-O4: {} failed ({}); falling back to {}",
                    tc.name(),
                    error_head(&e),
                    fb.bin().display()
                );
                compile_exe(&fb, c_file, out_exe, c_src).map_err(|e2| {
                    format!("fallback {} also failed:\n{e2}", fb.name())
                })?;
            }
            _ => return Err(e),
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
) -> Result<i32, String> {
    let tmp = c_file.with_extension(format!("jit{}", std::process::id()));
    let _ = std::fs::remove_file(&tmp);
    if let Err(e) = compile_exe(tc, c_file, &tmp, c_src) {
        match tc {
            Toolchain::Tcc(_) => {
                let fb = find_cc_fallback(true)?;
                eprintln!(
                    "bash-O4: {} failed ({}); falling back to {}",
                    tc.name(),
                    error_head(&e),
                    fb.bin().display()
                );
                compile_exe(&fb, c_file, &tmp, c_src).map_err(|e2| {
                    format!("fallback {} also failed:\n{e2}", fb.name())
                })?;
            }
            _ => return Err(e),
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
    fn toolchain_found() {
        // The dev box has tcc; elsewhere any cc satisfies the fallback.
        assert!(find_toolchain().is_ok());
    }
}
