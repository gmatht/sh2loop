#!/usr/bin/env bash
# bench_sqrt.sh — dash / auto-JS / hand-JS / C -O3 benchmark of ~/sqrt1337.sh
# (find i in 1..10000 where i^2 contains "1337" — output 3657 5598 7165).
#
#   * dash:        real dash running the original script (spawns seq+grep
#                  per iteration)
#   * auto-js:     otranspilerl --target js -> real JS with the sh2 namespace
#                  prepended (the transpiled JS: native arith +
#                  String(...).includes, no spawns)
#   * hand-js:     a hand-written native JS equivalent (the fully-inlined
#                  ideal the transpiler is converging toward)
#   * c:           the same logic compiled with gcc -O3
#
# Each prints the same output (verified); timing = median of RUNS (dash gets
# 1 run — it takes ~10s+). Env: SRC (default the repo's sh2perl/sqrt1337.sh),
# RUNS (default 3). The hand-written JS and the C binary must already exist
# (HAND_JS / C_BIN): this script times them, it does not build them.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OTRANSPILERL="${OTRANSPILERL:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
SRC="${SRC:-$ROOT/sh2perl/sqrt1337.sh}"
RUNS="${RUNS:-3}"
HAND_JS="${HAND_JS:-/tmp/sqrtbench/sqrt1337.js}"
C_BIN="${C_BIN:-/tmp/sqrtbench/sqrt1337_c}"
AUTO_JS=/tmp/sqrtbench/sqrt1337_auto.mjs

# Generate the transpiled program once (process-substitution fds are
# single-use, so the timing loop needs a real file).
#
# `--target js` emits runnable JavaScript (top-level await, plain ESM) and
# expects the `sh2` runtime to be in scope; the old `--estree` spelling is
# no longer a CLI flag (the current CLI reads `--estree` as a filename and
# exits 1), so this is the runnable form of the same lowering. The namespace
# is the same module the estree runner imports (harness/sh2-namespace.mjs),
# resolved by absolute path — no NODE_PATH, no vendor tree to install.
NS="$ROOT/harness/sh2-namespace.mjs"
mkdir -p "$(dirname "$AUTO_JS")"
{ printf 'import { sh2 } from "%s";\n' "$NS"
  "$OTRANSPILERL" --target js "$SRC" 2>/dev/null
} > "$AUTO_JS"
[ -s "$AUTO_JS" ] || { echo "transpile of $SRC produced nothing (--target js)" >&2; exit 1; }

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
if [ ! -x "$C_BIN" ]; then
  # Missing is not a mismatch: say so and time only the legs that exist
  # (a bare "OUTPUT MISMATCH" for an absent binary has chased two people).
  echo "  c: SKIPPED — no executable at $C_BIN (build one with bash-O4 -o, or set C_BIN=)"
else
  out=$(timeout 300 "$C_BIN" 2>/dev/null)
  [ "$out" = "$exp" ] && echo "  c: OK (same output)" || { echo "  c: OUTPUT MISMATCH"; exit 1; }
fi
out=$(node "$AUTO_JS" 2>/dev/null)
[ "$out" = "$exp" ] && echo "  auto-js: OK (same output)" || { echo "  auto-js: OUTPUT MISMATCH"; exit 1; }

echo
echo "=== timing (seconds, lower is better) ==="
printf "%-10s %12s\n" "impl" "median(s)"
td=$(t_sec 1 dash "$SRC")
echo "dash       $td"
tj=$(t_sec "$RUNS" node "$AUTO_JS")
echo "auto-js    $tj"
th=$(t_sec "$RUNS" node "$HAND_JS")
echo "hand-js    $th"
tc=""; [ -x "$C_BIN" ] && tc=$(t_sec "$RUNS" "$C_BIN")
echo "c -O3      ${tc:--}"

echo
echo "=== speedups vs dash ==="
awk -v d="$td" -v j="$tj" -v h="$th" -v c="$tc" 'BEGIN {
  printf "dash:    1.0x\n";
  printf "auto-js: %.1fx\n", d/j;
  printf "hand-js: %.1fx\n", d/h;
  printf "c -O3:   %s\n", (c == "" ? "- (binary absent)" : c > 0.001 ? sprintf("%.1fx", d/c) : ">10000x");
}'
