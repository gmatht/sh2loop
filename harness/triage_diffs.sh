#!/usr/bin/env bash
# triage_diffs.sh — for each failing file, render + run bash vs perl, save diff head.
# Usage: triage_diffs.sh <fail_list_file> <outdir>
# fail_list_file: basenames, one per line. outdir: gets <base>.diff + summary.tsv
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
SUB="$ROOT/sh2perl"
OTRANS="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
SR="$SUB/backends/perl/target/debug/shir_render"
export OTRANSPILER_ROOT="$ROOT"
LIST="$1"; OUT="$2"
mkdir -p "$OUT"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
: > "$OUT/summary.tsv"
while IFS= read -r b; do
  [ -n "$b" ] || continue
  f=$(ls "$SUB"/examples/"$b" "$SUB"/frontends/*/testdata/"$b" 2>/dev/null | head -1 || true)
  [ -n "$f" ] || { printf '%s\tNO-SRC\n' "$b" >> "$OUT/summary.tsv"; continue; }
  shir=$("$OTRANS" --target shir "$f" 2>/dev/null) || { printf '%s\tEMIT-FAIL\n' "$b" >> "$OUT/summary.tsv"; continue; }
  [ -n "$shir" ] || { printf '%s\tEMIT-EMPTY\n' "$b" >> "$OUT/summary.tsv"; continue; }
  if ! g_out=$(printf '%s' "$shir" | "$SR" --target=perl - 2>/dev/null); then
    printf '%s\tRENDER-FAIL\n' "$b" >> "$OUT/summary.tsv"; continue
  fi
  s=$(printf '%s' "$g_out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  if [ "$s" -ne 0 ]; then printf '%s\tSTUB(%s)\n' "$b" "$s" >> "$OUT/summary.tsv"; continue; fi
  printf '%s' "$g_out" > "$tmp/eq.pl"
  qx=$(perl "$ROOT/check_qx.pl" "$tmp/eq.pl" 2>/dev/null | command grep -c FAIL || true)
  if [ "${qx:-0}" -gt 0 ]; then printf '%s\tQX\n' "$b" >> "$OUT/summary.tsv"; continue; fi
  wdir="$tmp/w"; mkdir -p "$wdir"; rm -f "$wdir"/*
  ( cd "$wdir" && timeout 10 perl "$tmp/eq.pl" >"$tmp/mine.out" 2>"$tmp/mine.err" </dev/null ); mrc=$?
  ( cd "$wdir" && timeout 10 bash "$f" >"$tmp/ref.out" 2>/dev/null </dev/null ); rrc=$?
  head -c 200000 "$tmp/mine.out" > "$tmp/mine.cap" 2>/dev/null
  head -c 200000 "$tmp/ref.out" > "$tmp/ref.cap" 2>/dev/null
  if cmp -s "$tmp/mine.cap" "$tmp/ref.cap" && [ "$mrc" = "$rrc" ]; then
    printf '%s\tPASS-NOW(rc=%s)\n' "$b" "$mrc" >> "$OUT/summary.tsv"
  else
    { echo "rc mine=$mrc bash=$rrc"; diff "$tmp/ref.cap" "$tmp/mine.cap" | head -30; echo "--- STDERR(mine):"; head -c 2000 "$tmp/mine.err"; } > "$OUT/$b.diff"
    printf '%s\tEQUIV(rc mine=%s bash=%s)\n' "$b" "$mrc" "$rrc" >> "$OUT/summary.tsv"
  fi
done < "$LIST"
echo "done: $(wc -l < "$OUT/summary.tsv") files"
