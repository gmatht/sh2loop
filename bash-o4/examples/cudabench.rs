//! cudabench — CUDA leg for bench-opt.sh: `cudabench <problem> <N> [--runs K]`
//! prints `<median_ms> <checksum>`. Mirrors gpuleg (same problems,
//! checksums, finishes) with PTX kernels via cudaffi instead of SPIR-V:
//!   sumred/squares-map — blocked masked reduction (1024 items/lane,
//!     tree reduce, partials + host mod-2^32 finish)
//!   collatz            — branchy Collatz steps + block reduction
//! PTX JIT happens once outside the timer (like gcc compile); timed
//! section is warmup + median dispatches + host finish.
//!
//! PTX notes (WSL-driver parser quirks, diagnosed by bisection — do not
//! "clean up"): entry header single-line; no user reg may shadow a
//! special (`%tid` vs `%tid.x` — all locals prefixed); `.target sm_70`
//! (driver JITs forward to the actual arch).
use bash_o4::cudaffi;

const BLOCK: u64 = 1024;
const THREADS: u32 = 256;

/// Blocked reduction template: each lane accumulates BLOCK items, then a
/// shared-memory tree reduces to one partial per block. TRIPS/BLOCK/op
/// substituted per run; partials feed the host-side finish.
fn block_ptx(op: &str, trips: u64) -> String {
    // Parser rules (WSL driver, bisected — do not "clean up"):
    // single-line entry header; no user reg shadows a special; NO
    // overlapping dest/src regs; shared takes u32 byte offsets (no
    // cvta); immediates fit their type.
    format!(
        r#".version 7.0
.target sm_70
.address_size 64
.visible .entry kern(.param .u64 _out)
{{
  .reg .u64 %out, %base, %ii, %kk, %blk, %acc, %off, %addr, %ea, %t0, %t1, %gid64, %blkid;
  .reg .u32 %t_tid, %t_bid, %t_ntid, %o1, %o2, %so;
  .reg .pred %pp, %qq;
  .reg .s64 %sacc, %sv, %s1;
  .shared .align 8 .s64 tile[256];
  ld.param.u64 %out, [_out];
  mov.u32 %t_tid, %tid.x;
  mov.u32 %t_bid, %ctaid.x;
  mov.u32 %t_ntid, %ntid.x;
  mad.lo.u32 %o1, %t_bid, %t_ntid, %t_tid;
  cvt.u64.u32 %gid64, %o1;
  cvt.u64.u32 %blkid, %t_bid;
  mov.u64 %blk, {block};
  mul.lo.u64 %base, %gid64, %blk;
  mov.u64 %acc, 0;
  mov.u64 %kk, 0;
KLOOP:
  setp.ge.u64 %pp, %kk, %blk;
  @%pp bra KDONE;
  add.u64 %ii, %base, %kk;
  setp.ge.u64 %qq, %ii, {trips};
  @%qq bra KNEXT;
{op}
KNEXT:
  add.u64 %kk, %kk, 1;
  bra KLOOP;
KDONE:
  mov.b64 %sacc, %acc;
  mul.lo.u32 %so, %t_tid, 8;
  st.shared.s64 [%so], %sacc;
  bar.sync 0;
  mov.u32 %t_ntid, 128;
TLOOP:
  setp.eq.u32 %pp, %t_ntid, 0;
  @%pp bra TDONE;
  setp.lt.u32 %pp, %t_tid, %t_ntid;
  @%pp bra TSKIP;
  bra TCONT;
TSKIP:
  add.u32 %o1, %t_tid, %t_ntid;
  mul.lo.u32 %o2, %o1, 8;
  ld.shared.s64 %sv, [%o2];
  mul.lo.u32 %o2, %t_tid, 8;
  ld.shared.s64 %sacc, [%o2];
  add.s64 %s1, %sacc, %sv;
  st.shared.s64 [%o2], %s1;
TCONT:
  bar.sync 0;
  shr.u32 %t_ntid, %t_ntid, 1;
  bra TLOOP;
TDONE:
  setp.eq.u32 %pp, %t_tid, 0;
  @%pp bra PSTALL;
  bra PDONE;
PSTALL:
  ld.shared.s64 %sacc, [%so];
  mul.lo.u64 %t0, %blkid, 8;
  ld.param.u64 %t1, [_out];
  add.u64 %t1, %t1, %t0;
  st.global.s64 [%t1], %sacc;
PDONE:
  ret;
}}
"#,
        trips = trips,
        block = BLOCK,
        op = op
    )
}

fn sumred_op() -> String {
    // ((acc + ((i*i) & mask)) & mask), u64 — matches the GLSL leg bit
    // for bit (nonneg values; masking equals mod-2^32).
    [
        "  mul.lo.u64 %t0, %ii, %ii;",
        "  and.b64 %t1, %t0, 4294967295;",
        "  add.u64 %t0, %acc, %t1;",
        "  and.b64 %acc, %t0, 4294967295;",
    ]
    .join("\n")
}

fn collatz_op() -> String {
    // v = (g*37+3) % 251; while (v>1) { even? halve : 3v+1; acc++ }.
    // All values small (collatz excursions from <251 seeds); s64 exact.
    [
        "  mul.lo.u64 %t0, %ii, 37;",
        "  add.u64 %t0, %t0, 3;",
        "  rem.u64 %t0, %t0, 251;",
        "  cvt.s64.u64 %sv, %t0;",
        "CLOOP:",
        "  setp.le.s64 %pp, %sv, 1;",
        "  @%pp bra CNEXT;",
        "  and.b64 %t1, %sv, 1;",
        "  setp.eq.u64 %pp, %t1, 0;",
        "  @%pp bra CEVEN;",
        "  mul.lo.s64 %sv, %sv, 3;",
        "  add.s64 %sv, %sv, 1;",
        "  bra CCONT;",
        "CEVEN:",
        "  shr.s64 %sv, %sv, 1;",
        "CCONT:",
        "  add.u64 %acc, %acc, 1;",
        "  bra CLOOP;",
        "CNEXT:",
    ]
    .join("\n")
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.len() < 2 {
        eprintln!("usage: cudabench <squares-map|sumred|collatz> <N> [--runs K]");
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
    if !cudaffi::has_cuda_device() {
        eprintln!("SKIP cudabench: no CUDA device");
        std::process::exit(2);
    }
    let runner = cudaffi::CudaRunner::new().expect("runner");

    // Build once (outside timer, like gcc compile): (ptx, groups, out_lens, finish)
    enum Finish {
        PartialsSumMod,
        PartialsSumRaw,
    }
    let (ptx, groups, out_lens, finish): (String, u32, Vec<usize>, Finish) = match problem.as_str() {
        "squares-map" | "sumred" => {
            // Identical math (masked squares accumulate) — GPU fuses both.
            let ptx = block_ptx(&sumred_op(), n);
            let groups = ((n + 256 * BLOCK as u64 - 1) / (256 * BLOCK as u64)) as u32;
            (ptx, groups, vec![groups as usize], Finish::PartialsSumMod)
        }
        "collatz" => {
            let ptx = block_ptx(&collatz_op(), n);
            let groups = ((n + 256 * BLOCK as u64 - 1) / (256 * BLOCK as u64)) as u32;
            (ptx, groups, vec![groups as usize], Finish::PartialsSumRaw)
        }
        _ => {
            eprintln!("unknown problem {problem}");
            std::process::exit(2);
        }
    };

    // Warmup (proves correctness once, outside timer).
    let out = runner
        .run(&ptx, "kern", &out_lens, groups, THREADS)
        .expect("warmup dispatch");
    let checksum = finish_all(&finish, &out);
    // Timed: median dispatches + host finish each rep.
    let mut ts = Vec::new();
    for _ in 0..runs {
        let t = std::time::Instant::now();
        let out = runner
            .run(&ptx, "kern", &out_lens, groups, THREADS)
            .expect("dispatch");
        let _ = finish_all(&finish, &out);
        ts.push(t.elapsed().as_secs_f64() * 1000.0);
    }
    ts.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = ts[ts.len() / 2];
    println!("{median:.3} {checksum}");
    let _ = ts;

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
