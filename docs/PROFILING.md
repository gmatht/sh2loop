# Profiling real-world use: what to measure, how, and how the next translation uses it

Status: **design doc only — no implementation**. This document asks what
a profile-guided transpilation loop would look like here: which
measurements pay for themselves, how to take them without distorting
the program, and how a later translation consumes them without ever
weakening correctness.

Related (read first, not duplicated here):

- `docs/LISTS.MD` §4 — the static analyses profiles would complement
  (op census, trip-count bounds, structure selection). Every place that
  doc says "over-approximates (safe direction)" or "returns None" is a
  place a measured value could sharpen the decision.
- `docs/OPTIMISED_LIST.md` — consumption profiles and aggregate
  maintenance (a profile tells us which aggregates *actually* pay).
- `bench.sh` — comparative benchmarking (bash/dash/JS/C, auto-calibrated).
  Benchmarks measure *implementations*; profiles measure *programs*.
  The two meet in §7.
- `harness/sh2-namespace.mjs`, `harness/estree-runner.mjs` — the JS
  execution path a JS-side profiler would instrument.

## 1. Why: the exact places static proof gives up

The static analyses are deliberately fail-closed, and each refusal has a
price. A profile is ground truth where proof is absent:

| static refusal (today) | price paid | what a profile would say |
|---|---|---|
| Trip bound `None` (dynamic loop bound; `analyze_string_lengths` CAP) | every unbounded list grows by realloc instead of one exact `malloc`; every unbounded loop keeps generic guards | the actual max trip count and max list length observed |
| `setArray`-in-loop over-approximates resets (list_profile bounds) | upper bounds balloon → `Vec` where `Fixed` would do | whether the reset ever actually re-executes (often: once) |
| Call-site types unproven (positional `$N` reads) | `Number(p)`/`atoll` coercion at every entry + retained `|| 0` guards | the runtime types actually received per call site (monomorphic?) |
| Width unknown (`int_array_widths` widens to I64) | 8 bytes/element + 64-bit ALU everywhere | the max magnitude actually stored per array |
| Bigint tier (`2**100` poisons the list) | GMP path for all elements and all ops | whether any bigint *ever* arrives (often: never in production) |
| Branch layout | cold error paths inline in hot loops | taken/not-taken counts per site |
| `max`/`min`/`sum` aggregates maintained speculatively | O(1) per-append upkeep for a reduction nobody calls | whether the reduction *ever* executes |

The pattern: static analysis answers "what *may* happen" (sound, often
vague); profiling answers "what *did* happen" (precise, possibly
stale). The design below keeps the first as the safety net and uses
the second only to *rank and sharpen* decisions the first already
proved safe — plus one narrow assertive mode (§5.3) with runtime
guards, for the cases where the static answer is "unknown" rather
than "no".

## 2. What to measure (metric catalog)

Every metric names its consumer. No vanity metrics: if no lowering
decision reads it, it is not collected.

### 2.1 Value profiles (per variable / per array)

- **Integer magnitude histogram** (bucketed: fits i8/u8/…/i64/u64, beyond
  i64). Consumers: `int_array_widths` (exact narrow width instead of
  proven bound), the bigint tier decision (stays GMP iff a bigint was
  *observed* — with an overflow guard, §5.3), scalar homing widths.
  Buckets, never raw values (privacy + bounded size, §6).
- **String length histogram** (for `char*` homes and `var_lengths`):
  max observed length per string var. Consumer: fixed-buffer sizing
  (`char s[N]`) with a length guard instead of heap.
- **Array length trace**: max length reached per array + growth-event
  count (how many reallocs). Consumers: `Fixed` vs `Vec` (observed max
  ≤ cap ⇒ fixed is *sufficient*, no proof needed), initial `cap`
  pre-sizing (one `malloc`, zero regrowth), SmallVec inline-N tuning.
- **Set cardinality + touch shape**: max size, insert/delete ratio.
  Consumer: set lowering choice (sorted-vec vs hash, §6.4 open question
  in LISTS.MD).

### 2.2 Control profiles (per site)

- **Loop trip counts**: exact trips per execution (histogram: min/p50/max),
  per loop site. Consumers: bound assertions (§7.1 — checking the static
  `append_hi` against reality), unroll/jam decisions, hoist validation
  (was the hoisted invariant really invariant?).
- **Branch taken/not-taken** per `if`/`while`/`case` arm. Consumers: block
  layout (`__builtin_expect`, cold outlining of error paths out of hot
  loops), `&&`/`||` ordering.
- **Function call counts + arg-type matrix** per call site: how often,
  and the runtime type tuple received (number/string/bigint/object).
  Consumers: monomorphic-site specialization (drop a guard when one
  type observed 100%), the `Number(p)`-elimination proof (§4 below in
  spirit — observed monomorphism backs the static proof, never replaces
  it without a guard), inlining thresholds.
- **Reduction/consumer execution bits**: did `max`/`min`/`sum`/`sorted`
  *execute* (not just exist)? Consumers: aggregate maintenance on/off
  (LISTS.MD gates metadata on *proven* consumers; execution bits are
  the ground-truth version).

### 2.3 Cost profiles (per program run)

- **Allocation census**: malloc/realloc/free counts + bytes per site
  class (vec growth, string temps, vbufs). Consumers: temp-buffer
  pooling, SmallVec sizing, strdup discipline review.
- **Helper-call mix**: how often each `_sh_*`/runtime helper runs
  (e.g. is `_sh_isqrt` hot or once-per-run?). Consumers: inline-vs-call
  decisions, precomputation.
- **Wall time per function/loop** (sampling only, §3.3): ranks *where*
  any of the above matters. A perfect profile of cold code is worthless;
  time focuses effort. Informational only — never a gate.

## 3. How to measure

### 3.1 Instrumented builds (primary: C target)

The transpilers already emit C, so the lowest-friction profiler is a
`--profile`-style emission mode (name TBD) that plants counters:

- **Counter arrays, not callouts**: one static `uint64_t` per site
  (trip sums, taken/not-taken pairs) — single-instruction overhead,
  no function-call perturbation of the hot loop.
- **Bucketed value histograms**: magnitude/length observations update
  one of ~8 buckets by shift/compare — O(1), no allocation, no raw
  values recorded (privacy, §6).
- **Call-site type matrix**: each instrumented call records arg-type
  tags into a small per-site bitmap (none observed yet ⇒ bit set on
  first sighting — 1 byte per type per site).
- **Dump at exit**: `atexit` handler writes one JSON file
  (`<prog>.profile.json`: site IDs → counters). Merging across runs:
  counters add, histograms take max/union, type bitmaps OR. Never
  average away a max (bounds need worst-case, not typical-case).

Overhead budget: the instrumented binary must stay within ~2x of the
clean build on the corpus benchmarks (bench.sh N-calibration absorbs
small deltas; anything above signals a too-heavy probe). Counter-only
sites should cost <5%.

### 3.2 Sampling (secondary: any native target, incl. C)

`perf`-style time-based sampling of the *clean* binary: zero code
perturbation, function/loop hotness ranking. Coarser than counters
(no per-site trip counts, no value shapes) — use it to *rank*, then
instrument only what matters. No new code required (documents the
workflow, not a feature).

### 3.3 JS target

Two existing hooks, no new runtime needed for v1: `node --prof` on the
emitted program (hot-function ranking, free) and counter injection
through `sh2-namespace.mjs`-adjacent shims for the small set of
high-value sites (loop trips, call arg types). Full JS value
profiling is explicitly out of scope — the C loop is where profiles
pay (native ints, manual memory, branch layout).

### 3.4 What is *not* measured

Raw values (privacy + size), per-iteration traces (I/O bound, perturb
everything), allocations' contents, timing at counter granularity
(noisy, useless). If a consumer needs it and it is not in §2, the
consumer is wrong, not the profiler.

## 4. Profile schema (what the next translation reads)

One JSON per program+workload, versioned with the source hash it was
taken against (staleness, §5.4):

```json
{
  "schema": 1,
  "hash_algo": "fnv1a64",
  "source_hash": "094c3aa5281c5947",
  "options": {"target": "c", "SH2_DUAL_LOOPS": "-", "SH2_LIST_VEC": "-"},
  "loops": [
    {"name": "all_factors:cfor@0", "trips": [3, 3, 46340],
     "execs": 5, "trip_sum": 46346, "trip_max": 46340}
  ],
  "branches": [
    {"name": "all_factors:if0/then@0", "execs": 46340},
    {"name": "all_factors:if0/else@1", "execs": 12}
  ],
  "mags": [
    {"name": "all_factors:mag:i@0", "max_bucket": 2}
  ],
  "lens": [
    {"name": "all_factors:len:factors@0", "len_max": 6, "appends": 6}
  ]
}
```

Site entries are positional per kind (id = array index, stable for
fixed source+flags+transpiler); names carry `{scope}:{kind}@{id}` plus
the arm (`ifK/then`) for grouping. Buckets are bytes-needed (0..7,
aligned with the i8/u8/…/u64 tier edges). `trips` keeps the first 64
executions' counts (first-file-wins on merge truncation); `trip_sum` /
`trip_max` / `execs` are the exact unbounded aggregates.

Phase-1 extensions (designed, not yet emitted): `growth_events` per
array (times the grow path fired), per-call `arg_types` bitmaps, and
reduction-site `execs`.

Rules: maxima only travel upward (a bound is the max ever seen);
type bitmaps only gain bits; counters only add. A profile can never
make a safety claim *smaller* by merging — staleness can only widen.

## 5. How the next translation uses it

### 5.1 Advisory mode (default; always sound)

Profiles *rank and sharpen* decisions the static analyses already
proved safe:

- `Fixed` vs `Vec`: observed `len_max ≤ cap` corroborates (never
  replaces) the proof; where the proof said `None`, an observed max
  does **not** license `Fixed` (see assertive mode) — but it does
  license exact `cap` pre-sizing of the `Vec` (zero regrowth on the
  observed workload, still correct beyond it).
- Widths: observed bucket corroborates a proven bound; where unproven,
  it only tunes (e.g. prefer `u32` storage *with* the existing
  overflow behavior — never to remove a check).
- Aggregates: `reductions.*.execs == 0` across all merged profiles
  confirms a `max`/`min`/`sum` nobody calls — drop its maintenance
  (the static gate stays as backup for unseen code paths).
- Layout: branch counts drive `__builtin_expect` + cold outlining;
  call counts drive inline thresholds.
- Hoist validation: loop-trip histograms confirm a hoisted bound was
  loop-invariant in practice (regression signal if not).

### 5.2 Profile asserts (testing the analyses against reality)

The highest-ROI use, and purely a test-time behavior: compile with
`--profile-checks` (name TBD) to emit `assert()`s comparing static
proofs against runtime truth — `append_hi` vs actual max length,
proven width vs actual magnitude bucket, `None`-trip loops' actual
trip distribution. A firing assert is a *test failure pinpointing a
wrong-or-sloppy proof*, not a user-facing error. This is how the
conservative analyses earn trust over time: every over-approximation
gets a number attached (how much did we over-approximate *in
practice*?).

### 5.3 Assertive mode (opt-in; guarded, never blind)

For decisions static proof *cannot* make (answer `None`), a profile
may license them **iff** a runtime guard preserves correctness on
violation:

- `Fixed` from observed max: emit the fixed array **plus** a
  `len > CAP → fallback` path (growable spill or abort-with-message —
  never silent UB). The guard is the soundness; the profile is just
  the sizing hint that keeps the guard cold.
- Bigint-tier drop from never-observed-bigint: keep an overflow check
  that routes to the GMP path on first violation (one branch per op,
  off the hot path).
- Monomorphic specialization: guard on the type tag, generic fallback
  beside it.
- Rule of thumb: the guard must be cheaper than the thing it replaces
  *and* reviewable in the emitted code (a reader of the C output can
  see exactly what happens on violation). No invisible deopt, no
  traps-that-abort silently.

Without a guard, an assertive use is a miscompile-in-waiting and is
refused the same way an unproven static claim is.

### 5.4 Staleness, versioning, workflow

- Profiles are keyed by source hash + options; a changed program or
  changed flags *invalidates* (warn, do not apply). Merging across
  runs is allowed only for identical keys; across workloads (different
  inputs), merge with max/union semantics (§3.1) and record the
  workload names.
- Workflow: `transpile --profile` → run against a representative
  workload (the corpus tests are a start, not the workload — real
  inputs matter) → `transpile --with-profile` for the deliverable.
  The gates from §7 run on *both* builds (correctness must not depend
  on the profile).
- Profiles live next to the program, never in the repo by default
  (like any build artifact; committing a workload profile is a
  deliberate, reviewed act — it bakes one workload's shape into
  everyone's build).

## 6. Correctness, safety, privacy

- **Profiles never weaken semantics.** Advisory uses only sharpen
  already-sound decisions; assertive uses carry runtime guards; the
  default build (no profile) is always available and always the
  reference for correctness gates.
- **No profile-shaped code without a reader-visible fallback.** If you
  cannot point at the `else` branch in the emitted C, the optimization
  does not ship.
- **Determinism**: instrumentation is counters/histograms only —
  no timing-dependent output, no allocation-order dependence in dumps
  (sorted keys), no raw values. Two runs of the same workload produce
  merge-equivalent profiles (modulo wall-time metrics, which are
  informational).
- **Privacy**: buckets and bitmaps only — magnitudes as ranges, types
  as tags, never strings/keys/values. A profile file must be safe to
  attach to a bug report. (If a future metric needs more, it gets its
  own privacy review first.)
- **No global mutable profiler state in the *transpiler*** (lesson of
  the `static Mutex` era): profile *consumption* is a pure function
  of (program, profile file) → verdicts, unit-testable without I/O.

## 7. Tests and examples (effectiveness + correctness)

Correctness gates are profile-agnostic (same stdout-oracle suites on
clean, instrumented, and profile-built binaries — a profile must
*never* change observable behavior; any divergence is a P0
miscompile, not a tuning issue). On top of that:

- **Profile-assert tests** (§5.2): synthetic programs with known
  answers (`append_hi` must equal the asserted max; widths must match
  the asserted bucket) run under `--profile-checks` — a firing assert
  fails the test. This is the suite that grades the static analyses.
- **Capacity tests**: the t94-style growth cases, run profile-built
  with exact pre-sizing — assert *zero* reallocs (growth_events == 0
  in a second instrumented run) while stdout still matches. The
  optimization proves itself by disappearing from the profile.
- **Guard tests**: workloads crafted to *violate* the profile (feed
  a bigint where none was observed; exceed the observed max) —
  assert correct output *and* guard activation (a guard counter in
  the profile proves the fallback path is real, not dead code).
- **Choice-stability tests**: same program, two workloads with
  different shapes → both profiles valid, both builds correct; the
  merged profile picks the safe (wider) option. Pins the max/union
  merge semantics.
- **Benchmark deltas (informational, never gated)**: bench.sh
  before/after on shipped profile wins, recorded here when measured
  — following the precedent of the hoist (`~7x` on a 30M-iteration
  microbench) and the t86 loop (`5.9 s` vs `8.3 s` native). Numbers
  inform; gates decide.

## 8. Open questions / non-goals

1. **Who owns representative workloads?** The corpus tests are
   small by design; real inputs live with users. Without a story for
   obtaining them, profiles stay toy-sized. (No telemetry without an
   explicit, separate, opt-in decision — out of scope here.)
2. **Granularity of invalidation**: whole-program hash invalidation
   is coarse (one-line change discards everything). Function-level
   profiles with call-graph-aware invalidation is the obvious next
   step — not designed here.
3. **JIT-style tiering**: re-transpile hot loops at runtime based on
   live counters (a `--profile` binary that recompiles itself)? Far
   future; the ahead-of-time loop in §5 is the whole proposal.
4. **Cross-backend profiles**: a C-measured profile informing the JS
   build (magnitudes transfer; branch counts roughly transfer;
   allocation counts do not). Schema-compatible, semantics TBD.
5. **Sampling-based value profiles**: time-based sampling cannot see
   values — only the instrumented path gives §2.1. That asymmetry is
   permanent; plan around it.
6. **Non-goal**: profile-guided *parsing*/frontend choices (all of
   this is backend lowering), and any use of profiles in correctness
   gates (gates stay profile-blind by design).

## 9. Implementation design

How to build it, concretely enough to start. C target first (where
profiles pay: native ints, manual memory, branch layout); JS second
and smaller; the pieces are ordered so each lands independently
useful (rollout in §9.5).

### 9.1 Emission: site IDs and counter shapes (C)

Site IDs are assigned in a render pre-pass that walks statements in
order (`function : construct @ index`, e.g. `all_factors:while@3`)
— *after* all duplicating transforms (unrolling, versioning). This
ordering is load-bearing: IDs assigned pre-transform go ambiguous
when a body is duplicated (which copy is `while@3`?), so stability
is defined as *same source + same flags + same transpiler version →
same IDs*, with the transpiler version in the staleness key (§9.3).
Deterministic traversal only (sorted maps — the existing
byte-identical-output discipline already requires this).

Storage is fixed-size statics (site count known after the pre-pass):

```c
static uint64_t _prof_trip_sum[NSITES];
static uint64_t _prof_trip_max[NSITES];
static uint64_t _prof_taken[NSITES];
static uint64_t _prof_nottaken[NSITES];
static uint8_t  _prof_mag[NSITES];   /* max magnitude bucket seen */
static const char *_prof_names[NSITES] = { /* "all_factors:while@3", … */ };
```

Per-site shapes (each chosen to keep probe cost at a few
instructions, no calls, no allocation):

- **Loop trips**: never per-iteration. Native loops already count;
  `while` loops get one `size_t _tripN = 0` + `++` per iteration
  (~1 cycle vs the body), and at loop *exit* a single update of
  sum/max. Trip distributions come from per-execution records, not
  sampling.
- **Branches**: branchless coercion, never an added branch:
  `_prof_taken[N] += (c != 0); _prof_nottaken[N] += (c == 0);`
  (adding a real branch to measure branches would perturb exactly
  what is measured).
- **Magnitude buckets**: one intrinsic, no chain: `uint64_t m =
  v < 0 ? 0ULL - (uint64_t)v : (uint64_t)v;` (defined for `INT64_MIN`,
  unlike negation), then bucket `63 - __builtin_clzll(m)` clamped to
  8 buckets that align with the i8/u8/…/u64 tier edges. Max-bucket
  per site (`if (b > _prof_mag[N]) _prof_mag[N] = b;`).
- **String lengths**: measured only at materialization points
  (append, return, whole-string assign) — never inside scan loops,
  where even `strlen` would dominate. Placement rule, not a tunable.
- **Call arg types**: *not collected for C* — C values are statically
  typed, so there is nothing dynamic to observe (magnitudes, yes;
  types, no). The type matrix (§2.2) is a JS-side instrument.

### 9.2 Runtime dump, merge tool, consumption API

**Dump** (`atexit`, C): one handler writes `<prog>.profile.json`
(default beside the binary; overridable via an explicit out path —
never CWD-sniffing). Hand-rolled minimal JSON writer (~50 lines, no
dependency): integers, fixed key order (sorted — merge-equivalence
must not depend on run order), schema version + source hash header.
Fork guard: record the start pid, dump only on match (children that
`fork`/`exec` would otherwise clobber or duplicate the file); per-pid
suffixed files plus merge support is the documented extension, not
v1. No dump on crash/SIGKILL (rerun; long workloads do not get
periodic dumps in v1 — keep the failure semantics boring).

**Merge** (offline Python script, stdlib `json` only — e.g.
`harness/profile-merge.py`): counters add, maxima take max, type
bitmaps OR, string sets union. Merge is *order-independent by
construction* (every operator commutes), which is asserted by unit
test, not by convention. Schema-version mismatch → refuse (never
coerce across versions); source-hash mismatch → refuse for assertive
use, warn for advisory (§5.4).

**Staleness key**: hash of (normalized shIR + target + opt flags +
transpiler version). Normalized shIR (not source text) so formatting
churn doesn't invalidate; transpiler version included because site
IDs and lowering shapes move with it.

**Consumption API** (the only way verdicts enter lowering): an
optional loaded profile behind small query functions —
`profile_max_len(name)`, `profile_max_bucket(name)`,
`profile_trips(site)`, `profile_taken(site)` — each returning
`None` when absent. Every consumer keeps its static-only path for
`None`, which is therefore *byte-identical to today* (the A/B
firewall for the whole feature: `None`-path output never changes).
New decisions read the query, never the file — unit-testable without
I/O, and no global profiler state in the transpiler (the `static
Mutex` lesson stands).

### 9.3 JS side, harness, testing the profiler, rollout

**JS instrumentation stays small on purpose**: loop-trip and call
counts via emitter-gated inline increments (only in `--profile`
mode), arg-type tags through `sh2-namespace`-adjacent shims, timing
via `node --prof` (free, no code). Full JS value profiling is out of
scope — the C loop is where native ints and manual memory make
profiles pay; JS keeps ranking (sampling) + the few counters that
feed its own decisions (call-type monomorphism).

**Harness/workflow**: one script drives the loop — build
instrumented → run against a representative workload → merge →
report (`harness/profile.sh`, mirroring `bench.sh` conventions:
`set -uo pipefail`, explicit env knobs, no hidden state). Workloads
are named and versioned alongside the profile (a profile without a
recorded workload is a number without provenance — mergeable, but
flagged). Gates run three builds where it matters — clean
(reference), instrumented, profile-built — with *identical* expected
stdout on all three (a profile must never change observable
behavior; any divergence is a P0 miscompile, §7).

**Testing the profiler itself** (distinct from testing *with*
profiles, §7):

- Site-ID determinism: same program twice → identical IDs; plus a
  transform-churn test (unroll/version on/off must not alias two
  sites to one ID — the post-transform assignment exists for this).
- Merge math: unit tests pin add/max/OR/union semantics and
  order-independence; schema validation rejects bad versions and
  mismatched hashes (both directions: assertive refuses, advisory
  warns).
- Golden profiles: a known program's instrumented run produces the
  expected JSON shape (magnitudes in the right buckets, trips exact,
  no raw values anywhere — assert the absence too).
- Overhead budget is *monitored, never gated*: bench.sh deltas are
  recorded per release, but timing is not an assertion (repo testing
  policy — flaky by construction). A blowout is investigated, not
  asserted.

**Rollout (each phase independently useful, each gated before the
next)**: Phase 0 — schema + merge tool + four instrumented site
classes (loop trips, branch arms, value magnitudes, array lengths) +
golden tests (built 2026-09-11: `tests/profile_e2e.rs`,
`harness/profile-merge.py`). Phase 1 — growth events + call types +
profile asserts for one analysis (`append_hi`). Phase 2 — first
consumption (exact cap pre-sizing; zero-realloc proof per §7).
Phase 3 — assertive flag + widen guards + guard-activation tests.

**Explicitly not built**: a profiling daemon, a profile database,
auto-tuning search, telemetry upload, in-transpiler global profiler
state, or JS value profiling. If a proposal needs any of these, it
is a different document.

