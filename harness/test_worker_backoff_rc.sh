#!/bin/bash
# harness/test_worker_backoff_rc.sh — the retry loop must report the AI CLI's
# REAL exit code, not the `if` statement's.
#
# WHY THIS TEST EXISTS. `invoke_ai_with_backoff` in harness/worker_common.sh
# used to read the status like this:
#
#     if invoke_ai "$prompt_file" "$log_file"; then
#       return 0
#     fi
#     local rc=$?          # <-- the status of the COMPOUND statement
#
# In bash, `if cmd; then ...; fi` with a false condition and no `else` yields
# 0. So every hard failure logged as `rc=0` — indistinguishable from a
# transient blip — and the `while true` loop (documented "NEVER gives up")
# retried a deterministic, never-going-to-succeed error forever.
#
# Observed on 2026-10-01: the perl worker logged `pir failed (rc=0, attempt
# 1..120)` over ~20 hours, every attempt being `pir: no model matches
# 'commandcode/stealth/space-bunny-alpha'`. pir's real exit code there is 1.
# Nothing alerted, because the log looked benign.
#
# WHAT THIS PINS. Two things, because either alone is insufficient:
#   1. RUNTIME: the shipped `invoke_ai_with_backoff` reports invoke_ai's rc.
#      The loop is unbounded, so the test runs it under a `timeout` and reads
#      the log it writes; a correct implementation emits `rc=1 attempt=1`
#      within the first tick.
#   2. STATIC: the capture sits in an `else` branch on the same command.
#      Runtime alone would not catch the capture being moved back out to the
#      line after the `fi`, and static alone would not catch a refactor that
#      dropped the else entirely.
set -u

ROOT="${ROOT:-/home/llm/sh2loop}"
COMMON="$ROOT/harness/worker_common.sh"
LOG="$(mktemp)"
PROMPT="$(mktemp)"
trap 'rm -f "$LOG" "$PROMPT" "$LOG.probe"' EXIT

fail=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

[ -f "$COMMON" ] || { echo "missing $COMMON" >&2; exit 1; }

# ── 1. RUNTIME: drive the SHIPPED function with a failing invoke_ai ───────
# Sourced in a subshell so the override does not leak. `invoke_ai` is
# redefined AFTER sourcing, which is the seam the real code calls.
#
# The real loop never returns, so `timeout` kills it after a few ticks; the
# proof is in the log lines it wrote, not in its exit status. BACKOFF_BASE is
# pinned low so two attempts land inside the timeout.
rm -f "$LOG.probe"
(
  # shellcheck disable=SC1090
  . "$COMMON"
  check_context_budget() { return 0; }
  invoke_ai() { return 1; }                       # pir's real rc on a hard failure
  BACKOFF_BASE=0
  BACKOFF_MAX=0
  invoke_ai_with_backoff "$PROMPT" "$LOG.probe"
) >/dev/null 2>&1 &
loop_pid=$!

# Wait for the first log line, then stop the unbounded loop.
for _ in $(seq 1 40); do
  [ -s "$LOG.probe" ] && break
  sleep 0.25
done
sleep 0.5
kill "$loop_pid" 2>/dev/null
wait "$loop_pid" 2>/dev/null

runtime_line="$(head -1 "$LOG.probe" 2>/dev/null)"
# The real line carries a [timestamp] prefix and a trailing ", retry in Ns";
# the load-bearing part is `rc=1` vs the `rc=0` of the bug.
if printf '%s' "$runtime_line" | command grep -q 'pir failed (rc=1, attempt 1)'; then
  ok "shipped invoke_ai_with_backoff logs rc=1 for a failing invoke_ai"
elif printf '%s' "$runtime_line" | command grep -q 'pir failed (rc=0, attempt 1)'; then
  bad "shipped loop logged rc=0 — it is reading the if-statement, not invoke_ai"
else
  bad "shipped loop logged '$runtime_line', want 'rc=1, attempt 1'"
fi

# ── 2. STATIC: the capture must be in an else on the same command ────────
if awk '
  /^[[:space:]]*if invoke_ai/ { inif=1; next }
  inif && /^[[:space:]]*else[[:space:]]*$/ { seen_else=1; next }
  inif && /rc=\$\?/          { found=1; inif=0 }
  END { exit (seen_else && found) ? 0 : 1 }
' "$COMMON"; then
  ok "the rc capture is inside an else branch on the invoke_ai command"
else
  bad "the rc capture is not in an else branch on the invoke_ai command"
fi

# ── 3. STATIC: no bare `local rc=$?` after a finished `if` ────────────────
# Catches the exact original shape being reintroduced.
if awk '
  /^[[:space:]]*if invoke_ai/ { inif=1; want=NR+1; next }
  inif && want && NR==want && /local rc=\$\?/ { print "bare capture at " NR > "/dev/stderr"; bad=1 }
  inif && /^[[:space:]]*fi[[:space:]]*$/ { inif=0; want=0 }
  END { exit bad ? 1 : 0 }
' "$COMMON" 2>/dev/null; then
  ok "no bare 'local rc=\$?' on the line after a finished if"
else
  bad "a bare 'local rc=\$?' follows a finished if — that reads the compound status"
fi

# ── 4. The success path still returns 0 ──────────────────────────────────
rm -f "$LOG.probe"
(
  # shellcheck disable=SC1090
  . "$COMMON"
  check_context_budget() { return 0; }
  invoke_ai() { return 0; }
  invoke_ai_with_backoff "$PROMPT" "$LOG.probe"
) >/dev/null 2>&1
if [ ! -s "$LOG.probe" ]; then
  ok "a succeeding invoke_ai returns 0 without logging a failure"
else
  bad "a succeeding invoke_ai logged a failure: $(head -1 "$LOG.probe")"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "test_worker_backoff_rc: PASS"
  exit 0
fi
echo "test_worker_backoff_rc: FAIL ($fail)"
exit 1