#!/usr/bin/env bash
# corpus-c — the C-idiom corpus matrix gate (GOOD_EXAMPLES.md conventions,
# applied to C source): every example demonstrates one or two C idioms,
# prints diagnostic output, and is judged ONLY on executed stdout —
#   oracle : native gcc compile+run of the .c source
#   targets: every installed backend renderer fed the C frontend's A1:
#     perl    otranspilerl-cli --source-lang shir --target perl   → perl
#     python  shir_render --target python → python3
#     sh      shir_render --target sh     → bash
#     estree  otranspilerl-cli --source-lang shir --target estree → estree-runner.mjs (node)
#     js      shir_render --target js     → node
#     go      shir_render --target go     → go build+run
#     rust    shir_render --target rust   → rustc+run
#     java    shir_render --target java   → javac+java
#     zig     shir_render --target zig    → zig build-exe -O Debug + run
#       (Debug keeps runtime safety ON: integer overflow, bounds, null-unwrap
#        panics are failures. ZIG_VALGRIND=1 re-runs the built binary under
#        valgrind --leak-check=full (rc 99 → zig=MEM-FAIL cell).
#        ZIG_TSAN=1 builds with -fsanitize-thread instead; not combined with
#        valgrind (TSan binaries under valgrind are noisy) — valgrind is
#        skipped with a note when both are set.)
#     c       shir_render --target c      → gcc (round-trip)
#
# A test passes per target only when transpiled stdout == native stdout.
# No allowlist: a red cell is a pipeline gap signal. A target whose
# toolchain is missing is reported SKIP (documented, not silent).
#
# Usage: corpus-c.sh [--gate] [--only tgt,tgt] [--verbose] [dir]
#   dir default: frontends/corpus-c   TMO: per-step timeout seconds (120)
#   ZIG_VALGRIND=1  memcheck each passing zig binary under valgrind
#   ZIG_TSAN=1      build zig with -fsanitize-thread (data-race detector)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="${CLI:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
CSHGO="${CSHGO:-$ROOT/frontends/c-sh-go/c-sh-go}"
OUTPARAM="$ROOT/harness/outparam_to_returns.py"
ESTREE_RUNNER="$ROOT/harness/estree-runner.mjs"
GATE=0; ONLY=""; DIR=""; VERBOSE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --gate) GATE=1 ;;
    --only) ONLY="${2:-}"; shift ;;
    --verbose|-v) VERBOSE=1 ;;
    *) DIR="$1" ;;
  esac
  shift
done
DIR="${DIR:-$ROOT/frontends/corpus-c}"
TMO="${TMO:-120}"

have() { command -v "$1" >/dev/null 2>&1; }

TARGETS=(perl python sh estree js go rust java zig c)
if [ -n "$ONLY" ]; then IFS=',' read -ra TARGETS <<< "$ONLY"; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Link libraries the C backend may emit: GMP (bigint) and libm (sqrt).
# Probe once; add only what the toolchain provides.
CLIBS=""
if printf 'int main(void){return 0;}\n' | gcc -x c - -o "$tmp/probe_libs" -lgmp -lm 2>/dev/null; then
  CLIBS="-lgmp -lm"
fi
rm -f "$tmp/probe_libs"

total=0; passes=0; fails=0; skips=0
declare -a FAILCELLS

render() { # render <tgt> <a1> <od> — renderer invocation only
  local tgt="$1" a1="$2" od="$3"
  case "$tgt" in
    perl)   "$CLI" - --target pl   < "$a1" > "$od/prog.pl"  2>"$od/render.err" ;;
    python) "$CLI" - --target py   < "$a1" > "$od/prog.py"  2>"$od/render.err" ;;
    sh)     "$CLI" - --target sh   < "$a1" > "$od/prog.sh"  2>"$od/render.err" ;;
    estree) "$CLI" - --target estree < "$a1" > "$od/prog.json" 2>"$od/render.err" ;;
    js)     "$CLI" - --target js   < "$a1" > "$od/prog.js"  2>"$od/render.err" ;;
    go)     "$CLI" - --target go   < "$a1" > "$od/prog.go"  2>"$od/render.err" ;;
    rust)   "$CLI" - --target rs   < "$a1" > "$od/prog.rs"  2>"$od/render.err" ;;
    java)   "$CLI" - --target java < "$a1" > "$od/Sh2Program.java" 2>"$od/render.err" ;;
    zig)    "$CLI" - --target zig  < "$a1" > "$od/prog.zig" 2>"$od/render.err" ;;
    c)      "$CLI" - --target c    < "$a1" > "$od/prog.c"   2>"$od/render.err" ;;
    *) return 9 ;;
  esac
}

exec_target() { # exec_target <tgt> <od> — compile(if needed)+run; stdout → $od/out
  local tgt="$1" od="$2"
  case "$tgt" in
    perl)   timeout $TMO perl "$od/prog.pl" > "$od/out" 2> "$od/run.err" </dev/null ;;
    python) timeout $TMO python3 "$od/prog.py" > "$od/out" 2> "$od/run.err" </dev/null ;;
    sh)     timeout $TMO bash "$od/prog.sh" > "$od/out" 2> "$od/run.err" </dev/null ;;
    estree) timeout $TMO node "$ESTREE_RUNNER" "$od/prog.json" > "$od/out" 2> "$od/run.err" </dev/null ;;
    js)     timeout $TMO node "$od/prog.js" > "$od/out" 2> "$od/run.err" </dev/null ;;
    go)     (cd "$od" && timeout $TMO /snap/go/current/bin/go build -o progbin prog.go) 2>>"$od/run.err" || return 3
            timeout $TMO "$od/progbin" > "$od/out" 2> "$od/run.err" </dev/null ;;
    rust)   timeout $TMO rustc -O -o "$od/progbin" "$od/prog.rs" 2>>"$od/run.err" || return 3
            timeout $TMO "$od/progbin" > "$od/out" 2> "$od/run.err" </dev/null ;;
    java)   (cd "$od" && timeout $TMO javac Sh2Program.java) 2>>"$od/run.err" || return 3
            (cd "$od" && timeout $TMO java Sh2Program) > "$od/out" 2> "$od/run.err" </dev/null ;;
    zig)    have zig || return 4
            tsan=""; [ "${ZIG_TSAN:-0}" = 1 ] && tsan="-fsanitize-thread"
            # -O Debug (default): safety checks ON — a safety panic is a
            # RUN-FAIL, the Zig analog of an ASan/UBSan finding. Never use a
            # safety-off mode (-O ReleaseFast/Small) for the correctness gate.
            # shellcheck disable=SC2086
            (cd "$od" && timeout $((TMO*3)) zig build-exe prog.zig -O Debug $tsan -femit-bin="$od/progbin") 2>>"$od/run.err" || return 3
            if [ "${ZIG_VALGRIND:-0}" = 1 ] && [ "${ZIG_TSAN:-0}" != 1 ]; then
              have valgrind || return 4
              timeout "$TMO" valgrind --error-exitcode=99 --leak-check=full \
                --errors-for-leak-kinds=definite,possible "$od/progbin" > "$od/out" 2> "$od/run.err" </dev/null || return $?
            else
              if [ "${ZIG_VALGRIND:-0}" = 1 ]; then
                echo "(zig: valgrind skipped — not combined with -fsanitize-thread)" >> "$od/run.err"
              fi
              timeout "$TMO" "$od/progbin" > "$od/out" 2> "$od/run.err" </dev/null
            fi ;;
    c)      gcc -o "$od/progbin" "$od/prog.c" $CLIBS 2>>"$od/run.err" || return 3
            timeout $TMO "$od/progbin" > "$od/out" 2> "$od/run.err" </dev/null ;;
    *) return 4 ;;
  esac
}

for f in "$DIR"/*.c; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in *_refuse*) continue;; esac
  bn=$(basename "$f")
  total=$((total+1))
  # oracle: native gcc
  if ! gcc -o "$tmp/native" "$f" $CLIBS 2>"$tmp/gcc.err"; then
    echo "FAIL $bn (native gcc oracle compile: $(head -1 "$tmp/gcc.err"))"
    fails=$((fails+1)); FAILCELLS+=("$bn:oracle"); continue
  fi
  timeout $TMO "$tmp/native" > "$tmp/native.out" 2>/dev/null </dev/null
  # frontend emit (+ outparam transform)
  if ! "$CSHGO" --shir "$f" --raw 2>"$tmp/emit.err" | python3 "$OUTPARAM" > "$tmp/a1.json"; then
    echo "FAIL $bn (frontend emit)"
    fails=$((fails+1)); FAILCELLS+=("$bn:frontend"); continue
  fi
  row=""
  for tgt in "${TARGETS[@]}"; do
    od="$tmp/w_$tgt"; mkdir -p "$od"
    if ! render "$tgt" "$tmp/a1.json" "$od"; then
      row="$row $tgt=RENDER-FAIL"; fails=$((fails+1)); FAILCELLS+=("$bn:$tgt(render)")
      [ "$VERBOSE" = 1 ] && head -2 "$od/render.err" | sed 's/^/       /'
      continue
    fi
    rc=0; exec_target "$tgt" "$od" || rc=$?
    case "$rc" in
      0)
        if diff -q "$tmp/native.out" "$od/out" >/dev/null 2>&1; then
          row="$row $tgt=OK"; passes=$((passes+1))
        else
          row="$row $tgt=DIFF"; fails=$((fails+1)); FAILCELLS+=("$bn:$tgt(diff)")
          [ "$VERBOSE" = 1 ] && diff "$tmp/native.out" "$od/out" | head -6 | sed 's/^/       /'
        fi ;;
      3) row="$row $tgt=COMPILE-FAIL"; fails=$((fails+1)); FAILCELLS+=("$bn:$tgt(compile)")
         [ "$VERBOSE" = 1 ] && head -3 "$od/run.err" | sed 's/^/       /' ;;
      4) row="$row $tgt=SKIP"; skips=$((skips+1)) ;;
      99) row="$row $tgt=MEM-FAIL"; fails=$((fails+1)); FAILCELLS+=("$bn:$tgt(memcheck)")
         [ "$VERBOSE" = 1 ] && grep -m3 -E "Invalid|definitely lost|indirectly lost|ERROR SUMMARY" "$od/run.err" | sed 's/^/       /' ;;
      *) row="$row $tgt=RUN-FAIL($rc)"; fails=$((fails+1)); FAILCELLS+=("$bn:$tgt(run)")
         [ "$VERBOSE" = 1 ] && head -3 "$od/run.err" | sed 's/^/       /' ;;
    esac
  done
  echo "$bn:$row"
done

echo "--- corpus-c matrix: $total examples, cells: $passes pass / $fails fail / $skips skip ---"
if [ -n "${FAILCELLS[*]:-}" ]; then
  printf 'RED CELLS:\n'; printf '  %s\n' "${FAILCELLS[@]}"
fi
if [ "$GATE" = 1 ]; then
  [ "$fails" -eq 0 ] || exit 1
fi
exit 0
