# c-sh-go: asmArgument coverage needs the A1 Asm node (sibling of c-sh-go-asm-20260814-012824.md)

Companion to the pending request `core-requests/c-sh-go-asm-20260814-012824.md`
(inline-asm statement node, covering asmOperand / asmDefinition / asmClobbers).
This request adds the TOP-LEVEL grammar rule of the same family — `asmArgument`
(grammars-v4 C.g4: `asmStringLiteral [':' asmOperands? (':' asmOperands?
(':' asmClobbers?)*)?]`) — so the implemented `Asm` node is verified against
the full asm statement shape, not just its operand sub-rules. The two requests
are COMPATIBLE: one `Asm` node satisfies both.

## NEED

The A1 shIR contract must gain an inline-assembly statement node so the
c-sh-go frontend can PARSE and EMIT the `asmArgument` rule (the complete
GNU asm statement: template string + optional output/input operand
sections + optional clobbers) instead of silently dropping or refusing
it. Proposed shape (same as c-sh-go-asm-20260814-012824.md):

```json
{"type": "Asm", "template": "mov %1, %0",
 "outputs": [{"constraint": "=r", "target": "x"}],
 "inputs":  [{"constraint": "r",  "expr": "y"}],
 "clobbers": ["cc"]}
```

- `template`: the raw assembly template string, verbatim — this is the
  minimal `asmArgument` form (`asm("nop")` = template only, no
  sections).
- `outputs` / `inputs`: the `asmOperand` bindings (constraint string +
  lowered C lvalue/expression) — the `:`-separated sections of the full
  `asmArgument` form.
- `clobbers`: the `asmClobbers` list (the optional third section).
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

The external-grammar coverage check (`rules-gap.sh c-sh-go`, PARSER_GAPS.md)
reports `asmArgument` unexercised (category 1 — A1-EXTENSION: "raw assembler
— target-specific, and the estree runtime can't execute it"); no testdata
example covers it. Verified against the current frontend binary:

- `asm("nop");` — the minimal asmArgument form (template only): exits 0
  but the statement is SILENTLY DROPPED from the emitted A1 (an unknown
  call-statement name → `nil, nil`): a guess, not an expression — `asm`
  can have observable effects, and the frontend's own rule is
  refuse > guess. A testdata example of this form would pass the
  executed-stdout oracle (gcc: `nop` has no stdout effect) while the A1
  carries NOTHING — blessing a silent drop, which the workspace
  guardrails forbid.
- `asm("mov %1, %0" : "=r"(x) : "r"(y) : "cc");` — the full asmArgument
  form: REFUSES with `REFUSE: expected "," at token {op :}` — the
  statement parser routes `asm` to the call-form path, which has no
  operand grammar. This is a parser gap, not a clean by-design subset
  refusal.

FRONTEND.md's "Still refused (honest)" lists do not document asm as a
by-design subset exclusion; PARSER_GAPS.md classifies the family as
category 1 (A1-EXTENSION), and the sibling request
c-sh-go-asm-20260814-012824.md (pending) is already being implemented by
the estree worker. The frontend tokenizer already handles every token the
asmArgument grammar needs — the only missing piece is an A1 node to carry
the construct.

## MINIMAL-CORE-CHANGE

1. Add an `Asm` statement variant to the A1 contract (shir_json.rs) and
   its deserializer (shir_json_in.rs), shape as in NEED — identical to
   the change requested by c-sh-go-asm-20260814-012824.md. The `Asm`
   node is a statement; `outputs`/`inputs` reference variables by the
   store-name convention (same as `Var`/`Assign`); `expr`/`target`
   fields reuse the existing value-node serialization (string or
   `Arith`). `template` is a plain string; an empty `outputs`/`inputs`/
   `clobbers` array covers the minimal `asm("nop")` form of
   `asmArgument`.
2. ESTree renderer (estree.rs): lower `Asm` to an emitted comment /
   no-op. NOTE: with a no-op lowering, the executed-stdout oracle
   (native gcc vs JS) DIFFS whenever the asm has observable effects
   (operand writes), so an oracle-passing example can only use
   effect-free asm (`asm("nop");`). If the renderer instead refuses on
   non-empty operands, the node still closes the frontend emit gap and
   the coverage question stays honest; the estree worker mediates.
3. No changes to src/parser/ (the shared core parses no C). The
   frontend-side asm parse path (a follow-on frontend change once the
   node exists) is out of scope for the core.

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
token {op :}` — the operand sections of `asmArgument` cannot be
expressed. The minimal form `asm("nop");` exits 0 but is silently
dropped (no A1 node). With an `Asm` node, the frontend emits the
construct (gate: valid A1 shIR); the executed-stdout oracle semantics
are the estree worker's call per the mediation rules (the example above
would DIFF under a no-op lowering — the honest testdata form is
`asm("nop");` with no operands).

Asm statement node landed in the shared core (ir.rs IrStmt::Asm, shir_json.rs/shir_json_in.rs A1 serialization with string-or-node operands, estree renderer no-op carrying the template with output-drop flags; perl/sh/go/rust/zig/glsl backends refuse loudly). Verified: value-node + minimal string-operand + template-only forms ingress and render. estree corpus 521/521, perl 320, cargo test --lib 264/0.
## OUTCOME: implemented

