#!/usr/bin/env node
// Classify sh2.* call sites across the corpus's generated ESTree JSON.
// Usage: node analyze_sites.mjs [--builtin|--exec|--all]
import { readdirSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = '/home/llm/sh2loop';
const debashc = `${root}/sh2perl/target/debug/debashc`;
const examples = `${root}/sh2perl/examples`;
const filter = process.argv[2] || '--all';

const files = readdirSync(examples).filter(f => f.endsWith('.sh')).sort();

const counters = new Map();
const samples = new Map(); // key -> [file, snippet]
const loopCounters = new Map();

function count(name, file, inLoop, snippet) {
  const k = `${name}|${snippet}`;
  counters.set(k, (counters.get(k) || 0) + 1);
  if (inLoop) loopCounters.set(k, (loopCounters.get(k) || 0) + 1);
  if (!samples.has(k)) samples.set(k, [file, snippet]);
}

for (const f of files) {
  let json;
  try {
    json = execFileSync(debashc, ['file', '--estree', path.join(examples, f)], { encoding: 'utf8', timeout: 30000 });
  } catch (e) { continue; }
  let data;
  try { data = JSON.parse(json); } catch { continue; }

  // walk and find sh2.* call expressions
  const walk = (node, inLoop) => {
    if (Array.isArray(node)) { for (const n of node) walk(n, inLoop); return; }
    if (!node || typeof node !== 'object') return;
    if (node.type === 'CallExpression') {
      const c = node.callee;
      if (c && c.type === 'MemberExpression' && c.object && c.object.name === 'sh2' && c.property) {
        const name = c.property.name;
        // snippet: first arg literal if present
        let snippet = '';
        const args = node.arguments || [];
        if (args.length > 0) {
          const a = args[0];
          if (a.type === 'Literal') snippet = `"${String(a.value).slice(0, 40)}"`;
          else if (a.type === 'Identifier') snippet = `$${a.name}`;
          else if (a.type === 'ArrayExpression') {
            const items = a.elements.map(e => e && e.type === 'Literal' ? `"${String(e.value).slice(0,20)}"` : (e && e.type === 'Identifier' ? `$${e.name}` : '?')).join(',');
            snippet = `[${items}]`;
          }
        }
        count(name, f, inLoop, snippet);
      }
    }
    // loop bodies count as in-loop
    const isLoop = node.type && /Loop$/.test(node.type) && node.type !== 'WhileStatement';
    // arrow function args of sh2.*Loop calls are bodies
    let childInLoop = inLoop;
    if (isLoop) childInLoop = true;
    for (const [k, v] of Object.entries(node)) {
      if (k === 'loc' || k === 'range') continue;
      walk(v, childInLoop);
    }
  };
  walk(data, false);
}

// aggregate per name+snippet
const rows = [...counters.entries()].map(([k, n]) => {
  const [name, snippet] = k.split('|');
  return { name, snippet, n, inLoop: loopCounters.get(k) || 0 };
});

// filter
let filtered = rows;
if (filter === '--builtin') filtered = rows.filter(r => r.name === 'builtin');
if (filter === '--exec') filtered = rows.filter(r => r.name === 'exec');
if (filter === '--test') filtered = rows.filter(r => r.name === 'test');
if (filter === '--param') filtered = rows.filter(r => r.name === 'param');
if (filter === '--setVar') filtered = rows.filter(r => r.name === 'setVar');
if (filter === '--setVarAll') filtered = rows.filter(r => r.name === 'setVar');
if (filter === '--caseMatch') filtered = rows.filter(r => r.name === 'caseMatch');

// group by snippet for exec: show the command
filtered.sort((a, b) => b.n - a.n || a.name.localeCompare(b.name));
for (const r of filtered.slice(0, 120)) {
  const [file] = samples.get(`${r.name}|${r.snippet}`) || ['?'];
  console.log(`${String(r.n).padStart(4)} [in-loop ${r.inLoop}] ${r.name.padEnd(18)} ${r.snippet.padEnd(50)}  <- ${file}`);
}
