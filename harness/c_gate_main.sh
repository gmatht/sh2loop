#!/bin/bash
# c_gate_main.sh — c_gate_repro.sh logic, rendering through MAIN's renderer
# (the superior worktree renderer was merged into main in 952a2cab).
# Usage: harness/c_gate_main.sh [--sanitize[=asan|thread]] [file.sh ...] [jobs N]
#   SANITIZE=1|asan|thread  same as --sanitize (env form; flag wins)
#   SANITIZE_CC=cc          compiler for the sanitize pass (gcc/clang both OK)
# The default pass compiles with plain `cc` and diffs stdout vs bash (fast).
# The sanitize pass (opt-in) recompiles every PASSing program with
#   -fsanitize=address,undefined (or thread,undefined) -fno-sanitize-recover=all
#   -g -O1 -fno-omit-frame-pointer
# and re-runs it under ASAN_OPTIONS/UBSAN_OPTIONS halt-on-error; any
# sanitizer finding or stdout mismatch turns the PASS into FAIL ... sanitize.
# New sanitize reds are renderer bugs (fix the generator, never bless).
# NOTE: address and thread are mutually exclusive — pick one per run.
set -u
ROOT=/home/llm/sh2loop
SUB=$ROOT/sh2perl
CORE=${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}
CC=cc
SANITIZE_CC=${SANITIZE_CC:-cc}
SANITIZE=${SANITIZE:-0}
if [ "${1:-}" = "--sanitize" ]; then SANITIZE=asan; shift; fi
if [ "${1:-}" = "--sanitize=asan" ]; then SANITIZE=asan; shift; fi
if [ "${1:-}" = "--sanitize=thread" ]; then SANITIZE=thread; shift; fi
if [ "$SANITIZE" = "1" ]; then SANITIZE=asan; fi
JOBS=${JOBS:-8}
if [ "${1:-}" = "jobs" ]; then JOBS=$2; shift 2; fi
if [ $# -gt 0 ]; then corpus=$(printf '%s\n' "$@"); else corpus=$(ls $SUB/examples/*.sh $ROOT/frontends/*/testdata/*.sh 2>/dev/null); fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Sanitize-pass setup: pick flags, then probe the toolchain once. If the
# probe fails (no sanitizer runtime), disable the pass rather than failing
# the whole gate on toolchain drift.
SAN_FLAGS=""
if [ "$SANITIZE" != "0" ]; then
  case "$SANITIZE" in
    asan)   SAN_FLAGS="-fsanitize=address,undefined -fno-sanitize-recover=all -g -O1 -fno-omit-frame-pointer" ;;
    thread) SAN_FLAGS="-fsanitize=thread,undefined -fno-sanitize-recover=all -g -O1 -fno-omit-frame-pointer" ;;
    *) echo "c_gate_main: unknown SANITIZE=$SANITIZE (want asan|thread|0); sanitize pass off" >&2; SANITIZE=0 ;;
  esac
fi
if [ "$SANITIZE" != "0" ]; then
  if ! printf 'int main(void){return 0;}\n' | $SANITIZE_CC $SAN_FLAGS -x c - -o "$tmp/probe_san" 2>/dev/null; then
    echo "c_gate_main: $SANITIZE_CC rejects $SANITIZE flags; sanitize pass off" >&2
    SANITIZE=0; SAN_FLAGS=""
  fi
  rm -f "$tmp/probe_san"
fi
# Link libraries the C backend may emit: GMP (bigint) and libm (sqrt).
# Probe once; add only what the toolchain provides (a missing -lgmp must
# not fail the whole gate — the bigint subset is a renderer gap to fix).
CLIBS=""
if printf 'int main(void){return 0;}\n' | cc -x c - -o "$tmp/probe_libs" -lgmp -lm 2>/dev/null; then
  CLIBS="-lgmp -lm"
fi
rm -f "$tmp/probe_libs"
run_one() {
  f="$1"; id=$(echo "$f" | md5sum | cut -d' ' -f1)
  d="$tmp/$id"; mkdir -p "$d"
  # absolute script path: run_one executes in $d (CWD isolation), so a
  # relative $1 would not resolve there (and would silently empty $ref)
  case "$f" in
    /*) ;;
    *) f="$PWD/$f" ;;
  esac
  shir=$("$CORE" "$f" --source-lang sh --target shir --raw 2>/dev/null) || { echo "SKIP $f" > "$d/v"; return; }
  [ -z "$shir" ] && { echo "SKIP $f" > "$d/v"; return; }
  bash -n "$f" 2>/dev/null || { echo "SKIP $f" > "$d/v"; return; }
  g_out=$(printf '%s' "$shir" | "$CORE" - --target c 2>"$d/rerr") || { echo "FAIL $f render" > "$d/v"; return; }
  s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2_[A-Za-z_]" || true)
  if [ "$s" -gt 0 ]; then echo "FAIL $f stub:$s" > "$d/v"; cp <<<"$g_out" /dev/null 2>/dev/null; printf '%s' "$g_out" > "$d/prog.c"; return; fi
  printf '%s' "$g_out" > "$d/prog.c"
  eq_exit=1
  # run_one executes the binary AND bash in the test's own temp dir:
  # tests that write relative files (heredoc-*-span.sh both write x.py)
  # raced each other under parallel load when sharing the invoker's CWD.
  # Both sides share the isolated dir, so CWD-sensitive comparisons
  # (`basename $(pwd)`, $0-absolute) still agree; litter dies with $tmp.
  cc "$d/prog.c" $CLIBS -o "$d/bin" 2>"$d/ccerr" && (cd "$d" && timeout 15 ./bin > out 2>/dev/null) && eq_exit=0
  bash_rc=0
  (cd "$d" && timeout 15 bash "$f" > ref 2>/dev/null) || bash_rc=$?
  verdict=FAIL
  if [ "$eq_exit" != 124 ] && [ "$bash_rc" != 124 ] && [ "$eq_exit" = 0 ] && [ "$bash_rc" = 0 ] \
     && diff -q "$d/out" "$d/ref" >/dev/null 2>&1; then
    verdict=PASS
  fi
  # Sanitize pass: recompile with ASan/TSan+UBSan, rerun under halt-on-error,
  # stdout must still match bash. Runs only on PASS (the compilable subset).
  if [ "$verdict" = PASS ] && [ "${SANITIZE:-0}" != "0" ]; then
    if $SANITIZE_CC $SAN_FLAGS "$d/prog.c" $CLIBS -o "$d/bin_san" 2>"$d/sanccerr"; then
      san_exit=1
      if [ "$SANITIZE" = thread ]; then
        (cd "$d" && TSAN_OPTIONS=halt_on_error=1:exitcode=99 timeout 30 ./bin_san > sanout 2>sanerr) && san_exit=0 || san_exit=$?
      else
        (cd "$d" && ASAN_OPTIONS=strict_string_checks=1:detect_stack_use_after_return=1:detect_leaks=1 \
        UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
        timeout 30 ./bin_san > sanout 2>sanerr) && san_exit=0 || san_exit=$?
      fi
      if [ "$san_exit" != 0 ] || ! diff -q "$d/sanout" "$d/ref" >/dev/null 2>&1; then
        first_err=$(grep -m1 -oE "(ERROR: AddressSanitizer[^ ]*|SUMMARY: .*|runtime error: .*|WARNING: ThreadSanitizer[^ ]*|ERROR: LeakSanitizer[^ ]*)" "$d/sanerr" 2>/dev/null || head -c 120 "$d/sanerr" 2>/dev/null | tr '\n' ' ')
        verdict="FAIL $f sanitize($SANITIZE rc=$san_exit${first_err:+: $first_err})"
        # verdict already contains the FAIL line; emit below
        echo "$verdict" > "$d/v"
        return
      fi
    else
      echo "FAIL $f sanitize-compile" > "$d/v"
      return
    fi
  fi
  if [ "$verdict" = PASS ]; then
    echo "PASS $f" > "$d/v"
  else
    echo "FAIL $f exec/diff" > "$d/v"
  fi
}
export -f run_one; export tmp CORE CC SANITIZE SAN_FLAGS SANITIZE_CC CLIBS
printf '%s\n' "$corpus" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
cat "$tmp"/*/v | sort > "$tmp/all"
pass=$(grep -c '^PASS' "$tmp/all"); skip=$(grep -c '^SKIP' "$tmp/all"); fail=$(grep -c '^FAIL' "$tmp/all")
echo "PASS=$pass FAIL=$fail SKIP=$skip"
grep '^FAIL' "$tmp/all"
