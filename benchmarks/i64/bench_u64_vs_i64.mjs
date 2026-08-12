'use strict';
// Coherent i64 vs u64 comparison: all cells, inline kernels, one harness.
import { performance } from 'node:perf_hooks';
const A = 1234567890123456789n, S = 1234567n;

function bench(T, op, obs) {
  const fn = (n) => {
    const arr = new T(3); arr[0] = A; arr[1] = S; arr[2] = op === 'mul' ? 1n : 0n;
    let c = 0n;
    if (op === 'add') {
      if (obs) { for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; c ^= arr[2]; } }
      else     { for (let i = 0; i < n; i++) { arr[2] = arr[2] + arr[0]; } }
    } else if (op === 'mul') {
      if (obs) { for (let i = 0; i < n; i++) { arr[2] = arr[2] * arr[0]; c ^= arr[2]; } }
      else     { for (let i = 0; i < n; i++) { arr[2] = arr[2] * arr[0]; } }
    } else {
      if (obs) { for (let i = 0; i < n; i++) { arr[2] = (arr[2] + arr[0]) / arr[1]; c ^= arr[2]; } }
      else     { for (let i = 0; i < n; i++) { arr[2] = (arr[2] + arr[0]) / arr[1]; } }
    }
    return c ^ arr[0];
  };
  fn(1 << 20); fn(1 << 20);
  // linearity
  const t = n => { const s = performance.now(); fn(n); return performance.now() - s; };
  const lin = (t(1 << 26) / t(1 << 25)).toFixed(1);
  const it = 1 << 26, s = [];
  for (let k = 0; k < 9; k++) { const st = performance.now(); fn(it); s.push(performance.now() - st); }
  s.sort((a, b) => a - b);
  return { ns: (s[4] * 1e6) / it, lin };
}

console.log(`node ${process.version} (V8 ${process.versions.v8})`);
console.log('op      variant   BigInt64Array  BigUint64Array  penalty  linearity(i/u)');
for (const op of ['add', 'mul', 'div']) {
  for (const obs of [false, true]) {
    const i = bench(BigInt64Array, op, obs);
    const u = bench(BigUint64Array, op, obs);
    console.log(`${op.padEnd(4)}  ${(obs ? 'readback' : 'RMW').padEnd(8)}  ${i.ns.toFixed(2).padStart(8)} ns   ${u.ns.toFixed(2).padStart(8)} ns   ${(u.ns / i.ns).toFixed(1)}x   ${i.lin}/${u.lin}`);
  }
}
