//! bash-O4 library: the -O4 optimizing driver pipeline.
//!
//! Stages: parse (bash→ShIR A1) → analyses/candidacy → C render → tcc
//! JIT/AOT → (later) Vulkan compute offload with CPU fallback. The
//! modules mirror docs/BASH-O4.md §4.2/§4.9: `pipeline` (M1 codegen),
//! `tcc` (M1 link), `cache` (P2 artifact cache), `candidacy` (M2),
//! `shader` (M3 scaffolding: GLSL emission + SPIR-V check),
//! `fetch` (M4 manifest + consented downloads), `vkffi` (M3 device
//! detect + minimal compute runner, lavapipe-capable).

/// Restore the default `SIGPIPE` disposition. Call this first thing in
/// `main`.
///
/// Rust's runtime sets `SIGPIPE` to `SIG_IGN`, so writing to a pipe whose
/// reader has already exited surfaces as an `Err` from `println!`, and
/// `println!` *panics* on error.  The result was that
/// `bash-O4 --check prog.sh | head -n 1` exited **101** with a Rust backtrace
/// instead of just stopping — and because `SIG_IGN` is inherited across
/// `exec`, the `tcc`/`gcc` children were ignoring it too.  Restoring the
/// default gives the normal Unix behaviour (die on `SIGPIPE`, status 141).
pub fn restore_sigpipe_default() {
    // SAFETY: installing a signal disposition has no memory-safety
    // implications and is safe to call before any threads exist.
    unsafe {
        libc::signal(libc::SIGPIPE, libc::SIG_DFL);
    }
}

pub mod cache;
pub mod candidacy;
pub mod cli;
pub mod cu_run;
pub mod flags;
pub mod cudaffi;
pub mod cu_candidacy;
pub mod fetch;
pub mod pipeline;
pub mod py;
pub mod shader;
pub mod tcc;
pub mod vkffi;

/// CLI entry (mirrors `otranspilerl::cli`): returns a process exit code.
pub fn cli(args: &[String]) -> i32 {
    cli::run(args)
}
