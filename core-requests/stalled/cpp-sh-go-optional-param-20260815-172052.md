# cpp-sh-go: default (optional) parameters — A1 contract lacks a defaults representation

## NEED
The A1 contract must be able to represent a sub parameter with a
default-value expression (C++ default arguments — tree-sitter-cpp's
`optional_parameter_declaration`). Concretely: `Sub` needs a
defaults-carrying params shape, e.g. `"params": ["x", ...]` plus a
parallel `"param_defaults": [<expr>|null, ...]` field (or `params` as
`{"name": ..., "default": <expr>|null}` objects), with `IrSub.params`
becoming `Vec<IrParam> { name: String, default: Option<IrExpr> }` and
the ESTree renderer emitting JS `AssignmentPattern` params
(`function f(x = 5)`) for the non-null ones. The deserializer must
accept the new shape (missing defaults = None) without breaking the
existing string-array form (contract version compatibility).

## WHY
The cpp-sh-go frontend (tree-sitter-cpp + whitelist walker over the
shared clib C lowering) refuses every program using a default argument:
`unsupported C++: optional_parameter_declaration at line N`. This is
NOT a deliberate subset exclusion — FRONTEND.md's "Refused loudly" list
(templates, classes, `std::`, `->`, exceptions, `auto`, `constexpr`,
references, new-with-args, delete-non-identifier) never mentions default
arguments, and the whitelist's empirical base was only the positive
testdata files. The blocker is the contract: `IrSub.params: Vec<String>`
(ir.rs) / `sub_json` "params" string array (shir_json.rs) /
`str_array` deserializer (shir_json_in.rs) have no slot for a default
value. No frontend-side desugar can fake it: caller-side rewriting
(`f()` → `f(5)`) needs whole-program signature analysis the bounded
token-level desugar doesn't do, and callee-side detection of an absent
argument needs an "undefined/absent" signal the C surface and ESTree
call convention don't provide.

## MINIMAL-CORE-CHANGE
- `src/ir.rs`: `IrSub.params: Vec<String>` → `Vec<IrParam>` where
  `pub struct IrParam { pub name: String, pub default: Option<IrExpr> }`.
- `src/shir_json.rs` (`sub_json`): emit the defaults next to params
  (parallel array keeps the name list byte-compatible where no default
  exists; or objects — pick one shape and mirror it in the deserializer
  and the Go `shiremit` emitter in frontends/shir-emit-go/).
- `src/shir_json_in.rs` (Sub deserializer): accept the new shape;
  `param_defaults` absent / null entries → `None` (old emits keep
  round-tripping).
- `src/estree.rs`: render a param with a default as an ESTree
  `AssignmentPattern { left: Identifier, right: <expr> }` in the
  function's `params` (JS native default-parameter semantics — the
  reference runtime already evaluates defaults at call time).
- No change to the sh parser/lowering itself (sh has no default params;
  the field is optional and defaults to None everywhere else).

## FAILING-CASE
`frontends/cpp-sh-go` — minimal C++ program (snippet; a future
`testdata_cpp/t20_default_param.cc`):

```cpp
#include <stdio.h>
int f(int x = 5) { return x; }
int main() { printf("%d\n", f()); printf("%d\n", f(3)); return 0; }
```

Currently: `./cpp-sh-go --shir` refuses with
`unsupported C++: optional_parameter_declaration at line 2` (tree-sitter
node `optional_parameter_declaration` wrapping `parameter_declaration` +
`default_value_clause`). Expected once the contract has the field:
frontend whitelists `optional_parameter_declaration`/`default_value_clause`,
emits the defaults, and the executed-stdout oracle matches native g++
(`5` then `3`).
