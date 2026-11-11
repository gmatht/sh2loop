#!/bin/bash
# harness/render-snapshot.sh — golden rendered output over a deterministic
# sample of the corpus.
#
# WHY: `fail-rs` compares program BEHAVIOUR, so a render can change everywhere
# and still pass — a renamed helper, a dead rule that stops firing, cosmetic
# churn. Two landed changes were exactly that kind: D1's helper-name collision
# (77 helper entries rendering 75 distinct names) and D4's program-wide BigInt
# sweep changed every affected emission without moving a single gate verdict.
# A byte-level snapshot over a sample makes that visible as a reviewable diff.
#
# Usage:
#   ./harness/render-snapshot.sh              check: exit 1 on any drift
#   ./harness/render-snapshot.sh --update     rewrite the snapshot from today
#   ./harness/render-snapshot.sh --verbose    print every compared file
#   SAMPLE=37 ./harness/render-snapshot.sh    every Nth example (default 37)
#   BACKENDS=rs,c ./harness/render-snapshot.sh  targets, comma separated (default rs)
#
# The sample is every Nth file in sorted order, so it is stable and covers the
# corpus evenly without listing files. Snapshot layout:
# harness/render-snapshot/<example>.<backend>. Diffs are printed (first 12
# lines each) so a drift is reviewable; `--update` is a deliberate decision,
# never automatic, and must be in its own commit.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
EX="$ROOT/sh2perl/examples"
DIR="$ROOT/harness/render-snapshot"
SAMPLE="${SAMPLE:-37}"
BACKENDS="${BACKENDS:-rs}"
mode=check; verbose=0
for a in "$@"; do
  case "$a" in
    --update) mode=update ;;
    --check) mode=check ;;
    --verbose) verbose=1 ;;
    -*) echo "render-snapshot: unknown argument $a" >&2; exit 2 ;;
    *) echo "render-snapshot: unexpected argument $a" >&2; exit 2 ;;
  esac
done
[ -x "$CLI" ] || { echo "render-snapshot: no CLI at $CLI" >&2; exit 2; }
[ -d "$EX" ] || { echo "render-snapshot: no corpus at $EX" >&2; exit 2; }

mapfile -t ALL < <( cd "$EX" && ls -1 *.sh 2>/dev/null | sort )
[ "${#ALL[@]}" -gt 0 ] || { echo "render-snapshot: empty corpus" >&2; exit 2; }
sel=()
for ((i = 0; i < ${#ALL[@]}; i += SAMPLE)); do sel+=("${ALL[$i]}"); done

mkdir -p "$DIR"
tmpd=$(mktemp -d "${TMPDIR:-/tmp}/render-snapshot.XXXXXX") || exit 1
trap 'rm -rf "$tmpd"' EXIT

changed=0; missing=0; wrote=0
for f in "${sel[@]}"; do
  name="${f%.sh}"
  for b in ${BACKENDS//,/ }; do
    snap="$DIR/$name.$b"
    out="$tmpd/$name.$b"
    if ! "$CLI" --target "$b" "$EX/$f" > "$out" 2>/dev/null || [ ! -s "$out" ]; then
      echo "EMIT-FAIL $name [$b]"
      changed=$((changed + 1))
      continue
    fi
    if [ "$mode" = update ]; then
      cp "$out" "$snap"; wrote=$((wrote + 1))
      continue
    fi
    if [ ! -f "$snap" ]; then
      echo "MISSING  $name [$b]  (no snapshot; --update to record it)"
      missing=$((missing + 1))
      continue
    fi
    if cmp -s "$out" "$snap"; then
      [ "$verbose" = 1 ] && echo "ok       $name [$b]"
      continue
    fi
    changed=$((changed + 1))
    echo "CHANGED  $name [$b]"
    diff -u "$snap" "$out" | head -12 | sed 's/^/    /'
  done
done

if [ "$mode" = update ]; then
  echo "render-snapshot: wrote $wrote file(s) to harness/render-snapshot (sample=$SAMPLE, backends=$BACKENDS)"
  exit 0
fi
echo "render-snapshot: ${#sel[@]} program(s) x [$BACKENDS], $changed changed, $missing missing"
if [ "$changed" -gt 0 ] || [ "$missing" -gt 0 ]; then
  echo "render-snapshot: DRIFT — review the diff above, then --update in its own commit"
  exit 1
fi
echo "render-snapshot: no drift"
exit 0
