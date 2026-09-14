//! Python front-end support for the -O4 driver family (`python-O4`).
//!
//! This is the Python counterpart of the bash pipeline: the frontend
//! (`frontends/py-sh-go`, the workspace's Python→A1 shIR frontend)
//! emits the same A1 contract the shell parser does, so every generic
//! stage downstream (C render, tcc JIT, CUDA candidacy/dispatch) is
//! reused unchanged.
//!
//! The counted-loop / append normalisation lives in the SHARED shIR
//! transforms (`debashl::transforms::counted_arith_forinit` and
//! `append_to_store`), which the A1 ingress runs for every backend and
//! python-O4 calls on its candidacy view. This module owns only the
//! frontend invocation and the cast-stripped i64 candidacy view.

use debashl::ir::{ArithAst, AssignTarget, IrExpr, IrProgram, IrStmt};
use std::collections::{BTreeMap, BTreeSet};

/// Locate the py-sh-go frontend binary.
/// Precedence: `$PY_SH_GO` → workspace root's `frontends/py-sh-go/py-sh-go`
/// (found exe-relative / via `$BASH_O4_SH2PERL`).
pub fn find_frontend() -> Result<std::path::PathBuf, String> {
    if let Ok(v) = std::env::var("PY_SH_GO") {
        let p = std::path::PathBuf::from(v);
        if p.is_file() {
            return Ok(p);
        }
        return Err(format!("$PY_SH_GO={} is not a file", p.display()));
    }
    // <root>/sh2perl exists → <root>/frontends/py-sh-go/py-sh-go.
    if let Ok(sp) = crate::tcc::find_sh2perl() {
        if let Some(root) = sp.parent() {
            let cand = root.join("frontends").join("py-sh-go").join("py-sh-go");
            if cand.is_file() {
                return Ok(cand);
            }
        }
    }
    // exe-relative walk (mirror of find_sh2perl).
    if let Ok(exe) = std::env::current_exe() {
        let mut dir: Option<std::path::PathBuf> = exe.parent().map(|p| p.to_path_buf());
        for _ in 0..5 {
            let Some(d) = dir else { break };
            let cand = d.join("frontends").join("py-sh-go").join("py-sh-go");
            if cand.is_file() {
                return Ok(cand);
            }
            dir = d.parent().map(|p| p.to_path_buf());
        }
    }
    Err("cannot locate the py-sh-go frontend (set $PY_SH_GO)".to_string())
}

/// Run the frontend on `path` and return its A1 shIR JSON.
pub fn a1_for(path: &std::path::Path) -> Result<String, String> {
    let fe = find_frontend()?;
    let out = std::process::Command::new(&fe)
        .arg("--shir")
        .arg(path)
        .arg("--raw")
        // python-O4 only ever renders C (or PTX, which is i64-exact by
        // construction), so prove integer ranges against the signed-i64
        // ceiling rather than the JS Number bound. Without this, a value
        // provably inside i64 but outside 2^53 (e.g. `i*i` for i<1e9, or
        // a `((x%M)+M)%M` accumulator bounded by M) is wrapped in
        // Cast(Int64) — the frontend's bigint marker — and the C backend
        // homes it in GMP (sumred: 67 s CPU vs 2.4 s).
        .arg("--exact-i64")
        .output()
        .map_err(|e| format!("running {}: {e}", fe.display()))?;
    if !out.status.success() {
        return Err(format!(
            "py-sh-go failed ({}): {}",
            out.status,
            String::from_utf8_lossy(&out.stderr).trim()
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Run the frontend on PYTHON SOURCE TEXT (written to a temp file).
pub fn a1_for_source(src: &str) -> Result<String, String> {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    // Unique per call: tests run in parallel threads of ONE process, so
    // pid alone collides (the two py tests used to race on the same
    // temp file).
    let uniq = format!(
        "{}-{:?}-{}",
        std::process::id(),
        std::thread::current().id(),
        SEQ.fetch_add(1, Ordering::Relaxed)
    );
    let dir = std::env::temp_dir().join(format!("pyo4-src-{uniq}"));
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let f = dir.join("prog.py");
    std::fs::write(&f, src).map_err(|e| e.to_string())?;
    let r = a1_for(&f);
    let _ = std::fs::remove_dir_all(&dir);
    r
}

/// Candidacy view: the same A1 with `Cast` markers stripped. The
/// Python frontend wraps integer-domain reads/moduli in `Cast(Int64, …)`
/// (its bigint exactness marker) — exactness the CPU render needs, but
/// noise for the i64 CUDA model, where `lower_arith` treats the cast as
/// identity AND the mask-plan's AST walk must see bare `Num` moduli
/// (a cast-wrapped pow2 divisor hides the maskable site and costs the
/// `&`/`rem` fast path). Stripping here keeps the shared candidacy code
/// untouched and the CPU render byte-identical (it still uses `a1`).
pub fn a1_without_casts(a1: &str) -> String {
    match serde_json::from_str::<serde_json::Value>(a1) {
        Ok(mut v) => {
            strip_casts_json(&mut v);
            v.to_string()
        }
        Err(_) => a1.to_string(),
    }
}

fn strip_casts_json(v: &mut serde_json::Value) {
    match v {
        serde_json::Value::Object(map) => {
            for (_, child) in map.iter_mut() {
                strip_casts_json(child);
            }
            if map.get("type").and_then(|t| t.as_str()) == Some("Cast") {
                // The flat view strips EVERY cast: the i64 CUDA model
                // treats them as identity, and the mask-plan AST walk
                // must see bare `Num` divisors and bare counter `Var`s
                // (`Cast(Var)` hides both). The sequential-lane analysis
                // keeps its own unstripped view.
                if let Some(arg) = map.remove("arg") {
                    *v = arg;
                }
            }
        }
        serde_json::Value::Array(arr) => {
            for c in arr.iter_mut() {
                strip_casts_json(c);
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use debashl::shir_json_in::shir_json_to_ir;
    use debashl::transforms as T;

    fn prog(src: &str) -> IrProgram {
        let a1 = a1_for_source(src).expect("frontend");
        shir_json_to_ir(&a1).expect("ingress")
    }

    /// The shared transforms python-O4's candidacy view applies.
    fn normalize(p: &mut IrProgram) {
        T::counted_arith_forinit::transform(&mut p.stmts);
        T::append_to_store::transform(&mut p.stmts);
    }

    fn has_forinit(stmts: &[IrStmt]) -> bool {
        stmts.iter().any(|s| matches!(s, IrStmt::ForInit { .. }))
    }

    #[test]
    fn recovers_counted_while() {
        let mut p = prog("N = 10\ns = 0\nfor i in range(N):\n    s = s + i\nprint(s)\n");
        normalize(&mut p);
        assert!(has_forinit(&p.stmts), "no ForInit: {:?}", p.stmts);
    }

    /// `a1_for_source` runs the frontend with `--exact-i64`, so an
    /// integer proven within signed i64 stays native instead of being
    /// wrapped in `Cast(Int64)` (the bigint marker that homes it in
    /// GMP). sumred's mod-2^32 chain is the motivating shape; a genuine
    /// `2**100` must still be marked bigint.
    #[test]
    fn exact_i64_keeps_bounded_mod_chain_native() {
        let a1 = a1_for_source(
            "N = 1000000000\ns = 0\nfor i in range(N):\n    s = (s + (i * i) % 4294967296) % 4294967296\nprint(s)\n",
        )
        .expect("frontend");
        assert!(
            !a1.contains("\"Int64\""),
            "bounded mod-chain still carries the bigint marker:\n{a1}"
        );
        let big = a1_for_source("x = 2 ** 100\nprint(x)\n").expect("frontend");
        assert!(
            big.contains("\"Int64\""),
            "2**100 must stay bigint (exactness):\n{big}"
        );
    }

    #[test]
    fn append_in_counted_loop_becomes_store() {
        let mut p = prog("N = 10\na = []\nfor i in range(N):\n    a.append(i * i)\nprint(a[0])\n");
        normalize(&mut p);
        let s = format!("{:?}", p.stmts);
        assert!(s.contains("a[i]"), "indexed store expected: {s}");
    }

    /// Integration: the Python frontend's shapes reach the CUDA candidacy
    /// through the SHARED transforms (structured `Arith` conditions,
    /// `Cast(Int64, …)` markers, counted-loop appends, floor-mod).
    mod candidacy {
        use super::*;
        use crate::cu_candidacy;

        fn flat(src: &str) -> IrProgram {
            let a1 = a1_for_source(src).expect("frontend");
            let mut p = shir_json_to_ir(&a1_without_casts(&a1)).expect("ingress");
            normalize(&mut p);
            p
        }
        fn cand(src: &str) -> (bool, bool, bool) {
            let p = flat(src);
            let m = cu_candidacy::analyze(&p).iter().any(|v| v.is_candidate());
            let r = cu_candidacy::analyze_reduce(&p)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            // seq uses the RAW view (it keys on the frontend's Cast
            // markers), normalized by the shared counted-loop pass.
            let mut pr = prog(src);
            normalize(&mut pr);
            let s = cu_candidacy::analyze_seq(&pr)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            (m, r, s)
        }

        #[test]
        fn sum_loop_is_reduce_candidate() {
            let (m, r, _) = cand("N = 1000\ns = 0\nfor i in range(N):\n    s = s + i\nprint(s)\n");
            assert!(!m, "scalar carry is not a map");
            assert!(r, "plain sum must be a reduce candidate");
        }

        #[test]
        fn mod_accumulate_with_casts_is_reduce_candidate() {
            let (_, r, _) = cand(
                "N = 1000000000\ns = 0\nfor i in range(N):\n    s = (s + (i * i) % 4294967296) % 4294967296\nprint(s)\n",
            );
            assert!(r, "mod-accumulate must lower through the Cast markers");
        }

        #[test]
        fn map_fill_is_map_candidate() {
            let (m, _, _) = cand("N = 100\na = []\nfor i in range(N):\n    a[i] = i * i\nprint(a[3])\n");
            assert!(m, "indexed fill must be a map candidate");
        }

        #[test]
        fn array_read_mod_is_reduce_candidate() {
            let (m, r, _) = cand(
                "N = 100\na = []\nfor i in range(N):\n    a[i] = i * i\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 256\nprint(s)\n",
            );
            assert!(m, "fill must be a map candidate");
            assert!(r, "array-read reduce must be a candidate");
        }

        #[test]
        fn append_rewrite_enables_map_and_fusion() {
            // The valid-CPython `append` idiom reaches the map/reduce
            // candidacy through the shared `append-to-store` transform.
            let (m, r, _) = cand(
                "N = 100\na = []\nfor i in range(N):\n    a.append(i * i)\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 256\nprint(s)\n",
            );
            assert!(m && r, "append source must yield map+reduce");
        }

        #[test]
        fn floor_mod_composition_lowers_to_mask() {
            // squares-map checksum: `((s+a[i]) % M + M) % M` with pow2 M.
            // Bitwise low bits = the nonnegative residue for ANY sign, so
            // the composition is exactly the existing MaskAdd vehicle —
            // this is what enables the FUSED map+reduce path.
            let p = flat(
                "N = 100000000\na = []\nfor i in range(N):\n    a.append(i * i)\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 4294967296\nprint(s)\n",
            );
            let spec = cu_candidacy::analyze_reduce(&p)
                .into_iter()
                .find_map(|v| v.spec)
                .expect("reduce spec");
            assert!(
                matches!(spec.op, debashl::cuda_backend::CuReduceOp::MaskAdd { .. }),
                "pow2 floor-mod must mask, got {:?}",
                spec.op
            );
            assert_eq!(spec.arrays, vec!["a".to_string()], "must read the map array");
        }

        #[test]
        fn cast_stripped_view_enables_mask_plan() {
            let p = flat(
                "N = 1000000000\ns = 0\nfor i in range(N):\n    s = (s + (i * i) % 4294967296) % 4294967296\nprint(s)\n",
            );
            let spec = cu_candidacy::analyze_reduce(&p)
                .into_iter()
                .find_map(|v| v.spec)
                .expect("reduce spec");
            assert!(spec.mask_thresh.is_some(), "mask plan must fire: {:?}", spec.mask_thresh);
        }

        #[test]
        fn nested_while_only_outer_loop_converts() {
            // Collatz: the inner `while v > 1 … s = s + 1` ends with a
            // counter-looking update but its condition does not drive the
            // counter — it must stay a While (the sequential-lane
            // classifier needs it).
            let src = "N = 1000\ntotal = 0\nfor k in range(N):\n    v = (k * 37 + 3) % 251\n    s = 0\n    while v > 1:\n        if v % 2 == 0:\n            v = v // 2\n        else:\n            v = 3 * v + 1\n        s = s + 1\n    total = total + s\nprint(total)\n";
            let mut p = prog(src);
            normalize(&mut p);
            let forinits = p.stmts.iter().filter(|s| matches!(s, IrStmt::ForInit { .. })).count();
            assert_eq!(forinits, 1, "only the outer range loop: {:?}", p.stmts);
            let (_, _, seq) = cand(src);
            assert!(seq, "collatz must remain a sequential-lane candidate");
        }

        #[test]
        fn multiple_appends_stay_calls() {
            // Refuse > guess: two appends per iteration cannot be one
            // affine store at the counter index.
            let mut p = prog("N = 10\na = []\nfor i in range(N):\n    a.append(i)\n    a.append(i)\nprint(a[0])\n");
            normalize(&mut p);
            assert!(
                !format!("{:?}", p.stmts).contains("a[i]"),
                "two appends must stay calls: {:?}",
                p.stmts
            );
        }
    }
}
