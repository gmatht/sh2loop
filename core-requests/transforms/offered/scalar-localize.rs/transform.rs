//! scalar-localize — mark the scalar variables whose uses are confined to ONE
//! scope and whose first mention is a top-level write, so a renderer can emit
//! a local binding (`let s = …`) instead of a global cell (`__SHV_s`, a
//! `thread_local!`).
//!
//! ## Need
//! `s="hello world"; if [[ "$s" == *w* ]]; then …` renders in Rust as
//! `__SHV_s.with(|v| v.borrow().clone())` even though nothing observes the
//! binding across scopes. The existing promotion
//! (`rust_backend::compute_local_vars` over
//! `shir_passes::list_profile::use_scopes`) refuses the name because a read
//! inside a test/condition argument is marked *risky* — a bit that describes a
//! renderer which lowers an argument through a FILE-SCOPE helper that captures
//! the value. Rust does not: `read_str`/`getvar_str` splice the value at the
//! mention (`self.tls(name)`), so the bit over-refuses.
//!
//! ## The verdict
//! A name is SCALAR-LOCAL when ALL of:
//!   - every mention sits in ONE scope (`Main`, or one named function/sub),
//!   - it is written at least once (a read-only name keeps the process
//!     environment's value; a `let` would shadow it with ""),
//!   - its FIRST mention is a WRITE at the top level of its scope — that is
//!     where the `let` lands, and a first write inside a branch would bind
//!     after the guard had already run,
//!   - no construct in the program can reach a name the walk cannot see:
//!     `eval`/`source`/`.` (either spelling), a DYNAMIC `getVar`/`setVar`
//!     argument, `Ext`, `RawText`, `Select`, `Asm`, `Shaderize`.
//!
//! The `risky` bit is deliberately NOT consulted: it is a renderer property,
//! not an IR one. A backend whose reads render inline accepts this verdict; a
//! backend that lowers through a capturing helper keeps its own veto.
//!
//! ## Entry points
//! [`transform_program`] is the real one — the verdict is about WHOLE-PROGRAM
//! scope confinement, `prog.subs` included. It is NOT registered in
//! `transforms::all()`: the registry hands a transform only a statement list,
//! which would hide every `sub` body and mark a cross-scope name local.
//! [`transform`] exists for the registry's shape only and is never registered.
//!
//! Analysis-only: no structural mutation; the verdict lives in a module static
//! and a renderer reads it through [`locals`] / [`is_local`].
//!
//! ## Manifest
//! name: scalar-localize
//! prereqs: []
//! invariant: a marked name has exactly one owning scope, at least one write,
//!   its first mention is a top-level write in that scope, and no construct in
//!   the program can reach an unmodelled name.
//! scope: offered to rs (the `__SHV_*` → `let` promotion); other backends may
//!   adopt it by reading the verdict — none is forced to.
//! updates: none (first offer)

use std::collections::{HashMap, HashSet};
use std::sync::Mutex;

use crate::ir::{ArithAst, InterpPart, IrExpr, IrProgram, IrStmt};

/// The single scope a marked name lives in.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum LocalScope {
    Main,
    Func(String),
}

static VERDICTS: Mutex<Option<HashMap<String, LocalScope>>> = Mutex::new(None);

/// Drop the cached verdict (the `clear_verdicts` contract every analysis-only
/// transform honours: an out-of-band caller that runs transforms in isolation
/// must reset, or run 2 observes run 1's verdict).
pub fn clear_verdicts() {
    *VERDICTS.lock().unwrap() = None;
}

/// Every marked name → its owning scope.
pub fn locals() -> HashMap<String, LocalScope> {
    VERDICTS.lock().unwrap().clone().unwrap_or_default()
}

/// Is `name` scalar-local?
pub fn is_local(name: &str) -> bool {
    VERDICTS
        .lock()
        .unwrap()
        .as_ref()
        .is_some_and(|m| m.contains_key(name))
}

/// The program-level entry (the real one).
pub fn transform_program(prog: &IrProgram) -> bool {
    *VERDICTS.lock().unwrap() = Some(analyze(prog));
    false // analysis-only
}

/// Statement-list entry, for a caller that has no `IrProgram`. This is the
/// shape `transforms::all()` offers, and it is NOT registered there: with
/// `subs` empty a name used by a function body looks one-scope and would be
/// wrongly marked local.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let prog = IrProgram {
        imports: Vec::new(),
        requires: Vec::new(),
        stmts: std::mem::take(stmts),
        subs: Vec::new(),
        var_types: Vec::new(),
        stmt_lines: Vec::new(),
        var_lengths: Vec::new(),
        var_const: Vec::new(),
        var_lifetimes: Vec::new(),
        var_nospace: Vec::new(),
        var_storage: Vec::new(),
        var_bash_env: Vec::new(),
    };
    let verdict = analyze(&prog);
    *stmts = prog.stmts;
    *VERDICTS.lock().unwrap() = Some(verdict);
    false
}

// ── the analysis ─────────────────────────────────────────────────────

/// One attributed mention.
#[derive(Debug, Clone)]
struct Mention {
    scope: LocalScope,
    write: bool,
    top: bool,
}

fn analyze(prog: &IrProgram) -> HashMap<String, LocalScope> {
    let mut out: HashMap<String, Vec<Mention>> = HashMap::new();
    let mut unsafe_names: HashSet<String> = HashSet::new();
    let mut opaque = false; // a construct that can reach ANY name

    let mut loop_vars: HashSet<String> = HashSet::new();
    let mut w = W {
        out: &mut out,
        unsafe_names: &mut unsafe_names,
        opaque: &mut opaque,
        scope: LocalScope::Main,
        top: true,
        loop_vars: HashSet::new(),
    };
    for st in &prog.stmts {
        w.top = true;
        w.stmt(st);
    }
    for sub in &prog.subs {
        w.scope = LocalScope::Func(sub.name.clone());
        w.top = true;
        for st in &sub.body {
            w.stmt(st);
        }
    }
    loop_vars.extend(w.loop_vars.iter().cloned());

    if opaque {
        return HashMap::new();
    }
    let mut kept: HashMap<String, LocalScope> = HashMap::new();
    for (name, mentions) in out {
        if unsafe_names.contains(&name)
            || is_shell_special(&name)
            || mentions.is_empty()
            || loop_vars.contains(&name)
        {
            continue;
        }
        let first = mentions[0].scope.clone();
        if mentions.iter().any(|m| m.scope != first) {
            continue; // observable across scopes
        }
        let m0 = &mentions[0];
        if !(m0.write && m0.top) {
            continue; // the `let` lands at the first mention
        }
        if !mentions.iter().any(|m| m.write) {
            continue;
        }
        kept.insert(name, first);
    }
    kept
}

struct W<'a> {
    out: &'a mut HashMap<String, Vec<Mention>>,
    unsafe_names: &'a mut HashSet<String>,
    opaque: &'a mut bool,
    scope: LocalScope,
    top: bool,
    /// Names BOUND by a loop header (`for i in …`). A renderer emits its own
    /// binding for those and a pass-2 `let` would either shadow it or leave
    /// the assignment dangling — measured: a `for` loop turned into
    /// `i = 0; loop { … }` with no `let i` at all.
    loop_vars: HashSet<String>,
}

impl<'a> W<'a> {
    fn push(&mut self, name: &str, write: bool) {
        if name.is_empty() || name.chars().all(|c| c.is_ascii_digit()) {
            self.unsafe_names.insert(name.to_string());
            return;
        }
        self.out.entry(name.to_string()).or_default().push(Mention {
            scope: self.scope.clone(),
            write,
            top: self.top,
        });
    }

    fn stmt(&mut self, st: &IrStmt) {
        // `self.top` is set by the CALLER (the statement lists that are top
        // level arm it, `nested` clears it); a statement never restores it,
        // or a nested walk's last state would leak into the next statement.
        self.stmt_inner(st);
    }

    fn nested(&mut self, list: &[IrStmt]) {
        for s in list {
            self.top = false;
            self.stmt(s);
        }
    }

    /// A string WORD of a command: `$name` references are reads, and a bare
    /// identifier is a read only when the frontends substituted it
    /// (`"$x"` arrives as the text `x`); a quoted literal is DATA, so
    /// `s = "s"` never reads `s`.
    fn word(&mut self, w: &IrExpr) {
        match w {
            IrExpr::Str(s, style) => {
                if matches!(style, crate::ir::StrStyle::Raw) {
                    self.text(s);
                }
            }
            other => self.expr(other),
        }
    }

    fn text(&mut self, t: &str) {
        for v in dollar_vars(t) {
            self.push(&v, false);
        }
    }

    fn stmt_inner(&mut self, st: &IrStmt) {
        match st {
            IrStmt::Assign { targets, expr, .. } => {
                // A LITERAL RHS is DATA: record the write first so `s="…"`
                // opens with the write, which the "first mention is a
                // top-level write" rule needs. A COMPUTED RHS reads the old
                // value, so it is walked first.
                let literal_rhs =
                    matches!(expr, IrExpr::Str(_, _) | IrExpr::Int(_) | IrExpr::Bool(_));
                // A COMPUTED RHS reads the old value first (`y=$((y+2))`,
                // `y+=2`), so its write is not a *first* write — recording
                // it before the read would let a `let mut y = …` read `y`
                // before it exists (measured: 051_primes `cannot find value
                // y`). Walk the RHS first whenever it could read a target.
                let self_referential = !literal_rhs && self.rhs_reads_any(expr, targets);
                if !literal_rhs {
                    self.expr(expr);
                }
                for t in targets {
                    let base = t.var.split('[').next().unwrap_or(&t.var);
                    if !self_referential {
                        self.push(base, true);
                    }
                    for i in &t.indices {
                        self.expr(i);
                    }
                }
                // a literal RHS was already classified (DATA) above; walking
                // it again would turn `s = "s"` into a read of `s`
                let _ = &literal_rhs;
            }
            IrStmt::Output { value, target, .. } => {
                if let Some(t) = target {
                    self.push(t, true);
                }
                self.expr(value);
            }
            IrStmt::WriteFile { path, content, .. } => {
                self.expr(path);
                self.expr(content);
            }
            IrStmt::Declare { vars, init, .. } => {
                // a declaration IS the binding: a literal init records the
                // writes first (so `local s=""` opens with the write); a
                // self-referential init (`local n=$((n+1))`) reads first, and
                // then there is no first WRITE to hang a `let` on.
                let literal_init = init
                    .as_ref()
                    .is_none_or(|i| matches!(i, IrExpr::Str(_, _) | IrExpr::Int(_) | IrExpr::Bool(_)));
                if literal_init {
                    for v in vars {
                        self.push(&v.name, true);
                    }
                    if let Some(i) = init {
                        self.expr(i);
                    }
                } else {
                    if let Some(i) = init {
                        self.expr(i);
                    }
                    for v in vars {
                        self.push(&v.name, true);
                    }
                }
            }
            IrStmt::DeclareArray { var, elements, .. } => {
                self.push(var, true);
                for e in elements {
                    self.expr(e);
                }
            }
            IrStmt::If { cond, then, elsifs, else_ } => {
                self.expr(cond);
                self.nested(then);
                for (c, b) in elsifs {
                    self.expr(c);
                    self.nested(b);
                }
                self.nested(else_);
            }
            IrStmt::For { var, iter, body } => {
                self.expr(iter);
                self.loop_vars.insert(var.clone());
                self.push(var, true);
                self.nested(body);
            }
            IrStmt::ForInit { init, cond, step, body } => {
                // the counter of a recovered counted loop is bound by the
                // renderer's own `for` header
                for s in init.iter().chain(step.iter()) {
                    if let IrStmt::Assign { targets, .. } = s {
                        for t in targets {
                            self.loop_vars.insert(t.var.clone());
                        }
                    }
                }
                self.nested(init);
                self.expr(cond);
                self.nested(step);
                self.nested(body);
            }
            IrStmt::While { cond, body } => {
                self.expr(cond);
                self.nested(body);
            }
            IrStmt::DoWhile { body, cond, .. } => {
                self.expr(cond);
                self.nested(body);
            }
            IrStmt::Exec { cmd, args, capture, redirects, env, .. } => {
                if dynamic_command(cmd) {
                    *self.opaque = true;
                }
                self.expr(cmd);
                for a in args {
                    self.word(a);
                }
                if let Some(c) = capture {
                    self.push(c, true);
                }
                for r in redirects {
                    self.expr(r);
                }
                for (n, v) in env {
                    self.push(n, true);
                    self.expr(v);
                }
            }
            IrStmt::Pipeline { stages, capture, .. } => {
                for s in stages {
                    self.nested(s);
                }
                if let Some(c) = capture {
                    self.push(c, true);
                }
            }
            IrStmt::Redirect { inner, redirects } => {
                self.nested(inner);
                for r in redirects {
                    self.expr(&r.target);
                }
            }
            IrStmt::Block(b) | IrStmt::Subshell(b) | IrStmt::Background(b) => self.nested(b),
            IrStmt::Function { name, params, body, named_blocks } => {
                // A nested definition is its OWN scope: a write inside it is
                // not a write of the enclosing one (t42's `def f(): global g;
                // g = 1` must not make `g` a main-scope local).
                self.push(name, true);
                let save_scope = self.scope.clone();
                self.scope = LocalScope::Func(name.clone());
                for p in params {
                    self.push(p, true);
                }
                self.nested(body);
                for (_, b) in named_blocks {
                    self.nested(b);
                }
                self.scope = save_scope;
            }
            IrStmt::Try { body, excepts, else_body, finally_body } => {
                self.nested(body);
                for e in excepts {
                    if let Some(m) = &e.match_expr {
                        self.expr(m);
                    }
                    if let Some(n) = &e.as_name {
                        self.push(n, true);
                    }
                    self.nested(&e.body);
                }
                self.nested(else_body);
                self.nested(finally_body);
            }
            IrStmt::Case { discriminant, clauses } => {
                self.expr(discriminant);
                for c in clauses {
                    for p in &c.patterns {
                        self.text(p);
                    }
                    self.nested(&c.body);
                }
            }
            IrStmt::Select { clauses } => {
                *self.opaque = true;
                for c in clauses {
                    if let Some(t) = &c.target {
                        self.push(t, true);
                    }
                    for e in c.ch.iter().chain(c.value.iter()) {
                        self.expr(e);
                    }
                }
            }
            IrStmt::Asm { outputs, inputs, .. } => {
                *self.opaque = true;
                for (_, e) in outputs.iter().chain(inputs.iter()) {
                    self.expr(e);
                }
            }
            IrStmt::Shaderize { var, body, .. } => {
                *self.opaque = true;
                self.push(var, true);
                self.nested(body);
            }
            IrStmt::Die { expr, .. } | IrStmt::Warn { expr, .. } => self.expr(expr),
            IrStmt::Return(e) | IrStmt::Exit(e) => {
                if let Some(x) = e {
                    self.expr(x);
                }
            }
            IrStmt::SetChildError(e) => self.expr(e),
            IrStmt::Expr(e) => self.expr(e),
            IrStmt::RawText(t) => {
                *self.opaque = true;
                self.text(t);
            }
            IrStmt::Ext(n) => {
                *self.opaque = true;
                for c in n.children() {
                    self.nested(std::slice::from_ref(c));
                }
            }
            IrStmt::Require(_)
            | IrStmt::Label(_)
            | IrStmt::Goto(_)
            | IrStmt::Continue
            | IrStmt::Break => {}
        }
    }

    fn expr(&mut self, e: &IrExpr) {
        match e {
            IrExpr::Int(_) | IrExpr::Bool(_) | IrExpr::Range { .. } | IrExpr::Json(_) => {}
            // a quoted literal is DATA; an unquoted word is a substituted
            // reference (`"$x"` reaches here as `x`)
            IrExpr::Str(s, style) => {
                if matches!(style, crate::ir::StrStyle::Raw) {
                    self.text(s);
                }
            }
            IrExpr::RawExpr(s) => self.text(s),
            IrExpr::Regex { pattern, flags } => {
                self.text(pattern);
                self.text(flags);
            }
            IrExpr::Var(v, _) | IrExpr::Ident(v) => self.push(v, false),
            IrExpr::Index { var, key } => {
                self.push(var, false);
                self.expr(key);
            }
            IrExpr::BinOp { lhs, rhs, .. } => {
                self.expr(lhs);
                self.expr(rhs);
            }
            IrExpr::Call { func, args } => {
                if dynamic_command(e) {
                    *self.opaque = true;
                }
                // `getVar("v")` / `param("op","v")` carry the name as a STRING
                // arg — that is a read of `v`, the form the A1 actually uses.
                let name_arg = if func == "param" { 1 } else { 0 };
                if matches!(
                    func.as_str(),
                    "getVar"
                        | "param"
                        | "arrayLen"
                        | "listVar"
                        | "arrayIndex"
                        | "setArray"
                        | "setArrayAppend"
                        | "setVar"
                ) {
                    match args.get(name_arg) {
                        Some(IrExpr::Str(n, _)) => {
                            let write =
                                matches!(func.as_str(), "setVar" | "setArray" | "setArrayAppend");
                            self.push(n, write);
                        }
                        _ => *self.opaque = true, // dynamic name
                    }
                }
                for a in args {
                    self.expr(a);
                }
            }
            IrExpr::MethodCall { obj, args, .. } => {
                self.expr(obj);
                for a in args {
                    self.expr(a);
                }
            }
            IrExpr::Ternary { cond, then, else_ } => {
                self.expr(cond);
                self.expr(then);
                self.expr(else_);
            }
            IrExpr::DefinedOr { expr, default } => {
                self.expr(expr);
                self.expr(default);
            }
            IrExpr::Interpolate(parts) => {
                for p in parts {
                    match p {
                        InterpPart::Lit(s) => self.text(s),
                        InterpPart::Expr(x) => self.expr(x),
                    }
                }
            }
            IrExpr::Capture { expr, .. } => self.expr(expr),
            IrExpr::Arrow(body) | IrExpr::Lambda { body, .. } => self.nested(body),
            IrExpr::Array(items) => {
                for i in items {
                    self.expr(i);
                }
            }
            IrExpr::ArrayComp { var, iter, elem, cond } => {
                self.expr(iter);
                self.push(var, true);
                self.expr(elem);
                if let Some(c) = cond {
                    self.expr(c);
                }
            }
            IrExpr::Object(props) => {
                for (_, v) in props {
                    self.expr(v);
                }
            }
            IrExpr::Splice(inner) => self.expr(inner),
            IrExpr::Arith(a) => self.arith(a),
            IrExpr::Ext(_) => *self.opaque = true,
        }
    }

    /// Does `expr` READ any of these assignment targets? (`y=$((y+2))`.)
    fn rhs_reads_any(&self, expr: &IrExpr, targets: &[crate::ir::AssignTarget]) -> bool {
        let mut out: HashMap<String, Vec<Mention>> = HashMap::new();
        let mut unsafe_names: HashSet<String> = HashSet::new();
        let mut opaque = false;
        let mut loop_vars = HashSet::new();
        let mut probe = W {
            out: &mut out,
            unsafe_names: &mut unsafe_names,
            opaque: &mut opaque,
            scope: self.scope.clone(),
            top: self.top,
            loop_vars: std::mem::take(&mut loop_vars),
        };
        probe.expr(expr);
        targets.iter().any(|t| {
            let base = t.var.split('[').next().unwrap_or(&t.var);
            out.get(base).is_some_and(|ms| ms.iter().any(|m| !m.write))
        })
    }

    fn arith(&mut self, a: &ArithAst) {
        match a {
            ArithAst::Num(_) | ArithAst::Sizeof(_) => {}
            ArithAst::Var(v) | ArithAst::Ident(v) => self.push(v, false),
            ArithAst::Index { var, key } => {
                self.push(var, false);
                self.arith(key);
            }
            ArithAst::Bin { lhs, rhs, .. } => {
                self.arith(lhs);
                self.arith(rhs);
            }
            ArithAst::Un { arg, .. } | ArithAst::Cast { arg, .. } => self.arith(arg),
            ArithAst::Cond { test, then, else_ } => {
                self.arith(test);
                self.arith(then);
                self.arith(else_);
            }
            ArithAst::Assign { var, rhs, .. } => {
                self.push(var, true);
                self.arith(rhs);
            }
            ArithAst::IncDec { var, .. } => self.push(var, true),
        }
    }
}

/// `.`/`source`/`eval` executed as a command (both the `Exec` and the
/// `Expr(Call{exec|builtin})` spelling) can write ANY name.
fn dynamic_command(e: &IrExpr) -> bool {
    let args = match e {
        IrExpr::Str(h, _) => return matches!(h.as_str(), "." | "source" | "eval"),
        IrExpr::Call { func, args } if matches!(func.as_str(), "exec" | "builtin" | "callDirect") => {
            args
        }
        _ => return false,
    };
    matches!(args.first(), Some(IrExpr::Str(h, _)) if matches!(h.as_str(), "." | "source" | "eval"))
}

/// Shell specials / positionals that keep their runtime storage.
fn is_shell_special(name: &str) -> bool {
    name.is_empty()
        || name.chars().all(|c| c.is_ascii_digit())
        || matches!(
            name,
            "@" | "*"
                | "#"
                | "?"
                | "$"
                | "!"
                | "-"
                | "_"
                | "PPID"
                | "BASHPID"
                | "IFS"
                | "PATH"
                | "HOME"
                | "PWD"
                | "OLDPWD"
                | "SHELL"
                | "USER"
                | "TERM"
                | "LANG"
                | "LC_ALL"
                | "RANDOM"
                | "SECONDS"
                | "LINENO"
                | "FUNCNAME"
                | "BASH_SOURCE"
                | "OPTARG"
                | "OPTIND"
        )
}

/// `$name` / `${name…}` references in a text operand.
fn dollar_vars(text: &str) -> Vec<String> {
    let b = text.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < b.len() {
        if b[i] != b'$' {
            i += 1;
            continue;
        }
        i += 1;
        if i < b.len() && b[i] == b'{' {
            i += 1;
            if i < b.len() && (b[i] == b'#' || b[i] == b'!') {
                i += 1;
            }
        }
        let start = i;
        while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_') {
            i += 1;
        }
        if i > start {
            out.push(text[start..i].to_string());
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{AssignTarget, StrStyle};

    fn assign(name: &str, e: IrExpr) -> IrStmt {
        IrStmt::Assign {
            targets: vec![AssignTarget { var: name.to_string(), sigil: None, indices: vec![] }],
            expr: e,
            asm: None,
        }
    }

    fn lit(s: &str) -> IrExpr {
        IrExpr::Str(s.to_string(), StrStyle::DoubleQuoted)
    }

    fn getv(n: &str) -> IrExpr {
        IrExpr::Call { func: "getVar".to_string(), args: vec![lit(n)] }
    }

    fn empty_prog(stmts: Vec<IrStmt>, subs: Vec<crate::ir::IrSub>) -> IrProgram {
        IrProgram {
            imports: vec![],
            requires: vec![],
            stmts,
            subs,
            var_types: vec![],
            stmt_lines: vec![],
            var_lengths: vec![],
            var_const: vec![],
            var_lifetimes: vec![],
            var_nospace: vec![],
            var_storage: vec![],
            var_bash_env: vec![],
        }
    }

    fn mark(stmts: Vec<IrStmt>) -> Vec<String> {
        transform_program(&empty_prog(stmts, vec![]));
        let mut v: Vec<String> = locals().keys().cloned().collect();
        v.sort();
        v
    }

    /// THE t60 SHAPE: `s="hello world"` then a read inside a condition.
    #[test]
    fn a_var_read_only_inside_a_condition_is_local() {
        let stmts = vec![
            assign("s", lit("hello world")),
            IrStmt::If {
                cond: IrExpr::Call {
                    func: "contains".to_string(),
                    args: vec![getv("s"), lit("world")],
                },
                then: vec![IrStmt::Expr(getv("s"))],
                elsifs: vec![],
                else_: vec![],
            },
        ];
        assert_eq!(mark(stmts), vec!["s".to_string()]);
    }

    /// A read-only name keeps the environment's value — a `let` would shadow
    /// it with "".
    #[test]
    fn a_never_written_name_is_not_local() {
        assert!(mark(vec![IrStmt::Expr(getv("PATH"))]).is_empty());
    }

    /// Two scopes: the value is observable across them.
    #[test]
    fn a_name_used_in_two_scopes_is_not_local() {
        let sub = crate::ir::IrSub {
            name: "f".to_string(),
            params: vec![],
            param_defaults: vec![],
            body: vec![IrStmt::Expr(getv("s"))],
        };
        transform_program(&empty_prog(vec![assign("s", lit("x"))], vec![sub]));
        assert!(!is_local("s"), "cross-scope use must stay global");
    }

    /// `eval` can write ANY name — the whole verdict is withheld.
    #[test]
    fn a_dynamic_construct_withholds_everything() {
        let stmts = vec![
            assign("s", lit("x")),
            IrStmt::Exec {
                cmd: lit("eval"),
                args: vec![lit("s=1")],
                capture: None,
                redirects: vec![],
                env: Vec::new(),
            },
        ];
        assert!(mark(stmts).is_empty());
    }

    /// The first mention must be a TOP-LEVEL write.
    #[test]
    fn a_first_write_inside_a_branch_is_not_local() {
        let stmts = vec![IrStmt::If {
            cond: IrExpr::Bool(true),
            then: vec![assign("s", lit("x"))],
            elsifs: vec![],
            else_: vec![],
        }];
        assert!(mark(stmts).is_empty());
    }

    /// `local s=…` at a function top is a top-level write of that scope.
    #[test]
    fn a_declaration_at_the_scope_top_is_local() {
        let stmts = vec![
            IrStmt::Declare {
                vars: vec![crate::ir::Decl { name: "s".to_string(), sigil: None }],
                init: Some(lit("x")),
                local: true,
            },
            IrStmt::Expr(getv("s")),
        ];
        assert_eq!(mark(stmts), vec!["s".to_string()]);
    }

    /// A COMPUTED self-write (`y=$((y+2))`) opens with a READ of `y`, so it
    /// is not a top-level first WRITE: a `let mut y = …` there would read `y`
    /// before it exists (measured as `cannot find value y` in 051_primes).
    #[test]
    fn a_computed_self_write_is_not_a_first_write() {
        let stmts = vec![
            assign("y", IrExpr::Arith(Box::new(ArithAst::Bin {
                op: "+".to_string(),
                lhs: Box::new(ArithAst::Var("y".to_string())),
                rhs: Box::new(ArithAst::Num(2)),
            }))),
            IrStmt::Expr(getv("y")),
        ];
        assert!(mark(stmts).is_empty(), "a self-read RHS cannot open the binding");
    }

    /// A quoted literal is DATA: `s = "s"` must not read `s`, or the phantom
    /// read precedes the write and the name is refused.
    #[test]
    fn a_literal_rhs_does_not_read_its_own_target() {
        assert_eq!(mark(vec![assign("a", lit("a")), IrStmt::Expr(getv("a"))]), vec!["a".to_string()]);
    }
}
