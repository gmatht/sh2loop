//! gpuleg — GPU leg for bench-opt.sh: `gpuleg <problem> <N> [--runs K]`
//! prints `<median_ms> <checksum>`. Problems (all fused map+reduce where
//! the math allows — checksums agree with the CPU legs, readback is
//! partials-only):
//!   squares-map — FUSED squares + mod-2^32 tree reduction (same math as
//!     sumred: per-lane `(acc + (i*i & mask)) & mask`, tree, partials +
//!     host finish). A full-array-readback variant exists in git history
//!     (traffic-parity studies) but is ~10x slower on transfer — never
//!     for the bench.
//!   sumred      — BLOCK reduction template (M5 preview: 1024 items/lane,
//!     tree reduce, partials + host sum, all mod 2^32)
//!   collatz     — branchy Collatz steps + block reduction (M5 preview)
//! SPIR-V compile happens once outside the timer (like gcc compile);
//! timed section is warmup + median dispatches + host finish.
use bash_o4::{shader, vkffi};

const BLOCK: u64 = 1024;

// sumred/collatz use hand templates (M5 reduction preview): BLOCK
// sequential items per lane + shared-memory tree reduction. TRIPS/BLOCK
// substituted per run; partials feed the host-side mod-2^32 finish.
fn block_template(op: &str, trips: u64) -> String {
    format!(
        r#"#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_p {{ int64_t partials[]; }};
const uint64_t TRIPS = {trips}u;
const uint64_t BLOCK = {BLOCK}u;
// mod 2^32 as a mask (a `4294967296u` literal would overflow uint).
shared int64_t tile[256];
void main() {{
  uint t = gl_LocalInvocationID.x;
  uint64_t base = uint64_t(gl_GlobalInvocationID.x) * BLOCK;
  uint64_t acc = 0u;
  for (uint64_t k = 0u; k < BLOCK; k++) {{
    uint64_t i = base + k;
    if (i >= TRIPS) break;
    acc = {op};
  }}
  tile[t] = int64_t(acc);
  barrier();
  for (uint s = 128u; s > 0u; s >>= 1u) {{
    if (t < s) {{ tile[t] = tile[t] + tile[t + s]; }}
    barrier();
  }}
  if (t == 0u) {{ partials[gl_WorkGroupID.x] = tile[0]; }}
}}
"#,
        trips = trips,
        BLOCK = BLOCK,
        op = op
    )
}

fn sumred_op() -> String {
    // (acc + i*i) mod 2^32 via masking — all values fit i64 exactly,
    // and masking equals mod-2^32 for the nonneg values here.
    "((acc + ((i * i) & uint64_t(0xFFFFFFFFu))) & uint64_t(0xFFFFFFFFu))".to_string()
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("usage: gpuleg <squares-map|sumred|collatz> <N> [--runs K]");
        std::process::exit(2);
    }
    let (problem, n): (String, u64) = (args[0].clone(), args[1].parse().expect("N"));
    let mut runs = 3;
    let mut i = 2;
    while i < args.len() {
        if args[i] == "--runs" {
            runs = args[i + 1].parse().expect("runs");
            i += 1;
        }
        i += 1;
    }
    if !vkffi::has_compute_device() {
        eprintln!("SKIP gpuleg: no Vulkan compute device");
        std::process::exit(2);
    }
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("VK_ICD_FILENAMES").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }
    let root = std::env::temp_dir().join(format!("bo4gpuleg{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let cc = shader::find_spirv_compiler(&root).expect("need glslangValidator");
    let runner = vkffi::ComputeRunner::new().expect("runner");

    // Build once (outside timer, like gcc compile): (spv, groups, out_lens, finish)
    enum Finish {
        PartialsSumMod,
        PartialsSumRaw,
    }
    let (spv, groups, out_lens, finish): (Vec<u8>, u32, Vec<usize>, Finish) = match problem.as_str() {
        "squares-map" => {
            // Fused: identical math to sumred (per-lane masked squares
            // accumulate + tree). Full readback would move 800MB for an
            // 8-byte answer — transfer-bound by construction.
            let glsl = block_template(&sumred_op(), n);
            let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv");
            let groups = ((n + 256 * BLOCK - 1) / (256 * BLOCK)) as u32;
            (spv, groups, vec![groups as usize], Finish::PartialsSumMod)
        }
        "sumred" => {
            let glsl = block_template(&sumred_op(), n);
            let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv");
            let groups = ((n + 256 * BLOCK - 1) / (256 * BLOCK)) as u32;
            (spv, groups, vec![groups as usize], Finish::PartialsSumMod)
        }
        "collatz" => {
            let glsl = collatz_glsl(n);
            let spv = shader::compile_spv(&cc, &glsl, &root).expect("spv");
            let groups = ((n + 256 * BLOCK - 1) / (256 * BLOCK)) as u32;
            (spv, groups, vec![groups as usize], Finish::PartialsSumRaw)
        }
        _ => {
            eprintln!("unknown problem {problem}");
            std::process::exit(2);
        }
    };

    // Warmup (proves correctness once, outside timer).
    let out = runner
        .run(&spv, None, &out_lens, groups)
        .expect("warmup dispatch");
    let checksum = finish_all(&finish, &out);
    // Timed: median dispatches + host finish each rep.
    let mut ts = Vec::new();
    for _ in 0..runs {
        let t = std::time::Instant::now();
        let out = runner
            .run(&spv, None, &out_lens, groups)
            .expect("dispatch");
        let _ = finish_all(&finish, &out);
        ts.push(t.elapsed().as_secs_f64() * 1000.0);
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = ts[ts.len() / 2];
    println!("{median:.3} {checksum}");
    let _ = std::fs::remove_dir_all(&root);

    fn finish_all(finish: &Finish, out: &[Vec<i64>]) -> u64 {
        const MOD: u64 = 4294967296;
        match finish {
            Finish::PartialsSumMod => {
                let mut s: u64 = 0;
                for &x in &out[0] {
                    s = (s + (x as u64) % MOD) % MOD;
                }
                s
            }
            Finish::PartialsSumRaw => out[0].iter().map(|&x| x as u64).sum(),
        }
    }
}

/// Collatz block shader: per-lane step counts over BLOCK seeds, tree
/// reduction to one partial per workgroup. Totals fit i64 exactly.
fn collatz_glsl(trips: u64) -> String {
    format!(
        r#"#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_p {{ int64_t partials[]; }};
const uint64_t TRIPS = {trips}u;
const uint64_t BLOCK = {BLOCK}u;
shared int64_t tile[256];
void main() {{
  uint t = gl_LocalInvocationID.x;
  uint64_t base = uint64_t(gl_GlobalInvocationID.x) * BLOCK;
  int64_t acc = 0;
  for (uint64_t k = 0u; k < BLOCK; k++) {{
    uint64_t g = base + k;
    if (g >= TRIPS) break;
    int64_t v = int64_t((g * 37u + 3u) % 251u);
    while (v > 1) {{
      if (v % 2 == 0) {{ v = v / 2; }} else {{ v = 3 * v + 1; }}
      acc = acc + 1;
    }}
  }}
  tile[t] = acc;
  barrier();
  for (uint s = 128u; s > 0u; s >>= 1u) {{
    if (t < s) {{ tile[t] = tile[t] + tile[t + s]; }}
    barrier();
  }}
  if (t == 0u) {{ partials[gl_WorkGroupID.x] = tile[0]; }}
}}
"#,
        trips = trips,
        BLOCK = BLOCK
    )
}
