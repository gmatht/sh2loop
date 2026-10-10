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
         \x20                     (`fb-blocks`/`fb-overlay`: the fb0 fragment pair)\n\
         \x20 --fetch-libs[=ask|auto|off]  library download policy (default ask)\n\
         \x20 --prefetch           warm the fetch cache from the manifest, then exit\n\
         \x20 --audit-fetch        print the fetch audit log, then exit\n\
         \x20 --publish-fb0[=PATH]  create the fb0 device NODE as a file of raw\n\
         \x20                     ARGB pixels (default $FB0_NODE > $FB0_DEV >\n\
         \x20                     /dev/fb0, size $FB0_GEOM WxH), print its path,\n\
         \x20                     then exit\n\
         \x20 --dump-fb0[=PATH]   write the PPM named by $FB_DUMP into the fb0\n\
         \x20                     node, so a shell can read the frame the\n\
         \x20                     program drew (`cat /dev/fb0`), then exit\n\n\
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
    /// `--publish-fb0[=PATH]`: create the fb0 device NODE tree (see
    /// `crate::fbnode`) and exit. `Some("")` means "use the default path
    /// (`$FB0_NODE` > `$FB0_DEV` > `/dev/fb0`)".
    pub publish_fb0: Option<String>,
    /// `--dump-fb0=FILE`: after the run, copy a P6 PPM (the device's own
    /// `fb_dump_ppm` output) into the node, converting it to the node's
    /// ARGB layout. This is the bridge that makes the node show a device
    /// frame: the device dumps pixels as PPM, and this writes them where
    /// the node (and therefore a shell or a viewer) can read them.
    pub dump_fb0: Option<String>,
}

impl Default for Options {
    fn default() -> Self {
        Options {
            common: CommonFlags::default(),
            emit_shader: None,
            fetch_libs: None,
            prefetch: false,
            audit_fetch: false,
            publish_fb0: None,
            dump_fb0: None,
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
            "--publish-fb0" => o.publish_fb0 = Some(String::new()),
            s if s.starts_with("--publish-fb0=") => {
                o.publish_fb0 = Some(s["--publish-fb0=".len()..].to_string());
            }
            "--dump-fb0" => o.dump_fb0 = Some(String::new()),
            s if s.starts_with("--dump-fb0=") => {
                o.dump_fb0 = Some(s["--dump-fb0=".len()..].to_string());
            }
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

/// `chmod 755` (AOT copy path: `fs::copy` creates umask-default
/// permissions, while the direct `build_aot` path it replaces sets the
/// executable bit — the `-o` artifact must stay runnable). No-op
/// off unix.
fn chmod_x(p: &std::path::Path) -> Result<(), String> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perm = std::fs::metadata(p)
            .map_err(|e| format!("stat {}: {e}", p.display()))?
            .permissions();
        perm.set_mode(0o755);
        std::fs::set_permissions(p, perm).map_err(|e| format!("chmod {}: {e}", p.display()))?;
    }
    #[cfg(not(unix))]
    {
        let _ = p;
    }
    Ok(())
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

    // --publish-fb0 is device-only (no program needed): create the fb0 node
    // tree and exit, so a script or harness can materialise the device with
    // no render at all.
    if let Some(path) = &o.publish_fb0 {
        return cmd_publish_fb0(path);
    }

    // --dump-fb0 is likewise device-only: it converts a PPM the device
    // already produced into the node's pixels.
    if let Some(path) = &o.dump_fb0 {
        return cmd_dump_fb0(path);
    }

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
    let (a1, shir_hit) = crate::pipeline::parse_to_shir_cached(&src, &cache_root);
    verbose(&o, &format!("shir cache {}", if shir_hit { "hit" } else { "miss" }));
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

    // ⑧/⑨ link + run. The executable itself is cached under the same
    // content key as the C (see cache::cached_exe): a hit skips the
    // ~minute gcc link of a game-sized render entirely. Any cache
    // problem falls back to the uncached path, so caching can never
    // fail a run that would otherwise work.
    if let Some(out) = o.common.out_exe.clone() {
        verbose(&o, &format!("AOT via {}", tc_id));
        let out = PathBuf::from(&out);
        match crate::cache::cached_exe(&cached.dir, |dst| {
            crate::tcc::build_aot(&tc, &c_file, dst, &cached.c_src, &cache_root).map(|_| ())
        }) {
            Ok(hit) => {
                verbose(&o, &format!("exe cache {}", if hit.hit { "hit" } else { "miss" }));
                match std::fs::copy(&hit.path, &out)
                    .map_err(|e| format!("copy cached exe: {e}"))
                    .and_then(|_| chmod_x(&out))
                {
                    Ok(()) => 0,
                    Err(e) => {
                        eprintln!("bash-O4: {e}");
                        1
                    }
                }
            }
            Err(_) => match crate::tcc::build_aot(&tc, &c_file, &out, &cached.c_src, &cache_root) {
                Ok(()) => 0,
                Err(e) => {
                    eprintln!("bash-O4: {e}");
                    1
                }
            },
        }
    } else {
        verbose(&o, &format!("JIT via {}", tc_id));
        // The fb0 DEVICE NODE, if this box has none (see `fbnode::publish`):
        // a JIT run is the one mode where the program is about to execute,
        // so it is the one mode where a device path it opens has to name
        // something. Best-effort — a program that never touches the path
        // must not fail because `/dev` is not writable.
        if let Err(e) = publish_fb0_for_run() {
            verbose(&o, &format!("fb0 node not published ({e})"));
        }
        match crate::cache::cached_exe(&cached.dir, |dst| {
            crate::tcc::build_aot(&tc, &c_file, dst, &cached.c_src, &cache_root).map(|_| ())
        }) {
            Ok(hit) => {
                verbose(&o, &format!("exe cache {}", if hit.hit { "hit" } else { "miss" }));
                match crate::tcc::exec_compiled(&hit.path, &prog_path, &o.common.prog_args) {
                    Ok(rc) => rc,
                    Err(e) => {
                        eprintln!("bash-O4: {e}");
                        1
                    }
                }
            }
            Err(_) => match crate::tcc::run_jit(&tc, &c_file, &cached.c_src, &prog_path, &o.common.prog_args, &cache_root) {
                Ok(rc) => rc,
                Err(e) => {
                    eprintln!("bash-O4: {e}");
                    1
                }
            },
        }
    }
}

/// `--dump-fb0=FILE`: write a P6 PPM (the device's `fb_dump_ppm` output) into
/// the fb0 node, converting it to the node's ARGB layout.
///
/// This is the half that makes the node a display rather than a dead file: the
/// C device draws into its own RAM surface, the program dumps that surface as
/// PPM (`fb_dump_ppm "$FB_DUMP"`), and this puts those pixels in the node so a
/// shell — or anything with the node open — reads the frame the program drew.
///
/// `arg` empty means "the node path from the environment", which is the usual
/// spelling: `--dump-fb0` after a run that set `$FB_DUMP`.
fn cmd_dump_fb0(arg: &str) -> i32 {
    let node_path = if arg.is_empty() {
        crate::fbnode::path_from_env()
    } else {
        PathBuf::from(arg)
    };
    // The source PPM: `$FB_DUMP`, the same variable a headless run dumps to.
    let Ok(src) = std::env::var("FB_DUMP") else {
        eprintln!("bash-O4: dump-fb0: $FB_DUMP is not set, so there is no PPM to copy");
        return 1;
    };
    if src.is_empty() {
        eprintln!("bash-O4: dump-fb0: $FB_DUMP is empty");
        return 1;
    }
    let ppm = match std::fs::read(&src) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("bash-O4: dump-fb0: read {src}: {e}");
            return 1;
        }
    };
    let mut node = match crate::fbnode::publish(&node_path) {
        Ok(n) => n,
        Err(e) => {
            eprintln!("bash-O4: dump-fb0: {e}");
            return 1;
        }
    };
    let frame = match crate::fbnode::from_ppm(&ppm, node.geom()) {
        Ok(f) => f,
        Err(e) => {
            eprintln!(
                "bash-O4: dump-fb0: {src} does not fit {}x{}: {e}",
                node.geom().w,
                node.geom().h
            );
            return 1;
        }
    };
    match node.write_frame(&frame) {
        Ok(()) => {
            eprintln!(
                "fb0 node {} now holds {}x{} from {src}",
                node.path().display(),
                node.geom().w,
                node.geom().h
            );
            0
        }
        Err(e) => {
            eprintln!("bash-O4: dump-fb0: write {}: {e}", node.path().display());
            1
        }
    }
}

/// `--publish-fb0[=PATH]`: create the fb0 device NODE and exit.
///
/// This is the "make the emulation a device node" half of the driver: the
/// linker-side device is `crate::devices` (a content-addressed source
/// directory), and this is the run-time-side one — one path, `/dev/fb0` by
/// default, sized to the geometry and holding raw pixels (see
/// [`crate::fbnode`]).
///
/// The path is printed on stdout so a caller can capture it
/// (`fb0=$(bash-O4 --publish-fb0)`); the geometry goes to stderr as a
/// diagnostic, because this mode does nothing else.
fn cmd_publish_fb0(arg: &str) -> i32 {
    let path = if arg.is_empty() {
        crate::fbnode::path_from_env()
    } else {
        PathBuf::from(arg)
    };
    match crate::fbnode::publish(&path) {
        Ok(node) => {
            let g = node.geom();
            eprintln!(
                "published fb0 node {} ({}x{}, {} bytes, ARGB)",
                node.path().display(),
                g.w,
                g.h,
                g.len()
            );
            println!("{}", node.path().display());
            0
        }
        Err(e) => {
            eprintln!("bash-O4: publish-fb0: {e}");
            1
        }
    }
}

/// Publish the fb0 node for a run if this box has none.
///
/// WHY AUTOMATIC, and why it may fail quietly: a program that draws by calling
/// the `fb_*` primitives does not need the node (the C lowering turns the draw
/// into an in-process call), and a program that OPENS the device path needs it
/// to exist. The driver cannot tell the two apart before the render, so the
/// node is published for every JIT run where the path is absent — and a publish
/// failure is a note, not an error, because a box where `/dev` is not writable
/// must still run a program that never touches the path.
///
/// An EXISTING path is left to [`crate::fbnode::publish`], which refuses
/// anything that is not a regular file: on a box with a real `/dev/fb0` that
/// node is the display, and it is the thing this emulation exists to be
/// compatible with.
fn publish_fb0_for_run() -> Result<(), String> {
    let path = crate::fbnode::path_from_env();
    let node = crate::fbnode::publish(&path)?;
    // One node per process, for the process's lifetime: the handle must
    // outlive this call, and the node is a single file rather than the
    // per-verb read ends an earlier design needed. `Box::leak` is the honest
    // spelling — the alternative is a `OnceLock` whose destructor runs at
    // exit, which is the one moment where dropping it is harmless but the
    // type then misstates how long the node is readable.
    let leaked: &'static crate::fbnode::Node = Box::leak(Box::new(node));
    let _ = leaked;
    Ok(())
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

/// `--emit-shader ID`: GLSL450 for one candidate loop, or the fb0
/// fragment pair for `fb-blocks`/`fb-overlay` (the device-write leg —
/// needs `/dev/fb0/<verb>` writes, or their `fb_*` call equivalents,
/// in the program; SPIR-V-checked per stage when a compiler exists).
fn cmd_emit_shader(o: &Options, a1: &str, id: &str) -> i32 {
    let prog = match crate::pipeline::parse_program(a1) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("bash-O4: shader: {e}");
            return 1;
        }
    };
    // Any `fb-` id routes to the fragment leg (supported verbs emit;
    // the rest refuse with an explanation instead of "unknown loop id").
    if id.starts_with("fb-") {
        return cmd_emit_fb_shader(o, &prog, id);
    }
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

/// `--emit-shader fb-blocks|fb-overlay`: the fb0 fragment pair.
fn cmd_emit_fb_shader(o: &Options, prog: &debashl::ir::IrProgram, id: &str) -> i32 {
    let verb = id.strip_prefix("fb-").unwrap_or(id);
    match crate::fb_frag::emit_fb_shader(prog, verb) {
        Ok((vertex, fragment)) => {
            print!("// ===== vertex ({id}) =====\n{vertex}");
            print!("// ===== fragment ({id}) =====\n{fragment}");
            let cache_root = crate::cache::cache_root(o.common.cache_dir.as_deref());
            if let Some(cc) = crate::shader::find_spirv_compiler(&cache_root) {
                let dir = std::env::temp_dir().join(format!("bo4spv{}", std::process::id()));
                let _ = std::fs::create_dir_all(&dir);
                for (src, ext) in [(&vertex, "vert"), (&fragment, "frag")] {
                    match crate::fb_frag::compile_stage(&cc, src, &dir, ext) {
                        Ok(spv) => verbose(
                            o,
                            &format!("shader {id}.{ext}: SPIR-V {} bytes", spv.len()),
                        ),
                        Err(e) => verbose(o, &format!("shader {id}.{ext}: SPIR-V check: {e}")),
                    }
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
