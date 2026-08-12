# BinInt64 — BigInt64Array arithmetic vs plain BigInt vs regular float64

Benchmark of BigInt arithmetic in JavaScript: **plain `BigInt` variables** vs **operands
directly loaded from a `BigInt64Array` with the result immediately stored back**, plus a
comparison against **regular float arithmetic** (plain `Number` and `Float64Array`).

Environment: **Node v24.18.0, V8 13.6.233.17-node.50, linux x64**. Medians of 9 trials,
per-case calibrated iteration counts (~250 ms/trial), warmup before timing. All loops were
verified to run every iteration (linear scaling with `n`, checked with two clocks) and to
produce bit-exact results (checked against a mod-2^64 reference). Single-threaded.

## TL;DR

| op | plain BigInt | BigInt64Array | plain Number | Float64Array |
|----|-------------:|--------------:|-------------:|-------------:|
| add | 5.3 ns | **1.0 ns** | **0.8 ns** | 1.9 ns |
| mul | 2.5 ns | **1.4 ns** | **0.8 ns** | 1.9 ns |
| div | 12.8 ns | 9.1 ns | **4.2 ns** | **5.2 ns** |

- **BigInt64Array load→compute→store is ~5× faster than plain BigInt** for add (1.0 vs 5.3 ns),
  and comes with **free mod-2^64 wrap-around**. V8 lowers the array element ops to native
  int64 machine instructions; the value never becomes a heap-allocated `BigInt` object.
  Plain `BigInt` arithmetic allocates a new immutable `BigInt` per operation.
- The fast path **only survives while values stay inside the array**. Materializing a
  `BigInt` from an element read costs ~4–6 ns and turns the rest into normal (allocating)
  BigInt arithmetic. If the result must be read back as a `BigInt` every iteration, the
  advantage mostly disappears (add 5.4 vs 5.3 ns; div 13.4 vs 12.8 — the array even loses
  for div).
- **Regular float is faster still** for plain-variable arithmetic (add 0.8 ns, div 4.2 ns),
  and there is **no boundary cost** (Numbers are values, not heap objects). But for
  in-array add/mul, the **BigInt64Array int64 path beats Float64Array** (1.0 vs 1.9 ns);
  floats only win decisively at **division** (5.2 vs 9.1 ns, hardware `divsd`).
- `BigInt64Array` is capped at signed 64-bit; arbitrary precision is plain-`BigInt` only
  (a 512-bit add measured 46–47 ns).
- Signedness is chosen by array type, not per element: `BigInt64Array` is i64,
  `BigUint64Array` is u64 (identical bit storage). **Both get the native
  element arithmetic — the early "i64-only fast path" claim was a
  same-process measurement artifact (retracted in §6)**.
- **u32 is fast**: it shares the machine-int32 domain with i32 (`|0`, `Math.imul`, `>>>`);
  only div/mod/cmp/shift and conversions to BigInt/print interpret the sign bit (§7).
  Contrast: at 64 bits, `BigUint64Array` is as fast as `BigInt64Array`
  for load→compute→store (§6); at 32 bits, `Uint32Array` is as fast as `Int32Array`.

## 1. Scenarios benchmarked

All loops use the same shapes and values in the same magnitude class (~2^60).

```
plain BigInt   : let t = 0n; for (...) t = t + A;            // variables only
BigInt64Array  : arr[2] = arr[2] + arr[0];                    // load from array, store back
*Obs           : same + c ^= arr[2] (result read back as BigInt every iteration)
plain Number   : let t = 0; for (...) t = t + FA;             // regular float arithmetic
Float64Array   : arr[2] = arr[2] + arr[0];                    // (f64 typed array)
Float32Array   : same but f32 (curiosity: V8 converts on load/store)
```

Value notes:
- `BigInt64Array` stores signed 64-bit and **wraps mod 2^64** on store. The plain-BigInt
  equivalent ("keep the accumulator in range") is `t = (t + A) & (2^64n - 1n)` — measured
  separately, because BigInt bitwise ops are not free.
- Plain `BigInt` values that grow past 2^64 get a second limb; measured both (growing and
  masked) because BigInt cost depends on magnitude.
- Floats need no range bound for speed, so float mul is measured unbounded (overflows to
  ±Infinity after ~34 iterations — same per-op cost). The "bounded float" idiom
  (`% 1e18`) is reported separately: fmod costs ~8 ns, just like `& mask` costs ~28 ns on
  BigInt.

## 2. Results (ns/op, lower is better)

### 2a. BigInt: plain variables vs BigInt64Array (the original question)

| scenario | ns/op |
|---|---:|
| plain BigInt add, `t += 5n` (stays 1 limb) | 5.27 |
| plain BigInt add, `t += ~2^60` (grows to 2 limbs) | 21.50 |
| plain BigInt add + manual 64-bit wrap, `& (2^64-1)` | 32.94 |
| **BigInt64Array add, `arr[2] = arr[2] + arr[0]`** | **1.01** |
| BigInt64Array add + read back every iteration | 5.41 |
| plain BigInt mul + `& mask` | 2.46 |
| **BigInt64Array mul, `arr[2] = arr[2] * arr[0]`** | **1.36** |
| BigInt64Array mul + read back | 4.00 |
| plain BigInt div | 12.81 |
| **BigInt64Array div, `arr[2] = (arr[2]+arr[0]) / arr[1]`** | **9.12** |
| BigInt64Array div + read back | 13.39 |
| plain BigInt add, 512-bit operands (array cannot) | ~47 |

### 2b. Regular float: plain Number vs Float64Array

| scenario | ns/op |
|---|---:|
| plain Number add | 0.82 |
| plain Number mul (unbounded) | 0.81 |
| plain Number mul (bounded `% 1e18`, fmod) | 8.66 |
| plain Number div | 4.15 |
| Float64Array add (load+store) | 1.86 |
| Float64Array mul (load+store) | 1.89 |
| Float64Array div (load+store) | 5.15 |
| Float32Array add (load+store) | 3.77 |
| `t += f64arr[0]` (load element into Number — boundary crossing) | 0.81 |

### 2c. Head-to-head (int vs float, same loop shape)

| op | plain BigInt | BigInt64Array | plain Number | Float64Array | who wins |
|----|---:|---:|---:|---:|---|
| add | 5.27 | 1.01 | 0.82 | 1.86 | Number ≈ BigInt64Array > Float64Array > BigInt |
| mul | 2.46 | 1.36 | 0.81 | 1.89 | Number > BigInt64Array > Float64Array > BigInt |
| div | 12.81 | 9.12 | 4.15 | 5.15 | Number > Float64Array > BigInt64Array > BigInt |

Relative: plain Number add is **6.4×** faster than plain BigInt add; BigInt64Array add is
**1.8× faster** than Float64Array add; Float64Array div is **1.8×** faster than
BigInt64Array div and **2.5×** faster than plain BigInt div.

## 3. Why BigInt64Array beats plain BigInt

1. **Native int64 lowering.** While a value lives only in `BigInt64Array` elements, V8 can
   keep it as a raw 64-bit integer in a register and emit machine `add`/`imul`/`idiv`
   instructions. Observed ~1.0–1.4 ns/op is roughly one memory-to-memory integer op — no
   `BigInt` object is ever allocated. (`BigUint64Array` gets the same path — see §6.
2. **Free wrap-around.** Storing wraps mod 2^64 natively, so "accumulator stays in range"
   costs nothing. Doing the same with plain BigInt (`& (2^64-1)`) costs ~28 ns extra
   (32.94 vs 5.27 for add) because BigInt bitwise ops go through slow builtins.
3. **Plain BigInt allocates per op.** Every `+`/`*`/`/` produces a new immutable heap
   object; cost grows with limb count (5.3 ns at 1 limb → 21.5 ns once values exceed 2^64).

## 4. The boundary is the enemy (BigInt side)

| crossing | measured cost |
|---|---|
| element → BigInt variable (`t += arr[0]`) | ~31.9 ns vs 25.5 ns for the same plain computation ⇒ ~6 ns for materializing the BigInt object |
| BigInt variable → element (truncation/conversion on store) | small on top of the BigInt-side op |
| result read back as BigInt every iteration | erases most of the win (see 2a *Obs rows) |

Float has **no such boundary**: `t += f64arr[0]` measured 0.81 ns, identical to plain
add — Numbers are values, loads/stores are plain copies.

## 5. Float semantics vs int64 semantics (why you might pick either)

- **float64**: 53-bit mantissa (values near 2^60 are already inexact), gradual precision
  loss, overflow → ±Infinity, NaN. Fastest arithmetic; `Float32Array` is *slower* than
  `Float64Array` for this pattern (3.77 vs 1.86 ns) due to f32↔f64 conversions.
- **BigInt64Array**: exact integers in [-2^63, 2^63-1], deterministic mod-2^64 wrap, no
  precision loss. In-array add/mul is even faster than Float64Array.
- **plain BigInt**: only option for arbitrary precision (512-bit add ≈ 46 ns), slowest for
  small values.

## 6. i64 vs u64: BigUint64Array

You cannot choose signedness per element: `BigInt64Array` is always signed i64 (loads in
[-2^63, 2^63-1]) and `BigUint64Array` is always unsigned u64 (loads in [0, 2^64-1]).
Both store identical 8-byte two's-complement bit patterns and wrap mod 2^64 on store
(any BigInt accepted, no throw; storing a Number throws `TypeError`). The same
`ArrayBuffer` can be read through either view — only the interpretation differs:

```js
const buf = new ArrayBuffer(8);
const i = new BigInt64Array(buf), u = new BigUint64Array(buf);
u[0] = 2n ** 63n + 5n;
i[0] // -9223372036854775803n   (same bits, signed)
u[0] //  9223372036854775813n   (unsigned)
```

But the choice has a large performance consequence — or so the FIRST version of this benchmark claimed (a 2–10× BigUint64Array penalty). **That was a measurement artifact**: running i64 and u64 kernels of IDENTICAL shape in ONE process makes V8's optimized-code sharing mis-specialize whichever kernel did not get the first optimization, dropping it to the BigInt-materialization path. Real programs have one array type per hot loop, so the correct methodology is ONE CASE PER PROCESS. Measured that way (`bench_u64_vs_i64.mjs <case>`, best-of-25 trials):

| op | BigInt64Array | BigUint64Array | u64 on BigInt64Array (asUintN on read) |
|----|--------------:|---------------:|--------------------------------------:|
| add (load+store) | 1.8 ns | 1.9 ns | 2.1 ns |
| mul (load+store) | 2.4 ns | 2.6 ns | — (bit-identical to add) |
| add + read back BigInt | ~15–60 ns | ~30–50 ns | 50 ns |
| div (load+store) | — | ~130–175 ns | ~125–170 ns |

(medians and best-of wobble with box load; the RMW rows are stable — both array types get V8's native int64 element arithmetic; the 10× §3/i64-only claim is RETRACTED.)

Practical implications (updated):

- **BigUint64Array is as fast as BigInt64Array for load→compute→store arithmetic** — use it directly for u64; the asUintN-reinterpret trick buys nothing.
- u64-on-BigInt64Array IS bit-exact for add/sub/mul/and/or/xor (verified — mod-2^64 arithmetic is signedness-agnostic), and reads reinterpret with `BigInt.asUintN(64, x)`; it only makes sense if you need i64/u64 *mixed* in one array (both interpretations of the same bits).
- **Readback is the real cost**: materializing the BigInt per iteration is 15–60 ns regardless of array type — the reason the transpiler's general i64 expressions use BigInt values, not array element churn.
- Division is BigInt-bound either way (~130–175 ns) — no native u64 path.

## 7. u32: the fast machine-int lane (C `unsigned int`)

**Is there a fast u32 implementation in JS? Yes.** JS has no u32 type: a u32 value
≥ 2^31 is *stored as a negative i32* (identical bits), so the whole u32 lane lives in
the machine-int32 domain using the asm.js/emscripten idioms (`u32bench.mjs`, each
idiom verified bit-exact against BigInt references):

| op | idiom | ns/op |
|---|---|---:|
| add/sub (wrap mod 2^32) | `(a + b) \| 0` | 0.5 in-range / 4.6–5.2 (≥ 2^31) |
| mul | `Math.imul(a, b)` | 0.85 |
| shifts | `<<`, `>>>` | 0.7 |
| comparison | `(a >>> 0) < (b >>> 0)` | 1.9–3.5 |
| div / mod | `((a >>> 0) / (b >>> 0)) \| 0` | 6.8–7.8 |

(measured while the workspace's background loops were running — absolutes are upper
bounds, ratios hold)

Findings:

- **u32 div/mod is not the problem it's reputed to be**: the naive `>>>0` form costs the
  same as signed division (~7 ns). The classic “branch when operands < 2^31” guard is
  *slower* (9.2 ns) — skip it.
- **The naive forms beat the classic tricks on V8 13.6**: `(a >>> 0) < (b >>> 0)`
  (1.9 ns) beats the XOR-0x80000000 trick (2.8 ns).
- **One real cost — the Smi boundary**: `(a + b) | 0` with the sum overflowing Smi
  range materializes a HeapNumber: ~5 ns vs ~0.5 ns in-range. Mul/shift/compare/div
  never allocate (int32-native ops).

### i32 and u32 are the same implementation — except at interpretation points

The identity holds only *inside* the machine-int32 domain. The sign bit is read
whenever the value leaves it (conversion to Number, promotion, storage, or a
sign-interpreting op):

| crossing | i32 | u32 | ns/op |
|---|---|---|---:|
| → Number / string | `x` (identity) | `x >>> 0` | 1.7 / 1.8 (≈free, fused) |
| → BigInt (C `(long long)` cast) | `BigInt(x)` sign-extend | `BigInt(x >>> 0)` zero-extend | 14.5 / 10.9 |
| → typed storage | `Int32Array` | `Uint32Array` | 1.83 / 1.84 (no penalty) |
| `/` `%` `<` `>` `>>` | signed forms | `>>>0` / `>>>` forms | 2–8 |

So for the C backend: `int` and `unsigned int` share one `|0` lowering (add/sub/mul/
bitwise are bit-identical); signedness only branches at promotion to i64, printing,
and div/mod/cmp/shift. Contrast with the 64-bit lane (§6): at 32 bits, `Uint32Array`
is as fast as `Int32Array` (and the same holds at 64 bits — the early "BigUint64Array
penalty" was a measurement artifact).

## 8. When to use what

| situation | choice |
|---|---|
| hot loop, values fit in i64, result stays in an array (e.g. hash/PRNG state, counters, wrap arithmetic) | **BigInt64Array** — fastest exact option, free wrap |
| same, but needs u64 semantics (unsigned div/compare/shift) or values > 2^63 read back non-negative | **BigUint64Array** — same speed as `BigInt64Array` for load→compute→store (§6) |
| hot loop, fractional values or 53-bit precision is enough | **Number / Float64Array** — fastest overall, division especially |
| hot loop, C `unsigned int` / u32 semantics | **Numbers with u32 idioms** (`|0`, `Math.imul`, `>>>`, `((a>>>0)/(b>>>0))|0`) — ~1–7 ns/op; identical to i32 except at div/mod/cmp/shift and promotion/print (§7) |
| arbitrary precision / values beyond 64 bits | **plain BigInt** (no array alternative) |
| code that shuttles values between variables and arrays every iteration | avoid; keep values on one side of the boundary in hot loops |

## 9. Caveats

- Microbenchmark; absolute ns vary by CPU, engine version, and JIT state. The int64 fast
  path and allocation behavior are V8-specific (numbers above: V8 13.6 / Node 24).
- The ~1 ns/op RMW figures are an idealized hot-loop pattern (single accumulator,
  loop-invariant operand). Alternating-index / multi-element access patterns measured
  ~5.9 ns/op with per-iteration read-back.
- Float mul is reported unbounded because floats don't need range bounds for speed; the
  bounded variant (`% 1e18`) costs ~8 ns (fmod) and is included for completeness.
- The u32 numbers (§7) were captured while the workspace's background loops were
  competing for CPU — treat absolutes as upper bounds; the ratios and the i32/u32
  equivalence are the durable findings.

## 10. Reproduce

```
node bench_int_vs_float.mjs   # int + float, single harness (this document's numbers)
node bench_bigint_final.mjs   # int-only, larger case set incl. boundary isolation
node bench_u64_vs_i64.mjs <case>  # i64 vs u64, ONE case per process (see the file header: the same-process form is an artifact)
node u32bench.mjs             # u32 idioms + i32/u32 divergence points
node verify_bigint.mjs        # semantics + linear-scaling verification
node micro_bigint.mjs         # mechanism isolation (fast-path variants)
```

All scripts print a checksum at the end; results are medians of 9 trials with calibrated
iteration counts, and each loop's bit-exactness and linear scaling were verified.
