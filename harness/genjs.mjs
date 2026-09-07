#!/usr/bin/env node
// genjs.mjs — print the generated JS for a corpus test (otranspilerl-cli --target estree → estree-gen)
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const otranspilerl-cli = '/home/llm/sh2loop/sh2perl/otranspilerl/target/debug/otranspilerl-cli';
const f = process.argv[2];
const json = JSON.parse(execFileSync(otranspilerl-cli, ['file', '--estree', f], { cwd: '/home/llm/sh2loop/sh2perl', stdio: ['ignore', 'pipe', 'ignore'] }).toString());
const { generate } = await import('/home/llm/sh2loop/harness/estree-gen.mjs');
console.log(generate(json));
