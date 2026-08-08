#!/usr/bin/env node
// site_dump.mjs — dump sh2.* call sites per test file with surrounding code,
// for improvement-mode triage. Usage:
//   node harness/site_dump.mjs [--shir] [PREFIX] [--names a,b,c]
// Reads the same ESTree JSON as fail-estree (debashc file --estree <file>).
import { execFileSync } from 'node:child_process';
import { globSync } from 'node:fs';
import { readFileSync } from 'node:fs';

const root = '/home/llm/sh2loop';
const debashc = `${root}/sh2perl/target/debug/debashc`;
const namesArg = process.argv.indexOf('--names');
const want = namesArg >= 0 ? new Set(process.argv[namesArg + 1].split(',')) : null;
const prefixes = process.argv.slice(2).filter(a => !a.startsWith('--'));
const tests = globSync(`${root}/sh2perl/examples/*.sh`).sort();

// pretty-print a compact JS-ish snippet
function pp(node, depth = 0) {
  if (node == null) return String(node);
  if (typeof node === 'string' || typeof node === 'number') return JSON.stringify(node);
  if (Array.isArray(node)) return '[' + node.map(n => pp(n, depth + 1)).join(', ') + ']';
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
    case 'BlockStatement': return '{ … }';
    case 'IfStatement': return `if (${pp(node.test)}) ${pp(node.consequent)}`;
    case 'ReturnStatement': return `return ${pp(node.argument)}`;
    case 'ExpressionStatement': return `${pp(node.expression)};`;
    case 'VariableDeclaration': return `let ${(node.declarations || []).map(d => pp(d.id) + (d.init ? ' = ' + pp(d.init) : '')).join(', ')}`;
    default: return `<${t}>`;
  }
}

let total = 0;
const famTot = {};
for (const f of tests) {
  const base = f.split('/').pop();
  if (prefixes.length && !prefixes.some(p => base.startsWith(p))) continue;
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
        if (!want || want.has(n)) {
          hits.push({ n, inLoop, src: pp(node) });
        }
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
    console.log(`\n=== ${base} (${hits.length}) ===`);
    for (const h of hits) {
      total++;
      famTot[h.n] = (famTot[h.n] || 0) + 1;
      console.log(`  ${h.inLoop ? 'LOOP ' : '      '}sh2.${h.n}: ${h.src.slice(0, 220)}`);
    }
  }
}
console.log(`\nTOTAL ${total}`);
console.log(Object.entries(famTot).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k}\t${v}`).join('\n'));
