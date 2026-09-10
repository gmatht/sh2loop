# Core request: split-set union (`set[int]` → small ∪ big partitions)

Date: 2026-09-09. From: the t89/t90 "mostly-small set, occasional big element"
shape. Owner: **core** (mechanism) + per-backend rendering (bound + two-loop
acceptance), per §11 marketplace.

## The problem

`set[int]` is currently all-or-nothing per set. `setElemDom` (py-sh-go) latches
a set to `"big"` the moment ANY recorded element is unproven within ±2^53, and
`setType` poisons it on rebinding. So `sorted(s)` picks `sortedIntJoin` or
`sortedBigintJoin` at compile time and the set is ONE homogeneous array.

The t89/t90 shape is exactly the failure:

```python
def small_factors(n):
    factors = set()
    for i in range(1, 100):
        if n % i == 0:
            factors.add(i)          # small (1..99)
    return sorted(list(factors))
```

For `n = 2**100 + 13`, `n // i` is huge, so the whole set latches `"big"` and
the common small elements (1..99) are stored/joined as BigInts too. Correct,
but the hot path pays bigint cost for values that are provably small.

## The design: a runtime two-partition set

`set[int]` is represented as **two arrays** — a *small* partition (narrow
domain) and a *big* partition (wide domain) — with a per-`add()` routing
decision. This is the "entry-guarded dual version" pattern from
`docs/opt-levels.md` applied to collection elements instead of loop
iterations.

```
add(s, v):  if isSmall(v) → small_partition.push(v)   # i64/u64/i53
            else          → big_partition.push(v)      # BigInt
```

**The split is dynamic (per-element runtime routing), not a static sum type.**
Set membership is runtime, so a `for x in s` cannot know its partition at
compile time. The "union" is realized as two arrays + a routing check, not a
static `set[i64] | set[bigint]`.

**The routing check runs in the WIDE domain** (compute `v` as BigInt, compare
against the small bound) — you cannot test `v <= 2^63-1` in i64 arithmetic
when `v` might overflow. Same rule opt-levels.md already mandates for dual-loop
guards.

**The small partition's width is target-dependent** (opt-levels.md is explicit:
*"JS dual loops are i53/BigInt, not i64/BigInt"*):

| Target | small partition | bound |
|---|---|---|
| JS / ESTree | i53 (JS Number) | `Number.isSafeInteger(v)` |
| C / Rust / Go / Zig | i64 | `-2^63 ≤ v ≤ 2^63-1` |
| C / Rust / Go / Zig (set proven nonneg) | u64 | `0 ≤ v ≤ 2^64-1` |

The u64 refinement is a **compile-time choice about the small partition's
type**, not a third runtime partition — you still have exactly two runtime
partitions. (Moot for JS: no uint64 arithmetic.)

**Dedup stays correct because the partition is a function of the value, not
the expression.** A given value always routes to the same partition, so
dedup-within-partition preserves global set semantics. `s.add(5)` twice →
dedup in small; `s.add(2**100)` twice → dedup in big; no cross-partition
collision.

## Core mechanism (this request)

### 1. Gating — mirror `set_dual_loops`

A speed-class static + env fallback, exactly like `set_dual_loops` /
`dual_loops_enabled` (shir.rs:3078):

```rust
pub fn set_split_sets(on: Option<bool>) { /* atomic override */ }
fn split_sets_enabled() -> bool { /* override, else SH2_SPLIT_SETS env */ }
```

The CLI (`otranspilerl/src/lib.rs:625`) sets `set_split_sets(Some(true))` at
`-O3`/`-O4`, alongside `set_dual_loops(Some(true))`. Refused at `-O0`/`-Og`/
`-Os`/`-Oz` (it duplicates loop bodies and adds a per-add check — speed-class).

### 2. The transform `split-set` (`src/transforms/split_set.rs`)

Input pattern = the py-sh-go set lowering (already core-recognized):
- `setArray(s, [])` — `set()` init.
- `setArrayAppend(s, [v])` — `s.add(x)`.
- `sortedIntJoin(s)` / `sortedBigintJoin(s)` — `sorted(s)`.
- `"${s[@]}"` slice (`param slice`) — `for x in s`.

Rewrite:
- Split `s` into `s__small` / `s__big`.
- Each `setArrayAppend(s, [v])` → `if isSmall(v): setArrayAppend(s__small,[v])
  else: setArrayAppend(s__big,[v])`.
- `sortedIntJoin(s)`/`sortedBigintJoin(s)` → a **merge of both partitions**
  (see §4).
- `for x in s` → **two loops** (versioned body, see §3).

The frontend needs no change to emit the input pattern — it keeps emitting
`setArray`/`setArrayAppend`/`sortedIntJoin`/`sortedBigintJoin`. Its
`setElemDom` int/big verdict becomes a moot hint (the split handles both).
Optional later: a neutral `sortedJoin(s)` node so the frontend stops choosing
int/big at all.

### 3. The routing primitive + two-loop iteration

The `isSmall(v)` bound is target-specific, so the core emits a **generic
`SplitRoute` node** (or `sh2.splitRoute(v)` call) and each backend renders the
bound with its narrow-domain width (the same bound it uses for dual-loop
guards). This is the §11 split: mechanism in core, bound in backend.

`for x in s` becomes two check-free loops, each homogeneous by construction:

```
for x in s__small:  body_narrow(x)   # all i64, no per-iteration branch
for x in s__big:    body_wide(x)     # all BigInt, no per-iteration branch
```

The body is **versioned** (duplicated, arithmetic domain adjusted per
partition) — reuse the existing `dual_version_while` machinery (shir.rs:3109)
for the body-domain adjustment. This is strictly better than one array + a
per-iteration dispatch, which opt-levels.md explicitly refuses ("Never a
branch inside the loop"). The per-element cost is paid once at `add()`, not
per iteration.

### 4. `sorted()` / join merge

`sortedIntJoin(s)`/`sortedBigintJoin(s)` → merge of the two partitions:
- Shell target: `sort -n -u` over the concatenation (already
  arbitrary-precision, simplest).
- Native backends: a linear merge of two sorted runs (the C backend already
  has sorted-join helpers — `c_backend.rs` `sortedIntJoin`/`sortedBigintJoin`
  arms).

### 5. Soundness (fail-closed, mirroring the native-array migration)

- The set must be **append-only** (setArray init + setArrayAppend only; no
  indexed writes/deletes/assoc/dynamic — refuse otherwise).
- All refs to `s` program-wide lie in **one scope** (or the transform handles
  cross-scope); anything elsewhere refuses.
- The routing check **runs in the wide domain** (no overflow).
- **Dedup by value** (partition is a function of the value) preserves global
  set semantics.
- Iteration order changes, but Python set order is hash-based/arbitrary and
  the current insertion-order lowering already doesn't match python3 — the
  split does not make correctness worse. Verify the corpus doesn't pin a raw
  iteration order (the set tests all go through `sorted()`).

### 6. Marketplace offering (per §11)

The core owns the mechanism (`SplitRoute` node + `split-set` transform +
two-loop rendering). Each backend accepts/rejects the rendering. The transform
ships a manifest (prereqs: `setArray`/`setArrayAppend`/`sortedIntJoin`/
`sortedBigintJoin` present; invariant: split-set preserves set semantics;
intended scope: speed-class, O3+). Backends that refuse keep the single-array
path (current behavior).

## Regression guards

- **t89/t90 stay green** (correctness unchanged — the split is a performance
  optimization, not a semantic change).
- **New hot-iteration test**: a set that is mostly small with occasional big
  elements, iterated in a hot loop with arithmetic. Assert the narrow loop
  contains no BigInt (structural assertion, per the testing policy — not "did
  not crash").
- **A/B gate**: `SH2_SPLIT_SETS=0` vs `1` produce identical stdout/exit on
  the corpus (the firewall: levels change bytes/cycles, never behavior).

## Loop-width over the small partition (speculative overflow fallback)

The split-set's small partition is *bounded* (elements ≤ 2^63−1), but the loop
*body arithmetic* over it can still overflow (a sum-reduction over u64 elements
overflows u64). The strategy ladder, in order:

1. **Proven closure** → single narrow loop, no checks (existing).
2. **Entry-guarded dual** → one magnitude check at entry, guard implies
   closure (existing, opt-levels.md).
3. **Speculative narrow + overflow fallback** (NEW, this request) → for
   data-dependent loops where closure is unprovable but the loop is
   likely-narrow and hot. Run narrow with a **checked op** per arithmetic
   site; on overflow, **restart from a checkpoint in the wide domain**.
4. **Single wide loop** → unprovable / not hot (existing).

**The per-iteration check is a hardware side-effect flag, not a data-dependent
branch** — `__builtin_add_overflow` (C), `overflowing_add` (Rust),
`math/bits.Add64` (Go), `@addWithOverflow` (Zig), `Number.isSafeInteger` (JS).
It is almost always clear, so the branch predictor handles it perfectly; this
is what makes the speculative rung viable where a naive per-iteration guard
isn't. The fallback is **restart-based** (restore a checkpoint, re-run in
wide) — you cannot switch mid-loop because wrapped values are already
computed. Restart-from-beginning first; checkpointing later.

**Refinement — mid-loop domain switch (no redo).** Instead of restarting,
when an op overflows: (1) **do not write the overflowed value** (the checked
op's result is discarded — a wrapped value is never committed), (2) convert
the live loop-carried state (induction vars, accumulators, body-written vars)
to bigint, (3) **goto the corresponding point in the bigint mirror** and
continue. This is a continuation-style switch; it avoids redoing the work.
The clean framing: convert the loop-carried state, then redo the *remainder
of the current iteration* in bigint from the converted state.

**Switch-point placement is the complexity.** The bigint loop must be a
mirror with a label at each switch point, and each needs the live-variable
conversion. Switch points sit at the loop-carried arithmetic sites AND any
intermediate that can overflow given bounded inputs (`acc += arr[i] * 2`
needs a point at `arr[i] * 2` too). They multiply with body complexity.

**The accumulator-only case is cheap** (the split-set's small partition is
bounded, so only the accumulator can overflow): only `acc` converts, the
bigint loop is a near-copy with `acc` widened, elements stay narrow. This is
the partial fallback made cheap by the mid-loop switch.

**Tradeoff — restart is NOT simpler; the mid-loop switch is the default.**
Restart-from-beginning re-executes the aborted narrow run, so it is only
correct if that run had NO observable side effects (array writes, prints,
calls) — and you cannot roll back a print or a subprocess call. It therefore
requires a **purity proof** on the loop body: a hard semantic analysis that
excludes most real loops. The mid-loop switch has no such requirement:
control *transfers* at the overflow site, so each side effect happens exactly
once (before the site in narrow, after in bigint) — no re-execution, no
purity proof. Its complexity is purely mechanical (generate the bigint mirror
+ labels + gotos), which a compiler does reliably. So: **mid-loop switch is
the default**; restart-from-beginning is a later optimization for provably
pure loop bodies (single wide loop, no mirror/gotos).

**The u128/i128 tier is sound and valuable.** Summing N u64 values fits in
u128 iff N < 2^64 — provable for any u64-counted loop. So the proof
obligation is just *bound the iteration count and the element magnitudes*.
u128/i128 is native on 64-bit (2 registers), far faster than BigInt. It
composes with the split-set: the small partition is bounded by construction,
so the u128 proof is nearly free when iterating it.

**Partial fallback:** for a sum-reduction over a bounded set, only the
*accumulator* goes wide on overflow; the elements stay narrow (they are
bounded). Cheaper than a full wide loop.

**32-bit subset:** yes, consider it, but as a *third* tier gated behind the
64-bit machinery (same overflow/fallback machinery, narrower bound). The win
(no REX prefix, smaller encoding) is modest on modern x86-64; opt-levels.md
already has `u32`/`uint32_t` as a proven-range refinement. Most valuable for
genuinely-small sets (pixel values 0–255). Start with 64-bit; add 32-bit only
if profiling shows it matters.

**Full width hierarchy:** `i32/u32 → i64/u64 → u128/i128 (if provable) →
BigInt`. Each tier is a fallback target. JS is the odd one out — no u128, so
its wide domain is BigInt only.

## Open items

- Whether the frontend emits a neutral `sortedJoin(s)` node (removing its
  compile-time int/big verdict) or the core transform treats both existing
  nodes as the same consumer. The latter needs no frontend change; the former
  is cleaner.
- Whether the two-loop body versioning reuses `dual_version_while` directly or
  needs a collection-specific variant.
- The exact `SplitRoute` node shape in the A1 contract (additive, round-trip
  tested, per the contract rules).

## Implementation status (2026-09-09)

**Landed (first slice — the sorted()/join path):**
- Gating: `set_split_sets`/`split_sets_enabled` in `shir.rs` (mirrors
  `set_dual_loops`); CLI sets it at `-O3`/`-O4`.
- Transform `src/transforms/split_set.rs` (registered `split-set`): splits a
  set built via `setArray(s,[])`+`setArrayAppend(s,[v])` into `s` (small) +
  `s__big` (big), routes each append via `sh2.isSmallInt(v)`, and rewrites
  `sortedIntJoin`/`sortedBigintJoin` → `sortedJoinMerge(s, s__big)`. Wired
  into the A1-ingress path (`otranspilerl/src/lib.rs` `ingest`), self-gated.
- Runtime helpers `sh2.isSmallInt` (exact BigInt ±(2^53−1) check, no lossy
  Number conversion) and `sh2.sortedJoinMerge` (sort small as Numbers, big as
  BigInts, linear merge) in `harness/sh2-namespace.mjs`.
- 4 unit tests in `split_set.rs` (split, refuse-iterated, refuse-nonempty,
  disabled-by-default).
- Verified: A/B firewall holds (split == nosplit on t86/t88/t89/t90); t89/t90
  match python3; `isSmallInt` boundary exact (2^53−1 small, 2^53 big);
  `sortedJoinMerge` handles interleaving negative big values.

**Deferred (follow-up):** the two-loop iteration (`for x in s` → narrow loop
over `s` + wide loop over `s__big`) — iterated sets are currently refused by
the transform. The speculative overflow fallback / u128 tier / 32-bit subset
are design (see above), not yet implemented.

**Slot-homing fix (2026-09-09):** `analyze_true64` now refuses to home an
RMW accumulator in a BigInt64Array slot when any RHS operand has an
UNKNOWN or out-of-±2^53 range (a slot wraps mod 2^64, losing a bigint
operand — t91_set_sum_fallback dropped the 2^100 term).

**RESOLVED (2026-09-09, exact-BigInt accumulator):** t91 now matches
python3 (`1267650600228256423094467428346`). The frontend emits
`Cast(Int64, …)` for bigint-domain reads of int/big loop vars, and the
core (`shir::exact_bigint_var_read` in `arith_cast_to_estree`) renders a
non-C-typed / non--true64 / non-slot / non-wide-arm var arg EXACTLY
(`BigInt(var || 0)`, no `asIntN(64, …)` wrap). A `DUAL_WIDE_ARM` flag
(set around the versioned dual-loop wide-arm render alongside
`INT64_WRAP_FORCE`) keeps the bash int64 wide-arm casts on the mod-2^64
`asIntN` wrap path, so the py-sh-go exact-BigInt read and the bash int64
wrap are no longer ambiguous (the earlier `bigint_homed` attempt could
not distinguish them, and the broad no-wrap-instead-of-`bigint_homed`
change broke `dual_shape_when_opted_in`). The frontend still types big
vars as widthless `Int` (never the C-only `Int64` object kind), so the
assignment write is not wrapped either. This is the exact-sum correctness
guard; the split-set speculative narrow-then-wide two-loop fallback
remains design/follow-up.
