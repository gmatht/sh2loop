# Dual loops, triple loops, and assumed widths: where versioning lives

Status: **design doc only — no implementation**. This document decides
three related questions: where multi-version lowering belongs in the
pipeline (frontend / core / backend), whether a third (or Nth) tier
ever pays (the i32/i128 question), and how profiling validates the
proofs versioning rests on — including a flag to compile against only
the bit sizes a benchmark observed.

Related (read first, not duplicated here):

- `docs/OPTIMISED_LIST.md` — the extent B-tree (partition by class) and
  the consumption-profile pass (prove the consumer before maintaining
  metadata). Extents answer *where values live*; this doc answers *how
  many code versions operate on them*.
- `docs/LISTS.MD` §2–§4 — container shapes and the op census; §6.4 on
  constant tuning.
- `docs/PROFILING.md` — metric catalog, profile schema, advisory vs
  assertive modes, profile asserts (§5.2). This doc is that doc's first
  customer.
- `sh2perl/docs/opt-levels.md` — the level taxonomy and the firewall
  (levels change bytes and cycles, **never observable behavior**). Every
  versioning decision below must clear that firewall or carry an
  explicit guard (see §5).

## 0. Taxonomy: three different things called "two paths"

The codebase already has three mechanisms that are easy to conflate.
They have different soundness stories and different homes:

| mechanism | shape | guard | example in-tree |
|---|---|---|---|
| **Versioned loop** (dual loop) | whole loop body duplicated; one guard at entry picks an arm | entry condition over proven ranges (`dual_version_while`, `shir.rs:3129`) | i53 fast arm + BigInt exact arm on JS at `-O3` |
| **Split routing** (dynamic) | single body; per-element branch routes each value | per-element class test at each operation | split-set union (`s` + `s__big`, `isSmallInt` routing, `sortedJoinMerge`) |
| **Tiered lift** (single path, wider type) | one body, widened bindings | none (the wide type is exact for all inputs) | true64 `BigInt64Array` slots; `int_array_widths` narrowing (the reverse: narrowing a single path) |

Rule of thumb: version when the fast path is *wrong* outside its range
(needs a guard); route when values of different classes *interleave*
at runtime (no static partition exists); lift when one type is exact
for everything and merely slower (no guard, just cost). Confusing them
produces the classic bugs: a version without a guard (miscompile past
the range), a route with a hoisted guard (wrong for mixed inputs), a
lift where the wide type is lossy (silent rounding — the `Number`
past-2^53 failure the BigInt tier exists to prevent).

## 1. Where to implement dual-loops etc.

### 1.1 The split the codebase already enforces

- **Core (`shir.rs`, `shir_passes/`)** owns everything soundness-critical:
  the analyses that prove ranges/overflow-freedom (`analyze_var_ranges`,
  nonzero-divisor proofs via `set_nonzero_vars`, the `arith_versionable_op`
  subset check), the *mechanism* of versioning (duplicate + guard +
  preserve semantics on both arms), and the A/B firewall (split must not
  change observable behavior). Rationale: a wrong guard is a miscompile
  in *every* backend — it cannot be a backend-local judgment. This
  mirrors the §11 marketplace rule (mechanism in core) and the toolkit
  purity rule (no frontend-specific logic in shared passes: `CORRO_*`-style
  leakage has a name here too — no `PY_*`/`JS_*` special cases in the
  versioning core).
- **Frontends** own *domain facts*: which values are proven in which
  class (`setElemDom` int/big, `Cast(Int64, …)` witnesses, literal
  ranges). They emit the facts as IR annotations, never as lowering
  decisions.
- **Backends** own *arm selection and the cost model*: which tiers to
  materialize for a proven profile, how the guard lowers (a branch? a
  separate function? fallthrough order?), and when to decline versioning
  entirely. The same profile means different code per backend (§2).

### 1.2 At which IR level

Versioning happens as a **shIR-to-shIR transform** (today's
`dual_version_while`: `While` → guarded two-`While`), not in the
renderer, for three reasons:

1. Every backend inherits the same soundness argument (prove once).
2. Downstream shared passes (dead-store elim, const markup, the
   lifetime analysis the C backend sizes buffers from) see the final
   shape — versioning *before* them keeps their verdicts truthful.
3. The A/B firewall is testable at the IR level (same input program,
   versions on/off, diff the renders + run both).

What must NOT move into renderers: guard *correctness* (which condition
implies which arm is sound). What SHOULD stay renderer-local: guard
*form* (branch vs dispatch table vs outlined function), arm order
(likely-first for branch prediction — the backend knows its profile
better than the core), and the decline decision (`-Os`/`-Oz` forbid
duplication per opt-levels.md; a backend whose tiers cost the same
renders one arm — see C below).

### 1.3 The decline path (as important as the version path)

Every versioning site needs a reviewer-visible reason it *didn't*
version: unversionable cond op, unversionable body statement, analysis
budget exhausted (`-O0` skips the fixpoints), size profile (`-Os`),
or single-tier backend. Decline is the default; versioning is the
privilege that must be earned per site. (Failure mode this prevents:
a half-versioned loop — fast arm taken where the proof doesn't reach.
The `vars_ok` + `body_versionable` conjunction in `dual_version_while`
is the template: *all* premises must hold, no partial credit.)

## 2. Are triple loops worth it?

### 2.1 The tier tables (what a third arm would even be)

| backend | tier 1 (fast) | tier 2 (middle) | tier 3 (exact) | middle-vs-top gap |
|---|---|---|---|---|
| JS | i32-ish Smi ops / `\|0` | f64 Number (i53) | BigInt | **huge** (native double vs bigint dispatch) |
| C | i32/u32 (native) | i64/u64 (native) | GMP mpz | ~zero scalar (all native); SIMD-width only |
| Zig | i32/i64 | i64/u64 wider | `Managed` bigint | large (managed bigint) |
| Perl | IV | NV | PV/Math::BigInt-ish | moderate (dualvar dispatch) |

Reading: a middle tier pays **iff** (a) it is much faster than the top
tier *on that backend*, (b) it is much more likely than the top tier
(proven or profiled), and (c) the guard chain stays cheap. JS clears
(a) decisively (Number vs BigInt is the codebase's biggest verified
gap — the t86 loop exists because of it); C fails (a) for scalar code
(the C "dual" is really fixed-vs-GMP — a third int tier buys nothing
except autovectorizer food, which belongs in §2.3, not in versioning).

### 2.2 The cost model (when N=3 beats N=2 beats N=1)

Per versioned site, with tier values partitioning the range:

```
win(N) = Σ_trips × Σ_tiers P(tier) × [cost(top) − cost(tier)]
       − guard_cost(N) − size_cost(N) × compile_and_icache_weight
```

- `guard_cost` grows with N (a chain of range checks; hoistable to the
  entry only when the range is loop-invariant — else it rots into
  per-iteration checks and the whole scheme loses to split routing).
- `size_cost` grows ~linearly (×N code bodies; matters at `-Os`/`-Oz`,
  which therefore cap N=1 — the levels doc already forbids duplication
  there; triple loops are an `-O3`-only conversation).
- The middle tier needs a *disjoint* range proof (or profile slice):
  i32-provable-but-not-i53 is rare in real programs (loop counters are
  the main case, and those are usually unbounded → unprovable →
  profile-only).

Practical rule, stated as a gate rather than an opinion: a third arm
ships for a (backend, op-class) pair only with a measured workload
where N=3 beats N=2 by more than the noise floor (bench.sh,
informational per testing policy) **and** the guard provably hoists.
Without both, the third arm is speculative code bloat that the next
reader must maintain without understanding — the exact failure mode
the decline path (§1.3) exists to prevent.

### 2.3 What triple loops are NOT (common confusions)

- **Not narrowed single-version** (`int_array_widths`, extent widths):
  when values are *proven* in i32, one i32 version wins outright — no
  guard, no second body. Multi-versioning is only for the unproven.
- **Not the three-run partition** (`-bigint / i64 / +bigint` sorted
  join, `sortedJoinMerge`): that is split-routing with a static
  partition (one pass over classes, §0), not versioned loops.
- **Not SIMD**: narrower C int tiers for autovectorization are a
  *layout* decision (extent widths), orthogonal to versioning. If the
  vectorizer wants i32, narrow the extent; do not version the loop.

### 2.4 The profile-measured middle (where triple loops actually live)

The honest home for N≥3 is **profile-measured, guard-checked**
assertive mode (PROFILING.MD §5.3): the distribution (how often each
tier hits) cannot be proven in general but is trivially measured.
A triple loop then reads as: fast arm (profile says 99.9%), middle arm
(profile says 0.1%), exact arm (never observed, guard-kept). The middle
arm exists *because the profile showed the top arm firing* — without
that measurement it would never be written. This inverts the usual
order: don't version speculatively and hope; measure first, version
exactly the observed shape.

### 2.5 Memory-driven tiers: packing as the reason for N≥3

Sections 2.1–2.4 price *cycles*. For large data structures the
dominant currency is *bytes*: narrower tiers pack denser, and the win
is large enough to justify version tiers that speed alone never would
— including on backends (like C) where all int widths execute at the
same scalar speed.

The packing ladder (bytes/element; a 67M-element array for scale):

| tier | bytes/elem | 67M array | notes |
|---|---|---|---|
| i64/u64 | 8 | 536 MB | baseline |
| i32/u32 | 4 | 268 MB | |
| i16/u16 | 2 | 134 MB | |
| i8/u8 | 1 | 67 MB | |
| bool/bitset | 1/8 | ~8 MB | booleans/predicates only |
| nibble (4-bit) | 1/2 | ~34 MB | values 0–15; unpack tax |
| varint/RLE/delta/dict | data-dependent | — | needs profile evidence |

Why this matters more than ALU:

- **Cache steps, not slopes.** The win is discontinuous: packing from
  600 MB to 300 MB on a 256 MB L3 still misses; 600 → 150 MB (i16)
  suddenly fits, and every subsequent iteration stops touching DRAM.
  Tier choice should therefore consider *cache-size steps*, not just
  linear byte savings — a tier whose footprint lands just under a
  cache level beats a narrower tier that doesn't change residency.
- **Allocation success.** 8x smaller fits where the wide version OOMs
  (fixed caps, 32-bit address spaces, WASM linear memories). Against
  OOM the value of packing is effectively infinite — the alternative
  is not "slower" but "does not run".
- **Bandwidth-bound scans.** Sum/scan/sort/join over a packed array
  move proportionally fewer bytes; for streaming ops the speedup
  tracks the packing ratio almost exactly.
- **Where it loses.** Below cache residency the unpack tax is pure
  loss (extra ALU per read for zero bandwidth gain); random access
  into bit-packed/nibble tiers pays per-read decode. Small structures
  must never pack — the decision needs a size floor as well as a
  width ceiling.

Mechanics (same guard discipline as §2, storage-flavored):

- **Store-side width check, one-way widen.** Reads need no guard
  (stored values fit by construction). On a too-wide store,
  reallocate wider and convert — amortized like vec growth — with
  mid-loop control transfer (the same shape as the split-set
  mid-loop switch: transfer, never restart, so side effects happen
  once).
- **Aggregates stay wide.** Packed *storage* is not packed
  *computation*: a sum over i8 elements still accumulates in i64
  (a `sum` that wrapped at 127 would be a miscompile, not an
  optimization). Rule: aggregate tier ≥ element tier, always.
- **Order preservation.** Signed→unsigned reinterpretation does not
  preserve order (sign bit) — sorted joins and comparisons over
  packed extents must account for it (bias the sign bit, or keep a
  signed tier for order-sensitive consumers).

Composition with the existing designs:

- **Heterogeneous per-extent packing** (OPTIMISED_LIST.MD open
  question #5): an i8 extent and an i64 extent coexist in one list,
  each single-version at its own width. This is usually *better* than
  versioned loops over a uniformly-packed array — per-extent choice
  needs no guard at all when the extent's class is proven, and a
  store-side widen only when it isn't.
- **Chunked deque blocks pack independently** (LISTS.MD §2.D): a
  fresh block starts narrow and widens on demand — packing falls out
  of the block lifecycle with no global decision.
- **SmallVec inline storage** stays width-agnostic (inline bytes are
  fixed by the struct; packing the spill is a separate decision).

Decision rule (extends §2.2's `win(N)`): add a memory term — bytes
saved × trips × bandwidth cost, *plus* the cache-step bonus (a step
function at L1/L2/L3/RAM sizes for the target), *plus* OOM-avoidance
valued as run-vs-not-run.

What profiling is (and isn't) needed for the memory decision: less
than §2.4 suggests. Footprint is `count × width + overhead`, and —
unlike speed, which needs dynamic probabilities — both factors
usually have *static* upper bounds from analyses this repo already
runs:

| count bound | width bound | decision (no profile needed) |
|---|---|---|
| proven (`append_hi`) | proven (range analysis) | exact saving; pack with no guard at all |
| proven | unproven | pack speculatively behind the store-side widen guard; saving holds iff values fit |
| unproven | proven | per-element saving certain; growth path handles count |
| unproven | unproven | needs likelihood (profile) or domain knowledge to justify the machinery |

So for the power-of-two ladder, only the bottom-right cell wants a
profile — and even there the profile answers *likelihood*, not
*safety* (the widen guard keeps speculative packing correct
regardless). The size floor is likewise static (`append_hi` below
threshold ⇒ never pack). Even cache-step reasoning is mostly static:
L1/L2/L3 sizes are target constants, the working set is count ×
width, both bounded above — residency *upper bounds* compose from
static parts.

Genuinely hard without profiling: unproven-width *likelihood* (how
often would the widen path actually fire?), data-dependent schemes
(RLE/dict/delta need cardinality/sortedness — dynamic properties by
definition), allocator realities (rounding, fragmentation — bounds
still hold, exact RSS doesn't), cache residency under concurrent
load, and workload shift (a list outgrowing its observed max — the
guard handles it, but the saving evaporates). None of these affect
correctness, only whether the tier earns its maintenance cost.

Profile-measured distributions therefore choose tiers only where
static bounds run out — primarily the bottom-right cell and the
beyond-quad data-dependent packings.

What static *can't* tell you (the other half of the ledger):

- **Typical vs bound savings.** A bound says "at most N elements of
  at most width W" — the saving vs the unpacked baseline is exact
  *as a bound*, but bounds are worst-case and worst cases are rare.
  An `append_hi` of 10⁹ with a real workload of 3 elements saves ~12
  bytes in practice while the bound claims gigabytes. The amount that
  matters for the decision is *typical absolute savings*, and that is
  a measured quantity (or a domain prior — same thing with less
  paperwork). Relatedly, the counterfactual itself can be unknowable
  statically: for unbounded structures there is no baseline footprint
  to save *from*.
- **Fit likelihood.** When the width is unproven, static tells you the
  guard exists, not how often it fires. A widen path that never fires
  is free; one firing every hundred stores dominates. Only measurement
  (or a domain prior) separates them.
- **The machinery's own footprint.** Versioned loop bodies live in
  `.text` × N (I-cache pressure — packing data to fit D-cache while
  bloating I-cache is a real tradeoff), plus widen paths, guard
  tables, and cap/len bookkeeping per array. This cost is *exactly*
  knowable statically (it is emitted code — count it!), and the size
  floor must clear *it*, not just the data size: packing 12 bytes
  with 2 KB of versioning machinery is a net loss no profile can fix.
- **Widen-transient doubling.** Converting narrow→wide needs both
  arrays live at once (old N bytes + new up-to-8N) — peak transient
  ≈ 9N against a steady state of 8N. Packing to *avoid* OOM has a
  hole exactly at the widen step: if 9N doesn't fit, the widen dies
  trying to prevent death. Mitigations, in order of preference:
  chunk-wise convert-and-free (spare block only, no 2x transient),
  and failing that, the P1 fail-stop (abort loudly on alloc failure
  — the existing OOM policy already answers this: a loud abort beats
  silent corruption, and it only triggers where the unpacked build
  would also have died, earlier).
- **Resident-set reality.** Static bounds compose into footprint
  upper bounds, but RSS also reflects allocator rounding,
  fragmentation, and what else shares the machine — none statically
  knowable. Bounds tell you what *fits*; only measurement tells you
  what *fit*.

Net: static decides *shape* (which tiers, which guards, exact
machinery cost) and *safety* (bounds, widen paths, fail-stops);
measurement decides *worth* (typical savings, fit likelihood,
residency achieved). A packing decision needs both columns, and the
doc's earlier framing leaned too far toward the first. Quad (64/32/16/8) remains the sweet spot for the ladder itself — it covers the realistic integer range with uniform power-of-two mechanics. Beyond quad, tiers must be data-dependent packings (nibble/varint/RLE/delta/dict), each requiring profile evidence that the data has the shape (low cardinality, sorted runs, tiny range) — never speculative.

Correction to §2.1's C row: scalar ALU shows no i32-vs-i64 gap, but
the cache/bandwidth gap is real for large arrays — triple versioning
in C is a *memory* play (pack for residency), not a speed play. The
table's verdict stands (no scalar-ALU middle tier), with packing as
the separate, legitimate reason for narrow tiers there.

### 2.6 Fixed-width wide tiers: when BigInt(128/256) earns its place

Between native i64 and arbitrary-precision GMP sits a tier the matrix
above skips: *fixed-width* wide integers — 128 and 256 bits with no
heap, no size dispatch, no allocator traffic. The question is when
such a tier beats both neighbors, and the answer splits by width and
by op mix.

The ladder, with what each step costs (per-op, steady state):

| tier | representation | add/sub | mul | div/mod | cmp/bitwise |
|---|---|---|---|---|---|
| i64/u64 | 1 limb, hardware | 1 insn | 1 insn | 1 slow insn | 1 insn |
| u128/s128 | 2 limbs; `__int128` HW on x86-64, native in Zig/Rust | ~1–2 insn | ~4 limb-mults | libcall-ish / multi-div64 | trivial |
| u256 | 4×u64 manual carry chains (C); native `u256` in Zig | ~4–8 insn + carries | 16 limb-mults | schoolbook long division (~16+ div64, each 20–90 cycles) | trivial |
| u512+ | 8+ limbs, quadratic mul | costly | 64+ limb-mults | very costly | trivial |
| GMP mpz | heap limbs + size + dispatch | call + alloc risk | Karatsuba/Toom + asm | optimized asm, still heavy | call overhead |

Reading it:

- **u128 is nearly free.** On x86-64, `__int128` add/sub/mul are
  hardware (one or two instructions); Zig and Rust have native
  128-bit ints outright. Whenever values exceed i64 but fit 128 —
  UUIDs and 128-bit counters, IPv6 arithmetic, 128-bit hashes,
  nanosecond timestamps past 2262 — the u128 tier wins over GMP by
  roughly the whole allocation+dispatch cost, with almost no per-op
  penalty over i64. This tier should be the *default* second rung
  everywhere, taken on proof *or* profile with a store-side widen
  guard to GMP.
- **u256 is where it gets interesting.** Manual carry chains make
  add/sub/mul a small constant multiple of i64 — still an order of
  magnitude cheaper than GMP's per-op call+dispatch+possible-alloc
  for bulk loops. Worth it when (a) values are bounded in 256 bits
  (proven range, domain knowledge — SHA-256 digests *are* 256-bit
  values, ed25519 field elements live under 2²⁵⁵ — or profiled max
  with a widen guard), (b) the op mix favors limbs (add/sub/mul/
  cmp/bitwise; see div caveat), and (c) scale amortizes (many
  elements or a hot loop; a handful of values never repays the
  tier's code).
- **Division is the whole ballgame.** Schoolbook multi-limb div costs
  O(limbs²) slow `div64`s; GMP answers with Karatsuba/Toom-Cook plus
  hand-tuned assembly. For div/mod-heavy loops the fixed-wide tier
  may merely tie GMP — or lose once allocation is out of the
  picture. Rule: add/sub/mul/cmp/bitwise-dominated workloads take
  the fixed tier confidently; div/mod-dominated ones measure first
  (bench.sh) or default to GMP. Never assert — the constants decide,
  per workload.
- **Wider than 256 needs a reason, not just room.** Limb-mul cost
  grows quadratically (4 → 16 → 64), so each wider tier must be the
  *narrowest fitting width* — never wider "for headroom" (headroom
  is what the GMP fallback is for). RSA-2048-style values skip the
  ladder straight to GMP.
- **Comparison/sort-only workloads are trivially safe at any fixed
  width** (memcmp-shaped, no arithmetic at all) — sorting 256-bit
  keys needs no div machinery, no carry chains, nothing but order.
  This is the cheapest fixed-wide win and should be taken first.

Per-backend reality (same rule as §2.1 — the tier must exist *and*
be cheap *there*):

- **Zig**: `u256`/`u512`/wider are *native* arbitrary-width ints —
  the best backend for fixed-wide tiers by far. Bounded → just use
  the width. Almost no reason to ever route bounded-under-512-bit
  values to `Managed`.
- **C**: `__int128` native (u128 trivially worth it); u256 as manual
  `u64×4` (worth it for bulk add/mul-heavy per above); u512+ manual
  (rarely — quadratic mul bites, needs measured justification).
- **Rust**: no `u256` in core (`u128` native) — a fixed-256 tier
  means an external crate (`crypto-bigint` or similar), which is a
  *dependency* decision, not just a code decision. u128: free, take
  it. u256: only with a measured workload that repays a dependency.
- **JS**: no fixed-width bigints exist — never. `BigInt` tier only.
  (A fixed-wide *simulation* in f64 pairs would be slower than
  BigInt and less exact — anti-optimization.)
- **Perl/Python/Go**: bignum-library tiers only (`Math::BigInt`,
  `int`, `big.Int` — all heap/arbitrary). No fixed-wide loop tier.

Guards and composition:

- Bound sources, in order of preference: proven range (no guard),
  domain knowledge (crypto field sizes, address widths — documented
  at the site, reviewed like code), profile-measured max + widen
  guard to GMP (assertive mode, §4). Never bare hope.
- Signedness is part of the tier: `s128`/`s256` two's complement
  with *signed* compares, matching source semantics — an unsigned
  compare on signed values is a miscompile, not a narrowing.
- Printing/serialization may use a *different* tier than compute
  (convert once at the boundary, e.g. via the GMP print path) —
  tier-per-operation-class is allowed, but each boundary convert
  must be audited like any other widening.
- With §2.5 packing: a u256 extent packs 2× denser than GMP limbs
  *and* skips allocation — fixed-wide tiers are simultaneously the
  memory play. Heterogeneous extents (`i64` extent + `u256` extent
  + GMP extent) compose exactly like §2.5 describes.

## 3. Profiling checking proven assumptions

This is PROFILING.MD §5.2 aimed at the versioning proofs specifically.
Every guard the versioner emits rests on a proof; every proof is a
falsifiable claim; a profile is the falsifier. Concretely, the
assumption registry for this codebase (each item: the claim, what
breaks if wrong, how a profile checks it):

| assumption (proof site) | claim | breakage if false | profile check |
|---|---|---|---|
| nonzero divisor (`set_nonzero_vars` → dropped `mpz_sgn` guard) | divisor never 0 in any mentioning scope | div-by-zero crash / wrong abort semantics | divisor-value buckets incl. an explicit zero bucket; any hit = P0 bug report |
| `int_array_widths` narrowings | every element fits the width | wraparound / truncation | per-array magnitude bucket vs proving bound |
| `append_hi` bounds (list_profile) | length never exceeds the bound | the exit-127 the bound was built to avoid (or a wrong `Fixed`) | max-length assertion per array |
| dual-loop entry guards (`dual_version_while` cond) | taken arm's range holds for the whole trip | wrong-arm execution (miscompute) | arm-taken counters + max-range-seen per guard |
| param-range proofs (`strip_proven_nonzero_guard`, `HoistCalls`) | every static call site passes in-range args | guard stripped wrongly → `NaN`/`0` divergence | arg-magnitude buckets per call site |
| true64 slot homing (`slot_var_index` / RMW chains) | accumulator stays in int64 | silent wrap | accumulator magnitude bucket |
| trip bounds (`analyze_var_ranges`-derived) | loop iterates within bound | under-allocated scratch / wrong unroll | trip histogram vs bound |
| monomorphic call sites (any future specialization) | one arg-type tuple | guard fallback (benign if guarded; bug if not) | type bitmap vs assumed tuple |

Mechanics (per PROFILING.MD §5.2, specialized): each proof registers
`(claim, site, bound)` at transpile time; `--profile-checks` emits an
`assert()` per claim; a firing assert is filed as *proof bug*, never
worked around in the profile. Differential mode (log divergences
without asserting) is how *new* proofs are explored before being
trusted: run the proof and the check side by side on the corpus for a
release cycle; promote to assert only at zero divergences.

The meta-point: a proof without a falsifier rots. Today's conservative
analyses are *probably* right; the registry makes that measurable, and
the measured over-approximation (`append_hi` said 1024, reality said
6 — the t86 shape) is what justifies tightening them later.

## 4. Flag: assume only the bit sizes seen in the benchmark

### 4.1 Semantics (exact)

`--assume-observed-widths=<profile>` (name TBD; env mirror
`SH2_ASSUME_OBSERVED_WIDTHS`, following the `SH2_ASSUME_*` convention
— default OFF, `=0`/absent disables): compile *as if* every integer
value fits the max bucket its profile records, **with a guard on every
widening operation that can prove nothing statically**:

- Width selection (array homing, scalar homing, extent widths, param
  slots) uses the observed bucket instead of the proven bound.
- Every op that could exceed it carries a check + fallback: C integer
  ops use checked arithmetic (`__builtin_add_overflow` family, or
  manual pre-checks where builtins are unavailable) routing to the
  next tier up to GMP; JS re-checks `Number.isSafeInteger` at tier
  boundaries (or stays BigInt past i53 — the flag never narrows past
  exactness without a guard that preserves it).
- Escape hatch stays fully guarded: any value from outside the
  profiled program (external callers, FFI, `--library` exports,
  `eval`) takes the generic path — the flag only specializes
  *provenance-closed* flows. `--library` + this flag is either refused
  or forces guards on every export boundary (loud, documented).

What the flag is NOT: a license to delete checks. Any use that removes
a guard rather than specializing behind one is a miscompile-in-waiting
and is refused the same way an unproven static claim is. The emitted
code must show the reader exactly what happens on violation (the
PROFILING.MD rule: point at the `else` branch).

### 4.2 Staleness and refusal (hard, not advisory)

Unlike advisory profiles, this flag changes what the compiler
*assumes* — so staleness handling is refusal-grade:

- Missing profile file → hard error (never silent default; a build
  that "works" by ignoring the flag is worse than no build).
- Source/options hash mismatch → hard error (refuse to compile).
  Rationale: an assertive assumption about *other code's* values is
  unsound by construction (the new code was never measured).
- Workload mismatch is *not* checked (cannot be — same program, new
  inputs) — that is precisely what the guards are for. The flag
  trades guard-coldness for sizing precision, never correctness.

### 4.3 Placement in the existing conventions

- It is **not an `-O` level** (opt-levels.md: levels never change
  behavior; this flag changes what is *assumed*, guarded or not — it
  is a semantic-dimension flag like `--true64`, explicit and separate).
- It **composes** with levels: `-O3` + assume-observed = versioned
  loops whose tiers come from measurement; `-Os` + assume-observed =
  single narrowed path with guards (no duplication — the levels doc
  already forbids it there).
- Env form follows `SH2_ASSUME_*` (default OFF); CLI form takes the
  profile path (an env var cannot carry a filename robustly across
  the harness — actually it can, but the CLI form is auditable in
  build logs; do both, CLI wins on conflict).
- Relation to `SH2_ASSUME_I53` ("vars NOT proven big stay JS..."):
  that assumption is *static-default* (no measurement, no guard
  beyond existing semantics); the new flag is its measured,
  guarded, per-program refinement. If both are ever in tension, the
  flag's explicit profile wins and the assumption's default yields —
  statically-default assumptions must never silently override an
  explicit measurement.

### 4.4 What it must refuse (non-exhaustive)

- `--library` exports without per-boundary guards (external inputs
  are unmeasured by definition).
- Programs with `eval`/`source`/dynamic dispatch touching sized
  values (provenance open).
- Workloads the profile doesn't cover, claimed by naming only (no
  mechanism can verify workload coverage — document the gap, rely on
  guards).
- Combining with `-O0` (no analyses run; there is nothing sane to
  specialize — refuse loudly, don't silently ignore).

## 5. Worked shape: t86 under all four sections

- §1: the isqrt bound versions in core (`dual_version_while` shape),
  arms selected per backend (JS: Number/BigInt; C: i64/GMP or
  narrowed widths); the frontend emits only domain facts.
- §2: no third arm — the middle tier (i32) has no measured workload
  beating two tiers; the i64 bulk + bigint tail partition (split
  routing, not versioning) already captures the shape.
- §3: profile asserts on `append_hi` (factors), the isqrt-entry guard
  range, and the divisor-nonzero proof in the divisibility test —
  each falsifiable on the next new input.
- §4: with a t86 workload profile (max factor magnitude observed),
  `--assume-observed-widths` could narrow the factor extents to the
  observed bucket behind overflow guards; without it, the proven
  bounds stand.

## 6. Open questions / non-goals

1. **Guard placement**: entry-hoisted vs per-operation — entry guards
   need loop-invariant ranges (uncommon); per-op guards cost per
   iteration (defeats the purpose for tight loops). The middle ground
   (guard the *transfer* points: appends, param entries, returns) is
   sketched but not designed.
2. **Who runs the workload?** Same open question as PROFILING.MD §8.1,
   sharpened: assertive flags need *trusted* workloads, not just any
   inputs. No trust model is proposed here.
3. **Tier-count caps per backend**: a `max_tiers` knob (default 2,
   `-Os` forces 1) would make §2's gate mechanical — but adds config
   surface for a decision with no measured demand yet. Deferred until
   the first N=3 candidate with numbers.
4. **Non-goal**: auto-tuning search over tierings (compile each
   combination, keep the fastest) — bench.sh measures implementations,
   not combinations; the space explodes (tiers × loops × backends).
   Profiles inform one human-reviewed decision at a time.
5. **Non-goal**: changing the firewall. Every section above preserves
   it: versions/guards/fallbacks keep stdout identical with or without
   profiles, flags, or tiers. A divergence is a P0 miscompile, and
   the gates stay profile-blind.
