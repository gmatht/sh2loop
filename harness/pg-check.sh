#!/usr/bin/env bash
# Gate-accurate perl-generator loop, but fast and diagnostic.
#
# Why a separate harness: `./fail` is the authority, but its only signal for a
# COMPILE error in the generated Perl is "stdout mismatch" — because the gate
# runs `perl -e 'do FILE'`, and a file that fails to compile makes `do` return
# false immediately with NOTHING on stdout and exit 0. A dozen unrelated
# looking "silent" failures are really one bug: uncompilable output.
#
# This harness runs the same command shapes ./fail uses (same argv0, same
# -M5.010, same uu-ffi env) and additionally runs `perl -c` so a compile error
# is named directly. Byte comparison is cmp, like the gate's `eq`.
#
# Usage:
#   harness/pg-check.sh                 # every example, summary only
#   harness/pg-check.sh a.sh b.sh       # named examples, with diffs
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
EX="$root/sh2perl/examples"

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

want=("$@")
if [ ${#want[@]} -eq 0 ]; then
  mapfile -t want < <(cd "$EX" && ls *.sh)
fi

# one worker body, in a file (export -f does not survive into `bash -c` here)
worker_body() {
cat <<'WEOF'
n=$1
ex_root=$2; CLI=$3
ex="$ex_root/$n"
d=$(mktemp -d "${TMPDIR:-/tmp}/pgcheck.XXXXXX")
trap 'rm -rf "$d"' EXIT

if ! bash -n "$ex" 2>/dev/null; then printf 'SKIP\t%s\tbash-parse\n' "$n"; exit; fi
if ! "$CLI" --target pl "$ex" >"$d/t.pl" 2>"$d/gen.err"; then
  printf 'GENERR\t%s\t%s\n' "$n" "$(head -1 "$d/gen.err")"; exit
fi
if [ ! -s "$d/t.pl" ]; then printf 'GENEMPTY\t%s\t\n' "$n"; exit; fi

cerr=$(perl -c "$d/t.pl" 2>&1 | command grep -v 'uu-ffi' | command grep -v 'syntax OK' \
       | command grep -E 'error|Missing|Unterminated|Bareword|Ambiguous|String found' | head -1)
if [ -n "$cerr" ]; then
  printf 'COMPILE\t%s\t%s\n' "$n" "$(printf '%s' "$cerr" | sed 's|'"$d"'/t.pl|GEN|')"
  exit
fi

mkdir -p "$d/b" "$d/p"
( cd "$d/b" && timeout 30 bash "$ex" ) >"$d/b.out" 2>/dev/null; brc=$?
( cd "$d/p" && timeout 30 perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$ex" "$d/t.pl" ) >"$d/p.out" 2>/dev/null; prc=$?

if cmp -s "$d/b.out" "$d/p.out" && [ "$brc" = "$prc" ]; then
  printf 'PASS\t%s\t\n' "$n"; exit
fi
why=stdout; [ "$brc" = "$prc" ] || why="exit($brc/$prc)"
printf 'DIFF\t%s\t%s\n' "$n" "$why"
if [ -n "${VERBOSE:-}" ]; then
  echo "--- $n ($why) bash=$(wc -c <"$d/b.out")B perl=$(wc -c <"$d/p.out")B"
  diff "$d/b.out" "$d/p.out" 2>&1 | head -"${DIFFLINES:-10}"
  cp "$d/t.pl" "$d/../pgcheck.$n.pl" 2>/dev/null
fi
WEOF
}

W=$(mktemp -d "${TMPDIR:-/tmp}/pgcheckw.XXXXXX")
worker_body > "$W/w.sh"
chmod +x "$W/w.sh"

printf '%s\0' "${want[@]}" | xargs -0 -P "${JOBS:-6}" -I{} "$W/w.sh" {} "$EX" "$CLI" > "$W/res.tsv" 2>&1
if [ -n "${KEEP_RESULTS:-}" ]; then cp "$W/res.tsv" "$KEEP_RESULTS"; fi

echo "--- counts ---"
awk -F'\t' '{c[$1]++} END{for(k in c) printf "%-10s %d\n", k, c[k]}' "$W/res.tsv" | sort -k2 -rn
if [ ${#want[@]} -le 12 ] || [ -n "${VERBOSE:-}" ]; then
  echo "--- non-pass ---"
  awk -F'\t' '$1!="PASS"' "$W/res.tsv" | sort
fi
rm -rf "$W"
