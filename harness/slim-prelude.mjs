#!/usr/bin/env node
// slim-prelude.mjs — PROTOTYPE: emit a runnable JS file carrying only the
// sh2-namespace members a program actually uses, instead of importing the
// whole ~515 KB harness/sh2-namespace.mjs.
//
//   node harness/slim-prelude.mjs <program.js> --out <slim.mjs>
//   node harness/slim-prelude.mjs <program.js> --run
//     (--run: execute <program.js> against the FULL namespace and against
//      the slim prelude, and diff stdout/stderr/exit code.)
//
// Method: parse the namespace with acorn, split the `sh2 = {...}` object
// literal into per-member source slices, collect `sh2.<name>` refs from
// the program, and close over member->member (`this.<m>` / `sh2.<m>` /
// `sh.<m>` / `shell.<m>` — the codebase passes the namespace around
// under several names) and member->module (bare identifier matching a
// top-level declaration) refs, plus the builtins table sliced by
// call-site literals (see below). Output is a complete runnable module
// mirroring harness/js-run.mjs: prelude + _init + program + _finish.
// If the prelude fails `node --check`, or any step fails, the tool exits
// nonzero WITHOUT writing output (fail closed — never emit a
// silently-truncated runtime).
//
// Builtins specialization: the 81-entry `builtins.NAME = …` table is
// emitted per-entry, keeping only names seen at literal dispatch sites
// (`sh2.builtin("nm", …)` / `sh2.exec("nm", …)` / `fnCall` /
// `fnValue` / `callUndefined` in the program, plus literal `builtins.nm`
// refs inside included code, transitively). Any dynamic dispatch
// (non-literal arg, aliasing, or a dynamic builtins[x] read outside the
// 5 dispatch members) falls back to the full table — still correct.
// Unlisted `sh2.*` reads are data fields assigned at runtime (kept
// absent: reads see undefined, exactly as in the full namespace).
//
// Dependency: acorn (prototype resolves it from /tmp/acorntest; promotion
// to a gate tool must vendor it or reimplement extraction).
// Env: SLIM_ACORN=/path/to/acorn.mjs to override.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ACORN_URL = process.env.SLIM_ACORN
  ?? '/tmp/acorntest/node_modules/acorn/dist/acorn.mjs';
const { Parser } = await import(ACORN_URL);

const ROOT = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const NS_PATH = path.join(ROOT, 'harness', 'sh2-namespace.mjs');
// Lifecycle roots: js-run.mjs calls these on every run.
const LIFECYCLE = ['_init', '_finish', '_setAllowlist', '_setLang'];

function usage() {
  console.error('usage: node harness/slim-prelude.mjs <program.js> (--out <slim.mjs> | --run)');
  process.exit(2);
}

const argv = process.argv.slice(2);
const progPath = argv.find(a => !a.startsWith('--'));
const wantOut = argv.includes('--out') ? argv[argv.indexOf('--out') + 1] : null;
const wantRun = argv.includes('--run');
if (!progPath || (!wantOut && !wantRun)) usage();

function parseModule(src, file) {
  return Parser.parse(src, { ecmaVersion: 'latest', sourceType: 'module', locations: false });
}

// Generic ESTree walk (no acorn-walk dependency).
function walk(node, cb) {
  if (!node || typeof node.type !== 'string') return;
  cb(node);
  for (const k of Object.keys(node)) {
    if (k === 'parent') continue;
    const v = node[k];
    if (Array.isArray(v)) {
      for (const e of v) if (e && typeof e.type === 'string') walk(e, cb);
    } else if (v && typeof v.type === 'string') {
      walk(v, cb);
    }
  }
}

const nsSrc = fs.readFileSync(NS_PATH, 'utf8');
const nsAst = parseModule(nsSrc, NS_PATH);

// --- 1. module-scope declarations: name -> {start, end} source slice ---
const moduleDecls = new Map(); // name -> {start,end}
// NOTE: exported decls nest inside ExportNamedDeclaration wrappers —
// unwrap one level or every `export function`/`export const` helper
// (evalArith, toI64, BUILTIN_NAMES, …) is silently missed and its
// callers degrade (often inside try/catch → wrong values, not crashes).
const unwrap = (st) => (st.type === 'ExportNamedDeclaration' && st.declaration) ? st.declaration : st;
for (const raw of nsAst.body) {
  const st = unwrap(raw);
  if (st.type === 'FunctionDeclaration' && st.id) {
    moduleDecls.set(st.id.name, { start: raw.start, end: raw.end });
  } else if (st.type === 'VariableDeclaration') {
    for (const d of st.declarations) {
      if (d.id.type === 'Identifier') moduleDecls.set(d.id.name, { start: raw.start, end: raw.end });
    }
  } else if (st.type === 'ClassDeclaration' && st.id) {
    moduleDecls.set(st.id.name, { start: raw.start, end: raw.end });
  }
}

// --- 2. the sh2 object literal: member name -> {node, isFunction} ---
let sh2Obj = null;
walk(nsAst, (n) => {
  if (!sh2Obj && n.type === 'VariableDeclarator' && n.id.name === 'sh2'
      && n.init && n.init.type === 'ObjectExpression') {
    sh2Obj = n.init;
  }
});
if (!sh2Obj) { console.error('slim-prelude: sh2 object literal not found'); process.exit(1); }

const members = new Map(); // name -> {prop, isFunction}
for (const prop of sh2Obj.properties) {
  if (prop.type === 'SpreadElement') {
    console.error('slim-prelude: spread in sh2 literal — refusing (unanalyzable)');
    process.exit(1);
  }
  const key = prop.key.type === 'Identifier' ? prop.key.name
    : prop.key.type === 'Literal' ? String(prop.key.value) : null;
  if (key == null) { console.error('slim-prelude: computed key in sh2 literal — refusing'); process.exit(1); }
  const v = prop.value;
  const isFunction = v.type === 'FunctionExpression' || v.type === 'ArrowFunctionExpression';
  members.set(key, { prop, isFunction });
}

// --- 3. per-member dependency scan ---
// Collect identifiers that are LOCAL to the member (params, local
// function-scoped bindings) so they are not mistaken for module deps.
// Roots that can never be the sh2 namespace: module imports, JS
// builtins, and module-scope declarations. Anything else in `P.X`
// position with a member-named X is treated as a namespace access
// (over-inclusion is sound; the --run comparison verifies behavior).
// Member names that also exist as builtin properties (Math.max,
// console.warn, process.cwd, path.join, re.test, … — measured
// exhaustively against Array/String/Object/Map/Set/Promise/JSON/Math/
// console/process/Number/RegExp builtins). For THESE names only, the
// object must be an explicit namespace root; every other member name
// is unambiguous (no builtin collision possible).
const AMBIGUOUS_PROPS = new Set([
  'join', 'split', 'max', 'min', 'warn', 'cwd', 'argv0', 'exec', 'test',
]);
const NS_ROOTS = new Set(['sh2', 'sh', 'shell']);
const NON_NS_ROOTS = new Set([
  'console', 'process', 'JSON', 'Math', 'Object', 'Array', 'String',
  'Number', 'Boolean', 'Map', 'Set', 'Promise', 'Buffer', 'URL', 'RegExp',
  'Error', 'Symbol', 'BigInt', 'Intl', 'Reflect', 'Proxy', 'WeakMap',
  'WeakSet', 'Atomics', 'DataView', 'Float64Array', 'Uint8Array',
  'TextEncoder', 'TextDecoder', 'performance', 'queueMicrotask',
  'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval',
  'require', 'module', 'exports', '__dirname', '__filename', 'globalThis',
]);
// --- 4. program refs ---
const progSrc = fs.readFileSync(progPath, 'utf8');
let progAst;
try {
  progAst = parseModule(progSrc, progPath);
} catch (e) {
  // program may be a fragment with top-level await/return — retry as script
  progAst = Parser.parse(progSrc, { ecmaVersion: 'latest', sourceType: 'script' });
}
// Program refs split into member uses vs emitter scratch temps: the
// emitter parks statement-expression values on the namespace object
// (`sh2._g = …`, `sh2._r = …`, `sh2._readOk`, `sh2._writeErr` — assigned,
// never a helper call). An assigned-but-unknown name is scratch: it is
// pre-declared `undefined` in the prelude (reads see undefined until the
// program's own assignment runs — exactly the full-namespace behavior).
// A read-but-never-assigned unknown name is a genuine unknown: refuse.
// Namespace-managed scratch: fields assigned as `this.X` / `sh2.X`
// anywhere in the namespace (e.g. _readOk/_writeErr set by fs.*),
// never declared in the literal. Reads see undefined until namespace
// code assigns — pre-declaring `undefined` reproduces that exactly.
const nsAssigned = new Set();
walk(nsAst, (n) => {
  if (n.type === 'AssignmentExpression' && n.left.type === 'MemberExpression'
      && !n.left.computed && n.left.property.type === 'Identifier'
      && ((n.left.object.type === 'ThisExpression')
        || (n.left.object.type === 'Identifier'
          && (n.left.object.name === 'sh2' || n.left.object.name === 'sh')))) {
    nsAssigned.add(n.left.property.name);
  }
});
// Top-level augments: `builtins.echo = function…` statements populate a
// module container AFTER its declaration. When the container is needed,
// its augments come with it (source order); each augment's RHS is scanned
// for further deps (`this.*` binds sh2 at call time: fn.call(this,…)).
const augments = new Map(); // name -> [stmt nodes]
for (const st of nsAst.body) {
  if (st.type === 'ExpressionStatement' && st.expression.type === 'AssignmentExpression') {
    let n = st.expression.left;
    while (n.type === 'MemberExpression') n = n.object;
    if (n.type === 'Identifier' && moduleDecls.has(n.name)) {
      if (!augments.has(n.name)) augments.set(n.name, []);
      augments.get(n.name).push(st);
    }
  }
}
const used = new Set(LIFECYCLE.filter((m) => members.has(m)));
// The 5 dynamic dispatchers: members whose bodies read builtins[name]
// with a runtime name. Specializing the builtins table is sound only
// when every reachable call into them carries a literal name:
// program call sites (checked below) plus internal call sites
// (collected during closure). Anything dynamic → full table.
const DISPATCH = new Set(['builtin', 'exec', 'fnCall', 'fnValue', 'callUndefined']);
const keptBuiltins = new Set();
let needFullBuiltins = false;
const biQueue = []; // builtins-side worklist (kept entries needing dep scans)
// literal first-arg of a call, or undefined when dynamic/absent
function litFirstArg(node) {
  if (node.type !== 'CallExpression' || !node.arguments.length) return undefined;
  const a = node.arguments[0];
  if (a.type === 'Literal' && typeof a.value === 'string') return a.value;
  if (a.type === 'TemplateLiteral' && a.expressions.length === 0 && a.quasis.length === 1) {
    return a.quasis[0].value.cooked;
  }
  return undefined;
}
// walk with parent pointers (needed: is this MemberExpression a call callee?)
function walkP(node, cb, parent = null) {
  if (!node || typeof node.type !== 'string') return;
  cb(node, parent);
  for (const k of Object.keys(node)) {
    if (k === 'parent') continue;
    const v = node[k];
    if (Array.isArray(v)) v.forEach((e) => walkP(e, cb, node));
    else if (v && typeof v.type === 'string') walkP(v, cb, node);
  }
}
// callee `X.D` / `this.D` / `sh.D` with D a dispatch member (dot or
// computed-literal form — the audit must see computed dispatch too)?
function dispatchCallee(node) {
  if (node.type !== 'MemberExpression') return null;
  let dname = null;
  if (!node.computed && node.property.type === 'Identifier') dname = node.property.name;
  else if (node.computed && node.property.type === 'Literal'
    && typeof node.property.value === 'string') dname = node.property.value;
  if (!dname || !DISPATCH.has(dname)) return null;
  const o = node.object;
  if (o.type === 'ThisExpression') return dname;
  if (o.type === 'Identifier' && (NS_ROOTS.has(o.name)
      || (!NON_NS_ROOTS.has(o.name) && !moduleDecls.has(o.name)
        && !AMBIGUOUS_PROPS.has(dname)))) return dname;
  return null;
}
// shared per-unit scan: literal builtins refs, dynamic builtins reads,
// and dispatch-member calls (with literal-ness). isDispatchBody must be
// true ONLY for the 5 sh2 dispatch members themselves — their dynamic
// reads are covered by audited call-site literals. Everywhere else a
// dynamic read forces the full table.
const progRead = new Set();
const progAssigned = new Set();
// program dispatch audit: every sh2.D(...) call with D in DISPATCH must
// carry a literal command name (added to keptBuiltins); any dynamic or
// non-call reference forces the full builtins table (aliasing etc.).
const calledCallees = new Set();
walkP(progAst, (n, parent) => {
  const isCallCallee = parent && parent.type === 'CallExpression' && parent.callee === n;
  if (n.type === 'MemberExpression' && !n.computed
      && n.object.type === 'Identifier' && n.object.name === 'sh2'
      && n.property.type === 'Identifier') {
    const d = DISPATCH.has(n.property.name) ? n.property.name : null;
    if (d && isCallCallee) {
      calledCallees.add(n);
      const lit = litFirstArg(parent);
      if (lit === undefined) needFullBuiltins = true;
      else if (!keptBuiltins.has(lit)) {
        keptBuiltins.add(lit);
        biQueue.push(lit); // program-literal builtins need dep scanning too
      }
    } else if (d) {
      needFullBuiltins = true; // aliasing or dynamic use — fail open
    }
    progRead.add(n.property.name);
  } else if (n.type === 'AssignmentExpression' && n.left.type === 'MemberExpression'
      && !n.left.computed && n.left.object.type === 'Identifier'
      && n.left.object.name === 'sh2' && n.left.property.type === 'Identifier') {
    progAssigned.add(n.left.property.name);
  } else if (n.type === 'UpdateExpression' && n.argument.type === 'MemberExpression'
      && !n.argument.computed && n.argument.object.type === 'Identifier'
      && n.argument.object.name === 'sh2' && n.argument.property.type === 'Identifier') {
    progAssigned.add(n.argument.property.name);
  }
});
const scratch = new Set();
for (const name of new Set([...progRead, ...progAssigned])) {
  if (members.has(name)) {
    used.add(name);
  } else if (progAssigned.has(name)) {
    scratch.add(name);
  } else if (nsAssigned.has(name)) {
    scratch.add(name);
  } else {
    console.error(`slim-prelude: program reads unknown sh2.${name} — refusing`);
    process.exit(1);
  }
}

// --- 5. closure ---
// Soundness rule: over-inclusion only costs bytes (extra code still
// resolves dynamically at runtime); under-inclusion is the only failure
// mode, and it is caught loudly — a missing member throws at first use
// (or degrades inside try/catch, which the --run comparison catches as
// a MISMATCH). Fail-closed throughout: unknown program refs, unparsable
// slices, and node --check failures all exit nonzero without writing.
const needMembers = new Set();
const needModule = new Set();
const queue = [];
const modQueue = [];
// Absorb one scanned unit's refs into the worklists. inDispatch must be
// true ONLY for the 5 sh2 dispatch members themselves — their dynamic
// builtins reads are covered by audited call-site literals. Anywhere
// else a dynamic read forces the full builtins table.
function absorbRefs(sink, inDispatch, unitName) {
  for (const r of [...sink.thisRefs, ...sink.sh2Refs]) {
    if (members.has(r) && !needMembers.has(r)) queue.push(r);
    else if (!members.has(r)) {
      // Data field assigned elsewhere (e.g. this.lang via _setLang),
      // absent from the literal: reads see undefined, exactly as in the
      // full namespace before assignment. Warn, do not fail.
      console.error(`slim-prelude: note: ${unitName} refs unlisted sh2.${r} (data field, kept absent)`);
    }
  }
  for (const b of sink.bareIdents) {
    if (b === 'sh2') continue;
    if (moduleDecls.has(b) && !needModule.has(b)) {
      needModule.add(b);
      modQueue.push(b);
    }
  }
  for (const lit of sink.builtinLits) {
    if (!keptBuiltins.has(lit)) {
      keptBuiltins.add(lit);
      biQueue.push(lit);
    }
  }
  const dbg = process.env.SLIM_DEBUG === '1' ? (...a) => console.error('slim-prelude: debug:', ...a) : () => {};
  if (sink.builtinDyn && !inDispatch) { needFullBuiltins = true; dbg('full-table: dynamic builtins read in', unitName); }
  for (const dc of sink.dispCalls) {
    if (dc.lit === null) { needFullBuiltins = true; dbg('full-table: dynamic dispatch call in', unitName); }
    else if (!keptBuiltins.has(dc.lit)) {
      keptBuiltins.add(dc.lit);
      biQueue.push(dc.lit);
    }
  }
}
// One shared unit scan: member refs, bare module idents, builtins-table
// literals, dynamic builtins reads, and dispatch-member calls.
function scanUnit(root, inDispatch, unitLabel) {
  const sink = { thisRefs: new Set(), sh2Refs: new Set(), bareIdents: new Set(), builtinLits: new Set(), builtinDyn: false, dispCalls: [] };
  const propName = (p) => {
    if (!p.computed && p.property.type === 'Identifier') return p.property.name;
    if (p.computed && p.property.type === 'Literal' && typeof p.property.value === 'string') return p.property.value;
    return null;
  };
  walkP(root, (n, parent) => {
    if (n.type === 'MemberExpression') {
      const o = n.object;
      const pname = propName(n);
      const isBuiltinsObj = o.type === 'Identifier' && o.name === 'builtins';
      const isThis = o.type === 'ThisExpression';
      const isNsRoot = o.type === 'Identifier'
        && (NS_ROOTS.has(o.name)
          || (!NON_NS_ROOTS.has(o.name) && !moduleDecls.has(o.name)
            && !AMBIGUOUS_PROPS.has(pname)));
      if (pname !== null && (isThis || isNsRoot)) {
        // this.* / sh2.* / sh.* / shell.* (incl. computed-literal sh2["m"])
        if (isThis) sink.thisRefs.add(pname);
        else sink.sh2Refs.add(pname);
        return;
      }
      if (isBuiltinsObj) {
        if (pname !== null) sink.builtinLits.add(pname);
        else sink.builtinDyn = true;
        return;
      }
      // Any other computed read is a dynamic property — the --run
      // comparison is the backstop (no computed sh2[...] exists in-tree).
      return;
    }
    if (n.type === 'Identifier') {
      sink.bareIdents.add(n.name);
      return;
    }
    if (n.type === 'CallExpression') {
      const d = n.callee.type === 'MemberExpression' ? dispatchCallee(n.callee) : null;
      if (d) {
        const lit = litFirstArg(n);
        sink.dispCalls.push({ name: d, lit: lit === undefined ? null : lit });
      }
    }
  });
  absorbRefs(sink, inDispatch, (typeof unitLabel === 'string' ? unitLabel : (inDispatch ? '(dispatch)' : '(unit)')));
}
// Member refs out of a module decl (`sh.getVar(…)` — helpers take the
// namespace as `sh`) resolve to MEMBERS, not modules: queue them into
// the member worklist. Bare identifiers resolve to module decls.
const scanModuleDecl = (name) => {
  const loc = moduleDecls.get(name);
  if (!loc) return;
  const units = [nsSrc.slice(loc.start, loc.end)];
  // The builtins table's 81 assignments are NOT scanned here: each kept
  // entry is scanned individually via scanBuiltinAugment, so unkept
  // builtins (eval/exec/type dynamic reads, xargs dynamic dispatch)
  // can never force the full table.
  if (name !== 'builtins') {
    for (const st of augments.get(name) || []) units.push(nsSrc.slice(st.start, st.end));
  }
  for (const slice of units) {
    let sub;
    try {
      sub = Parser.parse(slice, { ecmaVersion: 'latest', sourceType: 'module' });
    } catch { continue; }
    scanUnit(sub, false, 'module:' + name);
  }
};
// Scan one kept builtin's augment RHS for further refs.
const scannedBuiltins = new Set();
const scanBuiltinAugment = (lit) => {
  if (scannedBuiltins.has(lit)) return;
  scannedBuiltins.add(lit);
  for (const st of augments.get('builtins') || []) {
    const key = st.expression.left.property;
    const kname = key.type === 'Identifier' ? key.name : key.value;
    if (kname !== lit) continue;
    let sub;
    try {
      sub = Parser.parse(nsSrc.slice(st.start, st.end), { ecmaVersion: 'latest', sourceType: 'module' });
    } catch { continue; }
    scanUnit(sub, false, 'builtin:' + lit);
  }
};
queue.push(...used);
let fullBackfilled = false;
while (queue.length || modQueue.length || biQueue.length
    || (needFullBuiltins && !fullBackfilled)) {
  while (queue.length) {
    const name = queue.pop();
    if (needMembers.has(name)) continue;
    const m = members.get(name);
    if (!m) continue; // data refs checked at parse; defensive
    needMembers.add(name);
    scanUnit(m.prop, DISPATCH.has(name), 'member:' + name);
  }
  while (modQueue.length) scanModuleDecl(modQueue.pop());
  while (biQueue.length) {
    const lit = biQueue.pop();
    scanBuiltinAugment(lit);
  }
  if (needFullBuiltins && !fullBackfilled) {
    // Full-table fallback: every augment must be scanned for deps
    // (an unscanned kept-out augment like sha256sum's would run with
    // missing module helpers). Mark all scanned; emission stays full.
    fullBackfilled = true;
    const keys = new Set();
    for (const st of augments.get('builtins') || []) {
      const key = st.expression.left.property;
      keys.add(key.type === 'Identifier' ? key.name : key.value);
    }
    for (const k of keys) scanBuiltinAugment(k);
  }
}

// --- 6. emit ---
// Preserve source order (namespace order, then module decl order) for
// readability; semantics do not depend on it (all refs resolve at call).
const importDecls = nsAst.body
  .filter((st) => st.type === 'ImportDeclaration')
  .map((st) => nsSrc.slice(st.start, st.end));
const memberSlices = [];
for (const [name] of members) {
  if (!needMembers.has(name)) continue;
  const p = members.get(name).prop;
  memberSlices.push(nsSrc.slice(p.start, p.end));
}
const moduleSlices = [];
// The builtins table (81 `builtins.NAME = …` assignments) is the one
// sliceable unit: with audited-literal dispatch everywhere, emit only
// the kept entries (plus the declaration). Anything dynamic anywhere
// (needFullBuiltins) falls back to the whole table — still correct.
let keptAugments = 0;
for (const [name, loc] of moduleDecls) {
  if (!needModule.has(name)) continue;
  moduleSlices.push(nsSrc.slice(loc.start, loc.end));
  for (const st of augments.get(name) || []) {
    if (name === 'builtins' && !needFullBuiltins) {
      const key = st.expression.left.property;
      const kname = key.type === 'Identifier' ? key.name : key.value;
      if (!keptBuiltins.has(kname)) continue;
      keptAugments++;
    }
    moduleSlices.push(nsSrc.slice(st.start, st.end));
  }
}
if (needModule.has('builtins')) {
  console.error(`slim-prelude: builtins table: ${needFullBuiltins ? 'FULL (dynamic dispatch present)' : keptAugments + '/' + (augments.get('builtins') || []).length + ' entries kept'}`);
}
const prelude =
  importDecls.join('\n') + '\n' +
  moduleSlices.join('\n') + '\n' +
  'const sh2 = {\n' +
  [...memberSlices, ...[...scratch].map((n) => `${n}: undefined`)].join(',\n') +
  '\n};\n';

function runnable(preludeText) {
  return preludeText +
    `sh2._init("prog", []);\n` +
    `sh2._setAllowlist(null);\n` +
    progSrc + '\nawait sh2._finish();\n';
}

if (wantOut) {
  const out = runnable(prelude);
  const tmp = wantOut + '.check.mjs';
  fs.writeFileSync(tmp, out);
  try {
    execFileSync(process.execPath, ['--check', tmp], { stdio: 'pipe' });
  } catch (e) {
    console.error('slim-prelude: emitted file fails node --check — refusing to write output');
    console.error((e.stderr || '').toString().split('\n').slice(0,8).join('\n'));
    console.error('(kept for inspection: ' + tmp + ')');
    fs.copyFileSync(tmp, wantOut + '.broken');
    fs.rmSync(tmp);
    process.exit(1);
  }
  fs.rmSync(tmp);
  fs.writeFileSync(wantOut, out);
  const full = prelude.length + progSrc.length;
  console.error(`slim-prelude: prelude ${prelude.length} bytes (namespace ${nsSrc.length}); program ${progSrc.length}`);
}

if (wantRun) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'slim-'));
  const fullFile = path.join(dir, 'full.mjs');
  const slimFile = path.join(dir, 'slim.mjs');
  const nsImport = `import { sh2 } from ${JSON.stringify(NS_PATH)};\n`;
  fs.writeFileSync(fullFile, nsImport + `sh2._init("prog", []);\nsh2._setAllowlist(null);\n` + progSrc + '\nawait sh2._finish();\n');
  fs.writeFileSync(slimFile, runnable(prelude));
  for (const f of [fullFile, slimFile]) {
    try { execFileSync(process.execPath, ['--check', f], { stdio: 'pipe' }); }
    catch { console.error(`slim-prelude: ${f} fails node --check`); process.exit(1); }
  }
  const runOne = (f) => {
    try {
      const stdout = execFileSync(process.execPath, [f], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
      return { rc: 0, stdout };
    } catch (e) {
      return { rc: e.status ?? 1, stdout: (e.stdout ?? '').toString() };
    }
  };
  const a = runOne(fullFile);
  const b = runOne(slimFile);
  fs.rmSync(dir, { recursive: true, force: true });
  if (a.rc === b.rc && a.stdout === b.stdout) {
    console.error(`slim-prelude: MATCH (rc=${a.rc}, ${a.stdout.length} bytes stdout, prelude ${prelude.length} bytes)`);
  } else {
    console.error(`slim-prelude: MISMATCH full(rc=${a.rc},${a.stdout.length}B) slim(rc=${b.rc},${b.stdout.length}B)`);
    console.error('--- full stdout ---'); console.error(a.stdout.slice(0, 2000));
    console.error('--- slim stdout ---'); console.error(b.stdout.slice(0, 2000));
    process.exit(1);
  }
}
