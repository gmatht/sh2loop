# c-sh-go: asmQualifier coverage needs an Asm-node qualifier field (sibling of c-sh-go-asm-20260814-012824.md)

Companion to the pending request `core-requests/c-sh-go-asm-20260814-012824.md`
(inline-asm statement node, covering asmOperand / asmDefinition /
asmClobbers) and `core-requests/c-sh-go-asmargument-20260814-020654.md`
(the top-level asmArgument rule). This request adds the `asmQualifier`
rule specifically (grammars-v4 C.g4: `asmQualifier: 'volatile' | 'inline'
| 'goto';` — the optional keyword between `asm` and `(`). The three
requests are COMPATIBLE: one `Asm` node with a qualifier field satisfies
all of them.

## NEED

The A1 shIR contract's inline-assembly statement node must carry the
`asmQualifier` — minimally a `volatile` bool field on the `Asm` node
(`inline` and `goto` are droppable: no runtime meaning, but the
frontend must PARSE them, and `goto` changes the operand grammar to
labels, so it should be recorded or refused honestly, never silently
dropped). Proposed shape (extends the family request's):

```json
{"type": "Asm", "template": "nop",
 "volatile": true,
 "outputs": [], "inputs": [], "clobbers": []}
```

- `volatile`: true when the source wrote `asm volatile (...)`; the
  qualifier is a compiler hint with no runtime effect in the A1 model.
- Deserializer support in `shir_json_in.rs` (the frontend's emit must
  round-trip through the core deserializer — the ingress gate).
- ESTree renderer lowering: with a no-op lowering, an oracle-passing
  example can only use effect-free asm (`asm volatile("nop");`); the
  estree worker mediates the renderer choice per the family request.

## WHY

The external-grammar coverage check (`rules-gap.sh c-sh-go`,
PARSER_GAPS.md) reports `asmQualifier` unexercised; no testdata example
covers it. Verified against the current frontend binary:

- `asm volatile("nop");` exits 0 but the statement is SILENTLY DROPPED
  (the emitted A1 has empty `stmts`): the `asm` call-form path has no
  qualifier grammar, so it guesses instead of expressing — a violation
  of the frontend's own refuse > guess rule (`asm` can have observable
  effects).
- `asm volatile("nop" : : "r"(x) : "cc");` is likewise dropped (the
  operand sections never reach the parser's error path because the
  statement is discarded before the operand scan).

FRONTEND.md's "Still refused (honest)" lists do not document asm as a
by-design subset exclusion; PARSER_GAPS.md classifies the asm family as
category 1 (A1-EXTENSION). The frontend tokenizer already lexes
`volatile` as an identifier — the only missing pieces are the A1 node
(family request) and its qualifier field (this request).

## MINIMAL-CORE-CHANGE

1. On the `Asm` statement variant proposed in
   `c-sh-go-asm-20260814-012824.md`, add a `volatile` bool field
   (default false when absent — keeps the family request's shape
   backward-compatible), plus its deserializer handling in
   `shir_json_in.rs`.
2. ESTree renderer (estree.rs): lower `Asm` (with or without
   `volatile`) to an emitted comment / no-op — `volatile` changes
   nothing in the lowering (it is a codegen hint). With a no-op
   lowering, the executed-stdout oracle (native gcc vs JS) DIFFS
   whenever the asm has observable effects, so an oracle-passing
   example can only use effect-free asm; the estree worker mediates.
3. No changes to src/parser/ (the shared core parses no C) and no
   changes to the frontend's Go parser needed for the CONTRACT — the
   frontend side (asm parse path, qualifier acceptance) is a separate,
   follow-on frontend change once the node + field exist.

## FAILING-CASE

```c
#include <stdio.h>

int main(void) {
    asm volatile("nop");
    printf("ok\n");
    return 0;
}
```

Current behavior (frontend emit): exit 0, but the emitted A1 `stmts`
contain ONLY the printf — the `asm volatile("nop");` statement is
silently dropped (a guess, not an expression; the construct can have
observable effects). With an `Asm` node + `volatile` field, the
frontend emits the construct (gate: valid A1 shIR); the executed-stdout
oracle semantics are the estree worker's call per the mediation rules.

Asm statement node landed in the shared core (ir.rs IrStmt::Asm, shir_json.rs/shir_json_in.rs A1 serialization with string-or-node operands, estree renderer no-op carrying the template with output-drop flags; perl/sh/go/rust/zig/glsl backends refuse loudly). Verified: value-node + minimal string-operand + template-only forms ingress and render. estree corpus 521/521, perl 320, cargo test --lib 264/0.
## OUTCOME: implemented

