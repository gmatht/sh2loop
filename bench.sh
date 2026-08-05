#!/usr/bin/env bash
# bench.sh — bash / dash / transpiled-JS benchmark.
#   * shellbench samples (/tmp/shellbench/sample/*.sh): each #bench section
#     is extracted, wrapped in an N-iteration loop (N auto-calibrated so bash
#     takes ~CAL_MS), and timed under bash, dash, and the transpiled JS.
#   * ~/sqrt1337.sh (the 10k-iteration echo|grep search) timed under all three.
#
# Usage: bench.sh [sample.sh ...]    (default: all shellbench samples)
# Env:   SHELLBENCH_DIR  where shellbench was cloned (default /tmp/shellbench)
#        CAL_MS          calibration target for bash per bench (default 300)
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

time_c() { # script → seconds via the C backend (sh2c — the c_backend bin)
  local f=$1
  "$ROOT/sh2perl/backends/c/target/debug/c_backend" "$f" 2>/dev/null > /tmp/bench_runner.c || { echo ERR; return; }
  gcc -O2 -o /tmp/bench_runner_c /tmp/bench_runner.c 2>/dev/null || { echo ERR; return; }
  local t
  t=$(/usr/bin/time -f "%e" timeout 60 /tmp/bench_runner_c 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] && echo "$t" || echo ERR
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

ops() { # seconds → ops/sec (N / t), or ERR
  local n=$1 t=$2
  [[ "$t" =~ ^[0-9.]+$ ]] && { awk -v n="$n" -v t="$t" 'BEGIN { printf "%.0f", n / t }'; } || echo ERR
}

echo "=== shellbench samples (bash / dash / transpiled JS) ==="
printf "%-24s %12s %12s %12s %12s\n" "bench" "bash/s" "dash/s" "js/s" "c/s"
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
    tc=$(time_c /tmp/bench_runner.sh)
    st=$(perl "$ROOT/harness/sh2stat.pl" /tmp/bench_runner.json 2>/dev/null || echo "-\t-\t-")
    printf "%-24s %12s %12s %12s %12s   sh2[%s]\n" "$(basename "$sample" .sh):$name" \
      "$(ops "$n" "$tb")" "$(ops "$n" "$td")" "$(ops "$n" "$tj")" "$(ops "$n" "$tc")" "$st"
  done
done

echo
echo "=== ~/sqrt1337.sh (10k iterations, echo \$((i*i)) | grep 1337) ==="
S=~/sqrt1337.sh
printf "%-12s %12s %12s %12s\n" "shell" "time(s)" "ratio" ""
for sh in bash dash; do
  t=$(/usr/bin/time -f "%e" timeout 300 "$sh" "$S" 2>&1 >/dev/null)
  [[ "$t" =~ ^[0-9.]+$ ]] && printf "%-12s %12s %12s\n" "$sh" "$t" "1.0x" \
    || printf "%-12s %12s %12s\n" "$sh" "ERR(>300s)" "1.0x"
done
tj=$(/usr/bin/time -f "%e" timeout 60 node "$ROOT/harness/estree-runner.mjs" \
      <("$DEBASHC" file --estree "$S" 2>/dev/null) --source "$S" 2>&1 >/dev/null)
printf "%-12s %12s\n" "js" "$tj"
