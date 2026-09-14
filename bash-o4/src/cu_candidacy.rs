//! CUDA candidacy: per-loop verdicts for PTX lowering.
//!
//! Mirrors `candidacy` (Vk) with one decisive difference: the trip bound
//! may be a DYNAMIC ident (`for ((i=0;i<n;i++))` with `n=$1`) instead of
//! a literal. Trips/grid are then computed on the host at dispatch from
//! the bound value, and the bound rides as externs[0]. Literal bounds
//! stay on the Vk path (static trips); this path vetoes them —
//! precisely: literal-bound loops are refused here (`static-bound`,
//! use the GLSL emitter) so each backend owns its shapes loudly.
//!
//! v1 scope (documented): ForInit only (`While`/`For` skipped silently,
//! like the Vk path skips While); single-target affine index stores;
//! value arithmetic `+ - * / %` over {counter, Int-verdict externs,
//! literals}; scalar accumulates veto `scalar-carry` (parallel reduction
//! is future work — same M5 boundary). Bound vars are type-permissive
//! (bare ident; host atolls like bash — comparison-only use keeps this
//! sound); value externs stay strict (Int-verdict).

use debashl::cuda_backend::{CuArith, CuLoopSpec, CuStore};
use debashl::ir::{ArithAst, IrExpr, IrProgram, IrStmt, IrType};
use std::collections::{BTreeMap, BTreeSet};

/// A per-loop verdict. `Display` mirrors the `--check` line format.
#[derive(Debug, Clone, PartialEq)]
pub struct CuVerdict {
    pub id: String,
    pub path: String,
    pub var: String,
    pub lo: i64,
    pub bound_var: String,
    pub bound_lt: bool,
    pub step: i64,
    pub verdict: CuVerdictKind,
    pub spec: Option<CuLoopSpec>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum CuVerdictKind {
    Candidate,
    Veto { reason: &'static str },
}

impl CuVerdict {
    pub fn is_candidate(&self) -> bool {
        matches!(self.verdict, CuVerdictKind::Candidate)
    }
}

impl std::fmt::Display for CuVerdict {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self.verdict {
            CuVerdictKind::Candidate => write!(
                f,
                "candidate {} ({}: {} in {}..{}({}) step {})",
                self.id,
                self.path,
                self.var,
                self.lo,
                self.bound_var,
                if self.bound_lt { "<" } else { "<=" },
                self.step
            ),
            CuVerdictKind::Veto { reason } => {
                write!(f, "veto {} ({}: {}): {reason}", self.id, self.path, self.var)
            }
        }
    }
}

/// Analyze a program; one verdict per `ForInit` loop, in order.
pub fn analyze(prog: &IrProgram) -> Vec<CuVerdict> {
    let types: BTreeMap<String, IrType> =
        prog.var_types.iter().map(|(n, t)| (n.clone(), t.clone())).collect();
    let mut out = Vec::new();
    let mut scope = Scope::new("main".to_string(), &types);
    walk_stmts(&prog.stmts, "main", &mut scope, &mut out);
    out
}

struct Scope<'a> {
    name: String,
    types: &'a BTreeMap<String, IrType>,
    n: usize,
}

impl<'a> Scope<'a> {
    fn new(name: String, types: &'a BTreeMap<String, IrType>) -> Self {
        Scope { name, types, n: 0 }
    }
    fn next_id(&mut self) -> String {
        let id = format!("cu_loop_{}_{}", self.name, self.n);
        self.n += 1;
        id
    }
}

fn is_signed_int(t: &IrType) -> bool {
    matches!(t, IrType::Int | IrType::Int32 | IrType::Int64)
}

fn walk_stmts(stmts: &[IrStmt], path: &str, scope: &mut Scope, out: &mut Vec<CuVerdict>) {
    for (i, s) in stmts.iter().enumerate() {
        let here = format!("{path}[{i}]");
        match s {
            IrStmt::ForInit { init, cond, step, body } => {
                out.push(analyze_for_init(scope, &here, init, cond, step, body));
            }
            IrStmt::Function { name, body, .. } => {
                let mut inner = Scope::new(name.clone(), scope.types);
                walk_stmts(body, &format!("{name}/body"), &mut inner, out);
            }
            IrStmt::If { then, elsifs, else_, .. } => {
                walk_stmts(then, &here, scope, out);
                for (_, b) in elsifs {
                    walk_stmts(b, &here, scope, out);
                }
                walk_stmts(else_, &here, scope, out);
            }
            IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => {
                walk_stmts(body, &here, scope, out);
            }
            IrStmt::Subshell(b) | IrStmt::Background(b) | IrStmt::Block(b) => {
                walk_stmts(b, &here, scope, out);
            }
            _ => {}
        }
    }
}

fn veto(scope: &mut Scope, path: &str, var: &str, reason: &'static str) -> CuVerdict {
    CuVerdict {
        id: scope.next_id(),
        path: path.to_string(),
        var: var.to_string(),
        lo: 0,
        bound_var: String::new(),
        bound_lt: true,
        step: 1,
        verdict: CuVerdictKind::Veto { reason },
        spec: None,
    }
}

fn analyze_for_init(
    scope: &mut Scope,
    path: &str,
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    body: &[IrStmt],
) -> CuVerdict {
    // init: single `v = NUM` (Int or Arith Num/Assign-=).
    let (var, lo) = match init.last() {
        Some(IrStmt::Assign { targets, expr, .. }) => {
            let Some(t) = targets.first() else {
                return veto(scope, path, "?", "non-counted-init");
            };
            if targets.len() != 1 || t.var.contains('[') {
                return veto(scope, path, &t.var, "non-counted-init");
            }
            let n = match expr {
                IrExpr::Int(n) => Some(*n),
                IrExpr::Arith(a) => match a.as_ref() {
                    ArithAst::Num(n) => Some(*n),
                    ArithAst::Assign { var: v, op, rhs }
                        if v == &t.var && op == "=" =>
                    {
                        match rhs.as_ref() {
                            ArithAst::Num(n) => Some(*n),
                            _ => None,
                        }
                    }
                    _ => None,
                },
                _ => None,
            };
            let Some(n) = n else {
                return veto(scope, path, &t.var, "non-counted-init");
            };
            (t.var.clone(), n)
        }
        _ => return veto(scope, path, "?", "non-counted-init"),
    };
    if scope.types.get(&var).is_some_and(|t| !is_signed_int(t)) {
        return veto(scope, path, &var, "unproven-width");
    }
    // cond: `loopvar </<= IDENT` text (dynamic bound — the CUDA case).
    // Literal bounds refuse (static-bound: the GLSL emitter owns those).
    let (bound_var, inclusive) = match cond_dyn_bound(cond, &var) {
        Some(v) => v,
        None => return veto(scope, path, &var, "non-counted-cond"),
    };
    // step: single positive (`++`, `+= N`, `+ N` forms).
    let st = match step {
        [IrStmt::Assign { targets, expr, .. }] => {
            let is_var = targets.len() == 1 && targets[0].var == var;
            let d = match expr {
                IrExpr::Arith(a) => match a.as_ref() {
                    ArithAst::IncDec { var: v, delta, .. } if v == &var => Some(*delta),
                    ArithAst::Assign { var: v, op, rhs } if v == &var => match op.as_str() {
                        "+=" => match rhs.as_ref() {
                            ArithAst::Num(n) => Some(*n),
                            _ => None,
                        },
                        "-=" => match rhs.as_ref() {
                            ArithAst::Num(n) => Some(-n),
                            _ => None,
                        },
                        _ => None,
                    },
                    ArithAst::Bin { op, lhs, rhs }
                        if op == "+"
                            && matches!(lhs.as_ref(), ArithAst::Var(v) | ArithAst::Ident(v) if v == &var)
                            && matches!(rhs.as_ref(), ArithAst::Num(n) if *n > 0) =>
                    {
                        match rhs.as_ref() {
                            ArithAst::Num(n) => Some(*n),
                            _ => None,
                        }
                    }
                    _ => None,
                },
                _ => None,
            };
            if !is_var {
                return veto(scope, path, &var, "non-counted-step");
            }
            match d {
                Some(n) if n != 0 => n,
                _ => return veto(scope, path, &var, "non-counted-step"),
            }
        }
        _ => return veto(scope, path, &var, "non-counted-step"),
    };
    if st <= 0 {
        return veto(scope, path, &var, "non-positive-step");
    }
    finish(scope, path, &var, lo, &bound_var, inclusive, st, body)
}

/// Find `loopvar </<= IDENT` text in a condition call (dynamic bound).
/// Literal bounds refuse here (`static-bound` — the GLSL path owns them).
fn cond_dyn_bound(cond: &IrExpr, var: &str) -> Option<(String, bool)> {
    fn texts(e: &IrExpr, out: &mut Vec<String>) {
        match e {
            IrExpr::Str(s, _) => out.push(s.clone()),
            IrExpr::Array(items) => items.iter().for_each(|x| texts(x, out)),
            IrExpr::Call { args, .. } => args.iter().for_each(|x| texts(x, out)),
            _ => {}
        }
    }
    fn is_ident(s: &str) -> bool {
        !s.is_empty() && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '_')
    }
    let mut ts = Vec::new();
    texts(cond, &mut ts);
    ts.iter().find_map(|t| {
        let clean: String = t.chars().filter(|c| !c.is_whitespace()).collect();
        // (literal-bound shapes refused: parse fails below → None)
        for op in ["<=", "<"] {
            if let Some((l, r)) = clean.split_once(op) {
                let lv = l.strip_prefix('$').unwrap_or(l);
                let rv = r.strip_prefix('$').unwrap_or(r);
                if lv == var && is_ident(rv) && rv.parse::<i64>().is_err() {
                    return Some((rv.to_string(), op == "<="));
                }
            }
        }
        None
    })
}

/// Shared body analysis + spec construction (mirror of the Vk finish).
fn finish(
    scope: &mut Scope,
    path: &str,
    var: &str,
    lo: i64,
    bound_var: &str,
    inclusive: bool,
    step: i64,
    body: &[IrStmt],
) -> CuVerdict {
    use crate::candidacy;
    let mut cx = BodyCx { var, types: scope.types, externs: BTreeSet::new() };
    let mut stores: Vec<CuStore> = Vec::new();
    let mut seen_arrays: BTreeSet<String> = BTreeSet::new();
    for s in body {
        let IrStmt::Assign { targets, expr, .. } = s else {
            return veto(scope, path, var, host_reason(s));
        };
        if targets.len() != 1 {
            return veto(scope, path, var, "multi-target");
        }
        // Index form: structured single Var/Ident/Str, else flattened
        // `arr[...]` text (split_target handles the bracket parse).
        let t0 = &targets[0];
        let (arr, idx_text) = if t0.indices.len() == 1 {
            let base = t0.var.split('[').next().unwrap_or(&t0.var);
            let itext = match &t0.indices[0] {
                IrExpr::Var(v, _) | IrExpr::Ident(v) => v.clone(),
                IrExpr::Str(x, _) => x.clone(),
                _ => return veto(scope, path, var, "non-affine-index"),
            };
            (base.to_string(), itext)
        } else if t0.indices.is_empty() {
            match candidacy::split_target(&t0.var) {
                Some((arr, idx)) => (arr.to_string(), idx.to_string()),
                None => return veto(scope, path, var, "scalar-carry"),
            }
        } else {
            return veto(scope, path, var, "non-affine-index");
        };
        if arr.is_empty() {
            return veto(scope, path, var, "scalar-carry");
        }
        let Some((a, b)) = candidacy::affine_index(&idx_text, var) else {
            return veto(scope, path, var, "non-affine-index");
        };
        if !seen_arrays.insert(arr.to_string()) {
            return veto(scope, path, var, "overlapping-stores");
        }
        let IrExpr::Arith(ast) = expr else {
            let scalar = match expr {
                IrExpr::Var(name, _) | IrExpr::Ident(name) => read_scalar(&mut cx, var, name),
                IrExpr::Call { func, args } if func == "getVar" => {
                    match args.first() {
                        Some(IrExpr::Str(name, _)) => read_scalar(&mut cx, var, name),
                        _ => None,
                    }
                }
                IrExpr::Int(n) => Some(CuArith::Num(*n)),
                IrExpr::Str(s, _) => s.parse::<i64>().ok().map(CuArith::Num),
                _ => None,
            };
            let Some(value) = scalar else {
                return veto(scope, path, var, "non-arith-value");
            };
            stores.push(CuStore { array: arr.to_string(), index_a: a, index_b: b, value });
            continue;
        };
        let value = match lower_arith(ast, &mut cx) {
            Ok(v) => v,
            Err(r) => return veto(scope, path, var, r),
        };
        stores.push(CuStore { array: arr.to_string(), index_a: a, index_b: b, value });
    }
    if stores.is_empty() {
        return veto(scope, path, var, "empty-body");
    }
    let id = scope.next_id();
    // externs[0] is always the bound var (host contract); value externs
    // follow in sorted order (BTreeSet iteration — deterministic).
    let mut externs = vec![bound_var.to_string()];
    for e in cx.externs {
        if e != bound_var {
            externs.push(e);
        }
    }
    let spec = CuLoopSpec {
        id: id.clone(),
        var: var.to_string(),
        lo,
        bound_var: bound_var.to_string(),
        bound_lt: !inclusive,
        step,
        threads: 256,
        externs,
        stores,
    };
    CuVerdict {
        id,
        path: path.to_string(),
        var: var.to_string(),
        lo,
        bound_var: bound_var.to_string(),
        bound_lt: !inclusive,
        step,
        verdict: CuVerdictKind::Candidate,
        spec: Some(spec),
    }
}

/// Veto reason for a non-Assign body statement (mirror of host_reason).
fn host_reason(s: &IrStmt) -> &'static str {
    if let IrStmt::Expr(IrExpr::Call { func, args }) = s {
        return match func.as_str() {
            "exec" | "builtin" => match args.first() {
                Some(IrExpr::Str(s, _)) if s == "echo" || s == "printf" => "body-host-io",
                _ => "body-call",
            },
            "pipeline" => "body-pipeline",
            "capture" | "captureWords" => "body-capture",
            _ => "body-call",
        };
    }
    match s {
        IrStmt::Output { .. } => "body-host-io",
        IrStmt::WriteFile { .. } => "body-writefile",
        IrStmt::Redirect { .. } => "body-redirect",
        IrStmt::Function { .. } => "body-function",
        _ => "body-other",
    }
}

/// A scalar read in value position: the loop counter, an Int-verdict
/// outer var (recorded as a host-provided extern), else unprovable.
fn read_scalar(cx: &mut BodyCx, var: &str, name: &str) -> Option<CuArith> {
    if name == var {
        Some(CuArith::LoopVar)
    } else if cx.types.get(name).is_some_and(is_signed_int) {
        cx.externs.insert(name.to_string());
        Some(CuArith::ExtVar(name.to_string()))
    } else {
        None
    }
}

/// Lower value arithmetic to `CuArith` (ops ⊆ {+,-,*,/, %}; reads ⊆
/// {loop var, Int-verdict vars, literals}). Records externals.
struct BodyCx<'a> {
    var: &'a str,
    types: &'a BTreeMap<String, IrType>,
    externs: BTreeSet<String>,
}

fn lower_arith(e: &ArithAst, cx: &mut BodyCx) -> Result<CuArith, &'static str> {
    match e {
        ArithAst::Num(n) => Ok(CuArith::Num(*n)),
        ArithAst::Var(name) | ArithAst::Ident(name) => {
            let v = cx.var;
            read_scalar(cx, v, name).ok_or("unproven-width")
        }
        ArithAst::Bin { op, lhs, rhs } => {
            let (l, r) = (lower_arith(lhs, cx)?, lower_arith(rhs, cx)?);
            match op.as_str() {
                "+" => Ok(CuArith::Add(Box::new(l), Box::new(r))),
                "-" => Ok(CuArith::Sub(Box::new(l), Box::new(r))),
                "*" => Ok(CuArith::Mul(Box::new(l), Box::new(r))),
                "/" => Ok(CuArith::Div(Box::new(l), Box::new(r))),
                "%" => Ok(CuArith::Mod(Box::new(l), Box::new(r))),
                _ => Err("non-arith-op"),
            }
        }
        ArithAst::Index { .. } => Err("index-read"),
        _ => Err("non-arith-expr"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn prog_of(src: &str) -> IrProgram {
        let a1 = otranspilerl::shell_to_shir(src);
        debashl::shir_json_in::shir_json_to_ir(&a1).expect("ingress")
    }

    #[test]
    fn dyn_fill_is_candidate() {
        // `for ((i=0;i<n;i++)); do a[$i]=$((i*i)); done` with dynamic n:
        // candidate with bound_var=n, externs=[n], Mul value.
        let prog = prog_of("#!/bin/bash\nn=$1\nfor ((i=0;i<n;i++)); do a[$i]=$((i*i)); done\n");
        let vs = analyze(&prog);
        assert_eq!(vs.len(), 1, "one loop verdict: {vs:?}");
        let v = &vs[0];
        assert!(v.is_candidate(), "expected candidate: {v}");
        assert_eq!(v.bound_var, "n");
        assert!(v.bound_lt);
        let spec = v.spec.as_ref().expect("spec");
        assert_eq!(spec.externs, vec!["n".to_string()]);
        assert_eq!(spec.stores.len(), 1);
        assert_eq!(spec.stores[0].array, "a");
    }

    #[test]
    fn scalar_carry_vetoes() {
        // `s=$((s+i))` accumulate: scalar-carry veto (reduction future work).
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$((s+i)); done\n");
        let vs = analyze(&prog);
        assert_eq!(vs.len(), 1);
        assert!(!vs[0].is_candidate(), "accumulate must veto: {}", vs[0]);
    }

    #[test]
    fn literal_bound_refuses() {
        // `for ((i=0;i<100;i++))`: static-bound (GLSL path owns it).
        let prog = prog_of("#!/bin/bash\nfor ((i=0;i<100;i++)); do a[$i]=$i; done\n");
        let vs = analyze(&prog);
        assert_eq!(vs.len(), 1);
        assert!(!vs[0].is_candidate(), "literal bound must refuse: {}", vs[0]);
    }

    #[test]
    fn div_mod_values_lower() {
        // `%` and `/` values lower (beyond the Vk +,-,* set).
        let prog = prog_of("#!/bin/bash\nn=$1\nfor ((i=0;i<n;i++)); do a[$i]=$((i%251)); done\n");
        let vs = analyze(&prog);
        assert_eq!(vs.len(), 1);
        assert!(vs[0].is_candidate(), "mod value must lower: {}", vs[0]);
        let spec = vs[0].spec.as_ref().expect("spec");
        assert!(matches!(spec.stores[0].value, CuArith::Mod(_, _)));
    }
}
