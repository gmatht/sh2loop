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

const argv = process.argv.slice(2);
const jsonPath = argv[0];
if (!jsonPath) {
  console.error('usage: estree-runner.mjs <program.estree.json> [--name argv0] [--args ...]');
  process.exit(2);
}
let name = path.basename(jsonPath).replace(/\.estree\.json$/, '');
const positional = [];
for (let i = 1; i < argv.length; i++) {
  if (argv[i] === '--name') name = argv[++i];
  else if (argv[i] === '--args') { positional.push(...argv.slice(i + 1)); break; }
}

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
const moduleSrc =
  `import { sh2 } from ${JSON.stringify(nsPath)};\n` +
  `sh2._init(${JSON.stringify(name)}, ${JSON.stringify(positional)});\n` +
  js +
  `\nawait sh2._finish();\n`;

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'estree-run-'));
const modFile = path.join(tmpDir, 'prog.mjs');
fs.writeFileSync(modFile, moduleSrc);

try {
  execFileSync(process.execPath, [modFile], { stdio: 'inherit' });
} catch (e) {
  process.exit(e.status ?? 1);
} finally {
  fs.rmSync(tmpDir, { recursive: true, force: true });
}
