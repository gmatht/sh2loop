# rust: A1 JSON ingress rejects `Array.elements: null` (empty array literal)

## NEED

`src/shir_json_in.rs`'s `arr()` helper rejects a JSON `null` for an optional
array field, so a frontend that emits `"elements": null` for an EMPTY array
literal cannot be ingested by ANY backend at the A1 ingress. The rust
backend reports:

```
ShIR JSON ingress: Program.stmts[1].expr.args[0].body[0].expr.args[1].elements: not an array
```

Two fail-go corpus cells never reach the renderer because of it:
`t107_spaced_return`, `t108_struct_slice_value`.

## WHY

`arr()` is a strict `as_array()` with no null tolerance:

```rust
fn arr<'a>(v: Option<&'a Value>, where_: &str) -> Result<&'a Vec<Value>, String> {
    v.and_then(|x| x.as_array())
        .ok_or_else(|| format!("{where_}: not an array"))
}
```

The go-sh frontend legitimately emits `"elements": null` for a zero-argument
command word (`exec("pair", [])` — a Go call with no args). Two shapes must be
distinguished, because a silent `null -> []` would also mask a genuinely
malformed array:

1. `"elements": null`  — an empty word list (Go zero-arg call) → `[]`. VALID.
2. `"elements": [1,2]` with non-array members, or a missing required array —
   still a hard error.

The sibling helper `str_array` (line 1400) ALREADY has the right shape —
`None => Ok(vec![])` — and tolerates a missing field. `arr()` is the
inconsistent one. Note `arr()` returns a BORROW (`&'a Vec<Value>`), so
tolerating null needs a static empty `&'static Vec<Value>` (or a
`Cow`/`SmallVec`) return type; `str_array`'s owned-`Vec` approach does not
transfer directly.

## MINIMAL-CORE-CHANGE

Make `arr()` treat an explicit JSON `null` (and, consistently with
`str_array`, a missing key) as the empty array, leaving every other
non-array value a hard error. Either:

- return `Cow<'a, [Value]>`/`&'a Vec<Value>` backed by a
  `static EMPTY: Vec<Value> = Vec::new();`, or
- add a sibling `arr_opt()` returning an owned `Vec<Value>` and use it at the
  `elements` call site (and any other *optional* array field), keeping `arr()`
  strict for REQUIRED arrays.

The second is the smaller blast radius: required arrays keep failing loudly,
only the optional/empty-able ones gain the null tolerance.

Also worth checking: whether the go-sh EMITTER should stop emitting `null`
at all (it is what the A1 JSON schema's own round-trip fixture would say).
Either side fixed makes these two cells renderable; the ingress tolerance is
the one that unblocks every backend at once.

## FAILING-CASE

```
frontends/go-sh/testdata/t107_spaced_return.go
frontends/go-sh/testdata/t108_struct_slice_value.go
```

Both already have `func main`, so fail-go passes them through unwrapped. The
A1 they emit contains, at `stmts[1].expr.args[0].body[0].expr.args[1]`:

```json
{ "type": "Array", "elements": null }
```

Repro:

```
cd frontends/go-sh
./go-sh --shir --raw testdata/t107_spaced_return.go \
  | otranspilerl/target/debug/otranspilerl-cli - - --target rust
# ShIR JSON ingress: Program.stmts[1]...elements: not an array
```

The in-process library path (`shir_to_rust` on a parsed program) is NOT
affected — only the JSON ingress rejects it, which is why the worktree's
`rust_backend <file.sh>` bin renders these fine while the gate's A1-ingress
path fails.

## OUTCOME: implemented — already landed in core HEAD: `exprs_from` (src/shir_json_in.rs) treats an explicit JSON null as an empty element list, so `{"type":"Array","elements":null}` ingests as `[]`. Pinned by `array_elements_null_is_an_empty_list`; `array_elements_non_array_still_refuses` proves the tolerance did not become a blanket "malformed input is empty" (a string elements list is still a hard error). The sibling go-sh `make([]any, 0)` emitter half is the frontend owner's; the core half that unblocks every backend at once is done.
