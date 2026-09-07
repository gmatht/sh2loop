---
name: sh2dev
description: Build, test, and verify the sh2perl workspace (Perl + ESTree backends, submodule hygiene).
---

# sh2dev — sh2perl development workflow

Run from the workspace root (`/nvme/ai/sh2loop`).

## Build

- `cd sh2perl && cd otranspilerl && cargo build --bin otranspilerl-cli`

## Test

- Full corpus: `./fail` — Perl backend vs bash (517 examples).
- Subset: `./fail <prefix>` (filename prefix filter).
- Unit: `cd sh2perl && cargo test`.

## Verify a change

1. Build.
2. Run the relevant corpus subset (or full `./fail`).
3. If tests regressed, check `git stash list` for reverted experiments before
   assuming the change is wrong.
4. Never "fix" a failing test by blessing a regression.

## Submodule hygiene

- Commit inside `sh2perl` first, then `git add sh2perl` in the workspace to
  bump the gitlink (separate workspace commit).
- Never `git add .` — scratch files accumulate; stage explicit paths.
- `.last_trusted_count` / `.max_tests_passed` are per-run state files — don't
  commit them.

## ESTree backend (planned)

- `otranspilerl-cli --target estree` should emit standard ESTree JSON with shell semantics
  lowered to a `sh2.*` runtime namespace (see PLAN.md §1/§2).
- Reference executor: `harness/estree-runner.mjs` (@babel/generator + node
  `sh2.*` namespace over `node:fs/promises` + `child_process`).
- Gate stages: A parallel metric → B per-test with blessed-fail allowlist →
  C hard gate.
