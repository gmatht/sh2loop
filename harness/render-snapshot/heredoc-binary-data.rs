use std::sync::atomic::Ordering;

static __SH_RC: std::sync::atomic::AtomicI32 = std::sync::atomic::AtomicI32::new(0);
static __SH_ARGV: std::sync::Mutex<Vec<String>> = std::sync::Mutex::new(Vec::new());
static __SH_OUT: std::sync::Mutex<Option<Vec<u8>>> = std::sync::Mutex::new(None);
thread_local! { static __SH_OUTFILE_TL: std::cell::RefCell<Option<std::fs::File>> = const { std::cell::RefCell::new(None) }; }
static __SH_STDIN: std::sync::Mutex<Option<Box<dyn std::io::Read + Send>>> = std::sync::Mutex::new(None);
static __SH_STDIN_PATH: std::sync::Mutex<Option<std::path::PathBuf>> = std::sync::Mutex::new(None);

static __SH_TRAPS: std::sync::Mutex<Vec<String>> = std::sync::Mutex::new(Vec::new());

thread_local! { #[allow(non_upper_case_globals)] static __SHV_INTERPRETER_UNDER_TEST: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }

fn __sh_q(s: &str) -> String {
    let mut o = String::with_capacity(s.len() + 8);
    o.push('\'');
    for c in s.chars() {
        if c == '\'' { o.push_str("'\\''"); } else { o.push(c); }
    }
    o.push('\'');
    o
}

fn __sh_wq(ws: &[String]) -> String {
    let mut o = String::new();
    for (i, w) in ws.iter().enumerate() {
        if i > 0 { o.push(' '); }
        o.push_str(&__sh_q(w));
    }
    o
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

fn __sh_arg(i: usize) -> String {
    __SH_ARGV.lock().unwrap().get(i).cloned().unwrap_or_default()
}

fn __sh_run_traps() {
    let hs = std::mem::take(&mut *__SH_TRAPS.lock().unwrap());
    for h in hs { let _ = __sh_spawn(&h, None); }
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
    __SHV_INTERPRETER_UNDER_TEST.with(|v| *v.borrow_mut() = { let (__c, __r) = __sh_capture_rc(&__sh_wq(&vec!["command".to_string(), "-v".to_string(), { let __v = __sh_arg(0); if __v.is_empty() { "python3".to_string() } else { __v.to_string() } }])); __SH_RC.store(__r, Ordering::Relaxed); __c });
    if __SHV_INTERPRETER_UNDER_TEST.with(|v| v.borrow().clone()) == "".to_string() {
        print!("Interpreter must be the command line argument.\n");
        __SH_RC.store(0, Ordering::Relaxed);
        __sh_run_traps();
        std::process::exit(4);
    } else {
        __SH_RC.store(0, Ordering::Relaxed);
    }
    __SH_RC.store(__sh_spawn(&__sh_wq(&vec![__SHV_INTERPRETER_UNDER_TEST.with(|v| v.borrow().clone()), "-E".to_string(), "-".to_string()]), Some("print('Hello from embedded Python')\n".to_string().as_bytes())), Ordering::Relaxed);
    std::process::ExitCode::from(__SH_RC.load(Ordering::Relaxed) as u8)
}