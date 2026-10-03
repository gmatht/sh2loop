#!/usr/bin/env bash
# Reproduce ONE Perl-generator corpus case through the EXACT pipeline ./fail
# uses, and keep every artefact on disk so the generated Perl can be read.
#
#   harness/pg-one-case.sh <example.sh|full/path.sh>
#
# Mirrors ./fail:
#   1. otranspilerl-cli --target pl <src>          (stdout IS the Perl)
#   2. check_qx.pl on the emitted Perl (a violation = FAIL)
#   3. perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' <src> <gen.pl>
#      with cwd = a scratch dir and the gen.pl path RELATIVE (./gen.pl),
#      because Perl 5.26+ removed '.' from @INC and `do "gen.pl"` dies.
#   4. bash <src>
#   5. compare stdout byte-for-byte + exit code.
#
# Prints "dir=<path>" last so a case can be re-examined without a re-run.
set -u
ROOT=/home/llm/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"

arg=$1
case "$arg" in
  /*) src="$arg" ;;
  *)  src="$ROOT/sh2perl/examples/$arg" ;;
esac
[ -f "$src" ] || { echo "no such example: $src" >&2; exit 2; }

D=$(mktemp -d /tmp/pgone.XXXXXX)

export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

timeout 20 "$CLI" --target pl "$src" > "$D/gen.pl" 2> "$D/gen.err" \
  || { echo "GEN-FAIL: $(head -3 "$D/gen.err")"; echo "dir=$D"; exit 1; }

if perl -ne 'exit(/system\(\x27bash\x27,\s*\x27[^\x27]*\x27\)/ ? 0 : 1)' "$D/gen.pl"; then
  echo "PARSER-FALLBACK (bash wrapper)"; echo "dir=$D"; exit 1
fi

perl "$ROOT/check_qx.pl" "$D/gen.pl" > "$D/qx.out" 2>&1; qx=$?
[ "$qx" != 0 ] && { echo "CHECK_QX VIOLATION:"; command grep FAIL "$D/qx.out" | head -5; echo "dir=$D"; exit 1; }

# cwd = the scratch dir (the corpus examples create temp files, and so must we
# not collide with a concurrent gate), and ./gen.pl so `do` resolves.
( cd "$D" && timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $__f=shift @ARGV; do $__f' "$src" ./gen.pl > perl.out 2>perl.err </dev/null ); pex=$?
( cd "$D" && timeout -k 2 20 bash "$src" > bash.out 2>bash.err </dev/null ); bex=$?

# Both arms must go through kill-session.sh, exactly as ./fail runs them: a
# corpus example that leaves an orphaned process-substitution child alive will
# otherwise wedge THIS shell (tty-cmdsub.sh held the helper for 30s) while the
# gate itself completes. Same wrapper, same blast radius.
if [ "${PG_KILLSESSION:-1}" = 1 ]; then
  ( cd "$D" && timeout -k 2 20 "$ROOT/harness/kill-session.sh" perl -M5.010 -e '$0=shift @ARGV; my $__f=shift @ARGV; do $__f' "$src" ./gen.pl > perl.out 2>perl.err </dev/null ); pex=$?
  ( cd "$D" && timeout -k 2 20 "$ROOT/harness/kill-session.sh" bash "$src" > bash.out 2>bash.err </dev/null ); bex=$?
fi

name=$(basename "$src")
if cmp -s "$D/bash.out" "$D/perl.out" && [ "$pex" = "$bex" ]; then
  echo "=== $name PASS  dir=$D"
  exit 0
fi
echo "=== $name FAIL  bash=$bex perl=$pex"
if ! cmp -s "$D/bash.out" "$D/perl.out"; then
  echo "--- stdout diff (bash < | perl >) ---"
  diff "$D/bash.out" "$D/perl.out" | head -"${DIFFLINES:-30}"
fi
[ -s "$D/perl.err" ] && { echo "--- perl stderr ---"; head -6 "$D/perl.err"; }
echo "dir=$D"
exit 1
