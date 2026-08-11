#!/usr/bin/env node
// inloop_dump.mjs — dump only the IN-LOOP sh2.* call sites (per fail-estree's
// metric rule: a call nested in a *Loop arrow body runs per iteration).
import { execFileSync } from 'node:child_process';
import { globSync } from 'node:fs';

const root = '/home/llm/sh2loop';
const debashc = `${root}/sh2perl/target/debug/debashc`;

function pp(node) {
  if (node == null) return String(node);
  if (typeof node === 'string' || typeof node === 'number') return JSON.stringify(node);
  if (Array.isArray(node)) return '[' + node.map(n => pp(n)).join(', ') + ']';
  if (typeof node === 'boolean') return String(node);
  const t = node.type;
  switch (t) {
    case 'Literal': return JSON.stringify(node.value ?? node.raw);
    case 'Identifier': return node.name;
    case 'MemberExpression': return pp(node.object) + (node.computed ? '[' + pp(node.property) + ']' : '.' + pp(node.property));
    case 'CallExpression': {
      const callee = pp(node.callee);
      const args = (node.arguments || []).map(a => pp(a));
      return `${callee}(${args.join(', ')})`;
    }
    case 'ArrowFunctionExpression': return `(${pp(node.params)} => ${pp(node.body)})`;
    case 'BinaryExpression': return `(${pp(node.left)} ${node.operator} ${pp(node.right)})`;
    case 'LogicalExpression': return `(${pp(node.left)} ${node.operator} ${pp(node.right)})`;
    case 'UnaryExpression': return `${node.operator}${pp(node.argument)}`;
    case 'AssignmentExpression': return `(${pp(node.left)} ${node.operator} ${pp(node.right)})`;
    case 'TemplateLiteral': return '`' + (node.quasis || []).map(q => q.value?.raw ?? '').join('${…}') + '`';
    case 'SequenceExpression': return '(' + (node.expressions || []).map(pp).join(', ') + ')';
    case 'ConditionalExpression': return `(${pp(node.test)} ? ${pp(node.consequent)} : ${pp(node.alternate)})`;
    default: return `<${t}>`;
  }
}

const tests = globSync(`${root}/sh2perl/examples/*.sh`).sort();
const famTot = {};
let total = 0;
for (const f of tests) {
  const base = f.split('/').pop();
  let json;
  try {
    json = JSON.parse(execFileSync(debashc, ['file', '--estree', f], { cwd: `${root}/sh2perl`, stdio: ['ignore', 'pipe', 'ignore'] }).toString());
  } catch { continue; }
  const hits = [];
  const walk = (node, inLoop) => {
    if (Array.isArray(node)) { for (const n of node) walk(n, inLoop); return; }
    if (!node || typeof node !== 'object') return;
    if (node.type === 'CallExpression') {
      const c = node.callee;
      if (c && c.type === 'MemberExpression' && c.object?.name === 'sh2') {
        const n = c.property?.name;
        if (inLoop) hits.push({ n, src: pp(node) });
        if (n && /Loop$/.test(n)) {
          for (const a of node.arguments || []) {
            walk(a, a?.type === 'ArrowFunctionExpression' ? true : inLoop);
          }
          return;
        }
      }
    }
    for (const v of Object.values(node)) walk(v, inLoop);
  };
  walk(json, false);
  if (hits.length) {
    console.log(`\n=== ${base} (${hits.length} in-loop) ===`);
    for (const h of hits) {
      total++;
      famTot[h.n] = (famTot[h.n] || 0) + 1;
      console.log(`  sh2.${h.n}: ${h.src.slice(0, 300)}`);
    }
  }
}
console.log(`\nTOTAL in-loop ${total}`);
console.log(Object.entries(famTot).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}\t${v}`).join('\n'));
