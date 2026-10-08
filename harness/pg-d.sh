#!/usr/bin/env bash
# pg-d.sh — one perl-generator example, byte diff against bash, in ./fail's
# exact environment (same transpiler invocation, same $0=source convention,
# same kill-session wrapper, same byte caps on both sides).
#
# Usage:  pg-d.sh <example.sh> [-k]     -k keeps the workdir
#         DL=60 pg-d.sh <example.sh>     -more diff context lines
#         FULL=1 pg-d.sh <example.sh>     -also copy the generated perl to scratch/
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EX="$1"; shift || true
case "$EX" in /*) ;; *) EX="$ROOT/sh2perl/examples/$EX" ;; esac
[ -f "$EX" ] || { echo "no such example: $EX"; exit 2; }
keep=0
for a in "$@"; do [ "$a" = "-k" ] && keep=1; done

T=$(mktemp -d /tmp/pgd-XXXXXX)
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

if ! "$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target pl "$EX" > "$T/t.pl" 2>"$T/gen.err"; then
  echo "== GEN FAILED =="; head -20 "$T/gen.err"; echo "keep: $T"; exit 1
fi
[ "${FULL:-0}" = 1 ] && cp "$T/t.pl" "$ROOT/scratch/gen-$(basename "$EX").pl"

"$ROOT/harness/kill-session.sh" timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
  "$EX" "$T/t.pl" > "$T/pl.out" 2>"$T/pl.err"; prc=$?
"$ROOT/harness/kill-session.sh" timeout 20 bash "$EX" > "$T/bash.out" 2>/dev/null; brc=$?

echo "=== $(basename "$EX")  perl_rc=$prc bash_rc=$brc"
[ "$prc" = 124 ] && echo "TIMEOUT (perl)"
[ "$brc" = 124 ] && echo "TIMEOUT (bash)"
if diff -q "$T/bash.out" "$T/pl.out" >/dev/null; then
  echo "STDOUT MATCH"
else
  echo "--- diff bash(-) vs perl(+) ---"
  diff "$T/bash.out" "$T/pl.out" | head -"${DL:-30}"
fi
if [ -s "$T/pl.err" ]; then
  echo "--- perl stderr ---"; head -"${ERRL:-6}" "$T/pl.err"
fi
echo "$T" > "$ROOT/.last-pgd"
[ "$keep" = 1 ] && echo "workdir: $T"
exit 0
