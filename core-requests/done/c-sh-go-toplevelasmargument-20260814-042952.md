# c-sh-go: toplevelAsmArgument needs a DECLARATION-position asm (the landed Asm node is statement-only)

Companion to the implemented family request
`core-requests/done/c-sh-go-asmstringliteral-20260814-030615.md` (the
`Asm` statement node landed: `IrStmt::Asm` in ir.rs, A1 serialization in
shir_json.rs / shir_json_in.rs, estree no-op renderer). This request pins
the rule the family's single STATEMENT node does not carry:
`toplevelAsmArgument` is the argument of `asmDefinition`
(`asm_ '(' toplevelAsmArgument ')'`), which is the DECLARATOR-extension /
file-scope asm form (GCC asm labels) — NOT the statement form
`asmStatement` (`asm_ asmQualifierList? '(' asmArgument ')' ';'`), which
the landed node covers.

## NEED

The A1 contract needs a position for a DECLARATION-attached asm label
(GCC asm labels: `int x asm("myx");`). The landed `IrStmt::Asm` is a
statement (Program.stmts / sub bodies); the A1 declaration shapes
(`Assign`, `Var`/`var_types`) carry no asm field, so the only gcc-valid
carrier of `toplevelAsmArgument` is unrepresentable. Options for the
estree worker (single owner of the contract) to mediate:

1. an optional `asm` field on the A1 declaration/`Assign` serialization —
   `{"type":"Assign",...,"asm":{"template":"myx","volatile":false,
   "outputs":[],"inputs":[],"clobbers":[]}}` — reusing the existing Asm
   operand shapes (`asm_operands_from` in shir_json_in.rs), or
2. a standalone `AsmDef` node for the file-scope/declarator position
   (same template/volatile/outputs/inputs/clobbers shape), or
3. an explicit ruling that the asm-label form stays refused (ledgered),
   if the symbol-name semantics are judged out of scope — the c-sh-go
   frontend then gets a LOUD-refuse path instead of the current silent
   drop.

The frontend needs one of these to proceed: today it has no asm grammar
at all and silently DROPS the construct (exit 0, no node — and the
surrounding declarator's initializer vanishes too), which is a guess, not
an expression (the frontend rule is refuse > guess).

## WHY

The external-grammar coverage check (`rules-gap.sh c-sh-go`) reports
`toplevelAsmArgument` unexercised; no testdata example can be written for
a construct the emit does not carry (the gate would pass on a program
whose asm vanished — the same trap the asmstringliteral request
documented). PARSER_GAPS.md classifies the asm family as category 1
(A1-EXTENSION), not a by-design subset exclusion, and the family request
(c-sh-go-asm-20260814-012824.md) explicitly listed asmDefinition among
the rules the Asm node was to satisfy — but the implemented node is
statement-position only. Verified against the current frontend binary:

- `int x asm("myx") = 7; int main(void){ printf("%d\n", x); }` — exits 0,
  but the emit contains NO Assign for x (the initializer is silently
  dropped along with the asm label; `var_types` lists x as Int32 and the
  printf reads an unset var → 0).
- gcc accepts the construct (`gcc -std=gnu11` compiles and prints 7), so
  the executed-stdout oracle would DIFF — but the frontend emit check
  passes first (exit 0), so the gate would pass on the emitted-away
  construct. The oracle cannot distinguish the drop.
- gcc REJECTS the other carrier: file-scope asm with operands
  (`asm("nop" : "=r"(x));` at translation-unit level — "expected ')'"),
  so the DECLARATOR asm label is the only gcc-valid form entering
  `toplevelAsmArgument`.

## MINIMAL-CORE-CHANGE

Smallest option: add the optional `asm` field to the A1 declaration /
`Assign` JSON shape (shir_json.rs serializer + shir_json_in.rs
deserializer), carrying `{"template","volatile","outputs","inputs",
"clobbers"}` with the existing Asm operand serialization (string-or-node
operands, `asm_operands_from`). No changes to src/parser/ (the shared
core parses no C). The estree no-op renderer lowering already exists
(template comment; an asm label has no runtime effect in the JS model —
the symbol it names does not exist, so the no-op is oracle-faithful). The
c-sh-go frontend's follow-on parse path (a separate frontend change, as
with the rest of the family) then emits the construct or refuses loudly.

## FAILING-CASE

```c
#include <stdio.h>

int x asm("myx") = 7;

int main(void) {
    printf("%d\n", x);
    return 0;
}
```

Current behavior (frontend emit): exit 0, but the emit contains NO node
for the asm label AND drops the `= 7` initializer (x appears only in
`var_types`; the printf reads an unset var). gcc prints 7 — the
executed-stdout oracle would DIFF, but the gate's ingress check passes
first because the frontend exits 0 (silent drop, not a refusal). With a
declaration-position asm field, the frontend emits the construct (gate:
valid A1 shIR); the estree no-op keeps the oracle exact (the label has no
runtime effect in JS).

## OUTCOME: implemented
