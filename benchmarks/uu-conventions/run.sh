#!/usr/bin/env bash
# run.sh — end-to-end uutils calling-convention benchmark.
#
# For each script in this directory:
#   uu leg   : otranspilerl --target c  (default render: external commands
#              lower to in-process _sh_uu_run / _sh_uu_capture)
#   fork leg : SH2_UU_FFI=0 render (the same program with `bash -c` sites)
# both compiled with cc -O2 (the uu leg links runtime/uu_run.c +
# libcoreutils_ffi.so), both gated on stdout == bash before any number is
# printed, each timed as the MEDIAN of RUNS ns-timed runs of N invocations
# (the ratios are the result; the absolute seconds are indicative on a
# shared box).
#
# PATH: the renderer only absorbs a command whose STATIC name is in its
# table (builtin set + SH2_ABSORB_CMDS feed). It does NOT look at PATH, so
# the scripts say `sort` / `wc` and the GNU binaries must be on PATH as
# sort/wc (on a uutils install they already are). Here /tmp/uupath holds
# gnusort/gnuwc links, so both uu legs and fork legs run the same
# implementation (GNU) and the comparison isolates the convention.
#
# Usage: benchmarks/uu-conventions/run.sh [N]
#   Env: CC (cc), RUNS (3), OUT (/tmp/uuconv), UU_PATH (dir to prepend to
#        PATH for the timed runs; default /tmp/uupath, created from gnu*)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CLI="${OTRANSPILERL:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
CC="${CC:-cc}"; RUNS="${RUNS:-3}"; OUT="${OUT:-/tmp/uuconv}"
N="${1:-1000}"
SCRIPTS="sort wc sort-capture"

[ -x "$CLI" ] || { echo "no otranspilerl-cli at $CLI (cargo build --bin otranspilerl-cli)" >&2; exit 1; }
[ -f "$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so" ] || {
  echo "no libcoreutils_ffi.so — build it: sh2perl/runtime/build_uu_ffi.sh" >&2; exit 1; }
UU_PATH="${UU_PATH:-/tmp/uupath}"
mkdir -p "$OUT" "$UU_PATH"
for u in sort wc cat; do
  [ -e "$UU_PATH/$u" ] || ln -s "$(command -v "gnu$u" || command -v "$u")" "$UU_PATH/$u"
done
export PATH="$UU_PATH:$PATH" OTRANSPILER_ROOT="$ROOT"
[ -f "$OUT/in.txt" ] || seq 1 1000 > "$OUT/in.txt"
[ "$OUT" = /tmp/uuconv ] || ln -sfn "$OUT/in.txt" /tmp/uuconv/in.txt

printf 'script,leg,N,sec,us_per_call,stdout_vs_bash\n'
for s in $SCRIPTS; do
  f="$HERE/$s.sh"
  "$CLI" --target c "$f" > "$OUT/$s.c" 2>/dev/null || { echo "$s: render failed" >&2; continue; }
  SH2_UU_FFI=0 "$CLI" --target c "$f" > "$OUT/$s-fork.c" 2>/dev/null
  $CC -O2 -o "$OUT/$s" "$OUT/$s.c" "$ROOT/sh2perl/runtime/uu_run.c" \
     -I "$ROOT/sh2perl/runtime" -L "$ROOT/sh2perl/runtime/lib" \
     -lcoreutils_ffi -lpthread -Wl,-rpath,"$ROOT/sh2perl/runtime/lib" -lm 2>/dev/null \
     || { echo "$s: cc (uu leg) failed" >&2; continue; }
  $CC -O2 -o "$OUT/$s-fork" "$OUT/$s-fork.c" -lm 2>/dev/null \
     || { echo "$s: cc (fork leg) failed" >&2; continue; }
  nuu=$(grep -c '_sh_uu_run\|_sh_uu_capture' "$OUT/$s.c")
  nfk=$(grep -c '_sh_uu_run\|_sh_uu_capture' "$OUT/$s-fork.c")
  [ "$nuu" -gt 0 ] || { echo "$s: WARNING uu leg emitted no _sh_uu_* call" >&2; }
  [ "$nfk" -eq 0 ] || { echo "$s: WARNING fork leg still has _sh_uu_* calls" >&2; }
  ref="$(bash "$f" 3 2>/dev/null | head -3)"
  for leg in uu fork; do
    b="$OUT/$s"; [ "$leg" = fork ] && b="$OUT/$s-fork"
    got="$("$b" 3 2>/dev/null | head -3)"
    [ "$got" = "$ref" ] || { echo "$s,$leg: STDOUT DIFFERS FROM BASH — no number printed" >&2; printf '%s,%s,%s,ERR,,DIFF\n' "$s" "$leg" "$N"; continue; }
    # `date +%s%N` rather than /usr/bin/time: %e has 10 ms resolution, and
    # the wc leg lands in single-digit ms — measured, `wc,uu,1000,0.01`
    # reported itself as either 0.01 s or 10 us per call depending on the
    # rounding. Median of RUNS ns-timed runs; us/call is printed with two
    # decimals and N is part of the row, so the number can be checked.
    ts=(); for i in $(seq "$RUNS"); do
      st=$(date +%s%N); "$b" "$N" >/dev/null 2>&1; en=$(date +%s%N); ts+=($((en-st)))
    done
    med=$(printf '%s\n' "${ts[@]}" | sort -n | awk '{a[NR]=$1} END{print (NR%2?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2)}')
    printf '%s,%s,%s,%.6f,%.2f,same\n' "$s" "$leg" "$N" \
      "$(awk -v t="$med" 'BEGIN{print t/1e9}')" "$(awk -v t="$med" -v n="$N" 'BEGIN{print t/1e3/n}')"
  done
done
