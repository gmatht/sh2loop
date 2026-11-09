#!/usr/bin/env bash
# quota-trap-signal.sh — did the bytes THIS AI attempt appended carry a
# provider QUOTA signal (as opposed to any evidence about the build)?
#
# usage: quota-trap-signal.sh <log> [<byte-offset>]
#   exit 0 = a quota signal is present in the examined window
#   exit 1 = no quota signal (or the log cannot be read)
#
# The caller (setup_backends.sh --run-backend-worker) snapshots the log length
# BEFORE the AI attempt and passes that offset here, so only the bytes the
# attempt added are examined. A whole-log grep is wrong twice over: historical
# 429s make every future trap unreachable (including a genuine build break),
# and the phrase "rate limit" inside a quoted tool result is not an error at
# all. `--pi-fix-backend` always exits 0, so log text is the only signal.
#
# This lives in its own script so the pattern set AND the read are testable —
# see harness/test_quota_trap_signal.sh. Inline in setup_backends.sh they were
# not, and that is how the bug below survived unmeasured.
#
# ── THE BUG THIS PINS (2026-10-25, go worker) ─────────────────────────
# The check used to be
#
#     tail -c "+$((_pre_off + 1))" "$LOG" | grep -qE '<patterns>' && _quota_hit=1
#
# under the script's `set -euo pipefail`. `grep -q` exits at the FIRST match,
# so `tail` — still writing a multi-megabyte window — dies on EPIPE, and
# pipefail turns the pipeline into 141. The `&&` therefore never ran and
# `_quota_hit` stayed 0 even when the window was full of quota text.
# Measured: a 1 KB window returns 0; a 2 MB window returns 141.
#
# That is exactly what trapped the go worker. Attempt 3 (2026-10-25
# 03:44:28 -> 03:59:46) appended a 3,628,660-byte window containing 8x
# "HTTP 429", 3x "GoUsageLimitError" and the harness's own fallback line
# ("... hit a daily quota wall (rc=5) — switching this worker to ...") — the
# old pattern matched all of them and the check still reported "no quota",
# because tail had 3.6 MB left to write when grep quit. The counter reached
# 3 and the worker trapped on a build break that never existed: both the core
# and the worktree's shir_render built clean (`cargo build` Finished; see the
# escalation core-requests/go-20261025-035947.md). The smaller historical
# windows are why the detector DID fire before (15 cooldown lines in that
# same log): tail finished first, so the pipeline reported grep's status.
#
# TWO independent fixes are shipped here, because either one alone would have
# left the worker trappable:
#   1. read to EOF instead of exiting early — no EPIPE, so the pipeline status
#      is grep's status regardless of pipefail. This is the load-bearing fix.
#   2. recognize the fleet's own fallback wordings (see the pattern note
#      below), so an attempt blocked by a quota wall says so in its own words.
set -u

log="${1:?usage: quota-trap-signal.sh <log> [<byte-offset>]}"
offset="${2:-0}"

[ -r "$log" ] || exit 1
case "$offset" in ''|*[!0-9]*) offset=0;; esac

# `grep -a` without `-q`, and stdout discarded, ON PURPOSE — see fix 1 above.
# `-q` is what closed the pipe early. Reading to EOF costs one pass over the
# attempt's own window (single-digit MB) and buys a status that means what it
# says; a detector that can only say "no" is worse than no detector.
#
# `command grep` because an interactive shell here may define `grep` as a
# ripgrep wrapper whose flags are not GNU grep's (AGENTS.md).
#
# The provider wordings were observed live, not guessed:
#   - "HTTP 429"                    OpenRouter / most providers
#   - "free-models-per-day"         OpenRouter's exact daily-free error
#   - "reached today's limit"       Glyph Cluster (cmd exits rc=5)
#   - "currently at capacity", "is unavailable for free",
#     "free tier can only be used"  worker_common.sh's fallback triggers
#   - "hit a daily quota wall"      the fallback line worker_common.sh WRITES
#                                   (2026-10-25: it was not in this list, so
#                                   a quota-blocked attempt read as a build
#                                   failure)
# The last two classes are the harness talking about itself rather than the
# provider, which is deliberate: they are the only evidence a blocked attempt
# leaves behind.
tail -c "+$((offset + 1))" "$log" 2>/dev/null | command grep -aE \
  'HTTP 429|GoUsageLimitError|quota.?blocked|quota.?exhausted|quota.?wall|rate.?limit exceeded|free-models-per-day|reached today.s limit|FreeTierError|currently at capacity|is unavailable for free|free tier can only be used' \
  >/dev/null
