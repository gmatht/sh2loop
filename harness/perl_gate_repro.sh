#!/bin/bash
# perl_gate_repro.sh — per-file verdict reproducer for the perl backend gate.
# Mirrors setup_backends.sh --backend-gate perl, but prints ONE LINE PER FILE
# (verdict + reason) so failures can be clustered. Read-only: writes only under
# /tmp and its own output dir.
#
# Usage: harness/perl_gate_repro.sh [outdir] [limit]
set -uo pipefail

W=/mnt/wsl/projects/sh2loop
WT=$W/sh2perl/backends/perl
SUB=$W/sh2perl
OTRANS=$W/otranspilerl/target/debug/otranspilerl-cli
BIN=$WT/target/debug/shir_render
KS=$W/harness/kill-session.sh
OUT=${1:-/tmp/perl_gate_repro}
LIMIT=${2:-0}

mkdir -p "$OUT"; rm -f "$OUT"/verdicts.tsv "$OUT"/renders/*.pl 2>/dev/null
mkdir -p "$OUT/renders"

corpus=$(ls "$SUB"/examples/*.sh "$W"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)

n=0
for f in $corpus; do
  n=$((n+1)); [ "$LIMIT" != 0 ] && [ "$n" -gt "$LIMIT" ] && break
  base=$(basename "$f")
  if ! bash -n "$f" 2>/dev/null; then
    printf '%s\tskip\tbash-n\n' "$base" >> "$OUT/verdicts.tsv"; continue
  fi
  shir=$("$OTRANS" --target shir "$f" 2>/dev/null) || { printf '%s\temitfail\trc=%s\n' "$base" "$?" >> "$OUT/verdicts.tsv"; continue; }
  if [ -z "$shir" ]; then printf '%s\temitfail\tempty\n' "$base" >> "$OUT/verdicts.tsv"; continue; fi
  g_out=$(printf '%s' "$shir" | "$BIN" --target=perl - 2>/dev/null) || { printf '%s\trendfail\t\n' "$base" >> "$OUT/verdicts.tsv"; continue; }
  if [ -z "$g_out" ]; then printf '%s\trendfail\tempty\n' "$base" >> "$OUT/verdicts.tsv"; continue; fi

  s=$(printf '%s' "$g_out" | command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  printf '%s' "$g_out" > "$OUT/renders/$base.pl"
  if [ "$s" -gt 0 ]; then printf '%s\tstub\t%s\n' "$base" "$s" >> "$OUT/verdicts.tsv"; continue; fi

  # anti-cheat
  if printf '%s' "$g_out" | command grep -qE "system\('bash',\s*'[^']*'\)"; then
    printf '%s\tanticheat-bashwrap\t\n' "$base" >> "$OUT/verdicts.tsv"; continue
  fi
  qxout=$(perl "$W/check_qx.pl" "$OUT/renders/$base.pl" 2>/dev/null | command grep -c FAIL || true)
  if [ "${qxout:-0}" -gt 0 ]; then printf '%s\tanticheat-qx\t%s\n' "$base" "$qxout" >> "$OUT/verdicts.tsv"; continue; fi

  scratch=$(mktemp -d "$W/.eq_scratch_repro.XXXXXX")
  eq_exit=1
  (cd "$scratch" && "$KS" timeout 15 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$f" "$OUT/renders/$base.pl") > "$OUT/renders/$base.out" 2>/dev/null && eq_exit=0 || eq_exit=$?
  bash_rc=0
  (cd "$scratch" && "$KS" timeout 15 bash "$f") > "$OUT/renders/$base.ref" 2>/dev/null || bash_rc=$?
  rm -rf "$scratch"

  reason=""
  [ "$eq_exit" = 124 ] && reason="timeout-pl"
  [ "$bash_rc" = 124 ] && reason="timeout-bash"
  if [ -z "$reason" ] && [ "$eq_exit" != "$bash_rc" ]; then reason="rc:$eq_exit/$bash_rc"; fi
  if [ -z "$reason" ] && ! diff -q "$OUT/renders/$base.out" "$OUT/renders/$base.ref" >/dev/null 2>&1; then reason="stdout"; fi
  if [ -z "$reason" ]; then
    printf '%s\tpass\t\n' "$base" >> "$OUT/verdicts.tsv"
  else
    printf '%s\tFAIL\t%s\n' "$base" "$reason" >> "$OUT/verdicts.tsv"
  fi
done

echo "verdicts: $OUT/verdicts.tsv"
command awk -F'\t' '{c[$2]++} END {for (k in c) printf "  %-20s %d\n", k, c[k]}' "$OUT/verdicts.tsv" | sort -k2 -nr
