#!/usr/bin/env node
// genjs.mjs — print the generated JS for a corpus test (debashc --estree → estree-gen)
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const debashc = '/home/llm/sh2loop/sh2perl/target/debug/debashc';
const f = process.argv[2];
const json = JSON.parse(execFileSync(debashc, ['file', '--estree', f], { cwd: '/home/llm/sh2loop/sh2perl', stdio: ['ignore', 'pipe', 'ignore'] }).toString());
const { generate } = await import('/home/llm/sh2loop/harness/estree-gen.mjs');
console.log(generate(json));
