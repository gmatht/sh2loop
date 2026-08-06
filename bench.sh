#!/usr/bin/env bash
# bench.sh — bash / dash / transpiled-JS / transpiled-C benchmark.
#   * shellbench samples (/tmp/shellbench/sample/*.sh): each #bench section
#     is extracted, wrapped in an N-iteration loop (N auto-calibrated so bash
#     takes ~CAL_MS), and timed under bash, dash, the transpiled JS, and the
#     transpiled C at one or more compiler levels.
#   * ~/sqrt1337.sh (the 10k-iteration echo|grep search) timed under all.
#
# Usage: bench.sh [sample.sh ...]    (default: all shellbench samples)
# Env:   SHELLBENCH_DIR  where shellbench was cloned (default /tmp/shellbench)
#        CAL_MS          calibration target for bash per bench (default 300)
#        CC_LEVELS       | -separated compiler invocations for the C column
#                        (default: tcc -D__STDC_NO_VLA__ -O2; the define stops
#                        glibc 2.39 regex.h emitting a VLA-in-param prototype,
#                        which tcc 0.9.27 can't parse — gcc ignores it).
#                        e.g. 'tcc -D__STDC_NO_VLA__ -O0|tcc -D__STDC_NO_VLA__ -O3'
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEBASHC="$ROOT/sh2perl/target/debug/debashc"
RUNNER="node $ROOT/harness/estree-runner.mjs"
SB="${SHELLBENCH_DIR:-/tmp/shellbench}"
CAL_MS="${CAL_MS:-300}"

# extract #bench sections from a sample: prints
#   NAME<TAB>PRE-LINES<TAB>BODY-LINES<TAB>SETUP<TAB>CLEANUP   (tab-joined)
extract_benches() { # sample outdir -> writes outdir/N/<name>.{pre,body,setup,cleanup}
  local sample=$1 outdir=$2
  mkdir -p "$outdir"
  awk -F'\t' -v out="$outdir" '
    BEGIN { idx = 0 }
    /^setup\(\)/ { in_setup=1; setup=$0 "\n"; if ($0 ~ /}$/) in_setup=0; next }
    in_setup { setup = setup $0 "\n"; if ($0 ~ /}$/) in_setup=0; next }
    /^cleanup\(\)/ { in_cleanup=1; cleanup=$0 "\n"; if ($0 ~ /}$/) in_cleanup=0; next }
    in_cleanup { cleanup = cleanup $0 "\n"; if ($0 ~ /}$/) in_cleanup=0; next }
    /^#bench[[:space:]]*"/ {
      if (name != "" && body != "") {
        print name > out "/" idx ".name"
        printf "%s", pre  > out "/" idx ".pre"
        printf "%s", body > out "/" idx ".body"
        printf "%s", setup > out "/" idx ".setup"
        printf "%s", cleanup > out "/" idx ".cleanup"
        idx++
      }
      name=$0; sub(/^#bench[[:space:]]*"/, "", name); sub(/".*/, "", name)
      pre=""; body=""; in_pre=1; in_body=0
      next
    }
    name != "" && /^@begin/ { in_pre=0; in_body=1; next }
    name != "" && /^@end/ { in_body=0; next }
    name != "" && in_body { body = body $0 "\n"; next }
    name != "" && in_pre && $0 !~ /^@/ { pre = pre $0 "\n" }
    END {
      if (name != "" && body != "") {
        print name > out "/" idx ".name"
        printf "%s", pre  > out "/" idx ".pre"
        printf "%s", body > out "/" idx ".body"
        printf "%s", setup > out "/" idx ".setup"
        printf "%s", cleanup > out "/" idx ".cleanup"
        idx++
      }
      print idx
    }
  ' "$sample"
}

make_runner() { # N pre body setup cleanup > out
  local n=$1 pre=$2 body=$3 setup=$4 cleanup=$5
  [ -z "$setup" ] && setup="setup() { :; }"
  [ -z "$cleanup" ] && cleanup="cleanup() { :; }" 
  {
    echo '#!/bin/sh'
    [ -n "$setup" ] && echo "$setup"
    printf '%s\n' "$pre" | sed 's/^/ /'
    echo "__count=0"
    echo 'while [ $__count -lt '"$n"' ]; do'
    printf '%s\n' "$body" | sed 's/^/  /'
    echo '  __count=$((__count+1))'
    echo 'done'
    # observe the loop result: keeps the C column honest (a compiler that
    # dead-code-eliminates the loop would otherwise report a bogus floor) and
    # lets the C column gate its stdout against bash's (fast-but-WRONG runs
    # are reported as WRONG, never blessed).
    echo 'echo "$__count"'
    [ -n "$cleanup" ] && echo "$cleanup"
  } > /tmp/bench_runner.sh
}

time_shell() { # shell script → seconds (or "ERR")
  local sh=$1 f=$2
  local t
  t=$(/usr/bin/time -f "%e" timeout 60 "$sh" "$f" 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] && echo "$t" || echo ERR
}

time_js() { # script → seconds (or "ERR")
  local f=$1
  "$DEBASHC" file --estree "$f" 2>/dev/null > /tmp/bench_runner.json || { echo ERR; return; }
  local t
  t=$(/usr/bin/time -f "%e" timeout 60 node "$ROOT/harness/estree-runner.mjs" /tmp/bench_runner.json --source "$f" 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] && echo "$t" || echo ERR
}

cc_label() { # compiler invocation → column label (e.g. 'tcc -O3' -> tcc-O3)
  printf '%s' "$1" | awk '{f=$NF; sub(/^-+/, "", f); printf "%s-%s", $1, f}'
}

calibrate() { # pre body setup cleanup → N such that bash takes ~CAL_MS
  local pre=$1 body=$2 setup=$3 cleanup=$4
  local n=1000
  while [ $n -le 100000000 ]; do
    make_runner "$n" "$pre" "$body" "$setup" "$cleanup"
    local t
    t=$(time_shell bash /tmp/bench_runner.sh)
    [[ "$t" =~ ^[0-9.]+$ ]] || break
    local ms; ms=$(echo "$t * 1000" | bc -l 2>/dev/null || echo 0)
    if [ "${ms%.*}" -ge "$CAL_MS" ] 2>/dev/null; then break; fi
    n=$((n * 4))
  done
  echo "$n"
}

out_shell() { # shell script → stdout (for the C-column correctness gate)
  timeout 60 "$1" "$2" 2>/dev/null
}

run_c() { # CCSPEC script → "TIME\tOUT" (ERR on render/compile/run failure);
  # the same binary is run twice — once for stdout (the gate), once timed.
  local cc=$1 f=$2
  "$ROOT/sh2perl/backends/c/target/debug/c_backend" "$f" 2>/dev/null > /tmp/bench_runner.c || { echo ERR; return; }
  $cc -o /tmp/bench_runner_c /tmp/bench_runner.c 2>/dev/null || { echo ERR; return; }
  local t out
  out=$(timeout 60 /tmp/bench_runner_c 2>/dev/null)
  t=$(/usr/bin/time -f "%e" timeout 60 /tmp/bench_runner_c 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] || t=ERR
  printf '%s\t%s' "$t" "$out"
}

ops() { # seconds → ops/sec (N / t), or ERR (t=0 → the run was sub-ms:
  # the C column dead-code-eliminates unobserved loops — report the floor)
  local n=$1 t=$2
  [[ "$t" =~ ^[0-9.]+$ ]] || { echo ERR; return; }
  awk -v n="$n" -v t="$t" 'BEGIN { if (t > 0) printf "%.0f", n / t; else print ">1e9" }'
}

echo "=== shellbench samples (bash / dash / transpiled JS / transpiled C) ==="
IFS='|' read -ra LEVELS <<< "${CC_LEVELS:-tcc -D__STDC_NO_VLA__ -O2}"
printf "%-24s %12s %12s %12s" "bench" "bash/s" "dash/s" "js/s"
for cc in "${LEVELS[@]}"; do printf " %12s" "$(cc_label "$cc")/s"; done
printf "\n"
OUT=/tmp/bench_sections; rm -rf "$OUT"
for sample in ${@:-$SB/sample/*.sh}; do
  [ -f "$sample" ] || continue
  nsec=$(extract_benches "$sample" "$OUT" | tail -1)
  for (( i = 0; i < nsec; i++ )); do
    name=$(cat "$OUT/$i.name")
    pre=$(cat "$OUT/$i.pre"); body=$(cat "$OUT/$i.body")
    setup=$(cat "$OUT/$i.setup"); cleanup=$(cat "$OUT/$i.cleanup")
    n=$(calibrate "$pre" "$body" "$setup" "$cleanup")
    make_runner "$n" "$pre" "$body" "$setup" "$cleanup"
    tb=$(time_shell bash /tmp/bench_runner.sh)
    td=$(time_shell dash /tmp/bench_runner.sh)
    tj=$(time_js /tmp/bench_runner.sh)
    ref=$(out_shell bash /tmp/bench_runner.sh)   # C column must match this
    printf "%-24s %12s %12s %12s" "$(basename "$sample" .sh):$name" \
      "$(ops "$n" "$tb")" "$(ops "$n" "$td")" "$(ops "$n" "$tj")"
    for cc in "${LEVELS[@]}"; do
      ro=$(run_c "$cc" /tmp/bench_runner.sh)
      t=${ro%%$'\t'*}
      o=${ro#*$'\t'}
      if [ "$t" = ERR ]; then
        printf " %12s" "ERR"
      elif [ "$o" = "$ref" ]; then
        printf " %12s" "$(ops "$n" "$t")"
      else
        printf " %12s" "WRONG"
      fi
    done
    st=$(perl "$ROOT/harness/sh2stat.pl" /tmp/bench_runner.json 2>/dev/null || echo "-\t-\t-")
    printf "   sh2[%s]\n" "$st"
  done
done

echo
echo "=== ~/sqrt1337.sh (10k iterations, echo \$((i*i)) | grep 1337) ==="
S=~/sqrt1337.sh
printf "%-12s %12s %12s\n" "shell" "time(s)" "ratio"
for sh in bash dash; do
  t=$(/usr/bin/time -f "%e" timeout 300 "$sh" "$S" 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] && printf "%-12s %12s %12s\n" "$sh" "$t" "1.0x" \
    || printf "%-12s %12s %12s\n" "$sh" "ERR(>300s)" "1.0x"
done
tj=$(/usr/bin/time -f "%e" timeout 60 node "$ROOT/harness/estree-runner.mjs" \
      <("$DEBASHC" file --estree "$S" 2>/dev/null) --source "$S" 2>&1 >/dev/null)
printf "%-12s %12s\n" "js" "$tj"
# the C column: the c_backend renders sqrt1337 -> tcc -O2 -> run. The
# renderer only lowers the lowable subset (echo/arith); a grep pipeline is
# NOT lowable — verify the output matches bash before timing (a fast but
# WRONG run is worse than an honest 'unlowerable').
# the C column: the c_backend renders sqrt1337 -> compile -> run. The
# renderer only lowers the lowable subset (echo/arith); a grep pipeline is
# NOT lowable — verify the output matches bash before timing (a fast but
# WRONG run is worse than an honest 'unlowerable'). Correctness is checked
# once (level-independent), then each CC_LEVELS compiler is timed.
cc0="${LEVELS[0]}"
if "$ROOT/sh2perl/backends/c/target/debug/c_backend" "$S" 2>/dev/null > /tmp/sqrt1337.c && $cc0 -o /tmp/sqrt1337_c /tmp/sqrt1337.c 2>/dev/null; then
  if [ "$(/tmp/sqrt1337_c 2>/dev/null)" = "$(seq 1 10000 | awk '{s=$1*$1; if (s ~ /1337/) print $1}')" ]; then
    for cc in "${LEVELS[@]}"; do
      $cc -o /tmp/sqrt1337_c /tmp/sqrt1337.c 2>/dev/null
      tc=$(/usr/bin/time -f "%e" timeout 60 /tmp/sqrt1337_c 2>&1 >/dev/null)
      printf "%-12s %12s\n" "c($(cc_label "$cc"))" "$tc"
    done
  else
    printf "%-12s %12s\n" "c($(cc_label "$cc0"))" "unlowerable"
  fi
else
  printf "%-12s %12s\n" "c($(cc_label "$cc0"))" "render-err"
fi
