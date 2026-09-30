#!/usr/bin/env python3
"""tests/test_model_rotation.py — rotation, telemetry, and scoring tests.

No real model calls: a fake `cmd` on PATH emits a canned result frame. The
clock is injected, so a phase boundary is tested at exactly +4h without
sleeping. Run: python3 tests/test_model_rotation.py
"""

from __future__ import annotations

import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HARNESS = os.path.join(ROOT, "harness")
sys.path.insert(0, HARNESS)

import ai_invoke  # noqa: E402
import model_report  # noqa: E402

SB = "commandcode/stealth/space-bunny-alpha"
# The cmd catalog id is hyphen-separated; the OpenRouter colon form is rejected
# by cmd as an unknown model. Verified against `cmd --list-models`.
LAG = "poolside/laguna-s-2.1-free"
# The bare, provider-unqualified Alpha id. pir REFUSES it ("exists in multiple
# providers" — commandcode/ and openrouter/ both serve it), which is why the
# fleet pins the qualified form; kept here so a test can assert that refusal
# path is not reintroduced.
SB_BARE = "stealth/space-bunny-alpha"

# A result frame shaped like cmd's real JSON output.
RESULT_FRAME = {
    "type": "result",
    "durationMs": 12345,
    "usage": {
        "inputTokens": 1000,
        "outputTokens": 200,
        "cacheReadTokens": 50,
        "cacheWriteTokens": 25,
    },
}


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="rot-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        os.environ["WORKER_MODEL_DIR"] = os.path.join(self.tmp, ".worker-model")
        os.environ["WORKER_FALLBACK_MODEL"] = "ollama-cloud/deepseek-v4.1-flash"

    def write_epoch(self, epoch: int):
        os.makedirs(ai_invoke.runtime_dir(), exist_ok=True)
        with open(ai_invoke.epoch_path(), "w") as fh:
            fh.write(str(epoch))

    def fake_cmd(self, stdout: str = "", exit: int = 0, marker: bool = False):
        """Install a fake `cmd` on PATH that records its argv and prints stdout."""
        bindir = os.path.join(self.tmp, "bin")
        os.makedirs(bindir, exist_ok=True)
        argv_log = os.path.join(self.tmp, "argv.log")
        script = f"""#!/usr/bin/env bash
printf '%s\\n' "$*" >> {argv_log}
if [ -f "$FAKE_STDIN_COPY" ]; then cat > "$FAKE_STDIN_COPY"; fi
cat <<'FRAME'
{stdout}FRAME
exit {exit}
"""
        path = os.path.join(bindir, "cmd")
        with open(path, "w") as fh:
            fh.write(script)
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        old_path = os.environ.get("PATH", "")
        os.environ["PATH"] = bindir + os.pathsep + old_path
        self.addCleanup(lambda: os.environ.__setitem__("PATH", old_path))
        return argv_log

    def run_invoke(self, worker: str, prompt: str = "fix it", extra=()):
        pf = os.path.join(self.tmp, f"prompt-{worker}.txt")
        with open(pf, "w") as fh:
            fh.write(prompt)
        out = io.StringIO()
        with redirect_stdout(out):
            rc = ai_invoke.main(["--worker", worker, "--prompt-file", pf, *extra])
        return rc

    def invocations(self):
        return model_report.load_jsonl(ai_invoke.invocations_path())

    def gates(self):
        return model_report.load_jsonl(model_report.gates_path())


class TestPhaseSelection(Base):
    # ── THE ROTATION A/B IS CURRENTLY DISABLED ──────────────────────────
    # Every GROUPS entry is even == odd == SPACE_BUNNY (operator, 2026-09-30:
    # Laguna exhausted OpenRouter's daily free-models-per-day budget, and a
    # worker whose PRIMARY is Laguna has no route out of it). So the swap
    # tests below now assert the MECHANISM — the phase is computed correctly
    # and every phase resolves to one model — instead of asserting a specific
    # A/B assignment that no longer exists.
    #
    # Re-enabling the A/B is a one-line revert per worker in GROUPS; these
    # tests will then pass again against LAG without being touched, because
    # they no longer hardcode which model wins a phase.

    def test_initial_assignment_is_exactly_as_requested(self):
        # Every worker's primary is the pinned Alpha id, in EVERY phase.
        for worker in ai_invoke.WORKERS:
            for phase in (0, 1, 2, 3):
                self.assertEqual(
                    ai_invoke.model_for(worker, phase), SB,
                    f"{worker} phase {phase} is not the pinned model",
                )

    def test_phase_is_computed_correctly_at_the_four_hour_boundary(self):
        # The swap logic itself is still live and must stay correct for when
        # the A/B is restored — only the model's VALUE is currently constant.
        self.write_epoch(1_000_000)
        for t, phase in ((1_000_000, 0), (1_000_000 + 4 * 3600, 1), (1_000_000 + 8 * 3600, 2)):
            p = ai_invoke.current_phase(t, ai_invoke.read_epoch())
            self.assertEqual(p, phase, f"at t={t}")
        # Even and odd are currently indistinguishable by value, but they are
        # still DISTINCT SLOTS in the table — a re-pin sets one without the
        # other, and that is what makes a one-line restore possible.
        self.assertEqual(ai_invoke.GROUPS["rust"]["even"], ai_invoke.GROUPS["rust"]["odd"])
        self.assertNotEqual(ai_invoke.GROUPS["rust"]["even"], LAG)

    def test_delayed_invocation_jumps_straight_to_latest_phase(self):
        self.write_epoch(1_000_000)
        # 13 hours later: must not replay the two missed toggles.
        self.assertEqual(ai_invoke.current_phase(1_000_000 + 13 * 3600, ai_invoke.read_epoch()), 3)
        self.assertEqual(ai_invoke.model_for("rust", 3), SB)

    def test_before_epoch_uses_phase_zero_and_is_marked(self):
        self.assertIsNone(ai_invoke.read_epoch())
        self.assertEqual(ai_invoke.current_phase(1_700_000_000, None), 0)
        self.fake_cmd(stdout=json.dumps(RESULT_FRAME) + "\n")
        self.run_invoke("rust")
        rec = self.invocations()[0]
        self.assertEqual(rec["model"], SB)
        self.assertTrue(rec["pre_epoch"])

    def test_command_line_carries_the_exact_model_id(self):
        self.write_epoch(1_000_000)
        self.fake_cmd(stdout=json.dumps(RESULT_FRAME) + "\n")
        self.run_invoke("rust", extra=["--now", str(1_000_000)])
        self.run_invoke("perl", extra=["--now", str(1_000_000)])
        argv_log = os.path.join(self.tmp, "argv.log")
        lines = open(argv_log).read()
        # The id must reach cmd VERBATIM — the source warns that a rejected id
        # is indistinguishable from a broken worker, and the qualified form is
        # the one pir also accepts (the bare form is ambiguous to it).
        self.assertIn(f"--model {SB}", lines)
        self.assertIn(f"--model {SB}", lines)  # both workers, same pinned model
        # The BARE id must never be the one passed: pir refuses an id that
        # exists in several providers, and the bare form is exactly that. A
        # substring check would false-alarm, because the bare form is a
        # substring of the qualified one — so assert on the token boundary.
        self.assertNotIn(f"--model {SB_BARE}", lines)
        self.assertIn("--output-format json", lines)

    def test_dry_run_reports_without_calling(self):
        self.write_epoch(1_000_000)
        pf = os.path.join(self.tmp, "p.txt")
        open(pf, "w").write("x")
        out = io.StringIO()
        with redirect_stdout(out):
            ai_invoke.main(["--worker", "c", "--prompt-file", pf, "--dry-run", "--now", str(1_000_000)])
        data = json.loads(out.getvalue())
        self.assertEqual(data["model"], SB)
        self.assertEqual(data["group"], "A")


class TestTelemetry(Base):
    def test_result_frame_is_parsed_into_tokens(self):
        self.write_epoch(1_000_000)
        self.fake_cmd(stdout=json.dumps(RESULT_FRAME) + "\n")
        self.run_invoke("rust")
        rec = self.invocations()[0]
        self.assertTrue(rec["telemetry"])
        self.assertEqual(rec["tokens"]["input"], 1000)
        self.assertEqual(rec["tokens"]["output"], 200)
        self.assertEqual(rec["duration_ms"], 12345)
        self.assertEqual(model_report.reported_tokens(rec), 1275)

    def test_missing_result_frame_is_null_not_zero(self):
        self.write_epoch(1_000_000)
        self.fake_cmd(stdout='{"type":"message"}\n')
        self.run_invoke("rust")
        rec = self.invocations()[0]
        self.assertFalse(rec["telemetry"])
        self.assertIsNone(model_report.reported_tokens(rec))

    def test_partial_usage_is_unknown_not_a_smaller_total(self):
        rec = {"tokens": {"input": 100, "output": None, "cache_read": 0, "cache_write": 0}}
        self.assertIsNone(model_report.reported_tokens(rec))

    def test_non_numeric_usage_is_ignored(self):
        parsed = ai_invoke.parse_result_line(json.dumps({"type": "result", "usage": {"inputTokens": "lots"}}))
        self.assertEqual(parsed["tokens"]["input"], None)

    def test_run_end_nextstate_blob_is_stripped(self):
        # cmd's run_end frame carries the whole workspace git status + message
        # history. Echoing it unbounded is the GB-scale log incident class.
        line = json.dumps({"type": "event", "event": {"type": "run_end", "result": {
            "finalText": "OK",
            "usage": {"inputTokens": 5, "outputTokens": 1},
            "nextState": {"messages": [{"role": "user", "content": "x" * 5000}]},
            "modState": {"workspace": {"gitStatus": "M " + "y" * 5000}},
        }}})
        out = ai_invoke.redact_for_log(line)
        self.assertNotIn("nextState", out)
        self.assertNotIn("modState", out)
        self.assertLess(len(out), len(line) // 10)
        # the usage telemetry survives — that is what we log it for
        self.assertIn("inputTokens", out)

    def test_small_run_end_frame_is_still_redacted(self):
        # A size-based early-out would wrongly keep this blob.
        line = '{"type":"event","event":{"type":"run_end","result":{"nextState":{"messages":["keepme"]}}}}'
        self.assertNotIn("keepme", ai_invoke.redact_for_log(line))

    def test_result_frame_is_never_redacted(self):
        line = json.dumps(RESULT_FRAME)
        self.assertEqual(ai_invoke.redact_for_log(line), line)


class TestQuotaFallback(Base):
    # The Laguna fallback can only be exercised by a worker whose PRIMARY is
    # Laguna, and no worker is any more (the fleet is pinned to Alpha). The
    # guard itself is unchanged and still load-bearing — it is what gives a
    # worker re-pinned to Laguna for the A/B its quota escape route back. So
    # these tests re-pin one worker in GROUPS for their duration and restore
    # it after, which is exactly the operation a real A/B run performs.
    def repin_to_laguna(self, worker: str):
        original = dict(ai_invoke.GROUPS[worker])
        ai_invoke.GROUPS[worker] = {"group": original["group"], "even": LAG, "odd": LAG}
        self.addCleanup(ai_invoke.GROUPS.__setitem__, worker, original)

    def test_laguna_quota_marker_switches_to_fallback(self):
        self.repin_to_laguna("perl")
        self.write_epoch(1_000_000)
        # First call emits the quota marker and fails; the fake then succeeds.
        bindir = os.path.join(self.tmp, "bin")
        os.makedirs(bindir, exist_ok=True)
        script = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$ARGV_LOG"
if [ -f "$SEEN" ]; then
  echo '{"type":"result","durationMs":1,"usage":{"inputTokens":1,"outputTokens":1,"cacheReadTokens":0,"cacheWriteTokens":0}}'
else
  touch "$SEEN"
  echo 'HTTP 429: Rate limit exceeded: free-models-per-day. Add 10 credits'
  exit 1
fi
"""
        path = os.path.join(bindir, "cmd")
        open(path, "w").write(script)
        os.chmod(path, 0o755)
        os.environ["PATH"] = bindir + os.pathsep + os.environ["PATH"]
        os.environ["ARGV_LOG"] = os.path.join(self.tmp, "argv.log")
        os.environ["SEEN"] = os.path.join(self.tmp, "seen")

        self.run_invoke("perl")
        argv = open(os.environ["ARGV_LOG"]).read()
        self.assertIn(f"--model {LAG}", argv)
        self.assertIn("--model ollama-cloud/deepseek-v4.1-flash", argv)
        rec = self.invocations()[0]
        self.assertTrue(rec["fallback_used"])
        self.assertEqual(rec["model"], "ollama-cloud/deepseek-v4.1-flash")
        self.assertEqual(rec["fallback_from"], LAG)

    def test_non_laguna_model_never_switches(self):
        self.write_epoch(1_000_000)
        bindir = os.path.join(self.tmp, "bin")
        os.makedirs(bindir, exist_ok=True)
        script = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$ARGV_LOG"
echo 'HTTP 429: Rate limit exceeded: free-models-per-day'
exit 1
"""
        path = os.path.join(bindir, "cmd")
        open(path, "w").write(script)
        os.chmod(path, 0o755)
        os.environ["PATH"] = bindir + os.pathsep + os.environ["PATH"]
        os.environ["ARGV_LOG"] = os.path.join(self.tmp, "argv.log")
        self.run_invoke("rust")
        argv = open(os.environ["ARGV_LOG"]).read()
        self.assertNotIn("deepseek", argv)
        rec = self.invocations()[0]
        self.assertFalse(rec["fallback_used"])
        self.assertEqual(rec["model"], SB)

    def test_plain_429_does_not_switch(self):
        self.write_epoch(1_000_000)
        bindir = os.path.join(self.tmp, "bin")
        os.makedirs(bindir, exist_ok=True)
        script = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "$ARGV_LOG"
echo 'HTTP 429: rate limit exceeded'
exit 1
"""
        path = os.path.join(bindir, "cmd")
        open(path, "w").write(script)
        os.chmod(path, 0o755)
        os.environ["PATH"] = bindir + os.pathsep + os.environ["PATH"]
        os.environ["ARGV_LOG"] = os.path.join(self.tmp, "argv.log")
        self.run_invoke("perl")
        argv = open(os.environ["ARGV_LOG"]).read()
        self.assertNotIn("deepseek", argv)

    def test_empty_fallback_model_disables_switch(self):
        # fallback_model() reads the env lazily, so an empty value really does
        # disable the switch without a module reload.
        self.assertEqual(ai_invoke.fallback_model(), "ollama-cloud/deepseek-v4.1-flash")
        os.environ["WORKER_FALLBACK_MODEL"] = ""
        self.assertEqual(ai_invoke.fallback_model(), "")


class TestEpochAndScoring(Base):
    def test_epoch_init_is_atomic_and_refuses_overwrite(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(model_report.main(["init-rotation", "--now", "1000000"]), 0)
        self.assertEqual(model_report.read_epoch(), 1_000_000)
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(model_report.main(["init-rotation", "--now", "2000000"]), 1)
        self.assertEqual(model_report.read_epoch(), 1_000_000)
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(model_report.main(["init-rotation", "--now", "2000000", "--reset"]), 0)
        self.assertEqual(model_report.read_epoch(), 2_000_000)

    def test_malformed_jsonl_line_warns_and_is_skipped(self):
        ai_invoke.append_jsonl(ai_invoke.invocations_path(), {"worker": "rust", "model": SB})
        with open(ai_invoke.invocations_path(), "a") as fh:
            fh.write("{not json\n")
        recs = model_report.load_jsonl(ai_invoke.invocations_path())
        self.assertEqual(len(recs), 1)

    def test_normalized_progress_and_token_efficiency(self):
        epoch = 1_000_000
        inv = [
            {"worker": "rust", "model": SB, "started_at": epoch, "ended_at": epoch + 3600,
             "tokens": {"input": 100, "output": 10, "cache_read": 0, "cache_write": 0}},
        ]
        gates = [
            {"worker": "rust", "corpus": "rust-648", "pass": 600, "fail": 48, "recorded_at": epoch},
            {"worker": "rust", "corpus": "rust-648", "pass": 620, "fail": 28, "recorded_at": epoch + 1800},
        ]
        spans = model_report.model_intervals("rust", inv, gates, epoch)
        self.assertEqual(len(spans), 1)
        s = spans[0]
        self.assertAlmostEqual(s["normalized"], 20 / 648)
        self.assertAlmostEqual(s["hours"], 1.0)
        # tokens are complete here, so they are summable
        self.assertEqual(s["tokens"], 110)

    def test_corpus_change_marks_normalized_unavailable(self):
        epoch = 1_000_000
        inv = [{"worker": "rust", "model": SB, "started_at": epoch, "ended_at": epoch + 3600, "tokens": None}]
        gates = [
            {"worker": "rust", "corpus": "a", "pass": 10, "fail": 5, "recorded_at": epoch},
            {"worker": "rust", "corpus": "b", "pass": 20, "fail": 1, "recorded_at": epoch + 1800},
        ]
        s = model_report.model_intervals("rust", inv, gates, epoch)[0]
        self.assertIsNone(s["normalized"])
        self.assertIn("corpus changed", s["reason"])

    def test_regression_keeps_negative_progress(self):
        epoch = 1_000_000
        inv = [{"worker": "c", "model": LAG, "started_at": epoch, "ended_at": epoch + 3600, "tokens": None}]
        gates = [
            {"worker": "c", "corpus": "c-647", "pass": 500, "fail": 100, "recorded_at": epoch},
            {"worker": "c", "corpus": "c-647", "pass": 495, "fail": 105, "recorded_at": epoch + 1800},
        ]
        s = model_report.model_intervals("c", inv, gates, epoch)[0]
        self.assertEqual(s["normalized"], -5 / 600)

    def test_skips_do_not_enter_the_denominator(self):
        epoch = 1_000_000
        inv = [{"worker": "perl", "model": LAG, "started_at": epoch, "ended_at": epoch + 3600, "tokens": None}]
        gates = [
            {"worker": "perl", "corpus": "perl-555", "pass": 500, "fail": 50, "skip": 5, "recorded_at": epoch},
            {"worker": "perl", "corpus": "perl-555", "pass": 510, "fail": 45, "skip": 5, "recorded_at": epoch + 1800},
        ]
        s = model_report.model_intervals("perl", inv, gates, epoch)[0]
        # (50-45)/(500+50) = 5/550, NOT 5/555.
        self.assertAlmostEqual(s["normalized"], 5 / 550)

    def test_missing_start_gate_is_unknown(self):
        epoch = 1_000_000
        inv = [{"worker": "estree", "model": LAG, "started_at": epoch, "ended_at": epoch + 3600, "tokens": None}]
        gates = [{"worker": "estree", "corpus": "e", "pass": 5, "fail": 5, "recorded_at": epoch + 1800}]
        s = model_report.model_intervals("estree", inv, gates, epoch)[0]
        self.assertIsNone(s["normalized"])

    def test_report_withholds_ranking_until_both_models_observed(self):
        self.write_epoch(1_000_000)
        ai_invoke.append_jsonl(ai_invoke.invocations_path(), {
            "worker": "rust", "model": SB, "started_at": 1_000_000, "ended_at": 1_000_100,
            "tokens": {"input": 1, "output": 1, "cache_read": 0, "cache_write": 0}, "pre_epoch": False,
        })
        out = io.StringIO()
        with redirect_stdout(out):
            model_report.main(["report", "--now", str(1_000_500)])
        self.assertIn("NOT RANKING YET", out.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
