> RESEND (re-filing). The 21:07/23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# c-frontend: mem.* seam slice 2 — the arena (malloc, real offsets, pointer arithmetic)

## NEED

Extend the sh2.mem seam (slice 1 = named-variable allocations, offset 0)
to a real arena: `sh2.mem.alloc(size)` -> a NUMERIC allocation id over a
typed slot array; load/store WITH offsets and an element size;
pointer arithmetic (offset +/- n, type-scaled); `sh2.mem.free`. This is
the documented slice-2: C `malloc`/heap pointers and dynamic pointer
arithmetic — currently refused by the C frontend.

## WHY

The C frontend covers static pointer targets (alias folding, strings,
arrays, out-params) and refuses the dynamic cases (malloc, p = p + n in
a loop). Heap pointers are pervasive in real C; the seam is the
portable mechanism (the allocation_id + offset model discussed in the
pointer design).

## MINIMAL-CORE-CHANGE

Runtime-only (harness/sh2-namespace.mjs) + whitelist additions:
- `mem.alloc(size) -> "<mem-id>:" + id + ":" + size` (an arena entry,
  encoded like the slice-1 handle tag so it round-trips the string-typed
  store).
- `mem.load(h, offset, type) / mem.store(h, offset, type, v)` — the
  offset reads/writes the arena slot; `type` gives the element size for
  pointer arithmetic (`p + n` scales by sizeof(*p)).
- `mem.free(h)`.
- The A1 needs the minimal type layer for scaling: the pointer VALUE
  carries its element size (a field in the encoded handle, or a
  var_types extension Ptr(size)).
- estree_gate.pl whitelist: mem.alloc/mem.load/mem.store/mem.free (or
  flat names alloc/load/store/free in the mem family).

## FAILING-CASE

```c
int *p = malloc(3 * sizeof(int));   /* refused today */
p[0] = 10; p[1] = 20; p[2] = 30;
printf("%d\n", p[1]);
free(p);
```

## GATE

`cargo test --lib`; a malloc test renders + executes (gcc == estree);
the corpus is untouched (no corpus file emits mem.*).

## REFERENCE

The slice-1 seam (sh2.addrOf/memLoad/memStore in sh2-namespace.mjs) is
the proven pattern; slice 2 extends it from named vars to an arena.
