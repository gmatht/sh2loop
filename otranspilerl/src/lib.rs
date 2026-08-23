//! otranspilerl — the unified transpiler as a library.
//!
//! Statically links the `debashl` core and all nine backend renderers so
//! the whole otranspiler pipeline runs in-process from Rust. Source
//! languages other than shell (`py`/`c`/`pl`/`zsh`/`fish`/`go`) are
//! lowered to the neutral A1 shIR by the per-language frontend
//! executables, spawned as child processes (native). The WASM build
//! replaces that spawn with a clear error — the in-process shell →
//! A1 → any-backend path is fully available there (see `wasi.rs`).
//!
//! The CLI is a library function (`cli`), so a binary is a three-line
//! wrapper (`src/main.rs`).

use std::path::{Path, PathBuf};

pub mod wasi;

// ── the dispatch tables (the single source of truth) ─────────────────
// source extension → frontend executable (relative to the workspace root)
pub const SOURCES: &[(&str, &str)] = &[
    (".py", "frontends/py-sh-go/py-sh-go"),
    (".c", "frontends/c-sh-go/c-sh-go"),
    (".pl", "frontends/perl-sh-go/perl-sh-go"),
    (".zsh", "frontends/zsh-sh-go/zsh-sh-go"),
    (".fish", "frontends/fish-sh-go/fish-sh-go"),
    (".go", "frontends/go-sh/go-sh"),
    // .sh and no-ext: the core itself (in-process)
];
// target extension → the in-process backend renderer. `shir` = the
// neutral A1 contract itself (no renderer, passthrough).
pub const TARGETS: &[(&str, &str)] = &[
    (".js", "estree"),
    (".pl", "perl"),
    (".c", "c"),
    (".go", "go"),
    (".py", "python"),
    (".sh", "sh"),
    (".java", "java"),
    (".rs", "rust"),
    (".zig", "zig"),
    (".glsl", "glsl"),
    (".glslv", "glslv"),
    (".shir", "shir"),
];

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// `path` → source/target language, mirroring the Go wrapper's `langOf`:
/// `-` and `.shir` → "shir", known extensions → the extension, anything
/// else (incl. `.sh` and no extension) → "sh".
pub fn lang_of(path: &str) -> &'static str {
    if path == "-" {
        return "shir";
    }
    let ext = Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");
    match ext {
        "py" => "py",
        "c" => "c",
        "pl" => "pl",
        "zsh" => "zsh",
        "fish" => "fish",
        "go" => "go",
        "js" => "js",
        "rs" => "rs",
        "zig" => "zig",
        "java" => "java",
        "shir" => "shir",
        _ => "sh",
    }
}

/// Locate the workspace root: `OTRANSPILER_ROOT` env override, else walk
/// up from the current directory until a dir containing both `sh2perl`
/// and `frontends` is found.
pub fn workspace_root() -> Option<PathBuf> {
    if let Ok(r) = std::env::var("OTRANSPILER_ROOT") {
        if !r.is_empty() {
            return Some(PathBuf::from(r));
        }
    }
    let mut dir = std::env::current_dir().ok()?;
    loop {
        if dir.join("sh2perl").is_dir() && dir.join("frontends").is_dir() {
            return Some(dir);
        }
        if !dir.pop() {
            break;
        }
    }
    None
}

/// Run a child process, feed it `stdin`, return its stdout on success.
/// Native: `std::process`. WASM: no process spawn in wasm32-wasip1 — the
/// runtime's process interface is not wired yet, so frontends report a
/// clear error instead of failing silently.
#[cfg(not(target_family = "wasm"))]
pub fn run_process(exe: &Path, args: &[&str], stdin: &[u8]) -> Result<Vec<u8>, String> {
    use std::io::Write;
    let mut child = std::process::Command::new(exe)
        .args(args)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("spawn {}: {}", exe.display(), e))?;
    if let Some(mut child_stdin) = child.stdin.take() {
        let _ = child_stdin.write_all(stdin);
    }
    let out = child
        .wait_with_output()
        .map_err(|e| format!("run {}: {}", exe.display(), e))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(format!("{} failed: {}", exe.display(), err.trim()));
    }
    Ok(out.stdout)
}

#[cfg(target_family = "wasm")]
pub fn run_process(exe: &Path, _args: &[&str], _stdin: &[u8]) -> Result<Vec<u8>, String> {
    Err(format!(
        "process spawn not available in this build (needed to run {}); \
         run the source->shir frontend externally and feed the A1 JSON via '-' or a .shir file",
        exe.display()
    ))
}

/// Read a whole file. Tries a real file read first; falls back to treating
/// the argument as literal source text (mirrors the core's `--shir`
/// dispatch).
fn read_source(src: &str) -> Result<String, String> {
    // byte-preserving: invalid-UTF-8 bytes decode to PUA markers (the
    // estree corpus has non-UTF-8 examples — fs::read_to_string would fail
    // on them and the gate reported "stream did not contain valid UTF-8").
    // byte-preserving with the ESTREE marker base (U+F800+byte): the
    // emitter's map_raw_bytes (src/estree.rs) detects 0xF800..=0xF8FF and
    // turns them back into raw bytes. bytes_to_marked_lossy uses 0xE000
    // — the emitter misses those and the output differs (verified on
    // utf8-non-utf8-content.sh). Valid UTF-8 passes through as-is.
    let decode = |bytes: &[u8]| -> String {
        match String::from_utf8(bytes.to_vec()) {
            Ok(s) => s,
            Err(_) => bytes
                .iter()
                .map(|&b| {
                    if b < 0x80 {
                        b as char
                    } else {
                        char::from_u32(0xF800 + b as u32).unwrap_or('\u{FFFD}')
                    }
                })
                .collect(),
        }
    };
    match std::fs::read(src) {
        Ok(bytes) => Ok(decode(&bytes)),
        Err(_) if !src.contains(' ') => {
            match std::fs::read(src) {
                Ok(bytes) => Ok(decode(&bytes)),
                Err(e) => Err(format!("read {src}: {e}")),
            }
        }
        Err(_) => Ok(src.to_string()),
    }
}

/// In-process shell source → neutral A1 shIR JSON (the same path the core's
/// `--shir <file> --raw` takes: `ast_to_ir`, A2 `var_types` included). A
/// parse failure emits the canonical empty Program — never empty stdout.
pub fn shell_to_shir(content: &str) -> String {
    let (commands, lines) = match debashl::Parser::new(content).parse_with_lines() {
        Ok(p) => p,
        Err(_) => {
            return debashl::shir_json::shir_to_shir_json(&debashl::shir::ast_to_ir(&[]));
        }
    };
    let prog = debashl::shir::ast_to_ir_with_lines(&commands, &lines);
    debashl::shir_json::shir_to_shir_json(&prog)
}

/// The debashc-canonical parse-error ESTree fallback: a Program whose only
/// statement is `process.exit(2)` — the estree runner executes it and exits
/// 2, matching bash's syntax-error verdict. The plain empty Program would
/// exit 0 ("exit code (bash=2 estree=0)" gate failures on
/// parse-double-semicolon.sh etc.).
pub fn parse_error_estree_fallback() -> String {
    // static (otranspilerl has no direct serde_json dep — this mirrors the
    // debashc CLI's fallback byte-for-byte)
    r#"{"type":"Program","sourceType":"module","body":[{"type":"ExpressionStatement","expression":{"type":"CallExpression","callee":{"type":"MemberExpression","object":{"type":"Identifier","name":"process"},"property":{"type":"Identifier","name":"exit"},"computed":false,"optional":false},"arguments":[{"type":"Literal","value":2,"raw":"2"}],"optional":false}}]}"#.to_string()
}

/// A1 shIR JSON → target source, entirely in-process. `lang` is the bare
/// target name (`c`, `js`, `pl`, `sh`, `go`, `rs`, `zig`, `java`, `py`,
/// `shir`, or the backend kind `estree`/`perl`/`python`/`rust`); a leading
/// dot is tolerated. `shir` returns the A1 unchanged. Dispatches through
/// the `TARGETS` table (ext → backend kind) exactly like the Go wrapper.
/// Embed-profile options (the purify design, PLAN §10): render a shell
/// snippet as an embeddable Perl FRAGMENT — statements only, no preamble,
/// host-scope reuse, analysis-driven refusals. The host text outside the
/// construct's span is never touched by this API (the harvester/splice
/// engine owns it); the fragment + `required_host_bindings` + `refusals`
/// are the entire contract (docs/embed-contract.md).
#[derive(Default, Clone, Debug)]
pub struct EmbedOpts {
    /// Names the host program declares in the enclosing scope (the
    /// harvester's membership list).
    pub host_scope: Vec<String>,
    /// Backtick semantics: preserve trailing newlines (Perl `qx` doesn't
    /// strip; bash `$()` does).
    pub backtick: bool,
    /// Emit English.pm names instead of normalizing to `$/`/`$!`/`$@`.
    pub english: bool,
}

/// A1 → embeddable Perl fragment (same ingress as `render`: A1 in, the
/// shared restructure/strip passes, then the embed renderer). Returns the
/// full `EmbedResult` — the CLI prints the fragment on stdout and the
/// bindings/refusals on stderr, so stdout stays splice-clean.
pub fn render_embed(a1: &str, opts: &EmbedOpts) -> Result<debashl::ir::EmbedResult, String> {
    let mut prog = debashl::shir_json_in::shir_json_to_ir(a1)?;
    debashl::shir_passes::restructure_goto_only(&mut prog);
    debashl::shir_passes::strip_cfor(&mut prog);
    Ok(debashl::ir::shir_to_perl_embed(
        &prog,
        &debashl::ir::EmbedCtx {
            host_scope: opts.host_scope.clone(),
            backtick_newlines: opts.backtick,
            english_names: opts.english,
        },
    ))
}

/// Render a shell snippet to an embeddable Perl fragment, given a snippet
/// A1 JSON string (`render_embed` does the full pipeline from A1).
/// The sh→js compile pipeline: shell source → the estree AFTER the
/// moved estreeToJs head passes (the wasm's prefix — the JS side
/// continues at pass #5). Returns `{"estree": <estree JSON>}` — the
/// same shape the current `transpile` returns, but with the head passes
/// already applied in-process (no JS-side re-run).
pub fn compile(src: &str, _opts: &str) -> Result<String, String> {
    // a parse failure degrades to the empty program — the same behavior
    // the transpile path has (shell_to_shir's Err arm), so a broken
    // script compiles to the empty JS instead of erroring.
    let (commands, lines) = match debashl::Parser::new(src).parse_with_lines() {
        Ok(p) => p,
        Err(_) => (Vec::new(), Vec::new()),
    };
    let mut prog = debashl::shir::ast_to_ir_with_lines(&commands, &lines);
    // loop-opt (LICM-lite, estree-20260813-182436/201235): hoist the
    // leading loop-invariant run of statements out of every While/For/
    // DoWhile body so the emitted code stops re-deriving the same
    // products/arith per iteration (the game's per-cell index math, the
    // texture generators' invariant glyph geometry). Program-level, so it
    // plugs here (the WASM compile channel the browser game uses), NOT in
    // ast_to_ir — the --shir export and the perl/c channels stay
    // byte-identical.
    debashl::shir_passes::loop_opt::hoist_loop_invariants(&mut prog);
    let estree = debashl::shir::shir_to_estree_compiled(&prog);
    // the estree JSON embeds directly into the envelope (estree_to_json
    // is a complete JSON object)
    Ok(format!("{{\"estree\":{}}}", debashl::estree::estree_to_json(&estree)))
}

pub fn render(a1: &str, lang: &str) -> Result<String, String> {
    let lang = lang.strip_prefix('.').unwrap_or(lang);
    let kind = TARGETS
        .iter()
        .find(|(ext, _)| *ext == format!(".{lang}").as_str())
        .or_else(|| TARGETS.iter().find(|(_, k)| *k == lang))
        .map(|(_, k)| *k)
        .ok_or_else(|| {
            format!("target {lang:?} not wired (known: js, pl, c, go, py, sh, java, rs, zig, glsl, glslv, shir)")
        })?;
    let mut prog = debashl::shir_json_in::shir_json_to_ir(a1)?;
    // FRONTEND A1 ingress: the same worker-submitted transforms the bash
    // path runs in ast_to_ir — this is how zsh/fish/java/zig sources get
    // the text_ops primitive reductions. Gated by DEBASHC_TRANSFORMS
    // inside apply() (text-ops is opt-in there), so default behavior is
    // byte-identical.
    debashl::transforms::apply(&mut prog.stmts);
    // A1 ingress: restructure Label/Goto into structured flow (the shared
    // pass — the CLI's --shir-in-estree/--shir-in-perl run the same
    // restructure_goto_only; without it frontend A1 carrying C `goto`
    // reaches the renderers' Label/Goto arms instead of DoWhile/While).
    // The ESTREE target SKIPS both passes — debashc's `file --estree` is
    // ast_to_ir → shir_to_estree_json DIRECTLY, and the estree emitter
    // handles goto/cfor natively; restructuring changed the output for
    // goto/cfor-bearing examples (gate "stdout mismatch" deltas).
    if kind != "estree" {
        debashl::shir_passes::restructure_goto_only(&mut prog);
        // rich nodes (C-style ForInit) → the shell-flavored A1 the renderers
        // expect; a survivor means this pipeline forgot the strip.
        debashl::shir_passes::strip_cfor(&mut prog);
    }
    let target = match kind {
        "estree" => {
            debashl::shir::shir_to_estree_json(&prog).map_err(|e| format!("estree: {e}"))?
        }
        "perl" => debashl::ir::shir_to_perl(&prog),
        "c" => debashl::c_backend::shir_to_c(&prog),
        "go" => debashl::go_backend::shir_to_go(&prog),
        "python" => debashl::python_backend::shir_to_python(&prog),
        "sh" => debashl::sh_backend::shir_to_sh(&prog)?,
        "java" => debashl::java_backend::shir_to_java(&prog)?,
        "rust" => debashl::rust_backend::shir_to_rust(&prog),
        "zig" => debashl::zig_backend::shir_to_zig(&prog),
        // A1 → GLSL ES 1.00 render fragment — the same options the
        // dedicated otranspilerl_glsl shell→shader entry uses (the
        // MIMEcroft bridges: frag_x/frag_y/vcolor/uv/tex/crack, putb
        // colour output), so frontend A1s render to shaders too. The
        // backend is the pure-computation subset — process/file/external
        // constructs render as /* TODO(unsupported) */ markers.
        "glsl" => debashl::glsl_backend::shir_to_glsl_opts(
            &prog,
            &debashl::glsl_backend::ShGlslOptions {
                es100: true,
                color_out: true,
                vert_out: false,
                tex_size: 32,
                max_view: 800, // the sh2runtime device canvas is fixed 800×600 (mediump gate)
            },
        ),
        // A1 → GLSL ES 1.00 render VERTEX (the other MIMEcroft stage —
        // `sh2glsl --vertex`; the ap_*/ucp_*/ucy_*/… bridges and the
        // vp_*/vc_*/vu_* outputs).
        "glslv" => debashl::glsl_backend::shir_to_glsl_opts(
            &prog,
            &debashl::glsl_backend::ShGlslOptions {
                es100: true,
                color_out: false,
                vert_out: true,
                tex_size: 32,
                max_view: 800, // the sh2runtime device canvas is 800×600
            },
        ),
        "shir" => return Ok(a1.to_string()),
        other => {
            return Err(format!("backend {other:?} not wired"));
        }
    };
    Ok(target)
}

fn read_stdin() -> Result<String, String> {
    let mut s = String::new();
    std::io::Read::read_to_string(&mut std::io::stdin(), &mut s)
        .map_err(|e| format!("stdin: {e}"))?;
    Ok(s)
}

fn abs_path(src: &str) -> String {
    let p = Path::new(src);
    if p.is_absolute() {
        return src.to_string();
    }
    match std::env::current_dir() {
        Ok(cwd) => cwd.join(p).to_string_lossy().into_owned(),
        Err(_) => src.to_string(),
    }
}

/// Emit the neutral A1 for a source file, mirroring the Go wrapper's
/// `emitA1`: `-` or `shir` sources read the A1 verbatim; known non-shell
/// languages spawn their frontend; everything else is shell, handled
/// in-process.
pub fn shir_from(root: &Path, src: &str, src_lang: &str) -> Result<String, String> {
    if src == "-" || src_lang == "shir" {
        return if src == "-" {
            read_stdin()
        } else {
            std::fs::read_to_string(src).map_err(|e| format!("read {src}: {e}"))
        };
    }
    if let Some((_, fe)) = SOURCES
        .iter()
        .find(|(ext, _)| *ext == format!(".{src_lang}").as_str())
    {
        let exe = root.join(fe);
        let abs = abs_path(src);
        let out = run_process(&exe, &["--shir", &abs, "--raw"], &[])?;
        return Ok(String::from_utf8_lossy(&out).into_owned());
    }
    // shell (and unknown source langs): the core, in-process.
    let content = read_source(src)?;
    Ok(shell_to_shir(&content))
}

/// Full pipeline: source file → A1 → target source.
pub fn transpile(root: &Path, src: &str, src_lang: &str, tgt_lang: &str) -> Result<String, String> {
    let a1 = shir_from(root, src, src_lang)?;
    render(&a1, tgt_lang)
}

// ── CLI ───────────────────────────────────────────────────────────────

const USAGE: &str = "otranspiler <input> [<output>] [flags]
  input  file.{py,c,pl,sh,zsh,fish,go,shir}   (no ext = sh; - = A1 from stdin)
  output {-,file}.{c,js,pl,sh,go,rs,zig,java,py,shir}  (no ext = sh; - = stdout)
  --source-lang L   force the source language
  --target L        force the target language
  --run             JS target: execute via the estree runner
  --shir            output the raw A1 contract (same as output ext .shir)
  --embed-perl      Perl target: render an EMBEDDABLE fragment (purify design,
                    PLAN §10) — no preamble/exit; fragment on stdout,
                    REQUIRED/REFUSE diagnostics on stderr
  --literal         treat <input> as literal source text, never as a filename
                    (single-word snippets like `ls` would otherwise hit the
                    file heuristic)
  --scope-vars a,b,c  embed: names the host program declares in the
                    enclosing scope (reused as bare `$x`)
  --backtick        embed: Perl-qx semantics (preserve trailing newlines)
  --english         embed: emit English.pm names instead of $/ $! $@";

/// Run the full CLI for an explicitly-located workspace root, writing to
/// the provided stdout/stderr sinks. Returns the process exit code.
pub fn cli_at(
    root: &Path,
    args: &[String],
    stdout: &mut dyn std::io::Write,
    stderr: &mut dyn std::io::Write,
) -> i32 {
    let mut force_src = String::new();
    let mut force_tgt = String::new();
    let mut do_run = false;
    let mut embed = false;
    let mut literal = false;
    let mut embed_opts = EmbedOpts::default();
    let mut positional: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        match a.as_str() {
            "-h" | "--help" => {
                let _ = writeln!(stderr, "{USAGE}");
                return 0;
            }
            "--run" => do_run = true,
            "--shir" => force_tgt = "shir".into(),
            "--embed-perl" => {
                embed = true;
                force_tgt = "perl".into();
            }
            "--literal" => literal = true,
            "--scope-vars" => {
                if i + 1 < args.len() {
                    embed_opts.host_scope = args[i + 1]
                        .split(',')
                        .map(|s| s.trim().to_string())
                        .filter(|s| !s.is_empty())
                        .collect();
                    i += 1;
                }
            }
            s if s.starts_with("--scope-vars=") => {
                embed_opts.host_scope = s["--scope-vars=".len()..]
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect();
            }
            "--backtick" => embed_opts.backtick = true,
            "--english" => embed_opts.english = true,
            "--source-lang" => {
                if i + 1 < args.len() {
                    force_src = args[i + 1].clone();
                    i += 1;
                }
            }
            "--target" => {
                if i + 1 < args.len() {
                    force_tgt = args[i + 1].clone();
                    i += 1;
                }
            }
            s if s.starts_with("--source-lang=") => {
                force_src = s["--source-lang=".len()..].to_string();
            }
            s if s.starts_with("--target=") => {
                force_tgt = s["--target=".len()..].to_string();
            }
            _ => positional.push(a.clone()),
        }
        i += 1;
    }

    if positional.is_empty() {
        let _ = writeln!(stderr, "{USAGE}");
        return 2;
    }
    let input = positional[0].clone();
    let output = positional.get(1).cloned().unwrap_or_default();

    let src_lang = if force_src.is_empty() {
        lang_of(&input).to_string()
    } else {
        force_src.clone()
    };
    let tgt_lang = if force_tgt.is_empty() {
        if output.is_empty() {
            "js".to_string()
        } else {
            lang_of(&output).to_string()
        }
    } else {
        force_tgt.clone()
    };

    if embed {
        // embed profile: snippet A1 → embeddable Perl fragment. Fragment on
        // stdout (splice-clean); REQUIRED/REFUSE diagnostics on stderr so
        // the caller (harvester/splice engine) can gate and fall back.
        let a1 = if literal {
            Ok(shell_to_shir(&input))
        } else {
            shir_from(root, &input, &src_lang)
        };
        let a1 = match a1 {
            Ok(a1) => a1,
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler: {e}");
                return 1;
            }
        };
        let res = match render_embed(&a1, &embed_opts) {
            Ok(res) => res,
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler: {e}");
                return 1;
            }
        };
        for r in &res.refusals {
            let _ = writeln!(stderr, "REFUSE: {r}");
        }
        if !res.required_host_bindings.is_empty() {
            let _ = writeln!(
                stderr,
                "REQUIRED: {}",
                res.required_host_bindings.join(",")
            );
        }
        return write_out(stdout, stderr, &output, res.fragment.as_bytes());
    }

    if tgt_lang == "shir" {
        // emit the neutral A1: run the frontend (or pass .shir input through)
        let a1 = match shir_from(root, &input, &src_lang) {
            Ok(a1) => a1,
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler: {e}");
                return 1;
            }
        };
        return write_out(stdout, stderr, &output, a1.as_bytes());
    }

    // ESTree parity with debashc's DIRECT path: the corpus baseline
    // (`file --estree`) is ast_to_ir → shir_to_estree_json with NO shIR
    // JSON round-trip — even debashc's own --shir-in-estree round-trip
    // differs from it. For shell sources, replicate the direct path
    // exactly (byte-marked reads; parse error → the process.exit(2)
    // fallback above).
    if tgt_lang == "estree" && src_lang == "sh" && input != "-" {
        let content = match read_source(&input) {
            Ok(c) => c,
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler: {e}");
                return 1;
            }
        };
        let commands = match debashl::Parser::new(&content).parse() {
            Ok(c) => c,
            Err(_) => {
                return write_out(
                    stdout,
                    stderr,
                    &output,
                    parse_error_estree_fallback().as_bytes(),
                );
            }
        };
        // the corpus baseline (`file --estree`) is the estree module's
        // AST-level emitter — debashl::estree::ast_to_estree_json — NOT the
        // shIR path (shir_to_estree_json); they differ on process
        // substitution etc. (verified on 012_process_substitution.sh).
        return match debashl::estree::ast_to_estree_json(&commands) {
            Ok(json) => write_out(stdout, stderr, &output, json.as_bytes()),
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler: estree: {e}");
                1
            }
        };
    }

    // the pipeline: A1 -> the target backend -> output
    let a1 = match shir_from(root, &input, &src_lang) {
        Ok(a1) => a1,
        Err(e) => {
            let _ = writeln!(stderr, "otranspiler: {e}");
            return 1;
        }
    };
    // ESTree parse-error parity with debashc: a shell source that fails to
    // parse renders the process.exit(2) fallback (the plain empty Program
    // exits 0 — gate "exit code (bash=2 estree=0)" failures). Only for
    // in-process shell sources (a `-`/`.shir` A1 input has no parse).
    if (tgt_lang == "estree" || (tgt_lang == "js" && !do_run)) && src_lang == "sh" {
        if let Ok(content) = read_source(&input) {
            if debashl::Parser::new(&content).parse().is_err() {
                return write_out(
                    stdout,
                    stderr,
                    &output,
                    parse_error_estree_fallback().as_bytes(),
                );
            }
        }
    }
    let out = match render(&a1, &tgt_lang) {
        Ok(out) => out,
        Err(e) => {
            let _ = writeln!(stderr, "otranspiler: {e}");
            return 1;
        }
    };

    if tgt_lang == "js" && do_run {
        return run_estree(root, &input, out.as_bytes(), stderr);
    }
    write_out(stdout, stderr, &output, out.as_bytes())
}

/// `--run`: execute the emitted ESTree via the reference runner.
fn run_estree(root: &Path, input: &str, estree: &[u8], stderr: &mut dyn std::io::Write) -> i32 {
    #[cfg(not(target_family = "wasm"))]
    {
        use std::io::Write;
        let runner = root.join("harness/estree-runner.mjs");
        let mut child = match std::process::Command::new("node")
            .arg(&runner)
            .arg("/dev/stdin")
            .arg("--source")
            .arg(input)
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::inherit())
            .stderr(std::process::Stdio::inherit())
            .spawn()
        {
            Ok(c) => c,
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler --run: spawn node: {e}");
                return 1;
            }
        };
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(estree);
        }
        match child.wait() {
            Ok(status) => status.code().unwrap_or(1),
            Err(e) => {
                let _ = writeln!(stderr, "otranspiler --run: {e}");
                1
            }
        }
    }
    #[cfg(target_family = "wasm")]
    {
        let _ = (root, input, estree);
        let _ = writeln!(
            stderr,
            "otranspiler --run: node spawn not available in this build"
        );
        1
    }
}

fn write_out(
    stdout: &mut dyn std::io::Write,
    stderr: &mut dyn std::io::Write,
    output: &str,
    data: &[u8],
) -> i32 {
    if output.is_empty() || output == "-" {
        if stdout.write_all(data).is_err() {
            return 1;
        }
        return 0;
    }
    match std::fs::write(output, data) {
        Ok(()) => 0,
        Err(e) => {
            let _ = writeln!(stderr, "otranspiler: {e}");
            1
        }
    }
}

/// Run the CLI as a process would: workspace root auto-located, output to
/// real stdout/stderr. This is the entire "binary" — see `src/main.rs`.
pub fn cli(args: &[String]) -> i32 {
    let root = match workspace_root() {
        Some(r) => r,
        None => {
            eprintln!("otranspiler: cannot locate the workspace root (set OTRANSPILER_ROOT)");
            return 1;
        }
    };
    cli_at(&root, args, &mut std::io::stdout(), &mut std::io::stderr())
}

/// Run the CLI with output captured (no stdio): returns `(exit, stdout,
/// stderr)`. Used by the WASM C-ABI export and the tests.
pub fn cli_captured(root: &Path, args: &[String]) -> (i32, String, String) {
    let mut out: Vec<u8> = Vec::new();
    let mut err: Vec<u8> = Vec::new();
    let code = cli_at(root, args, &mut out, &mut err);
    (
        code,
        String::from_utf8_lossy(&out).into_owned(),
        String::from_utf8_lossy(&err).into_owned(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn root() -> PathBuf {
        workspace_root().expect("workspace root (sh2perl + frontends present)")
    }

    fn embed(args: &[&str]) -> (i32, String, String) {
        cli_captured(&root(), &args.iter().map(|s| s.to_string()).collect::<Vec<_>>())
    }

    #[test]
    fn embed_fragment_has_no_preamble() {
        let (code, out, err) = embed(&["--embed-perl", "echo hi; x=5; echo $x"]);
        assert_eq!(code, 0, "stderr: {err}");
        for banned in [
            "#!/usr/bin/env perl",
            "use strict",
            "use warnings",
            "use Carp",
            "use English",
            "exit $main_exit_code",
            "my $main_exit_code",
        ] {
            assert!(!out.contains(banned), "fragment must not contain {banned:?}: {out}");
        }
        assert!(out.contains("do {"), "fragment wrapped in a do-block: {out}");
    }

    #[test]
    fn embed_bindings_gate_on_stderr() {
        // host-scope read: bare `$x` reuse, required binding reported
        let (code, out, err) = embed(&["--embed-perl", "--scope-vars", "x", "echo $x"]);
        assert_eq!(code, 0, "stderr: {err}");
        assert!(err.contains("REQUIRED: x"), "stderr: {err}");
        assert!(!out.contains("my $x"), "host-scope read must not be declared: {out}");
        // without scope: local `my $x = '';`, nothing required
        let (_, out2, err2) = embed(&["--embed-perl", "echo $x"]);
        assert!(out2.contains("my $x = '';"), "local decl: {out2}");
        assert!(!err2.contains("REQUIRED"), "stderr: {err2}");
    }

    #[test]
    fn embed_refusal_on_stderr() {
        // `exit 3` would terminate the host — refused, fallback eligible
        let (code, out, err) = embed(&["--embed-perl", "exit 3"]);
        assert_eq!(code, 0, "refusal is a verdict, not an error; stderr: {err}");
        assert!(err.contains("REFUSE"), "stderr: {err}");
        assert!(out.contains("exit"), "fragment still emitted for inspection: {out}");
    }

    #[test]
    fn embed_deterministic_across_runs() {
        let args = &["--embed-perl", "--scope-vars", "x", "x=$((x+1)); echo $x"];
        let (_, a, _) = embed(args);
        let (_, b, _) = embed(args);
        assert_eq!(a, b, "embed output must be byte-stable");
    }

    #[test]
    fn embed_english_and_backtick_flags() {
        // --english keeps English.pm names ($INPUT_RECORD_SEPARATOR/$OS_ERROR
        // in the cat emulation); the default normalizes to $/ / $!
        let snip = "y=$(cat /etc/hostname); echo $y";
        let (_, out_en, _) = embed(&["--embed-perl", "--english", snip]);
        let (_, out_def, _) = embed(&["--embed-perl", snip]);
        assert!(
            out_en.contains("$INPUT_RECORD_SEPARATOR") && out_en.contains("$OS_ERROR"),
            "--english keeps English.pm names: {out_en}"
        );
        assert!(
            out_def.contains("local $/") && out_def.contains("$!"),
            "default normalizes: {out_def}"
        );
        // --backtick preserves trailing newlines (drops the chomp the
        // standalone $() semantics apply); default strips them
        let snip2 = "x=$(echo hi); echo $x";
        let (_, out_bt, _) = embed(&["--embed-perl", "--backtick", snip2]);
        let (_, out_nb, _) = embed(&["--embed-perl", snip2]);
        assert!(
            !out_bt.contains("chomp $_r;") && out_nb.contains("chomp $_r;"),
            "--backtick must drop the command-substitution chomp: {out_bt} / {out_nb}"
        );
    }
}
