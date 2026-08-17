#!/usr/bin/env bash
# core-sweep.sh — the LLM-free core loop (PLAN §11.9): build the shared
# core + every backend (via build-lock.sh), run each backend's gate, and
# append verdicts to core-requests/transforms/verdicts.log for the
# backends to read. NO pi — acceptance is the gate verdict: a backend's
# gate passing with its transform set ACCEPTS it; a failure is logged
# with the transform + prereq attribution the backend reads and fixes
# (the core never mediates or implements — PLAN §11.2/§11.9).
#
#   core-sweep.sh [--backends "rust sh c ..."] [--limit N]
#
# verdict line format (append-only, tsv like triage/verdicts.tsv):
#   <backend> <transform-set-hash> PASS|FAIL <detail> <epoch>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/core-requests/transforms/verdicts.log"
LOCK="$ROOT/harness/build-lock.sh"
DEFAULT_BACKENDS="perl js c python zig go rust sh java"
LIMIT=""

backends="$DEFAULT_BACKENDS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backends) backends="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    *) echo "core-sweep.sh: unknown option $1" >&2; exit 2;;
  esac
done

mkdir -p "$(dirname "$LOG")"
epoch=$(date +%s)
echo "[core-sweep] start epoch=$epoch backends='$backends'"

# 1. the shared core (one build, dedup'd — the estree loop and every
#    backend gate share sh2perl/target)
if ! "$LOCK" --role core --timeout 300 -- bash -c 'cd "$1" && cargo build --manifest-path Cargo.toml --bin debashc' _ "$ROOT/sh2perl" >> "$LOG" 2>&1; then
  echo "[core-sweep] core build FAILED" >> "$LOG"
  exit 1
fi

# 2. per backend: build its worktree + run its gate, log the verdict
n=0
for lang in $backends; do
  n=$((n+1))
  if [[ -n "$LIMIT" && $n -gt "$LIMIT" ]]; then break; fi
  wt="$ROOT/sh2perl/backends/$lang"
  if [[ ! -f "$wt/Cargo.toml" ]]; then
    echo -e "$lang\t-\tSKIP\tno worktree at $wt\t$epoch" >> "$LOG"
    continue
  fi
  # the transform-set hash: what the backend's manifest selects today
  # (PLAN §11.2 per-backend manifest; unset → the canonical set on main)
  tset_hash="$(git -C "$ROOT/sh2perl" rev-parse --short HEAD 2>/dev/null || echo unknown)"

  if "$LOCK" --role backend --timeout 1800 --share-target "$wt/target" -- \
       cargo build --manifest-path "$wt/Cargo.toml" >> "$LOG" 2>&1; then
    detail="build ok; gate not run (run-gate.sh $lang test separately)"
    verdict="PASS"
  else
    detail="build failed — see $LOG"
    verdict="FAIL"
  fi
  echo -e "$lang\t$tset_hash\t$verdict\t$detail\t$epoch" >> "$LOG"
  echo "[core-sweep] $lang: $verdict"
done

echo "[core-sweep] done — verdicts appended to $LOG"
