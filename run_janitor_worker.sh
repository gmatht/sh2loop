#!/usr/bin/env bash
# run_janitor_worker.sh — the BACKLOG JANITOR: decides which OLD core
# requests (open + stalled) become NEW-spec marketplace bundles, gives a
# reason for every decision, and resubmits the good ones. The janitor is
# the AUTHOR (LLM) side of the marketplace — the core worker stays the
# LLM-free gate. The janitor does NOT gate; it only converts + submits.
#
# Each iteration:
#   1. scan the old requests (core-requests/*.md + stalled/*.md) that
#      have no conversion marker yet,
#   2. classify each: CONVERT (shared A1/IR transform → write the bundle
#      transform.rs + register + manifest with OFFERED-TO) / SUPERSEDED
#      (already landed — name the transform) / NOT-A-TRANSFORM (renderer-
#      specific — stays with its worker) / DUPLICATE (merge into another),
#      with a REASON for every verdict,
#   3. resubmit the CONVERTed bundles to core-requests/transforms/<name>/
#      (the core worker's gate picks them up), append the verdict marker
#      to the source request, and record the reason in
#      core-requests/janitor-verdicts.tsv.
#
# Scope: core-requests/ only. Never touches the code (sh2perl/src) — the
# core worker gates what this worker submits.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
REQS="$ROOT/core-requests"
LOG="$ROOT/loop-janitor-worker.log"
VERDICTS="$REQS/janitor-verdicts.tsv"
MODEL="${MODEL:-deepseek-v4-flash}"
THINKING="${THINKING:-xhigh}"
WATCH="${WATCH:-900}"
MAX_PER_RUN="${MAX_PER_RUN:-4}"   # requests classified per iteration (pi budget)

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$REQS/transforms"
[ -f "$VERDICTS" ] || printf 'request\tverdict\treason\tbundle\n' > "$VERDICTS"
echo "[$(date +%FT%T)] janitor worker started (pid=$$)" >> "$LOG"

# old requests not yet converted (no marker, no bundle, not already judged).
# ORDER: the stalled estree-20260813 A1-optimization backlog FIRST (the
# known CONVERT-candidates — const-fold, DCE, SSA, loop passes...), then
# the other stalled, then the open requests (newest first).
pending_requests() {
  {
    ls "$REQS/stalled"/estree-20260813-*.md 2>/dev/null
    ls "$REQS/stalled"/*.md 2>/dev/null | grep -v estree-20260813
    ls "$REQS"/*.md 2>/dev/null | grep -vE "/(done|stalled|offered|rejected)/"
  } | while read -r f; do
    grep -q "## CONVERTED-TO\|## SUPERSEDED\|## NOT-A-TRANSFORM\|## DUPLICATE" "$f" 2>/dev/null && continue
    echo "$f"
  done | head -"$MAX_PER_RUN" || true
}

# does a bundle already exist for this request (name-derived)?
has_bundle() { # request file
  local name; name=$(basename "$1" .md)
  for d in "$REQS"/transforms/*/; do
    [ -d "$d" ] && grep -q "$name" "$d/manifest" 2>/dev/null && return 0
  done
  return 1
}

while true; do
  echo "[$(date +%FT%T)] janitor: iteration start" >> "$LOG"
  pending=$(pending_requests)
  if [ -z "$pending" ]; then
    echo "[$(date +%FT%T)] janitor: no unconverted requests — backlog clean" >> "$LOG"
    sleep "$WATCH"
    continue
  fi
  echo "[$(date +%FT%T)] janitor: $(echo "$pending" | wc -l) request(s) to classify" >> "$LOG"

  {
    printf 'You are the BACKLOG JANITOR for the shIR marketplace (PLAN.md §11).\n'
    printf 'Decide which OLD core requests become NEW-spec marketplace bundles, give a\n'
    printf 'REASON for every decision, and resubmit the good ones.\n\n'
    printf 'The new spec: a bundle is a directory core-requests/transforms/<name>/ with\n'
    printf '  transform.rs     a concrete, self-contained IR transform (fn(&mut Vec<IrStmt>)\n'
    printf '                   -> bool — see core-requests/transforms/sync-ok-loops.rs for the\n'
    printf '                   shape; the shared A1 ops are the model, e.g. grepMatches/Range)\n'
    printf '  register         two sections: "### mod\\npub mod <name>;\\n### all\\n        (<name>-lift, <name>::transform),\\n"\n'
    printf '  manifest         prereqs / invariant / scope / ## OFFERED-TO: <backends>\n'
    printf '  contract.patch   (only if the op needs a new ingress — a git diff the core\n'
    printf '                   applies ahead of the transform)\n\n'
    printf 'Classification rubric (every verdict needs a REASON):\n'
    printf '  CONVERT        a shared A1/IR-level transform the backends would benefit from\n'
    printf '                 (const-folding, DCE, SSA copy-prop, loop passes, case-lookup\n'
    printf '                 lifts) — WRITE the bundle (transform.rs + register + manifest\n'
    printf '                 + OFFERED-TO) into core-requests/transforms/<name>/.\n'
    printf '  SUPERSEDED     already landed (the builtin op, sync-ok-loops, ...) — name the\n'
    printf '                 landed transform.\n'
    printf '  NOT-A-TRANSFORM renderer-specific emission (estree inlining, split-elide, ...)\n'
    printf '                 — stays with its worker; do not bundle.\n'
    printf '  DUPLICATE      another request already covers it — name the merge target.\n\n'
    printf 'Reference: core-requests/MARKETPLACE-ESTREE-CLASSIFICATION.md has the stalled\n'
    printf 'estree-20260813 backlog classified (12 core-bound, 5 estree, 2 split).\n\n'
    printf 'The pending requests (classify each):\\n'
    for f in $pending; do
      printf '===== %s =====\n' "$(basename "$f")"
      head -40 "$f"
      printf '\n'
    done
    printf '\nFor every request append a marker line to the request file:\n'
    printf '  ## CONVERTED-TO: <bundle-name>\\n  ## REASON: <why>\\n'
    printf '  (or ## SUPERSEDED: <transform> / ## NOT-A-TRANSFORM: <who> / ## DUPLICATE: <other>\\n'
    printf '   + ## REASON: <why>).\\n'
    printf 'Write the CONVERTed bundles (transform.rs + register + manifest) into\n'
    printf 'core-requests/transforms/<name>/. Never touch sh2perl/src — the core worker gates.\n'
    printf 'Stage explicit paths only.\n'
  } > /tmp/janitor-prompt-$$
  pi --mode json --provider opencode-go --model "$MODEL" --thinking "$THINKING" \
     < /tmp/janitor-prompt-$$ >> "$LOG" 2>&1 || true
  rm -f /tmp/janitor-prompt-$$

  # record the verdicts from the markers pi appended
  for f in $pending; do
    name=$(basename "$f" .md)
    marker=$(grep -oE "## (CONVERTED-TO|SUPERSEDED|NOT-A-TRANSFORM|DUPLICATE):? ?.*" "$f" 2>/dev/null | head -1)
    reason=$(grep -oE "## REASON: .*" "$f" 2>/dev/null | head -1)
    bundle=""
    case "$marker" in
      *CONVERTED-TO*) bundle=$(ls -d "$REQS"/transforms/*/ 2>/dev/null | tail -1 | xargs -r basename) ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$name" "${marker:-unmarked}" "${reason#\#\# REASON: }" "$bundle" >> "$VERDICTS"
  done
  echo "[$(date +%FT%T)] janitor: iteration done — see $VERDICTS" >> "$LOG"
  sleep "$WATCH"
done
