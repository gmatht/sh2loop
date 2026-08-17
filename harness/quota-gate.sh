#!/usr/bin/env bash
# quota-gate.sh — the pi quota guard (PLAN §11 / the 85%-in-30min burn).
#
# The workers spawn pi on every gate failure; when the opencode-go quota is
# exhausted (429 GoUsageLimitError), the invocations die instantly and the
# retry loops BURN the rolling budget without landing fixes. This gate
# checks the provider's own state BEFORE spawning pi:
#
#   1. the active key's quotaBlockedUntil (opencode-keys.json)
#   2. a per-worker 429 MEMORY marker (last pi 429 + cooldown) so a worker
#      that just hit the limit backs off instead of re-spawning
#
# Usage:
#   if quota_ok "worker-name"; then
#     pi --mode json …           # the invocation
#     mark_pi_outcome $?          # record a 429 so the next call backs off
#   else
#     echo "quota-blocked — skipping pi"
#   fi
set -u
KEYS_JSON="${OPENCODE_KEYS_JSON:-/home/llm/.pi/agent/opencode-keys.json}"
MEM_DIR="${QUOTA_MEM_DIR:-/home/llm/sh2loop/.quota-mem}"
COOLDOWN_S="${QUOTA_COOLDOWN_S:-1800}"   # back off 30 min after a 429

# quota_ok <worker> — 0 = pi may run, 1 = quota blocked (skip)
quota_ok() {
  local who="${1:-unknown}"
  # 1. the provider's own per-key block state
  if [ -f "$KEYS_JSON" ]; then
    if python3 -c "
import json, time, sys
d = json.load(open('$KEYS_JSON'))
now = int(time.time()*1000)
idx = d.get('activeKeyIndex', 0)
b = d.get('quotaBlockedUntil', {}).get(str(idx))
if b and b > now:
    sys.exit(1)
sys.exit(0)
" 2>/dev/null; then
      : # active key not provider-blocked
    else
      echo "[quota-gate] active key provider-blocked — skipping pi ($who)" >&2
      return 1
    fi
  fi
  # 2. the worker's own 429 memory (a recent pi 429 → back off)
  local mem="$MEM_DIR/$who.429"
  if [ -f "$mem" ]; then
    local last=$(( $(date +%s) - $(cat "$mem" 2>/dev/null || echo 0) ))
    if [ "$last" -lt "$COOLDOWN_S" ]; then
      echo "[quota-gate] pi 429 ${last}s ago — backing off (skip, $who)" >&2
      return 1
    fi
    rm -f "$mem"
  fi
  return 0
}

# mark_pi_outcome <exit_code> [log_file] — record a 429 so the next
# invocation backs off (the retry storm is the quota burner).
mark_pi_outcome() {
  local rc="$1" who="${2:-unknown}" log="${3:-}"
  if [ "$rc" -ne 0 ]; then
    if [ -n "$log" ] && grep -q "429:\|GoUsageLimitError" "$log" 2>/dev/null; then
      mkdir -p "$MEM_DIR"
      date +%s > "$MEM_DIR/$who.429"
      echo "[quota-gate] pi 429 recorded for $who — next invocation backs off ${COOLDOWN_S}s" >&2
    fi
  fi
}
