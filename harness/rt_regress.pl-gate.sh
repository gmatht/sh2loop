#!/usr/bin/env bash
# rt_regress.pl-gate.sh — per-file regression view of the perl backend gate.
#
# Reproduces, per file, what setup_backends.sh --backend-gate perl does:
#   core A1 emit (otranspilerl-cli --target shir)
#   -> worktree renderer (sh2perl/backends/perl/target/debug/shir_render --target=perl -)
#   -> stub grep (TODO(unsupported)|sh2[A-Za-z_0-9]+\()
#   -> anti-cheat: check_qx.pl, and the system('bash','...') wrapper
#   -> equivalence: run the render under perl, diff stdout vs bash (cap-capture)
#
# Usage: harness/rt_regress.pl-gate.sh [--sub PREFIX] [--out FILE] [FILE...]
#        (no FILE = the whole corpus, same glob list as the gate)
set -u
ROOT=${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
BIN="$ROOT/sh2perl/backends/perl/target/debug/shir_render"
OUT=""
SUB=""
files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --sub) SUB="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    *) files+=("$1"); shift;;
  esac
done
if [ ${#files[@]} -eq 0 ]; then
  while IFS= read -r f; do files+=("$f"); done < <(ls "$ROOT"/sh2perl/examples/*.sh "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)
fi
[ -n "$SUB" ] && files=($(printf '%s\n' "${files[@]}" | command grep "/$SUB" || true))
[ ${#files[@]} -eq 0 ] && { echo "no files"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ok=0; fail=0; skip=0; stubn=0; qxn=0; eqn=0; emitn=0; wn=0
for f in "${files[@]}"; do
  b=$(basename "$f")
  shir=$("$CLI" --target shir "$f" 2>/dev/null) || { emitn=$((emitn+1)); fail=$((fail+1)); echo "EMITFAIL $b"; continue; }
  [ -n "$shir" ] || { emitn=$((emitn+1)); fail=$((fail+1)); echo "EMITEMPTY $b"; continue; }
  if ! bash -n "$f" 2>/dev/null; then skip=$((skip+1)); continue; fi
  if g_out=$(printf '%s' "$shir" | "$BIN" --target=perl - 2>/dev/null); then rok=1; else rok=0; g_out=""; fi
  s=$(printf '%s' "$g_out" | command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  stubn=$((stubn+s))
  if [ "$rok" != 1 ] || [ "$s" -ne 0 ]; then fail=$((fail+1)); echo "STUB/ERR($s) $b"; continue; fi
  if printf '%s' "$g_out" | command grep -qE "system\('bash',\s*'[^']*'\)"; then wn=$((wn+1)); fail=$((fail+1)); echo "BASHWRAP $b"; continue; fi
  printf '%s' "$g_out" > "$tmp/eq.pl"
  q=$(perl "$ROOT/check_qx.pl" "$tmp/eq.pl" 2>/dev/null | command grep -c FAIL || true)
  if [ "${q:-0}" -gt 0 ]; then qxn=$((qxn+1)); fail=$((fail+1)); echo "QX $b"; continue; fi
  if ! perl -c "$tmp/eq.pl" >/dev/null 2>&1; then fail=$((fail+1)); echo "NOCOMPILE $b"; continue; fi
  bash "$f" > "$tmp/ref.out" 2>/dev/null; rrc=$?
  timeout 20 perl "$tmp/eq.pl" > "$tmp/got.out" 2>/dev/null; grc=$?
  if ! command grep -qxFf /dev/null /dev/null 2>/dev/null; then :; fi
  if ! diff -q "$tmp/ref.out" "$tmp/got.out" >/dev/null 2>&1; then eqn=$((eqn+1)); fail=$((fail+1)); echo "EQ $b"; continue; fi
  ok=$((ok+1))
done
echo "=== TOTAL=${#files[@]} ok=$ok fail=$fail skip=$skip | stubcalls=$stubn stubfiles? | qx=$qxn bashwrap=$wn emitfail=$emitn equiv=$eqn"
[ -n "$OUT" ] && echo "written to $OUT"