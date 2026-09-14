//! Shared `-O4` driver flags.
//!
//! `bash-O4` and `python-O4` are the same driver with different front ends,
//! so the flags a user types should not depend on which one they reached
//! for.  Before this module each binary had its own copy of the parsing
//! (including *two* private `GpuMode` enums) and they had drifted:
//! `bash-O4` had no `--n/--runs/--bind`, no `--help`, and its `--gpu` was
//! a policy that never dispatched, while `python-O4`'s `--gpu` did.
//!
//! The shared flags live here as one parser ([`try_common`]) and one help
//! block ([`common_usage`]); a driver only adds its own extras.  That makes
//! the common surface identical *by construction* rather than by review,
//! and `tests/flag_parity.rs` pins it end to end.
//!
//! Deliberately NOT shared (genuinely front-end specific):
//! - `bash-O4`: `--emit-shader ID`, `--fetch-libs[=ask|auto|off]`,
//!   `--prefetch`, `--audit-fetch` (the fetch manifest is for the Vulkan/GLSL
//!   side, which the Python driver does not use).
//! - `python-O4`: nothing.

use std::iter::Peekable;
use std::slice::Iter;

/// GPU policy.  `Force` is an error when nothing can dispatch (exit 3);
/// `Auto` falls back to the CPU path.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GpuMode {
    Auto,
    Force,
    Off,
}

/// Everything both drivers parse identically.
#[derive(Debug, Clone)]
pub struct CommonFlags {
    pub prog: Option<String>,
    pub prog_args: Vec<String>,
    pub out_exe: Option<String>,
    pub emit_c: bool,
    pub check: bool,
    pub dump_shir: bool,
    pub gpu: GpuMode,
    /// True when the user *explicitly* asked for GPU handling (`--gpu`,
    /// `--gpu=…`, `--cpu-only`, `--no-gpu`).  Dispatch only happens when
    /// this is set: without it `--gpu` defaults to `Auto`, and making the
    /// bare default dispatch would silently change what `bash-O4 prog.sh`
    /// does (and what `harness/gpu_gate.sh` measures).
    pub gpu_flag: bool,
    /// Bound value handed to the GPU leg.
    pub n: u64,
    /// GPU timing repetitions.
    pub runs: usize,
    /// Explicit bindings for GPU externs that cannot be inferred from `n`.
    pub binds: Vec<(String, i64)>,
    pub cache_dir: Option<String>,
    pub opt_level: String,
    pub true64: Option<bool>,
    /// Never touch the network.  `bash-O4` uses it for the library fetch;
    /// `python-O4` has nothing to fetch, so it is trivially satisfied.
    pub offline: bool,
    pub verbose: bool,
    pub help: bool,
    pub version: bool,
}

impl Default for CommonFlags {
    fn default() -> Self {
        CommonFlags {
            prog: None,
            prog_args: Vec::new(),
            out_exe: None,
            emit_c: false,
            check: false,
            dump_shir: false,
            gpu: GpuMode::Auto,
            gpu_flag: false,
            n: 0,
            runs: 3,
            binds: Vec::new(),
            cache_dir: None,
            opt_level: "O4".to_string(),
            true64: None,
            offline: false,
            verbose: false,
            help: false,
            version: false,
        }
    }
}

/// Consume one *shared* flag from `it`, if that is what `a` is.
///
/// `Ok(true)` — consumed; `Ok(false)` — not a shared flag, the caller's own
/// `match` should handle it; `Err(_)` — a shared flag with a bad value.
///
/// The caller passes the already-`next()`ed `a` plus the iterator, because
/// several shared flags take a following value or have an `=value` form.
pub fn try_common(
    a: &str,
    it: &mut Peekable<Iter<'_, String>>,
    f: &mut CommonFlags,
) -> Result<bool, String> {
    match a {
        "-o" => f.out_exe = Some(it.next().ok_or("-o needs FILE")?.clone()),
        "--emit-c" => f.emit_c = true,
        "--check" => f.check = true,
        "--dump-shir" => f.dump_shir = true,
        "-h" | "--help" => f.help = true,
        "-V" | "--version" => f.version = true,
        "--cpu-only" | "--no-gpu" => {
            f.gpu_flag = true;
            f.gpu = GpuMode::Off;
        }
        "--gpu" => {
            f.gpu_flag = true;
            f.gpu = GpuMode::Auto;
        }
        "--n" => f.n = it.next().ok_or("--n needs N")?.parse().map_err(|_| "--n N")?,
        "--runs" => {
            f.runs = it.next().ok_or("--runs needs K")?.parse().map_err(|_| "--runs K")?
        }
        "--bind" => {
            let kv = it.next().ok_or("--bind VAR=VAL")?;
            let (k, v) = kv.split_once('=').ok_or("--bind VAR=VAL")?;
            f.binds.push((k.to_string(), v.parse().map_err(|_| "bind value")?));
        }
        "--true64" => f.true64 = Some(true),
        "--no-true64" => f.true64 = Some(false),
        "--offline" => f.offline = true,
        "--verbose" => f.verbose = true,
        "-O0" | "-Og" | "-O2" | "-Os" | "-Oz" | "-O3" | "-O4" => f.opt_level = a[1..].to_string(),
        "--cache-dir" => f.cache_dir = Some(it.next().ok_or("--cache-dir needs PATH")?.clone()),
        s if s.starts_with("-o") && s.len() > 2 && !s.starts_with("--") => {
            f.out_exe = Some(s[2..].to_string())
        }
        s if s.starts_with("--gpu=") => {
            f.gpu_flag = true;
            f.gpu = match &s["--gpu=".len()..] {
                "auto" => GpuMode::Auto,
                "force" => GpuMode::Force,
                "off" => GpuMode::Off,
                v => return Err(format!("bad --gpu={v:?} (want auto|force|off)")),
            };
        }
        s if s.starts_with("--cache-dir=") => {
            f.cache_dir = Some(s["--cache-dir=".len()..].to_string())
        }
        _ => return Ok(false),
    }
    Ok(true)
}

/// The shared help block.  Drivers print their own usage line, this text,
/// then their extras — so the common section cannot drift.
pub fn common_usage() -> &'static str {
    "  -o FILE              AOT: write native executable (via tcc), do not run\n\
     \x20 --emit-c             print the CPU C source (debug), do not compile\n\
     \x20 --check              parse + GPU-candidacy report, no codegen\n\
     \x20 --dump-shir          print the ShIR A1 JSON, nothing else\n\
     \x20 --gpu[=auto|force|off]  GPU path: dispatch a transpiled kernel and print\n\
     \x20                      `<median_ms> <checksum>`; auto falls back to the\n\
     \x20                      CPU path, force exits 3 with nothing dispatchable\n\
     \x20 --n N                bound value for the GPU leg (default 0)\n\
     \x20 --runs K             GPU timing repetitions (default 3)\n\
     \x20 --bind VAR=VAL       bind a GPU extern that `--n` cannot infer\n\
     \x20 --cpu-only, --no-gpu force the CPU path\n\
     \x20 -O0|-Og|-O2|-Os|-Oz|-O3|-O4  render presets (default O4)\n\
     \x20 --cache-dir PATH     override the artifact/fetch cache root\n\
     \x20 --offline            never touch the network\n\
     \x20 --true64|--no-true64  true 64-bit arithmetic (default true: safe;\n\
     \x20                      $SH2_TRUE64=0 opts out)\n\
     \x20 --verbose            diagnostics (cache hit/miss, toolchain, GPU note)\n\
     \x20 -h, --help           this help, exit 0\n\
     \x20 -V, --version        version, exit 0\n"
}

/// The `[-- args...]` / JIT contract text, also shared verbatim.
pub fn common_footer() -> &'static str {
    "JIT (default) compiles with tcc to a temp executable and runs it\n\
     (inherited stdio; exits with the program's own exit code). A tcc\n\
     compile failure retries once via cc/gcc/clang with a stderr note."
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(flags: &[&str]) -> Result<(CommonFlags, Vec<String>), String> {
        let owned: Vec<String> = flags.iter().map(|s| s.to_string()).collect();
        let mut f = CommonFlags::default();
        let mut it = owned.iter().peekable();
        let mut rest = Vec::new();
        while let Some(a) = it.next() {
            if a == "--" {
                rest.extend(it.by_ref().cloned());
                break;
            }
            if !try_common(a, &mut it, &mut f)? {
                rest.push(a.clone());
            }
        }
        Ok((f, rest))
    }

    #[test]
    fn gpu_flag_tracks_explicit_use() {
        let (f, _) = parse(&[]).unwrap();
        assert!(!f.gpu_flag, "a bare invocation must not opt into dispatch");
        for flags in [&["--gpu"][..], &["--gpu=auto"], &["--cpu-only"], &["--gpu=force"]] {
            let (f, _) = parse(flags).unwrap();
            assert!(f.gpu_flag, "{flags:?} should set gpu_flag");
        }
        let (f, _) = parse(&["--gpu=force"]).unwrap();
        assert_eq!(f.gpu, GpuMode::Force);
        let (f, _) = parse(&["--no-gpu"]).unwrap();
        assert_eq!(f.gpu, GpuMode::Off);
    }

    #[test]
    fn gpu_values_are_validated() {
        assert!(parse(&["--gpu=bogus"]).is_err());
        assert!(parse(&["--gpu=off"]).is_ok());
    }

    #[test]
    fn gpu_leg_options_parse() {
        let (f, _) = parse(&["--n", "1000000", "--runs", "5", "--bind", "m=7"]).unwrap();
        assert_eq!(f.n, 1000000);
        assert_eq!(f.runs, 5);
        assert_eq!(f.binds, vec![("m".to_string(), 7)]);
        assert!(parse(&["--n", "abc"]).is_err());
        assert!(parse(&["--bind", "novalue"]).is_err());
    }

    #[test]
    fn out_exe_accepts_both_spellings() {
        assert_eq!(parse(&["-o", "x"]).unwrap().0.out_exe.as_deref(), Some("x"));
        assert_eq!(parse(&["-ox"]).unwrap().0.out_exe.as_deref(), Some("x"));
    }

    #[test]
    fn own_flags_are_not_consumed() {
        for own in ["--emit-shader", "--fetch-libs", "--prefetch", "--audit-fetch", "-x"] {
            let (_, rest) = parse(&[own]).unwrap();
            assert_eq!(rest, vec![own.to_string()], "{own} belongs to the driver");
        }
    }

    #[test]
    fn usage_documents_every_shared_flag() {
        let u = common_usage();
        for flag in [
            "-o FILE", "--emit-c", "--check", "--dump-shir", "--gpu[=auto|force|off]", "--n N",
            "--runs K", "--bind VAR=VAL", "--cpu-only", "--no-gpu", "-O0", "--cache-dir",
            "--offline", "--true64", "--verbose", "--help", "--version",
        ] {
            assert!(u.contains(flag), "shared usage omits {flag}");
        }
    }
}
