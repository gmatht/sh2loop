//! sort-uniq-pipeline — the §11.4 bundle transform for the `SortLines`
//! node (core-requests/bundles/sort-uniq-pipeline/bundle.json).
//!
//! name: sort-uniq-pipeline
//! depends: [SortLines]
//! prereqs: []
//! invariant: ONLY the exact py-sh-go `sorted()` lowering shape lifts:
//!   Capture { Arrow { Pipeline [ exec printf "%s\n" <whole-array-read>,
//!                                exec sort [-n] [-u],
//!                                exec awk <comma-join program> ] } }
//!   (the awk stage is OPTIONAL — `sorted(x)` without the join prints
//!   newline-separated). Any other stage, flag outside {-n,-u}, custom
//!   key (-k/-t), non-trivial awk, or a non-whole-array first argument
//!   refuses (open node model, refuse > guess). Status-preserving
//!   (lastExit 0) and byte-preserving (LC_ALL=C collation is the sort
//!   contract).
//! scope: [estree, go, c, perl, python, rust, java, zig]
//! updates: none
//!
//! PLACEHOLDER — the offerer (py-sh-go frontend / the estree worker) fills
//! the lowering: rewrite the Capture-of-Pipeline into
//! `Capture { Arrow { Expr(Call("SortLines", [values, numeric?, unique?,
//! join?])) } }` (the capture's newline tail must be preserved — the
//! pipeline's awk emits NO trailing newline; the node joins on ", " with
//! none either, so the capture bytes stay identical). Until then this is
//! a no-op (the sweep records the bundle OFFER-PENDING, not PASS).
use crate::ir::{IrExpr, IrStmt};

pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let _ = stmts;
    // TODO(offerer): the recognizer walks every Capture{Arrow{Pipeline}}
    // site (function bodies included), matches the exact shape above,
    // and rewrites it to the SortLines contract expression.
    false
}
