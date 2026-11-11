#!/bin/bash
# harness/unsupported-census.sh — what each backend cannot lower, measured.
#
# WHY: every backend emits a TODO marker where it has no arm for a construct,
# and a TODO prints NOTHING where bash prints something — a silent wrong
# answer. Until now the only way to learn the set of unsupported classes was
# to read them out of a render by hand, so "rust is ahead here / c is behind
# there" was folklore. This is the per-backend table:
#
#   * markers per backend, programs carrying them, and a shape histogram
#     (`TODO(unsupported): <shape>` for rust, the TODO text for the others);
#   * `--check` against harness/unsupported-baseline.json: a shape that
#     appears where none was before is a regression (fail); a shape that
#     disappears is progress, recorded with --update.
#
# Usage:
#   ./harness/unsupported-census.sh                  all backends, table
#   ./harness/unsupported-census.sh --backend rs     one backend
#   ./harness/unsupported-census.sh --json           machine-readable
#   ./harness/unsupported-census.sh --update         rewrite the baseline
#   ./harness/unsupported-census.sh --check          drift check only
#   ./harness/unsupported-census.sh <prefix>         examples starting with it
#
# Exit: 0 clean, 1 new shape (only with --check), 2 no CLI.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
EX="$ROOT/sh2perl/examples"
BASE="$ROOT/harness/unsupported-baseline.json"
[ -x "$CLI" ] || { echo "unsupported-census: no CLI at $CLI" >&2; exit 2; }

backend=""; json=0; update=0; check=0; prefix=""
for a in "$@"; do
  case "$a" in
    --backend) : ;;
    --backend=*) backend="${a#--backend=}" ;;
    --json) json=1 ;;
    --update) update=1 ;;
    --check) check=1 ;;
    -*) echo "unsupported-census: unknown argument $a" >&2; exit 2 ;;
    *) prefix="$a" ;;
  esac
done
prev=""
for a in "$@"; do
  [ "$prev" = "--backend" ] && backend="$a"
  prev="$a"
done
[ -n "$backend" ] || backend="rs c py js"

tmp=$(mktemp) || exit 1
trap 'rm -rf "$tmp" "$tmp.d"' EXIT
mkdir -p "$tmp.d"

rendered=0
for b in $backend; do
  for f in "$EX"/"$prefix"*.sh; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .sh)
    out="$("$CLI" --target "$b" "$f" 2>/dev/null)" || continue
    [ -n "$out" ] || continue
    rendered=$((rendered + 1))
    # shape = the marker's payload, comment leader and variable tails removed
    shapes=$(printf '%s\n' "$out" |
      command grep -oE 'TODO(\(unsupported\))?:? [^*/#]*' |
      sed 's/^TODO(\?unsupported)\?: *//; s/^TODO: *//' |
      sed 's/[[:space:]]*$//' |
      command grep -v '^$' | sort -u)
    [ -n "$shapes" ] || continue
    printf '%s\n' "$shapes" >> "$tmp"
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      printf '%s|%s|%s\n' "$b" "$name" "$s" >> "$tmp.d/pairs"
    done <<< "$shapes"
  done
done

if [ "$update" = 1 ]; then
  python3 - "$tmp.d/pairs" "$BASE" <<'PY'
import json, sys
pairs, base = sys.argv[1], sys.argv[2]
d = {}
try:
    for line in open(pairs):
        b, _, s = line.rstrip("\n").partition("|")
        s = s.partition("|")[2]
        d.setdefault(b, [])
        if s not in d[b]:
            d[b].append(s)
except FileNotFoundError:
    pass
for b in d:
    d[b].sort()
json.dump({"shapes": d}, open(base, "w"), indent=1, sort_keys=True)
open(base, "a").write("\n")
print(f"unsupported-census: baseline written ({sum(len(v) for v in d.values())} shapes)")
PY
  exit $?
fi

if [ "$json" = 1 ]; then
  python3 - "$tmp.d/pairs" <<'PY'
import json, sys
progs, shp = {}, {}
try:
    for line in open(sys.argv[1]):
        b, n, s = line.rstrip("\n").split("|", 2)
        progs.setdefault(b, set()).add(n)
        shp.setdefault(b, {})
        shp[b][s] = shp[b].get(s, 0) + 1
except FileNotFoundError:
    pass
print(json.dumps({b: {"programs": len(progs.get(b, ())),
                      "shapes": shp.get(b, {})} for b in shp}, indent=1, sort_keys=True))
PY
  exit 0
fi

python3 - "$tmp.d/pairs" "$BASE" "$check" <<'PY'
import json, os, sys
pairs, base, check = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
progs, shp = {}, {}
try:
    for line in open(pairs):
        b, n, s = line.rstrip("\n").split("|", 2)
        progs.setdefault(b, set()).add(n)
        shp.setdefault(b, {})
        shp[b][s] = shp[b].get(s, 0) + 1
except FileNotFoundError:
    pass
new = {}
if check and os.path.exists(base):
    old = json.load(open(base)).get("shapes", {})
    for b in shp:
        for s in shp[b]:
            if s not in old.get(b, []):
                new.setdefault(b, []).append(s)
print("  backend  programs  markers  shapes")
for b in sorted(shp):
    print(f"  {b:<7}  {len(progs.get(b, ())):>8}  {sum(shp[b].values()):>7}  {len(shp[b]):>6}")
for b in sorted(shp):
    top = sorted(shp[b].items(), key=lambda kv: -kv[1])[:6]
    print(f"\n  {b} top shapes:")
    for s, n in top:
        print(f"    {n:>4}  {s[:100]}")
if new:
    print("\nunsupported-census: NEW unsupported shapes (regression):")
    for b, ss in new.items():
        for s in ss:
            print(f"    {b}: {s[:100]}")
    sys.exit(1)
if check:
    print("\nunsupported-census: no new unsupported shape")
PY
