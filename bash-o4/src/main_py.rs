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

use bash_o4::{cache, cu_run, pipeline, py, tcc};

const USAGE: &str = "\
usage: python-O4 [options] program.py [-- args...]\n\
\n\
  -o FILE              AOT: write native executable (via tcc), do not run\n\
  --emit-c             print the CPU C source (debug), do not compile\n\
  --check              parse + CUDA-candidacy report, no codegen\n\
  --dump-shir          print the ShIR A1 JSON, nothing else\n\
  --gpu[=auto|force|off]  CUDA path: dispatch a transpiled kernel and print\n\
                       `<median_ms> <checksum>` (auto skips to CPU; force\n\
                       exits 3 with no dispatchable shape/device)\n\
  --n N                bound value for the GPU leg (default 0)\n\
  --runs K             GPU timing repetitions (default 3)\n\
  --bind VAR=VAL       bind a non-single extern for the GPU leg\n\
  --cpu-only, --no-gpu force the CPU path\n\
  --cache-dir PATH     override the artifact cache root\n\
  -O0|-Og|-O2|-Os|-Oz|-O3|-O4  render presets (default O4)\n\
  --true64|--no-true64  true 64-bit arithmetic (default true)\n\
  --verbose            diagnostics\n\
  -h, --help           this help, exit 0\n\
  -V, --version        version, exit 0\n\
\n\
JIT (default) compiles with tcc to a temp executable and runs it\n\
(inherited stdio; exits with the program's own exit code). A tcc\n\
compile failure retries once via cc/gcc/clang with a stderr note.\n\
\n\
The GPU leg is the bench/offload vehicle (per-loop offload; the\n\
whole-program host split is the open M3 item, same as bash-O4): it\n\
prints the offloaded loop's checksum, which equals the program's\n\
stdout for the map/reduce bench shapes.";

#[derive(Debug, Clone, Copy, PartialEq)]
enum GpuMode {
    Auto,
    Force,
    Off,
}

struct Options {
    prog: Option<String>,
    prog_args: Vec<String>,
    out_exe: Option<String>,
    emit_c: bool,
    check: bool,
    dump_shir: bool,
    gpu: GpuMode,
    gpu_flag: bool,
    n: u64,
    runs: usize,
    binds: Vec<(String, i64)>,
    cache_dir: Option<String>,
    opt_level: String,
    true64: Option<bool>,
    verbose: bool,
    help: bool,
    version: bool,
}

impl Default for Options {
    fn default() -> Self {
        Options {
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
            verbose: false,
            help: false,
            version: false,
        }
    }
}

fn usage_err(msg: &str) -> i32 {
    eprintln!("python-O4: {msg}\n{USAGE}");
    2
}

fn parse_args(args: &[String]) -> Result<Options, String> {
    let mut o = Options::default();
    let mut it = args.iter().peekable();
    let mut seen_prog = false;
    while let Some(a) = it.next() {
        if seen_prog {
            o.prog_args.push(a.clone());
            continue;
        }
        match a.as_str() {
            "-o" => o.out_exe = Some(it.next().ok_or("-o needs FILE")?.clone()),
            "--emit-c" => o.emit_c = true,
            "--check" => o.check = true,
            "--dump-shir" => o.dump_shir = true,
            "--cpu-only" | "--no-gpu" => {
                o.gpu_flag = true;
                o.gpu = GpuMode::Off;
            }
            "-h" | "--help" => o.help = true,
            "-V" | "--version" => o.version = true,
            "--gpu" => {
                o.gpu_flag = true;
                o.gpu = GpuMode::Auto;
            }
            s if s.starts_with("--gpu=") => {
                o.gpu_flag = true;
                o.gpu = match &s["--gpu=".len()..] {
                    "auto" => GpuMode::Auto,
                    "force" => GpuMode::Force,
                    "off" => GpuMode::Off,
                    v => return Err(format!("bad --gpu={v:?} (want auto|force|off)")),
                };
            }
            "--n" => o.n = it.next().ok_or("--n needs N")?.parse().map_err(|_| "--n N")?,
            "--runs" => {
                o.runs = it.next().ok_or("--runs needs K")?.parse().map_err(|_| "--runs K")?
            }
            "--bind" => {
                let kv = it.next().ok_or("--bind VAR=VAL")?;
                let (k, v) = kv.split_once('=').ok_or("--bind VAR=VAL")?;
                o.binds.push((k.to_string(), v.parse().map_err(|_| "bind value")?));
            }
            "--true64" => o.true64 = Some(true),
            "--no-true64" => o.true64 = Some(false),
            "--verbose" => o.verbose = true,
            "-O0" | "-Og" | "-O2" | "-Os" | "-Oz" | "-O3" | "-O4" => {
                o.opt_level = a[1..].to_string();
            }
            s if s.starts_with("--cache-dir=") => {
                o.cache_dir = Some(s["--cache-dir=".len()..].to_string())
            }
            "--cache-dir" => o.cache_dir = Some(it.next().ok_or("--cache-dir needs PATH")?.clone()),
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
    if o.help {
        print!("{USAGE}");
        return 0;
    }
    if o.version {
        println!("python-O4 {}", env!("CARGO_PKG_VERSION"));
        return 0;
    }
    let Some(prog) = o.prog.clone() else {
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
    if o.dump_shir {
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

    if o.check {
        for v in bash_o4::cu_candidacy::analyze(&prog_flat) {
            println!("MAP {v}");
        }
        for v in bash_o4::cu_candidacy::analyze_reduce(&prog_flat) {
            println!("RED {v}");
        }
        for v in bash_o4::cu_candidacy::analyze_seq(&prog_ir) {
            println!("SEQ {v}");
        }
        if o.verbose {
            eprintln!("python-O4: recovered {loops} counted loop(s), {appends} append(s)");
        }
        return 0;
    }

    // ③ GPU leg (bench/offload vehicle).
    if o.gpu_flag && o.gpu != GpuMode::Off {
        match cu_run::run(&prog_ir, &prog_flat, o.n, &o.binds, o.runs) {
            Ok((ms, checksum)) => {
                println!("{ms:.3} {checksum}");
                return 0;
            }
            Err(skip) => {
                if o.gpu == GpuMode::Force {
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
    let t64key = match o.true64 {
        Some(true) => "t64=1",
        Some(false) => "t64=0",
        None => "t64=env",
    };
    let opts_key = format!("py opt={} {t64key} gpu={:?}", o.opt_level, o.gpu);
    let key = cache::artifact_key(&a1, &opts_key, &tc_id);
    let cache_root = cache::cache_root(o.cache_dir.as_deref());
    let opt_level = o.opt_level.clone();
    let true64 = o.true64;
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

    if o.emit_c {
        print!("{}", cached.c_src);
        return 0;
    }

    if let Some(out) = o.out_exe.clone() {
        match tcc::build_aot(&tc, &c_file, &PathBuf::from(&out), &cached.c_src) {
            Ok(()) => 0,
            Err(e) => {
                eprintln!("python-O4: {e}");
                1
            }
        }
    } else {
        match tcc::run_jit(&tc, &c_file, &cached.c_src, &prog_path, &o.prog_args) {
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
