# Optimised Python list-of-integers representation

Status: **partially implemented** (C backend + py-sh-go frontend); the
estree/Zig backends and the extent B-tree are future work.

## Implemented so far

- **py-sh-go frontend**: `max(x)` / `min(x)` / `sum(x)` builtins lower to
  typed `max`/`min`/`sum` reduction nodes (t92_max_min_sum).
- **C backend** `max`/`min`/`sum`: native scan over an int array
  (`long long[]`, width-narrowed) or a GMP scan over a bigint array
  (`char *[]` of decimal text); `int_arrays`/`analyze_reduce_arrays` keep
  a list reduced only this way on the i64 fast path, maintaining
  `_max`/`_min`/`_sum` incrementally so the reduction is **O(1)**
  (Optimisation 1). `is_int_expr` accepts string literals that parse as
  i64.
- **C backend — extent sorted-consumption partition (Optimisation 2)**:
  `_sh_sorted_bigint_join` partitions a mixed list into the i64 extent
  (native `long long` sort, never an mpz compare) and the bigint extent
  (mpz sort), then outputs `-bigint, i64, +bigint` — exact because
  bigints outside i64 range are all `< i64_min` or `> i64_max`
  (t93_extent_mixed).
- **estree backend**: `sh2.max`/`min`/`sum` (BigInt-exact) + the
  native-array twins `maxArr`/`minArr`/`sumArr` and
  `sortedIntJoinArr`/`sortedBigintJoinArr`; array-read tracking so the
  native-array pass keeps a reduced/sorted list as a JS array and
  rewrites `sh2.max("xs")`/`sh2.sortedBigintJoin("xs")` to the `*Arr`
  twins. **All py-sh-go tests pass on estree (90/90)** — t89/t90 bigint
  factors, t91 set-sum fallback, t92 max/min/sum, t93 extent.
- **Not yet**: the full extent B-tree, and the Zig backend's
  `max`/`min`/`sum`/sorted (its regular-list array model is incomplete).

This document is the design for the full scheme; the implemented slice is
the native-reduction foundation the rest builds on.

## Current state

The py-sh-go frontend lowers Python `list`/`set` to the shell surface:

- `x = [a, b, c]` → `setArray("x", [a, b, c])`
- `x.append(v)` / `x.add(v)` → `setArrayAppend("x", [v])`
- `sorted(x)` / `print(x)` → `sortedIntJoin` / `sortedBigintJoin`
- `max(x)` / `min(x)` / `sum(x)` → (currently) a shell-out pipeline or a
  full re-scan

The C backend already has two relevant analyses:

- **`int_arrays`** (`analyze_int_arrays`): an array whose elements are all
  provable 64-bit integers AND that is only consumed by
  `sortedIntJoin`/`sortedBigintJoin` is stored as `long long[]` + `_len`
  instead of `char *[]`. This is the *all-or-nothing* i64 fast path.
- **`int_array_widths`**: narrows the element type to `I8..U64` when the
  range analysis proves a tighter bound.

Bigint arrays (`sortedBigintJoin`) use GMP `mpz_t[]` (C) / `Managed` (Zig).

### The problem

The current model is **monomorphic per array**: an array is either all-i64
(`long long[]`) or all-bigint (`mpz_t[]`). Consequences:

1. **One bigint poisons the whole list.** A list that is 99% small ints with
   a single `2**100` element is forced onto the `mpz_t[]` path, losing the
   i64 fast path for every element and every operation.
2. **`max`/`min`/`sum` re-scan from scratch.** Each call walks the whole
   array, even when the value is recomputable from a maintained aggregate.
3. **`sorted()` pays the full cross-class sort.** Sorting a mostly-i64 list
   compares every element through the bigint path (or the string path),
   even though the i64 bulk could be sorted with a fast native int sort.
4. **`max` cannot skip i64 extents.** When a bigint element exists, the
   global max is always a bigint, but the current code still scans the i64
   elements.

## Proposed representation: a B-tree of extents

Represent a list of integers as a **B-tree of extents**. An *extent* is a
contiguous run of elements of a single *class*:

- **i64 extent** — a dense array of `i64` (or a narrower width from
  `int_array_widths`: `i8/u8/i16/u16/u32/i32/u64`).
- **bigint extent** — a dense array of `mpz_t` (C) / `Managed` (Zig).

The B-tree is ordered by *position* (it is a sequence, not a keyed map), so
each node stores a child count and the leaves are the extents.

```
list = [ 5, 7, 9,  2**100, 2**101,  3, 1 ]
        └─ i64 extent ─┘ └─ bigint ─┘ └─ i64 ─┘
```

### Why a B-tree of extents

- **Small bigint counts stay cheap.** A list with `k` bigint elements has
  at most `2k+1` extents; the `n-k` i64 elements stay on the native i64
  path. The bigint cost is proportional to the *number of bigint elements*,
  not the list length.
- **O(log n) indexed access.** `x[i]` descends the B-tree by child count.
- **O(1) amortized append.** `append(v)` appends to the last extent when
  `v` is the same class, else opens a new extent (and rebalances the tree).
- **Extent merging.** Adjacent same-class extents merge on append/insert,
  keeping the extent count near `2k+1` (bounded by the number of class
  transitions).

### Extent node metadata

Each extent (and each internal B-tree node) maintains a small aggregate:

```
struct Extent {
    class: I64 | BigInt,
    data:  i64[] | mpz_t[],
    len:   usize,
    // aggregates (maintained incrementally on append/insert/remove)
    max:   Value,        // i64 or bigint
    min:   Value,
    sum:   Value,        // i64 or bigint (bigint when any element is)
    has_bigint: bool,    // any element is bigint
}
```

Internal B-tree nodes fold the child aggregates (max of maxes, sum of sums,
count of counts), so the *root* gives O(1) access to `len`, `max`, `min`,
`sum` without descending.

## ShIR passes: consumption-profile detection

A ShIR pass walks the program and, for each list variable, computes a
**consumption profile** — the set of operations applied to it. The profile
selects the representation and which metadata to maintain.

> **The pass is what makes the metadata worthwhile.** There is no point
> maintaining `max`/`min`/`sum` unless that operation is *actually called*
> on the list. Every aggregate we maintain costs on every `append`/`insert`
> (an O(1) update folded up the tree). If the pass cannot prove a `max`
> consumer, we maintain **no** `max` metadata — the append stays a bare
> extent append. The pass is the gate: it proves a consumer exists, and
> only then do we pay the maintenance cost to make that consumer O(1).
> Without the pass, the whole scheme is speculative overhead on every
> mutation for a benefit that may never be realised.

| consumer | profile | representation / metadata |
|---|---|---|
| `sorted(x)` only | `Sorted` | partition into `-bigint / i64 / bigint` runs |
| `max(x)` / `min(x)` | `Extremum` | maintain per-chunk `max`/`min` |
| `sum(x)` | `Sum` | maintain per-chunk `sum` |
| `x[i]`, `len(x)`, mixed | `General` | plain extent B-tree |
| `print(x)` (repr) | `Repr` | join the extents in order |

The pass is a **fixed-point** like `analyze_bigint_vars`: a list's profile
is the union of the profiles of every consumer reachable from it, and a
list passed to a function inherits the function's consumption of its
parameter.

The pass emits the profile as an annotation on the `setArray` /
`setArrayAppend` / `sortedIntJoin` / `max` / `min` / `sum` nodes, so each
backend can choose its lowering without re-deriving the analysis.

### Why the pass must be a fixed point (and why it gates the metadata)

A list is often built in one place and consumed in another — possibly
inside a function. `factors` is built by `all_factors` and consumed by
`sorted(list(factors))` in the caller. The pass must follow the data flow
across function boundaries to learn that `factors` is `Sorted`-consumed;
only then does it annotate the `setArray`/`setArrayAppend` sites to build
the partition-ready representation. If the pass stopped at the function
boundary, it would see no consumer at the build site and maintain nothing
— which is correct *only if* the list truly has no reduction consumer. The
fixed point is what lets the pass prove the consumer exists before any
metadata is maintained.

### Example

```python
def all_factors(n):
    factors = set()
    for i in range(1, int(n**0.5) + 1):
        if n % i == 0:
            factors.add(i)
            factors.add(n // i)
    return sorted(list(factors))
```

`factors` is consumed only by `sorted(list(factors))` → profile `Sorted`.
The pass annotates it so the backend can partition into
`-bigint / i64 / bigint` and sort each run independently.

## Optimisation 1: chunk-level max/min

When a list has profile `Extremum` (the pass proved `max`/`min` is called),
the backend maintains `max`/`min` per extent and folds them up the B-tree.

- `max(x)` reads the root aggregate: **O(1)** (or O(#chunks) if only
  per-extent maxes are kept, no root fold).
- `append(v)` updates the last extent's `max`/`min` and the folded ancestors:
  **O(log n)** amortized.

The maintenance cost is paid **only** because the pass proved an
`Extremum` consumer. A list with no `max`/`min` call keeps bare extents —
no `max`/`min` field, no fold, no per-append update.

### Optimisation 1a: skip i64 extents when a bigint max exists

Because any bigint is greater than any i64, once an extent (or the root)
has `has_bigint == true` and a bigint `max`, the global `max` is a bigint
and **all i64 extents can be skipped** when recomputing `max`. Only the
bigint extents need scanning. This is the "if max > 2^64 then skip
non-bigint extents" rule:

```
fn global_max(root):
    if root.has_bigint:
        # the max is a bigint; i64 extents cannot beat it
        return max over bigint extents only
    else:
        return max over all i64 extents
```

The same rule applies to `min` with the sign flipped: if a negative bigint
exists, the global min is a bigint and positive i64 extents are skipped.

## Optimisation 2: sorted-consumption partitioning

When a list has profile `Sorted` (consumed only by `sorted()`), the backend
partitions the elements into three runs:

```
-bigint (ascending)  |  i64 (ascending)  |  +bigint (ascending)
```

- Each run is sorted **independently** with a class-appropriate sort:
  the i64 run with a fast native int sort (no GMP/Managed compare), the
  bigint runs with GMP/Managed compare.
- The concatenation is the sorted list, because every `-bigint < any i64 <
  any +bigint` (and `0`/small negatives live in the i64 run).
- This avoids comparing i64 against bigint during the sort — the partition
  guarantees the cross-class order, so the sort never pays the bigint
  compare for the i64 bulk.

The i64 run can reuse the existing `_sh_sorted_int{width}_join` machinery;
the bigint runs reuse `_sh_sorted_bigint_join`. The three runs are joined
in order.

## Optimisation 3: sum

When a list has profile `Sum`, the backend maintains `sum` per extent and
folds it up the tree. `sum(x)` reads the root aggregate in O(1). A bigint
sum is only maintained for extents that actually contain bigints; i64
extents keep an i64 sum (and the fold widens to bigint only when a bigint
extent is present).

## Operation complexity summary

| operation | current (monomorphic) | proposed (extent B-tree) |
|---|---|---|
| `append(v)` | O(1) | O(1) amortized (extent append + rebalance) |
| `x[i]` | O(1) | O(log n) |
| `len(x)` | O(1) | O(1) (root count) |
| `max(x)` / `min(x)` | O(n) re-scan | O(1) (root aggregate) or O(#bigint extents) |
| `sum(x)` | O(n) re-scan | O(1) (root aggregate) |
| `sorted(x)` | O(n log n) cross-class | O(n log n) but i64 bulk sorted natively; bigint cost ∝ #bigint |
| `print(x)` (repr) | O(n) | O(n) (join extents in order) |

The headline win: **bigint cost is proportional to the number of bigint
elements**, not the list length, and reduction consumers are O(1) instead of
O(n).

## Integration with existing backends

### C backend

- Extend `int_arrays` from a monomorphic `long long[]` to a tagged union of
  extents: `{ i64[] | mpz_t[] }` per extent, with the extent metadata
  (`max`/`min`/`sum`/`has_bigint`).
- `int_array_widths` still narrows the i64 extents.
- `sortedIntJoin`/`sortedBigintJoin` become the three-run partition join
  when the profile is `Sorted`.
- `max`/`min`/`sum` lower to the root aggregate read (or the bigint-only
  scan when `has_bigint`).

### Zig backend

- i64 extents are `i64[]`; bigint extents are `std.math.big.int.Managed[]`.
- The `sh2SortedIntJoin` helper already sorts an `i64[]`; extend to the
  three-run partition.
- `max`/`min`/`sum` read the maintained aggregate.

### ShIR

- The consumption-profile pass lives in `shir_passes/` (it is a shared
  analysis, like `analyze_bigint_vars`), emitting annotations that every
  backend consumes. It must stay backend-agnostic (toolkit purity: the
  profile is a property of the *program*, not of any renderer).

## Open questions / future work

1. **Extent rebalancing.** When appends alternate classes, the extent count
   can grow to `2k+1`; a pathological interleave (`i64, bigint, i64,
   bigint, …`) keeps many single-element extents. A B-tree with a minimum
   fill factor bounds this, but the merge policy needs tuning.
2. **Insert/delete in the middle.** `x.insert(i, v)` / `del x[i]` split an
   extent and rebalance; the metadata must be recomputed for the split
   extents. This is the main complexity cost of the B-tree over a plain
   growable array.
3. **`max`/`min` with mixed signs.** The "skip i64 extents" rule is exact
   for `max` when a positive bigint exists and for `min` when a negative
   bigint exists. A bigint that is *small* (e.g. `2**64 - 1` is still
   positive but less than nothing) does not help `min`; the rule must check
   the *sign* of the bigint max/min, not just `has_bigint`.
4. **When to materialise vs. keep lazy.** A list that is built and consumed
   once (e.g. `sorted(list(factors))`) may not need a persistent B-tree at
   all — the partition can be done in one pass. The pass should distinguish
   "built once, consumed once" from "persistent, mutated across calls".
5. **`int_array_widths` interaction.** The i64 extents can each carry their
   own width; a narrow extent (`i8`) and a wide extent (`i64`) can coexist
   in the same list, and the join widens on output.

## Related

- `src/c_backend.rs`: `analyze_int_arrays`, `int_array_widths`,
  `_sh_sorted_int{width}_join`, `_sh_sorted_bigint_join`.
- `src/zig_backend.rs`: `sh2SortedIntJoin`, bigint lowering via
  `std.math.big.int.Managed`.
- `frontends/py-sh-go`: `setArray`/`setArrayAppend`/`sortedIntJoin`/
  `sortedBigintJoin` emission.
- `PLAN.md` v37/v38: the py-sh-go bigint regime and set/sorted lowering.
