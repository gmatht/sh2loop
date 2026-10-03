#!/usr/bin/env bash
# perl triage: render every corpus file through the worktree's shir_render and
# classify the outcome, mirroring the gate's order of checks:
#   render-error | stub | check_qx | equiv | PASS
# Usage: harness/perl_triage.sh [outdir]   (defaults to /tmp/perl_triage)
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
SUB="$ROOT/sh2perl"
WT="$ROOT/sh2perl/backends/perl"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
BIN="$WT/target/debug/shir_render"
OUT="${1:-/tmp/perl_triage}"
mkdir -p "$OUT/renders"
[ -x "$CLI" ] || { echo "missing $CLI" >&2; exit 1; }
[ -x "$BIN" ] || { echo "missing $BIN" >&2; exit 1; }

corpus=$(ls "$SUB"/examples/*.sh "$SUB"/frontends/*/testdata/*.sh 2>/dev/null)

printf 'class\tfile\n' > "$OUT/classes.tsv"
for f in $corpus; do
  b=$(basename "$f")
  shir=$("$CLI" --target shir "$f" 2>/dev/null) || { printf 'emit\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; }
  [ -n "$shir" ] || { printf 'emit\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; }
  if ! bash -n "$f" 2>/dev/null; then printf 'skip-bashparse\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; fi
  out=$(printf '%s' "$shir" | "$BIN" --target=perl - 2>"$OUT/renders/$b.err") || {
    printf 'render\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; }
  [ -n "$out" ] || { printf 'render-empty\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; }
  printf '%s' "$out" > "$OUT/renders/$b.pl"
  s=$(printf '%s' "$out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  if [ "$s" -gt 0 ]; then printf 'stub\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; fi
  if printf '%s' "$out" | grep -qE "system\('bash',\s*'[^']*'\)"; then
    printf 'bashwrapper\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; fi
  printf '%s' "$out" > "$OUT/renders/$b.chk.pl"
  q=$(perl "$ROOT/check_qx.pl" "$OUT/renders/$b.chk.pl" 2>/dev/null | grep -c FAIL || true)
  if [ "${q:-0}" -gt 0 ]; then printf 'check_qx\t%s\n' "$b" >> "$OUT/classes.tsv"; continue; fi
  # equivalence, hermetic cwd on both sides
  d=$(mktemp -d "$ROOT/.perl_triage.XXXXXX")
  ( cd "$d" && perl "$OUT/renders/$b.chk.pl" 2>/dev/null | head -c 1048576 ) > "$d/tr.out"; trc=${PIPESTATUS[0]}
  ( cd "$d" && bash "$f" 2>/dev/null | head -c 1048576 ) > "$d/ba.out"
  if cmp -s "$d/tr.out" "$d/ba.out"; then printf 'PASS\t%s\n' "$b" >> "$OUT/classes.tsv";
  else printf 'equiv\t%s\n' "$b" >> "$OUT/classes.tsv"; fi
  rm -rf "$d"
done
echo "--- class counts ---"
awk -F'\t' 'NR>1{c[$1]++}END{for(k in c)printf "%-14s %d\n",k,c[k]}' "$OUT/classes.tsv" | sort -k2 -rn
echo "classes.tsv: $OUT/classes.tsv ; renders: $OUT/renders"
