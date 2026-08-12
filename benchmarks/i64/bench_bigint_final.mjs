'use strict';
// ============================================================================
// BigInt arithmetic: plain variables vs BigInt64Array load+store round-trips
// Node 24.18.0 / V8 13.6.233.17-node.50, linux x64
//
// Scenarios:
//   plain*  : operands/results live in BigInt variables ("natural" arithmetic)
//   typed*  : operands loaded from BigInt64Array, result immediately stored
//             back into it (the exact pattern in question)
//   *Obs    : also reads the stored result back as a BigInt every iteration
//   loadOnly/storeOnly: isolate the array<->BigInt boundary costs
// ============================================================================
import { performance } from 'node:perf_hooks';

const MASK = (1n << 64n) - 1n;
const A   = 1234567890123456789n; // ~2^60 (single 64-bit limb)
const SM  = 5n;                   // tiny operand: t stays single-limb for n<=2^28
const MA  = 1234567890n;          // ~2^30 multiplier (MA*MA < 2^64)
const S   = 1234567n;             // divisor ~2^20
const BIG = (1n << 511n) | 123456789n; // 512-bit (impossible in BigInt64Array)

let sink = 0n;

// ---- correctness verification (mod-2^64 semantics) -------------------------
{
  const M64 = 1n << 64n;
  const refMod = v => { v %= M64; return v >= (1n << 63n) ? v - M64 : v; };
  const arr = new BigInt64Array(3);
  arr[0] = A; arr[1] = MA; arr[2] = 0n;
  for (let i = 0; i < 1000; i++) arr[2] = arr[2] + arr[0];
  const gotAdd = arr[2], wantAdd = refMod(BigInt(1000) * A);
  arr[2] = 1n;
  for (let i = 0; i < 1000; i++) arr[2] = arr[2] * arr[0];
  const gotMul = arr[2], wantMul = refMod(A ** 1000n);
  if (gotAdd !== wantAdd || gotMul !== wantMul) throw new Error('semantics mismatch');
  console.log(`[verify] mod-2^64 add/mul semantics OK (${gotAdd}, ${gotMul})`);
}

// ---- case kernels (each: run n iterations, return checksum) ----------------
const kPlainAddSmall = n => { let t = 0n; const a = SM; for (let i = 0; i < n; i++) t += a; return t; };
const kPlainAddGrow  = n => { let t = 0n; const a = A;  for (let i = 0; i < n; i++) t += a; return t; };
const kPlainAddMask  = n => { let t = 0n; const a = A;  for (let i = 0; i < n; i++) t = (t + a) & MASK; return t; };

const kTypedAdd = n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
};
const kTypedAddObs = n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; }
  return c ^ arr[0];
};
const kLoadOnly = n => {
  const arr = new BigInt64Array(3); arr[0] = A;
  let t = 0n;
  for (let i = 0; i < n; i++) t += arr[0];
  return t ^ arr[1];
};
const kStoreOnly = n => {
  const arr = new BigInt64Array(3);
  let t = 0n; const a = A;
  for (let i = 0; i < n; i++) { t = (t + a) & MASK; arr[2] = t; }
  return arr[2] ^ t;
};

const kPlainMulMask = n => { let t = 1n; const a = MA; for (let i = 0; i < n; i++) t = (t * a) & MASK; return t; };
const kTypedMul = n => {
  const arr = new BigInt64Array(3); arr[0] = MA; arr[2] = 1n;
  for (let i = 0; i < n; i++) arr[2] = arr[2] * arr[0];
  return arr[2] ^ arr[1];
};
const kTypedMulObs = n => {
  const arr = new BigInt64Array(3); arr[0] = MA; arr[2] = 1n;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = arr[2] * arr[0]; c ^= arr[2]; }
  return c ^ arr[1];
};

const kPlainDiv = n => { let t = 0n; const a = A, s = S; for (let i = 0; i < n; i++) t = (t + a) / s; return t; };
const kTypedDiv = n => {
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = S;
  for (let i = 0; i < n; i++) arr[2] = (arr[2] + arr[0]) / arr[1];
  return arr[2] ^ arr[0];
};
const kTypedDivObs = n => {
  const arr = new BigInt64Array(3); arr[0] = A; arr[1] = S;
  let c = 0n;
  for (let i = 0; i < n; i++) { arr[2] = (arr[2] + arr[0]) / arr[1]; c ^= arr[2]; }
  return c ^ arr[0];
};

const kPlainBigAdd = n => { let t = 0n; const a = BIG; for (let i = 0; i < n; i++) t = (t + a) & MASK; return t; };

// ---- harness ------------------------------------------------------------------
function measure(name, fn) {
  fn(1 << 20); // warmup / JIT
  let iters = 1 << 23;
  { // calibrate to ~250 ms per trial
    const st = performance.now(); fn(iters);
    iters = Math.max(1 << 20, Math.min(1 << 28, Math.round(250 / ((performance.now() - st) / iters))));
  }
  fn(1 << 20); // re-warm at final shape
  const samples = [];
  for (let t = 0; t < 9; t++) {
    const st = performance.now();
    const c = fn(iters);
    samples.push(performance.now() - st);
    sink ^= c;
  }
  const s = [...samples].sort((x, y) => x - y);
  const ns = (s[s.length >> 1] * 1e6) / iters;
  console.log(`${name.padEnd(38)} ${(1000 / ns).toFixed(2).padStart(9)} MOPS  ${ns.toFixed(2).padStart(8)} ns/op`);
  return ns;
}

console.log(`node ${process.version}  ${process.platform}/${process.arch}  (V8 ${process.versions.v8})`);
console.log('-'.repeat(62));

const r = {};
r.plainAddSmall = measure('plain add (t += 5n, stays 1 limb)', kPlainAddSmall);
r.plainAddGrow  = measure('plain add (t += ~2^60, grows to 2 limbs)', kPlainAddGrow);
r.plainAddMask  = measure('plain add + manual 64-bit wrap (& MASK)', kPlainAddMask);
r.typedAdd      = measure('typed add: arr[2] = arr[2] + arr[0]', kTypedAdd);
r.typedAddObs   = measure('typed add (above) + read back every iter', kTypedAddObs);
r.loadOnly      = measure('boundary load: t += arr[0] (result local)', kLoadOnly);
r.storeOnly     = measure('boundary store: arr[2] = (t+a)&MASK', kStoreOnly);

r.plainMulMask  = measure('plain mul + manual 64-bit wrap', kPlainMulMask);
r.typedMul      = measure('typed mul: arr[2] = arr[2] * arr[0]', kTypedMul);
r.typedMulObs   = measure('typed mul + read back every iter', kTypedMulObs);

r.plainDiv      = measure('plain div: t = (t + a) / s', kPlainDiv);
r.typedDiv      = measure('typed div: arr[2] = (arr[2]+arr[0])/arr[1]', kTypedDiv);
r.typedDivObs   = measure('typed div + read back every iter', kTypedDivObs);

r.plainBigAdd   = measure('plain add, 512-bit operands (array can\'t)', kPlainBigAdd);

console.log('-'.repeat(62));
const faster = (a, b) => `${(a / b).toFixed(1)}x faster`; // a=plain ns, b=typed ns
console.log('Head-to-head, same 64-bit-range semantics (lower is faster):');
console.log(`  add  plain(t+=5n) ${r.plainAddSmall.toFixed(2)}ns  vs  typed RMW ${r.typedAdd.toFixed(2)}ns  -> typed ${faster(r.plainAddSmall, r.typedAdd)}`);
console.log(`       plain + manual wrap ${r.plainAddMask.toFixed(2)}ns vs typed RMW+readback ${r.typedAddObs.toFixed(2)}ns -> typed ${faster(r.plainAddMask, r.typedAddObs)}`);
console.log(`  mul  plain + manual wrap ${r.plainMulMask.toFixed(2)}ns vs typed RMW ${r.typedMul.toFixed(2)}ns -> typed ${faster(r.plainMulMask, r.typedMul)}`);
console.log(`  div  plain ${r.plainDiv.toFixed(2)}ns vs typed RMW ${r.typedDiv.toFixed(2)}ns -> typed ${faster(r.plainDiv, r.typedDiv)}`);
console.log('Boundary crossing (kills the native fast path):');
console.log(`  load element -> BigInt variable: ${r.loadOnly.toFixed(2)}ns vs plain add(growing) ${r.plainAddGrow.toFixed(2)}ns -> materializing costs ~${(r.loadOnly - r.plainAddGrow).toFixed(2)}ns extra`);
console.log(`  store BigInt variable -> element: store adds ~${Math.max(0, r.storeOnly - r.plainAddMask).toFixed(2)}ns on top of plain add+wrap`);
console.log('Context:');
console.log(`  plain 512-bit add (BigInt64Array impossible): ${r.plainBigAdd.toFixed(2)}ns/op`);
console.log(`checksum: ${sink.toString(16).slice(0, 8)}`);
