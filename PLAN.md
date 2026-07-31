# Plan: ESTree-JSON Contract, Test Gate, and a Universal ShIR

Covers three related work items:

1. **Decouple sh2perl and sh2runtime via an ESTree-JSON data contract** — no
   submodules, no code-level coupling. sh2perl emits ESTree JSON; sh2runtime
   consumes it against its virtual FS.
2. Extend sh2perl's test runner so a test only passes when the emitted ESTree,
   executed by the reference executor, passes the corpus vs `bash` (staged
   rollout; sh2runtime validates the same ESTree in its own repo).
3. Evolve toward a **language-neutral ShIR** between the shell AST and the
   per-language IRs (Perl IR, ESTree/JS IR).

> **Revision history**
> - v1: ESTree → JS linked against a bespoke sh2runtime "compiled-script API".
> - v2: target C → wasm32-wasi. Rejected: C needs type inference + runtime lib;
>   WASI has no fork/exec (but see v3 note — fork isn't a semantic need);
>   sh2runtime's in-browser C compiler is unfinished.
> - v3: ESTree → JS; runtime surface = standard node `fs/promises` APIs +
>   one bespoke `exec`/`pipeline` seam; sh2runtime implements the seam over its
>   virtual FS. Fork/exec reframed: bash needs *copy semantics* (env/fd
>   snapshot, streams, exit code), not real processes — emulable everywhere.
> - v4: **the interface is ESTree JSON itself.** sh2perl emits JSON (standard
>   ESTree, shell semantics lowered to calls into a documented `sh2.*` runtime
>   namespace); executors do the rest. No submodule, no shared code.
> - v5 (current): **topology correction.** sh2perl *stays* a properly-registered
>   submodule of sh2loop (the workspace needs to modify it); sh2runtime is NOT a
>   submodule (ESTree JSON decouples it). One-way rule: sh2loop → sh2perl;
>   sh2perl never references sh2loop (e.g. its tracked `fail -> ../fail` symlink
>   must go).

---

## 0. Current state (verified facts)

| Component | State |
|---|---|
| `/nvme/ai/sh2loop` (superproject) | Git repo, branch `master`, **no remotes**; hosts test infra (`fail`, `check_qx.pl`, `main_loop_rust.pl`) |
| `sh2perl` entry in superproject index | gitlink (mode `160000`) at `09f6a4f6`, **no `.gitmodules`** → broken/unofficial submodule |
| `sh2perl` (primary repo) | origin `git@github.com:gmatht/sh2perl.git`, own CI (`.github/workflows/test.yml`); working tree at `febb301`, dirty scratch files; **tracks a `fail -> ../fail` symlink** (violates the one-way rule — must be removed) |
| `sh2runtime` | exists at `gmatht/sh2runtime`; node v22 available; already runs async JS commands + `.js` files in `/commands/` against its virtual FS; WASI via `@wasmer/wasi` for third-party wasm tools |
| sh2perl backends | Perl only. `src/ir.rs` = Perl-specific IR with `RawText` bridges; `pub mod mir` commented out. No ESTree emitter exists. |
| Tests | `fail`: debashc → Perl → `check_qx.pl` gate → run vs `bash` → normalized stdout + side-effect compare. 517 examples, 426 passing. |

Key docs:
- `sh2perl/docs/ir-design.md` — Perl IR + "two-layer IR (future)" (ShIR between AST and language IRs).
- `sh2perl/docs/AST.md` — the shell AST that feeds everything.
- `sh2runtime/docs/architectural-considerations.md` — §3/§5 ESTree as leaf backend; §7 Common ShIR; §9 JS-first backend order.
- `sh2runtime/README.md` — virtual FS + tinysh JS-command model (`.js` files are the "compiled binaries").

---

## 1. Repo topology: sh2perl stays a submodule; sh2runtime does not

### 1.1 The dependency rule (one-way)

- **sh2loop → sh2perl:** the workspace depends on and *modifies* sh2perl (the
  harness drives debashc, blesses examples, bumps the gitlink). sh2perl is a
  **properly registered submodule** of sh2loop.
- **sh2perl → sh2loop: forbidden.** sh2perl must never reference or write into
  the workspace. Concretely: remove the **tracked `fail -> ../fail` symlink**
  from sh2perl (it dangles when sh2perl is cloned standalone); the workspace
  provides its own `fail`. sh2perl's CI stays self-contained (cargo tests).
- **sh2perl ⇄ sh2runtime: no code coupling.** The interface is ESTree JSON
  (1.2); sh2runtime is **not** a submodule. Test-time coupling is by commit SHA
  in CI (1.4).

### 1.2 The contract

- **sh2perl emits standard ESTree JSON** (`debashc --estree file.sh`). No JS
  text, no `@babel/generator` inside sh2perl, no imports into sh2runtime — it's
  a pure data emitter.
- Shell semantics are expressed in the ESTree as calls into a **documented
  `sh2.*` runtime namespace** (the only non-standard part is the *name set*,
  not node types): `sh2.fs.readFile`, `sh2.fs.writeFile`, `sh2.fs.stat`,
  `sh2.exec`, `sh2.pipeline`, `sh2.redirect`, `sh2.capture`, `sh2.exit`,
  `sh2.getVar`/`sh2.setVar`... File tests lower to `try/catch` +
  `sh2.fs.stat`; pipelines lower to `sh2.pipeline([...closures])`; command
  substitution lowers to `await sh2.capture(...)`.
- **The consumer owns the spec.** sh2runtime's repo hosts `docs/estree-api.md`
  defining the namespace (names, signatures, semantics, error codes — node
  `.code` style: `ENOENT`, `EISDIR`). sh2perl targets that doc, pinned by SHA
  in CI (1.4). This is the same "consumer defines the API" pattern as any
  client/server split.

### 1.3 Register sh2perl as a proper submodule (workspace fix)

The gitlink exists but `.gitmodules` is missing — register it (from
`/nvme/ai/sh2loop`):

1. Settle sh2perl's working tree: commit/stash `.last_trusted_count`;
   gitignore or remove scratch files (`__tmp_run_*.pl`, `"$f"`, `001`, ...)
   so the submodule stays clean.
2. Remove the tracked `fail -> ../fail` symlink from sh2perl (commit the
   deletion there).
3. Add `.gitmodules`:
   ```ini
   [submodule "sh2perl"]
       path = sh2perl
       url = git@github.com:gmatht/sh2perl.git
   ```
4. Fast-forward the gitlink to the current HEAD (`febb301`, a descendant of the
   recorded `09f6a4f6`): `git add sh2perl .gitmodules`, commit.
5. `git submodule init`; confirm `git submodule status` clean.

No sh2runtime submodule is created anywhere.

### 1.4 Cross-repo CI pinning (replaces the missing sh2runtime submodule)

- **sh2perl CI** stays self-contained: cargo tests, purify, perl-critic — no
  external checkouts.
- **sh2loop CI** (needs a remote first): checks out the submodule, builds
  debashc, runs `fail` + `fail-estree` (the corpus gate).
- **sh2runtime CI**: checks out `gmatht/sh2perl@<sha>` to pull corpus fixtures
  + expected outputs; validates the ESTree it consumes is exactly what sh2perl
  emits (schema + round-trip), then runs it against the virtual FS.
- Optional once sh2runtime ships its executor: a sh2loop CI job checks out
  `gmatht/sh2runtime@<sha>` and runs the same corpus against the virtual FS.

---

## 2. Test gate: "passes only if the ESTree passes the corpus"

### 2.1 Target semantics

Two executors consume the same ESTree JSON; both must agree with `bash`:

```
test.sh ── debashc ──► Perl ───────► perl <tmp/test.pl> ───────────► stdout ──► vs ──► bash
   │
   └── debashc --estree ──► test.estree.json
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
   Reference executor (sh2perl CI)   sh2runtime executor (their CI/browser)
   ESTree→JS via @babel/generator    ESTree→JS (or direct tree-walk)
   + node fs/promises + child_process + sh2.* → virtual FS + command registry
              │                                │
              ▼                                ▼
          stdout ──► vs ──► bash          stdout ──► vs ──► bash
```

- **sh2loop CI** validates transpiler correctness with the reference executor
  (real node `fs`, real `child_process` — full process semantics, same coverage
  as the Perl backend).
- **sh2runtime repo** validates the browser path against the virtual FS. The
  "only pass if linked against sh2runtime" semantics is satisfied by *both*
  executors agreeing on the same ESTree; sh2perl doesn't block on sh2runtime.

Rollout (do **not** gate on the new backend on day one — it starts at ~0% vs
426/517 Perl):

- **Stage A — parallel metric:** `fail-estree` runner records
  `{file, perl: PASS/FAIL, estree: PASS/FAIL, reasons[]}`; no gating.
- **Stage B — per-test gate:** green only when `perl == PASS && estree ==
  PASS`, with a `blessed-fail-estree.txt` allowlist (existing blessing pattern).
- **Stage C — hard gate:** remove the allowlist. End state.

### 2.2 debashc side: `--estree` output mode

1. New `src/estree.rs`: ESTree node structs with `#[derive(Serialize)]`
   (`Program`, `ExpressionStatement`, `CallExpression`, `TemplateLiteral`,
   `ArrowFunctionExpression`, ...). Emit **standard ESTree only** — all shell
   semantics lowered to `sh2.*` calls (1.1), never custom node types.
2. `shir_to_estree()`: `ShIR → ESTree` lowering per
   `architectural-considerations.md` §5/§9, with targetings:
   - `FileTest` → `try { await sh2.fs.stat(p) } catch (e) { e.code ===
     'ENOENT' }`
   - `Redirect` → `sh2.redirect(fd, mode, target)`
   - `CommandSubstitution` → `await sh2.capture(...)`
   - `Pipeline` → `sh2.pipeline([...])`
   - variables/arith/strings → `sh2.getVar`/`sh2.setVar`/standard literals+ops
3. **Structural gate (deterministic):** validate emitted JSON — (a) against an
   ESTree schema (any standard ESTree validator), (b) every callee is in the
   `sh2.*` whitelist, (c) no `eval`/`Function`/dynamic import, (d) no `*Sync`
   calls (browser can't block — async-only codegen with top-level `await`).
   Replaces `check_qx.pl` for the JS side.
4. **Determinism check:** same input → byte-identical ESTree (mirrors the
   existing example-blessing determinism workflow).

### 2.3 Reference executor (sh2loop's harness)

`harness/estree-runner.mjs` in the sh2loop workspace (alongside `fail` and
`check_qx.pl` — the harness belongs to the workspace, not to sh2perl):
- ESTree JSON → JS text via `@babel/generator` (pinned devDep).
- Provide the `sh2.*` namespace for node: `sh2.fs.*` → `node:fs/promises`,
  `sh2.exec`/`sh2.pipeline`/`sh2.capture` → `child_process`
  (spawnSync/execSync/pipe), `sh2.exit` → `process.exit`, `$?`/`$CHILD_ERROR`
  → tracked exit codes.
- Run under node with a temp cwd; capture stdout; compare vs `bash` with the
  same normalization + side-effect checks as `fail`.
- Doubles as the reference implementation of the `sh2.*` spec — testable in
  the sh2loop harness before sh2runtime ships anything.

### 2.4 sh2runtime side (their repo, out of scope for sh2perl CI)

- Publish `docs/estree-api.md` (the `sh2.*` namespace spec — 1.1).
- Consume ESTree: generate JS via `@babel/generator` (pure JS, fits their
  no-build-step style) or interpret directly; map `sh2.fs.*` → VirtualFS
  (node-compatible names + error `.code` semantics — their ramfs already
  throws `ENOENT: path`, needs the `code` property), `sh2.exec` → command
  registry (`.js` modules in `/commands/`), `sh2.pipeline` → async fd
  streaming, `sh2.capture` → async read.
- **Process model = emulation, not fork** (per v3 analysis): a "process" is
  `{env snapshot, fd table, cwd, args}` → run → streams + exit code → discard.
  Edge cases to handle explicitly: fd-table inheritance (`exec 3>file`),
  `trap`/`kill`/`wait`/`$!`, interleaved background output, synthetic
  `$$`/`$BASHPID`. Genuinely external tools (`ssh`, network) go on the blessed
  list until real wasm binaries exist (their `download-wasm-bins.js` covers
  grep/curl/etc.).
- WASI (`@wasmer/wasi` + wasmfs) stays for *third-party* binaries, not sh2perl
  output. (JS cannot call WASI directly — WASI is a wasm↔host interface and JS
  is the host; the only "JS on WASI" route is a JS engine compiled to
  wasm32-wasi, an optional future unifier.)

### 2.5 Harness changes (sh2loop workspace)

The reference executor and the gate runners live in **sh2loop**, alongside the
existing `fail`/`check_qx.pl` test scripts (sh2loop is the harness; it modifies
sh2perl — never the reverse):

- `fail` gains `--estree` mode (or a sibling `fail-estree`): `debashc
  --estree` → structural gate → `estree-runner.mjs` → compare vs `bash`.
- Stage B: `fail` returns PASS only when both verdicts pass; reasons tagged
  `[perl]` / `[estree]`.
- Parallel workers + timeouts identical to the current `fail`.
- `@babel/generator` is a pinned devDep of the sh2loop harness (or a `harness/`
  package), not of sh2perl.

### 2.6 CI

- **sh2perl CI** (`sh2perl/.github/workflows/test.yml`): unchanged — cargo
  tests, purify, perl-critic. Self-contained; no external checkouts.
- **sh2loop CI** (new workflow; requires adding a remote to the superproject):
  checks out the sh2perl submodule, builds debashc, runs `fail` + `fail-estree`:
  ```yaml
  - uses: actions/checkout@v4
    with: { submodules: true }
  - uses: actions/setup-node@v4
    with: { node-version: 22 }
  - run: cd sh2perl && cargo build --bin debashc
  - run: ./fail                       # Perl baseline
  - run: ./fail-estree                # ESTree metric / gate
  ```
- Optional once sh2runtime ships: a job checking out `gmatht/sh2runtime@<sha>`
  and running the corpus against the virtual FS.

Badges mirror the existing perlcritic/purify pattern, adding `estree-tests`.

---

## 3. Universal IR: yes — evolve toward ShIR (not a third parallel IR)

### Recommendation

**Yes, move toward a language-neutral ShIR**, but by *generalizing the existing
`src/ir.rs`*, not by inventing a fresh IR alongside Perl-IR and the ESTree
emitter. Both existing docs already commit to this shape:

- `docs/ir-design.md` ("Two-layer IR (future)"): `Shell AST → ShIR → {Perl IR,
  Rust IR, ...}`.
- `sh2runtime/docs/architectural-considerations.md` §7/§9: Common ShIR with
  `Exec`, `Pipeline`, `If`, `Assign`, `Declare`, `Redirect`, `Read`, `Write`,
  abstract `FileTest`, no sigils, no per-language error handling.

With ESTree as the second consumer, the IR now feeds **two dynamically typed
backends** (Perl text, ESTree JSON) — no type inference pass needed (stays
parked until a statically-typed backend lands, per docs §8).

`src/ir.rs` is already ~80% language-neutral (`Output`, `Assign`, `Declare`,
`If`, `While`, `For`, `Pipeline`, `Return`). What is Perl-specific:

| Current (Perl IR) | ShIR change |
|---|---|
| `Sigil` on `Var`/`Decl` | drop from core; backends re-add (`VarSigil` optional annotation) |
| `StrStyle::{SingleQuoted, DoubleQuoted, Command, Heredoc}` | core = `{Literal, DoubleQuoted, Verbatim}`; `Command`/`Heredoc` become Perl-backend extensions (JS uses template literals) |
| `System { cmd, capture }` | `Exec { cmd, args, redirects, capture }` (language-agnostic) |
| `Index { var, key }`, `BinOp`, `Ternary`, `Call` | keep as-is (already neutral) |
| `RawText`/`RawExpr` | keep — explicitly designed as the migration bridge; it is *not* a defect |

### Sequencing

1. **Refactor-first:** generalize `ir.rs` → language-neutral ShIR. Perl backend
   becomes one consumer: `shir_to_perl()` (renamed `ir_to_perl`). All 517 Perl
   tests must stay green — pure refactor with `RawText` untouched.
2. **Add the second consumer:** `shir_to_estree()` + the reference executor
   (sections 1–2). The IR is only trustworthy once two backends consume it; do
   not build shared optimization passes before this.
3. **Shared passes (only after both backends exist):** constant folding, dead
   assignment elimination, unified import/require registry (replacing ad-hoc
   `needs_*()` booleans).
4. **ESTree stays a leaf backend** — a data emitter for JS consumers; never the
   universal IR (no ESTree→Perl/Rust/Python codegen exists).

### Open questions

- Separate `shir-rs` crate for future frontends (Batch/POSIX)? (Recommend: no,
  until a second frontend is real.)
- Does `--estree` belong in the `debashc` binary or a separate
  `debashc-estree` bin? (Recommend: same binary, `--estree` flag, so CI and
  users share one build.)

---

## 4. Milestones (dependency order)

1. **M1 — Register the sh2perl submodule:** settle sh2perl's working tree
   (gitignore/remove scratch files), **remove the tracked `fail -> ../fail`
   symlink from sh2perl**, add `.gitmodules`, fast-forward the gitlink to the
   current HEAD, `git submodule init`. No sh2runtime submodule — the ESTree
   JSON contract decouples it.
2. **M2 — Agent context (see §6):** `AGENTS.md` (sh2perl primary + workspace
   root pointer), `.pi/skills/sh2dev`, `.pi/prompts/` — future sessions inherit
   plan, status, conventions, guardrails.
3. **M3 — IR generalization (pure refactor):** `ir.rs` → language-neutral ShIR;
   Perl backend unchanged; 517 tests still pass; `RawText` intact.
4. **M4 — ESTree emitter + reference executor:** `shir_to_estree()` +
   `debashc --estree`; `tests/estree-runner.mjs` (@babel/generator + node
   `sh2.*` namespace); structural gate (schema + callee whitelist + no `*Sync`);
   `fail-estree`. Stage A: parallel metric, zero gating.
5. **M5 — Gate:** per-test `perl && estree` verdicts with blessed-fail
   allowlist (Stage B), then hard gate (Stage C). CI badges.
6. **M6 — Shared passes:** constant folding / dead-code / import registry on
   ShIR once two backends are stable.
7. **M7 — sh2runtime consumes ESTree (their repo):** `docs/estree-api.md`
   spec, `sh2.*` → VirtualFS + command registry, run sh2perl corpus fixtures
   (pinned by SHA) against the virtual FS. Optional follow-on: engine-on-WASI
   (quickjs.wasm) as a unifying runtime layer.

---

## 5. Risks

- **Contract (format) drift:** the ESTree shape + `sh2.*` namespace must match
  between sh2perl and sh2runtime. Mitigate: consumer-owned spec doc; schema +
  whitelist validated on both sides; shared corpus fixtures; round-trip test in
  sh2runtime CI.
- **Sync vs async:** generated ESTree lowers to async-only code (`await`,
  top-level await, ESM). Enforce in the structural gate (reject `*Sync`
  callees). tinysh already runs async commands (`await fs.read(...)`).
- **Error semantics:** executors must throw node-compatible errors (`.code` =
  `ENOENT`/`EISDIR`/...) or `[ -f x ]` / `|| die`-style checks diverge between
  node CI and the browser. Their ramfs needs the `code` property added.
- **Reference executor ≠ sh2runtime:** node-CI and browser could disagree.
  Mitigate: the reference executor is the spec's reference implementation;
  shared fixtures; sh2runtime CI runs the same corpus.
- **Builtin/exec table is the real work:** `echo`, `ls`, `grep`, ... for the
  browser path (same logic the Perl backend encodes; tinysh's builtin object is
  the seed; ~30 builtins cover the corpus). Node CI side is free
  (`child_process`).
- **New backend starts at ~0%:** staged rollout + blessed-fail allowlist keeps
  CI honest.
- **Semantic drift between backends:** Perl and ESTree must match the *same
  normalized stdout contract*, not each other's output byte-for-byte.
- **IR refactor churn:** 90/517 failing Perl tests + stashed regressions — the
  refactor must be strictly output-preserving; keep `RawText` until proven.
- **`@babel/generator` dependency:** pinned devDep in sh2perl (reference
  executor) and sh2runtime (their executor).

---

## 6. Agent (pi) context — so future sessions know what's going on

A fresh pi session auto-loads only `AGENTS.md`/`CLAUDE.md` (global
`~/.pi/agent/AGENTS.md`, then parent dirs walking up from cwd, then cwd). It
will **not** read `PLAN.md` or `sh2perl/.cursorrules` (pi doesn't read Cursor
files). Today no `AGENTS.md`, `.pi/`, skill, or prompt template exists — every
session starts cold. This is a multi-session, multi-repo effort, so agent
context is part of M2.

Deliverables (primary at the sh2loop workspace root; sh2perl stays standalone):

1. **`/nvme/ai/sh2loop/AGENTS.md`** (workspace root — the primary doc for
   sessions working across the repos): the **one-way dependency rule** (sh2loop
   → sh2perl; sh2perl never references sh2loop), the submodule layout, "read
   PLAN.md first", current status (517 examples / 426 passing / gate stages
   A→C), harness commands (`./fail`, `./fail-estree`), and the guardrails
   (output-preserving refactors only, never bless a regression, check `git
   stash list`, never `git add .` — the tree is full of scratch files).
2. **`sh2perl/AGENTS.md`** (standalone — **no sh2loop paths or references**):
   build/test commands (`cargo build --bin debashc`, `cargo test`), IR
   migration status (`src/ir.rs` → ShIR, `RawText` policy), `check_qx.pl` gate
   (external, invoked from the workspace), where the ESTree emitter lands
   (`src/estree.rs`), the `sh2.*` namespace contract.
3. **Skill** `.pi/skills/sh2dev/SKILL.md` (agentskills format): build → test →
   verify workflow (`cargo build`, `./fail`, `./fail-estree`, ESTree structural
   gate, submodule-free layout), loaded on demand.
4. **Prompt templates** `.pi/prompts/*.md` (optional): `/run-tests`,
   `/add-example`, `/bless-estree` (curate the allowlist).
5. **Migrate `.cursorrules`** still-relevant points into `AGENTS.md` so the
   knowledge isn't orphaned.
6. **sh2runtime side (their repo):** `docs/estree-api.md` referenced from a
   future `sh2runtime/AGENTS.md`.

---

## 7. Execution log

- **2026-07-31 — M1 done.** sh2perl registered as a proper submodule
  (`.gitmodules` + gitlink → `d18a506`); `fail -> ../fail` symlink removed from
  sh2perl (one-way rule); 65 tracked scratch artifacts removed + `.gitignore`
  patterns added; working-tree generator WIP (words.rs, pipeline_commands.rs,
  ir.rs, mod.rs, redirects.rs) committed as-is (compiles; full corpus 430/517
  passed, matching last committed baseline — no regressions).
- **2026-07-31 — M2 done.** `AGENTS.md` (workspace + standalone sh2perl),
  `.pi/skills/sh2dev`, `.pi/prompts/{run-tests,bless-estree}.md`.
- **Caveat:** a background `main_loop_rust.pl` is actively committing/editing
  sh2perl sources (repo moved febb301 → aa5df7a during M1). The gitlink will
  need re-bumping after that loop settles.
