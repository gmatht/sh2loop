# c-sh-go: asmStringLiteral coverage needs the A1 Asm node (companion to the pending c-sh-go-asm family)

Companion to the pending requests `core-requests/c-sh-go-asm-20260814-012824.md`
(inline-asm statement node, covering asmOperand / asmDefinition /
asmClobbers), `core-requests/c-sh-go-asmargument-20260814-020654.md`
(asmArgument), `core-requests/c-sh-go-asmqualifier-20260814-021445.md`
(asmQualifier) and `core-requests/c-sh-go-asmstatement-20260814-024404.md`
(asmStatement). This request pins the STRING rule itself — grammars-v4
C.g4: `asmStringLiteral : StringLiteral ;` — the rule the rules-gap check
currently reports unexercised (it is NOT yet ledgered in
frontends/coverage/core-pending-c-sh-go.txt, so it surfaces as a gap).
It is fully COMPATIBLE with the family: the single `Asm` node the family
request proposes satisfies this rule too (`template` carries the
asmStringLiteral text verbatim).

## NEED

The A1 shIR contract must gain an inline-assembly statement node so the
c-sh-go frontend can PARSE and EMIT the asm family — and with it the
`asmStringLiteral` rule, which is the template string inside EVERY asm
form (`simpleAsmExpr: asm_ '(' asmStringLiteral ')'`, `asmArgument`,
`toplevelAsmArgument`, `asmOperand`, `asmClobbers`). Proposed shape
(same as c-sh-go-asm-20260814-012824.md):

```json
{"type": "Asm", "template": "nop", "volatile": false,
 "outputs": [], "inputs": [], "clobbers": []}
```

- `template`: the raw assembly template string (the asmStringLiteral),
  verbatim.
- `outputs` / `inputs`: the `asmOperand` bindings (constraint string +
  the C lvalue/expression, lowered with the frontend's existing
  `valueNode` machinery).
- `clobbers`: the `asmClobbers` list.
- `volatile`: the asmQualifier (compiler hint, no runtime meaning).
- Deserializer support in `shir_json_in.rs` (the frontend's emit must
  round-trip through the core deserializer — the ingress gate).
- An ESTree renderer lowering. JS cannot execute machine code; a no-op
  with a generated `// asm: <template>` comment is the faithful lowering
  ONLY for effect-free asm (empty outputs). The estree worker mediates
  the renderer choice (see WHY — the executed-stdout oracle constrains
  what an example can exercise).

## WHY

The external-grammar coverage check (`rules-gap.sh c-sh-go`,
PARSER_GAPS.md) reports `asmStringLiteral` unexercised; no testdata
example covers it. Verified against the current frontend binary:

- `asm("nop");` (the minimal asmStringLiteral carrier — the
  `simpleAsmExpr` / bare-`asmArgument` form) exits 0 but is SILENTLY
  DROPPED — the emit contains no node for it (unknown call-statement
  name → `nil, nil`). A guess, not an expression: the frontend's own
  rule is REFUSE > GUESS, and no testdata example can be written for a
  construct the emit does not carry (the gate would pass on a program
  whose asm vanished).
- `asm("nop" : : : "cc");` and the operand forms REFUSE:
  `REFUSE: expected "," at token {op :}` — the statement parser routes
  `asm` to the call-form path, which has no operand grammar.

FRONTEND.md's "Still refused (honest)" lists do not document asm as a
by-design subset exclusion; PARSER_GAPS.md classifies the family as
category 1 (A1-EXTENSION). The frontend tokenizer already handles every
token the statement needs — the only missing piece is an A1 node to
carry the construct. The family escalation is pending in core-requests/
(the estree worker is mid-implementation); this file pins the
specifically surfaced rule so it joins the same batch.

## MINIMAL-CORE-CHANGE

Identical to the family request `c-sh-go-asm-20260814-012824.md`
(compatible with the asmargument / asmqualifier / asmstatement
siblings — one `Asm` node satisfies all of them):

1. Add an `Asm` statement variant to the A1 contract (shir_json.rs) and
   its deserializer (shir_json_in.rs), shape as in NEED. The `Asm` node
   is a statement; `outputs`/`inputs` reference variables by the
   store-name convention (same as `Var`/`Assign`); `template` is the
   raw asmStringLiteral text.
2. ESTree renderer (estree.rs / shir.rs): lower `Asm` to an emitted
   comment / no-op. NOTE: with a no-op lowering, the executed-stdout
   oracle (native gcc vs JS) DIFFS whenever the asm has observable
   effects (operand writes), so an oracle-passing example can only use
   effect-free asm (`asm("nop");` — exercises `asmStringLiteral`
   through `simpleAsmExpr`, not `asmOperand`). The estree worker
   mediates.
3. No changes to src/parser/ (the shared core parses no C) and no
   changes to the frontend's Go parser needed for the CONTRACT — the
   frontend side (asm parse path) is a separate, follow-on frontend
   change once the node exists.

## FAILING-CASE

```c
#include <stdio.h>

int main(void) {
    asm("nop");
    printf("hi\n");
    return 0;
}
```

Current behavior (frontend emit): exit 0, but the emit contains NO node
for the asm statement (silent drop — the program prints `hi` in both
gcc and JS, so the oracle cannot distinguish the drop; the coverage
question stays open). With an `Asm` node, the frontend emits the
construct (gate: valid A1 shIR); the executed-stdout oracle semantics
are the estree worker's call per the mediation rules (the honest
testdata form is `asm("nop");` with no operands — effect-free, exact
under a no-op lowering).

Asm statement node landed in the shared core (ir.rs IrStmt::Asm, shir_json.rs/shir_json_in.rs A1 serialization with string-or-node operands, estree renderer no-op carrying the template with output-drop flags; perl/sh/go/rust/zig/glsl backends refuse loudly). Verified: value-node + minimal string-operand + template-only forms ingress and render. estree corpus 521/521, perl 320, cargo test --lib 264/0.
## OUTCOME: implemented

