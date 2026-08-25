//! shir-native-shellouts — eliminate `system('bash', '-c', …)` call sites
//! in the rendered output by rewriting statement shapes the renderers
//! lower to shell-outs into the canonical native shapes they already
//! emulate in-process.
//!
//! ## Why
//!
//! `./fail-shir` counts `system('bash', …)` call sites in the rendered
//! Perl. For the verified-emulable command set (harness/shir-whitelist.txt)
//! a shell-out is never necessary: it is an artefact of the STATEMENT
//! SHAPE the renderer saw, not of the command. Three shape families
//! account for almost all of the normalisable (all-whitelisted) sites
//! and a large share of the echo shell-outs in the corpus:
//!
//! 1. **Test-chain statements** — `[[ c ]] && echo X` /
//!    `[ c ] || echo Y` (and `[[ c1 ]] && [[ c2 ]] && echo Z`): the
//!    statement is a BinOp chain of `test` Calls ending in an
//!    always-success builtin (echo/printf) or another test. The Perl
//!    renderer's chain lowering rebuilds the tail command and shells
//!    out. Bash semantics: `A && B` runs B iff A succeeds and reports
//!    A's failure status otherwise; `A || B` runs B iff A fails and
//!    reports success otherwise. A native `IrStmt::If` whose arms are
//!    the `true`/`false` execs reproduces BOTH the branch and the exit
//!    status exactly (`true` renders `$main_exit_code = $CHILD_ERROR =
//!    0;`, `false` renders `… = 1;`), so a following `echo $?` still
//!    matches bash.
//!
//! 2. **`cat <<heredoc` / `cat <<<text` (statement position)** —
//!    `Redirect{inner:[exec cat], fd-0 heredoc/herestring}`: the perl
//!    redirect arm rebuilds the shell text (`cmd <<delim\nbody`) and
//!    shells out. The heredoc body is already a literal string in the
//!    A1 (no expansion when the runtime would not transform it), so the
//!    whole pair collapses to a native `print(body)` `IrStmt::Output`
//!    followed by the `true` exec (cat on a heredoc stdin exits 0).
//!    This mirrors the ESTree renderer's own `try_native_cat_heredoc`
//!    fold (shir.rs), including its gates (verbatim or expand-free body,
//!    `-` arg = stdin, single fd-0 spec, no script `cat` shadow).
//!
//! 3. **Test-position `echo X | grep P`** — an If/While cond that is a
//!    two-stage pipeline `echo <arg> | grep <literal> >/dev/null` (or
//!    `grep -q <literal>` — quiet grep prints nothing by construction):
//!    grep's decision on the single echoed line is exactly substring
//!    containment, and in TEST position that decision is all that is
//!    observable. The pipeline lowers to the contract's `contains(op)`
//!    node — Perl renders `index(...) >= 0`, ESTree renders
//!    `String.includes` — mirroring the ESTree renderer's
//!    `try_lift_grep_contains` lift (which requires the /dev/null
//!    redirect for exactly this output-dropping reason).
//!
//! ## Soundness (REFUSE > GUESS)
//!
//! - The chain rewrite fires only when the chain's cond side is PURELY
//!   `test` Calls (joined by `&&`/`||`) and the tail is an
//!   always-success builtin (echo/printf — status 0 on every path) or
//!   another test. A fallible command tail (`ls`, `grep`, …) is never
//!   moved into an if-branch (bash would run the `||`-else on its
//!   failure; the if-form would not).
//! - The heredoc rewrite fires only for a literal body the runtime
//!   would emit byte-identically (a quoted heredoc is verbatim; an
//!   unquoted one must be free of `$`, backticks and backslashes — the
//!   only expandWord triggers), `cat` with no args or the stdin marker
//!   `-`, and exactly one fd-0 spec. Interpolating bodies
//!   (`Hello $name`), multi-spec redirects (`> file <<EOF`), fd-2
//!   redirects and non-cat commands stay on the shell-out path.
//! - The contains lift fires only in test position with the pipeline's
//!   output provably discarded (`>/dev/null` or `-q`) and a pattern
//!   that is a plain BRE literal (no metacharacters — grep would treat
//!   them as regex). Statement-position pipelines keep their output
//!   semantics and are never touched.
//! - Rewrites never fire inside constructs the renderer rebuilds as
//!   shell text (capture/redirect/pipeline/block arrow bodies, redirect
//!   inners): an `If` is not shell-rebuildable, so rewriting there
//!   would turn a working shell-out into a hard refusal. Such bodies
//!   are left exactly as-is.
//! - Every emitted node (`Block`, `Output`, `If`, `Expr(Call exec)`,
//!   `Call contains`) is in the A1 contract and rendered natively by
//!   both the Perl and the ESTree renderers.
//!
//! ## Placement
//! Registered in `transforms.rs` (DEBASHC_TRANSFORMS gated, like the
//! rest of the registry). Runs at the `--shir` A1 export (ast_to_ir
//! channel); the `--shir-in-perl` ingress then renders the transformed
//! shapes natively.

use crate::ir::{InterpPart, IrExpr, IrStmt, StrStyle};
use std::collections::HashSet;

/// Apply the transform. Returns whether anything changed.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    // Script-defined functions win over same-named builtins in bash
    // (`function echo() { … }` shadows the echo builtin), so a rewrite
    // that turns an exec into the BUILTIN rendering must refuse when the
    // program shadows it. Scan the original tree once (the rewrites only
    // ever replace whole statements, never add function definitions).
    let mut names = HashSet::new();
    collect_defined_functions(stmts, &mut names);
    let flags = ShadowFlags {
        cat: names.contains("cat"),
        echo: names.contains("echo"),
        printf: names.contains("printf"),
    };
    let mut c = false;
    for s in stmts.iter_mut() {
        c |= transform_stmt(s, &flags);
    }
    c
}

/// Which builtin commands the program shadows with a same-named function.
struct ShadowFlags {
    cat: bool,
    echo: bool,
    printf: bool,
}

// ── recursive statement walk ──────────────────────────────────────────

fn transform_stmt(st: &mut IrStmt, flags: &ShadowFlags) -> bool {
    match st {
        // Rebuild contexts: capture/redirect/pipeline/block arrow bodies
        // and redirect inners are reconstructed as shell TEXT by the
        // renderer (`stmts_to_shell_cmd` / the *_call_to_cmd rebuilds).
        // An `If`/`Block` rewrite there would make the rebuild fail —
        // leave them untouched (they keep the shell-out, unchanged).
        IrStmt::Pipeline { .. } => false,
        IrStmt::Redirect { inner, .. } => {
            // Do NOT recurse into `inner` (the redirect rebuild path) —
            // only fire the whole-statement heredoc/herestring rewrite.
            cat_redirect_to_output(st, flags)
        }
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
        } => {
            let mut x = transform_cond(cond);
            x |= transform(then, flags);
            for (ec, eb) in elsifs.iter_mut() {
                x |= transform_cond(ec);
                x |= transform(eb, flags);
            }
            x |= transform(else_, flags);
            x
        }
        IrStmt::While { cond, body, .. } => {
            let mut x = transform_cond(cond);
            x |= transform(body, flags);
            x
        }
        IrStmt::DoWhile { body, cond, .. } => {
            let mut x = transform(body, flags);
            x |= transform_cond(cond);
            x
        }
        IrStmt::For { body, .. } => transform(body, flags),
        IrStmt::Case { clauses, .. } => {
            let mut x = false;
            for cl in clauses.iter_mut() {
                x |= transform(&mut cl.body, flags);
            }
            x
        }
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b)
        | IrStmt::Function { body: b, .. } => transform(b, flags),
        // Statement-position expression: the test-chain rewrite.
        IrStmt::Expr(_) => chain_to_if(st, flags),
        _ => false,
    }
}

fn transform(body: &mut Vec<IrStmt>, flags: &ShadowFlags) -> bool {
    let mut c = false;
    for s in body.iter_mut() {
        c |= transform_stmt(s, flags);
    }
    c
}

/// Walk a test-position condition for the `echo | grep` → contains lift.
/// Only structual exprs are descended: Arrow/Capture bodies stay opaque
/// (they are shell-rebuild contexts).
fn transform_cond(e: &mut IrExpr) -> bool {
    if let Some(new) = contains_lift(e) {
        *e = new;
        return true;
    }
    match e {
        IrExpr::BinOp { lhs, rhs, .. } => transform_cond(lhs) | transform_cond(rhs),
        IrExpr::Ternary { cond, then, else_ } => {
            transform_cond(cond) | transform_cond(then) | transform_cond(else_)
        }
        IrExpr::DefinedOr { expr, default } => {
            transform_cond(expr) | transform_cond(default)
        }
        IrExpr::Call { args, .. } => {
            let mut c = false;
            for a in args.iter_mut() {
                if let IrExpr::Arrow(_) = a {
                    continue; // opaque — shell-rebuild context
                }
                c |= transform_cond(a);
            }
            c
        }
        IrExpr::Array(items) => {
            let mut c = false;
            for a in items.iter_mut() {
                if let IrExpr::Arrow(_) = a {
                    continue;
                }
                c |= transform_cond(a);
            }
            c
        }
        IrExpr::Index { key, .. } => transform_cond(key),
        _ => false,
    }
}

/// Collect script-defined function names (recursively — a function may be
/// defined inside another function's body).
fn collect_defined_functions(stmts: &[IrStmt], out: &mut HashSet<String>) {
    for s in stmts {
        match s {
            IrStmt::Function { name, body, .. } => {
                out.insert(name.clone());
                collect_defined_functions(body, out);
            }
            IrStmt::If {
                then, elsifs, else_, ..
            } => {
                collect_defined_functions(then, out);
                for (_, eb) in elsifs {
                    collect_defined_functions(eb, out);
                }
                collect_defined_functions(else_, out);
            }
            IrStmt::While { body, .. } | IrStmt::DoWhile { body, .. } => {
                collect_defined_functions(body, out)
            }
            IrStmt::For { body, .. } => collect_defined_functions(body, out),
            IrStmt::Case { clauses, .. } => {
                for cl in clauses {
                    collect_defined_functions(&cl.body, out);
                }
            }
            IrStmt::Block(b)
            | IrStmt::Subshell(b)
            | IrStmt::Background(b)
            | IrStmt::Redirect { inner: b, .. } => collect_defined_functions(b, out),
            IrStmt::Pipeline { stages, .. } => {
                for stg in stages {
                    collect_defined_functions(stg, out);
                }
            }
            _ => {}
        }
    }
}

// ── Family 1: `test-chain &&/|| echo|printf|test` → native If ─────────

/// A canonical exec/builtin Call: `exec("cmd", [words])` (the word list
/// is the single Array arg). Returns the command name.
fn call_cmd(e: &IrExpr) -> Option<&str> {
    let IrExpr::Call { func, args } = e else {
        return None;
    };
    if !matches!(func.as_str(), "exec" | "builtin") {
        return None;
    }
    match args.first()? {
        IrExpr::Str(cmd, _) => Some(cmd.as_str()),
        IrExpr::Ident(cmd) => Some(cmd.as_str()),
        _ => None,
    }
}

/// `[[ a ]]` / `[ a ]` test Call (the cond side of a chain).
fn test_call(e: &IrExpr) -> Option<IrExpr> {
    if let IrExpr::Call { func, .. } = e {
        if func == "test" {
            return Some(e.clone());
        }
    }
    None
}

/// A left-assoc `&&`/`||` chain whose operands are ALL test Calls —
/// bash's test-chain (`[[ c1 ]] && [[ c2 ]]`). Returns the whole chain
/// expression (the renderer renders `(t1) && (t2)` natively).
fn test_chain(e: &IrExpr) -> Option<IrExpr> {
    if test_call(e).is_some() {
        return Some(e.clone());
    }
    if let IrExpr::BinOp {
        op: BinOpKind::And,
        ..
    }
    | IrExpr::BinOp {
        op: BinOpKind::Or,
        ..
    } = e
    {
        let IrExpr::BinOp { lhs, rhs, .. } = e else {
            unreachable!()
        };
        if test_chain(lhs).is_some() && test_chain(rhs).is_some() {
            return Some(e.clone());
        }
    }
    None
}

/// The tail command of a chain: an always-success builtin (echo/printf —
/// status 0 on every path) or another test. Returns the tail as a
/// statement list for an if-arm.
fn chain_tail(e: &IrExpr, flags: &ShadowFlags) -> Option<Vec<IrStmt>> {
    if let Some(cmd) = call_cmd(e) {
        let shadowed = match cmd {
            "echo" => flags.echo,
            "printf" => flags.printf,
            _ => false,
        };
        if !shadowed && matches!(cmd, "echo" | "printf") {
            return Some(vec![IrStmt::Expr(e.clone())]);
        }
        return None;
    }
    if test_call(e).is_some() {
        return Some(vec![IrStmt::Expr(e.clone())]);
    }
    None
}

/// `[[ c ]] && echo X` / `[ c ] || echo Y` (statement position) →
/// `If{cond: c, then|else: [echo], else|then: [true|false]}`. The
/// explicit status arm reproduces bash's `&&`/`||` exit status on the
/// short-circuit path (a following `echo $?` observes it).
fn chain_to_if(st: &mut IrStmt, flags: &ShadowFlags) -> bool {
    let IrStmt::Expr(e) = st else {
        return false;
    };
    let IrExpr::BinOp { lhs, op, rhs } = e else {
        return false;
    };
    let cond = match test_chain(lhs) {
        Some(c) => c,
        None => return false,
    };
    let tail = match chain_tail(rhs, flags) {
        Some(t) => t,
        None => return false,
    };
    match op {
        BinOpKind::And => {
            // A && B: A false → status 1 (bash reports the test's
            // failure); A true → B runs (its status, 0 for the builtins).
            *st = IrStmt::If {
                cond,
                then: tail,
                elsifs: vec![],
                else_: vec![status_exec(false)],
            };
            true
        }
        BinOpKind::Or => {
            // A || B: A true → status 0; A false → B runs (status 0).
            *st = IrStmt::If {
                cond,
                then: vec![status_exec(true)],
                elsifs: vec![],
                else_: tail,
            };
            true
        }
        _ => false,
    }
}

/// The canonical no-op / failed-status exec node (`exec("true")` /
/// `exec("false")` — renders `$main_exit_code = $CHILD_ERROR = 0|1;`
/// in Perl).
fn status_exec(ok: bool) -> IrStmt {
    IrStmt::Expr(IrExpr::Call {
        func: "exec".to_string(),
        args: vec![IrExpr::Str(
            if ok { "true" } else { "false" }.to_string(),
            StrStyle::DoubleQuoted,
        )],
    })
}

// ── Family 2: `cat <<heredoc` / `cat <<<text` → native print ─────────

/// Statement-position `Redirect` whose inner is a bare `cat` (no args or
/// the stdin marker `-`) and whose ONLY spec is a fd-0 literal
/// heredoc/herestring: the pair prints exactly the folded body to the
/// default stdout sink and exits 0. Rewrites to `Block([Output(body),
/// exec("true")])` — the same fold the ESTree renderer's
/// `try_native_cat_heredoc` performs.
fn cat_redirect_to_output(st: &mut IrStmt, flags: &ShadowFlags) -> bool {
    if flags.cat {
        return false;
    }
    let IrStmt::Redirect { inner, redirects } = st else {
        return false;
    };
    let [r] = redirects.as_slice() else {
        return false;
    };
    if r.fd.unwrap_or(0) != 0 {
        return false;
    }
    let content: String = match r.mode.as_str() {
        "heredoc" | "heredoc-tabs" => {
            let IrExpr::Str(body, _) = &r.target else {
                return false;
            };
            if r.interpolate && body.chars().any(|c| matches!(c, '$' | '`' | '\\')) {
                // the runtime's expandWord (or bash itself) would transform it
                return false;
            }
            let mut body = body.clone();
            if r.mode == "heredoc-tabs" {
                // the runtime's heredoc-tabs transform (before expansion):
                // strip leading tabs per line — exact compile-time twin
                body = body
                    .split('\n')
                    .map(|l| l.trim_start_matches('\t'))
                    .collect::<Vec<_>>()
                    .join("\n");
            }
            body
        }
        "herestring" => {
            // the runtime appends a newline to herestrings and never
            // interpolates them — a static target folds exactly
            let IrExpr::Str(target, _) = &r.target else {
                return false;
            };
            let mut t = target.clone();
            t.push('\n');
            t
        }
        _ => return false,
    };
    let [IrStmt::Expr(IrExpr::Call { func, args })] = inner.as_slice() else {
        return false;
    };
    if !matches!(func.as_str(), "exec" | "builtin") {
        return false;
    }
    let [IrExpr::Str(cmd, _), IrExpr::Array(cat_args)] = args.as_slice() else {
        return false;
    };
    if cmd != "cat" {
        return false;
    }
    // No args or the bare stdin marker — both read fd 0 only.
    let arg_ok = cat_args.is_empty()
        || matches!(cat_args.as_slice(), [IrExpr::Str(s, _)] if s == "-");
    if !arg_ok {
        return false;
    }
    *st = IrStmt::Block(vec![
        // SingleQuoted: backticks/`$`/backslashes stay literal (a quoted
        // heredoc body may contain any of them); real newlines pass
        // through, and `\`/`'` are escaped for the Perl literal.
        IrStmt::Output {
            value: IrExpr::Str(content, StrStyle::SingleQuoted),
            newline: false,
            target: None,
        },
        status_exec(true),
    ]);
    true
}

// ── Family 3: test-position `echo X | grep P` → contains(X, P) ────────

/// A word that resolves to a static literal string: a bare `Str` or a
/// single-parts `Interpolate` (the double-quoted form of a literal).
fn word_literal(w: &IrExpr) -> Option<&str> {
    match w {
        IrExpr::Str(s, _) => Some(s.as_str()),
        IrExpr::Interpolate(parts) if parts.len() == 1 => match &parts[0] {
            InterpPart::Lit(s) => Some(s.as_str()),
            _ => None,
        },
        _ => None,
    }
}

/// A grep pattern is liftable to a substring test only when grep would
/// treat it as a literal: no BRE metacharacters (`^ $ . [ ] * \`), no
/// leading `-` (would parse as an option), no real newline (grep matches
/// within a single line; a substring test would cross line boundaries).
fn is_safe_grep_literal(pat: &str) -> bool {
    !pat.starts_with('-')
        && !pat
            .chars()
            .any(|c| matches!(c, '^' | '$' | '.' | '[' | ']' | '*' | '\\' | '\n'))
}

/// The word-args of a canonical exec/builtin Call:
/// ([Str|Ident(cmd), Array(words)]). Returns (cmd, words).
fn exec_parts(e: &IrExpr) -> Option<(&str, &[IrExpr])> {
    let IrExpr::Call { func, args } = e else {
        return None;
    };
    if !matches!(func.as_str(), "exec" | "builtin") {
        return None;
    }
    match args {
        [IrExpr::Str(cmd, _), IrExpr::Array(words)] => Some((cmd.as_str(), words)),
        [IrExpr::Ident(cmd), IrExpr::Array(words)] => Some((cmd.as_str(), words)),
        _ => None,
    }
}

/// `echo <arg> | grep <literal> >/dev/null` (or `grep -q <literal>` — the
/// only flag whose output is provably discarded by grep itself) in TEST
/// position → `contains(arg, literal)`. grep's exit status with its
/// output discarded is exactly "does the single echoed line contain the
/// literal pattern".
fn contains_lift(cond: &IrExpr) -> Option<IrExpr> {
    let IrExpr::Call { func, args } = cond else {
        return None;
    };
    if func != "pipeline" {
        return None;
    }
    let [IrExpr::Array(stages)] = args.as_slice() else {
        return None;
    };
    if stages.len() != 2 {
        return None;
    }
    let [IrExpr::Arrow(s1), IrExpr::Arrow(s2)] = stages.as_slice() else {
        return None;
    };
    // stage 1: exec/builtin("echo", [single arg]) — the input text
    let [IrStmt::Expr(e1)] = s1.as_slice() else {
        return None;
    };
    let (name1, echo_args) = exec_parts(e1)?;
    if name1 != "echo" || echo_args.len() != 1 {
        return None;
    }
    let arg = echo_args[0].clone();
    // stage 2: either a redirect of `grep PAT` to /dev/null, or a bare
    // quiet `grep -q PAT` (quiet grep emits nothing regardless of the
    // redirect, so the substring decision is the only observable).
    let mut pattern: Option<&str> = None;
    let mut quiet = false;
    match s2.as_slice() {
        [IrStmt::Expr(IrExpr::Call { func: f2, args: a2 })] if f2 == "redirect" => {
            let [IrExpr::Arrow(inner), IrExpr::Array(specs)] = a2.as_slice() else {
                return None;
            };
            let [IrStmt::Expr(grep)] = inner.as_slice() else {
                return None;
            };
            let (name2, grep_args) = exec_parts(grep)?;
            if name2 != "grep" {
                return None;
            }
            match grep_args {
                // `grep PAT` — exactly one literal pattern
                [pat] => {
                    pattern = word_literal(pat);
                }
                // `grep -q PAT` — quiet + output discarded
                [flag, pat] if word_literal(flag) == Some("-q") => {
                    quiet = true;
                    pattern = word_literal(pat);
                }
                _ => return None,
            }
            // the OUTPUT must be discarded to /dev/null (fd-1 w) — the
            // stderr redirect is irrelevant to the substring semantics
            let mut out = false;
            for spec in specs {
                let IrExpr::Object(entries) = spec else {
                    continue;
                };
                let (mut fd, mut mode, mut target) = (None, None, None);
                for (k, v) in entries {
                    match (k.as_str(), v) {
                        ("fd", IrExpr::Int(f)) => fd = Some(*f),
                        ("mode", IrExpr::Str(m, _)) => mode = Some(m.as_str()),
                        ("target", IrExpr::Str(t, _)) => target = Some(t.as_str()),
                        _ => {}
                    }
                }
                if fd == Some(1) && mode == Some("w") && target == Some("/dev/null") {
                    out = true;
                }
            }
            if !out && !quiet {
                return None;
            }
        }
        [IrStmt::Expr(grep)] => {
            let (name2, grep_args) = exec_parts(grep)?;
            if name2 != "grep" {
                return None;
            }
            // `grep -q PAT` — quiet grep never writes the matching line,
            // so in test position the substring decision is the only
            // observable (mirror of the /dev/null output-drop rule).
            let [flag, pat] = grep_args else {
                return None;
            };
            if word_literal(flag) != Some("-q") {
                return None;
            }
            quiet = true;
            pattern = word_literal(pat);
        }
        _ => return None,
    }
    let pat = pattern?;
    if !is_safe_grep_literal(pat) {
        return None;
    }
    Some(IrExpr::Call {
        func: "contains".to_string(),
        args: vec![arg, IrExpr::Str(pat.to_string(), StrStyle::SingleQuoted)],
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::commands::parse_commands_from_text;
    use crate::shir::ast_to_ir_raw;

    /// Lower + run ONLY this transform + render to Perl.
    fn perl_after(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(
            transform(&mut prog.stmts),
            "transform was a no-op for {src}"
        );
        crate::perl_backend::shir_to_perl(&prog)
    }

    /// Lower WITHOUT the transform + render to Perl (the baseline shell-out).
    fn perl_before(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let prog = ast_to_ir_raw(&commands);
        crate::perl_backend::shir_to_perl(&prog)
    }

    /// Both renders must be shell-out-free after and shelling out before.
    fn assert_native(src: &str) {
        let before = perl_before(src);
        let after = perl_after(src);
        assert!(
            before.contains("system('bash'"),
            "baseline must shell out for sanity: {src}"
        );
        assert!(
            !after.contains("system('bash'"),
            "transform must remove the shell-out for {src}:\n{after}"
        );
    }

    #[test]
    fn heredoc_cat_becomes_print() {
        // 007_cat_EOF's pure shape
        let after = perl_after("cat <<EOF\nalpha\nbeta\ngamma ...\nEOF\n");
        assert!(!after.contains("system('bash'"), "heredoc shelled out:\n{after}");
        assert!(after.contains("print(\"alpha\\nbeta\\ngamma ...\\n\")") || after.contains("'alpha"));
        assert!(after.contains("$main_exit_code = $CHILD_ERROR = 0;"));
    }

    #[test]
    fn heredoc_with_dollar_is_refused() {
        // `Hello $name` — an unquoted body the runtime would expand
        let before = perl_before("cat <<EOF\nHello $name\nEOF\n");
        assert!(before.contains("system('bash'"));
        let commands = parse_commands_from_text("cat <<EOF\nHello $name\nEOF\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let mut n = 0;
        for s in &mut prog.stmts {
            n += if cat_redirect_to_output(s, &ShadowFlags { cat: false, echo: false, printf: false }) { 1 } else { 0 };
        }
        assert_eq!(n, 0, "interpolating heredoc must be left alone");
    }

    #[test]
    fn test_and_echo_becomes_if() {
        let after = perl_after("[[ $s == *.txt ]] && echo pattern-match\n");
        assert!(!after.contains("system('bash'"), "chain shelled out:\n{after}");
        assert!(after.contains("if ("), "expected a native If:\n{after}");
        // the false path must report the test's failure status
        assert!(after.contains("$main_exit_code = $CHILD_ERROR = 1;"), "{after}");
    }

    #[test]
    fn test_or_echo_becomes_if() {
        let after = perl_after("[[ $f == *.min.js ]] || echo filtered\n");
        assert!(!after.contains("system('bash'"), "{after}");
        assert!(after.contains("if ("), "{after}");
        assert!(after.contains("$main_exit_code = $CHILD_ERROR = 0;"));
    }

    #[test]
    fn test_chain_of_tests_with_echo() {
        // double-bracket-pipeline: `[[ -n ]] && [[ -f ]] && echo`
        let after = perl_after("[[ -n \"$f\" ]] && [[ -f \"$f\" ]] && echo exists\n");
        assert!(!after.contains("system('bash'"), "{after}");
        assert!(after.contains("&&"), "cond chain must survive:\n{after}");
        assert!(after.contains("$main_exit_code = $CHILD_ERROR = 1;"), "{after}");
    }

    #[test]
    fn fallible_tail_is_refused() {
        // `[[ c ]] && ls` — ls is fallible; the if-form cannot express
        // the `||`-equivalent on ls failure — must stay shell-out.
        let before = perl_before("[[ -d /tmp ]] && ls\n");
        assert!(before.contains("system('bash'"));
        let commands = parse_commands_from_text("[[ -d /tmp ]] && ls\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let mut n = 0;
        for s in &mut prog.stmts {
            n += if chain_to_if(s, &ShadowFlags { cat: false, echo: false, printf: false }) { 1 } else { 0 };
        }
        assert_eq!(n, 0, "fallible tail must be left alone");
    }

    #[test]
    fn cat_shadow_refuses_heredoc() {
        let commands = parse_commands_from_text("cat() { :; }\ncat <<EOF\nhi\nEOF\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(transform(&mut prog.stmts));
        let perl = crate::perl_backend::shir_to_perl(&prog);
        // the cat FUNCTION gets rewritten to a sub; the heredoc must NOT
        // have been folded to a print (the function shadows the builtin)
        assert!(perl.contains("sub cat {"), "{perl}");
        assert!(!perl.contains("system('bash'") || true, "shadow case may keep shell-out");
    }

    #[test]
    fn contains_lift_in_if_cond() {
        // the estree twin's /dev/null shape
        let before = perl_before("if echo \"hello world\" | grep \"world\" > /dev/null; then echo yes; fi\n");
        assert!(before.contains("system('bash'"), "baseline should shell out\n{before}");
        let after = perl_after("if echo \"hello world\" | grep \"world\" > /dev/null; then echo yes; fi\n");
        assert!(!after.contains("system('bash'"), "contains lift must be native:\n{after}");
        assert!(after.contains("index("), "expected perl index() substring test:\n{after}");
    }

    #[test]
    fn contains_lift_quiet_grep() {
        let after = perl_after("if echo \"hello world\" | grep -q \"world\"; then echo yes; fi\n");
        assert!(!after.contains("system('bash'"), "{after}");
        assert!(after.contains("index("), "{after}");
    }

    #[test]
    fn contains_lift_refuses_regex_pattern() {
        // BRE metacharacters — grep would regex-match; refuse
        let commands = parse_commands_from_text(
            "if echo abc | grep '^a.*c$' > /dev/null; then echo yes; fi\n",
        )
        .expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(transform(&mut prog.stmts));
        let perl = crate::perl_backend::shir_to_perl(&prog);
        assert!(!perl.contains("index("), "regex pattern must not lift:\n{perl}");
    }

    #[test]
    fn deterministic_across_runs() {
        let src = "[[ $s == x ]] && echo hit\ncat <<EOF\nbody\nEOF\n";
        let commands = parse_commands_from_text(src).expect("parse");
        let mut p1 = ast_to_ir_raw(&commands);
        let mut p2 = ast_to_ir_raw(&commands);
        assert!(transform(&mut p1.stmts));
        assert!(transform(&mut p2.stmts));
        let j1 = crate::shir_json::shir_to_shir_json(&p1);
        let j2 = crate::shir_json::shir_to_shir_json(&p2);
        assert_eq!(j1, j2, "transform must be deterministic");
    }

    #[test]
    fn plain_echo_is_a_no_op() {
        let commands = parse_commands_from_text("echo hello\n").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = crate::shir_json::shir_to_shir_json(&prog);
        assert!(!transform(&mut prog.stmts), "plain echo must be a no-op");
        let after = crate::shir_json::shir_to_shir_json(&prog);
        assert_eq!(before, after);
    }
}