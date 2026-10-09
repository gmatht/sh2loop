#!/usr/bin/env bash
# harness/test_worker_opencode.sh — the `opencode` WORKER_CLI backend.
#
# No paid calls, and no real provider calls either: a fake `opencode` script
# stands in for the client, exactly as harness/test_worker_fallback.sh uses a
# fake `cmd`. Every assertion here is about the ARGV and the control flow the
# backend produces, plus the two error-detection helpers — the parts that are
# easy to get wrong and expensive to debug on the fleet.
#
# WHY THIS EXISTS. Adding a CLI backend touches three things that must agree
# and cannot drift: the argv the client needs, the failure signal it does (and
# does not) give us, and the quota-fallback target, which must be reachable BY
# THE SAME CLIENT. Each of those was measured against the real binary on
# 2026-10-09; these tests pin the conclusions so a later edit cannot silently
# undo them.
set -u
cd "$(dirname "$0")/.."

PASS=0
FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '       %s\n' "$2"; }
check(){ if [ "$2" = "$3" ]; then ok "$1 [$2]"; else bad "$1 (got '$2', want '$3')"; fi; }

# A fake opencode that records its argv and emits a scripted reply.
FAKE="$TMP/opencode"
write_fake() { # <output> <rc>
  # NOTE: the reply and rc are baked in HERE (quoted heredoc), and $TMP is
  # baked in by unquoted expansion — the script records argv and echoes a
  # fixed reply. It must NOT consume stdin: a fake that reads stdin would
  # hang when the backend passes a positional prompt, and would mask the
  # very bug these argv tests exist to catch.
  cat > "$FAKE" <<EOS
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/argv.txt"
printf '%s' '$1'
exit $2
EOS
  chmod +x "$FAKE"
}
write_fake 'PROBE-REPLY' 0
: > "$TMP/argv.txt"

export WORKSPACE="$(pwd)"
export WORKER_OPENCODE_BIN="$FAKE"

# ── 1. the backend exists at all ──────────────────────────────────────
echo "--- the opencode backend is reachable ---"
# The old dispatch hard-failed on anything but pi|pir|cmd. If this regresses,
# `WORKER_CLI=opencode` silently runs no AI at all.
if command grep -q '^    opencode)' harness/worker_common.sh; then
  ok "invoke_ai dispatches an opencode case"
else
  bad "no opencode case in invoke_ai dispatch"
fi
if command grep -q 'expected pi|pir|cmd|opencode' harness/worker_common.sh; then
  ok "the unknown-CLI error names opencode"
else
  bad "the unknown-CLI error still says 'expected pi|pir|cmd'"
fi

# ── 2. argv shape (the part that cannot be guessed) ───────────────────
echo "--- argv: headless shape and provider-qualified model ---"
export WORKER_CLI=opencode
source harness/worker_common.sh
printf 'do a thing\n' > "$TMP/p.txt"
: > "$TMP/log.txt"
: > "$TMP/argv.txt"
WORKER_OPENCODE_MODEL='opencode/longcat-2.5-preview-free' \
  invoke_ai "$TMP/p.txt" "$TMP/log.txt" >/dev/null 2>&1
ARGV=$(cat "$TMP/argv.txt")
case "$ARGV" in
  run\ --format\ json\ -m\ opencode/longcat-2.5-preview-free*)
    ok "argv starts with: run --format json -m <provider/model>" ;;
  *) bad "unexpected argv: $ARGV" ;;
esac
# `opencode run` has no --no-session / --yolo / --tools-all (verified against
# `opencode run --help`); passing them would make it exit on a usage error.
for f in --no-session --yolo --tools-all; do
  case "$ARGV" in
    *"$f"*) bad "argv passes cmd-only flag $f (opencode would reject it)" ;;
    *) ok "argv does not pass cmd-only flag $f" ;;
  esac
done
# The prompt is POSITIONAL. Piping it on stdin (which is what cmd does for a
# large prompt) is the pir bug all over again: the client starts with no prompt.
if [ -f "$TMP/argv.txt" ]; then
  if command grep -q 'do a thing' "$TMP/argv.txt"; then
    ok "prompt is passed positionally"
  else
    bad "prompt was not passed positionally"
  fi
fi

# ── 3. the big-prompt path hands over a file-reading instruction ──────
echo "--- a >100KB prompt is handed over as a file to read ---"
python3 -c "open('$TMP/big.txt','w').write('x'*200000)"
: > "$TMP/argv.txt"
invoke_ai "$TMP/big.txt" "$TMP/log.txt" >/dev/null 2>&1
if command grep -q "Read the full task instructions from" "$TMP/argv.txt"; then
  ok "large prompt becomes a read-the-file instruction (no truncation)"
else
  bad "large prompt did not use the read-the-file path"
fi

# ── 4. failure detection: the error shapes actually observed ──────────
echo "--- hard-failure detection (opencode can fail loudly) ---"
printf 'Error: Upstream request failed: Model is unavailable.\n' > "$TMP/e1"
printf '{"type":"error","error":{"name":"UnknownError","data":{"message":"boom"}}}\n' > "$TMP/e2"
printf '{"type":"text","part":{"text":"all fine"}}\n' > "$TMP/e3"
check "unavailable-model line detected" "$(_opencode_failed_in_log "$TMP/e1" && echo y || echo n)" "y"
check "UnknownError frame detected"     "$(_opencode_failed_in_log "$TMP/e2" && echo y || echo n)" "y"
check "a successful turn is NOT flagged" "$(_opencode_failed_in_log "$TMP/e3" && echo y || echo n)" "n"

# ── 5. quota detection covers opencode's own wording ──────────────────
echo "--- quota-wall detection now covers the opencode free tier ---"
printf '{"type":"error","error":{"type":"FreeTierError","message":"OpenCode'"'"'s free tier can only be used from within OpenCode"}}\n' > "$TMP/q1"
printf 'Error: This model is unavailable for free. The paid version is available now\n' > "$TMP/q2"
printf 'Error: You'"'"'ve reached today'"'"'s limit on Glyph Cluster.\n' > "$TMP/q3"
printf '{"type":"text","part":{"text":"ok"}}\n' > "$TMP/q4"
check "FreeTierError is a quota wall"        "$(_quota_wall_in_log "$TMP/q1" && echo y || echo n)" "y"
check "unavailable-for-free is a quota wall" "$(_quota_wall_in_log "$TMP/q2" && echo y || echo n)" "y"
check "glyph daily limit still detected"     "$(_quota_wall_in_log "$TMP/q3" && echo y || echo n)" "y"
check "normal output is not a quota wall"    "$(_quota_wall_in_log "$TMP/q4" && echo y || echo n)" "n"

# ── 6. the fallback target must be reachable by the SAME client ───────
echo "--- opencode falls back WITHIN the free tier, not to ollama ---"
# The bug this pins: WORKER_FALLBACK_MODEL is `ollama-cloud/…`, which is NOT in
# the opencode catalog. Falling back to it would turn one quota wall into an
# unknown-model error on every later call — strictly worse than the wall.
if command grep -q 'WORKER_OPENCODE_FALLBACK_MODEL' harness/worker_common.sh; then
  ok "there is an opencode-specific fallback model"
else
  bad "opencode would fall back to the cross-provider WORKER_FALLBACK_MODEL"
fi
if command grep -q 'WORKER_CLI" = "opencode"' harness/worker_common.sh; then
  ok "the backoff loop branches on WORKER_CLI=opencode"
else
  bad "the backoff loop does not special-case opencode"
fi

# ── 7. the binary is resolved absolutely (the systemd PATH trap) ───────
echo "--- the opencode binary must not depend on PATH ---"
# /usr/bin/opencode and /usr/local/bin/opencode do NOT exist on this box; only
# /root/.opencode/bin/opencode does. A worker under a minimal PATH would
# otherwise fail every call with 'command not found'.
( unset WORKER_OPENCODE_BIN
  source harness/worker_common.sh
  case "$WORKER_OPENCODE_BIN" in
    /*) echo absolute ;;
    opencode) echo bare ;;
    *) echo other ;;
  esac ) > "$TMP/binres"
case "$(cat "$TMP/binres")" in
  absolute) ok "resolves an absolute opencode path" ;;
  *)        bad "opencode bin is not absolute: $(cat "$TMP/binres")" ;;
esac

echo
echo "worker opencode backend: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
