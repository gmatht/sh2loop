#!/usr/bin/env bash
# bench.sh — bash / dash / transpiled-JS / transpiled-C benchmark.
#   * shellbench samples (/tmp/shellbench/sample/*.sh): each #bench section
#     is extracted, wrapped in an N-iteration loop (N auto-calibrated so bash
#     takes ~CAL_MS), and timed under bash, dash, the transpiled JS, and the
#     transpiled C at one or more compiler levels.
#   * sqrt1337.sh (the 10k-iteration echo|grep search) timed under all.
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
DEBASHC="${DEBASHC:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"  # the CLI is in the workspace crate now, not the submodule
# C renderer. Order:
#   1. $C_RENDER when set (an explicit worktree binary, read as
#      "<bin> --target=c -" on stdin, with a bare "<bin>" fallback);
#   2. the CLI's own in-process C backend (`--target c`) — the same
#      renderer harness/c_gate_main.sh exercises, so the column exists
#      without a separate worktree. It is what the 2026-11-27 capture used:
#      every sample rendered, and every benchmark that compiled printed the
#      same final line as bash. NOTE: `--target shir | <external
#      shir_render>` does NOT work here — the renderer that consumes the A1
#      needs its own ingress passes and loses type verdicts, which showed up
#      as `var = _s1` storing a pointer into a `long long` (a C compile
#      error) on the `string length` bench.
render_c() { # script.sh -> C on stdout (rc!=0 when nothing rendered)
  local out
  if [ -n "${C_RENDER:-}" ] && [ -x "$C_RENDER" ]; then
    out=$("$DEBASHC" --target shir "$1" 2>/dev/null | "$C_RENDER" --target=c - 2>/dev/null)
    if [ -z "$out" ]; then
      out=$("$DEBASHC" --target shir "$1" 2>/dev/null | "$C_RENDER" 2>/dev/null)
    fi
  else
    out=$("$DEBASHC" --target c "$1" 2>/dev/null)
  fi
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}
RUNNER="node $ROOT/harness/estree-runner.mjs"
SB="${SHELLBENCH_DIR:-/tmp/shellbench}"
CAL_MS="${CAL_MS:-300}"

# extract #bench sections from a sample: prints
#   NAME<TAB>PRE-LINES<TAB>BODY-LINES<TAB>SETUP<TAB>CLEANUP   (tab-joined)
extract_benches() { # sample outdir -> writes outdir/N/<name>.{pre,body,setup,cleanup,post}
  local sample=$1 outdir=$2
  mkdir -p "$outdir"
  awk -F'\t' -v out="$outdir" '
    BEGIN { idx = 0 }
    /^setup\(\)/ { in_setup=1; setup=$0 "\n"; if ($0 ~ /}$/) in_setup=0; next }
    in_setup { setup = setup $0 "\n"; if ($0 ~ /}$/) in_setup=0; next }
    /^cleanup\(\)/ { in_cleanup=1; cleanup=$0 "\n"; if ($0 ~ /}$/) in_cleanup=0; next }
    in_cleanup { cleanup = cleanup $0 "\n"; if ($0 ~ /}$/) in_cleanup=0; next }
    /^[[:space:]]*#bench[[:space:]]*"/ {
      if (name != "" && body != "") {
        print name > out "/" idx ".name"
        printf "%s", pre  > out "/" idx ".pre"
        printf "%s", body > out "/" idx ".body"
        printf "%s", setup > out "/" idx ".setup"
        printf "%s", cleanup > out "/" idx ".cleanup"
        printf "%s", post > out "/" idx ".post"
        idx++
      }
      # the marker is INDENTED inside the section function wrapper
      # ("  #bench \"assign variable\""); anchoring on ^#bench matched
      # nothing and every sample silently yielded zero benches.
      name=$0; sub(/^[[:space:]]*#bench[[:space:]]*"/, "", name); sub(/".*/, "", name)
      pre=""; body=""; post=""; in_pre=1; in_body=0; in_post=0
      next
    }
    # @begin/@end may be indented (they sit inside the section func wrapper)
    name != "" && /^[[:space:]]*@begin/ { in_pre=0; in_body=1; next }
    name != "" && /^[[:space:]]*@end/ { in_body=0; in_post=1; next }
    name != "" && in_body { body = body $0 "\n"; next }
    name != "" && in_pre && $0 !~ /^@/ { pre = pre $0 "\n"; next }
    name != "" && in_post { post = post $0 "\n" }
    END {
      if (name != "" && body != "") {
        print name > out "/" idx ".name"
        printf "%s", pre  > out "/" idx ".pre"
        printf "%s", body > out "/" idx ".body"
        printf "%s", setup > out "/" idx ".setup"
        printf "%s", cleanup > out "/" idx ".cleanup"
        printf "%s", post > out "/" idx ".post"
        idx++
      }
      print idx
    }
  ' "$sample"
}

make_runner() { # N pre body setup cleanup post > out
  local n=$1 pre=$2 body=$3 setup=$4 cleanup=$5 post=$6
  [ -z "$setup" ] && setup="setup() { :; }"
  [ -z "$cleanup" ] && cleanup="cleanup() { :; }"
  {
    echo '#!/bin/sh'
    [ -n "$setup" ] && echo "$setup"
    # the pre lines (the section's function wrapper: 'func() {' and any
    # 'local var' decls) open a scope the post lines (@end's closing '}'
    # + the 'func' call) close — together they define and call the
    # section's function once, with the N-iteration loop inside it. pre /
    # body / post are emitted VERBATIM: re-indenting would move here-doc
    # terminators (EOF at column 0) off column 0 and break the runner.
    printf '%s\n' "$pre"
    echo "__count=0"
    echo 'while [ $__count -lt '"$n"' ]; do'
    printf '%s\n' "$body"
    echo '  __count=$((__count+1))'
    echo 'done'
    # observe the loop result: keeps the C column honest (a compiler that
    # dead-code-eliminates the loop would otherwise report a bogus floor) and
    # lets the C column gate its stdout against bash's (fast-but-WRONG runs
    # are reported as WRONG, never blessed).
    echo 'echo "$__count"'
    printf '%s\n' "$post"
    [ -n "$cleanup" ] && echo "$cleanup"
  } > /tmp/bench_runner.sh
}


timed() { # [timeout_secs=60] cmd... -> seconds with 6 decimals ("ERR" on timeout)
  python3 -c '
import subprocess, sys, time
to = 60
args = sys.argv[1:]
if args and args[0].isdigit():
    to = int(args[0]); args = args[1:]
t0 = time.perf_counter()
try:
    subprocess.run(args, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=to)
    print(f"{time.perf_counter() - t0:.6f}")
except subprocess.TimeoutExpired:
    print("ERR")
' "$@"
}

time_shell() { # shell script → seconds (or "ERR")
  local sh=$1 f=$2
  local t
  t=$(timed 60 "$sh" "$f")
  [[ "$t" =~ ^[0-9.]+$ ]] && echo "$t" || echo ERR
}

# ESTree JSON (for the sh2.* call-site tally) and runnable JS (for timing)
# from ONE shIR render. The old `file --estree` spelling is gone from the
# CLI — it now reads `--estree` as a filename and exits 1, so the JS column
# was silently ERR everywhere.
estree_json() { # script.sh -> ESTree JSON on stdout
  "$DEBASHC" --target shir "$1" 2>/dev/null | "$DEBASHC" - --target estree 2>/dev/null
}

js_program() { # script.sh -> runnable ESM with the sh2 namespace prepended
  printf 'import { sh2 } from "%s";\n' "$ROOT/harness/sh2-namespace.mjs"
  "$DEBASHC" --target js "$1" 2>/dev/null
}

time_js() { # script → seconds (or "ERR")
  local f=$1
  command -v node >/dev/null 2>&1 || { echo ERR; return; }
  js_program "$f" > /tmp/bench_runner.mjs
  [ -s /tmp/bench_runner.mjs ] || { echo ERR; return; }
  local t
  t=$(timed 60 node /tmp/bench_runner.mjs)
  [[ "$t" =~ ^[0-9.]+$ ]] && echo "$t" || echo ERR
}

cc_label() { # compiler invocation → column label (e.g. 'tcc -O3' -> tcc-O3)
  printf '%s' "$1" | awk '{f=$NF; sub(/^-+/, "", f); printf "%s-%s", $1, f}'
}

calibrate() { # pre body setup cleanup post → N such that bash takes ~CAL_MS
  local pre=$1 body=$2 setup=$3 cleanup=$4 post=$5
  local n=1000
  while [ $n -le 100000000 ]; do
    make_runner "$n" "$pre" "$body" "$setup" "$cleanup" "$post"
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
  render_c "$f" > /tmp/bench_runner.c || { echo ERR; return; }
  # `-lgmp -lm`: the C backend emits mpz_* for constant folding and libm for
  # the numeric helpers (harness/c_gate_main.sh links both, probing first).
  # Without -lgmp every bench that folds a constant failed to LINK, which
  # the driver reported as a bare ERR.
  $cc -o /tmp/bench_runner_c /tmp/bench_runner.c -lgmp -lm 2>/dev/null \
     || $cc -o /tmp/bench_runner_c /tmp/bench_runner.c -lm 2>/dev/null \
     || { echo ERR; return; }
  local t out
  out=$(timeout 60 /tmp/bench_runner_c 2>/dev/null)
  t=$(timed 60 /tmp/bench_runner_c)
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
    post=$(cat "$OUT/$i.post")
    n=$(calibrate "$pre" "$body" "$setup" "$cleanup" "$post")
    make_runner "$n" "$pre" "$body" "$setup" "$cleanup" "$post"
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
    estree_json /tmp/bench_runner.sh > /tmp/bench_runner.json
    st=$(perl "$ROOT/harness/sh2stat.pl" /tmp/bench_runner.json 2>/dev/null) || st='-\t-\t-'
    [ -n "$st" ] || st='-\t-\t-'   # a blank tally looks like a measurement
    printf "   sh2[%s]\n" "$st"
  done
done

echo
echo "=== sqrt1337.sh (10k iterations, echo \$((i*i)) | grep 1337) ==="
# the repo's own copy (it lived in $HOME when the suite was first written;
# $HOME/sqrt1337.sh may not exist, which made every leg exit 127 at 1.5 ms
# and report a bogus 0.0 s "speed run"). SRC= overrides.
S="${SRC:-$ROOT/sh2perl/sqrt1337.sh}"
[ -f "$S" ] || { echo "no $S (set SRC=)"; S=""; }
if [ -n "$S" ]; then
printf "%-12s %12s %12s\n" "shell" "time(s)" "ratio"
for sh in bash dash; do
  t=$(timed 300 "$sh" "$S")
  [[ "$t" =~ ^[0-9.]+$ ]] && printf "%-12s %12s %12s\n" "$sh" "$t" "1.0x" \
    || printf "%-12s %12s %12s\n" "$sh" "ERR(>300s)" "1.0x"
done
if js_program "$S" > /tmp/sqrt1337.mjs && [ -s /tmp/sqrt1337.mjs ]; then
  tj=$(timed 60 node /tmp/sqrt1337.mjs)
  printf "%-12s %12s\n" "js" "$tj"
else
  printf "%-12s %12s\n" "js" "ERR"
fi
# the C column: the c renderer (shir_render) renders sqrt1337 -> compile ->
# run. The
# renderer only lowers the lowable subset (echo/arith); a grep pipeline is
# NOT lowable — verify the output matches bash before timing (a fast but
# WRONG run is worse than an honest 'unlowerable'). Correctness is checked
# once (level-independent), then each CC_LEVELS compiler is timed.
cc0="${LEVELS[0]}"
if render_c "$S" > /tmp/sqrt1337.c && $cc0 -o /tmp/sqrt1337_c /tmp/sqrt1337.c -lgmp -lm 2>/dev/null; then
  if [ "$(/tmp/sqrt1337_c 2>/dev/null)" = "$(seq 1 10000 | awk '{s=$1*$1; if (s ~ /1337/) print $1}')" ]; then
    for cc in "${LEVELS[@]}"; do
      $cc -o /tmp/sqrt1337_c /tmp/sqrt1337.c -lgmp -lm 2>/dev/null
      tc=$(timed 60 /tmp/sqrt1337_c)
      printf "%-12s %12s\n" "c($(cc_label "$cc"))" "$tc"
    done
  else
    printf "%-12s %12s\n" "c($(cc_label "$cc0"))" "unlowerable"
  fi
else
  printf "%-12s %12s\n" "c($(cc_label "$cc0"))" "render-err"
fi
fi
