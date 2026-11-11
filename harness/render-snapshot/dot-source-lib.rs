use std::sync::atomic::Ordering;

static __SH_RC: std::sync::atomic::AtomicI32 = std::sync::atomic::AtomicI32::new(0);

fn __sh_env(n: &str) -> String {
    std::env::var(n).unwrap_or_default()
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

fn main() -> std::process::ExitCode {
    let _ = std::fs::write("lib_tmp.sh".to_string(), "shared_val=secret\n".to_string());
    __SH_RC.store(0, Ordering::Relaxed);
    { let __src = std::fs::read_to_string("./lib_tmp.sh").unwrap_or_default(); for __line in __src.lines() { if let Some((__n, __val)) = __line.trim().split_once('=') { std::env::set_var(__n, __val.trim()); } } }
    println!("shared={}", __sh_env("shared_val"));
    __SH_RC.store(0, Ordering::Relaxed);
    __SH_RC.store(__sh_rm(&vec!["-f".to_string(), "lib_tmp.sh".to_string()]), Ordering::Relaxed);
    std::process::ExitCode::from(__SH_RC.load(Ordering::Relaxed) as u8)
}