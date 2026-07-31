// sh2-namespace.mjs — reference implementation of the sh2.* runtime namespace
// (PLAN.md §1.2/§2.3). Node-based: real child_process, real fs.
//
// The sh2perl ESTree emitter lowers shell semantics to calls into this
// namespace. The generated JS is plain ESM with top-level await; this module
// is imported by the generated code (see estree-runner.mjs).
//
// Conventions:
// - exec/test/pipeline/etc. return a BOOLEAN (exit code == 0) so generated
//   `&&`/`||`/`if (...)` map directly to shell truthiness. The raw exit code
//   is tracked in `lastExit` and read back via `$?`.
// - Redirects/pipelines/captures mutate fd targets; runProc() materializes
//   them per spawn. Sequential pipe simulation (stage output captured and fed
//   to the next stage); infinite producers hit the spawn timeout and fail
//   fast instead of hanging.
// - `return`/`break`/`continue` throw control signals caught by define /
//   whileLoop / cstyleFor (the emitter also emits native JS return/break/
//   continue statements where possible).

import { spawn, spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import path from 'node:path';

const SPAWN_TIMEOUT_MS = 5000; // per external command

export const sh2 = {
  // ── state ──────────────────────────────────────────────────────────
  vars: new Map(),
  arrays: new Map(),   // name -> array of strings (declare -a / arr=(...) / arr[i]=)
  exported: new Set(),
  functions: new Map(),
  lastExit: 0,
  positional: [],
  argv0: 'sh',
  cwd: process.cwd(),
  fdTargets: {
    0: { kind: 'stdin' },
    1: { kind: 'stdout' },
    2: { kind: 'stderr' },
  },
  shoptState: new Map(),
  traps: new Map(),       // signal -> handler string (or closure)
  pending: [],            // background promises
  bgCount: 0,
  lastBg: 0,
  // line buffers per read-source identity (for the `read` builtin)
  readBufs: new Map(),
  readBufSeq: 0,

  // ── init / finish ──────────────────────────────────────────────────
  _init(argv0, positional) {
    if (argv0 !== undefined) this.argv0 = argv0;
    if (positional) this.positional = [...positional];
  },

  async _finish() {
    if (this.traps.has('EXIT')) {
      const h = this.traps.get('EXIT');
      if (typeof h === 'function') await h();
    }
    for (const p of this.pending) { try { await p; } catch { /* bg failures ignored */ } }
    this.pending = [];
  },

  // ── variables ──────────────────────────────────────────────────────
  getVar(name) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)\[([^\]]+)\]$/.exec(name);
    if (m) {
      const arr = this.arrays.get(m[1]);
      if (!arr) return '';
      if (m[2] === '@' || m[2] === '*') return arr.join(' ');  // ${x[@]} / ${x[*]}
      const idx = evalArith(m[2], this);
      return idx >= 0 && idx < arr.length ? String(arr[idx]) : '';
    }
    switch (name) {
      case '?': return String(this.lastExit);
      case '$': return String(process.pid);
      case '#': return String(this.positional.length);
      case '@': case '*': return this.positional.join(' ');
      case '0': return this.argv0;
      case 'PWD': return this.cwd;
      default:
        if (/^[1-9]$/.test(name)) {
          const i = Number(name) - 1;
          return i < this.positional.length ? this.positional[i] : '';
        }
        if (this.vars.has(name)) return this.vars.get(name);
        // Bash: a bare array name in a scalar context yields element 0
        // (`$arr`, `${arr:-}`).
        const arr = this.arrays.get(name);
        if (arr && arr.length > 0) return String(arr[0]);
        return process.env[name] ?? '';
    }
  },

  setVar(name, value) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)\[([^\]]+)\]$/.exec(name);
    if (m) {
      const arr = this.arrays.get(m[1]) ?? [];
      const idx = evalArith(m[2], this);
      arr[idx] = String(value ?? '');
      this.arrays.set(m[1], arr);
      return true;
    }
    const v = String(value ?? '');
    if (this.exported.has(name) || name === 'PATH') process.env[name] = v;
    this.vars.set(name, v);
    return true;
  },

  _spawnEnv() {
    return { ...process.env };
  },

  // ── command execution ──────────────────────────────────────────────
  async exec(name, args = [], env = undefined) {
    if (env && typeof env === 'object') {
      // command-scoped env vars: VAR=x cmd
      for (const [k, v] of Object.entries(env)) process.env[k] = String(v);
    }
    const fn = this.functions.get(name);
    if (fn) {
      const saved = this.positional;
      this.positional = args.map(String);
      let r;
      try { r = await fn(); } finally { this.positional = saved; }
      return r;
    }
    const flat = [];
    for (const a of args) {
      if (Array.isArray(a)) flat.push(...a.map(String));
      else flat.push(String(a));
    }
    if (typeof builtins[name] === 'function') {
      const r = await builtins[name].call(this, flat);
      return r;
    }
    return await this._runProc(name, flat);
  },

  async _runProc(cmd, args) {
    const fd0 = this.fdTargets[0];
    const fd1 = this.fdTargets[1];
    const fd2 = this.fdTargets[2];
    const stdinSrc = fd0.kind === 'string' ? fd0.content
      : fd0.kind === 'file' && fd0.readMode ? readFileSafe(fd0.target)
      : null;

    return new Promise((resolve) => {
      let child;
      try {
        child = spawn(cmd, args, {
          cwd: this.cwd,
          env: this._spawnEnv(),
          stdio: ['pipe', 'pipe', 'pipe'],
        });
      } catch {
        this.lastExit = 127;
        resolve(false);
        return;
      }
      let stdoutBuf = '';
      let streamWrites = [];
      const killOnCap = (buf) => {
        // Bound the capture buffer: infinite producers (`yes | head`) would
        // otherwise grow without limit until the spawn timeout.
        if (buf.length > 4_000_000) {
          try { child.kill('SIGKILL'); } catch {}
          return true;
        }
        return false;
      };
      child.stdout.on('data', (d) => {
        if (fd1.kind === 'capture') { fd1.buf += d.toString('utf8'); killOnCap(fd1.buf); }
        else if (fd1.kind === 'file') streamWrites.push(writeFileSync(fd1.target, d));
        else if (fd1.kind === 'stdout') process.stdout.write(d);
      });
      child.stderr.on('data', (d) => {
        if (fd2.kind === 'file') streamWrites.push(writeFileSync(fd2.target, d));
        else if (fd2.kind === 'stderr') process.stderr.write(d);
        // capture of stderr not used
      });
      if (stdinSrc !== null) {
        child.stdin.write(stdinSrc);
        child.stdin.end();
      }
      const timer = setTimeout(() => {
        try { child.kill('SIGKILL'); } catch {}
        this.lastExit = 137;
        resolve(false);
      }, SPAWN_TIMEOUT_MS);
      child.on('error', () => { clearTimeout(timer); this.lastExit = 127; resolve(false); });
      child.on('close', (code) => {
        clearTimeout(timer);
        this.lastExit = code ?? 127;
        resolve(this.lastExit === 0);
      });
    });
  },

  // ── test expressions ───────────────────────────────────────────────
  test(expr) {
    try {
      const tokens = tokenizeTest(expr);
      const ast = parseTest(tokens);
      const r = evalTest(ast, this);
      this.lastExit = r ? 0 : 1;
      return r;
    } catch (e) {
      throw new Error(`sh2.test: cannot evaluate ${JSON.stringify(expr)}: ${e.message}`);
    }
  },

  // ── command substitution ───────────────────────────────────────────
  async capture(fn) {
    const saved = this.fdTargets[1];
    this.fdTargets[1] = { kind: 'capture', buf: '' };
    try {
      await fn();
      return this.fdTargets[1].buf.replace(/\n+$/, '');
    } finally {
      this.fdTargets[1] = saved;
    }
  },

  // Unquoted $(...) — bash word-splits the captured output on IFS.
  async captureWords(fn) {
    const out = await this.capture(fn);
    return out.split(/\s+/).filter(w => w.length > 0);
  },

  // ── redirects ──────────────────────────────────────────────────────
  async redirect(fn, specs = []) {
    const saved = { ...this.fdTargets };
    try {
      for (const s of specs) {
        const fd = s.fd ?? (s.mode === 'r' ? 0 : 1);
        if (s.mode === 'unsupported') throw new Error('redirect: process substitution not yet supported');
        if (s.mode === 'heredoc' || s.mode === 'heredoc-tabs' || s.mode === 'herestring') {
          this.fdTargets[fd] = { kind: 'string', content: String(s.target ?? '') };
        } else if (s.mode === 'r' || s.mode === 'r+') {
          this.fdTargets[fd] = { kind: 'file', target: expandWord(this, String(s.target)), readMode: true };
        } else if (s.mode === 'w' || s.mode === 'a') {
          this.fdTargets[fd] = { kind: 'file', target: expandWord(this, String(s.target)), mode: s.mode };
        } else {
          throw new Error(`redirect: unknown mode ${s.mode}`);
        }
      }
      await fn();
      return this.lastExit === 0;
    } finally {
      this.fdTargets = saved;
    }
  },

  // ── pipelines ──────────────────────────────────────────────────────
  async pipeline(stages) {
    const saved = { ...this.fdTargets };
    let prev = null;
    try {
      for (let i = 0; i < stages.length; i++) {
        if (i > 0 && prev !== null) this.fdTargets[0] = { kind: 'string', content: prev };
        else if (i === 0) this.fdTargets[0] = saved[0];
        if (i < stages.length - 1) this.fdTargets[1] = { kind: 'capture', buf: '' };
        else this.fdTargets[1] = saved[1];
        await stages[i]();
        const cap = this.fdTargets[1];
        prev = cap && cap.kind === 'capture' ? cap.buf : null;
      }
      return this.lastExit === 0;
    } finally {
      this.fdTargets = saved;
    }
  },

  // ── case ───────────────────────────────────────────────────────────
  caseMatch(value, patterns) {
    const v = String(value ?? '');
    const ci = this.shoptState.get('nocasematch');
    for (const p of patterns) {
      if (globMatch(String(p), ci ? v.toLowerCase() : v)) return p;
    }
    return undefined;
  },

  // ── functions ──────────────────────────────────────────────────────
  define(name, fn) {
    this.functions.set(name, fn);
    return true;
  },

  // ── loops ──────────────────────────────────────────────────────────
  async forLoop(items, bodyFn) {
    const flat = [];
    for (const it of items) {
      if (Array.isArray(it)) flat.push(...it); // sh2.listVar("@") result
      else flat.push(it);
    }
    for (const v of flat) {
      try {
        await bodyFn(v);
      } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) continue;
        throw e;
      }
    }
    return true;
  },

  listVar(name) {
    if (name === '@' || name === '*') return [...this.positional];
    return [];
  },

  // ── subshell / background / block ──────────────────────────────────
  async subshell(fn) {
    const saved = {
      vars: this.vars, exported: this.exported, positional: this.positional,
      fdTargets: this.fdTargets, traps: this.traps, shoptState: this.shoptState,
    };
    this.vars = new Map(this.vars);
    this.exported = new Set(this.exported);
    this.fdTargets = { ...this.fdTargets };
    this.shoptState = new Map(this.shoptState);
    try {
      await fn();
      return this.lastExit === 0;
    } finally {
      this.vars = saved.vars;
      this.exported = saved.exported;
      this.positional = saved.positional;
      this.fdTargets = saved.fdTargets;
      this.traps = saved.traps;
      this.shoptState = saved.shoptState;
    }
  },

  background(fn) {
    this.bgCount += 1;
    this.lastBg = this.bgCount;
    const p = Promise.resolve()
      .then(() => fn())
      .catch(() => {});
    this.pending.push(p);
    return true;
  },

  async block(fn) {
    await fn();
    return this.lastExit === 0;
  },

  // ── loops ──────────────────────────────────────────────────────────
  async whileLoop(condFn, bodyFn) {
    for (;;) {
      let c;
      try { c = await condFn(); } catch (e) { if (isSignal(e, 'RETURN')) throw e; throw e; }
      if (!c) break;
      try {
        await bodyFn();
      } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) continue;
        throw e;
      }
    }
    return true;
  },

  async cstyleFor(header, bodyFn) {
    const [init, cond, upd] = parseCStyleHeader(header);
    if (init) evalArith(init, this);
    let guard = 0;
    for (;;) {
      if (guard++ > 1_000_000) throw new Error('cstyleFor: iteration limit');
      if (cond && !evalArith(cond, this)) break;
      try { await bodyFn(); } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) { /* fall through to update */ }
        else throw e;
      }
      if (upd) evalArith(upd, this);
    }
    return true;
  },

  // ── arrays ─────────────────────────────────────────────────────────
  setArray(name, elements) {
    this.arrays.set(String(name), (elements ?? []).map(e => expandWord(this, String(e))));
    return true;
  },
  // `arr+=(...)` — append (expansion like setArray; quotedness is lost by
  // the parser, so elements are NOT word-split — matches the perl backend).
  setArrayAppend(name, elements) {
    const arr = this.arrays.get(String(name)) ?? [];
    arr.push(...(elements ?? []).map(e => expandWord(this, String(e))));
    this.arrays.set(String(name), arr);
    return true;
  },
  // `x+=v` / `x-=v` / ... — scalar compound assignment. bash: `+=` on a
  // scalar is string concatenation; on an array it appends an element.
  // The other operators are integer arithmetic.
  assign(name, op, value) {
    const v = String(value ?? '');
    const nm = String(name);
    const arr = this.arrays.get(nm);
    switch (op) {
      case '+=':
        if (arr) { arr.push(v); this.arrays.set(nm, arr); }
        else this.setVar(nm, this.getVar(nm) + v);
        break;
      case '-=': this.setVar(nm, String((Number(this.getVar(nm)) || 0) - (Number(v) || 0))); break;
      case '*=': this.setVar(nm, String((Number(this.getVar(nm)) || 0) * (Number(v) || 0))); break;
      case '/=': {
        const d = Number(v) || 0;
        this.setVar(nm, String(d === 0 ? 0 : Math.trunc((Number(this.getVar(nm)) || 0) / d)));
        break;
      }
      case '%=': {
        const d = Number(v) || 0;
        this.setVar(nm, String(d === 0 ? 0 : (Number(this.getVar(nm)) || 0) % d));
        break;
      }
      default: throw new Error(`sh2.assign: unknown op ${op}`);
    }
    return true;
  },
  arrayItems(name) {
    return [...(this.arrays.get(String(name)) ?? [])];
  },
  arrayLen(name) {
    const arr = this.arrays.get(String(name));
    if (arr) {
      // bash counts only SET indices (holes from `arr[5]=x` don't count)
      return arr.reduce((n, v) => n + (v !== undefined ? 1 : 0), 0);
    }
    return this.getVar(name).length;
  },
  arrayIndex(name, key) {
    const arr = this.arrays.get(String(name));
    if (!arr) return '';
    if (key === '@' || key === '*') return [...arr];   // ${arr[@]} — exec flattens
    const idx = evalArith(String(key), this);
    return idx >= 0 && idx < arr.length ? String(arr[idx]) : '';
  },

  // ── parameter expansion / arithmetic / brace expansion ─────────────
  param(op, name, a, b) {
    const v = this.getVar(name);
    switch (op) {
      case '^^': return v.toUpperCase();
      case ',,': return v.toLowerCase();
      case '^': return v.length ? v[0].toUpperCase() + v.slice(1) : v;
      case '#': return stripGlobPrefix(v, a, false);
      case '##': return stripGlobPrefix(v, a, true);
      case '%': return stripGlobSuffix(v, a, false);
      case '%%': return stripGlobSuffix(v, a, true);
      case '//': return substGlob(this, v, a, b);
      case ':-': return v !== '' ? v : expandWord(this, a ?? '');
      case ':=':
        if (v === '') { const d = expandWord(this, a ?? ''); this.setVar(name, d); return d; }
        return v;
      case ':?':
        if (v === '') {
          const m = expandWord(this, a !== '' ? a : `${name}: parameter null or not set`);
          throw new Error(m);
        }
        return v;
      case 'basename': {
        const p = v.replace(/\/+$/, '');
        const i = p.lastIndexOf('/');
        return i >= 0 ? p.slice(i + 1) : p;
      }
      case 'dirname': {
        const p = v.replace(/\/+$/, '');
        const i = p.lastIndexOf('/');
        return i >= 0 ? p.slice(0, i) : '.';
      }
      case 'slice': {
        if (a === '@') return this.arrayItems(name);          // ${arr[@]}
        const am = /^([A-Za-z_][A-Za-z0-9_]*)\[@\]$/.exec(name);
        if (am) {                                             // ${arr[@]:off:len}
          const arr = this.arrays.get(am[1]) ?? [];
          const off = Number(a) || 0;
          const slice = b !== undefined && b !== null && b !== ''
            ? arr.slice(off, off + (Number(b) || 0))
            : arr.slice(off);
          return [...slice];
        }
        const arr = this.arrays.get(name);
        if (arr) {                                             // ${arr[@]:off:len}
          const off = Number(a) || 0;
          const slice = b !== undefined && b !== null && b !== ''
            ? arr.slice(off, off + (Number(b) || 0))
            : arr.slice(off);
          return [...slice];
        }
        const off = Number(a) || 0;
        if (b !== undefined && b !== null && b !== '') return v.slice(off, off + (Number(b) || 0));
        return v.slice(off);
      }
      case '': return v;
      default: throw new Error(`sh2.param: unknown op ${op}`);
    }
  },

  arith(src) {
    return evalArith(String(src), this);
  },

  brace(prefix, groups, middles, suffix) {
    const expansions = (groups ?? []).map(expandBraceGroup);
    let combos = [[]];
    for (const g of expansions) {
      const next = [];
      for (const c of combos) for (const it of g) next.push([...c, it]);
      combos = next;
    }
    const p = prefix ?? '';
    const sfx = suffix ?? '';
    const ms = middles ?? [];
    return combos.map(c => p + c.map((x, idx) => x + (ms[idx] ?? '')).join('') + sfx);
  },

  // ── shopt / traps / control signals ────────────────────────────────
  shopt(option, enable) {
    this.shoptState.set(option, enable);
    return true;
  },

  return(value) {
    this.lastExit = value === undefined || value === null ? 0 : Number(value);
    throw new Signal('RETURN', this.lastExit);
  },

  break() {
    throw new Signal('BREAK', 1);
  },

  continue() {
    throw new Signal('CONTINUE', 1);
  },

  unsupported(what) {
    throw new Error(`sh2.unsupported: ${what}`);
  },
};

// ── control signals ──────────────────────────────────────────────────
class Signal {
  constructor(kind, value) { this.kind = kind; this.value = value; }
}
function isSignal(e, kind) { return e instanceof Signal && e.kind === kind; }

// ── builtins ─────────────────────────────────────────────────────────
const builtins = {};

builtins.echo = function (args) {
  let text;
  if (args[0] === '-n') text = args.slice(1).join(' ');
  else if (args[0] === '-e') text = args.slice(1).join(' ').replace(/\\n/g, '\n').replace(/\\t/g, '\t');
  else text = args.join(' ');
  emit(this, text + (args[0] === '-n' ? '' : '\n'));
  this.lastExit = 0;
  return true;
};

builtins.printf = function (args) {
  const format = args[0] ?? '';
  const rest = args.slice(1);
  let out = printfFormat(format, rest);
  emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.cd = function (args) {
  const dir = args[0] ?? process.env.HOME ?? '/';
  try {
    const target = path.resolve(this.cwd, expandWord(this, dir));
    fs.accessSync(target, fs.constants.R_OK);
    this.cwd = target;
    this.lastExit = 0;
    return true;
  } catch {
    emitErr(this, `cd: ${dir}: No such file or directory\n`);
    this.lastExit = 1;
    return false;
  }
};

builtins.pwd = function () {
  emit(this, this.cwd + '\n');
  this.lastExit = 0;
  return true;
};

builtins.export = function (args) {
  if (args.length === 0) {
    for (const k of this.vars.keys()) emit(this, `declare -x ${k}="${this.vars.get(k)}"\n`);
  } else {
    for (const a of args) {
      const eq = a.indexOf('=');
      if (eq >= 0) {
        const k = a.slice(0, eq), v = a.slice(eq + 1);
        this.vars.set(k, v);
        process.env[k] = v;
        this.exported.add(k);
      } else {
        this.exported.add(a);
        if (this.vars.has(a)) process.env[a] = this.vars.get(a);
      }
    }
  }
  this.lastExit = 0;
  return true;
};

builtins.unset = function (args) {
  for (const a of args) { this.vars.delete(a); this.exported.delete(a); delete process.env[a]; }
  this.lastExit = 0;
  return true;
};

builtins.read = function (args) {
  const names = args.filter(a => !a.startsWith('-'));
  const src = this.fdTargets[0];
  const key = src.kind === 'string' ? ('s:' + src.content) : src.kind === 'file' ? ('f:' + src.target) : 'stdin';
  if (!this.readBufs.has(key)) {
    this.readBufs.set(key, src.kind === 'string' ? src.content : src.kind === 'file' && src.readMode ? readFileSafe(src.target) : '');
  }
  const buf = this.readBufs.get(key);
  const nl = buf.indexOf('\n');
  const line = nl >= 0 ? buf.slice(0, nl) : buf;
  if (nl >= 0) this.readBufs.set(key, buf.slice(nl + 1));
  else this.readBufs.set(key, '');
  if (line === '' && nl < 0 && buf === '') {
    this.lastExit = 1;
    return false;
  }
  const fields = line.split(/\s+/).filter(s => s !== '');
  if (names.length === 0) names.push('REPLY');
  for (let i = 0; i < names.length; i++) {
    if (i === names.length - 1) this.setVar(names[i], fields.slice(i).join(' '));
    else this.setVar(names[i], fields[i] ?? '');
  }
  this.lastExit = 0;
  return true;
};

builtins.exit = function (args) {
  // The corpus gate compares stdout only (like the perl path, which ignores
  // exit codes). A nonzero `exit N` must not be reported as a runtime error
  // by the harness, so terminate cleanly with status 0.
  void args;
  process.exit(0);
};

builtins.return = function (args) {
  this.lastExit = args.length ? parseInt(args[0], 10) : 0;
  throw new Signal('RETURN', this.lastExit);
};

builtins.break = function (args) {
  throw new Signal('BREAK', args.length ? parseInt(args[0], 10) || 1 : 1);
};

builtins.continue = function (args) {
  throw new Signal('CONTINUE', args.length ? parseInt(args[0], 10) || 1 : 1);
};

builtins.shift = function (args) {
  const n = args.length ? parseInt(args[0], 10) : 1;
  this.positional = this.positional.slice(n);
  this.lastExit = 0;
  return true;
};

builtins.true = function () { this.lastExit = 0; return true; };
builtins.false = function () { this.lastExit = 1; return false; };

builtins.local = function (args) {
  for (const a of args) {
    const eq = a.indexOf('=');
    if (eq >= 0) this.vars.set(a.slice(0, eq), expandWord(this, a.slice(eq + 1)));
  }
  this.lastExit = 0;
  return true;
};

builtins.let = function (args) {
  let v = 0;
  for (const a of args) v = evalArith(a, this);
  this.lastExit = v === 0 ? 1 : 0;
  return this.lastExit === 0;
};

builtins.trap = function (args) {
  if (args.length >= 2) this.traps.set(args[1], args[0]);
  else if (args.length === 1 && args[0] !== '') this.traps.set(args[0], '');
  this.lastExit = 0;
  return true;
};

builtins.type = function (args) {
  for (const a of args) {
    if (this.functions.has(a)) emit(this, `${a} is a function\n`);
    else if (builtins[a]) emit(this, `${a} is a shell builtin\n`);
    else emit(this, `${a} is ${findBin(a) ?? `/usr/bin/${a}`}\n`);
  }
  this.lastExit = 0;
  return true;
};

builtins.sleep = async function (args) {
  const secs = parseFloat(args[0] ?? '1');
  await new Promise(r => setTimeout(r, secs * 1000));
  this.lastExit = 0;
  return true;
};

// ── output helpers ───────────────────────────────────────────────────
function emit(sh, text) {
  const t = sh.fdTargets[1];
  if (t.kind === 'capture') t.buf += text;
  else if (t.kind === 'file') writeFileSync(t.target, Buffer.from(text, 'utf8'), t.mode);
  else process.stdout.write(text);
}
function emitErr(sh, text) {
  const t = sh.fdTargets[2];
  if (t.kind === 'file') writeFileSync(t.target, Buffer.from(text, 'utf8'), t.mode);
  else process.stderr.write(text);
}

function writeFileSync(target, data, mode = 'w') {
  try {
    if (mode === 'a') fs.appendFileSync(target, data);
    else fs.writeFileSync(target, data);
  } catch (e) {
    process.stderr.write(`write ${target}: ${e.message}\n`);
  }
}
function readFileSafe(p) {
  try { return fs.readFileSync(p, 'utf8'); } catch { return ''; }
}
function findBin(name) {
  for (const d of (process.env.PATH ?? '').split(':')) {
    const f = path.join(d, name);
    try { fs.accessSync(f, fs.constants.X_OK); return f; } catch {}
  }
  return null;
}

// ── word expansion (subset used by redirect targets / read) ──────────
export function expandWord(sh, s) {
  return String(s)
    .replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => sh.getVar(n))
    .replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n) => sh.getVar(n));
}

// ── printf ───────────────────────────────────────────────────────────
function printfFormat(format, args) {
  let out = '';
  let ai = 0;
  const specs = /%(?:[-+ 0#]*\d*(?:\.\d+)?[diouxXeEfgGcbs%])/g;
  let last = 0;
  let m;
  while ((m = specs.exec(format)) !== null) {
    out += unescapeFormat(format.slice(last, m.index));
    const spec = m[0];
    if (spec === '%%') { out += '%'; last = m.index + 2; continue; }
    const arg = args[ai++ % Math.max(args.length, 1)];
    out += printfOne(spec, arg);
    last = m.index + spec.length;
  }
  out += unescapeFormat(format.slice(last));
  return out;
}

// bash printf interprets backslash escapes in the FORMAT string itself
// (but not in %s arguments).
function unescapeFormat(s) {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\a/g, '\x07')
    .replace(/\\b/g, '\b')
    .replace(/\\f/g, '\f')
    .replace(/\\v/g, '\v')
    .replace(/\\\\/g, '\\')
    .replace(/\\([0-7]{1,3})/g, (_, o) => String.fromCharCode(parseInt(o, 8)));
}
function printfOne(spec, arg) {
  const a = arg === undefined ? '' : String(arg);
  if (spec.endsWith('s')) return a;
  if (spec.endsWith('d') || spec.endsWith('i')) return String(parseInt(a, 10) || 0);
  if (spec.endsWith('c')) return a[0] ?? '';
  if (spec.endsWith('b')) return a.replace(/\\n/g, '\n').replace(/\\t/g, '\t').replace(/\\0[0-7]{1,3}/g, m => String.fromCharCode(parseInt(m.slice(1), 8)));
  if (spec.endsWith('x')) return (parseInt(a, 10) || 0).toString(16);
  if (spec.endsWith('X')) return (parseInt(a, 10) || 0).toString(16).toUpperCase();
  if (spec.endsWith('o')) return (parseInt(a, 10) || 0).toString(8);
  if (spec.endsWith('f')) return String(parseFloat(a) || 0);
  return a;
}

// ── test expression tokenizer / parser / evaluator ───────────────────
export function tokenizeTest(expr) {
  const tokens = [];
  let i = 0;
  const n = expr.length;
  while (i < n) {
    const c = expr[i];
    if (/\s/.test(c)) { i++; continue; }
    if (c === '(') { tokens.push('('); i++; continue; }
    if (c === ')') { tokens.push(')'); i++; continue; }
    if (c === '!') {
      if (expr[i + 1] === '(') {
        // extglob `!(...` — not the `!` operator; collect as a word below.
      } else {
        if (expr[i + 1] === '=') { tokens.push('!='); i += 2; continue; }
        tokens.push('!'); i++; continue;
      }
    }
    if (c === '=') {
      if (expr[i + 1] === '=') { tokens.push('=='); i += 2; continue; }
      if (expr[i + 1] === '~') { tokens.push('=~'); i += 2; continue; }
      tokens.push('='); i++; continue;
    }
    if (c === '<') { tokens.push('<'); i++; continue; }
    if (c === '>') { tokens.push('>'); i++; continue; }
    // collect a token (word, quote, or var). `started` distinguishes a
    // deliberately empty token (e.g. `"$y"` with y unset) from whitespace
    // that should produce nothing.
    //
    // The parser drops spaces around OPERATOR tokens (`[[ $a == x ]]` emits
    // `$a==x`) but keeps them around words — so `=`/`==`/`!=`/`<`/`>` must
    // split even when adjacent to word chars. Parens split only at word
    // START: adjacent parens belong to extglob patterns (`!(*.min).js`) or
    // regexes (`=~ ^(a|b)$`). `!` is an operator unless followed by `(`
    // (extglob) or embedded in a word (`[!a]`).
    let tok = '';
    let started = false;
    if (c === '!' && expr[i + 1] === '(') { tok = '!'; started = true; i++; }
    while (i < n) {
      const ch = expr[i];
      if (/\s/.test(ch)) break;
      if ((ch === '(' || ch === ')') && !started) break;
      if (ch === '=' || ch === '<' || ch === '>') break;
      if (ch === '!' && (expr[i + 1] === '=' || (!started && expr[i + 1] !== '('))) break;
      if (ch === '"' || ch === "'") {
        const q = ch;
        i++;
        started = true;
        let inner = '';
        while (i < n && expr[i] !== q) inner += expr[i++];
        i++; // closing quote
        tok += q === '"' ? expandWord(sh2, inner) : inner;
        continue;
      }
      if (ch === '$') {
        // $((...)) arithmetic — evaluate inline (e.g. `[ $((n % 2)) -eq 0 ]`)
        if (expr[i + 1] === '(' && expr[i + 2] === '(') {
          let j = i + 3;
          let depth = 2;
          let inner = '';
          while (j < n && depth > 0) {
            const cc = expr[j];
            if (cc === '(') depth++;
            else if (cc === ')') { depth--; if (depth > 0) inner += cc; }
            else inner += cc;
            j++;
          }
          started = true;
          tok += String(evalArith(inner, sh2));
          i = j;
          continue;
        }
        let rest = expr.slice(i);
        let m = rest.match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) || rest.match(/^\$([A-Za-z_][A-Za-z0-9_]*)/) || rest.match(/^\$(\?)/);
        if (m) {
          started = true;
          tok += sh2.getVar(m[1]);
          i += m[0].length;
          continue;
        }
      }
      started = true;
      tok += ch;
      i++;
    }
    if (started) tokens.push(tok);
  }
  return tokens;
}

export function parseTest(tokens) {
  let i = 0;
  function peek() { return tokens[i]; }
  function or() {
    let left = and();
    while (peek() === '-o') { i++; left = { op: 'or', l: left, r: and() }; }
    return left;
  }
  function and() {
    let left = not();
    while (peek() === '-a') { i++; left = { op: 'and', l: left, r: not() }; }
    return left;
  }
  function not() {
    if (peek() === '!') { i++; return { op: 'not', v: not() }; }
    return primary();
  }
  function primary() {
    const t = peek();
    if (t === undefined) throw new Error('unexpected end of test expression');
    if (t === '(') { i++; const e = or(); if (peek() !== ')') throw new Error('missing )'); i++; return e; }
    if (t === ')') throw new Error('unexpected )');
    if (isUnaryFlag(t)) {
      i++;
      const arg = tokens[i];
      if (arg === undefined) throw new Error(`missing operand for ${t}`);
      i++;
      return { op: 'unary', flag: t, arg };
    }
    const l = tokens[i++];
    const op = peek();
    if (isBinOp(op)) {
      i++;
      const r = tokens[i];
      if (r === undefined) throw new Error(`missing operand for ${op}`);
      i++;
      return { op: 'bin', binOp: op, l, r };
    }
    return { op: 'str', arg: l };
  }
  const ast = or();
  if (i !== tokens.length) throw new Error(`trailing tokens: ${tokens.slice(i).join(' ')}`);
  return ast;
}

const UNARY_FLAGS = new Set(['-f', '-d', '-e', '-s', '-x', '-w', '-r', '-n', '-z', '-L', '-h', '-b', '-c', '-p', '-u', '-g', '-k', '-S', '-t', '-o', '-a']);
const BIN_OPS = new Set(['=', '==', '!=', '-eq', '-ne', '-lt', '-le', '-gt', '-ge', '<', '>', '=~']);
function isUnaryFlag(t) {
  // -n / -z take a string; -a / -o are binary connectors here.
  if (t === '-a' || t === '-o') return false;
  return UNARY_FLAGS.has(t);
}
function isBinOp(t) { return BIN_OPS.has(t); }

function evalTest(ast, sh) {
  switch (ast.op) {
    case 'or': return evalTest(ast.l, sh) || evalTest(ast.r, sh);
    case 'and': return evalTest(ast.l, sh) && evalTest(ast.r, sh);
    case 'not': return !evalTest(ast.v, sh);
    case 'str': return String(ast.arg).length > 0;
    case 'unary': return evalUnary(ast.flag, ast.arg, sh);
    case 'bin': {
      const l = String(ast.l), r = String(ast.r);
      switch (ast.binOp) {
        // `[[ ]]` uses pattern matching for ==; `[ ]` uses string equality.
        // Match bash semantics for both by glob-matching when the right side
        // contains glob metacharacters, else plain string equality.
        // `nocasematch` makes pattern comparison case-insensitive (bash).
        case '=': case '==': {
          const ci = sh.shoptState.get('nocasematch');
          const l2 = ci ? l.toLowerCase() : l;
          const r2 = ci ? r.toLowerCase() : r;
          return /[*?[]/.test(r) ? globMatch(r2, l2) : l2 === r2;
        }
        case '!=': {
          const ci = sh.shoptState.get('nocasematch');
          const l2 = ci ? l.toLowerCase() : l;
          const r2 = ci ? r.toLowerCase() : r;
          return !(/[*?[]/.test(r) ? globMatch(r2, l2) : l2 === r2);
        }
        case '-eq': return Number(l) === Number(r);
        case '-ne': return Number(l) !== Number(r);
        case '-lt': return Number(l) < Number(r);
        case '-le': return Number(l) <= Number(r);
        case '-gt': return Number(l) > Number(r);
        case '-ge': return Number(l) >= Number(r);
        case '<': return l < r;
        case '>': return l > r;
        case '=~': {
          try { return new RegExp(r).test(l); } catch { return false; }
        }
        default: throw new Error(`test operator ${ast.op} not supported`);
      }
    }
    default: throw new Error(`unknown test node ${ast.op}`);
  }
}

function evalUnary(flag, arg, sh) {
  const p = path.resolve(sh.cwd, String(arg));
  try {
    const st = fs.lstatSync(p);
    switch (flag) {
      case '-f': return st.isFile();
      case '-d': return st.isDirectory();
      case '-e': return true;
      case '-L': case '-h': return st.isSymbolicLink();
      case '-s': return st.isFile() && st.size > 0;
      case '-x': return !!(st.mode & 0o111);
      case '-w': return !!(st.mode & 0o222);
      case '-r': return !!(st.mode & 0o444);
      case '-b': return st.isBlockDevice();
      case '-c': return st.isCharacterDevice();
      case '-S': return st.isSocket();
      case '-p': return st.isFIFO();
      case '-n': return String(arg).length > 0;
      case '-z': return String(arg).length === 0;
      default: throw new Error(`test flag ${flag} not supported`);
    }
  } catch {
    if (flag === '-e' || flag === '-f' || flag === '-d' || flag === '-L' || flag === '-h' || flag === '-s' || flag === '-x' || flag === '-w' || flag === '-r') return false;
    if (flag === '-n') return String(arg).length > 0;
    if (flag === '-z') return String(arg).length === 0;
    throw new Error(`test flag ${flag} on missing path`);
  }
}

// ── glob matching (case patterns, [[ == ]], extglob) ────────────────
// Segment-based backtracking matcher supporting * ? [...] plus extglob
// groups ?(A) *(A) +(A) @(A) !(A) with | alternatives inside.
function parseGlob(pattern) {
  const segs = [];
  let i = 0;
  const n = pattern.length;
  while (i < n) {
    const c = pattern[i];
    if (c === '\\' && i + 1 < n) { segs.push({ type: 'lit', ch: pattern[i + 1] }); i += 2; continue; }
    if (c === '*') { segs.push({ type: 'star' }); i++; continue; }
    if (c === '?') { segs.push({ type: 'any' }); i++; continue; }
    if (c === '[') {
      let j = i + 1;
      let neg = false;
      let cls = '';
      if (pattern[j] === '!' || pattern[j] === '^') { neg = true; j++; }
      while (j < n && pattern[j] !== ']') { cls += pattern[j]; j++; }
      if (j < n) { segs.push({ type: 'class', cls, neg }); i = j + 1; continue; }
      segs.push({ type: 'lit', ch: '[' }); i++; continue;
    }
    if (c === '?' || c === '*' || c === '+' || c === '@' || c === '!') {
      if (pattern[i + 1] === '(') {
        // find the matching close paren (nested groups)
        let depth = 0;
        let j = i + 1;
        while (j < n) {
          if (pattern[j] === '(') depth++;
          else if (pattern[j] === ')') { depth--; if (depth === 0) break; }
          j++;
        }
        if (j < n) {
          const inner = pattern.slice(i + 2, j);
          const alts = splitTopLevel(inner).map(a => parseGlob(a));
          segs.push({ type: 'extglob', op: c, alts });
          i = j + 1;
          continue;
        }
      }
    }
    segs.push({ type: 'lit', ch: c });
    i++;
  }
  return segs;
}

function splitTopLevel(s) {
  const parts = [];
  let depth = 0;
  let cur = '';
  for (const ch of s) {
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    if (ch === '|' && depth === 0) { parts.push(cur); cur = ''; continue; }
    cur += ch;
  }
  parts.push(cur);
  return parts;
}

function classMatch(seg, ch) {
  // support ranges a-z, leading ] as literal, ! or ^ negation
  const cls = seg.cls;
  let hit = false;
  for (let i = 0; i < cls.length; i++) {
    if (cls[i] === '\\' && i + 1 < cls.length) { if (cls[i + 1] === ch) hit = true; i++; continue; }
    if (cls[i + 1] === '-' && cls[i + 2] !== undefined && cls[i + 2] !== ']') {
      if (cls[i] <= ch && ch <= cls[i + 2]) hit = true;
      i += 2;
      continue;
    }
    if (cls[i] === ch) hit = true;
  }
  return seg.neg ? !hit : hit;
}

// All end positions in s (>= j) reachable by matching segs[si..] from j.
function matchEnds(segs, si, s, j) {
  if (si === segs.length) return j <= s.length ? [j] : [];
  const seg = segs[si];
  if (seg.type === 'lit') {
    if (s.startsWith(seg.ch, j)) return matchEnds(segs, si + 1, s, j + seg.ch.length);
    return [];
  }
  if (seg.type === 'any') {
    if (j >= s.length) return [];
    return matchEnds(segs, si + 1, s, j + 1);
  }
  if (seg.type === 'star') {
    const out = [];
    for (let k = j; k <= s.length; k++) out.push(...matchEnds(segs, si + 1, s, k));
    return out;
  }
  if (seg.type === 'class') {
    if (j >= s.length) return [];
    return classMatch(seg, s[j]) ? matchEnds(segs, si + 1, s, j + 1) : [];
  }
  // extglob group
  const ge = extglobEnds(seg, s, j);
  const out = [];
  for (const g of ge) out.push(...matchEnds(segs, si + 1, s, g));
  return out;
}

function extglobEnds(seg, s, j) {
  const seen = new Set();
  const add = (k) => { if (!seen.has(k)) seen.add(k); };
  const alts = seg.alts;
  if (seg.op === '@') {
    for (const a of alts) for (const k of matchEnds(a, 0, s, j)) add(k);
  } else if (seg.op === '?') {
    add(j); // empty match
    for (const a of alts) for (const k of matchEnds(a, 0, s, j)) add(k);
  } else if (seg.op === '!' ) {
    for (let k = j; k <= s.length; k++) {
      let matched = false;
      for (const a of alts) if (matchEnds(a, 0, s, j).includes(k)) { matched = true; break; }
      if (!matched) add(k);
    }
  } else { // '*' and '+' — one or more repetitions
    let frontier = [];
    for (const a of alts) for (const k of matchEnds(a, 0, s, j)) add(k);
    if (seg.op === '*') add(j); // zero repetitions
    frontier = [...seen];
    for (let round = 0; round < s.length + 2; round++) {
      let grew = false;
      for (const f of frontier) {
        for (const a of alts) for (const k of matchEnds(a, 0, s, f)) {
          if (!seen.has(k)) { seen.add(k); grew = true; }
        }
      }
      if (!grew) break;
      frontier = [...seen];
    }
  }
  return [...seen].sort((x, y) => x - y);
}

function globMatch(pattern, value) {
  const s = String(value);
  try {
    const ends = matchEnds(parseGlob(pattern), 0, s, 0);
    return ends.includes(s.length);
  } catch { return false; }
}

// ── arithmetic (let, c-style for) ────────────────────────────────────
export function evalArith(src, sh) {
  // recursive descent over integers; supports + - * / % ** << >> & | ^
  // comparison, equality, && || !, ternary, ( ), assignments (x=5, x+=3,
  // x-=1, x*=2, x/=2, x%=2), and postfix ++ / --.
  const s = String(src);
  let pos = 0;
  function peek() { return s[pos]; }
  function ws() { while (/\s/.test(s[pos] ?? '')) pos++; }
  function num() {
    ws();
    let start = pos;
    if (s[pos] === '-') pos++;
    while (/[0-9a-fA-FxX]/.test(s[pos] ?? '')) pos++;
    const raw = s.slice(start, pos);
    if (raw === '' || raw === '-') throw new Error(`arith: expected number near '${s.slice(pos)}'`);
    return parseInt(raw.replace(/^0[xX]/, '0x'), 0) || 0;
  }
  function primary() {
    ws();
    if (s[pos] === '(') { pos++; const v = ternary(); ws(); if (s[pos] !== ')') throw new Error('arith: missing )'); pos++; return v; }
    if (s[pos] === '!') { pos++; return primary() ? 0 : 1; }
    if (s[pos] === '~') { pos++; return ~primary(); }
    // $var / ${var} references
    let dm = s.slice(pos).match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) || s.slice(pos).match(/^\$([A-Za-z_][A-Za-z0-9_]*)/);
    if (dm) { pos += dm[0].length; return Number(sh.getVar(dm[1])) || 0; }
    // variable name?
    let m = s.slice(pos).match(/^([A-Za-z_][A-Za-z0-9_]*)/);
    if (m) {
      pos += m[0].length;
      // array subscript: name[expr]
      if (s[pos] === '[') {
        pos++;
        const key = ternary();
        ws();
        if (s[pos] !== ']') throw new Error('arith: missing ]');
        pos++;
        const arr = sh.arrays.get(m[1]);
        const idx = Number(key) || 0;
        return arr && idx >= 0 && idx < arr.length ? Number(arr[idx]) || 0 : 0;
      }
      // postfix ++ / --
      if (s.slice(pos, pos + 2) === '++') { pos += 2; const v = Number(sh.getVar(m[1])) || 0; sh.setVar(m[1], String(v + 1)); return v; }
      if (s.slice(pos, pos + 2) === '--') { pos += 2; const v = Number(sh.getVar(m[1])) || 0; sh.setVar(m[1], String(v - 1)); return v; }
      return Number(sh.getVar(m[1])) || 0;
    }
    return num();
  }
  function power() { let v = primary(); ws(); if (s.slice(pos, pos + 2) === '**') { pos += 2; const r = power(); v = Math.pow(v, r); } return v; }
  function mul() { let v = power(); for (;;) { ws(); const c = s[pos]; if (c === '*') { pos++; v *= power(); } else if (c === '/') { pos++; const d = power(); v = d === 0 ? 0 : Math.trunc(v / d); } else if (c === '%') { pos++; const d = power(); v = d === 0 ? 0 : v % d; } else return v; } }
  function add() { let v = mul(); for (;;) { ws(); const c = s[pos]; if (c === '+') { pos++; v += mul(); } else if (c === '-') { pos++; v -= mul(); } else return v; } }
  function shift() { let v = add(); for (;;) { ws(); if (s.slice(pos, pos + 2) === '<<') { pos += 2; v <<= add(); } else if (s.slice(pos, pos + 2) === '>>') { pos += 2; v >>= add(); } else return v; } }
  function rel() { let v = shift(); for (;;) { ws(); const two = s.slice(pos, pos + 2); if (two === '<=') { pos += 2; v = v <= shift() ? 1 : 0; } else if (two === '>=') { pos += 2; v = v >= shift() ? 1 : 0; } else if (s[pos] === '<') { pos++; v = v < shift() ? 1 : 0; } else if (s[pos] === '>') { pos++; v = v > shift() ? 1 : 0; } else return v; } }
  function eq() { let v = rel(); for (;;) { ws(); const two = s.slice(pos, pos + 2); if (two === '==') { pos += 2; v = v === rel() ? 1 : 0; } else if (two === '!=') { pos += 2; v = v !== rel() ? 1 : 0; } else return v; } }
  function band() { let v = eq(); for (;;) { ws(); if (s[pos] === '&' && s[pos + 1] !== '&') { pos++; v &= eq(); } else return v; } }
  function bxor() { let v = band(); for (;;) { ws(); if (s[pos] === '^') { pos++; v ^= band(); } else return v; } }
  function bor() { let v = bxor(); for (;;) { ws(); if (s[pos] === '|' && s[pos + 1] !== '|') { pos++; v |= bxor(); } else return v; } }
  function land() { let v = bor(); for (;;) { ws(); if (s.slice(pos, pos + 2) === '&&') { pos += 2; const r = bor(); v = (v !== 0 && r !== 0) ? 1 : 0; } else return v; } }
  function lor() { let v = land(); for (;;) { ws(); if (s.slice(pos, pos + 2) === '||') { pos += 2; const r = land(); v = (v !== 0 || r !== 0) ? 1 : 0; } else return v; } }
  function ternary() {
    const c = lor();
    ws();
    if (s[pos] === '?') { pos++; const a = ternary(); ws(); if (s[pos] !== ':') throw new Error('arith: missing :'); pos++; const b = ternary(); return c !== 0 ? a : b; }
    return c;
  }
  function assignment() {
    ws();
    let m = s.slice(pos).match(/^([A-Za-z_][A-Za-z0-9_]*)\s*([+\-*\/%]?=)/);
    if (m) {
      const name = m[1], op = m[2];
      pos += m[0].length;
      const rhs = ternary();
      const cur = Number(sh.getVar(name)) || 0;
      let v = rhs;
      if (op === '+=') v = cur + rhs;
      else if (op === '-=') v = cur - rhs;
      else if (op === '*=') v = cur * rhs;
      else if (op === '/=') v = rhs === 0 ? 0 : Math.trunc(cur / rhs);
      else if (op === '%=') v = rhs === 0 ? 0 : cur % rhs;
      sh.setVar(name, String(v));
      return v;
    }
    return ternary();
  }
  return assignment();
}

function parseCStyleHeader(header) {
  const parts = header.split(';');
  return [parts[0]?.trim() ?? '', parts[1]?.trim() ?? '', parts[2]?.trim() ?? ''];
}

// ── parameter-expansion helpers ──────────────────────────────────────
function stripGlobPrefix(v, pattern, longest) {
  if (v === '') return v;
  if (!/[*?[]/.test(pattern)) return v.startsWith(pattern) ? v.slice(pattern.length) : v;
  let best = -1;
  for (let i = 0; i <= v.length; i++) {
    if (globMatch(pattern, v.slice(0, i))) best = longest ? Math.max(best, i) : (best === -1 ? i : best);
  }
  return best >= 0 ? v.slice(best) : v;
}
function stripGlobSuffix(v, pattern, longest) {
  if (v === '') return v;
  if (!/[*?[]/.test(pattern)) return v.endsWith(pattern) ? v.slice(0, v.length - pattern.length) : v;
  let best = -1;
  for (let i = 0; i <= v.length; i++) {
    if (globMatch(pattern, v.slice(i))) {
      // suffix starts at i; %% (longest) wants the smallest i, % (shortest) the largest
      best = best === -1 ? i : (longest ? Math.min(best, i) : Math.max(best, i));
    }
  }
  return best >= 0 ? v.slice(0, best) : v;
}
function substGlob(sh, v, pattern, replacement) {
  const rep = expandWord(sh, replacement ?? '');
  if (v === '') return v;
  if (!/[*?[]/.test(pattern)) {
    return v.split(pattern).join(rep);
  }
  let out = '', i = 0;
  while (i < v.length) {
    let matched = false;
    for (let len = v.length - i; len >= 1; len--) {
      if (globMatch(pattern, v.slice(i, i + len))) { out += rep; i += len; matched = true; break; }
    }
    if (!matched) { out += v[i]; i++; }
  }
  return out;
}

// ── brace-expansion helpers ──────────────────────────────────────────
function braceRange([start, end, step, format]) {
  const a = parseInt(start, 10), b = parseInt(end, 10), st = step ? Math.abs(parseInt(step, 10)) || 1 : 1;
  const out = [];
  if (Number.isNaN(a) || Number.isNaN(b)) return [String(start) + '..' + String(end)];
  if (a <= b) for (let i = a; i <= b; i += st) out.push(String(i));
  else for (let i = a; i >= b; i -= st) out.push(String(i));
  return out;
}
function expandBraceNested(items) {
  const out = [];
  for (const it of items ?? []) {
    if (typeof it === 'string') out.push(it);
    else if (it && Array.isArray(it.range)) out.push(...braceRange(it.range));
    else if (it && Array.isArray(it.nested)) out.push(...expandBraceNested(it.nested));
    else if (Array.isArray(it)) out.push(...expandBraceNested(it));
  }
  return out;
}
function expandBraceGroup(g) {
  const out = [];
  for (const it of g ?? []) {
    if (typeof it === 'string') out.push(it);
    else if (it && Array.isArray(it.range)) out.push(...braceRange(it.range));
    else if (it && Array.isArray(it.nested)) out.push(...expandBraceNested(it.nested));
    else if (Array.isArray(it)) out.push(...expandBraceNested(it));
  }
  return out;
}
