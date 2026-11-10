#!/usr/bin/env node
// estree-contract.mjs — the sh2.* op contract between the transpiler and the
// runtime (PLAN.md §1/§2). This is VALIDATION, not theorem: it is the check
// that would catch a runtime rename before the corpus does.
//
// WHY IT EXISTS. `sh2runtime` and this transpiler are coupled only by the
// ESTree JSON contract, and until now nothing compared the two sides. The
// coupling has four writers, each of which can drift alone:
//
//   1. the EMITTER (sh2perl's estree backend) — which ops it actually emits;
//   2. the RUNTIME (`harness/sh2-namespace.mjs`, `export const sh2`) — which
//      ops exist, and with what arity/prototype;
//   3. the STRUCTURAL GATE (`harness/estree_gate.pl` `%whitelist`) — a THIRD
//      hand-maintained name list, which admits or rejects callees before the
//      runtime ever sees them;
//   4. the POLYFILL mirror (`runtime/polyfills.sh` / `polyfills.c`, documented
//      in `runtime/README.md`) — the per-backend implementation of the pure
//      CPU core and the host seam.
//
// A rename on the runtime side leaves (3) still admitting the old name and the
// corpus failing with a TypeError; a rename in (3) leaves the runtime's op
// unreachable. Neither is a compile error anywhere. This script makes both a
// reported gap.
//
// WHAT IT CHECKS (each one is a hard failure):
//   A. PRESENCE — every `sh2.*` CALL callee the corpus emits resolves on the
//      runtime object to a function (or to a prototype method of the value the
//      runtime initializes that field to: `sh2.positional.join` is
//      Array.prototype.join, `sh2.assocNames.add` is Set.prototype.add,
//      `sh2._r.split` is String.prototype.split). Arity is checked too: the
//      largest argument count the emitter uses must fit the implementation's
//      parameter list (a rest parameter makes it unbounded; a native function
//      declares its exact arity). Too FEW arguments is deliberately not an
//      error — this runtime takes optional trailing parameters without
//      defaults (`pipeline(stages, fdTargets)`), so a minimum would be a false
//      positive; the emitted minimum is snapshotted instead (see C).
//   B. GATE WHITELIST — every name `estree_gate.pl` admits must resolve on the
//      runtime, as `sh2.<name>` or `sh2.fs.<name>` (the gate flattens the fs
//      namespace into the same whitelist).
//   C. SURFACE SNAPSHOT — op -> {argc set, static argument kinds per position}
//      must equal `harness/estree-contract.json`. This is where "types" lives:
//      the argument KINDS the emitter passes (Literal:string vs Identifier vs
//      ArrayExpression ...) are part of the calling convention, and a new op,
//      a dropped op, or a changed shape at a position is a deliberate review
//      (`--update`), not a silent change.
//   D. POLYFILL MIRROR — every function `runtime/README.md`'s inventory table
//      claims is mirrored by the polyfills must exist in `polyfills.sh` or
//      `polyfills.c` (the same extraction `runtime/check-coverage.py` uses for
//      builtins). This catches a rename on the sh2runtime side.
//
// WHAT IT DOES NOT CHECK (stated, not hidden):
//   * semantics — whether an op computes what bash computes. That is
//     `./fail-estree`, which compares estree-runner output against bash over
//     the corpus; this script only proves the two sides agree about NAMES,
//     ARITY and ARGUMENT SHAPES.
//   * ops no corpus example emits. The corpus is the authority for what ships,
//     so a rename of a dead op is invisible here (and invisible to the corpus
//     too). `--print-ops` lists what was actually seen.
//   * ops of the other runtimes (C/Go/Rust/... transpiled from
//     `runtime/polyfills.sh`): their per-backend call convention is the
//     adapters' business (`runtime/adapters/*`); only the documented mirror
//     (D) is checked.
//
// NON-VACUOUS. `--selftest` synthesises each failure from a fake surface, so a
// check that cannot report is a FAILED control, not a green section; and B/D
// treat an EMPTY parse (0 whitelist names, 0 inventory rows) as a finding,
// because a stale regex reads exactly like a clean section. Measured on copies
// of the namespace via `--namespace`: renaming `builtin` (the most-emitted op)
// fails A and B, narrowing its parameter list fails A with the count, and
// deleting `die` fails B — a corpus-only check stayed green through all three.
//
// USAGE
//   node harness/estree-contract.mjs                 # check (default)
//   node harness/estree-contract.mjs --update        # accept the current surface
//   node harness/estree-contract.mjs --files a.sh b.sh
//   node harness/estree-contract.mjs --json p.estree.json
//   node harness/estree-contract.mjs --print-ops
//   node harness/estree-contract.mjs --selftest      # negative controls
//   node harness/estree-contract.mjs --namespace other/sh2-namespace.mjs
//
// ENV: OTRANSPILERL_BIN (default <root>/otranspilerl/target/debug/otranspilerl-cli),
//      SH2PERL_DIR (default <root>/sh2perl — the examples corpus).
// EXIT: 0 contract holds; 1 any gap/drift; 2 setup error (nothing was checked).

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.dirname(HERE);
const BASELINE = path.join(HERE, 'estree-contract.json');
const GATE = path.join(HERE, 'estree_gate.pl');
const RUNTIME_DIR = path.join(ROOT, 'runtime');
const RUNNER = path.join(HERE, 'estree-runner.mjs');

const args = process.argv.slice(2);
const opt = {
  update: args.includes('--update'),
  selftest: args.includes('--selftest'),
  printOps: args.includes('--print-ops'),
  quiet: args.includes('--quiet'),
  files: [],
  jsons: [],
  namespace: null,
};
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--files') opt.files = args.slice(i + 1).filter((a) => !a.startsWith('--'));
  if (args[i] === '--json') opt.jsons = args.slice(i + 1).filter((a) => !a.startsWith('--'));
  if (args[i] === '--namespace') opt.namespace = args[i + 1];
}
const NS = opt.namespace ? path.resolve(opt.namespace) : path.join(HERE, 'sh2-namespace.mjs');
if (!opt.files.length && !opt.jsons.length) {
  const ex = path.join(process.env.SH2PERL_DIR || path.join(ROOT, 'sh2perl'), 'examples');
  if (!fs.existsSync(ex)) {
    console.error(`estree-contract: no example corpus at ${ex} (set SH2PERL_DIR)`);
    process.exit(2);
  }
  opt.files = fs.readdirSync(ex).filter((f) => f.endsWith('.sh')).sort().map((f) => path.join(ex, f));
}
const BIN = process.env.OTRANSPILERL_BIN || path.join(ROOT, 'otranspilerl', 'target', 'debug', 'otranspilerl-cli');

// ── ESTree walking ────────────────────────────────────────────────────
// The callee of a `sh2.*` call is a MemberExpression chain; render it as a
// dotted path. A computed member (`sh2[x]`) is NOT a contract op (the emitter
// never produces one) and is returned as null so it can be reported.
function calleePath(node) {
  if (!node || typeof node !== 'object') return null;
  if (node.type === 'Identifier') return node.name;
  if (node.type === 'MemberExpression') {
    if (node.computed) return null;
    const obj = calleePath(node.object);
    const prop = node.property && node.property.type === 'Identifier' ? node.property.name : null;
    return obj && prop ? `${obj}.${prop}` : null;
  }
  return null;
}

// Static argument kind: the ESTree node type, with a Literal's JS type folded
// in (`Literal:string` vs `Literal:number`) — that distinction is exactly the
// "matching types" half of the contract.
function argKind(node) {
  if (!node || typeof node !== 'object') return 'none';
  if (node.type === 'Literal') return `Literal:${node.value === null ? 'null' : typeof node.value}`;
  return node.type || '?';
}

function newNode() {
  return { argcs: new Set(), kinds: new Map(), sites: 0 };
}

function collectOps(program, into = new Map()) {
  const stack = [program];
  while (stack.length) {
    const n = stack.pop();
    if (Array.isArray(n)) {
      stack.push(...n);
      continue;
    }
    if (!n || typeof n !== 'object') continue;
    if (n.type === 'CallExpression') {
      const p = calleePath(n.callee);
      if (p && p.startsWith('sh2.')) {
        const a = Array.isArray(n.arguments) ? n.arguments : [];
        let e = into.get(p);
        if (!e) into.set(p, (e = newNode()));
        e.argcs.add(a.length);
        e.sites++;
        a.forEach((x, i) => {
          if (!e.kinds.has(i)) e.kinds.set(i, new Set());
          e.kinds.get(i).add(argKind(x));
        });
      } else if (p === null && n.callee && n.callee.type === 'MemberExpression') {
        const obj = calleePath(n.callee.object);
        if (obj === 'sh2') {
          let e = into.get('sh2[computed]');
          if (!e) into.set('sh2[computed]', (e = newNode()));
          e.sites++;
        }
      }
    }
    stack.push(...Object.values(n));
  }
  return into;
}

// ── runtime resolution ────────────────────────────────────────────────
// Fields the runtime initializes to a plain value whose TYPE is the contract.
// `_r` is the one exception: it is assigned ad hoc (`sh2._r = sh2.fs.readText(…)
// at sh2-namespace.mjs:636, a utf8 string) rather than declared in the object
// literal, so its type is named here instead of inferred. Keep this list
// SHORT: a declared type is a claim, and the point of the check is to infer
// what the runtime actually initializes.
const DECLARED_VALUE_TYPES = { _r: 'string' };

function typeOfValue(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (v instanceof Map) return 'map';
  if (v instanceof Set) return 'set';
  if (typeof v === 'string') return 'string';
  if (typeof v === 'number') return 'number';
  if (typeof v === 'boolean') return 'boolean';
  if (typeof v === 'function') return 'function';
  if (typeof v === 'object') return 'object';
  return typeof v;
}

function protoMember(v, name) {
  // Walk the prototype chain explicitly: `Object.getPrototypeOf(v)[name]`
  // would miss a getter defined further up, and an own property (e.g. a Map's
  // `size`) must not be mistaken for a method.
  let p = Object.getPrototypeOf(v);
  while (p) {
    const d = Object.getOwnPropertyDescriptor(p, name);
    if (d) return typeof d.value === 'function' ? d.value : null;
    p = Object.getPrototypeOf(p);
  }
  return null;
}

function resolveOp(root, dotted) {
  const segs = dotted.split('.');
  if (segs[0] !== 'sh2') return { ok: false, why: 'not a sh2.* callee' };
  let cur = root;
  const walked = ['sh2'];
  for (let i = 1; i < segs.length; i++) {
    const seg = segs[i];
    const t = typeOfValue(cur);
    if (t === 'object' && cur !== null && !(cur instanceof Map) && !(cur instanceof Set) && !Array.isArray(cur)) {
      if (!Object.prototype.hasOwnProperty.call(cur, seg)) {
        // A field the runtime assigns at run time (declared in
        // DECLARED_VALUE_TYPES) has no initializer to infer from; if the
        // remaining segment is a method of its declared type, that is the
        // contract the emitter relies on.
        const dt = DECLARED_VALUE_TYPES[seg];
        if (dt && i === segs.length - 2) {
          const method = segs[i + 1];
          const ctor = { string: String, array: Array, map: Map, set: Set, number: Number }[dt];
          const fn = ctor ? protoMember(Object.create(ctor.prototype), method) : null;
          if (fn) return { ok: true, value: fn, kind: 'method', owner: dt, path: dotted };
          return { ok: false, why: `declared ${dt} \`${walked.join('.')}.${seg}\` has no method \`${method}\`` };
        }
        return { ok: false, why: `${walked.join('.')} has no member \`${seg}\`` };
      }
      cur = cur[seg];
      walked.push(seg);
      continue;
    }
    // A value/collection root: the remaining segment must be a method of the
    // value's type, and it must be the LAST segment.
    if (i !== segs.length - 1) {
      return { ok: false, why: `cannot index into ${t} \`${walked.join('.')}\`` };
    }
    const declaredType = t === 'undefined' ? DECLARED_VALUE_TYPES[walked[walked.length - 1]] : null;
    let fn = null;
    if (declaredType) {
      const ctor = { string: String, array: Array, map: Map, set: Set, number: Number }[declaredType];
      fn = ctor ? protoMember(Object.create(ctor.prototype), seg) : null;
      if (!fn) return { ok: false, why: `declared ${declaredType} \`${walked.join('.')}\` has no method \`${seg}\`` };
      return { ok: true, value: fn, kind: 'method', owner: declaredType, path: dotted };
    }
    fn = protoMember(cur, seg);
    if (!fn) {
      return { ok: false, why: `${t} \`${walked.join('.')}\` has no method \`${seg}\`` };
    }
    return { ok: true, value: fn, kind: 'method', owner: t, path: dotted };
  }
  return { ok: true, value: cur, kind: typeOfValue(cur), path: dotted };
}

// Declared arity of an implementation: the parameter list (rest => unbounded),
// or a native function's exact `.length`. `Function.prototype.toString` on a
// JS function yields its source, so the parse is on real parameters rather
// than on `fn.length` (which stops at the first default and would understate
// `builtin(name, args, opts = {}, extra = [])`).
function arityOf(fn) {
  const src = Function.prototype.toString.call(fn);
  if (/\[native code\]/.test(src) || !src.trim()) {
    return { native: true, min: fn.length, max: fn.length, params: fn.length };
  }
  let params = null;
  let m = src.match(/^\s*(?:async\s+)?(?:function\s*[A-Za-z0-9_$]*\s*)?\(([^)]*)\)\s*(?:=>|\{)/);
  if (!m) m = src.match(/^\s*(?:async\s+)?[A-Za-z0-9_$]+\s*\(([^)]*)\)\s*\{/);
  if (m) params = splitParams(m[1]);
  if (!params) return { native: false, min: fn.length, max: fn.length, params: fn.length, unparsed: true };
  const rest = params.some((p) => p.startsWith('...'));
  const firstDefault = params.findIndex((p) => p.includes('='));
  return {
    native: false,
    min: firstDefault === -1 ? params.length : firstDefault,
    max: rest ? Infinity : params.length,
    params: params.length,
    rest,
  };
}

function splitParams(src) {
  const out = [];
  let depth = 0;
  let cur = '';
  for (const ch of src) {
    if ('([{'.includes(ch)) depth++;
    else if (')]}'.includes(ch)) depth--;
    if (ch === ',' && depth === 0) {
      out.push(cur.trim());
      cur = '';
    } else cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

// ── the four name lists ───────────────────────────────────────────────
function gateWhitelist() {
  const src = fs.readFileSync(GATE, 'utf8');
  const m = src.match(/my\s+%whitelist\s*=\s*map\s*\{\s*\$_ => 1\s*\}\s*qw\(([\s\S]*?)\);/);
  if (!m) return null;
  return m[1].split(/\s+/).filter(Boolean);
}

function polyfillNames() {
  const sh = fs.readFileSync(path.join(RUNTIME_DIR, 'polyfills.sh'), 'utf8');
  const c = fs.readFileSync(path.join(RUNTIME_DIR, 'polyfills.c'), 'utf8');
  const bash = new Set([...sh.matchAll(/^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{/gm)].map((m) => m[1]));
  for (const m of c.matchAll(/int\s+sh2poly_([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) bash.add(`sh2poly_${m[1]}`);
  for (const m of c.matchAll(/DELEGATE\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,/g)) bash.add(`sh2poly_${m[1]}`);
  return new Set([...bash].map((n) => n.replace(/^sh2poly_/, '')));
}

// The inventory table in runtime/README.md §1: the functions the doc claims the
// polyfills implement (column 1, backticked identifiers).
function readmeInventory() {
  const src = fs.readFileSync(path.join(RUNTIME_DIR, 'README.md'), 'utf8');
  const start = src.indexOf('## 1. What the polyfills are');
  const end = src.indexOf('## 1b.');
  if (start === -1 || end === -1) return null;
  const body = src.slice(start, end);
  const names = new Set();
  for (const line of body.split('\n')) {
    if (!line.startsWith('|')) continue;
    const cell = line.split('|')[1] || '';
    for (const m of cell.matchAll(/`([A-Za-z_][A-Za-z0-9_]*)`/g)) names.add(m[1]);
  }
  return names;
}

// ── analysis ──────────────────────────────────────────────────────────
function surfaceFromMap(map) {
  const out = {};
  for (const [op, e] of [...map.entries()].sort()) {
    const kinds = {};
    for (const [pos, ks] of [...e.kinds.entries()].sort((a, b) => a[0] - b[0])) {
      kinds[String(pos)] = [...ks].sort();
    }
    out[op] = { argcs: [...e.argcs].sort((a, b) => a - b), kinds };
  }
  return out;
}

function analyse(surface, { sh2, whitelist, polyfills, inventory, baseline }) {
  const findings = [];
  const add = (section, msg) => findings.push({ section, msg });

  // A. presence + arity
  const resolved = new Map();
  for (const [op, e] of Object.entries(surface)) {
    if (op === 'sh2[computed]') {
      add('A', 'computed `sh2[…]` callee — the emitter must name its op literally');
      continue;
    }
    const r = resolveOp(sh2, op);
    if (!r.ok) {
      add('A', `${op}: not implemented — ${r.why}`);
      continue;
    }
    if (typeof r.value !== 'function') {
      add('A', `${op}: resolves to a ${typeOfValue(r.value)}, not a function`);
      continue;
    }
    const ar = arityOf(r.value);
    const hi = Math.max(...e.argcs);
    const lo = Math.min(...e.argcs);
    if (hi > ar.max) {
      add(
        'A',
        `${op}: emitter passes ${hi} argument(s), implementation takes at most ${ar.max}` +
          (ar.rest ? ' (rest)' : ` (params=${ar.params}${ar.native ? ', native' : ''})`),
      );
    }
    resolved.set(op, { r, ar, lo, hi });
  }

  // B. the gate's whitelist must admit only names the runtime has
  if (whitelist === null) {
    add('B', 'could not parse `%whitelist` out of harness/estree_gate.pl');
  } else {
    for (const name of whitelist) {
      const top = resolveOp(sh2, `sh2.${name}`);
      const fsop = resolveOp(sh2, `sh2.fs.${name}`);
      const callable = (r) => r.ok && (typeof r.value === 'function' || ['map', 'set', 'array', 'object'].includes(typeOfValue(r.value)));
      if (!callable(top) && !callable(fsop)) {
        add(
          'B',
          `estree_gate.pl admits \`${name}\`, but neither sh2.${name} nor sh2.fs.${name} exists ` +
            (top.ok || fsop.ok ? `(found a ${typeOfValue((top.ok ? top : fsop).value)})` : ''),
        );
      }
    }
    if (whitelist.length === 0) add('B', 'estree_gate.pl %whitelist parsed as EMPTY — the parser is stale, not the gate clean');
  }

  // C. surface snapshot
  if (!baseline) {
    add('C', 'no harness/estree-contract.json baseline — run with --update to record one');
  } else {
    const cur = surface;
    const base = baseline.ops || {};
    for (const op of Object.keys(cur)) {
      if (!(op in base)) add('C', `${op}: emitted but not in the baseline (new op — review, then --update)`);
    }
    for (const op of Object.keys(base)) {
      if (!(op in cur)) add('C', `${op}: in the baseline but no longer emitted (dropped op — review, then --update)`);
    }
    for (const op of Object.keys(cur)) {
      const b = base[op];
      if (!b) continue;
      const a = cur[op];
      if (JSON.stringify(a.argcs) !== JSON.stringify(b.argcs)) {
        add('C', `${op}: argument counts ${JSON.stringify(b.argcs)} -> ${JSON.stringify(a.argcs)}`);
      }
      const positions = new Set([...Object.keys(a.kinds), ...Object.keys(b.kinds)]);
      for (const pos of [...positions].sort((x, y) => x - y)) {
        const antes = JSON.stringify((b.kinds || {})[pos] || []);
        const ahora = JSON.stringify(a.kinds[pos] || []);
        if (antes !== ahora) add('C', `${op}: argument ${pos} kinds ${antes} -> ${ahora}`);
      }
    }
  }

  // D. the documented polyfill mirror
  if (inventory === null) {
    add('D', 'could not parse the polyfill inventory out of runtime/README.md');
  } else if (polyfills === null) {
    add('D', 'could not read runtime/polyfills.sh|.c');
  } else {
    if (inventory.size === 0) add('D', 'runtime/README.md §1 inventory parsed as EMPTY — the parser is stale, not the mirror clean');
    for (const name of [...inventory].sort()) {
      if (!polyfills.has(name)) add('D', `runtime/README.md advertises polyfill \`${name}\`, but it is not in polyfills.sh/.c`);
    }
  }

  return { findings, resolved, counts: { A: Object.keys(surface).length, B: whitelist ? whitelist.length : 0, C: Object.keys((baseline && baseline.ops) || {}).length, D: inventory ? inventory.size : 0 } };
}

// ── corpus rendering ──────────────────────────────────────────────────
function renderFile(file) {
  const r = spawnSync(BIN, ['-O3', '--target', 'estree', file], {
    encoding: 'utf8',
    env: { ...process.env, OTRANSPILER_ROOT: ROOT },
    maxBuffer: 64 * 1024 * 1024,
    timeout: 120_000,
  });
  if (r.error) throw new Error(`spawn ${BIN}: ${r.error.message}`);
  if (r.status !== 0) return { error: `exit ${r.status}${r.signal ? ` (${r.signal})` : ''}`, stderr: r.stderr };
  try {
    return { program: JSON.parse(r.stdout) };
  } catch (e) {
    return { error: `invalid JSON: ${e.message}` };
  }
}

function readJsonArtifact(file) {
  try {
    return { program: JSON.parse(fs.readFileSync(file, 'utf8')) };
  } catch (e) {
    return { error: `cannot read/parse ${file}: ${e.message}` };
  }
}

// ── selftest: prove each check can FAIL ───────────────────────────────
// A checker that only ever prints "ok" is worse than none. Each control
// fabricates the exact shape the check exists for and asserts it is reported.
function selftest() {
  const mk = (calls) => ({
    type: 'Program',
    sourceType: 'module',
    body: calls.map(([op, argc]) => ({
      type: 'ExpressionStatement',
      expression: {
        type: 'CallExpression',
        callee: op
          .split('.')
          .slice(1)
          .reduce(
            (obj, name) => ({
              type: 'MemberExpression',
              computed: false,
              optional: false,
              object: obj,
              property: { type: 'Identifier', name },
            }),
            { type: 'Identifier', name: op.split('.')[0] },
          ),
        arguments: Array.from({ length: argc }, () => ({ type: 'Literal', value: 'x', raw: '"x"' })),
      },
    })),
  });

  const root = { sh2: RUNTIME }; // resolved in main() before calling
  const ctx = { sh2: root.sh2, whitelist: gateWhitelist(), polyfills: polyfillNames(), inventory: readmeInventory(), baseline: null };
  const controls = [];
  const check = (name, surface, expectSection) => {
    const { findings } = analyse(surface, ctx);
    const hit = findings.find((f) => f.section === expectSection);
    controls.push({ name, ok: Boolean(hit), msg: hit ? hit.msg : '(no finding)' });
  };

  check('missing op is reported', surfaceFromMap(collectOps(mk([['sh2.noSuchOpAnywhere', 0]]))), 'A');
  check('too many arguments is reported', surfaceFromMap(collectOps(mk([['sh2.param', 9]]))), 'A');
  {
    // sh2._r is a string field, so `_r.split` is String.prototype.split: this
    // must RESOLVE (kind: method), not be reported missing.
    const surface = surfaceFromMap(collectOps(mk([['sh2._r.split', 1]])));
    const { findings, resolved } = analyse(surface, ctx);
    const hit = resolved.get('sh2._r.split');
    const aFindings = findings.filter((f) => f.section === 'A');
    controls.push({
      name: 'value-root method resolves (sh2._r.split -> String.prototype.split)',
      ok: Boolean(hit && hit.r.kind === 'method' && hit.r.owner === 'string' && aFindings.length === 0),
      msg: hit ? `resolved as ${hit.r.owner} method` : '(did not resolve)',
    });
  }
  // B: a name the runtime lacks, injected into the whitelist
  {
    const { findings } = analyse(surfaceFromMap(new Map()), { ...ctx, whitelist: [...ctx.whitelist, 'zzNotAnOp'] });
    const hit = findings.find((f) => f.section === 'B' && f.msg.includes('zzNotAnOp'));
    controls.push({ name: 'unknown whitelist name is reported', ok: Boolean(hit), msg: hit ? hit.msg : '(no finding)' });
  }
  // C: drift against a fabricated baseline
  {
    const surface = surfaceFromMap(collectOps(mk([['sh2.param', 3]])));
    const { findings } = analyse(surface, { ...ctx, baseline: { ops: { 'sh2.goneOp': { argcs: [], kinds: {} } } } });
    const hit = findings.find((f) => f.section === 'C' && f.msg.includes('sh2.goneOp'));
    controls.push({ name: 'baseline drift is reported', ok: Boolean(hit), msg: hit ? hit.msg : '(no finding)' });
  }
  // D: an advertised polyfill that does not exist
  {
    const { findings } = analyse(surfaceFromMap(new Map()), { ...ctx, inventory: new Set(['zzNotAPolyfill']) });
    const hit = findings.find((f) => f.section === 'D' && f.msg.includes('zzNotAPolyfill'));
    controls.push({ name: 'missing advertised polyfill is reported', ok: Boolean(hit), msg: hit ? hit.msg : '(no finding)' });
  }

  let bad = 0;
  for (const c of controls) {
    console.log(`${c.ok ? 'PASS' : 'FAIL'}  ${c.name}${c.ok ? '' : `\n        ${c.msg}`}`);
    if (!c.ok) bad++;
  }
  console.log(`selftest: ${controls.length - bad}/${controls.length} controls fired`);
  return bad === 0 ? 0 : 1;
}

// ── main ──────────────────────────────────────────────────────────────
const { sh2: RUNTIME } = await import(NS);

if (opt.selftest) process.exit(selftest());

const opMap = new Map();
let scanned = 0;
const renderErrors = [];
for (const f of opt.files) {
  const r = renderFile(f);
  scanned++;
  if (r.error) {
    renderErrors.push(`${path.basename(f)}: ${r.error}${r.stderr ? `: ${r.stderr.split('\n')[0]}` : ''}`);
    continue;
  }
  collectOps(r.program, opMap);
}
for (const f of opt.jsons) {
  const r = readJsonArtifact(f);
  if (r.error) {
    renderErrors.push(r.error);
    continue;
  }
  scanned++;
  collectOps(r.program, opMap);
}
if (!opt.quiet) {
  console.log(`estree-contract: ${scanned - renderErrors.length}/${scanned} artifacts, ${opMap.size} distinct sh2.* ops`);
}
if (scanned && opMap.size === 0) {
  console.error('estree-contract: no sh2.* calls found — the scan is broken or the corpus emptied (nothing was checked)');
  process.exit(2);
}

const surface = surfaceFromMap(opMap);
if (opt.printOps) {
  for (const [op, e] of Object.entries(surface)) {
    console.log(`${op}  argc=${JSON.stringify(e.argcs)}  kinds=${JSON.stringify(e.kinds)}`);
  }
  process.exit(0);
}

let baseline = null;
if (fs.existsSync(BASELINE)) {
  try {
    baseline = JSON.parse(fs.readFileSync(BASELINE, 'utf8'));
  } catch (e) {
    console.error(`estree-contract: ${BASELINE} is not valid JSON: ${e.message}`);
    process.exit(2);
  }
}

if (opt.update) {
  const before = baseline ? baseline.ops || {} : null;
  const doc = {
    _comment:
      'Generated by harness/estree-contract.mjs --update: the sh2.* call surface the example corpus emits. ' +
      'Each op records the argument counts and the static argument KINDS per position. Re-run --update deliberately ' +
      'when the emitter changes; the checker fails on any difference, and separately on any op the runtime lacks.',
    artifacts: scanned,
    ops: surface,
  };
  fs.writeFileSync(BASELINE, `${JSON.stringify(doc, null, 1)}\n`);
  console.log(`estree-contract: wrote ${path.relative(ROOT, BASELINE)} (${Object.keys(surface).length} ops, ${scanned} artifacts)`);
  if (before) {
    const added = Object.keys(surface).filter((o) => !(o in before));
    const removed = Object.keys(before).filter((o) => !(o in surface));
    if (added.length) console.log(`  added:   ${added.join(' ')}`);
    if (removed.length) console.log(`  removed: ${removed.join(' ')}`);
  }
  process.exit(0);
}

const { findings, resolved, counts } = analyse(surface, {
  sh2: RUNTIME,
  whitelist: gateWhitelist(),
  polyfills: polyfillNames(),
  inventory: readmeInventory(),
  baseline,
});

if (!opt.quiet) {
  const sections = { A: 'runtime presence/arity', B: 'gate whitelist', C: 'surface snapshot', D: 'polyfill mirror' };
  for (const [k, label] of Object.entries(sections)) {
    const n = findings.filter((f) => f.section === k).length;
    const unit = { A: 'emitted ops', B: 'whitelist names', C: 'snapshot ops', D: 'advertised polyfills' }[k];
    console.log(`  ${k}. ${label}: ${n === 0 ? 'ok' : `${n} finding(s)`}  (${counts[k]} ${unit})`);
  }
  const unknownRoots = [...resolved.entries()].filter(([, v]) => v.r.kind !== 'function' && v.r.kind !== 'method');
  if (unknownRoots.length) {
    console.log(`  note: ${unknownRoots.map(([op]) => op).join(' ')} resolve to non-functions`);
  }
}
if (resolved.size && !opt.quiet) {
  console.log(`  checked ${resolved.size}/${Object.keys(surface).length} emitted ops against ${path.relative(ROOT, NS)}`);
}
for (const f of renderErrors) console.log(`  render: ${f}`);

if (findings.length) {
  console.log('');
  for (const f of findings) console.log(`FAIL [${f.section}] ${f.msg}`);
  console.log(`\nestree-contract: ${findings.length} finding(s)`);
  process.exit(1);
}
if (!opt.quiet) console.log('estree-contract: contract holds');
process.exit(0);
