# sh2loop — Workspace Agent Guide

Dev workspace for the sh2perl transpiler ecosystem. **The plan is the
authority: read PLAN.md first** (architecture, milestones, decisions,
revision history).

## Layout & dependency rule (one-way)

- `sh2perl/` — **submodule** (`git@github.com:gmatht/sh2perl.git`). The
  workspace modifies it (the harness drives debashc, blesses examples) and
  bumps the gitlink. **sh2perl must never reference or write into this
  workspace** — its CI is self-contained.
- `sh2runtime/` — **not a submodule**. Separate repo; coupled only via the
  ESTree-JSON contract (PLAN.md §1). Pinned by commit SHA in CI when needed.
- Test harness: `fail` (Perl corpus gate), `check_qx.pl`, `main_loop_rust.pl`,
  `fail-coreutils` (workspace-side regression corpus); planned: `fail-estree`,
  `harness/estree-runner.mjs` (reference executor).
- `harness/check_ast.pl` — AST-structure regression tests (pins parser gaps
  like `echo x $$` vs `echo x$$` distinguishability; KNOWN AST LIMITATION
  lines are tracked parser gaps, not blessed regressions).

## Common commands

- `cd sh2perl && cargo build --bin debashc`
- `./fail` — full corpus gate (517 examples; generated Perl vs bash stdout)
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
