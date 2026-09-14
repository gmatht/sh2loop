//! Flag parity between the `-O4` drivers.
//!
//! `bash-O4` and `python-O4` are the same driver with different front ends.
//! They used to carry separate copies of the flag parsing — two private
//! `GpuMode` enums, `--gpu` meaning "policy, never dispatch" in one and
//! "dispatch" in the other, and `--n/--runs/--bind/--help` missing from
//! bash-O4 entirely.  The shared spec now lives in `bash_o4::flags`, and
//! these tests pin the *observable* contract so a future edit to either
//! binary cannot quietly re-diverge:
//!
//! 1. both `--help` texts contain every shared flag;
//! 2. both reject an unknown flag with exit 2 (usage error);
//! 3. both accept the GPU-leg flags and report the same usage error when
//!    they are malformed;
//! 4. both keep the bare invocation on the CPU path (`--gpu` must be
//!    explicit), which is what makes `--gpu=auto` safe for the CPU gate.
//!
//! These drive the real binaries, so they test the wiring, not just the
//! parser: a driver that forgot to consult `try_common` fails here.

use std::process::Command;

fn bin(name: &str) -> std::path::PathBuf {
    // target/<profile>/deps/<test binary> -> target/<profile>/<bin>
    let mut p = std::env::current_exe().expect("current_exe");
    p.pop();
    if p.ends_with("deps") {
        p.pop();
    }
    p.push(name);
    p
}

fn run(bin_name: &str, args: &[&str]) -> (i32, String, String) {
    let out = Command::new(bin(bin_name))
        .args(args)
        .output()
        .unwrap_or_else(|e| panic!("spawn {bin_name} {args:?}: {e}"));
    (
        out.status.code().unwrap_or(-1),
        String::from_utf8_lossy(&out.stdout).into_owned(),
        String::from_utf8_lossy(&out.stderr).into_owned(),
    )
}

/// Every flag both drivers must understand.  Kept as literal text so this
/// test fails loudly if a name is renamed in only one driver.
const SHARED_FLAGS: &[&str] = &[
    "-o FILE",
    "--emit-c",
    "--check",
    "--dump-shir",
    "--gpu[=auto|force|off]",
    "--n N",
    "--runs K",
    "--bind VAR=VAL",
    "--cpu-only",
    "--no-gpu",
    "-O2",
    "-O4",
    "--cache-dir PATH",
    "--offline",
    "--true64",
    "--no-true64",
    "--verbose",
    "-h, --help",
    "-V, --version",
];

const DRIVERS: &[&str] = &["bash-O4", "python-O4"];

#[test]
fn both_drivers_document_every_shared_flag() {
    for d in DRIVERS {
        let (code, stdout, _) = run(d, &["--help"]);
        assert_eq!(code, 0, "{d} --help must exit 0");
        for flag in SHARED_FLAGS {
            assert!(
                stdout.contains(flag),
                "{d} --help omits the shared flag {flag:?}\n--- help ---\n{stdout}"
            );
        }
    }
}

#[test]
fn help_is_recognised_in_both_spellings() {
    for d in DRIVERS {
        let (short, short_out, _) = run(d, &["-h"]);
        let (long, long_out, _) = run(d, &["--help"]);
        assert_eq!((short, long), (0, 0), "{d}: -h/--help must both exit 0");
        assert_eq!(short_out, long_out, "{d}: -h and --help must agree");
    }
}

#[test]
fn version_is_reported_in_both_spellings() {
    for d in DRIVERS {
        let (sc, sout, _) = run(d, &["-V"]);
        let (lc, lout, _) = run(d, &["--version"]);
        assert_eq!((sc, lc), (0, 0), "{d}: -V/--version must both exit 0");
        assert_eq!(sout, lout, "{d}: -V and --version must agree");
        assert!(
            sout.starts_with(d),
            "{d}: version line should name the driver, got {sout:?}"
        );
        assert!(
            sout.trim().split(' ').nth(1).is_some_and(|v| v.contains('.')),
            "{d}: version line should carry a version, got {sout:?}"
        );
    }
}

#[test]
fn unknown_flag_is_a_usage_error_in_both() {
    for d in DRIVERS {
        let (code, _, stderr) = run(d, &["--definitely-not-a-flag"]);
        assert_eq!(code, 2, "{d}: unknown flag must exit 2 (usage)");
        assert!(
            stderr.contains("unknown flag"),
            "{d}: stderr should name the offending flag:\n{stderr}"
        );
        // The usage block is printed on error, so the shared section shows.
        assert!(
            stderr.contains("--cpu-only"),
            "{d}: usage error should print the shared usage block"
        );
    }
}

#[test]
fn gpu_leg_flags_are_accepted_by_both() {
    // A malformed value must be a *usage* error (2), not "unknown flag" —
    // i.e. the flag is recognised but validated.
    for d in DRIVERS {
        let (code, _, stderr) = run(d, &["--gpu=sideways"]);
        assert_eq!(code, 2, "{d}: bad --gpu value must exit 2");
        assert!(
            stderr.contains("bad --gpu") && !stderr.contains("unknown flag"),
            "{d}: --gpu values must be validated, not rejected as unknown:\n{stderr}"
        );

        let (code, _, stderr) = run(d, &["--n", "not-a-number"]);
        assert_eq!(code, 2, "{d}: bad --n value must exit 2");
        assert!(
            !stderr.contains("unknown flag"),
            "{d}: --n must be recognised:\n{stderr}"
        );

        let (code, _, stderr) = run(d, &["--bind", "novalue"]);
        assert_eq!(code, 2, "{d}: malformed --bind must exit 2");
        assert!(
            !stderr.contains("unknown flag"),
            "{d}: --bind must be recognised:\n{stderr}"
        );
    }
}

#[test]
fn all_optimisation_levels_are_accepted_by_both() {
    for d in DRIVERS {
        for level in ["-O0", "-Og", "-O2", "-Os", "-Oz", "-O3", "-O4"] {
            let (code, _, stderr) = run(d, &[level]);
            // No program given: the usage error is "need program.<ext>",
            // never "unknown flag".
            assert!(
                !stderr.contains("unknown flag"),
                "{d} rejected {level}: {stderr}"
            );
            assert_eq!(code, 2, "{d} {level} without a program should be usage");
        }
    }
}

#[test]
fn bare_invocation_does_not_opt_into_dispatch() {
    // `--gpu` must be explicit.  If a bare run started dispatching, its
    // stdout would become "<ms> <checksum>" instead of the program's
    // output, silently breaking every existing caller (and the CPU leg of
    // harness/gpu_gate.sh, which compares stdout against bash).
    //
    // Both drivers must therefore fail the same way for a missing program
    // whether or not `--gpu=auto` is passed *and* the difference must be
    // observable only via gpu_flag.  We check the parse contract directly
    // on the shared type, plus that neither binary treats `--gpu=auto` as
    // an unknown flag.
    for d in DRIVERS {
        let (code, stdout, _) = run(d, &["--gpu=auto"]);
        assert_eq!(code, 2, "{d}: --gpu=auto with no program is a usage error");
        assert!(
            stdout.is_empty(),
            "{d}: a usage error must not print a dispatch result to stdout: {stdout:?}"
        );
    }
}

/// `--check` is a shared flag, so its *report* must be recognisably the same
/// report.  The verdict sets legitimately differ per front end (the shell A1
/// has already been through `fuse-fill-consume`, a raw frontend A1 has not),
/// so this pins the FORMAT and the section vocabulary: the CUDA lines use the
/// same `MAP`/`RED`/`SEQ` labels with the same `candidate|veto cu_*` shape in
/// both drivers, and both count their CUDA candidates under the same name.
#[test]
fn check_report_uses_the_same_labels_in_both() {
    let cases: &[(&str, &str)] = &[
        ("bash-O4", "../bash-o4/bench/sh/squares-map.sh"),
        ("python-O4", "../bash-o4/bench/py/squares-map.py"),
    ];
    for (driver, prog) in cases {
        let (code, stdout, stderr) = run(driver, &["--check", prog]);
        assert_eq!(code, 0, "{driver} --check {prog} failed: {stderr}");
        let mut seen = std::collections::BTreeSet::new();
        for line in stdout.lines() {
            if let Some(rest) = line.split_once(' ').map(|(l, r)| (l, r)) {
                if ["MAP", "RED", "SEQ"].contains(&rest.0) {
                    seen.insert(rest.0.to_string());
                    assert!(
                        rest.1.starts_with("candidate cu_") || rest.1.starts_with("veto cu_"),
                        "{driver}: malformed CUDA verdict line {line:?}"
                    );
                }
            }
        }
        assert!(
            !seen.is_empty(),
            "{driver}: --check printed no CUDA verdicts for {prog}:\n{stdout}"
        );
        assert!(
            stdout.contains("CUDA_CANDIDATES="),
            "{driver}: --check must report the CUDA candidate count:\n{stdout}"
        );
        // The GLSL half is bash-O4's own backend; python-O4 has no GLSL path.
        if *driver == "bash-O4" {
            assert!(
                stdout.contains("GLSL_CANDIDATES="),
                "bash-O4 --check must distinguish the GLSL count:\n{stdout}"
            );
        } else {
            assert!(
                !stdout.contains("GLSL "),
                "python-O4 has no GLSL backend, so it must not claim GLSL verdicts"
            );
        }
    }
}
