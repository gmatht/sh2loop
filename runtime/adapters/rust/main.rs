// adapters/rust/main.rs — the Rust backend's thin adapter for the C
// polyfills. Links libsh2poly.a directly (no FFI overhead) and maps the
// sh2.* call-site convention to sh2poly_dispatch.
//
// Build: rustc -O main.rs -L ../.. -l static=sh2poly -o sh2poly-adapter
// Run:   ./sh2poly-adapter   (reads adapters/battery.txt)
//
// The battery runner: reads battery.txt (TAB-separated fields, `\\` →
// backslash, `\n` → newline), sets up the deterministic stdin,
// dispatches every call, prints `== name` / `status=N`.
use std::ffi::CString;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::io::AsRawFd;

extern "C" {
    fn sh2poly_init();
    fn sh2poly_dispatch(argc: i32, argv: *mut *mut i8) -> i32;
    fn dup2(oldfd: i32, newfd: i32) -> i32;
}

fn unescape(field: &str) -> String {
    let mut out = String::new();
    let mut chars = field.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            match chars.next() {
                Some('\\') => out.push('\\'),
                Some('n') => out.push('\n'),
                Some('t') => out.push('\t'),
                Some(other) => {
                    out.push('\\');
                    out.push(other);
                }
                None => out.push('\\'),
            }
        } else {
            out.push(c);
        }
    }
    out
}

fn dispatch(name: &str, args: &[String]) -> i32 {
    let mut cstrings: Vec<CString> = Vec::new();
    cstrings.push(CString::new(name).unwrap());
    for a in args {
        cstrings.push(CString::new(a.as_str()).unwrap());
    }
    let mut ptrs: Vec<*mut i8> = cstrings.iter().map(|c| c.as_ptr() as *mut i8).collect();
    ptrs.push(std::ptr::null_mut());
    unsafe { sh2poly_dispatch(ptrs.len() as i32 - 1, ptrs.as_mut_ptr()) }
}

fn main() {
    unsafe { sh2poly_init(); }  // unbuffer the C library's stdout
    // the adapter's own prints must flush before/after each dispatch
    let stdout = std::io::stdout();
    let mut out = stdout.lock();

    // deterministic stdin for the read/readarray calls
    std::fs::write("/tmp/sh2poly_selftest_in.txt", "alpha beta gamma\none\ntwo\nthree\n").unwrap();
    let stdin_file = File::open("/tmp/sh2poly_selftest_in.txt").unwrap();
    unsafe {
        dup2(stdin_file.as_raw_fd(), 0);
    }

    let battery = File::open("adapters/battery.txt")
        .unwrap_or_else(|_| File::open("battery.txt").unwrap());
    for line in BufReader::new(battery).lines() {
        let line = line.unwrap();
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        let name = fields[0];
        let args: Vec<String> = fields[1..].iter().map(|f| unescape(f)).collect();
        writeln!(out, "== {}", name).unwrap();
        out.flush().unwrap();
        let st = dispatch(name, &args);
        writeln!(out, "status={}", st).unwrap();
        out.flush().unwrap();
    }
}
