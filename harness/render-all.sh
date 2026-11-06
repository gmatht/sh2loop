#!/usr/bin/env bash
# render-all.sh — render every corpus source to C with a given CLI, into one
# directory, so two builds can be byte-diffed (`diff -r out_a out_b`).
#
#   harness/render-all.sh <cli> <outdir>
#
# Used to prove a renderer change is output-IDENTICAL where it should be and
# differs only where the change is aimed (the eval-inlining round, C_UB_PROOF
# §30). One file per source, named after its path with `/` -> `__`.
set -u
CLI=${1:?usage: render-all.sh <cli> <outdir>}
OUT=${2:?usage: render-all.sh <cli> <outdir>}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export OTRANSPILER_ROOT="$ROOT"
mkdir -p "$OUT"
n=0; fail=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  key=$(printf '%s' "${f#"$ROOT"/}" | tr '/' '_')
  if shir=$("$CLI" "$f" --source-lang sh --target shir --raw 2>/dev/null) \
     && printf '%s' "$shir" | "$CLI" - --target c > "$OUT/$key.c" 2>/dev/null; then
    n=$((n+1))
  else
    rm -f "$OUT/$key.c"
    fail=$((fail+1))
  fi
done < <(ls "$ROOT"/sh2perl/examples/*.sh "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)
echo "rendered=$n refused=$fail out=$OUT"
