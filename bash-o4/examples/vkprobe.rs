//! Micro-probes for BASH_VULKAN optimisation decisions (NOT shipped
//! paths — results in docs/BASH_VULKAN.md). Dispatches hand-written
//! GLSL variants through the same runner + validator as production:
//!   vec4      — 4 elements per invocation (unroll candidate)
//!   blockred  — per-workgroup tree reduction to partial sums (M5 ceiling)
use bash_o4::{shader, vkffi};

fn setup() -> (vkffi::ComputeRunner, std::path::PathBuf, std::path::PathBuf) {
    assert!(vkffi::has_compute_device(), "need Vulkan device");
    const LVP: &str = "/usr/share/vulkan/icd.d/lvp_icd.json";
    if std::env::var("VK_ICD_FILENAMES").is_err() && std::path::Path::new(LVP).is_file() {
        std::env::set_var("VK_ICD_FILENAMES", LVP);
    }
    let root = std::env::temp_dir().join(format!("bo4probe{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();
    let cc = shader::find_spirv_compiler(&root).expect("need glslangValidator");
    let runner = vkffi::ComputeRunner::new().expect("runner");
    (runner, root, cc)
}

const VEC4_GLSL: &str = r#"#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_a { int64_t data_a[]; };
const uint64_t TRIPS = 1048576u;
void main() {
  uint64_t t = gl_GlobalInvocationID.x;
  uint64_t base = t * 4u;
  if (base >= TRIPS) return;
  for (uint k = 0u; k < 4u; k++) {
    uint64_t idx = base + k;
    if (idx >= TRIPS) return;
    int64_t i_ = int64_t(idx);
    data_a[uint(idx)] = (i_ * i_);
  }
}
"#;

// One partial sum (of 256 int64 squares) per workgroup.
const BLOCKRED_GLSL: &str = r#"#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_p { int64_t partials[]; };
const uint64_t TRIPS = 1048576u;
shared int64_t tile[256];
void main() {
  uint t = gl_LocalInvocationID.x;
  uint64_t i = uint64_t(gl_GlobalInvocationID.x);
  int64_t v = 0;
  if (i < TRIPS) { int64_t x = int64_t(i); v = x * x; }
  tile[t] = v;
  barrier();
  for (uint s = 128u; s > 0u; s >>= 1u) {
    if (t < s) { tile[t] = tile[t] + tile[t + s]; }
    barrier();
  }
  if (t == 0u) { partials[gl_WorkGroupID.x] = tile[0]; }
}
"#;

fn time_it(f: impl Fn()) -> f64 {
    f(); // warmup
    let reps = 5;
    let t = std::time::Instant::now();
    for _ in 0..reps {
        f();
    }
    t.elapsed().as_secs_f64() * 1000.0 / reps as f64
}

// Branchy Collatz step counts + block reduction (ceiling probe for
// control-flow-heavy integer work: unvectorisable + untranspilable
// today, but maximally thread-parallel).
const COLLATZ_GLSL: &str = r#"#version 450
#extension GL_EXT_shader_explicit_arithmetic_types : enable
layout(local_size_x = 256) in;
layout(set = 0, binding = 0) restrict buffer Out_p { int64_t partials[]; };
const uint64_t TRIPS = 160000u;
shared int64_t tile[256];
void main() {
  uint t = gl_LocalInvocationID.x;
  uint64_t g = uint64_t(gl_GlobalInvocationID.x);
  int64_t s = 0;
  if (g < TRIPS) {
    int64_t v = int64_t((g * 37u + 3u) % 251u);
    while (v > 1) {
      if (v % 2 == 0) { v = v / 2; } else { v = 3 * v + 1; }
      s = s + 1;
    }
  }
  tile[t] = s;
  barrier();
  for (uint k = 128u; k > 0u; k >>= 1u) {
    if (t < k) { tile[t] = tile[t] + tile[t + k]; }
    barrier();
  }
  if (t == 0u) { partials[gl_WorkGroupID.x] = tile[0]; }
}
"#;

fn main() {
    let (runner, root, cc) = setup();
    // vec4: 1M lanes / 4 per invocation.
    let spv = shader::compile_spv(&cc, VEC4_GLSL, &root).expect("vec4 spv");
    let ms = time_it(|| {
        let out = runner.run(&spv, None, &[1048576], 1048576 / 4 / 256).expect("vec4");
        assert_eq!(out[0][1048575], 1048575i64 * 1048575);
    });
    println!("vec4 1M: {ms:.3} ms");
    // blockred: 4096 partials, host finishes the sum.
    let spv = shader::compile_spv(&cc, BLOCKRED_GLSL, &root).expect("red spv");
    let out = runner.run(&spv, None, &[4096], 4096).expect("red");
    let total: i128 = out[0].iter().map(|&x| x as i128).sum();
    // NOTE: 2^20 lanes, not 10^6 — compute the oracle, never hardcode.
    let want: i128 = (0..1048576).map(|i| (i as i128) * (i as i128)).sum();
    assert_eq!(total, want);
    println!("total={total} n={}", out[0].len());
    for g in [0, 1, 4094, 4095] {
        let p = out[0][g];
        let base = g * 256;
        let base = g * 256;
        let exp: i128 = (base..base + 256).map(|i| (i as i128) * (i as i128)).sum();
        println!("group {g}: got {p} want {exp} match={}", p as i128 == exp);
    }
    println!("blockred 1M (4096 partials + host sum): {ms:.3} ms");
    // Collatz ceiling: 160K seeds, 625 workgroups.
    let spv = shader::compile_spv(&cc, COLLATZ_GLSL, &root).expect("collatz spv");
    let ms = time_it(|| {
        let out = runner.run(&spv, None, &[625], 625).expect("collatz");
        let total: i64 = out[0].iter().sum();
        assert_eq!(total, 7094421); // bash oracle (bench gate cross-checks gcc)
    });
    println!("collatz 160K seeds (625 partials + host sum): {ms:.3} ms");
    let _ = std::fs::remove_dir_all(&root);
}
