#!/usr/bin/env python3
"""harness/model_report.py — rotation bookkeeping and model comparison.

Four subcommands over the two JSONL files that `ai_invoke.py` and the workers
write:

    init-rotation   create .worker-model/epoch once (never silently overwrite)
    record-gate     append one complete gate result for a worker
    status          current phase, model, health, telemetry completeness
    report          per-worker and per-model progress comparison

Progress is NORMALIZED, because the corpora differ in size and are not
comparable as raw fail counts:

    normalized_progress   = (start_failures - end_failures) / start_total
    progress_per_hour     = normalized_progress / actual_interval_hours
    progress_per_1m_tokens = normalized_progress * 1e6 / reported_tokens

A model is only ranked once every model worker has a measured interval under
BOTH models — otherwise the comparison is confounded by worker difficulty and
by unequal observation time, and a confident wrong winner is worse than none.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import statistics
import sys
import time

PHASE_SECONDS = 4 * 3600
WORKERS = ("rust", "c", "perl", "estree")


def runtime_dir() -> str:
    env = os.environ.get("WORKER_MODEL_DIR")
    if env:
        return env
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".worker-model")


def epoch_path() -> str:
    return os.path.join(runtime_dir(), "epoch")


def invocations_path() -> str:
    return os.path.join(runtime_dir(), "invocations.jsonl")


def gates_path() -> str:
    return os.path.join(runtime_dir(), "gates.jsonl")


def read_epoch():
    try:
        with open(epoch_path()) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def load_jsonl(path: str) -> list[dict]:
    """Read a JSONL file, warning on (not crashing over) a torn line.

    A worker killed mid-append can leave a partial line. Refusing to produce a
    report because of one bad line would hide every other measurement, so the
    bad line is reported and skipped.
    """
    out: list[dict] = []
    try:
        with open(path, errors="replace") as fh:
            for n, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    print(f"warning: {os.path.basename(path)}:{n} is not valid JSON — skipped", file=sys.stderr)
                    continue
                if isinstance(obj, dict):
                    out.append(obj)
    except OSError:
        return []
    return out


def append_jsonl(path: str, record: dict) -> None:
    os.makedirs(runtime_dir(), exist_ok=True)
    blob = (json.dumps(record, sort_keys=True) + "\n").encode()
    with open(os.path.join(runtime_dir(), "rotation.lock"), "a+") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
            try:
                os.write(fd, blob)
            finally:
                os.close(fd)
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)


def phase_of(ts: float, epoch: int) -> int:
    return max(0, int((ts - epoch) // PHASE_SECONDS))


def fmt_hours(h: float | None) -> str:
    if h is None:
        return "?"
    if h < 1:
        return f"{h * 60:.0f}m"
    if h < 48:
        return f"{h:.1f}h"
    return f"{h / 24:.1f}d"


def fmt_tokens(total: int | None) -> str:
    """Just the total. Per-call categories live in invocations.jsonl."""
    return "unknown" if total is None else f"{total:,}"


def reported_tokens(rec: dict) -> int | None:
    """Total reported tokens, or None when telemetry is incomplete.

    A partial frame is not a smaller number — it is unknown, and treating it as
    a total would make an unmeasured call look like a cheap one.
    """
    tok = rec.get("tokens")
    if not isinstance(tok, dict):
        return None
    vals = [tok.get(k) for k in ("input", "output", "cache_read", "cache_write")]
    if any(v is None for v in vals):
        return None
    return sum(vals)


def cmd_init(args) -> int:
    existing = read_epoch()
    if existing is not None and not args.reset:
        print(f"epoch already initialized: {existing} ({time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(existing))})")
        print("refusing to overwrite; pass --reset to start a new rotation")
        return 1
    os.makedirs(runtime_dir(), exist_ok=True)
    with open(os.path.join(runtime_dir(), "rotation.lock"), "a+") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            again = read_epoch()
            if again is not None and not args.reset:
                print(f"epoch already initialized (raced): {again}")
                return 1
            value = int(args.now if args.now is not None else time.time())
            tmp = epoch_path() + ".tmp"
            with open(tmp, "w") as fh:
                fh.write(f"{value}\n")
            os.replace(tmp, epoch_path())
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)
    print(f"rotation epoch set: {value} ({time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(value))})")
    print(f"phase length: {PHASE_SECONDS // 3600}h; next swap at "
          f"{time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(value + PHASE_SECONDS))}")
    return 0


def cmd_record_gate(args) -> int:
    rec = {
        "worker": args.worker,
        "corpus": args.corpus,
        "pass": args.pass_,
        "fail": args.fail,
        "skip": args.skip,
        "recorded_at": args.now if args.now is not None else time.time(),
        "source": args.source,
        "pre_epoch": read_epoch() is None,
    }
    for extra in ("stub", "equivalence", "static", "bundle"):
        val = getattr(args, extra, None)
        if val is not None:
            rec[extra] = val
    append_jsonl(gates_path(), rec)
    print(f"recorded gate: {args.worker} {args.pass_}/{args.pass_ + args.fail} pass, {args.fail} fail, {args.skip} skip")
    return 0


def model_intervals(worker: str, invocations: list[dict], gates: list[dict], epoch: int) -> list[dict]:
    """Reconstruct the intervals a worker actually spent on each model.

    Intervals come from invocation START timestamps, not from the nominal
    four-hour grid: a call that ran across a deadline kept its model, and a
    worker that was idle for hours genuinely has no observation for that time.
    """
    mine = sorted(
        (r for r in invocations if r.get("worker") == worker and not r.get("pre_epoch")),
        key=lambda r: r.get("started_at") or 0,
    )
    my_gates = sorted(
        (g for g in gates if g.get("worker") == worker and not g.get("pre_epoch")),
        key=lambda g: g.get("recorded_at") or 0,
    )
    if not mine:
        return []

    spans: list[dict] = []
    current = None
    for rec in mine:
        model = rec.get("model")
        start = rec.get("started_at")
        end = rec.get("ended_at") or start
        if start is None:
            continue
        if current is None or current["model"] != model:
            if current is not None:
                current["end"] = start
            current = {"model": model, "start": start, "end": end, "invocations": []}
            spans.append(current)
        current["end"] = max(current["end"], end)
        current["invocations"].append(rec)
    for span in spans:
        span["end"] = max(span["end"], span["start"])

    for span in spans:
        inside = [g for g in my_gates if span["start"] <= (g.get("recorded_at") or 0) <= span["end"]]
        before = [g for g in my_gates if (g.get("recorded_at") or 0) <= span["start"]]
        span["start_gate"] = before[-1] if before else None
        span["end_gate"] = inside[-1] if inside else None
        span["hours"] = max(span["end"] - span["start"], 1.0) / 3600.0
        span["tokens"] = _span_tokens(span)
        span.update(_span_progress(span))
    return spans


def _span_tokens(span: dict) -> int | None:
    """Sum reported tokens over the span, or None if any call is unmeasured."""
    total = 0
    for rec in span["invocations"]:
        t = reported_tokens(rec)
        if t is None:
            return None
        total += t
    return total if span["invocations"] else None


def _span_progress(span: dict) -> dict:
    """Normalized progress across a span, or an explicit reason it is unknown."""
    sg, eg = span.get("start_gate"), span.get("end_gate")
    if sg is None or eg is None:
        return {"normalized": None, "reason": "no complete gate on both sides of the interval"}
    if sg.get("corpus") != eg.get("corpus"):
        return {"normalized": None, "reason": f"corpus changed ({sg.get('corpus')} -> {eg.get('corpus')})"}
    start_total = (sg.get("pass") or 0) + (sg.get("fail") or 0)
    if not start_total:
        return {"normalized": None, "reason": "start gate has no pass/fail counts"}
    return {
        "normalized": ((sg.get("fail") or 0) - (eg.get("fail") or 0)) / start_total,
        "reason": None,
        "raw": f"{sg.get('fail')}f -> {eg.get('fail')}f",
    }


def cmd_status(args) -> int:
    epoch = read_epoch()
    invocations = load_jsonl(invocations_path())
    gates = load_jsonl(gates_path())
    now = args.now if args.now is not None else time.time()

    print("=== Model rotation status ===")
    if epoch is None:
        print("  epoch: NOT initialized — workers use their phase-0 model;")
        print("         records are marked pre_epoch and excluded from scoring.")
        phase = 0
    else:
        phase = phase_of(now, epoch)
        print(f"  epoch: {epoch} ({time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(epoch))})")
        print(f"  phase: {phase} ({(phase % 2) and 'odd — groups swapped' or 'even — base assignment'})")
        until = epoch + (phase + 1) * PHASE_SECONDS
        print(f"  next boundary: {time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(until))} "
              f"(in {fmt_hours((until - now) / 3600)})")

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from ai_invoke import GROUPS, model_for  # type: ignore

    print("")
    print("  worker   group  model                       invocations  telemetry  last gate")
    for w in WORKERS:
        recs = [r for r in invocations if r.get("worker") == w]
        model = model_for(w, phase)
        good = sum(1 for r in recs if reported_tokens(r) is not None)
        lg = [g for g in gates if g.get("worker") == w]
        last = time.strftime("%H:%M", time.localtime(lg[-1]["recorded_at"])) if lg and lg[-1].get("recorded_at") else "-"
        print(f"  {w:<8} {GROUPS[w]['group']:<6} {model:<27} {len(recs):<12} {good}/{len(recs):<10} {last}")

    print("")
    print("  core     -      none (deterministic)       0            n/a        (LLM-free gate)")
    return 0


def cmd_report(args) -> int:
    epoch = read_epoch()
    invocations = load_jsonl(invocations_path())
    gates = load_jsonl(gates_path())
    now = args.now if args.now is not None else time.time()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from ai_invoke import GROUPS  # type: ignore

    print("=== Model progress comparison ===")
    if epoch is None:
        print("  epoch not initialized — nothing comparable yet.")
        return 0
    print(f"  rotation age: {fmt_hours((now - epoch) / 3600)}   current phase: {phase_of(now, epoch)}")
    print("")

    per_model: dict[str, dict] = {}
    incomplete: list[str] = []
    for w in WORKERS:
        spans = model_intervals(w, invocations, gates, epoch)
        if not spans:
            incomplete.append(w)
            continue
        print(f"--- {w} (group {GROUPS[w]['group']}) ---")
        for s in spans:
            norm = s.get("normalized")
            label = f"{norm * 100:+.2f}%" if norm is not None else "unknown"
            per_hour = s["normalized"] / s["hours"] if norm is not None else None
            tok = s.get("tokens")
            eff = (norm * 1e6 / tok) if (norm is not None and norm > 0 and tok) else None
            print(f"  {s['model']:<34} {fmt_hours(s['hours']):>6}  progress={label:<9}"
                  f" {s.get('raw') or '':<12} tokens={fmt_tokens(tok)}"
                  f"  /h={('%.4f' % per_hour) if per_hour is not None else '?'}"
                  f"  per1M={('%.4f' % eff) if eff is not None else '?'}")
            if s.get("reason"):
                print(f"      ({s['reason']})")
        print("")

    # Group scores average normalized values; summing raw fails across
    # different corpora would be meaningless.
    for model in sorted({s["model"] for w in WORKERS for s in model_intervals(w, invocations, gates, epoch)}):
        vals, hours, toks = [], 0.0, 0
        tok_known = True
        for w in WORKERS:
            for s in model_intervals(w, invocations, gates, epoch):
                if s["model"] != model:
                    continue
                hours += s["hours"]
                if s.get("normalized") is not None:
                    vals.append(s["normalized"])
                if s.get("tokens") is None:
                    tok_known = False
                else:
                    toks += s["tokens"]
        if not vals:
            continue
        mean_norm = statistics.fmean(vals)
        per_model[model] = {
            "mean_normalized": mean_norm,
            "hours": hours,
            "tokens": toks if tok_known else None,
            "per_hour": mean_norm / hours if hours else None,
            "per_1m": (mean_norm * 1e6 / toks) if (tok_known and toks and mean_norm > 0) else None,
        }

    print("--- By model (mean of per-worker normalized progress) ---")
    for model, s in sorted(per_model.items(), key=lambda kv: -(kv[1]["per_hour"] or 0)):
        print(f"  {model:<34} {fmt_hours(s['hours']):>6}  mean_progress={s['mean_normalized'] * 100:+.2f}%"
              f"  /h={('%.4f' % s['per_hour']) if s['per_hour'] is not None else '?'}"
              f"  tokens={s['tokens'] if s['tokens'] is not None else 'unknown'}"
              f"  per1M={('%.4f' % s['per_1m']) if s['per_1m'] is not None else '?'}")
    print("")

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from ai_invoke import GROUPS, LAGUNA, SPACE_BUNNY  # type: ignore

    models_seen = {r.get("model") for r in invocations if not r.get("pre_epoch")}
    expected = {SPACE_BUNNY, LAGUNA}
    if incomplete or not expected.issubset(models_seen):
        missing = sorted(expected - models_seen)
        print("  NOT RANKING YET: need a measured interval under both models for every worker.")
        if incomplete:
            print(f"    workers with no post-epoch invocation: {', '.join(incomplete)}")
        if missing:
            print(f"    models never observed: {', '.join(missing)}")
    else:
        print("  Both models have intervals; ranking above is comparable (still correlates worker difficulty).")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Rotation bookkeeping and model comparison.")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("init-rotation", help="create the epoch once")
    p.add_argument("--reset", action="store_true")
    p.add_argument("--now", type=float, default=None)
    p.set_defaults(func=cmd_init)

    p = sub.add_parser("record-gate", help="append a complete gate result")
    p.add_argument("--worker", required=True, choices=WORKERS)
    p.add_argument("--corpus", required=True)
    p.add_argument("--pass", dest="pass_", type=int, required=True)
    p.add_argument("--fail", type=int, required=True)
    p.add_argument("--skip", type=int, default=0)
    p.add_argument("--source", default="")
    for opt in ("--stub", "--equivalence", "--static", "--bundle"):
        p.add_argument(opt, type=int, default=None)
    p.add_argument("--now", type=float, default=None)
    p.set_defaults(func=cmd_record_gate)

    p = sub.add_parser("status", help="current phase, model, health")
    p.add_argument("--now", type=float, default=None)
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("report", help="per-worker and per-model comparison")
    p.add_argument("--now", type=float, default=None)
    p.set_defaults(func=cmd_report)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
