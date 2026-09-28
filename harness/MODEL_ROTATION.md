# Model rotation and telemetry

Four workers run on two models in two fixed groups, swapping every four hours,
so their progress can be compared per wall-clock hour and per token.

Model selection is a **command-line argument** (`cmd --model <exact-id>`), not
a database row and not a mutable config file. The only persistent state is one
epoch timestamp, because a worker's environment is frozen at process start and
cannot implement a swap by itself.

## Groups

| Worker | Group | Even phase | Odd phase |
|---|---|---|---|
| `rust` | A | `stealth/space-bunny-alpha` | `poolside/laguna-s-2.1-free` |
| `c` | A | `stealth/space-bunny-alpha` | `poolside/laguna-s-2.1-free` |
| `estree` | B | `poolside/laguna-s-2.1-free` | `stealth/space-bunny-alpha` |
| `core` | — | none (deterministic) | none |

The `perl` row was removed 2026-09-29 with `main_loop_rust.pl`. That
loop tracked the duplicate perl renderer; the corpus is now tracked by
`estree` through `fail-estree`. `perl` the *backend* still exists and
still has its own worker — it just has no separate group-B loop.

**Model ids are verified, not assumed.** `cmd` rejects the OpenRouter-style
colon form (`poolside/laguna-s-2.1:free`) as an unknown model — the catalog id
is hyphen-separated. A rejected id looks exactly like a broken worker, so
`ai_invoke.py` defines the id once and it was confirmed with a live call.

## Swaps happen at invocation boundaries

A swap is **never** pushed onto a running worker. `ai_invoke.py` snapshots the
model once per invocation:

```
phase = floor((now - epoch) / 14400)     # 0 = 4 hours
```

- A call that started before a deadline finishes on its original model.
- The **next** call picks up the new phase.
- If the machine sleeps or a call crosses several deadlines, the next call jumps
  straight to the latest phase. Missed toggles are not replayed.
- No signal, restart, or kill is part of a swap. There is no rotation timer.

Intervals are therefore reconstructed from invocation **start** timestamps, not
from the nominal four-hour grid: a worker that was idle for hours genuinely has
no observation for that time.

## Files

- `harness/ai_invoke.py` — the invocation wrapper. Chooses the model for the
  phase, launches `cmd`, applies the Laguna quota fallback, and records
  token usage. Not a broker; it changes no repository files.
- `harness/model_report.py` — `init-rotation`, `record-gate`, `status`,
  `report`.
- `harness/ai_fallback.pm` — shared quota-fallback detection for the Perl
  loops, so they cannot drift apart.
- `harness/MODEL_ROTATION.md` — this file.

A worker opts in with `WORKER_ROTATE_WORKER=<rust|c|estree>`. Unset means
the direct `WORKER_CLI` path, which is unchanged.

## Laguna daily-quota fallback

OpenRouter's exact daily-free error is `free-models-per-day`. When the active
model is Laguna **and** the output carries that marker, the **same prompt** is
retried on `ollama-cloud/deepseek-v4.1-flash`.

- Detection is **stream-based, not exit-based**: `pir` retries a 429 internally,
  forever, before returning to the caller, so a script cannot learn the quota
  from the child's exit status — the child never exits. It reads the streamed
  retry notice instead.
- The switch is **one-way** and at most once per invocation: no oscillation, no
  loop. A restarted worker probes Laguna again and re-switches if the daily
  quota is still exhausted, which is also how the switch is undone — when quota
  resets.
- Near misses (plain 429, `weekly usage limit`, billing/quota, timeouts, 5xx,
  auth) do not match and keep the existing infinite retry. No non-Laguna model
  ever switches.
- If the fallback model also fails, its normal infinite retry applies. Workers
  still never give up.
- `WORKER_FALLBACK_MODEL=` (empty) disables it.
- Ollama Cloud may be metered — this is the one intentional cost.

The opencode-go/`pi` quota gate (`harness/quota-gate.sh`) is scoped to
`WORKER_CLI=pi` so a stale `pi` 429 marker can never suppress a rotating
worker, which would also suppress the fallback.

## Runtime data

Ignored `.worker-model/`:

- `epoch` — one integer, the common rotation start.
- `invocations.jsonl` — one record per AI call: worker, group, phase, model,
  fallback_used, rc, timestamps, per-category tokens, reported duration.
- `gates.jsonl` — one record per complete gate: worker, corpus identity,
  pass/fail/skip.
- `rotation.lock` — advisory lock for epoch init and safe appends.

Before the epoch exists, workers use their phase-0 model and records are marked
`pre_epoch` and excluded from scoring.

**Missing telemetry is `null`, never zero.** An unmeasured call is unknown, not
cheap; a partial usage frame is not a smaller total.

## Progress scoring

The corpora differ in size, so raw fail counts are not comparable. Progress is
normalized against the gate at the start of the interval:

```
normalized_progress    = (start_failures - end_failures) / (start_pass + start_fail)
progress_per_hour      = normalized_progress / actual_interval_hours
reported_tokens        = input + output + cache_read + cache_write
progress_per_1m_tokens = normalized_progress * 1e6 / reported_tokens
```

- Skips stay out of the denominator.
- Negative progress is retained as a regression; `per1M` is shown only for
  positive progress, since "progress per token" is meaningless for a
  regression.
- A corpus change keeps the raw counts but marks normalized comparison
  unavailable.
- Group scores average the per-worker normalized values rather than summing
  across incompatible corpora.
- Unknown telemetry is excluded from efficiency and shown explicitly.
- A **ranking is withheld** until every model worker has a measured interval
  under both models. One worker on one model is not a comparison.

## Commands

```bash
python3 harness/model_report.py init-rotation      # once; refuses to overwrite
python3 harness/model_report.py status
python3 harness/model_report.py report             # also embedded in ./progress.sh

# a worker records a complete gate:
record_gate <worker> <corpus> <pass> <fail> <skip>
```

`init-rotation` refuses to overwrite an existing epoch unless `--reset` is
passed. To start a new rotation: `--reset`, and delete the JSONL files if the old
history should not be scored.

## Tests

```bash
python3 tests/test_model_rotation.py    # 25 tests, fake cmd, injected clock
bash harness/test_worker_fallback.sh     # 10 checks, fake cmd, no paid calls
```

No real model calls. The tests cover phase boundaries at +4h/+8h, a delayed
invocation jumping to the latest phase, exact command-line model ids, token
validation and unknown-not-zero telemetry, run_end blob redaction, epoch
atomicity, malformed-line tolerance, normalized progress with regressions /
skips / corpus changes, withheld ranking, the quota switch, all near-miss
non-switches, non-Laguna non-switch, no oscillation, and the empty-fallback
disable.
