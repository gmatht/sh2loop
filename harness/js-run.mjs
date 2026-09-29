// js-run.mjs — execute `--target js` output the way the reference executor
// runs the printed program (estree-runner.mjs).
//
// `--target js` emits a JS *fragment*, not a standalone script: it references
// the `sh2` runtime namespace (sh2.builtin / sh2.functions.set / sh2.lastExit
// / sh2.exec / …) but carries no import — see the header of estree-gen.mjs
// ("Output is used only as an intermediate: the reference executor runs it
// under node with the `sh2` namespace global") and the `--library` path,
// which is the only mode that prepends the import. Running the fragment with
// a bare `node rendered.js` throws `ReferenceError: sh2 is not defined`
// before any output, which reads as a phantom "backend can't render" failure
// in cross-product triage.
//
// This runner wraps the fragment exactly as estree-runner.mjs does: import
// the sh2 namespace, `_init`/`_setAllowlist`/[`_setLang`], the fragment, then
// `_finish()`.
//
// Usage: node js-run.mjs <rendered.js> [--source <src file>]

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { BUILTIN_NAMES } from './sh2-namespace.mjs';

const argv = process.argv.slice(2);
const jsPath = argv[0];
if (!jsPath) {
  console.error('usage: js-run.mjs <rendered.js> [--source <src file>]');
  process.exit(2);
}
let sourceFile = null;
for (let i = 1; i < argv.length; i++) {
  if (argv[i] === '--source') sourceFile = argv[++i];
}

let js;
try {
  js = fs.readFileSync(jsPath, 'utf8');
} catch (e) {
  console.error(`js-run: cannot read ${jsPath}: ${e.message}`);
  process.exit(2);
}

// `$0` mirrors the reference runner: the source path when known, else the
// fragment's basename.
const name = sourceFile || path.basename(jsPath);

// Security allowlist — identical construction to estree-runner.mjs: every
// WORD token in the source, minus shell builtins. External binaries the
// program spawns must appear in the source text; without a source there is
// nothing to allow.
const builtins = new Set(BUILTIN_NAMES);
let allowlist = [];
if (sourceFile) {
  try {
    const src = fs.readFileSync(sourceFile, 'utf8');
    allowlist = [...new Set(
      src.split(/[^A-Za-z0-9_.+@\/:.-]+/).filter(w => w.length > 0 && !builtins.has(w)),
    )];
  } catch { /* fall through to the empty allowlist */ }
}

const nsPath = path.join(import.meta.dirname, 'sh2-namespace.mjs');
const moduleSrc =
  `import { sh2 } from ${JSON.stringify(nsPath)};\n` +
  `sh2._init(${JSON.stringify(name)}, []);\n` +
  `sh2._setAllowlist(${JSON.stringify(allowlist)});\n` +
  (sourceFile && /\.zsh$/.test(sourceFile)
    ? `sh2._setLang("zsh");\n`
    : '') +
  js +
  `\nawait sh2._finish();\n`;

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sh2js-run-'));
const modFile = path.join(tmpDir, 'prog.mjs');
fs.writeFileSync(modFile, moduleSrc);

try {
  execFileSync(process.execPath, [modFile], { stdio: 'inherit' });
} catch (e) {
  process.exit(e.status ?? 1);
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
