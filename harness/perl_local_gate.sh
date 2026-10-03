#!/usr/bin/env bash
# perl_local_gate.sh — a FAST, SERIAL copy of setup_backends.sh --backend-gate
# perl, for iterating on the renderer. Same verdicts (render-clean + no
# sh2.*/TODO stubs + anti-cheat check_qx + executed equivalence vs bash),
# minus the load gate, the build lock and the log-file writes.
#
# Usage:
#   harness/perl_local_gate.sh                 # whole corpus, summary only
#   harness/perl_local_gate.sh <prefix>        # only corpus files matching prefix
#   harness/perl_local_gate.sh -v <prefix>     # ... and print the diffs
#   harness/perl_local_gate.sh -l              # list failing basenames only
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
SUB="$ROOT/sh2perl"
OTRANS="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
SR="$SUB/backends/perl/target/debug/shir_render"
[ -x "$OTRANS" ] || { echo "missing $OTRANS — build otranspilerl-cli first" >&2; exit 2; }
[ -x "$SR" ] || { echo "missing $SR — cargo build --bin shir_render in backends/perl" >&2; exit 2; }

verbose=0; listonly=0; prefix=""
while [ $# -gt 0 ]; do
  case "$1" in
    -v) verbose=1; shift ;;
    -l) listonly=1; shift ;;
    -h) sed -n '2,12p' "$0"; exit 0 ;;
    *) prefix="$1"; shift ;;
  esac
done

corpus=$(ls "$SUB"/examples/*.sh "$SUB"/frontends/*/testdata/*.sh 2>/dev/null)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ok=0; fail=0; skip=0; stubf=0; eqf=0; cheat=0; emitfail=0; qxf=0
fails=""
for f in $corpus; do
  b=$(basename "$f")
  case "$b" in *"$prefix"*) ;; *) continue ;; esac
  shir=$("$OTRANS" --target shir "$f" 2>/dev/null) || { emitfail=$((emitfail+1)); fail=$((fail+1)); fails="$fails $b(emit)"; continue; }
  [ -n "$shir" ] || { emitfail=$((emitfail+1)); fail=$((fail+1)); fails="$fails $b(empty)"; continue; }
  bash -n "$f" 2>/dev/null || { skip=$((skip+1)); continue; }
  if ! g_out=$(printf '%s' "$shir" | "$SR" --target=perl - 2>/dev/null); then
    fail=$((fail+1)); fails="$fails $b(render)"; continue
  fi
  s=$(printf '%s' "$g_out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  if [ "$s" -ne 0 ]; then stubf=$((stubf+1)); fail=$((fail+1)); fails="$fails $b(stub:$s)"; continue; fi
  if printf '%s' "$g_out" | grep -qE "system\('bash',\s*'[^']*'\)"; then
    cheat=$((cheat+1)); fail=$((fail+1)); fails="$fails $b(wrapper)"; continue
  fi
  printf '%s' "$g_out" > "$tmp/eq.pl"
  qx=$(perl "$ROOT/check_qx.pl" "$tmp/eq.pl" 2>/dev/null | command grep -c FAIL || true)
  if [ "${qx:-0}" -gt 0 ]; then qxf=$((qxf+1)); fail=$((fail+1)); fails="$fails $b(qx)"; continue; fi
  # equivalence: perl render vs bash, stdout only, rc equality
  ( cd "$tmp" && timeout 20 perl "$tmp/eq.pl" >"$tmp/mine.out" 2>/dev/null ); mrc=$?
  ( cd "$tmp" && timeout 20 bash "$f" >"$tmp/ref.out" 2>/dev/null ); rrc=$?
  # cap: drain to EOF, bounded in BYTES (a mis-lowered loop can emit forever)
  head -c 1048576 "$tmp/mine.out" > "$tmp/mine.cap" 2>/dev/null
  head -c 1048576 "$tmp/ref.out"  > "$tmp/ref.cap"  2>/dev/null
  if ! command grep -q . "$tmp/mine.cap" 2>/dev/null; then :; fi
  if cmp -s "$tmp/mine.cap" "$tmp/ref.cap" && [ "$mrc" = "$rrc" ]; then
    ok=$((ok+1))
    if [ "$listonly" = 1 ]; then echo "PASS $b"; fi
  else
    eqf=$((eqf+1)); fail=$((fail+1)); fails="$fails $b"
    if [ "$listonly" = 1 ]; then echo "FAIL $b"
    elif [ "$verbose" = 1 ]; then
      echo "=== FAIL $b (rc mine=$mrc bash=$rrc) src: $f"
      echo "--- src"; sed -n '1,60p' "$f"
      echo "--- render"; sed -n '1,60p' "$tmp/eq.pl"
      echo "--- diff (bash vs perl)"; diff "$tmp/ref.cap" "$tmp/mine.cap" | head -40
    fi
  fi
done
echo "---- perl local gate: OK=$ok FAIL=$fail (render=$((fail-stubf-eqf-qxf-cheat)) stub=$stubf qx=$qxf wrapper=$cheat equiv=$eqf) skip=$skip emitfail=$emitfail ----"
[ "$listonly" = 0 ] && echo "failing: $fails"