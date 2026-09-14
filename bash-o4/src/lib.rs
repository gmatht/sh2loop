//! bash-O4 library: the -O4 optimizing driver pipeline.
//!
//! Stages: parse (bash→ShIR A1) → analyses/candidacy → C render → tcc
//! JIT/AOT → (later) Vulkan compute offload with CPU fallback. The
//! modules mirror docs/BASH-O4.md §4.2/§4.9: `pipeline` (M1 codegen),
//! `tcc` (M1 link), `cache` (P2 artifact cache), `candidacy` (M2),
//! `shader` (M3 scaffolding: GLSL emission + SPIR-V check),
//! `fetch` (M4 manifest + consented downloads), `vkffi` (M3 device
//! detect + minimal compute runner, lavapipe-capable).

pub mod cache;
pub mod candidacy;
pub mod cli;
pub mod cu_run;
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
