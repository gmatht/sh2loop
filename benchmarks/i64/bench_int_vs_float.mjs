'use strict';
// ============================================================================
// BigInt (int64) vs regular float64 arithmetic — one harness, same loop shapes,
// values in the same ~2^60 magnitude class.
//
//   plain BigInt / plain Number : operands & results in local variables
//   BigInt64Array / Float64Array: operands loaded from the typed array, result
//                                 stored straight back (native fast-path form)
//   *Obs : result also read back into a BigInt every iteration
// ============================================================================
import { performance } from 'node:perf_hooks';

const MASK = (1n << 64n) - 1n;
const A  = 1234567890123456789n; // ~2^60
const SM = 5n;                   // keeps plain add single-limb for n <= 2^28
const MA = 1234567890n;          // ~2^30 multiplier (MA*MA < 2^64)
const S  = 1234567n;             // ~2^20 divisor

const FA  = 1234567890123456789; // same magnitude as A, as float64
const FMA = 1234567890;
const FS  = 1234567;

let sink = 0n; // BigInt checksum
let sinkN = 0; // Number checksum

// ---- int64 kernels ---------------------------------------------------------
const kPlainAddSmall = n => { let t = 0n; const a = SM; for (let i = 0; i < n; i++) t += a; return t; };
const kPlainAddGrow  = n => { let t = 0n; const a = A;  for (let i = 0; i < n; i++) t += a; return t; };
const kPlainAddMask  = n => { let t = 0n; const a = A;  for (let i = 0; i < n; i++) t = (t + a) & MASK; return t; };
const kTypedAdd      = n => { const arr = new BigInt64Array(3); arr[0] = A; for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0]; return arr[2] ^ arr[0]; };
const kTypedAddObs   = n => { const arr = new BigInt64Array(3); arr[0] = A; let c = 0n; for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; } return c ^ arr[0]; };
const kPlainMulMask  = n => { let t = 1n; const a = MA; for (let i = 0; i < n; i++) t = (t * a) & MASK; return t; };
const kTypedMul      = n => { const arr = new BigInt64Array(3); arr[0] = MA; arr[2] = 1n; for (let i = 0; i < n; i++) arr[2] = arr[2] * arr[0]; return arr[2] ^ arr[1]; };
const kTypedMulObs   = n => { const arr = new BigInt64Array(3); arr[0] = MA; arr[2] = 1n; let c = 0n; for (let i = 0; i < n; i++) { arr[2] = arr[2] * arr[0]; c ^= arr[2]; } return c ^ arr[1]; };
const kPlainDiv      = n => { let t = 0n; const a = A, s = S; for (let i = 0; i < n; i++) t = (t + a) / s; return t; };
const kTypedDiv      = n => { const arr = new BigInt64Array(3); arr[0] = A; arr[1] = S; for (let i = 0; i < n; i++) arr[2] = (arr[2] + arr[0]) / arr[1]; return arr[2] ^ arr[0]; };
const kTypedDivObs   = n => { const arr = new BigInt64Array(3); arr[0] = A; arr[1] = S; let c = 0n; for (let i = 0; i < n; i++) { arr[2] = (arr[2] + arr[0]) / arr[1]; c ^= arr[2]; } return c ^ arr[0]; };

// ---- float64 kernels ---------------------------------------------------------
const kFPlainAdd = n => { let t = 0; const a = FA; for (let i = 0; i < n; i++) t += a; return t; };
const kFPlainMul = n => { let t = 1; const a = FMA; for (let i = 0; i < n; i++) t = (t * a) % 1e18; return t; };   // bounded, fmod cost included
const kFPlainMulUn = n => { let t = 1; const a = FMA; for (let i = 0; i < n; i++) t = t * a; return t; };           // unbounded (overflows to Infinity)
const kFPlainDiv = n => { let t = 0; const a = FA, s = FS; for (let i = 0; i < n; i++) t = (t + a) / s; return t; };
const kFTypedAdd = n => { const arr = new Float64Array(3); arr[0] = FA; for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0]; return arr[2] + arr[0]; };
const kFTypedMul = n => { const arr = new Float64Array(3); arr[0] = FMA; arr[2] = 1; for (let i = 0; i < n; i++) arr[2] = (arr[2] * arr[0]) % 1e18; return arr[2] + arr[0]; };
const kFTypedMulUn = n => { const arr = new Float64Array(3); arr[0] = FMA; arr[2] = 1; for (let i = 0; i < n; i++) arr[2] = arr[2] * arr[0]; return arr[2] + arr[0]; };
const kFTypedDiv = n => { const arr = new Float64Array(3); arr[0] = FA; arr[1] = FS; for (let i = 0; i < n; i++) arr[2] = (arr[2] + arr[0]) / arr[1]; return arr[2] + arr[0]; };
const kFAdd32     = n => { const arr = new Float32Array(3); arr[0] = FA; for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0]; return arr[2] + arr[0]; };
const kFLoadOnly  = n => { const arr = new Float64Array(3); arr[0] = FA; let t = 0; for (let i = 0; i < n; i++) t += arr[0]; return t + arr[1]; };

// ---- linear-scaling check (proves loops really run all n iterations) --------
function linearity(fn) {
  fn(1 << 20);
  const t = n => { const s = performance.now(); fn(n); return performance.now() - s; };
  const a = t(1 << 26), b = t(1 << 27);
  return b / a;
}
for (const [name, fn] of [
  ['float plain add', kFPlainAdd], ['float plain mul', kFPlainMul], ['float plain mul unb', kFPlainMulUn], ['float plain div', kFPlainDiv],
  ['float64 arr add', kFTypedAdd], ['float64 arr mul unb', kFTypedMulUn], ['float64 arr div', kFTypedDiv],
]) {
  console.log(`[linearity] ${name.padEnd(18)} n=2^26 vs 2^27 -> ${linearity(fn).toFixed(2)}x (expect ~2.0)`);
}

// ---- harness -----------------------------------------------------------------
function measure(name, fn) {
  fn(1 << 20);
  let iters = 1 << 23;
  {
    const st = performance.now(); fn(iters);
    iters = Math.max(1 << 20, Math.min(1 << 28, Math.round(250 / ((performance.now() - st) / iters))));
  }
  fn(1 << 20);
  const samples = [];
  for (let t = 0; t < 9; t++) {
    const st = performance.now();
    const c = fn(iters);
    samples.push(performance.now() - st);
    if (typeof c === 'bigint') sink ^= c; else sinkN += c;
  }
  const s = [...samples].sort((x, y) => x - y);
  const ns = (s[s.length >> 1] * 1e6) / iters;
  console.log(`${name.padEnd(42)} ${(1000 / ns).toFixed(2).padStart(9)} MOPS  ${ns.toFixed(2).padStart(8)} ns/op`);
  return ns;
}

console.log(`node ${process.version}  ${process.platform}/${process.arch}  (V8 ${process.versions.v8})`);
console.log('-'.repeat(66));

const r = {};
console.log('-- integers: plain BigInt vs BigInt64Array --');
r.plainAddSmall = measure('plain BigInt add (t += 5n, 1 limb)', kPlainAddSmall);
r.plainAddGrow  = measure('plain BigInt add (t += ~2^60, grows)', kPlainAddGrow);
r.plainAddMask  = measure('plain BigInt add + & mask (manual wrap)', kPlainAddMask);
r.typedAdd      = measure('BigInt64Array add (load+store)', kTypedAdd);
r.typedAddObs   = measure('BigInt64Array add + read back BigInt', kTypedAddObs);
r.plainMulMask  = measure('plain BigInt mul + & mask', kPlainMulMask);
r.typedMul      = measure('BigInt64Array mul (load+store)', kTypedMul);
r.typedMulObs   = measure('BigInt64Array mul + read back BigInt', kTypedMulObs);
r.plainDiv      = measure('plain BigInt div', kPlainDiv);
r.typedDiv      = measure('BigInt64Array div (load+store)', kTypedDiv);
r.typedDivObs   = measure('BigInt64Array div + read back BigInt', kTypedDivObs);

console.log('-- regular float: plain Number vs Float64Array --');
r.fPlainAdd  = measure('plain Number add (t += ~2^60)', kFPlainAdd);
r.fPlainMul  = measure('plain Number mul (bounded % 1e18)', kFPlainMul);
r.fPlainMulUn = measure('plain Number mul (unbounded, -> Inf)', kFPlainMulUn);
r.fPlainDiv  = measure('plain Number div', kFPlainDiv);
r.fTypedAdd  = measure('Float64Array add (load+store)', kFTypedAdd);
r.fTypedMul  = measure('Float64Array mul (load+store)', kFTypedMul);
r.fTypedMulUn = measure('Float64Array mul unbounded (load+store)', kFTypedMulUn);
r.fTypedDiv  = measure('Float64Array div (load+store)', kFTypedDiv);
r.fAdd32     = measure('Float32Array add (load+store)', kFAdd32);
r.fLoadOnly  = measure('Number t += f64arr[0] (boundary load)', kFLoadOnly);

console.log('-'.repeat(66));
const fmt = x => x.toFixed(2);
console.log('summary (ns/op):          BigInt                  float64');
console.log(`add   plain=${String(fmt(r.plainAddSmall)).padStart(7)} typed=${String(fmt(r.typedAdd)).padStart(7)}  |  plain=${String(fmt(r.fPlainAdd)).padStart(7)} typed=${String(fmt(r.fTypedAdd)).padStart(7)}`);
console.log(`mul   plain=${String(fmt(r.plainMulMask)).padStart(7)} typed=${String(fmt(r.typedMul)).padStart(7)}  |  plain=${String(fmt(r.fPlainMulUn)).padStart(7)} typed=${String(fmt(r.fTypedMulUn)).padStart(7)}  (unbounded; bounded-with-fmod: ${fmt(r.fPlainMul)}, ${fmt(r.fTypedMul)})`);
console.log(`div   plain=${String(fmt(r.plainDiv)).padStart(7)} typed=${String(fmt(r.typedDiv)).padStart(7)}  |  plain=${String(fmt(r.fPlainDiv)).padStart(7)} typed=${String(fmt(r.fTypedDiv)).padStart(7)}`);
console.log('ratio float/bigint (lower = float faster):');
console.log(`  add: plain ${(r.fPlainAdd / r.plainAddSmall).toFixed(2)}x   typed-array ${(r.fTypedAdd / r.typedAdd).toFixed(2)}x`);
console.log(`  mul: plain ${(r.fPlainMulUn / r.plainMulMask).toFixed(2)}x   typed-array ${(r.fTypedMulUn / r.typedMul).toFixed(2)}x`);
console.log(`  div: plain ${(r.fPlainDiv / r.plainDiv).toFixed(2)}x   typed-array ${(r.fTypedDiv / r.typedDiv).toFixed(2)}x`);
console.log(`float boundary load: ${r.fLoadOnly.toFixed(2)} ns/op (vs plain add ${r.fPlainAdd.toFixed(2)}) — free, no materialization`);
console.log(`checksums: bigint=${sink.toString(16).slice(0, 8)} number=${sinkN.toFixed(1)}`);
