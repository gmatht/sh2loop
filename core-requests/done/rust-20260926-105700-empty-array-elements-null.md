# rust: go-sh emits `Array.elements: null` for an empty word list

## NEED

`frontends/go-sh/go-sh.go` `execStmtTA` builds the exec argument word list as

```go
elems := make([]any, len(words))
for i, w := range words { elems[i] = w }
```

A Go `make([]any, 0)` marshals to JSON **`null`**, so any exec whose word
list is empty emits:

```json
{"type": "Array", "elements": null}
```

The core's A1 deserializer (`src/shir_json_in.rs`, the `"Array"` arm ->
`exprs_from`) rejects a non-array `elements`, so ingress fails before any
backend renderer runs.

## WHY

The A1 contract requires `Array.elements` to be a JSON array. This is not
new or debated — the corpus already asserts it explicitly:

`frontends/go-sh/testdata/t95_empty_array.go`:

> // t95_empty_array: the empty array literal `[]string{}` — the A1
> // Array.elements must marshal to `[]`, never `null` (the core's
> // deserializer rejects null elements).

t95 passes only because that path allocates with `[]any{}` (an explicit
empty slice literal). `execStmtTA` uses `make([]any, len(words))`, which
produces the *same* empty word list but marshals to `null`. The corpus
covers the literal case and misses the exec-args case.

**Blast radius is every backend, not just rust.** Any renderer that ingests
A1 JSON — c, go, js/estree, python, zig, java, perl — hits the identical
rejection on the identical node. The three failing cases are
multi-value-return / ranged-slice constructs that route their synthetic
exec through an empty word list:

- `t107_spaced_return` — `a, b := pair()`; the synthetic `exec pair` carries
  no word args.
- `t108_struct_slice_value` — ranging a `[]tok` value slice.
- `t110_slice_error` — `s, err := getPair()`.

## MINIMAL-CORE-CHANGE

One-line-shaped fix in the **frontend**, not the core: in `execStmtTA`,
emit an empty JSON array when `words` is empty rather than relying on the
`make([]any, 0)` nil-ish marshal. Either

```go
elems := make([]any, 0, len(words))   // non-nil empty slice
for _, w := range words { elems = append(elems, w) }
```

or (defensive, and also correct for any other producer) relax the
deserializer to accept `null` as an empty `elements` list:

```rust
"Array" => {
    let elements = match o.get("elements") {
        None | Some(Value::Null) => Vec::new(),
        other => exprs_from(other, &format!("{where_}.elements"))?,
    };
    IrExpr::Array(elements)
}
```

The **frontend** fix is the one to prefer: it keeps the contract
(`elements` is always an array) true at the source rather than teaching
every consumer to tolerate a lie. The deserializer relaxation is worth
doing anyway as belt-and-braces, since a `null` in the wild is exactly what
this bug produced.

There is one more instance of the same pattern worth auditing in the same
pass: the other `make([]any, ...)`-shaped element builders reachable from
exec/call argument construction, so the fix is not one call site in a
sea of identical sites.

## FAILING-CASE

`backends/rust/.gate/verify.sh` over the 124-file Go corpus
(`frontends/go-sh/testdata`), 3 RENDER-ERR:

```
t107_spaced_return        RENDER-ERR   ShIR JSON ingress: Program.stmts[1].expr.args[0].body[0].expr.args[1].elements: not an array
t108_struct_slice_value   RENDER-ERR   ShIR JSON ingress: Program.stmts[4].expr.args[0].body[0].expr.args[1].elements: not an array
t110_slice_error          RENDER-ERR   ShIR JSON ingress: Program.stmts[1].expr.args[0].body[0].expr.args[1].elements: not an array
```

Workaround in use meanwhile: none on the rust side (the node is rejected at
ingress, before the renderer). The rust worktree is at
`backends/rust`; `.gate/verify.sh` is the per-worktree harness
(`go-sh --shir --raw | shir_render --target rust | rustc | run | diff`).

## OUTCOME: implemented — duplicate of rust-20260926-140000-array-elements-null.md; the core half (null-tolerant `elements` ingress) is landed and pinned by `array_elements_null_is_an_empty_list` / `array_elements_non_array_still_refuses`. The preferred frontend-side fix (go-sh `execStmtTA` must not emit a nil-slice null) remains the go-sh owner's and is not a core change.
