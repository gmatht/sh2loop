//! M2 GPU candidacy (docs/BASH-O4.md §4.3).
//!
//! Per-loop verdicts over the typed `IrProgram`: a loop is a candidate
//! iff (1) counted shape, (2) pure body, (3) proven widths, (4) affine
//! memory — profitability (5) is enforced at dispatch, not here. First
//! failure vetoes with a logged reason (`--check` prints it).
//!
//! v1 scope (documented): only independent affine array stores of i64
//! `+ - *` arithmetic lower to an emittable `VkLoopSpec`. Scalar
//! accumulates need a parallel reduction (M5) → veto `scalar-carry`.

use debashl::ir::{ArithAst, IrExpr, IrProgram, IrStmt, IrType};
use debashl::vulkan_backend::{VkArith, VkLoopSpec, VkStore};
use std::collections::{BTreeMap, BTreeSet};

/// A per-loop verdict. `Display` is the `--check` line format.
#[derive(Debug, Clone, PartialEq)]
pub struct LoopVerdict {
    pub id: String,
    pub path: String,
    pub var: String,
    pub lo: i64,
    pub hi: i64,
    pub step: i64,
    pub trips: u64,
    pub verdict: Verdict,
    pub spec: Option<VkLoopSpec>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Verdict {
    Candidate,
    Veto { reason: &'static str },
}

impl LoopVerdict {
    pub fn is_candidate(&self) -> bool {
        matches!(self.verdict, Verdict::Candidate)
    }
}

impl std::fmt::Display for LoopVerdict {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self.verdict {
            Verdict::Candidate => write!(
                f,
                "candidate {} ({}: {} in {}..{} step {} trips={})",
                self.id, self.path, self.var, self.lo, self.hi, self.step, self.trips
            ),
            Verdict::Veto { reason } => write!(
                f,
                "veto {} ({}: {}): {reason}",
                self.id, self.path, self.var
            ),
        }
    }
}

/// Analyze a program; one verdict per `For`/`ForInit` loop, in order.
/// (`While`/`DoWhile` are not counted shapes — skipped silently.)
pub fn analyze(prog: &IrProgram) -> Vec<LoopVerdict> {
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
        let id = format!("sh_loop_{}_{}", self.name, self.n);
        self.n += 1;
        id
    }
}

fn is_signed_int(t: &IrType) -> bool {
    matches!(t, IrType::Int | IrType::Int32 | IrType::Int64)
}

fn walk_stmts(stmts: &[IrStmt], path: &str, scope: &mut Scope, out: &mut Vec<LoopVerdict>) {
    for (i, s) in stmts.iter().enumerate() {
        let here = format!("{path}[{i}]");
        match s {
            IrStmt::For { var, iter, body } => {
                out.push(analyze_for(scope, &here, var, iter, body));
            }
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
                // Not counted shapes — still scan inside for nested loops.
                walk_stmts(body, &here, scope, out);
            }
            IrStmt::Subshell(b) | IrStmt::Background(b) | IrStmt::Block(b) => {
                walk_stmts(b, &here, scope, out);
            }
            _ => {}
        }
    }
}

/// Extract (lo, hi, step) from a `For` iterator.
fn for_bounds(iter: &IrExpr) -> Result<(i64, i64, i64), &'static str> {
    match iter {
        IrExpr::Range { start, end } => Ok((*start, *end, 1)),
        IrExpr::Array(items) => {
            // Brace ranges arrive as Array[Str(""), Call brace(Json range), ...].
            let mut range: Option<(i64, i64, i64)> = None;
            let mut all_ints = true;
            for it in items {
                match it {
                    IrExpr::Str(s, _) if s.parse::<i64>().is_ok() => {}
                    IrExpr::Str(s, _) if s.is_empty() => {}
                    IrExpr::Call { func, args } if func == "brace" => {
                        if let Some(r) = brace_range(args) {
                            if range.replace(r).is_some() {
                                return Err("multi-range-iter");
                            }
                        } else {
                            all_ints = false;
                        }
                    }
                    _ => {
                        all_ints = false;
                    }
                }
            }
            if let Some(r) = range {
                return Ok(r);
            }
            if all_ints {
                return Err("non-range-iter");
            }
            Err("non-counted-iter")
        }
        _ => Err("non-counted-iter"),
    }
}

/// Parse the Json range payload: `[[{"range": ["lo","hi",step?,…]}]]`.
fn brace_range(args: &[IrExpr]) -> Option<(i64, i64, i64)> {
    fn find(node: &IrExpr) -> Option<(i64, i64, i64)> {
        match node {
            IrExpr::Json(v) => parse_range_value(v),
            IrExpr::Array(items) => items.iter().find_map(find),
            IrExpr::Call { args, .. } => args.iter().find_map(find),
            _ => None,
        }
    }
    args.iter().find_map(find)
}

fn parse_range_value(v: &serde_json::Value) -> Option<(i64, i64, i64)> {
    match v {
        serde_json::Value::Array(items) => items.iter().find_map(parse_range_value),
        serde_json::Value::Object(map) => {
            let r = map.get("range")?;
            let parts = r.as_array()?;
            let num = |i: usize| -> Option<i64> {
                match parts.get(i)? {
                    serde_json::Value::String(s) => s.parse().ok(),
                    serde_json::Value::Number(n) => n.as_i64(),
                    _ => None,
                }
            };
            let lo = num(0)?;
            let hi = num(1)?;
            // Third slot is the step when present (null = 1). Some
            // frontends put the step at index 2 as a string or number.
            let step = num(2).unwrap_or(1);
            if step == 0 {
                return None;
            }
            Some((lo, hi, step))
        }
        _ => None,
    }
}

/// Split `name[idx]` target text into (array, index-text).
fn split_target(var: &str) -> Option<(&str, &str)> {
    let open = var.rfind('[')?;
    if !var.ends_with(']') {
        return None;
    }
    let name = &var[..open];
    if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
        return None;
    }
    Some((name, &var[open + 1..var.len() - 1]))
}

/// Parse an affine index in the loop var: `i | $i | i±N | N±i | N*i`.
/// Returns (a, b) with idx = a*i + b.
fn affine_index(text: &str, var: &str) -> Option<(i64, i64)> {
    let t: String = text.chars().filter(|c| !c.is_whitespace()).collect();
    let t = t.strip_prefix('$').unwrap_or(&t);
    if t == var {
        return Some((1, 0));
    }
    if let Some((l, r)) = t.split_once('*') {
        let (l, r) = (l.strip_prefix('$').unwrap_or(l), r.strip_prefix('$').unwrap_or(r));
        if l == var {
            if let Ok(n) = r.parse::<i64>() {
                return Some((n, 0));
            }
        }
        if r == var {
            if let Ok(n) = l.parse::<i64>() {
                return Some((n, 0));
            }
        }
        return None;
    }
    // i±N / N+i
    for (i, op) in t.char_indices().filter(|(_, c)| *c == '+' || *c == '-') {
        if i == 0 {
            continue; // leading sign belongs to a literal, not handled
        }
        let (l, r) = t.split_at(i);
        let r = &r[1..];
        let l = l.strip_prefix('$').unwrap_or(l);
        if l == var {
            if let Ok(n) = r.parse::<i64>() {
                return Some((1, if op == '+' { n } else { -n }));
            }
        }
        if op == '+' && r.strip_prefix('$').unwrap_or(r) == var {
            if let Ok(n) = l.parse::<i64>() {
                return Some((1, n));
            }
        }
        return None;
    }
    None
}

/// A scalar read in value position: the loop counter, an Int-verdict
/// outer var (recorded as a host-provided extern), else unprovable.
fn read_scalar(cx: &mut BodyCx, var: &str, name: &str) -> Option<VkArith> {
    if name == var {
        Some(VkArith::LoopVar)
    } else if cx.types.get(name).is_some_and(is_signed_int) {
        cx.externs.insert(name.to_string());
        Some(VkArith::ExtVar(name.to_string()))
    } else {
        None
    }
}

/// First call argument as a static string (command-name sniffing).
fn first_str(args: &[IrExpr]) -> Option<&str> {
    match args.first() {
        Some(IrExpr::Str(s, _)) => Some(s),
        _ => None,
    }
}

/// Lower value arithmetic to `VkArith` (ops ⊆ {+,-,*}; reads ⊆
/// {loop var, Int-verdict vars, literals}). Records externals.
struct BodyCx<'a> {
    var: &'a str,
    types: &'a BTreeMap<String, IrType>,
    externs: BTreeSet<String>,
}

fn lower_arith(e: &ArithAst, cx: &mut BodyCx) -> Result<VkArith, &'static str> {
    match e {
        ArithAst::Num(n) => Ok(VkArith::Num(*n)),
        ArithAst::Var(name) | ArithAst::Ident(name) => {
            let v = cx.var;
            read_scalar(cx, v, name).ok_or("unproven-width")
        }
        ArithAst::Bin { op, lhs, rhs } => {
            let (l, r) = (lower_arith(lhs, cx)?, lower_arith(rhs, cx)?);
            match op.as_str() {
                "+" => Ok(VkArith::Add(Box::new(l), Box::new(r))),
                "-" => Ok(VkArith::Sub(Box::new(l), Box::new(r))),
                "*" => Ok(VkArith::Mul(Box::new(l), Box::new(r))),
                _ => Err("non-arith-op"),
            }
        }
        _ => Err("non-arith-expr"),
    }
}

/// Trips for lo + k*step `<`/`<=` hi (checked; None on overflow/empty).
fn trips(lo: i64, hi: i64, step: i64, inclusive: bool) -> Option<u64> {
    if step <= 0 {
        return None;
    }
    let span = (hi as i128 - lo as i128) + if inclusive { 1 } else { 0 };
    if span <= 0 {
        return None;
    }
    let t = (span + step as i128 - 1) / step as i128;
    u64::try_from(t).ok()
}

fn veto(
    scope: &mut Scope,
    path: &str,
    var: &str,
    reason: &'static str,
) -> LoopVerdict {
    LoopVerdict {
        id: scope.next_id(),
        path: path.to_string(),
        var: var.to_string(),
        lo: 0,
        hi: 0,
        step: 1,
        trips: 0,
        verdict: Verdict::Veto { reason },
        spec: None,
    }
}

fn analyze_for(
    scope: &mut Scope,
    path: &str,
    var: &str,
    iter: &IrExpr,
    body: &[IrStmt],
) -> LoopVerdict {
    if scope.types.get(var).is_some_and(|t| !is_signed_int(t)) {
        return veto(scope, path, var, "unproven-width");
    }
    let (lo, hi, step) = match for_bounds(iter) {
        Ok(b) => b,
        Err(r) => return veto(scope, path, var, r),
    };
    if step <= 0 {
        return veto(scope, path, var, "non-positive-step");
    }
    finish(scope, path, var, lo, hi, step, false, body)
}

fn analyze_for_init(
    scope: &mut Scope,
    path: &str,
    init: &[IrStmt],
    cond: &IrExpr,
    step: &[IrStmt],
    body: &[IrStmt],
) -> LoopVerdict {
    // init: exactly one `loopvar = Num`.
    let (var, lo) = match init {
        [IrStmt::Assign { targets, expr, .. }] => {
            let Some(t) = targets.first() else {
                return veto(scope, path, "?", "non-counted-init");
            };
            if targets.len() != 1 || t.var.contains('[') {
                return veto(scope, path, &t.var, "non-counted-init");
            }
            let n = match expr {
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
    // cond: `loopvar </<= NUM` text inside a builtin/test call.
    let (hi, inclusive) = match cond_text(cond, &var) {
        Some(v) => v,
        None => return veto(scope, path, &var, "non-counted-cond"),
    };
    // step: `loopvar++` / `loopvar += N`.
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
    finish(scope, path, &var, lo, hi, st, inclusive, body)
}

/// Find `loopvar </<= NUM` text in a condition call.
fn cond_text(cond: &IrExpr, var: &str) -> Option<(i64, bool)> {
    fn texts(e: &IrExpr, out: &mut Vec<String>) {
        match e {
            IrExpr::Str(s, _) => out.push(s.clone()),
            IrExpr::Array(items) => items.iter().for_each(|x| texts(x, out)),
            IrExpr::Call { args, .. } => args.iter().for_each(|x| texts(x, out)),
            _ => {}
        }
    }
    let mut ts = Vec::new();
    texts(cond, &mut ts);
    ts.iter().find_map(|t| parse_cmp(t, var))
}

/// Parse `i<10` / `i <= 20` (whitespace tolerated).
fn parse_cmp(text: &str, var: &str) -> Option<(i64, bool)> {
    let t: String = text.chars().filter(|c| !c.is_whitespace()).collect();
    for op in ["<=", "<"] {
        if let Some((l, r)) = t.split_once(op) {
            if l.strip_prefix('$').unwrap_or(l) == var {
                if let Ok(n) = r.parse::<i64>() {
                    return Some((n, op == "<="));
                }
            }
        }
    }
    None
}

/// Shared body analysis + spec construction.
#[allow(clippy::too_many_arguments)]
fn finish(
    scope: &mut Scope,
    path: &str,
    var: &str,
    lo: i64,
    hi: i64,
    step: i64,
    inclusive: bool,
    body: &[IrStmt],
) -> LoopVerdict {
    let Some(trips) = trips(lo, hi, step, inclusive) else {
        return veto(scope, path, var, "empty-range");
    };
    if trips == 0 {
        return veto(scope, path, var, "empty-range");
    }
    let mut cx = BodyCx { var, types: scope.types, externs: BTreeSet::new() };
    let mut stores: Vec<VkStore> = Vec::new();
    let mut seen_arrays: BTreeSet<String> = BTreeSet::new();
    for s in body {
        let IrStmt::Assign { targets, expr, .. } = s else {
            return veto(scope, path, var, host_reason(s));
        };
        if targets.len() != 1 {
            return veto(scope, path, var, "multi-target");
        }
        let tgt = &targets[0].var;
        let Some((arr, idx)) = split_target(tgt) else {
            return veto(scope, path, var, "scalar-carry");
        };
        let Some((a, b)) = affine_index(idx, var) else {
            return veto(scope, path, var, "non-affine-index");
        };
        if !seen_arrays.insert(arr.to_string()) {
            return veto(scope, path, var, "overlapping-stores");
        }
        let IrExpr::Arith(ast) = expr else {
            // Scalar reads lower too (`a[$i]=$i`, `a[$i]=5`); anything
            // else (captures, interpolations, calls) is not i64-plain.
            let scalar = match expr {
                IrExpr::Var(name, _) | IrExpr::Ident(name) => read_scalar(&mut cx, var, name),
                IrExpr::Call { func, args } if func == "getVar" => {
                    match args.first() {
                        Some(IrExpr::Str(name, _)) => read_scalar(&mut cx, var, name),
                        _ => None,
                    }
                }
                IrExpr::Int(n) => Some(VkArith::Num(*n)),
                IrExpr::Str(s, _) => s.parse::<i64>().ok().map(VkArith::Num),
                _ => None,
            };
            let Some(value) = scalar else {
                return veto(scope, path, var, "non-arith-value");
            };
            stores.push(VkStore { array: arr.to_string(), index_a: a, index_b: b, value });
            continue;
        };
        let value = match lower_arith(ast, &mut cx) {
            Ok(v) => v,
            Err(r) => return veto(scope, path, var, r),
        };
        stores.push(VkStore { array: arr.to_string(), index_a: a, index_b: b, value });
    }
    if stores.is_empty() {
        return veto(scope, path, var, "empty-body");
    }
    let id = scope.next_id();
    let spec = VkLoopSpec {
        id: id.clone(),
        var: var.to_string(),
        lo,
        hi,
        hi_inclusive: inclusive,
        step,
        trips,
        externs: cx.externs.into_iter().collect(),
        stores,
    };
    LoopVerdict {
        id,
        path: path.to_string(),
        var: var.to_string(),
        lo,
        hi,
        step,
        trips,
        verdict: Verdict::Candidate,
        spec: Some(spec),
    }
}

/// Veto reason for a non-Assign body statement.
fn host_reason(s: &IrStmt) -> &'static str {
    // Shell surface arrives as `Expr(Call exec/builtin ...)` — classify
    // the command, not just the IR node.
    if let IrStmt::Expr(IrExpr::Call { func, args }) = s {
        return match func.as_str() {
            "exec" | "builtin" => match first_str(args) {
                Some("echo") | Some("printf") => "body-host-io",
                _ => "body-call",
            },
            "pipeline" => "body-pipeline",
            "capture" | "captureWords" => "body-capture",
            _ => "body-call",
        };
    }
    match s {
        IrStmt::Output { .. } => "body-host-io",
        IrStmt::WriteFile { .. } => "body-host-io",
        IrStmt::Redirect { .. } => "body-redirect",
        IrStmt::Function { .. } => "body-function",
        IrStmt::Subshell(_) => "body-subshell",
        IrStmt::Background(_) => "body-background",
        IrStmt::Pipeline { .. } => "body-pipeline",
        IrStmt::Return(_) => "body-early-exit",
        IrStmt::Exit(_) => "body-early-exit",
        IrStmt::Break | IrStmt::Continue => "body-flow",
        IrStmt::If { .. } => "body-branch",
        IrStmt::While { .. } | IrStmt::DoWhile { .. } => "body-nested-loop",
        IrStmt::For { .. } | IrStmt::ForInit { .. } => "body-nested-loop",
        IrStmt::Try { .. } => "body-effect",
        IrStmt::Die { .. } | IrStmt::Warn { .. } => "body-effect",
        IrStmt::Declare { .. } | IrStmt::DeclareArray { .. } => "body-decl",
        _ => "body-effect",
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
    fn squares_loop_is_candidate() {
        let p = prog_of("#!/bin/bash\nfor ((i=0;i<10;i++)); do a[$i]=$((i*i)); done\n");
        let v = analyze(&p);
        assert_eq!(v.len(), 1, "{v:?}");
        assert!(v[0].is_candidate(), "{}", v[0]);
        assert_eq!(v[0].trips, 10);
        let spec = v[0].spec.as_ref().expect("spec");
        assert_eq!(spec.stores.len(), 1);
        assert_eq!(spec.stores[0].array, "a");
    }

    #[test]
    fn brace_range_loop_is_candidate() {
        let p = prog_of("#!/bin/bash\nfor i in {0..7}; do a[$i]=$((i+1)); done\n");
        let v = analyze(&p);
        assert_eq!(v.len(), 1);
        assert!(v[0].is_candidate(), "{}", v[0]);
        assert_eq!((v[0].lo, v[0].hi, v[0].trips), (0, 7, 7));
    }

    #[test]
    fn veto_reasons_cover_doc_shapes() {
        // accumulate → scalar-carry (needs reduction, M5)
        let p = prog_of("#!/bin/bash\ns=0\nfor i in {1..10}; do s=$((s+i)); done\n");
        let v = analyze(&p);
        assert!(matches!(v[0].verdict, Verdict::Veto { reason: "scalar-carry" }), "{}", v[0]);
        // echo in body → host-io
        let p = prog_of("#!/bin/bash\nfor i in {1..10}; do echo $i; done\n");
        let v = analyze(&p);
        assert!(matches!(v[0].verdict, Verdict::Veto { reason: "body-host-io" }), "{}", v[0]);
        // pipeline in body → veto
        let p = prog_of("#!/bin/bash\nfor i in 1 2 3; do echo hi | grep h; done\n");
        let v = analyze(&p);
        assert!(matches!(v[0].verdict, Verdict::Veto { .. }), "{}", v[0]);
        // while loop → skipped silently (not counted)
        let p = prog_of("#!/bin/bash\nwhile read l; do echo $l; done < f\n");
        assert!(analyze(&p).is_empty());
    }

    #[test]
    fn ids_are_stable() {
        let p = prog_of("#!/bin/bash\nfor ((i=0;i<3;i++)); do a[$i]=$i; done\n");
        let a = analyze(&p).into_iter().map(|v| v.to_string()).collect::<Vec<_>>();
        let b = analyze(&p).into_iter().map(|v| v.to_string()).collect::<Vec<_>>();
        assert_eq!(a, b);
        assert!(a[0].starts_with("candidate sh_loop_main_0"), "{}", a[0]);
    }
}
