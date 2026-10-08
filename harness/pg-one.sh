#!/bin/bash
# Single-example Perl generator repro, faithful to ./fail's environment
# (UU-FFI libs exported, so the generated code takes the __sh_uu_run arm).
# Usage: harness/pg-one.sh examples/foo.sh [--diff]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
EX="$1"
[ -n "$EX" ] || { echo "usage: $0 <example.sh>"; exit 2; }
# A bare name resolves against the corpus dir the gate uses
# (`fail`: `$ENV{FAIL_CORPUS} // "$sh2perl/examples"`); a path is taken as given.
case "$EX" in
  /*) ;;
  */*) EX="$ROOT/$EX" ;;
  *)   EX="$ROOT/sh2perl/examples/$EX" ;;
esac
[ -f "$EX" ] || { echo "no such example: $EX"; exit 2; }

TMP=$(mktemp -d /tmp/pgone-XXXXXX)
trap 'rm -rf "$TMP"' EXIT

export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

"$CLI" --target pl "$EX" > "$TMP/t.pl" 2>"$TMP/gen.err"
genrc=$?
if [ $genrc -ne 0 ]; then
  echo "== GEN FAILED (rc=$genrc) =="
  head -20 "$TMP/gen.err"
  exit 1
fi

# setsid + -k: `timeout N` signals only its direct child, so an example that
# forks a writer which outlives it (096_head_procsub.sh) leaks that writer on
# every run. Same wrapper ./fail uses.
# KEEP=1 skips the EXIT trap (below), so the retained dir still holds
# pl.err / bash.err when you go looking for why a run produced no output.
if [ "${KEEP:-0}" = 1 ]; then trap - EXIT; fi
setsid timeout -k 2 20 bash "$EX" > "$TMP/bash.out" 2>"$TMP/bash.err"; bashrc=$?
setsid timeout -k 2 20 perl -M5.010 -e '$0 = shift @ARGV; my $f = shift @ARGV; do $f' "$EX" "$TMP/t.pl" > "$TMP/pl.out" 2>"$TMP/pl.err"; plrc=$?

echo "--- bash exit=$bashrc   perl exit=$plrc"
if cmp -s "$TMP/bash.out" "$TMP/pl.out"; then
  echo "STDOUT: MATCH"
else
  echo "STDOUT: MISMATCH"
  if [ "${2:-}" = "--diff" ]; then
    diff -u "$TMP/bash.out" "$TMP/pl.out" | head -60
  else
    echo "bash: $(wc -c < "$TMP/bash.out") bytes | perl: $(wc -c < "$TMP/pl.out") bytes"
  fi
fi
[ -s "$TMP/pl.err" ] && { echo "--- perl stderr:"; head -10 "$TMP/pl.err"; }
# KEEP=1 retains the whole work dir (generated Perl + both stdouts + diff).
# PG_OUT=<dir> additionally copies the generated Perl to a fixed path, so a
# follow-up read of the emitted code does not need the tmp dir name.
if [ "${KEEP:-0}" = 1 ]; then echo "--- kept: $TMP"; fi
if [ -n "${PG_OUT:-}" ]; then
  mkdir -p "$PG_OUT"
  cp "$TMP/t.pl" "$PG_OUT/${name:-$(basename "$EX" .sh)}.pl"
  cp "$TMP/bash.out" "$PG_OUT/${name:-$(basename "$EX" .sh)}.bash.out"
  cp "$TMP/pl.out" "$PG_OUT/${name:-$(basename "$EX" .sh)}.pl.out"
fi
exit 0
