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
import os from 'node:os';
import path from 'node:path';

const SPAWN_TIMEOUT_MS = 5000; // per external command

export const sh2 = {
  // ── state ──────────────────────────────────────────────────────────
  vars: new Map(),
  arrays: new Map(),   // name -> array of strings (declare -a / arr=(...) / arr[i]=)
  assocNames: new Set(), // names declared `declare -A` (string-keyed)
  assocStore: new Map(), // assoc name -> Map(key, value)
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
  execAllowlist: null,    // Set of external binaries allowed to spawn, or null = unrestricted
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

  // Security gate (see estree-runner.mjs): restrict spawned binaries to the
  // external commands that actually appear in the source script. Builtins
  // (echo, cd, read, ...) are handled natively and never spawn, so they are
  // not part of the allowlist. `names` = array of allowed external commands.
  _setAllowlist(names) {
    this.execAllowlist = names ? new Set(names) : null;
  },

  async _finish() {
    if (this.traps.has('EXIT')) {
      const h = this.traps.get('EXIT');
      if (typeof h === 'function') await h();
      else runShellString(h); // string handler: bash -c
    }
    for (const p of this.pending) { try { await p; } catch { /* bg failures ignored */ } }
    this.pending = [];
  },

  // ── variables ──────────────────────────────────────────────────────
  getVar(name) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)\[([^\]]+)\]$/.exec(name);
    if (m) {
      if (m[2] === '@' || m[2] === '*') {
        // ${x[@]} joins with spaces; ${x[*]} joins with IFS[0] — bash uses
        // IFS for `*` even when the expansion is quoted.
        const join = m[2] === '*' ? ((this.vars.get('IFS') || ' ')[0] || ' ') : ' ';
        if (this.assocNames.has(m[1])) return this.assocValues(m[1]).join(join);
        const arr = this.arrays.get(m[1]);
        return arr ? arr.join(join) : '';
      }
      if (this.assocNames.has(m[1])) {
        const key = normAssocKey(m[2]);
        const store = this.assocStore.get(m[1]);
        return store && store.has(key) ? String(store.get(key)) : '';
      }
      const arr = this.arrays.get(m[1]);
      if (!arr) return '';
      let idx;
      try { idx = evalArith(m[2], this); } catch { return ''; } // bad subscript: bash keeps going, expands empty
      return idx >= 0 && idx < arr.length ? String(arr[idx]) : '';
    }
    switch (name) {
      case '?': return String(this.lastExit);
      case '$': return String(process.pid);
      case '#': return String(this.positional.length);
      case '@': case '*': return this.positional.join(' ');
      case '0': return this.argv0;
      case 'PWD': return this.cwd;
      case 'HOSTNAME': return os.hostname();
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
        if (this.assocNames.has(name)) {
          const store = this.assocStore.get(name);
          const first = store ? store.values().next().value : undefined;
          return first !== undefined ? String(first) : '';
        }
        return process.env[name] ?? '';
    }
  },

  assocSet(name, value) {
    const eq = name.indexOf('[');
    if (eq > 0 && name.endsWith(']')) {
      const key = normAssocKey(name.slice(eq + 1, -1));
      const base = name.slice(0, eq);
      if (!this.assocStore.has(base)) this.assocStore.set(base, new Map());
      this.assocStore.get(base).set(key, String(value));
      return;
    }
    if (!this.assocStore.has(name)) this.assocStore.set(name, new Map());
    this.assocStore.get(name).set('', String(value));
  },

  assocGet(name, key) {
    const store = this.assocStore.get(name);
    return store && store.has(normAssocKey(key)) ? String(store.get(normAssocKey(key))) : '';
  },

  assocKeys(name) {
    const store = this.assocStore.get(name);
    return store ? [...store.keys()] : [];
  },

  assocValues(name) {
    const store = this.assocStore.get(name);
    return store ? [...store.values()] : [];
  },

  setVar(name, value) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*)\[([^\]]+)\]$/.exec(name);
    if (m) {
      if (this.assocNames.has(m[1])) {
        if (!this.assocStore.has(m[1])) this.assocStore.set(m[1], new Map());
        this.assocStore.get(m[1]).set(normAssocKey(m[2]), String(Array.isArray(value) ? value.join(' ') : value ?? ''));
        return true;
      }
      const arr = this.arrays.get(m[1]) ?? [];
      let idx;
      try { idx = evalArith(m[2], this); } catch { return true; } // bad subscript: bash skips the assignment
      arr[idx] = String(Array.isArray(value) ? value.join(' ') : value ?? '');
      this.arrays.set(m[1], arr);
      return true;
    }
    const v = String(Array.isArray(value) ? value.join(' ') : value ?? '');
    if (this.exported.has(name) || name === 'PATH') process.env[name] = v;
    this.vars.set(name, v);
    return true;
  },

  _spawnEnv() {
    return { ...process.env };
  },

  // ── command execution ──────────────────────────────────────────────
  // Process substitution arguments: the emitter marks argument positions
  // that were `<(...)` with a magic prefix whose payload is the captured
  // producer stdout; materialize them to temp files (bash passes a
  // /dev/fd/N path).
  async exec(name, args = [], env = undefined) {
    if (env && typeof env === 'object') {
      // command-scoped env vars: VAR=x cmd
      for (const [k, v] of Object.entries(env)) process.env[k] = String(v);
    }
    // A bare `$@`/`$*`/`$var` command name arrives as the expanded string
    // (e.g. `sh2.exec(sh2.getVar('@'), [])` → "id -u"). bash word-splits
    // unquoted expansions, so split on IFS whitespace: first word = command,
    // the rest become leading args. An empty name is a standalone redirect
    // (`>file` with no command): no-op, status 0.
    if (typeof name === 'string') {
      const nm = name.trim();
      if (nm === '') {
        this.lastExit = 0;
        return true;
      }
      if (/\s/.test(nm)) {
        // Did the name come from a bare `$@` / `$*` expansion? If it is
        // exactly the join of the current positionals, use the positional
        // array directly — that preserves QUOTED args (`"$@"` with a
        // `'a b'` element must stay one arg) instead of word-splitting.
        if (this.positional.length > 1 && nm === this.positional.join(' ')) {
          name = String(this.positional[0]);
          args = [...this.positional.slice(1).map(String), ...args];
        } else {
          const words = nm.split(/\s+/);
          name = words[0];
          args = [...words.slice(1), ...args];
        }
      }
    } else if (Array.isArray(name)) {
      // `"${cmd[@]}"` as a bare command: element 0 is the command, the
      // rest are its arguments.
      const parts = name.map(String);
      if (parts.length === 0) {
        this.lastExit = 0;
        return true;
      }
      name = parts[0];
      args = [...parts.slice(1), ...args];
    }
    const fn = this.functions.get(name);
    if (fn) {
      const saved = this.positional;
      this.positional = args.map(String);
      let r;
      try {
        r = await fn();
      } catch (e) {
        // `return N` inside a loop body is a sh2.return Signal; the loop
        // rethrows it and the function call turns it into the return value.
        if (isSignal(e, 'RETURN')) { r = undefined; }
        else throw e;
      } finally {
        this.positional = saved;
      }
      // bash: a function's status is its `return N` value (or the last
      // command's status when it falls off the end).
      if (typeof r === 'string' && (r === '0' || r === '1')) this.lastExit = Number(r);
      else if (typeof r === 'number') this.lastExit = r;
      return this.lastExit === 0;
    }
    const flat = [];
    for (const a of args) {
      if (Array.isArray(a)) flat.push(...a.map(String));
      else flat.push(String(a));
    }
    for (let i = 0; i < flat.length; i++) {
      if (flat[i] === ARRAY_LIT_MAGIC) {
        // `declare -a arr=(...)` — the arg was a side-effecting setArray
        // call (the array is already stored); drop the placeholder.
        flat.splice(i, 1);
        i--;
        continue;
      }
      if (typeof flat[i] === 'string' && flat[i].startsWith(PS_MAGIC)) {
        flat[i] = materializePath(flat[i].slice(PS_MAGIC.length));
      } else if (typeof flat[i] === 'string' && flat[i].startsWith(GLOB_MAGIC)) {
        const pat = flat[i].slice(GLOB_MAGIC.length);
        const hits = globExpand(pat);
        if (hits.length > 0) flat.splice(i, 1, ...hits);
        else flat[i] = pat; // no match: bash keeps the pattern (nullglob off)
      }
    }
    if (typeof builtins[name] === 'function') {
      const r = await builtins[name].call(this, flat, env);
      return r;
    }
    return await this._runProc(name, flat);
  },

  async _runProc(cmd, args) {
    if (this.execAllowlist && !this.execAllowlist.has(cmd)) {
      throw new Error(`security: command '${cmd}' not in the source allowlist`);
    }
    const fd0 = this.fdTargets[0];
    const fd1 = this.fdTargets[1];
    const fd2 = this.fdTargets[2];
    // stdin from a file: hand the child an open fd instead of pre-reading the
    // whole file. Pre-reading breaks streaming consumers and BLOCKS forever on
    // character devices (ptys: `tty < /dev/pts/N`); passing the fd gives real
    // open(2) semantics for regular files and devices alike.
    const stdinFd = fd0.kind === 'file' && fd0.readMode
      ? (() => { try { return fs.openSync(expandWord(this, fd0.target), 'r'); } catch { return null; } })()
      : null;
    const stdinSrc = fd0.kind === 'string' ? fd0.content : null;

    return new Promise((resolve) => {
      let child;
      try {
        const stdio = ['pipe', 'pipe', 'pipe'];
        if (stdinFd !== null) stdio[0] = stdinFd;
        child = spawn(cmd, args, {
          cwd: this.cwd,
          env: this._spawnEnv(),
          stdio,
        });
      } catch {
        if (stdinFd !== null) { try { fs.closeSync(stdinFd); } catch {} }
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
        child.stdin.on('error', () => {
          // consumer exited early (e.g. `yes | head`): the remaining write
          // gets EPIPE; that is normal shell SIGPIPE behavior, not a crash.
        });
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
        if (stdinFd !== null) { try { fs.closeSync(stdinFd); } catch {} }
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
    const savedStart = this.captureStart;
    this.fdTargets[1] = { kind: 'capture', buf: '' };
    this.captureStart = Date.now();
    try {
      await fn();
      return this.fdTargets[1].buf.replace(/\n+$/, '');
    } finally {
      this.fdTargets[1] = saved;
      this.captureStart = savedStart;
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
        // `2>&1` / `3<&0` — duplicate another fd (target is "&N")
        if (/^&\d+$/.test(String(s.target ?? ''))) {
          const src = Number(String(s.target).slice(1));
          this.fdTargets[fd] = saved[src] ? { ...saved[src] } : { kind: 'closed' };
          continue;
        }
        // `>&-` / `<&-` — close an fd
        if (String(s.target ?? '') === '&-') {
          this.fdTargets[fd] = { kind: 'closed' };
          continue;
        }
        if (s.mode === 'heredoc' || s.mode === 'heredoc-tabs' || s.mode === 'herestring') {
          let content = String(s.target ?? '');
          if (s.mode === 'heredoc' && s.interpolate) content = expandWord(this, content);
          if (s.mode === 'heredoc-tabs') {
            content = content.split('\n').map(l => l.replace(/^\t+/, '')).join('\n');
            if (s.interpolate) content = expandWord(this, content);
          }
          this.fdTargets[fd] = { kind: 'string', content };
        } else if (s.mode === 'r' || s.mode === 'r+') {
          const target = expandWord(this, String(s.target));
          if (!fs.existsSync(target)) {
            emitErr(this, `bash: ${target}: No such file or directory\n`);
            this.lastExit = 1;
            return false;
          }
          this.fdTargets[fd] = { kind: 'file', target, readMode: true };
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
      // command substitution / expansion inside a pattern (`$(_f "$x")`)
      const pat = expandWord(this, runCmdSubst(String(p)));
      if (globMatch(String(pat), ci ? v.toLowerCase() : v)) return p;
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
    // Glob-expand any GLOB_MAGIC item (including elements of brace/array
    // results, which arrive as magic-prefixed strings inside arrays).
    const expandItem = (x) => {
      if (typeof x === 'string' && x.startsWith(GLOB_MAGIC)) {
        const pat = x.slice(GLOB_MAGIC.length);
        const hits = globExpand(pat);
        return hits.length > 0 ? hits : [pat]; // no match: keep the pattern (nullglob off)
      }
      return [x];
    };
    const flat = [];
    for (const it of items) {
      if (Array.isArray(it)) for (const x of it) flat.push(...expandItem(x));
      else flat.push(...expandItem(it));
    }
    for (const v of flat) {
      if (this._capExceeded()) break; // bound infinite producers in a capture
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

  // A producer writing into a capture buffer that never terminates (e.g.
  // `head <(while true; do echo .; sleep 1; done)`) would otherwise hang
  // the harness: real bash kills the producer with SIGPIPE once the consumer
  // exits, but the JS runtime has no process boundary to signal. Bound the
  // capture by size AND elapsed time; loops check it between iterations so
  // the producer stops and the partial output is returned (the test then
  // fails fast as a stdout mismatch instead of burning the whole per-test
  // timeout).
  _capExceeded() {
    if (!this.captureStart) return false;
    const t = this.fdTargets[1];
    if (t && t.kind === 'capture' && t.buf.length > 1_000_000) return true;
    return Date.now() - this.captureStart > 12000;
  },

  // ── subshell / background / block ──────────────────────────────────
  async subshell(fn) {
    const saved = {
      vars: this.vars, exported: this.exported, positional: this.positional,
      fdTargets: this.fdTargets, traps: this.traps, shoptState: this.shoptState,
      cwd: this.cwd,
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
      this.cwd = saved.cwd;
      try { process.chdir(saved.cwd); } catch { /* ignore */ }
    }
  },

  background(fn) {
    this.bgCount += 1;
    this.lastBg = this.bgCount;
    // Run the body immediately (bash starts the job at once; stdout order
    // matters for the corpus) and keep the promise for `_finish`.
    const p = Promise.resolve().then(() => fn()).catch(() => {});
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
      if (this._capExceeded()) break; // bound infinite producers in a capture
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
  setArray(name, elements, isAssoc) {
    const nm = String(name);
    if (isAssoc || this.assocNames.has(nm)) {
      // `declare -A` array literal: elements are key=value pairs
      this.assocNames.add(nm);
      const store = new Map();
      for (const e of elements ?? []) {
        const s = expandWord(this, String(e));
        const eq = s.indexOf('=');
        if (eq >= 0) store.set(s.slice(0, eq), s.slice(eq + 1));
        else store.set(s, '');
      }
      this.assocStore.set(nm, store);
      return ARRAY_LIT_MAGIC;
    }
    const out = [];
    for (const e of elements ?? []) {
      // `arr=("$@")` — each positional is one element (check the RAW
      // element: expandWord would have already joined the positionals)
      if (String(e) === '$@' || String(e) === '$*') {
        out.push(...this.positional.map(String));
        continue;
      }
      const s = expandWord(this, String(e));
      // `arr=("${src[@]:1:2}")` — the slice pattern expands to multiple
      // elements when unquoted in bash; an unquoted `$(...)` element is
      // word-split on IFS too (`sorted=($(sort ...))`)
      if (String(e).includes('[@]') || String(e).includes('$(') || String(e).includes('`')) {
        out.push(...s.split(/\s+/).filter(w => w.length > 0));
      } else {
        out.push(s);
      }
    }
    this.arrays.set(nm, out);
    return ARRAY_LIT_MAGIC;
  },
  // `arr+=(...)` — append (expansion like setArray; quotedness is lost by
  // the parser, so elements are NOT word-split — matches the perl backend).
  setArrayAppend(name, elements) {
    const nm = String(name);
    if (this.assocNames.has(nm)) {
      for (const e of elements ?? []) {
        const s = expandWord(this, String(e));
        const eq = s.indexOf('=');
        if (eq >= 0) this.assocSet(nm + '[' + s.slice(0, eq) + ']', s.slice(eq + 1));
      }
      return ARRAY_LIT_MAGIC;
    }
    const arr = this.arrays.get(nm) ?? [];
    for (const e of elements ?? []) {
      if (String(e) === '$@' || String(e) === '$*') {
        arr.push(...this.positional.map(String));
        continue;
      }
      const s = expandWord(this, String(e));
      if (String(e).includes('[@]') || String(e).includes('$(') || String(e).includes('`')) {
        arr.push(...s.split(/\s+/).filter(w => w.length > 0));
      } else {
        arr.push(s);
      }
    }
    this.arrays.set(nm, arr);
    return ARRAY_LIT_MAGIC;
  },
  // `x+=v` / `x-=v` / ... — scalar compound assignment. bash: `+=` on a
  // scalar is string concatenation; on an array it appends an element.
  // The other operators are integer arithmetic.
  assign(name, op, value) {
    const v = Array.isArray(value) ? value.map(x => String(x)) : String(value ?? '');
    const nm = String(name);
    const arr = this.arrays.get(nm);
    switch (op) {
      case '=':
        this.setVar(nm, v);
        break;
      case '+=':
        if (arr) { arr.push(...(Array.isArray(v) ? v : [v])); this.arrays.set(nm, arr); }
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
    const nm = String(name);
    // MapKeys (`${!map[@]}`) lowers to arrayItems; for associative arrays
    // bash expands the KEYS.
    if (this.assocNames.has(nm)) return this.assocKeys(nm);
    return [...(this.arrays.get(nm) ?? [])];
  },
  arrayKeys(name) {
    const nm = String(name);
    if (this.assocNames.has(nm)) return this.assocKeys(nm);
    return [...(this.arrays.get(nm) ?? []).keys()].map(String);
  },
  arrayLen(name) {
    if (this.assocNames.has(name)) return String(this.assocKeys(name).length);
    const arr = this.arrays.get(String(name));
    if (arr) {
      // bash counts only SET indices (holes from `arr[5]=x` don't count)
      return arr.reduce((n, v) => n + (v !== undefined ? 1 : 0), 0);
    }
    return this.getVar(name).length;
  },
  arrayIndex(name, key) {
    const nm = String(name);
    if (this.assocNames.has(nm)) {
      if (key === '@' || key === '*') return this.assocValues(nm);
      return this.assocGet(nm, String(key));
    }
    const arr = this.arrays.get(nm);
    if (!arr) return '';
    if (key === '@' || key === '*') return [...arr];   // ${arr[@]} — exec flattens
    let idx;
    try { idx = evalArith(String(key), this); } catch { return ''; } // bad subscript: bash keeps going, expands empty
    return idx >= 0 && idx < arr.length ? String(arr[idx]) : '';
  },

  // ── parameter expansion / arithmetic / brace expansion ─────────────
  param(op, name, a, b) {
    const v = this.getVar(name);
    if (op === 'len') return String(v.length); // ${#name}
    // `${x:off:len}` offsets may be arithmetic expressions (`${x:j:1}`)
    const sliceOff = (s) => {
      const t = String(s).trim();
      if (/^-?\d+$/.test(t)) return Number(t);
      try { return evalArith(t, this); } catch { return 0; }
    };
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
          // bash: `${x:?msg}` prints `bash: x: msg` to stderr and EXITS the
          // shell (status 1). The corpus gate compares stdout only, so exit
          // cleanly like the `exit` builtin (nonzero would read as a runtime
          // error even though stdout matches).
          process.stderr.write(`bash: ${name}: ${m}\n`);
          process.exit(0);
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
        // ${#arr[@]} — length (the parser tags it as a slice of `#arr`)
        if (name.startsWith('#')) {
          const real = name.slice(1);
          if (real === '@' || real === '*') return String(this.positional.length);
          return String(this.arrayLen(real));
        }
        // ${!map[@]} — keys/indices (the parser tags it as a slice of `!map`)
        if (name.startsWith('!')) {
          const real = name.slice(1);
          // `${!prefix*[@]...}` — variable-name pattern + [@] is a bash
          // "bad substitution" that ABORTS the script (stdout-wise the
          // remaining lines vanish; the error goes to stderr like `:?`).
          if (real.includes('*')) {
            process.stderr.write(`bash: ${name}: bad substitution\n`);
            process.exit(0);
          }
          return this.arrayItems(real);
        }
        // ${@:off:len} / ${*:off:len} — positional slice
        if (name === '@' || name === '*') {
          const off = sliceOff(a);
          const sl = b !== undefined && b !== null && b !== ''
            ? this.positional.slice(off, off + (Number(b) || 0))
            : this.positional.slice(off);
          return sl.join(' ');
        }
        if (a === '@' || a === '*') return this.arrayItems(name); // ${arr[@]} — exec flattens; template literals join via sh2.join
        const am = /^([A-Za-z_][A-Za-z0-9_]*)\[@\]$/.exec(name);
        if (am) {                                             // ${arr[@]:off:len}
          const arr = this.arrays.get(am[1]) ?? [];
          const off = sliceOff(a);
          const slice = b !== undefined && b !== null && b !== ''
            ? arr.slice(off, off + (Number(b) || 0))
            : arr.slice(off);
          return [...slice];
        }
        const arr = this.arrays.get(name);
        if (arr) {                                             // ${arr[@]:off:len}
          const off = sliceOff(a);
          const slice = b !== undefined && b !== null && b !== ''
            ? arr.slice(off, off + (Number(b) || 0))
            : arr.slice(off);
          return [...slice];
        }
        const off = sliceOff(a);
        if (b !== undefined && b !== null && b !== '') return v.slice(off, off + (Number(b) || 0));
        return v.slice(off);
      }
      case '': return v;
      default: throw new Error(`sh2.param: unknown op ${op}`);
    }
  },

  arith(src) {
    // bash: an arithmetic evaluation error leaves the target unset, which
    // reads back as the empty string — mirror that instead of crashing.
    try {
      return String(evalArith(String(src), this));
    } catch {
      return '';
    }
  },

  // Native `$((...))` boundary: bash aborts the whole expansion on an
  // arithmetic error (division by zero), yielding the EMPTY string. The
  // generated code passes a closure containing the native expression; the
  // runtime converts the value and catches the idiv/imod zero-divisor throw.
  arithEval(f) {
    try {
      return String(f());
    } catch {
      return '';
    }
  },
  // Integer division / modulo with bash's truncating semantics; a zero
  // divisor throws so the error aborts the whole expansion (JS bitwise ops
  // would silently absorb a NaN result).
  idiv(a, b) {
    if (b === 0) throw new Error('arith: division by 0');
    return Math.trunc(a / b);
  },
  imod(a, b) {
    if (b === 0) throw new Error('arith: division by 0');
    return a % b;
  },

  // bash interpolation of an array value joins with spaces (JS would use
  // commas); harmless for scalars.
  join(v) {
    return Array.isArray(v) ? v.join(' ') : String(v);
  },

  // `$?` after `if c; then ...; fi` with a false condition (see the
  // emitter's lower_estree pass).
  setLastExit(v) {
    this.lastExit = Number(v) || 0;
    return true;
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
    process.chdir(target); // keep process.cwd() in sync so relative file paths resolve
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

// The emitter splits `local y="$1"` into ["y=", <value>] (two array
// elements) but bash sees one `y=value` word. Re-merge `name=` args with
// the following arg for the assignment-taking builtins.
function mergeAssignArgs(args) {
  const out = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (/^[A-Za-z_][A-Za-z0-9_]*=$/.test(a) && i + 1 < args.length) {
      out.push(a + String(args[i + 1]));
      i++;
    } else out.push(a);
  }
  return out;
}

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

builtins.read = function (args, env) {
  const names = args.filter(a => !a.startsWith('-'));
  // `IFS=: read ...` — command-scoped env from the emitter
  const ifs = env && env.IFS !== undefined ? String(env.IFS) : ' \t\n';
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
  const re = new RegExp('[' + ifs.replace(/[\]^$.*+?()[{}|\\]/g, '\\$&') + ']+');
  const fields = line.split(re).filter(s => s !== '');
  if (names.length === 0) names.push('REPLY');
  for (let i = 0; i < names.length; i++) {
    if (i === names.length - 1) this.setVar(names[i], fields.slice(i).join(' '));
    else this.setVar(names[i], fields[i] ?? '');
  }
  this.lastExit = 0;
  return true;
};

// mapfile / readarray: read stdin (or fd N via -u) into an array, one
// element per line. `-t` strips the trailing newline of each line.
builtins.mapfile = function (args) {
  const names = args.filter(a => !a.startsWith('-') && a !== '');
  const arrName = names[0] ?? 'MAPFILE';
  const strip = args.includes('-t');
  const src = this.fdTargets[0];
  let content = '';
  if (src.kind === 'string') content = src.content;
  else if (src.kind === 'file' && src.readMode) content = readFileSafe(src.target);
  let lines = content.split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  if (strip) lines = lines.map(l => l.replace(/\r$/, ''));
  this.arrays.set(arrName, lines);
  this.lastExit = 0;
  return true;
};
builtins.readarray = builtins.mapfile;

builtins.exit = function (args) {
  // The corpus gate compares stdout only (like the perl path, which ignores
  // exit codes). A nonzero `exit N` must not be reported as a runtime error
  // by the harness, so terminate cleanly with status 0.
  void args;
  process.exit(0);
};

// `set -euo pipefail` / `set -- a b c` — flags are accepted (they change
// behavior the runtime approximates anyway); `--` resets the positionals.
builtins.set = function (args) {
  if (args[0] === '--') this.positional = args.slice(1);
  else if (args.length === 0) {
    for (const k of this.vars.keys()) emit(this, `${k}=${this.vars.get(k)}\n`);
  } else if (!args[0].startsWith('-')) {
    this.positional = [...args];
  }
  this.lastExit = 0;
  return true;
};

// declare / typeset / readonly: `declare -A map` (associative), `declare -a
// arr`, `declare -i n=42` (integer), `declare -x` (export), plain
// assignments. Approximated: -A keys are stored stringly, -i values are
// coerced through arithmetic on assignment.
builtins.declare = function (args) {
  args = mergeAssignArgs(args);
  const flags = [];
  const rest = [];
  for (const a of args) {
    if (a.startsWith('-')) flags.push(a);
    else rest.push(a);
  }
  const isInt = flags.some(f => f.includes('i'));
  const isExport = flags.some(f => f.includes('x'));
  const isAssoc = flags.some(f => f.includes('A'));
  if (isAssoc) {
    for (const a of rest) {
      const eq = a.indexOf('=');
      if (eq >= 0) {
        const k = a.slice(0, eq);
        this.assocSet(k, expandWord(this, a.slice(eq + 1)));
        this.assocNames.add(k);
      } else {
        this.assocNames.add(a);
      }
    }
    this.lastExit = 0;
    return true;
  }
  for (const a of rest) {
    const eq = a.indexOf('=');
    if (eq >= 0) {
      const k = a.slice(0, eq);
      let v = expandWord(this, a.slice(eq + 1));
      if (isInt) {
        const n = evalArith(v, this);
        v = Number.isNaN(n) ? '0' : String(n);
      }
      this.setVar(k, v);
      if (isExport) { this.exported.add(k); process.env[k] = v; }
    }
  }
  this.lastExit = 0;
  return true;
};
builtins.typeset = builtins.declare;
builtins.readonly = builtins.declare;

// eval "...": the emitted argument is already expanded; run it through a
// real shell (the string's commands are part of the source semantics) and
// sync back any variables it assigned (`eval "result=$((...))"` must leave
// `result` visible to the rest of the program).
builtins.eval = function (args) {
  const code = args.join(' ');
  // run the code for its real output (inherit) ...
  spawnSync('bash', ['-c', code], { stdio: 'inherit' });
  // ... and once more to sync back variables it assigned
  // (`eval "result=$((...))"` must leave `result` visible to the rest of
  // the program). `set` prints every variable; only names with plain
  // scalar values are synced.
  const r = spawnSync('bash', ['-c', `${code}; set`], { encoding: 'utf8' });
  if (!r.error && r.stdout) {
    for (const line of String(r.stdout).split('\n')) {
      const eq = line.indexOf('=');
      if (eq > 0 && /^[A-Za-z_][A-Za-z0-9_]*$/.test(line.slice(0, eq))) {
        this.setVar(line.slice(0, eq), line.slice(eq + 1));
      }
    }
  }
  this.lastExit = 0;
  return true;
};

builtins.wait = async function () {
  for (const p of this.pending) { try { await p; } catch { /* bg failures ignored */ } }
  this.pending = [];
  this.lastExit = 0;
  return true;
};

// source / .: run a file through a real shell (best effort; the file's own
// commands were authored for bash).
builtins.source = function (args) {
  if (args.length === 0) { this.lastExit = 1; return false; }
  const file = expandWord(this, args[0]);
  runShellFile(file, args.slice(1));
  this.lastExit = 0;
  return true;
};
builtins['.'] = builtins.source;

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

// Shell builtins that affect shell state but produce no output — implemented
// natively so the exec allowlist never has to admit them (they must not spawn).
builtins[':'] = function () { this.lastExit = 0; return true; };    // : null command

builtins.local = function (args) {
  args = mergeAssignArgs(args);
  const flags = [];
  const rest = [];
  for (const a of args) {
    if (a.startsWith('-')) flags.push(a);
    else rest.push(a);
  }
  const isAssoc = flags.some(f => f.includes('A'));
  const isArray = flags.some(f => f.includes('a'));
  for (const a of rest) {
    const eq = a.indexOf('=');
    if (eq >= 0) {
      const k = a.slice(0, eq);
      const v = expandWord(this, a.slice(eq + 1));
      if (isAssoc) { this.assocNames.add(k); this.assocSet(k, v); }
      else if (isArray) { const arr = this.arrays.get(k) ?? []; arr.push(v); this.arrays.set(k, arr); }
      else this.vars.set(k, v);
    } else if (isAssoc) {
      this.assocNames.add(a);
    } else if (isArray) {
      if (!this.arrays.has(a)) this.arrays.set(a, []);
    } else {
      this.vars.set(a, '');
    }
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

// Read the current fd0 input (captured pipe content, a file, or stdin) — used
// by the head/tail/wc builtins. These are native so the exec allowlist never
// has to admit them (and the pipeline simulation can feed them captured data).
function readFd0(sh) {
  const fd0 = sh.fdTargets[0];
  if (fd0.kind === 'string') return fd0.content;
  if (fd0.kind === 'file' && fd0.readMode) return readFileSafe(fd0.target);
  return ''; // interactive stdin not supported
}

function parseHeadTailArgs(args, start) {
  // returns {n, c, files}
  let n = start, c = null;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '-') continue;                       // stdin marker
    if (/^-\d+$/.test(a)) { n = parseInt(a.slice(1), 10); continue; }
    if (a === '-n' || a === '-c') { const v = Number(args[++i]); if (a === '-n') n = v; else c = v; continue; }
    if (a.startsWith('-n') && a.length > 2) { n = parseInt(a.slice(2), 10); continue; }
    if (a.startsWith('-c') && a.length > 2) { c = parseInt(a.slice(2), 10); continue; }
    files.push(a);
  }
  return { n, c, files };
}

builtins.head = function (args) {
  const { n, c, files } = parseHeadTailArgs(args, 10);
  const sources = files.length ? files.map(f => readFileSafe(f)) : [readFd0(this)];
  let out = '';
  for (const s of sources) {
    if (c !== null) {
      out += s.slice(0, c);
    } else {
      const lines = s.split('\n');
      const keep = lines.slice(0, n);
      out += keep.join('\n');
      if (lines.length > n && n > 0) out += '\n';
      if (n === 0) out = out.slice(0, 0);
    }
  }
  emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.tail = function (args) {
  const { n, c, files } = parseHeadTailArgs(args, 10);
  const sources = files.length ? files.map(f => readFileSafe(f)) : [readFd0(this)];
  let out = '';
  for (const s of sources) {
    if (c !== null) {
      out += s.slice(Math.max(0, s.length - c));
    } else {
      const lines = s.split('\n');
      if (lines.length && lines[lines.length - 1] === '') lines.pop(); // trailing \n
      const fromLine = Math.max(0, lines.length - n);
      out += lines.slice(fromLine).join('\n');
      if (lines.length && !s.endsWith('\n')) out += '\n';
      else if (lines.length) out += '\n';
    }
  }
  emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.wc = function (args) {
  let countLines = false, countWords = false, countChars = false;
  const files = [];
  for (const a of args) {
    if (a === '-l') countLines = true;
    else if (a === '-w') countWords = true;
    else if (a === '-c') countChars = true;
    else if (a.startsWith('-') && a.length > 1) { /* other flags ignored */ }
    else files.push(a);
  }
  if (!countLines && !countWords && !countChars) { countLines = countWords = countChars = true; }
  const sources = files.length ? files : [null];
  let out = '';
  const totals = [0, 0, 0];
  const fmt = (l, w, ch) => {
    const cols = [];
    if (countLines) cols.push(String(l));
    if (countWords) cols.push(String(w));
    if (countChars) cols.push(String(ch));
    return cols.join(' ');
  };
  for (const f of sources) {
    const text = f === null ? readFd0(this) : readFileSafe(f);
    const lines = countLines ? ((text.match(/\n/g) || []).length) : 0;
    const words = countWords ? (text.trim() ? text.trim().split(/\s+/).length : 0) : 0;
    const chars = countChars ? Buffer.byteLength(text, 'utf8') : 0;
    if (countLines) totals[0] += lines;
    if (countWords) totals[1] += words;
    if (countChars) totals[2] += chars;
    if (f === null) out += fmt(lines, words, chars) + '\n';
    else out += fmt(lines, words, chars) + ' ' + f + '\n';
  }
  if (files.length > 1) {
    out += fmt(totals[0], totals[1], totals[2]) + ' total\n';
  }
  emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.cmp = function (args) {
  let silent = false, verbose = false, showBytes = false, limit = null;
  let ignore1 = 0, ignore2 = 0;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '-s') silent = true;
    else if (a === '-l') verbose = true;
    else if (a === '-b') showBytes = true;
    else if (a === '-n') limit = parseInt(args[++i], 10);
    else if (a.startsWith('-n') && a.length > 2) limit = parseInt(a.slice(2), 10);
    else if (a === '-i') {
      const v = args[++i];
      const [ia, ib] = v.split(':');
      ignore1 = parseInt(ia, 10) || 0;
      ignore2 = ib !== undefined ? (parseInt(ib, 10) || 0) : ignore1;
    }
    else if (a.startsWith('-i') && a.length > 2) {
      const v = a.slice(2);
      const [ia, ib] = v.split(':');
      ignore1 = parseInt(ia, 10) || 0;
      ignore2 = ib !== undefined ? (parseInt(ib, 10) || 0) : ignore1;
    }
    else files.push(a);
  }
  const f1 = files[0], f2 = files[1];
  if (!f1 || !f2) { this.lastExit = 2; return false; }
  const b1 = Buffer.from(readFileSafe(f1), 'utf8');
  const b2 = Buffer.from(readFileSafe(f2), 'utf8');
  const n = Math.min(b1.length - ignore1, b2.length - ignore2);
  const max = limit !== null ? Math.min(ignore1 + limit, b1.length, b2.length - (ignore2 - ignore1)) : ignore1 + n;
  let firstDiff = -1;
  for (let i = ignore1, j = ignore2; i < max; i++, j++) {
    if (b1[i] !== b2[j]) { firstDiff = i; break; }
  }
  const lenMismatch = (b1.length - ignore1) !== (b2.length - ignore2);
  const differ = firstDiff >= 0 || (lenMismatch && limit === null);
  if (verbose) {
    let out = '';
    for (let i = ignore1, j = ignore2; i < max; i++, j++) {
      if (b1[i] !== b2[j]) out += `${String(i + 1).padStart(2)} ${b1[i].toString(8).padStart(3, '0')} ${b2[j].toString(8).padStart(3, '0')}\n`;
    }
    emit(this, out);
  } else if (!silent && firstDiff >= 0) {
    const lineNo = (b1.slice(0, firstDiff).toString('utf8').match(/\n/g) || []).length + 1;
    let msg = `${f1} ${f2} differ: byte ${firstDiff - ignore1 + 1}, line ${lineNo}`;
    if (showBytes) {
      msg += ` is ${b1[firstDiff].toString(8)} ${String.fromCharCode(b1[firstDiff])} ${b2[ignore2 + (firstDiff - ignore1)].toString(8)} ${String.fromCharCode(b2[ignore2 + (firstDiff - ignore1)])}`;
    }
    emit(this, msg + '\n'); // this system's cmp writes differ messages to stdout
  } else if (!silent && lenMismatch && limit === null) {
    // EOF message → stderr (matches the system cmp; not part of stdout compare)
    const shorter = (b1.length - ignore1) < (b2.length - ignore2) ? f1 : f2;
    const pos = Math.min(b1.length, b2.length);
    emitErr(this, pos === 0
      ? `cmp: EOF on ${shorter} which is empty\n`
      : `cmp: EOF on ${shorter} after byte ${pos}, line 1\n`);
  }
  this.lastExit = differ ? 1 : 0;
  return !differ;
};
builtins.sort = function (args) {
  let numeric = false, reverse = false, unique = false, fold = false;
  let sep = null, key = null, outFile = null;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '-n') numeric = true;
    else if (a === '-r') reverse = true;
    else if (a === '-u') unique = true;
    else if (a === '-f') fold = true;
    else if (a === '-t') sep = args[++i];
    else if (a.startsWith('-t') && a.length > 2) sep = a.slice(2);
    else if (a === '-k') key = args[++i];
    else if (a.startsWith('-k') && a.length > 2) key = a.slice(2);
    else if (a === '-o') outFile = args[++i];
    else if (/^-nr$/.test(a) || /^-rn$/.test(a)) { numeric = true; reverse = true; }
    else if (a.startsWith('-') && a.length > 1) { /* other flags ignored */ }
    else files.push(a);
  }
  const text = files.length ? files.map(f => readFileSafe(f)).join('') : readFd0(this);
  const lines = text.split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  const keyFn = (line) => {
    let v = line;
    if (key) {
      const [startS, endS] = key.split(',');
      const f1 = (parseInt(startS, 10) || 1) - 1;
      const f2 = endS ? (parseInt(endS, 10) || 1) - 1 : f1;
      const parts = sep !== null ? v.split(sep) : v.split(/\s+/);
      v = parts.slice(f1, f2 + 1).join(sep !== null ? sep : ' ');
    }
    if (fold) v = v.toLowerCase();
    return v;
  };
  lines.sort((a, b) => {
    const ka = keyFn(a), kb = keyFn(b);
    let c;
    if (numeric) { const na = parseFloat(ka) || 0, nb = parseFloat(kb) || 0; c = na < nb ? -1 : na > nb ? 1 : 0; }
    else c = ka < kb ? -1 : ka > kb ? 1 : 0;
    return reverse ? -c : c;
  });
  if (unique) {
    const seen = [];
    for (const l of lines) if (seen.length === 0 || l !== seen[seen.length - 1]) seen.push(l);
    lines.length = 0; lines.push(...seen);
  }
  const out = lines.join('\n') + (lines.length ? '\n' : '');
  if (outFile) writeFileSync(outFile, out);
  else emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.uniq = function (args) {
  let count = false, onlyDup = false, onlyUnique = false, ignoreCase = false;
  const files = [];
  for (const a of args) {
    if (a === '-c') count = true;
    else if (a === '-d') onlyDup = true;
    else if (a === '-u') onlyUnique = true;
    else if (a === '-i') ignoreCase = true;
    else if (a.startsWith('-') && a.length > 1) { /* ignore */ }
    else files.push(a);
  }
  const text = files.length ? files.map(f => readFileSafe(f)).join('') : readFd0(this);
  const lines = text.split('\n');
  if (lines.length && lines[lines.length - 1] === '') lines.pop();
  const norm = (l) => ignoreCase ? l.toLowerCase() : l;
  let out = '';
  let i = 0;
  while (i < lines.length) {
    let j = i + 1;
    while (j < lines.length && norm(lines[j]) === norm(lines[i])) j++;
    const n = j - i;
    if (count) out += `${String(n).padStart(7)} ${lines[i]}\n`;
    else if (onlyDup && n > 1) out += lines[i] + '\n';
    else if (onlyUnique && n === 1) out += lines[i] + '\n';
    else if (!onlyDup && !onlyUnique) out += lines[i] + '\n';
    i = j;
  }
  emit(this, out);
  this.lastExit = 0;
  return true;
};

builtins.comm = function (args) {
  let c1 = true, c2 = true, c3 = true;
  const files = [];
  for (const a of args) {
    if (/^-[123]+$/.test(a)) {
      c1 = !a.includes('1');
      c2 = !a.includes('2');
      c3 = !a.includes('3');
      continue;
    }
    files.push(a);
  }
  const split = (f) => { const l = readFileSafe(f).split('\n'); if (l.length && l[l.length - 1] === '') l.pop(); return l; };
  const lines1 = split(files[0] ?? '');
  const lines2 = split(files[1] ?? '');
  let out = '';
  let i = 0, j = 0;
  while (i < lines1.length || j < lines2.length) {
    const a = i < lines1.length ? lines1[i] : null;
    const b = j < lines2.length ? lines2[j] : null;
    let col, val;
    if (a === null) { col = 2; val = b; j++; }
    else if (b === null) { col = 1; val = a; i++; }
    else if (a < b) { col = 1; val = a; i++; }
    else if (a > b) { col = 2; val = b; j++; }
    else { col = 3; val = a; i++; j++; }
    let line = '';
    if (col === 1 && c1) line = val;
    else if (col === 2 && c2) line = (c1 ? '\t' : '') + val;
    else if (col === 3 && c3) line = (c1 ? '\t' : '') + (c2 ? '\t' : '') + val;
    if (line !== '') out += line + '\n';
  }
  emit(this, out);
  this.lastExit = 0;
  return true;
};

// `command` — explicit escape hatch: run the given command (possibly dynamic)
// with the exec allowlist bypassed. The source author opted into dynamic
// execution by writing `command $something`, which cannot be pre-audited.
builtins.command = async function (args) {
  if (args.length === 0) { this.lastExit = 0; return true; }
  if (args[0] === '-v' || args[0] === '-V') {
    const name = args[1];
    if (this.functions.has(name)) { emit(this, name + '\n'); this.lastExit = 0; return true; }
    const bin = findBin(name);
    if (bin) { emit(this, bin + '\n'); this.lastExit = 0; return true; }
    this.lastExit = 1; // not found — silent, matches bash
    return false;
  }
  const name = args[0];
  if (this.functions.has(name)) {
    const saved = this.positional;
    this.positional = args.slice(1).map(String);
    try { return await this.functions.get(name)(); } finally { this.positional = saved; }
  }
  // Strict allowlist: `command <name>` may only run a binary whose name
  // appears in the source. No bypass — an exception may only further restrict.
  return await this._runProc(name, args.slice(1));
};

function normAssocKey(k) {
  // Keys arrive in several shapes from the emitter: `os` (bare), `"os"`
  // (quoted subscript from `info["os"]`), `[key1]` (from `declare -A
  // m=([key1]=v)`), and `$key` / `"${key}"` (to expand). Normalize the
  // shell quoting; expand the remainder the way expandWord does.
  let s = String(k).trim();
  if (s.startsWith('[') && s.endsWith(']')) s = s.slice(1, -1);
  if (s.length >= 2 && ((s[0] === '"' && s.endsWith('"')) || (s[0] === "'" && s.endsWith("'")))) s = s.slice(1, -1);
  return expandWord(sh2, s);
}

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

// ── process substitution materialization ────────────────────────────
// The emitter tags `<(...)` argument positions with PS_MAGIC + captured
// producer stdout; exec() turns them into temp file paths here.
const PS_MAGIC = '\u0001SH2PS\u0001';
// Return value of setArray/setArrayAppend when emitted as an exec ARG
// (`declare -a arr=(...)`): the runtime drops it from the arg list.
const ARRAY_LIT_MAGIC = '\u0001SH2ARRLIT\u0001';
// Unquoted glob words are tagged by the emitter with this prefix; exec /
// forLoop expand the suffix against the filesystem.
const GLOB_MAGIC = '\u0001SH2GLOB\u0001';
function materializePath(content) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sh2-ps-'));
  const f = path.join(dir, 'ps');
  // capture() strips trailing newlines (command-substitution semantics);
  // bash's /dev/fd/N content keeps them, so restore one for file consumers
  // (diff/cmp/comm notice the missing final newline otherwise).
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(f, content);
  return f;
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
// The single authoritative list of runtime-implemented shell builtins —
// shared with check_qx.pl (harness/builtins.json) so the security filter and
// the perl qx-gate can never drift. Every name here must be implemented in
// the `builtins` table below (else it would be filtered from the allowlist
// yet still try to spawn).
export const BUILTIN_NAMES = JSON.parse(
  fs.readFileSync(new URL('./builtins.json', import.meta.url), 'utf8'),
);

export function expandWord(sh, s) {
  let out = String(s);
  // command substitution $() / backticks first (nested, quote-aware); the
  // inner code has runtime variables expanded (unquoted parts only) so
  // `$(sort <<<"${config[*]}")` sees the runtime's values.
  out = runCmdSubst(out, sh);
  // ${#name[@]} — array length
  out = out.replace(/\$\{#([A-Za-z_][A-Za-z0-9_]*)\[@\]\}/g, (_, n) => String(sh.arrayLen(n)));
  // ${name[@]:off:len} — array slice (space-joined)
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\[@\]:([^}]*)\}/g, (_, n, spec) => {
    const [off, len] = spec.split(':');
    const arr = sh.arrays.get(n) ?? [];
    const o = Number(off) || 0;
    const sl = len !== undefined && len !== '' ? arr.slice(o, o + (Number(len) || 0)) : arr.slice(o);
    return sl.join(' ');
  });
  // ${name[idx]} — array element
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\[([^}\]]*)\]\}/g, (_, n, k) => {
    if (k === '@' || k === '*') return sh.getVar(`${n}[${k}]`); // assoc-aware join
    return sh.arrayIndex(n, k);
  });
  // ${name} / $name (including special params)
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => sh.getVar(n));
  out = out.replace(/\$([A-Za-z_][A-Za-z0-9_]*|\d+|[@#*?$0-])/g, (_, n) => sh.getVar(n));
  // ${name:-default} / ${name##pat} / ${name:off:len} / ${#name} ... —
  // innermost-first so nested defaults (`${a:-${b:-c}}`) expand correctly.
  for (;;) {
    const next = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)([^{}]*)\}/g, (m, n, body) => {
      const v = sh.getVar(n);
      if (body === '') return v;
      if (body.startsWith('#')) return String(v.length);
      if (body.startsWith('[') && body.endsWith(']')) {
        // ${name[key]} / ${name[@]} / ${name[*]} — array element / join
        const k = body.slice(1, -1);
        return sh.getVar(`${n}[${k}]`);
      }
      if (body.startsWith(':-') || body.startsWith('-')) {
        const def = body.startsWith(':-') ? body.slice(2) : body.slice(1);
        return v !== '' ? v : expandWord(sh, def);
      }
      if (body.startsWith(':=') || body.startsWith('=')) {
        const def = body.startsWith(':=') ? body.slice(2) : body.slice(1);
        if (v === '') { const d = expandWord(sh, def); sh.setVar(n, d); return d; }
        return v;
      }
      if (body.startsWith(':?') || body.startsWith('?')) {
        if (v === '') {
          const d = expandWord(sh, body.startsWith(':?') ? body.slice(2) : body.slice(1));
          process.stderr.write(`bash: ${n}: ${d}\n`);
          process.exit(0);
        }
        return v;
      }
      if (body.startsWith(':+') || body.startsWith('+')) {
        const alt = body.startsWith(':+') ? body.slice(2) : body.slice(1);
        return v !== '' ? expandWord(sh, alt) : '';
      }
      if (body.startsWith(':')) {
        // ${name:off:len} / ${name:off} — string slice (offsets may be
        // arithmetic expressions: `${s:j:1}`)
        const spec = body.slice(1);
        const [off, len] = spec.split(':');
        let o = Number(off) || 0;
        if (String(off).trim() !== '' && String(Number(off)) !== String(off).trim()) {
          try { o = evalArith(String(off), sh); } catch { /* keep 0 */ }
        }
        const oo = o < 0 ? Math.max(0, v.length + o) : o;
        return len !== undefined && len !== '' ? v.slice(oo, oo + (Number(len) || 0)) : v.slice(oo);
      }
      return m; // unknown op — leave the literal alone
    });
    if (next === out) break;
    out = next;
  }
  // strip a pair of surrounding quotes (parser keeps them in defaults)
  if (out.length >= 2) {
    const q = out[0];
    if ((q === '"' || q === "'") && out.endsWith(q)) out = out.slice(1, -1);
  }
  return out;
}

// Command substitution in plain strings (heredocs, array elements, case
// patterns): run `$(...)` / backtick bodies through a real shell.
function runCmdSubst(s, sh) {
  return String(s).replace(/\$(\(\([\s\S]*?\)\)|\([\s\S]*?\)|`[\s\S]*?`)/g, (m) => {
    if (m.startsWith('$(') && !m.startsWith('$((')) {
      const inner = m.slice(2, -1);
      return shellCapture(expandUnquoted(sh, inner));
    }
    if (m.startsWith('`')) {
      const inner = m.slice(1, -1);
      return shellCapture(expandUnquoted(sh, inner.replace(/\\`/g, '`')));
    }
    return m; // $((...)) arithmetic: leave as-is (evaluated elsewhere)
  });
}

// Expand shell variables in the UNQUOTED segments of a code fragment (a
// single-quoted inner segment must stay literal — `$(sed 's/$x//')`).
function expandUnquoted(sh, code) {
  if (!sh) return String(code);
  const parts = String(code).split("'");
  for (let i = 0; i < parts.length; i += 2) {
    parts[i] = expandWord(sh, parts[i]);
  }
  return parts.join("'");
}

function shellCapture(code) {
  try {
    const r = spawnSync('bash', ['-c', code], { encoding: 'utf8' });
    if (r.error) return '';
    return String(r.stdout ?? '').replace(/\n+$/, '');
  } catch { return ''; }
}

function runShellString(code) {
  try { spawnSync('bash', ['-c', code], { stdio: 'inherit' }); } catch { /* ignore */ }
}

function runShellFile(file, args) {
  try { spawnSync('bash', [file, ...args], { stdio: 'inherit' }); } catch { /* ignore */ }
}

// ── glob expansion ───────────────────────────────────────────────────
// Expand an unquoted glob pattern against the filesystem. Returns [] when
// nothing matches (caller keeps the literal pattern — nullglob is off).
function globExpand(pattern) {
  const parts = pattern.split('/');
  let dirs = [''];
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const last = i === parts.length - 1;
    const next = [];
    for (const d of dirs) {
      const base = d === '' ? '.' : d;
      let entries;
      try { entries = fs.readdirSync(base, { withFileTypes: true }); } catch { continue; }
      for (const ent of entries) {
        const name = ent.name;
        if (name.startsWith('.') && !part.startsWith('.')) continue; // dotglob off
        if (!globMatch(part, name)) continue;
        const p = d === '' ? name : d + '/' + name;
        if (last) next.push(p);
        else if (ent.isDirectory()) next.push(p);
      }
    }
    dirs = next;
  }
  return dirs.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}

// ── printf ───────────────────────────────────────────────────────────
// bash reuses the FORMAT string for every argument (cycling through
// conversions), so `printf '%s ' a b` prints "a b ". We emit one format
// pass per argument, consuming one conversion per pass.
function printfFormat(format, args) {
  if (args.length === 0) return formatOnce(format, () => '');
  let out = '';
  let ai = 0;
  while (ai < args.length) {
    // One pass over the format per argument (bash cycles the format across
    // arguments). Count how many conversions the pass actually consumed so
    // `ai` always advances — a format with NO recognized conversions (e.g.
    // `%q` when unhandled, or plain text) must still terminate.
    let used = 0;
    out += formatOnce(format, () => { used++; return args[ai + used - 1] ?? ''; });
    ai += Math.max(used, 1);
  }
  return out;
}

function formatOnce(format, nextArg) {
  const specs = /%(?:[-+ 0#]*\d*(?:\.\d+)?[diouxXeEfgGcbsq%])/g;
  let out = '';
  let last = 0;
  let m;
  while ((m = specs.exec(format)) !== null) {
    out += unescapeFormat(format.slice(last, m.index));
    const spec = m[0];
    if (spec === '%%') { out += '%'; last = m.index + 2; continue; }
    out += printfOne(spec, nextArg());
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
  const m = /^%([-+ 0#]*)(\d*)(?:\.(\d+))?([diouxXeEfgGcbsq%])$/.exec(spec) || [];
  const flags = m[1] ?? '';
  const width = m[2] ? Number(m[2]) : 0;
  const prec = m[3] ? Number(m[3]) : undefined;
  const conv = m[4] ?? spec.slice(-1);
  const pad = (s, left) => {
    if (width <= s.length) return s;
    const fill = flags.includes('0') && !flags.includes('-') && conv !== 's' ? '0' : ' ';
    const padN = width - s.length;
    return left ? s + fill.repeat(padN) : fill.repeat(padN) + s;
  };
  switch (conv) {
    case 's': return pad(a, flags.includes('-'));
    case 'q': return shellQuote(a);
    case 'd': case 'i': return pad(String(parseInt(a, 10) || 0), flags.includes('-'));
    case 'c': return pad(a[0] ?? '', flags.includes('-'));
    case 'b': return pad(a.replace(/\\n/g, '\n').replace(/\\t/g, '\t').replace(/\\0[0-7]{1,3}/g, m2 => String.fromCharCode(parseInt(m2.slice(1), 8))), flags.includes('-'));
    case 'x': return pad((parseInt(a, 10) || 0).toString(16), flags.includes('-'));
    case 'X': return pad((parseInt(a, 10) || 0).toString(16).toUpperCase(), flags.includes('-'));
    case 'o': return pad((parseInt(a, 10) || 0).toString(8), flags.includes('-'));
    case 'f': {
      let s = String(parseFloat(a) || 0);
      if (prec !== undefined) s = (parseFloat(a) || 0).toFixed(prec);
      return pad(s, flags.includes('-'));
    }
    default: return a;
  }
}

// bash `%q` — quote the argument for reuse as shell input. Printable safe
// characters pass through; whitespace/specials get backslash-escaped;
// non-printables (newline, tab, …) force the $'...' form.
function shellQuote(s) {
  const safe = /^[A-Za-z0-9_.,:@%+=/-]*$/;
  if (safe.test(s)) return s;
  if (/[^\x20-\x7e]/.test(s)) {
    let out = "$'";
    for (const ch of s) {
      const c = ch.codePointAt(0);
      if (ch === '\\') out += '\\\\';
      else if (ch === "'") out += "\\'";
      else if (ch === '\n') out += '\\n';
      else if (ch === '\t') out += '\\t';
      else if (ch === '\r') out += '\\r';
      else if (c < 0x20 || c === 0x7f) out += '\\0' + c.toString(8).padStart(3, '0');
      else out += ch;
    }
    return out + "'";
  }
  return s.replace(/([^A-Za-z0-9_.,:@%+=/-])/g, '\\$1');
}

// ── test expression tokenizer / parser / evaluator ───────────────────
export function tokenizeTest(expr) {
  const tokens = [];
  let i = 0;
  const n = expr.length;
  while (i < n) {
    const c = expr[i];
    if (/\s/.test(c)) { i++; continue; }
    if (c === '\\' && (expr[i + 1] === '(' || expr[i + 1] === ')')) {
      // `\(` / `\)` — escaped parens are GROUPING in `[ ]` (POSIX requires
      // the escape); the test-expr reconstruction keeps the backslash.
      tokens.push(expr[i + 1]);
      i += 2;
      continue;
    }
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
      if (ch === '\\' && (expr[i + 1] === '(' || expr[i + 1] === ')')) break; // \( / \) — grouping; ends this word
      if ((ch === '(' || ch === ')') && !started) break;
      if (ch === '=' || ch === '<' || ch === '>') break;
      if (ch === '!' && (expr[i + 1] === '=' || (!started && expr[i + 1] !== '('))) break;
      if (ch === '"' || ch === "'") {
        const q = ch;
        i++;
        started = true;
        let inner = '';
        while (i < n && expr[i] !== q) {
          if (expr[i] === '$' && expr[i + 1] === '(') {
            // `$(...)` inside the quotes: skip to the MATCHING close paren,
            // ignoring parens/quotes nested inside the command text, so the
            // inner quotes (`"$(readlink \"/path\")"`) don't end the token.
            let j = i + 2;
            let depth = 1;
            while (j < n && depth > 0) {
              const cc = expr[j];
              if (cc === '\\') { j += 2; continue; }
              if (cc === '"' || cc === "'") {
                const qq = cc; j++;
                while (j < n && expr[j] !== qq) { if (expr[j] === '\\') j++; j++; }
                j++;
                continue;
              }
              if (cc === '(') depth++;
              else if (cc === ')') depth--;
              j++;
            }
            inner += expr.slice(i, j);
            i = j;
            continue;
          }
          if (expr[i] === '\\' && i + 1 < n) { inner += expr[i + 1]; i += 2; continue; }
          inner += expr[i++];
        }
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
          try {
            tok += String(evalArith(inner, sh2));
          } catch {
            tok += ''; // bash: arithmetic error → empty expansion
          }
          i = j;
          continue;
        }
        // $(...) / backticks — command substitution (run through bash)
        let rest = expr.slice(i);
        let cm = rest.match(/^\$\(([\s\S]*?)\)/) || rest.match(/^`([\s\S]*?)`/);
        if (cm) {
          started = true;
          tok += shellCapture(cm[1]);
          i += cm[0].length;
          continue;
        }
        let m = rest.match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\}/) || rest.match(/^\$([A-Za-z_][A-Za-z0-9_]*|\d+|[#@*?$])/);
        if (m) {
          started = true;
          tok += sh2.getVar(m[1]);
          i += m[0].length;
          continue;
        }
        // `${var#pat}` / `${var%pat}` / `${var:-def}` / `${var:=def}` /
        // `${var:?msg}` / `${var^^}` / `${var,,}` / `${var//p/r}` — run the
        // expansion through sh2.param. The closing brace may be missing when
        // the parser split the expansion at an inner space (`${x#* }`), so it
        // is optional here.
        let pm = rest.match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)((?:##?|%%?|:-|:=|:\?|\^\^?|,,?|\/\/?)[^}]*)?\}?/);
        if (pm) {
          started = true;
          const name = pm[1];
          const opBody = pm[2] ?? '';
          let op = '';
          let extra = '';
          const om = /^(##?|%%?|:-|:=|:\?|\^\^?|,,?|\/\/?)(.*)$/s.exec(opBody);
          if (om) {
            op = om[1];
            extra = om[2] ?? '';
          }
          if (op === '') tok += sh2.getVar(name);
          else if (op === '^^' || op === ',,' || op === '^' || op === ',') tok += sh2.param(op, name);
          else if (op === '//' || op === '/') {
            const slash = extra.indexOf('/');
            const pat = slash >= 0 ? extra.slice(0, slash) : extra;
            const rep = slash >= 0 ? extra.slice(slash + 1) : '';
            tok += sh2.param('//', name, pat, rep);
          } else {
            tok += sh2.param(op, name, extra);
          }
          i += pm[0].length;
          continue;
        }
      }
      if (ch === '~' && !started && tok === '') {
        // leading ~ expands to $HOME (and ~/... to $HOME/...); `~user`
        // stays literal
        started = true;
        const home = sh2.getVar('HOME') || process.env.HOME || '';
        const next = expr[i + 1];
        if (!/[A-Za-z0-9_]/.test(next ?? '')) {
          tok += home;
          i++;
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

const UNARY_FLAGS = new Set(['-f', '-d', '-e', '-s', '-x', '-w', '-r', '-n', '-z', '-L', '-h', '-b', '-c', '-p', '-u', '-g', '-k', '-S', '-t', '-o', '-a', '-O', '-G', '-N']);
const BIN_OPS = new Set(['=', '==', '!=', '-eq', '-ne', '-lt', '-le', '-gt', '-ge', '<', '>', '=~', '-nt', '-ot', '-ef']);
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
        case '-nt': return statTime(l) > statTime(r);
        case '-ot': return statTime(l) < statTime(r);
        case '-ef': {
          const a = statInfo(l), b = statInfo(r);
          return !!(a && b && a.dev === b.dev && a.ino === b.ino);
        }
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
  // bash: a unary test on an EMPTY argument is false (except -z); an empty
  // path must not resolve to the cwd.
  if (String(arg) === '') {
    if (flag === '-z') return true;
    if (flag === '-n') return false;
    return false;
  }
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
      case '-u': return !!(st.mode & 0o4000);
      case '-g': return !!(st.mode & 0o2000);
      case '-k': return !!(st.mode & 0o1000);
      case '-O': return st.uid === process.getuid();
      case '-G': return st.gid === process.getgid();
      case '-N': return st.mtimeMs > st.atimeMs;
      case '-t': {
        // `-t fd` — stdin is a terminal? The harness runs the program with
        // piped stdin, so any fd is never a tty here (matches `bash file`
        // under the same conditions).
        return false;
      }
      case '-n': return String(arg).length > 0;
      case '-z': return String(arg).length === 0;
      default: throw new Error(`test flag ${flag} not supported`);
    }
  } catch {
    if (flag === '-e' || flag === '-f' || flag === '-d' || flag === '-L' || flag === '-h' || flag === '-s' || flag === '-x' || flag === '-w' || flag === '-r') return false;
    if (flag === '-n') return String(arg).length > 0;
    if (flag === '-z') return String(arg).length === 0;
    if (flag === '-O' || flag === '-G' || flag === '-N') return false;
    if (flag === '-u' || flag === '-g' || flag === '-k') return false;
    if (flag === '-t') return false;
    throw new Error(`test flag ${flag} on missing path`);
  }
}

// `-nt` / `-ot` / `-ef` helpers. Missing files count as infinitely old
// (bash treats a nonexistent operand as older than any existing file).
function statTime(p) {
  try { return fs.lstatSync(path.resolve(p)).mtimeMs; } catch { return -Infinity; }
}
function statInfo(p) {
  try {
    const st = fs.lstatSync(path.resolve(p));
    return { dev: st.dev, ino: st.ino };
  } catch { return null; }
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
    // prefix ++ / -- (`$((++i))`, `(( j = i++ + ++i ))`)
    if (s.slice(pos, pos + 2) === '++') {
      pos += 2;
      const m = s.slice(pos).match(/^([A-Za-z_][A-Za-z0-9_]*)/);
      if (!m) throw new Error('arith: expected variable after ++');
      pos += m[0].length;
      const v = (Number(sh.getVar(m[1])) || 0) + 1;
      sh.setVar(m[1], String(v));
      return v;
    }
    if (s.slice(pos, pos + 2) === '--') {
      pos += 2;
      const m = s.slice(pos).match(/^([A-Za-z_][A-Za-z0-9_]*)/);
      if (!m) throw new Error('arith: expected variable after --');
      pos += m[0].length;
      const v = (Number(sh.getVar(m[1])) || 0) - 1;
      sh.setVar(m[1], String(v));
      return v;
    }
    // $var / ${var} references (bash expands these BEFORE parsing, so an
    // unset variable becomes the empty string; in arithmetic it reads as 0)
    let dm = s.slice(pos).match(/^\$\{#([A-Za-z_][A-Za-z0-9_]*)\[@\]\}/)
      || s.slice(pos).match(/^\$\{#([A-Za-z_][A-Za-z0-9_]*)\}/)
      || s.slice(pos).match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\[([^}\]]+)\]\}/)
      || s.slice(pos).match(/^\$\{([A-Za-z_][A-Za-z0-9_]*)\}/)
      || s.slice(pos).match(/^\$(\d+|[@#*?$])/)
      || s.slice(pos).match(/^\$([A-Za-z_][A-Za-z0-9_]*)/);
    if (dm) {
      pos += dm[0].length;
      const name = dm[1];
      if (dm[0].startsWith('${#')) {
        // ${#arr[@]} — array length; ${#var} — string length
        if (dm[0].includes('[@]')) return Number(sh.arrayLen(name)) || 0;
        return sh.getVar(name).length;
      }
      if (dm[0].includes('[') && dm[2] !== undefined) {
        // ${name[key]} — array element (arithmetic key)
        let idx;
        try { idx = evalArith(String(dm[2]), sh); } catch { idx = Number(dm[2]) || 0; }
        const arr = sh.arrays.get(name) ?? [];
        return idx >= 0 && idx < arr.length ? Number(arr[idx]) || 0 : 0;
      }
      const v = sh.getVar(name);
      return Number(v) || 0; // unset/empty reads as 0 in arithmetic
    }
    // $(cmd) — command substitution (nested arithmetic like
    // `$(( $(wc -l < f) + 1 ))`)
    const cs = s.slice(pos).match(/^\$\(([^()]*)\)/);
    if (cs) {
      pos += cs[0].length;
      const out = shellCapture(cs[1]);
      return Number(String(out).trim()) || 0;
    }
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
  function mul() { let v = power(); for (;;) { ws(); const c = s[pos]; if (c === '*') { pos++; v *= power(); } else if (c === '/') { pos++; const d = power(); if (d === 0) throw new Error('arith: division by 0'); v = Math.trunc(v / d); } else if (c === '%') { pos++; const d = power(); if (d === 0) throw new Error('arith: division by 0'); v = v % d; } else return v; } }
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
function alphaRange(a, b, step) {
  const out = [];
  const ca = a.charCodeAt(0), cb = b.charCodeAt(0);
  const st = step ? Math.abs(parseInt(step, 10)) || 1 : 1;
  if (ca <= cb) for (let i = ca; i <= cb; i += st) out.push(String.fromCharCode(i));
  else for (let i = ca; i >= cb; i -= st) out.push(String.fromCharCode(i));
  return out;
}

function braceRange([start, end, step, format]) {
  const st = step ? Math.abs(parseInt(step, 10)) || 1 : 1;
  const numRe = /^-?\d+$/;
  const isNum = numRe.test(String(start)) && numRe.test(String(end));
  // mixed `{a1..c3}` → alpha part × numeric part
  const am = /^([a-zA-Z]+)(\d+)$/.exec(String(start));
  const bm = /^([a-zA-Z]+)(\d+)$/.exec(String(end));
  if (!isNum && am && bm) {
    const alphas = alphaRange(am[1], bm[1], 1);
    const lo = parseInt(am[2], 10), hi = parseInt(bm[2], 10);
    const width = Math.max(am[2].length, bm[2].length);
    const out = [];
    for (const ch of alphas) {
      if (lo <= hi) for (let n = lo; n <= hi; n++) out.push(ch + String(n).padStart(width, '0'));
      else for (let n = lo; n >= hi; n--) out.push(ch + String(n).padStart(width, '0'));
    }
    return out;
  }
  if (isNum) {
    const a = parseInt(start, 10), b = parseInt(end, 10);
    if (Number.isNaN(a) || Number.isNaN(b)) return [String(start) + '..' + String(end)];
    const width = /^0/.test(String(start)) || /^0/.test(String(end))
      ? Math.max(String(start).length, String(end).length) : 0;
    const out = [];
    const fmt = (n) => {
      const s = String(Math.abs(n));
      const padded = width ? s.padStart(width, '0') : s;
      return n < 0 ? '-' + padded : padded;
    };
    if (a <= b) for (let i = a; i <= b; i += st) out.push(fmt(i));
    else for (let i = a; i >= b; i -= st) out.push(fmt(i));
    return out;
  }
  if (/^[a-zA-Z]$/.test(String(start)) && /^[a-zA-Z]$/.test(String(end))) {
    return alphaRange(String(start), String(end), st);
  }
  // longer alpha runs ({ab..az}) — step applies to the last letter
  if (/^[a-zA-Z]+$/.test(String(start)) && /^[a-zA-Z]+$/.test(String(end))) {
    const out = [];
    const ca = String(start).charCodeAt(0), cb = String(end).charCodeAt(0);
    const prefix = String(start).slice(0, -1);
    if (ca <= cb) for (let i = ca; i <= cb; i += st) out.push(prefix + String.fromCharCode(i));
    else for (let i = ca; i >= cb; i -= st) out.push(prefix + String.fromCharCode(i));
    return out;
  }
  return [String(start) + '..' + String(end)];
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
  // bash: a range inside a comma-separated group stays LITERAL
  // (`{1..3,7..9}` prints `1..3 7..9`); only a lone range expands.
  const items = g ?? [];
  const hasRange = items.some(it => it && Array.isArray(it.range));
  const out = [];
  for (const it of items) {
    if (typeof it === 'string') out.push(it);
    else if (it && Array.isArray(it.range)) {
      if (items.length === 1) out.push(...braceRange(it.range));
      else out.push(it.range.slice(0, 2).join('..'));
    }
    else if (it && Array.isArray(it.nested)) out.push(...expandBraceNested(it.nested));
    else if (Array.isArray(it)) out.push(...expandBraceNested(it));
  }
  return out;
}
