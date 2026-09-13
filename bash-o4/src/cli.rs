//! `bash-O4` command line (docs/BASH-O4.md §4.1).
//!
//! Exit codes: 0 success (or the JIT-run program's own exit code),
//! 1 compile/lower error, 2 usage, 3 GPU-force failure, 4 fetch refusal.

use std::path::PathBuf;

use crate::candidacy;
use crate::fetch::{self, FetchPolicy};

const USAGE: &str = "\
usage: bash-O4 [options] program.sh [-- args...]\n\
\n\
  -o FILE              AOT: write native executable (via tcc), do not run\n\
  --emit-c             print the CPU C source (debug), do not compile\n\
  --emit-shader ID     print the GLSL450 compute shader for candidate ID\n\
  --check              parse + GPU-candidacy report, no codegen\n\
  --dump-shir          print the ShIR A1 JSON, nothing else\n\
  --cpu-only, --no-gpu force the CPU path (also used when no Vulkan ICD)\n\
  --gpu=auto|force|off GPU policy (default auto; force fails (rc 3) when\n\
                       no candidate can dispatch)\n\
  --fetch-libs[=ask|auto|off]  library download policy (default ask)\n\
  --cache-dir PATH     override the artifact/fetch cache root\n\
  --offline            never touch the network (fetch refused, rc 4)\n\
  --prefetch           warm the fetch cache from the manifest, then exit\n\
  --audit-fetch        print the fetch audit log, then exit\n\
  -O0|-Og|-O2|-Os|-Oz|-O3|-O4  CLI presets (default: CLI no-flag default).\n\
  --true64|--no-true64  true 64-bit arithmetic (default true: safe; $SH2_TRUE64=0 opts out)\n\
  --verbose            diagnostics (cache hit/miss, toolchain, GPU note)\n\
\n\
JIT (default) compiles with tcc to a temp executable and runs it\n\
(with inherited stdio; exits with the program's own exit code). A tcc\n\
compile failure retries once via cc/gcc/clang with a stderr note.\n\
GPU dispatch is not yet wired: --gpu=auto compiles CPU-only;\n\
--gpu=force exits 3.";

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GpuMode {
    Auto,
    Force,
    Off,
}

pub struct Options {
    pub prog: Option<String>,
    pub prog_args: Vec<String>,
    pub out_exe: Option<String>,
    pub emit_c: bool,
    pub emit_shader: Option<String>,
    pub check: bool,
    pub dump_shir: bool,
    pub cpu_only: bool,
    pub gpu: GpuMode,
    pub fetch_libs: Option<String>,
    pub cache_dir: Option<String>,
    pub offline: bool,
    pub prefetch: bool,
    pub audit_fetch: bool,
    pub opt_level: String,
    pub true64: Option<bool>,
    pub verbose: bool,
}

impl Default for Options {
    fn default() -> Self {
        Options {
            prog: None,
            prog_args: Vec::new(),
            out_exe: None,
            emit_c: false,
            emit_shader: None,
            check: false,
            dump_shir: false,
            cpu_only: false,
            gpu: GpuMode::Auto,
            fetch_libs: None,
            cache_dir: None,
            offline: false,
            prefetch: false,
            audit_fetch: false,
            opt_level: "O4".to_string(),
            true64: None,
            verbose: false,
        }
    }
}

fn usage_err(msg: &str) -> i32 {
    eprintln!("bash-O4: {msg}\n{USAGE}");
    2
}

pub fn parse_args(args: &[String]) -> Result<Options, String> {
    let mut o = Options::default();
    let mut it = args.iter().peekable();
    // Bash convention: the first positional is the program; EVERYTHING
    // after it is program args (even flag-like words). A single `--`
    // right after the program is consumed for compatibility (`prog --
    // -x` ≡ `prog -x`); a second `--` passes through as data.
    let mut seen_prog = false;
    let mut dashdash_eaten = false;
    while let Some(a) = it.next() {
        if seen_prog {
            if a == "--" && !dashdash_eaten {
                dashdash_eaten = true;
                continue;
            }
            o.prog_args.push(a.clone());
            continue;
        }
        if a == "--" {
            // No program yet: `--` ends flag parsing; next positional
            // is the program, the rest are its args.
            for rest in it.by_ref() {
                if !seen_prog {
                    o.prog = Some(rest.clone());
                    seen_prog = true;
                } else {
                    o.prog_args.push(rest.clone());
                }
            }
            break;
        }
        match a.as_str() {
            "-o" => {
                o.out_exe = Some(it.next().ok_or("-o needs FILE")?.clone());
            }
            s if s.starts_with("-o") && s.len() > 2 => {
                o.out_exe = Some(s[2..].to_string());
            }
            "--emit-c" => o.emit_c = true,
            "--check" => o.check = true,
            "--dump-shir" => o.dump_shir = true,
            "--cpu-only" | "--no-gpu" => o.cpu_only = true,
            "--offline" => o.offline = true,
            "--true64" => o.true64 = Some(true),
            "--no-true64" => o.true64 = Some(false),
            "--prefetch" => o.prefetch = true,
            "--audit-fetch" => o.audit_fetch = true,
            "--verbose" => o.verbose = true,
            "-O0" | "-Og" | "-O2" | "-Os" | "-Oz" | "-O3" | "-O4" => {
                o.opt_level = a[1..].to_string();
            }
            s if s.starts_with("--emit-shader=") => {
                o.emit_shader = Some(s["--emit-shader=".len()..].to_string());
            }
            "--emit-shader" => {
                o.emit_shader = Some(it.next().ok_or("--emit-shader needs ID")?.clone());
            }
            s if s.starts_with("--gpu=") => {
                o.gpu = match &s["--gpu=".len()..] {
                    "auto" => GpuMode::Auto,
                    "force" => GpuMode::Force,
                    "off" => GpuMode::Off,
                    v => return Err(format!("bad --gpu={v:?} (want auto|force|off)")),
                };
            }
            s if s.starts_with("--fetch-libs") => {
                let v = s.strip_prefix("--fetch-libs=").unwrap_or("ask");
                match v {
                    "ask" | "auto" | "off" => o.fetch_libs = Some(v.to_string()),
                    _ => return Err(format!("bad --fetch-libs={v:?} (want ask|auto|off)")),
                }
            }
            s if s.starts_with("--cache-dir=") => {
                o.cache_dir = Some(s["--cache-dir=".len()..].to_string());
            }
            "--cache-dir" => {
                o.cache_dir = Some(it.next().ok_or("--cache-dir needs PATH")?.clone());
            }
            s if s.starts_with('-') => return Err(format!("unknown flag {s:?}")),
            _ => {
                o.prog = Some(a.clone());
                seen_prog = true;
            }
        }
    }
    Ok(o)
}

fn verbose(o: &Options, msg: &str) {
    if o.verbose {
        eprintln!("bash-O4: {msg}");
    }
}

pub fn run(args: &[String]) -> i32 {
    let o = match parse_args(args) {
        Ok(o) => o,
        Err(e) => return usage_err(&e),
    };

    let cache_root = crate::cache::cache_root(o.cache_dir.as_deref());

    // --audit-fetch / --prefetch are cache-only (no program needed).
    if o.audit_fetch {
        return match fetch::audit_log(&cache_root) {
            Ok(log) => {
                print!("{log}");
                0
            }
            Err(e) => {
                eprintln!("bash-O4: audit: {e}");
                1
            }
        };
    }
    if o.prefetch {
        let policy = fetch_policy(&o);
        return match fetch::prefetch(&cache_root, policy) {
            Ok(n) => {
                verbose(&o, &format!("prefetched {n} artifacts"));
                0
            }
            Err(e) => {
                eprintln!("bash-O4: prefetch: {e}");
                e.exit_code()
            }
        };
    }

    let Some(prog) = o.prog.clone() else {
        return usage_err("need program.sh");
    };
    let prog_path = PathBuf::from(&prog);

    // ① parse → A1.
    let src = match crate::pipeline::read_source(&prog_path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("bash-O4: {e}");
            return 1;
        }
    };
    let a1 = crate::pipeline::parse_to_shir(&src);
    if o.dump_shir {
        println!("{a1}");
        return 0;
    }

    // ④ candidacy report (no codegen).
    if o.check {
        return cmd_check(&o, &a1);
    }

    // --emit-shader ID (no compile).
    if let Some(id) = o.emit_shader.clone() {
        return cmd_emit_shader(&o, &a1, &id);
    }

    // GPU policy (v1: dispatch not yet wired — auto degrades to CPU).
    let gpu_off = o.cpu_only || o.gpu == GpuMode::Off;
    if o.gpu == GpuMode::Force {
        eprintln!("bash-O4: --gpu=force: no candidate dispatches yet (M3 dispatch not wired)");
        return 3;
    }
    if !gpu_off && o.verbose {
        if crate::vkffi::has_compute_device() {
            verbose(&o, "Vulkan device present; dispatch not yet wired — CPU fallback");
        } else {
            verbose(&o, "no Vulkan ICD — CPU path");
        }
    }

    // ⑤ CPU render (cached).
    let tc = match crate::tcc::find_toolchain() {
        Ok(t) => t,
        Err(e) => {
            eprintln!("bash-O4: {e}");
            return 1;
        }
    };
    let tc_id = format!("{:?}", tc);
    let t64key = match o.true64 {
        Some(true) => "t64=1",
        Some(false) => "t64=0",
        None => "t64=env",
    };
    let opts_key = format!("opt={} {t64key} gpu={:?}", o.opt_level, o.gpu);
    let key = crate::cache::artifact_key(&a1, &opts_key, &tc_id);
    let opt_level = o.opt_level.clone();
    let true64 = o.true64;
    let cached = match crate::cache::cached_c(&cache_root, &key, &a1, || {
        crate::pipeline::render_c_with(&a1, &opt_level, true64)
    }) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("bash-O4: render: {e}");
            return 1;
        }
    };
    verbose(&o, &format!("cache {} {}", if cached.hit { "hit" } else { "miss" }, key));
    let c_file = cached.dir.join("prog.c");

    if o.emit_c {
        print!("{}", cached.c_src);
        return 0;
    }

    // ⑧/⑨ link + run.
    if let Some(out) = o.out_exe.clone() {
        verbose(&o, &format!("AOT via {}", tc_id));
        match crate::tcc::build_aot(&tc, &c_file, &PathBuf::from(&out), &cached.c_src) {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("bash-O4: {e}");
                1
            }
        }
    } else {
        verbose(&o, &format!("JIT via {}", tc_id));
        match crate::tcc::run_jit(&tc, &c_file, &cached.c_src, &prog_path, &o.prog_args) {
            Ok(rc) => rc,
            Err(e) => {
                eprintln!("bash-O4: {e}");
                1
            }
        }
    }
}

/// `--check`: candidacy verdicts over the typed program.
fn cmd_check(o: &Options, a1: &str) -> i32 {
    let prog = match crate::pipeline::parse_program(a1) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("bash-O4: check: {e}");
            return 1;
        }
    };
    let verdicts = candidacy::analyze(&prog);
    let n_cand = verdicts.iter().filter(|v| v.is_candidate()).count();
    for v in &verdicts {
        println!("{v}");
    }
    println!("CANDIDATES={n_cand} LOOPS={}", verdicts.len());
    if o.verbose {
        println!(
            "device: {}",
            if crate::vkffi::has_compute_device() {
                "vulkan-compute present"
            } else {
                "none"
            }
        );
    }
    0
}

/// `--emit-shader ID`: GLSL450 for one candidate loop.
fn cmd_emit_shader(o: &Options, a1: &str, id: &str) -> i32 {
    let prog = match crate::pipeline::parse_program(a1) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("bash-O4: shader: {e}");
            return 1;
        }
    };
    match crate::shader::emit_shader(&prog, id) {
        Ok(glsl) => {
            print!("{glsl}");
            // Prove the bytes are real SPIR-V-compilable when a compiler
            // is present (never fail CPU work on toolchain drift).
            let cache_root = crate::cache::cache_root(o.cache_dir.as_deref());
            if let Some(cc) = crate::shader::find_spirv_compiler(&cache_root) {
                let dir = std::env::temp_dir().join(format!("bo4spv{}", std::process::id()));
                let _ = std::fs::create_dir_all(&dir);
                match crate::shader::compile_spv(&cc, &glsl, &dir) {
                    Ok(spv) => verbose(o, &format!("shader {id}: SPIR-V {} bytes", spv.len())),
                    Err(e) => verbose(o, &format!("shader {id}: SPIR-V check: {e}")),
                }
                let _ = std::fs::remove_dir_all(&dir);
            } else {
                verbose(o, "no SPIR-V compiler; GLSL only");
            }
            0
        }
        Err(e) => {
            eprintln!("bash-O4: shader: {e}");
            1
        }
    }
}

/// Resolve the effective fetch policy: flag > env > default ask.
fn fetch_policy(o: &Options) -> FetchPolicy {
    if o.offline || std::env::var("BASH_O4_OFFLINE").as_deref() == Ok("1") {
        return FetchPolicy::Off;
    }
    if let Some(f) = o.fetch_libs.clone() {
        return FetchPolicy::parse(&f);
    }
    FetchPolicy::parse(
        &std::env::var("BASH_O4_FETCH_LIBS").unwrap_or_else(|_| "ask".to_string()),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn true64_flags_parse() {
        let o = parse_args(&["--no-true64".into(), "p.sh".into()]).unwrap();
        assert_eq!(o.true64, Some(false));
    }

    #[test]
    fn flags_parse() {
        let o = parse_args(&["-o".into(), "a".into(), "p.sh".into()]).unwrap();
        assert_eq!(o.out_exe.as_deref(), Some("a"));
        assert_eq!(o.prog.as_deref(), Some("p.sh"));
        let o = parse_args(&["--gpu=force".into(), "p.sh".into(), "--".into(), "x".into()])
            .unwrap();
        assert_eq!(o.gpu, GpuMode::Force);
        assert_eq!(o.prog_args, vec!["x".to_string()]);
        // Bash convention: bare trailing words are program args.
        let o = parse_args(&["p.sh".into(), "a".into(), "--verbose".into()]).unwrap();
        assert_eq!(o.prog.as_deref(), Some("p.sh"));
        assert_eq!(o.prog_args, vec!["a".to_string(), "--verbose".to_string()]);
        assert!(!o.verbose);
        // Double dash after program: first eaten, second is data.
        let o = parse_args(&["p.sh".into(), "--".into(), "--".into()]).unwrap();
        assert_eq!(o.prog_args, vec!["--".to_string()]);
        assert!(parse_args(&["--bogus".into()]).is_err());
        assert!(parse_args(&[]).unwrap().prog.is_none());
    }
}
