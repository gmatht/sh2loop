// bench-polyfills.mjs — polyfill vs hand-written runtime benchmark
// (CROSS_BACKEND_RUNTIME.md M2).
//
// Usage: node bench-polyfills.mjs <polyfills.estree.json>
//
// Loads the transpiled polyfill JS (which registers the functions via
// sh2.functions.set and runs the self-test calls), then benchmarks each
// polyfill function through the adapter
//   sh2.captureSync(() => sh2.fnCall(name, [args]))
// against the hand-written sh2-namespace.mjs function, on the same
// inputs. Reports ops/sec for both. The self-test output is discarded
// (the module's stdout is captured and dropped).

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { generate } from '../harness/estree-gen.mjs';

const jsonPath = process.argv[2];
if (!jsonPath) {
  console.error('usage: node bench-polyfills.mjs <polyfills.estree.json>');
  process.exit(2);
}
const program = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const js = generate(program);

const nsPath = path.join(import.meta.dirname, '..', 'harness', 'sh2-namespace.mjs');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sh2bench-'));
const resultFile = path.join(tmpDir, 'result.json');

// The benchmark module: import the reference runtime, register the
// transpiled polyfill functions, then measure both paths.
const moduleSrc = `
import { sh2 } from ${JSON.stringify(nsPath)};
sh2._init("bench", []);
${js}
// ── benchmark ────────────────────────────────────────────────────────
const bench = (label, fn, inputs, iters) => {
  // warmup
  for (let i = 0; i < 2000; i++) for (const x of inputs) fn(x);
  const t0 = process.hrtime.bigint();
  let sink = 0;
  for (let i = 0; i < iters; i++) for (const x of inputs) sink += String(fn(x)).length;
  const t1 = process.hrtime.bigint();
  const secs = Number(t1 - t0) / 1e9;
  return { label, opsPerSec: Math.round((iters * inputs.length) / secs), sink };
};

// The transpiled polyfill functions write their result to stdout (bash
// convention) — via the NATIVE echo path (process.stdout.write), which
// bypasses the runtime's captureSync (fdTargets). The adapter sinks
// process.stdout.write into a buffer and returns the captured value.
// POST echo-return-lifting (CROSS_BACKEND_RUNTIME.md §8.3): the
// eligible functions RETURN their value natively, so the adapter
// dispatches through sh2.fnValue directly — no stdout sink, no
// newline strip (the benchmarked five are all lifted;
// globMatch/caseMatch/param keep the stdout convention — the bench
// does not touch them).
const polyValue = (name, args) => sh2.fnValue(name, args);

const paths = ["/foo", "a/b", "foo", "a/b/", "/", "", "a//b", "a///b", "a/b//", "//", "///", "a//", "a/", "a/b/c", "/a/b/", "x/y/z/"];
const strs = ["hello", "", "a b c", "hello world", "the quick brown fox", "x".repeat(100), "a".repeat(1000)];
const pairs = [["hello", "he"], ["hello", "x"], ["hello world", "lo w"], ["hello world", "xyz"], ["abc", ""], ["", ""], ["x".repeat(1000), "y".repeat(500)]];

const ITERS = 20000;
const out = [];

// basename
out.push(bench("basename.ref",  (x) => sh2.basename(x), paths, ITERS));
out.push(bench("basename.poly", (x) => polyValue("basename", [x]), paths, ITERS));
// dirname
out.push(bench("dirname.ref",  (x) => sh2.dirname(x), paths, ITERS));
out.push(bench("dirname.poly", (x) => polyValue("dirname", [x]), paths, ITERS));
// strLen
out.push(bench("strLen.ref",  (x) => String(sh2.strLen(x)), strs, ITERS));
out.push(bench("strLen.poly", (x) => polyValue("strLen", [x]), strs, ITERS));
// contains
out.push(bench("contains.ref",  ([h, n]) => sh2.contains(h, n), pairs, ITERS));
out.push(bench("contains.poly", ([h, n]) => polyValue("contains", [h, n]), pairs, ITERS));
// strHasPrefix
out.push(bench("strHasPrefix.ref",  ([s, p]) => String(s).startsWith(String(p)), pairs, ITERS));
out.push(bench("strHasPrefix.poly", ([s, p]) => polyValue("strHasPrefix", [s, p]), pairs, ITERS));

// _installStdoutBuffer swallows console.log (flushed only at _finish) —
// write the JSON to a file instead.
import { writeFileSync } from 'node:fs';
writeFileSync(${JSON.stringify(path.join(tmpDir, 'result.json'))}, JSON.stringify(out, null, 2));
`;

const modFile = path.join(tmpDir, 'bench.mjs');
fs.writeFileSync(modFile, moduleSrc);
try {
  // stdout to a file (the self-test calls print; the JSON goes to result.json)
  const fd = fs.openSync(path.join(tmpDir, 'stdout.txt'), 'w');
  execFileSync(process.execPath, [modFile], { stdio: ['ignore', fd, 'inherit'] });
  fs.closeSync(fd);
} catch (e) {
  console.error('benchmark module failed:', e.message);
  process.exit(1);
}
process.stdout.write(fs.readFileSync(resultFile, 'utf8'));
