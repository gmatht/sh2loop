//! `--check` verdicts: candidates accepted, vetoes named.
//!
//! Structural assertions (the verdict line + reason), not "no crash":
//! each case pins the exact classification docs/BASH-O4.md §4.3 promises.

use std::path::PathBuf;
use std::process::Command;

fn bin() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_bash-O4"))
}

fn check(body: &str) -> (String, i32) {
    use std::sync::atomic::{AtomicUsize, Ordering};
    static N: AtomicUsize = AtomicUsize::new(0);
    let n = N.fetch_add(1, Ordering::SeqCst);
    // Unique dir per test: parallel tests share the process (and pid),
    // so a fixed path lets scripts overwrite each other mid-run.
    let d = std::env::temp_dir().join(format!("bo4ck{}-{n}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let s = d.join("t.sh");
    std::fs::write(&s, body).unwrap();
    let out = Command::new(bin()).arg("--check").arg(&s).output().unwrap();
    let stdout = String::from_utf8_lossy(&out.stdout).into_owned();
    let rc = out.status.code().unwrap_or(1);
    let _ = std::fs::remove_dir_all(&d);
    (stdout, rc)
}

#[test]
fn squares_cfor_is_candidate() {
    let (o, rc) = check("#!/bin/bash\nfor ((i=0;i<1024;i++)); do a[$i]=$((i*i)); done\n");
    assert_eq!(rc, 0);
    assert!(o.contains("candidate sh_loop_main_0"), "{o}");
    assert!(o.contains("trips=1024"), "{o}");
    // The counts are now namespaced: this program is a GLSL candidate and
    // NOT a CUDA one (the CUDA candidacy wants a dynamic bound), so assert
    // both halves explicitly rather than a bare `CANDIDATES=`.
    assert!(o.contains("GLSL_CANDIDATES=1 GLSL_LOOPS=1"), "{o}");
    assert!(o.contains("CUDA_CANDIDATES=0"), "{o}");
}

#[test]
fn offloadable_shape_reports_a_cuda_candidate() {
    // Regression: `--check` used to print ONLY the GLSL candidacy and a bare
    // `CANDIDATES=`, so a program that offloads fine through `--gpu`
    // reported `CANDIDATES=0` — the flag actively misled.  This is the
    // bench squares-map shape (fill, then a masked sum), which the shell
    // path fuses into one reduction candidate.
    let (o, rc) = check(
        "#!/bin/bash\nn=$1\nfor ((i=0;i<n;i++)); do a[$i]=$((i*i)); done\n\
         s=0\nfor ((i=0;i<n;i++)); do s=$(((s + a[i]) & 0xFFFFFFFF)); done\n",
    );
    assert_eq!(rc, 0);
    assert!(
        o.contains("RED candidate") || o.contains("MAP candidate"),
        "the CUDA section must show the offloadable candidate:\n{o}"
    );
    assert!(
        !o.contains("CUDA_CANDIDATES=0"),
        "an offloadable shape must not report zero CUDA candidates:\n{o}"
    );
}

#[test]
fn brace_range_is_candidate() {
    let (o, rc) = check("#!/bin/bash\nfor i in {0..7}; do a[$i]=$((i+1)); done\n");
    assert_eq!(rc, 0);
    assert!(o.contains("candidate sh_loop_main_0"), "{o}");
    assert!(o.contains("GLSL_CANDIDATES=1"), "{o}");
}

#[test]
fn accumulate_is_scalar_carry_veto() {
    let (o, rc) = check("#!/bin/bash\ns=0\nfor i in {1..10}; do s=$((s+i)); done\n");
    assert_eq!(rc, 0);
    assert!(o.contains("veto") && o.contains("scalar-carry"), "{o}");
    assert!(o.contains("GLSL_CANDIDATES=0"), "{o}");
}

#[test]
fn echo_body_is_host_io_veto() {
    let (o, rc) = check("#!/bin/bash\nfor i in {1..10}; do echo $i; done\n");
    assert_eq!(rc, 0);
    assert!(o.contains("body-host-io"), "{o}");
}

#[test]
fn eval_body_is_effect_veto() {
    let (o, rc) = check("#!/bin/bash\nfor i in 1 2 3; do eval \"x=$i\"; done\n");
    assert_eq!(rc, 0);
    assert!(o.contains("veto"), "{o}");
}

#[test]
fn unknown_shader_id_errors() {
    let d = std::env::temp_dir().join(format!("bo4id{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let s = d.join("t.sh");
    std::fs::write(&s, "#!/bin/bash\necho hi\n").unwrap();
    let out = Command::new(bin()).arg("--emit-shader").arg("sh_loop_main_9").arg(&s).output().unwrap();
    assert_eq!(out.status.code(), Some(1));
    let _ = std::fs::remove_dir_all(&d);
}
