#!/usr/bin/env bash
# rust-dogfood.sh — the dogfooding scoreboard for the rust-frontend.
#
# The rust-frontend's stated v0.2 goal is to lower ALL of sh2perl's own Rust
# source (`sh2perl/src/**/*.rs`, FRONTEND.md "the src/ coverage push"). This
# script is the reproducible measurement of that goal: how many of the
# transpiler's OWN source files the transpiler can lower to A1 shIR with no
# refusal, plus a histogram of the FIRST blocker per refused file.
#
# Why a first-blocker histogram: each file stops at its first refusal, so a
# per-file histogram is a frontier, not a census. A blocker that appears 7
# times may unblock 0 files (they all hit a second blocker). The `--census`
# mode runs the syn tally over the whole tree for the true idiom weights.
#
# Reproducibility: the source tree is read from a SNAPSHOT taken once per run
# (the live sh2perl/src is rewritten by fleet workers concurrently, and a
# mid-run edit makes the score jump). The snapshot is content-addressed by a
# tarball hash so the recorded score names the exact bytes it measured.
#
# Usage:
#   harness/rust-dogfood.sh                 # score + first-blocker histogram
#   harness/rust-dogfood.sh --quiet         # score only (gate form)
#   harness/rust-dogfood.sh --json          # machine-readable, for the gate
#   harness/rust-dogfood.sh --list          # per-file PASS/REFUSE + blocker
#
# Exit: 0 normally; with --min N, non-zero if the pass count < N (regression
# guard: the number may only go UP, and a red score is a real red).
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
# Piped/re-exec'd invocation (`bash -s < script`) leaves no usable $0 —
# fall back to git so the script still finds the workspace it lives in.
if [ ! -d "$ROOT/sh2perl/src" ]; then
  ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]:-$0}")" rev-parse --show-toplevel 2>/dev/null || true)
fi
SRCDIR=${SRCDIR:-$ROOT/sh2perl/src}
FE=${FE:-$ROOT/sh2perl/frontends/rust-frontend/target/debug/rust-frontend}
TMO=${TMO:-120}
MODE=full
MIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) MODE=quiet; shift;;
    --json) MODE=json; shift;;
    --list) MODE=list; shift;;
    --min) MIN=$2; shift 2;;
    --min=*) MIN=${1#--min=}; shift;;
    *) echo "rust-dogfood: unknown arg $1" >&2; exit 2;;
  esac
done

[ -x "$FE" ] || {
  echo "rust-dogfood: no rust-frontend at $FE" >&2
  echo "  build it: (cd sh2perl/frontends/rust-frontend && cargo build --offline)" >&2
  exit 2
}

# --- snapshot the source tree (content-addressed) -------------------------
SNAP=$(mktemp -d "${TMPDIR:-/tmp}/rust-dogfood.XXXXXX") || exit 1
trap 'rm -rf "$SNAP"' EXIT
mkdir -p "$SNAP/src"
# copy the tree without mutating the measured bytes
( cd "$SRCDIR" && tar cf - . ) 2>/dev/null | ( cd "$SNAP/src" && tar xf - ) || {
  echo "rust-dogfood: cannot snapshot $SRCDIR" >&2; exit 2; }
SRC_HASH=$( cd "$SNAP/src" && find . -name '*.rs' -print0 \
              | sort -z | xargs -0 cat | sha256sum | cut -c1-16 )

mapfile -t FILES < <( cd "$SNAP/src" && find . -name '*.rs' | sort )
total=${#FILES[@]}
[ "$total" -gt 0 ] || { echo "rust-dogfood: no .rs files under $SRCDIR" >&2; exit 2; }

# --- run the frontend over every file -------------------------------------
pass=0; refuse=0; crash=0
declare -A HIST=()
LIST=()
for rel in "${FILES[@]}"; do
  f="$SNAP/src/$rel"
  # the frontend prints the refusal on stderr and exits non-zero
  err=$(timeout "$TMO" "$FE" --shir "$f" --raw 2>&1 >/dev/null)
  rc=$?
  if [ $rc -eq 0 ]; then
    pass=$((pass+1))
    LIST+=("PASS	${rel#./}	")
    continue
  fi
  if [ $rc -eq 124 ]; then
    crash=$((crash+1))
    key="TIMEOUT (>${TMO}s)"
  else
    refuse=$((refuse+1))
    # first blocker: the LAST "unsupported Rust:" line is the site that
    # actually stopped emission; normalize the backticked detail so the
    # histogram groups by CLASS.
    key=$(printf '%s\n' "$err" \
          | grep -o 'unsupported Rust: .*' | head -1 \
          | sed 's/ (line [0-9]*)$//; s/ (line [0-9]*//; s/`[^`]*`/`X`/g')
    [ -n "$key" ] || key="(no diagnostic — build/crash)"
  fi
  HIST["$key"]=$(( ${HIST["$key"]:-0} + 1 ))
  LIST+=("REFUSE	${rel#./}	$key")
done

pct=$(awk -v p="$pass" -v t="$total" 'BEGIN{printf "%.1f", (t?100*p/t:0)}')

case "$MODE" in
  json)
    printf '{"total":%d,"pass":%d,"refuse":%d,"crash":%d,"pct":"%s","src_hash":"%s"}\n' \
      "$total" "$pass" "$refuse" "$crash" "$pct" "$SRC_HASH"
    ;;
  list)
    printf '%s\n' "${LIST[@]}"
    ;;
  quiet)
    printf 'dogfood %d/%d (%s%%) src=%s\n' "$pass" "$total" "$pct" "$SRC_HASH"
    ;;
  full)
    echo "rust-frontend dogfooding scoreboard"
    echo "  source:      $SRCDIR"
    echo "  src hash:    $SRC_HASH  ($total .rs files)"
    echo "  LOWERED:     $pass / $total  ($pct%)"
    echo "  refused:     $refuse"
    [ "$crash" -gt 0 ] && echo "  TIMEOUT:     $crash"
    echo
    echo "  first-blocker histogram (each file stops at its FIRST refusal):"
    for k in "${!HIST[@]}"; do printf '%d\t%s\n' "${HIST[$k]}" "$k"; done \
      | sort -rn | awk -F'\t' '{printf "  %3d  %s\n", $1, $2}'
    echo
    echo "  (the census over the WHOLE tree, not just first-blockers:"
    echo "   cd sh2perl/frontends/rust-frontend && ./target/debug/census $SRCDIR/*.rs)"
    ;;
esac

if [ "$pass" -lt "$MIN" ]; then
  echo "rust-dogfood: REGRESSION — lowered $pass < required $MIN" >&2
  exit 1
fi
