#!/usr/bin/env bash
# bench_sqrt.sh — dash / auto-JS / hand-JS / C -O3 benchmark of ~/sqrt1337.sh
# (find i in 1..10000 where i^2 contains "1337" — output 3657 5598 7165).
#
#   * dash:        real dash running the original script (spawns seq+grep
#                  per iteration)
#   * auto-js:     otranspilerl --target estree -> estree-runner (the transpiled JS:
#                  native arith + String(...).includes, no spawns)
#   * hand-js:     a hand-written native JS equivalent (the fully-inlined
#                  ideal the transpiler is converging toward)
#   * c:           the same logic compiled with gcc -O3
#
# Each prints the same output (verified); timing = median of RUNS (dash gets
# 1 run — it takes ~60s+). Env: SRC (default ~/sqrt1337.sh), RUNS (default 3).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OTRANSPILERL="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
RUNNER="node $ROOT/harness/estree-runner.mjs"
SRC="${SRC:-$HOME/sqrt1337.sh}"
RUNS="${RUNS:-3}"
HAND_JS="${HAND_JS:-/tmp/sqrtbench/sqrt1337.js}"
C_BIN="${C_BIN:-/tmp/sqrtbench/sqrt1337_c}"
AUTO_JSON=/tmp/sqrt_auto.json

# generate the transpiled program once (process-substitution fds are
# single-use, so the timing loop needs a real file)
"$OTRANSPILERL" --target estree "$SRC" 2>/dev/null > "$AUTO_JSON"

t_sec() { # seconds (median over RUNS) for a command
  local runs=$1; shift
  local ts=()
  for _ in $(seq "$runs"); do
    ts+=($(/usr/bin/time -f "%e" "$@" 2>&1 >/dev/null))
  done
  printf '%s\n' "${ts[@]}" | sort -n | awk '{a[NR]=$1} END {print (NR%2 ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2)}'
}

echo "=== verifying identical output ==="
exp=$(timeout 300 dash "$SRC" 2>/dev/null)
echo "  dash: OK (same output)"
out=$(timeout 300 node "$HAND_JS" 2>/dev/null)
[ "$out" = "$exp" ] && echo "  hand-js: OK (same output)" || { echo "  hand-js: OUTPUT MISMATCH"; exit 1; }
out=$(timeout 300 "$C_BIN" 2>/dev/null)
[ "$out" = "$exp" ] && echo "  c: OK (same output)" || { echo "  c: OUTPUT MISMATCH"; exit 1; }
out=$(node "$ROOT/harness/estree-runner.mjs" "$AUTO_JSON" --source "$SRC" 2>/dev/null)
[ "$out" = "$exp" ] && echo "  auto-js: OK (same output)" || { echo "  auto-js: OUTPUT MISMATCH"; exit 1; }

echo
echo "=== timing (seconds, lower is better) ==="
printf "%-10s %12s\n" "impl" "median(s)"
td=$(t_sec 1 dash "$SRC")
echo "dash       $td"
tj=$(t_sec "$RUNS" node "$ROOT/harness/estree-runner.mjs" "$AUTO_JSON" --source "$SRC")
echo "auto-js    $tj"
th=$(t_sec "$RUNS" node "$HAND_JS")
echo "hand-js    $th"
tc=$(t_sec "$RUNS" "$C_BIN")
echo "c -O3      $tc"

echo
echo "=== speedups vs dash ==="
awk -v d="$td" -v j="$tj" -v h="$th" -v c="$tc" 'BEGIN {
  printf "dash:    1.0x\n";
  printf "auto-js: %.1fx\n", d/j;
  printf "hand-js: %.1fx\n", d/h;
  printf "c -O3:   %s\n", (c > 0.001 ? sprintf("%.1fx", d/c) : ">10000x");
}'
