// i64 vs u64: BigInt64Array vs BigUint64Array — CORRECTED methodology.
//
// WARNING: running i64 and u64 kernels of identical shape in ONE process
// produces a spurious 10-20x "u64 penalty" — V8's optimized-code sharing
// for identical closures mis-specializes whichever kernel did not get the
// first optimization, dropping it to the BigInt-materialization path.
// Real programs have ONE array type per hot loop, so each case must run
// in its OWN process (best-of trials; the box runs background workers,
// so medians get skewed — best-of is preemption-immune).
//
// Usage: node bench_u64_vs_i64.mjs <case>
//   add-i64 | add-u64 | mul-i64 | mul-u64 | div-i64 | div-u64
//   add-obs-i64 | add-obs-u64 | mul-obs-i64 | mul-obs-u64
import { performance } from 'node:perf_hooks';

const A = 0x8000000000000005n;  // >= 2^63 (u64 range; negative as i64 bits)
const MA = 0x1000000000000003n;
const D = 0x100000003n;          // ~2^32 divisor

const CASES = {
  'add-i64': (n) => { const a = new BigInt64Array(3); a[0] = A; for (let i = 0; i < n; i++) a[2] = a[2] + a[0]; return a[2] ^ a[0]; },
  'add-u64': (n) => { const a = new BigUint64Array(3); a[0] = A; for (let i = 0; i < n; i++) a[2] = a[2] + a[0]; return a[2] ^ a[0]; },
  'mul-i64': (n) => { const a = new BigInt64Array(3); a[0] = MA; a[2] = 1n; for (let i = 0; i < n; i++) a[2] = a[2] * a[0]; return a[2] ^ a[0]; },
  'mul-u64': (n) => { const a = new BigUint64Array(3); a[0] = MA; a[2] = 1n; for (let i = 0; i < n; i++) a[2] = a[2] * a[0]; return a[2] ^ a[0]; },
  'div-i64': (n) => { const a = new BigInt64Array(3); a[0] = A; a[1] = D; for (let i = 0; i < n; i++) a[2] = (a[2] + a[0]) / a[1]; return a[2] ^ a[0]; },
  'div-u64': (n) => { const a = new BigUint64Array(3); a[0] = A; a[1] = D; for (let i = 0; i < n; i++) a[2] = (a[2] + a[0]) / a[1]; return a[2] ^ a[0]; },
  'add-obs-i64': (n) => { const a = new BigInt64Array(3); a[0] = A; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] + a[0]; c ^= a[2]; } return c ^ a[0]; },
  'add-obs-u64': (n) => { const a = new BigUint64Array(3); a[0] = A; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] + a[0]; c ^= a[2]; } return c ^ a[0]; },
  'mul-obs-i64': (n) => { const a = new BigInt64Array(3); a[0] = MA; a[2] = 1n; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] * a[0]; c ^= a[2]; } return c ^ a[0]; },
  'mul-obs-u64': (n) => { const a = new BigUint64Array(3); a[0] = MA; a[2] = 1n; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] * a[0]; c ^= a[2]; } return c ^ a[0]; },
  // u64 implemented on BigInt64Array (bit patterns; asUintN reinterpret)
  'u64onI64-add': (n) => { const a = new BigInt64Array(3); a[0] = A; for (let i = 0; i < n; i++) a[2] = a[2] + a[0]; return a[2] ^ a[0]; },
  'u64onI64-add-obs': (n) => { const a = new BigInt64Array(3); a[0] = A; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] + a[0]; c ^= BigInt.asUintN(64, a[2]); } return c ^ a[0]; },
  'u64onI64-mul-obs': (n) => { const a = new BigInt64Array(3); a[0] = MA; a[2] = 1n; let c = 0n; for (let i = 0; i < n; i++) { a[2] = a[2] * a[0]; c ^= BigInt.asUintN(64, a[2]); } return c ^ a[0]; },
  'u64onI64-div': (n) => { const a = new BigInt64Array(3); a[0] = A; a[1] = D; for (let i = 0; i < n; i++) { const t = BigInt.asUintN(64, a[2]) + BigInt.asUintN(64, a[0]); a[2] = BigInt.asIntN(64, t / BigInt.asUintN(64, a[1])); } return a[2] ^ a[0]; },
};

const CASE = process.argv[2];
if (!CASES[CASE]) {
  console.error(`usage: node bench_u64_vs_i64.mjs <${Object.keys(CASES).join('|')}>`);
  process.exit(2);
}
// correctness: u64-on-BigInt64Array must equal BigUint64Array bit-exactly
if (CASE === 'u64onI64-add' || CASE === 'u64onI64-add-obs' || CASE === 'u64onI64-mul-obs' || CASE === 'u64onI64-div') {
  const u = new BigUint64Array(3), i = new BigInt64Array(3);
  u[0] = A; i[0] = A; u[1] = D; i[1] = D; u[2] = 0n; i[2] = 0n;
  for (let k = 0; k < 1000; k++) { u[2] = (u[2] + u[0]) % (1n << 64n); i[2] = i[2] + i[0]; }
  const ok = u[2] === BigInt.asUintN(64, i[2]);
  console.log(`[verify] u64-on-i64 add == BigUint64Array: ${ok}`);
}

const fn = CASES[CASE];
fn(1 << 20); fn(1 << 20);
for (let w = 0; w < 10; w++) fn(1 << 24);
const it = CASE.startsWith('div') || CASE.endsWith('obs') || CASE.endsWith('obs-i64') || CASE.endsWith('obs-u64') ? 1 << 24 : 1 << 26;
const samples = [];
for (let k = 0; k < 25; k++) { const st = performance.now(); fn(it); samples.push(performance.now() - st); }
samples.sort((a, b) => a - b);
console.log(`${CASE.padEnd(18)} best ${(samples[0] * 1e6 / it).toFixed(2)}  med ${(samples[12] * 1e6 / it).toFixed(2)} ns/op`);
