import { readFileSync } from "node:fs";
const load = async (f, imp) => (await WebAssembly.instantiate(readFileSync(f), imp)).instance.exports;
const N = 100_000_000, M = 100_000;
const time = (fn) => { for (let i = 0; i < 3; i++) fn(); let best = Infinity; for (let i = 0; i < 5; i++) { const t0 = performance.now(); fn(); best = Math.min(best, performance.now() - t0); } return best; };
const tcc = await load("h2h_tcc.wasm", { wasi_snapshot_preview1: { fd_write: () => 0, proc_exit: () => 0 } });
const emcc = await load("h2h_emcc.wasm");
for (const [name, w] of [["tcc fork ", tcc], ["emcc -O3 ", emcc]]) {
  const m = new BigInt64Array(w.memory.buffer);
  for (let i = 0; i < 1024; i++) m[i] = BigInt(i % 5 + 1);
  for (let i = 0; i < M; i++) m[i] = BigInt(i);  // M*8 = 800KB fits the tcc wasm's fixed 1MB
  const tLoop = time(() => w.runLoopDep(N, 0));
  const tSum = time(() => w.memSum(0, M));
  console.log(`${name} loop_dep(100M): ${(tLoop * 1e6 / N).toFixed(2)} ns/iter   mem_sum(100k): ${(tSum * 1e6 / M).toFixed(2)} ns/elem`);
}
// BigInt baseline
let a = 0n; const M64 = 0xFFFFFFFFFFFFFFFFn;
const m = new BigInt64Array(tcc.memory.buffer);
for (let i = 0; i < 1024; i++) m[i] = BigInt(i % 5 + 1);
const tBig = time(() => { a = 0n; for (let i = 0; i < 2_000_000; i++) a = (a * m[i & 1023] + 1n) & M64; });
console.log(`BigInt  loop(2M):  ${(tBig * 1e6 / 2e6).toFixed(2)} ns/iter`);
