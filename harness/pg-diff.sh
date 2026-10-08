#!/usr/bin/env bash
# pg-diff.sh — reproduce ONE corpus example through the Perl generator arm of
# ./fail and show the byte-level diff. Diagnostic only; the gate stays ./fail.
#
#   harness/pg-diff.sh <example.sh> [example2.sh ...]
#
# Prints, per example: bash exit/stdout vs perl exit/stdout, then a unified
# diff of the two stdouts. Uses the exact invocation ./fail uses, so what
# shows here is what the gate sees.
#
# The uu-ffi env vars matter: ./fail exports SH2_UU_LIB / SH2_UU_PIPELINE_LIB /
# UU_FFI_MULTICALL so the generator emits __sh_uu_run and the runtime takes the
# in-process coreutils arm. Without them the generator emits a different
# program and the runtime falls back to fork/exec, so the diff here would NOT
# be what the gate sees. Keep these three in sync with ./fail.
set -u
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
cap="perl $root/harness/cap-capture.pl 1048576"

for ex in "$@"; do
  t="$root/sh2perl/examples/$ex"
  [ -f "$t" ] || t="$ex"
  d=$(mktemp -d /tmp/pgdiff.XXXXXX)

  # Write BOTH stdouts to FILES. Command substitution strips trailing
  # newlines, which would make a missing/extra final newline — a real and
  # frequently-hit generator bug here — compare as IDENTICAL. cmp on the
  # files is the only byte-for-byte comparison that can see it.
  "$root/harness/kill-session.sh" timeout 20 bash "$t" 2>"$d/bs.err" | $cap bash >"$d/bash.out"
  bash_rc=$?
  timeout 20 sh -c "\"$CLI\" --target pl \"$t\" 2>/dev/null" >"$d/test.pl"
  gen_rc=$?
  # Parser-fallback detection must use the SAME regex ./fail uses. A looser
  # `grep -E "system\('bash'"` also matches the __sh_uu_run runtime fallback
  # seam in the preamble helper — a legitimate external-command fallback, not a
  # parse failure — and would mislabel ~32 healthy examples as parser gaps.
  # `perl -ne 'exit(1) if /…/'` exits 0 when NOTHING matched, so the shell
  # test is the NEGATION of what just parsed: skip on a 0 exit.
  if ! perl -ne 'exit(1) if /system\(\x27bash\x27,\s*\x27[^\x27]*\x27\)/' "$d/test.pl"; then
    echo "==================== $ex"; echo "PARSER FALLBACK (bash wrapper)"; continue
  fi
  "$root/harness/kill-session.sh" timeout 20 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$t" "$d/test.pl" 2>"$d/ps.err" | $cap perl >"$d/perl.out"
  perl_rc=$?

  bb=$(wc -c <"$d/bash.out"); pb=$(wc -c <"$d/perl.out")
  echo "==================== $ex"
  echo "gen_rc=$gen_rc bash_rc=$bash_rc perl_rc=$perl_rc  bash_bytes=$bb perl_bytes=$pb"
  if cmp -s "$d/bash.out" "$d/perl.out"; then
    echo "stdout: IDENTICAL"
  else
    echo "stdout diff (< bash | > perl), cat -A so trailing space/CR/EOF show:"
    diff <(cat -A "$d/bash.out") <(cat -A "$d/perl.out") | head -40
  fi
  if [ -s "$d/ps.err" ]; then echo "--- perl stderr ---"; head -15 "$d/ps.err"; fi
  if [ -s "$d/bs.err" ]; then echo "--- bash stderr ---"; head -5 "$d/bs.err"; fi
  echo "(artifacts: $d)"
done
