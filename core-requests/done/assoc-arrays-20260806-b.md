> RESEND (this is a re-filing). The 23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# associative arrays: declare -A map[k]=v — the subscript is baked into the name

## NEED

The parser bakes associative-array subscripts INTO the variable name:
`map["key"]=v` / `map[key]=v` arrive as `Assign { targets: [{ var:
"map[key]", indices: [] }] }` (and `matrix[0,0]=1` for the bash
pseudo-multidim idiom). The IR has no `MapAccess`/`MapKeys`/`MapLength`
representation (the ast_words layer has those node types — the AST side
knows the distinction — but `ast_to_ir` flattens).

Minimal contract: emit the subscript structurally:

```rust
AssignTarget { var: "map", indices: vec![IrExpr::Str("key", ...)] }
```

and map `declare -A name` to an `IrStmt::Declare` (or keep the current
`exec(declare, [-A, name])` — the renderer can key off the subscript
presence). Indexed reads (`${map[key]}`) already emit
`arrayIndex(map, key)` — the write side just needs the same structure.

## WHY

Corpus files blocked: 029_arrays_associative.sh,
063_02_complex_array_assignments.sh, 058_advanced_bash_idioms.sh
(pseudo-multidim `matrix[0,0]` — the Perl renderer works around the
baked name with a `split_indexed_var` hack emitting `$matrix{"0,0"}`
hash keys, which only handles the literal case, not `$i,$j` dynamic
keys), 063_hard_to_parse.sh.

## MINIMAL-CORE-CHANGE

In `ast_to_ir`'s Assign lowering (src/shir.rs): when the parser's
variable name contains `[...]`, split it into `var` + `indices` instead
of keeping the raw name. The `matrix[0,0]=1` pseudo-multidim case keeps
both index parts (`indices: ["0", "0"]` → a nested/joined key — the
backend decides); `map["key"]`/`map[key]` emit `indices: ["key"]`.

## FAILING-CASE

```sh
#!/bin/bash
declare -A colors
colors[red]="ff0000"
colors[blue]="0000ff"
echo ${colors[red]}
echo ${colors[blue]}
```

Current (Perl renderer): `declare -A` passes through, the write becomes
`$colors{"red"} = ...` only via the name-split hack, and the read
`arrayIndex(colors, red)` renders `$colors[red]` (bareword!) or the
hash-key form — the two must agree. Structural indices make reads and
writes symmetric.
