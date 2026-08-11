# c-sh-go: float arithmetic in the runtime (`sh2.floatArith`)

## NEED
The c-sh-go now lowers `double`/`float` types and float literals
(`1.5`, `2.0`) but `printf("%.1f\n", 1.5 * 2.0)` (testdata/t23_float.c)
still outputs `0.0` because the runtime's `sh2.arith(<string>)` uses
bash's integer-only arithmetic (`$(( 1.5 * 2.0 ))` is a bash syntax
error). The c-sh-go's `x * 2.0` lowers to a string call
`sh2.arith("($x * 2.0)")`; the runtime substitutes `$x` → `"1.5"`,
then bash's int-only eval returns `0` (or refuses on the literal
`2.0`).

## WHY
- t23_float.c is the last remaining gate failure in the c-sh-go fleet
  (30/31; the other 30 are green after the c-sh-go worker's
  recent `Label`/`Goto` emission work and my fix to
  `RestructureGoto::handle_nested` which was escaping the program on
  Block-wrapped loop bodies).
- The c-sh-go's `Arith` AST path can't represent floats (the core
  `ArithAst::Num` is `i64`); a string-based `sh2.arith` was the
  pragmatic fix, but the runtime's eval is integer-only.
- `IrType::Float(u8)` is now in the core (commit c45800e, Aug 7
  13:29) — the type lattice is ready, but the runtime's arith
  pipeline still rejects float literals.

## MINIMAL-CORE-CHANGE
Two additive, non-breaking options. Either is fine; the smaller is
the first:

1. **Add `sh2.floatArith(src)` to the runtime** (`harness/sh2-namespace.mjs`):
   ```
   floatArith(src) {
     // Float-aware bash arithmetic: substitute $vars (same as arith),
     // then evaluate the expression as JS (which handles floats
     // natively — bash's $(( )) is integer-only and refuses `.5`).
     try {
       const s = arithExpand(this, String(src));
       if (!/^[\d\s()+\-*/%<>=!&|^~?.eE]+$/.test(s)) {
         return ARITH_BAD_MAGIC; // refuse non-arithmetic
       }
       return String(Function('"use strict"; return (' + s + ')')());
     } catch {
       return ARITH_BAD_MAGIC;
     }
   }
   ```
   The c-sh-go emits `sh2.floatArith("($x * 2.0)")` instead of
   `sh2.arith("($x * 2.0)")` when the c-sh-go's `hasFloat(e)` walker
   sees a `.` in any operand (already implemented locally, gate is
   `IR_emit_calls_sh2_floatArith`).

   (preferred) Or add the float-arith path inside the existing
   `sh2.arith`: detect `.` in the expanded string and dispatch to
   the float eval. One runtime, one entry point, no caller change
   needed.

2. **OR** extend `ArithAst::Num` to support floats — but this is a
   bigger change touching every backend (Perl/ESTree renderers,
   `arith_ast_to_perl`, etc.) and doesn't help t23 in isolation
   (printf is the consumer, not the arith result).

## FAILING-CASE
`frontends/c-sh-go/testdata/t23_float.c`:
```c
int main(void) {
    double x = 1.5;
    double y = x * 2.0;
    printf("%.1f\n", y);
    return 0;
}
```
Expected: `3.0`. Actual: `0.0`.

## STATUS (2026-08-07)
- c-sh-go gate: **30/31** (was 26/31 before this work session;
  +4 from c-sh-go's `Label`/`Goto` emission, +1 from the
  `RestructureGoto::handle_nested` shared-core fix, -1 from t23
  still open).
- c-sh-go diff (committed in this work session): `main.go` has
  float-literal lexing, `double`/`float` type-keyword handling,
  `testExpr` top-level-id -ne 0 numeric-truth fix, `wrapForContinues`
  for `for`/`continue` interaction, `Label`/`Goto` parser emission
  with flat list-return flattening, and `hasFloat`/`exprToArithString`
  helpers for the float-arith string call.
- The c-sh-go worker was killed for this work session; it will
  resume on restart and pick up the WIP.
