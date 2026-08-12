'use strict';
// Verify the suspiciously fast typed-array RMW result: linear scaling, value correctness,
// and a comparison against native int64 semantics via BigUint64Array + Number? (no — use
// BigInt math directly as reference for mod-2^64 wrap).
import { performance } from 'node:perf_hooks';
const A = 1234567890123456789n;

function typedRMW(n) {
  const arr = new BigInt64Array(3); arr[0] = A;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2];
}

// reference: (n*A) mod 2^64, interpreted as signed
function refMod(n) {
  const M = 1n << 64n;
  let v = (BigInt(n) * A) % M;
  if (v >= (1n << 63n)) v -= M; // to signed
  return v;
}

for (const n of [7, 1000, 1 << 20]) {
  const got = typedRMW(n), want = refMod(n);
  console.log(`n=${n}: got=${got} want=${want} match=${got === want}`);
}

// linear scaling: time n vs 2n (also 4n), should scale ~linearly
for (const [name, fn] of [['typedRMW', typedRMW], ['plainSmall', n => { let t = 0n; for (let i = 0; i < n; i++) t += 5n; return t; }]]) {
  fn(1 << 20);
  const time = n => { const s = performance.now(); fn(n); return performance.now() - s; };
  const t1 = time(1 << 26), t2 = time(1 << 27), t4 = time(1 << 28);
  console.log(`${name}: n=2^26 ${t1.toFixed(1)}ms  n=2^27 ${t2.toFixed(1)}ms (${(t2 / t1).toFixed(2)}x)  n=2^28 ${t4.toFixed(1)}ms (${(t4 / t2).toFixed(2)}x)`);
}

// does the fast path hold when the result must be observed every iteration
// vs only at the end? And is arr[0] load hoisted?
function typedRMW_obs(n) { // observe arr[2] every iteration via XOR into a BigInt
  const arr = new BigInt64Array(3); arr[0] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; }
  return c ^ arr[0];
}
function typedRMW_varop(n) { // operand alternates -> no hoisting
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[i & 1]; c ^= arr[2]; }
  return c ^ arr[0];
}
function typedRMW_imm(n) { // literal operand
  const arr = new BigInt64Array(3); arr[0] = A;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + 5n;
  return arr[2] ^ arr[0];
}

function bench(name, fn) {
  fn(1 << 20);
  const iters = 1 << 26;
  const samples = [];
  for (let t = 0; t < 7; t++) { const s = performance.now(); fn(iters); samples.push(performance.now() - s); }
  const s = [...samples].sort((a, b) => a - b);
  const ns = (s[s.length >> 1] * 1e6) / iters;
  console.log(`${name.padEnd(28)} ${(1000 / ns).toFixed(2).padStart(8)} MOPS ${ns.toFixed(2).padStart(8)} ns/op`);
}

bench('typedRMW (no obs, arr0 hoistable)', typedRMW);
bench('typedRMW + obs every iter', typedRMW_obs);
bench('typedRMW varying operand', typedRMW_varop);
bench('typedRMW literal operand', typedRMW_imm);
