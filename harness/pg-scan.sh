#!/bin/bash
# Fast parallel Perl-generator scanner: same comparison as ./fail (bash stdout
# vs generated-Perl stdout, byte-for-byte, plus exit code) but N-way parallel
# and without the WorkerPool/JSON plumbing, so the generator can be iterated on
# in seconds instead of minutes.
#
# Usage: harness/pg-scan.sh [prefix-filter] [jobs]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
EXDIR="${PG_EXDIR:-$ROOT/sh2perl/examples}"
FILTER="${1:-}"
JOBS="${2:-8}"
# An array, not a string: $CAP is a multi-word command and must NOT be
# word-split by accident nor quoted as one filename.
CAP=(perl "$ROOT/harness/cap-capture.pl" "${PG_STDOUT_CAP:-1048576}")

WORK=$(mktemp -d /tmp/pgscan-XXXXXX)

run_one() {
  local ex="$1" id="$2"
  local d="$WORK/$id"
  local cap=(perl "$CAP_SCRIPT" "$CAP_BYTES")
  mkdir -p "$d"
  # The external-command seam (UU-FFI.md): ./fail sets these for BOTH the
  # transpile and the run, so the generated code takes the in-process
  # coreutils arm at runtime. Setting them for the transpile only (or not at
  # all) makes the scanner disagree with the gate: the .so has no `grep -P`,
  # so with the seam live the generated pipeline returns nothing where the
  # fork/exec fallback returns a match. Exported for the whole worker.
  export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
  export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
  export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"
  "$CLI" --target pl "$ex" > "$d/t.pl" 2>"$d/gen.err"
  local genrc=$?
  if [ $genrc -ne 0 ]; then
    echo "FAIL $(basename "$ex") | gen-failed"
    return
  fi
  perl "$ROOT/check_qx.pl" "$d/t.pl" > "$d/qx.out" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "FAIL $(basename "$ex") | check_qx: $(grep -m1 FAIL "$d/qx.out" | cut -c1-120)"
    return
  fi
  # cwd = the corpus dir, as ./fail runs (it is the transpiler's default
  # working directory); a relative path in the script then resolves the same
  # way on both sides. setsid + -k: the bound must reach the whole process
  # group, or an example that outlives `timeout` leaks its forked writer
  # (096_head_procsub.sh) into the rest of the scan.
  ( cd "$EXDIR" && setsid timeout -k 2 20 bash "$ex" 2>/dev/null ) | "${cap[@]}" bash > "$d/bash.out"; local brc=$?
  ( cd "$EXDIR" && setsid timeout -k 2 20 perl -M5.010 -e '$0 = shift @ARGV; my $f = shift @ARGV; do $f' "$ex" "$d/t.pl" 2>"$d/perl.err" ) | "${cap[@]}" perl > "$d/pl.out"; local prc=$?
  if ! cmp -s "$d/bash.out" "$d/pl.out"; then
    echo "FAIL $(basename "$ex") | stdout ($(wc -c < "$d/bash.out") vs $(wc -c < "$d/pl.out"))"
    return
  fi
  if [ "$brc" != "$prc" ]; then
    echo "FAIL $(basename "$ex") | exit (bash=$brc perl=$prc)"
    return
  fi
  echo "PASS $(basename "$ex")"
  # Remove ONLY this example's dir (it is pid-suffixed, so no sibling can be
  # inside it). The parent's $WORK is never removed here.
  rm -rf "$d"
}
export -f run_one
export CLI ROOT WORK EXDIR
export -n CAP 2>/dev/null || true
# CAP is an array; rebuild it inside each worker.
export CAP_SCRIPT="$ROOT/harness/cap-capture.pl"
export CAP_BYTES="${PG_STDOUT_CAP:-1048576}"

cd "$EXDIR"
ls *.sh 2>/dev/null | sort > "$WORK/names.txt"
: > "$WORK/args.txt"
while read -r f; do
  [ -n "$FILTER" ] && [[ "$f" != *"$FILTER"* ]] && continue
  printf '%s\t%s\n' "$EXDIR/$f" "$$.$f" >> "$WORK/args.txt"
done < "$WORK/names.txt"

# One `bash -c` per example, args as positional parameters (a path can hold
# tabs/spaces; xargs' {} substitution would not be safe).
xargs -P "$JOBS" -a "$WORK/args.txt" -d '\n' -I{} \
  bash -c 'IFS=$(printf "\t"); set -- {}; run_one "$1" "$2"' \
  | sort > "$WORK/res.txt"

n_pass=$(grep -c '^PASS' "$WORK/res.txt" || true)
n_fail=$(grep -c '^FAIL' "$WORK/res.txt" || true)
echo "========================================"
echo "PG-SCAN: $n_pass passed, $n_fail failed out of $((n_pass + n_fail))"
echo "========================================"
if [ "$n_fail" -gt 0 ]; then
  grep '^FAIL' "$WORK/res.txt" | sed 's/^/  FAIL: /'
fi
