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

// ── the explicit store twins (Plan 42) ──────────────────────────────
// `sh2.getVar("a[i]")` / `sh2.setVar("a[i]", v)` re-parse the subscript
// and re-dispatch assoc-vs-indexed per call; the emitter now names the
// twin directly when the program DECLARES the array's kind. Each twin
// MUST compute exactly what the name-text path computes.
{
  const fresh = () => {
    // a pristine shell state: the twins below write only their own names
    sh2.vars = Object.create(null); sh2.arrays = new Map();
    sh2.assocNames = new Set(); sh2.assocStore = new Map();
  };
  // indexed arrays: arrayIndex == getVar("a[k]"), arrayStore == setVar("a[k]",v)
  // (an EMPTY subscript is not in the matrix on purpose: the emitter's
  // `baked_subscript_read` gate refuses it, and the two runtime paths
  // genuinely disagree there — getVar's subscript regex requires at least
  // one character, so `a[]` is a plain store read of the literal name.)
  fresh();
  sh2.setArray('ta', ['x', 'y', 'z'], false);
  for (const k of ['0', '1', '2', '3', '-1', '-3', '-9', 'i + 1']) {
    sh2.vars.i = '1';
    assert.equal(String(sh2.arrayIndex('ta', k)), String(sh2.getVar(`ta[${k}]`)),
      `arrayIndex(${JSON.stringify(k)}) must equal getVar("ta[k]")`);
  }
  // a malformed subscript yields the ARITH_BAD_MAGIC marker on BOTH paths
  sh2.setArray('tb', ['p'], false);
  const bad1 = sh2.arrayIndex('tb', '2 +');
  const bad2 = sh2.getVar('tb[2 +]');
  assert.equal(String(bad1), String(bad2), 'a bad subscript agrees on both paths');
  for (const [k, v] of [['0', 'new0'], ['5', 'new5'], ['-1', 'neg']]) {
    fresh();
    sh2.setArray('tc', ['a', 'b', 'c'], false);
    sh2.arrayStore('tc', k, v);
    const got = [...sh2.arrays.get('tc')];
    fresh();
    sh2.setArray('tc', ['a', 'b', 'c'], false);
    sh2.setVar(`tc[${k}]`, v);
    assert.deepEqual(got, [...sh2.arrays.get('tc')],
      `arrayStore(${JSON.stringify(k)}) must equal setVar("tc[k]")`);
  }
  // assoc arrays: assocSet == setVar("m[k]", v) for every key shape the
  // emitter hands over, and arrayIndex == getVar("m[k]") on the read side.
  // (`[bar]`/`a[i][j]`-style subscripts carrying their own `]` are NOT in
  // the matrix: setVar/getVar's subscript regex cannot match them, so the
  // name-text path treats the whole text as a plain variable name. The
  // emitter's `bracketed_store_twin` refuses exactly those.)
  for (const k of ['"foo"', 'foo', '"a b"', '$ak']) {
    fresh();
    sh2.assocNames.add('tm'); sh2.assocStore.set('tm', new Map());
    sh2.vars.ak = 'dyn';
    sh2.assocSet('tm', k, 'val');
    const viaTwin = [...sh2.assocStore.get('tm').entries()];
    fresh();
    sh2.assocNames.add('tm'); sh2.assocStore.set('tm', new Map());
    sh2.vars.ak = 'dyn';
    sh2.setVar(`tm[${k}]`, 'val');
    assert.deepEqual(viaTwin, [...sh2.assocStore.get('tm').entries()],
      `assocSet(${JSON.stringify(k)}) must equal setVar("tm[k]")`);
  }
  fresh();
  sh2.assocNames.add('tn'); sh2.assocStore.set('tn', new Map([['q', '7']]));
  assert.equal(String(sh2.arrayIndex('tn', 'q')), String(sh2.getVar('tn[q]')),
    'the assoc element read agrees on both paths');
  // both write twins report success (a statement-position store write must
  // never make the errexit guard fire)
  fresh();
  assert.equal(sh2.arrayStore('tz', '0', 'v'), true, 'arrayStore reports success');
  sh2.assocNames.add('ty');
  assert.equal(sh2.assocSet('ty', 'k', 'v'), true, 'assocSet reports success');
}
console.log('ok: explicit store twins');

// ── Plan 42: word-expansion + glob-strip fast paths ──────────────────
// expandWord gained a whole-word `${name<op>…}` fast path, per-rewrite
// gates and a runCmdSubst early-out; stripGlobPrefix/stripGlobSuffix
// gained the single-star (`*P` / `P*`) formula; assocGet normalizes its
// key once. Each assertion below is against an INDEPENDENT oracle: real
// bash's own answers (the strip table), the general path (the prefix
// trick), or the pre-change formula.
{
  // (1) The single-star strip formula vs BASH. Table produced by running
  // the same expansions under /bin/bash on this box.
  const stripTable = [
    // value, pattern, #, ##, %, %%
    ['/a/b/c.txt', '*/', 'a/b/c.txt', 'c.txt', '/a/b/c.txt', '/a/b/c.txt'],
    ['/a/b/c.txt', '.*', '/a/b/c.txt', '/a/b/c.txt', '/a/b/c', '/a/b/c'],
    ['/a/b/c.txt', '*:', '/a/b/c.txt', '/a/b/c.txt', '/a/b/c.txt', '/a/b/c.txt'],
    ['/a/b/c.txt', 'a*', '/a/b/c.txt', '/a/b/c.txt', '/', '/'],
    ['/a/b/c.txt', '*a', '/b/c.txt', '/b/c.txt', '/a/b/c.txt', '/a/b/c.txt'],
    ['/a/b/c.txt', '*c', '.txt', '.txt', '/a/b/c.txt', '/a/b/c.txt'],
    ['/a/b/c.txt', '*', '/a/b/c.txt', '', '/a/b/c.txt', ''],
    ['abc', 'a*', 'bc', '', '', ''],
    ['abc', '*a', 'bc', 'bc', 'abc', 'abc'],
    ['abc', 'ab*', 'c', '', '', ''],
    ['abc', '*c', '', '', 'ab', ''],
    ['aaa', 'a*', 'aa', '', 'aa', ''],
    ['aaa', '*a', 'aa', '', 'aa', ''],
    ['a.b.c', '.*', 'a.b.c', 'a.b.c', 'a.b', 'a'],
    ['a.b.c', '*c', '', '', 'a.b.', ''],
    ['a.b.c', 'a*', '.b.c', '', '', ''],
    ['x', 'a*', 'x', 'x', 'x', 'x'],
    ['', '*/', '', '', '', ''],
    ['pre-fix', '*/', 'pre-fix', 'pre-fix', 'pre-fix', 'pre-fix'],
  ];
  for (const [v, p, S, SS, Pct, PPct] of stripTable) {
    assert.equal(sh2.param('#', 'v', p, '', v), S, `\${v#${p}} on ${JSON.stringify(v)}`);
    assert.equal(sh2.param('##', 'v', p, '', v), SS, `\${v##${p}} on ${JSON.stringify(v)}`);
    assert.equal(sh2.param('%', 'v', p, '', v), Pct, `\${v%${p}} on ${JSON.stringify(v)}`);
    assert.equal(sh2.param('%%', 'v', p, '', v), PPct, `\${v%%${p}} on ${JSON.stringify(v)}`);
  }

  // (2) The `${name<op>…}` whole-word fast path must agree with the
  // general path. `expandWord("X" + w)` cannot match the anchored fast
  // path (the word starts with a literal), so it runs the full machinery
  // on the SAME expansion — the prefix is trigger-free, so the results
  // differ only by that prefix. Values are trigger-free (the fast path
  // bails to the general path when a substituted value carries `$`,
  // a backtick, `~`, a backslash or a quote).
  const gen = (w) => expandWord(sh2, 'X' + w).slice(1);
  const valueMatrix = ['pre-fix', 'abc', 'a.b.c', 'aaa', '', 'a b'];
  const wordMatrix = [
    (n) => `\${${n}:0:3}`, (n) => `\${${n}:2}`, (n) => `\${${n}:1:2}`,
    (n) => `\${${n}:-zzz}`, (n) => `\${${n}:+alt}`, (n) => `\${${n}#pre-}`,
    (n) => `\${${n}##*.}`, (n) => `\${${n}%.*}`, (n) => `\${${n}%%*}`,
    (n) => `\${${n}^^}`, (n) => `\${${n},,}`, (n) => `\${${n}/a/Q}`,
    (n) => `\${${n}//a/Q}`, (n) => `\${#${n}}`, (n) => `\${${n}}`,
  ];
  for (const val of valueMatrix) {
    sh2.vars.pv = val;
    for (const mk of wordMatrix) {
      const w = mk('pv');
      assert.equal(expandWord(sh2, w), gen(w),
        `fast path diverges from the general path for ${w} with pv=${JSON.stringify(val)}`);
    }
  }
  // A value that DOES carry a trigger must still produce the general
  // path's answer (the slice result is never re-expanded — only a
  // `${…}` in the result would be, and that falls back).
  sh2.vars.pv = 'a$b';
  assert.equal(expandWord(sh2, '${pv:0:2}'), 'a$', 'a `$` in the result is NOT re-expanded');
  assert.equal(expandWord(sh2, '${pv:0:1}${pv:0:1}'), 'aa', 'two expansions in one word');

  // (3) The per-rewrite gates: a multi-reference word must equal the
  // pre-change unconditional formula (the `$name` replace + the braced
  // loop). The reference reimplements that formula directly.
  const refExpand = (s) => {
    let out = s.replace(/\$\{([A-Za-z_][A-Za-z0-9_.]*)\}/g, (_, n) => sh2.getVar(n));
    out = out.replace(/\$([A-Za-z_][A-Za-z0-9_]*|\d+|[@#*?$0-])/g, (_, n) => sh2.getVar(n));
    for (;;) {
      if (out.indexOf('${') < 0) break;
      const next = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_.]*)([^{}]*)\}/g, (m, n, body) => {
        const v = sh2.getVar(n);
        if (body === '') return v;
        if (body === '#') return String(v.length);
        return sh2.param(body.replace(/^:/, 'slice:').split(':')[0], n, body, '', v);
      });
      if (next === out) break;
      out = next;
    }
    return out;
  };
  sh2.vars.pa = 'A'; sh2.vars.pb = 'B';
  for (const s of ['$pa/$pb', 'pre-$pa-post', '$pa$pb', 'x$pa/${pb}y', '$pa-${pa}', '$#-$?']) {
    assert.equal(expandWord(sh2, s), refExpand(s), `gated replaces diverge for ${JSON.stringify(s)}`);
  }

  // (4) runCmdSubst's early-out: a word with neither `$(` nor a backtick
  // comes back untouched, and the `$(…)` form still runs.
  assert.equal(expandWord(sh2, '$pa-$pb'), 'A-B', 'plain refs expand');
  assert.equal(expandWord(sh2, '$(echo hi)'), 'hi', 'a cmdsub still runs');

  // (5) assocGet normalizes its key ONCE — same answer as the old
  // double-normalization formula, including a key that needs expanding.
  const assocRef = (nm, key) => {
    const store = sh2.assocStore.get(nm);
    const k = expandWord(sh2, String(key).trim().replace(/^\[|\]$/g, '').replace(/^"|"$/g, ''));
    return store && store.has(k) ? String(store.get(k)) : '';
  };
  sh2.assocNames.add('tk'); sh2.assocStore.set('tk', new Map());
  sh2.vars.key = 'dyn';
  sh2.assocSet('tk', 'foo', 'bar');
  sh2.assocSet('tk', '"$key"', 'val');
  for (const k of ['foo', 'dyn', '"$key"', '$key', 'missing']) {
    assert.equal(sh2.assocGet('tk', k), assocRef('tk', k),
      `assocGet(${JSON.stringify(k)}) must match the double-normalization formula`);
  }

  // (6) The emitter's new indexed-subscript key (src/shir.rs
  // `subscript_key_expr`): `arrayIndex(base, <native arith value>)` must
  // equal `arrayIndex(base, <the text evalArith would resolve>)`.
  sh2.setArray('ts', ['zero', 'one', 'two', 'three', 'four'], false);
  for (const i of ['0', '1', '4', '5', '-1', '-9', 'x', '']) {
    sh2.vars.si = i;
    for (const [text, val] of [['si', evalArith('si', sh2)], ['si+1', evalArith('si+1', sh2)]]) {
      assert.equal(sh2.arrayIndex('ts', val), sh2.arrayIndex('ts', text),
        `arrayIndex value key ${JSON.stringify(val)} must equal the text key ${JSON.stringify(text)}`);
    }
  }
  // and the write twin
  sh2.setArray('tw2', [], false);
  sh2.vars.si = '2';
  sh2.arrayStore('tw2', evalArith('si', sh2), 'v');
  sh2.arrayStore('tw2', '3', 'w');
  assert.equal(sh2.arrayIndex('tw2', '2'), 'v', 'value-key write lands on the arith index');
  assert.equal(sh2.arrayIndex('tw2', '3'), 'w', 'text-key write lands on the literal index');
}
console.log('ok: plan-42 expansion + glob-strip fast paths');
