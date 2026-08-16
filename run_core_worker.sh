#!/usr/bin/env bash
# run_core_worker.sh — the CORE/CONTRACT worker, MARKETPLACE mode (PLAN.md
# §11 / v29): the core is narrowed to build CI + the invariants + the A1
# schema + canonical bug-fixes. Transforms are CONCRETE, manifest-carrying
# modules: a backend implements + offers them; other backends accept or
# reject. The core's bar is: the transform COMPILES + the A1 contract/
# invariants hold + every backend tree still BUILDS (the op ships a
# self-fallback arm). It does NOT run every backend corpus green — each
# backend's accept/reject is ITS decision, and rejection is safe because
# the fallback renders the op as the exec it came from (no regression,
# no gain).
#
# Mandate per iteration (in order):
#   1. the transform/request queue (incl. the stalled A1-optimization
#      requests) — implement as concrete transforms with a MANIFEST
#      (prereqs, invariant, intended scope), gate on build + invariants,
#      and OFFER/NOTIFY the affected backends (the sharing scope).
#   2. the invariants gate — cargo test --lib, determinism, round-trip,
#      and harness/check_qx_shir.py (the A1-native invariant).
#   3. canonical bug-fixes on the core (the array-key/loop-hang class).
#
# Scope: sh2perl/src/ (shir.rs ir.rs shir_json* transforms* shir_passes*)
# + core-requests/ + harness/ A1 checks. The estree worker keeps
# estree.rs + the corpus + the runtime (CORE_WORKER_ACTIVE=1 defers the
# request queue here). Commit only when green; wake sleeping workers when
# their request lands.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
SUB="$ROOT/sh2perl"
LOG="$ROOT/loop-core-worker.log"
DEBASHC="$SUB/target/debug/debashc"
REQS="$ROOT/core-requests"
MODEL="${MODEL:-deepseek-v4-flash}"
THINKING="${THINKING:-xhigh}"
WATCH="${WATCH:-900}"

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$REQS/done" "$REQS/stalled" "$ROOT/gate-reports"
echo "[$(date +%FT%T)] core worker (marketplace) started (pid=$$)" >> "$LOG"

# the A1-native invariant gate: count check_qx_shir violations
a1_gate() {
  local v=0 c f
  for f in "$SUB"/examples/*.sh; do
    c=$("$DEBASHC" --shir "$f" --raw 2>/dev/null | "$ROOT/harness/check_qx_shir.py" 2>/dev/null | grep -c FAIL || true)
    v=$((v + c))
  done
  echo "$v"
}

# the open request queue (newest first); the STALLED A1-optimization
# requests are the transform backlog the marketplace unblocks
pending_requests() {
  {
    ls "$REQS"/*.md 2>/dev/null | grep -vE "/(done|stalled|offered|rejected)/"
    ls "$REQS/stalled"/*.md 2>/dev/null
  } | sort -r || true
}

wake_sleepers() {
  for m in "$REQS"/sleeping-*; do
    [ -f "$m" ] || continue
    echo "[$(date +%FT%T)] core: waking $(basename "$m" | sed 's/sleeping-//')" >> "$LOG"
    rm -f "$m"
  done
}

while true; do
  bash "$ROOT/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
  echo "[$(date +%FT%T)] core: iteration start" >> "$LOG"

  pending=$(pending_requests)
  if [ -n "$pending" ]; then
    echo "[$(date +%FT%T)] core: $(echo "$pending" | wc -l) pending request(s)" >> "$LOG"
    {
      printf 'You are the CORE/CONTRACT worker in MARKETPLACE mode (PLAN.md §11):\n'
      printf 'implement the pending requests as CONCRETE shared transforms/ops with a\n'
      printf 'MANIFEST, gate them on build + the invariants, and OFFER each to the\n'
      printf 'affected backends. Acceptance rule: a transform is accepted if it\n'
      printf 'COMPILES, the A1 contract stays valid (schema + round-trip +\n'
      printf 'determinism), and every backend tree still BUILDS — the op must ship\n'
      printf 'a self-fallback arm (an op a backend has NOT accepted renders as the\n'
      printf 'exec it came from). You do NOT need every backend corpus green with\n'
      printf 'the op: each backend decides accept/reject itself, and rejection is\n'
      printf 'safe by the fallback (no regression, no gain).\n\n'
      printf 'For EACH request:\n'
      printf '  1. Implement it as a concrete transform/op (transforms.rs or\n'
      printf '     shir_passes/) with a manifest appended to the request file:\n'
      printf '     ## MANIFEST\\n prereqs: <what it needs>\\n invariant: <what must\n'
      printf '     hold>\\n scope: <intended sharing scope — which backends>\\n'
      printf '  2. ## OUTCOME: implemented | rejected: <reason>\\n'
      printf '  3. ## OFFERED-TO: <the backends that should adopt this op — the ones\n'
      printf '     that would benefit (e.g. the ones that shell out the command the\n'
      printf '     op replaces)> — this is the NOTIFY step: the offered backends see\n'
      printf '     the op and decide accept/reject.\n\n'
      printf 'The pending requests:\\n'
      for f in $pending; do
        printf '===== %s =====\n' "$(basename "$f")"
        head -50 "$f"
        printf '\n'
      done
      printf '\nScope: sh2perl/src/ (shir.rs ir.rs shir_json* transforms* shir_passes*) +\n'
      printf 'core-requests/ + harness/. NEVER touch backends/ or frontends/.\n'
      printf 'Verify: cargo test --lib + the A1 round-trip/determinism invariants +\n'
      printf 'each backend tree still compiles (the fallback arm). fail-estree is the\n'
      printf 'ESTREE worker accepts/rejects the op itself (its gate). Move finalized\n'
      printf 'requests to done/. Commit the submodule\n'
      printf '(git -C sh2perl add src/ && commit) and the workspace explicitly.\n'
    } > /tmp/core-prompt-$$
    pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
       < /tmp/core-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/core-prompt-$$
  fi

  # the invariants gate (A1-native ladder + lib tests)
  v=$(a1_gate)
  echo "[$(date +%FT%T)] core: A1-native invariant — $v exec-of-builtin violations" >> "$LOG"
  if [ "$v" -gt 0 ]; then
    echo "[$(date +%FT%T)] core: A1 invariant red ($v) — invoking pi on the transforms" >> "$LOG"
    {
      printf 'The A1 shIR must be NATIVE: harness/check_qx_shir.py over the corpus reports\n'
      printf '%s exec-of-builtin violations (raw exec of a builtins.json command that\n' "$v"
      printf 'backends would shell out). Implement the builtin-op transform + contract op\n'
      printf '(core-requests/shir-builtin-op-20260816.md + core-requests/transforms/builtin_lift.rs)\n'
      printf 'and the fold-lift specs (egrep, quiet-grep, case-cmdsub, param-default,\n'
      printf 'test-operands) so the violations count down. Ship each with a MANIFEST\n'
      printf '(prereqs / invariant / scope) and an ## OFFERED-TO list naming the backends\n'
      printf 'that shell out the replaced command (rust, perl, c) — the notify step.\n'
      printf 'Scope: sh2perl/src/ — never the backends/frontends. Verify cargo test --lib\n'
      printf '+ fail-estree stay green. Commit the submodule explicitly.\n'
    } > /tmp/core-a1-prompt-$$
    pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
       < /tmp/core-a1-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/core-a1-prompt-$$
  fi

  # verify + finalize when green
  if [ "$(a1_gate)" -eq 0 ] && "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
       --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] core: gate GREEN (A1 native + lib tests)" >> "$LOG"
    printf '%s core-worker: GREEN (A1 native + lib tests)\n' "$(date +%FT%T)" >> "$ROOT/gate-reports/core-worker.report"
    wake_sleepers
  else
    echo "[$(date +%FT%T)] core: gate RED after fixes — left for the next iteration (never bless a regression)" >> "$LOG"
    printf '%s core-worker: RED (A1-native ladder + lib tests)\n' "$(date +%FT%T)" >> "$ROOT/gate-reports/core-worker.report"
  fi
  sleep "$WATCH"
done
