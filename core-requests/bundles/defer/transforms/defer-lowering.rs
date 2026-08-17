//! defer-lowering — the §11.4 bundle transform for the `Defer` node
//! (core-requests/bundles/defer/bundle.json).
//!
//! name: defer-lowering
//! depends: [Defer]
//! prereqs: []
//! invariant: only a Defer whose body is a single call is lowered; every
//!   other shape refuses. The lowered form runs the deferred call at the
//!   enclosing function's return (LIFO across defers) — Go semantics.
//!   Non-function contexts refuse.
//! scope: [go, rust, java, c]
//! updates: none
//!
//! PLACEHOLDER — the offerer (go-sh frontend / a backend worker) fills the
//! lowering. The sweep validates the bundle's SPEC + MANIFEST; this module
//! is not wired into any build until the offerer completes it.
use crate::ir::{IrExpr, IrStmt};

pub fn lower_defer(stmts: &mut Vec<IrStmt>) -> bool {
    // TODO(offerer): wrap the enclosing function body so Defer bodies run
    // at return, LIFO. Until then this is a no-op that returns false
    // (the sweep records the bundle as OFFER-PENDING, not PASS).
    let _ = stmts;
    false
}
