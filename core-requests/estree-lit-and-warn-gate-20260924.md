# estree: `console.warn` violates the structural gate's sh2.*-callee rule

## NEED
The `parse-unexpected-braceclose.sh` / `parse-unexpected-parenclose.sh`
corpus examples fail with:

    gate: FAIL: non-sh2 callee: warn

## WHY
`IrStmt::Warn` (src/shir.rs ~37052) lowers to a raw `console.warn(value)`
MemberExpression call. `harness/estree_gate.pl` check (b) requires EVERY
CallExpression callee to be a `sh2.<name>` member with `<name>` in the
whitelist (plus the `sh2.fs.<name>` surface). `console.warn` therefore
fails the gate by construction — the emitter and the gate disagree.

(The comment claims a fallback `sh2.warn(value)` exists; it does not.)

## MINIMAL-CORE-CHANGE
Either:
1. emit `sh2.warn(value)` and register `warn` in the whitelist +
   `harness/sh2-namespace.json` + a `warn(v)` method in
   `harness/sh2-namespace.mjs` (mirrors how `lit` was just registered), or
2. teach the gate that `console.warn` is an allowed callee (weaker — it
   widens the "no non-sh2 callee" invariant).

Option 1 is preferred: it keeps the single invariant and matches the
`die` op, which already lowers through `sh2_call("die", ...)`.

## FAILING-CASE
    sh2perl/examples/parse-unexpected-braceclose.sh
    sh2perl/examples/parse-unexpected-parenclose.sh
    # `echo "hello"` + a stray `}`; emits a Warn statement for the
    # unexpected BraceClose.

## NOTE
Independent of the `lit` registration (already landed in
67754dc2/f546f64a + sh2perl 12c643a8f), which cleared 21 of the 30
estree failures. This is the remaining 2-of-10 gate failures.
