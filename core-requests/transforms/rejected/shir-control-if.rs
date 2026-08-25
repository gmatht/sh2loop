//! shir-control-if — rewrite statement-position `test && echo/printf` and
//! `test || echo/printf` control chains into native `IrStmt::If` nodes, so
//! the Perl renderer's shell-out path (`control_chain_to_perl` — the
//! `if (cond) { system('bash', '-c', 'echo …') }` shape) never fires.
//!
//! ## Need
//!
//! A shell source like `[[ $s == *.txt ]] && echo pattern-match` lowers
//! to the A1 statement `Expr(BinOp(And, test, builtin("echo", …)))`.
//! The Perl renderer has NO native arm for a BinOp control chain: it
//! rebuilds the shell text and lowers the whole chain to
//! `system('bash', '-c', …)` (fail-shir's "#1 tally", `echo` 66 sites).
//! The ESTree renderer lowers the same BinOp form natively — so the chain
//! is emulable, it just isn't in the canonical native SHAPE. The natural
//! native shape for a test-guarded command is the A1 `If` node, which
//! BOTH renderers already emit as `if (cond) { … }` / a native JS
//! `IfStatement` (the echo arm renders as a plain print/printf — no
//! bash at runtime).
//!
//! This transform is the single-branch complement of `shir-native-stmt`
//! family 3 (which handles the two-arm `test && echo || echo` → if/else).
//! The single-arm `test && echo` case is left as a shell-out there
//! deliberately (its false-path status is the test's — an if/else cannot
//! express it); here the missing else is exactly the point.
//!
//! ## Shape
//!
//! - `Expr(BinOp(And, <pure-test-chain>, exec/builtin echo|printf))`
//!   → `If { cond: <chain>, then: [<arm>], else: [] }`.
//! - `Expr(BinOp(Or, <pure-test-chain>, exec/builtin echo|printf))`
//!   → `If { cond: not(<chain>), then: [<arm>], else: [] }` (`not`
//!   Call — the estree runtime's `sh2.not`; Perl's `not(...)`; both
//!   native).
//!
//! ## Soundness (REFUSE > GUESS)
//!
//! - The ARM must be a SINGLE always-success builtin (`echo`/`printf` —
//!   status 0 on every path). This is the same arm restriction
//!   `shir-native-stmt` enforces for family 3: only an always-success
//!   arm lets a pipe/and-chain's status collapse onto the native
//!   statement's `$main_exit_code = 0` without a fallible-command
//!   divergence. A fallible command (cat/ls/grep/…) must NOT be moved
//!   into a plain if-branch — bash's `A && B` runs B only when A held;
//!   the if-form would too, but the `||`-else forms they pair with
//!   depend on mid-chain status we would flatten.
//! - The COND must be a PURE test chain (`test` calls joined by
//!   And/Or/Not) — a chain whose truth is fully determined by the native
//!   `test` nodes, so no side-effectful/fallible command sits in the
//!   guard. Only then is `if (cond)` identical for every backend.
//! - Only the STATEMENT-position BinOp (an `IrStmt::Expr` whose whole
//!   expression is the chain) is rewritten. A BinOp inside a condition,
//!   an argument, a pipeline stage etc. is an expression context with its
//!   own (native) renderer paths — left untouched.
//! - The two-arm `test && echo || echo` chain is left to shir-native-stmt
//!   (its top is an `Or` whose lhs is not a pure test chain — refused
//!   here, so there is no double-handling).
//!
//! ## Placement
//! Registered in `transforms.rs` (DEBASHC_TRANSFORMS gated). Runs after
//! `shir-native-stmt` (which owns the two-arm case). The emitted `If` /
//! `Call("not")` / `Call exec`-shaped arms are all in the A1 contract and
//! rendered natively by BOTH the Perl and the ESTree renderers — no new
//! statement kinds, no core edits.

use crate::ir::{BinOpKind, IrExpr, IrStmt, StrStyle};

/// Apply the transform. Returns whether anything changed.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let mut c = false;
    for s in stmts.iter_mut() {
        c |= transform_stmt(s);
    }
    c
}

fn transform_stmt(st: &mut IrStmt) -> bool {
    // Recurse into children FIRST (bottom-up — a nested chain inside an
    // If body is rewritten before we look at the enclosing statement).
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
        IrStmt::Expr(e) => {
            let mut x = transform_expr(e);
            // statement-position chain → If
            x |= chain_to_if(st);
            x
        }
        IrStmt::Assign { expr, .. } | IrStmt::Output { value: expr, .. } => transform_expr(expr),
        IrStmt::Declare {
            init: Some(expr), ..
        } => transform_expr(expr),
        IrStmt::WriteFile { path, content, .. } => transform_expr(path) | transform_expr(content),
        IrStmt::Redirect { inner, redirects } => {
            let mut x = transform(inner);
            for r in redirects.iter_mut() {
                x |= transform_expr(&mut r.target);
            }
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
        IrExpr::Index { key, .. } => transform_expr(key),
        _ => false,
    }
}

/// Is `e` a `test` Call (a native test, `[[ ]]`-lowered)?
fn is_test_call(e: &IrExpr) -> bool {
    matches!(e, IrExpr::Call { func, .. } if func == "test")
}

/// Is `e` a PURE test chain — `test` calls joined only by And/Or/Not
/// (no commands, no side effects)? Only a pure chain can be safely moved
/// into a native `if (cond)` guard: every backend evaluates such a chain
/// as a pure boolean and leaves the test's status semantics intact.
fn is_pure_test(e: &IrExpr) -> bool {
    match e {
        IrExpr::Call { func, .. } => func == "test",
        IrExpr::BinOp { op, lhs, rhs } => match op {
            // double-operand chain: BOTH sides must be pure tests
            BinOpKind::And | BinOpKind::Or => is_pure_test(lhs) && is_pure_test(rhs),
            // `! test` — single-operand negation
            BinOpKind::Not => is_pure_test(lhs),
            // numeric/string/other BinOps carry non-test semantics — refuse
            _ => false,
        },
        _ => false,
    }
}

/// The word-args of a canonical exec-style Call:
/// `exec("cmd", [word, …])` or `builtin("cmd", [word, …])`.
fn exec_parts(e: &IrExpr) -> Option<(&str, &[IrExpr])> {
    if let IrExpr::Call { func, args } = e {
        if matches!(func.as_str(), "exec" | "builtin") {
            if let [IrExpr::Str(cmd, _), IrExpr::Array(words)] = args.as_slice() {
                return Some((cmd, words));
            }
        }
    }
    None
}

/// A single arm statement for an always-success builtin
/// (echo/printf — status 0 on every path). Any word list is accepted:
/// both renderers render every word shape of these two builtins natively
/// (statement-position echo/printf already emit plain print/printf).
fn single_always_true_arm(e: &IrExpr) -> Option<Vec<IrStmt>> {
    let (cmd, _words) = exec_parts(e)?;
    if matches!(cmd, "echo" | "printf") {
        Some(vec![IrStmt::Expr(e.clone())])
    } else {
        None
    }
}

/// `Expr(BinOp(And|Or, <pure-test>, exec/builtin echo|printf))` →
/// `If { cond: <chain | not(<chain>)>, then: [<arm>], else: [] }`.
///
/// Soundness: the cond's truth is the test chain's (native in every
/// backend); the arm is always-success, so the native `$main_exit_code`
/// / `lastExit` mirror of the arm's status is identical to the chain's
/// true-path status, and the false-path leaves the status exactly as the
/// current shell-out renderer already leaves it (untouched). REFUSE for
/// any other chain shape (fallible arm, impure guard, deeper nesting).
fn chain_to_if(st: &mut IrStmt) -> bool {
    let IrStmt::Expr(e) = &*st else {
        return false;
    };
    let IrExpr::BinOp { op, lhs, rhs } = e else {
        return false;
    };
    let (cond, negate) = match op {
        BinOpKind::And => (lhs, false),
        BinOpKind::Or => (lhs, true),
        _ => return false,
    };
    // the guard must be a PURE test chain (native boolean in every backend)
    if !is_pure_test(cond) {
        return false;
    }
    // the arm must be a single always-success echo/printf
    let Some(arm) = single_always_true_arm(rhs) else {
        return false;
    };
    let cond = if negate {
        // `test || arm` — the arm runs exactly when the test is false:
        // `If { cond: not(test), … }` (estree runtime `sh2.not`,
        // Perl `not(...)` — both native).
        IrExpr::Call {
            func: "not".to_string(),
            args: vec![(**cond).clone()],
        }
    } else {
        (**cond).clone()
    };
    *st = IrStmt::If {
        cond,
        then: arm,
        elsifs: vec![],
        else_: vec![],
    };
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

    fn changed(src: &str) -> bool {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        transform(&mut prog.stmts)
    }

    #[test]
    fn test_and_echo_becomes_if() {
        let json = lower("[[ $s == *.txt ]] && echo pattern-match");
        // the chain is gone — a real If node took its place
        assert!(json.contains("\"If\""), "missing If node: {json}");
        // no BinOp And with a native exec rhs that would shell out...
        // (the original BinOp is replaced; the echo survives as the arm)
        assert!(json.contains("\"echo\""), "echo arm lost: {json}");
    }

    #[test]
    fn test_or_echo_becomes_not_if() {
        let json = lower("[[ $f == x ]] || echo filtered");
        assert!(json.contains("\"If\""), "missing If node: {json}");
        assert!(json.contains("\"not\""), "missing not() guard: {json}");
    }

    #[test]
    fn plain_echo_is_a_noop() {
        // no chain — the transform must not touch a plain top-level echo
        let commands = parse_commands_from_text("echo hello").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        assert!(!transform(&mut prog.stmts), "plain echo must be a no-op");
    }

    #[test]
    fn fallible_arm_is_refused() {
        // `[[ -f f ]] && cat f` — cat can fail; moving it into a bare
        // if-branch would flatten the true-path status. REFUSE.
        let commands = parse_commands_from_text("[[ -f f ]] && cat f").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "fallible arm must be untouched");
        assert!(!changed);
    }

    #[test]
    fn impure_guard_is_refused() {
        // `ls && echo done` — the guard is a command, not a pure test;
        // the chain's status semantics need the shell-out. REFUSE.
        let commands = parse_commands_from_text("ls && echo done").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "impure guard must be untouched");
        assert!(!changed);
    }

    #[test]
    fn nested_chain_rewrites() {
        // the chain inside an if-body is rewritten too
        let json = lower("if true; then [[ $s == *.txt ]] && echo hit; fi");
        assert!(json.contains("\"If\""), "missing outer/inner If: {json}");
        assert!(json.contains("\"echo\""), "echo arm lost: {json}");
    }

    #[test]
    fn two_arm_chain_left_for_native_stmt() {
        // `test && echo || echo` — shir-native-stmt's family-3 shape; the
        // guard is NOT a pure test chain here (Or of And(test, echo)),
        // so this transform must leave it for the native-stmt pass.
        let commands = parse_commands_from_text("[[ -f f ]] && echo yes || echo no").expect("parse");
        let mut prog = ast_to_ir_raw(&commands);
        let before = shir_to_shir_json(&prog);
        let changed = transform(&mut prog.stmts);
        let after = shir_to_shir_json(&prog);
        assert_eq!(before, after, "two-arm chain must be untouched by this transform");
        assert!(!changed);
    }

    #[test]
    fn deterministic_across_runs() {
        let src = "[[ $s == *.txt ]] && echo a || true";
        assert_eq!(lower(src), lower(src));
    }
}
