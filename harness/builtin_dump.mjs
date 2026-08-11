#!/usr/bin/env node
// dump args of selected builtin calls per file, with in-loop tags
import { execFileSync } from 'node:child_process';
import { globSync } from 'node:fs';

const root = '/home/llm/sh2loop';
const tests = globSync(`${root}/sh2perl/examples/*.sh`).sort();
const wantNames = new Set((process.argv[2] ?? 'wc,let,cmp,unset').split(','));

function pp(n) {
  if (n == null) return String(n);
  if (typeof n === 'string' || typeof n === 'number') return JSON.stringify(n);
  if (Array.isArray(n)) return '[' + n.map(pp).join(', ') + ']';
  const t = n.type;
  switch (t) {
    case 'Literal': return JSON.stringify(n.value ?? n.raw);
    case 'Identifier': return n.name;
    case 'MemberExpression': return pp(n.object) + (n.computed ? '[' + pp(n.property) + ']' : '.' + pp(n.property));
    case 'CallExpression': return pp(n.callee) + '(' + (n.arguments || []).map(pp).join(', ') + ')';
    case 'BinaryExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'LogicalExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'UnaryExpression': return n.operator + pp(n.argument);
    case 'AssignmentExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'TemplateLiteral': return '`' + (n.quasis || []).map((q, i) => (q.value?.raw ?? '') + (n.expressions?.[i] ? '${' + pp(n.expressions[i]) + '}' : '')).join('') + '`';
    case 'ArrowFunctionExpression': return '(' + (n.params || []).map(pp).join(',') + ' => ' + pp(n.body) + ')';
    case 'AwaitExpression': return 'await ' + pp(n.argument);
    case 'ArrayExpression': return '[' + (n.elements || []).map(pp).join(', ') + ']';
    case 'SequenceExpression': return '(' + (n.expressions || []).map(pp).join(', ') + ')';
    case 'ConditionalExpression': return '(' + pp(n.test) + ' ? ' + pp(n.consequent) + ' : ' + pp(n.alternate) + ')';
    default: return '<' + t + '>';
  }
}

for (const f of tests) {
  const base = f.split('/').pop();
  let json;
  try {
    json = JSON.parse(execFileSync(`${root}/sh2perl/target/debug/debashc`, ['file', '--estree', f], { cwd: `${root}/sh2perl`, stdio: ['ignore', 'pipe', 'ignore'] }).toString());
  } catch { continue; }
  const hits = [];
  const walk = (n, inLoop) => {
    if (Array.isArray(n)) { for (const x of n) walk(x, inLoop); return; }
    if (!n || typeof n !== 'object') return;
    if (n.type === 'CallExpression' && n.callee?.type === 'MemberExpression' && n.callee?.object?.name === 'sh2') {
      const nm = n.callee.property?.name;
      if (nm === 'builtin') {
        const a0 = n.arguments?.[0];
        const bname = a0?.value ?? '?';
        if (wantNames.has(bname)) hits.push({ inLoop, bname, src: pp(n).slice(0, 260) });
      }
      if (nm && /Loop$/.test(nm)) {
        for (const a of n.arguments || []) { if (a?.type === 'ArrowFunctionExpression') walk(a, true); }
        return;
      }
    }
    for (const v of Object.values(n)) walk(v, inLoop);
  };
  walk(json, false);
  if (hits.length) {
    console.log(`=== ${base} ===`);
    for (const h of hits) console.log(`  ${h.inLoop ? 'LOOP ' : '     '}sh2.builtin("${h.bname}"): ${h.src}`);
  }
}
