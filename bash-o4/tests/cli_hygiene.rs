//! CLI hygiene: things that must hold for *any* command-line tool we ship.
//!
//! These drive the real binaries, so they cover the wiring (a fix applied to
//! one `main` and not the other fails here).

use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::process::ExitStatusExt;
use std::process::{Command, Stdio};

fn bin(name: &str) -> std::path::PathBuf {
    let mut p = std::env::current_exe().expect("current_exe");
    p.pop();
    if p.ends_with("deps") {
        p.pop();
    }
    p.push(name);
    p
}

/// Run `<bin> <args...>` with stdout piped, read ONE line, then close the
/// read end — exactly what `head -n 1` does.
///
/// Returns `(exit_code, terminating_signal, stderr)`.  Dying on `SIGPIPE`
/// reports `exit_code == None` and `signal == Some(13)`; a shell would render
/// that as status 141.
fn run_with_head(args: &[&str]) -> (Option<i32>, Option<i32>, String) {
    let mut child = Command::new(bin("bash-O4"))
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn");
    {
        let out = child.stdout.take().expect("piped stdout");
        let mut r = BufReader::new(out);
        let mut line = String::new();
        let _ = r.read_line(&mut line);
        // Dropping `r` closes the read end while the child is still writing.
    }
    let status = child.wait().expect("wait");
    let mut err = String::new();
    if let Some(mut e) = child.stderr.take() {
        let _ = e.read_to_string(&mut err);
    }
    (status.code(), status.signal(), err)
}

/// A script with enough loops that `--check` is still writing when the reader
/// goes away (otherwise the race makes the test vacuous).
fn many_loops(path: &std::path::Path) {
    let mut src = String::from("#!/bin/bash\n");
    for i in 0..200 {
        src.push_str(&format!("for ((i=0;i<{i};i++)); do a[$i]=$((i*2)); done\n"));
    }
    let mut f = std::fs::File::create(path).expect("create");
    f.write_all(src.as_bytes()).expect("write");
}

#[test]
fn closed_stdout_pipe_does_not_panic() {
    // Regression: Rust ignores SIGPIPE, so `println!` returned an error and
    // `expect`-ing it panicked — `bash-O4 --check prog.sh | head -n 1` exited
    // **101** with a Rust backtrace.  `lib.rs::restore_sigpipe_default` puts
    // the default disposition back, so the process dies quietly on SIGPIPE
    // (status 141) like every other Unix tool.
    let d = std::env::temp_dir().join(format!("bo4pipe{}", std::process::id()));
    let _ = std::fs::create_dir_all(&d);
    let p = d.join("many.sh");
    many_loops(&p);

    for (label, args) in [
        ("--check", vec!["--check", p.to_str().unwrap()]),
        ("--dump-shir", vec!["--dump-shir", p.to_str().unwrap()]),
        ("--emit-c", vec!["--emit-c", p.to_str().unwrap()]),
    ] {
        let (code, signal, err) = run_with_head(&args);
        assert_ne!(
            code,
            Some(101),
            "`{label} | head -1` panicked (exit 101) instead of dying on SIGPIPE:\n{err}"
        );
        assert!(
            !err.contains("panicked") && !err.contains("Broken pipe"),
            "`{label} | head -1` reported a broken pipe to the user:\n{err}"
        );
        // Either it died on SIGPIPE (signal 13 — what a shell shows as 141),
        // or it finished before the reader closed.  Anything else (a Rust
        // panic's 101, an unrelated error exit) is a regression.
        assert!(
            signal == Some(13) || code == Some(0),
            "`{label} | head -1` should die on SIGPIPE (13) or exit 0, got code={code:?} signal={signal:?}:\n{err}"
        );
    }
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn normal_invocation_is_unaffected_by_the_sigpipe_reset() {
    // The fix must not change the ordinary path: full stdout, exit code from
    // the program.
    let d = std::env::temp_dir().join(format!("bo4norm{}", std::process::id()));
    let _ = std::fs::create_dir_all(&d);
    let p = d.join("t.sh");
    std::fs::write(&p, "#!/bin/bash\ns=0\nfor ((i=0;i<4;i++)); do s=$((s+i)); done\necho $s\n")
        .expect("write");
    let out = Command::new(bin("bash-O4"))
        .arg(&p)
        .output()
        .expect("run");
    assert_eq!(out.status.code(), Some(0));
    assert_eq!(String::from_utf8_lossy(&out.stdout), "6\n");
    let _ = std::fs::remove_dir_all(&d);
}
