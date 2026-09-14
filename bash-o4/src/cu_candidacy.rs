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

impl std::fmt::Display for CuReduceVerdict {
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

/// A scalar-accumulate verdict for reduction lowering.
#[derive(Debug, Clone, PartialEq)]
pub struct CuReduceVerdict {
    pub id: String,
    pub path: String,
    pub var: String,
    pub lo: i64,
    pub bound_var: String,
    pub bound_lt: bool,
    pub step: i64,
    pub verdict: CuVerdictKind,
    pub spec: Option<debashl::cuda_backend::CuReduceSpec>,
}

/// Accumulator init: literal value or unset (bash unset-arith-0).
#[derive(Debug, Clone, Copy, PartialEq)]
enum AccInit {
    Lit(i64),
    Unset,
}

/// Analyze a program for reduction candidates: ForInit-dyn loops whose
/// body is a single scalar accumulate plus nothing else (step lives
/// separately). Shapes (`acc` = target, `X` = anything lowerable):
/// `acc+X`/`X+acc` (Add), `acc*X`/`X*acc` (Mul), `(acc+X)%m` (ModAdd,
/// m literal in 1..=2^32), `(acc+X)&mask` (MaskAdd, mask+1 pow2 and
/// <= u32::MAX). Anything else vetoes with a reason.
///
/// Init rule: `acc` assigned at most once outside this loop's body, and
/// that assign (if any) is an unconditional literal (top-level or Block
/// straight-line — never under If/loops/functions, where conditionality
/// would make the entry value unknowable). Zero outside assigns means
/// bash-unset (reads 0 in arith) — accepted as init 0.
pub fn analyze_reduce(prog: &IrProgram) -> Vec<CuReduceVerdict> {
    let types: BTreeMap<String, IrType> =
        prog.var_types.iter().map(|(n, t)| (n.clone(), t.clone())).collect();
    let mut out = Vec::new();
    let mut scope = Scope::new("main".to_string(), &types);
    walk_reduce(&prog.stmts, "main", &mut scope, &mut out, &types, prog);
    out
}

fn walk_reduce(
    stmts: &[IrStmt],
    path: &str,
    scope: &mut Scope,
    out: &mut Vec<CuReduceVerdict>,
    types: &BTreeMap<String, IrType>,
    prog: &IrProgram,
) {
    for (i, s) in stmts.iter().enumerate() {
        let here = format!("{path}[{i}]");
        match s {
            IrStmt::ForInit { init, cond, step, body } => {
                out.push(analyze_reduce_init(
                    scope, &here, init, cond, step, body, types, prog,
                ));
            }
            IrStmt::Function { name, body, .. } => {
                let mut inner = Scope::new(name.clone(), types);
                walk_reduce(body, &format!("{name}/body"), &mut inner, out, types, prog);
            }
            IrStmt::If { then, elsifs, else_, .. } => {
                walk_reduce(then, &here, scope, out, types, prog);
                for (_, b) in elsifs {
                    walk_reduce(b, &here, scope, out, types, prog);
                }
                walk_reduce(else_, &here, scope, out, types, prog);
            }
            IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => {
                walk_reduce(body, &here, scope, out, types, prog);
            }
            IrStmt::Subshell(b) | IrStmt::Background(b) | IrStmt::Block(b) => {
                walk_reduce(b, &here, scope, out, types, prog);
            }
            _ => {}
        }
    }
}

fn rveto(scope: &mut Scope, path: &str, var: &str, reason: &'static str) -> CuReduceVerdict {
    CuReduceVerdict {
        id: scope.next_id().replace("cu_loop_", "cu_red_"),
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

/// Outside-loop assigns to `acc`: at most one unconditional literal.
/// Straight-line positions (top level, Blocks, ForInit inits) count
/// literals; loop bodies/steps, conditionals, functions, and anything
/// else naming acc disqualify. Zero hits means bash-unset (reads 0).
/// `skip_body` is this loop's own body slice (its accum assign is
/// structural, never an init — skipped by pointer range).
fn acc_init_rule(
    prog: &IrProgram,
    acc: &str,
    skip_body: &[IrStmt],
) -> Option<AccInit> {
    let skip = skip_body.as_ptr_range();
    let in_skip = |s: &IrStmt| {
        let p = s as *const IrStmt;
        p >= skip.start && p < skip.end
    };
    struct Found {
        count: u32,
        lit: Option<i64>,
        bad: bool,
    }
    fn lit_of(expr: &IrExpr) -> Option<i64> {
        // Frontend emits list literals as Str ("0", not Int 0).
        match expr {
            IrExpr::Int(n) => Some(*n),
            IrExpr::Str(t, _) => t.trim().parse::<i64>().ok(),
            IrExpr::Arith(a) => match a.as_ref() {
                ArithAst::Num(n) => Some(*n),
                _ => None,
            },
            _ => None,
        }
    }
    fn scan(
        stmts: &[IrStmt],
        acc: &str,
        in_skip: &dyn Fn(&IrStmt) -> bool,
        conditional: bool,
        found: &mut Found,
    ) {
        for s in stmts {
            if in_skip(s) {
                continue;
            }
            match s {
                IrStmt::Assign { targets, expr, .. } => {
                    for t in targets {
                        let base = t.var.split('[').next().unwrap_or(&t.var);
                        if base != acc {
                            continue;
                        }
                        if !t.indices.is_empty() || t.var.contains('[') {
                            found.bad = true;
                            continue;
                        }
                        match lit_of(expr) {
                            Some(n) => {
                                found.count += 1;
                                if conditional {
                                    found.bad = true;
                                } else if found.lit.replace(n).is_some() {
                                    found.bad = true;
                                }
                            }
                            None => {
                                found.bad = true;
                            }
                        }
                    }
                }
                IrStmt::Block(b) => scan(b, acc, in_skip, conditional, found),
                IrStmt::ForInit { init, step, body, .. } => {
                    // init runs once (literal inits count); step/body
                    // repeat (any acc write there disqualifies — except
                    // this loop's own body, skipped by range above).
                    scan(init, acc, in_skip, conditional, found);
                    if writes_acc(step, acc, in_skip) || writes_acc(body, acc, in_skip) {
                        found.bad = true;
                    }
                }
                IrStmt::If { then, elsifs, else_, .. } => {
                    scan(then, acc, in_skip, true, found);
                    for (_, b) in elsifs {
                        scan(b, acc, in_skip, true, found);
                    }
                    scan(else_, acc, in_skip, true, found);
                }
                IrStmt::ForInit { init, step, body, .. } => {
                    // init runs once (straight-line); step/body repeat.
                    scan(init, acc, in_skip, conditional, found);
                    if writes_acc(step, acc, in_skip) || writes_acc(body, acc, in_skip) {
                        found.bad = true;
                    }
                }
                _ => {
                    if writes_acc(std::slice::from_ref(s), acc, in_skip) {
                        found.bad = true;
                    }
                }
            }
        }
    }
    /// Any write to acc under these stmts (deep, except skipped).
    fn writes_acc(stmts: &[IrStmt], acc: &str, in_skip: &dyn Fn(&IrStmt) -> bool) -> bool {
        stmts.iter().any(|s| {
            if in_skip(s) {
                return false;
            }
            match s {
                IrStmt::Assign { targets, .. } => targets.iter().any(|t| {
                    t.var.split('[').next().unwrap_or(&t.var) == acc
                }),
                IrStmt::Declare { vars, .. } => vars.iter().any(|d| d.name == acc),
                IrStmt::DeclareArray { var, .. } => var == acc,
                IrStmt::If { then, elsifs, else_, .. } => {
                    writes_acc(then, acc, in_skip)
                        || elsifs.iter().any(|(_, b)| writes_acc(b, acc, in_skip))
                        || writes_acc(else_, acc, in_skip)
                }
                IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => {
                    writes_acc(body, acc, in_skip)
                }
                IrStmt::For { body, .. } => writes_acc(body, acc, in_skip),
                IrStmt::ForInit { init, step, body, .. } => {
                    writes_acc(init, acc, in_skip)
                        || writes_acc(step, acc, in_skip)
                        || writes_acc(body, acc, in_skip)
                }
                IrStmt::Block(b) => writes_acc(b, acc, in_skip),
                _ => false,
            }
        })
    }
    let mut found = Found { count: 0, lit: None, bad: false };
    scan(&prog.stmts, acc, &in_skip, false, &mut found);
    for sub in &prog.subs {
        // Function bodies may run inside loops (dynamic scope) — any
        // write there disqualifies (conservative).
        if writes_acc(&sub.body, acc, &in_skip) {
            found.bad = true;
        }
    }
    if found.bad {
        return None;
    }
    match (found.count, found.lit) {
        (0, _) => Some(AccInit::Unset),
        (1, Some(n)) => Some(AccInit::Lit(n)),
        _ => None,
    }
}

fn analyze_reduce_init(
    scope: &mut Scope,
    path: &str,
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    body: &[IrStmt],
    types: &BTreeMap<String, IrType>,
    prog: &IrProgram,
) -> CuReduceVerdict {
    use debashl::cuda_backend::{CuArith, CuReduceOp, CuReduceSpec};
    // init literal + counter Int-verdict (mirror map path).
    let (var, lo) = match init.last() {
        Some(IrStmt::Assign { targets, expr, .. }) => {
            let Some(t) = targets.first() else {
                return rveto(scope, path, "?", "non-counted-init");
            };
            if targets.len() != 1 || t.var.contains('[') {
                return rveto(scope, path, &t.var, "non-counted-init");
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
                return rveto(scope, path, &t.var, "non-counted-init");
            };
            (t.var.clone(), n)
        }
        _ => return rveto(scope, path, "?", "non-counted-init"),
    };
    if types.get(&var).is_some_and(|t| !is_signed_int(t)) {
        return rveto(scope, path, &var, "unproven-width");
    }
    let (bound_var, inclusive) = match cond_dyn_bound(cond, &var) {
        Some(v) => v,
        None => return rveto(scope, path, &var, "non-counted-cond"),
    };
    // step single positive (mirror map path).
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
                return rveto(scope, path, &var, "non-counted-step");
            }
            match d {
                Some(n) if n != 0 => n,
                _ => return rveto(scope, path, &var, "non-counted-step"),
            }
        }
        _ => return rveto(scope, path, &var, "non-counted-step"),
    };
    if st <= 0 {
        return rveto(scope, path, &var, "non-positive-step");
    }
    // Body: exactly one scalar accumulate statement.
    let one = match body {
        [one] => one,
        _ => return rveto(scope, path, &var, "non-single-accumulate"),
    };
    let IrStmt::Assign { targets, expr, .. } = one else {
        return rveto(scope, path, &var, host_reason(one));
    };
    if targets.len() != 1 {
        return rveto(scope, path, &var, "multi-target");
    }
    let acc = targets[0].var.split('[').next().unwrap_or(&targets[0].var).to_string();
    if acc.is_empty() || acc == var {
        return rveto(scope, path, &var, "bad-accum-target");
    }
    if !targets[0].indices.is_empty() || targets[0].var.contains('[') {
        return rveto(scope, path, &var, "accum-indexed");
    }
    let IrExpr::Arith(ast) = expr else {
        return rveto(scope, path, &var, "non-arith-accum");
    };
    // Acc init (unconditional literal outside, or unset).
    let acc_init = match acc_init_rule(prog, &acc, body) {
        Some(AccInit::Lit(n)) => n,
        Some(AccInit::Unset) => 0,
        None => return rveto(scope, path, &var, "non-literal-init"),
    };
    // Op classification over (acc-side, other-side).
    let mut cx = BodyCx { var: &var, types, externs: BTreeSet::new() };
    // Returns (op, X-subtree) with X lowered after.
    enum Shape<'x> {
        Add(&'x ArithAst),
        Mul(&'x ArithAst),
        Mod(&'x ArithAst, i64),
        Mask(&'x ArithAst, i64),
    }
    fn is_acc(x: &ArithAst, acc: &str) -> bool {
        matches!(x, ArithAst::Var(v) | ArithAst::Ident(v) if v == acc)
    }
    let shape: Option<Shape> = match ast.as_ref() {
        ArithAst::Bin { op, lhs, rhs } if op == "+" || op == "*" => {
            if is_acc(lhs, &acc) {
                Some(if op == "+" { Shape::Add(rhs) } else { Shape::Mul(rhs) })
            } else if is_acc(rhs, &acc) {
                Some(if op == "+" { Shape::Add(lhs) } else { Shape::Mul(lhs) })
            } else {
                None
            }
        }
        ArithAst::Bin { op, lhs, rhs } if op == "%" => {
            // `(acc+X) % m` / `(X+acc) % m`, m literal in 1..=2^32
            // (2^32 needs u64 compare — u32::MAX excludes it).
            let Some((inner, m)) = (match rhs.as_ref() {
                ArithAst::Num(m) if *m >= 1 && (*m as u64) <= (1u64 << 32) => Some((lhs.as_ref(), *m)),
                _ => None,
            }) else {
                return rveto(scope, path, &var, "non-accum-op");
            };
            match inner {
                ArithAst::Bin { op: op2, lhs: l2, rhs: r2 } if op2 == "+" => {
                    if is_acc(l2, &acc) {
                        Some(Shape::Mod(r2, m))
                    } else if is_acc(r2, &acc) {
                        Some(Shape::Mod(l2, m))
                    } else {
                        None
                    }
                }
                _ => None,
            }
        }
        ArithAst::Bin { op, lhs, rhs } if op == "&" => {
            // `(acc+X) & mask` / `(X+acc) & mask`, mask+1 pow2 <= 2^32.
            let Some((inner, mask)) = (match rhs.as_ref() {
                ArithAst::Num(m) if *m >= 0 && ((*m as u64) + 1).is_power_of_two()
                    && (*m as u64) < (1u64 << 32) =>
                {
                    Some((lhs.as_ref(), *m))
                }
                _ => None,
            }) else {
                return rveto(scope, path, &var, "non-accum-op");
            };
            match inner {
                ArithAst::Bin { op: op2, lhs: l2, rhs: r2 } if op2 == "+" => {
                    if is_acc(l2, &acc) {
                        Some(Shape::Mask(r2, mask))
                    } else if is_acc(r2, &acc) {
                        Some(Shape::Mask(l2, mask))
                    } else {
                        None
                    }
                }
                _ => None,
            }
        }
        _ => None,
    };
    // (X must mention acc for Min/Max? No — Min/Max aren't matched here
    // at all in v1 (call-shaped, not arith). Add/Mul/Mod/Mask above.)
    let Some(shape) = shape else {
        return rveto(scope, path, &var, "non-accum-op");
    };
    // Lower X with array reads allowed (Index -> ArrRead).
    fn lower_value(e: &ArithAst, cx: &mut BodyCx, var: &str) -> Result<CuArith, &'static str> {
        match e {
            ArithAst::Num(n) => Ok(CuArith::Num(*n)),
            ArithAst::Var(name) | ArithAst::Ident(name) => {
                read_scalar(cx, var, name).ok_or("unproven-width")
            }
            ArithAst::Bin { op, lhs, rhs } => {
                let (l, r) = (lower_value(lhs, cx, var)?, lower_value(rhs, cx, var)?);
                match op.as_str() {
                    "+" => Ok(CuArith::Add(Box::new(l), Box::new(r))),
                    "-" => Ok(CuArith::Sub(Box::new(l), Box::new(r))),
                    "*" => Ok(CuArith::Mul(Box::new(l), Box::new(r))),
                    "/" => Ok(CuArith::Div(Box::new(l), Box::new(r))),
                    "%" => Ok(CuArith::Mod(Box::new(l), Box::new(r))),
                    _ => Err("non-arith-op"),
                }
            }
            ArithAst::Index { var: arr, key } => {
                // Array element read (lengths trusted — dense coverage).
                let k = lower_value(key, cx, var)?;
                Ok(CuArith::ArrRead { array: arr.clone(), index: Box::new(k) })
            }
            _ => Err("non-arith-expr"),
        }
    }
    // Collect arrays read (for buffer params).
    fn collect_arrays(e: &ArithAst, out: &mut Vec<String>) {
        match e {
            ArithAst::Index { var, key } => {
                if !out.contains(var) {
                    out.push(var.clone());
                }
                collect_arrays(key, out);
            }
            ArithAst::Bin { lhs, rhs, .. } => {
                collect_arrays(lhs, out);
                collect_arrays(rhs, out);
            }
            ArithAst::Un { arg, .. } => collect_arrays(arg, out),
            ArithAst::Cond { test, then, else_ } => {
                collect_arrays(test, out);
                collect_arrays(then, out);
                collect_arrays(else_, out);
            }
            ArithAst::Assign { rhs, .. } => collect_arrays(rhs, out),
            ArithAst::Cast { arg, .. } => collect_arrays(arg, out),
            _ => {}
        }
    }
    let (op, x_ast) = match shape {
        Shape::Add(x) => (CuReduceOp::Add, x),
        Shape::Mul(x) => (CuReduceOp::Mul, x),
        Shape::Mod(x, m) => (CuReduceOp::ModAdd { modulus: m }, x),
        Shape::Mask(x, m) => (CuReduceOp::MaskAdd { mask: m }, x),
    };
    let value = match lower_value(x_ast, &mut cx, &var) {
        Ok(v) => v,
        Err(r) => return rveto(scope, path, &var, r),
    };
    let mut arrays: Vec<String> = Vec::new();
    collect_arrays(x_ast, &mut arrays);
    let id = scope.next_id().replace("cu_loop_", "cu_red_");
    let mut externs: Vec<String> = cx.externs.into_iter().collect();
    externs.sort();
    let spec = CuReduceSpec {
        id: id.clone(),
        var: var.to_string(),
        lo,
        bound_var: bound_var.to_string(),
        bound_lt: !inclusive,
        step: st,
        threads: 256,
        block_items: 1024,
        op,
        value,
        acc_init,
        externs,
        arrays,
    };
    CuReduceVerdict {
        id,
        path: path.to_string(),
        var: var.to_string(),
        lo,
        bound_var: bound_var.to_string(),
        bound_lt: !inclusive,
        step: st,
        verdict: CuVerdictKind::Candidate,
        spec: Some(spec),
    }
}

#[cfg(test)]
mod reduce_tests {
    use super::*;

    fn prog_of(src: &str) -> IrProgram {
        let a1 = otranspilerl::shell_to_shir(src);
        debashl::shir_json_in::shir_json_to_ir(&a1).expect("ingress")
    }

    #[test]
    fn sumred_accumulate_is_candidate() {
        // `s=$(((s + (i*i)%4294967296) % 4294967296))`: mod-accumulate
        // with s=0 init, i*i value (Mul+Mod lower).
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$(((s + (i*i)%4294967296) % 4294967296)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1, "one verdict: {vs:?}");
        let v = &vs[0];
        assert!(matches!(v.verdict, CuVerdictKind::Candidate), "expected candidate: {v}");
        let spec = v.spec.as_ref().expect("spec");
        assert!(matches!(spec.op, debashl::cuda_backend::CuReduceOp::ModAdd { modulus: 4294967296 }));
        assert_eq!(spec.acc_init, 0);
    }

    #[test]
    fn plain_sum_is_candidate() {
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$((s+i)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
    }

    #[test]
    fn mask_accumulate_is_candidate() {
        // squares-map loop2 shape: `s=$(((s + a[i]) & 0xFFFFFFFF))`.
        // (Array reads need the array; here with a plain var for shape.)
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$(((s + i) & 255)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
    }

    #[test]
    fn multi_assign_vetoes() {
        // Two accumulates in one body: not a single reduction.
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nt=0\nfor ((i=0;i<n;i++)); do s=$((s+i)); t=$((t+1)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(!matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
    }

    #[test]
    fn dynamic_init_vetoes() {
        // `s=$1` init (non-literal): entry value unknowable statically.
        let prog = prog_of("#!/bin/bash\nn=$1\ns=$2\nfor ((i=0;i<n;i++)); do s=$((s+i)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(!matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
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
