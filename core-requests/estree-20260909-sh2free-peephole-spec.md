# Peephole spec: sh2-free fast-path loops (t86_factor target shape)

Date: 2026-09-09. From: t86 `-O3` JS inspection + measurement.
Owner: estree worker (renderer + in-flight store-only-native feature —
this spec is written to LAND ON that feature, not duplicate it).

## Measurement (node, t86_factor corpus: 67M-iteration divisibility loop)

- Original `-O3` estree output (sh2.imod/idiv/setArrayAppend/sortedIntJoin):
  ~1150 ms.
- Hand-written sh2-free Number loop, byte-identical stdout: ~660 ms.
- Gap: **~1.7x**, all in per-iteration sh2 dispatch + store-keyed
  array traffic. (For reference, native python3 is ~8.3 s — the
  transpiled output already wins; this is about closing the remaining
  interpreter-overhead gap, not about beating python.)
- 2026-09-09 update: the hot loop no longer dispatches `imod` (zero-cmp
  native `%` shipped below); best-of-5 ~1050 ms vs ~1040–1150 before and
  ~650 hand-native. Remaining per-iteration costs are the `Number(p1)`
  coercion, `? 1 : 0` tests (since removed — see below) and loop
  bookkeeping; the rest is store/coercion traffic owned by the
  store-only-native feature.

## Target shape (proven byte-identical to python3 on t86)

```js
function all_factors(p1) {
  const n = Number(p1) || 0;
  const limit = Math.trunc(Math.sqrt(Number(p1) || 0)) + 1;
  const factors = [];
  for (let i = 1; i < limit; i++) {
    if (n % i === 0) {
      factors.push(i);
      factors.push(Math.trunc(n / i));
    }
  }
  return [...new Set(factors)].sort((a, b) => a - b).join(', ');
}
```

## Fold table (each row is independently shippable, in this order)

1. **`__fl0` setVar/getVar roundtrip** (once per call, ~zero measurable
   gain — do it for code health, not speed):
   `sh2.setVar("__fl0", E); ... Number(sh2.vars.__fl0 ?? ...) || 0`
   → `const __fl0v = E` when the temp is written once with a call-free
   arith RHS and read numerically only. Fires on t86/t88/t89 identically
   at Og/O3/O4 (the shape is level-independent).
2. **Native array for append-only-then-join arrays**: `setArray("f", [])`
   + `setArrayAppend` + terminal `sortedIntJoin`/`listJoin` (see
   companion request `py-sh-go-20260909-list-repr-pipeline.md` for the
   ordered-join half) → `const f = []` + `push` + inlined sort/dedup/join.
   This is ~80% of the measured gap. It is the store-only-native
   feature's core case — implement THERE (the analyses already exist:
   `analyze_store_only`, LIFTED sets), not as a competing peephole.
3. **Native `%`/`Math.trunc` for proven-safe div/mod**: already exists
   (`arith_native` + divisor proofs); no work needed beyond keeping it
   firing as more vars lift natively via (2).

## SHIPPED since this spec was written (same author, same session)

- **Status-record dedup** (`sh2._g = (sh2._g = E, …), …` → single
  record): the `&&`/`||` chain-link lowering re-recorded the identical
  status; t28 17→9 calls, corpus `_g` 42→36, exit codes verified.
- **Zero-compare native `%`** (`X == 0` with nonzero-proven divisor):
  the gate reused the abort-capable detector, so proven-nonzero divisors
  defeated it while `==` poison forced the helper (triple lock-out with
  `may_bigint`). t86's hot loop is now native `%` (67M `imod`
  dispatches gone); pure-Number restriction keeps it op-identical to the
  helper (BigInt trees keep `imod`, t89 verified).
- **Native single-pattern `caseMatch`** (`h*`→startsWith etc.): per-eval
  arg-flatten + expandWord + glob-parse gone (t68's 2 calls).
- **Taint refinement for lifted-Number vars**: attempted, measured zero
  effect (every helper site still taints via its other side), REVERTED
  rather than ship dead code (note in `arith_has_var_read`).
- **Test-position `? 1 : 0` removal**: measured 307 ms → 295 ms over 20M
  iterations (~4%, V8 folds it anyway). SHIPPED anyway for statement
  tests (`If`/`While`: airtight truthiness proof, confined to two
  emission sites, value positions untouched) — the user asked for the
  ugly wrappers gone.

## Explicitly NOT recommended (measured, rejected)

- Hoisting loop-invariant `BigInt(p1 || 0)` out of bigint loops: measured
  238 ms → 226 ms over 2M iterations (~5%, mostly V8 already CSE-ing the
  same-value construction). Not worth emitter LICM complexity. Skip.
- `asIntN(64, …)` removal on the BigInt arm: the wrap is the documented
  i64 semantic (bash `$(( ))`); removing it changes truncation behavior.
  Only revisit alongside a documented arbitrary-precision-vs-i64 decision
  (see t89: the DIVIDEND is now arbitrary-precision via `BigInt(p1 || 0)`;
  the divisor wrap is harmless for in-i64 divisors but is a second cap
  for over-i64 loop counters — no corpus case hits it today).

## SHIPPED 2026-09-09: zero-compare native `%` for nonzero-proven divisors

The `X == 0` gate (`arith_is_zero_cmp`) reused the abort-capable detector
(`arith_has_div_mod`, which excludes proven-nonzero divisors), so a
proven-nonzero divisor DEFEATED the gate while the `==` poison forced the
helper — a triple lock-out (`may_bigint` taint blocks the third path too).
t86's 67M-iteration `n % i == 0` (divisor `i`-in-`1..` proven nonzero) paid
67M `imod` dispatches for a loop that cannot abort. The gate now also
fires on syntactic `%`/`/` presence with proven-nonzero divisors, restricted
to pure-Number trees (no Cast, no BigInt-homed/slotted/typed reads —
native `%` is then op-identical to the helper's Number path, NaN `== 0`
false = bash abort→false, minus dispatch). t86's hot loop is now native
`%` (67M `imod` dispatches structurally eliminated — no helper call
remains on the per-iteration path; rare-path `idiv` stays via
`may_bigint`). Wall-clock delta is below measurement noise on a loaded
box (best-of-5 ~1050 ms vs ~1040–1150 ms before; hand-native is ~650 ms —
the rest is store/coercion traffic owned by the store-only-native
feature). BigInt-touching trees keep the exact helper (t89 verified).
`!= 0` and poison-carrying shapes are untouched.

## ACCEPTANCE: t86's five lines (for the store-only-native feature)

The exact remaining `sh2.` traffic in t86 `-O3`, what each must become,
and the soundness condition. Verify with:
`./2js t86` (or py-sh-go `--shir` + `otranspilerl-cli -O3 --target js`),
then `diff <(node out.js) <(python3 t86_factor.py)` and the 67M-loop timer.

1. `sh2.setArray("factors", []);` → `const factors = [];`
   Condition: every static ref to the name in scope is an append or the
   terminal join below (no `getVar`/subscript/dynamic/computed refs —
   the `any_dynamic` verdict already proves this), single function scope.
2. `sh2.setArrayAppend("factors", [i]);` → `factors.push(i);`
   (multi-element appends → `push(...es)`). Same condition as (1).
3. `sh2.setVar("__fl0", E); … Number(sh2.vars.__fl0 ?? …) || 0`
   → `const __fl0v = E;` Condition: single setVar write with call-free
   arith RHS + single numeric read + no other refs (a use-counted temp;
   `call_free_expr` proves purity so inlining cannot duplicate effects).
4. `sh2.sortedIntJoin("factors")` → inline
   `[...new Set(f)].sort((a,b)=>a-b).join(", ")` — ONLY when every
   appended element is provably Number (Num literals, clean lifted-nums,
   `Math.trunc`/idiv-of-proven — NOT bare `sh2.idiv(...)` returns, which
   are BigInt-or-Number by input; `a-b` throws on BigInt). Otherwise keep
   the helper (t89's exactness depends on it).
5. `sh2.idiv(Number(p1) || 0, i)` (rare path) → `Math.trunc(... / ...)` —
   ONLY when the dividend is param-range-proven i53 (else the `Number()`
   coercion itself rounds; the helper is the only exact channel for
   unproven ranges).

(1)+(2) are ~all of the remaining per-iteration cost; (4) is once per
call; (3)+(5) are once per call / rare-path. Reference native shape
(byte-identical stdout, ~690 ms best-of-5): `/tmp/t86_native2.js`.

## DELIVERED 2026-09-09: native-array migration (item 2 above)

Shipped as a fail-closed post-emission ESTree pass (`array_migrate_program`,
`sh2perl/src/shir.rs`, runs last after hoisting), NOT in store-only-native:
it fires on the exact CLOSED shapes (empty init + inert appends + terminal
joins) with whole-program ref-closure, and goes inert the moment the IR
feature lifts the same array first (no setArray calls left to match) or any
unlisted shape appears. The two approaches are complementary layers, not
competitors. Kill-switch `SH2_NO_ARRAY_MIGRATE=1` restores the store path.

Delivered shapes (v2): `setArray(N,[es])` → top-placed `const N=[es]` (empty OR all-pure-and-inert elements; purity proves no effects shift earlier, inertness proves no expansion divergence);
`setArrayAppend(N,es)` → `N.push(...es)` in place; `sortedIntJoin` /
`sortedBigintJoin` → op-for-op IIFE transliterations (int dedups ITEMS,
bigint dedups VALS — the helpers differ, replicated exactly). Refuses:
assoc (assocSet/declare-A/isAssoc), indexed writes/deletes, dynamics,
eval/fnCall, subshell/redirect, direct `sh2.arrays` access, shadowing,
cross-scope refs, non-inert elements, getVar reads and DYNAMIC-key
arrayIndex reads (safe misses, stay store-side). Literal-key
`arrayIndex(N,k)` → bounds-checked native read (negative wraps,
out-of-range `""` — the runtime's exact decision); `arrayLen(N)` →
`N.length`; `arrayItems(N)`/`@`/`*` → `[...N]` (dense-only, so
`.length`/spread are exact). Indexed WRITES (`setVar("N[i]")`,
`N[i]=…`) still refuse (holes/overwrites).

Element inertness (the runtime `expandWord`s every appended scalar):
Num, inert-Str (no `$`/backtick/`\`), Number/Math/idiv/imod/arithEval
results (canonical numerics or sanitized strings — arithEval never throws),
loop counters (Num/inert-Str/IncDec-only writes incl. cstyle-header and
arith/builtin string writes, shadow-aware), `sh2.vars.V` slot reads
(counter-proven), `??` with dead fallback (leading-prefix or dominating
cstyle init). 10 unit tests (`lowering_shape_tests::array_*`), all green.

Verified: t89 migrates (`const factors`+push) and matches python3 exactly;
t86/t88 migrate identically but currently print `[]` on BOTH paths from the
concurrent `_i_sqrt_nv` breakage (see triage-20260909-isqrt-native-bound —
kill-switch proof, not array-caused). Gates: sh 88/88, pl 68/68, py 85/87
(2 concurrent). Lib: 10/10 array tests green; 9 failures elsewhere are
concurrent (kill-switch proof — last-exit, dead-flags, assignment, range).
Items (3) temp-fold and (5) rare-idiv are now SHIPPED as post-emission
ESTree transforms (same pass family as the array migration):
- **Temp-roundtrip fold** (`fold_temp_roundtrips`): `setVar("T", E)` +
  `Tv = (Number(sh2.vars.T ?? (process.env.T ?? "")) || 0) + 0` →
  `Tv = (Number(E) || 0) + 0` (setVar + store read gone). Sound when T
  is written once and read once and E is pure (Math/Number/arith only).
- **`idiv` peephole** (`peephole_idiv`): `sh2.idiv(A, B)` →
  `Math.trunc(A / B)` when A and B are provably Numbers and B provably
  non-zero (the helper throws on zero divisor; `Math.trunc` would yield
  NaN/Infinity). Number-proving: `Number`/`parseInt`/`parseFloat` coerce
  anything, `Math.*` returns a Number, positive-literal loop counters are
  non-zero.
Both are fail-closed (multi-read/impure temps and unknown divisors keep
store/helper). 5 new unit tests (`temp_fold_*`, `idiv_*`). Item (4)
superseded by the exact IIFE transliteration.

**`sortedJoinMerge` pair migration** (the split-set worker's remaining
piece, finished here): `sortedJoinMerge(A, B)` → inline merge IIFE over
two native arrays (sort small as Numbers, big as BigInts, linear merge,
dedup — op-for-op identical to the runtime helper). Both arrays migrate
together (remove both setArrays, insert both consts, rewrite appends,
then inline the merge — both native before the IIFE references them).
Fail-closed: a non-migratable partner refuses the pair. t86/t88 are now
FULLY sh2-free (no `sh2.` calls in the hot function). 2 new unit tests
(`array_migrates_join_merge_pair`, `array_refuses_join_merge_partner_not_migratable`).

## DELIVERED 2026-09-10: interprocedural param-range proof (drop the `|| 0`)

The hoisted `const __p1n = Number(p1) || 0` kept a per-call coercion the
loop then reuses: `Number(p1)` re-parses a string param on all 67M
iterations. Shipped as a fail-closed post-emission ESTree pass
(`strip_proven_nonzero_guard`, `sh2perl/src/shir.rs`, runs in
`shir_to_estree` immediately after the param-read hoist that emits the
guards): when EVERY static direct call site passes a nonzero-number
literal for a position, the guard is dead — a nonzero number is truthy,
so `Number(p) || 0` ≡ `Number(p)` exactly — and the const init drops the
`|| 0`. t86: `const __p1n = Number(p1);`, byte-exact vs python3.

Proof shape (pure, no compilation statics): a read-only two-phase walk
mirroring the hoist's own coverage collects fn definitions (all three
shapes: `FunctionDeclaration`, `N = arrow`, `let N = arrow`),
every static direct call's arg-lists, and escapes (any non-callee value
use of the name, any string/template text equal to the name for
`fnCall`-style dynamic dispatch, any shadowing binding, any rebinding
to a non-function, opaque destructuring bindings, redefinition with
different params). A param is proven only with ≥1 call and a
nonzero-number literal (`hoist_nonzero_number_literal`: numeric ≠ 0,
`±` unary on numeric ≠ 0, narrow digit strings `"10"`/`"-3"`/`"4.5"` —
hex/exponent/whitespace strings refuse, sound-incomplete) at that
position in ALL calls. Short calls (missing position → `undefined` →
NaN) refuse. The rewrite only touches the exact hoist-emitted
`const __pNn = Number(p) || 0` shape under the proven function's own
context (nested functions push their own); `BigInt(p || 0)` guards are
deliberately out of scope (empty-string throws vs coerces — kept).
`--library` disables the pass (`SH2_LIBRARY`, set/unset around render
in `otranspilerl/src/lib.rs`): exported functions accept external
callers, so no range is provable — library output keeps `|| 0`
(verified), and the `--help` / `apply_library` docs were corrected from
the old "params specialize to call-site ranges" wording to guards-kept.
7 new unit tests (`nonzero_literal_shapes`, `strip_drops_guard_*`,
`strip_keeps_guard_{zero_call,missing_arg,library,escaped_or_rebound}`,
`strip_leaves_bigint_guard`), all green. Gates with the pass active:
py 90/90, pl 68/68, go 118/118; lib 6 unrelated `estree::` failures are
concurrent (see triage-estree-20260910-paramrange-adjacent-reds).

Robustness note (2026-09-10, same session): the param-lift emission
changed under this pass (hoisted `function f(p1)` → `f = (p1) =>` with
a `let f = null` prologue preamble). The pass handles all three define
shapes, but the prologue preamble initially shadow-escaped every proof
(`let f = null` binds the name). Fix: `let N;` / `let N = null`
declarators are declaration noise and no longer count as shadowing
bindings — null carries no value into any call and every syntactic call
is still recorded, so attribution stands; real value bindings
(`let N = 5`, params, catch params) still escape. Pinned by
`strip_drops_guard_null_prologue` (+ `strip_drops_guard_function_declaration`
for the declaration shape).
## FIXED 2026-09-10: `--library` exports for all define shapes

`apply_library` only exported `__fn_`-prefixed defines, so plain-named
functions (`const f = arrow`, `function f`, `f = arrow` onto a prologue
`let` — the last even dropped as driver) produced libraries importing as
`{}`. Defines are now detected by SHAPE (any declarator/`FunctionDeclaration`/
assignment whose value is an arrow/function), legacy `__fn_x` still exports
stripped. 4 unit tests; live `t86.lib.mjs` imports `{ all_factors }`,
returns correct factors, keeps `Number(p1) || 0`.
