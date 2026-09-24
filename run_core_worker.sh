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
# The core worker lives in its OWN git worktree (sh2perl/backends/core on
# backend/core, the fleet's isolation pattern): its WIP, verify-cycles and
# commits never touch the main tree the estree worker's gate reads. It
# lands on main ONLY via a green merge. See the estree-worker deadlock
# this fixes: the split gave role separation without tree separation.
SUB="$ROOT/sh2perl/backends/core"
LOG="$ROOT/loop-core-worker.log"
DEBASHC="$SUB/otranspilerl/target/debug/otranspilerl-cli"
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
         --manifest-path "$SUB/Cargo.toml" --bin otranspilerl-cli >> "$LOG" 2>&1; then
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

  # ── 2b. guard: stash unauthorized shared-core changes ──
  # Other workers (perl, estree) may have committed directly to the shared
  # core (src/shir.rs, src/ir.rs, src/estree.rs, src/parser/) without going
  # through the core worker's gate. Check the main tree and stash any
  # uncommitted changes to the shared core.
  shared_core_dirty=$(git -C "$ROOT/sh2perl" status --porcelain -- src/shir.rs src/ir.rs src/estree.rs src/parser/ 2>/dev/null || true)
  if [ -n "$shared_core_dirty" ]; then
    echo "[$(date +%FT%T)] core: UNAUTHORIZED shared-core changes detected — stashing:" >> "$LOG"
    echo "$shared_core_dirty" >> "$LOG"
    git -C "$ROOT/sh2perl" stash push -m "core-worker: stash unauthorized shared-core changes ($(date +%FT%T))" -- src/shir.rs src/ir.rs src/estree.rs src/parser/ >> "$LOG" 2>&1 || true
    printf '%s core-worker: STASHED unauthorized shared-core changes\n' "$(date +%FT%T)" >> "$ROOT/gate-reports/core-worker.report"
  fi
  # Also check if main tree has commits that the core worktree doesn't have
  # (i.e., someone committed directly to the shared core bypassing the gate).
  main_head=$(git -C "$ROOT/sh2perl" rev-parse HEAD 2>/dev/null || true)
  core_head=$(git -C "$SUB" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$main_head" ] && [ -n "$core_head" ] && [ "$main_head" != "$core_head" ]; then
    # Check if the divergence is in shared core files
    diff_files=$(git -C "$ROOT/sh2perl" diff --name-only "$core_head" "$main_head" -- src/shir.rs src/ir.rs src/estree.rs src/parser/ 2>/dev/null || true)
    if [ -n "$diff_files" ]; then
      echo "[$(date +%FT%T)] core: main tree has unauthorized shared-core commits (diverged from core worktree):" >> "$LOG"
      echo "$diff_files" >> "$LOG"
      # Revert the main tree's shared core to match the core worktree
      git -C "$ROOT/sh2perl" checkout "$core_head" -- src/shir.rs src/ir.rs src/estree.rs src/parser/ >> "$LOG" 2>&1 || true
      git -C "$ROOT/sh2perl" commit -m "core-worker: revert unauthorized shared-core changes" >> "$LOG" 2>&1 || true
      printf '%s core-worker: REVERTED unauthorized shared-core commits\n' "$(date +%FT%T)" >> "$ROOT/gate-reports/core-worker.report"
    fi
  fi

  # ── 3. finalize: commit accepted core changes when green (in the WORKTREE) ──
  # The estree corpus is part of the core worker's green: it must never
  # land a marketplace change that regresses the estree path (the
  # array/function regressions that started this — its old gate was only
  # check_qx_shir + lib tests). SH2PERL_DIR points fail-estree at THIS
  # worktree's binary.
  # Timeout: fail-estree can hang if the build is broken. Cap at 1 hour.
  #
  # PROBE-FAILED vs CORPUS-RED: fail-estree always prints its summary line
  # when it actually ran, and exits 1 for a genuine red corpus (the gate
  # verdict is the FAILURE COUNT, not the exit status). So an exit status
  # can NOT tell the two apart — only the presence of a parsed count can.
  # The old `:-9999` sentinel collapsed "timed out / crashed / produced no
  # summary" into the same RED text as "27 real failures", which is why the
  # report flapped estree=27 / estree=9999 / estree=27.
  #
  # The dominant cause is `fail-estree` dying at its BUILD step because the
  # main tree's sh2perl does not compile — note it builds $ROOT/otranspilerl
  # (the MAIN checkout), NOT $SH2PERL_DIR, so a broken main tree takes the
  # core gate down even though the core WORKTREE (sh2perl/backends/core)
  # builds fine. Name that cause explicitly instead of logging an opaque
  # "no summary line".
  #
  # Detecting it: fail-estree's `die "Build failed"` goes to STDERR, which
  # this capture discards (2>/dev/null) — so the marker is NOT greppable
  # here. What IS on stdout is the cargo output it printed first, ending in
  # `error: could not compile ...`. Detect that instead.
  estree_probe=ok
  estree_reason=""
  estree_out=$(timeout 3600 env SH2PERL_DIR="$SUB" "$ROOT/fail-estree" 2>/dev/null) || true
  estree_fails=$(printf '%s\n' "$estree_out" | sed -n 's/.*ESTREE: [0-9]* passed, \([0-9]*\) failed.*/\1/p' | tail -1)
  if [ -z "$estree_fails" ]; then
    estree_probe=failed
    estree_fails="?"
    if printf '%s\n' "$estree_out" | grep -qE 'error: could not compile|could not compile .* due to'; then
      estree_reason="main tree sh2perl does not compile"
      echo "[$(date +%FT%T)] core: estree probe FAILED — $ROOT/otranspilerl (the MAIN tree; the probe's build step ignores SH2PERL_DIR, so the core worktree's clean build does not help) does not compile. No corpus verdict is available." >> "$LOG"
      printf '%s\n' "$estree_out" | grep -E '^error' | head -10 >> "$LOG"
    else
      estree_reason="no ESTREE summary (timed out or crashed)"
      echo "[$(date +%FT%T)] core: estree probe FAILED (no ESTREE summary line — fail-estree timed out or crashed; this is NOT a corpus verdict)" >> "$LOG"
      printf '%s\n' "$estree_out" | tail -20 >> "$LOG"
    fi
  fi
  if [ "$(a1_gate)" -eq 0 ] && [ "$estree_probe" = ok ] && [ "$estree_fails" -le 0 ] && \
       "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
       --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] core: gate GREEN (A1 native + estree corpus + lib tests)" >> "$LOG"
    printf '%s core-worker: GREEN (A1-native %s, estree %s fails, %s done, %s rejected)\n' "$(date +%FT%T)" "$v" "$estree_fails" "$(done_count)" "$(rejected_count)" >> "$ROOT/gate-reports/core-worker.report"
    if [ -n "$(git -C "$SUB" status --porcelain -- src/ 2>/dev/null)" ]; then
      git -C "$SUB" add src/ 2>/dev/null || true
      git -C "$SUB" commit -m "core marketplace: accepted transforms (build + invariants + estree corpus green)" 2>/dev/null || true
    fi
    # LAND on main ONLY when green, via merge — the estree worker's main
    # tree stays clean (it never sees this worker's WIP or commits-in-
    # progress). ff-only: if main moved (estree commits), defer to the next
    # iteration rather than risk a cross-worker merge conflict.
    if [ -n "$(git -C "$SUB" log --oneline main..backend/core 2>/dev/null)" ]; then
      if git -C "$ROOT/sh2perl" merge --ff-only backend/core >> "$LOG" 2>&1; then
        echo "[$(date +%FT%T)] core: landed backend/core -> main (ff)" >> "$LOG"
      else
        echo "[$(date +%FT%T)] core: ff-merge deferred (main moved) — will retry next iteration" >> "$LOG"
      fi
    fi
    wake_sleepers
  else
    if [ "$estree_probe" != ok ]; then
      echo "[$(date +%FT%T)] core: gate RED (a1=$v estree-probe-FAILED) after acceptance — left for the next iteration (never bless a regression)" >> "$LOG"
      printf '%s core-worker: RED (A1-native %s, estree probe FAILED — %s, %s done, %s rejected)\n' "$(date +%FT%T)" "$v" "$estree_reason" "$(done_count)" "$(rejected_count)" >> "$ROOT/gate-reports/core-worker.report"
    else
      echo "[$(date +%FT%T)] core: gate RED (a1=$v estree=$estree_fails) after acceptance — left for the next iteration (never bless a regression)" >> "$LOG"
      printf '%s core-worker: RED (A1-native %s, estree %s fails, %s done, %s rejected)\n' "$(date +%FT%T)" "$v" "$estree_fails" "$(done_count)" "$(rejected_count)" >> "$ROOT/gate-reports/core-worker.report"
    fi
  fi
  sleep "$WATCH"
done
