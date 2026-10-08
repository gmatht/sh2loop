#!/usr/bin/env bash
# Reproduce the ./fail [perl] gate for one example, byte-for-byte, and leave
# every artefact in a per-example directory for diffing.
#
# The invocation here is copied from ./fail itself (transpile -> check_qx ->
# perl -M5.010 do FILE -> vs bash), so a triage verdict means what the gate
# means. Both sides go through harness/cap-capture.pl exactly as the gate does.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
EX="$1"
NAME="$(basename "$EX" .sh)"
D="$ROOT/tmp_run/pg-triage/$NAME"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
CAP="perl $ROOT/harness/cap-capture.pl 1048576"

rm -rf "$D"; mkdir -p "$D"

# 1. transpile. The gate exports these three UU-FFI seam vars for the
#    transpiler too, and they change the emitted Perl (the FFI preamble, which
#    contains a BEGIN block). Omitting them makes a triage run disagree with
#    the gate on exactly the panics this harness exists to reproduce.
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"
timeout 20 "$CLI" --target pl "$EX" >"$D/gen.pl" 2>"$D/gen.err"
gen_rc=$?

# 2. the gate rejects the bash-wrapper fallback: that is a parser gap, not a
#    generator defect, and must be reported as such.
if grep -qE "system\('bash',\s*'[^']*'\)" "$D/gen.pl"; then
  echo "$NAME: PARSER-FALLBACK"
  exit 3
fi
if [ $gen_rc -ne 0 ]; then
  echo "$NAME: GEN-FAILED rc=$gen_rc"
  exit 4
fi

# 3. check_qx
if [ -f "$ROOT/check_qx.pl" ]; then
  perl "$ROOT/check_qx.pl" "$D/gen.pl" >"$D/qx.out" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "$NAME: CHECK-QX $(grep -m1 FAIL "$D/qx.out" 2>/dev/null)"
    exit 5
  fi
fi

# 4. run the Perl (argv0 = source path, exactly as the gate does it)
timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' \
  "$EX" "$D/gen.pl" >"$D/perl.out" 2>"$D/perl.err" </dev/null
perl_rc=$?
head -c 1048576 "$D/perl.out" >"$D/perl.cap"; mv "$D/perl.cap" "$D/perl.out"

# 5. run bash, in its own process group so a forking example cannot leak
setsid timeout -k 2 20 bash "$EX" >"$D/bash.out" 2>"$D/bash.err" </dev/null
bash_rc=$?
head -c 1048576 "$D/bash.out" >"$D/bash.cap"; mv "$D/bash.cap" "$D/bash.out"

# 6. verdict
same_out=1; cmp -s "$D/perl.out" "$D/bash.out" || same_out=0
if [ $same_out -eq 1 ] && [ "$perl_rc" -eq "$bash_rc" ]; then
  echo "$NAME: PASS"
  exit 0
fi
# BOTH reasons matter: stdout and exit code are separate checks and a case can
# fail either or both. An earlier version of this line string-compared
# ("$same_out -eq 1"), so a STDOUT-only failure was reported as EXIT and the
# whole red list came back mislabelled.
why=""
[ "$same_out" -eq 0 ] && why="STDOUT"
[ "$perl_rc" -ne "$bash_rc" ] && why="$why+EXIT"
echo "$NAME: FAIL(${why:-STDOUT}) perl_rc=$perl_rc bash_rc=$bash_rc"
exit 1
