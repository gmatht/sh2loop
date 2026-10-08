#!/usr/bin/env bash
# c-gate-repro.sh — faithful, PARALLEL reproduction of the c backend gate cell
# (setup_backends.sh lines 1069-1343) for fast failure-driven iteration.
#
# Mirrors the gate exactly:
#   - shIR from the core A1 emitter (`otranspilerl-cli --target shir`)
#   - render via the c_backend BIN (g_binmode=1, the c pattern)
#   - stub gate: TODO(unsupported)|sh2[A-Za-z_0-9]+\(
#   - clang --analyze must be clean (warning:|error: -> sa_fail=1)
#   - compile with cc, run with argv0 = source path
#   - verdict: exit codes EQUAL (c is in the equality group) && stdout diff -q
#
# Usage: c-gate-repro.sh [jobs] [--save]
# Writes /tmp/cgate/{pass,fail,stub,sa,render,compile} lists.
set -uo pipefail

JOBS="${1:-8}"
SAVE="${2:-}"
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SUB="$ROOT/sh2perl"
BT="$SUB/backends"
WT="$BT/c"
BIN="$WT/target/debug/c_backend"
OTRANS="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
OUT=/tmp/cgate
SCRATCH="$OUT/scratch"
mkdir -p "$SCRATCH"
rm -f "$OUT"/{pass,fail,stub,sa,render,compile}

corpus=$(ls "$SUB"/examples/*.sh "$SUB"/frontends/*/testdata/*.sh 2>/dev/null)

# one cell; echoes "<verdict> <reason>" and writes artifacts under $SCRATCH
one() {
  local f="$1" tag
  tag=$(printf '%s' "$f" | md5sum | cut -c1-16)
  local base="$SCRATCH/$tag"

  bash -n "$f" 2>/dev/null || { echo "SKIP parse-error"; return; }
  local shir
  shir=$("$OTRANS" --target shir "$f" 2>/dev/null) || { echo "SKIP shir-emit-fail"; return; }
  [ -n "$shir" ] || { echo "SKIP empty-shir"; return; }

  # render via the c_backend bin (gate's g_binmode path)
  local out
  out=$("$BIN" "$f" 2>/dev/null) || { echo "FAIL render-crash"; return; }

  # stub gate (canonical pattern from setup_backends.sh:1127)
  local s
  s=$(printf '%s' "$out" | grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  printf '%s' "$out" > "$base.c"
  if [ "$s" -ne 0 ]; then echo "FAIL stub"; return; fi

  # static analysis gate (clang --analyze; rc 0 even when it warns -> grep)
  if clang --analyze "$base.c" 2>&1 | grep -qE "warning:|error:"; then
    clang --analyze "$base.c" > "$base.sa" 2>&1
    echo "FAIL sa"
    return
  fi

  # compile
  cc "$base.c" -o "$base.bin" 2>"$base.cc" || { echo "FAIL compile"; return; }

  # run both sides; argv0 = source path (matches `bash "$f"`)
  local eq_exit=0 bash_rc=0
  timeout 15 bash -c 'exec -a "$0" "$1"' "$f" "$base.bin" > "$base.out" 2>/dev/null || eq_exit=$?
  timeout 15 bash "$f" > "$base.ref" 2>/dev/null || bash_rc=$?
  if [ "$eq_exit" = 124 ] || [ "$bash_rc" = 124 ]; then echo "FAIL timeout"; return; fi
  if [ "$eq_exit" != "$bash_rc" ]; then echo "FAIL rc($eq_exit vs $bash_rc)"; return; fi
  if ! diff -q "$base.out" "$base.ref" >/dev/null 2>&1; then echo "FAIL stdout"; return; fi
  echo "PASS"
}

export -f one
export OTRANS BIN SCRATCH

printf '%s\n' $corpus | xargs -P "$JOBS" -I{} bash -c 'r=$(one "$1"); echo "$r	$1"' _ {} \
  > "$OUT/raw.tsv" 2>/dev/null

# tally
awk -F'\t' '{split($1,a," "); v=a[1]; r=a[2]; print v"\t"r"\t"$2}' "$OUT/raw.tsv" > "$OUT/tally.tsv"
grep -c '^PASS' "$OUT/tally.tsv" > "$OUT/pass.n" || echo 0 > "$OUT/pass.n"
echo "PASS: $(cat "$OUT/pass.n")  TOTAL: $(wc -l < "$OUT/tally.tsv")"
echo "--- fail buckets ---"
awk -F'\t' '$1=="FAIL"{print $2}' "$OUT/tally.tsv" | sed 's/([0-9].*//' | sort | uniq -c | sort -rn
echo "--- skip buckets ---"
awk -F'\t' '$1=="SKIP"{print $2}' "$OUT/tally.tsv" | sort | uniq -c | sort -rn

# per-bucket file lists
for b in stub sa compile render-crash stdout timeout rc; do
  awk -F'\t' -v B="$b" '$1=="FAIL" && $2 ~ "^"B {print $3}' "$OUT/tally.tsv" > "$OUT/$b.list"
  echo "$b: $(wc -l < "$OUT/$b.list")"
done
[ "$SAVE" = "--save" ] && cp "$OUT/tally.tsv" "$OUT/tally.saved.tsv"
