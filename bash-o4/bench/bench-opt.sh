#!/usr/bin/env bash
# bench-opt.sh — optimised-only benchmarks at ~1s scale (NO bash leg).
#
# bash is too slow to run at the sizes where steady-state throughput is
# measurable (and ms-scale rows are startup noise), so this suite compares
# only optimised implementations at N calibrated so the SLOWER leg takes
# about a second:
#   gcc-O3  — handwritten C + gcc -O3 (the CPU ceiling)
#   bo4-gcc — bash-O4 --emit-c recompiled with gcc -O3 (backend quality;
#             all three problems run: counter-dynamic fills route to
#             growable vecs since the array-cap fix). TRANSPILED (like
#             cuda-tx below) — compare against gcc-O3 to read backend
#             quality directly.
#   gpu     — gpuleg dispatch (FUSED squares-map map+reduce and M5-preview
#             block templates for reductions) + host finish
#   cuda    — cudabench dispatch (handwritten PTX block templates via
#             cudaffi) + host finish; the hardware ceiling for cuda-tx.
#             SKIPPED with a note when no CUDA device is present
#   cuda-tx — cutranspile dispatch (TRANSPILED bash->candidacy->PTX, no
#             hand kernels) + host finish; SKIPPED when candidacy vetoes
#             (map-only v1: scalar-carry reductions) or no device
#
# Agreement gate: every RUNNING leg's checksum must byte-agree (exit codes
# too). Speedups are vs gcc-O3 (no bash baseline here by design).
#
# Usage: bench/bench-opt.sh [--runs N] [--save FILE] [--problem NAME]...
#   RUNS env overrides --runs (default 3); TIMEOUT caps each run (900).
set -uo pipefail

BENCH="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BENCH/../.." && pwd)"
BO4="$ROOT/bash-o4/target/debug/bash-O4"
GPULEG="$ROOT/bash-o4/target/debug/examples/gpuleg"
CUDABENCH="$ROOT/bash-o4/target/debug/examples/cudabench"
CUTRANSPILE="$ROOT/bash-o4/target/debug/examples/cutranspile"
export BASH_O4_SH2PERL="$ROOT/sh2perl"
RUNTIME="$ROOT/sh2perl/runtime"
RUNS="${RUNS:-3}"
TIMEOUT="${TIMEOUT:-900}"
SAVE=""
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2;;
    --save) SAVE="$2"; shift 2;;
    --problem) ONLY="$ONLY $2"; shift 2;;
    -h|--help) sed -n '2,22p' "$0"; exit 0;;
    *) echo "unknown flag $1" >&2; exit 2;;
  esac
done

if [ ! -x "$BO4" ]; then
  (cd "$ROOT/bash-o4" && cargo build --bin bash-O4) >&2 || exit 1
fi
if [ ! -x "$GPULEG" ]; then
  (cd "$ROOT/bash-o4" && cargo build --example gpuleg) >&2 || exit 1
fi
if [ ! -x "$CUDABENCH" ]; then
  (cd "$ROOT/bash-o4" && cargo build --example cudabench) >&2 || exit 1
fi
if [ ! -x "$CUTRANSPILE" ]; then
  (cd "$ROOT/bash-o4" && cargo build --example cutranspile) >&2 || exit 1
fi
command -v gcc >/dev/null || { echo "need gcc" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# problems: name | N | sh or "-" | handwritten C | gpuleg problem or "-"
PROBLEMS="sumred squares-map twoarr collatz"
# N calibrated so the SLOWER leg lands ~1s (order-of-one-second scale,
# not ms noise): sumred-1B (gpu ~0.6s), squares-map-100M (gpu ~1.3s),
# collatz-18M (gcc ~0.9s).
prob_n()   { case "$1" in sumred) echo 1000000000;; squares-map) echo 100000000;; twoarr) echo 50000000;; collatz) echo 18000000;; esac; }
prob_sh()  { case "$1" in sumred) echo sumred.sh;; collatz) echo collatz.sh;; squares-map) echo squares-map.sh;; twoarr) echo twoarr.sh;; *) echo "-";; esac; }
prob_c()   { case "$1" in sumred) echo sumred.c;; squares-map) echo squaresmap.c;; twoarr) echo twoarr.c;; collatz) echo collatz.c;; esac; }
prob_gpu() { case "$1" in sumred) echo sumred;; squares-map) echo squares-map;; collatz) echo collatz;; *) echo "-";; esac; }
prob_bo4() { # "" = runnable, else skip reason
  case "$1" in
    sumred) echo "";;
    squares-map) echo "";; # counter-dynamic fills route to growable vecs
    twoarr) echo "";; # multi-store fill: fused by fuse-fill-consume
    collatz) echo "";;
  esac
}
if [ -n "$ONLY" ]; then PROBLEMS="$ONLY"; fi

median() { sort -n | awk '{a[NR]=$1} END {print (NR%2 ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2)}'; }

t_ns() { # median wall-nanoseconds over $1 runs of the rest
  local runs=$1; shift
  timeout "$TIMEOUT" "$@" >/dev/null 2>&1 || return 1
  local ts=()
  for _ in $(seq "$runs"); do
    local s e
    s=$(date +%s%N)
    timeout "$TIMEOUT" "$@" >/dev/null 2>&1 || return 1
    e=$(date +%s%N)
    ts+=($((e - s)))
  done
  printf '%s\n' "${ts[@]}" | median
}

inc_flags() { local f="$1" extra=""; if grep -q "uu_run.h" "$f"; then extra="-I$RUNTIME -I$RUNTIME/lib"; fi; echo "$extra"; }
link_flags() {
  local f="$1" extra="-lm"
  if grep -q "uu_run.h" "$f"; then
    extra="$extra $RUNTIME/uu_run.c $RUNTIME/lib/libcoreutils_ffi.so -lpthread -Wl,-rpath,$RUNTIME/lib -I$RUNTIME -I$RUNTIME/lib"
  fi
  if grep -q "gmp.h" "$f"; then extra="$extra -lgmp"; fi
  echo "$extra"
}

vec_report() {
  local log
  log=$(gcc -O3 $(inc_flags "$1") -fopt-info-vec-optimized -c "$1" -o /dev/null 2>&1) || { echo "ERR"; return 0; }
  echo "$log" | grep -c "optimized: loop vectorized" || true
}

fail() { echo "BENCH-OPT FAIL: $*" >&2; exit 1; }

if [ -n "$SAVE" ]; then printf 'problem\tN\tleg\ts\tns_item\tspeedup_vs_gcc\tvec_loops\n' > "$SAVE"; fi
printf '%-12s %11s %-8s %12s %12s %10s %4s\n' problem N leg s ns/item speedup vec

for p in $PROBLEMS; do
  n="$(prob_n "$p")"; cref="$BENCH/c/$(prob_c "$p")"; gprob="$(prob_gpu "$p")"
  [ -f "$cref" ] || fail "missing $cref"

  # ---- build gcc + bo4 legs ----
  gcc -O3 "$cref" -o "$TMP/$p-hand" 2>"$TMP/$p-hand.err" || { head -n 5 "$TMP/$p-hand.err" >&2; fail "gcc $p"; }
  bo4skip="$(prob_bo4 "$p")"
  if [ -z "$bo4skip" ]; then
    sh="$BENCH/sh/$(prob_sh "$p")"
    "$BO4" --emit-c "$sh" > "$TMP/$p-gen.c" 2>"$TMP/$p-gen.err" || fail "emit-c $p"
    # shellcheck disable=SC2086
    gcc -O3 "$TMP/$p-gen.c" $(link_flags "$TMP/$p-gen.c") -o "$TMP/$p-gcc" 2>"$TMP/$p-gcc.err" || { head -n 5 "$TMP/$p-gcc.err" >&2; fail "gcc generated $p"; }
  fi

  # ---- agreement gate (checksums + exit codes across RUNNING legs) ----
  run() { local label=$1; shift; timeout "$TIMEOUT" "$@" > "$TMP/$label.out" 2>/dev/null; echo $?; }
  r_hand=$(run ref-hand "$TMP/$p-hand" "$n")
  [ -z "$bo4skip" ] && r_bgcc=$(run ref-gcc "$TMP/$p-gcc" "$n")
  # "-" = no handwritten GPU kernel for this shape: the gpu and cuda legs
  # SKIP (they are checksum-anchored hand kernels by design), while
  # cuda-tx — the TRANSPILED leg — still runs and still gates.
  gskip=""
  if [ "$gprob" = "-" ]; then
    gskip="no handwritten GPU kernel"
    echo "  $p: gpu/cuda skipped ($gskip)" >&2
  fi
  if [ -z "$gskip" ]; then
    gpu_line=$(timeout "$TIMEOUT" "$GPULEG" "$gprob" "$n" --runs 1 2>"$TMP/$p-gpu.err") || { cat "$TMP/$p-gpu.err" >&2; fail "gpu $p"; }
    gpu_ms=$(echo "$gpu_line" | awk '{print $1}'); gpu_sum=$(echo "$gpu_line" | awk '{print $2}')
    echo "$gpu_sum" > "$TMP/ref-gpu.out"; r_gpu=0
  fi
  # ---- cuda leg (SKIP when no CUDA device: exit 2 + SKIP message) ----
  cuda_skip="$gskip"
  cuda_rc=0
  if [ -z "$gskip" ]; then
  cuda_line=$(timeout "$TIMEOUT" "$CUDABENCH" "$gprob" "$n" --runs 1 2>"$TMP/$p-cuda.err")
  cuda_rc=$?
  fi
  if [ "$cuda_rc" -eq 2 ]; then
    cuda_skip="$(cat "$TMP/$p-cuda.err" 2>/dev/null | head -n 1)"
    echo "  $p: cuda skipped ($cuda_skip)" >&2
  elif [ "$cuda_rc" -ne 0 ]; then
    cat "$TMP/$p-cuda.err" >&2; fail "cuda $p"
  fi
  hand_sum=$(cat "$TMP/ref-hand.out")
  if [ -z "$cuda_skip" ] && [ "$cuda_rc" -eq 0 ]; then
    cuda_sum=$(echo "$cuda_line" | awk '{print $2}')
    [ "$cuda_sum" = "$hand_sum" ] || fail "$p: cuda checksum $cuda_sum != gcc $hand_sum"
  fi
  if [ -z "$gskip" ]; then
    [ "$gpu_sum" = "$hand_sum" ] || fail "$p: gpu checksum $gpu_sum != gcc $hand_sum"
  fi
  if [ -z "$bo4skip" ]; then
    bgcc_sum=$(cat "$TMP/ref-gcc.out")
    [ "$bgcc_sum" = "$hand_sum" ] || fail "$p: bo4-gcc checksum $bgcc_sum != gcc $hand_sum"
    [ "$r_hand" = "$r_bgcc" ] || fail "$p: exit codes differ (gcc=$r_hand bo4=$r_bgcc)"
  fi
  [ "$r_hand" = 0 ] || fail "$p: gcc leg rc=$r_hand"
  echo "  $p: checksums agree" >&2

  # ---- time (warmup + median; gpu timed inside gpuleg) ----
  "$TMP/$p-hand" "$n" >/dev/null 2>&1
  [ -z "$bo4skip" ] && "$TMP/$p-gcc" "$n" >/dev/null 2>&1
  ns_hand=$(t_ns "$RUNS" "$TMP/$p-hand" "$n") || fail "timing hand $p"
  if [ -z "$bo4skip" ]; then ns_bgcc=$(t_ns "$RUNS" "$TMP/$p-gcc" "$n") || fail "timing bo4 $p"; fi
  if [ -z "$gskip" ]; then
    gpu_line=$(timeout "$TIMEOUT" "$GPULEG" "$gprob" "$n" --runs "$RUNS" 2>/dev/null) || fail "timing gpu $p"
    ns_gpu=$(awk -v m="$(echo "$gpu_line" | awk '{print $1}')" 'BEGIN {printf "%d", m*1e6}')
  fi
  if [ -z "$cuda_skip" ]; then
    cuda_line=$(timeout "$TIMEOUT" "$CUDABENCH" "$gprob" "$n" --runs "$RUNS" 2>/dev/null) || fail "timing cuda $p"
    ns_cuda=$(awk -v m="$(echo "$cuda_line" | awk '{print $1}')" 'BEGIN {printf "%d", m*1e6}')
  fi
  # ---- cuda-tx leg (TRANSPILED: bash -> candidacy -> PTX -> device) ----
  # Only problems with a .sh source attempt it; candidacy vetoes and
  # missing devices SKIP (exit 2) instead of failing.
  cutx_skip=""
  cutx_sh="$(prob_sh "$p")"
  if [ "$cutx_sh" != "-" ]; then
    cutx_line=$(timeout "$TIMEOUT" "$CUTRANSPILE" "$BENCH/sh/$cutx_sh" "$n" --runs 1 2>"$TMP/$p-cutx.err")
    cutx_rc=$?
    if [ "$cutx_rc" -eq 2 ]; then
      cutx_skip="$(cat "$TMP/$p-cutx.err" 2>/dev/null | head -n 1)"
      echo "  $p: cuda-tx skipped ($cutx_skip)" >&2
    elif [ "$cutx_rc" -ne 0 ]; then
      cat "$TMP/$p-cutx.err" >&2; fail "cuda-tx $p"
    else
      cutx_sum=$(echo "$cutx_line" | awk '{print $2}')
      [ "$cutx_sum" = "$hand_sum" ] || fail "$p: cuda-tx checksum $cutx_sum != gcc $hand_sum"
    fi
  else
    cutx_skip="no .sh source"
  fi

  v_hand=$(vec_report "$cref")
  if [ -z "$bo4skip" ]; then v_gen=$(vec_report "$TMP/$p-gen.c"); else v_gen="-"; fi

  row() { # leg ns vec -> table line (+tsv)
    local leg=$1 ns=$2 vec=$3 s ni sp
    s=$(awk -v x="$ns" 'BEGIN {printf "%.3f", x/1e9}')
    ni=$(awk -v x="$ns" -v n="$n" 'BEGIN {printf "%.2f", x/n}')
    sp=$(awk -v h="$ns_hand" -v m="$ns" 'BEGIN {printf "%.1f", (m>500000 ? h/m : 0)}')
    printf '%-12s %11s %-8s %12s %12s %10s %4s\n' "$p" "$n" "$leg" "$s" "$ni" "$sp" "$vec"
    if [ -n "$SAVE" ]; then printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$p" "$n" "$leg" "$s" "$ni" "$sp" "$vec" >> "$SAVE"; fi
  }
  row gcc-O3 "$ns_hand" "$v_hand"
  if [ -z "$bo4skip" ]; then row bo4-gcc "$ns_bgcc" "$v_gen"; else printf '%-12s %11s %-8s %12s %12s %10s %4s %s\n' "$p" "$n" "bo4-gcc" "SKIP" "-" "-" "-" "($bo4skip)" >&2; echo "  $p: bo4-gcc skipped ($bo4skip)" >&2; fi
  if [ -z "$gskip" ]; then row gpu "$ns_gpu" "-"; else printf '%-12s %11s %-8s %12s %12s %10s %4s %s\n' "$p" "$n" "gpu" "SKIP" "-" "-" "-" "($gskip)" >&2; fi
  if [ -z "$cuda_skip" ]; then row cuda "$ns_cuda" "-"; else echo "  $p: cuda skipped ($cuda_skip)" >&2; fi
  if [ -z "$cutx_skip" ]; then
    cutx_line=$(timeout "$TIMEOUT" "$CUTRANSPILE" "$BENCH/sh/$cutx_sh" "$n" --runs "$RUNS" 2>/dev/null) || fail "timing cuda-tx $p"
    ns_cutx=$(awk -v m="$(echo "$cutx_line" | awk '{print $1}')" 'BEGIN {printf "%d", m*1e6}')
    row cuda-tx "$ns_cutx" "-"
  else
    echo "  $p: cuda-tx skipped ($cutx_skip)" >&2
  fi
done
