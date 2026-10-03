#!/usr/bin/env bash
# pg-census.sh — count a rendered-Perl SHAPE across a set of examples, so a
# candidate fix is sized before it is written. Prints one line per example
# that matches, with the match count. Diagnostic only; the gate stays ./fail.
#
#   harness/pg-census.sh <extended-regex> [ex1.sh ...]
#   harness/pg-census.sh @pattern.txt [ex1.sh ...]   (pattern read from a
#       file, so a regex containing `$` survives the caller's own expansion)
set -u
root=/home/llm/sh2loop
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
pat="${1:?extended regex or @file required}"
case "$pat" in
  @*) pat=$(cat "${pat#@}") ;;
esac
shift
[ $# -gt 0 ] || set -- $(ls "$root/sh2perl/examples"/*.sh)
total=0
# The CLI resolves a relative script path against ITS cwd, and ./fail runs
# with the corpus dir as that cwd — so run there too or a bare name finds no
# file and every count is a silent zero.
cd "$root/sh2perl/examples" || exit 1
# A caller that passes a PATH (or a name) already carrying .sh must not get a
# doubled suffix: the old `[ -f "$t" ] || t="$ex.sh"` probe appended .sh to an
# existing file, and `|| continue` then skipped it silently — which is how a
# census reports "TOTAL 0" for a shape that is demonstrably present.
for ex in "$@"; do
  t="$ex"
  if [ ! -f "$t" ]; then t="$ex.sh"; fi
  if [ ! -f "$t" ]; then echo "SKIP (no such example) $ex" >&2; continue; fi
  n=$(timeout 20 "$CLI" --target pl "$t" 2>/dev/null | grep -cE "$pat" || true)
  if [ "$n" != 0 ]; then printf '%-52s %s\n' "$(basename "$t")" "$n"; total=$((total+n)); fi
done
echo "TOTAL matches: $total"
