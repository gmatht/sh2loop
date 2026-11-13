# Parser drops `:off:len` when the expanded name has a subscript, and `#` on an element

**From:** python backend worker (bucket-B pass, 2026-11-11)
**Type:** parser bug, `src/parser/` (single-owner core) — not a renderer gap
**Blocked:** `${a[i]:1:2}` on an array element; `${#a[0]}` (bucket-A leftover)

Both are visible in the A1 contract, so no renderer can fix them. Evidence is
a 3-line input and its `--shir` output, nothing else needed.

## 1. `${a[0]:1:1}` loses the slice

```sh
a=(one two)
echo "${a[0]:1:1}"
```

emitted (relevant node only):

```json
{"func":"param","args":[{"type":"Str","value":""},{"type":"Str","value":"a[0]"}]}
```

The `:1:1` is **gone**. bash prints `ne`; every backend therefore prints the
whole element (`one`). The un-subscripted form is correct, which is what
localizes it to the subscript path:

```sh
echo "${a[@]:1:1}"   # → param("slice","a","@","1")   ✅
echo "${s:1:1}"      # → param("slice","s","1","1")   ✅
```

The slice appears to be parsed only when the name run is followed directly by
`:`, and the `[`…`]` subscript consumes the `:1:1` instead. The natural fix is
to keep the four-arg shape and carry the subscript through, either as
`{func:"param", args:["slice","a","1","1"]}` plus an index field, or as
`{func:"slice", args:[<IrExpr::Index>, "1", "1"]}` — the renderers already
handle both `param("slice",…)` on a plain name and `${a[i]}` reads, so either
shape is ingestible without new nodes.

## 2. `${#a[0]}` loses the subscript

```sh
a=(one two)
echo "${#a[0]}"
```

emitted:

```json
{"func":"arrayLen","args":[{"type":"Str","value":"a"}]}
```

Expected: the length of element 0 (`3`). bash prints 3; `arrayLen("a")` is the
whole-array count (2), so this is a silently wrong *value*, not a crash — and
it is the one shape in the length row where the subscript is meaningful.
`${#a[@]}` and `${#a[*]}` are the array-count forms and are already right
(`arrayLen` with `@`/`*` or without a subscript).

Both are single-file in the 563-example corpus, so the priority is low — but
they are the only remaining slice/length shapes python refuses, and they are
unfixable below the parser.
