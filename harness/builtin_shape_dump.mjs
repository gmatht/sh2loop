#!/usr/bin/env node
// builtin_shape_dump.mjs — group sh2.builtin("<name>", args) sites by arg shape
import { globSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const root = '/home/llm/sh2loop';
const otranspilerl-cli = `${root}/sh2perl/otranspilerl/target/debug/otranspilerl-cli`;
const tests = globSync(`${root}/sh2perl/examples/*.sh`).sort();
function pp(node, depth = 0) {
  if (node == null) return String(node);
  if (typeof node === 'string' || typeof node === 'number') return JSON.stringify(node);
  if (Array.isArray(node)) return '[' + node.map(n => pp(n, depth + 1)).join(', ') + ']';
  if (typeof node === 'boolean') return String(node);
  const t = node.type;
  switch (t) {
    case 'Literal': return JSON.stringify(node.value ?? node.raw);
    case 'ArrayExpression': return '[' + (node.elements || []).map(e => pp(e, depth + 1)).join(', ') + ']';
    case 'Identifier': return node.name;
    case 'MemberExpression': return pp(node.object) + (node.computed ? '[' + pp(node.property) + ']' : '.' + pp(node.property));
    case 'CallExpression': return pp(node.callee) + '(' + (node.arguments || []).map(pp).join(', ') + ')';
    case 'ArrowFunctionExpression': return '(=> ' + pp(node.body) + ')';
    case 'BinaryExpression': return '(' + pp(node.left) + ' ' + node.operator + ' ' + pp(node.right) + ')';
    case 'UnaryExpression': return node.operator + pp(node.argument);
    case 'SequenceExpression': return '(' + (node.expressions || []).map(pp).join(', ') + ')';
    case 'ConditionalExpression': return '(' + pp(node.test) + ' ? ' + pp(node.consequent) + ' : ' + pp(node.alternate) + ')';
    default: return '<' + t + '>';
  }
}
const wantNames = new Set((process.argv[2] ?? 'echo,cat,grep,sort,sed,tr,test,wc,ls,head,local,cd,diff,unset').split(','));
const counts = {};
const perFile = {};
for (const f of tests) {
  let json;
  try { json = JSON.parse(execFileSync(otranspilerl-cli, ['file', '--estree', f], { cwd: `${root}/sh2perl`, stdio: ['ignore', 'pipe', 'ignore'] }).toString()); } catch { continue; }
  const walk = (x) => {
    if (Array.isArray(x)) { x.forEach(walk); return; }
    if (!x || typeof x !== 'object') return;
    if (x.type === 'CallExpression') {
      const c = x.callee;
      if (c && c.type === 'MemberExpression' && c.object && c.object.name === 'sh2' && c.property.name === 'builtin') {
        const name = x.arguments?.[0]?.value ?? '?';
        if (wantNames.has(name)) {
          const key = name + ' | ' + pp(x.arguments?.[1]).slice(0, 160);
          counts[key] = (counts[key] || 0) + 1;
        }
      }
    }
    for (const v of Object.values(x)) walk(v);
  };
  walk(json);
}
const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
console.log('distinct shapes:', sorted.length);
for (const [k, v] of sorted.slice(0, 80)) console.log(String(v).padStart(4), '\t', k);
