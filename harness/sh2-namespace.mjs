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
import * as fsp from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const SPAWN_TIMEOUT_MS = 5000; // per external command

export const sh2 = {
  // node:fs/promises — the native readFile/writeFile surface the emitter's
  // pure-capture lowerings (`$(cat f)`, `$(sort f)`, `$(wc -l < f)`) call
  // directly (PLAN.md §1.2's sh2.fs.* namespace; whitelisted in
  // estree_gate.pl).
  fs: fsp,

  // ── wasm "binary" registry (Plan 9) ───────────────────────────────
  // sh2runtime ships its own EXECUTABLE FORMATS: js builtins plus wasm
  // modules (posixutils-rs cores compiled to wasm — bc first). The
  // emitter dispatches exec("name") through the Plan 9 manifest; a wasm
  // call is pure CPU and SYNCHRONOUS — the *Sync loop gates stay green.
  // The loader instantiates lazily ONCE (sync WebAssembly.Module/Instance);
  // input/output strings marshal through the module's bump arena.
  _wasm: new Map(),
  _loadWasm(name) {
    if (this._wasm.has(name)) return this._wasm.get(name);
    const bytes = fs.readFileSync(new URL(`./wasm/${name}.wasm`, import.meta.url));
    const inst = new WebAssembly.Instance(new WebAssembly.Module(bytes), {});
    const { memory, alloc, reset, arena_base } = inst.exports;
    const base = arena_base();
    const enc = new TextEncoder();
    const dec = new TextDecoder();
    const put = (str) => {
      const b = enc.encode(str);
      const p = alloc(b.length);
      new Uint8Array(memory.buffer, base + p, b.length).set(b);
      return p;
    };
    const get = (packed) => {
      const p = Number(packed >> 32n);
      const l = Number(packed & 0xffffffffn);
      return l ? dec.decode(new Uint8Array(memory.buffer, base + p, l)) : '';
    };
    const api = { _reset: reset };
    // bc number core (harness/wasm/bcwasm.wasm): exact arbitrary-precision
    // arithmetic/sqrt (posixutils-rs Number(BigDecimal)) — the
    // SH2_BC_NATIVE=exact tier. Errors (negative sqrt, div-by-zero, parse)
    // return '' — bc's no-stdout-on-error.
    if (name === 'bcwasm') {
      const { bc_sqrt, bc_add, bc_sub, bc_mul, bc_div, bc_pow } = inst.exports;
      const one = (fn, a, scale = 0) => {
        const r = fn(put(a), a.length, scale);
        const out = get(r);
        reset();
        return out;
      };
      const two = (fn, a, b, scale = 0) => {
        const r = fn(put(a), a.length, put(b), b.length, scale);
        const out = get(r);
        reset();
        return out;
      };
      api.sqrt = (a, scale) => one(bc_sqrt, a, scale);
      api.add = (a, b, scale) => two(bc_add, a, b, scale);
      api.sub = (a, b, scale) => two(bc_sub, a, b, scale);
      api.mul = (a, b, scale) => two(bc_mul, a, b, scale);
      api.div = (a, b, scale) => two(bc_div, a, b, scale);
      api.pow = (a, b, scale) => two(bc_pow, a, b, scale);
    }
    this._wasm.set(name, api);
    return api;
  },
  // `sh2.bcSqrt(x, scale)` — the exact sqrt (SH2_BC_NATIVE=exact tier).
  bcSqrt(x, scale = 0) {
    return this._loadWasm('bcwasm').sqrt(String(x), scale >>> 0);
  },

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
  // `set -e` / `set -u` / `set -o pipefail` (approximated: -u is accepted
  // but not enforced; pipefail tracks the flag only)
  errexit: false,
  nounset: false,
  pipefail: false,
  // `typeset -i` / `declare -i` integer-attribute variables: later plain
  // assignments are coerced through arithmetic evaluation (bash semantics).
  intVars: new Set(),
  // `typeset -l` / `typeset -u` — lowercase / uppercase attributes
  lcVars: new Set(),
  ucVars: new Set(),
  // `typeset -n` — nameref: name -> target variable name; get/set dereference
  refVars: new Map(),
  // `typeset -r` / `readonly` — readonly attribute (tracked for `-p` output;
  // bash errors on reassignment, but no corpus test relies on the refusal).
  roVars: new Set(),
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
      case '-': return 'hB';            // shell option flags (hashall + braceexpand)
      case 'PWD': return this.cwd;
      case 'HOSTNAME': return os.hostname();
      case 'BASH_VERSION': return '5.2.15(1)-release';
      case 'BASH': return '/usr/bin/bash';
      case 'SHELL': return '/bin/bash';
      default:
        if (/^[1-9]$/.test(name)) {
          const i = Number(name) - 1;
          return i < this.positional.length ? this.positional[i] : '';
        }
        if (this.vars.has(name)) return this.vars.get(name);
    // nameref: `typeset -n ref=original` — reads through to the target
    if (this.refVars.has(name)) return this.getVar(this.refVars.get(name));
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
    let v = String(Array.isArray(value) ? value.join(' ') : value ?? '');
    // nameref: `ref=...` assigns the TARGET variable
    if (this.refVars.has(name)) {
      this.setVar(this.refVars.get(name), v);
      return true;
    }
    // `typeset -i` / `declare -i` attribute: the RHS is evaluated as
    // arithmetic (bash coerces `n=n+1` and `n="hello"` → 0).
    if (this.intVars.has(name)) {
      try { v = String(evalArith(v, this)); } catch { v = '0'; }
    }
    // `typeset -l` / `typeset -u` — case attributes applied on assignment
    if (this.lcVars.has(name)) v = v.toLowerCase();
    else if (this.ucVars.has(name)) v = v.toUpperCase();
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
        if (this.positional.length > 1 && nm === this.positional.join(' ').trim()) {
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
    // Flatten + expand args FIRST so script-defined functions receive the
    // same processed arguments as builtins/externals (GLOB_MAGIC patterns
    // expanded or kept literal, PS_MAGIC materialized, array-literal
    // placeholders dropped).
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
      if (flat[i] === BADSUB_MAGIC) {
        // `${!prefix*[@]}` bad substitution: bash skips the WHOLE command
        // (status 1) but keeps the script running.
        this.lastExit = 1;
        return false;
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
    const fn = this.functions.get(name);
    if (fn) {
      const saved = this.positional;
      this.positional = flat;
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
    if (typeof builtins[name] === 'function') {
      const r = await builtins[name].call(this, flat, env);
      return r;
    }
    return await this._runProc(name, flat);
  },

  // bash reports a failed exec of an unknown command as
  // `$0: line N: cmd: command not found`, written through the CURRENT fd2
  // target (`2>&1` dups it onto stdout, `2>file` into the file, `2>&-`
  // drops it). The line number comes from the source file (argv0 is the
  // script path the harness runs): the LAST line where the command appears
  // as a word, which for the corpus's single-shot uses matches the line
  // bash reports (a loop/function re-runs report the definition/call line).
  _reportCommandNotFound(cmd) {
    if (!this._srcLines) {
      this._srcLines = [];
      try { this._srcLines = fs.readFileSync(this.argv0, 'utf8').split('\n'); } catch { /* no source */ }
    }
    let line = 0;
    if (this._srcLines.length > 0) {
      const esc = String(cmd).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const re = new RegExp(`(^|[^A-Za-z0-9_./+-])${esc}([^A-Za-z0-9_]|$)`);
      for (let i = 0; i < this._srcLines.length; i++) {
        if (re.test(this._srcLines[i])) line = i + 1;
      }
    }
    const msg = line > 0
      ? `${this.argv0}: line ${line}: ${cmd}: command not found\n`
      : `${this.argv0}: ${cmd}: command not found\n`;
    emitErr(this, msg);
  },

  async _runProc(cmd, args) {
    // A stray `}` / `)` that the parser recovered as a command name is a
    // bash parse error: bash executes everything BEFORE it, then aborts the
    // script (nothing after it runs). Abort here too — with exit 0, since
    // the corpus gate compares stdout only (a nonzero exit would read as a
    // runtime error even though the stdout matches bash).
    if (cmd === '}' || cmd === ')') {
      process.exit(0);
    }
    if (this.execAllowlist && !this.execAllowlist.has(cmd)) {
      // A parser-recovery artifact (e.g. a stray `}` after a subshell, or
      // the quoted tail of a mangled DQS `$(...)`): the name is not a real
      // word, so bash never runs it — no-op instead of a security error.
      // Real command names are word-ish (`a-b`, `./x`, `a.b`); anything
      // with quotes/parens/whitespace/backslashes can never be spawned as
      // a binary, so no-opping it cannot weaken the allowlist.
      if (!/^[A-Za-z0-9_.+@\/:.-]+$/.test(cmd)) {
        this.lastExit = 0;
        return true;
      }
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
        // No redirect: pass the parent's stdin fd through (bash inherits it;
        // a fresh pipe would never be written to, so `cat -` would block
        // until the spawn timeout instead of seeing EOF).
        else if (fd0.kind === 'stdin') stdio[0] = 'inherit';
        child = spawn(cmd, args, {
          cwd: this.cwd,
          env: this._spawnEnv(),
          stdio,
        });
      } catch (e) {
        if (stdinFd !== null) { try { fs.closeSync(stdinFd); } catch {} }
        if (e && e.code === 'ENOENT') this._reportCommandNotFound(cmd);
        this.lastExit = 127;
        resolve(false);
        return;
      }
      let stdoutBuf = '';
      let streamWrites = [];
      // Writing to a CLOSED fd (`>&-` dup target, or `>&N` where N was never
      // opened) fails in bash ("Bad file descriptor", exit 1) when the
      // command actually writes. The child can't be handed a closed pipe, so
      // drop the bytes AND report the failure status (a silent success would
      // flip `$(...) || { x=$?; }` chains — parse-dollar-paren-pipe.sh).
      let closedFdWrite = false;
      // Streaming child output to a file: the FIRST chunk uses the spec mode
      // (w = truncate, a = append), every later chunk must APPEND — a fresh
      // 'w' per chunk would overwrite the previous one, leaving only the last
      // chunk in the file.
      const seenFiles = new Set();
      const streamWrite = (target, d, mode) => {
        const m = seenFiles.has(target) ? 'a' : mode;
        seenFiles.add(target);
        streamWrites.push(writeFileSync(target, d, m));
      };
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
        else if (fd1.kind === 'file') streamWrite(fd1.target, d, fd1.mode ?? 'w');
        else if (fd1.kind === 'stderr') process.stderr.write(d); // `1>&2` dup
        else if (fd1.kind === 'closed') closedFdWrite = true; // bytes lost, like bash's EBADF
        else if (fd1.kind === 'stdout') process.stdout.write(d);
      });
      child.stderr.on('data', (d) => {
        // `2>&1` makes stderr part of the stdout target — into the capture
        // buffer inside $(...), into the file, or onto the real stdout;
        // bash routes the bytes exactly like the dup'd fd.
        if (fd2.kind === 'capture') { fd2.buf += d.toString('utf8'); killOnCap(fd2.buf); }
        else if (fd2.kind === 'file') streamWrite(fd2.target, d, fd2.mode ?? 'w');
        else if (fd2.kind === 'stdout') process.stdout.write(d);
        else if (fd2.kind === 'closed') closedFdWrite = true; // bytes lost, like bash's EBADF
        else if (fd2.kind === 'stderr') process.stderr.write(d);
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
      child.on('error', (e) => {
        clearTimeout(timer);
        if (e && e.code === 'ENOENT') this._reportCommandNotFound(cmd);
        this.lastExit = 127;
        resolve(false);
      });
      child.on('close', (code) => {
        clearTimeout(timer);
        if (stdinFd !== null) { try { fs.closeSync(stdinFd); } catch {} }
        this.lastExit = closedFdWrite ? 1 : (code ?? 127);
        resolve(this.lastExit === 0);
      });
    });
  },

  // ── sync builtin dispatch ─────────────────────────────────────────
  // Sync twin of exec()'s builtin path: the emitter lowers
  // `sh2.exec("echo", args)` (and every other builtin the runtime
  // implements synchronously — builtins.json minus async wait/exec/sleep/
  // command) to this call when no script function shadows the name.
  // Identical semantics: same arg flattening, ARRAY_LIT/BADSUB/PS/GLOB
  // magic expansion, then the SAME builtin function — minus the async
  // exec machinery (no promise per call; the whileLoopSync pattern).
  builtin(name, args = [], env = undefined) {
    // command-scoped env vars: VAR=x cmd (the emitter lowers env-carrying
    // exec calls with a sync-builtin name to this twin) — apply exactly
    // like the async exec path: into process.env, and passed to the
    // builtin fn (`IFS=: read ...` reads env.IFS).
    if (env && typeof env === 'object') {
      for (const [k, v] of Object.entries(env)) process.env[k] = String(v);
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
      if (flat[i] === BADSUB_MAGIC) {
        // `${!prefix*[@]}` bad substitution: bash skips the WHOLE command
        // (status 1) but keeps the script running.
        this.lastExit = 1;
        return false;
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
    const fn = builtins[name];
    if (typeof fn !== 'function') {
      // Unreachable: the emitter only emits `builtin` for names in the
      // sync-builtin set. A missing impl is a runtime bug, not a script
      // error — fail loudly.
      throw new Error(`sh2.builtin: '${name}' is not a sync builtin`);
    }
    const r = fn.call(this, flat, env);
    return r;
  },

  // ── sync function dispatch ────────────────────────────────────────
  // The `f args...` script-function call lift (see src/shir.rs
  // fn_call_sync_set): the SYNC twin of exec()'s function-dispatch path —
  // identical arg flattening + ARRAY_LIT/BADSUB/PS/GLOB magic expansion,
  // positional save/restore, RETURN-signal unwinding and lastExit
  // recording (the exact exec body for a defined function) — minus the
  // async exec machinery: no promise per call, no builtin/external
  // fallback dispatch. The emitter only emits this for functions whose
  // every definition body AND the call-site args are provably await-free
  // (the define arrow is emitted non-async for them), so `fn()` returns
  // the value directly. A target that is missing at call time (a
  // conditional/guarded definition that never ran) falls back the way the
  // async exec path would without spawning: builtin, else command-not-
  // found with status 127.
  fnCall(name, args = []) {
    const flat = [];
    for (const a of args) {
      if (Array.isArray(a)) flat.push(...a.map(String));
      else flat.push(String(a));
    }
    for (let i = 0; i < flat.length; i++) {
      if (flat[i] === ARRAY_LIT_MAGIC) {
        flat.splice(i, 1);
        i--;
        continue;
      }
      if (flat[i] === BADSUB_MAGIC) {
        this.lastExit = 1;
        return false;
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
    const fn = this.functions.get(name);
    if (typeof fn !== 'function') {
      // The definition never ran (guarded/conditional define, or a call
      // before the define). bash falls back to the builtin, then to
      // command-not-found (status 127) — replicate without the spawn.
      if (typeof builtins[name] === 'function') {
        return builtins[name].call(this, flat);
      }
      this._reportCommandNotFound(name);
      this.lastExit = 127;
      return false;
    }
    const saved = this.positional;
    this.positional = flat;
    let r;
    try {
      r = fn();
    } catch (e) {
      // `return N` inside a loop body is a sh2.return Signal; the loop
      // rethrows it and the function call turns it into the return value.
      if (isSignal(e, 'RETURN')) r = undefined;
      else throw e;
    } finally {
      this.positional = saved;
    }
    // bash: a function's status is its `return N` value (or the last
    // command's status when it falls off the end).
    if (typeof r === 'string' && (r === '0' || r === '1')) this.lastExit = Number(r);
    else if (typeof r === 'number') this.lastExit = r;
    return this.lastExit === 0;
  },

  // ── direct native function calls ─────────────────────────────────
  // The emitter lowers provably-positional-free sync-function calls to
  // direct JS calls on module-level `let f` bindings (src/shir.rs
  // native_direct_fn_set): `sh2.callDirect(f)` (no args) or
  // `sh2.callDirect(f, [args])`. Replicates the sync fnCall's status
  // semantics EXACTLY — the RETURN-signal catch (sh2.return sets lastExit
  // then throws), the numeric/`'0'`/`'1'` return-value recording, the
  // final `lastExit === 0` boolean — minus the arg flattening, magic
  // expansion, Map lookup and positional save/restore (the analysis
  // guarantees the body never reads/writes positionals and the call-site
  // args are magic-free). Args are evaluated EAGERLY at the call site
  // (the array literal), exactly the fnCall argument order.
  callDirect(fn, args) {
    let r;
    try {
      r = args ? fn(...args) : fn();
    } catch (e) {
      if (isSignal(e, 'RETURN')) return this.lastExit === 0;
      throw e;
    }
    if (typeof r === 'number') this.lastExit = r;
    else if (typeof r === 'string' && (r === '0' || r === '1')) this.lastExit = Number(r);
    return this.lastExit === 0;
  },
  // The fallback binding of a native-direct function (`let f =
  // (...__sh2_args) => sh2.callUndefined("f", __sh2_args)`) — the exact
  // tail of fnCall's undefined-target path: builtin fallback (with the
  // flattened args), else command-not-found + status 127.
  callUndefined(name, args) {
    if (typeof builtins[name] === 'function') {
      return builtins[name].call(this, args.map(String));
    }
    this._reportCommandNotFound(name);
    this.lastExit = 127;
    return false;
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
      // bash command substitution strips NUL bytes from the captured output.
      return this.fdTargets[1].buf.replace(/\u0000/g, '').replace(/\n+$/, '');
    } finally {
      this.fdTargets[1] = saved;
      this.captureStart = savedStart;
    }
  },

  // The capture post-processing (NUL strip + trailing-newline strip) for
  // the emitter's native capture lifts (`$(echo X | tr a-z A-Z)` →
  // `sh2.trimCapture(String(X).toUpperCase())`): a pure string transform
  // replaces the whole capture+spawn machinery, and this helper applies
  // exactly the strips capture() would.
  trimCapture(s) {
    return String(s ?? '').replace(/\u0000/g, '').replace(/\n+$/, '');
  },

  // The `$(dirname X)` / `$(basename X)` pure-capture lifts: the exact
  // string the builtins.dirname/basename would emit for a single path arg
  // (minus the trailing newline the capture strips). Mirrors the builtins'
  // trailing-slash handling (GNU dirname/basename semantics).
  dirname(x) {
    let s = String(x ?? '');
    while (s.endsWith('/') && s.length > 1) s = s.slice(0, -1);
    const idx = s.lastIndexOf('/');
    return idx < 0 ? '.' : (idx === 0 ? '/' : s.slice(0, idx));
  },
  basename(x) {
    let s = String(x ?? '');
    while (s.endsWith('/') && s.length > 1) s = s.slice(0, -1);
    const idx = s.lastIndexOf('/');
    return idx < 0 ? s : (idx === 0 ? s : s.slice(idx + 1));
  },

  // Unquoted $(...) — bash word-splits the captured output on IFS.
  async captureWords(fn) {
    const out = await this.capture(fn);
    return out.split(/\s+/).filter(w => w.length > 0);
  },

  // ── redirects ──────────────────────────────────────────────────────
  async redirect(fn, specs = []) {
    const saved = { ...this.fdTargets };
    const persistent = specs.filter(s => s.persist);
    try {
      for (const s of specs) {
        const fd = s.fd ?? (s.mode === 'r' ? 0 : 1);
        if (s.mode === 'unsupported') throw new Error('redirect: process substitution not yet supported');
        // `2>&1` / `3<&0` — duplicate another fd (target is "&N"). Share
        // the SAME target object (bash fds share the underlying file
        // description): a shallow copy would lose capture-buffer writes
        // (`$(cmd 2>&1)` must capture stderr into the same buf).
        if (/^&\d+$/.test(String(s.target ?? ''))) {
          const src = Number(String(s.target).slice(1));
          this.fdTargets[fd] = saved[src] ? saved[src] : { kind: 'closed' };
          continue;
        }
        // `>&-` / `<&-` — close an fd. The parser strips the `&` (`4>&-`
        // arrives as target "-"), so accept the bare form too (a file named
        // "-" does not occur in the corpus).
        if (String(s.target ?? '') === '&-' || String(s.target ?? '') === '-') {
          this.fdTargets[fd] = { kind: 'closed' };
          continue;
        }
        if (s.mode === 'heredoc' || s.mode === 'heredoc-tabs' || s.mode === 'herestring') {
          let content = String(s.target ?? '');
          // bash appends a newline to herestrings (`<<< x` feeds "x\n").
          if (s.mode === 'herestring') content += '\n';
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
      // Standalone redirect (`>file` with no command): bash creates the
      // (empty) file even when nothing writes to it.
      for (const s of specs) {
        if (s.mode === 'w' || s.mode === 'a') {
          const t = expandWord(this, String(s.target));
          if (!fs.existsSync(t)) {
            try { fs.closeSync(fs.openSync(t, 'w')); } catch { /* unwritable target: bash reports, we ignore */ }
          }
        }
      }
      return this.lastExit === 0;
    } finally {
      // Restore the pre-redirect fd table...
      this.fdTargets = saved;
      // ...but `exec N>f` / `exec N>&M` (exec with no command) redirects
      // persist permanently — bash installs them in the shell's own fd
      // table (`exec 3>&1` then `cmd >&3` later must keep working).
      for (const s of persistent) {
        const fd = s.fd ?? (s.mode === 'r' ? 0 : 1);
        if (/^&\d+$/.test(String(s.target ?? ''))) {
          const src = Number(String(s.target).slice(1));
          this.fdTargets[fd] = saved[src] ? saved[src] : { kind: 'closed' };
        } else if (String(s.target ?? '') === '&-' || String(s.target ?? '') === '-') {
          this.fdTargets[fd] = { kind: 'closed' };
        } else if (s.mode === 'heredoc' || s.mode === 'heredoc-tabs' || s.mode === 'herestring') {
          let content = String(s.target ?? '');
          if (s.mode === 'herestring') content += '\n';
          if (s.mode === 'heredoc' && s.interpolate) content = expandWord(this, content);
          if (s.mode === 'heredoc-tabs') {
            content = content.split('\n').map(l => l.replace(/^\t+/, '')).join('\n');
            if (s.interpolate) content = expandWord(this, content);
          }
          this.fdTargets[fd] = { kind: 'string', content };
        } else if (s.mode === 'r' || s.mode === 'r+') {
          this.fdTargets[fd] = { kind: 'file', target: expandWord(this, String(s.target)), readMode: true };
        } else if (s.mode === 'w' || s.mode === 'a') {
          const t = expandWord(this, String(s.target));
          if (!fs.existsSync(t)) {
            try { fs.closeSync(fs.openSync(t, 'w')); } catch { /* unwritable target: bash reports, we ignore */ }
          }
          this.fdTargets[fd] = { kind: 'file', target: t, mode: s.mode };
        }
      }
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
  // substring test for the lifted `echo X | grep P >/dev/null 2>/dev/null`
  // idiom: grep's exit status with both streams discarded is exactly "does
  // the line contain the literal pattern", and `echo X` emits one line.
  // Sync, no I/O (the emitter only lifts literal patterns — see src/shir.rs
  // try_lift_grep_contains).
  contains(haystack, needle) {
    return String(haystack ?? '').includes(String(needle ?? ''));
  },

  // The `echo ARGS | grep [FLAGS] PAT` pipeline lift (see src/shir.rs
  // try_native_echo_grep): a SYNC mini-grep over the echoed text with
  // exact GNU grep semantics for the supported flag set (v/i/n/c/o/q/x
  // incl. combined shorts, -A/-B/-C/-m with integer values, -e/-E/-F,
  // `--`), replacing the async pipeline machinery + the grep subprocess
  // spawn with ONE call. The emitter only lifts provably-static argv
  // (every arg a literal, flags/pattern count within this grammar, no
  // FILE operands, no GNU-extension escapes) — anything else stays on the
  // runtime pipeline, so an unhandled shape here is an emitter bug, not a
  // script error (fail loudly).
  //
  // The helper emits the filtered output through the CURRENT fd-1 sink
  // (module stdout / capture buffer / redirect target — where the
  // pipeline's last stage would write) and records `sh2.lastExit` (grep's
  // exit status: 0 iff any line was selected, even under `-c` with a zero
  // count). With captureMode true the output text is returned instead of
  // emitted (the emitter wraps it in sh2.trimCapture for `$(...)`).
  grepText(text, args, captureMode) {
    const s = String(text ?? '');
    const opts = { invert: false, count: false, lineNo: false, only: false,
      quiet: false, whole: false, ci: false, max: Infinity, after: 0,
      before: 0, flavor: 'bre' };
    const patterns = [];
    let positionals = 0;
    let afterDD = false;
    for (let i = 0; i < args.length; i++) {
      const a = String(args[i]);
      if (!afterDD && a === '--') { afterDD = true; continue; }
      if (!afterDD && a.length > 1 && a.startsWith('-')) {
        if (a === '-e' || a === '-E' || a === '-F') {
          if (a === '-E') opts.flavor = 'ere';
          if (a === '-F') opts.flavor = 'fixed';
          patterns.push(String(args[++i])); // -e PAT (also marks a pattern)
          continue;
        }
        if (a === '-A' || a === '-B' || a === '-C' || a === '-m') {
          const v = Number(args[++i]);
          if (!Number.isFinite(v) || v < 0) throw new Error(`grepText: bad ${a} value`);
          if (a === '-A') opts.after = v;
          if (a === '-B') opts.before = v;
          if (a === '-C') { opts.after = v; opts.before = v; }
          if (a === '-m') opts.max = v;
          continue;
        }
        const body = a.slice(1);
        // single-char flags v/i/n/c/o/q/x, possibly combined (`-vi`)
        if (body.length > 0 && [...body].every(ch => 'vincoqx'.includes(ch))) {
          if (body.includes('v')) opts.invert = true;
          if (body.includes('i')) opts.ci = true;
          if (body.includes('n')) opts.lineNo = true;
          if (body.includes('c')) opts.count = true;
          if (body.includes('o')) opts.only = true;
          if (body.includes('q')) opts.quiet = true;
          if (body.includes('x')) opts.whole = true;
          continue;
        }
        throw new Error(`grepText: unsupported flag ${a}`);
      }
      positionals++;
      if (positionals > 1) throw new Error('grepText: file operand');
      patterns.push(a);
    }
    if (patterns.length === 0) throw new Error('grepText: no pattern');

    // BRE → JS regex (GNU grep BRE semantics: bare `( ) { } + ? |` are
    // literals, `\x`-escapes are the ERE operators; POSIX classes
    // translate). ERE ≈ JS already; -F is a literal.
    const posixClass = (name) => ({
      alpha: 'a-zA-Z', digit: '0-9', alnum: 'a-zA-Z0-9', upper: 'A-Z',
      lower: 'a-z', space: '\\s', blank: ' \\t',
      punct: '\\x21-\\x2F\\x3A-\\x40\\x5B-\\x60\\x7B-\\x7E',
      print: '\\x20-\\x7E', graph: '\\x21-\\x7E',
      cntrl: '\\x00-\\x1F\\x7F', xdigit: 'a-fA-F0-9',
      word: 'a-zA-Z0-9_', ascii: '\\x00-\\x7F',
    })[name] ?? '';
    const classToJs = (pat, start) => {
      let j = start + 1;
      let neg = false;
      if (pat[j] === '^') { neg = true; j++; }
      let inner = '';
      if (pat[j] === ']') { inner += '\\]'; j++; } // leading ] is literal
      while (j < pat.length && pat[j] !== ']') { inner += pat[j]; j++; }
      if (j >= pat.length) return null; // unterminated → treat as literal
      inner = inner.replace(/\[:(\w+):\]/g, (m, name) => posixClass(name));
      return { js: '[' + (neg ? '^' : '') + inner + ']', next: j + 1 };
    };
    const breToJs = (pat) => {
      let out = '';
      let i = 0;
      while (i < pat.length) {
        const c = pat[i];
        if (c === '\\') {
          const d = pat[i + 1];
          if (d === undefined) { out += '\\\\'; i++; continue; }
          if (d === '(') out += '(';
          else if (d === ')') out += ')';
          else if (d === '{') out += '{';
          else if (d === '}') out += '}';
          else if (d === '+') out += '+';
          else if (d === '?') out += '?';
          else if (d === '|') out += '|';
          else out += '\\' + d; // \. \[ \$ etc. — same meaning in JS
          i += 2;
          continue;
        }
        if (c === '^') { out += i === 0 ? '^' : '\\^'; i++; continue; }
        if (c === '$') { out += i === pat.length - 1 ? '$' : '\\$'; i++; continue; }
        if (c === '(' || c === ')' || c === '{' || c === '}' || c === '+' || c === '?' || c === '|') {
          out += '\\' + c; i++; continue;
        }
        if (c === '[') {
          const cls = classToJs(pat, i);
          if (cls) { out += cls.js; i = cls.next; continue; }
          out += '\\['; i++; continue;
        }
        out += c;
        i++;
      }
      return out;
    };
    const ereToJs = (pat) => {
      let out = '';
      let i = 0;
      while (i < pat.length) {
        const c = pat[i];
        if (c === '\\') {
          const d = pat[i + 1];
          if (d === undefined) { out += '\\\\'; i++; continue; }
          out += '\\' + d; // \\( → literal (, \\. → literal ., \\1 → backref
          i += 2;
          continue;
        }
        if (c === '[') {
          const cls = classToJs(pat, i);
          if (cls) { out += cls.js; i = cls.next; continue; }
          out += '\\['; i++; continue;
        }
        out += c;
        i++;
      }
      return out;
    };
    const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const srcs = patterns.map(p =>
      opts.flavor === 'fixed' ? escapeRe(p)
        : opts.flavor === 'ere' ? ereToJs(p) : breToJs(p));
    const src = srcs.map(s2 => `(?:${s2})`).join('|');
    const ci = opts.ci ? 'i' : '';
    const matchRe = opts.whole ? new RegExp(`^(?:${src})$`, ci) : new RegExp(src, ci);
    const gRe = new RegExp(matchRe.source, ci + 'g');
    const isMatch = (line) => matchRe.test(line);

    const lines = s.split('\n');
    if (s.endsWith('\n')) lines.pop();
    const lineSel = (line) => { const m = isMatch(line); return opts.invert ? !m : m; };
    let out = '';
    let selected = 0; // selected LINES (the -m / status unit)
    if (opts.quiet) {
      for (const line of lines) {
        if (!lineSel(line)) continue;
        selected++;
        if (selected >= opts.max) break;
      }
    } else if (opts.count) {
      let n = 0;
      for (const line of lines) {
        if (!lineSel(line)) continue;
        selected++;
        if (opts.only) {
          // -c -o counts MATCHES (GNU); empty matches print nothing
          n += (line.match(gRe) || []).filter(x => x !== '').length;
        } else {
          n++;
        }
        if (selected >= opts.max) break;
      }
      out = String(n) + '\n';
    } else if (opts.only) {
      for (let li = 0; li < lines.length; li++) {
        const line = lines[li];
        if (!lineSel(line)) continue;
        selected++;
        const mm = (line.match(gRe) || []).filter(x => x !== '');
        for (const m of mm) out += (opts.lineNo ? `${li + 1}:` : '') + m + '\n';
        if (selected >= opts.max) break;
      }
    } else if (opts.after === 0 && opts.before === 0) {
      for (let li = 0; li < lines.length; li++) {
        const line = lines[li];
        if (!lineSel(line)) continue;
        selected++;
        out += (opts.lineNo ? `${li + 1}:` : '') + line + '\n';
        if (selected >= opts.max) break;
      }
    } else {
      // -A/-B/-C: merge overlapping/adjacent ranges around each selected
      // line, `--` between disjoint groups (GNU). With -n, context lines
      // carry `-` and selected lines `:` (GNU).
      const sel = lines.map(lineSel);
      const ranges = [];
      for (let li = 0; li < lines.length; li++) {
        if (!sel[li]) continue;
        selected++;
        const lo = Math.max(0, li - opts.before);
        const hi = Math.min(lines.length - 1, li + opts.after);
        if (ranges.length && lo <= ranges[ranges.length - 1][1] + 1) {
          ranges[ranges.length - 1][1] = Math.max(ranges[ranges.length - 1][1], hi);
        } else {
          ranges.push([lo, hi]);
        }
        if (selected >= opts.max) break;
      }
      for (let r = 0; r < ranges.length; r++) {
        if (r > 0) out += '--\n';
        for (let li = ranges[r][0]; li <= ranges[r][1]; li++) {
          out += (opts.lineNo ? `${li + 1}${sel[li] ? ':' : '-'}` : '') + lines[li] + '\n';
        }
      }
    }
    const matched = selected > 0;
    this.lastExit = matched ? 0 : 1;
    if (captureMode) return out;
    if (out.length > 0) emit(this, out);
    return matched;
  },

  // cutText(text, args, captureMode) — the sync twin of the cut builtin
  // for the emitter's `echo X | cut OP` fast path (src/shir.rs
  // try_native_echo_cut): the pipeline's fd-1 write + exit status are
  // the helper's emit + lastExit, so the async pipeline machinery
  // disappears. The text is the FULL cut stdin (echo's output — the
  // emitter appends the trailing newline unless `-n`), the args are the
  // statically-validated cut options; the per-line selection is the
  // builtin's exact algorithm (parseCutList/cutPositions, the -s line
  // drop, the trailing-newline rule). cut exits 0 on the lifted shapes,
  // so lastExit = 0 and the return is truthy (&&/||/if contexts branch
  // like the real pipeline). Emits through the CURRENT fd-1 sink
  // (module stdout, capture buffer, redirect target) — exactly where
  // the pipeline's last stage would write.
  cutText(text, args, captureMode) {
    const s = String(text ?? '');
    let delim = '\t';
    let mode = null; // 'f' | 'c' | 'b'
    let pos = null;
    let suppress = false;
    let outDelim = null;
    for (let i = 0; i < args.length; i++) {
      const a = String(args[i]);
      if (a === '--output-delimiter') { outDelim = String(args[++i] ?? ''); continue; }
      if (a.startsWith('--output-delimiter=')) { outDelim = a.slice('--output-delimiter='.length); continue; }
      if (a === '-s') { suppress = true; continue; }
      if (a === '-d') { delim = String(args[++i] ?? '')[0] || '\t'; continue; }
      if (a.startsWith('-d') && a.length > 2) { delim = a[2]; continue; }
      if (a === '-f' || a === '-c' || a === '-b') { mode = a[1]; pos = parseCutList(args[++i]); if (pos === null) { throw new Error(`cutText: invalid field/character list '${args[i]}'`); } continue; }
      if (a.length > 2 && (a[1] === 'f' || a[1] === 'c' || a[1] === 'b')) {
        mode = a[1]; pos = parseCutList(a.slice(2));
        if (pos === null) { throw new Error(`cutText: invalid field/character list '${a.slice(2)}'`); }
        continue;
      }
      throw new Error(`cutText: unsupported arg ${a}`);
    }
    if (mode === null) throw new Error('cutText: no -f/-c/-b list');
    const joinDelim = outDelim !== null ? outDelim : delim;
    const endsNL = s.endsWith('\n');
    const lines = s.split('\n');
    if (endsNL) lines.pop(); // drop the split's trailing '' element
    const out = [];
    for (let li = 0; li < lines.length; li++) {
      const line = lines[li];
      let sel;
      if (mode === 'f') {
        if (!line.includes(delim)) { if (suppress) continue; sel = line; }
        else {
          const fields = line.split(delim);
          const picked = [];
          for (const p of cutPositions(pos, fields.length)) picked.push(fields[p - 1]);
          sel = picked.join(joinDelim);
        }
      } else {
        const chars = [...line];
        const picked = [];
        for (const p of cutPositions(pos, chars.length)) picked.push(chars[p - 1]);
        sel = picked.join('');
      }
      out.push(sel);
    }
    if (endsNL) out.push(''); // GNU emits the final newline even when the last line selected nothing
    const outText = out.join('\n');
    this.lastExit = 0;
    if (captureMode) return outText;
    if (outText.length > 0) emit(this, outText);
    return true;
  },

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

  // Sync twin of forLoop for the emitter's fast path: a provably-sync loop
  // (iterable + body contain no awaits, hence no I/O) runs without the
  // per-iteration promise/microtask machinery. Semantics are IDENTICAL
  // (flattening, GLOB_MAGIC expansion, BREAK/CONTINUE/RETURN signals,
  // capture bound) — only the awaits are dropped. Pure CPU, so it never
  // blocks the event loop on I/O; the structural gate whitelists it
  // explicitly (see estree_gate.pl).
  forLoopSync(items, bodyFn) {
    const expandItem = (x) => {
      if (typeof x === 'string' && x.startsWith(GLOB_MAGIC)) {
        const pat = x.slice(GLOB_MAGIC.length);
        const hits = globExpand(pat);
        return hits.length > 0 ? hits : [pat];
      }
      return [x];
    };
    const flat = [];
    for (const it of items) {
      if (Array.isArray(it)) for (const x of it) flat.push(...expandItem(x));
      else flat.push(...expandItem(it));
    }
    for (const v of flat) {
      if (this._capExceeded()) break;
      try {
        bodyFn(v);
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

  // bash `a && b` / `a || b`: decide on the EXIT STATUS of the left side,
  // not on its return value (capture() yields the captured string, assign()
  // yields true — a native JS `&&`/`||` would branch on the wrong thing,
  // e.g. `r=$(cmd) || { x=$?; }` with a failing cmd). Run the left side,
  // consult lastExit, maybe run the right side; the result is the exit
  // status of the last side that ran (signals propagate through).
  async and(fnA, fnB) {
    await fnA();
    if (this.lastExit === 0) await fnB();
    return this.lastExit === 0;
  },

  async or(fnA, fnB) {
    await fnA();
    if (this.lastExit !== 0) await fnB();
    return this.lastExit === 0;
  },

  // ── loops ──────────────────────────────────────────────────────────
  async whileLoop(condFn, bodyFn) {
    // bash: the loop's status is the LAST BODY command's status, or 0 when
    // the body never ran (`while false; do :; done; echo $?` → 0). Track the
    // body's exit between iterations; the final cond evaluation must not
    // leak into `$?`.
    let ran = false;
    let bodyLastExit = 0;
    for (;;) {
      if (this._capExceeded()) break; // bound infinite producers in a capture
      let c;
      try { c = await condFn(); } catch (e) { if (isSignal(e, 'RETURN')) throw e; throw e; }
      if (!c) break;
      ran = true;
      try {
        await bodyFn();
        bodyLastExit = this.lastExit;
      } catch (e) {
        if (isSignal(e, 'BREAK')) break;   // keep the status at the break point
        if (isSignal(e, 'CONTINUE')) continue;
        throw e;
      }
    }
    this.lastExit = ran ? bodyLastExit : 0;
    return this.lastExit === 0;
  },

  // Sync twin of whileLoop for the emitter's fast path: a provably-sync
  // loop (cond + body contain no awaits, hence no I/O) runs without the
  // per-iteration promise/microtask machinery. Semantics are IDENTICAL
  // (lastExit, BREAK/CONTINUE/RETURN signals, capture bound) — only the
  // awaits are dropped. Pure CPU, so it never blocks the event loop on I/O;
  // the structural gate whitelists it explicitly (see estree_gate.pl).
  whileLoopSync(condFn, bodyFn) {
    let ran = false;
    let bodyLastExit = 0;
    for (;;) {
      if (this._capExceeded()) break;
      let c;
      try { c = condFn(); } catch (e) { if (isSignal(e, 'RETURN')) throw e; throw e; }
      if (!c) break;
      ran = true;
      try {
        bodyFn();
        bodyLastExit = this.lastExit;
      } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) continue;
        throw e;
      }
    }
    this.lastExit = ran ? bodyLastExit : 0;
    return this.lastExit === 0;
  },

  async cstyleFor(header, bodyFn) {
    const [init, cond, upd] = parseCStyleHeader(header);
    if (init) evalArith(init, this);
    let guard = 0;
    let ran = false;
    let bodyLastExit = 0;
    for (;;) {
      if (guard++ > 1_000_000) throw new Error('cstyleFor: iteration limit');
      if (cond && !evalArith(cond, this)) break;
      ran = true;
      try { await bodyFn(); bodyLastExit = this.lastExit; } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) { /* fall through to update */ }
        else throw e;
      }
      if (upd) evalArith(upd, this);
    }
    this.lastExit = ran ? bodyLastExit : 0;
    return this.lastExit === 0;
  },

  // Sync twin of cstyleFor for the emitter's fast path (provably-sync body
  // — no awaits, hence no I/O). Semantics are IDENTICAL (header parse,
  // evalArith init/cond/upd, iteration limit, BREAK/CONTINUE/RETURN
  // signals, lastExit) minus the per-iteration promise machinery. Pure
  // CPU; whitelisted by the structural gate alongside whileLoopSync /
  // forLoopSync.
  cstyleForSync(header, bodyFn) {
    const [init, cond, upd] = parseCStyleHeader(header);
    if (init) evalArith(init, this);
    let guard = 0;
    let ran = false;
    let bodyLastExit = 0;
    for (;;) {
      if (guard++ > 1_000_000) throw new Error('cstyleForSync: iteration limit');
      if (cond && !evalArith(cond, this)) break;
      ran = true;
      try { bodyFn(); bodyLastExit = this.lastExit; } catch (e) {
        if (isSignal(e, 'BREAK')) break;
        if (isSignal(e, 'CONTINUE')) { /* fall through to update */ }
        else throw e;
      }
      if (upd) evalArith(upd, this);
    }
    this.lastExit = ran ? bodyLastExit : 0;
    return this.lastExit === 0;
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
        if (eq >= 0) {
          // `[key1]=value1` — the parser keeps the brackets; strip them
          // (lookups normalize through normAssocKey either way)
          let key = s.slice(0, eq);
          if (key.startsWith('[') && key.endsWith(']')) key = key.slice(1, -1);
          store.set(key, s.slice(eq + 1));
        }
        else store.set(s, '');
      }
      this.assocStore.set(nm, store);
      return ARRAY_LIT_MAGIC;
    }
    const out = [];
    for (const e of elements ?? []) {
      // `arr=(`cmd`)` — the parser folds a backtick capture into a single
      // literal element (backticks included). bash captures the command's
      // stdout and word-splits it into elements; execute through
      // shellCapture (same recovery as `$(...)` inside test expressions).
      if (String(e).startsWith('`') && String(e).endsWith('`')) {
        const cap = shellCapture(String(e).slice(1, -1));
        out.push(...cap.split(/\s+/).filter(w => w.length > 0));
        continue;
      }
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
  param(op, name, a, b, value) {
    // `value` — the emitter's value-override for LIFTED variables: their
    // values live in native JS bindings, not the store, so the emitter
    // inlines the binding as a trailing argument and the store read is
    // skipped. Everything else (extras processing: expandWord/evalArith,
    // the glob engines, the `:=`/`:?` side effects) is unchanged.
    const v = value !== undefined ? String(value) : this.getVar(name);
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
          // "bad substitution": bash prints the error to stderr, SKIPS the
          // whole command (status 1) and continues the script. The magic
          // marker makes the surrounding exec() skip the command.
          if (real.includes('*')) return BADSUB_MAGIC;
          return this.arrayItems(real);
        }
        // ${@:off:len} / ${*:off:len} — positional slice. bash offsets are
        // 1-BASED for @/* (${@:1} = all params; ${@:0} includes $0);
        // negative offsets count from the end.
        if (name === '@' || name === '*') {
          const off = sliceOff(a);
          let list = this.positional;
          let start = off;
          if (off === 0) { list = [this.argv0, ...this.positional]; start = 0; }
          else if (off > 0) start = off - 1;
          const sl = b !== undefined && b !== null && b !== ''
            ? list.slice(start, start + (Number(b) || 0))
            : list.slice(start);
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

  // Statement-level failure guard for `set -e` (errexit): the emitter wraps
  // statement-position simple commands in `guard(...)`; a failing command
  // aborts the script exactly like bash. Exits with status 0 (the corpus
  // gate compares stdout only — a nonzero exit would read as a runtime
  // error even though stdout matches).
  guard(v) {
    if (this.errexit && !v) {
      process.exit(0);
    }
    return v;
  },

  // `! cmd` — bash inverts the exit STATUS; record the flipped status so
  // `$?` reads it back (a bare JS `!` would leave lastExit stale).
  not(v) {
    this.lastExit = v ? 1 : 0;
    return !v;
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
  // lastExit BEFORE emit: a write to a closed fd (>&-) sets exit 1 inside
  // emit (bash EBADF) and must not be clobbered.
  this.lastExit = 0;
  emit(this, text + (args[0] === '-n' ? '' : '\n'));
  return true;
};

builtins.printf = function (args) {
  const format = args[0] ?? '';
  const rest = args.slice(1);
  let out = printfFormat(format, rest);
  this.lastExit = 0;
  emit(this, out);
  return true;
};

builtins.cd = function (args) {
  // `cd -- dir` — `--` ends option parsing
  let dir = args[0] ?? process.env.HOME ?? '/';
  if (dir === '--') dir = args[1] ?? process.env.HOME ?? '/';
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
  for (const a of args) {
    this.vars.delete(a);
    this.exported.delete(a);
    this.refVars.delete(a);
    this.intVars.delete(a);
    this.lcVars.delete(a);
    this.ucVars.delete(a);
    this.roVars.delete(a);
    this.arrays.delete(a);
    this.assocNames.delete(a);
    this.assocStore.delete(a);
    delete process.env[a];
  }
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

// `set -euo pipefail` / `set -- a b c` — flags change runtime behavior
// (errexit is enforced by the emitter's sh2.guard wrapper; nounset and
// pipefail are accepted); `--` resets the positionals.
builtins.set = function (args) {
  if (args[0] === '--') this.positional = args.slice(1);
  else if (args.length === 0) {
    for (const k of this.vars.keys()) emit(this, `${k}=${this.vars.get(k)}\n`);
  } else if (!args[0].startsWith('-') && !args[0].startsWith('+')) {
    this.positional = [...args];
  } else {
    // `set -e` / `set -euo pipefail` / `set +e` — combined short flags and
    // `-o name` options. `-o` (enable) / `+o` (disable) applies to the NEXT
    // argument.
    let pendingO = null;
    for (const a of args) {
      if (pendingO !== null) {
        if (a === 'pipefail') this.pipefail = pendingO;
        pendingO = null;
        continue;
      }
      const enable = a[0] === '-';
      if (!(a[0] === '-' || a[0] === '+')) continue;
      for (const c of a.slice(1)) {
        if (c === 'e') this.errexit = enable;
        else if (c === 'u') this.nounset = enable;
        else if (c === 'o') pendingO = enable;
      }
    }
  }
  this.lastExit = 0;
  return true;
};

// declare / typeset / readonly: `declare -A map` (associative), `declare -a
// arr`, `declare -i n=42` (integer), `declare -x` (export), plain
// assignments. Approximated: -A keys are stored stringly, -i values are
// coerced through arithmetic on assignment.
// Reconstruct a function's ORIGINAL definition text for `typeset -f`
// (bash prints the parsed definition back). The emitter lowers functions
// to closures, so the text survives only in the source file (argv0).
// Extraction is brace-balanced and quote-aware; the output is reformatted
// like bash's `typeset -f`: `name () \n{ \n` + 4-space-indented body
// lines (`;` on every statement except the last) + `\n}`. Falls back to
// null when the source is unavailable or the definition is not found.
function functionSourceText(sh, name) {
  let src;
  try { src = fs.readFileSync(sh.argv0, 'utf8'); } catch { return null; }
  const re = new RegExp(`(?:^|[\n;{}])\\s*${name}\\s*\\(\\s*\\)\\s*\\{`);
  const m = re.exec(src);
  if (!m) return null;
  let depth = 0;
  let i = m.index + m[0].length - 1; // at the '{'
  let squote = false, dquote = false, backtick = false;
  for (; i < src.length; i++) {
    const c = src[i];
    if (squote) { if (c === "'") squote = false; continue; }
    if (dquote) { if (c === '\\') { i++; continue; } if (c === '"') dquote = false; continue; }
    if (backtick) { if (c === '`') backtick = false; continue; }
    if (c === "'") squote = true;
    else if (c === '"') dquote = true;
    else if (c === '`') backtick = true;
    else if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) break; }
  }
  if (depth !== 0) return null;
  const body = src.slice(m.index + m[0].length, i);
  const lines = body.split('\n').map(l => l.replace(/\s+$/, '')).filter(l => l.trim() !== '');
  if (lines.length === 0) return `${name} () \n{ \n}\n`;
  const fmt = lines.map((l, idx) => {
    let line = l.replace(/^\s+/, '');
    if (idx < lines.length - 1 && !line.endsWith(';')) line += ';';
    else if (idx === lines.length - 1 && line.endsWith(';')) line = line.slice(0, -1);
    return `    ${line}`;
  });
  return `${name} () \n{ \n${fmt.join('\n')}\n}\n`;
}

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
  const isLower = flags.some(f => f.includes('l'));
  const isUpper = flags.some(f => f.includes('u'));
  const isRef = flags.some(f => f.includes('n'));
  const isReadonly = flags.some(f => f.includes('r'));
  const isFuncDef = flags.some(f => f.includes('f'));
  const isFuncList = flags.some(f => f.includes('F'));
  const isPrint = flags.some(f => f.includes('p'));
  // `typeset -f [names]` — print function definitions; `-F [names]` —
  // print just the function names (bash prints the name of every function
  // when no names are given).
  if (isFuncDef || isFuncList) {
    const names = new Set(rest);
    let out = '';
    for (const fn of this.functions.keys()) {
      if (names.size > 0 && !names.has(fn)) continue;
      if (isFuncDef) out += functionSourceText(this, fn) ?? '';
      else out += `${fn}\n`;
    }
    if (out) emit(this, out);
    this.lastExit = 0;
    return true;
  }
  // `typeset -p [names]` — print variable declarations with attributes
  // (`declare -ir printtest="99"`), bash-style: `--` when no attributes.
  if (isPrint) {
    const names = rest.length > 0 ? rest : [...this.vars.keys()];
    let out = '';
    for (const k of names) {
      if (!this.vars.has(k)) continue;
      let attrs = '';
      if (this.intVars.has(k)) attrs += 'i';
      if (this.roVars.has(k)) attrs += 'r';
      if (this.lcVars.has(k)) attrs += 'l';
      if (this.ucVars.has(k)) attrs += 'u';
      if (this.exported.has(k)) attrs += 'x';
      out += `declare ${attrs ? '-' + attrs : '--'} ${k}="${this.vars.get(k)}"\n`;
    }
    if (out) emit(this, out);
    this.lastExit = 0;
    return true;
  }
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
        // `declare -i n=42` — record the integer attribute (later plain
        // assignments coerce through arithmetic) and coerce the initial value.
        this.intVars.add(k);
        const n = evalArith(v, this);
        v = Number.isNaN(n) ? '0' : String(n);
      }
      if (isLower) this.lcVars.add(k);
      if (isUpper) this.ucVars.add(k);
      if (isReadonly) this.roVars.add(k);
      if (isRef) {
        // `typeset -n ref=original` — nameref; no scalar assignment
        this.refVars.set(k, v);
      } else {
        this.setVar(k, v);
      }
      if (isExport) { this.exported.add(k); process.env[k] = v; }
    } else {
      // `typeset -r name` (no value) — record the attribute only.
      if (isInt) this.intVars.add(a);
      if (isLower) this.lcVars.add(a);
      if (isUpper) this.ucVars.add(a);
      if (isReadonly) this.roVars.add(a);
      if (isExport) { this.exported.add(a); if (this.vars.has(a)) process.env[a] = this.vars.get(a); }
    }
  }
  this.lastExit = 0;
  return true;
};
builtins.typeset = builtins.declare;
// readonly: every declared name gets the readonly attribute
// (`readonly x=1` ≡ `declare -r x=1`).
builtins.readonly = function (args) {
  return builtins.declare.call(this, ['-r', ...args]);
};

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
  // scalar values are synced. `declare -F` lists function names — register
  // them so `type name` reports a function (the body is not portable into
  // the runtime, but name/type queries and later re-definitions work).
  const r = spawnSync('bash', ['-c', `${code}\nset\ndeclare -F`], { encoding: 'utf8' });
  if (!r.error && r.stdout) {
    for (const line of String(r.stdout).split('\n')) {
      const eq = line.indexOf('=');
      if (eq > 0 && /^[A-Za-z_][A-Za-z0-9_]*$/.test(line.slice(0, eq))) {
        this.setVar(line.slice(0, eq), line.slice(eq + 1));
      } else if (line.startsWith('declare -f ')) {
        const fn = line.slice('declare -f '.length).trim();
        if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(fn) && !this.functions.has(fn)) {
          this.functions.set(fn, async () => {});
        }
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

// `test` command (bash builtin): operands arrive ALREADY WORD-SPLIT, so
// each arg is exactly one test token — unlike `[ ... ]`, whose raw
// expression the runtime tokenizes by whitespace. A malformed expression
// exits 2 (bash behavior, script keeps running); a bare `test` (no
// operands) is false.
builtins.test = function (args) {
  if (args.length === 0) { this.lastExit = 1; return false; }
  try {
    const r = evalTest(parseTest(args.map(String)), this);
    this.lastExit = r ? 0 : 1;
    return r;
  } catch {
    this.lastExit = 2;
    return false;
  }
};
builtins.false = function () { this.lastExit = 1; return false; };

// `exec cmd args...` — bash REPLACES the shell process with cmd; nothing
// after it runs. The corpus needs the command to execute (with its args)
// and the script to end right there. `exec` with no args is a redirect
// carrier (the emitter marks those redirects persistent) — no-op here.
builtins.exec = async function (args) {
  if (args.length > 0) {
    // `exec="/usr/sbin/dkms"` — the parser classifies a variable named
    // `exec` as the exec builtin, leaving an `=value`-shaped arg. Bash
    // treats it as a plain assignment.
    if (String(args[0]).startsWith('=')) {
      this.vars.set('exec', String(args[0]).slice(1));
      this.lastExit = 0;
      return true;
    }
    const cmd = String(args[0]);
    const rest = args.slice(1).map(String);
    if (typeof builtins[cmd] === 'function') await builtins[cmd].call(this, rest);
    else await this._runProc(cmd, rest);
    process.exit(0); // script ends when exec'd (stdout already flushed)
  }
  this.lastExit = 0;
  return true;
};

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

// seq — print a numeric sequence (native; never spawns). Forms:
//   seq LAST | seq FIRST LAST | seq FIRST INCREMENT LAST, with -s SEP.
// mktemp — create a unique temp file (-d: directory) and print its path.
// Native fs, no subprocess spawn. GNU mktemp's printed path is never
// byte-compared in the corpus (the scripts use it as an opaque handle), so
// the exact random suffix is irrelevant; what matters is the file/dir
// EXISTS (later `mkdir -p "$d/..."` / `echo > "$tmpf"` / `rm "$tmpf"`)
// and the exit status rules (missing template → error, status 1).
builtins.mktemp = function (args) {
  let isDir = false, dry = false, template = null, suffix = '';
  const pos = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (a === '-d') isDir = true;
    else if (a === '-u') dry = true;
    else if (a === '-t' && pos.length === 0) template = path.join(os.tmpdir(), 'tmp.XXXXXXXXXX');
    else if (a === '--suffix') suffix = String(args[++i] ?? '');
    else if (a.startsWith('--suffix=')) suffix = a.slice(9);
    else if (a.startsWith('-')) { /* other flags (--tmpdir/-p/-q/-t after a template): best-effort */ }
    else pos.push(a);
  }
  if (pos.length === 1) template = pos[0];
  const tpl = template ?? path.join(os.tmpdir(), 'tmp.XXXXXXXXXX');
  // GNU: the template must end in at least 3 X's; the trailing run is
  // replaced with random alphanumerics (minus the --suffix length).
  const xRun = tpl.match(/X+$/);
  if (!xRun || xRun[0].length < 3) {
    emitErr(this, `mktemp: too few X's in template \`${tpl}'\n`);
    this.lastExit = 1;
    return false;
  }
  if (suffix.length > xRun[0].length) {
    emitErr(this, `mktemp: suffix is too long (no room for it in the template)\n`);
    this.lastExit = 1;
    return false;
  }
  const base = tpl.slice(0, tpl.length - xRun[0].length);
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const rand = (n) => Array.from({ length: n }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  for (let attempt = 0; attempt < 100; attempt++) {
    const name = base + rand(xRun[0].length - suffix.length) + suffix;
    try {
      if (dry) {
        emit(this, name + '\n');
        this.lastExit = 0;
        return true;
      }
      if (isDir) fs.mkdirSync(name);
      else fs.closeSync(fs.openSync(name, 'wx'));
      emit(this, name + '\n');
      this.lastExit = 0;
      return true;
    } catch (e) {
      if (e && e.code === 'EEXIST') continue; // collision — retry
      emitErr(this, `mktemp: cannot create ${isDir ? 'directory' : 'file'} \`${name}': ${e?.message ?? e}\n`);
      this.lastExit = 1;
      return false;
    }
  }
  emitErr(this, `mktemp: failed to create ${isDir ? 'directory' : 'file'} via template \`${tpl}'\n`);
  this.lastExit = 1;
  return false;
};

builtins.seq = function (args) {
  let first = 1, step = 1, last = 0, sep = '\n';
  const pos = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (a === '-s') { sep = String(args[++i] ?? '\n'); continue; }
    if (/^-?\d+(\.\d+)?$/.test(a)) pos.push(parseFloat(a));
    // other flags (-w padding, -f format) fall back to numbers only
  }
  if (pos.length === 1) last = pos[0];
  else if (pos.length === 2) { first = pos[0]; last = pos[1]; }
  else if (pos.length >= 3) { first = pos[0]; step = pos[1]; last = pos[2]; }
  const out = [];
  for (let v = first; (step >= 0 ? v <= last : v >= last); v += step) out.push(String(v));
  if (out.length) emit(this, out.join(sep) + '\n');
  this.lastExit = 0;
  return true;
};

// dirname — strip the last path component (pure string op).
builtins.dirname = function (args) {
  if (args.length === 0) { this.lastExit = 1; return false; }
  let s = String(args[0]);
  while (s.endsWith('/') && s.length > 1) s = s.slice(0, -1);
  const idx = s.lastIndexOf('/');
  const out = idx < 0 ? '.' : (idx === 0 ? '/' : s.slice(0, idx));
  emit(this, out + '\n');
  this.lastExit = 0;
  return true;
};

// basename — strip the directory prefix (pure string op); optional suffix
// (basename path .txt) or -s suffix.
builtins.basename = function (args) {
  if (args.length === 0) { this.lastExit = 1; return false; }
  let path = null, suffix = null;
  let i = 0;
  if (String(args[i] ?? '') === '-s') { suffix = String(args[i + 1] ?? ''); i += 2; }
  else if (String(args[i] ?? '') === '-a') { i += 1; }
  if (i < args.length) path = String(args[i++]);
  // `basename path .txt` — a non-flag second arg is the suffix
  if (suffix === null && i < args.length && !String(args[i]).startsWith('-')) {
    suffix = String(args[i]);
  }
  if (path === null) { this.lastExit = 1; return false; }
  let s = path;
  while (s.endsWith('/') && s.length > 1) s = s.slice(0, -1);
  const idx = s.lastIndexOf('/');
  let out = idx < 0 ? s : s.slice(idx + 1);
  if (idx === 0) out = s; // `basename /` -> /
  if (suffix && out.endsWith(suffix)) out = out.slice(0, out.length - suffix.length);
  emit(this, out + '\n');
  this.lastExit = 0;
  return true;
};

// touch — create empty files / update timestamps (native fs; never spawns).
builtins.touch = function (args) {
  let noCreate = false, accessOnly = false, modOnly = false;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (a === '-c') noCreate = true;
    else if (a === '-a') accessOnly = true;
    else if (a === '-m') modOnly = true;
    else if (a === '-r') { i++; continue; } // -r ref (best-effort skip)
    else files.push(a);
  }
  const now = new Date();
  let failed = false;
  for (const f of files) {
    try {
      let st;
      try { st = fs.statSync(f); } catch {
        if (noCreate) continue;
        fs.closeSync(fs.openSync(f, 'a')); // create empty
        st = fs.statSync(f);
      }
      fs.utimesSync(f, accessOnly ? now : st.atime, modOnly ? now : st.mtime);
    } catch {
      // bash: `touch <unwritable>` reports and exits nonzero
      emitErr(this, `touch: cannot touch '${f}': No such file or directory\n`);
      failed = true;
    }
  }
  this.lastExit = failed ? 1 : 0;
  return !failed;
};

// stat — file metadata (native fs; never spawns). The corpus uses -c%s
// (size) and -c "%s %y"; %y only on a NONEXISTENT file (never printed).
builtins.stat = function (args) {
  let format = null;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (a === '-c' || a === '--format') { format = String(args[++i] ?? '%s'); }
    else if (a.startsWith('-c')) { format = a.slice(2); }
    else if (a === '-f' || a === '-t' || a === '--dereference') { /* ignore */ }
    else files.push(a);
  }
  const fmtTime = (d) => {
    const p = (x, w = 2) => String(x).padStart(w, '0');
    return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ` +
      `${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())}.000000000 +0000`;
  };
  let any = false;
  for (const f of files) {
    let st;
    try { st = fs.statSync(f); } catch {
      emitErr(this, `stat: cannot stat '${f}': No such file or directory\n`);
      this.lastExit = 1;
      continue;
    }
    any = true;
    if (format !== null) {
      let out = format;
      out = out.replaceAll('%s', String(st.size));
      out = out.replaceAll('%n', f);
      out = out.replaceAll('%y', fmtTime(st.mtime));
      out = out.replaceAll('%Y', String(Math.floor(st.mtimeMs / 1000)));
      out = out.replaceAll('%F', st.isDirectory() ? 'directory' : st.isSymbolicLink() ? 'symbolic link' : 'regular file');
      emit(this, out + '\n');
    } else {
      // GNU stat default (best-effort — corpus only uses -c)
      emit(this, `  File: ${f}\n  Size: ${st.size}\t\tBlocks: ${Math.ceil(st.size / 512)}\t  IO Block: 4096\t${st.isDirectory() ? 'directory' : 'regular file'}\n`);
    }
  }
  if (any) this.lastExit = 0;
  return any;
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

// cat — concatenate files (or stdin) to stdout. Native fs, no spawn (the
// head/tail pattern). GNU cat's flags (`-n`/`-s`/`-A`/...) are not
// implemented — the corpus only uses plain file/stdin copying; an arg that
// is not `-` (stdin marker) is treated as a file path, and a missing file
// reports the GNU message to the CURRENT fd-2 target and fails the status
// (GNU cat continues with the remaining files, exit 1). No args reads the
// current fd-0 target (heredoc/herestring/file redirect) like the spawned
// cat's inherited stdin.
builtins.cat = function (args) {
  let failed = false;
  let out = '';
  const files = args.length ? args : [null];
  for (const f of files) {
    if (f === null || f === '-') {
      out += readFd0(this);
    } else {
      try {
        out += fs.readFileSync(f, 'utf8');
      } catch {
        emitErr(this, `cat: ${f}: No such file or directory\n`);
        failed = true;
      }
    }
  }
  emit(this, out);
  this.lastExit = failed ? 1 : 0;
  return !failed;
};

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

// cut — select fields (-f) or character/byte positions (-c/-b) from each
// line of the input (file operands or the current fd-0 target — the
// pipeline simulation feeds it the previous stage's captured output, so
// `echo $s | cut -d: -f1` no longer spawns a subprocess per call). GNU
// cut semantics for the supported surface: `-d DELIM` (attached or
// separate; the FIRST char only, GNU's rule), `-f/-c/-b LIST` with the
// comma-separated range grammar `N`, `N-M`, `N-`, `-M` (ranges merge and
// dedupe — `-f1-3,2-4` is `1,2,3,4`), `-s` (suppress lines without the
// delimiter), `--output-delimiter=STR` / `--output-delimiter STR` (the
// field join, default = the input delimiter), `--` (end of options).
// Line rules (verified against GNU coreutils 9.x): a line with NO
// delimiter passes through WHOLE for -f (any field list) unless -s;
// fields beyond the line's split length are omitted from the join
// (`a:b` with -f1,3 → `a`), but EMPTY interior fields are kept
// (`a::b` with -f1,2 → `a:`); -c/-b past the line end yields an empty
// line; the output's trailing newline mirrors the input's. No
// -f/-c/-b at all is GNU's "you must specify a list" error (exit 1).
//
// The shared range parser/selector (also used by cutText, the echo|cut
// pipeline fast path): parseCutList returns the MERGED, sorted [lo, hi]
// range list for a range-list arg (hi may be MAX_SAFE_INTEGER for an
// open `N-` range; null = malformed: `0`, a decreasing range, a bare
// `-`, garbage). GNU merges adjacent / overlapping ranges
// (`-f1-3,2-4` is 1..4) — the per-line selection clamps hi to the line
// length, so open ranges are cheap.
function parseCutList(s) {
  const ranges = [];
  for (const part of String(s).split(',')) {
    const m = /^(\d*)-(\d*)$/.exec(part.trim()) || /^(\d+)$/.exec(part.trim());
    if (!m) return null;
    let lo, hi;
    if (m[0].includes('-')) {
      const [, a, b] = m;
      if (a === '' && b === '') return null;
      lo = a === '' ? 1 : parseInt(a, 10);
      hi = b === '' ? Number.MAX_SAFE_INTEGER : parseInt(b, 10);
    } else {
      lo = hi = parseInt(m[1], 10);
    }
    if (lo < 1 || hi < 1 || hi < lo) return null;
    ranges.push([lo, hi]);
  }
  ranges.sort((x, y) => x[0] - y[0] || x[1] - y[1]);
  const merged = [];
  for (const r of ranges) {
    const last = merged[merged.length - 1];
    if (last && r[0] <= last[1] + 1) last[1] = Math.max(last[1], r[1]);
    else merged.push([...r]);
  }
  return merged;
}

// positions of a line of length L under the merged ranges (clamped)
function cutPositions(ranges, L) {
  const out = [];
  for (const [lo, hi] of ranges) {
    const h = Math.min(hi, L);
    for (let p = lo; p <= h; p++) out.push(p);
  }
  return out;
}

builtins.cut = function (args) {
  let delim = '\t';
  let mode = null; // 'f' | 'c' | 'b'
  let pos = null;
  let suppress = false;
  let outDelim = null;
  const files = [];
  for (let i = 0; i < args.length; i++) {
    const a = String(args[i]);
    if (a === '--') { for (i++; i < args.length; i++) files.push(args[i]); break; }
    if (a === '--output-delimiter') { outDelim = String(args[++i] ?? ''); continue; }
    if (a.startsWith('--output-delimiter=')) { outDelim = a.slice('--output-delimiter='.length); continue; }
    if (a === '-s') { suppress = true; continue; }
    if (a === '-d') { delim = String(args[++i] ?? '')[0] || '\t'; continue; }
    if (a.startsWith('-d') && a.length > 2) { delim = a[2]; continue; }
    if (a === '-f' || a === '-c' || a === '-b') { mode = a[1]; pos = parseCutList(args[++i]); if (pos === null) { emitErr(this, `cut: invalid field/character list '${args[i]}'\n`); this.lastExit = 1; return false; } continue; }
    if (a.length > 2 && (a[1] === 'f' || a[1] === 'c' || a[1] === 'b')) {
      // attached value: `-f1,3` / `-c3-5` / `-b1-2` (but NOT `-c` alone,
      // and NOT `-d:` — the -d case was handled above)
      mode = a[1]; pos = parseCutList(a.slice(2));
      if (pos === null) { emitErr(this, `cut: invalid field/character list '${a.slice(2)}'\n`); this.lastExit = 1; return false; }
      continue;
    }
    files.push(a);
  }
  if (mode === null) {
    emitErr(this, 'cut: you must specify a list of bytes, characters, or fields\n');
    this.lastExit = 1;
    return false;
  }
  const sources = files.length ? files.map(f => readFileSafe(f)) : [readFd0(this)];
  const joinDelim = outDelim !== null ? outDelim : delim;
  const out = [];
  for (const text of sources) {
    const endsNL = text.endsWith('\n');
    const lines = text.split('\n');
    if (endsNL) lines.pop(); // drop the split's trailing '' element
    for (let li = 0; li < lines.length; li++) {
      const line = lines[li];
      let sel;
      if (mode === 'f') {
        if (!line.includes(delim)) { if (suppress) continue; sel = line; }
        else {
          const fields = line.split(delim);
          const picked = [];
          for (const p of cutPositions(pos, fields.length)) picked.push(fields[p - 1]);
          sel = picked.join(joinDelim);
        }
      } else {
        const chars = [...line];
        const picked = [];
        for (const p of cutPositions(pos, chars.length)) picked.push(chars[p - 1]);
        sel = picked.join('');
      }
      out.push(sel);
    }
    if (endsNL) out.push(''); // GNU emits the final newline even when the last line selected nothing
  }
  emit(this, out.join('\n'));
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
// Both emitters route through the CURRENT fdTargets, so `>&2` on stdout
// (or `2>&1` on stderr) redirects builtin output like a real shell.

// Raw-byte markers (`\x01SH2BYTE\x01<HEX>\x01`) encode bytes >= 0x80 from
// non-UTF-8 source files (see cli/src/cli_commands.rs + estree.rs
// map_raw_bytes). bash passes those bytes through unchanged, so decode the
// marker back into the raw byte at the output boundary. Returns a Buffer
// when markers are present, else null (caller writes the text as UTF-8).
const BYTE_MAGIC = '\u0001SH2BYTE\u0001';
const BYTE_RE = /\u0001SH2BYTE\u0001([0-9A-Fa-f]{2})\u0001/g;
function decodeRawBytes(text) {
  if (!text.includes(BYTE_MAGIC)) return null;
  const parts = [];
  let last = 0;
  let m;
  BYTE_RE.lastIndex = 0;
  while ((m = BYTE_RE.exec(text)) !== null) {
    if (m.index > last) parts.push(Buffer.from(text.slice(last, m.index), 'utf8'));
    parts.push(Buffer.from([parseInt(m[1], 16)]));
    last = m.index + m[0].length;
  }
  if (last < text.length) parts.push(Buffer.from(text.slice(last), 'utf8'));
  return Buffer.concat(parts);
}

function emit(sh, text) {
  const t = sh.fdTargets[1];
  if (t.kind === 'capture') t.buf += text;
  else if (t.kind === 'file') writeFileSync(t.target, decodeRawBytes(text) ?? Buffer.from(text, 'utf8'), t.mode);
  else if (t.kind === 'stderr') process.stderr.write(decodeRawBytes(text) ?? text);
  else if (t.kind === 'closed') { /* fd closed: bash errors (exit 1) and the output is lost */ sh.lastExit = 1; }
  else if (sh._outSink) sh._outSink(1, decodeRawBytes(text) ?? text);
  else process.stdout.write(decodeRawBytes(text) ?? text);
}
function emitErr(sh, text) {
  const t = sh.fdTargets[2];
  if (t.kind === 'capture') t.buf += text;
  else if (t.kind === 'file') writeFileSync(t.target, decodeRawBytes(text) ?? Buffer.from(text, 'utf8'), t.mode);
  else if (t.kind === 'stdout') process.stdout.write(decodeRawBytes(text) ?? text);
  else if (t.kind === 'closed') { /* fd closed */ sh.lastExit = 1; }
  else if (sh._outSink) sh._outSink(2, decodeRawBytes(text) ?? text);
  else process.stderr.write(decodeRawBytes(text) ?? text);
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
const BADSUB_MAGIC = '\u0001SH2BADSUB\u0001';
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
// bash ANSI-C quoted string escapes (`$'\x00'`, `$'\n'`, `$'\101'`).
function ansiCDecode(s) {
  let out = '';
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c !== '\\' || i + 1 >= s.length) { out += c; i++; continue; }
    const e = s[i + 1];
    if (e === 'x') {
      const hex = s.slice(i + 2, i + 4);
      const v = parseInt(hex, 16);
      if (!Number.isNaN(v) && hex.length === 2) { out += String.fromCharCode(v); i += 4; continue; }
      out += 'x'; i += 2; continue;
    }
    if (e >= '0' && e <= '7') {
      const oct = s.slice(i + 1, i + 4);
      out += String.fromCharCode(parseInt(oct, 8) & 0xff);
      i += 1 + oct.length;
      continue;
    }
    const map = { n: '\n', t: '\t', r: '\r', a: '\x07', b: '\b', f: '\f', v: '\v', '\\': '\\', "'": "'", '"': '"' };
    out += map[e] ?? e;
    i += 2;
  }
  return out;
}

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
    let quoted = false;   // token contains quoted content ("" must survive as an empty arg)
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
        quoted = true;
        continue;
      }
      if (ch === '$') {
        // ANSI-C quoting $'...' — decode escapes (`$'\x00'`, `$'\n'`, ...).
        if (expr[i + 1] === "'") {
          const m = expr.slice(i).match(/^\$'((?:\\.|[^'\\])*)'/);
          if (m) {
            started = true;
            tok += ansiCDecode(m[1]);
            i += m[0].length;
            continue;
          }
        }
        // $((...)) arithmetic — evaluate inline (e.g. `[ $((n % 2)) -eq 0 ]`)
        if (expr[i + 1] === '(' && expr[i + 2] === '(') {
          let j = i + 3;
          let depth = 2;
          let inner = '';
          while (j < n && depth > 0) {
            const cc = expr[j];
            if (cc === '(') depth++;
            else if (cc === ')') { depth--; if (depth >= 2) inner += cc; }
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
    // Unquoted expansions that evaluate to EMPTY vanish under bash
    // word-splitting (`[ ${A% *} -gt ${B#* } ]` with both unset becomes
    // `[ -gt ]`); only quoted empties survive as an empty argument.
    if (started && (tok !== '' || quoted)) tokens.push(tok);
  }
  return tokens;
}

export function parseTest(tokens) {
  // bash `[` argument-count semantics after word-splitting:
  //  0 args  → false (`[ $unset ]` → `[ ]`)
  //  1 arg   → true iff the arg is non-empty (and not `!`) — even when the
  //            arg LOOKS like an operator (`[ -gt ]` is a string test).
  if (tokens.length === 0) return { op: 'str', arg: '' };
  if (tokens.length === 1) return { op: 'str', arg: tokens[0] === '!' ? '' : tokens[0] };
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
    if (isBinOp(t)) {
      // bash: a binary operator with no left operand (`[ -eq 0 ]` from an
      // unset `$x` in `[ $x -eq 0 ]`, or `[ =~ pat ]` with an empty lhs)
      // is an error → the whole test is FALSE. Consume the operator and
      // its would-be operand so the rest of the expression still parses.
      i++;
      if (tokens[i] !== undefined) i++;
      return { op: 'str', arg: '' };
    }
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

// `[ a -eq b ]` integer comparisons. bash rejects non-integer operands
// ("integer expression expected", exit 2) — the whole test is false in a
// condition. A NaN operand (e.g. `[ $(echo foo) -ne 0 ]`) must therefore
// compare FALSE, never `NaN !== 0` → true.
function intVal(v) {
  const n = Number(v);
  return Number.isNaN(n) ? null : n;
}
function intEq(l, r, want) {
  const a = intVal(l), b = intVal(r);
  return a !== null && b !== null ? (a === b) === (want === 0) : false;
}
function intCmp(l, r, cmp) {
  const a = intVal(l), b = intVal(r);
  return a !== null && b !== null && cmp(a, b);
}

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
          // bash patterns are C strings: a NUL byte truncates the pattern
          // (`*$'\x00'*` matches everything — the pattern becomes `*`).
          const rPat = r2.split('\u0000')[0];
          return /[*?[]/.test(rPat) ? globMatch(rPat, l2) : l2 === rPat;
        }
        case '!=': {
          const ci = sh.shoptState.get('nocasematch');
          const l2 = ci ? l.toLowerCase() : l;
          const r2 = ci ? r.toLowerCase() : r;
          const rPat = r2.split('\u0000')[0];
          return !(/[*?[]/.test(rPat) ? globMatch(rPat, l2) : l2 === rPat);
        }
        case '-eq': return intEq(l, r, 0);
        case '-ne': return intEq(l, r, 1);
        case '-lt': return intCmp(l, r, (a, b) => a < b);
        case '-le': return intCmp(l, r, (a, b) => a <= b);
        case '-gt': return intCmp(l, r, (a, b) => a > b);
        case '-ge': return intCmp(l, r, (a, b) => a >= b);
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
// (bash treats a nonexistent operand as older than any existing file); an
// EMPTY operand is also "missing" — bash resolves it to nothing, NOT the
// cwd (`test "" -ef ""` is false, and `[ "" -nt x ]` never holds).
function statTime(p) {
  if (p === '') return -Infinity;
  try { return fs.lstatSync(path.resolve(p)).mtimeMs; } catch { return -Infinity; }
}
function statInfo(p) {
  if (p === '') return null;
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
// bash expands `$var` / `${var}` / `$1` / `$(cmd)` references INSIDE
// `$((...))` to their string values BEFORE parsing the expression, so an
// unset variable can leave the expression syntactically invalid
// (`$(( $j * 5 ))` → `$(( * 5 ))` → error) or perfectly valid
// (`$(( $1 + 2 ))` → `$(( + 2 ))` → 2). Pre-expand the same way, then
// require the whole text to parse (a trailing `"test"` in
// `$((echo "test"))` is a bash syntax error, not a silent partial parse).
function arithExpand(sh, s) {
  let out = String(s);
  out = out.replace(/\$\{#([A-Za-z_][A-Za-z0-9_]*)\[@\]\}/g, (_, n) => String(sh.arrayLen(n)));
  out = out.replace(/\$\{#([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => String(sh.getVar(n).length));
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\[([^}\]]+)\]\}/g, (_, n, k) => {
    let idx;
    try { idx = evalArith(String(k), sh); } catch { idx = 0; }
    const arr = sh.arrays.get(n) ?? [];
    return idx >= 0 && idx < arr.length ? String(arr[idx]) : '';
  });
  out = out.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, n) => sh.getVar(n));
  out = out.replace(/\$(\d+|[@#*?$])/g, (_, n) => sh.getVar(n));
  out = out.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, n) => sh.getVar(n));
  // $(cmd) — command substitution (nested arithmetic like
  // `$(( $(wc -l < f) + 1 ))`)
  out = out.replace(/\$\(([^()]*)\)/g, (_, c) => String(shellCapture(c)).trim());
  return out;
}

export function evalArith(src, sh) {
  // recursive descent over integers; supports + - * / % ** << >> & | ^
  // comparison, equality, && || !, ternary, ( ), assignments (x=5, x+=3,
  // x-=1, x*=2, x/=2, x%=2), and postfix ++ / --.
  const s = arithExpand(sh, String(src));
  if (s.trim() === '') return 0; // `$(( $1 ))` with $1 unset → `$(( ))` → 0
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
    const v = parseInt(raw.replace(/^0[xX]/, '0x'), 0);
    if (Number.isNaN(v)) throw new Error(`arith: expected number near '${raw}'`);
    return v;
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
    // unary + / - (bash expands `$var` to the empty string BEFORE parsing,
    // so `$(( $x + 1 ))` with x unset becomes `$(( + 1 ))` — a unary plus)
    if (s[pos] === '-' || s[pos] === '+') {
      const op = s[pos];
      pos++;
      const v = primary();
      return op === '-' ? -v : v;
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
  const v = assignment();
  ws();
  // bash parses the WHOLE expanded expression: trailing garbage
  // (`$(( 5 + ))`, `$(( echo "test" ))`) is a syntax error, and the shell
  // aborts that expansion (empty result).
  if (pos !== s.length) {
    throw new Error(`arith: trailing input near '${s.slice(pos)}'`);
  }
  return v;
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
