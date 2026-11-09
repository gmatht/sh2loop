#!/usr/bin/env bash
# harness/test_quota_trap_signal.sh — pins the trap-decision quota detector.
#
# THE BUG (2026-10-25, go worker). The detector was
#     tail -c "+N" "$LOG" | grep -qE '<patterns>' && _quota_hit=1
# under `set -euo pipefail`. `grep -q` exits at the first match, `tail` dies on
# EPIPE with megabytes still to write, and pipefail turns the pipeline into
# 141 — so `_quota_hit` stayed 0 on exactly the attempts that carried the most
# quota evidence. The go attempt's window was 3.6 MB with 11 matches; the
# worker trapped on a build break that did not exist.
#
# Case 7 is the load-bearing one: it reproduces 141 on the pre-fix reader and
# requires the shipped detector to answer 0 under the same shell options.
# Case 2 covers the pattern side (the harness's own fallback line).
set -u
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
n=0

ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

H=harness/quota-trap-signal.sh
[ -x "$H" ] || { echo "FATAL: $H missing or not executable"; exit 1; }

# One fresh scratch dir per case: a leftover from the previous case must never
# be able to make the next one pass (or fail) for the wrong reason.
# NOTE: never call this through a command substitution (`d=$(fresh)`) — that is a
# subshell, so the case counter would never advance and every case would share
# one directory. That bug was in the first draft of this test and made case 7
# read case 7b's file.
newdir() { n=$((n+1)); NEW="$TMP/case$n"; mkdir -p "$NEW"; }

# The exact line harness/worker_common.sh writes on a quota fallback (verified
# in loop-backend-go.log: 2026-10-24T20:13:36 and 2026-10-24T22:51:22).
FALLBACK_LINE='[2026-10-24T20:13:36] fallback: commandcode/stealth/glyph-cluster:free hit a daily quota wall (rc=5) — switching this worker to ollama-cloud/deepseek-v4.1-flash'

# ── 1. The pattern list that shipped before the fix must MISS it ─────
echo "--- old pattern list vs the real fallback line ---"
newdir; d=$NEW
printf '%s\n' "$FALLBACK_LINE" > "$d/log"
if command grep -qaE 'HTTP 429|GoUsageLimitError|quota.?blocked|quota.?exhausted|rate.?limit exceeded' "$d/log"; then
  bad "the old pattern list matched the fallback line — this test no longer pins the bug"
else
  ok "old pattern list misses 'hit a daily quota wall'"
fi

# ── 2. The shipped detector must HIT it ──────────────────────────────
echo "--- shipped detector vs the real fallback line ---"
newdir; d=$NEW
printf '%s\n' "$FALLBACK_LINE" > "$d/log"
if "$H" "$d/log" 0; then
  ok "detector recognizes the harness's own 'daily quota wall' fallback line"
else
  bad "detector MISSES the fallback line — a quota-blocked attempt would trap again"
fi

# ── 3. Offset discipline: historical bytes must not count ────────────
# The caller snapshots the log length before the attempt. A wall from an
# earlier attempt must not suppress a later, genuine trap.
echo "--- offset discipline ---"
newdir; d=$NEW
{ printf '%s\n' "$FALLBACK_LINE"; printf 'build FAILED: error[E0308]: mismatched types\n'; } > "$d/log"
off=$(printf '%s\n' "$FALLBACK_LINE" | wc -c)
if "$H" "$d/log" "$off"; then
  bad "a quota line BEFORE the offset was counted as this attempt's signal"
else
  ok "quota line before the offset is ignored"
fi
if "$H" "$d/log" 0; then
  ok "same quota line inside the window is counted"
else
  bad "quota line inside the window was not counted"
fi

# ── 4. A genuine build failure must NOT read as quota ────────────────
echo "--- a real build break still traps ---"
newdir; d=$NEW
cat > "$d/log" <<'EOF'
error[E0308]: mismatched types
  --> src/shir.rs:120:9
error: could not compile `debashl` (lib) due to 1 previous error
[2026-10-25T03:44:24] [go] backend gate: core build FAILED
EOF
if "$H" "$d/log" 0; then
  bad "a plain compiler error was classified as a quota signal — a real break would never trap"
else
  ok "compiler error alone is not a quota signal"
fi

# A tool result quoting the phrase must not be read as a wall either; only the
# observed provider/fallback wordings are signals.
newdir; d=$NEW
printf 'tool result: the docs say "this rate limit is per key"\n' > "$d/log"
if "$H" "$d/log" 0; then
  bad "bare 'rate limit' text was classified as a quota signal"
else
  ok "bare 'rate limit' prose is not a quota signal"
fi

# ── 5. Every wording that WAS recognized still is ────────────────────
echo "--- previously recognized walls still match ---"
newdir; d=$NEW
for msg in 'HTTP 429: Too Many Requests' \
           'GoUsageLimitError: no tokens left' \
           'HTTP 429: Rate limit exceeded: free-models-per-day. Add 10 credits' \
           "Error: You've reached today's limit on Glyph Cluster. Resets in 7h"; do
  printf '%s\n' "$msg" > "$d/log"
  if "$H" "$d/log" 0; then
    ok "still matches: ${msg:0:44}"
  else
    bad "no longer matches: $msg"
  fi
done

# ── 6. Empty / unreadable input answers "no", never a crash ──────────
echo "--- degenerate input ---"
newdir; d=$NEW
: > "$d/log"
if "$H" "$d/log" 0; then
  bad "an empty window reported a quota signal"
else
  ok "empty window is not a quota signal"
fi
if "$H" "$d/missing.log" 0; then
  bad "a missing log reported a quota signal"
else
  ok "missing log is not a quota signal"
fi
if "$H" "$d/log" 'not-a-number' >/dev/null 2>&1; then
  bad "a non-numeric offset reported a quota signal"
else
  ok "non-numeric offset is handled"
fi

# ── 7. THE EPIPE BUG: a large window under `set -uo pipefail` ────────
# The caller runs under `set -euo pipefail`. A `grep -q` reader exits at the
# first match and the still-writing `tail` dies on EPIPE (141), which pipefail
# reports as the pipeline's status. The window must exceed the 64 KiB pipe
# buffer for this to be deterministic, which the real go window (3.6 MB) and
# this fixture both do.
echo "--- large window under pipefail (the 2026-10-25 trap) ---"
newdir; d=$NEW
{ printf '%s\n' "$FALLBACK_LINE"
  for i in $(seq 1 60000); do printf 'filler line %s of the attempt transcript\n' "$i"; done
} > "$d/log"
sz=$(stat -c %s "$d/log")

# Pre-fix reader, reproduced verbatim: it must FAIL here, or this case is not
# pinning anything.
rc=$(bash -c 'set -uo pipefail; tail -c "+1" "$1" 2>/dev/null | grep -qE "HTTP 429|quota.?wall" >/dev/null; echo $?' _ "$d/log")
if [ "$rc" = "141" ]; then
  ok "pre-fix reader returns 141 (EPIPE) on a $((sz/1024)) KB window"
elif [ "$rc" = "0" ]; then
  bad "pre-fix reader returned 0 on $((sz/1024)) KB — the EPIPE bug did not reproduce here"
else
  bad "pre-fix reader returned unexpected $rc on $((sz/1024)) KB"
fi

# A large window whose only evidence is a build error must still answer "no",
# so the fix cannot be "always say quota".
newdir; d2=$NEW
{ printf 'error[E0308]: mismatched types\n'
  for i in $(seq 1 60000); do printf 'filler line %s of the attempt transcript\n' "$i"; done
} > "$d2/log"
rc=$(bash -c 'set -uo pipefail; "$1" "$2" 0; echo $?' _ "$H" "$d2/log")
if [ "$rc" = "1" ]; then
  ok "large build-error window answers 1 (not quota)"
else
  bad "large build-error window answered $rc (want 1)"
fi

# The shipped detector under the caller's own shell options: this is the case
# that failed before the fix (it answered 141 -> the trap fired).
rc=$(bash -c 'set -uo pipefail; "$1" "$2" 0; echo $?' _ "$H" "$d/log")
if [ "$rc" = "0" ]; then
  ok "detector answers 0 on the 3.6MB-class window under pipefail"
else
  bad "detector answered $rc on a $((sz/1024)) KB window under pipefail (want 0)"
fi

# ── 8. The call site must actually use the detector ──────────────────
echo "--- call-site wiring ---"
if command grep -q 'harness/quota-trap-signal.sh' setup_backends.sh; then
  ok "setup_backends.sh calls harness/quota-trap-signal.sh"
else
  bad "setup_backends.sh does not call the detector — the fix is unwired"
fi
if command grep -q "quota.?exhausted|rate.?limit exceeded" setup_backends.sh; then
  bad "the old inline pattern list is still in setup_backends.sh (two sources of truth)"
else
  ok "no duplicate inline pattern list left in setup_backends.sh"
fi
if bash -n setup_backends.sh 2>/dev/null; then
  ok "setup_backends.sh parses (bash -n)"
else
  bad "setup_backends.sh does not parse"
fi
if bash -n "$H" 2>/dev/null; then
  ok "quota-trap-signal.sh parses (bash -n)"
else
  bad "quota-trap-signal.sh does not parse"
fi

echo ""
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
