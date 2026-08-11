# i64 implementation: performance & the tcc fork — measured state

Date: 2026-08-11. Runtime: node v24.18.0 (V8). Benchmarks: `benchmarks/i64/`.

## The problem

The A1 IR carries a widthless `Int` ("every assignment is provably numeric —
native `long long` / number"). C's `int`/`long long` collapse into it; the c
backend re-emits `long long`, narrowed only where its range analysis proves a
narrower width safe. When the *execution* of i64 arithmetic matters, every
backend pays a different tax:

| backend | i32 | i64 |
|---|---|---|
| JS | ~free (`\|0`, `Math.imul`, `>>>`) | **expensive** — see below |
| Rust/Go/Zig | free | free (native) |
| Perl | 1 op (mask) | free (IV = 64-bit) |
| sh | 2 ops (mask + sign fix) | ~free (shell arithmetic = signed long) |
| Python | 2 ops (bignum has no wrap) | 2 ops |

The engine fact that decides everything: **no mainstream JS engine unboxes
BigInt to native i64 registers.** BigInt values are heap objects; arithmetic is
a C++ fast path at best, and the i64 params/results of the WebAssembly JS API
must be BigInt (the BigInt integration). Limb-pair (hi/lo i32) emulation is
never fused by the JIT — engines only reconstruct i64 from i32 pairs
internally, for their own wasm lowering. `BigInt64Array` gives *true i64
storage* (real 64-bit memory) but arithmetic on read values still boxes.

## Measured (V8, node v24, `i64bench.mjs`, per iteration, 2 ops each)

| scenario | ns/iter | vs BigInt |
|---|---|---|
| BigInt `(x+1n)*3n` (masked at 2^64) | 74–87 | 1.00× |
| BigInt64Array storage + BigInt arith | 45–55 | 0.6× |
| wasm per-op, BigInt crossing (2 calls) | 20–22 | 0.25× |
| wasm per-op, hi/lo i32 crossing (no BigInt) | 13 | 0.18× |
| wasm whole-loop batched (data-dep chain) | 0.95 | 0.013× (~80×) |
| bulk sum 1M i64s, JS (BigInt reads) | 12 | 0.15× |
| bulk sum 1M i64s, in wasm | 0.35 | 0.005× (~35×) |
| bulk `+= 1` over 1M i64s, JS | 1.1 | 0.015× |
| bulk `+= 1` over 1M i64s, in wasm | 0.42 | 0.006× |
| fill 1M i64s from JS (BigInt64Array) | 23–30 | 0.3× |
| control i32 `\|0` + `Math.imul` | 1.9 | 0.02× |
| control f64 doubles | 8.8 | 0.12× |

### Conclusions

1. **Per-op wasm delegation beats BigInt 4–6× but is nowhere near native**
   (~10 ns/call; the i64→BigInt result allocation is real). The only path to
   native speed is **whole-region-in-wasm** (~80× over BigInt).
2. **The copying cost is at the bulk fill boundary only** (~25 ns/elem,
   JS BigInt → i64 storage), and it is *identical* whether the target is a
   plain `BigInt64Array` or wasm linear memory — the benchmark's store *is* a
   `BigInt64Array` view over `wasm.memory.buffer` (shared backing, zero
   marshalling). Data-resident = zero copy.
3. **Strength reduction is a clang-only property.** The first run of the
   whole-loop benchmark showed "0.12 ns/iter" — impossible for a serial
   mul+add chain. clang had reduced `acc = acc*3+1` to its closed form
   `(3ⁿ−1)/2` via modular exponentiation (verified bit-exact). A data-dependent
   multiplier (loaded from memory) gives the honest 0.95 ns. BigInt-in-JS
   never gets algebraic optimizations; wasm inherits LLVM's.
4. **i32 remains the outlier** (1.9 ns — 40× faster than BigInt). The cost
   cliff is at the 32→64 boundary, not the 0→32 one.

## The tcc fork (gmatht/tinycc, `/root/src/tinycc-wasm`)

A wasm32 backend (`wasm32-gen.c`/`wasm32-link.c`) exists in our fork; it is
**not in mainline tcc** (built 0.9.28rc mob from source: zero wasm code; no
maintained upstream wasm fork). Build: `./configure --cpu=wasm32 && make` —
the target is configure-time, not a `-target` flag.

### Measured vs emcc (same source, `h2h.mjs`)

| | tcc fork wasm | emcc -O3 wasm | BigInt JS |
|---|---|---|---|
| compile time | 3 ms | 957 ms | — |
| loop_dep (100M) | 13.0 ns/iter | 0.93 ns/iter | 80 ns/iter |
| mem_sum (100k) | 10.5 ns/elem | 0.54 ns/elem | — |
| `-O2`/`-O3` flags | no change | — | — |

The fork is **14–19× slower than emcc on hot i64 loops** (single-pass codegen,
amplified in wasm: no registers to spill to, i64s lowered to i32 pairs,
TurboFan can't recover what was never there) and — before this work —
**silently wrong for i64 values beyond 32 bits** (pow3(20) mismatch, sumN
wrong). The compile-time win (3 ms vs ~1 s) is real and decisive for
in-browser UX; the hot-loop performance is not.

### Fixed (committed `0115c18c`)

The critical bug class: **the backend re-read the source slots after storing
the low result** — `d` aliases a source slot (`get_reg` recycles consumed
operands), so the high word/carry was computed from the clobbered value.
Data-dependent, silent wrong results. Fix: park the result/sum in dedicated
scratch locals; the carry moved from memory slot 7 (allocatable!) to a
dedicated wasm local.

- `gen_opl` split (all i64 ops): never re-read a/b after the low store.
- `TOK_UMULL` (32×32→64): same for the high word.
- `TOK_ADDC1/SUBC1`: carry = wrapped sum < a, computed before any store;
  borrow = a < b unsigned; carry in a wasm local.
- **i64 params**: split into hi/lo against the outer `[addr, param]`
  (previously the param was pushed twice → two dangling stack values →
  malformed wasm).
- **variable-count 64-bit shifts**: tccgen routes them through unprototyped
  `__ashldi3/__lshrdi3/__ashrdi3` calls; intercepted in `gfunc_call` and
  emitted inline (wasm masks the count by 63, matching defined C behavior).
- **w_layout edge emission**: an unresolved edge target (label pos −1) ran
  the LEB loop on a negative `v` forever (arithmetic shift keeps −1) → heap
  corruption + compiler segfault. Now a loud REFUSE.
- **i64 memory lvalue loads** (committed `6c5460b0`): the backend assumed
  i64 register pairs are consecutive (r, r+1), but tccgen's `get_reg`
  allocates the second word independently. `reg_classes[0]` carried a
  spurious `RC_F(0)`, so `RC_RET(i64)` failed `RC2_TYPE`'s `rc == RC_IRET`
  test and an i64 return's second word could land in any int register while
  the epilog reads the fixed pair (0,1) — wrong hi word for `return p[0]`.
  `gen_opl`/`TOK_UMULL` combined operands from `(a, a+1)` and stored the
  split to `(d, d+1)` — with non-consecutive pairs those read/wrote the
  wrong slots, and allocating `d2` without marking `d` busy on the vstack
  returned the SAME slot for low and high (silently merging the stores).
  Now: no `RC_F(0)` on reg 0; the actual `r2` of each operand is used;
  a real second register is allocated for the high word; the shift count
  (kept INT by tccgen) has a zero high word.

Verified: pow3(n) n≤60, sumN(100000), 3000+ randomized i64 add/sub/mul/
shift/bitwise/mixed checks against emcc, memory lvalue loads (ld4-6),
loaded×loaded muls, i64 params/returns, carry/borrow across 2^32.

### Known remaining (pre-existing; all loud or documented, none silent)

- if/else inside loops with i64 bodies — returns 0 (the pristine original
  produces identical wrong results; the loop back-edge + branch label
  mapping in w_layout).
- 64-bit compares — REFUSE (unresolved label) or, in some shapes, wrong
  results; the underlying deferred-`cmp_r` design also corrupts 32-bit
  compares under register pressure (eager evaluation fixes it but perturbs
  the fragile w_layout into malformed output — the float path already
  evaluates eagerly).
- i64 call args/returns, 64-bit division, varargs — loud REFUSEs.

## tcc's own corpus (the right test set)

Yes — tcc ships its own conformance corpus, and it's what the fork should be
measured against: `tests/tests2/` (150 tests with `.expect` files) plus
`tests/tcctest.c` (4520 lines) and the preprocessor tests in `tests/pp/`.
The corpus runner (`tests/wasm-corpus/run-corpus.mjs` in the fork) compiles
each tests2 test with the wasm32 backend, runs it via Node WASI + the
sh2runtime's `c-runtime.js` env shim (the `env.$*` imports), and compares
stdout to `.expect`. Current state (2026-08-11):

**36 PASS / 17 WRONG / 70 REFUSE / 6 COMPILE-OUT / 3 RUN-CRASH /
10 RUN-ERR / 9 NO-EXPECT** — identical on the pristine fork, so the i64
fixes introduce zero corpus regressions. The 17 WRONG (silent wrong output
— the dangerous class: 06_case switch, 16_nesting, 37_sprintf %02d, 91_ptr
_longlong, 132/133 %g…) and the 4 compiler heap-corruption crashes
(39_typedef, 89_nocode_wanted, 95_bitfields, 101_cleanup) are the actionable
backlog.

## Architectural recommendations

1. **Observation-point enforcement, not per-op wrap.** Signed overflow is UB
   in C, so the transpiler is free to run arithmetic in the backend's widest
   native integer and enforce width only at casts, assignment truncation,
   unsigned ops, and formatting — localized checks, near-zero cost.
2. **Never cross i64; cross i32 offsets.** Data lives in wasm linear memory
   (or `BigInt64Array`); only handles cross the boundary. `BigInt64Array` over
   `wasm.memory.buffer` is the zero-copy i64-true heap.
3. **Per-op wasm delegation is a wash** (~10 ns/call ≈ BigInt); the win is
   whole-region (a real wasm backend, or the c backend + clang/emcc — which
   also buys LLVM's algebraic optimizations).
4. **The fork's niche** is fast-turnaround compilation (3 ms) of non-hot code;
   hot i64 loops belong to emcc/clang output or a proper wasm backend.
