# py-sh-go: For-Range loop var read inside an Interpolate exec arg prints empty (store-sync-elim rewrite misses the native store read)

## NEED

The ESTree renderer's store-sync-elimination path for a STORE-BACKED
for-loop variable must rewrite the body's rendered read of the loop var
to the native loop binding — not only the `sh2.getVar("i")` CALL form,
but also the NATIVE STORE READ form `(sh2.vars.i ?? process.env.i ?? "")`
that `store_var_read`/`native_store_read` (shir.rs) emits for a
plain-ident, non-blocked name.

## WHY

The py-sh-go frontend emits (and the core's OWN shell frontend emits the
identical shape for `for i in $(seq 2 5); do echo "n$i"; done`):

```json
{"type":"For","var":"i","iter":{"type":"Range","start":2,"end":4},
 "body":[{"type":"Expr","expr":{"type":"Call","func":"exec","purity":"Emulable",
   "args":[{"type":"Str","value":"echo","style":"DoubleQuoted"},
     {"type":"Array","elements":[{"type":"Interpolate","parts":[
       {"kind":"lit","text":"n"},
       {"kind":"expr","expr":{"type":"Call","func":"getVar","purity":"Emulable",
         "args":[{"type":"Str","value":"i","style":"DoubleQuoted"}]}}]}]}]}}]}
```

Since core request `estree-20260814-020001-lift-interpolate-arg-desync`,
`mark_str_args`'s Interpolate arm marks `i` store-read, so `i` is NOT
numeric-lifted. The For lowering then takes the store-sync-elimination
path (`native_range_for` / for-of sync-elim), which emits:

- `let __sh2_for_last_i = (sh2.vars.i ?? process.env.i ?? "")` (pre-loop),
- per iteration `__sh2_for_last_i = i` + the body, and
- `sh2.setVar("i", __sh2_for_last_i)` (post-loop),

and rewrites body `sh2.getVar("i")` calls to the binding via
`forof_rewrite_getvar`. BUT a store-bound read of a plain-ident,
non-`NATIVE_STORE_READ_BLOCKED` name renders as the pure property read
`(sh2.vars.i ?? process.env.i ?? "")` — NOT a `sh2.getVar` call — and
`forof_rewrite_getvar` (shir.rs ~34230) only matches the call form. The
rewrite is a silent no-op; every iteration reads the empty store.

Result (t58_seq_range.py, the py-sh-go gate's only FAIL — 76/77):

    python3 t58_seq_range.py → n2\nn3\nn4
    transpiled ESTree run    → n\nn\nn      (loop var empty)

Verified identical failure on the core's own pipeline:
`for i in $(seq 2 5); do echo "n$i"; done` → `debashc --shir` →
`debashc --shir-in-estree` → estree-runner prints `n`×4 (empty `$i`).
All three frontend-side iterable shapes fail (bare `Range`, materialized
`Array` of Str items, and the `captureWords(Arrow(seq))` form) — the
defect is in the shared sync-elim rewrite, not in any one iterable. A
bare getVar exec arg (no Interpolate) lifts and works, so the
Interpolate store-mark is the trigger; `forof_sync_elim_ok` already
PROVED the body only observes the var through getVar reads (no store
writes of the var), so rewriting the rendered read is sound.

## MINIMAL-CORE-CHANGE

In `forof_rewrite_getvar`'s `expr_rewrite` (shir.rs, near the
`sh2.getVar(var)` call-form match): also replace the native store read
shape with `Identifier(js_var)` —

- `LogicalExpression(??)` whose LEFT is `MemberExpression(sh2.vars.<var>)`
  with property the literal `var` (i.e. the exact `native_store_read`
  output for `var`: `sh2.vars.<var> ?? process.env.<var> ?? ""`). Match
  the left side precisely (`sh2.vars.<var>`); the right-hand fallback
  chain can be any shape (it is unreachable once the binding holds the
  value, but keep it structurally compatible).

The same `expr_rewrite` serves both the native-counter (`Range`) and the
for-of sync-elim paths, so one change fixes both. No new node types, no
contract change, no deserializer change. `./fail-estree` should stay at
baseline: today this path emits WRONG output (empty var), so the rewrite
only turns wrong output into correct output for shapes the eligibility
check (`forof_sync_elim_ok`) already admitted.

Broader alternative (NOT required for the gate, higher regression risk):
exempt pure loop counters (names in `collect_for_iters` that are never
store-written outside the loop iteration) from the Interpolate
store-read mark in `numeric_lift_vars`/`string_lift_vars`, restoring the
`seq_range_for` transform's documented expectation that the loop var is
numeric-lifted. The surgical rewrite fix is preferred.

## FAILING-CASE

Python (py-sh-go testdata/t58_seq_range.py):

```python
for i in range(2, 5):
    print("n" + str(i))
```

expected stdout `n2\nn3\nn4`; transpiled run prints `n\nn\nn`.

Shell (the core's own frontend, identical A1 shape):

```bash
for i in $(seq 2 5); do
  echo "n$i"
done
```

`debashc --shir` then `debashc --shir-in-estree` + harness/estree-runner.mjs:
expected `n2\nn3\nn4\nn5`; prints `n`×4.

A1 ingress repro (accepts via `debashc --shir-in-estree`):

```json
{"contract_version":1,"imports":[],"requires":[],"stmt_lines":[],"stmts":[{"body":[{"expr":{"args":[{"style":"DoubleQuoted","type":"Str","value":"echo"},{"elements":[{"parts":[{"kind":"lit","text":"n"},{"expr":{"args":[{"style":"DoubleQuoted","type":"Str","value":"i"}],"func":"getVar","purity":"Emulable","type":"Call"},"kind":"expr"}],"type":"Interpolate"}],"type":"Array"}],"func":"exec","purity":"Emulable","type":"Call"},"type":"Expr"}],"iter":{"end":4,"start":2,"type":"Range"},"type":"For","var":"i"}],"subs":[],"type":"Program","var_types":[{"name":"i","type":"Int"}]}
```

## OUTCOME: implemented — forof_rewrite_getvar's expr_rewrite now matches the native store read shape `(sh2.vars.i ?? (process.env.i ?? ""))` (the LogicalExpression `??` arm with is_vars_member + is_env_member, shir.rs ~34850) alongside the sh2.getVar("i") call form, rewriting both to the native loop binding. Verified this round: the A1 Range-for failing case prints n2/n3/n4 and the shell `for i in $(seq 2 5)` twin prints n2..n5 — both == bash.
