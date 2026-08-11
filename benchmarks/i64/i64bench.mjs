// i64/u64: BigInt vs BigInt64Array vs WASM-backed — benchmark.
// Usage: node i64bench.mjs
import { readFileSync } from "node:fs";

const wasm = (await WebAssembly.instantiate(readFileSync("/tmp/i64bench/ops.wasm"))).instance.exports;
const mem = new BigInt64Array(wasm.memory.buffer);
const mem32 = new Int32Array(wasm.memory.buffer);

const M64 = 0xFFFFFFFFFFFFFFFFn;
const N = 1_000_000;          // per-op loop iterations (2 ops each)
const BL = 2_000_000;         // batched loop iterations (inside wasm)
const M = 1_000_000;          // bulk element count

function time(fn, warmups = 2, runs = 3) {
  for (let i = 0; i < warmups; i++) fn();
  let best = Infinity;
  for (let i = 0; i < runs; i++) {
    const t0 = performance.now();
    fn();
    best = Math.min(best, performance.now() - t0);
  }
  return best;
}
const ns = (ms, iters) => (ms * 1e6 / iters).toFixed(2);

// ── 1. pure BigInt arithmetic: x = (x+1n)*3n ──────────────────────
let xBig = 0n;
process.stderr.write("1 bigint…");
const tBig = time(() => {
  for (let i = 0; i < N; i++) xBig = ((xBig + 1n) * 3n) & M64;
});
const bigIter = tBig / N; // 2 ops per iter

// ── 2. BigInt64Array storage + BigInt arithmetic ──────────────────
const store = new BigInt64Array(N);
store[0] = 0n;
let xStore = 0n;
process.stderr.write("2 store…");
const tStore = time(() => {
  for (let i = 0; i < N; i++) {
    xStore = ((store[i & 0xffff] + 1n) * 3n) & M64;
    store[i & 0xffff] = xStore;
  }
});

// ── 3. wasm per-op, BigInt crossing (x+1n)*3n via two wasm calls ──
let xWb = 0n;
process.stderr.write("3 wasm-bigint…");
const tWb = time(() => {
  for (let i = 0; i < N; i++) xWb = wasm.mul64(wasm.add64(xWb, 1n), 3n);
});

// ── 4. wasm per-op, hi/lo i32 crossing (no BigInt on the JS side) ─
const OUT = 0x1000; // scratch in wasm memory
let lo = 0, hi = 0;
process.stderr.write("4 wasm-hilo…");
const tWl = time(() => {
  for (let i = 0; i < N; i++) {
    wasm.addSplit(lo, hi, 1, 0, OUT); lo = mem32[OUT >> 2]; hi = mem32[(OUT >> 2) + 1];
    wasm.mulSplit(lo, hi, 3, 0, OUT); lo = mem32[OUT >> 2]; hi = mem32[(OUT >> 2) + 1];
  }
});

// ── 5. batched: whole loop inside wasm vs the BigInt loop ─────────
let rLoop = 0n;
process.stderr.write("5 batch…");
for (let i = 0; i < 1024; i++) mem[i] = BigInt((i % 5) + 1);
const tLoopW = time(() => { rLoop = wasm.runLoopDep(BL, 0); });
const tLoopB = time(() => {
  let a = 0n;
  for (let i = 0; i < BL; i++) a = (a * 3n + 1n) & M64;
  rLoop ^= a;
});

// ── 6. bulk: 1M i64s, JS fill into BigInt64Array over wasm memory ─
for (let i = 0; i < M; i++) mem[i] = BigInt(i);
process.stderr.write("6 fill…");
const tFill = time(() => { for (let i = 0; i < M; i++) mem[i] = BigInt(i); });
// 6a. sum in JS (BigInt reads)
let sJs = 0n;
process.stderr.write("6a sumJS…");
const tSumJs = time(() => { for (let i = 0; i < M; i++) sJs += mem[i]; });
// 6b. sum in wasm (memSum: i64 loads + adds inside wasm)
let sW = 0n;
process.stderr.write("6b sumW…");
const tSumW = time(() => { sW = wasm.memSum(0, M); });
// 6c. in-place add in JS vs wasm
process.stderr.write("6c addJS…");
const tAddJs = time(() => { for (let i = 0; i < M; i++) mem[i] += 1n; });
process.stderr.write("6d addW…");
const tAddW = time(() => { wasm.memAdd(0, M, 1n); });

// ── controls: i32 |0 path and f64 doubles (the "cheap" lanes) ─────
let xi = 0;
process.stderr.write("7 i32…");
const tI32 = time(() => { for (let i = 0; i < N; i++) xi = (Math.imul((xi + 1) | 0, 3)) | 0; });
let xf = 0;
process.stderr.write("7 f64…");
const tF64 = time(() => { for (let i = 0; i < N; i++) xf = (xf + 1) * 3; });

const rel = (v) => (v / bigIter).toFixed(2) + "x";

console.log(`node ${process.version} — per-iteration timings, ${N} iters (2 ops each)`);
console.log("─".repeat(64));
console.log("scenario                                   ns/iter   vs BigInt");
console.log("─".repeat(64));
console.log(`1  BigInt  (x+1n)*3n                       ${ns(tBig, N).padStart(7)}  ${"1.00x"}`);
console.log(`2  BigInt64Array store + BigInt arith      ${ns(tStore, N).padStart(7)}  ${rel(tStore / N)}`);
console.log(`3  wasm per-op, BigInt crossing (2 calls)  ${ns(tWb, N).padStart(7)}  ${rel(tWb / N)}`);
console.log(`4  wasm per-op, hi/lo i32 crossing         ${ns(tWl, N).padStart(7)}  ${rel(tWl / N)}`);
console.log(`5  wasm whole-loop batched (dep)         ${ns(tLoopW, BL).padStart(7)}  ${rel(tLoopW / BL)}`);
console.log(`6a bulk: sum 1M i64s, JS (BigInt reads)    ${ns(tSumJs, M).padStart(7)}  ${rel(tSumJs / M)}`);
console.log(`6b bulk: sum 1M i64s, in wasm (memSum)     ${ns(tSumW, M).padStart(7)}  ${rel(tSumW / M)}`);
console.log(`6c bulk: += 1 over 1M i64s, JS             ${ns(tAddJs, M).padStart(7)}  ${rel(tAddJs / M)}`);
console.log(`6d bulk: += 1 over 1M i64s, in wasm        ${ns(tAddW, M).padStart(7)}  ${rel(tAddW / M)}`);
console.log(`7  fill 1M i64s from JS (BigInt64Array)    ${ns(tFill, M).padStart(7)}  ${rel(tFill / M)}`);
console.log("─".repeat(64));
console.log("controls (2 ops/iter):");
console.log(`   i32 via |0 + Math.imul                   ${ns(tI32, N).padStart(7)}  ${rel(tI32 / N)}`);
console.log(`   f64 doubles                               ${ns(tF64, N).padStart(7)}  ${rel(tF64 / N)}`);
console.log("─".repeat(64));
// sanity: all paths must agree
console.log("sanity: xBig =", String(xBig).slice(0, 10) + "…  wasm runLoop =", rLoop,
  " sumJS =", String(sJs).slice(0, 8), " sumW =", String(sW).slice(0, 8),
  " xWb =", String(xWb).slice(0, 8), " xStore =", String(xStore).slice(0, 8));
