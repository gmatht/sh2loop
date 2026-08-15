> RESEND (this is a re-filing). The 23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# typed-node IR growth: element size + struct layout in the A1 contract

## NEED

Grow the A1 contract's type annotations from the current
`IrType { Int, Str, Any }` (an emission-side verdict) into a
first-class, serialized type layer: pointer element sizes, array
lengths, and struct layouts. Minimal concrete shape (additive — existing
emissions byte-identical):

- `IrType::Int(width)` — the C frontend's int widths (already hinted by
  the range analysis's width table),
- `IrType::Ptr(Box<IrType>)` — element type ⇒ element size for pointer
  arithmetic,
- `IrType::Array(Box<IrType>, Option<len>)`,
- `IrType::Struct(Vec<(String, IrType)>)` — named struct layouts (field
  → type) so member offsets/sizeof are computable,
- serialized beside `var_types`/`var_lengths`/`var_const`/`var_lifetimes`
  on `IrProgram` (shir_json.rs emit + shir_json_in.rs round-trip;
  `contract_version` stays 1 — additive field, same pattern as the
  earlier annotation siblings; `shir_json_in` rejects unknown kinds like
  it already does for VarKind).

Backends that ignore it are unaffected (additive-only).

## WHY

This is the shared prerequisite the C frontend's own roadmap names
(FRONTEND.md, pointer slice 2): "needs the minimal type layer: element
size + struct layout." Its immediate consumer is the pending
`c-mem-slice2` request (the sh2.mem arena — malloc, real offsets,
pointer arithmetic), which currently can only carry the element size as
an ad-hoc field in the handle tag; a contract-level type layer makes the
scaling correct and reusable instead of a runtime convention.

Beyond C: `cxx-rust-adequacy.md` maps every C++/Rust feature that shIR
cannot express today — classes/templates/RAII are unreachable without
exactly this type layer (Struct fields ⇒ the seed of classes). This
request is the fork point that makes a future C++-14 frontend meaningful
instead of "a C frontend with a .cpp lexer". It is ALSO the type basis
for the C backend's ~5% corpus ceiling (fixed-size buffers, typed
rendering).

## MINIMAL-CORE-CHANGE

In src/ir.rs: extend `IrType` with the four variants above (or add a
parallel `IrTypeInfo` struct for programs that carry it). Serialize in
shir_json.rs (e.g. a `types: [{name, type, size, layout?}]` list, or
extend the existing `var_types` entries) and round-trip in
shir_json_in.rs. The C frontend (frontends/c-sh-go) then emits
`Ptr(Int(4))` for `int *p`, and the runtime/backends scale `p + n` by
the element size.

## FAILING-CASE

```c
struct Point { int x; int y; };      /* refused today — no struct type */
int *p = malloc(3 * sizeof(int));    /* refused — c-mem-slice2 needs
                                        sizeof(int) from the type layer */
p[1] = 20;
printf("%d\n", p[1]);
```

## GATE

`cargo test --lib` (round-trip incl. the new kinds); the ESTree corpus
stays byte-identical (additive annotations); the C frontend's malloc
probe (gcc == estree, `frontends-stdout.sh c`) renders + executes once
`c-mem-slice2`'s arena lands on top.

## RELATION TO c-mem-slice2

This is the contract half; `c-mem-slice2-20260806.md` is the runtime
half. Either can land first (the arena works with the encoded-handle
fallback), but the type layer should be MEDIATED as the shared
prerequisite so future frontends (C++, Rust) inherit it — not buried in
the C runtime's handle format. Coordinate, don't duplicate: if the
mediation implements c-mem-slice2 first, this request becomes the
follow-up that replaces the ad-hoc size field with the typed nodes.

## OUTCOME: rejected: the sized-int layer (Int32/Int64/UInt32/UInt64/Float) already landed; Ptr/Array/Struct would break IrType's Copy derive and every backend's exhaustive match for ZERO corpus coverage — the gate defers to c-mem-slice2 on the c-sh-go ledger; land the type layer there when the C frontend emits it.
