# c: `var_types` ingress rejects the `AsciiStr` verdict the A2 analysis now emits

## NEED

`ir_type_from` (the shIR JSON **ingress** parser in `src/shir_json_in.rs`) does not
accept the `{"kind":"AsciiStr"}` `var_types` verdict. Any shIR JSON whose program
has an ASCII-promoted `var` fails to deserialize, so the render never happens.

This is a hard ingress error, not a soft-degrade: the backend worker cannot work
around it from the worktree, because the only place the verdict is parsed is
shared core.

## WHY

Three core facts drifted apart:

1. `src/ir.rs` has carried the `IrType::AsciiStr` variant for a while, and its
   `Deserialize` impl (`visit_map`, `Some("AsciiStr") => Ok(IrType::AsciiStr)`)
   accepts it.
2. `src/shir.rs` (`promote_ascii` / the fixed-point around line 7870) now
   **emits** `IrType::AsciiStr` in `var_types`.
3. `ir_type_from` in `src/shir_json_in.rs` — a *separate, hand-rolled* parser used
   for the `var_types` / `requires.ty` ingress path — never learned the arm. Its
   `kind` match only handles `Float` / `Int32` / `Int64` / `UInt32` / `UInt64`.

So the producer and the type both speak `AsciiStr`, but the shIR-JSON ingress
parser does not. Every backend going through that ingress is broken for any
program with an ASCII-promoted variable.

Measured on the live corpus (`otranspilerl-cli --target shir --raw`, 647 files),
51 `var_types` entries are `{"kind":"AsciiStr"}` — so this is not a rare edge
case, it is ~a third of the corpus's *files* touched by a first failing render.

## MINIMAL-CORE-CHANGE

Add one arm to the `kind` match in `ir_type_from` (`src/shir_json_in.rs`):

```rust
Some("AsciiStr") => Ok(IrType::AsciiStr),
```

That is the whole fix. It mirrors what `ir.rs`'s own `Deserialize` already does,
so it is a strict consistency repair, not a contract change.

Optional hardening, same function, no behaviour change for current producers:
make the `kind` arm's fallback warn-and-default to `IrType::Str` for a
**string-ish** unknown kind rather than hard-erroring, so a future additive
string verdict degrades to "treat as Str" (the documented no-op for backends that
ignore the annotation) instead of taking down ingress for every file.

No new node, no new field, no transform — so this is the plain `.md` bug path,
not `contract-gen`.

## FAILING-CASE

```sh
CORE=/home/llm/sh2loop/otranspilerl/target/debug/otranspilerl-cli
WB=/home/llm/sh2loop/sh2perl/backends/c/target/debug/shir_render
F=/home/llm/sh2loop/sh2perl/frontends/posix-sh-go/testdata/t62_word_split.sh

$CORE "$F" --source-lang sh --target shir --raw | $WB --target=c -
```

Actual (exit non-zero, no C emitted):

```
ShIR JSON ingress: Program.var_types[0].type: expected {{kind: Float, width: N}} or {{kind: Int32}} etc.
```

The offending JSON (`$CORE ... | jq -c '.var_types'`):

```json
[{"name":"w","type":{"kind":"AsciiStr"}},{"name":"x","type":"Str"}]
```

`var_types[0].type` is `{"kind":"AsciiStr"}` — exactly the unhandled kind.

Expected after the one-arm fix: the C renders, and the stub/TODO count for this
file is 0 (it is a pure word-split/echo program).

## OUTCOME: implemented — `src/shir_json_in.rs:218` now has `Some("AsciiStr") => Ok(IrType::AsciiStr)`. The arm is present and the ingress accepts the verdict.
