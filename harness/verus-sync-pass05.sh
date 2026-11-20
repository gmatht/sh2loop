#!/usr/bin/env bash
# verus-sync-pass05.sh — the source ANCHOR for proofs/verus/optimize_pass05.rs.
#
#   ./harness/verus-sync-pass05.sh            # regenerate to stdout / $OUT_TMP
#   ./harness/verus-sync-pass05.sh --check    # compare with the committed baseline
#
# WHY. `optimize_pass05.rs` proves properties of functions that live in
# `sh2perl/src/ir.rs` (Pass 0.5: `fold_stmt`, `fold_expr`, `pow_wrapping`,
# `fold_bin_op`, `fold_un_op`, `fold_arith_ast`). Verus cannot verify the
# crate — the crate uses `Box`/`String`/`Vec` shapes a spec has no model for —
# so the proof necessarily mirrors the code. This script is the mechanical tie
# that keeps the mirror honest: it emits the verbatim text of the six
# functions plus a content hash, and `harness/verus-gate.sh` regenerates it on
# every gate run and diffs it against the committed baseline
# (`sh2perl/proofs/verus/optimize_pass05_sync.txt`).
#
# WHAT IT CATCHES: any edit to those six functions — a new operator arm, a
# changed guard, a reordered refusal, a renamed helper — changes the emitted
# text or the hash, so the gate goes red until the proof is re-read and the
# baseline re-committed deliberately. Removing or renaming one of the
# functions is FATAL, not silent.
#
# WHAT IT DOES NOT DO: it does not translate Rust to Verus. The spec mirror in
# `optimize_pass05.rs` is still written by hand; this anchor closes the
# "nobody notices the code moved" class, not the "a human mistranscribed it"
# class. The translatable subset is small enough to generate (the repo's
# `verus-sync.sh` already does that for `i32_provable`'s estimator); Pass 0.5
# constructs `ArithAst` values, so a faithful generated expansion also needs a
# Verus datatype for the AST — the next step, not this one.
#
# Exit: 0 emitted (or --check clean); 1 drift / unparseable source.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$root/sh2perl/src/ir.rs"
BASE="$root/sh2perl/proofs/verus/optimize_pass05_sync.txt"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

[ -f "$SRC" ] || { echo "verus-sync-pass05: no source: $SRC" >&2; exit 1; }

gen() {
python3 - "$SRC" <<'PYEOF'
import hashlib, re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
sha = hashlib.sha256(text.encode()).hexdigest()[:12]

FNS = [
    ("fn fold_stmt(s: &IrStmt) -> IrStmt", "fold_stmt"),
    ("fn fold_expr(e: &IrExpr) -> IrExpr", "fold_expr"),
    ("fn pow_wrapping(base: i64, exp: i64) -> i64", "pow_wrapping"),
    ("fn fold_bin_op(op: &str, a: i64, b: i64) -> Option<i64>", "fold_bin_op"),
    ("fn fold_un_op(op: &str, a: i64) -> Option<i64>", "fold_un_op"),
    ("pub(crate) fn fold_arith_ast(ast: &ArithAst) -> ArithAst", "fold_arith_ast"),
]

def balanced(sig, name):
    start = text.find(sig)
    if start < 0:
        print(f"verus-sync-pass05: FATAL: cannot find {name} in {path}", file=sys.stderr)
        print("  (the source outgrew the extractor — extend it, do not hand-edit)", file=sys.stderr)
        sys.exit(1)
    depth, i, n = 0, start, len(text)
    while i < n:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    if depth != 0:
        print(f"verus-sync-pass05: FATAL: unbalanced braces in {name}", file=sys.stderr)
        sys.exit(1)
    return text[start:i + 1]

# The op vocabulary must still be the one the model tables: a new arm is a
# new proof obligation, so it is FATAL here rather than a quiet text change.
fold = balanced("fn fold_bin_op(op: &str, a: i64, b: i64) -> Option<i64>", "fold_bin_op")
# A line-initial string literal in fold_bin_op is an ARM (some arms carry an
# `if` guard, which a stricter pattern would miss).
ops = set(re.findall(r'^\s*"([^"]+)"', fold, re.M))
expected = {"+", "-", "*", "/", "%", "&", "|", "^", ">>", "<<", "&&", "||", "**"}
if not expected.issubset(ops):
    print(f"verus-sync-pass05: FATAL: fold_bin_op lost arms: {sorted(expected - ops)}", file=sys.stderr)
    sys.exit(1)

print(f"// GENERATED from sh2perl/src/ir.rs @ {sha}")
print("// DO NOT EDIT — run harness/verus-sync-pass05.sh")
print("// Region: optimize_stmts Pass 0.5 — the constant fold that runs on EVERY")
print("// program. The Verus model sh2perl/proofs/verus/optimize_pass05.rs")
print("// mirrors these six functions; this baseline is how the gate notices")
print("// that the code moved under it.")
print(f"// fold_bin_op arms in scope: {' '.join(sorted(ops))}")
print()
for sig, name in FNS:
    print(f"// ---- {name} ----")
    print(balanced(sig, name))
    print()
PYEOF
}

if [ "$CHECK" -eq 1 ]; then
  tmp="$(mktemp)"
  OUT_TMP="$tmp" bash "${BASH_SOURCE[0]}" || { rm -f "$tmp"; exit 1; }
  if diff -u "$BASE" "$tmp"; then
    echo "verus-sync-pass05: clean ($(wc -l < "$tmp") lines)"
    rm -f "$tmp"
    exit 0
  fi
  rm -f "$tmp"
  echo "verus-sync-pass05: DRIFT — regenerate the baseline and re-read the model" >&2
  exit 1
fi

if [ -n "${OUT_TMP:-}" ]; then
  gen > "$OUT_TMP"
else
  gen
fi
