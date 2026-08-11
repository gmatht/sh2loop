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
  # diff the NEW verdict rows (epoch > baseline) against the baseline;
  # escalate status changes to a FAIL-* that weren't escalated before.
  local new_rows; new_rows=$(awk -F'\t' -v fe="$fe" '$1==fe' "$TRIAGE/verdicts.tsv" 2>/dev/null || true)
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
  # refresh the baseline for this frontend (latest status per pair)
  awk -F'\t' -v fe="$fe" '$1==fe {print $1"\t"$2"\t"$3"\t"$4}' "$TRIAGE/verdicts.tsv" 2>/dev/null \
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

# rotate through the frontends; a lease defers to a desktop
FRONTENDS=(c-sh-go cpp-sh-go bat-sh-go py-sh-go perl-sh-go posix-sh-go zsh-sh-go fish-sh-go)
while true; do
  if [ -f "$WORKSPACE/.leases/triage" ]; then
    echo "[$(date +%FT%T)] triage: leased to $(cut -d' ' -f1 "$WORKSPACE/.leases/triage") — yielding" >> "$LOG"
    sleep 300; continue
  fi
  for fe in "${FRONTENDS[@]}"; do
    bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
    cycle "$fe" || true
    sleep 60
  done
  sleep 600
done
