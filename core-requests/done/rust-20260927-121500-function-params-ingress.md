# rust: `IrStmt::Function` cannot carry `params` — the go-sh frontend's named Go parameters are silently dropped at ingress

## NEED

`go-sh --shir --raw` emits a function definition as an `IrStmt::Function` JSON
node with a `params` list of **named** Go parameters:

```json
{"type":"Function","name":"isYes","params":["s"],"body":[...]}
```

`IrStmt::Function` (`src/ir.rs:771`) has only `name`, `body`, `named_blocks`.
There is no `params` field, so the deserializer's `"Function"` arm
(`src/shir_json_in.rs:658`) never reads it — the parameter names are dropped on
the floor, silently, with no error.

`params` is emitted and understood on `IrSub` (the `subs` list — `sub_json` in
`src/shir_json.rs:126`, and the existing core test at `src/ir.rs:12093` uses
`{"type":"Function","name":"f","params":[]}`). But go-sh emits the definition
into `stmts` as a `Function`, not into `subs` as a `Sub`, so the parameter list
is unrepresentable on the path go-sh actually takes.

## WHY

A Go function with named parameters loses them entirely, so **every read of a
parameter inside the body becomes a read of an unbound name**. The rust backend
renders the body verbatim and the parameter reads fall through to the
environment lookup:

```rust
fn isYes() -> String {
    let __bt_0 = if __sh_env("s") == "y".to_string() { ... };
```

`s` should be the function's first argument; it is read as `$s` from the
environment instead. `__sh_env("s")` is `""` for any real program, so the
predicate silently returns `false` for every input.

This is not a rare shape — it is the single most common Go function form. It
accounts for **12 of the 20 remaining go-corpus failures**, all of which
currently produce empty or wrong output:

| case | Go shape | symptom |
|---|---|---|
| `t109_bool_func` | `func isYes(s string) bool` | all output empty |
| `t115_bool_literal_return` | `func pick(b bool) string` | wrong value (`false false`) |
| `t111_char_code` | `func has(s, sub string) bool` | wrong value |
| `t107_spaced_return` | `func pair() string` (return value) | empty |
| `t94_multi_return` | `func divmod(a, b int) (int, string)` | empty |
| `t96_typed_params` | `func add(a, b int) int` | empty |
| `t104`/`t108` `struct_slice*` | `func join(sep, a, b string) string` | empty |
| `t103` `map_literal` | `func pick(m map[..]) string` | empty key |
| `t110` `slice_error` | `func head(s []string) string` | empty |
| `t112` `struct_field_incr` | field mutation via param | empty |
| `t114` `map_call_value` | `func get(m, k) string` | empty |
| `t116` `struct_return` | `func mk() S` | empty |

The rust backend cannot work around this: the parameter names are gone before any
backend code runs. The only place they could be preserved is the shared core
(node + serializer + deserializer).

Note the frontends that matter here are already correct producers — go-sh emits
a faithful, round-trippable `params` list. The gap is purely that the core's
`IrStmt::Function` has nowhere to put it.

## MINIMAL-CORE-CHANGE

Three coordinated edits, all mechanical, mirroring how `IrSub.params` already
works:

1. **`src/ir.rs`** — add `params: Vec<String>` to the `Function` variant:

   ```rust
   Function {
       name: String,
       params: Vec<String>,
       body: Vec<IrStmt>,
       named_blocks: Vec<(String, Vec<IrStmt>)>,
   },
   ```

2. **`src/shir_json.rs`** — the `IrStmt::Function` serializer arm (line ~308)
   emits `"params": params`. Per the file's existing convention for optional
   fields (`named_blocks` is emitted only when non-empty, to keep every existing
   emit byte-identical), emit `params` **only when non-empty** so the ~650-file
   corpus oracles stay byte-identical. Absent = `[]`, matching the existing
   `{"type":"Function","name":"f","params":[]}` test fixture, which must keep
   passing.

3. **`src/shir_json_in.rs`** — the `"Function"` arm (line ~658) reads
   `params` as an optional array of strings, mirroring the `typeParams` arm
   directly above it: absent/null → `vec![]`, a non-string entry → an ingress
   `Err` (do not silently accept, same as `typeParams`).

Adding a field to an enum variant is source-compatible for the `_ =>` /
`..` patterns renderers use, so no backend needs a matching change to keep
compiling. The precondition in README §11.9 (open node model) holds: this
widens an existing variant rather than adding one.

**Alternative** (if a variant change is unwanted): have go-sh emit named Go
functions into the `subs` list as `IrSub` instead of `IrStmt::Function`, which
already has `params`. That is a frontend change, but it is the smaller blast
radius — it needs no core edit at all, and `sub_json` already serializes
`params`. Whichever side takes it, the invariant to restore is:
**a function definition's parameter names must survive A1 ingress.**

## FAILING-CASE

```
$ sh2perl/frontends/go-sh/go-sh --shir sh2perl/frontends/go-sh/testdata/t109_bool_func.go --raw \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["stmts"][0]["params"])'
['s']

$ ... | shir_render --target=rust -   # after ingress
fn isYes() -> String {
    let __bt_0 = if __sh_env("s") == "y".to_string() { "true".to_string() } else { "false".to_string() };
```

Expected: `isYes` renders with `s` bound to the first call argument
(`isYes("y")` from `main`), so `isYes("y")` yields `true`.

Actual: the parameter is absent from the signature and read as an environment
variable, so the program prints nothing at all (`go run` prints
`yes` / `not-n` / `true`).

Rust-side gate once the field survives: 12 of 20 remaining go-corpus failures
turn green; that is the whole tail except `t83_type_args`, `t101_addr_deref`,
`t102_variadic_spread` and `t113_any_slice_maps`.

## OUTCOME: implemented — already landed in core HEAD 62b79b39a: `IrStmt::Function` carries `params: Vec<String>` (src/ir.rs:778), the serializer emits it only when non-empty so every existing corpus emit stays byte-identical (src/shir_json.rs), and ingress validates it as an optional string array with a hard error on a non-string entry (src/shir_json_in.rs:658). Covered by `function_params_survive_ingress_and_round_trip` and `function_params_absent_is_empty`, both green under cargo test --lib.
