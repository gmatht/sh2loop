# The golden render record (`sh2golden`)

The behaviour gates compare what a transpiled program *prints*, so a lowering
can change every render it touches and still pass — and "which `sh2perl` made
this render?" has no answer once the worktree has moved on. This is the record
that answers both: the rendered text of the corpus, per backend, stamped with
the exact renderer identity that produced it.

It is **not needed to compile or run anything**. No gate, build or CI job
depends on it: a gate must never need a second clone.

## Shape: a standalone repo, not a submodule

- A submodule exists so a consumer can check out a pinned commit and *build
  against it*. Nothing builds against rendered text; the workflow is
  regenerate → `git diff` → review → commit. A gitlink would only add a
  pointer bump per render — and this superproject already has three
  `.gitmodules`-less gitlinks (`s2p.c`, `s2p.rust`, `s2p_go`) that make
  `git submodule status` fail outright.
- `sh2perl` must never reference this record (PLAN §1.1), and `examples/`
  lives inside the `sh2perl` submodule, so nesting is ruled out as well.
- Where it lives: `$SH2_GOLDEN_REPO`, default `.golden-inbox/` in the
  workspace (ignored, machine state). Promote to `gmatht/sh2golden` as a
  sibling clone once the format settles; `sets/` keeps the same layout, so no
  history is rewritten. If a comparison later needs a fixed point, pin it by
  commit SHA in CI — the `sh2runtime` pattern (AGENTS.md:14-15, PLAN §1.2).

## What a set is

One directory per render round: `sets/<utc-stamp>-<sh2perl-sha7>-<backend>/`

| file | meaning |
|---|---|
| `render.json` | the stamp (below) |
| `MANIFEST.tsv` | `name <TAB> sha256 <TAB> bytes <TAB> status` |
| `renders/<example>.<ext>` | status `rendered` |
| `renders/<example>.<ext>.refused` | status `refused`; the first diagnostic line |
| `renders/<example>.<ext>.error` | status `error`; the first stderr line |
| `patches/tracked.patch` | only when the renderer's worktree had tracked changes |
| `determinism.diff` | only when two renders of the same input disagreed |
| `INDEX.tsv` (record root) | append-once row per set: backend, sh2perl sha, corpus sha, counts — answers "which version" without opening a set |

`render.json` records, because the version string cannot (`CARGO_PKG_VERSION`
is a hard-coded `0.1.0` in both crates):

- `renderer` — `kind` (`shir_render` or `cli`), `path`, `sha256` of the
  binary, its mtime;
- the workspace's `sha`/`branch`/`dirty`, and the same for the backend
  worktree (`sh2perl_worktree_*`), plus `ahead`/`behind` against `main` —
  worktrees are routinely hundreds of commits behind, and each carries its own
  `examples/` snapshot;
- `corpus` — directory, the sha256 of every input actually read (so a render
  made from an edited example is detected), and the `HEAD:examples` tree hash;
- `counts` and `unstable`.

A worktree with tracked changes is the normal case mid-fix: the patch beside
the stamp makes the render reproducible from `sh2perl@<sha> + tracked.patch`
after the worktree moves on. (`dirty` counts tracked changes only — untracked
scratch, pid files and caches do not change what the compiler emits, and
counting them would mark every worktree dirty forever.)

## Tools

```
harness/golden-render.sh --backend rust              # one set
harness/golden-render.sh --all --jobs 8              # every backend with a renderer
harness/golden-render.sh --backend c --limit 20      # smoke run
harness/golden-diff.sh <setA> <setB>                 # summary (rc 1 if any differ)
harness/golden-diff.sh <setA> <setB> --list|--stat   # per-example detail
harness/golden-diff.sh <setA> --grep 'sh2\.bigint'   # which examples contain it
harness/golden-diff.sh --latest rust                 # the newest set for a backend
```

`golden-diff.sh` refuses to pretend: it prints both worktrees' distance from
`main` and warns when the two sides are not like-for-like or were rendered
from different `sh2perl` commits, and it flags an `unstable` set.

## Renderer choice

Per backend, `backends/<lang>/target/debug/shir_render --target=<lang>` when
that bin exists (what the gates use), else `otranspilerl-cli <example>
--target <lang>`; the stamp records which, because the two are not guaranteed
to agree and several worktrees still lack `shir_render`.

## Determinism and hygiene

- Every render is done twice; non-identical outputs are a transpiler bug (an
  embedded tmp path, a timestamp) and mark the set `unstable`.
- Re-rendering with an unchanged binary must leave the record clean. That
  clean tree is the acceptance test.
- Per-file cap 1 MiB (larger renders become `oversize`, not committed) and
  `golden-render.sh` never stages: text only, one commit per backend per
  round, and the record gets its own pre-commit guard.
