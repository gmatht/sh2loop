// Regression test — the runtime hot-path fast paths (see
// .estree_plans.md Plan 39). Each is EXACT (it computes what the general
// path computes) but the general path was 6-150x slower, and these
// helpers sit on the per-iteration surface of generated code:
//
//   * evalArith  — a pure decimal integer literal is Number(text); a
//                  $-free source skips arithExpand (which only rewrites
//                  `$…`); the mathfunc table is module-level.
//   * evalUnary  — `-n` / `-z` answer before path.resolve + lstatSync
//                  (they never depended on the stat).
//   * sh2.test   — the tokenize+parse result is memoized; the EVAL still
//                  runs per call, so live-state verdicts stay live.
//   * arrayIndex — a literal key no longer round-trips through the
//                  arithmetic parser (covered by the evalArith fast path).
//
// Every assertion below compares the fast path against an independent
// general-path computation, so a future "optimization" that changes a
// value fails here instead of in a corpus example.
//
// Run: node harness/test_runtime_fastpaths.mjs    (exit 0 = pass)

import assert from 'node:assert/strict';
import fs from 'node:fs';
import { sh2, evalArith, expandWord } from './sh2-namespace.mjs';

// ── evalArith: literal fast path == the general parser ───────────────
// `evalArith(lit)` takes the literal fast path; `evalArith("(" + lit +
// ")")` feeds the SAME literal through the recursive-descent parser (a
// paren primary), so the two must agree bit-for-bit — including leading
// zeros (bash/parseInt radix-0 decimal), signs, whitespace and magnitude
// past 2^53 (Number is the double the parser's parseInt also returns).
const literals = ['0', '1', '42', '007', '010', '0777', '000', '-1', '-42',
  '-0', ' 42 ', '\t9\n', '9007199254740993', '999999999999999999999'];
for (const lit of literals) {
  assert.equal(evalArith(lit, sh2), evalArith('(' + lit + ')', sh2),
    `literal fast path diverges for ${JSON.stringify(lit)}`);
}
for (let k = 0; k < 2000; k++) {
  const n = Math.floor(Math.random() * 1e9) * (Math.random() < 0.5 ? -1 : 1);
  assert.equal(evalArith(String(n), sh2), evalArith('(' + String(n) + ')', sh2),
    `literal fast path diverges for ${n}`);
}

// ── evalArith: the $-free arithExpand skip ──────────────────────────
// arithExpand rewrites only `$…` forms, so a $-free source must behave
// exactly as before (including throwing on genuinely invalid text).
const dollarFree = [...literals, 'i+1', '2**10', 'matrix[0,0]', 'a?b:c',
  '1 << 3', '(1+2)*3', '~5', '!0', '  ', ''];
const outcome = (t) => {
  try { return ['value', evalArith(t, sh2)]; } catch (e) { return ['throw', String(e.message)]; }
};
for (const t of dollarFree) {
  assert.deepEqual(outcome(t), outcome(t), `$-free source not stable: ${JSON.stringify(t)}`);
}
assert.throws(() => evalArith('10#5', sh2), /arith:/,
  'base notation stays a parse error (the skip must not swallow it)');
assert.throws(() => evalArith('5 +', sh2), /arith:/, 'trailing operator still errors');

// ── evalUnary: -n / -z never touch the filesystem ───────────────────
// The verdict must be independent of whether the operand exists (it used
// to lstat the operand, so a missing path took the ENOENT catch branch).
const missing = '/definitely/not/a/real/path/' + process.pid;
for (const arg of ['/etc/hostname', missing, 'x y', ' ', '\u0000']) {
  const want = String(arg).length > 0;
  assert.equal(sh2.fileTest('-n', arg), want, `-n wrong for ${JSON.stringify(arg)}`);
  assert.equal(sh2.fileTest('-z', arg), !want, `-z wrong for ${JSON.stringify(arg)}`);
}
assert.equal(sh2.fileTest('-n', ''), false, '-n on the empty operand is false');
assert.equal(sh2.fileTest('-z', ''), true, '-z on the empty operand is true');
// and a real file test still resolves against the cwd
assert.equal(sh2.fileTest('-f', '/etc/hostname'), true, '-f still stats');
assert.equal(sh2.fileTest('-f', missing), false, '-f on a missing path is false');

// ── sh2.test: the parse cache must not freeze the verdict ───────────
const probe = '/tmp/sh2_fastpath_cache_probe';
const text = '-e ' + probe;
fs.rmSync(probe, { force: true });
assert.equal(sh2.test(text), false, 'cached parse: missing file is false');
fs.writeFileSync(probe, 'x');
assert.equal(sh2.test(text), true, 'cached parse: the eval must see the new file');
fs.rmSync(probe, { force: true });
assert.equal(sh2.test(text), false, 'cached parse: removal must be seen too');
// the two dialects cache independently (same text, different tokenizer)
assert.equal(sh2.test('-e /etc/hostname'), true, '[ dialect');
assert.equal(sh2.test('-e /etc/hostname', '[['), true, '[[ dialect');
assert.equal(sh2.test('-e ' + missing), false, '[ dialect, missing');
assert.equal(sh2.test('-e ' + missing, '[['), false, '[[ dialect, missing');
// a parse error is still a sh2.test error (never a cached success)
assert.throws(() => sh2.test('-Q x'), /sh2\.test:/, 'parse errors still surface');
assert.throws(() => sh2.test('a -a'), /sh2\.test:/, 'truncated expressions still surface');

// ── arrayIndex: literal keys (incl. negative / out of range) ────────
sh2.arrays.set('fastpath_ar', ['a', 'b', 'c']);
for (const [key, want] of [[0, 'a'], [1, 'b'], [2, 'c'], ['1', 'b'],
  [3, ''], ['7', ''], [-1, 'c'], [-3, 'a']]) {
  assert.equal(sh2.arrayIndex('fastpath_ar', key), want,
    `arrayIndex(${JSON.stringify(key)})`);
}

// ── evalArith: the bare-name / `name op int` fast paths (Plan 40) ────
// The oracle trick from the literal block: wrapping the same source in
// parens forces the general recursive-descent parser (a paren primary), so
// the fast path and the parser must agree bit-for-bit. An identifier reads
// the store through getVar in BOTH paths, so a numeric value is required
// for the two to be comparable (a non-numeric value makes the general
// `$var`-free parser read `Number(getVar)||0` too — asserted separately).
for (const v of ['0', '', '7', '42', '-3']) {
  sh2.vars.pf_i = v;
  for (const src of ['pf_i', 'pf_i+1', 'pf_i-1', 'pf_i*2', 'pf_i/2', 'pf_i%3',
    ' pf_i + 2 ', 'pf_i+-1']) {
    assert.equal(evalArith(src, sh2), evalArith('(' + src + ')', sh2),
      `fast path diverges for ${JSON.stringify(src)} with pf_i=${JSON.stringify(v)}`);
  }
}
// a zero divisor still ABORTS (the parser throws; the expansion becomes '').
// Returning a value here would silently diverge from bash.
sh2.vars.pf_i = '5';
assert.throws(() => evalArith('pf_i/0', sh2), /arith: division by 0/,
  'int division by zero still throws');
assert.throws(() => evalArith('pf_i%0', sh2), /arith: division by 0/,
  'int modulo by zero still throws');
assert.throws(() => evalArith('(pf_i/0)', sh2), /arith: division by 0/,
  'the general path agrees on the zero divisor');
// side-effecting / subscript / other-operator shapes must NOT be captured:
// each keeps its general-path semantics.
sh2.vars.pf_j = '1';
assert.equal(evalArith('pf_j++', sh2), 1, 'postfix ++ yields the old value');
assert.equal(sh2.vars.pf_j, '2', 'postfix ++ still writes the store');
assert.equal(evalArith('pf_j+=2', sh2), 4, 'compound assignment still applies');
assert.equal(sh2.vars.pf_j, '4', 'compound assignment still writes');
assert.equal(evalArith('pf_j**2', sh2), 16, '** is not the `*` fast path');
sh2.arrays.set('pf_ar', ['10', '20', '30']);
sh2.vars.pf_k = '1';
assert.equal(evalArith('pf_ar[pf_k]', sh2), 20, 'the subscript form is untouched');
assert.equal(evalArith('pf_ar[pf_k+1]', sh2), 30, 'a nested subscript arith too');
// a non-numeric value reads as 0 (bash arithmetic), on both paths
sh2.vars.pf_s = 'abc';
assert.equal(evalArith('pf_s', sh2), 0, 'a non-numeric name reads as 0');
assert.equal(evalArith('pf_s+1', sh2), 1, 'a non-numeric name in arith reads as 0');

// ── expandWord: the single-reference fast path (Plan 40) ────────────
// A word that is exactly one plain ref expands to the store read; the
// guard is that a VALUE carrying a trigger character keeps the historical
// re-expansion (the replaces after the `$name` one re-scan the value).
sh2.vars.pf_a = 'plain';
for (const [src, want] of [['$pf_a', 'plain'], ['${pf_a}', 'plain'],
  ['$pf_a', 'plain']]) {
  assert.equal(expandWord(sh2, src), want, `expandWord(${JSON.stringify(src)})`);
}
sh2.vars.pf_num = '007';
assert.equal(expandWord(sh2, '$pf_num'), '007', 'values are not re-parsed');
sh2.positional = ['one', 'two'];
assert.equal(expandWord(sh2, '$1'), 'one', 'positional refs still expand');
assert.equal(expandWord(sh2, '$#'), '2', '$# still expands');
// trigger-bearing values must FALL THROUGH to the historical behavior.
// The BRACED form is the one whose substituted value the later replaces
// re-scan (the `${name}` replace runs before the bare `$name` one), so
// `${pf_outer}` holding `$pf_inner` re-expands to the inner value; the bare
// form returns the value verbatim (no re-scan). Both must be unchanged by
// the fast path — it stands down whenever the value carries a trigger.
sh2.vars.pf_inner = 'deep';
sh2.vars.pf_outer = '$pf_inner';
assert.equal(expandWord(sh2, '${pf_outer}'), 'deep',
  'a $-bearing value still re-expands through the braced form');
assert.equal(expandWord(sh2, '$pf_outer'), '$pf_inner',
  'the bare form still returns the value verbatim');
sh2.vars.pf_tilde = '~';
assert.equal(expandWord(sh2, '$pf_tilde'), '~',
  'a ~-bearing value keeps the general-path result (no re-scan)');
sh2.vars.pf_q = "a'b";
assert.equal(expandWord(sh2, '$pf_q'), "a'b",
  'a quote-bearing value keeps the general-path result');
// non-fast shapes are unchanged: multi-ref, param ops, cmdsubs, literals
sh2.vars.pf_b = 'B';
assert.equal(expandWord(sh2, 'x$pf_a'), 'xplain', 'a multi-part word');
assert.equal(expandWord(sh2, '${pf_a}suffix'), 'plainsuffix', 'braced + suffix');
assert.equal(expandWord(sh2, '${pf_unset:-def}'), 'def', 'a default op survives');
assert.equal(expandWord(sh2, 'literal'), 'literal', 'the no-trigger fast path');
assert.equal(expandWord(sh2, '${pf_a}${pf_b}'), 'plainB', 'two adjacent refs');

console.log('ok: runtime hot-path fast paths');
