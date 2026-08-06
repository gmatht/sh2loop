#!/usr/bin/env node
// estree-print.mjs — print the sh2perl ESTree JSON (stdin) as JS text.
// Usage: debashc file --estree x.sh | node harness/estree-print.mjs
import { generate } from './estree-gen.mjs';
import fs from 'fs';
const program = JSON.parse(fs.readFileSync(0, 'utf8'));
process.stdout.write(generate(program));
