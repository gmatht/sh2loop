# c-sh-go: asmStatement coverage needs the A1 Asm node (sibling of c-sh-go-asm-20260814-012824.md)

Companion to the pending request `core-requests/c-sh-go-asm-20260814-012824.md`
(inline-asm statement node, covering asmOperand / asmDefinition /
asmClobbers) and its siblings `core-requests/c-sh-go-asmargument-20260814-020654.md`
(the top-level asmArgument rule) and `core-requests/c-sh-go-asmqualifier-20260814-021445.md`
(the asmQualifier rule). This request pins the STATEMENT rule itself —
grammars-v4 C.g4: `asmStatement: asmQualifier? asmArgument ';'` — the
grammar rule the rules-gap check reports unexercised. All four requests
are COMPATIBLE: one `Asm` node in the A1 contract satisfies every one of
them (the family request already names `asmStatement` in its title; this
file confirms it as the surfaced gap and records the observed behavior).

## NEED

The A1 shIR contract must gain an inline-assembly statement node so the
c-sh-go frontend can PARSE and EMIT `asmStatement` (the full GNU asm
statement: optional qualifier, template string, optional output/input
operand sections, optional clobbers — terminated by `;`) instead of
silently dropping or refusing it. Proposed shape (same as
c-sh-go-asm-20260814-012824.md):

```json
{"type": "Asm", "template": "mov %1, %0",
 "outputs": [{"constraint": "=r", "target": "x"}],
 "inputs":  [{"constraint": "r",  "expr": "y"}],
 "clobbers": ["cc"]}
```

- `template`: the raw assembly template string, verbatim — the minimal
  `asmStatement` form (`asm("nop");` = template only, no sections).
- `outputs` / `inputs`: the `asmOperand` bindings (constraint string +
  the C lvalue/expression, lowered with the frontend's existing
  `valueNode` machinery).
- `clobbers`: the `asmClobbers` list.
- `volatile` / `inline` / `goto` qualifiers: a `volatile` bool field
  (the others carry no runtime meaning — the frontend may drop them).
- Deserializer support in `shir_json_in.rs` (the frontend's emit must
  round-trip through the core deserializer — the ingress gate).
- An ESTree renderer lowering. JS cannot execute machine code; a no-op
  with a generated `// asm: <template>` comment is the faithful lowering
  ONLY for effect-free asm. The estree worker mediates the renderer
  choice (see WHY — the executed-stdout oracle constrains what an
  example can exercise).

## WHY

The external-grammar coverage check (`rules-gap.sh c-sh-go`,
PARSER_GAPS.md) reports `asmStatement` unexercised; no testdata example
covers it. Verified against the current frontend binary:

- `asm("nop");` (the minimal asmStatement) exits 0 but is SILENTLY
  DROPPED — the emit contains no node for it (unknown call-statement
  name → `nil, nil`). A guess, not an expression: `asm` can have
  observable effects, and the frontend's own rule is REFUSE > GUESS
  (GOOD_EXAMPLES.md). No testdata example can be written for it — the
  gate would pass on a program whose asm vanished.
- `asm("mov %1, %0" : "=r"(x) : "r"(y) : "cc");` REFUSES:
  `REFUSE: expected "," at token {op :}` — the statement parser routes
  `asm` to the call-form path, which has no operand grammar.

FRONTEND.md's "Still refused (honest)" lists do not document asm as a
by-design subset exclusion; PARSER_GAPS.md classifies the family as
category 1 (A1-EXTENSION). The frontend tokenizer already handles every
token the statement needs — the only missing piece is an A1 node to
carry the construct.

## MINIMAL-CORE-CHANGE

Identical to the family request `c-sh-go-asm-20260814-012824.md`
(compatible with the asmargument / asmqualifier siblings):

1. Add an `Asm` statement variant to the A1 contract (shir_json.rs) and
   its deserializer (shir_json_in.rs), shape as in NEED. The `Asm` node
   is a statement; `outputs`/`inputs` reference variables by the
   store-name convention (same as `Var`/`Assign`); `expr`/`target`
   fields reuse the existing value-node serialization (string or
   `Arith`).
2. ESTree renderer (estree.rs): lower `Asm` to an emitted comment /
   no-op. NOTE: with a no-op lowering, the executed-stdout oracle
   (native gcc vs JS) DIFFS whenever the asm has observable effects
   (operand writes), so an oracle-passing example can only use
   effect-free asm (`asm("nop");` — exercises `asmStatement`, not
   `asmOperand`). If the renderer instead refuses on non-empty
   operands, the node still closes the frontend emit gap and the
   coverage question stays honest; the estree worker mediates.
3. No changes to src/parser/ (the shared core parses no C) and no
   changes to the frontend's Go parser needed for the CONTRACT — the
   frontend side (asm parse path) is a separate, follow-on frontend
   change once the node exists.

## FAILING-CASE

```c
#include <stdio.h>

int main(void) {
    int x = 0, y = 5;
    asm("mov %1, %0" : "=r"(x) : "r"(y) : "cc");
    printf("%d\n", x);
    return 0;
}
```

Current behavior (frontend emit): exit 1, `REFUSE: expected "," at
token {op :}` — the operand section cannot be expressed. The minimal
form `asm("nop");` exits 0 but the statement VANISHES from the emit
(silent drop — a guess). With an `Asm` node, the frontend emits the
construct (gate: valid A1 shIR); the executed-stdout oracle semantics
are the estree worker's call per the mediation rules (the example above
would DIFF under a no-op lowering — the honest testdata form is
`asm("nop");` with no operands).

Asm statement node landed in the shared core (ir.rs IrStmt::Asm, shir_json.rs/shir_json_in.rs A1 serialization with string-or-node operands, estree renderer no-op carrying the template with output-drop flags; perl/sh/go/rust/zig/glsl backends refuse loudly). Verified: value-node + minimal string-operand + template-only forms ingress and render. estree corpus 521/521, perl 320, cargo test --lib 264/0.
## OUTCOME: implemented

