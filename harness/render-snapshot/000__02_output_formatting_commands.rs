use std::sync::atomic::Ordering;

static __SH_RC: std::sync::atomic::AtomicI32 = std::sync::atomic::AtomicI32::new(0);

static __SH_OUT: std::sync::Mutex<Option<Vec<u8>>> = std::sync::Mutex::new(None);
thread_local! { static __SH_OUTFILE_TL: std::cell::RefCell<Option<std::fs::File>> = const { std::cell::RefCell::new(None) }; }
static __SH_STDIN: std::sync::Mutex<Option<Box<dyn std::io::Read + Send>>> = std::sync::Mutex::new(None);
static __SH_STDIN_PATH: std::sync::Mutex<Option<std::path::PathBuf>> = std::sync::Mutex::new(None);

static __SH_PIPESTATUS: std::sync::Mutex<Vec<i32>> = std::sync::Mutex::new(Vec::new());
static __SH_TRAPS: std::sync::Mutex<Vec<String>> = std::sync::Mutex::new(Vec::new());

static __SH_ARITH_WORD_FAIL: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

thread_local! { #[allow(non_upper_case_globals)] static __SHV_d: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }

fn __sh_print_words(ws: &[Vec<String>], nl: bool, _esc: bool) {
    if __SH_ARITH_WORD_FAIL.swap(false, Ordering::Relaxed) { return; }
    let mut s = ws.iter().flatten().map(String::as_str).collect::<Vec<_>>().join(" ");
    if nl { s.push('\n'); }
    __sh_sink(s.as_bytes());
}

fn __sh_puts(s: &str) {
    __sh_sink(s.as_bytes());
}

fn __sh_capture_rc(cmd: &str) -> (String, i32) {
    let mut c = std::process::Command::new("bash");
    c.arg("-c").arg(cmd);
    c.stdout(std::process::Stdio::piped());
    c.stdin(std::process::Stdio::inherit());
    let mut ch = match c.spawn() { Ok(x) => x, Err(_) => return (String::new(), 1) };
    let mut out = Vec::new();
    if let Some(mut so) = ch.stdout.take() {
        let _ = std::io::Read::read_to_end(&mut so, &mut out);
    }
    let rc = ch.wait().map(|s| s.code().unwrap_or(1)).unwrap_or(1);
    let mut s = String::from_utf8_lossy(&out).to_string();
    while s.ends_with('\n') { s.pop(); }
    (s, rc)
}

fn __sh_spawn(cmd: &str, input: Option<&[u8]>) -> i32 {
    let mut input = input.map(|d| d.to_vec());
    let stdin_path = __SH_STDIN_PATH.lock().unwrap().clone();
    if input.is_none() && stdin_path.is_none() {
        if let Some(mut r) = __SH_STDIN.lock().unwrap().take() {
            let mut d = Vec::new();
            let _ = std::io::Read::read_to_end(&mut r, &mut d);
            input = Some(d);
        }
    }
    let want_out = __SH_OUT.lock().unwrap().is_some() || __SH_OUTFILE_TL.with(|v| v.borrow().is_some());
    let mut c = std::process::Command::new("bash");
    c.arg("-c").arg(cmd);
    if !want_out {
        let _ = std::io::Write::flush(&mut std::io::stdout());
    }
    if want_out { c.stdout(std::process::Stdio::piped()); }
    if input.is_none() {
        if let Some(p) = &stdin_path {
            if let Ok(f) = std::fs::File::open(p) {
                c.stdin(std::process::Stdio::from(f));
            }
        }
    }
    if input.is_some() { c.stdin(std::process::Stdio::piped()); }
    let mut ch = match c.spawn() { Ok(x) => x, Err(_) => return 1 };
    if let Some(data) = input {
        if let Some(mut si) = ch.stdin.take() { let _ = std::io::Write::write_all(&mut si, &data); }
    }
    let mut out = Vec::new();
    if let Some(mut so) = ch.stdout.take() {
        let _ = std::io::Read::read_to_end(&mut so, &mut out);
    }
    let rc = ch.wait().map(|s| s.code().unwrap_or(1)).unwrap_or(1);
    if !out.is_empty() { __sh_sink(&out); }
    rc
}

fn __sh_run_traps() {
    let hs = std::mem::take(&mut *__SH_TRAPS.lock().unwrap());
    for h in hs { let _ = __sh_spawn(&h, None); }
}

fn __sh_rm(argv: &[String]) -> i32 {
    let mut force = false;
    let mut recursive = false;
    let mut dir_ok = false;
    let mut end_opts = false;
    let mut ops: Vec<&String> = Vec::new();
    for a in argv {
        if !end_opts {
            if a == "--" { end_opts = true; continue; }
            if a.len() > 1 && a.starts_with('-') {
                for c in a[1..].chars() {
                    match c {
                        'f' => force = true,
                        'r' | 'R' => recursive = true,
                        'd' => dir_ok = true,
                        _ => { eprintln!("rm: invalid option -- '{}'", c); return 1; }
                    }
                }
                continue;
            }
        }
        ops.push(a);
    }
    if ops.is_empty() {
        if force { return 0; }
        eprintln!("rm: missing operand");
        return 1;
    }
    let mut rc = 0;
    for p in ops {
        let path = std::path::Path::new(p);
        let meta = match std::fs::symlink_metadata(path) {
            Ok(m) => m,
            Err(e) => {
                if force && e.kind() == std::io::ErrorKind::NotFound { continue; }
                eprintln!("rm: cannot remove '{}': {}", p, e);
                rc = 1;
                continue;
            }
        };
        let is_dir = meta.is_dir();
        if is_dir && !recursive && !dir_ok {
            eprintln!("rm: cannot remove '{}': Is a directory", p);
            rc = 1;
            continue;
        }
        let res = if is_dir {
            if recursive { std::fs::remove_dir_all(path) } else { std::fs::remove_dir(path) }
        } else {
            std::fs::remove_file(path)
        };
        if let Err(e) = res {
            if force && e.kind() == std::io::ErrorKind::NotFound { continue; }
            eprintln!("rm: cannot remove '{}': {}", p, e);
            rc = 1;
        }
    }
    rc
}

fn __sh_mktemp(dir: bool, tmpl: &str) -> String {
    let t = if tmpl.is_empty() {
        let d = std::env::var("TMPDIR").ok().filter(|d| !d.is_empty()).unwrap_or_else(|| "/tmp".to_string());
        format!("{}/tmp.XXXXXXXXXX", d.trim_end_matches('/'))
    } else {
        tmpl.to_string()
    };
    let base = t.trim_end_matches('X').to_string();
    let nx = t.len() - base.len();
    let nx = if nx == 0 { 10 } else { nx };
    let cs: &[u8] = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for n in 0..100000u64 {
        let seed = (std::process::id() as u64).wrapping_mul(1_000_003)
            ^ n.wrapping_mul(7_919)
            ^ std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.subsec_nanos() as u64)
                .unwrap_or(0);
        let mut x = seed | 1;
        let mut s = base.clone();
        for _ in 0..nx { s.push(cs[(x % 62) as usize] as char); x /= 62; }
        let ok = if dir {
            std::fs::create_dir(&s).is_ok()
        } else {
            std::fs::OpenOptions::new().write(true).create_new(true).open(&s).is_ok()
        };
        if ok { return s; }
    }
    String::new()
}

fn __sh_sink(b: &[u8]) {
    let mut used = false;
    __SH_OUTFILE_TL.with(|v| { if let Some(f) = v.borrow_mut().as_mut() { let _ = std::io::Write::write_all(f, b); used = true; } });
    if used { return; }
    if let Some(o) = __SH_OUT.lock().unwrap().as_mut() { o.extend_from_slice(b); return; }
    let _ = std::io::Write::write_all(&mut std::io::stdout(), b);
}

#[allow(non_upper_case_globals)]
fn main() -> std::process::ExitCode {
    print!("=== Output and Formatting Commands ===\n");
    __SH_RC.store(0, Ordering::Relaxed);
    __sh_print_words(&[vec![format!("Echo result: {}", "Hello from backticks".to_string())]], true, false);
    __SH_RC.store(0, Ordering::Relaxed);
    __sh_print_words(&[vec![format!("Printf result: {}", "Number: 42, String: test".to_string())]], true, false);
    print!("=== Compression Commands ===\n");
    print!("=== Network Commands ===\n");
    print!("=== Process Management Commands ===\n");
    __SH_RC.store(0, Ordering::Relaxed);
    __SHV_d.with(|v| *v.borrow_mut() = { let __c = __sh_mktemp(true, &""); __SH_RC.store(if __c.is_empty() { 1 } else { 0 }, Ordering::Relaxed); __c });
    { let __b = { let __d = __SHV_d.with(|v| v.borrow().clone()); let __r = std::env::set_current_dir(&__d); if __r.is_ok() { std::env::set_var("PWD", std::env::current_dir().map(|p| p.display().to_string()).unwrap_or_default()); } __SH_RC.store(if __r.is_ok() { 0 } else { 1 }, Ordering::Relaxed); __r.is_ok() }; __SH_RC.store(if __b { 0 } else { 1 }, Ordering::Relaxed); if !__b {
        __sh_run_traps();
        std::process::exit(1);
    }
    }
    print!("=== Checksum Commands ===\n");
    let _ = std::fs::write("test_checksum.txt".to_string(), "test content\n".to_string());
    __SH_RC.store(0, Ordering::Relaxed);
    let sha256_result = { let (__c, __r) = __sh_capture_rc("'sha256sum' 'test_checksum.txt'"); __SH_RC.store(__r, Ordering::Relaxed); __c };
    __sh_print_words(&[vec![format!("SHA256 result: {}", sha256_result.clone())]], true, false);
    __SH_RC.store(0, Ordering::Relaxed);
    let sha512_result = { let (__c, __r) = __sh_capture_rc("'sha512sum' 'test_checksum.txt'"); __SH_RC.store(__r, Ordering::Relaxed); __c };
    __sh_print_words(&[vec![format!("SHA512 result: {}", sha512_result.clone())]], true, false);
    __SH_RC.store(0, Ordering::Relaxed);
    let strings_result = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    let mut __sh_pbuf0: Vec<u8> = Vec::new();
    __SH_PIPESTATUS.lock().unwrap().clear();
    __SH_RC.store(__sh_spawn(&format!("{} | {}", "'strings' 'test_binary.txt'".to_string(), "'head' '-3'".to_string()), Some(&__sh_pbuf0)), Ordering::Relaxed);
    __SH_PIPESTATUS.lock().unwrap().push(__SH_RC.load(Ordering::Relaxed));
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
};
    print!("Strings result:\n");
    __sh_print_words(&[vec![strings_result.clone()]], true, false);
    print!("=== I/O Redirection Commands ===\n");
    __SH_RC.store(0, Ordering::Relaxed);
    let tee_result = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    let mut __sh_pbuf1: Vec<u8> = Vec::new();
    __SH_PIPESTATUS.lock().unwrap().clear();
    {
    let __sh_oldout2 = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    __sh_puts("test output\n");
    __SH_RC.store(0, Ordering::Relaxed);
    __sh_pbuf1 = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __sh_oldout2);
    __SH_PIPESTATUS.lock().unwrap().push(__SH_RC.load(Ordering::Relaxed));
}
    __SH_RC.store(__sh_spawn("'tee' 'test_tee.txt'", Some(&__sh_pbuf1)), Ordering::Relaxed);
    __SH_PIPESTATUS.lock().unwrap().push(__SH_RC.load(Ordering::Relaxed));
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
};
    __sh_print_words(&[vec![format!("Tee result: {}", tee_result.clone())]], true, false);
    print!("=== Perl Command ===\n");
    __SH_RC.store(0, Ordering::Relaxed);
    let perl_result = { let (__c, __r) = __sh_capture_rc("'perl' '-e' 'print \"Hello from Perl\\n\"'"); __SH_RC.store(__r, Ordering::Relaxed); __c };
    __sh_print_words(&[vec![format!("Perl result: {}", perl_result.clone())]], true, false);
    __SH_RC.store(0, Ordering::Relaxed);
    __SH_RC.store(__sh_rm(&vec!["-f".to_string(), "test_checksum.txt".to_string(), "test_tee.txt".to_string()]), Ordering::Relaxed);
    { let __d = "/".to_string(); let __r = std::env::set_current_dir(&__d); if __r.is_ok() { std::env::set_var("PWD", std::env::current_dir().map(|p| p.display().to_string()).unwrap_or_default()); } __SH_RC.store(if __r.is_ok() { 0 } else { 1 }, Ordering::Relaxed); };
    __SH_RC.store(__sh_rm(&vec!["-r".to_string(), "-f".to_string(), __SHV_d.with(|v| v.borrow().clone())]), Ordering::Relaxed);
    std::process::ExitCode::from(__SH_RC.load(Ordering::Relaxed) as u8)
}