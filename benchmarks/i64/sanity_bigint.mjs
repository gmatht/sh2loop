'use strict';
// Sanity checks: verify loops actually execute every iteration (no DCE),
// and cross-check the harness timing with a second clock.
import { performance } from 'node:perf_hooks';
import { hrtime } from 'node:process';

const MASK = (1n << 64n) - 1n;
const A = 1234567890123456789n;

// Reference: run case bodies with n=7 and print checksums
const ref = [];
{
  let t = 0n, a = A;
  for (let i = 0; i < 7; i++) t += a;           // plainAdd
  ref.push(['plainAdd', t]);
  let t2 = 0n; for (let i = 0; i < 7; i++) t2 = (t2 + a) & MASK; // plainAddMask
  ref.push(['plainAddMask', t2]);
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = A;
  let c = 0n;
  for (let i = 0; i < 7; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; }
  ref.push(['typedAdd', arr[2], c]);
}
console.log('reference (n=7):', JSON.stringify(ref.map(r => [r[0], r[1].toString()])));

// Run the same bodies through the harness shape at n=7
function runPlain(n) { let t = 0n, a = A; for (let i = 0; i < n; i++) t += a; return t; }
function runPlainMask(n) { let t = 0n, a = A; for (let i = 0; i < n; i++) t = (t + a) & MASK; return t; }
function runTyped(n) {
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; }
  return [arr[2], c];
}
console.log('harness   (n=7):', JSON.stringify([
  ['plainAdd', runPlain(7).toString()],
  ['plainAddMask', runPlainMask(7).toString()],
  ['typedAdd', runTyped(7).map(String)],
]));

// Timing cross-check on a big loop, both clocks, and verify iteration count
// sensitivity: doubling n should ~double time (loop truly runs n times).
function timeIt(fn, n) {
  const t0 = performance.now(); const v = fn(n); const t1 = performance.now();
  const h0 = hrtime.bigint(); const v2 = fn(n); const h1 = hrtime.bigint();
  return { ms: t1 - t0, ns: Number(h1 - h0), v: v.toString().slice(0, 20), v2: v2.toString().slice(0, 20) };
}

for (const [name, fn] of [
  ['plainAdd', runPlain],
  ['plainAddMask', runPlainMask],
  ['typedAdd', runTyped],
]) {
  fn(1e6); fn(1e6); // warm
  const a = timeIt(fn, 1 << 26);
  const b = timeIt(fn, 1 << 27);
  console.log(`${name}: n=2^26 -> ${a.ms.toFixed(1)}ms (${(a.ns / (1 << 26)).toFixed(2)} ns/op hrtime); n=2^27 -> ${b.ms.toFixed(1)}ms (${(b.ns / (1 << 27)).toFixed(2)} ns/op hrtime); ratio ${(b.ms / a.ms).toFixed(2)}x  v1==v2: ${a.v === b.v}`);
}
