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
- Test harness: `fail` (Perl corpus gate), `check_qx.pl`,
  `fail-coreutils` (workspace-side regression corpus); planned: `fail-estree`,
  `harness/estree-runner.mjs` (reference executor).
- **Model rotation (see `harness/MODEL_ROTATION.md`).** Four workers run on two
  models in two fixed groups and swap every 4 hours: rust+c = group A,
  perl+estree = group B, Space Bunny Alpha vs Laguna. Core is LLM-free and is
  never assigned a model. The model is a **command-line argument**
  (`cmd --model <exact-id>`); the only persistent state is one epoch timestamp
  in the ignored `.worker-model/`. Swaps happen at **invocation boundaries** —
  a running call finishes on its original model and no worker is signalled,
  restarted, or killed. Compare models on *normalized* gate progress per hour
  and per token via `./progress.sh`; the ranking is withheld until every worker
  has a measured interval under both models. When Laguna hits OpenRouter's
  exact `free-models-per-day` quota, the worker script retries the same prompt
  on `ollama-cloud/deepseek-v4.1-flash` (one-way, once; may be metered).
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
- `harness/reap-orphan-examples.sh` — reap corpus examples that outlived
  their runner (`096_head_procsub.sh` and friends). Both gates wrap their own
  runs in `harness/kill-session.sh` and leave 0 behind, but an AI agent
  running an example ad-hoc to debug it is not wrapped, and a model's
  `shell_command` cannot be intercepted. Installed in root's crontab every
  10 min, logging to `loop-orphan-reap.log`; `--dry-run` lists candidates.
  **If that crontab entry is missing after a rebuild, reinstall it** —
  it is machine state, not in git:

  ```
  */10 * * * * /home/llm/sh2loop/harness/reap-orphan-examples.sh >/dev/null 2>>/home/llm/sh2loop/loop-orphan-reap.log
  ```

  The pids matter: the documented failure of an unbounded corpus example is
  pids.max (1024) exhaustion, after which every gate reports ~551/555
  failures with "Can't fork" — which reads as a catastrophic code
  regression and is not one.
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
