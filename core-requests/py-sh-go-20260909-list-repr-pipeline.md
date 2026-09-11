# Core request: Python bare-list value pipeline (`return <list>` / `print(<list>)`)

Date: 2026-09-09. From: t89_factor_big / list-append crash investigation.
Owner: split — py-sh-go frontend (emission) + estree worker (runtime helper).

## What works after the core list-append crash fix (shir.rs, 2026-09-09)

- `out.append(i)` on a store-only array no longer panics the compiler
  (`unreachable!("lifted var assigned an unanalysed source")` — the
  lifted/store-only Assign path now emits `setArray`/`setArrayAppend`/
  `assign` bare, mirroring the general path). The previously-red unit test
  `estree::migrated_passes_tests::array_lowering_is_conservative` is green.
- Exact-BigInt div/mod operands (`BigInt(p1 || 0)`) apply inside the
  append loop, so the divisibility test is exact past 2^64.

## What is still wrong (repro: `/tmp/sf.py`, kept out of testdata on purpose)

```python
def small_factors(n):
    out = []
    for i in range(1, 100):
        if n % i == 0:
            out.append(i)
    return out
print(small_factors(2**64 + 1))   # python: [1]   transpiled: 1
```

Two gaps, both on the value (not store-effect) side:

1. **Frontend emission (py-sh-go).** `return out` (bare list) lowers to
   `echo getVar("out")`, and the call-site `print(f(...))` lowers to
   `String(...)` with NO brackets — while the `sorted()`-return shape
   lowers to `sortedIntJoin` + backtick-bracket call site. So the
   bare-list shape has no agreed "join without brackets / print adds
   brackets" contract. Direct `print([1,2,3])` via a list var has the same
   hole (`/tmp/pl.py`: transpiled `[1]`, python `[1, 2, 3]`).
2. **Runtime read (estree).** `sh2.getVar("out")` on an array yields
   element 0 (the bash scalar-context rule — CORRECT for shell, must not
   change). There is no ordered (append-order, dup-preserving) `", "`-join
   helper; `sortedIntJoin` sorts+dedups (wrong for lists).

## Suggested contract (mirrors the set-shape precedent)

- New runtime helper, e.g. `sh2.listJoin(name)` — `arrayValues(name)`
  mapped through `String()` joined with `", "` (order-preserving).
- Frontend: `return <bare list>` lowers to `echo <listJoin>` (join without
  brackets); call-site `print(f(...))` for list returns wraps in brackets,
  exactly like the `sorted()` shape. Direct `print(<listvar>)` emits
  `"[" + listJoin + "]"`.

## Also noted (same lane, same worker)

- `t35_exit_code.py` (`r = getVar("?")` → native write `r = sh2.lastExit`
  vs store read `sh2.vars.r`) is the scalar twin of the store-only
  read/write agreement gap. The in-flight store-only-native feature
  (uncommitted `STORE_ONLY_VARS` decls + the reverted bare-read disjunct —
  see shir.rs NOTE 2026-09-09) owns completing it; the disjunct was
  reverted because it rendered bare identifiers with no `let` declared
  (ReferenceError on every such read).
