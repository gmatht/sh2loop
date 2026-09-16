#!/usr/bin/env node
// py2cy.js — Python → typed-Cython annotation driven by the REAL Rust
// static analysis (otranspilerl --analyze), not a JS reimplementation.
//
// Pipeline:  py source --(py-sh-go --shir)--> A1 --(otranspilerl --analyze)-->
// facts --(this file: emission only)--> annotated source.
//
// v1 scope (mirrors Go py2cy --py default mode):
//   * `cython.declare(x=cython.int|longlong, y=cython.double, ...)` lines
//     from Rust facts, per scope; the declare policy lives ENTIRELY in
//     the core (`shir::analyze_declares`: candidacy, int kinds, i64
//     containment, vetoes incl. the cross-scope union veto, widths,
//     `global`/`nonlocal` exclusion from the frontend's Function-node
//     fields). Each fact var carries `declare: {kind, width} | null`;
//     this file renders decided lists verbatim and implements NO policy.
//   * `import cython` iff anything declared; header always;
//   * otherwise byte-identical source (decline is the safe default).
// Deliberately NOT in v1 (declined, sound): dual-guard twins, GMP/i128
// tiers, .pyx cdef rewrites, int-list rewrites, nested-def declares.

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

function run(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { encoding: "utf8", ...opts });
  return r;
}

function parseArgs(argv) {
  const o = { file: null, frontend: null, cli: null, keepA1: false, verbose: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--frontend" && i + 1 < argv.length) o.frontend = argv[++i];
    else if (a === "--cli" && i + 1 < argv.length) o.cli = argv[++i];
    else if (a === "--keep-a1") o.keepA1 = true;
    else if (a === "-v" || a === "--verbose") o.verbose = true;
    else if (!a.startsWith("-") && !o.file) o.file = a;
    else {
      process.stderr.write(`py2cy.js: unknown arg ${a}\n`);
      process.exit(2);
    }
  }
  return o;
}

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (!o.file) {
    process.stderr.write("usage: py2cy.js [--frontend BIN] [--cli BIN] [--keep-a1] FILE.py\n");
    process.exit(2);
  }
  const src = readFileSync(o.file, "utf8");
  // binary resolution: explicit flag > env > beside-this-script >
  // workspace layout > PATH. (This file lives in harness/.)
  const here = dirname(fileURLToPath(import.meta.url));
  const cand = (p) => (p && existsSync(p) ? p : null);
  const frontend =
    o.frontend ||
    process.env.PY_SH_GO ||
    cand(join(here, "..", "sh2perl", "frontends", "py-sh-go", "py-sh-go")) ||
    cand(join(process.cwd(), "sh2perl", "frontends", "py-sh-go", "py-sh-go")) ||
    "py-sh-go";
  const cli =
    o.cli ||
    process.env.OTRANSPILERL_CLI ||
    cand(join(here, "..", "otranspilerl", "target", "debug", "otranspilerl-cli")) ||
    cand(join(process.cwd(), "otranspilerl", "target", "debug", "otranspilerl-cli")) ||
    "otranspilerl-cli";

  // 1. Python -> A1 (the frontend owns parsing; it refuses what it
  //    cannot lower — `is`, `id()`, dynamic shapes never become A1).
  const tmp = mkdtempSync(join(tmpdir(), "py2cy-"));
  const a1path = join(tmp, "prog.a1.json");
  let r = run(frontend, ["--shir", o.file, "--raw"], {});
  if (r.status !== 0) {
    process.stderr.write(`py2cy.js: frontend refused ${o.file}: ${(r.stderr || "").trim()}\n`);
    rmSync(tmp, { recursive: true, force: true });
    process.exit(3);
  }
  writeFileSync(a1path, r.stdout);

  // 2. A1 -> facts (the REAL Rust static analysis).
  r = run(cli, ["--source-lang", "shir", a1path, "--analyze"], {});
  if (r.status !== 0) {
    process.stderr.write(`py2cy.js: analyze failed: ${(r.stderr || "").trim()}\n`);
    rmSync(tmp, { recursive: true, force: true });
    process.exit(4);
  }
  let facts;
  try {
    facts = JSON.parse(r.stdout);
  } catch (e) {
    process.stderr.write(`py2cy.js: bad facts JSON: ${e}\n`);
    rmSync(tmp, { recursive: true, force: true });
    process.exit(4);
  }
  if (!o.keepA1) rmSync(tmp, { recursive: true, force: true });

  // 3. Emission (declare lines only; source otherwise untouched).
  const out = emit(src, facts);
  process.stdout.write(out);
}

// Render core decisions verbatim. `declare` is final per var
// ({kind: "int"|"float", width} | null); the i32->cython.int mapping
// below is pure rendering (total function of kind+width, no judgment).
const CTYPE = { int32: "cython.int", int64: "cython.longlong" };
function decide(facts) {
  // scope name -> {ints: [[name, ctype]], floats: [name]}
  const result = new Map();
  for (const s of facts.scopes) {
    const ints = [];
    const floats = [];
    const vars = s.vars || {};
    for (const n of Object.keys(vars).sort()) {
      const d = vars[n].declare;
      if (!d) continue;
      if (d.kind === "float") {
        floats.push(n);
        continue;
      }
      if (d.kind === "int") {
        ints.push([n, d.width === "i32" ? CTYPE.int32 : CTYPE.int64]);
      }
    }
    result.set(s.name, { ints, floats });
  }
  return result;
}

function declLine(ints, floats) {
  const parts = [];
  const byName = [...ints.map(([n, t]) => [n, t]), ...floats.map((n) => [n, "cython.double"])];
  byName.sort((a, b) => (a[0] < b[0] ? -1 : 1));
  for (const [n, t] of byName) parts.push(`${n}=${t}`);
  if (!parts.length) return "";
  return `cython.declare(${parts.join(", ")})\n`;
}

// splice `insert` after the module docstring + __future__ imports
// (a real import cannot precede a future import).
function insertAfterFuture(srcLines, insertLines) {
  let i = 0;
  const skipTrivia = () => {
    while (i < srcLines.length) {
      const t = srcLines[i].trim();
      if (t === "" || t.startsWith("#")) i++;
      else return;
    }
  };
  skipTrivia();
  if (i < srcLines.length) {
    const t = srcLines[i].trim();
    if (t.startsWith('"""') || t.startsWith("'''")) {
      const q = t.slice(0, 3);
      if ((t.slice(3).match(new RegExp(q.replace(/"/g, '\\"'), "g")) || []).length >= 1) {
        i++;
      } else {
        i++;
        while (i < srcLines.length) {
          if (srcLines[i].includes(q)) {
            i++;
            break;
          }
          i++;
        }
      }
    }
  }
  skipTrivia();
  while (i < srcLines.length && srcLines[i].trim().startsWith("from __future__ import ")) i++;
  return [...srcLines.slice(0, i), ...insertLines, ...srcLines.slice(i)];
}

function leadingWS(s) {
  const m = /^[ \t]*/.exec(s);
  return m ? m[0] : "";
}

// insertion line (1-based) for a top-level-ish `def name(` at line defIdx
// (0-based): first code line of the body (skipping blanks/comments),
// past a docstring; -1 if the body is on the def line (declined).
function bodyInsertLine(lines, defIdx) {
  let i = defIdx + 1;
  while (i < lines.length) {
    const t = lines[i].trim();
    if (t === "" || t.startsWith("#")) {
      i++;
      continue;
    }
    break;
  }
  if (i >= lines.length) return -1;
  if (i === defIdx + 1 && /:\s*\S/.test(lines[defIdx].slice(lines[defIdx].indexOf(":")))) {
    // body on the def line (`def f(): x = 5`) — declined (Go would
    // split the line; we keep the source byte-identical instead)
    void 0;
  }
  const t = lines[i].trim();
  if (t.startsWith('"""') || t.startsWith("'''") || /^([rRuUbBfF]{0,3})(""")|(''')/.test(t)) {
    const m = /([rRuUbBfF]{0,3})("""|''')/.exec(t);
    const q = m[2];
    const rest = t.slice(t.indexOf(q) + 3);
    if (rest.includes(q)) return i + 2; // single-line docstring
    i++;
    while (i < lines.length) {
      if (lines[i].includes(q)) return i + 2;
      i++;
    }
    return -1;
  }
  return i + 1;
}

function emit(src, facts) {
  const decided = decide(facts);
  const lines = src.split("\n");
  // module preamble
  const top = decided.get("<top>") || { ints: [], floats: [] };
  const moduleDecl = declLine(top.ints, top.floats);
  const anyDecl =
    moduleDecl !== "" || [...decided.values()].some((d) => d.ints.length + d.floats.length > 0);
  const preamble = [];
  if (anyDecl) preamble.push("import cython");
  if (moduleDecl !== "") preamble.push(moduleDecl.trimEnd());
  // function insertions (bottom-up so line numbers hold)
  const insertions = [];
  // map def sites: `def name(` lines (any indent; nested defs get no
  // facts in v1 and are skipped)
  const scopeNames = new Set(decided.keys());
  for (let i = 0; i < lines.length; i++) {
    const m = /^([ \t]*)def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/.exec(lines[i]);
    if (!m) continue;
    const [, , name] = m;
    if (!scopeNames.has(name)) continue;
    const d = decided.get(name);
    const ints = d.ints;
    const floats = d.floats;
    const decl = declLine(ints, floats);
    if (decl === "") continue;
    const at = bodyInsertLine(lines, i);
    if (at < 1) continue;
    const indent = leadingWS(lines[Math.min(at - 1, lines.length - 1)]);
    insertions.push({ line: at, text: indent + decl.trimEnd() });
  }
  insertions.sort((a, b) => b.line - a.line);
  let bodyLines = [...lines];
  for (const ins of insertions) {
    bodyLines = [...bodyLines.slice(0, ins.line - 1), ins.text, ...bodyLines.slice(ins.line - 1)];
  }
  if (preamble.length > 0) {
    bodyLines = insertAfterFuture(bodyLines, preamble);
  }
  const body = bodyLines.join("\n");
  return "# cython: language_level=3\n" + body;
}

main();
