//! Python front-end support for the -O4 driver family (`python-O4`).
//!
//! This is the Python counterpart of the bash pipeline: the frontend
//! (`frontends/py-sh-go`, the workspace's Python→A1 shIR frontend)
//! emits the same A1 contract the shell parser does, so every generic
//! stage downstream (C render, tcc JIT, CUDA candidacy/dispatch) is
//! reused unchanged.
//!
//! One frontend-specific fixup lives here: `normalize_counted` rewrites
//! the Python frontend's counted `while` shape into the core's
//! `IrStmt::ForInit` node. The shell frontend already emits ForInit; the
//! Python frontend lowers `for i in range(N)` to
//! `i = 0; while i < N: … ; i += 1`, and the CUDA candidacy (and any
//! other ForInit-keyed analysis) needs the recovered counted loop. The
//! rewrite is semantics-preserving (a C `for` runs its step on
//! `continue`, which matches Python's `for` and only improves on the
//! shell `while` shape for that case) and is applied to the candidacy
//! view only — the CPU render keeps the frontend's original nodes.

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

/// Rewrite the CPython idiom `a = []; for i in range(N): a.append(v)`
/// into the indexed affine store the map candidacy recognises
/// (`a[i] = v`), for the candidacy view only. Python lists do not
/// auto-grow, so `append` is the valid source form; the frontend lowers
/// it to a `setArrayAppend` call, which the map analysis cannot size.
///
/// Soundness (refuse > guess): only arrays with EXACTLY ONE append site
/// and no other write, an empty `setArray` init, and a counted loop from
/// 0 stepping +1 (so the append index is exactly the counter). Returns
/// the number of rewrites.
pub fn normalize_appends(prog: &mut IrProgram) -> usize {
    let mut info: BTreeMap<String, (usize, bool)> = BTreeMap::new();
    collect_appends(&prog.stmts, &mut info);
    for sub in &prog.subs {
        collect_appends(&sub.body, &mut info);
    }
    let ok: BTreeSet<String> = info
        .iter()
        .filter(|(_, (appends, other))| *appends == 1 && !*other)
        .map(|(k, _)| k.clone())
        .collect();
    if ok.is_empty() {
        return 0;
    }
    rewrite_appends(&mut prog.stmts, &ok)
}

fn is_append_call(e: &IrExpr) -> bool {
    matches!(e, IrExpr::Call { func, .. } if func == "setArrayAppend")
}

fn is_empty_array_init(e: &IrExpr) -> bool {
    match e {
        IrExpr::Call { func, args } if func == "setArray" => match args.get(1) {
            Some(IrExpr::Array(items)) => items.is_empty(),
            _ => false,
        },
        IrExpr::Array(items) => items.is_empty(),
        _ => false,
    }
}

/// Single appended value, or None when the call shape is not 1:1.
fn appended_value(e: &IrExpr) -> Option<IrExpr> {
    let IrExpr::Call { args, .. } = e else { return None };
    match args.get(1) {
        Some(IrExpr::Array(items)) if items.len() == 1 => Some(items[0].clone()),
        _ => None,
    }
}

fn collect_appends(stmts: &[IrStmt], info: &mut BTreeMap<String, (usize, bool)>) {
    for s in stmts {
        match s {
            IrStmt::Assign { targets, expr, .. } => {
                if let Some(t) = targets.first() {
                    let base = t.var.split('[').next().unwrap_or(&t.var).to_string();
                    if t.indices.is_empty() && !base.is_empty() {
                        let ent = info.entry(base).or_insert((0, false));
                        if is_append_call(expr) {
                            ent.0 += 1;
                        } else if !is_empty_array_init(expr) {
                            ent.1 = true;
                        }
                    }
                }
            }
            IrStmt::DeclareArray { var, .. } => {
                info.entry(var.clone()).or_insert((0, false)).1 = true;
            }
            IrStmt::If { then, elsifs, else_, .. } => {
                collect_appends(then, info);
                for (_, b) in elsifs {
                    collect_appends(b, info);
                }
                collect_appends(else_, info);
            }
            IrStmt::For { body, .. }
            | IrStmt::While { body, .. }
            | IrStmt::DoWhile { body, .. }
            | IrStmt::Block(body)
            | IrStmt::Subshell(body)
            | IrStmt::Background(body)
            | IrStmt::Redirect { inner: body, .. } => collect_appends(body, info),
            IrStmt::ForInit { init, step, body, .. } => {
                collect_appends(init, info);
                collect_appends(step, info);
                collect_appends(body, info);
            }
            IrStmt::Try { body, else_body, finally_body, excepts } => {
                collect_appends(body, info);
                collect_appends(else_body, info);
                collect_appends(finally_body, info);
                for e in excepts {
                    collect_appends(&e.body, info);
                }
            }
            IrStmt::Case { clauses, .. } => {
                for c in clauses {
                    collect_appends(&c.body, info);
                }
            }
            IrStmt::Select { clauses } => {
                for c in clauses {
                    collect_appends(&c.body, info);
                }
            }
            _ => {}
        }
    }
}

fn rewrite_appends(stmts: &mut Vec<IrStmt>, ok: &BTreeSet<String>) -> usize {
    let mut n = 0;
    for s in stmts.iter_mut() {
        match s {
            IrStmt::ForInit { init, step, body, .. } => {
                n += rewrite_appends(init, ok);
                n += rewrite_appends(step, ok);
                // Counted header from `normalize_counted`: `i = 0` and a
                // `+1` step (IncDec) — then append #k is index `i`.
                let counter = init.last().and_then(|s| match s {
                    IrStmt::Assign { targets, expr, .. } if targets.len() == 1 => {
                        let zero = matches!(expr, IrExpr::Int(0))
                            || matches!(expr, IrExpr::Str(t, _) if t.trim() == "0")
                            || matches!(expr, IrExpr::Arith(a)
                                if matches!(a.as_ref(), ArithAst::Num(0)));
                        zero.then(|| targets[0].var.clone())
                    }
                    _ => None,
                });
                let step_ok = matches!(
                    step.as_slice(),
                    [IrStmt::Assign { expr: IrExpr::Arith(a), .. }]
                        if matches!(a.as_ref(), ArithAst::IncDec { delta: 1, .. })
                ) && counter.is_some();
                if let (Some(counter), true) = (counter, step_ok) {
                    for b in body.iter_mut() {
                        if let IrStmt::Assign { targets, expr, .. } = b {
                            let Some(t) = targets.first() else { continue };
                            let base = t.var.split('[').next().unwrap_or(&t.var).to_string();
                            if t.indices.is_empty() && ok.contains(&base) {
                                if let Some(value) = appended_value(expr) {
                                    *b = IrStmt::Assign {
                                        targets: vec![AssignTarget {
                                            var: format!("{base}[{counter}]"),
                                            sigil: None,
                                            indices: Vec::new(),
                                        }],
                                        expr: value,
                                        asm: None,
                                    };
                                    n += 1;
                                }
                            }
                        }
                    }
                }
                n += rewrite_appends(body, ok);
            }
            IrStmt::If { then, elsifs, else_, .. } => {
                n += rewrite_appends(then, ok) + rewrite_appends(else_, ok);
                for (_, b) in elsifs {
                    n += rewrite_appends(b, ok);
                }
            }
            IrStmt::For { body, .. }
            | IrStmt::While { body, .. }
            | IrStmt::DoWhile { body, .. }
            | IrStmt::Block(body)
            | IrStmt::Subshell(body)
            | IrStmt::Background(body)
            | IrStmt::Redirect { inner: body, .. } => n += rewrite_appends(body, ok),
            IrStmt::Try { body, else_body, finally_body, excepts } => {
                n += rewrite_appends(body, ok)
                    + rewrite_appends(else_body, ok)
                    + rewrite_appends(finally_body, ok);
                for e in excepts {
                    n += rewrite_appends(&mut e.body, ok);
                }
            }
            IrStmt::Case { clauses, .. } => {
                for c in clauses {
                    n += rewrite_appends(&mut c.body, ok);
                }
            }
            IrStmt::Select { clauses } => {
                for c in clauses {
                    n += rewrite_appends(&mut c.body, ok);
                }
            }
            _ => {}
        }
    }
    n
}

/// Recover `IrStmt::ForInit` from the Python frontend's counted-while
/// shape, recursively. Returns the number of loops rewritten.
pub fn normalize_counted(prog: &mut IrProgram) -> usize {
    normalize_list(&mut prog.stmts)
}

fn normalize_list(stmts: &mut Vec<IrStmt>) -> usize {
    let mut n = 0;
    for s in stmts.iter_mut() {
        n += normalize_stmt(s);
    }
    let mut i = 1;
    while i < stmts.len() {
        let Some((_var, init, cond, step, body)) = counted_while(&stmts[i - 1], &stmts[i]) else {
            i += 1;
            continue;
        };
        let _ = stmts.remove(i - 1);
        stmts[i - 1] = IrStmt::ForInit {
            init: vec![init],
            cond,
            step: vec![step],
            body,
        };
        n += 1;
        if i > 1 {
            i -= 1;
        }
    }
    n
}

fn normalize_stmt(s: &mut IrStmt) -> usize {
    match s {
        IrStmt::If {
            then,
            elsifs,
            else_,
            ..
        } => {
            let mut c = normalize_list(then) + normalize_list(else_);
            for (_, b) in elsifs {
                c += normalize_list(b);
            }
            c
        }
        IrStmt::For { body, .. }
        | IrStmt::While { body, .. }
        | IrStmt::DoWhile { body, .. }
        | IrStmt::Block(body)
        | IrStmt::Subshell(body)
        | IrStmt::Background(body)
        | IrStmt::Redirect { inner: body, .. } => normalize_list(body),
        IrStmt::ForInit {
            init, step, body, ..
        } => {
            normalize_list(init) + normalize_list(step) + normalize_list(body)
        }
        IrStmt::Function {
            body, named_blocks, ..
        } => {
            let mut c = normalize_list(body);
            for (_, b) in named_blocks {
                c += normalize_list(b);
            }
            c
        }
        IrStmt::Try {
            body,
            else_body,
            finally_body,
            excepts,
        } => {
            let mut c =
                normalize_list(body) + normalize_list(else_body) + normalize_list(finally_body);
            for e in excepts {
                c += normalize_list(&mut e.body);
            }
            c
        }
        IrStmt::Case { clauses, .. } => {
            clauses.iter_mut().map(|c| normalize_list(&mut c.body)).sum()
        }
        IrStmt::Select { clauses } => {
            clauses.iter_mut().map(|c| normalize_list(&mut c.body)).sum()
        }
        _ => 0,
    }
}

/// Match `[<counter init>, While { cond, body }]` where the while body's
/// LAST statement is the counter update. Returns (var, cond, step-as-
/// Assign, body-without-step).
fn counted_while(
    init_stmt: &IrStmt,
    while_stmt: &IrStmt,
) -> Option<(String, IrStmt, IrExpr, IrStmt, Vec<IrStmt>)> {
    let IrStmt::Assign {
        targets,
        expr,
        asm: None,
    } = init_stmt
    else {
        return None;
    };
    if targets.len() != 1 || !targets[0].indices.is_empty() {
        return None;
    }
    let var = targets[0].var.clone();
    // Normalize the init to the arith numeric-literal form the counted-
    // loop consumers expect: the range lowering already emits
    // `Arith(Num)`, but a user-written `i = 0` arrives as `Str("0")`.
    let init_expr = match expr {
        IrExpr::Arith(_) => expr.clone(),
        IrExpr::Int(m) => IrExpr::Arith(Box::new(ArithAst::Num(*m))),
        IrExpr::Str(s, _) => {
            let m = s.trim().parse::<i64>().ok()?;
            IrExpr::Arith(Box::new(ArithAst::Num(m)))
        }
        _ => return None,
    };
    let init = IrStmt::Assign {
        targets: targets.clone(),
        expr: init_expr,
        asm: None,
    };
    let IrStmt::While { cond, body } = while_stmt else {
        return None;
    };
    // The candidate counter must actually drive the condition: a body
    // ending in `s = s + 1` under `while v > 1` is a loop-carried
    // counter, NOT a counted loop (converting it would break the
    // sequential-lane classifier, which needs the inner `while`).
    if !cond_mentions(cond, &var) {
        return None;
    }
    let last = body.last()?;
    let step = counter_update(last, &var)?;
    Some((var, init, cond.clone(), step, body[..body.len() - 1].to_vec()))
}

/// Does the condition read `name` (in the structured arith the Python
/// frontend emits, or in the shell `let`-text form)?
fn cond_mentions(cond: &IrExpr, name: &str) -> bool {
    fn arith(a: &ArithAst, name: &str) -> bool {
        match a {
            ArithAst::Var(v) | ArithAst::Ident(v) => v == name,
            ArithAst::Num(_) | ArithAst::Sizeof(_) => false,
            ArithAst::Bin { lhs, rhs, .. } => arith(lhs, name) || arith(rhs, name),
            ArithAst::Un { arg, .. } => arith(arg, name),
            ArithAst::Cond { test, then, else_ } => {
                arith(test, name) || arith(then, name) || arith(else_, name)
            }
            ArithAst::Assign { var, rhs, .. } => var == name || arith(rhs, name),
            ArithAst::IncDec { var, .. } => var == name,
            ArithAst::Index { var, key } => var == name || arith(key, name),
            ArithAst::Cast { arg, .. } => arith(arg, name),
        }
    }
    fn expr(e: &IrExpr, name: &str) -> bool {
        match e {
            IrExpr::Arith(a) => arith(a, name),
            IrExpr::Var(v, _) | IrExpr::Ident(v) => v == name,
            IrExpr::Str(s, _) => {
                // shell `let` text: `i < n` / `$i -lt $n`
                s.split(|c: char| !(c.is_ascii_alphanumeric() || c == '_'))
                    .any(|tok| tok == name)
            }
            IrExpr::Array(items) => items.iter().any(|x| expr(x, name)),
            IrExpr::Call { args, .. } => args.iter().any(|x| expr(x, name)),
            IrExpr::BinOp { lhs, rhs, .. } => expr(lhs, name) || expr(rhs, name),
            IrExpr::Index { var, key } => var == name || expr(key, name),
            IrExpr::Ternary { cond, then, else_ } => {
                expr(cond, name) || expr(then, name) || expr(else_, name)
            }
            _ => false,
        }
    }
    expr(cond, name)
}

/// Recognize the counter update and normalize it to an Assign statement.
fn counter_update(st: &IrStmt, var: &str) -> Option<IrStmt> {
    let arith = match st {
        IrStmt::Assign {
            targets,
            expr: IrExpr::Arith(a),
            asm: None,
        } if targets.len() == 1 && targets[0].var == var && targets[0].indices.is_empty() => {
            a
        }
        IrStmt::Expr(IrExpr::Arith(a)) => a,
        _ => return None,
    };
    let ok = match arith.as_ref() {
        ArithAst::IncDec { var: v, .. } => v == var,
        ArithAst::Assign { var: v, .. } => v == var,
        ArithAst::Bin { op, lhs, .. } if op == "+" || op == "-" => {
            matches!(lhs.as_ref(), ArithAst::Var(v) | ArithAst::Ident(v) if v == var)
        }
        _ => false,
    };
    if !ok {
        return None;
    }
    Some(IrStmt::Assign {
        targets: vec![AssignTarget {
            var: var.to_string(),
            sigil: None,
            indices: Vec::new(),
        }],
        expr: IrExpr::Arith(arith.clone()),
        asm: None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use debashl::shir_json_in::shir_json_to_ir;

    fn prog(src: &str) -> IrProgram {
        let a1 = a1_for_source(src).expect("frontend");
        shir_json_to_ir(&a1).expect("ingress")
    }

    fn has_forinit(stmts: &[IrStmt]) -> bool {
        stmts.iter().any(|s| matches!(s, IrStmt::ForInit { .. }))
    }

    #[test]
    fn recovers_counted_while() {
        // The range lowering emits `i = arith(0); while i < N: …; i++`.
        let mut p = prog("N = 10\ns = 0\nfor i in range(N):\n    s = s + i\nprint(s)\n");
        let n = normalize_counted(&mut p);
        assert!(n >= 1, "expected a recovered ForInit, stmts={:?}", p.stmts);
        assert!(has_forinit(&p.stmts), "no ForInit: {:?}", p.stmts);
    }

    #[test]
    fn leaves_uncounted_while_alone() {
        // No trailing counter update → not a counted loop, untouched.
        let mut p = prog("i = 0\nwhile i < 3:\n    print(i)\n    i = i + 2\n");
        // `i = i + 2` IS a counter update (step 2), so this one converts;
        // the uncounted case below must not.
        assert!(normalize_counted(&mut p) >= 1);
        let mut p2 = prog("i = 0\nwhile i < 3:\n    print(i)\n");
        assert_eq!(normalize_counted(&mut p2), 0, "uncounted while must stay: {:?}", p2.stmts);
    }

    /// Integration: the Python frontend's shapes reach the CUDA candidacy.
    /// This is THE python-O4 feasibility contract (the frontend emits
    /// structured `Arith` conditions and `Cast(Int64, …)` markers that
    /// the shell-frontend-driven candidacy never saw).
    mod candidacy {
        use super::*;
        use crate::cu_candidacy;

        fn candidates(src: &str) -> (bool, bool, bool) {
            let mut p = prog(src);
            normalize_counted(&mut p);
            let m = cu_candidacy::analyze(&p)
                .iter()
                .any(|v| v.is_candidate());
            let r = cu_candidacy::analyze_reduce(&p)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            let s = cu_candidacy::analyze_seq(&p)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            (m, r, s)
        }

        #[test]
        fn sum_loop_is_reduce_candidate() {
            // `s = s + i` over `range(N)` — structured cond + bare Var init.
            let (m, r, _s) = candidates("N = 1000\ns = 0\nfor i in range(N):\n    s = s + i\nprint(s)\n");
            assert!(!m, "scalar carry is not a map");
            assert!(r, "plain sum must be a reduce candidate");
        }

        #[test]
        fn mod_accumulate_with_casts_is_reduce_candidate() {
            // The bigint-regime Cast markers + mod chain (sumred shape).
            let (_, r, _) = candidates(
                "N = 1000000000\ns = 0\nfor i in range(N):\n    s = (s + (i * i) % 4294967296) % 4294967296\nprint(s)\n",
            );
            assert!(r, "mod-accumulate must lower through the Cast markers");
        }

        #[test]
        fn map_fill_is_map_candidate() {
            // `a[i] = i*i` — the frontend's array store shape.
            let (m, _, _) = candidates("N = 100\na = []\nfor i in range(N):\n    a[i] = i * i\nprint(a[3])\n");
            assert!(m, "indexed fill must be a map candidate");
        }

        #[test]
        fn array_read_mod_is_reduce_candidate() {
            // Regression pin for the frontend's arith `Index` fix: before
            // it, `a[i] % K` nil-panicked the frontend; a silently wrong
            // `subscriptIR` result would also break this shape.
            let (m, r, _) = candidates(
                "N = 100\na = []\nfor i in range(N):\n    a[i] = i * i\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 256\nprint(s)\n",
            );
            assert!(m, "fill must be a map candidate");
            assert!(r, "array-read reduce must be a candidate (mask/floor-mod)");
        }

        #[test]
        fn floor_mod_composition_lowers_to_mask() {
            // squares-map checksum: `((s+a[i]) % M + M) % M` with pow2 M.
            // Bitwise low bits = the nonnegative residue for ANY sign, so
            // the composition is exactly the existing MaskAdd vehicle —
            // pinned here because it is what enables the FUSED map+reduce
            // path (map-only readback loses to pure C).
            let src = "N = 100000000\na = []\nfor i in range(N):\n    a.append(i * i)\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 4294967296\nprint(s)\n";
            let a1 = a1_for_source(src).expect("frontend");
            let mut p = shir_json_to_ir(&a1_without_casts(&a1)).expect("ingress");
            normalize_counted(&mut p);
            normalize_appends(&mut p);
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
            // The frontend's bigint-regime `Cast(Int64, …)` markers hide
            // the pow2 modulus from the mask-plan AST walk. python-O4
            // feeds map/reduce a cast-stripped view; this pins that the
            // mask plan then fires (the `&`/shr fast path, ~15x).
            let src = "N = 1000000000\ns = 0\nfor i in range(N):\n    s = (s + (i * i) % 4294967296) % 4294967296\nprint(s)\n";
            let a1 = a1_for_source(src).expect("frontend");
            let mut flat = shir_json_to_ir(&a1_without_casts(&a1)).expect("ingress");
            normalize_counted(&mut flat);
            let spec = cu_candidacy::analyze_reduce(&flat)
                .into_iter()
                .find_map(|v| v.spec)
                .expect("reduce spec");
            assert!(spec.mask_thresh.is_some(), "mask plan must fire: {:?}", spec.mask_thresh);
        }

        #[test]
        fn append_rewrite_enables_map_and_fusion() {
            // The valid-CPython `append` idiom must reach the map/reduce
            // candidacy (driver-side rewrite; the frontend emits a
            // `setArrayAppend` call the map analysis cannot size).
            let src = "N = 100\na = []\nfor i in range(N):\n    a.append(i * i)\ns = 0\nfor i in range(N):\n    s = (s + a[i]) % 256\nprint(s)\n";
            let a1 = a1_for_source(src).expect("frontend");
            let mut p = shir_json_to_ir(&a1_without_casts(&a1)).expect("ingress");
            normalize_counted(&mut p);
            assert_eq!(normalize_appends(&mut p), 1, "append must rewrite: {:?}", p.stmts);
            let m = cu_candidacy::analyze(&p).iter().any(|v| v.is_candidate());
            let r = cu_candidacy::analyze_reduce(&p)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            assert!(m && r, "map+reduce must both be candidates");
        }

        #[test]
        fn multiple_appends_stay_calls() {
            // Refuse > guess: two appends per iteration cannot be a
            // single affine store at the counter index.
            let mut p = prog("N = 10\na = []\nfor i in range(N):\n    a.append(i)\n    a.append(i)\nprint(a[0])\n");
            normalize_counted(&mut p);
            assert_eq!(normalize_appends(&mut p), 0, "two appends must stay: {:?}", p.stmts);
        }

        #[test]
        fn nested_while_only_outer_loop_converts() {
            // Collatz shape: the inner `while v > 1: … s = s + 1` ends with
            // a counter-looking update but its condition does not drive
            // the counter — it must stay a While (the sequential-lane
            // classifier needs it), while the outer range loop converts.
            let src = "N = 1000\ntotal = 0\nfor k in range(N):\n    v = (k * 37 + 3) % 251\n    s = 0\n    while v > 1:\n        if v % 2 == 0:\n            v = v // 2\n        else:\n            v = 3 * v + 1\n        s = s + 1\n    total = total + s\nprint(total)\n";
            let mut p = prog(src);
            assert_eq!(normalize_counted(&mut p), 1, "only the outer loop: {:?}", p.stmts);
            let seq = cu_candidacy::analyze_seq(&p)
                .iter()
                .any(|v| matches!(v.verdict, cu_candidacy::CuVerdictKind::Candidate));
            assert!(seq, "collatz must remain a sequential-lane candidate");
        }
    }
}
