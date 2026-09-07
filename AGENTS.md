# sh2loop — Workspace Agent Guide

Dev workspace for the sh2perl transpiler ecosystem. **The plan is the
authority: read PLAN.md first** (architecture, milestones, decisions,
revision history).

## Layout & dependency rule (one-way)

- `sh2perl/` — **submodule** (`git@github.com:gmatht/sh2perl.git`). The
  workspace modifies it (the harness drives otranspilerl-cli, blesses
  examples) and
  bumps the gitlink. **sh2perl must never reference or write into this
  workspace** — its CI is self-contained.
- `sh2runtime/` — **not a submodule**. Separate repo; coupled only via the
  ESTree-JSON contract (PLAN.md §1). Pinned by commit SHA in CI when needed.
- Test harness: `fail` (Perl corpus gate), `check_qx.pl`, `main_loop_rust.pl`,
  `fail-coreutils` (workspace-side regression corpus); planned: `fail-estree`,
  `harness/estree-runner.mjs` (reference executor).
- `setup_backends.sh` — one git worktree per target backend (`backends/<lang>`
  on `backend/<lang>`, sharing the sh2perl core). Idempotent; `--sync` merges
  main in; `--remove` cleans up. Merge discipline: backend commits push to
  main only when they don't touch the shared core (src/shir.rs, src/ir.rs,
  src/estree.rs, src/parser/); the core stays single-owner during the
  lowering phase. **Transforms (`src/transforms/`, `src/shir_passes/`) are
  NOT single-owner — PLAN §11 marketplace:** a backend implements new
  transforms, fixes/updates existing ones, decides the sharing scope, and
  OFFERS them; other backends accept or reject (per-backend manifest,
  compile-time for transforms, render-time verdict for contract nodes).
  The core's transform role is build CI + bug-fixing the canonical set;
  updates to accepted transforms are offers too, and when all acceptors
  land the new version the old one is pruned (no forks — a modification is
  a new transform).
- `harness/check_ast.pl` — AST-structure regression tests (pins parser gaps
  like `echo x $$` vs `echo x$$` distinguishability). KNOWN AST GAP cases
  COUNT AS FAILURES (exit 1) — never blessed; the count drops only when a
  parser/transform fix lands (case prints RESOLVED, then leaves the list).

## Common commands

- `cd otranspilerl && cargo build --bin otranspilerl-cli` (the CLI; the
  sh2perl core builds via `cd sh2perl && cargo build --lib`)
- `./fail` — full corpus gate (552 examples; generated Perl vs bash stdout)
- The shIR shared library lives at `sh2perl/src/shir_passes/` (PLAN §3,
  design note in `sh2perl/docs/ir-design.md` §"The sh2.* boundary"):
  `PassContext` (analysis verdicts; replaces the ten `static Mutex<…>`
  globals in `shir.rs`), the `Metric` (sh2.* call-site tally, the
  worker's commit signal), and the trait scaffolding for analyses,
  transforms, and pattern lifts. Every backend consumes the same
  pipeline; the only thing that varies is the renderer.
- `./fail <prefix>` — subset by filename prefix
- `./fail-coreutils` — red regression tests from the GNU coreutils suite
  probe (`tests/coreutils/`; each documents a known parser/transpiler gap
  and goes green as the fix lands — never bless them)
- `./tests/coreutils/gate` — objective gate over the full 650-script
  corpus: a test passes only on its own verdict, never vs bash. Current
  rule: "if init.sh doesn't start, the test fails" (source not inlined →
  645 red; 4 parser-broken; 1 execution-verdict crash). See
  `tests/coreutils/README.md`.
- `./tests/coreutils/metric` — coverage metric (parse + ESTree
  unsupported counts) over all 650 scripts
- `git submodule update --init` — after a fresh clone

## Guardrails

- Never `git add .` here either — untracked scratch files abound; stage
  explicit paths.
- To change sh2perl: commit inside the submodule first, then bump the gitlink
  (`git add sh2perl`) in a separate workspace commit.
- When a plan milestone completes, update PLAN.md (status, decisions,
  revision history) in the same effort.
- Never bless a regression: a failing test may only be added to a
  blessed-fail allowlist for a known runtime limitation, never to hide a
  transpiler bug.
