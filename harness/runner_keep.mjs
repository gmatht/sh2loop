// estree-runner.mjs — reference executor entry point (PLAN.md §2.3).
//
// Usage: node estree-runner.mjs <program.estree.json> [--name <argv0>] [--args a b c]
//
// Reads the sh2perl ESTree JSON, prints it to JS via estree-gen.mjs, and runs
// it under node with the `sh2` namespace imported. The program's stdout goes
// to this runner's stdout (inherit), so the harness captures it directly.
// Exits nonzero on runtime errors / failed `exit` builtin / timeouts.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { generate } from './estree-gen.mjs';
import { BUILTIN_NAMES } from './sh2-namespace.mjs';

const argv = process.argv.slice(2);
const jsonPath = argv[0];
if (!jsonPath) {
  console.error('usage: estree-runner.mjs <program.estree.json> [--name argv0] [--args ...]');
  process.exit(2);
}
let name = null;
let sourceFile = null;
const positional = [];
for (let i = 1; i < argv.length; i++) {
  if (argv[i] === '--name') name = argv[++i];
  else if (argv[i] === '--source') sourceFile = argv[++i];
  else if (argv[i] === '--args') { positional.push(...argv.slice(i + 1)); break; }
}
// `$0` must match what bash sees (`bash /full/path/test.sh` → $0 = the full
// path of the .sh). The harness passes --source; default the program name
// to that exact string so `$0`-based output (usage lines, ${0##*/}, ${0#/})
// agrees with bash.
if (!name && sourceFile) name = sourceFile;
if (!name) name = path.basename(jsonPath).replace(/\.estree\.json$/, '');

let program;
try {
  program = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
} catch (e) {
  console.error(`estree-runner: cannot read/parse ${jsonPath}: ${e.message}`);
  process.exit(2);
}

let js;
try {
  js = generate(program);
} catch (e) {
  console.error(`estree-runner: printer error: ${e.message}`);
  process.exit(2);
}

const nsPath = path.join(import.meta.dirname, 'sh2-namespace.mjs');

// Security allowlist (trivial, conservative): every WORD token in the source
// .sh, minus shell builtins, plus the always-allowed command wrappers. The generated program may only spawn external
// binaries whose names appear in the source text — an over-approximation
// (variables/args/comment words are included, which is harmless) that can
// never miss a real command. A transpiler bug or tampered JSON invoking a
// command the source never mentions is rejected by the runtime gate.
// Centralized: the runtime's implemented builtins (never spawn). Shell
// keywords (if/then/while/…) are lowered to control flow by the transpiler,
// so they never appear as exec names either.
const builtins = new Set(BUILTIN_NAMES);
let allowlist = null;
if (sourceFile) {
  try {
    const src = fs.readFileSync(sourceFile, 'utf8');
    // Keep `/` (and `:`) as word chars so path-style command names
    // (`/bin/echo`) and `a:b` words survive tokenization as single tokens.
    allowlist = [...new Set(
      src.split(/[^A-Za-z0-9_.+@\/:.-]+/).filter(w => w.length > 0 && !builtins.has(w)),
    )];
  } catch { /* fall through to JSON-derived below */ }
}
if (!allowlist) {
  // Strict: no --source → empty allowlist. External binaries are only ever
  // allowed when their name is a word token in the source .sh; without the
  // source there is nothing to allow.
  allowlist = [];
}

const moduleSrc =
  `import { sh2 } from ${JSON.stringify(nsPath)};\n` +
  `sh2._init(${JSON.stringify(name)}, ${JSON.stringify(positional)});\n` +
  `sh2._setAllowlist(${JSON.stringify([...new Set(allowlist)])});\n` +
  (sourceFile && /\.zsh$/.test(sourceFile)
    ? `sh2._setLang("zsh");\n`  // zsh arrays are 1-based; see sh2-namespace.mjs _setLang
    : '') +
  js +
  `\nawait sh2._finish();\n`;

// Scratch dir for prog.mjs — under os.tmpdir(), NOT in the workspace:
// the corpus compares against `bash` runs from the workspace root, and
// tests that walk the tree (`find . -name "*.sh"` in
// 000__07_find_path_commands.sh) would see the scratch dir; worse, its
// create/remove churn REORDERS the directory's readdir layout (ext4
// htree), so the estree walk and the later bash reference walk the same
// dir in a different order and the stdout comparison fails even though
// no harness file was touched. /tmp is not listed by any corpus test
// (only specific files are written there). The program's cwd is the
// inherited workspace root regardless (no cwd option below).
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sh2estree-run-'));
const modFile = path.join(tmpDir, 'prog.mjs');
fs.writeFileSync(modFile, moduleSrc);

try {
  execFileSync(process.execPath, [modFile], { stdio: 'inherit' });
} catch (e) {
  process.exit(e.status ?? 1);
} finally {
  console.error("KEPT:", tmpDir);
}
