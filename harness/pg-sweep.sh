#!/bin/bash
# Batch triage for the Perl GENERATOR worker: reproduce the gate's exact
# invocation for every failing example and print a one-line verdict each,
# so a 60-example failure list can be triaged without 60 gate runs.
#
# Usage:
#   harness/pg-sweep.sh                 # triage the whole corpus
#   harness/pg-sweep.sh <prefix>        # only examples whose basename has <prefix>
#   harness/pg-sweep.sh --list <file>   # one example basename per line
#
# The per-example report goes to tmp_run/pg-triage/<name>/ (.out/.err pairs)
# and the one-line summary to stdout.
set -u
ROOT=/home/llm/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
OUT="$ROOT/tmp_run/pg-triage"
CAP=1048576
mkdir -p "$OUT"

run_one() {
  local name="$1" EX="$ROOT/sh2perl/examples/$1"
  local d="$OUT/$name"
  [ -f "$EX" ] || { printf '%-46s NO-SUCH-FILE\n' "$name"; return; }
  mkdir -p "$d"

  # Same env the gate sets, so the uu-ffi seam is exercised identically.
  export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
  export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
  export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

  timeout 20 "$CLI" --target pl "$EX" > "$d/t.pl" 2> "$d/gen.err"
  local genrc=$?
  if [ $genrc -ne 0 ]; then
    printf '%-46s GEN-FAIL rc=%s\n' "$name" "$genrc"; return
  fi
  # Same check ./fail does: the bash-wrapper FALLBACK is the whole program
  # (an anchored-ish `system('bash', '<file>')` with a single literal arg and
  # nothing else on the line). A `system('bash','-c',$cmd)` inside generated
  # code is the ordinary command-substitution seam, NOT a fallback.
  if grep -qE "^system\('bash',\s*'[^']*'\);" "$d/t.pl"; then
    printf '%-46s PARSER-FALLBACK\n' "$name"; return
  fi

  # check_qx gate, same as ./fail
  if [ -f "$ROOT/check_qx.pl" ]; then
    timeout 20 perl "$ROOT/check_qx.pl" "$d/t.pl" > "$d/qx.out" 2>/dev/null
    if [ $? -ne 0 ]; then
      printf '%-46s CHECK_QX  %s\n' "$name" "$(grep -m1 FAIL "$d/qx.out")"
      return
    fi
  fi

  # Both sides get their own process group + -k so a forking example (096)
  # cannot leak a writer into the next example.
  "$ROOT/harness/kill-session.sh" timeout 20 perl -M5.010 \
      -e '$0 = shift @ARGV; my $f = shift @ARGV; do $f' "$EX" "$d/t.pl" \
      > "$d/pl.out" 2> "$d/pl.err"
  local plrc=$?
  "$ROOT/harness/kill-session.sh" timeout 20 bash "$EX" \
      > "$d/bash.out" 2> "$d/bash.err"
  local bashrc=$?

  local verdict
  if cmp -s "$d/pl.out" "$d/bash.out"; then verdict="MATCH"; else verdict="STDOUT-DIFF"; fi
  if [ "$plrc" != "$bashrc" ]; then verdict="$verdict EXIT($bashrc/$plrc)"; fi
  if [ -s "$d/pl.err" ]; then
    verdict="$verdict PERLERR:$(head -1 "$d/pl.err" | cut -c1-60)"
  fi
  printf '%-46s %-28s bash=%s perl=%s\n' "$name" "$verdict" "$bashrc" "$plrc"
}
export -f run_one
export ROOT CLI OUT CAP

list=()
if [ "${1:-}" = "--list" ]; then
  while read -r l; do [ -n "$l" ] && list+=("$l"); done < "$2"
elif [ -n "${1:-}" ]; then
  for f in "$ROOT/sh2perl/examples/"*"$1"*.sh; do
    [ -f "$f" ] && list+=("$(basename "$f")")
  done
else
  for f in "$ROOT/sh2perl/examples/"*.sh; do list+=("$(basename "$f")"); done
fi

printf '%s\n' "${list[@]}" | xargs -P "${PG_JOBS:-8}" -I{} bash -c 'run_one "$@"' _ {}
