// Regression test — arithmetic comma operator in the estree runtime.
//
// bash parses a subscript as ARITHMETIC, and its arithmetic has the C comma
// operator (evaluate both, yield the last): `$((0,0))` is 0, so the
// pseudo-multidim idiom `matrix[0,0]=v` stores element 0 and
// `echo ${matrix[0,0]}` prints it. Before the fix `evalArith` threw
// "trailing input near ',0'"; `setVar`/`arrayIndex` swallow that throw
// (bash skips a bad subscript), so the write was a SILENT no-op and the
// read printed ''. This test pins the operator in both runtime copies.
//
// Run: node harness/test_eval_arith_comma.mjs    (exit 0 = pass)

import assert from 'node:assert/strict';
import { evalArith as evalNs } from './sh2-namespace.mjs';
import { evalArith as evalTrace } from './sh2-trace.mjs';

function stub() {
  const vars = Object.create(null);
  return {
    vars,
    arrays: new Map(),
    getVar(n) { return vars[n] ?? ''; },
    setVar(n, v) { vars[n] = String(v); return true; },
    arrayLen(n) { return (this.arrays.get(n) ?? []).length; },
  };
}

for (const [label, ev] of [['sh2-namespace', evalNs], ['sh2-trace', evalTrace]]) {
  const sh = stub();
  assert.equal(ev('0,0', sh), 0, `${label}: $((0,0)) is 0`);
  assert.equal(ev('1,2', sh), 2, `${label}: comma yields the last value`);
  assert.equal(ev('(3,4)', sh), 4, `${label}: comma inside parens`);
  assert.equal(ev('1+2, 10*2', sh), 20, `${label}: comma is lowest precedence`);
  assert.equal(ev('i=0,j=5', sh), 5, `${label}: chained assignment yields the last`);
  assert.equal(sh.getVar('i'), '0', `${label}: left assignment executed`);
  assert.equal(sh.getVar('j'), '5', `${label}: right assignment executed`);
  assert.equal(ev('0,0,0', sh), 0, `${label}: repeated comma`);
  // The comma must not weaken the trailing-garbage check.
  assert.throws(() => ev('5 +', sh), /arith:/, `${label}: trailing operator still errors`);
  assert.throws(() => ev('0 0', sh), /arith:/, `${label}: space is not a separator`);
  assert.throws(() => ev('0,', sh), /arith:/, `${label}: dangling comma errors`);
}

console.log('ok: arithmetic comma operator');
