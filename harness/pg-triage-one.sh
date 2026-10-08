#!/usr/bin/env bash
# Triage one corpus example for the Perl GENERATOR: generate, run, and show
# the stdout/exit-code diff plus the generated Perl.
#
# Usage: pg-triage-one.sh <example.sh> [--perl] [--gen]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EX=$1; shift || true
SHOW_PERL=0; SHOW_GEN=0
for a in "$@"; do
  case "$a" in
    --perl) SHOW_PERL=1 ;;
    --gen)  SHOW_GEN=1 ;;
  esac
done

# pid-suffixed scratch: an exit trap can only ever remove its own dir.
D=$(mktemp -d "$ROOT/tmp_run/pgt.XXXXXX")
trap 'rm -rf "$D"' EXIT

EX="$ROOT/sh2perl/examples/$EX"
BIN=$ROOT/otranspilerl/target/debug/otranspilerl-cli

"$BIN" --target pl "$EX" > "$D/test.pl" 2>"$D/gen.err"
perl -ne 'exit(/system\(\x27bash\x27,\s*\x27[^\x27]*\x27\)/ ? 0 : 1)' "$D/test.pl" && { echo "PARSER FALLBACK (bash wrapper)"; exit 2; }

bash "$EX" > "$D/bash.out" 2>/dev/null; bex=$?
perl -M5.010 -e '$0=shift @ARGV; do shift @ARGV' "$EX" "$D/test.pl" > "$D/perl.out" 2>"$D/perl.err"; pex=$?

if cmp -s "$D/bash.out" "$D/perl.out" && [ "$bex" = "$pex" ]; then
  echo "PASS $EX"
  exit 0
fi

echo "=== FAIL $EX"
echo "--- exit: bash=$bex perl=$pex"
echo "--- bash stdout ---"; command grep -n '' "$D/bash.out" | head -40
echo "--- perl stdout ---"; command grep -n '' "$D/perl.out" | head -40
echo "--- diff (bash < / perl >) ---"
diff -u "$D/bash.out" "$D/perl.out" | head -50
[ -s "$D/perl.err" ] && { echo "--- perl stderr ---"; head -15 "$D/perl.err"; }
[ "$SHOW_GEN" = 1 ] && { echo "--- generated perl ---"; command grep -n '' "$D/test.pl" | head -200; }
[ "$SHOW_PERL" = 1 ] && cp "$D/test.pl" "$ROOT/tmp_run/keep-$(basename "$EX" .sh).pl"
exit 1
