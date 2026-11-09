#!/usr/bin/env bash
# c-gate-run.sh — run the corpus gate cells with a GIVEN c_backend binary.
# Usage: BIN=... OUT=... c-gate-run.sh [jobs]
# Shares the verdict logic with harness/c-gate-repro.sh (which is the
# same run with the default worktree binary).
set -uo pipefail
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
JOBS="${1:-8}"
BIN="${BIN:?set BIN}"
OUT="${OUT:-/tmp/cgate_run}"
OTRANS="${OTRANS:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
export BIN OTRANS
SCRATCH="$OUT/scratch"
mkdir -p "$SCRATCH"

one() {
  local f="$1" tag base
  tag=$(printf '%s' "$f" | md5sum | cut -c1-16)
  base="$SCRATCH/$tag"
  bash -n "$f" 2>/dev/null || { echo "SKIP parse-error"; return; }
  "$BIN" "$f" > "$base.c" 2>/dev/null || { echo "FAIL render-crash"; return; }
  if grep -qE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' "$base.c"; then
    echo "FAIL stub"; return
  fi
  clang --analyze "$base.c" > "$base.sa" 2>&1
  if grep -qE "warning:|error:" "$base.sa"; then echo "FAIL sa"; return; fi
  cc "$base.c" -o "$base.bin" 2>/dev/null || { echo "FAIL compile"; return; }
  local eq_exit=0 bash_rc=0
  timeout 15 bash -c 'exec -a "$0" "$1"' "$f" "$base.bin" > "$base.out" 2>/dev/null || eq_exit=$?
  timeout 15 bash "$f" > "$base.ref" 2>/dev/null || bash_rc=$?
  if [ "$eq_exit" = 124 ] || [ "$bash_rc" = 124 ]; then echo "FAIL timeout"; return; fi
  if [ "$eq_exit" != "$bash_rc" ]; then echo "FAIL rc($eq_exit/$bash_rc)"; return; fi
  if ! diff -q "$base.out" "$base.ref" >/dev/null 2>&1; then echo "FAIL stdout"; return; fi
  echo "PASS"
}
export -f one
export SCRATCH

ls "$ROOT"/sh2perl/examples/*.sh \
   "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null \
 | xargs -P "$JOBS" -I{} bash -c 'r=$(one "$1"); echo "$r	$1"' _ {} \
 > "$OUT/raw.tsv" 2>/dev/null

echo "PASS: $(grep -c '^PASS' "$OUT/raw.tsv") / $(wc -l < "$OUT/raw.tsv")"
echo "--- buckets ---"
cut -f1 "$OUT/raw.tsv" | sed -E 's/\(.*//' | sort | uniq -c | sort -rn
for b in stub sa compile render-crash stdout timeout rc; do
  grep "^FAIL	$b	" "$OUT/raw.tsv" | cut -f3 > "$OUT/$b.list"
done
