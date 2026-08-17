//! defer-cleanup-list — alternative `Defer` lowering (offered by a backend
//! that prefers a runtime cleanup list over a static try/finally).
//!
//! name: defer-cleanup-list
//! depends: [Defer]
//! prereqs: []
//! invariant: same subset as defer-lowering (single-call bodies only);
//!   the deferred calls run at function return in a runtime cleanup list.
//! scope: [java]
//! updates: none
//!
//! PLACEHOLDER — the java backend offerer fills the lowering.
use crate::ir::{IrExpr, IrStmt};
pub fn lower_defer_cleanup(stmts: &mut Vec<IrStmt>) -> bool {
    let _ = stmts;
    false
}
