#!/usr/bin/env bash
# transform-laws.sh — the Tier-2 property gate for EVERY registered shIR→shIR
# transform (docs/transform-verification.md).
#
# Runs `tests/transform_laws.rs` in a sh2perl worktree and reports, per law,
# which transforms violated it. Four laws, all about the transform as a
# FUNCTION (no shell semantics):
#
#   determinism      f(p) is a function of p (verdict statics reset per run)
#   idempotence      f(f(p)) == f(p), except transforms declared SINGLE_PASS
#   forbidden-shape  per-transform "no shape outside the declared one"
#   perl-invariance  shir_to_perl(f(p)) == shir_to_perl(p) for RENDER_EQUIV
#
# The harness also prints a COVERAGE line: how many transforms actually
# REWROTE at least one generated program. A law that never fires on a
# transform proves nothing about it, so the coverage line is part of the
# verdict — this script exits 1 if a law fails, and prints the idle list as
# a warning (a generator gap, not a transform bug).
#
# Usage:
#   harness/transform-laws.sh [--worktree DIR] [--cases N] [--json]
#
# --worktree defaults to ./sh2perl. The test is built into a DISTINCT
# CARGO_TARGET_DIR by default (SH2_TARGET_DIR overrides): the shared
# otranspilerl/target is stale/racy on this box, and a gate that silently
# tests an old binary is worse than no gate.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WT="$ROOT/sh2perl"
CASES="${PROPTEST_CASES:-64}"
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) WT="$(cd "$2" && pwd)"; shift 2 ;;
    --cases)    CASES="$2"; shift 2 ;;
    --json)     JSON=1; shift ;;
    -h|--help)  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$WT/Cargo.toml" ]; then
  echo "transform-laws: no Cargo.toml under $WT" >&2
  exit 2
fi
if [ ! -f "$WT/tests/transform_laws.rs" ]; then
  echo "transform-laws: $WT/tests/transform_laws.rs missing (is this worktree up to date?)" >&2
  exit 2
fi

TARGET_DIR="${SH2_TARGET_DIR:-$WT/target-transform-laws}"
LOG="$(mktemp -t transform-laws.XXXXXX.log)"

if ! ( cd "$WT" && CARGO_TARGET_DIR="$TARGET_DIR" PROPTEST_CASES="$CASES" \
        cargo test --test transform_laws -- --test-threads=1 --nocapture ) >"$LOG" 2>&1; then
  STATUS=1
else
  STATUS=0
fi

# Per-law verdicts and the coverage line, straight from the harness output.
grep -E '^== law: |^LAW (determinism|idempotence|forbidden-shape|perl-invariance) (FAILED|input): |^COVERAGE ' "$LOG" \
  | sed 's/^== law: /law: /' > "$LOG.facts"

if [ "$JSON" = 1 ]; then
  python3 - "$LOG.facts" "$STATUS" "$CASES" <<'PY'
import json, sys
facts = open(sys.argv[1]).read().splitlines()
cov = next((l for l in facts if l.startswith("COVERAGE ")), "")
fails = [l for l in facts if " FAILED: " in l]
print(json.dumps({
    "status": "fail" if sys.argv[2] == "1" else "pass",
    "cases": int(sys.argv[3]),
    "coverage": cov[len("COVERAGE "):] if cov else None,
    "failures": fails,
}, indent=2))
PY
else
  cat "$LOG.facts"
  echo
  if [ "$STATUS" = 0 ]; then
    echo "transform-laws: PASS (cases=$CASES)"
  else
    echo "transform-laws: FAIL (cases=$CASES) — full log: $LOG" >&2
  fi
fi

[ "$STATUS" = 0 ] && rm -f "$LOG" "$LOG.facts"
exit "$STATUS"
