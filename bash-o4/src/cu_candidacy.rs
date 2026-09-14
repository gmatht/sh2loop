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
    finish(scope, path, &var, lo, &bound_var, inclusive, st, body, step)
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
    step_stmts: &[IrStmt],
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
        let value = match lower_arith(ast, &mut cx, None) {
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
    // Maskable pow2-mods in store values (None = none/stays signed).
    // Needs the loop context (body/step for discipline gates).
    let mask_thresh = cu_mask_plan_map(body, step_stmts, var, lo, bound_var, !inclusive, &stores);
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
        mask_thresh,
        mask_fast: false,
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

fn lower_arith(
    e: &ArithAst,
    cx: &mut BodyCx,
    lane: Option<&BTreeSet<String>>,
) -> Result<CuArith, &'static str> {
    match e {
        ArithAst::Num(n) => Ok(CuArith::Num(*n)),
        ArithAst::Var(name) | ArithAst::Ident(name) => {
            // Lane-local (seq prelude): domination-proven by the
            // lane-privatization analysis — renders as the lane reg.
            if lane.is_some_and(|l| l.contains(name)) {
                return Ok(CuArith::Lane(name.clone()));
            }
            let v = cx.var;
            read_scalar(cx, v, name).ok_or("unproven-width")
        }
        ArithAst::Bin { op, lhs, rhs } => {
            let (l, r) = (lower_arith(lhs, cx, lane)?, lower_arith(rhs, cx, lane)?);
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
/// Analyze a program for SEQUENTIAL-LANE reduction candidates: an outer
/// counted loop whose body is a lane-nest (private seeds, one
/// data-dependent While chain, one scalar accumulate) per
/// `shir_passes::lane_private::classify_seq_chain` (collatz). Returns
/// `CuReduceVerdict`s with array-free `CuReduceSpec`s carrying a
/// `seq_prelude` — the existing Reduce vehicle dispatches them
/// unchanged (partials + host finish).
///
/// Soundness: signed PTX throughout (wrap-identical to bash; the chain
/// guard keeps divisors positive so no div edge exists). No range
/// proofs in v1 (unsigned/shift specializations are V2 speed opts).
/// Whole-program scope (no private reads/writes outside the nest
/// except the acc literal init) is enforced here, not just in the
/// analysis.
pub fn analyze_seq(prog: &IrProgram) -> Vec<CuReduceVerdict> {
    let types: BTreeMap<String, IrType> =
        prog.var_types.iter().map(|(n, t)| (n.clone(), t.clone())).collect();
    let mut out = Vec::new();
    let mut scope = Scope::new("main".to_string(), &types);
    walk_seq(&prog.stmts, "main", &mut scope, &mut out, &types, prog);
    out
}

/// Top-level scan only (v1 scope): nested lane-nests are an honest
/// miss (no verdict, never a misfire) — the whole-program scope check
/// below is exact only when the nest sits at top level.
fn walk_seq(
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
                out.push(analyze_seq_init(scope, &here, init, cond, step, body, types, prog, i));
            }
            _ => {}
        }
    }
}

/// Header parse twin of analyze_for_init/analyze_reduce_init (documented
/// duplication: same counted-loop contract, seq-specific downstream).
/// Returns (var, lo, bound_var, inclusive, step) or a veto reason.
fn seq_counted_header(
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    types: &BTreeMap<String, IrType>,
) -> Result<(String, i64, String, bool, i64), &'static str> {
    let (var, lo) = match init.last() {
        Some(IrStmt::Assign { targets, expr, .. }) => {
            let Some(t) = targets.first() else {
                return Err("non-counted-init");
            };
            if targets.len() != 1 || t.var.contains('[') {
                return Err("non-counted-init");
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
                return Err("non-counted-init");
            };
            (t.var.clone(), n)
        }
        _ => return Err("non-counted-init"),
    };
    if types.get(&var).is_some_and(|t| !is_signed_int(t)) {
        return Err("unproven-width");
    }
    let (bound_var, inclusive) = match cond_dyn_bound(cond, &var) {
        Some(v) => v,
        None => return Err("non-counted-cond"),
    };
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
                return Err("non-counted-step");
            }
            match d {
                Some(n) if n != 0 => n,
                _ => return Err("non-counted-step"),
            }
        }
        _ => return Err("non-counted-step"),
    };
    if st <= 0 {
        return Err("non-positive-step");
    }
    Ok((var, lo, bound_var, inclusive, st))
}

fn analyze_seq_init(
    scope: &mut Scope,
    path: &str,
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    body: &[IrStmt],
    types: &BTreeMap<String, IrType>,
    prog: &IrProgram,
    loop_idx: usize,
) -> CuReduceVerdict {
    use debashl::cuda_backend::{CuArith, CuReduceOp, CuReduceSpec};
    use debashl::shir_passes::lane_private as LP;
    let (var, lo, bound_var, inclusive, st) = match seq_counted_header(init, cond, step, types) {
        Ok(h) => h,
        Err(r) => return rveto(scope, path, "?", r),
    };
    if lo < 0 || bound_var == var {
        return rveto(scope, path, &var, "seq-bounds");
    }
    // Lane-nest classification (privatization proof).
    let chain = match LP::classify_seq_chain(body, &var, &[&bound_var]) {
        Some(c) => c,
        None => return rveto(scope, path, &var, "non-seq-body"),
    };
    // Acc init (same rule as plain reductions: ≤1 literal init outside).
    let acc_init = match acc_init_rule(prog, &chain.acc, body) {
        Some(AccInit::Lit(n)) => n,
        Some(AccInit::Unset) => 0,
        None => return rveto(scope, path, &var, "seq-acc-init"),
    };
    // Whole-program scope: privates mentioned ONLY inside the nest
    // (headers scanned too — they run on host, lane state must not).
    if !seq_scope_ok(prog, loop_idx, init, cond, step, &chain) {
        return rveto(scope, path, &var, "seq-scope");
    }
    // Lower.
    let mut cx = BodyCx { var: &var, types, externs: BTreeSet::new() };
    let lanes: BTreeSet<String> = chain.private.iter().cloned().collect();
    let mut prelude: Vec<debashl::cuda_backend::CuSeqStmt> = Vec::new();
    for (name, rhs) in &chain.inits {
        let v = match rhs {
            LP::InitRhs::Num(n) => CuArith::Num(*n),
            LP::InitRhs::Arith(a) => match lower_arith(a, &mut cx, Some(&lanes)) {
                Ok(v) => v,
                Err(r) => return rveto(scope, path, &var, r),
            },
        };
        prelude.push(debashl::cuda_backend::CuSeqStmt::Assign { var: name.clone(), expr: v });
    }
    let IrStmt::While { cond: wcond, body: wbody } = &body[chain.while_idx] else {
        return rveto(scope, path, &var, "seq-chain-shape");
    };
    let wtest = match lower_seq_test(wcond, &mut cx, &lanes) {
        Some(t) => t,
        None => return rveto(scope, path, &var, "seq-chain-test"),
    };
    let mut wblock = Vec::new();
    for s in wbody.iter() {
        match lower_seq_stmt(s, &mut cx, &lanes) {
            Some(q) => wblock.push(q),
            None => return rveto(scope, path, &var, "seq-chain-stmt"),
        }
    }
    // Guard-nonneg peephole: a `Lane(v) > positive` while-test proves
    // v nonneg for the whole body, so pow2 mods on v render as `&`
    // (unsigned-speed, signed-sound — nonneg makes them identical).
    for v in guard_nonneg_vars(&wtest) {
        for q in wblock.iter_mut() {
            and_nonneg_stmt(q, &v);
        }
    }
    prelude.push(debashl::cuda_backend::CuSeqStmt::While { test: wtest, body: wblock });
    // Externs follow the reduce convention (bound EXCLUDED — the
    // vehicle binds it from N/trips; the kernel never reads it).
    // Privates and counter never externs (lane/counter regs).
    let id = scope.next_id().replace("cu_loop_", "cu_seq_");
    let mut externs: Vec<String> = cx.externs.into_iter().collect();
    externs.sort();
    let spec = CuReduceSpec {
        id: id.clone(),
        var: var.clone(),
        lo,
        bound_var: bound_var.clone(),
        bound_lt: !inclusive,
        step: st,
        threads: 256,
        block_items: 1024,
        op: CuReduceOp::Add,
        value: CuArith::Lane(chain.acc_var.clone()),
        acc_init,
        externs,
        arrays: vec![],
        mask_thresh: None,
        mask_fast: false,
        seq_prelude: prelude,
    };
    CuReduceVerdict {
        id,
        path: path.to_string(),
        var: var.clone(),
        lo,
        bound_var: bound_var.clone(),
        bound_lt: !inclusive,
        step: st,
        verdict: CuVerdictKind::Candidate,
        spec: Some(spec),
    }
}

/// Lane var proven even by an `(X%2)==0` equality test (either side
/// order). Powers beyond 2 need nonneg too — restricted to 2 (exact
/// for all evens, see Shr docs).
fn even_guard_var(t: &debashl::cuda_backend::CuTest) -> Option<String> {
    use debashl::cuda_backend::{CuArith as C, CuTest as T};
    let T::Cmp { op, lhs, rhs } = t else {
        return None;
    };
    if op != "==" {
        return None;
    }
    let lane_mod = |a: &C, b: &C| -> Option<String> {
        match (a, b) {
            (C::Mod(x, y), C::Num(0)) | (C::Num(0), C::Mod(x, y)) => match (x.as_ref(), y.as_ref()) {
                (C::Lane(v), C::Num(2)) => Some(v.clone()),
                _ => None,
            },
            _ => None,
        }
    };
    lane_mod(lhs, rhs)
}

/// Rewrite `Lane(v)/2` as `Shr(Lane(v),1)` under an even-guard (pure
/// recursion — every CuArith child is effect-free).
fn shr_even_expr(e: &mut debashl::cuda_backend::CuArith, var: &str) {
    use debashl::cuda_backend::CuArith as C;
    match e {
        C::Div(a, b)
            if matches!(a.as_ref(), C::Lane(v) if v == var)
                && matches!(b.as_ref(), C::Num(2)) =>
        {
            *e = C::Shr(Box::new(C::Lane(var.to_string())), 1);
        }
        C::Add(a, b)
        | C::Sub(a, b)
        | C::Mul(a, b)
        | C::Div(a, b)
        | C::Mod(a, b)
        | C::Min(a, b)
        | C::Max(a, b)
        | C::And(a, b) => {
            shr_even_expr(a, var);
            shr_even_expr(b, var);
        }
        C::Shr(a, _) => shr_even_expr(a, var),
        C::ArrRead { index, .. } => shr_even_expr(index, var),
        _ => {}
    }
}

fn shr_even_stmt(s: &mut debashl::cuda_backend::CuSeqStmt, var: &str) {
    use debashl::cuda_backend::CuSeqStmt as Q;
    match s {
        Q::Assign { expr, .. } => shr_even_expr(expr, var),
        Q::If { then, else_, .. } => {
            for x in then.iter_mut().chain(else_.iter_mut()) {
                shr_even_stmt(x, var);
            }
        }
        Q::While { body, .. } => {
            for x in body {
                shr_even_stmt(x, var);
            }
        }
    }
}

/// Lane vars proven nonneg by a while-test (`Lane(v) > n>=0` or
/// `>= n>=1`, either side order — guard dominates the body).
fn guard_nonneg_vars(t: &debashl::cuda_backend::CuTest) -> Vec<String> {
    use debashl::cuda_backend::{CuArith as C, CuTest as T};
    let T::Cmp { op, lhs, rhs } = t else {
        return vec![];
    };
    let lane_ge = |a: &C, b: &C| -> Option<String> {
        match (a, b) {
            (C::Lane(v), C::Num(n)) if (op == ">" && *n >= 0) || (op == ">=" && *n >= 1) => {
                Some(v.clone())
            }
            (C::Num(n), C::Lane(v)) if (op == "<" && *n >= 0) || (op == "<=" && *n >= 1) => {
                Some(v.clone())
            }
            _ => None,
        }
    };
    lane_ge(lhs, rhs).into_iter().collect()
}

/// Rewrite `Mod(Lane(v), pow2)` as `And(Lane(v), mask)` under a
/// nonneg-guard (identical for nonneg dividends; pow2-only — the mask
/// identity fails otherwise).
fn and_nonneg_expr(e: &mut debashl::cuda_backend::CuArith, var: &str) {
    use debashl::cuda_backend::CuArith as C;
    use debashl::shir_passes::maskable as M;
    match e {
        C::Mod(a, b) => {
            let hit = matches!(a.as_ref(), C::Lane(v) if v == var)
                && matches!(b.as_ref(), C::Num(d) if M::is_pow2_lit(*d));
            if hit {
                let d = match b.as_ref() {
                    C::Num(d) => *d,
                    _ => 0,
                };
                *e = C::And(
                    Box::new(C::Lane(var.to_string())),
                    Box::new(C::Num(d - 1)),
                );
            } else {
                and_nonneg_expr(a, var);
                and_nonneg_expr(b, var);
            }
        }
        C::Add(a, b)
        | C::Sub(a, b)
        | C::Mul(a, b)
        | C::Div(a, b)
        | C::Min(a, b)
        | C::Max(a, b)
        | C::And(a, b) => {
            and_nonneg_expr(a, var);
            and_nonneg_expr(b, var);
        }
        C::Shr(a, _) => and_nonneg_expr(a, var),
        C::ArrRead { index, .. } => and_nonneg_expr(index, var),
        _ => {}
    }
}

fn and_nonneg_stmt(s: &mut debashl::cuda_backend::CuSeqStmt, var: &str) {
    use debashl::cuda_backend::CuSeqStmt as Q;
    match s {
        Q::Assign { expr, .. } => and_nonneg_expr(expr, var),
        Q::If { test, then, else_ } => {
            and_nonneg_test(test, var);
            for x in then.iter_mut().chain(else_.iter_mut()) {
                and_nonneg_stmt(x, var);
            }
        }
        Q::While { test, body } => {
            and_nonneg_test(test, var);
            for x in body {
                and_nonneg_stmt(x, var);
            }
        }
    }
}

fn and_nonneg_test(t: &mut debashl::cuda_backend::CuTest, var: &str) {
    use debashl::cuda_backend::CuTest as T;
    let T::Cmp { lhs, rhs, .. } = t else {
        return;
    };
    and_nonneg_expr(lhs, var);
    and_nonneg_expr(rhs, var);
}

/// Lower one chain statement (Assign/If, no nesting beyond flat ifs —
/// the analysis guarantees the shape; anything else is an internal
/// refusal, never silent).
fn lower_seq_stmt(
    s: &IrStmt,
    cx: &mut BodyCx,
    lanes: &BTreeSet<String>,
) -> Option<debashl::cuda_backend::CuSeqStmt> {
    use debashl::cuda_backend::CuSeqStmt as Q;
    match s {
        IrStmt::Assign { targets, expr, .. } => {
            let [t] = targets.as_slice() else {
                return None;
            };
            let IrExpr::Arith(a) = expr else {
                return None;
            };
            let v = lower_arith(a, cx, Some(lanes)).ok()?;
            Some(Q::Assign { var: t.var.clone(), expr: v })
        }
        IrStmt::If { cond, then, elsifs, else_, .. } => {
            let test = lower_seq_test(cond, cx, lanes)?;
            // Even-guard peephole: `(v%2)==0` proves v even on the then
            // path, so `v/2` renders as `shr` (exact for all even s64 —
            // truncation and floor agree on evens; no nonneg needed).
            let even = even_guard_var(&test);
            let mut tq = Vec::new();
            for x in then.iter() {
                let mut q = lower_seq_stmt_flat(x, cx, lanes)?;
                if let Some(v) = &even {
                    shr_even_stmt(&mut q, v);
                }
                tq.push(q);
            }
            // (elsifs audited flat by the analysis; lower each arm —
            // V2 could nest Q::If, v1 chains on then/else shape… actually
            // just lower elsifs as nested Ifs (uniform, no extra code).
            let mut else_q: Vec<Q> = Vec::new();
            for x in else_.iter() {
                else_q.push(lower_seq_stmt_flat(x, cx, lanes)?);
            }
            // Fold elsifs inside-out into nested Ifs.
            for (c, b) in elsifs.iter().rev() {
                let t = lower_seq_test(c, cx, lanes)?;
                let mut tq2 = Vec::new();
                for x in b.iter() {
                    tq2.push(lower_seq_stmt_flat(x, cx, lanes)?);
                }
                else_q = vec![Q::If { test: t, then: tq2, else_: else_q }];
            }
            Some(Q::If { test, then: tq, else_: else_q })
        }
        _ => None,
    }
}

/// Flat chain assign (no nested ifs — analysis pins flat arms).
fn lower_seq_stmt_flat(
    s: &IrStmt,
    cx: &mut BodyCx,
    lanes: &BTreeSet<String>,
) -> Option<debashl::cuda_backend::CuSeqStmt> {
    use debashl::cuda_backend::CuSeqStmt as Q;
    let IrStmt::Assign { targets, expr, .. } = s else {
        return None;
    };
    let [t] = targets.as_slice() else {
        return None;
    };
    let IrExpr::Arith(a) = expr else {
        return None;
    };
    let v = lower_arith(a, cx, Some(lanes)).ok()?;
    Some(Q::Assign { var: t.var.clone(), expr: v })
}

/// Lower a chain test: let-text comparison or Arith comparison, sides
/// restricted to literals/bare vars/single-binop(var,op,lit).
fn lower_seq_test(
    cond: &IrExpr,
    cx: &mut BodyCx,
    lanes: &BTreeSet<String>,
) -> Option<debashl::cuda_backend::CuTest> {
    use debashl::cuda_backend::CuTest as T;
    // Collect (op, lhs-text, rhs-text) or (op, lhs-arith, rhs-arith).
    enum Side {
        Text(String),
        Arith(ArithAst),
    }
    let (op, l, r): (String, Side, Side) = match cond {
        IrExpr::Call { func, args } if func == "builtin" || func == "exec" => {
            let is_let = matches!(args.first(), Some(IrExpr::Str(n, _)) if n == "let");
            if !is_let {
                return None;
            }
            let mut texts = Vec::new();
            for a in args.iter().skip(1) {
                match a {
                    IrExpr::Str(s, _) => texts.push(s.clone()),
                    IrExpr::Array(els) => {
                        for e in els {
                            if let IrExpr::Str(s, _) = e {
                                texts.push(s.clone());
                            }
                        }
                    }
                    _ => {}
                }
            }
            if texts.len() != 1 {
                return None;
            }
            let (o, a, b) = split_test_text(&texts[0])?;
            (o, Side::Text(a), Side::Text(b))
        }
        IrExpr::Arith(a) => match a.as_ref() {
            ArithAst::Bin { op, lhs, rhs }
                if matches!(op.as_str(), "<" | ">" | "<=" | ">=" | "==" | "!=") =>
            {
                (op.clone(), Side::Arith((**lhs).clone()), Side::Arith((**rhs).clone()))
            }
            _ => return None,
        },
        _ => return None,
    };
    if !matches!(op.as_str(), "<" | ">" | "<=" | ">=" | "==" | "!=") {
        return None;
    }
    let lower_side = |s: Side, cx: &mut BodyCx| -> Option<debashl::cuda_backend::CuArith> {
        match s {
            Side::Arith(a) => lower_arith(&a, cx, Some(lanes)).ok(),
            Side::Text(t) => {
                let a = parse_test_side(&t)?;
                lower_arith(&a, cx, Some(lanes)).ok()
            }
        }
    };
    let (l, r) = (lower_side(l, cx)?, lower_side(r, cx)?);
    // (lower_arith enforces counter/lane/extern/literal shapes; Lane
    // reads are domination-proven by the analysis.)
    Some(T::Cmp { op, lhs: l, rhs: r })
}

/// Split `A < B` text at the top-level comparison (longest ops first).
fn split_test_text(t: &str) -> Option<(String, String, String)> {
    for op in ["<=", ">=", "==", "!=", "<", ">"] {
        if let Some((l, r)) = t.split_once(op) {
            return Some((op.to_string(), l.to_string(), r.to_string()));
        }
    }
    None
}

/// Restricted test-side parser: numeric literal (optional `$`), bare
/// var, or a single binop over recursively-parsed sides. Anything else
/// refuses (miss, safe). Width discipline is downstream's job
/// (lower_arith vetoes unproven vars as externs).
fn parse_test_side(t: &str) -> Option<ArithAst> {
    let s: String = t.chars().filter(|c| !c.is_whitespace()).collect();
    let s = s.strip_prefix('$').unwrap_or(&s);
    if let Ok(n) = s.parse::<i64>() {
        return Some(ArithAst::Num(n));
    }
    if is_seq_var(s) {
        return Some(ArithAst::Var(s.to_string()));
    }
    // Left-assoc: split on the LAST occurrence (so `a-b-c` is
    // `(a-b)-c`, not `a-(b-c)`). Both parts strictly shorter, so this
    // terminates. (Negative literals never reach here — the lit parse
    // above accepts a leading `-`.)
    for op in ["*", "/", "%", "+", "-"] {
        let (l, r) = match s.rfind(op) {
            Some(pos) if pos > 0 && pos + 1 < s.len() => s.split_at(pos),
            _ => continue,
        };
        let r = &r[1..];
        let (la, ra) = (parse_test_side(l)?, parse_test_side(r)?);
        return Some(ArithAst::Bin {
            op: op.to_string(),
            lhs: Box::new(la),
            rhs: Box::new(ra),
        });
    }
    None
}

/// Plain scalar var name for test sides.
fn is_seq_var(s: &str) -> bool {
    let mut cs = s.chars();
    match cs.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    cs.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

/// Whole-program scope for seq privates, on the shared exhaustive
/// scanners (`fuse_fill_consume`): every private is mentioned NOWHERE
/// except the nest body — headers included (they evaluate on host).
/// The acc is exempt (its init discipline is proven by acc_init_rule;
/// reads reproduce on host via the reduced checksum — the standard
/// reduce contract). Top-level nests only (see walk_seq).
fn seq_scope_ok(
    prog: &IrProgram,
    loop_idx: usize,
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    chain: &debashl::shir_passes::lane_private::SeqChain,
) -> bool {
    use debashl::transforms::fuse_fill_consume as Fuse;
    for p in &chain.private {
        if Fuse::stmts_have_arr(init, p)
            || Fuse::expr_has_arr(cond, p)
            || Fuse::stmts_have_arr(step, p)
        {
            return false;
        }
        for (i, s) in prog.stmts.iter().enumerate() {
            if i == loop_idx {
                continue;
            }
            if Fuse::stmt_has_arr(s, p) {
                return false;
            }
        }
        for sub in &prog.subs {
            if Fuse::stmts_have_arr(&sub.body, p) {
                return false;
            }
        }
    }
    true
}

/// Lower one chain statement (Assign/If, no nesting beyond flat ifs —
/// the analysis guarantees the shape; anything else is an internal
/// refusal, never silent).
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
    // Maskable pow2-mods (None = render signed; miss, safe).
    let mask_thresh = cu_mask_plan_reduce_side(
        body, step, &var, lo, &bound_var, !inclusive, &acc, acc_init, &op, x_ast,
    );
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
        mask_thresh,
        mask_fast: false,
        seq_prelude: vec![],
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
    fn sumred_gets_mask_threshold() {
        // `(s+(i*i)%2^32)%2^32` with s=0: maskable, threshold 3037000500.
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$(((s + (i*i)%4294967296) % 4294967296)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
        let spec = vs[0].spec.as_ref().expect("spec");
        assert_eq!(spec.mask_thresh, Some(3037000500), "threshold");
        assert!(!spec.mask_fast, "flag unset by candidacy");
    }

    #[test]
    fn nonpow2_outer_stays_signed() {
        // `(s+(i*i)%251)%251`: outer non-pow2 never masks, but the spec
        // still classifies (inner is literal-bound... here dynamic, so
        // inner unversionable too → no flag, but candidate stands).
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$(((s + (i*i)%251) % 251)); done\n");
        let vs = analyze_reduce(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Candidate), "{}", vs[0]);
        let spec = vs[0].spec.as_ref().expect("spec");
        assert_eq!(spec.mask_thresh, None, "no maskable pow2 site");
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

/// Convert lowered CuArith back to ArithAst for shared threshold math,
/// substituting the loop counter for LoopVar. Lossy (ExtVar/Min/Max/
/// And/ArrRead have no counter-pure form) → None, which conservatively
/// kills masking for that site (stays signed). Accumulator mentions are
/// split out by callers before calling (see cu_mask_plan).
fn cu_to_arith(e: &debashl::cuda_backend::CuArith, counter: &str) -> Option<ArithAst> {
    use debashl::cuda_backend::CuArith as C;
    match e {
        C::Num(n) => Some(ArithAst::Num(*n)),
        C::LoopVar => Some(ArithAst::Var(counter.to_string())),
        C::Add(a, b) => Some(ArithAst::Bin {
            op: "+".to_string(),
            lhs: Box::new(cu_to_arith(a, counter)?),
            rhs: Box::new(cu_to_arith(b, counter)?),
        }),
        C::Sub(a, b) => Some(ArithAst::Bin {
            op: "-".to_string(),
            lhs: Box::new(cu_to_arith(a, counter)?),
            rhs: Box::new(cu_to_arith(b, counter)?),
        }),
        C::Mul(a, b) => Some(ArithAst::Bin {
            op: "*".to_string(),
            lhs: Box::new(cu_to_arith(a, counter)?),
            rhs: Box::new(cu_to_arith(b, counter)?),
        }),
        C::Div(a, b) => Some(ArithAst::Bin {
            op: "/".to_string(),
            lhs: Box::new(cu_to_arith(a, counter)?),
            rhs: Box::new(cu_to_arith(b, counter)?),
        }),
        C::Mod(a, b) => Some(ArithAst::Bin {
            op: "%".to_string(),
            lhs: Box::new(cu_to_arith(a, counter)?),
            rhs: Box::new(cu_to_arith(b, counter)?),
        }),
        _ => None,
    }
}

/// Written names under stmts (conservative None on unknown effects).
/// Seed of a shared writes analysis (duplicated minimally here to avoid
/// cross-crate churn; unify when it grows — see BASH-VULKAN §12).
fn cu_written(stmts: &[IrStmt]) -> Option<BTreeSet<String>> {
    fn wexpr(e: &IrExpr, out: &mut BTreeSet<String>) -> bool {
        match e {
            IrExpr::Arith(a) => warith(a, out),
            IrExpr::Array(items) => items.iter().all(|x| wexpr(x, out)),
            IrExpr::Call { func, args } => {
                match func.as_str() {
                    "test" | "arith" | "getVar" | "param" | "echo" | "true" | "false" | ":" => {
                        args.iter().all(|a| wexpr(a, out))
                    }
                    _ => false,
                }
            }
            IrExpr::BinOp { lhs, rhs, .. } => wexpr(lhs, out) && wexpr(rhs, out),
            IrExpr::Ternary { cond, then, else_ } => {
                wexpr(cond, out) && wexpr(then, out) && wexpr(else_, out)
            }
            IrExpr::DefinedOr { expr, default } => wexpr(expr, out) && wexpr(default, out),
            IrExpr::Interpolate(parts) => parts.iter().all(|p| match p {
                debashl::ir::InterpPart::Expr(x) => wexpr(x, out),
                _ => true,
            }),
            IrExpr::Capture { .. }
            | IrExpr::MethodCall { .. }
            | IrExpr::RawExpr(_) => false,
            IrExpr::Index { key, .. } => wexpr(key, out),
            IrExpr::Splice(x) => wexpr(x, out),
            IrExpr::Lambda { .. }
            | IrExpr::Arrow(_)
            | IrExpr::ArrayComp { .. }
            | IrExpr::Ext(_) => false,
            _ => true,
        }
    }
    fn warith(a: &ArithAst, out: &mut BTreeSet<String>) -> bool {
        match a {
            ArithAst::Assign { var, rhs, .. } => {
                out.insert(var.clone());
                warith(rhs, out)
            }
            ArithAst::IncDec { var, .. } => {
                out.insert(var.clone());
                true
            }
            ArithAst::Bin { lhs, rhs, .. } => warith(lhs, out) && warith(rhs, out),
            ArithAst::Un { arg, .. } => warith(arg, out),
            ArithAst::Cond { test, then, else_ } => {
                warith(test, out) && warith(then, out) && warith(else_, out)
            }
            ArithAst::Cast { arg, .. } => warith(arg, out),
            ArithAst::Index { key, .. } => warith(key, out),
            _ => true,
        }
    }
    fn wstmt(s: &IrStmt, out: &mut BTreeSet<String>) -> bool {
        match s {
            IrStmt::Assign { targets, expr, .. } => {
                for t in targets {
                    let base = t.var.split('[').next().unwrap_or(&t.var);
                    if !base.is_empty() {
                        out.insert(base.to_string());
                    }
                    for ix in &t.indices {
                        if !wexpr(ix, out) {
                            return false;
                        }
                    }
                }
                wexpr(expr, out)
            }
            IrStmt::Declare { vars, init, .. } => {
                for d in vars {
                    out.insert(d.name.clone());
                }
                init.as_ref().is_none_or(|e| wexpr(e, out))
            }
            IrStmt::DeclareArray { var, elements, .. } => {
                out.insert(var.clone());
                elements.iter().all(|e| wexpr(e, out))
            }
            IrStmt::Expr(e)
            | IrStmt::Output { value: e, .. }
            | IrStmt::WriteFile { content: e, .. }
            | IrStmt::Return(Some(e))
            | IrStmt::Exit(Some(e))
            | IrStmt::Die { expr: e, .. }
            | IrStmt::Warn { expr: e, .. }
            | IrStmt::SetChildError(e) => wexpr(e, out),
            IrStmt::WriteFile { path, .. } => wexpr(path, out),
            IrStmt::If { cond, then, elsifs, else_, .. } => {
                wexpr(cond, out)
                    && then.iter().all(|x| wstmt(x, out))
                    && elsifs.iter().all(|(c, b)| wexpr(c, out) && b.iter().all(|x| wstmt(x, out)))
                    && else_.iter().all(|x| wstmt(x, out))
            }
            IrStmt::While { cond, body } | IrStmt::DoWhile { body, cond, .. } => {
                wexpr(cond, out) && body.iter().all(|x| wstmt(x, out))
            }
            IrStmt::For { var, iter, body } => {
                out.insert(var.clone());
                wexpr(iter, out) && body.iter().all(|x| wstmt(x, out))
            }
            IrStmt::ForInit { init, cond, step, body } => {
                init.iter().all(|x| wstmt(x, out))
                    && wexpr(cond, out)
                    && step.iter().all(|x| wstmt(x, out))
                    && body.iter().all(|x| wstmt(x, out))
            }
            IrStmt::Block(b) => b.iter().all(|x| wstmt(x, out)),
            IrStmt::Redirect { inner, redirects } => {
                redirects.iter().all(|r| wexpr(&r.target, out))
                    && inner.iter().all(|x| wstmt(x, out))
            }
            IrStmt::Case { discriminant, clauses, .. } => {
                wexpr(discriminant, out)
                    && clauses.iter().all(|c| c.body.iter().all(|x| wstmt(x, out)))
            }
            IrStmt::Try { body, excepts, else_body, finally_body } => {
                body.iter().all(|x| wstmt(x, out))
                    && excepts.iter().all(|e| {
                        e.match_expr.as_ref().is_none_or(|m| wexpr(m, out))
                            && e.body.iter().all(|x| wstmt(x, out))
                    })
                    && else_body.iter().all(|x| wstmt(x, out))
                    && finally_body.iter().all(|x| wstmt(x, out))
            }
            IrStmt::Function { .. } => false,
            IrStmt::Select { .. }
            | IrStmt::Pipeline { .. }
            | IrStmt::Subshell(_)
            | IrStmt::Background(_) => false,
            _ => true,
        }
    }
    let mut out = BTreeSet::new();
    if stmts.iter().all(|s| wstmt(s, &mut out)) {
        Some(out)
    } else {
        None
    }
}

/// Mask threshold for a MAP loop: min over pow2-mod sites in store
/// values (None = none unmaskable... precisely: None when no maskable
/// site or any gate fails — render signed). Gates: lo>=0, boundvar !=
/// counter, counter/boundvar written only by init/step (cu_writes
/// discipline over body+step).
/// Any Var/Ident mention of `name` in a CuArith tree.
fn mentions_var(e: &debashl::cuda_backend::CuArith, name: &str) -> bool {
    use debashl::cuda_backend::CuArith as C;
    match e {
        // LoopVar is the counter, never the accum (distinct names —
        // candidacy rejects acc==counter upstream).
        C::LoopVar | C::Num(_) => false,
        // ExtVar could alias acc textually — conservative true only on
        // exact match (over-approx miss, safe).
        C::ExtVar(n) => n == name,
        C::Add(a, b) | C::Sub(a, b) | C::Mul(a, b) | C::Div(a, b) | C::Mod(a, b) => {
            mentions_var(a, name) || mentions_var(b, name)
        }
        C::Min(a, b) | C::Max(a, b) | C::And(a, b) => {
            mentions_var(a, name) || mentions_var(b, name)
        }
        C::ArrRead { index, .. } => mentions_var(index, name),
        // Lane-local (seq prelude): exact-name match (same rule as ExtVar).
        C::Lane(n) => n == name,
        C::Shr(a, _) => mentions_var(a, name),
    }
}

fn cu_mask_plan_map(
    body: &[IrStmt],
    step: &[IrStmt],
    var: &str,
    lo: i64,
    boundvar: &str,
    lt: bool,
    stores: &[debashl::cuda_backend::CuStore],
) -> Option<i128> {
    use debashl::shir_passes::maskable as M;
    if lo < 0 || boundvar == var {
        return None;
    }
    // Discipline: body must not write counter (step's own write is
    // expected machinery, checked separately below); nothing anywhere
    // may write the bound (stale need).
    let wb = match cu_written(body) {
        Some(w) => w,
        None => return None,
    };
    if wb.contains(var) || wb.contains(boundvar) {
        return None;
    }
    let ws = match cu_written(step) {
        Some(w) => w,
        None => return None,
    };
    if ws.contains(boundvar) {
        return None;
    }
    let mut thresh: Vec<i128> = Vec::new();
    for st in stores {
        if !collect_pow2(&st.value, var, lt, &mut thresh) {
            return None;
        }
    }
    if thresh.is_empty() {
        return None;
    }
    let finite: Vec<i128> = thresh.iter().copied().filter(|t| *t < M::VER_INF).collect();
    if !finite.is_empty() && finite.iter().min().copied().unwrap_or(0) < 16 {
        return None;
    }
    Some(thresh.into_iter().min().unwrap_or(M::VER_INF))
}

/// Mask threshold for a REDUCE loop's accumulator site `(acc+X)%m`:
/// X acc-free with threshold T(X) plus acc entry literal in [0,m).
/// Other pow2 sites inside X join via the uniform walk. Non-pow2 outer
/// moduli stay rem (never kill the flag — only pow2 sites participate).
fn ast_pow2_sites(
    ast: &ArithAst,
    counter: &str,
    lt: bool,
    out: &mut Vec<i128>,
) -> bool {
    use debashl::shir_passes::maskable as M;
    match ast {
        ArithAst::Bin { op, lhs, rhs } if op == "%" || op == "/" => {
            if let ArithAst::Num(d) = rhs.as_ref() {
                if M::is_pow2_lit(*d) {
                    match M::mask_threshold(lhs, *d, counter, lt, true) {
                        Some(t) => out.push(t),
                        None => return false,
                    }
                }
            }
            ast_pow2_sites(lhs, counter, lt, out) && ast_pow2_sites(rhs, counter, lt, out)
        }
        ArithAst::Bin { lhs, rhs, .. } => {
            ast_pow2_sites(lhs, counter, lt, out) && ast_pow2_sites(rhs, counter, lt, out)
        }
        ArithAst::Un { arg, .. } => ast_pow2_sites(arg, counter, lt, out),
        ArithAst::Cond { test, then, else_ } => {
            ast_pow2_sites(test, counter, lt, out)
                && ast_pow2_sites(then, counter, lt, out)
                && ast_pow2_sites(else_, counter, lt, out)
        }
        ArithAst::Assign { rhs, .. } => ast_pow2_sites(rhs, counter, lt, out),
        ArithAst::Cast { arg, .. } => ast_pow2_sites(arg, counter, lt, out),
        ArithAst::Index { key, .. } => ast_pow2_sites(key, counter, lt, out),
        _ => true,
    }
}

/// Any Var/Ident mention of `name` in ArithAst (for acc-free checks).
fn ast_mentions(a: &ArithAst, name: &str) -> bool {
    match a {
        ArithAst::Var(v) | ArithAst::Ident(v) => v == name,
        ArithAst::Bin { lhs, rhs, .. } => ast_mentions(lhs, name) || ast_mentions(rhs, name),
        ArithAst::Un { arg, .. } => ast_mentions(arg, name),
        ArithAst::Cond { test, then, else_ } => {
            ast_mentions(test, name) || ast_mentions(then, name) || ast_mentions(else_, name)
        }
        ArithAst::Assign { var, rhs, .. } => var == name || ast_mentions(rhs, name),
        ArithAst::Cast { arg, .. } => ast_mentions(arg, name),
        ArithAst::Index { var, key } => var == name || ast_mentions(key, name),
        _ => false,
    }
}

/// Mask threshold for a REDUCE loop. Two cases:
/// - outer accum mod with POW2 modulus: the outer site itself masks
///   (needs X threshold + acc-init gate), plus any inner pow2 sites.
/// - otherwise (Add/Mul, non-pow2 outer): inner pow2 sites only; the
///   outer stays rem/div regardless (never kills the flag).
/// All-or-nothing per participating site; None = render signed.
#[allow(clippy::too_many_arguments)]
fn cu_mask_plan_reduce_side(
    body: &[IrStmt],
    step: &[IrStmt],
    var: &str,
    lo: i64,
    boundvar: &str,
    lt: bool,
    acc: &str,
    acc_init: i64,
    op: &debashl::cuda_backend::CuReduceOp,
    x_ast: &ArithAst,
) -> Option<i128> {
    use debashl::cuda_backend::CuReduceOp as Op;
    use debashl::shir_passes::maskable as M;
    if lo < 0 || boundvar == var {
        return None;
    }
    let wb = match cu_written(body) {
        Some(w) => w,
        None => return None,
    };
    if wb.contains(var) || wb.contains(boundvar) {
        return None;
    }
    let ws = match cu_written(step) {
        Some(w) => w,
        None => return None,
    };
    if ws.contains(boundvar) {
        return None;
    }
    let mut thresh: Vec<i128> = Vec::new();
    let mut will_mask_outer = false;
    if let Op::ModAdd { modulus } | Op::MaskAdd { mask: modulus } = op {
        if !M::is_pow2_lit(*modulus) {
            // Non-pow2 outer stays rem — X needs no threshold for the
            // outer's sake (inners below still join).
        } else {
            // Pow2 outer masks iff X verified + acc entry in range.
            if *modulus < 1
                || !(0 <= acc_init && (acc_init as u64) < (*modulus as u64))
            {
                return None;
            }
            if ast_mentions(x_ast, acc) {
                return None;
            }
            match M::mask_threshold(x_ast, *modulus, var, lt, true) {
                Some(t) => {
                    thresh.push(t);
                    will_mask_outer = true;
                }
                None => return None,
            }
        }
    }
    // Inner pow2 sites anywhere in X join uniformly (each must verify).
    let before = thresh.len();
    if !ast_pow2_sites(x_ast, var, lt, &mut thresh) {
        return None;
    }
    let inner_pow2_found = thresh.len() > before;
    // Usefulness: at least one site must actually mask.
    if !will_mask_outer && !inner_pow2_found {
        return None;
    }
    // (Empty means nothing versionable: no outer coverage and no
    // inner pow2 sites — masking would change nothing.)
    if thresh.is_empty() {
        return None;
    }
    let finite: Vec<i128> = thresh.iter().copied().filter(|t| *t < M::VER_INF).collect();
    if !finite.is_empty() && finite.iter().min().copied().unwrap_or(0) < 16 {
        return None;
    }
    Some(thresh.into_iter().min().unwrap_or(M::VER_INF))
}

/// Walk one CuArith value for pow2-mod sites, joining thresholds.
/// Returns false on the first unmaskable site (kills the flag).
fn collect_pow2(
    e: &debashl::cuda_backend::CuArith,
    counter: &str,
    lt: bool,
    out: &mut Vec<i128>,
) -> bool {
    use debashl::cuda_backend::CuArith as C;
    use debashl::shir_passes::maskable as M;
    match e {
        C::Mod(a, b) | C::Div(a, b) => {
            if let C::Num(d) = b.as_ref() {
                if M::is_pow2_lit(*d) {
                    match cu_to_arith(a, counter) {
                        Some(ast) => match M::mask_threshold(&ast, *d, counter, lt, true) {
                            Some(t) => out.push(t),
                            None => return false,
                        },
                        None => return false,
                    }
                }
            }
            collect_pow2(a, counter, lt, out) && collect_pow2(b, counter, lt, out)
        }
        C::Add(a, b) | C::Sub(a, b) | C::Mul(a, b) => {
            collect_pow2(a, counter, lt, out) && collect_pow2(b, counter, lt, out)
        }
        C::Min(a, b) | C::Max(a, b) | C::And(a, b) => {
            collect_pow2(a, counter, lt, out) && collect_pow2(b, counter, lt, out)
        }
        C::ArrRead { index, .. } => collect_pow2(index, counter, lt, out),
        _ => true,
    }
}

#[cfg(test)]
mod seq_tests {
    use super::*;

    fn prog_of(src: &str) -> IrProgram {
        let a1 = otranspilerl::shell_to_shir(src);
        debashl::shir_json_in::shir_json_to_ir(&a1).expect("ingress")
    }

    const COLLATZ: &str = "#!/bin/bash\nn=$1\ntotal=0\nfor ((k=0;k<n;k++)); do v=$(( (k*37+3) % 251 )); s=0; while ((v > 1)); do if ((v % 2 == 0)); then v=$((v/2)); else v=$((3*v+1)); fi; s=$((s+1)); done; total=$((total+s)); done\n";

    #[test]
    fn collatz_is_seq_candidate() {
        let prog = prog_of(COLLATZ);
        let vs = analyze_seq(&prog);
        assert_eq!(vs.len(), 1, "one loop verdict: {vs:?}");
        let v = &vs[0];
        assert!(matches!(v.verdict, CuVerdictKind::Candidate), "expected candidate: {v}");
        assert!(v.id.starts_with("cu_seq_"), "seq id: {}", v.id);
        let spec = v.spec.as_ref().expect("spec");
        assert!(spec.arrays.is_empty());
        assert!(spec.externs.is_empty(), "bound excluded: {:?}", spec.externs);
        assert!(!spec.seq_prelude.is_empty(), "prelude present");
        assert!(matches!(
            spec.value,
            debashl::cuda_backend::CuArith::Lane(_)
        ));
    }

    #[test]
    fn plain_map_is_not_seq() {
        // A fill loop has no chain/tail (classify fails, never panics).
        let prog = prog_of("#!/bin/bash\nn=$1\nfor ((i=0;i<n;i++)); do a[$i]=$((i*i)); done\n");
        let vs = analyze_seq(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Veto { .. }), "map must veto: {}", vs[0]);
    }

    #[test]
    fn plain_sum_is_not_seq() {
        // A single-accumulate reduce has no chain either.
        let prog = prog_of("#!/bin/bash\nn=$1\ns=0\nfor ((i=0;i<n;i++)); do s=$((s+i)); done\n");
        let vs = analyze_seq(&prog);
        assert_eq!(vs.len(), 1);
        assert!(matches!(vs[0].verdict, CuVerdictKind::Veto { .. }), "plain sum must veto: {}", vs[0]);
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
