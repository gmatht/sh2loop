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

## Box-health guards (the WSL page-cache/writeback wedge)

The box's failure mode is a **page-cache and writeback wedge**, not a CPU or
RAM shortage. History: 1.4 TB written cumulatively, io PSI 93–99%, loadavg
109 with 3 runnable, 58 of 75 D-state tasks in `__lock_buffer`, and
`init.scope/memory.peak` 47.07 GB of 47 GB total. The transpiler looked
broken during it; it was never a transpiler problem.

**This box is cgroup v2 only.** `stat -fc %T /sys/fs/cgroup` → `cgroup2fs`.
There is no v1 hierarchy to fall back to, and three commonly-cited remedies
do not apply:

- **There is no per-cgroup async-writeback control.** v2's real advantage
  over v1 is *proactive reclaim* (`memory.high`/`low`/`min`/`reclaim`, plus
  `full` accounting in `memory.pressure`, which v1 pressure lacked). That
  is the whole win, and it is the one that matters here.
- **`memory.force_empty` is the wrong tool.** It only works on a cgroup with
  NO processes in it, so it can never touch `init.scope`. The interface you
  want is **`memory.reclaim`**, which is what `cgroup-memory-manager` shells
  out to — and it works here directly, no dependency.
- **`memory.reclaim` returning EAGAIN is not an error.** It means "freed
  what I could, short of the ask". Measured: 1 byte and 1 KiB succeed, 64
  KiB fails on a cgroup holding 2 MB. Treating EAGAIN as failure makes a
  janitor a no-op on the box it was written for.

What is installed, and why each piece:

- `io.max` — `sh2-io-max.service` (`sh2-io.slice`), `sh2-contain.service`
  (the `init.scope` backstop), `sh2-system-slice-cap.service` (the
  `system.slice` backstop, added 2026-09-30 — it was the last unbounded
  population with real work in it: 164 children, 3.3 GB, including `cron`).
  **This is a CEILING, not a control that is continuously engaged.** It sits
  at 32 MB/s against a device whose measured single-stream ceiling is
  70–90 MB/s, so at the current 6 MiB/s it correctly never fires:
  `nr_throttled=0` in every capped cgroup is the *expected* reading, not a
  sign the cap is broken. (An earlier 200 MB/s cap sat above the achievable
  rate and was decoration; that is the failure mode to avoid, not this.)
  It throttles IO, *not* cache. Authority on the whole installed stack:
  `/usr/share/doc/wsl-io-throttle/README.md`.
- `memory.high` + `memory.reclaim` — `sh2-memory-reclaim.sh`, applied by
  `sh2-memory-reclaim.service` (boot-time oneshot) and reclaimed by
  `sh2-memory-reclaim-loop.timer` every 60s. Per-cgroup, and the values are
  **built-in defaults, not just env-overridable**: `init.scope` **32G**
  (raised from 24G on 2026-09-30 — at 24G it sat *at* its ~21G working set
  rather than above it and produced +413 `high` crossings per 30s on an
  idle box; now 0), `sh2workers` 8G and `sh2gates` 9G (98% of what they hold is reclaimable
  cache, so an active ceiling is right). `memory.high` alone would put every
  task to sleep in direct reclaim, and on WSL that runs in-kernel against the
  same saturated device — cache growth becomes a throughput stall.
  Effect: Cached 34.9G→15.1G, init.scope 28.9→11.7G, io PSI avg10 24.3%→1.3%,
  D-state 28→0, zero `oom_kill`.
- `pids.max` on `init.scope` = 8192, same boot-time oneshot. It was 57795
  (effectively unbounded). See the `reap-orphan-examples.sh` note above for
  the failure this prevents; 8192 is ~17x observed steady state and far
  above the 479 orphans that actually broke `sh2gates`.
- `sh2-scratch-sweep.sh` (6-hourly) — bounds the *accumulation* across runs.
  `/usr/lib/sh2-tmp-sweep` only removes `tmp.*` trees older than 3 days,
  which never matches `tmp_run/perl-gen-diffs/` or `tmp_run/pg/` — the two
  dirs that actually grew without bound. Skips any dir held by a live
  process.
- **Byte caps in the gates** — `harness/cap-capture.pl`, wired into `fail`,
  `fail-estree` and `harness/perl_gen_diffs.pl`. A mis-lowered example that
  loops forever produced 1.0 GB of stdout which the gates then persisted
  FOUR times. `timeout 20` bounds wall time and did not help; the bound has
  to be in bytes. The cap **drains to EOF rather than truncating**, on
  purpose: `head -c N` closes the pipe early and SIGPIPE is IGNORED on this
  fleet (systemd `IgnoreSIGPIPE=yes`; workers inherit it), so the writer
  would get EPIPE and keep looping — the `096_head_procsub.sh` orphan class
  that filled `sh2gates`. **RLIMIT_FSIZE is not used for captures**: it
  bounds file writes, not pipes (measured — 4 MB passed through a 512 KB
  `ulimit -f`). Cap is 1 MiB against a 7,470-byte maximum legitimate corpus
  output, and is applied to BOTH sides of every comparison.
- **The 9p mounts are NOT a write hotspot.** `/mnt/c`, `/mnt/d`, `/mnt/e`,
  `/mnt/j` are Windows-side. The claim that agent scratch lived there is
  wrong: the command-code scratchpad is 12 KB, **every** harness path
  (`/home/llm/sh2loop`, `/root`, `/tmp`, `/var/tmp`) is already on
  `/dev/sdd` = 8:48 (the device `io.max` caps), and open fds on any 9p mount
  = 0. The 9p blind spot is real (16 MB to `/mnt/c` records +0 MB and 1 wio
  on 8:48, vs +17 MB and 11 wios for `/tmp`) but nothing here writes there.

Reading `memory.stat` for a verdict? `file` is page cache and `anon` is real
memory — they need opposite treatment, and conflating them is how a cache
problem gets misdiagnosed as a RAM shortage.

## Worker traps: a quota wall is not a build failure

A worker that stops producing is usually **asleep by design**, not dead, and
**restarting it does not help** — it re-enters the same wait. Three
mechanisms, all fixed 2026-09-29 after the perl worker sat for 6.5 h:

- `core-requests/sleeping-<lang>` is the marker. `--worker-trapped` waits on
  it, so `ps` shows a live process and the unit shows `active`.
- **A provider 429 used to mark a worker TRAPPED.** `--run-backend-worker`
  escalated on `fail_count >= 3` without asking *why* the attempts failed, so
  three rate-limit retries — retriable in minutes — became a core-request and
  an indefinite sleep, on a gate that never failed to build. It now detects
  the quota signal in **only the bytes the current attempt appended** (a
  whole-log grep is poisoned by historical 429s and by the phrase "rate
  limit" inside a tool result), cools down instead of trapping, and resets
  the counter.
- **A rejected core-request no longer sleeps a worker forever.** Rejection is
  filed to `done/` without waking anyone, so if nothing is ever *implemented*
  the wake is unreachable — `grep -c 'woke '` over the whole estree log was
  **0**. A lang is now woken after `$SH2_REJECT_WAKE_GRACE` (default 2)
  rejections; an implementation clears the debt.
- **The trap sleep is bounded** by `$WORKER_TRAP_SLEEP_MAX_S` (default 7200).
  After that the worker exits so its supervisor restarts it and it re-gates.
  The marker is left for estree to clear.

Diagnosing it: the log line still says *"backing off 30 min"* long after that
30-minute loop handed off to the unbounded wait, so **the message never said
the wait had become open-ended**. Check the marker and the process tree, not
the message:

```
ls -la core-requests/sleeping-*                  # who is asleep, and since when
ps --ppid $(pgrep -f 'run-backend-worker <lang>')  # is it in a trap-sleep?
```

The estree loop self-re-execs when `main_loop_estree.pl` changes on disk
(`[self-reexec]` in its log), so changes reach it at the top of the next
iteration. The backend workers have **no** such mechanism — `Restart=always`
relaunches the *supervisor*, which does **not** re-run `--worker-trapped`
children, so after editing `setup_backends.sh` check for orphaned
`--worker-trapped` processes and restart the units.



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
  regression and is not one. `sh2gates` is now at 0/1024 with its refusal
  count flat, and `init.scope` is bounded at 8192 (see **Box-health
  guards**), but an ad-hoc run is still not wrapped by either.
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
