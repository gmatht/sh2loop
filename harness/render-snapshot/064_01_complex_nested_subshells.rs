use std::sync::atomic::Ordering;

static __SH_RC: std::sync::atomic::AtomicI32 = std::sync::atomic::AtomicI32::new(0);

static __SH_OUT: std::sync::Mutex<Option<Vec<u8>>> = std::sync::Mutex::new(None);
thread_local! { static __SH_OUTFILE_TL: std::cell::RefCell<Option<std::fs::File>> = const { std::cell::RefCell::new(None) }; }
static __SH_STDIN: std::sync::Mutex<Option<Box<dyn std::io::Read + Send>>> = std::sync::Mutex::new(None);
static __SH_STDIN_PATH: std::sync::Mutex<Option<std::path::PathBuf>> = std::sync::Mutex::new(None);

static __SH_PIPESTATUS: std::sync::Mutex<Vec<i32>> = std::sync::Mutex::new(Vec::new());

thread_local! { #[allow(non_upper_case_globals)] static __SHV___ps_tmp0: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }
thread_local! { #[allow(non_upper_case_globals)] static __SHV___ps_tmp1: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }
thread_local! { #[allow(non_upper_case_globals)] static __SHV___ps_tmp2: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }
thread_local! { #[allow(non_upper_case_globals)] static __SHV___ps_tmp3: std::cell::RefCell<String> = const { std::cell::RefCell::new(String::new()) }; }

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

fn __sh_run(cmd: &str) -> i32 {
    __sh_spawn(cmd, None)
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
    __SHV___ps_tmp1.with(|v| *v.borrow_mut() = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    __SH_RC.store(__sh_run("'mktemp'"), Ordering::Relaxed);
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
});
    {
        let __oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
        __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = Some(std::fs::File::create(&__SHV___ps_tmp1.with(|v| v.borrow().clone())).unwrap_or_else(|_| std::fs::File::open("/dev/null").unwrap())));
        __SHV___ps_tmp0.with(|v| *v.borrow_mut() = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    __SH_RC.store(__sh_run("'mktemp'"), Ordering::Relaxed);
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
});
        {
            let __oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
            __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = Some(std::fs::File::create(&__SHV___ps_tmp0.with(|v| v.borrow().clone())).unwrap_or_else(|_| std::fs::File::open("/dev/null").unwrap())));
            let mut __sh_pbuf0: Vec<u8> = Vec::new();
            __SH_PIPESTATUS.lock().unwrap().clear();
            __SH_RC.store(__sh_spawn(&format!("{} | {}", "'grep' '-v' '^#' '/etc/passwd'".to_string(), "'cut' '-d' ':' '-f' '1'".to_string()), Some(&__sh_pbuf0)), Ordering::Relaxed);
            __SH_PIPESTATUS.lock().unwrap().push(__SH_RC.load(Ordering::Relaxed));
            __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __oldout);
        }
        __SH_RC.store(__sh_run(&__sh_wq(&vec!["sort".to_string(), __SHV___ps_tmp0.with(|v| v.borrow().clone())])), Ordering::Relaxed);
        let __ps_saved_rc = __SH_RC.load(Ordering::Relaxed);
        __SH_RC.store(__sh_run(&__sh_wq(&vec!["rm".to_string(), "-f".to_string(), __SHV___ps_tmp0.with(|v| v.borrow().clone())])), Ordering::Relaxed);
        __SH_RC.store(__ps_saved_rc, Ordering::Relaxed);
        __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __oldout);
    }
    __SHV___ps_tmp3.with(|v| *v.borrow_mut() = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    __SH_RC.store(__sh_run("'mktemp'"), Ordering::Relaxed);
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
});
    {
        let __oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
        __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = Some(std::fs::File::create(&__SHV___ps_tmp3.with(|v| v.borrow().clone())).unwrap_or_else(|_| std::fs::File::open("/dev/null").unwrap())));
        __SHV___ps_tmp2.with(|v| *v.borrow_mut() = {
    let __cap_oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
    let __old = __SH_OUT.lock().unwrap().take();
    *__SH_OUT.lock().unwrap() = Some(Vec::new());
    let __cap_oldin = __SH_STDIN.lock().unwrap().take();
    __SH_RC.store(__sh_run("'mktemp'"), Ordering::Relaxed);
    *__SH_STDIN.lock().unwrap() = __cap_oldin;
    let __cap = __SH_OUT.lock().unwrap().take().unwrap();
    *__SH_OUT.lock().unwrap() = __old;
    __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __cap_oldout);
    let mut __s = String::from_utf8_lossy(&__cap).to_string();
    while __s.ends_with('\n') { __s.pop(); }
    __s
});
        {
            let __oldout = __SH_OUTFILE_TL.with(|v| v.borrow_mut().take());
            __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = Some(std::fs::File::create(&__SHV___ps_tmp2.with(|v| v.borrow().clone())).unwrap_or_else(|_| std::fs::File::open("/dev/null").unwrap())));
            let mut __sh_pbuf1: Vec<u8> = Vec::new();
            __SH_PIPESTATUS.lock().unwrap().clear();
            __SH_RC.store(__sh_spawn(&format!("{} | {}", "'grep' '-v' '^#' '/etc/group'".to_string(), "'cut' '-d' ':' '-f' '1'".to_string()), Some(&__sh_pbuf1)), Ordering::Relaxed);
            __SH_PIPESTATUS.lock().unwrap().push(__SH_RC.load(Ordering::Relaxed));
            __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __oldout);
        }
        __SH_RC.store(__sh_run(&__sh_wq(&vec!["sort".to_string(), __SHV___ps_tmp2.with(|v| v.borrow().clone())])), Ordering::Relaxed);
        let __ps_saved_rc = __SH_RC.load(Ordering::Relaxed);
        __SH_RC.store(__sh_run(&__sh_wq(&vec!["rm".to_string(), "-f".to_string(), __SHV___ps_tmp2.with(|v| v.borrow().clone())])), Ordering::Relaxed);
        __SH_RC.store(__ps_saved_rc, Ordering::Relaxed);
        __SH_OUTFILE_TL.with(|v| *v.borrow_mut() = __oldout);
    }
    __SH_RC.store(__sh_run(&__sh_wq(&vec!["diff".to_string(), __SHV___ps_tmp1.with(|v| v.borrow().clone()), __SHV___ps_tmp3.with(|v| v.borrow().clone())])), Ordering::Relaxed);
    let __ps_saved_rc = __SH_RC.load(Ordering::Relaxed);
    __SH_RC.store(__sh_run(&__sh_wq(&vec!["rm".to_string(), "-f".to_string(), __SHV___ps_tmp1.with(|v| v.borrow().clone()), __SHV___ps_tmp3.with(|v| v.borrow().clone())])), Ordering::Relaxed);
    __SH_RC.store(__ps_saved_rc, Ordering::Relaxed);
    println!("done: {}", __SH_RC.load(Ordering::Relaxed));
    __SH_RC.store(0, Ordering::Relaxed);
    std::process::ExitCode::SUCCESS
}