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
- Test harness: `fail` (Perl corpus gate), `check_qx.pl`, `main_loop_rust.pl`;
  planned: `fail-estree`, `harness/estree-runner.mjs` (reference executor).

## Common commands

- `cd sh2perl && cargo build --bin debashc`
- `./fail` — full corpus gate (517 examples; generated Perl vs bash stdout)
- `./fail <prefix>` — subset by filename prefix
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
