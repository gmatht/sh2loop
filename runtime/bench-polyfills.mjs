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

// ── extended coverage (remaining-optimizations goal, item 4) ──────────
// globMatch / param are now echo-return-lifted (the previous goal's
// glob-matcher lift); headLines too. caseMatch / line_at are NOT lifted
// (their no-match path emits nothing) — benchmarked via the slow
// stdout-capture path to size the remaining gap (item 2 blocker).
const globs = [["*.txt", "file.txt"], ["*.txt", "file.md"], ["a*", "abc"], ["*b*", "abc"], ["x", "y"], ["file.*", "file.txt"], ["[abc]", "b"], ["?", "x"], ["**", "a/b/c"], ["foo", "foo"]];
const params = [["len", "", "", "HelloWorld"], ["^^", "", "", "hello"], [",,", "", "", "HELLO"], ["^", "", "", "world"], [":-", "", "", ""], ["#", "", "", "file.txt"], ["##", "", "", "file.txt"], ["%", "", "", "file.txt"], ["%%", "", "", "file.txt"], ["slice", "2", "5", "HelloWorld"]];
const paramArgs = ["", "", "", "", "", "", "", "", "", "2,5"];
const NL = String.fromCharCode(10);
const multi = ["a"+NL+"b"+NL+"c"+NL+"d"+NL+"e", "one"+NL+"two"+NL+"three", "x".repeat(50)+NL+"y".repeat(50), "single", "", "line1"+NL+"line2"+NL+"line3"+NL+"line4"+NL+"line5"+NL+"line6"];
const cases = [["file.txt", ["*.md", "*.txt"]], ["file.md", ["*.md", "*.txt"]], ["hello", ["h*", "*o"]], ["hello", ["x*", "y*"]], ["abc", ["a*", "*c"]], ["", ["*"]]];
const idxs = [[multi[0], 2], [multi[0], 0], [multi[0], 99], [multi[1], 1], [multi[3], 0], [multi[5], 3]];

// headLines JS reference (split lines, first n, rejoin)
const headLinesRef = (s, n) => { const ls = String(s).split(NL); const k = n === "" ? ls.length : Number(n); return ls.slice(0, k).join(NL); };
// line_at JS reference (line k or empty)
const lineAtRef = (s, i) => { const ls = String(s).split(NL); return i >= 0 && i < ls.length ? ls[i] : ""; };
// globMatch JS reference (bash *, ?, [...] glob). A self-contained
// reference impl (not the runtime's hand-written matcher, which is a free
// fn not exposed on sh2; sh2-namespace.mjs is the worker's territory so we
// don't modify it here).
const globMatchRef = (pattern, value) => {
  const p = String(pattern), v = String(value);
  const match = (pi, vi) => {
    if (pi >= p.length) return vi >= v.length;
    if (p[pi] === '*') { for (let k = vi; k <= v.length; k++) if (match(pi + 1, k)) return true; return false; }
    if (vi >= v.length) return false;
    if (p[pi] === '?') return match(pi + 1, vi + 1);
    if (p[pi] === '[') {
      let j = pi + 1, neg = false;
      if (p[j] === '!') { neg = true; j++; }
      let hit = false;
      while (j < p.length && p[j] !== ']') { if (p[j] === v[vi]) hit = true; j++; }
      if (neg) hit = !hit;
      return hit && match(j + 1, vi + 1);
    }
    return p[pi] === v[vi] && match(pi + 1, vi + 1);
  };
  return match(0, 0);
};
// non-lifted polyfill capture (stdout path)
const polyCapture = (name, args) => sh2.captureSync(() => sh2.fnCall(name, args));

out.push(bench("globMatch.ref",  ([p, v]) => String(globMatchRef(p, v)), globs, ITERS));
out.push(bench("globMatch.poly", ([p, v]) => polyValue("globMatch", [p, v]), globs, ITERS));
out.push(bench("param.ref",  ([op, a, b, v]) => sh2.param(op, "", a, b, v), params, ITERS));
out.push(bench("param.poly", ([op, a, b, v]) => polyValue("param", [op, "", a, b, v]), params, ITERS));
out.push(bench("headLines.ref",  ([s, n]) => headLinesRef(s, n), idxs.map(([s, i]) => [s, String(i)]), ITERS));
out.push(bench("headLines.poly", ([s, n]) => polyValue("headLines", [s, n]), idxs.map(([s, i]) => [s, String(i)]), ITERS));
out.push(bench("caseMatch.ref",  ([v, ps]) => String(sh2.caseMatch(v, ps)), cases, ITERS));
out.push(bench("caseMatch.poly", ([v, ps]) => polyCapture("caseMatch", [v, ...ps]), cases, ITERS));
out.push(bench("line_at.ref",  ([s, i]) => lineAtRef(s, i), idxs, ITERS));
out.push(bench("line_at.poly", ([s, i]) => polyCapture("line_at", [s, String(i)]), idxs, ITERS));

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
