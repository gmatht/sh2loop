//! `python-O4` — the Python member of the -O4 driver family.
//!
//! Pipeline: `.py` → py-sh-go frontend (A1 shIR) → generic stages:
//! C render + `tcc` JIT/AOT (CPU path), or CUDA candidacy + PTX dispatch
//! (GPU path, `cu_run`). The frontend-specific `normalize_counted`
//! fixup (recovering the core's `ForInit` from the Python frontend's
//! counted-while shape) lives in `bash_o4::py`.
//!
//! Exit codes: 0 success (or the JIT program's own code), 1
//! compile/lower error, 2 usage, 3 `--gpu=force` with nothing
//! dispatchable.

use std::path::{Path, PathBuf};

use bash_o4::flags::GpuMode;
use bash_o4::{cache, cu_run, pipeline, py, tcc};

fn usage() -> String {
    format!(
        "usage: python-O4 [options] program.py [-- args...]\n\n\
         {}\n\
         {}\n\n\
         The GPU leg is the bench/offload vehicle (per-loop offload; the\
         whole-program host split is the open M3 item, same as bash-O4): it\
         prints the offloaded loop's checksum, which equals the program's\
         stdout for the map/reduce bench shapes.\n\n\
         Front end: py-sh-go (.py -> A1 shIR) -> the shared -O4 stages.",
        bash_o4::flags::common_usage(),
        bash_o4::flags::common_footer()
    )
}

/// Exactly the shared flag set — `python-O4` adds no driver-specific
/// flags, so its options ARE `CommonFlags` (see `bash_o4::flags`).
#[derive(Debug, Clone, Default)]
struct Options {
    common: bash_o4::flags::CommonFlags,
}

fn usage_err(msg: &str) -> i32 {
    eprintln!("python-O4: {msg}\n{}", usage());
    2
}

fn parse_args(args: &[String]) -> Result<Options, String> {
    let mut o = Options::default();
    let mut it = args.iter().peekable();
    let mut seen_prog = false;
    while let Some(a) = it.next() {
        if seen_prog {
            o.common.prog_args.push(a.clone());
            continue;
        }
        // Every flag python-O4 accepts is a SHARED flag, so the whole
        // match delegates: the common surface cannot drift from bash-O4.
        if bash_o4::flags::try_common(a, &mut it, &mut o.common)? {
            continue;
        }
        match a.as_str() {
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
        eprintln!("python-O4: {msg}");
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let code = run(&args);
    std::process::exit(code);
}

fn run(args: &[String]) -> i32 {
    let o = match parse_args(args) {
        Ok(o) => o,
        Err(e) => return usage_err(&e),
    };
    if o.common.help {
        print!("{}", usage());
        return 0;
    }
    if o.common.version {
        println!("python-O4 {}", env!("CARGO_PKG_VERSION"));
        return 0;
    }
    let Some(prog) = o.common.prog.clone() else {
        return usage_err("need program.py");
    };
    let prog_path = PathBuf::from(&prog);

    // ① frontend: .py → A1 shIR.
    let a1 = match py::a1_for(&prog_path) {
        Ok(a) => a,
        Err(e) => {
            eprintln!("python-O4: {e}");
            return 1;
        }
    };
    if o.common.dump_shir {
        println!("{a1}");
        return 0;
    }

    // ② typed programs (candidacy / check). Two views: the frontend's
    // original nodes feed the sequential-lane analysis (it keys on the
    // `Cast(Int64, …)` markers), while the cast-stripped view feeds
    // map/reduce (casts hide pow2 divisors from the mask plan). The CPU
    // render below stays on the untouched `a1`.
    let mut prog_ir = match pipeline::parse_program(&a1) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("python-O4: ingress: {e}");
            return 1;
        }
    };
    let mut prog_flat = match pipeline::parse_program(&py::a1_without_casts(&a1)) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("python-O4: ingress(flat): {e}");
            return 1;
        }
    };
    // Candidacy-view normalisation: the SHARED shIR transforms (the same
    // ones the A1 ingress runs for every backend) recover the core's
    // `ForInit` from the frontend's structured-Arith counted whiles and
    // turn counted-loop appends into affine stores. The sequential-lane
    // analysis uses the raw view (it keys on the frontend's Cast
    // markers); the cast-stripped flat view feeds map/reduce.
    use debashl::transforms as T;
    let mut loops = 0usize;
    loops += T::counted_arith_forinit::transform(&mut prog_ir.stmts) as usize;
    loops += T::counted_arith_forinit::transform(&mut prog_flat.stmts) as usize;
    let appends = T::append_to_store::transform(&mut prog_flat.stmts) as usize;

    if o.common.check {
        for v in bash_o4::cu_candidacy::analyze(&prog_flat) {
            println!("MAP {v}");
        }
        for v in bash_o4::cu_candidacy::analyze_reduce(&prog_flat) {
            println!("RED {v}");
        }
        for v in bash_o4::cu_candidacy::analyze_seq(&prog_ir) {
            println!("SEQ {v}");
        }
        if o.common.verbose {
            eprintln!("python-O4: recovered {loops} counted loop(s), {appends} append(s)");
        }
        return 0;
    }

    // ③ GPU leg (bench/offload vehicle).
    if o.common.gpu_flag && o.common.gpu != GpuMode::Off {
        match cu_run::run(&prog_ir, &prog_flat, o.common.n, &o.common.binds, o.common.runs) {
            Ok((ms, checksum)) => {
                println!("{ms:.3} {checksum}");
                return 0;
            }
            Err(skip) => {
                if o.common.gpu == GpuMode::Force {
                    eprintln!("python-O4: --gpu=force: {skip}");
                    return 3;
                }
                verbose(&o, &format!("gpu skipped ({skip}); CPU path"));
            }
        }
    }

    // ④ CPU render (cached), mirroring the bash-O4 profile mapping.
    let tc = match tcc::find_toolchain() {
        Ok(t) => t,
        Err(e) => {
            eprintln!("python-O4: {e}");
            return 1;
        }
    };
    let tc_id = format!("{tc:?}");
    let t64key = match o.common.true64 {
        Some(true) => "t64=1",
        Some(false) => "t64=0",
        None => "t64=env",
    };
    let opts_key = format!("py opt={} {t64key} gpu={:?}", o.common.opt_level, o.common.gpu);
    let key = cache::artifact_key(&a1, &opts_key, &tc_id);
    let cache_root = cache::cache_root(o.common.cache_dir.as_deref());
    let opt_level = o.common.opt_level.clone();
    let true64 = o.common.true64;
    let cached = match cache::cached_c(&cache_root, &key, &a1, || {
        pipeline::render_c_with(&a1, &opt_level, true64)
    }) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("python-O4: render: {e}");
            return 1;
        }
    };
    verbose(&o, &format!("cache {} {}", if cached.hit { "hit" } else { "miss" }, key));
    let c_file = cached.dir.join("prog.c");

    if o.common.emit_c {
        print!("{}", cached.c_src);
        return 0;
    }

    if let Some(out) = o.common.out_exe.clone() {
        match tcc::build_aot(&tc, &c_file, &PathBuf::from(&out), &cached.c_src) {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("python-O4: {e}");
                1
            }
        }
    } else {
        match tcc::run_jit(&tc, &c_file, &cached.c_src, &prog_path, &o.common.prog_args) {
            Ok(rc) => rc,
            Err(e) => {
                eprintln!("python-O4: {e}");
                1
            }
        }
    }
}

/// Keep `Path` imported for future AOT signature use.
#[allow(dead_code)]
fn _path(_: &Path) {}
