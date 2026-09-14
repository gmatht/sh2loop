//! `bash-O4` command line (docs/BASH-O4.md §4.1).
//!
//! Exit codes: 0 success (or the JIT-run program's own exit code),
//! 1 compile/lower error, 2 usage, 3 GPU-force failure, 4 fetch refusal.

use std::path::PathBuf;

use crate::candidacy;
use crate::fetch::{self, FetchPolicy};

fn usage() -> String {
    format!(
        "usage: bash-O4 [options] program.sh [-- args...]\n\n\
         {}\n\
         Driver-specific:\n\
         \x20 --emit-shader ID     print the GLSL450 compute shader for candidate ID\n\
         \x20 --fetch-libs[=ask|auto|off]  library download policy (default ask)\n\
         \x20 --prefetch           warm the fetch cache from the manifest, then exit\n\
         \x20 --audit-fetch        print the fetch audit log, then exit\n\n\
         {}\n\
         The GPU leg prints the offloaded loop's checksum (equal to the\n\
         program's stdout for the map/reduce bench shapes); the\n\
         whole-program host split is still the open M3 item.",
        crate::flags::common_usage(),
        crate::flags::common_footer()
    )
}

pub use crate::flags::{CommonFlags, GpuMode};

pub struct Options {
    /// Everything both `-O4` drivers parse identically (see `crate::flags`).
    pub common: CommonFlags,
    // -- driver-specific (bash + GLSL/Vulkan fetch) --
    pub emit_shader: Option<String>,
    pub fetch_libs: Option<String>,
    pub prefetch: bool,
    pub audit_fetch: bool,
}

impl Default for Options {
    fn default() -> Self {
        Options {
            common: CommonFlags::default(),
            emit_shader: None,
            fetch_libs: None,
            prefetch: false,
            audit_fetch: false,
        }
    }
}

fn usage_err(msg: &str) -> i32 {
    eprintln!("bash-O4: {msg}\n{}", usage());
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
            o.common.prog_args.push(a.clone());
            continue;
        }
        if a == "--" {
            // No program yet: `--` ends flag parsing; next positional
            // is the program, the rest are its args.
            for rest in it.by_ref() {
                if !seen_prog {
                    o.common.prog = Some(rest.clone());
                    seen_prog = true;
                } else {
                    o.common.prog_args.push(rest.clone());
                }
            }
            break;
        }
        // Shared flags come from `crate::flags` so this driver and
        // python-O4 cannot drift (they had two separate `GpuMode`s and
        // different `--gpu` behaviour before).
        if crate::flags::try_common(a, &mut it, &mut o.common)? {
            continue;
        }
        match a.as_str() {
            s if s.starts_with("--emit-shader=") => {
                o.emit_shader = Some(s["--emit-shader=".len()..].to_string());
            }
            "--emit-shader" => {
                o.emit_shader = Some(it.next().ok_or("--emit-shader needs ID")?.clone());
            }
            "--prefetch" => o.prefetch = true,
            "--audit-fetch" => o.audit_fetch = true,
            s if s.starts_with("--fetch-libs") => {
                let v = s.strip_prefix("--fetch-libs=").unwrap_or("ask");
                match v {
                    "ask" | "auto" | "off" => o.fetch_libs = Some(v.to_string()),
                    _ => return Err(format!("bad --fetch-libs={v:?} (want ask|auto|off)")),
                }
            }
            s if s.starts_with('-') => return Err(format!("unknown flag {s:?}")),
            _ => {
                o.common.prog = Some(a.clone());
                seen_prog = true;
            }
        }
    }
    Ok(o)
}

fn verbose(o: &Options, msg: &str) {
    if o.common.verbose {
        eprintln!("bash-O4: {msg}");
    }
}

pub fn run(args: &[String]) -> i32 {
    let o = match parse_args(args) {
        Ok(o) => o,
        Err(e) => return usage_err(&e),
    };

    if o.common.help {
        print!("{}", usage());
        return 0;
    }
    if o.common.version {
        println!("bash-O4 {}", env!("CARGO_PKG_VERSION"));
        return 0;
    }

    let cache_root = crate::cache::cache_root(o.common.cache_dir.as_deref());

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

    let Some(prog) = o.common.prog.clone() else {
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
    if o.common.dump_shir {
        println!("{a1}");
        return 0;
    }

    // ④ candidacy report (no codegen).
    if o.common.check {
        return cmd_check(&o, &a1);
    }

    // --emit-shader ID (no compile).
    if let Some(id) = o.emit_shader.clone() {
        return cmd_emit_shader(&o, &a1, &id);
    }

    // ② GPU leg — same contract as python-O4: dispatch only when the user
    // explicitly asked (`--gpu`, `--gpu=auto|force|off`); a bare invocation
    // stays on the CPU path, which is also what gpu_gate's CPU leg relies on
    // (it passes `--cpu-only`).  Same `cu_run` vehicle as python-O4.
    if o.common.gpu_flag && o.common.gpu != GpuMode::Off {
        let prog_ir = match crate::pipeline::parse_program(&a1) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("bash-O4: gpu: {e}");
                return 1;
            }
        };
        // The shell front end emits no `Cast` markers, so the flat view the
        // mask plan wants is the same program (see `cu_run::run`).
        match crate::cu_run::run(&prog_ir, &prog_ir, o.common.n, &o.common.binds, o.common.runs) {
            Ok((ms, checksum)) => {
                println!("{ms:.3} {checksum}");
                return 0;
            }
            Err(skip) => {
                if o.common.gpu == GpuMode::Force {
                    eprintln!("bash-O4: --gpu=force: {skip}");
                    return 3;
                }
                verbose(&o, &format!("gpu skipped ({skip}); CPU path"));
            }
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
    let t64key = match o.common.true64 {
        Some(true) => "t64=1",
        Some(false) => "t64=0",
        None => "t64=env",
    };
    let opts_key = format!("opt={} {t64key} gpu={:?}", o.common.opt_level, o.common.gpu);
    let key = crate::cache::artifact_key(&a1, &opts_key, &tc_id);
    let opt_level = o.common.opt_level.clone();
    let true64 = o.common.true64;
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

    if o.common.emit_c {
        print!("{}", cached.c_src);
        return 0;
    }

    // ⑧/⑨ link + run.
    if let Some(out) = o.common.out_exe.clone() {
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
        match crate::tcc::run_jit(&tc, &c_file, &cached.c_src, &prog_path, &o.common.prog_args) {
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
    // Two candidacies exist and they answer different questions, so report
    // BOTH under distinct labels.  The GLSL/Vulkan one (`sh_loop_*`) is what
    // `--emit-shader` renders; the CUDA one is what `--gpu` dispatches.  Only
    // the GLSL half used to be printed, which made `--check` actively
    // misleading: `squares-map` has no GLSL candidate (scalar accumulate) yet
    // it offloads fine, and the report said CANDIDATES=0.
    let gpu = candidacy::analyze(&prog);
    let g_cand = gpu.iter().filter(|v| v.is_candidate()).count();
    for v in &gpu {
        println!("GLSL {v}");
    }
    // The CUDA section is byte-identical to python-O4's (same labels, same
    // analysis), so `--check` means the same thing in every driver.
    let mut cuda = 0usize;
    for v in crate::cu_candidacy::analyze(&prog) {
        if v.is_candidate() {
            cuda += 1;
        }
        println!("MAP {v}");
    }
    for v in crate::cu_candidacy::analyze_reduce(&prog) {
        if matches!(v.verdict, crate::cu_candidacy::CuVerdictKind::Candidate) {
            cuda += 1;
        }
        println!("RED {v}");
    }
    for v in crate::cu_candidacy::analyze_seq(&prog) {
        if matches!(v.verdict, crate::cu_candidacy::CuVerdictKind::Candidate) {
            cuda += 1;
        }
        println!("SEQ {v}");
    }
    println!("GLSL_CANDIDATES={g_cand} GLSL_LOOPS={}", gpu.len());
    println!("CUDA_CANDIDATES={cuda}");
    if o.common.verbose {
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
            let cache_root = crate::cache::cache_root(o.common.cache_dir.as_deref());
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
    if o.common.offline || std::env::var("BASH_O4_OFFLINE").as_deref() == Ok("1") {
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
        assert_eq!(o.common.true64, Some(false));
    }

    #[test]
    fn flags_parse() {
        let o = parse_args(&["-o".into(), "a".into(), "p.sh".into()]).unwrap();
        assert_eq!(o.common.out_exe.as_deref(), Some("a"));
        assert_eq!(o.common.prog.as_deref(), Some("p.sh"));
        let o = parse_args(&["--gpu=force".into(), "p.sh".into(), "--".into(), "x".into()])
            .unwrap();
        assert_eq!(o.common.gpu, GpuMode::Force);
        assert_eq!(o.common.prog_args, vec!["x".to_string()]);
        // Bash convention: bare trailing words are program args.
        let o = parse_args(&["p.sh".into(), "a".into(), "--verbose".into()]).unwrap();
        assert_eq!(o.common.prog.as_deref(), Some("p.sh"));
        assert_eq!(o.common.prog_args, vec!["a".to_string(), "--verbose".to_string()]);
        assert!(!o.common.verbose);
        // Double dash after program: first eaten, second is data.
        let o = parse_args(&["p.sh".into(), "--".into(), "--".into()]).unwrap();
        assert_eq!(o.common.prog_args, vec!["--".to_string()]);
        assert!(parse_args(&["--bogus".into()]).is_err());
        assert!(parse_args(&[]).unwrap().common.prog.is_none());
    }
}
