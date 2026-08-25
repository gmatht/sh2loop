//! shir-cat-heredoc — eliminate `system('bash', '-c', q{'cat' <<…})`
//! shell-out call sites by rewriting the `cat`-with-fd-0-redirect A1 into
//! the canonical native shapes every renderer already emulates (exec-of-
//! echo for stdout, exec-of-echo behind the file redirect for `> file`,
//! and the folded string value for `$( … )` captures).
//!
//! ## Why
//!
//! `./fail-shir` counts `system('bash', -c, …)` call sites in the
//! rendered Perl. The single largest "normalisable" cluster is the
//! **heredoc / herestring body fed to `cat`**:
//!
//!     cat <<EOF
//!     alpha
//!     beta
//!     EOF
//!
//! The Perl `Redirect` arm rebuilds the shell text (heredoc body appended,
//! `<<'DELIM'`) and shells out via `bash -c` — even though `cat` with
//! only stdin input is the identity filter: it copies its input to stdout
//! (or to the file a `> file` redirect names). The ESTree renderer
//! already folds these shapes natively (`try_native_cat_heredoc` /
//! `try_native_echo_redirect` in shir.rs); the Perl renderer has no such
//! fold, so the A1 shape must be rewritten to a shape it renders
//! in-process. This transform produces exactly those canonical shapes.
//!
//! ## What it rewrites (REFUSE > GUESS)
//!
//! 1. **`cat <<'EOF' … EOF`** (single fd-0 heredoc/herestring, stdout) →
//!    `Expr(exec "echo" [body-minus-one-newline])`. Bash `cat` prints the
//!    body verbatim (it always ends in `\n`); `echo` re-adds the single
//!    trailing newline it appends, producing byte-identical stdout (and
//!    the `echo` builtin records the status `cat` would: 0).
//! 2. **`cat <<EOF > file`** (fd-0 heredoc + fd-1 `w`/`wc`/`a` file
//!    redirect) → `Redirect { inner: [Block([Expr(exec echo …)])],
//!    redirects: [the file redirect] }`. The Block makes the Perl
//!    `stmts_to_shell_cmd` rebuild refuse the inner, so the Perl
//!    renderer's native select-based file redirect fires (echo prints
//!    into the file); the ESTree renderer's `try_native_echo_redirect`
//!    peels the same Block (estree already folds `echo > file`).
//! 3. **`x=$(cat <<EOF … EOF)`** (an `IrStmt::Assign` whose WHOLE value
//!    is a `Capture` of the cat-redirect) → `Assign { expr: Str(body) }`.
//!    Command substitution strips the trailing newlines, so the folded
//!    value is the heredoc body with trailing newlines removed — native
//!    on both backends. Only the plain scalar-assign form fires (an
//!    unquoted `$(…)` in a list/word-splitting context can rejoin with a
//!    single space and must NOT be folded — bash would have split).
//!
//! ## Soundness gates (all are REFUSALS — a shape that cannot be proven
//! bash-identical keeps its shell-out)
//!
//! - `cat` must be the bare builtin: inner is a single `Expr(exec|builtin
//!   "cat", [])` (or `["-"]` — the stdin marker) with NO other words.
//!   `cat file <<EOF` reads the file too — refused.
//! - The fd-0 redirect is a single `heredoc` / `heredoc-tabs` /
//!   `herestring`; its target must be STATIC text (Str or all-Lit
//!   Interpolate), and an *unquoted* body (`interpolate`) must not
//!   contain `$`, backtick or backslash — those are runtime expansions
//!   the A1 left unmodelled (bash would expand them, a native print
//!   would not). Quoted (`<<'EOF'`, interpolate=false) bodies are fully
//!   literal and safe. `heredoc-tabs` strips leading tabs per line
//!   (the runtime's exact transform).
//! - No script-defined `cat` or `echo` FUNCTION may shadow the builtins
//!   (the perl renderer rewrites `exec(<fnname>)` to a sub call, and bash
//!   heredoc semantics are the builtin cat's — either direction is a
//!   behavior change, so refuse).
//! - The echo word must not begin with `-` (a leading `-n`/`-e` would be
//!   eaten by echo's flag parsing — refused).
//! - F2's file redirect must be the ONLY other redirect (fd 1,
//!   `w`/`wc`/`a`); fd-dup (`2>&1`), fd-2, multiple/mixed specs — refused.
//! - F3 fires only when the Capture is the literal shell `$(…)` form
//!   (`native: false`), assigned to a single plain scalar target.
//!
//! ## Placement / registration
//! Drop into `src/transforms/`, add `pub mod shir_cat_heredoc;`, and
//! register `("shir-cat-heredoc", shir_cat_heredoc::transform)` in
//! `src/transforms.rs` (DEBASHC_TRANSFORMS-gated like the rest). It is
//! idempotent (each family's output no longer matches its own input), and
//! every emitted node (`Block`/`Expr`/`exec`/`Redirect`/`Assign`/`Str`)
//! is already in the A1 contract and rendered natively by BOTH the Perl
//! and the ESTree renderers.

use crate::ir::{InterpPart, IrExpr, IrRedirect, IrStmt, StrStyle};

/// Apply the transform. Returns whether anything changed.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let mut c = false;
    for s in stmts.iter_mut() {
        c |= transform_stmt(s);
    }
    c
}

fn st(s: &str) -> IrExpr {
    IrExpr::Str(s.to_string(), StrStyle::DoubleQuoted)
}

/// The canonical native shape an `echo` statement takes: `exec("echo",
/// [word])` — the Emulable exec both renderers dispatch natively (Perl's
/// emit_echo, estree's echo fold).
fn exec_echo(word: &str) -> IrStmt {
    IrStmt::Expr(IrExpr::Call {
        func: "exec".to_string(),
        args: vec![
            st("echo"),
            IrExpr::Array(vec![IrExpr::Str(word.to_string(), StrStyle::DoubleQuoted)]),
        ],
    })
}

fn transform_stmt(st: &mut IrStmt) -> bool {
    // Recurse into children FIRST (bottom-up — a nested redirect inside an
    // If body is rewritten before we look at the enclosing shape).
    let mut c = match st {
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
        } => {
            let mut x = transform_expr(cond);
            x |= transform(then);
            for (ec, eb) in elsifs.iter_mut() {
                x |= transform_expr(ec);
                x |= transform(eb);
            }
            x |= transform(else_);
            x
        }
        IrStmt::For { iter, body, .. } => {
            let mut x = transform_expr(iter);
            x |= transform(body);
            x
        }
        IrStmt::While { cond, body, .. } => {
            let mut x = transform(body);
            x |= transform_expr(cond);
            x
        }
        IrStmt::DoWhile { body, cond, .. } => {
            let mut x = transform(body);
            x |= transform_expr(cond);
            x
        }
        IrStmt::Case {
            discriminant,
            clauses,
        } => {
            let mut x = transform_expr(discriminant);
            for cl in clauses.iter_mut() {
                x |= transform(&mut cl.body);
            }
            x
        }
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b)
        | IrStmt::Function { body: b, .. } => transform(b),
        IrStmt::Pipeline { stages, .. } => {
            let mut x = false;
            for stg in stages.iter_mut() {
                x |= transform(stg);
            }
            x
        }
        IrStmt::Expr(e) => transform_expr(e),
        IrStmt::Assign { expr, asm, .. } => {
            let mut x = transform_expr(expr);
            if asm.is_none() {
                x |= capture_cat_to_value(st);
            }
            x
        }
        IrStmt::Output { value, .. } => transform_expr(value),
        IrStmt::Declare {
            init: Some(expr), ..
        } => transform_expr(expr),
        IrStmt::WriteFile { path, content, .. } => transform_expr(path) | transform_expr(content),
        IrStmt::Redirect { inner, redirects } => {
            let mut x = transform(inner);
            for r in redirects.iter_mut() {
                // the fd-0 redirect target may be a static interpolate —
                // nothing dynamic to walk, but keep the recursion for
                // completeness on any exotic target.
                x |= transform_expr(&mut r.target);
            }
            x |= cat_heredoc_stdout(st);
            x |= cat_heredoc_file(st);
            x
        }
        IrStmt::Exec {
            cmd, args, env, ..
        } => {
            let mut x = transform_expr(cmd);
            for a in args.iter_mut() {
                x |= transform_expr(a);
            }
            for (_, v) in env.iter_mut() {
                x |= transform_expr(v);
            }
            x
        }
        _ => false,
    };
    c
}

fn transform_expr(e: &mut IrExpr) -> bool {
    match e {
        IrExpr::Arrow(stmts) => transform(stmts),
        IrExpr::Capture { expr, .. } => transform_expr(expr),
        IrExpr::Call { args, .. } => {
            let mut c = false;
            for a in args.iter_mut() {
                c |= transform_expr(a);
            }
            c
        }
        IrExpr::Array(items) => {
            let mut c = false;
            for a in items.iter_mut() {
                c |= transform_expr(a);
            }
            c
        }
        IrExpr::Object(pairs) => {
            let mut c = false;
            for (_, v) in pairs.iter_mut() {
                c |= transform_expr(v);
            }
            c
        }
        IrExpr::BinOp { lhs, rhs, .. } => transform_expr(lhs) | transform_expr(rhs),
        IrExpr::Ternary { cond, then, else_ } => {
            transform_expr(cond) | transform_expr(then) | transform_expr(else_)
        }
        IrExpr::Index { key, .. } => transform_expr(key),
        _ => false,
    }
}

// ── shared extraction ─────────────────────────────────────────────────

/// Does the program define a bash FUNCTION with this name anywhere?
/// (A script-defined `cat`/`echo` shadows the builtin; the perl renderer
/// rewrites `exec(<fnname>)` to a sub call — refuse to rewrite the shape.)
fn program_defines_function(stmts: &[IrStmt], name: &str) -> bool {
    let mut found = false;
    walk_stmts(stmts, &mut |s| {
        if let IrStmt::Function { name: n, .. } = s {
            if n == name {
                found = true;
            }
        }
    });
    found
}

fn walk_stmts(stmts: &[IrStmt], f: &mut impl FnMut(&IrStmt)) {
    for s in stmts {
        f(s);
        match s {
            IrStmt::If {
                cond,
                then,
                elsifs,
                else_,
            } => {
                walk_expr(cond, f);
                walk_stmts(then, f);
                for (_, b) in elsifs {
                    walk_stmts(b, f);
                }
                walk_stmts(else_, f);
            }
            IrStmt::For { iter, body, .. } => {
                walk_expr(iter, f);
                walk_stmts(body, f);
            }
            IrStmt::While { cond, body, .. } | IrStmt::DoWhile { cond, body, .. } => {
                walk_expr(cond, f);
                walk_stmts(body, f);
            }
            IrStmt::Case {
                discriminant,
                clauses,
            } => {
                walk_expr(discriminant, f);
                for cl in clauses {
                    walk_stmts(&cl.body, f);
                }
            }
            IrStmt::Block(b)
            | IrStmt::Subshell(b)
            | IrStmt::Background(b)
            | IrStmt::Function { body: b, .. } => walk_stmts(b, f),
            IrStmt::Pipeline { stages, .. } => {
                for stg in stages {
                    walk_stmts(stg, f);
                }
            }
            IrStmt::Expr(e) | IrStmt::Assign { expr: e, .. } => walk_expr(e, f),
            IrStmt::Output { value, .. } => walk_expr(value, f),
            IrStmt::Redirect { inner, redirects } => {
                walk_stmts(inner, f);
                for r in redirects {
                    walk_expr(&r.target, f);
                }
            }
            _ => {}
        }
    }
}

fn walk_expr(e: &IrExpr, f: &mut impl FnMut(&IrStmt)) {
    if let IrExpr::Arrow(stmts) = e {
        walk_stmts(stmts, f);
    }
}

/// Static text of an expression: a bare Str or an Interpolate of only
/// literal parts (the emitter wraps quoted words as all-Lit Interpolates).
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

/// A bash heredoc/herestring body the runtime would expand — the A1 left a
/// `$`/backtick/backslash as literal text. A native print would NOT
/// expand it; refuse (the shell-out stays).
fn verbatim_ok(body: &str) -> bool {
    !body.chars().any(|c| matches!(c, '$' | '`' | '\\'))
}

/// The exact byte stream bash `cat` emits reading only the fd-0 redirect:
/// the heredoc body (with `heredoc-tabs` stripping), or the herestring
/// target + the newline bash appends. None = dynamic/unsupported target.
fn redirect_desired(r: &IrRedirect) -> Option<String> {
    if r.fd.unwrap_or(0) != 0 {
        return None;
    }
    let target = static_text(&r.target)?;
    match r.mode.as_str() {
        "heredoc" => {
            if r.interpolate && !verbatim_ok(&target) {
                return None;
            }
            Some(target)
        }
        "heredoc-tabs" => {
            if r.interpolate && !verbatim_ok(&target) {
                return None;
            }
            // the runtime's exact heredoc-tabs transform: strip leading
            // tabs per line BEFORE any expansion
            Some(
                target
                    .split('\n')
                    .map(|l| l.trim_start_matches('\t'))
                    .collect::<Vec<_>>()
                    .join("\n"),
            )
        }
        "herestring" => {
            // bash appends a newline to herestring input and never
            // interpolates it
            let mut t = target;
            t.push('\n');
            Some(t)
        }
        _ => None,
    }
}

/// The single echo word reproducing `desired` bytes: remove exactly ONE
/// trailing newline (the one the echo builtin appends back). Refused when
/// the word starts with `-` (echo flag ambiguity: `-n` suppresses the
/// newline, `-e` enables escape interpretation — neither is cat's output).
fn echo_word(desired: &str) -> Option<String> {
    let word = desired.strip_suffix('\n').unwrap_or(desired);
    if word.starts_with('-') {
        return None;
    }
    Some(word.to_string())
}

/// The cat command inside the redirect: `[Expr(exec|builtin "cat",
/// [])]` or with a single `-` word. Returns the word list when the inner
/// is the bare-stdin cat shape.
fn bare_cat_words(inner: &[IrStmt]) -> Option<()> {
    let [IrStmt::Expr(IrExpr::Call { func, args })] = inner else {
        return None;
    };
    if !matches!(func.as_str(), "exec" | "builtin") {
        return None;
    }
    let [IrExpr::Str(name, _), IrExpr::Array(words)] = args.as_slice() else {
        return None;
    };
    if name != "cat" {
        return None;
    }
    let arg_ok = words.is_empty()
        || matches!(words.as_slice(), [IrExpr::Str(s, _)] if s == "-");
    if !arg_ok {
        return None;
    }
    Some(())
}

/// The `echo` exec stmt whose stdout bytes equal the fd-0 redirect body
/// (family 1). None on any refusal.
fn heredoc_cat_echo(inner: &[IrStmt], redirects: &[IrRedirect]) -> Option<IrStmt> {
    bare_cat_words(inner)?;
    let [r] = redirects else {
        return None;
    };
    let desired = redirect_desired(r)?;
    let word = echo_word(&desired)?;
    if desired.is_empty() && r.mode != "herestring" {
        // a heredoc body is never empty (bash always terminates it with
        // a newline); an empty `desired` here would be a parse anomaly —
        // refuse rather than guess the bytes.
        return None;
    }
    Some(exec_echo(&word))
}

// ── Family 1: `cat <<…` (stdout) → exec echo ─────────────────────────

/// `Redirect { inner: [Expr(exec|builtin cat)], redirects: [fd0
/// heredoc/heredoc-tabs/herestring] }` → `Expr(exec "echo" [body])`.
fn cat_heredoc_stdout(st: &mut IrStmt) -> bool {
    let IrStmt::Redirect { inner, redirects } = st else {
        return false;
    };
    if let Some(repl) = heredoc_cat_echo(inner, redirects) {
        // only fire on the canonical exec's own heredoc — never when a
        // script function shadows the builtins
        *st = repl;
        return true;
    }
    false
}

// ── Family 2: `cat <<… > file` → echo behind the file redirect ──────

/// `Redirect { inner: [Expr cat], redirects: [fd0 heredoc, fd1 w|wc|a
/// file] }` → `Redirect { inner: [Block([Expr(exec echo …)])], redirects:
/// [the file redirect] }`. The Block makes the Perl shell-text rebuild
/// refuse, so the native select-based file redirect fires; the ESTree
/// renderer peels the Block and folds `echo > file` natively.
fn cat_heredoc_file(st: &mut IrStmt) -> bool {
    let IrStmt::Redirect { inner, redirects } = st else {
        return false;
    };
    if redirects.len() != 2 {
        return false;
    }
    // the fd-0 heredoc/herestring AND the fd-1 file redirect, in either
    // order
    let mut heredoc: Option<&IrRedirect> = None;
    let mut file: Option<&IrRedirect> = None;
    for r in redirects {
        let fd = r.fd.unwrap_or(0);
        if fd == 0
            && matches!(r.mode.as_str(), "heredoc" | "heredoc-tabs" | "herestring")
        {
            if heredoc.is_some() {
                return false;
            }
            heredoc = Some(r);
        } else if fd == 1 && matches!(r.mode.as_str(), "w" | "wc" | "a") {
            if file.is_some() {
                return false;
            }
            file = Some(r);
        } else {
            return false;
        }
    }
    let (heredoc, file) = match (heredoc, file) {
        (Some(h), Some(f)) => (h, f),
        _ => return false,
    };
    if bare_cat_words(inner).is_none() {
        return false;
    }
    let desired = match redirect_desired(heredoc) {
        Some(d) => d,
        None => return false,
    };
    let word = match echo_word(&desired) {
        Some(w) => w,
        None => return false,
    };
    if desired.is_empty() && heredoc.mode != "herestring" {
        return false;
    }
    *st = IrStmt::Redirect {
        inner: vec![IrStmt::Block(vec![exec_echo(&word)])],
        redirects: vec![file.clone()],
    };
    true
}

// ── Family 3: `x=$(cat <<…)` → folded scalar assign ───────────────

/// `Assign { targets: [plain scalar], expr: Capture { native: false,
/// expr: Arrow([Expr(redirect-cat …)]) } }` — the shell `$(cat <<EOF …
/// EOF)` — folds to `Assign { expr: Str(body-minus-trailing-newlines) }`
/// (command substitution strips ALL trailing newlines). Only the WHOLE
/// expr being the capture fires: an unquoted `$(…)` in a word/array
/// context word-splits and re-joins with single spaces — not reproduced
/// by a folded string.
fn capture_cat_to_value(st: &mut IrStmt) -> bool {
    let IrStmt::Assign { targets, expr, .. } = st else {
        return false;
    };
    // a single plain scalar target
    if targets.len() != 1 {
        return false;
    }
    let t = &targets[0];
    if !t.indices.is_empty() {
        return false;
    }
    let IrExpr::Capture {
        expr: cap,
        native: false,
    } = expr
    else {
        return false;
    };
    let IrExpr::Arrow(body) = &**cap else {
        return false;
    };
    // the capture body: a single Expr(Call redirect ...)
    let [IrStmt::Expr(IrExpr::Call { func, args })] = body.as_slice() else {
        return false;
    };
    if func != "redirect" {
        return false;
    }
    let cmd_stmts = match args.first() {
        Some(IrExpr::Arrow(cmds)) => cmds,
        _ => return false,
    };
    if bare_cat_words(cmd_stmts).is_none() {
        return false;
    }
    let specs = match args.get(1) {
        Some(IrExpr::Array(s)) => s,
        _ => return false,
    };
    // parse the spec objects -> IrRedirect-like (fd, mode, target, interp)
    let mut redirects: Vec<IrRedirect> = Vec::new();
    for s in specs {
        let IrExpr::Object(fields) = s else {
            return false;
        };
        let mut fd: Option<i32> = None;
        let mut mode: Option<String> = None;
        let mut target: Option<IrExpr> = None;
        let mut interp = false;
        for (k, v) in fields {
            match k.as_str() {
                "fd" => {
                    if let IrExpr::Int(n) = v {
                        fd = Some(*n as i32);
                    }
                }
                "mode" => mode = static_text(v),
                "target" => target = Some(v.clone()),
                "interpolate" => {
                    if let IrExpr::Bool(b) = v {
                        interp = *b;
                    }
                }
                _ => {}
            }
        }
        redirects.push(IrRedirect {
            fd,
            mode: match mode {
                Some(m) => m,
                None => return false,
            },
            target: match target {
                Some(t) => t,
                None => return false,
            },
            interpolate: interp,
        });
    }
    // exactly one fd-0 heredoc/herestring, nothing else
    if redirects.len() != 1 {
        return false;
    }
    let r = &redirects[0];
    let desired = match redirect_desired(r) {
        Some(d) => d,
        None => return false,
    };
    if desired.is_empty() && r.mode != "herestring" {
        return false;
    }
    let value = desired.trim_end_matches('\n');
    *expr = IrExpr::Str(value.to_string(), StrStyle::DoubleQuoted);
    true
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

    /// Lower + run the transform + assert SOMETHING changed.
    fn assert_changes(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(
            transform(&mut prog.stmts),
            "transform was a no-op for {src}"
        );
        shir_to_shir_json(&prog)
    }

    /// Render the transformed program to Perl and return it.
    fn render_perl(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        let _ = transform(&mut prog.stmts);
        crate::ir::shir_to_perl(&prog)
    }

    #[test]
    fn cat_eof_stdout_becomes_native_echo() {
        let json = assert_changes("cat <<EOF\nalpha\nbeta\ngamma ...\nEOF\n");
        // no cat redirect / shell-out remnant in the A1
        assert!(!json.contains("\"redirect\""), "redirect survived: {json}");
        assert!(!json.contains("\"cat\""), "cat survived: {json}");
        // the native echo exec carries the body (minus the newline echo adds)
        assert!(json.contains("\"echo\""), "missing echo: {json}");
        assert!(json.contains("alpha"), "missing body: {json}");
    }

    #[test]
    fn cat_eof_perl_has_no_shellout() {
        let perl = render_perl("cat <<EOF\nalpha\nbeta\nEOF\n");
        assert!(
            !perl.contains("system('bash'"),
            "perl still shells out: {perl}"
        );
        assert!(
            perl.contains("alpha") && perl.contains("beta"),
            "body missing from native print: {perl}"
        );
    }

    #[test]
    fn quoted_heredoc_is_literal() {
        // <<'EOF' — even with $ / \ in the body it is fully literal
        let perl = render_perl("cat <<'EOF'\ncost: $5 & \\nothing\nEOF\n");
        assert!(!perl.contains("system('bash'"), "should be native: {perl}");
        assert!(perl.contains("cost: $5"), "body missing: {perl}");
    }

    #[test]
    fn unquoted_heredoc_with_var_refuses() {
        // `$name` in an interpolate=true body is a runtime expansion the
        // A1 left unmodelled — must keep the shell-out.
        let commands = parse_commands_from_text("cat <<EOF\nHello $name\nEOF\n").unwrap();
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "interpolated heredoc must be untouched");
        assert!(!changed);
    }

    #[test]
    fn cat_with_file_operand_refuses() {
        // `cat file <<EOF` reads the file too — not stdin-only.
        let commands = parse_commands_from_text("cat f.txt <<EOF\na\nEOF\n").unwrap();
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "cat-with-file must be untouched");
        assert!(!changed);
    }

    #[test]
    fn cat_eof_to_file_uses_native_redirect() {
        let perl = render_perl("cat <<EOF\nhello world\nEOF\n> /tmp/out.txt\n");
        assert!(
            !perl.contains("system('bash'"),
            "perl still shells out: {perl}"
        );
    }

    #[test]
    fn capture_cat_folds_to_scalar_value() {
        let json = assert_changes("x=$(cat <<EOF\nline1\nline2\nEOF\n)\n");
        // the Capture is gone: the Assign value is the folded body
        assert!(!json.contains("\"Capture\""), "capture survived: {json}");
        assert!(json.contains("line1\\nline2") || json.contains("line1\\u000aline2"),
            "folded value missing: {json}");
    }

    #[test]
    fn capture_cat_perl_is_native() {
        let perl = render_perl("x=$(cat <<EOF\nhello world\nEOF\n)\nprintf '%s\\n' \"$x\"\n");
        assert!(
            !perl.contains("system('bash'") && !perl.contains("'-|', 'bash'"),
            "capture still shells out: {perl}"
        );
    }

    #[test]
    fn non_cat_redirect_is_untouched() {
        // grep with a heredoc is a different family — untouched
        let commands = parse_commands_from_text("grep x <<EOF\na\nEOF\n").unwrap();
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "grep heredoc must be untouched");
        assert!(!changed);
    }

    #[test]
    fn nested_heredoc_inside_block_rewrites() {
        // the heredoc is buried inside a subshell
        let perl = render_perl("if true; then (cat <<EOF\nx\nEOF\n); fi\n");
        assert!(
            !perl.contains("system('bash'"),
            "nested heredoc should be native: {perl}"
        );
    }

    #[test]
    fn deterministic_across_runs() {
        let src = "cat <<EOF\nalpha\nbeta\nEOF\n";
        assert_eq!(lower(src), lower(src));
    }
}
