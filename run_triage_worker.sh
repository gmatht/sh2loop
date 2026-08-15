#!/usr/bin/env bash
# run_triage_worker.sh — the cross-product triage worker.
#
# Rotates through the frontends; each cycle sweeps ONE frontend's corpus
# through ALL backends (no execution cache — the point is detecting when
# any input changed), diffs the new verdicts against the previous
# baseline, escalates NEW failures by class, and regenerates the
# external report.
#
# Escalation by class (the ownership discipline):
#   FAIL-FRONTEND(-EMIT) → setup_backends.sh --pi-fix-frontend <frontend>
#   FAIL-BACKEND         → a structured core-request (the renderers live
#                          in the core/worktrees)
# A pair is escalated once per STATUS; a later PASS clears it.
#
# State (all under triage/):
#   verdicts.tsv    append-only verdicts (the report's source)
#   baseline.tsv    the LAST sweep's status per pair (fe<TAB>be<TAB>ex<TAB>status)
#   escalated.tsv   escalated (fe<TAB>be<TAB>ex<TAB>status) — never re-escalated
#   report.json/.md the external report
set -euo pipefail
cd "$(dirname "$0")"
WORKSPACE="$(pwd)"
TRIAGE="$WORKSPACE/triage"
mkdir -p "$TRIAGE"
LOG="$WORKSPACE/loop-triage-worker.log"
# Worker cgroup enrollment (harness/WorkerPool.pm): the triage worker and
# its sweep children (frontend binaries, backend renders) run inside the
# sh2workers cgroup. Best-effort: unprivileged WSL → cooperative fallback.
perl "$WORKSPACE/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
echo "[$(date +%FT%T)] triage worker started (pid=$$)" >> "$LOG"

escalate() {  # fe be ex status detail
  local fe="$1" be="$2" ex="$3" st="$4" det="$5"
  case "$st" in
    FAIL-FRONTEND*)
      echo "[$(date +%FT%T)] escalating $fe/$ex/$be ($st) → --pi-fix-frontend $fe" >> "$LOG"
      bash "$WORKSPACE/setup_backends.sh" --pi-fix-frontend "$fe" >> "$LOG" 2>&1 || true
      ;;
    FAIL-BACKEND)
      local ts; ts=$(date +%Y%m%d-%H%M%S)
      local req="$WORKSPACE/core-requests/triage-$be-$ts.md"
      {
        echo "# triage: $be backend can't render what the $fe frontend emits"
        echo
        echo "## NEED"
        echo "The $be renderer must handle this A1 (the estree reference renders it and"
        echo "matches native)."
        echo
        echo "## FAILING-CASE"
        echo "frontend $fe, example $ex (cross-product pair)."
        echo
        echo "## EVIDENCE"
        echo "$det"
      } > "$req"
      echo "[$(date +%FT%T)] escalating $fe/$ex/$be ($st) → $req" >> "$LOG"
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$fe" "$be" "$ex" "$st" >> "$TRIAGE/escalated.tsv"
}

cycle() {  # fe
  local fe="$1"
  echo "[$(date +%FT%T)] triage cycle: $fe × all backends" >> "$LOG"
  # the sweep recomputes everything (the point) and appends verdicts
  bash "$WORKSPACE/harness/triage.sh" --sweep "$fe" >> "$LOG" 2>&1 || true
  # diff the NEW verdict rows against the baseline; escalate status
  # changes to a FAIL-* that weren't escalated before. ONLY the LATEST
  # row per (frontend, backend, example) may be diffed: verdicts.tsv is
  # append-only, and walking the WHOLE history re-escalates stale FAIL
  # rows forever (a pair that later PASSes drops its escalation record,
  # so the next cycle re-files the old row — the 2026-08-14 18:04/18:08/
  # 18:11 duplicate core-request floods, all 'var_types not a string'
  # verdicts from the 10:57 sweep). tac reverses so !seen keeps the
  # newest row per pair; rows superseded by a later verdict never
  # escalate.
  local new_rows; new_rows=$(tac "$TRIAGE/verdicts.tsv" 2>/dev/null | awk -F'\t' -v fe="$fe" '$1==fe && !seen[$1 FS $2 FS $3]++' || true)
  local fe2 be ex st det ep
  echo "$new_rows" | while IFS=$'\t' read -r fe2 be ex st det ep; do
    [ -z "$fe2" ] && continue
    local old; old=$(awk -F'\t' -v f="$fe2" -v b="$be" -v e="$ex" '$1==f && $2==b && $3==e {print $4}' "$TRIAGE/baseline.tsv" 2>/dev/null | tail -1)
    # escalate only when the status CHANGED to a FAIL-* (or a FAIL detail changed)
    if [ "$old" != "$st" ] && [[ "$st" == FAIL-* ]]; then
      local esc; esc=$(awk -F'\t' -v f="$fe2" -v b="$be" -v e="$ex" -v s="$st" '$1==f && $2==b && $3==e && $4==s {print "yes"}' "$TRIAGE/escalated.tsv" 2>/dev/null | tail -1)
      if [ -z "$esc" ]; then escalate "$fe2" "$be" "$ex" "$st" "$det"; fi
    fi
  done || true
  # refresh the baseline for this frontend (latest status per pair):
  # verdicts.tsv is append-only, so !seen WITHOUT tac keeps the OLDEST
  # row per pair — a stale status (e.g. an early PASS-RENDER epoch) then
  # re-escalates every cycle: the diff sees a "status change" to FAIL-*,
  # and the clear-escalation step drops the record because the stale
  # baseline still says non-FAIL (observed 2026-08-15: zsh-sh-go
  # t70_var_case_mods re-escalated --pi-fix-frontend every ~3 min for
  # c/go/python/rust). tac reverses so the first-seen row is the newest.
  awk -F'\t' -v fe="$fe" '$1==fe {print $1"\t"$2"\t"$3"\t"$4}' "$TRIAGE/verdicts.tsv" 2>/dev/null \
    | tac \
    | awk -F'\t' '!seen[$1 FS $2 FS $3]++' > "$TRIAGE/.baseline.new"
  if [ -f "$TRIAGE/baseline.tsv" ]; then
    awk -F'\t' -v fe="$fe" '$1!=fe' "$TRIAGE/baseline.tsv" >> "$TRIAGE/.baseline.new"
  fi
  mv "$TRIAGE/.baseline.new" "$TRIAGE/baseline.tsv"
  # clear escalations that are now PASS (resolved)
  awk -F'\t' 'NR==FNR {ok[$1"\t"$2"\t"$3]=$4; next} {k=$1"\t"$2"\t"$3; if (ok[k] !~ /^FAIL-/) {} else print}' \
    "$TRIAGE/baseline.tsv" "$TRIAGE/escalated.tsv" 2>/dev/null > "$TRIAGE/.esc.new" || true
  mv "$TRIAGE/.esc.new" "$TRIAGE/escalated.tsv"
  bash "$WORKSPACE/harness/triage.sh" --report >> "$LOG" 2>&1 || true
  echo "[$(date +%FT%T)] triage cycle done: $fe (report updated)" >> "$LOG"
}

# ── dead-worker takeover ────────────────────────────────────────────
# If a frontend/backend worker isn't running (its supervisor pid in
# loop-*.pid is dead or missing — the same check do_start_workers uses),
# do its work here: build/gate/commit within scope, so the pipeline
# doesn't stall until the worker is restarted. The triage sweep then
# re-sweeps the fresh state.
worker_alive() {  # pidfile
  [ -f "$1" ] && kill -0 "$(cat "$1" 2>/dev/null)" 2>/dev/null
}

takeover_frontend() {  # fe
  local fe="$1"
  if ! worker_alive "$WORKSPACE/loop-frontend-$fe.pid"; then
    echo "[$(date +%FT%T)] frontend $fe worker NOT running — triage taking over" >> "$LOG"
    bash "$WORKSPACE/setup_backends.sh" --frontend-worker-once "$fe" >> "$LOG" 2>&1 || true
  fi
}

# refresh the otranspiler GUI's gate.json from the fresh verdicts and
# commit it (the repo is root-owned; sudo). The GUI reads ONLY this
# file for the example-button colours — without this, the buttons stay
# grey until someone re-runs sync-backend-gates.sh by hand, while the
# workers keep refreshing triage/report.json + .frontend_gate.tsv.
sync_gui_gate() {
  local repo=/root/src/sh2runtime
  [ -d "$repo" ] || { echo "[$(date +%FT%T)] sync_gui_gate: repo $repo missing" >> "$LOG"; return 0; }
  sudo bash "$repo/sync-backend-gates.sh" >> "$LOG" 2>&1 || true
  sudo git -C "$repo" add www/examples/gate.json www/otranspiler.html >> "$LOG" 2>&1 || true
  if ! sudo git -C "$repo" diff --cached --quiet; then
    sudo git -C "$repo" commit -m "gate.json: re-sync from the cross-validation workers" >> "$LOG" 2>&1 || true
  fi
}

takeover_backends() {
  local be
  for be in $(bash "$WORKSPACE/harness/triage.sh" --list-backends 2>/dev/null || true); do
    if ! worker_alive "$WORKSPACE/sh2perl/backends/$be/loop-backend-$be.pid"; then
      echo "[$(date +%FT%T)] backend $be worker NOT running — triage taking over" >> "$LOG"
      bash "$WORKSPACE/setup_backends.sh" --backend-worker-once "$be" >> "$LOG" 2>&1 || true
    fi
  done
}

# rotate through the frontends; a lease defers to a desktop
FRONTENDS=(c-sh-go cpp-sh-go bat-sh-go py-sh-go perl-sh-go posix-sh-go zsh-sh-go fish-sh-go go-sh powershell-sh-go rust-frontend zig-sh-go sh2perl)
while true; do
  if [ -f "$WORKSPACE/.leases/triage" ]; then
    echo "[$(date +%FT%T)] triage: leased to $(cut -d' ' -f1 "$WORKSPACE/.leases/triage") — yielding" >> "$LOG"
    sleep 300; continue
  fi
  for fe in "${FRONTENDS[@]}"; do
    bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
    takeover_frontend "$fe"
    takeover_backends
    cycle "$fe" || true
    sync_gui_gate
    sleep 60
  done
  sleep 600
done
