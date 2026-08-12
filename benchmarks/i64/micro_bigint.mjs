'use strict';
// Micro-variants to isolate why BigInt64Array round-trips beat plain BigInt locals.
import { performance } from 'node:perf_hooks';

const MASK = (1n << 64n) - 1n;
const A = 1234567890123456789n; // ~2^60 (one limb)
const A5 = 5n;                  // keeps t one-limb forever

let sink = 0n;

function measure(name, fn) {
  fn(1 << 20);
  let iters = 1 << 23;
  {
    const st = performance.now();
    fn(iters);
    const msPerOp = (performance.now() - st) / iters;
    iters = Math.max(1 << 20, Math.min(1 << 28, Math.round(250 / msPerOp)));
  }
  fn(1 << 20);
  const samples = [];
  for (let t = 0; t < 9; t++) {
    const st = performance.now();
    const c = fn(iters);
    samples.push(performance.now() - st);
    sink ^= c;
  }
  const s = [...samples].sort((a, b) => a - b);
  const ns = (s[s.length >> 1] * 1e6) / iters;
  console.log(`${name.padEnd(46)} ${(1000 / ns).toFixed(2).padStart(9)} MOPS  ${ns.toFixed(2).padStart(8)} ns/op`);
  return ns;
}

const v = {};
v.plainGrow = measure('plain t += A (t grows to 2 limbs)', n => {
  let t = 0n; const a = A; for (let i = 0; i < n; i++) t += a; return t;
});
v.plainSmall = measure('plain t += 5n (t stays 1 limb)', n => {
  let t = 0n; const a = A5; for (let i = 0; i < n; i++) t += a; return t;
});
v.plainSmallXor = measure('plain t += 5n + c ^= t (in-loop read)', n => {
  let t = 0n, c = 0n; const a = A5;
  for (let i = 0; i < n; i++) { t += a; c ^= t; } return c ^ t;
});
v.typedPure = measure('typed arr[2]=arr[2]+arr[0] (no in-loop read)', n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
});
v.typedXor = measure('typed same + c ^= arr[2] (in-loop read)', n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; }
  return c ^ arr[0];
});
v.typedStore = measure('typed arr[2]=t+a (operands local, store only)', n => {
  const arr = new BigInt64Array(3);
  let t = 0n; const a = A;
  for (let i = 0; i < n; i++) { t = (t + a) & MASK; arr[2] = t; }
  return arr[2] ^ t;
});
v.typedLoad = measure('typed t += arr[0] (load only, result local)', n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  let t = 0n;
  for (let i = 0; i < n; i++) t += arr[0];
  return t ^ arr[1];
});
v.baseline = measure('baseline arr[2]=arr[i&1] (pure copy)', n => {
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[i & 1]; c ^= arr[2]; }
  return c ^ arr[0];
});

console.log('-'.repeat(62));
console.log('ratios (plainSmall as the natural-arithmetic reference):');
console.log(`  typedPure / plainSmall    = ${(v.typedPure / v.plainSmall).toFixed(2)}x`);
console.log(`  typedXor  / plainSmallXor = ${(v.typedXor / v.plainSmallXor).toFixed(2)}x`);
console.log(`  baseline copy             = ${v.baseline.toFixed(2)} ns/op (pure load+store floor)`);
console.log(`checksum: ${sink.toString(16).slice(0, 8)}`);
