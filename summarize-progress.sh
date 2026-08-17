#!/usr/bin/env bash
# summarize-progress.sh — a progress summary from the workers' LAST gate
# reports (the NEW worker model: core/contract is a separate marketplace
# worker; estree is re-scoped to the corpus/emission).
#
# Each gate writes a timestamped report line to a KNOWN file under
# gate-reports/ (the newest line is the latest report); this script reads
# those files. Workers without a report file yet fall back to the last
# matching line in their loop log.
#
#   gate-reports/core-worker.report      ← run_core_worker.sh (marketplace:
#                                          A1-native ladder + pending reqs)
#   gate-reports/estree.report           ← fail-estree (estree: corpus/emission)
#   gate-reports/backend-<lang>.report   ← --backend-gate <lang>
#   gate-reports/go-js.report            ← fail-go (Go→JS/Rust corpus)
#   gate-reports/frontend-go-sh.report   ← go-sh frontend worker gate
#   gate-reports/idiom-triage.report     ← run_go_idiom_worker pass
#   gate-reports/triage.report           ← run_triage_worker cycle
#
# Does NOT run any gate — the reports are the source (fast, no load).
set -u
cd "$(dirname "$0")"
ROOT="$(pwd)"
REP="$ROOT/gate-reports"

now() { date +%s; }
age() {  # file -> "12m ago" / "-"
  [ -f "$1" ] || { echo "-"; return; }
  echo "$(( ($(now) - $(stat -c %Y "$1")) / 60 ))m ago"
}

# name | report file | pgrep (alive) | fallback log | fallback patterns
workers=(
  # ── the NEW model: core/contract is the marketplace owner; estree is
  #    the corpus/emission worker (requests deferred via CORE_WORKER_ACTIVE)
  "core/contract|$REP/core-worker.report|run_core_worker|$ROOT/loop-core-worker.log|core-worker: (GREEN|RED)|core-worker: iterating|A1-native invariant"
  "estree (corpus)|$REP/estree.report|main_loop_estree|$ROOT/loop-estree.log|estree [0-9]+/[0-9]+|ESTREE: [0-9]+/[0-9]+|[0-9]+/[0-9]+ pass"
  # ── the shIR normalisation worker (transform producer) ──────────────
  "shir (normalisation)|$REP/shir.report|main_loop_shir|$ROOT/loop-shir.log|SHIR: [0-9]+ files bash-free|shir: VERIFIED|shir: submission OUTCOME|shir: NOT verified"
  # ── the frontends / idiom-triage ─────────────────────────────────────
  "go-sh frontend|$REP/frontend-go-sh.report|frontends/go-sh/run_frontend_worker|$ROOT/loop-frontend-go-sh.log|fail-go: [0-9]+/[0-9]+ js pass|go-sh: gate (GREEN|FAILED)|frontend-stdout \\[go\\]: [0-9]+/[0-9]+ match"
  "cpp-sh-go frontend|$REP/frontend-cpp-sh-go.report|frontends/cpp-sh-go/run_frontend_worker|$ROOT/loop-frontend-cpp-sh-go.log|frontend-stdout \\[cpp\\]: [0-9]+/[0-9]+ match|C-invariant: c-sh-go corpus stays green"
  "idiom-triage|$REP/idiom-triage.report|run_go_idiom_worker|$ROOT/loop-go-idiom-worker.log|idiom-triage: (pass GREEN|app [a-z.-]+ TRANSPILES|ladder covers the app's dialect[^\"\\n]{0,30}|uncovered constructs)"
  # ── the backends ─────────────────────────────────────────────────────
  "rust backend|$REP/backend-rust.report|run-backend-worker rust|$ROOT/loop-backend-rust.log|\\[rust\\] backend gate: [^\"\\n]{0,80}|equivalence [0-9]+"
  "c backend|$REP/backend-c.report|run-backend-worker c|$ROOT/loop-backend-c.log|\\[c\\] backend gate: [^\"\\n]{0,80}"
  "perl backend|$REP/backend-perl.report|run-backend-worker perl|$ROOT/loop-backend-perl.log|\\[perl\\] backend gate: [^\"\\n]{0,80}"
  "sh backend|$REP/backend-sh.report|run-backend-worker sh|$ROOT/loop-backend-sh.log|\\[sh\\] backend gate: [^\"\\n]{0,80}"
  "go→js/rust|$REP/go-js.report|fail-go|$ROOT/loop-frontend-go-sh.log|fail-go: [0-9]+/[0-9]+ js pass, [0-9]+/[0-9]+ rust pass"
  # ── cross-product ────────────────────────────────────────────────────
  "triage|$REP/triage.report|run_triage_worker|$ROOT/loop-triage-worker.log|triage: cycle [a-z-]+ done|PASS[a-z-]* [^\"\\n]{0,60}"
)

ALL="${1:-}"
printf '%-16s %-7s %-72s %s\n' "worker" "alive" "last gate report" "age"
printf '%-16s %-7s %-72s %s\n' "------" "-----" "----------------" "---"
for w in "${workers[@]}"; do
  IFS='|' read -r name rep pgrep log pats <<< "$w"
  # primary: the known report file (newest line = the last report)
  if [ -f "$rep" ]; then
    line=$(tail -1 "$rep")
  elif [ -f "$log" ]; then
    line=$(grep -aoE "$pats" "$log" 2>/dev/null | tail -1)
    line="${line:-no gate report yet}"
  else
    line="no log/report"
  fi
  alive="-"
  [ -n "$pgrep" ] && pgrep -f "$pgrep" >/dev/null 2>&1 && alive="yes"
  src="$rep"
  [ -f "$rep" ] || src="$log"
  printf '%-16s %-7s %-72s %s\n' "$name" "$alive" "${line:0:72}" "$(age "$src")"
done

# ── marketplace queue (PLAN §11 channels) ──────────────────────────────
# the artifacts the LLM-free core consumes: transform offers, contract-gen
# specs, and bundles (a node + its transforms) — pending in the channels.
offers=$(ls core-requests/transforms/offered/*.rs 2>/dev/null | wc -l)
specs=$(ls core-requests/contracts/*.json 2>/dev/null | wc -l)
bundles=$(ls -d core-requests/bundles/*/ 2>/dev/null | wc -l)
accepted=$(ls core-requests/transforms/done/*.rs 2>/dev/null | wc -l)
rejected=$(ls core-requests/transforms/rejected/*.rs 2>/dev/null | wc -l)
echo ""
echo "marketplace queue: $offers offer(s), $specs spec(s), $bundles bundle(s) pending | $accepted accepted, $rejected rejected"
for b in core-requests/bundles/*/; do
  [ -d "$b" ] || continue
  bn=$(basename "$b")
  # per-offer status from the verdicts log (OFFER-OK / OFFER-FAIL /
  # PLACEHOLDER / ACCEPTED) — the count alone was ambiguous
  for x in "$b"/transforms/*.rs; do
    [ -f "$x" ] || continue
    xn=$(basename "$x" .rs)
    st="PENDING"
    grep -q "PLACEHOLDER" "$x" && st="PLACEHOLDER"
    v=$(grep "bundle:$bn/$xn" core-requests/transforms/verdicts.log 2>/dev/null | tail -1)
    [ -n "$v" ] && st=$(echo "$v" | awk -F'\t' '{print $3}')
    echo "  bundle $bn/$xn: $st"
  done
done
