#!/usr/bin/env bash
# run_core_worker.sh — the CORE/CONTRACT worker, MARKETPLACE mode (PLAN.md
# §11 / v29). LLM-FREE: this worker is a DETERMINISTIC gate, not an agent.
# The LLM work (writing transforms) belongs to the BACKENDS that offer
# them; the core only COMPILES + GATES.
#
# SUBMISSION BUNDLES: a transform that emits a NEW op ships its contract
# expansion WITH it — each submission is a directory
#   core-requests/transforms/<name>/
#     transform.rs      the transform module
#     contract.patch    the op ingress (the deserializer/schema change the
#                       op needs) — applied AHEAD of the transform, so the
#                       op compiles instead of bouncing on a missing
#                       prerequisite
#     manifest          prereqs / invariant / scope / ## OFFERED-TO
# The gate applies the contract expansion first, registers + builds the
# transform, runs the invariants, and accepts the BUNDLE together (commit)
# or rejects it (revert the submodule src, move to rejected/).
#
# Acceptance: compiles + the invariants hold (cargo test --lib, the A1
# round-trip/determinism, check_qx_shir) + every backend tree still builds
# (the op ships a self-fallback arm — an op a backend hasn't accepted
# renders as the exec it came from; rejection is safe, no regression).
# It does NOT run every backend corpus green — each backend's accept/
# reject is its own decision.
#
# Scope: sh2perl/src/ + harness/ A1 checks + core-requests/. The estree
# worker keeps estree.rs + the corpus + the runtime. Fast: no pi.
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
mkdir -p "$REQS/transforms/done" "$REQS/transforms/rejected" "$ROOT/gate-reports"
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

# pending submission BUNDLES (dirs carrying a transform.rs) — the
# marketplace channels (PLAN §11): transforms/offered .rs, contracts/*.json
# specs, and bundles/ (a node + its transforms)
pending_transforms() {
  for d in "$REQS"/transforms/offered/*.rs; do
    [ -f "$d" ] && echo "$d"
  done 2>/dev/null | sort || true
}

pending_contracts() {
  ls "$REQS"/contracts/*.json 2>/dev/null | sort || true
}

pending_bundles() {
  for d in "$REQS"/bundles/*/; do
    [ -d "$d" ] && [ -f "$d/bundle.json" ] && echo "${d%/}"
  done 2>/dev/null | sort || true
}

done_count() { ls "$REQS/done"/*.md "$REQS/done"/*.rs "$REQS/transforms/done"/*.rs 2>/dev/null | wc -l; }
rejected_count() { ls "$REQS/transforms/rejected"/*.rs 2>/dev/null | wc -l; }

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
  printf '%s core-worker: iterating (%s offers, %s specs, %s bundles, %s done, %s rejected)\n' \
    "$(date +%FT%T)" \
    "$(pending_transforms | wc -l)" \
    "$(pending_contracts | wc -l)" \
    "$(pending_bundles | wc -l)" \
    "$(done_count)" "$(rejected_count)" \
    >> "$ROOT/gate-reports/core-worker.report"

  # ── 1. gate the submission bundles (deterministic: contract → build → invariants) ──
  for bundle in $(pending_transforms); do
    name=$(basename "$bundle")
    echo "[$(date +%FT%T)] core: gating transform bundle $name" >> "$LOG"
    # the contract expansion is applied AHEAD of the transform (the user's
    # sequencing ask) — the op ingress the transform's op needs
    if [ -f "$bundle/contract.patch" ]; then
      if ! git -C "$SUB" apply --check "$bundle/contract.patch" >> "$LOG" 2>&1; then
        echo "[$(date +%FT%T)] core: $name contract.patch does not apply — REJECT" >> "$LOG"
        mv "$bundle" "$REQS/transforms/rejected/"
        printf '%s core-worker: REJECTED %s (contract patch)\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
        continue
      fi
      git -C "$SUB" apply "$bundle/contract.patch" >> "$LOG" 2>&1
    fi
    # INTEGRATE the transform: copy transform.rs into the crate and apply
    # the registration lines (the bundle's `register` file carries the exact
    # `pub mod <name>;` + `("<name>-lift", <name>::transform)` entries) —
    # acceptance must mean the TRANSFORM itself compiles, not just the
    # unchanged crate. Reverted on any failure (git checkout -- src/).
    if [ -f "$bundle/transform.rs" ]; then
      # the module name comes from the register file (`pub mod <name>;`) —
      # the bundle DIR may be hyphenated (builtin-lift) while the module is
      # underscored (builtin_lift); the file must match the module name
      modname=$(sed -n 's/^pub mod \([a-z_0-9]*\);$/\1/p' "$bundle/register" | head -1)
      cp "$bundle/transform.rs" "$SUB/src/transforms/${modname:-$(basename "$bundle")}.rs"
      if [ -f "$bundle/register" ]; then
        # the register file carries two sections inserted at their proper
        # places (markers ### mod / ### all): the mods go after the last
        # `pub mod` line; the all() entries go before the vec's closing `]`
        mods=$(sed -n '/^### mod$/,/^### all$/p' "$bundle/register" | grep -v '^###' || true)
        entries=$(sed -n '/^### all$/,$p' "$bundle/register" | grep -v '^###' || true)
        if [ -n "$mods" ]; then
          python3 - "$SUB/src/transforms.rs" "$mods" <<'PYEOF'
import sys
path, mods = sys.argv[1], sys.argv[2]
lines = open(path).read().split(chr(10))
last = max(i for i, l in enumerate(lines) if l.startswith('pub mod '))
for m in mods.strip().split(chr(10)):
    lines.insert(last + 1, m)
    last += 1
open(path, 'w').write(chr(10).join(lines))
PYEOF
        fi
        if [ -n "$entries" ]; then
          python3 - "$SUB/src/transforms.rs" "$entries" <<'PYEOF'
import sys
path, entries = sys.argv[1], sys.argv[2]
lines = open(path).read().split(chr(10))
idx = max(i for i, l in enumerate(lines) if '::transform),' in l)
close = next(i for i in range(idx, len(lines)) if lines[i].strip() == ']')
for e in entries.strip().split(chr(10)):
    lines.insert(close, e)
    close += 1
open(path, 'w').write(chr(10).join(lines))
PYEOF
        fi
      fi
    fi
    if ! "$ROOT/harness/build-lock.sh" --role core -- cargo build \
         --manifest-path "$SUB/Cargo.toml" --bin debashc >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: $name does not compile — REJECT (submodule src reverted)" >> "$LOG"
      git -C "$SUB" checkout -- src/ 2>/dev/null || true
      mv "$bundle" "$REQS/transforms/rejected/"
      printf '%s core-worker: REJECTED %s (build)\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
      continue
    fi
    if ! "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
         --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: $name fails the lib tests — REJECT (submodule src reverted)" >> "$LOG"
      git -C "$SUB" checkout -- src/ 2>/dev/null || true
      mv "$bundle" "$REQS/transforms/rejected/"
      printf '%s core-worker: REJECTED %s (lib tests)\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
      continue
    fi
    echo "[$(date +%FT%T)] core: ACCEPT $name (contract + transform, build + lib tests green)" >> "$LOG"
    git -C "$SUB" add src/ 2>/dev/null || true
    git -C "$SUB" commit -m "marketplace bundle $name: contract op + transform (build + invariants green)" 2>/dev/null || true
    mv "$bundle" "$REQS/transforms/done/"
    printf '%s core-worker: ACCEPTED %s (contract + transform, build + lib tests)\n' "$(date +%FT%T)" "$name" >> "$ROOT/gate-reports/core-worker.report"
  done

  # ── 2. the invariants gate (the builtin-op ladder — no LLM) ──
  v=$(a1_gate)
  echo "[$(date +%FT%T)] core: A1-native invariant — $v exec-of-builtin violations" >> "$LOG"

  # ── 3. finalize: commit accepted core changes when green ──
  if [ "$(a1_gate)" -eq 0 ] && "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
       --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] core: gate GREEN (A1 native + lib tests)" >> "$LOG"
    printf '%s core-worker: GREEN (A1-native %s, %s done, %s rejected)\n' "$(date +%FT%T)" "$v" "$(done_count)" "$(rejected_count)" >> "$ROOT/gate-reports/core-worker.report"
    if [ -n "$(git -C "$SUB" status --porcelain -- src/ 2>/dev/null)" ]; then
      git -C "$SUB" add src/ 2>/dev/null || true
      git -C "$SUB" commit -m "core marketplace: accepted transforms (build + invariants green)" 2>/dev/null || true
    fi
    wake_sleepers
  else
    echo "[$(date +%FT%T)] core: gate RED after acceptance — left for the next iteration (never bless a regression)" >> "$LOG"
    printf '%s core-worker: RED (A1-native %s, %s done, %s rejected)\n' "$(date +%FT%T)" "$v" "$(done_count)" "$(rejected_count)" >> "$ROOT/gate-reports/core-worker.report"
  fi
  sleep "$WATCH"
done
