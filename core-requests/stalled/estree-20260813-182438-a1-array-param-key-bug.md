# estree: CORRECTNESS — A1-path array reads emit store-key "$gi" instead of the JS param value

## NEED

The **A1 → ESTree path** (`shir_to_estree_json`, what `otranspilerl`
`render(a1, "js")` / the GUI / the `otranspiler` command use) must emit
`sh2.arrayIndex("map", `${gi}`)` — the **live JS parameter** — where
the **parse-tree path** (`estree.rs ast_to_estree_json`, what
`bash script.sh` / the debashcl engine use) already does. Today the A1
path emits `sh2.arrayIndex("map", "$gi")`, a **store lookup**, for a
name that is a JS function parameter and is **never in the store** —
the lookup resolves to a stale/empty value.

## WHY

`map_get() { gi=$1; gv=${map[$gi]}; }` compiles differently on the two
paths:

- debashcl/parse-tree path (correct): `function map_get(gi) { …
  arrayIndex("map", `${gi}`) … }` — the runtime gets the actual arg.
- otranspilerl/A1 path (WRONG): `function map_get(gi) { …
  arrayIndex("map", "$gi") … }` — `expandOperand("$gi")` looks up
  `vars.get("gi")`, which nothing ever writes (params are JS params on
  this path), so it expands to `""` → `Number("")` = 0 → **every
  param-indexed array read returns element 0**.

Repro (A1 path, array pre-seeded): `map=(0 1 2 3 4 5 6 7);
map_get() { gi=$1; gv=${map[$gi]}; }; map_get 5; echo "$gv"` prints
`gv=0`, expected `gv=5`. The browser game dodges it only because
`.sh` scripts run through the debashcl path — the GUI's transpile /
`otranspiler` command (A1 path) mis-render any script with
param-indexed array reads, and in the full game the store name `gi`
happens to be clobbered by an unrelated function (`glyph_index`'s font
`gi`), so the corruption is silent and order-dependent.

## MINIMAL-CORE-CHANGE

In the A1 estree lowering, the array-read key for a `Word::MapAccess`
/ baked-subscript whose key is a function-param ref (`$1`-copied, the
emitter's own param-lift) must emit the **native param binding**
(`${gi}`), not the store-key string. The parse-tree path already does
exactly this — mirror it. (`baked_subscript_read` + the `param`-shape
rewrite at shir.rs ~24145 already emit native keys for the `param("",
"map[$k]")` shape; the gap is the `Word::MapAccess` shape → `st(key)`.
A param that IS store-written (`sh2.vars.gi = …`) keeps the store key.)

## FAILING-CASE

    map=(0 1 2 3 4 5 6 7)
    map_get() { gi=$1; gv=${map[$gi]}; }
    map_get 5
    echo "$gv"

Via `otranspilerl render(a1,"js")`: prints `gv=0` (wrong — reads
`map[0]`). Via the debashcl path: prints `gv=5`. Both must print
`gv=5`. Corpus gate: `./fail-estree` at the trusted baseline — this is
a correctness fix; the corpus examples with param-indexed array reads
are exactly the ones that must not regress.
