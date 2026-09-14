//! cutranspile — transpiled-CUDA vehicle: `cutranspile <script.sh> <N>`
//! `[--runs K] [--bind var=value...]` prints `<median_ms> <checksum>`.
//!
//! End-to-end bash→ShIR→candidacy→PTX→GPU with NO hand kernels. The
//! dispatch lives in `bash_o4::cu_run` (shared with python-O4); this
//! example is the shell-frontend wrapper. Exit 2 + SKIP message when:
//! no CUDA device, no runnable shape, or unbindable externs (bench-opt
//! treats 2 as skip, not failure).
use bash_o4::{cu_run, pipeline};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("usage: cutranspile <script.sh> <N> [--runs K] [--bind var=value...]");
        std::process::exit(2);
    }
    let (script, n): (String, u64) = (args[0].clone(), args[1].parse().expect("N"));
    let mut runs = 3;
    let mut binds: Vec<(String, i64)> = Vec::new();
    let mut i = 2;
    while i < args.len() {
        if args[i] == "--runs" {
            runs = args[i + 1].parse().expect("runs");
            i += 1;
        } else if args[i] == "--bind" {
            let kv = &args[i + 1];
            let (k, v) = kv.split_once('=').expect("--bind var=value");
            binds.push((k.to_string(), v.parse().expect("bind value")));
            i += 1;
        }
        i += 1;
    }
    let src = std::fs::read_to_string(&script).expect("script");
    let prog = {
        let json = pipeline::parse_to_shir(&src);
        debashl::shir_json_in::shir_json_to_ir(&json).expect("ingress")
    };
    match cu_run::run(&prog, &prog, n, &binds, runs) {
        Ok((ms, checksum)) => println!("{ms:.3} {checksum}"),
        Err(skip) => {
            eprintln!("SKIP cutranspile: {skip}");
            std::process::exit(2);
        }
    }
}
