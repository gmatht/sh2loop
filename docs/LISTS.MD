# Python `list` → backend structures: candidates, costs, analysis, tests

Status: **design + prototype + in-tree analysis + C Vec hook**.
The §4 passes are prototyped in `scratch-listprof/` and dropped into
the tree as `sh2perl/src/shir_passes/list_profile/` (census, bounds,
selection). The C backend consumes the verdicts: `Fixed`-verdict and
untracked arrays keep fixed storage (byte-identical); `Vec`/
`SmallVec`/`Chunked`/`Gap`/`Rope` verdicts with unbounded-or-
overflowing bounds lower as a growable vec (`T *a` + `a_len` +
`a_cap`, doubling realloc, P1 fail-stop OOM) for both int and string
homings — `SH2_LIST_VEC=0` disables it. SmallVec/Gap/Chunked/Rope
share the Vec lowering until their own lowerings land.

This document compares the
data structures a Python `list` could lower to (C backend first; other
backends noted), states which operations are fast/slow on each, sketches
the static analysis that would select between them (including absolute and
big-O frequency bounds), and lists the tests/examples that would
demonstrate effectiveness and correctness.

Related (read first, not duplicated here):

- `docs/OPTIMISED_LIST.md` — the extent B-tree for int/bigint lists, the
  consumption-profile pass, Optimisations 1–3 (incremental max/min/sum,
  sorted-consumption partitioning). That doc owns the *class-split*
  dimension; this doc owns the *container-shape* dimension.
- `core-requests/py-sh-go-20260909-list-repr-pipeline.md` — the bare-list
  value-pipeline gap (`return out` / `print(out)` vs `sorted()` shape;
  the missing order-preserving `listJoin`).
- `sh2perl/src/shir.rs` `analyze_string_lengths` — the existing trip-count
  machinery (product of enclosing loop trips from `analyze_var_ranges`,
  `CAP = 1024`).

## 1. Current state (the baseline every candidate is measured against)

- **Frontend (py-sh-go)** lowers: list/set literals → `setArray`;
  `append`/`add` → `setArrayAppend`; `x[i]` and `x[i:j]` (via
  `param("slice", …)`); `len(x)`; `sorted(x)`; `max`/`min`/`sum`;
  print-join. **Not lowered**: `pop`, `insert`, `remove`, `extend`,
  `reverse`, `count`, `clear`, `copy`, `+` concat, comprehensions with
  filters — any design below must degrade gracefully (refuse or fall
  back) for these.
- **C backend** homes lists as **fixed static arrays + length**:
  `long long arr[1024]; size_t arr_len` when `analyze_int_arrays` proves
  all-i64 elements consumed numerically, else `char *arr[1024]`
  (`ARR_CAP = 1024`, `sh2perl/src/c_backend.rs`). Index read/write is
  O(1) (`_sh_arr_get`/`_sh_arr_set`); append is O(1) until the cap, then
  **hard exit 127** ("capacity exceeded", P1 fail-stop policy) — there is
  no growth path today. That exit is the status quo's sharp edge: any
  list the analysis cannot bound below 1024 is a *latent crash*.
- **Zig backend** mirrors this (`[1024]i64` + `_len`); **estree** keeps
  lists as JS arrays (growable, exact).

## 2. Candidate structures

All costs are for element type `T` (i64/char\*/mpz_t — the class split of
`OPTIMISED_LIST.md` is orthogonal and composes with every candidate
below: each candidate stores *extents*, not raw elements, when the list
is class-mixed).

### A. Fixed static array + len (status quo)

`T arr[CAP]; size_t len` in function scope (static storage when escaping).

- Pros: zero allocation; O(1) index/append/len; cache-dense; trivially
  compiled; no frees to leak; no failure modes except the cap.
- Cons: the cap *is* the failure mode (exit 127 past 1024); wastes
  `CAP × sizeof(T)` per list even when tiny; one shape for all lists.
- Fast: index, append, len, iterate, `max`/`min`/`sum` scan, sort (in place).
- Slow: insert/pop-front (`memmove`, O(n)); concat (needs a second buffer
  + copy, O(n+m)); slice (copy, O(k)); growth (impossible — exits).

### B. Growable dynamic array (vec)

`{ T *p; size_t len, cap; }`, doubling `realloc` on append past cap.

- Pros: no arbitrary cap (grows to memory); amortized O(1) append;
  keeps O(1) index and cache density; `realloc` growth is a solved,
  auditable pattern; shrink-to-fit on final consume is easy.
- Cons: allocation + free discipline (leak/double-free surface the status
  quo lacks); `realloc` copies O(n) at growth points (amortized away, but
  worst-case-per-append is O(n)); OOM handling must follow the P1
  fail-stop policy (`_sh_xstrdup` precedent: checked, `exit(127)`);
  pointer invalidation across growth (no interior pointers may survive
  an append — matters for aliasing, §4).
- Fast: index, append (amortized), len, iterate, scan-reductions, sort.
- Slow: insert/pop-front (still `memmove`, O(n)); per-append worst case
  O(n) at growth points; first append pays `malloc`.

### C. Small-vector (inline N + heap spill)

`{ T inl[N]; T *p; size_t len, cap; }` — starts inline, spills to B on
growth past N (N ≈ 8–16, tuned so the struct stays on one cache line
for i64).

- Pros: tiny lists (the common case: `factors`-style accumulators that
  stay small, 2–3 element literals) pay **no allocation at all**;
  medium/large lists degrade to B, never to exit-127; append stays
  amortized O(1) across the spill.
- Cons: every access branches inline-vs-heap (predictable, but real);
  `sizeof` is larger (matters for many live lists); spill copies N
  elements once; the free path must test the spill flag (forget it and
  you `free()` stack memory — the exact bug class `is_heap_store_var`
  exists to prevent).
- Fast: everything B is fast at, plus allocation-free small append/index.
- Slow: same O(n) middle-mutation as B; spill transition is a one-time
  O(N) copy + branch mispredict window.

### D. Chunked array / unrolled linked list (deque of blocks)

Blocks of K elements (`K ≈ 64`), doubly linked; index descends
`i / K`, offset `i % K`.

- Pros: O(1) amortized append **and** O(1) push/pop at *both* ends;
  growth never copies (no realloc spikes — steadier latency than B);
  insert/delete still O(n) element moves but only within/between blocks
  with cheap block splices; no single large allocation.
- Cons: index is division + pointer chase (slower constant than A/B/C,
  worse cache behavior); block headers + link pointers overhead;
  more complex free walk; sort must either copy out (O(n) extra) or sort
  block-wise + merge (more code).
- Fast: append/pop at both ends, len, iterate, extend/concat (block-list
  splice, O(#blocks)).
- Slow: random index (constant-factor slower, cache-hostile); sort and
  binary search (no flat address range); `max`/`min`/`sum` scans are
  fine asymptotically but slower per element.

### E. Gap buffer

Flat array with a movable gap at/near the mutation point: O(1) insert/
delete at the gap, O(n) to move the gap elsewhere.

- Pros: unbeatable for *localized* mutation bursts (repeated
  `insert(i,·)`/`pop(i)` near one index — e.g. building a list by
  insertion at a cursor); O(1) index; flat and cache-dense like A/B.
- Cons: a mutation far from the gap pays O(n) gap movement — adversarial
  alternating-ends workloads degenerate to O(n) per op; gap bookkeeping
  on every access; no advantage at all for append-only or random-index
  workloads (strictly worse constants than B).
- Fast: insert/delete at/near cursor, index, iterate.
- Slow: scattered mutation (gap thrash), concat/extend (gap must drain).

### F. Rope (concat tree)

Persistent-style binary tree with leaves as flat chunks; `a + b` is an
O(1) node allocation, never a copy.

- Pros: `+`/concat/`extend` O(1) (the operation every other candidate
  pays O(n+m) for); slices as O(log n) persistent views (no copy when
  read-only); structural sharing makes `b = a` aliasing free and safe.
- Cons: index is O(log n) pointer chase; iterate pays node-boundary
  branches; append is O(log n) amortized (rebalance); memory overhead per
  node; freeing needs a tree walk; sort/reduce must flatten first
  (O(n) to materialize); reference counting if shared (aliasing, §4) —
  the heaviest machinery here by far.
- Fast: concat, extend, persistent slice views, aliasing assignment.
- Slow: index, append constant, sort/scan (flatten first), memory churn.

### G. Sorted array / extent B-tree (see OPTIMISED_LIST.md)

Ordered-by-position B-tree of class extents with per-node aggregates.
Owned by the extent design; listed here only for matrix completeness:
it answers the *class-split + reduction* dimensions, while A–F answer
the *growth/mutation* dimension. The two compose (extents stored in any
A–F container).

## 3. Operation-cost matrix (C realities)

`n` = length, `k` = slice/insert span, `m` = second operand length.
Constants assume i64 elements; `char*`/mpz_t add indirection uniformly.

| op | A fixed | B vec | C small-vec | D chunked | E gap | F rope |
|---|---|---|---|---|---|---|
| `append` | O(1) / **exit past cap** | O(1) amort. | O(1) amort. | O(1) amort. | O(1) at gap else O(n) | O(log n) |
| `pop()` end | O(1) | O(1) | O(1) | O(1) | O(1) at gap | O(log n) |
| `pop(0)` / `insert(0,·)` | O(n) memmove | O(n) memmove | O(n) memmove | O(1) end-op | O(n) gap move | O(log n) |
| `insert(i,·)` / `del a[i]` | O(n) | O(n) | O(n) | O(n) moves, cheap splice | O(1) near cursor | O(log n) |
| `a[i]` read/write | O(1) | O(1) | O(1)+branch | O(1) slow const | O(1) | O(log n) |
| `len(a)` | O(1) | O(1) | O(1) | O(1) | O(1) | O(1) |
| iterate | O(n) dense | O(n) dense | O(n) dense | O(n) sparse | O(n) dense | O(n)+branches |
| `a + b` / `extend` | O(n+m) copy | O(n+m) copy | O(n+m) copy | O(#blocks) splice | O(n+m) | **O(1)** |
| `a[i:j]` (new list) | O(k) copy | O(k) copy | O(k) copy | O(k) copy | O(k) copy | O(log n) view |
| `sorted(a)` | O(n log n) inplace | O(n log n) inplace | O(n log n) inplace | O(n log n)* flatten | O(n log n) inplace | O(n log n)* flatten |
| `max/min/sum` | O(n) scan | O(n) scan | O(n) scan | O(n) sparse scan | O(n) scan | O(n)* flatten |
| `==` | O(n) memcmp-able | O(n) memcmp-able | O(n) | O(n) | O(n) | O(n)* |
| `in` / `.count` | O(n) | O(n) | O(n) | O(n) | O(n) | O(n)* |

\* flatten cost included once per materialization; repeated reductions
should flatten once (a lowering decision the analysis in §4 can direct).

Reading the matrix: **no structure dominates**. A/B/C win index/append/
scan/sort; D wins double-ended mutation; E wins cursor-localized
mutation; F wins concat/slice/aliasing. The status quo (A) is optimal
*iff* the list is provably bounded and never mutated in the middle —
which is exactly what §4 must prove per list.

## 4. Static analysis: op census + frequency bounds → structure choice

The selection must live in the **core** (`shir_passes/`, backend-agnostic
like `analyze_bigint_vars` — toolkit purity: the profile is a property
of the *program*; each backend maps profiles to its own structures),
with per-backend lowering. Three sub-analyses compose:

### 4.1 Op census per list (must-analysis, fixed-point)

Walk the shIR (mirroring `analyze_int_arrays`' read/write walkers) and,
per list variable, record the *set* of mutating/observing operations:
append-sites, indexed writes, middle insert/delete (`insert`, `pop(i)`,
`del a[i]`, slice-assign), end `pop()`, concats (`+`, `extend`),
slices, sorts, reductions (`max`/`min`/`sum`), len/index reads,
iteration, aliasing assignments (`b = a` — see §4.3), escapes (passed to
an unanalysed function, returned, printed as repr).

Fixed-point across function boundaries (same argument as
`OPTIMISED_LIST.md` §"Why the pass must be a fixed point"): a list built
in a callee and sorted in the caller must carry the `Sorted` profile at
its build sites. Union of consumers; `eval`/`source`/`.` poisons
everything (existing convention).

The census also gates *metadata*: per §OPTIMISED_LIST, aggregates are
maintained only for proven consumers. Same rule here: a chunked
structure's block links, a rope's node counts, a gap's cursor — none are
paid for unless the census proves the op that needs them.

### 4.2 Frequency bounds: absolute and big-O

Knowing *which* ops occur is not enough — `insert(0,·)` once at startup
is not a reason to abandon a vec. Two bound flavors, both with precedent
in-tree:

**Absolute bounds (trip counts).** Reuse the `analyze_string_lengths`
pattern: walk with `trip: Option<u64>` = product of enclosing loop trips
from `analyze_var_ranges` (Some(1) at top level, None when any enclosing
loop is unbounded, CAP 1024). For each list, accumulate per-op absolute
upper bounds: `appends ≤ literals + Σ append-sites × trip(site)`. This
directly answers the status quo's sharp edge: **a list whose append
upper bound is ≤ 1024 − literals keeps the fixed array (A)** — no
behavior change, no allocation; one that *may* exceed it must *not* use
A (today it would exit 127 — the analysis converts a latent crash into
a structure upgrade). Lower bounds come free: literals + unconditional
(unenclosed, untaken-branch-free) appends are a floor — a floor above
the small-vector inline N rules out C's inline benefit analysis (still
correct, just never inline-profitable).

**Big-O classes (loop-nest depth).** When trips are unbounded (None),
fall back to asymptotic classification per op site: depth of enclosing
loops × enclosing call frequency (recursive/unknown → unbounded). An op
at depth `d` runs O(N^d) in the input size. Selection rules become
asymptotic: any middle-mutation at depth ≥ 1 with an unbounded trip
disqualifies flat memmove structures (A/B/C) in favor of D (or E if all
mutation sites share one cursor index — provable when every insert/delete
targets the same syntactically-fixed index expression); any concat at
depth ≥ 1 favors F; append-only at any depth keeps B/C. Depth-0 (straight
line) ops never decide anything — even O(n) middle-mutation is a
constant total cost there.

Both flavors must be *upper* bounds to be sound for structure choice
(choosing D when B would do is a pessimization, never a miscompile;
choosing B when the list can exceed its cap is the exit-127 bug). Lower
bounds only gate optimizations (inline sizing, aggregate maintenance),
never safety.

### 4.3 Hazards the analysis must prove away (else refuse the upgrade)

- **Aliasing** (`b = a; b.append(x)`): flat structures share-or-copy?
  Python aliases (mutation visible through both names). F shares
  structurally (needs refcounts); A–E must either copy on alias
  (O(n) at alias time — the bound in §4.2 prices it) or prove the
  alias never mutates. Unproven alias + mutation ⇒ keep store
  semantics (today's behavior), never a clever structure.
- **Negative indices / out-of-range**: structure choice must not change
  `a[-1]` / `a[99]` semantics (C backend today: bounds-checked helpers
  — any new structure keeps the same checks).
- **Mutation during iteration**: `for x in a: a.append(x)` — Python
  iterates the *growing* list. Flat structures re-read `len` per
  iteration (today's `while` lowering does); chunked/rope iteration
  must preserve exactly that, or the structure is refused for the
  mutated-while-iterated list.
- **Element class transitions after selection**: the census sees
  `append(2**100)` only if the frontend's int-domain analysis proves
  the value big — else the small-vec inline width must widen on first
  big append (a one-way, O(n)-amortized widening the analysis prices
  as a single event, or the list stays class-split per OPTIMISED_LIST).
- **Escape to unanalysed code** (stored in a global, returned to an
  unknown caller, passed to `eval`): freeze to the most conservative
  structure the backend supports (today: fixed array + cap exit), never
  an instrumented one whose invariants the analysis can't see
  maintained.

### 4.4 Selection sketch (per list, core emits profile, backend lowers)

```
census = {append×a, midmut×m, concat×c, sort?, reductions?, slices?, aliases?}
bounds = {append_hi, midmut_hi (absolute or None), maxdepth per op}
if aliases unproven+mutated or escapes:            -> A (status quo, cap exit preserved)
elif midmut_hi == 0 and concat == 0:               -> A if append_hi ≤ CAP else B
elif all midmut at one fixed index:                -> E (gap at that index)
elif midmut unbounded-trip or double-ended pops:   -> D
elif concat at depth ≥ 1:                          -> F
elif append_hi small (≤ inline N) and midmut == 0: -> C
else:                                              -> B
+ class-split dimension from OPTIMISED_LIST.md (orthogonal extent choice)
+ reductions/sort handled per existing aggregate/partition rules
```

Backends map profiles to structures they implement; an unimplemented
profile falls back to the backend's default (C: A-then-B; estree: native
JS array — already growable, so most of this analysis is a C/Zig concern).

## 5. Tests and examples (effectiveness + correctness)

Every structure needs both halves: *correctness* (differential vs the
`python3` oracle — the existing gate shape) and *effectiveness* (proof
the structure was chosen and pays off). No implementation ships without
both.

### 5.1 Correctness: differential oracle tests (extend `testdata/`)

One testdata example per op × structure interaction, each asserting
transpiled-stdout == `python3`-stdout (the `frontend-stdout.sh` /
`fail` gate shape — never blessed, never weakened):

- **Bounds**: empty list ops (`[].append`, `len([])`, `sorted([])`,
  `max([])` must raise like Python — including the *error text* path);
  single-element; exactly-1024 and 1025 appends (the status-quo cap
  boundary — the test that would exit-127 today and must pass under
  B/C/D/F); negative indices (`a[-1]`, `a[-99]`); out-of-range reads
  and writes.
- **Mutation shapes**: append-only accumulation (t86 `factors` shape);
  `pop()`/`pop(0)`/`pop(i)` mixed; `insert(0,·)`/`insert(i,·)` front,
  middle, end (`insert(len,·)` ≡ append); `del a[i]`; slice assign and
  slice read (`a[1:3]`, `a[:]`, `a[::2]` if lowered); `a + b`, `a += b`,
  `extend`; `reverse`; `remove(v)` (first occurrence), `count`, `in`.
- **Aliasing**: `b = a` then mutate through each name; alias then sort;
  alias escaping into a function; `c = a[:]` (must NOT alias).
- **Iteration hazards**: append-while-iterating; `for x in sorted(a)`
  with concurrent append; nested iteration over the same list.
- **Class transitions**: small-then-big appends (`2**100` after 1000
  small ints — the poisoning case from OPTIMISED_LIST); big-then-small;
  alternating classes (extent-churn shape); reductions over mixed
  lists (`max`/`min`/`sum` after transitions).
- **Nesting**: lists of lists (append/independent mutation of inner
  lists — shared-structure bugs love nesting); list of strings (non-int
  element path stays `char*`).

### 5.2 Effectiveness: choice + payoff proof

Correctness gates can't see structure choice (any correct structure
passes). Effectiveness needs its own assertions, all structural (never
timing — timing is flaky; assert the *shape* of the choice):

- **Choice assertions on emitted C** (the repo's structural-assertion
  policy): a bounded append-only test must emit `T arr[N]` with **no**
  `malloc`/`realloc`/`free(list)`; a 2000-append test must emit growth
  machinery (**no** `exit(127)` capacity path reachable — or the cap
  constant raised with proof); a concat-in-loop test under F must emit
  node construction with **no** `memcpy` of payloads; an insert-at-0
  loop must **not** emit `memmove` per iteration under D/E. Each is a
  `shir_to_c` unit test over a synthetic program (the `hoist_pair_*`
  test pattern in `c_backend.rs`).
- **Census/bound unit tests**: synthetic programs asserting the analysis
  verdicts — op sets per list, `append_hi` values (literal + 10× trip-10
  loop ⇒ exact bound), None-trip unboundedness, fixed-cursor detection
  for E, depth classification. Same module-test pattern, no execution.
- **Benchmarks (informational, not gated)**: `harness/bench.sh`-style
  append-N / random-index / insert-front / sort-N comparisons of A vs
  B/D/F on fixed workloads, recorded in the doc's results section when
  run — numbers inform the inline-N and block-K constants (§2 C/D),
  never gate correctness.
- **Capacity-boundary execution**: the 1024/1025-append differential
  tests from §5.1 double as the effectiveness proof for growth (they
  fail — exit 127 — under A and pass under B/C/D/F).

### 5.3 Suggested example progression (small → hostile)

`t94_list_append_bounded` (append-only ≤ cap, stays A) →
`t95_list_growth` (2000 appends, forces B/C) →
`t96_list_insert_front` (middle-mutation loop, D/E) →
`t97_list_concat_loop` (`+` in a loop, F) →
`t98_list_alias_mutate` (aliasing hazards) →
`t99_list_mixed_class_growth` (class transition × growth interaction
with OPTIMISED_LIST). Each names the structure it is *designed* to
select; the choice assertions in §5.2 pin the selection.

## 6. Non-goals and open questions

1. **No new runtime library by default.** Every candidate above is
   emittable as local C (a struct + static helpers like the existing
   `_sh_arr_*`/`_sh_sorted_*` family). A shared runtime would be a new
   coupling surface — inline emission keeps each program self-contained.
2. **estree needs none of this — considered explicitly, no change.**
   JS arrays already grow (`push` amortized O(1)), index O(1),
   concat/slice (O(n) copies), with no capacity cap anywhere on the
   JS path (the only `1024`s in estree/shir are buffer sizes, loop
   batching, and analysis caps — no array bound). Evaluated and
   rejected: pre-sized `new Array(hi)` (holey arrays risk dictionary
   mode — often *slower* than natural growth, plus divergent `length`
   semantics), a rope runtime for concat loops (custom-type complexity
   for workloads the corpus never shows), SmallVec-style inlining
   (the JIT already does this). The census still runs — profiles are
   backend-agnostic — but the JS lowering ignores the growth
   dimension. If a concat-dominated JS workload ever appears, revisit
   F (rope) with benchmark proof first.
3. **Interaction with the extent B-tree** (G): whether extents live in
   A–F containers or the B-tree *is* the container for class-mixed lists
   is the main unresolved composition question; the least-risk path is
   extents-in-B/C (class-split inside a growable flat array) with D/E/F
   reserved for class-stable lists.
4. **Constant tuning** (small-vec N, chunk K, gap policy) has no a priori
   answer — §5.2 benchmarks decide, per element width (i64 vs `char*`
   vs mpz_t have different copy costs, so one N does not fit all).
5. **Memory accounting**: growth structures trade the cap-exit for
   unbounded memory use — a runaway append loop now OOMs instead of
   exiting 127. Whether that is an acceptable trade (and whether a
   configurable hard cap survives as a backstop) is a policy decision,
   not a technical one.
