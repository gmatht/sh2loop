#!/usr/bin/env bash
# bench.sh — bash-O4 vs pure C (gcc -O3), particularly vectorisable code.
#
# Four legs per problem (same N, same expected stdout — byte agreement is
# the gate; any mismatch fails loudly with no numbers):
#   bash    — real bash (the floor reference)
#   bo4-tcc — bash-O4 -o (the default driver path: generated C via tcc)
#   bo4-gcc — bash-O4 --emit-c recompiled with gcc -O3 (isolates BACKEND
#             quality from compiler quality)
#   gcc-O3  — handwritten C reference + gcc -O3 (the ceiling)
#
# Conventions (borrowed from bench_sqrt.sh + sh2runtime/bench/gcc-vs-igpu):
# fixed N per problem (no wall-time calibration — speedups stay honest),
# median of RUNS (nanosecond timer), ns/item + speedup-vs-bash table,
# vectoriser report per gcc-compiled binary.
#
# Usage: bench/bench.sh [--runs N] [--save FILE] [--problem NAME]...
#   RUNS env overrides --runs. TIMEOUT env caps each single run (default
#   600s; hangs fail loudly). sqrt1337's bash leg runs once (10k forks;
#   bench_sqrt.sh precedent); collatz runs once everywhere (fork-per-
#   iteration pathology in current lowering — see README).
set -uo pipefail

BENCH="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BENCH/../.." && pwd)"
BO4="$ROOT/bash-o4/target/debug/bash-O4"
export BASH_O4_SH2PERL="$ROOT/sh2perl"
RUNTIME="$ROOT/sh2perl/runtime"
RUNS="${RUNS:-5}"
TIMEOUT="${TIMEOUT:-600}"  # seconds per single run (fail loudly on hang)
SAVE=""
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2;;
    --save) SAVE="$2"; shift 2;;
    --problem) ONLY="$ONLY $2"; shift 2;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) echo "unknown flag $1" >&2; exit 2;;
  esac
done

if [ ! -x "$BO4" ]; then
  echo "building bash-O4..." >&2
  (cd "$ROOT/bash-o4" && cargo build --bin bash-O4) >&2 || exit 1
fi
command -v gcc >/dev/null || { echo "need gcc" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# problems: name | sh | N (empty = no arg) | handwritten C
PROBLEMS="addsum addsum32 squares hash collatz sqrt1337"
prob_sh()   { case "$1" in sqrt1337) echo sqrt1337.sh;; addsum32) echo addsum.sh;; *) echo "$1.sh";; esac; }
prob_n()    { case "$1" in addsum) echo 1000000;; addsum32) echo 46340;; squares) echo 1000000;; hash) echo 1000000;; collatz) echo 500;; sqrt1337) echo "";; esac; }
prob_c()    { echo "$1.c"; }
if [ -n "$ONLY" ]; then PROBLEMS="$ONLY"; fi

median() { # stdin numbers -> median
  sort -n | awk '{a[NR]=$1} END {print (NR%2 ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2)}'
}

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

# include-flags subset of the link flags (for -c compiles: sources and
# -Wl/-l/-pthread would break `gcc -c`; see tcc.rs link_needs).
inc_flags() { # $1 = C file; echoes -I args (or nothing)
  local f="$1" extra=""
  if grep -q "uu_run.h" "$f"; then extra="-I$RUNTIME -I$RUNTIME/lib"; fi
  echo "$extra"
}

# full link flags for executables (mirrors tcc.rs link_needs).
link_flags() { # $1 = C file; echoes extra args
  local f="$1" extra="-lm"
  if grep -q "uu_run.h" "$f"; then
    extra="$extra $RUNTIME/uu_run.c $RUNTIME/lib/libcoreutils_ffi.so -lpthread -Wl,-rpath,$RUNTIME/lib -I$RUNTIME -I$RUNTIME/lib"
  fi
  if grep -q "gmp.h" "$f"; then extra="$extra -lgmp"; fi
  echo "$extra"
}

vec_report() { # $1=C file -> count|"ERR": vectorized loops under gcc -O3
  local log
  log=$(gcc -O3 $(inc_flags "$1") -fopt-info-vec-optimized -c "$1" -o /dev/null 2>&1) || { echo "ERR"; return 0; }
  echo "$log" | grep -c "optimized: loop vectorized" || true
}

fail() { echo "BENCH FAIL: $*" >&2; exit 1; }

if [ -n "$SAVE" ]; then printf 'problem\tN\tleg\tms\tns_item\tspeedup_vs_bash\tvec_loops\n' > "$SAVE"; fi
printf '%-10s %8s %-8s %12s %12s %10s %4s\n' problem N leg ms ns/item speedup vec

for p in $PROBLEMS; do
  sh="$BENCH/sh/$(prob_sh "$p")"; n="$(prob_n "$p")"; cref="$BENCH/c/$(prob_c "$p")"
  [ -f "$sh" ] || fail "missing $sh"
  [ -f "$cref" ] || fail "missing $cref"

  # ---- build all four legs ----
  gcc -O3 "$cref" -o "$TMP/$p-hand" 2>"$TMP/$p-hand.err" || { head -n 5 "$TMP/$p-hand.err" >&2; fail "gcc $p"; }
  if [ -n "$n" ]; then set -- "$n"; else set --; fi
  "$BO4" -o "$TMP/$p-tcc" "$sh" 2>"$TMP/$p-tcc.err" || { head -n 5 "$TMP/$p-tcc.err" >&2; fail "bash-O4 -o $p"; }
  "$BO4" --emit-c "$sh" > "$TMP/$p-gen.c" 2>"$TMP/$p-gen.err" || fail "emit-c $p"
  # shellcheck disable=SC2086
  gcc -O3 "$TMP/$p-gen.c" $(link_flags "$TMP/$p-gen.c") -o "$TMP/$p-gcc" 2>"$TMP/$p-gcc.err" || { head -n 5 "$TMP/$p-gcc.err" >&2; fail "gcc generated $p"; }
  if [ -n "$n" ]; then set -- "$n"; else set --; fi

  # ---- agreement gate (byte-exact stdout AND exit code) ----
  run() { # $1=label, rest=cmd -> writes stdout file, echoes rc
    local label=$1; shift
    timeout "$TIMEOUT" "$@" > "$TMP/$label.out" 2>/dev/null; echo $?
  }
  if [ -n "$n" ]; then set -- "$n"; else set --; fi
  r_bash=$(run ref-bash bash "$sh" "$@"); r_tcc=$(run ref-tcc "$TMP/$p-tcc" "$@")
  r_bgcc=$(run ref-gcc "$TMP/$p-gcc" "$@"); r_hand=$(run ref-hand "$TMP/$p-hand" "$@")
  for leg in ref-tcc ref-gcc ref-hand; do
    cmp -s "$TMP/ref-bash.out" "$TMP/$leg.out" || fail "$p: stdout differs ($leg vs bash)"
  done
  [ "$r_bash" = "$r_tcc" ] && [ "$r_bash" = "$r_bgcc" ] && [ "$r_bash" = "$r_hand" ] \
    || fail "$p: exit codes differ (bash=$r_bash tcc=$r_tcc gcc=$r_bgcc hand=$r_hand)"
  echo "  $p: outputs agree" >&2

  # ---- time (warmup + median of RUNS; sqrt1337 bash leg runs once) ----
  if [ -n "$n" ]; then set -- "$n"; else set --; fi
  bash "$sh" "$@" >/dev/null 2>&1; "$TMP/$p-tcc" "$@" >/dev/null 2>&1
  "$TMP/$p-gcc" "$@" >/dev/null 2>&1; "$TMP/$p-hand" "$@" >/dev/null 2>&1
  bruns="$RUNS"; [ "$p" = sqrt1337 ] && bruns=1; [ "$p" = collatz ] && bruns=1
  truns="$RUNS"; [ "$p" = collatz ] && truns=1
  ns_bash=$(t_ns "$bruns" bash "$sh" "$@") || fail "timing bash $p"
  ns_tcc=$(t_ns "$truns" "$TMP/$p-tcc" "$@") || fail "timing tcc $p"
  ns_bgcc=$(t_ns "$truns" "$TMP/$p-gcc" "$@") || fail "timing bo4-gcc $p"
  ns_hand=$(t_ns "$truns" "$TMP/$p-hand" "$@") || fail "timing hand $p"

  # ---- vectoriser report (handwritten + generated C) ----
  v_hand=$(vec_report "$cref")
  v_gen=$(vec_report "$TMP/$p-gen.c")
  items="${n:-10000}"

  row() { # leg ns vec -> table line (+tsv)
    local leg=$1 ns=$2 vec=$3 ms ni sp
    ms=$(awk -v s="$ns" 'BEGIN {printf "%.3f", s/1e6}')
    ni=$(awk -v s="$ns" -v n="$items" 'BEGIN {printf "%.2f", s/n}')
    sp=$(awk -v b="$ns_bash" -v m="$ns" 'BEGIN {printf "%.1f", (m>500 ? b/m : 0)}')
    printf '%-10s %8s %-8s %12s %12s %10s %4s\n' "$p" "${n:-(fixed)}" "$leg" "$ms" "$ni" "$sp" "$vec"
    if [ -n "$SAVE" ]; then printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$p" "${n:-10000}" "$leg" "$ms" "$ni" "$sp" "$vec" >> "$SAVE"; fi
  }
  row bash "$ns_bash" "-"
  row bo4-tcc "$ns_tcc" "-"
  row bo4-gcc "$ns_bgcc" "$v_gen"
  row gcc-O3 "$ns_hand" "$v_hand"
done
