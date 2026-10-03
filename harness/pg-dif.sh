#!/usr/bin/env bash
# pg-dif.sh — one perl-GENERATOR example, full artifact dump.
#
# Usage: harness/pg-dif.sh <example.sh> [outdir]
#
# Reproduces EXACTLY what ./fail's perl arm does (same CLI invocation, same
# kill-session + timeout wrapper, same argv0 trick), then prints the first
# byte-level divergence between bash stdout and perl stdout plus both sides'
# exit codes. Writes the generated .pl, both stdouts, both stderrs and a
# unified diff into $outdir (default: a pid-suffixed temp dir) so the next
# iteration can read them without regenerating.
#
# Why a pid-suffixed dir: several of these examples leak process-substitution
# children, and a shared fixed scratch path deleted on exit is a
# self-inflicted race between concurrent runs.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
SRC_NAME="${1:?usage: pg-dif.sh <example.sh> [outdir]}"
OUT="${2:-/tmp/pgdif-$$-$(command -v mktemp >/dev/null && mktemp -u -t pghXXXXXX)}"
mkdir -p "$OUT"

SRC="$ROOT/sh2perl/examples/$SRC_NAME"
if [ ! -f "$SRC" ]; then
  echo "MISSING $SRC"; exit 2
fi

# 1. Generate the Perl (same call the gate makes).
"$CLI" --target pl "$SRC" >"$OUT/test.pl" 2>"$OUT/gen.err"
GEN_RC=$?
if [ $GEN_RC -ne 0 ]; then
  echo "== $SRC_NAME  GEN_FAILED rc=$GEN_RC"
  sed -n '1,5p' "$OUT/gen.err"
  echo "OUT=$OUT"; exit 0
fi

# 2. check_qx, exactly as ./fail does — reject before executing.
perl "$ROOT/check_qx.pl" "$OUT/test.pl" >"$OUT/qx.out" 2>/dev/null
QX_RC=$?
if [ $QX_RC -ne 0 ]; then
  echo "== $SRC_NAME  CHECK_QX"
  command grep -m3 -F FAIL "$OUT/qx.out" || sed -n '1,3p' "$OUT/qx.out"
  echo "OUT=$OUT"; exit 0
fi

# 3. Both arms. cwd is the WORKSPACE ROOT, exactly as ./fail runs them —
#    NOT a per-arm scratch dir. Several examples print $PWD or the absolute
#    path of the script, and an isolated cwd makes those lines differ for a
#    reason that has nothing to do with the generator.
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

# Both stdout captures go through the gate's byte cap, identically. Without
# this a runaway lowering (065_yes_head_while produced 236 MB) gets written
# to disk four times by the diff below — the very thing cap-capture.pl
# exists to prevent. Both sides use the SAME cap so equal stays equal.
CAP_CMD=(perl "$ROOT/harness/cap-capture.pl")

"$ROOT/harness/kill-session.sh" timeout 20 bash "$SRC" \
  2>"$OUT/bash.err" | "${CAP_CMD[@]}" bash >"$OUT/bash.out"
BASH_RC=$?

"$ROOT/harness/kill-session.sh" timeout 20 \
  perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
  "$SRC" "$OUT/test.pl" \
  2>"$OUT/perl.err" | "${CAP_CMD[@]}" perl >"$OUT/perl.out"
PERL_RC=$?

echo "== $SRC_NAME  bash_rc=$BASH_RC perl_rc=$PERL_RC"

diff -u "$OUT/bash.out" "$OUT/perl.out" >"$OUT/stdout.diff" 2>&1
SDIFF_RC=$?

if [ $SDIFF_RC -eq 0 ] && [ "$BASH_RC" = "$PERL_RC" ]; then
  echo "== $SRC_NAME  PASS"
  echo "OUT=$OUT"; exit 0
fi

echo "--- stdout diff (bash -> perl) ---"
if [ $SDIFF_RC -eq 0 ]; then
  echo "(stdout identical; mismatch is exit code only)"
else
  # Show just the interesting hunk, bounded.
  sed -n '1,40p' "$OUT/stdout.diff"
fi

if [ -s "$OUT/perl.err" ]; then
  echo "--- perl stderr (first 5) ---"
  sed -n '1,5p' "$OUT/perl.err" | command grep -v 'uu-ffi' || true
fi
if [ -s "$OUT/bash.err" ]; then
  echo "--- bash stderr (first 5) ---"
  sed -n '1,5p' "$OUT/bash.err"
fi

echo "OUT=$OUT"
