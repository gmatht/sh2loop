#!/bin/sh
# Reproduce ONE corpus example through the generator, exactly as ./fail does:
#   otranspilerl --target pl FILE  ->  perl FILE.pl  vs  bash FILE
# Prints the verdict, the first differing line, and both exit codes.
#   usage: pg-repro-one.sh <example.sh> [diff-lines]
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EX="$1"; NAME=$(basename "$EX"); N=${2:-25}
D=$(mktemp -d "/tmp/pg1.XXXXXX")
trap 'rm -rf "$D"' EXIT

SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so" \
SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so" \
UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall" \
timeout 60 "$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target pl "$EX" >"$D/test.pl" 2>"$D/gen.err"
genrc=$?
if [ $genrc -ne 0 ]; then
  echo "=== $NAME: GENERATE FAILED (rc=$genrc)"; sed -n '1,10p' "$D/gen.err"; exit 2
fi
if grep -qE "system\('bash'," "$D/test.pl"; then
  echo "=== $NAME: PARSER FALLBACK (bash wrapper)"; exit 3
fi

# syntax check first: a Perl compile error is its own class
perl -c "$D/test.pl" 2>"$D/syn.err"
if [ $? -ne 0 ]; then
  echo "=== $NAME: PERL SYNTAX ERROR"; sed -n '1,12p' "$D/syn.err"; exit 4
fi

"$ROOT/harness/kill-session.sh" timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$EX" "$D/test.pl" >"$D/perl.out" 2>"$D/perl.err"
pe=$?
"$ROOT/harness/kill-session.sh" timeout 20 bash "$EX" >"$D/bash.out" 2>"$D/bash.err"
be=$?

if cmp -s "$D/perl.out" "$D/bash.out" && [ "$pe" = "$be" ]; then
  echo "=== $NAME: PASS"; exit 0
fi

echo "=== $NAME: FAIL  exit perl=$pe bash=$be  (bytes perl=$(wc -c <"$D/perl.out") bash=$(wc -c <"$D/bash.out"))"
if [ "$pe" != "$be" ]; then echo "--- reason: EXIT CODE"; fi
if ! cmp -s "$D/perl.out" "$D/bash.out"; then
  echo "--- stdout diff (first $N lines):"
  diff "$D/bash.out" "$D/perl.out" | head -"$N"
fi
[ -s "$D/perl.err" ] && { echo "--- perl stderr:"; sed -n '1,8p' "$D/perl.err"; }
echo "--- generated perl: $D/test.pl (kept)"
exit 1
