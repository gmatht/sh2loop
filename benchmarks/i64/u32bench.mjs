// u32 arithmetic idioms for the C backend: "unsigned int" mapped to JS Numbers.
// Standard technique (asm.js/emscripten): keep u32 values as int32 bit patterns
// (`x | 0`), use Math.imul for multiply, `>>>` for u32 shifts, and the XOR
// 0x80000000 trick for unsigned comparison. Unsigned division is the hard case.
// Usage: node u32bench.mjs
import { performance } from 'node:perf_hooks';

const A32 = (3000000000) | 0; // u32 3e9 stored as i32 bits (-1294967296)
const S32 = 1234567;          // small addend (< 2^31: fast paths apply)
const D32 = 1234567;          // divisor (< 2^31)
const M32 = (2000000000) | 0; // u32 2e9 as i32 bits

// ---- correctness of the u32 idioms (must all agree) ------------------------
{
  let xorOk = true, imulOk = true, roundtripOk = true, divOk = true;
  for (let i = 0; i < 100000; i++) {
    const a = (Math.random() * 0x100000000) | 0;
    const b = (Math.random() * 0x100000000) | 0;
    // unsigned comparison: XOR trick vs naive >>>0
    if (((a ^ 0x80000000) < (b ^ 0x80000000)) !== ((a >>> 0) < (b >>> 0))) xorOk = false;
    // u32 multiply via Math.imul vs BigInt reference (mod 2^32, then to signed)
    let p = (BigInt(a >>> 0) * BigInt(b >>> 0)) & 0xffffffffn;
    if (p >= (1n << 31n)) p -= 1n << 32n;
    if (BigInt(Math.imul(a, b)) !== p) imulOk = false;
    // round-trip: |0 -> >>>0 -> |0
    if ((a >>> 0 | 0) !== a) roundtripOk = false;
    // u32 division: naive >>>0 form vs BigInt reference
    const q = (a >>> 0) / (b >>> 0) | 0;
    const qwant = Number(BigInt(a >>> 0) / BigInt(b >>> 0));
    if (q !== qwant) divOk = false;
  }
  console.log(`[verify] XOR-compare==u-compare: ${xorOk}  imul==u32-mul: ${imulOk}  |0/>>>0 roundtrip: ${roundtripOk}  u32-div==BigInt: ${divOk}`);
}

let sink = 0;   // Number checksum
let sinkB = 0n; // BigInt checksum
function bench(name, fn) {
  fn(1 << 20); fn(1 << 20);
  const it = 1 << 26;
  const s = [];
  for (let k = 0; k < 9; k++) {
    const st = performance.now();
    const v = fn(it);
    s.push(performance.now() - st);
    if (typeof v === 'bigint') sinkB ^= v; else sink += v;
  }
  s.sort((a, b) => a - b);
  const ns = (s[4] * 1e6) / it;
  console.log(`${name.padEnd(48)} ${(1000 / ns).toFixed(1).padStart(8)} MOPS ${ns.toFixed(2).padStart(8)} ns/op`);
  return ns;
}

const r = {};
console.log(`node ${process.version} (V8 ${process.versions.v8})`);
console.log('-'.repeat(68));

// ---- u32/i32 arithmetic (bit-identical for add/sub/mul/bitwise) ------------
r.u32Add  = bench('u32 add  t=(t+A32)|0  (A32 >= 2^31)', n => {
  let t = 0; const a = A32; for (let i = 0; i < n; i++) t = (t + a) | 0; return t;
});
r.i32Add  = bench('i32 add  t=(t+5)|0  (stays in Smi range)', n => {
  let t = 0; const a = 5; for (let i = 0; i < n; i++) t = (t + a) | 0; return t;
});
r.u32Mul  = bench('u32 mul  t=Math.imul(t,M32)', n => {
  let t = 1; const a = M32; for (let i = 0; i < n; i++) t = Math.imul(t, a); return t;
});
r.u32Shl  = bench('u32 shl  t=(t<<5)|0 / shr t>>>(5)', n => {
  let t = 1; for (let i = 0; i < n; i++) { t = (t << 5) | 0; t = t >>> 3; } return t;
});

// ---- division: the problem child -------------------------------------------
r.divLo   = bench('div fast t=(t+S32)/D32|0  (both <2^31)', n => {
  let t = 0; const s = S32, d = D32; for (let i = 0; i < n; i++) t = (t + s) / d | 0; return t;
});
r.divU32  = bench('div u32  t=((t+A32)>>>0)/(D32>>>0)|0', n => {
  let t = 0; const a = A32, d = D32; for (let i = 0; i < n; i++) t = ((t + a) >>> 0) / (d >>> 0) | 0; return t;
});
r.modU32  = bench('mod u32  t=((t+A32)>>>0)%(D32>>>0)|0', n => {
  let t = 0; const a = A32, d = D32; for (let i = 0; i < n; i++) t = ((t + a) >>> 0) % (d >>> 0) | 0; return t;
});
r.divGuard = bench('div guard t=u<0?(u>>>0)/d|0:u/d|0 (u>=2^31)', n => {
  let t = 0; const a = A32, d = D32;
  for (let i = 0; i < n; i++) { const u = t + a; t = u < 0 ? (u >>> 0) / d | 0 : u / d | 0; }
  return t;
});

// ---- unsigned comparison -----------------------------------------------------
r.cmpXor = bench('u32 cmp  (t^0x80000000)<(d^0x80000000)', n => {
  let t = 0; const d = A32; // d >= 2^31 forces the unsigned case
  for (let i = 0; i < n; i++) t = (t ^ 0x80000000) < (d ^ 0x80000000) ? (t + 1) | 0 : (t - 1) | 0;
  return t;
});
r.cmpNaive = bench('u32 cmp  (t>>>0)<(d>>>0)', n => {
  let t = 0; const d = A32;
  for (let i = 0; i < n; i++) t = (t >>> 0) < (d >>> 0) ? (t + 1) | 0 : (t - 1) | 0;
  return t;
});

// ---- divergence points: leaving the int32 domain ----------------------------
// Same bits; the difference is how the sign bit is read when the value crosses
// out of the machine-int domain (to Number, to BigInt, or into typed storage).
r.numI32 = bench('read as i32:  t += x (identity)', n => {
  let t = 0; let x = A32; for (let i = 0; i < n; i++) { x = (x + 1) | 0; t += x; } return t;
});
r.numU32 = bench('read as u32:  t += (x >>> 0)   [HeapNumber >=2^31]', n => {
  let t = 0; let x = A32; for (let i = 0; i < n; i++) { x = (x + 1) | 0; t += x >>> 0; } return t;
});
r.bigI32 = bench('promote i32:  b += BigInt(x) (sign-extend)', n => {
  let b = 0n; let x = A32; for (let i = 0; i < n; i++) { x = (x + 1) | 0; b += BigInt(x); } return b;
});
r.bigU32 = bench('promote u32:  b += BigInt(x >>> 0) (zero-extend)', n => {
  let b = 0n; let x = A32; for (let i = 0; i < n; i++) { x = (x + 1) | 0; b += BigInt(x >>> 0); } return b;
});
r.arrI32 = bench('Int32Array RMW add (i32 storage)', n => {
  const arr = new Int32Array(3); arr[0] = A32;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
});
r.arrU32 = bench('Uint32Array RMW add (u32 storage)', n => {
  const arr = new Uint32Array(3); arr[0] = A32;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
});

// ---- references: the i64 lanes from the other benchmarks ---------------------
r.bigAdd = bench('ref: plain BigInt add (1 limb)', n => {
  let t = 0n; const a = 5n; for (let i = 0; i < n; i++) t += a; return t;
});
r.i64arr = bench('ref: BigInt64Array add (load+store)', n => {
  const arr = new BigInt64Array(3); arr[0] = 1234567890123456789n;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
});
r.u64arr = bench('ref: BigUint64Array add (load+store)', n => {
  const arr = new BigUint64Array(3); arr[0] = 1234567890123456789n;
  for (let i = 0; i < n; i++) arr[2] = arr[2] + arr[0];
  return arr[2] ^ arr[0];
});
r.f64Add = bench('ref: f64 add (t += a)', n => {
  let t = 0; const a = 1.5e9; for (let i = 0; i < n; i++) t += a; return t;
});

console.log('-'.repeat(68));
console.log('head-to-head (u32 lane vs the i64 lanes):');
const row = (label, v) => console.log(`  ${label.padEnd(34)} ${v.toFixed(2)} ns/op`);
row('i32 add (Smi range)', r.i32Add); row('u32 add (>= 2^31)', r.u32Add); row('u32 mul', r.u32Mul);
row('div (signed)', r.divLo); row('div (u32 >>>0)', r.divU32); row('mod (u32 >>>0)', r.modU32);
row('cmp (naive >>>0)', r.cmpNaive); row('cmp (XOR trick)', r.cmpXor);
console.log('divergence points (leaving the int32 domain):');
row('read as i32 (identity)', r.numI32); row('read as u32 (x >>> 0)', r.numU32);
row('promote i32 -> BigInt', r.bigI32); row('promote u32 -> BigInt', r.bigU32);
row('Int32Array storage', r.arrI32); row('Uint32Array storage', r.arrU32);
row('plain BigInt add', r.bigAdd); row('BigInt64Array add', r.i64arr);
row('BigUint64Array add', r.u64arr); row('f64 add', r.f64Add);
console.log(`sink: ${sink} / ${sinkB.toString(16).slice(0, 8)}`);
