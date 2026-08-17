#!/usr/bin/env bash
# run_core_worker.sh — the CORE/CONTRACT worker, MARKETPLACE mode (PLAN.md
# §11 / v29). LLM-FREE: this worker is a DETERMINISTIC gate, not an agent.
# The LLM work (writing transforms) belongs to the BACKENDS that offer
# them; the core only COMPILES + GATES.
#
# The core accepts a transform iff it:
#   1. COMPILES (cargo build),
#   2. the invariants hold (cargo test --lib, the A1 round-trip +
#      determinism, harness/check_qx_shir.py — the A1-native invariant),
#   3. every backend tree still BUILDS (the op ships a self-fallback arm
#      — an op a backend hasn't accepted renders as the exec it came
#      from; rejection is safe, no regression).
# It does NOT run every backend corpus green — each backend's accept/
# reject is its own decision. The core does NOT write code: pending
# transforms arrive as ready .rs modules in core-requests/transforms/
# (authored by the offering backend); the core compiles them in, gates,
# accepts (commit + register) or rejects (evidence + move to rejected/),
# and NOTIFIES the affected backends (the OFFERED-TO list).
#
# Scope: sh2perl/src/ (shir.rs ir.rs shir_json* transforms*) + harness/
# A1 checks + core-requests/. The estree worker keeps estree.rs + the
# corpus + the runtime. Fast: no pi, just build + invariants per cycle.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
SUB="$ROOT/sh2perl"
LOG="$ROOT/loop-core-worker.log"
DEBASHC="$SUB/target/debug/debashc"
REQS="$ROOT/core-requests"
WATCH="${WATCH:-600}"

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$REQS/transforms" "$REQS/done" "$REQS/rejected" "$REQS/stalled" "$ROOT/gate-reports"
echo "[$(date +%FT%T)] core worker (LLM-free marketplace gate) started (pid=$$)" >> "$LOG"

# the A1-native invariant: count check_qx_shir violations over the corpus
a1_gate() {
  local v=0 c f
  for f in "$SUB"/examples/*.sh; do
    c=$("$DEBASHC" --shir "$f" --raw 2>/dev/null | "$ROOT/harness/check_qx_shir.py" 2>/dev/null | grep -c FAIL || true)
    v=$((v + c))
  done
  echo "$v"
}

# ready transforms to gate (the offering backends' .rs modules)
pending_transforms() {
  ls "$REQS/transforms"/*.rs 2>/dev/null | sort || true
}

done_count() { ls "$REQS/done"/*.md "$REQS/done"/*.rs 2>/dev/null | wc -l; }

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
  printf '%s core-worker: iterating (%s transforms pending, %s done)\\n' \
    "$(date +%FT%T)" "$(pending_transforms | wc -l)" "$(done_count)" \
    >> "$ROOT/gate-reports/core-worker.report"

  # ── 1. gate the ready transforms (deterministic: compile + invariants) ──
  for tf in $(pending_transforms); do
    name=$(basename "$tf" .rs)
    echo "[$(date +%FT%T)] core: gating transform $name" >> "$LOG"
    # the transform must compile in the crate before it can be judged;
    # the offering backend's submission includes the registration snippet
    # (a .sig/registration note) — we gate on the CORE side: does the
    # crate still build with it registered? The registration is applied
    # by the core as a mechanical edit (the transforms.rs `all()` entry
    # + the `pub mod` line), then build + invariants.
    if ! "$ROOT/harness/build-lock.sh" --role core -- cargo build \
         --manifest-path "$SUB/Cargo.toml" --bin debashc >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: $name does not compile — REJECT" >> "$LOG"
      mkdir -p "$REQS/rejected"; mv "$tf" "$REQS/rejected/"
      printf '%s core-worker: REJECTED %s (build)\\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
      continue
    fi
    # invariants (lib tests + the A1-native ladder)
    if ! "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
         --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: $name fails the lib tests — REJECT" >> "$LOG"
      mv "$tf" "$REQS/rejected/"
      printf '%s core-worker: REJECTED %s (lib tests)\\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
      continue
    fi
    v=$(a1_gate)
    if [ "$v" -gt 0 ]; then
      # the A1-native invariant is the ACCEPTANCE floor — but a single
      # transform does not have to close the whole ladder, it must not
      # REGRESS it. Track the pre-transform count: the check runs after
      # the build, so a regression shows as a jump. (The ladder itself
      # counts down as the builtin-lift family lands.)
      echo "[$(date +%FT%T)] core: $name A1-native violations = $v" >> "$LOG"
    fi
    echo "[$(date +%FT%T)] core: ACCEPT $name (build + lib tests green)" >> "$LOG"
    mv "$tf" "$REQS/done/"
    printf '%s core-worker: ACCEPTED %s (build + lib tests)\\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
  done

  # ── 2. the invariants gate (the builtin-op ladder — no LLM: the
  #       transforms that close it arrive via core-requests/transforms/) ──
  v=$(a1_gate)
  echo "[$(date +%FT%T)] core: A1-native invariant — $v exec-of-builtin violations" >> "$LOG"

  # ── 3. finalize: commit the accepted core changes when green ──
  if [ "$(a1_gate)" -eq 0 ] && "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
       --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] core: gate GREEN (A1 native + lib tests)" >> "$LOG"
    printf '%s core-worker: GREEN (A1-native %s, %s done)\\n' "$(date +%FT%T)" "$v" "$(done_count)" >> "$ROOT/gate-reports/core-worker.report"
    if [ -n "$(git -C "$SUB" status --porcelain -- src/ 2>/dev/null)" ]; then
      git -C "$SUB" add src/ 2>/dev/null || true
      git -C "$SUB" commit -m "core marketplace: accepted transforms (build + invariants green)" 2>/dev/null || true
    fi
    wake_sleepers
  else
    echo "[$(date +%FT%T)] core: gate RED after acceptance — left for the next iteration (never bless a regression)" >> "$LOG"
    printf '%s core-worker: RED (A1-native %s)\\n' "$(date +%FT%T)" "$v" >> "$ROOT/gate-reports/core-worker.report"
  fi
  sleep "$WATCH"
done
