#!/usr/bin/env bash
# run_core_worker.sh — the CORE/CONTRACT worker (TRANSLATE_ONE_APPLICATION
# fleet role #1): single owner of the shared IR (shir.rs/ir.rs), the A1
# contract (shir_json*), the transforms (transforms.rs + transforms/*),
# the core-requests queue, and the A1-native harness check
# (check_qx_shir.py). HIGHEST PRIORITY — every backend/frontend worker
# queues to it (the perl/rust/frontend native-lowering ladders all wait
# on the builtin-op + fold-lift transforms).
#
# Mandate per iteration (in order):
#   1. the core-request queue — mediate + implement the open requests
#      (unblocks the sleeping workers; the builtin-op + fold-lift specs)
#   2. the A1-native gate — harness/check_qx_shir.py over the corpus (the
#      builtin-op ladder: 2738 exec-of-builtin violations → 0)
#   3. cargo test --lib — the contract/IR unit tests
#
# Scope: sh2perl/src/ (the shared core) + core-requests/ + harness/ A1
# checks. The estree worker keeps estree.rs + the corpus + the runtime
# (CORE_WORKER_ACTIVE=1 defers the request queue to this worker). Commit
# only when green (no-regression guard); wake sleeping workers when their
# request lands.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
SUB="$ROOT/sh2perl"
LOG="$ROOT/loop-core-worker.log"
DEBASHC="$SUB/target/debug/debashc"
REQS="$ROOT/core-requests"
MODEL="${MODEL:-deepseek-v4-flash}"
THINKING="${THINKING:-xhigh}"
WATCH="${WATCH:-900}"   # seconds between iterations

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$REQS/done" "$REQS/stalled" "$ROOT/gate-reports"
echo "[$(date +%FT%T)] core worker started (pid=$$)" >> "$LOG"

# the A1-native gate: count check_qx_shir violations over the corpus
a1_gate() {
  local v=0 c f
  for f in "$SUB"/examples/*.sh; do
    c=$("$DEBASHC" --shir "$f" --raw 2>/dev/null | "$ROOT/harness/check_qx_shir.py" 2>/dev/null | grep -c FAIL || true)
    v=$((v + c))
  done
  echo "$v"
}

# the pending request queue (newest first; sleeping markers are live blockers)
pending_requests() {
  ls "$REQS"/*.md 2>/dev/null | grep -vE "/(done|stalled|offered|rejected)/" | sort -r || true
}

# wake the workers sleeping on implemented requests
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

  # 1. the request queue — mediate + implement (unblocks the backends)
  pending=$(pending_requests)
  if [ -n "$pending" ]; then
    echo "[$(date +%FT%T)] core: $(echo "$pending" | wc -l) pending request(s)" >> "$LOG"
    {
      printf 'You are the CORE/CONTRACT worker: single owner of the shared shIR and the\n'
      printf 'A1 contract. Implement the pending core requests below (they unblock the\n'
      printf 'sleeping backends/frontends) WITHOUT regressing the corpus.\n\n'
      for f in $pending; do
        printf '===== %s =====\n' "$(basename "$f")"
        head -60 "$f"
        printf '\n'
      done
      printf '\nScope: sh2perl/src/ (shir.rs ir.rs shir_json* transforms* transforms/) +\n'
      printf 'core-requests/ + harness/ (check_qx_shir.py). NEVER touch backends/ or\n'
      printf 'frontends/. Verify: cargo test --lib and harness/check_qx_shir.py + the\n'
      printf 'estree corpus (fail-estree) must not regress.\n'
      printf 'On implementation: APPEND "## OUTCOME: implemented" to the request file; on\n'
      printf 'rejection: "## OUTCOME: rejected: <reason>". Move finalized files to done/.\n'
      printf 'Commit the submodule (git -C sh2perl add src/ && commit) and the workspace\n'
      printf '(core-requests/) explicitly — never git add .\n'
    } > /tmp/core-prompt-$$
    pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
       < /tmp/core-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/core-prompt-$$
  fi

  # 2. the A1-native gate (the builtin-op ladder)
  v=$(a1_gate)
  echo "[$(date +%FT%T)] core: A1-native gate — $v exec-of-builtin violations" >> "$LOG"
  if [ "$v" -gt 0 ]; then
    echo "[$(date +%FT%T)] core: A1 gate red ($v) — invoking pi on the transforms" >> "$LOG"
    {
      printf 'The A1 shIR must be NATIVE: harness/check_qx_shir.py over the corpus reports\n'
      printf '%s exec-of-builtin violations (raw exec of a builtins.json command that\n' "$v"
      printf 'backends would shell out — rust bash -c, perl qx). Implement the builtin-op\n'
      printf 'transform + contract op (core-requests/shir-builtin-op-20260816.md and\n'
      printf 'core-requests/transforms/builtin_lift.rs — ready to compile) and the fold-lift\n'
      printf 'specs so the violations count down. Scope: sh2perl/src/ (shir.rs ir.rs\n'
      printf 'shir_json* transforms*) — never the backends/frontends.\n'
      printf 'Verify cargo test --lib + fail-estree stay green. Commit the submodule\n'
      printf '(git -C sh2perl add src/ && commit) explicitly.\n'
    } > /tmp/core-a1-prompt-$$
    pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
       < /tmp/core-a1-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/core-a1-prompt-$$
  fi

  # 3. verify + finalize when green
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
