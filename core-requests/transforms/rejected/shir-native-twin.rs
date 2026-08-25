//! shir-native-twin — rewrite statement shapes whose NATIVE TWIN the
//! renderers already emit (no `system('bash', '-c', …)` needed).
//!
//! ## Why
//!
//! `./fail-shir` counts `system('bash', …)` call sites in the rendered
//! Perl. When the A1 shape a statement takes is one the renderers do not
//! lower to an in-process emulation (the EMULATED_COMMANDS / builtin
//! paths), the Perl renderer rebuilds the shell text and shells out.
//! Three statement families have a provable NATIVE twin — a different A1
//! shape, same bytes on stdout + same exit status — that both the Perl
//! and the ESTree renderers already emit in-process:
//!
//! 1. **`cat <<EOF` / `cat <<-EOF` / `cat <<< '…'` heredoc/herestring**
//!    — `Redirect{inner:[exec cat], fd0 heredoc}` writes the (static)
//!    body to stdout / to a file. The ESTree backend already folds this
//!    exact shape natively (`try_native_cat_heredoc` → a
//!    `process.stdout.write` / `sh2.fs.writeFile`); the shIR twin that
//!    makes the PERL backend native too is a `printf %s <content>`
//!    exec: `bash cat <<EOF` and `bash printf %s "$body"` print the same
//!    bytes and both exit 0. With a fd-1 file spec present, the twin is
//!    `Redirect{inner:[Block([printf …])], fd1 w|a file}` — the
//!    Block-wrapped inner is NOT shell-rebuildable, so the Perl renderer
//!    falls into its native select()-based file-redirect arm.
//!
//! 2. **`test && echo/printf` / `test || echo/printf` chains** —
//!    `[[ cond ]] && echo X` / `[ cond ] || echo Y`: the decision is the
//!    test's; the arm is an always-success builtin. The chain becomes a
//!    native `If{cond, then:[echo]}` / `If{cond, else:[echo]}` (the
//!    `&&`-arm of `shir-native-stmt` needs the full `|| else`; the
//!    single-arm forms were left shelling out). REFUSED for any program
//!    that READS `$?` anywhere: the chain's false-path status (1) would
//!    be lost by an if/else, and a later `$?` read would diverge.
//!
//! 3. **`echo <arg> | grep <literal>` (statement position)** —
//!    exactly two stages, echo with ONE argument, grep with ONE literal
//!    pattern (no flags, no BRE metacharacters), the echo arg a single
//!    static line: grep prints the line exactly when it contains the
//!    pattern, else nothing, status 0/1. The native twin is
//!    `If{cond: contains(arg, pattern), then:[echo arg],
//!    else:[exec false]}` — perl renders `index($arg, $pat) >= 0`
//!    natively, the ESTree renderer lowers `contains` to the shared
//!    substring builtin. Status is reproduced on both arms (0 / 1), so
//!    later `$?` reads stay correct.
//!
//! ## Soundness (REFUSE > GUESS)
//!
//! - The heredoc fold only fires for STATIC content: a plain `Str`
//!   target; an UNQUOTED heredoc containing `$`, backticks or backslash
//!   is refused (the runtime's expansion would not be identity — mirrors
//!   the ESTree `try_native_cat_heredoc` gate); heredoc-tabs applies the
//!   per-line leading-tab strip exactly; the herestring appends its
//!   trailing newline. `cat` must be bare or the stdin marker `-`; the
//!   fd-0 heredoc spec must be the only input spec (a second fd-0 spec
//!   refuted); a file-spec twin is restricted to a single static fd-1
//!   `w`/`wc`/`a` target (no fd-2 specs, no `&`-dups, no dynamic
//!   targets). A program defining a function named `cat` or `printf`
//!   (bash would dispatch the FUNCTION) refuses the family.
//! - The chain-to-If twin refuses when the program reads `$?` anywhere
//!   (the false-path status is only recoverable while dead), when the
//!   cond tree contains anything but `test` calls, when a function named
//!   `echo`/`printf` shadows the arm, and when the arm is not a single
//!   always-success builtin exec.
//! - The grep-pipeline twin refuses echo flags (`-e`/`-n`), non-static
//!   echo args (a variable could hold embedded newlines — grep matches
//!   per line, `contains` does not), real newlines in the echo arg,
//!   grep flags, non-literal / metacharacter patterns, and programs that
//!   define functions named `echo`/`grep`.

use crate::ir::{BinOpKind, InterpPart, IrExpr, IrRedirect, IrStmt, StrStyle};

/// Program-wide gates, computed once per `transform` call on the
/// original tree (the transform introduces none of these itself).
struct Ctx {
    reads_dollar_question: bool,
    fn_cat: bool,
    fn_printf: bool,
    fn_echo: bool,
    fn_grep: bool,
}

/// Apply the transform. Returns whether anything changed.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let ctx = Ctx {
        reads_dollar_question: stmts_read_q(stmts),
        fn_cat: defines_fn(stmts, "cat"),
        fn_printf: defines_fn(stmts, "printf"),
        fn_echo: defines_fn(stmts, "echo"),
        fn_grep: defines_fn(stmts, "grep"),
    };
    let mut c = false;
    for s in stmts.iter_mut() {
        c |= transform_stmt(s, &ctx);
    }
    c
}

fn st(s: &str) -> IrExpr {
    IrExpr::Str(s.to_string(), StrStyle::DoubleQuoted)
}

/// `exec("cmd", [words…])` — the canonical pre-export exec Call.
fn exec_call(cmd: &str, words: Vec<IrExpr>) -> IrExpr {
    IrExpr::Call {
        func: "exec".to_string(),
        args: vec![st(cmd), IrExpr::Array(words)],
    }
}

/// Status-command exec: `exec("true")` / `exec("false")` render natively
/// on every backend (`$main_exit_code = $CHILD_ERROR = 0|1;` in Perl,
/// `sh2.lastExit = 0|1` in ESTree).
fn status_stmt(ok: bool) -> IrStmt {
    IrStmt::Expr(exec_call(if ok { "true" } else { "false" }, vec![]))
}

// ── walker ───────────────────────────────────────────────────────────

fn transform_stmt(st: &mut IrStmt, ctx: &Ctx) -> bool {
    let mut c = match st {
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
        } => {
            let mut x = transform_expr(cond, ctx);
            x |= transform(then, ctx);
            for (ec, eb) in elsifs.iter_mut() {
                x |= transform_expr(ec, ctx);
                x |= transform(eb, ctx);
            }
            x |= transform(else_, ctx);
            x
        }
        IrStmt::For { iter, body, .. } => {
            let mut x = transform_expr(iter, ctx);
            x |= transform(body, ctx);
            x
        }
        IrStmt::While { cond, body, .. } => {
            let mut x = transform(body, ctx);
            x |= transform_expr(cond, ctx);
            x
        }
        IrStmt::DoWhile { body, cond, .. } => {
            let mut x = transform(body, ctx);
            x |= transform_expr(cond, ctx);
            x
        }
        IrStmt::Case {
            discriminant,
            clauses,
        } => {
            let mut x = transform_expr(discriminant, ctx);
            for cl in clauses.iter_mut() {
                x |= transform(&mut cl.body, ctx);
            }
            x
        }
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b)
        | IrStmt::Function { body: b, .. } => transform(b, ctx),
        IrStmt::Pipeline { stages, .. } => {
            let mut x = false;
            for stg in stages.iter_mut() {
                x |= transform(stg, ctx);
            }
            x
        }
        IrStmt::Expr(e) => {
            let mut x = transform_expr(e, ctx);
            x |= chain_to_if(st, ctx);
            x |= echo_grep_pipeline_to_if(st, ctx);
            x
        }
        IrStmt::Assign { expr, .. } | IrStmt::Output { value: expr, .. } => transform_expr(expr, ctx),
        IrStmt::Declare {
            init: Some(expr), ..
        } => transform_expr(expr, ctx),
        IrStmt::WriteFile { path, content, .. } => transform_expr(path, ctx) | transform_expr(content, ctx),
        IrStmt::Redirect { inner, redirects } => {
            let mut x = transform(inner, ctx);
            for r in redirects.iter_mut() {
                x |= transform_expr(&mut r.target, ctx);
            }
            x |= cat_heredoc_fold(st, ctx);
            x
        }
        IrStmt::Exec {
            cmd, args, env, ..
        } => {
            let mut x = transform_expr(cmd, ctx);
            for a in args.iter_mut() {
                x |= transform_expr(a, ctx);
            }
            for (_, v) in env.iter_mut() {
                x |= transform_expr(v, ctx);
            }
            x
        }
        _ => false,
    };
    c
}

fn transform_expr(e: &mut IrExpr, ctx: &Ctx) -> bool {
    match e {
        IrExpr::Arrow(stmts) => transform(stmts, ctx),
        IrExpr::Call { args, .. } => {
            let mut c = false;
            for a in args.iter_mut() {
                c |= transform_expr(a, ctx);
            }
            c
        }
        IrExpr::Array(items) => {
            let mut c = false;
            for a in items.iter_mut() {
                c |= transform_expr(a, ctx);
            }
            c
        }
        IrExpr::Object(pairs) => {
            let mut c = false;
            for (_, v) in pairs.iter_mut() {
                c |= transform_expr(v, ctx);
            }
            c
        }
        IrExpr::BinOp { lhs, rhs, .. } => transform_expr(lhs, ctx) | transform_expr(rhs, ctx),
        IrExpr::Index { key, .. } => transform_expr(key, ctx),
        _ => false,
    }
}

// ── $? / function-shadow program scans ───────────────────────────────

/// The chain-to-If rewrite is only sound while the chain's false-path
/// status (1) is DEAD: an if/else leaves the previous status on the
/// false path, a `&&`/`||` chain records 1. Any program that reads `$?`
/// anywhere could observe the difference.
fn stmts_read_q(stmts: &[IrStmt]) -> bool {
    stmts.iter().any(stmt_read_q)
}

fn stmt_read_q(s: &IrStmt) -> bool {
    match s {
        IrStmt::Expr(e) => expr_read_q(e),
        IrStmt::Assign { expr, .. } => expr_read_q(expr),
        IrStmt::Output { value, .. } => expr_read_q(value),
        IrStmt::Declare { init, .. } => init.as_ref().map(expr_read_q).unwrap_or(false),
        IrStmt::DeclareArray { elements, .. } => elements.iter().any(expr_read_q),
        IrStmt::WriteFile { path, content, .. } => expr_read_q(path) || expr_read_q(content),
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
        } => {
            expr_read_q(cond)
                || then.iter().any(stmt_read_q)
                || else_.iter().any(stmt_read_q)
                || elsifs
                    .iter()
                    .any(|(c, b)| expr_read_q(c) || b.iter().any(stmt_read_q))
        }
        IrStmt::For { iter, body, .. } => expr_read_q(iter) || body.iter().any(stmt_read_q),
        IrStmt::While { cond, body, .. } => expr_read_q(cond) || body.iter().any(stmt_read_q),
        IrStmt::DoWhile { body, cond, .. } => body.iter().any(stmt_read_q) || expr_read_q(cond),
        IrStmt::Case {
            discriminant,
            clauses,
        } => {
            expr_read_q(discriminant)
                || clauses
                    .iter()
                    .any(|cl| cl.body.iter().any(stmt_read_q))
        }
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b)
        | IrStmt::Function { body: b, .. } => b.iter().any(stmt_read_q),
        IrStmt::Pipeline { stages, .. } => stages.iter().any(|stg| stg.iter().any(stmt_read_q)),
        IrStmt::Redirect { inner, redirects } => {
            inner.iter().any(stmt_read_q)
                || redirects.iter().any(|r| expr_read_q(&r.target))
        }
        IrStmt::Exec {
            cmd, args, env, ..
        } => {
            expr_read_q(cmd)
                || args.iter().any(expr_read_q)
                || env.iter().any(|(_, v)| expr_read_q(v))
        }
        IrStmt::SetChildError(e) => expr_read_q(e),
        IrStmt::Return(Some(e)) => expr_read_q(e),
        IrStmt::Exit(Some(e)) => expr_read_q(e),
        // Unrecognized / raw — conservative: assume a status read.
        _ => true,
    }
}

fn expr_read_q(e: &IrExpr) -> bool {
    match e {
        IrExpr::Str(s, _) => s.contains("$?"),
        IrExpr::Var(n, _) => n == "?",
        IrExpr::Interpolate(parts) => parts.iter().any(|p| match p {
            InterpPart::Lit(s) => s.contains("$?"),
            InterpPart::Expr(x) => expr_read_q(x),
        }),
        IrExpr::Call { args, .. } => {
            args.iter().any(expr_read_q)
                || args.first().map_or(false, |a| matches!(a, IrExpr::Str(s, _) if s == "?"))
        }
        IrExpr::Array(items) => items.iter().any(expr_read_q),
        IrExpr::Object(pairs) => pairs.iter().any(|(_, v)| expr_read_q(v)),
        IrExpr::BinOp { lhs, rhs, .. } => expr_read_q(lhs) || expr_read_q(rhs),
        IrExpr::Index { key, .. } => expr_read_q(key),
        IrExpr::Arrow(stmts) => stmts.iter().any(stmt_read_q),
        IrExpr::Capture { expr, .. } => expr_read_q(expr),
        IrExpr::MethodCall { obj, args, .. } => expr_read_q(obj) || args.iter().any(expr_read_q),
        IrExpr::Ternary { cond, then, else_ } => {
            expr_read_q(cond) || expr_read_q(then) || expr_read_q(else_)
        }
        IrExpr::DefinedOr { expr, default } => expr_read_q(expr) || expr_read_q(default),
        IrExpr::Splice(x) => expr_read_q(x),
        IrExpr::ArrayComp { body, .. } => body.iter().any(stmt_read_q),
        IrExpr::Lambda { body, .. } => body.iter().any(stmt_read_q),
        // Nothing else carries a `$?` read (arith, raw, regex, int, bool,
        // ident, json, range, nested arith).
        _ => false,
    }
}

/// Does the program define a (top-level or nested) function `name`?
/// Bash resolves `cmd` to a shell function before any builtin/external —
/// a fold that replaces `cat`/`echo`/`printf`/`grep` with a native twin
/// would silently bypass the function.
fn defines_fn(stmts: &[IrStmt], name: &str) -> bool {
    stmts.iter().any(|s| match s {
        IrStmt::Function {
            name: n, body, ..
        } => n == name || defines_fn(body, name),
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b) => defines_fn(b, name),
        IrStmt::If {
            then,
            elsifs,
            else_,
            ..
        } => {
            defines_fn(then, name)
                || defines_fn(else_, name)
                || elsifs.iter().any(|(_, b)| defines_fn(b, name))
        }
        IrStmt::For { body, .. } => defines_fn(body, name),
        IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => defines_fn(body, name),
        IrStmt::Case { clauses, .. } => clauses.iter().any(|c| defines_fn(&c.body, name)),
        IrStmt::Pipeline { stages, .. } => stages.iter().any(|stg| defines_fn(stg, name)),
        IrStmt::Redirect { inner, .. } => defines_fn(inner, name),
        _ => false,
    })
}

// ── Family 1: cat heredoc / herestring → printf %s twin ──────────────

/// The `exec`/`builtin` word-args of a canonical command Call.
fn call_parts(e: &IrExpr) -> Option<(&str, &[IrExpr])> {
    if let IrExpr::Call { func, args } = e {
        match args.as_slice() {
            [IrExpr::Str(cmd, _), IrExpr::Array(words)] => Some((cmd.as_str(), words)),
            [IrExpr::Ident(cmd), IrExpr::Array(words)] => Some((cmd.as_str(), words)),
            _ => None,
        }
    } else {
        None
    }
}

/// A static string (Str or all-literal Interpolate) → its text.
fn static_text(e: &IrExpr) -> Option<String> {
    match e {
        IrExpr::Str(s, _) => Some(s.clone()),
        IrExpr::Interpolate(parts) => {
            let mut out = String::new();
            for p in parts {
                match p {
                    InterpPart::Lit(s) => out.push_str(s),
                    InterpPart::Expr(_) => return None,
                }
            }
            Some(out)
        }
        _ => None,
    }
}

/// Family 1 fold:
///   `Redirect{inner:[exec cat], [fd0 heredoc|heredoc-tabs|herestring]}`
///     → `exec printf %s <content>`
///   `Redirect{inner:[exec cat], [fd0 heredoc…, fd1 w|a <file>]}`
///     → `Redirect{inner:[Block([exec printf %s <content>])], [fd1 w|a <file>]}`
fn cat_heredoc_fold(st: &mut IrStmt, ctx: &Ctx) -> bool {
    if ctx.fn_cat || ctx.fn_printf {
        return false;
    }
    let IrStmt::Redirect { inner, redirects } = st else {
        return false;
    };
    let [IrStmt::Expr(inner_call)] = inner.as_slice() else {
        return false;
    };
    let (name, cat_words) = match call_parts(inner_call) {
        Some(p) => p,
        None => return false,
    };
    if name != "cat" {
        return false;
    }
    // cat with no args, or the bare stdin marker — both read fd 0 only.
    let cat_ok = cat_words.is_empty()
        || matches!(cat_words, [IrExpr::Str(s, _)] if s == "-");
    if !cat_ok {
        return false;
    }
    // Split the specs: one fd-0 heredoc-family spec; everything else must
    // be at most one fd-1 file spec.
    let mut heredoc: Option<&IrRedirect> = None;
    let mut others: Vec<&IrRedirect> = Vec::new();
    for r in redirects {
        let fd = r.fd.unwrap_or(0);
        if fd == 0 && matches!(r.mode.as_str(), "heredoc" | "heredoc-tabs" | "herestring") {
            if heredoc.is_some() {
                return false; // two input specs — refuse
            }
            heredoc = Some(r);
        } else {
            others.push(r);
        }
    }
    let Some(h) = heredoc else {
        return false;
    };
    let content = match heredoc_content(h) {
        Some(c) => c,
        None => return false,
    };
    // The printf %s twin — `printf %s "$content"` writes the content
    // verbatim (no added newline, no escape processing), exit 0 — the
    // exact cat-on-heredoc contract. Both renderers lower it in-process:
    // Perl's emit_exec_call printf arm, the ESTree printf-fold /
    // runtime builtin.
    let print = IrStmt::Expr(exec_call("printf", vec![st("%s"), st(&content)]));
    match others.as_slice() {
        [] => {
            // stdout fold: replace the redirect with the plain print.
            *st = print;
            true
        }
        [o] => {
            // file fold: keep the fd-1 file redirect; the Block-wrapped
            // inner is NOT shell-rebuildable, so the Perl renderer's
            // native select()-based file-redirect arm fires.
            if o.fd.unwrap_or(1) != 1 {
                return false;
            }
            if !matches!(o.mode.as_str(), "w" | "wc" | "a") {
                return false;
            }
            let target = match static_text(&o.target) {
                Some(t) => t,
                None => return false, // dynamic target — REFUSE
            };
            if target.starts_with('&') || target.is_empty() {
                return false;
            }
            *st = IrStmt::Redirect {
                inner: vec![IrStmt::Block(vec![print])],
                redirects: vec![IrRedirect {
                    fd: Some(1),
                    mode: o.mode.clone(),
                    target: o.target.clone(),
                    interpolate: o.interpolate,
                }],
            };
            true
        }
        _ => false,
    }
}

/// The folded heredoc/herestring content. `None` = not statically
/// foldable (REFUSE).
fn heredoc_content(h: &IrRedirect) -> Option<String> {
    let body = static_text(&h.target)?;
    match h.mode.as_str() {
        "heredoc" | "heredoc-tabs" => {
            // An UNQUOTED heredoc body is expanded by the shell; the fold
            // is identity only when none of expandWord's triggers appear.
            if h.interpolate && body.chars().any(|c| matches!(c, '$' | '`' | '\\')) {
                return None;
            }
            if h.mode == "heredoc-tabs" {
                // `<<-EOF`: the runtime strips leading TABS per line
                // (before expansion — identity here, the estree twin's
                // exact transform).
                return Some(
                    body.split('\n')
                        .map(|l| l.trim_start_matches('\t'))
                        .collect::<Vec<_>>()
                        .join("\n"),
                );
            }
            Some(body)
        }
        "herestring" => {
            // `cat <<< 'x'`: the runtime feeds `x\n` — append the
            // terminator the herestring always adds.
            let mut t = body;
            t.push('\n');
            Some(t)
        }
        _ => None,
    }
}

// ── Family 2: `test && echo` / `test || echo` → If ───────────────────

/// `test-cond && echo/printf` → `If{cond, then:[echo/printf]}`
/// `test-cond || echo/printf` → `If{cond, else:[echo/printf]}`
///
/// The single-arm forms of the AND-OR chain (`shir-native-stmt` handles
/// the full `test && always || always`). Sound only while `$?` is DEAD
/// program-wide (the chain records 1 on the false path; the If leaves
/// the predecessor's status).
fn chain_to_if(st: &mut IrStmt, ctx: &Ctx) -> bool {
    if ctx.reads_dollar_question {
        return false;
    }
    if ctx.fn_echo || ctx.fn_printf {
        return false;
    }
    let IrStmt::Expr(IrExpr::BinOp { op, lhs, rhs }) = st else {
        return false;
    };
    let (is_and, cond, arm) = match op {
        BinOpKind::And => (true, lhs, rhs),
        BinOpKind::Or => (false, lhs, rhs),
        _ => return false,
    };
    // The condition must be a PURE test tree (leaves are `test` calls) —
    // a command that fails differently would change the arm decision.
    if !is_pure_test_tree(cond) {
        return false;
    }
    let arm = single_always_true(arm)?;
    if is_and {
        *st = IrStmt::If {
            cond: (**cond).clone(),
            then: vec![arm],
            elsifs: vec![],
            else_: vec![],
        };
    } else {
        *st = IrStmt::If {
            cond: (**cond).clone(),
            then: vec![],
            elsifs: vec![],
            else_: vec![arm],
        };
    }
    true
}

/// The chain arm must be a single always-success builtin exec (echo or
/// printf — status 0 on every path, so the `|| else` short-circuits
/// exactly like the if/else form).
fn single_always_true(e: &IrExpr) -> Option<IrStmt> {
    let (cmd, _) = call_parts(e)?;
    if matches!(cmd, "echo" | "printf") {
        return Some(IrStmt::Expr(e.clone()));
    }
    None
}

/// A pure test-expression tree: every leaf is a `test` Call; combinators
/// are And/Or/Not BinOps. Side-effect-free by construction (a `test`
/// call is a pure comparison over its string operands; anything else —
/// exec/capture/pipeline/redirect/arith-with-call — refuses).
fn is_pure_test_tree(e: &IrExpr) -> bool {
    match e {
        IrExpr::Call { func, args } => {
            if func != "test" {
                return false;
            }
            // the operands must be static text (no nested commands)
            args.iter().all(|a| match a {
                IrExpr::Str(..) | IrExpr::Interpolate(_) => true,
                _ => false,
            })
        }
        IrExpr::BinOp { op, lhs, rhs } => {
            matches!(op, BinOpKind::And | BinOpKind::Or | BinOpKind::Not)
                && is_pure_test_tree(lhs)
                && is_pure_test_tree(rhs)
        }
        _ => false,
    }
}

// ── Family 3: statement `echo <arg> | grep <literal>` → If ───────────

/// `echo <arg> | grep <pat>` — the pipeline's single-line identity:
/// grep prints the line (the one arg) exactly when it contains the
/// literal pattern. Twin: `If{contains(arg, pat), then:[echo arg],
/// else:[exec false]}` — bytes + status identical (grep 0/1). Only for
/// static single-line args and literal-safe patterns; the arg must be a
/// single line because grep matches PER LINE while `contains` matches
/// anywhere in the whole string.
fn echo_grep_pipeline_to_if(st: &mut IrStmt, ctx: &Ctx) -> bool {
    if ctx.fn_echo || ctx.fn_grep || ctx.fn_printf {
        return false;
    }
    let IrStmt::Expr(IrExpr::Call { func, args }) = st else {
        return false;
    };
    if func != "pipeline" {
        return false;
    }
    let stages: Vec<&IrExpr> = match args.as_slice() {
        [IrExpr::Array(elems)] if !elems.is_empty() => elems.iter().collect(),
        _ => return false,
    };
    let [s1, s2] = stages.as_slice() else {
        return false;
    };
    // stage 1: echo with exactly one word.
    let arg = match single_stage_exec(s1) {
        Some((cmd, words)) if cmd == "echo" => match words {
            [w] => w.clone(),
            _ => return false,
        },
        _ => return false,
    };
    // the arg must be a static SINGLE LINE (a variable could hold
    // embedded newlines; grep would match per line, contains would not).
    let arg_text = match static_text(&arg) {
        Some(t) if !t.contains('\n') => t,
        _ => return false,
    };
    // stage 2: grep with exactly one word (a literal pattern).
    let pat = match single_stage_exec(s2) {
        Some((cmd, words)) if cmd == "grep" => match words {
            [w] => w.clone(),
            _ => return false,
        },
        _ => return false,
    };
    let pat_text = static_text(&pat)?;
    if !safe_grep_literal(&pat_text) {
        return false;
    }
    *st = IrStmt::If {
        cond: IrExpr::Call {
            func: "contains".to_string(),
            args: vec![arg, pat],
        },
        then: vec![IrStmt::Expr(exec_call("echo", vec![st(&arg_text)]))],
        elsifs: vec![],
        // grep's failure status is 1 — reproduce it natively.
        else_: vec![status_stmt(false)],
    };
    true
}

/// A one-command Arrow stage: `Arrow([Expr(exec/builtin cmd words)])`.
fn single_stage_exec(arrow: &IrExpr) -> Option<(&str, &[IrExpr])> {
    let IrExpr::Arrow(stmts) = arrow else {
        return None;
    };
    let [IrStmt::Expr(call)] = stmts.as_slice() else {
        return None;
    };
    call_parts(call)
}

/// A grep pattern is substring-liftable only when grep would treat it as
/// a literal: no BRE metacharacters (`^ $ . [ ] * \`), no leading `-`
/// (would parse as an option), no real newline (grep matches within a
/// single line; a substring test would cross boundaries). BRE treats
/// `+ ? ( ) { } |` as literals, so they are safe. Not empty (an empty
/// pattern matches every line — indistinguishable here, but refuse to
/// keep the identity obvious).
fn safe_grep_literal(pat: &str) -> bool {
    !pat.is_empty()
        && !pat.starts_with('-')
        && !pat
            .chars()
            .any(|c| matches!(c, '^' | '$' | '.' | '[' | ']' | '*' | '\\' | '\n'))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::commands::parse_commands_from_text;
    use crate::shir::ast_to_ir_raw;
    use crate::shir_json::shir_to_shir_json;

    /// Lower + run the transform + serialize to compact JSON.
    fn lower(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        let _ = transform(&mut prog.stmts);
        shir_to_shir_json(&prog)
    }

    /// Lower + transform + render Perl — used to assert the shell-out is
    /// gone from the rendered output.
    fn render_perl(src: &str) -> (String, String) {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        (shir_to_perl(&prog), changed.to_string())
    }

    fn assert_no_shellout(src: &str) {
        let (perl, changed) = render_perl(src);
        assert_eq!(changed, "true", "transform was a no-op for {src}");
        assert!(
            !perl.contains("system('bash', '-c'"),
            "rendered perl still shells out for {src}:\n{perl}"
        );
    }

    #[test]
    fn cat_heredoc_folds_to_print() {
        // the canonical twin: bash `cat <<EOF` prints the body verbatim.
        let json = lower("cat <<EOF\nhello\nEOF\n");
        assert!(!json.contains("\"heredoc\""), "heredoc redirect gone: {json}");
        assert!(!json.contains("\"cat\""), "cat exec gone: {json}");
        assert!(json.contains("\"printf\""), "printf twin present: {json}");
        assert!(json.contains("hello\\n"), "body preserved: {json}");
        assert_no_shellout("cat <<EOF\nhello\nEOF\n");
    }

    #[test]
    fn cat_herestring_folds_with_newline() {
        // `cat <<< 'x'` feeds `x\n` — the twin must carry the terminator.
        let json = lower("cat <<< 'hello'");
        assert!(json.contains("\"printf\""));
        assert!(json.contains("hello\\n"), "herestring newline kept: {json}");
        assert_no_shellout("cat <<< 'hello'");
    }

    #[test]
    fn cat_quoted_heredoc_verbatim() {
        // `<<'EOF'` — no expansion; `$`/backticks are literal text.
        let json = lower("cat <<'EOF'\n$a $(cmd) `t`\nEOF\n");
        assert!(json.contains("\"printf\""), "quoted heredoc folds: {json}");
    }

    #[test]
    fn unquoted_heredoc_with_expansion_refused() {
        // `<<EOF` with `$name` — the runtime would expand; REFUSE.
        let commands = parse_commands_from_text("cat <<EOF\nHello $name\nEOF\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "expanding heredoc must be untouched");
        assert!(!changed);
    }

    #[test]
    fn cat_heredoc_to_file_folds() {
        // `cat <<EOF > out` — the fd-1 file redirect survives, the
        // heredoc is folded into the Block-wrapped printf.
        let json = lower("cat <<EOF > /tmp/sh2twin_out.txt\ncontent\nEOF\n");
        let _ = std::fs::remove_file("/tmp/sh2twin_out.txt");
        assert!(json.contains("\"Redirect\""), "file redirect kept: {json}");
        assert!(!json.contains("\"heredoc\""), "heredoc spec gone: {json}");
        assert!(json.contains("\"printf\""));
        let (perl, _) = render_perl("cat <<EOF > /tmp/sh2twin_out.txt\ncontent\nEOF\n");
        assert!(
            !perl.contains("system('bash', '-c'"),
            "file-heredoc must render native:\n{perl}"
        );
    }

    #[test]
    fn cat_heredoc_with_cat_args_refused() {
        // `cat -n <<EOF` reads stdin but also prints line numbers — the
        // verbatim twin would not. REFUSE.
        let commands = parse_commands_from_text("cat -n <<EOF\nx\nEOF\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after);
        assert!(!changed);
    }

    #[test]
    fn cat_heredoc_with_fd2_refused() {
        // `cat <<EOF 2>err` — stderr redirect not expressible by the twin.
        let commands =
            parse_commands_from_text("cat <<EOF 2>/tmp/sh2twin_err.txt\nx\nEOF\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed);
    }

    #[test]
    fn chain_and_echo_becomes_if() {
        let json = lower("[[ $s == *.txt ]] && echo pattern-match");
        assert!(json.contains("\"If\""), "chain becomes If: {json}");
        assert!(!json.contains("\"echo pattern-match\""), "no rebuildable text");
        assert_no_shellout("[[ $s == *.txt ]] && echo pattern-match");
    }

    #[test]
    fn chain_or_echo_becomes_if_else() {
        let json = lower("[[ $f == *.min.js ]] || echo filtered");
        assert!(json.contains("\"If\""));
        assert!(json.contains("\"else\""));
        assert_no_shellout("[[ $f == *.min.js ]] || echo filtered");
    }

    #[test]
    fn chain_of_two_tests_echo_becomes_if() {
        let json = lower("[[ -n \"$f\" ]] && [[ -f \"$f\" ]] && echo \"File exists\"");
        assert!(json.contains("\"If\""));
        assert_no_shellout("[[ -n \"$f\" ]] && [[ -f \"$f\" ]] && echo \"File exists\"");
    }

    #[test]
    fn chain_with_dollar_question_refused() {
        // `$?` is live — the false-path status (1) would be lost.
        let commands =
            parse_commands_from_text("true\n[ \"$?\" = \"0\" ] && echo status-zero\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed, "live-$? chain must be untouched");
    }

    #[test]
    fn chain_with_fallible_arm_refused() {
        // `test && cat file` — cat can fail; the `&&` chain would skip
        // the next arm differently from an if.
        let commands =
            parse_commands_from_text("[ -f x ] && cat x\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed);
    }

    #[test]
    fn echo_grep_pipeline_becomes_contains_if() {
        let json = lower("echo \"alpha beta\" | grep beta");
        assert!(json.contains("\"contains\""), "contains node: {json}");
        assert!(json.contains("\"If\""));
        assert!(json.contains("\"false\""), "failure arm status: {json}");
        assert_no_shellout("echo \"alpha beta\" | grep beta");
    }

    #[test]
    fn echo_grep_with_flags_refused() {
        // `grep -m 2` changes output; `grep -i` changes matching.
        let commands =
            parse_commands_from_text("echo hello | grep -i HELLO\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed);
    }

    #[test]
    fn echo_grep_metachar_pattern_refused() {
        let commands = parse_commands_from_text("echo a.b | grep a.b\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed, "BRE dot pattern must keep the shell-out");
    }

    #[test]
    fn echo_multiline_arg_refused() {
        let commands = parse_commands_from_text("echo -e \"a\\nb\" | grep b\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let changed = transform(&mut prog.stmts);
        assert!(!changed, "multiline echo arg must keep the shell-out");
    }

    #[test]
    fn unrelated_exec_untouched() {
        let commands = parse_commands_from_text("echo hello\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(!transform(&mut prog.stmts), "plain echo is a no-op");
    }

    #[test]
    fn deterministic_across_runs() {
        let src = "cat <<EOF\nbody\nEOF\n[[ $s == *.txt ]] && echo hit\necho \"a b\" | grep b\n";
        assert_eq!(lower(src), lower(src));
    }
}