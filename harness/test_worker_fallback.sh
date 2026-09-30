#!/usr/bin/env bash
# harness/test_worker_fallback.sh — Laguna daily-quota fallback tests.
#
# No paid calls: a fake `cmd` on PATH plays the role of a quota-exhausted
# provider. Pass/fail counted, mirroring harness/test_core_rollback.sh.
set -u
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }

# ── 1. Perl module semantics ──────────────────────────────────────────
echo "--- ai_fallback.pm detection ---"
perl -I harness -e '
use strict; use warnings; use ai_fallback;

my $LAG = $ai_fallback::LAGUNA_MODEL;
my $FB  = $ai_fallback::FALLBACK_MODEL;

# The exact quota marker switches for Laguna only.
die "laguna fallback missing\n" unless ai_fallback::ai_fallback_for($LAG) eq $FB;
die "space-bunny must have no fallback\n"
    if defined ai_fallback::ai_fallback_for("stealth/space-bunny-alpha");

# Near-miss errors must NOT match.
for my $bad (
    "HTTP 429: rate limit exceeded",
    "You have exceeded your weekly usage limit",
    "insufficient_quota / billing problem",
    "HTTP 500: internal server error",
    "request timed out after 3600s",
) {
    die "should not match: $bad\n" if defined ai_fallback::quota_marker($bad);
}
die "should match the real marker\n"
    unless ai_fallback::quota_marker("HTTP 429: Rate limit exceeded: free-models-per-day. Add 10 credits");

# The switch is one-way: a second switch must not move back.
my $sw = ai_fallback::QuotaSwitch->new($LAG);
my $first  = $sw->switch_to(undef);
my $second = $sw->switch_to(undef);
die "first switch wrong: $first\n"  unless $first  eq $FB;
die "second switch oscillated: $second\n" unless $second eq $FB;
die "switched flag wrong\n" unless $sw->switched;
die "from-model wrong\n" unless $sw->from eq $LAG;

# A non-Laguna model has nothing to switch to.
my $sw2 = ai_fallback::QuotaSwitch->new("stealth/space-bunny-alpha");
die "non-laguna should not switch\n" unless $sw2->switch_to(undef) eq "stealth/space-bunny-alpha";
die "non-laguna marked switched\n" if $sw2->switched;

print "PERL_OK\n";
' > "$TMP/perl.out" 2>"$TMP/perl.err"
if grep -q PERL_OK "$TMP/perl.out"; then
  ok "ai_fallback.pm: marker, near-misses, one-way switch"
else
  bad "ai_fallback.pm semantics" "$(head -3 "$TMP/perl.err" | tr '\n' ' ')"
fi

# ── 2. ai_invoke.py end-to-end switch (fake cmd) ─────────────────────
echo "--- ai_invoke.py quota switch ---"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/cmd" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARGV_LOG"
if [ -f "$SEEN" ]; then
  echo '{"type":"result","durationMs":5,"usage":{"inputTokens":10,"outputTokens":2,"cacheReadTokens":0,"cacheWriteTokens":0}}'
else
  touch "$SEEN"
  echo 'HTTP 429: Rate limit exceeded: free-models-per-day. Add 10 credits'
  exit 1
fi
FAKE
chmod +x "$TMP/bin/cmd"
export ARGV_LOG="$TMP/argv.log" SEEN="$TMP/seen"
export WORKER_MODEL_DIR="$TMP/.worker-model"

# The fleet is PINNED to Space Bunny Alpha (2026-09-30), so no worker's
# primary is Laguna and the switch — which is guarded on `model == LAGUNA` —
# can never fire. That guard is deliberate and still load-bearing: it is what
# gives a worker re-pinned to Laguna for the A/B its quota escape route back.
# To exercise it here, override the id the pin resolves to, which is the same
# switch an operator flips to run one worker on Laguna.
export WORKER_SPACE_BUNNY_MODEL='poolside/laguna-s-2.1-free'

printf 'fix it\n' > "$TMP/prompt.txt"
( PATH="$TMP/bin:$PATH" python3 harness/ai_invoke.py --worker perl --prompt-file "$TMP/prompt.txt" ) >/dev/null 2>&1

if grep -q 'poolside/laguna-s-2.1-free' "$ARGV_LOG" && grep -q 'ollama-cloud/deepseek-v4.1-flash' "$ARGV_LOG"; then
  ok "quota marker switches the same prompt to the fallback"
else
  bad "quota switch did not happen" "$(tr '\n' ' ' < "$ARGV_LOG")"
fi

if [ "$(grep -c 'model' "$ARGV_LOG")" = "2" ]; then
  ok "exactly one switch (two invocations, no oscillation)"
else
  bad "expected exactly 2 invocations" "$(wc -l < "$ARGV_LOG")"
fi

if python3 -c "
import json,sys
recs=[json.loads(l) for l in open('$WORKER_MODEL_DIR/invocations.jsonl')]
r=recs[-1]
sys.exit(0 if r['fallback_used'] and r['model']=='ollama-cloud/deepseek-v4.1-flash' else 1)
" 2>/dev/null; then
  ok "invocation record marks fallback_used and the fallback model"
else
  bad "invocation record wrong"
fi

# ── 3. Non-Laguna model must never switch ────────────────────────────
echo "--- non-Laguna never switches ---"
# Drop the override: every worker is back on the pinned Alpha, so the quota
# marker must NOT move it. Switching Alpha on a transient 429 would suppress
# its own retry and leave the worker with no model at all.
unset WORKER_SPACE_BUNNY_MODEL
rm -f "$ARGV_LOG" "$SEEN"; : > "$ARGV_LOG"
cat > "$TMP/bin/cmd" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARGV_LOG"
echo 'HTTP 429: Rate limit exceeded: free-models-per-day'
exit 1
FAKE
chmod +x "$TMP/bin/cmd"
echo "1000000" > "$WORKER_MODEL_DIR/epoch"
( PATH="$TMP/bin:$PATH" python3 harness/ai_invoke.py --worker rust --prompt-file "$TMP/prompt.txt" --now 1000000 ) >/dev/null 2>&1
if ! grep -q 'deepseek' "$ARGV_LOG"; then
  ok "space-bunny quota marker does NOT switch models"
else
  bad "space-bunny incorrectly switched to the fallback"
fi

# ── 4. Plain 429 must not switch ─────────────────────────────────────
echo "--- near-miss errors do not switch ---"
for msg in "HTTP 429: rate limit exceeded" \
           "You have exceeded your weekly usage limit" \
           "insufficient_quota: add credits" \
           "HTTP 503: service unavailable"; do
  rm -f "$ARGV_LOG" "$SEEN"; : > "$ARGV_LOG"
  cat > "$TMP/bin/cmd" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\$ARGV_LOG"
echo '$msg'
exit 1
FAKE
  chmod +x "$TMP/bin/cmd"
  echo "1000001" > "$WORKER_MODEL_DIR/epoch"   # odd phase -> perl/estree get space-bunny... force laguna instead
  # use estree on an even phase so the model IS laguna
  echo "1000000" > "$WORKER_MODEL_DIR/epoch"
  ( PATH="$TMP/bin:$PATH" python3 harness/ai_invoke.py --worker estree --prompt-file "$TMP/prompt.txt" --now 1000000 ) >/dev/null 2>&1
  if grep -q 'deepseek' "$ARGV_LOG"; then
    bad "incorrectly switched on: $msg"
  else
    ok "no switch on: ${msg:0:40}"
  fi
done

# ── 5. WORKER_FALLBACK_MODEL= disables the switch ────────────────────
echo "--- empty fallback disables ---"
rm -f "$ARGV_LOG" "$SEEN"; : > "$ARGV_LOG"
cat > "$TMP/bin/cmd" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARGV_LOG"
if [ -f "$SEEN" ]; then exit 0; fi
touch "$SEEN"
echo 'HTTP 429: Rate limit exceeded: free-models-per-day'
exit 1
FAKE
chmod +x "$TMP/bin/cmd"
( PATH="$TMP/bin:$PATH" WORKER_FALLBACK_MODEL= python3 harness/ai_invoke.py --worker estree --prompt-file "$TMP/prompt.txt" --now 1000000 ) >/dev/null 2>&1
if [ "$(grep -c model "$ARGV_LOG")" = "1" ]; then
  ok "empty WORKER_FALLBACK_MODEL disables the fallback"
else
  bad "fallback ran despite empty WORKER_FALLBACK_MODEL" "$(wc -l < "$ARGV_LOG")"
fi

echo ""
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" -eq 0 ]
