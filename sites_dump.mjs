#!/usr/bin/env node
// Dump sh2.* call sites from the emitted ESTree JSON for corpus examples.
// Usage: node sites_dump.mjs <sh2name> [sh2name2 ...] [--context N] [--limit N]
// Prints each example file whose emitted JSON contains a sh2.<name> call,
// with a compact rendering of the call expression.
import { execSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = '/home/llm/sh2loop';
const ex = join(root, 'sh2perl', 'examples');
const otranspilerl-cli = join(root, 'sh2perl', 'target', 'debug', 'otranspilerl-cli');

const names = process.argv.slice(2).filter(a => !a.startsWith('--'));
const ctxN = (() => { const i = process.argv.indexOf('--context'); return i >= 0 ? +process.argv[i+1] : 0; })();
const limit = (() => { const i = process.argv.indexOf('--limit'); return i >= 0 ? +process.argv[i+1] : 0; })();
const showSrc = process.argv.includes('--src');

function render(e, depth = 0) {
  if (!e || typeof e !== 'object') return JSON.stringify(e);
  if (Array.isArray(e)) return '[' + e.map(x => render(x, depth)).join(', ') + ']';
  switch (e.type) {
    case 'Literal': return JSON.stringify(e.value);
    case 'Identifier': return e.name;
    case 'MemberExpression': return render(e.object, depth) + (e.computed ? '[' + render(e.property, depth) + ']' : '.' + render(e.property, depth));
    case 'CallExpression': return render(e.callee, depth) + '(' + (e.arguments||[]).map(a => render(a, depth)).join(', ') + ')';
    case 'ArrowFunctionExpression': return '() => {' + ((e.body && e.body.body) || []).map(s => render(s, depth+1)).join('; ') + '}';
    case 'BinaryExpression': return '(' + render(e.left, depth) + ' ' + e.operator + ' ' + render(e.right, depth) + ')';
    case 'UnaryExpression': return e.operator + render(e.argument, depth);
    case 'LogicalExpression': return '(' + render(e.left, depth) + ' ' + e.operator + ' ' + render(e.right, depth) + ')';
    case 'ConditionalExpression': return '(' + render(e.test, depth) + ' ? ' + render(e.consequent, depth) + ' : ' + render(e.alternate, depth) + ')';
    case 'AssignmentExpression': return render(e.left, depth) + ' ' + e.operator + ' ' + render(e.right, depth);
    case 'SequenceExpression': return (e.expressions||[]).map(x => render(x, depth)).join(', ');
    case 'ArrayExpression': return '[' + (e.elements||[]).map(x => render(x, depth)).join(', ') + ']';
    case 'ExpressionStatement': return render(e.expression, depth) + ';';
    case 'BlockStatement': return '{' + (e.body||[]).map(s => render(s, depth)).join('; ') + '}';
    case 'IfStatement': return 'if (' + render(e.test, depth) + ') ' + render(e.consequent, depth) + (e.alternate ? ' else ' + render(e.alternate, depth) : '');
    case 'ReturnStatement': return 'return ' + (e.argument ? render(e.argument, depth) : '') + ';';
    case 'VariableDeclaration': return (e.declarations||[]).map(d => render(d, depth)).join(', ');
    case 'VariableDeclarator': return 'let ' + render(e.id, depth) + (e.init ? ' = ' + render(e.init, depth) : '');
    default: {
      // generic: render known expr-ish fields
      const keys = Object.keys(e).filter(k => !['type','start','end','loc','raw'].includes(k));
      const parts = [];
      for (const k of keys) {
        const v = e[k];
        if (v === null || v === undefined) continue;
        if (typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean') { parts.push(k + '=' + JSON.stringify(v)); continue; }
        if (k === 'callee' || k === 'object' || k === 'property' || k === 'argument' || k === 'init' || k === 'test' || k === 'consequent' || k === 'alternate' || k === 'left' || k === 'right' || k === 'id' || k === 'value') parts.push(render(v, depth));
        else if (Array.isArray(v) && k !== 'body') parts.push(k + ':[' + v.map(x => render(x, depth)).join(',') + ']');
        else if (Array.isArray(v)) parts.push('{' + v.map(s => render(s, depth)).join('; ') + '}');
      }
      return e.type + '(' + parts.join(', ') + ')';
    }
  }
}

const files = readdirSync(ex).filter(f => f.endsWith('.sh')).sort();
let shown = 0;
let totalSites = 0;
for (const f of files) {
  if (limit && shown >= limit) break;
  const src = readFileSync(join(ex, f), 'utf8');
  let json;
  try {
    json = execSync(`cd "${root}/sh2perl" && "${otranspilerl-cli}" file --estree "${join(ex, f)}" 2>/dev/null`, { maxBuffer: 64*1024*1024 }).toString();
  } catch { continue; }
  let data;
  try { data = JSON.parse(json); } catch { continue; }
  // find sh2 calls matching names
  const hits = [];
  const walk = (node, path) => {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach((n, i) => walk(n, path + '/' + i)); return; }
    if (node.type === 'CallExpression' && node.callee && node.callee.type === 'MemberExpression' &&
        node.callee.object && node.callee.object.name === 'sh2' && names.includes(node.callee.property.name)) {
      hits.push({ path, render: render(node) });
      totalSites++;
    }
    for (const [k, v] of Object.entries(node)) {
      if (['loc','start','end'].includes(k)) continue;
      walk(v, path + '.' + k);
    }
  };
  walk(data, '');
  if (hits.length) {
    shown++;
    console.log(`\n===== ${f} (${hits.length} sites) =====`);
    if (showSrc) {
      console.log(src.split('\n').slice(0, 60).join('\n'));
    }
    for (const h of hits.slice(0, 5)) {
      console.log('  ', h.render.slice(0, 400));
    }
    if (hits.length > 5) console.log(`  ... ${hits.length - 5} more`);
  }
}
console.log(`\nTOTAL sites across corpus: ${totalSites}`);
