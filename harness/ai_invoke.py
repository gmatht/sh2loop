#!/usr/bin/env python3
"""harness/ai_invoke.py — one AI invocation for a rotating worker fleet.

Model selection is a command-line argument (`cmd --model <exact-id>`), never a
database row and never a mutable config file. The only persistent state is one
epoch timestamp in `.worker-model/epoch`, because a worker's environment is
frozen at process start and cannot implement a swap by itself.

    phase = floor((now - epoch) / PHASE_SECONDS)      # 0 = 4 hours
    phase even  -> group A gets Space Bunny Alpha, group B gets Laguna
    phase odd   -> the two groups are swapped

A swap is never pushed onto a running worker: the model is snapshotted once per
invocation, so a call that started before a deadline finishes on its original
model and the NEXT call picks up the new phase.

Laguna quota fallback: OpenRouter's exact daily-free error is
`free-models-per-day`. That code is OpenRouter's own and does not occur in the
transpiler corpus, so "current model is Laguna AND the output carries the
marker" is a sufficient guard. The switch is one-way and happens at most once
per invocation, so it can never oscillate.
"""

from __future__ import annotations

import argparse
import errno
import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import time

PHASE_SECONDS = 4 * 3600

# Exact model ids. VERIFIED against `cmd --list-models` / a live call: the
# Laguna id is hyphen-separated. The colon form that pir/OpenRouter uses
# (`poolside/laguna-s-2.1:free`) is REJECTED by cmd as an unknown model, and a
# rejected id looks exactly like a broken worker — so this is verified, not
# assumed, and any override is checked the same way at init.
LAGUNA = os.environ.get("WORKER_LAGUNA_MODEL", "poolside/laguna-s-2.1-free")
# PROVIDER-QUALIFIED, and verified against BOTH catalogs, because the two CLIs
# do not agree on the id space:
#   cmd  (`cmd --list-models`)  lists the flat vendor/model form, and REJECTS
#        the pir/OpenRouter colon form as an unknown model. It nevertheless
#        also ACCEPTS the provider-qualified `commandcode/…` form — verified
#        by a live call returning a `result` frame with usage, 2026-09-30 —
#        so the qualified id works for the rotating path too.
#   pir  REFUSES a bare `stealth/space-bunny-alpha` outright: it exists in
#        both commandcode/ and openrouter/, and pir reports "exists in
#        multiple providers" rather than guessing. No other provider in
#        models-store.json carries a space-bunny model, so commandcode/ is
#        the unambiguous target.
#
# One id for the whole fleet keeps the telemetry in invocations.jsonl
# comparable: an entry recorded as `stealth/…` and one recorded as
# `commandcode/stealth/…` would otherwise look like two different models to
# every report that tallies by model string.
#
# GLYPH CLUSTER (operator, 2026-10-09), replacing space-bunny-alpha.
# The id is verified against `cmd --list-models` (1.79.1), NOT assumed:
#   stealth/glyph-cluster:free     FREE stealth reasoning model in early access
# The COLON form is the one cmd's own catalog prints and it IS accepted here
# (both bare and commandcode/-qualified) — confirmed by a live call that got
# past model resolution and failed only on auth. The HYPHEN form
# (stealth/glyph-cluster-free) is REJECTED as an unknown model, which is the
# trap the LAGUNA note above describes. Keep the colon.
# Kept commandcode/-qualified so the fleet records a single model string.
SPACE_BUNNY = os.environ.get("WORKER_SPACE_BUNNY_MODEL", "commandcode/stealth/glyph-cluster:free")

# OpenRouter's daily-free quota error code.
QUOTA_MARKER = "free-models-per-day"
# A DIFFERENT failure that must trigger the same fallback: the model has
# providers but they are all at capacity right now. Observed 2026-09-28 on
# Laguna: 316 such errors in the c worker's log, each reading
#   "The request limited providers for this model and they are currently at
#    capacity. ... Providers considered: poolside."
# Laguna is SINGLE-PROVIDER, so when poolside is busy there is nothing to
# fail over to and the retry ladder re-issues the same dead request forever
# (the c worker sat at `attempt 19, retry in 300s`). The quota marker never
# fires, because this is not a daily-quota error.
#
# Space Bunny Alpha is multi-provider and is not affected — 0 of these errors
# named stealth. It is Laguna-specific in practice, but the marker is
# provider-agnostic so it is matched on the message, not the model.
CAPACITY_MARKER = "currently at capacity"

# GLYPH CLUSTER's OWN DAILY WALL (added 2026-10-09). A THIRD wording, and it
# does not overlap with either marker above, so without this entry the switch
# never fired for the model the fleet actually runs. Observed live:
#
#   "Error: You've reached today's limit on Glyph Cluster. Resets in 7h 10m
#    (8:00 AM). Run /model to pick another model."
#
# and the CLI exits rc=5. Before this, that message fell through to the
# generic retry ladder: every worker re-issued the same exhausted request
# forever — the exact loop the fallback exists to break. Matched on the
# message, not the exit code, for the same reason as the others: cmd's rc is
# only meaningful alongside the text, and rc=5 also covers unrelated errors.
#
# NOTE the reset is a DAILY window, so this is expected to recur; the fallback
# is what carries the fleet across it rather than a bug to stamp out.
GLYPH_QUOTA_MARKER = "reached today's limit"

WORKERS = ("rust", "c", "perl", "estree", "perl-generator", "fish", "zsh")

# group -> {0: model_on_even_phase, 1: model_on_odd_phase}
# Group A holds the two sh2-native backends; group B the two ESTree-side ones.
#
# ── ALL WORKERS PINNED TO SPACE BUNNY ALPHA (operator, 2026-09-30) ──────
# Every entry below now has even == odd == SPACE_BUNNY, so the phase no longer
# changes any worker's model. Laguna is retained as the *fallback* target of
# last resort but is no longer any worker's primary: OpenRouter's daily
# `free-models-per-day` budget was exhausted, and a worker whose primary is
# Laguna has no route out of it — its only recourse is the 30-minute
# `rw_quota_cooldown_s` sleep, which burns wall-clock and fixes nothing.
#
# The table is kept (rather than collapsed to a single constant) so restoring
# the A/B is a one-line revert per worker, and so `model_for()` keeps
# returning something meaningful if a future override reintroduces a phase.
#
# CONSEQUENCE: the rotation A/B is no longer being measured, so a comparison
# between the two models over this window is meaningless. progress.sh's
# normalized-gate-progress-per-token comparison needs both arms per worker
# before any ranking is meaningful; re-pin a worker to LAGUNA to collect the
# other arm.
GROUPS = {
    "rust": {"group": "A", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
    "c": {"group": "A", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
    "perl": {"group": "B", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
      # The perl GENERATOR worker (run_perl_generator_worker.sh; gate ./fail,
      # scope src/perl_generator_fixed.rs). Group B with perl/estree. It was
      # missing from the roster: an unrecognised --worker is rejected, so the
      # worker would have run its gate and then failed every AI call.
      "perl-generator": {"group": "B", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
    "estree": {"group": "B", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
    # fish + zsh (2026-10-01): deployed with sh2backend-{fish,zsh}.service, and
    # like perl-generator they were missing from the roster — an unrecognised
    # --worker is REJECTED, so on the pir path they would run their gate and
    # then fail every AI call. Group A with the two sh2-native backends.
    "fish": {"group": "A", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
    "zsh": {"group": "A", "even": SPACE_BUNNY, "odd": SPACE_BUNNY},
}

def runtime_dir() -> str:
    # Read the override lazily: capturing it at import time makes the tests
    # write into the real workspace instead of their temp dir.
    env = os.environ.get("WORKER_MODEL_DIR")
    if env:
        return env
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".worker-model")


def fallback_model() -> str:
    """Ollama Cloud may be metered — the one intentional cost. Empty disables."""
    return os.environ.get("WORKER_FALLBACK_MODEL", "ollama-cloud/deepseek-v4.1-flash")


def epoch_path() -> str:
    return os.path.join(runtime_dir(), "epoch")


def lock_path() -> str:
    return os.path.join(runtime_dir(), "rotation.lock")


def invocations_path() -> str:
    return os.path.join(runtime_dir(), "invocations.jsonl")


def read_epoch() -> int | None:
    """Return the rotation epoch, or None before it has been initialized."""
    try:
        with open(epoch_path()) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def current_phase(now: float, epoch: int | None) -> int:
    """Phase index. Before the epoch exists, use the requested phase-0 model."""
    if epoch is None:
        return 0
    return max(0, int((now - epoch) // PHASE_SECONDS))


def model_for(worker: str, phase: int) -> str:
    spec = GROUPS[worker]
    return spec["odd"] if phase % 2 else spec["even"]


def append_jsonl(path: str, record: dict) -> None:
    """Append one complete JSON line under an advisory lock.

    A torn line would silently poison every later report, so the write is a
    single O_APPEND write of a newline-terminated blob.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    blob = (json.dumps(record, sort_keys=True) + "\n").encode()
    lock = os.path.join(runtime_dir(), "rotation.lock")
    os.makedirs(runtime_dir(), exist_ok=True)
    with open(lock, "a+") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
            try:
                os.write(fd, blob)
            finally:
                os.close(fd)
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)


def _as_int(value):
    """Tokens are numbers or absent. A missing value is None, never 0 —
    reporting 0 tokens would silently count an unmeasured call as free."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    return None


def parse_result_line(line: str) -> dict | None:
    """Extract telemetry from a `cmd --output-format json` result frame.

    Returns {"tokens": {...}, "duration_ms": int|None} or None when the line is
    not a usable result frame.
    """
    try:
        obj = json.loads(line)
    except (ValueError, TypeError):
        return None
    if not isinstance(obj, dict) or obj.get("type") != "result":
        return None
    usage = obj.get("usage")
    usage = usage if isinstance(usage, dict) else {}
    return {
        "tokens": {
            "input": _as_int(usage.get("inputTokens")),
            "output": _as_int(usage.get("outputTokens")),
            "cache_read": _as_int(usage.get("cacheReadTokens")),
            "cache_write": _as_int(usage.get("cacheWriteTokens")),
        },
        "duration_ms": _as_int(obj.get("durationMs")),
    }


# cmd's `-p` mode caps conversation turns and EXITS 8 WHEN THE CAP IS HIT:
#   --max-turns <number>  Cap conversation turns in -p mode (default 100; exit 8 on cap-hit)
#
# WHY WE MUST PASS IT (observed 2026-10-09, and misread as a broken fallback).
# Leaving the default in place made rc=8 look like a failing call — 19 of the
# last 20 invocations logged rc=8, which reads as "the ollama fallback is
# broken". It is not: rc=8 is the CAP-HIT signal, and a direct reproduction of
# the worker's exact argv (real prompt, worker cwd) did 16+ turns of real tool
# use and edited c_backend.rs before the cap stopped it. The fleet's tasks are
# whole-backend refactors ("lower 19,911 runtime delegations across 560 files,
# keep the gate green") that cannot fit in 100 turns, so EVERY call was exiting
# partway through with the work unlanded.
#
# 400 is chosen against the observed shape, not guessed: ~100 turns already
# exhausted a single prompt's budget, so the ceiling has to be well clear of it
# while still bounding a runaway loop. It is env-overridable so an operator can
# tune it per box without editing this file.
DEF_MAX_TURNS = os.environ.get("WORKER_MAX_TURNS", "400")


def cmd_argv(model: str, effort: str) -> list[str]:
    argv = [
        "cmd", "-p", "--no-session", "--yolo",
        "--model", model,
        "--output-format", "json", "--tools-all",
        "--max-turns", DEF_MAX_TURNS,
    ]
    if effort:
        argv += ["--effort", effort]
    return argv


def kill_tree(pid: int) -> None:
    """TERM then KILL a child and its descendants.

    A quota-stalled `cmd` can be sleeping in a long backoff with its own
    subprocesses; killing only the parent would leave them burning CPU.
    """
    try:
        pgid = os.getpgid(pid)
    except OSError:
        return
    for sig, grace in ((signal.SIGTERM, 2.0), (signal.SIGKILL, 1.0)):
        try:
            os.killpg(pgid, sig)
        except OSError as exc:
            if exc.errno == errno.ESRCH:
                return
        deadline = time.time() + grace
        while time.time() < deadline:
            try:
                os.kill(pid, 0)
            except OSError:
                return
            time.sleep(0.1)


def redact_for_log(line: str) -> str:
    """Drop the unbounded `nextState` blob from a `run_end` event frame.

    `cmd`'s run_end frame embeds the ENTIRE workspace git status and the full
    message history of the run. On a long agentic session that is megabytes per
    invocation — and this workspace already lost GBs of log plus cgroup page
    cache to unbounded transcript echo (the 2026-08-14/15 incident). The
    telemetry we actually want is the usage block, which is small and is
    already repeated in the final `result` frame.

    Keyed on the frame type, not on a size threshold: a size-based early-out
    would let a *small* run_end frame keep its blob and only redact a large
    one, which is exactly backwards.
    """
    if '"run_end"' not in line:
        return line
    try:
        obj = json.loads(line)
    except ValueError:
        return line[:4096] + "\n[run_end frame truncated: unparseable]\n"
    event = obj.get("event")
    if isinstance(event, dict) and isinstance(event.get("result"), dict):
        result = event["result"]
        result.pop("nextState", None)
        result.pop("modState", None)
    return json.dumps(obj, separators=(",", ":")) + "\n"


def run_once(prompt_file: str, model: str, effort: str, timeout: int, log_file: str | None) -> dict:
    """Run one `cmd` invocation, streaming to the worker log.

    Returns a dict with rc, whether the output carried the Laguna quota marker,
    the last result frame, and the observed duration. The child is started in
    its own process group so a timeout can reap the whole tree.
    """
    started = time.time()
    argv = cmd_argv(model, effort)
    try:
        fh_log = open(log_file, "ab") if log_file else subprocess.DEVNULL
    except OSError:
        fh_log = subprocess.DEVNULL
    with open(prompt_file, "rb") as fh_prompt:
        try:
            proc = subprocess.Popen(
                argv,
                stdin=fh_prompt,
                stdout=subprocess.PIPE,
                stderr=fh_log,
                start_new_session=True,
            )
        except OSError as exc:
            if fh_log is not subprocess.DEVNULL:
                fh_log.close()
            return {
                "rc": 127,
                "quota_marker": False,
                "capacity_marker": False,
                "result": None,
                "seconds": time.time() - started,
                "error": str(exc),
            }

    deadline = started + timeout
    quota_marker = False
    capacity_marker = False
    glyph_quota_marker = False
    result = None
    tail: list[str] = []
    try:
        assert proc.stdout is not None
        for raw in proc.stdout:
            line = raw.decode("utf-8", "replace")
            out_raw = redact_for_log(line)
            if fh_log is not subprocess.DEVNULL:
                fh_log.write(out_raw.encode("utf-8", "replace"))
                fh_log.flush()
            if QUOTA_MARKER in line:
                quota_marker = True
            if CAPACITY_MARKER in line:
                capacity_marker = True
            if GLYPH_QUOTA_MARKER in line:
                quota_marker = True
                glyph_quota_marker = True
            parsed = parse_result_line(line)
            if parsed is not None:
                result = parsed
            tail.append(out_raw)
            if len(tail) > 200:
                del tail[:100]
            if time.time() > deadline:
                kill_tree(proc.pid)
                break
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        kill_tree(proc.pid)
    finally:
        # A worker runs this thousands of times; leaking the pipe here would
        # slowly exhaust the process's descriptors.
        if proc.stdout is not None:
            proc.stdout.close()
        if fh_log is not subprocess.DEVNULL:
            fh_log.close()
    rc = proc.returncode if proc.returncode is not None else -1
    return {
        "rc": rc,
        "quota_marker": quota_marker,
        "capacity_marker": capacity_marker,
        "glyph_quota_marker": glyph_quota_marker,
        "result": result,
        "seconds": time.time() - started,
        "output_tail": "".join(tail[-40:]),
    }


def log_line(log_file: str | None, text: str) -> None:
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
    message = f"[{stamp}] {text}\n"
    if log_file:
        try:
            with open(log_file, "a") as fh:
                fh.write(message)
        except OSError:
            pass
    sys.stderr.write(message)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Invoke the AI CLI for one rotating worker.")
    ap.add_argument("--worker", required=True, choices=WORKERS)
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--log", default=None, help="worker log to stream output into")
    ap.add_argument("--effort", default=os.environ.get("WORKER_EFFORT", ""))
    ap.add_argument("--timeout", type=int, default=int(os.environ.get("WORKER_TIMEOUT", "3600")))
    ap.add_argument("--dry-run", action="store_true", help="print the chosen model/command and exit")
    ap.add_argument("--now", type=float, default=None, help="override the clock (tests)")
    args = ap.parse_args(argv)

    now = args.now if args.now is not None else time.time()
    epoch = read_epoch()
    phase = current_phase(now, epoch)
    model = model_for(args.worker, phase)

    if args.dry_run:
        print(json.dumps({
            "worker": args.worker,
            "group": GROUPS[args.worker]["group"],
            "phase": phase,
            "model": model,
            "epoch": epoch,
            "command": cmd_argv(model, args.effort),
            "fallback": fallback_model() if model == LAGUNA else None,
        }, indent=2))
        return 0

    started = time.time()
    fallback = fallback_model()
    outcome = run_once(args.prompt_file, model, args.effort, args.timeout, args.log)
    switched = False

    # Daily-quota fallback. One-way, at most once, and NOT scoped to one model:
    # the fleet runs SPACE_BUNNY (Glyph Cluster) as primary and Laguna as an
    # occasional pin, and BOTH are single-provider free tiers that hit a daily
    # wall in different words. Scoping this to LAGUNA alone — as it was until
    # 2026-10-09 — meant that when Glyph Cluster hit its own limit the guard
    # never fired and every worker re-issued the same exhausted request
    # forever. The trigger is therefore the MESSAGE, not the model id.
    #
    # THREE triggers, three different wordings for the same cure:
    #   - quota_marker / glyph quota: a daily budget is spent
    #   - capacity_marker:            providers are all busy right now
    # Without the capacity one a saturated single-provider model retries the
    # same dead request until the backoff gives up (observed: 316 capacity
    # errors and `attempt 19, retry in 300s` over one day on the c worker).
    _needs_fallback = outcome["quota_marker"] or outcome.get("capacity_marker")
    if (
        _needs_fallback
        and fallback
        and fallback != model
    ):
        blocked = outcome["seconds"]
        if outcome.get("glyph_quota_marker"):
            why = f"Glyph Cluster daily limit ({GLYPH_QUOTA_MARKER!r})"
        elif outcome["quota_marker"]:
            why = f"{QUOTA_MARKER!r} (daily quota)"
        else:
            why = f"providers at capacity ({CAPACITY_MARKER!r})"
        log_line(
            args.log,
            f"fallback: {model} hit {why} after {blocked:.0f}s — "
            f"switching this call to {fallback}",
        )
        switched = True
        model = fallback
        fallback_started = time.time()
        outcome = run_once(args.prompt_file, model, args.effort, args.timeout, args.log)
        outcome["seconds"] += blocked + (time.time() - fallback_started)
        outcome["fallback_from"] = LAGUNA
        outcome["blocked_seconds"] = blocked

    result = outcome.get("result") or {}
    record = {
        "worker": args.worker,
        "group": GROUPS[args.worker]["group"],
        "phase": phase,
        "model": model,
        "model_requested": GROUPS[args.worker]["odd"] if phase % 2 else GROUPS[args.worker]["even"],
        "fallback_used": switched,
        "rc": outcome.get("rc"),
        "started_at": started,
        "ended_at": time.time(),
        "epoch": epoch,
        "pre_epoch": epoch is None,
        "seconds": round(outcome.get("seconds", 0.0), 3),
        "tokens": (result.get("tokens") if isinstance(result, dict) else None),
        "duration_ms": result.get("duration_ms") if isinstance(result, dict) else None,
        "telemetry": bool(result),
    }
    if outcome.get("fallback_from"):
        record["fallback_from"] = outcome["fallback_from"]
        record["blocked_seconds"] = round(outcome.get("blocked_seconds", 0.0), 3)
    append_jsonl(invocations_path(), record)

    if not outcome.get("telemetry", True) and result == {}:
        log_line(args.log, f"note: no final result frame from {model}; tokens recorded as null")

    # Surface the tail so the worker log keeps its final-reply evidence even
    # when the caller only inspects the return code.
    if outcome.get("output_tail"):
        sys.stderr.write(outcome["output_tail"])
    return outcome.get("rc") or 0


if __name__ == "__main__":
    sys.exit(main())
