//! CLI parity: `bash-O4 run/-o` matches `bash` stdout + exit code.
//!
//! The corpus gate (`harness/gpu_gate.sh`) extends this to the corpus;
//! these are the pinned structural cases (args, exit codes, uu-ffi
//! runtime linkage, cache behavior, usage errors).

use std::path::PathBuf;
use std::process::Command;

fn bin() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_bash-O4"))
}

fn sh2perl() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("sh2perl")
}

fn tmpdir(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("bo4cli{tag}{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn write_script(dir: &std::path::Path, body: &str) -> PathBuf {
    let p = dir.join("t.sh");
    std::fs::write(&p, body).unwrap();
    p
}

fn bash_ref(script: &std::path::Path, args: &[&str]) -> (String, i32) {
    let out = Command::new("bash").arg(script).args(args).output().unwrap();
    (
        String::from_utf8_lossy(&out.stdout).into_owned(),
        out.status.code().unwrap_or(1),
    )
}

fn run_bo4(script: &std::path::Path, extra: &[&str], args: &[&str]) -> (String, String, i32) {
    let out = Command::new(bin())
        .env("BASH_O4_SH2PERL", sh2perl())
        .args(extra)
        .arg(script)
        .args(args)
        .output()
        .unwrap();
    (
        String::from_utf8_lossy(&out.stdout).into_owned(),
        String::from_utf8_lossy(&out.stderr).into_owned(),
        out.status.code().unwrap_or(1),
    )
}

#[test]
fn run_matches_bash_args_and_exit() {
    let d = tmpdir("a");
    let s = write_script(&d, "#!/bin/bash\necho hello $1 $2\nexit 3\n");
    let (o, rc) = bash_ref(&s, &["a", "b"]);
    assert_eq!((o.as_str(), rc), ("hello a b\n", 3));
    let (bo, _be, brc) = run_bo4(&s, &[], &["a", "b"]);
    assert_eq!(bo, o);
    assert_eq!(brc, rc);
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn run_matches_bash_compute_loop() {
    let d = tmpdir("b");
    let s = write_script(
        &d,
        "#!/bin/bash\ns=0\nfor ((i=1;i<=100;i++)); do s=$((s+i)); done\necho $s\n",
    );
    let (o, rc) = bash_ref(&s, &[]);
    assert_eq!(o, "5050\n");
    let (bo, _be, brc) = run_bo4(&s, &[], &[]);
    assert_eq!((bo.as_str(), brc), (o.as_str(), rc));
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn run_matches_bash_external_commands() {
    // Exercises the uu-ffi runtime linkage (sort/grep) end to end.
    let d = tmpdir("c");
    let s = write_script(
        &d,
        "#!/bin/bash\nprintf 'b\\na\\n' | sort\necho root | grep -o o\n",
    );
    let (o, rc) = bash_ref(&s, &[]);
    let (bo, be, brc) = run_bo4(&s, &[], &[]);
    assert_eq!(brc, rc, "stderr: {be}");
    assert_eq!(bo, o, "stderr: {be}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn aot_build_runs_and_matches() {
    let d = tmpdir("d");
    let s = write_script(&d, "#!/bin/bash\necho aot-$1\nexit 7\n");
    let exe = d.join("prog");
    let (_o, e, rc) = run_bo4(&s, &["-o", exe.to_str().unwrap()], &[]);
    assert_eq!(rc, 0, "build failed: {e}");
    assert!(exe.is_file());
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        assert!(std::fs::metadata(&exe).unwrap().permissions().mode() & 0o111 != 0);
    }
    let out = Command::new(&exe).arg("X").output().unwrap();
    assert_eq!(String::from_utf8_lossy(&out.stdout), "aot-X\n");
    assert_eq!(out.status.code(), Some(7));
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn argv0_is_script_path() {
    // The driver emulates the c_gate `exec -a` convention itself: the
    // JIT program sees $0 = script path (like `bash script.sh`), never
    // the cache temp path.
    let d = tmpdir("h");
    let s = write_script(&d, "#!/bin/bash\necho \"dollar0=$0\"\n");
    let (bo, be, brc) = run_bo4(&s, &[], &[]);
    assert_eq!(brc, 0, "stderr: {be}");
    assert_eq!(bo, format!("dollar0={}\n", s.display()), "stderr: {be}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn tcc_failure_falls_back_loudly() {
    // Renders using <regex.h> cannot compile under tcc (glibc headers).
    // bash-O4 must fall back to cc LOUDLY (stderr note) with identical
    // stdout — never a silent wrong result, never a hard failure.
    let d = tmpdir("g");
    let s = write_script(&d, "#!/bin/bash\n[[ abc =~ b+ ]] && echo yes || echo no\n");
    let (o, rc) = bash_ref(&s, &[]);
    assert_eq!(o, "yes\n");
    let (bo, be, brc) = run_bo4(&s, &[], &[]);
    assert_eq!((bo.as_str(), brc), (o.as_str(), rc), "stderr: {be}");
    assert!(be.contains("falling back to"), "loud fallback note: {be}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn cache_hit_on_second_run() {
    let d = tmpdir("e");
    let cache = d.join("cache");
    let s = write_script(&d, "#!/bin/bash\necho cached\n");
    let args = |c: &str| vec!["--verbose".to_string(), "--cache-dir".to_string(), c.to_string()];
    let a1: Vec<String> = args(cache.to_str().unwrap());
    let a1r: Vec<&str> = a1.iter().map(|s| s.as_str()).collect();
    let (_o1, e1, rc1) = run_bo4(&s, &a1r, &[]);
    assert_eq!(rc1, 0, "{e1}");
    assert!(e1.contains("cache miss"), "first run misses: {e1}");
    let (_o2, e2, rc2) = run_bo4(&s, &a1r, &[]);
    assert_eq!(rc2, 0, "{e2}");
    assert!(e2.contains("cache hit"), "second run hits: {e2}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn usage_and_force_codes() {
    let ( _o, _e, rc) = run_bo4(PathBuf::from("/nonexistent.sh").as_path(), &[], &[]);
    assert_eq!(rc, 1);
    let d = tmpdir("f");
    let s = write_script(&d, "#!/bin/bash\necho x\n");
    let (_o, _e, rc) = run_bo4(&s, &["--bogus-flag"], &[]);
    assert_eq!(rc, 2);
    let (_o, _e, rc) = run_bo4(&s, &["--gpu=force"], &[]);
    assert_eq!(rc, 3);
    let _ = std::fs::remove_dir_all(&d);
}
