#!/usr/bin/env bash
# harness/c_gate_ubsan.sh — Step 0 of C_UB_PROOF.md: measure the C backend's
# undefined-behaviour surface instead of trusting its comments.
#
# WHY THIS EXISTS, AND WHY IT IS NOT `c_gate_main.sh --sanitize`.
# c_gate_main.sh already HAS a sanitize arm, but that arm cannot answer the
# question this script asks, for three reasons measured 2026-10-22:
#
#  1. It runs ONLY ON `PASS` cells, so it measures the green subset — exactly
#     the subset least likely to contain a lowering bug. Here every program
#     that COMPILES is measured; equivalence vs bash is a SEPARATE verdict
#     (`EQUIV-FAIL`), never a precondition for the UB verdict.
#  2. It sets `ASAN_OPTIONS=detect_leaks=1`. The generated C never frees
#     anything by design (`c_backend.rs`: "limbs live for the process like
#     every other site-static — nothing is freed"), so LeakSanitizer reports
#     a leak for every program that exits and the arm can never be green.
#     detect_leaks is off here, and the leak question is out of scope.
#  3. It budgets the sanitize run `timeout 30` against the base run's 15, so a
#     program near the limit reads as a sanitize finding. Both runs here get
#     the SAME budget (default 15s), and a timeout on either side is its own
#     verdict (`TIMEOUT`), never `UBSAN`.
#
# Also: this box has no clang (checked: `which clang` empty, no
# /usr/lib/llvm-*/bin/clang), so the pass is a gcc one. gcc 13.3 is what the
# C gate compiles with, so the sanitizer sees the same frontend.
#
# WHAT "MEASURED" MEANS HERE — positive controls. A clean sweep from a probe
# that cannot fire is worthless, so before the corpus runs, four programs
# with known UB are compiled and must produce their expected diagnostic:
# signed integer overflow (the WIDTH class, which wraps silently and so is
# invisible to a stdout-only equivalence diff), an out-of-bounds index into
# a fixed buffer (the ARRAY-CAP class), a null load, and a division by zero.
# Each control is rendered by the C backend itself from a minimal shIR, so
# the compile+run path under test is the real one. If any control fails to
# fire, the run aborts with exit 2 — no tally is written.
#
# VERDICT CLASSES (one per file, tab-separated, plus the violation kind)
#   CLEAN        compiled, ran under sanitizers, no diagnostic, same stdout+rc
#   UBSAN|<kind> a UBSan diagnostic (`runtime error: <kind>`); the first one
#                of the run, so kinds are comparable across the corpus
#   ASAN|<kind>  an AddressSanitizer diagnostic
#   SAN-EXIT     exited non-zero under sanitizers where the plain build exited 0
#   SAN-DIFF     sanitizer build's stdout differs from the plain build's
#                (both compared from the SAME sandbox `cwd/` — see below)
#   TIMEOUT      either run hit the budget
#   CC-FAIL / SAN-CC-FAIL / STUB / SKIP / RENDER-FAIL as named
#
# SANDBOX. Each program runs twice; both runs use $d/cwd as the CWD, never the
# directory the runs write their own `out`/`sout` files into. The first probe
# version got this wrong and `046_cd..sh` — whose entire body is `cd ..` —
# listed `sout`/`serr` in its output, manufacturing a SAN-DIFF. It also
# copies the plain binary to the sanitizer binary's name so that `$0`-printing
# programs (057_case.sh prints `Usage: $0 …`) agree.
#
# `--warn` adds the SIGNAL THE SANITIZERS CANNOT SEE. Measured 2026-10-22:
# narrowing in practice is uint8_t/uint16_t only (range_width_name tests u8
# before i8, so any non-negative range yields the UNSIGNED type), and
# unsigned conversion is defined behaviour — UBSan cannot fire, and a
# size-1 global store has no redzone for ASan to check. Control:
# `uint8_t i; i = 300;` prints 44 under address,undefined with no diagnostic.
# So in --warn mode each compile also runs gcc's own analysis and reports
# `TRUNC|<from>-><to>` when a value can change on store. This is the
# store-side half of the P1 obligation (C_UB_PROOF.md §7).
#
# Usage: harness/c_gate_ubsan.sh [--jobs N] [--timeout S] [--no-asan] [--warn]
#                              [--report DIR] [--out TSV] [file.sh ...]
# Env:   JOBS (default 8)  SAN_TIMEOUT (default 15)  CORE_BIN  RENDER_BIN
# Exit:  0 ran; 2 a positive control did not fire (measurement invalid).
# Gate runs go through harness/kill-session.sh per cell (AGENTS.md: no
# unwrapped example run), and every capture is bounded by cap-capture.pl.
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SUB=$ROOT/sh2perl
CORE=${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}
RENDER=${RENDER_BIN:-$SUB/backends/c/target/debug/shir_render}
CC=${UBSAN_CC:-cc}
JOBS=${JOBS:-8}
SAN_TIMEOUT=${SAN_TIMEOUT:-15}
CAP=$((1024*1024))
USE_ASAN=1
REPORT=""
OUTTSV=""
WARN=0
files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) JOBS=$2; shift 2 ;;
    --timeout) SAN_TIMEOUT=$2; shift 2 ;;
    --no-asan) USE_ASAN=0; shift ;;
    --warn) WARN=1; shift ;;
    --report) REPORT=$2; shift 2 ;;
    --out) OUTTSV=$2; shift 2 ;;
    -h|--help) sed -n '2,60p' "$0"; exit 0 ;;
    *) files+=("$1"); shift ;;
  esac
done

SAN="-fsanitize=undefined -fno-sanitize-recover=all -g -O1 -fno-omit-frame-pointer"
[ "$USE_ASAN" = 1 ] && SAN="-fsanitize=undefined,address -fno-sanitize-recover=all -g -O1 -fno-omit-frame-pointer"

T=$(mktemp -d "${TMPDIR:-/tmp}/c_ubsan.XXXXXX")
trap 'rm -rf "$T"' EXIT

# Link set: GMP/m for the bigint and sqrt helpers; the uu-ffi runtime for the
# external-command default (probe once, exactly as c_gate_main.sh does).
CLIBS=""
if printf 'int main(void){return 0;}\n' | "$CC" -x c - -o "$T/pl" -lgmp -lm 2>/dev/null; then CLIBS="-lgmp -lm"; fi
rm -f "$T/pl"
UU_SRC=$SUB/runtime/uu_run.c; UU_LIBDIR=$SUB/runtime/lib; UU_SO=$UU_LIBDIR/libcoreutils_ffi.so
UU_LIBS=""; UU_INC=""
if [ -f "$UU_SRC" ] && [ -f "$UU_SO" ]; then
  # absolute paths throughout: the linker records the rpath as given, and a
  # relative `-Wl,-rpath,sh2perl/runtime/lib` yields a binary that only loads
  # from one CWD (measured: "error while loading shared libraries").
  UU_LIBS="$UU_SRC $UU_SO -lpthread -Wl,-rpath,$UU_LIBDIR"
  UU_INC="-I$SUB/runtime -I$UU_LIBDIR"
else
  export SH2_UU_FFI=0
fi
export SH2_UU_FFI="${SH2_UU_FFI:-1}"

# ── positive controls ───────────────────────────────────────────────────
MIN_SHIR='{"type":"Program","contract_version":1,"stmts":[],"subs":[]}'
control() { # control <name-or-empty> <prologue> <expect-regex>
  local name="$1" pro="$2" want="$3" c="$T/ctl_$1.c" got
  printf '%s' "$MIN_SHIR" | "$RENDER" --target=c - > "$c" 2>/dev/null || { echo "control $name: render failed"; return 1; }
  # inject at the top of main; the rendered shell has exactly one `int main(void) {`
  awk -v inj="$pro" '{ if (!d && index($0,"int main(void) {")) { sub(/int main\(void\) \{/, "int main(void) { " inj); d=1 } print }' "$c" > "$c.2" && mv "$c.2" "$c"
  "$CC" $SAN $UU_INC "$c" $CLIBS $UU_LIBS -o "$T/ctl_$name" 2>/dev/null || { echo "control $name: sanitized compile failed"; return 1; }
  got=$( cd "$T" && env -u BASH_ENV ASAN_OPTIONS=detect_leaks=0:abort_on_error=1 UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
        "$ROOT/harness/kill-session.sh" timeout "$SAN_TIMEOUT" "$T/ctl_$name" 2>&1 >/dev/null | head -c 4096 )
  if printf '%s' "$got" | grep -qE "$want"; then echo "control $name: FIRES"; return 0; fi
  echo "control $name: DID NOT FIRE (want /$want/), got: $(printf '%s' "$got" | head -2 | tr '\n' ' ')"
  return 1
}
ctl_bad=0
control overflow 'volatile int _c1=2000000000; volatile int _c2=2000000000; volatile int _c3=_c1+_c2;' 'runtime error: signed integer overflow' || ctl_bad=1
control oob      'char _qb[4]; volatile int _qi=6; _qb[_qi]=1;' 'runtime error: (index .* out of bounds|store to address)' || ctl_bad=1
control nullderef 'int *_qn=0; volatile int _qv=*_qn;' 'runtime error: load of null pointer' || ctl_bad=1
control divzero  'volatile int _qd=0; volatile int _qz=1/_qd;' 'runtime error: division by zero' || ctl_bad=1
if [ "$ctl_bad" != 0 ]; then
  echo "c_gate_ubsan: positive control(s) did not fire — the sanitizer pass measured nothing; refusing to write a tally" >&2
  exit 2
fi

# ── corpus ───────────────────────────────────────────────────────────────
if [ ${#files[@]} -eq 0 ]; then
  # prefer the AUTHORITATIVE nested frontends copy (submodule); fall back to a
  # legacy sibling only when the nested one is not initialised (c_gate_main.sh
  # convention — globbing both would double-count).
  fe=$(ls $SUB/frontends/*/testdata/*.sh 2>/dev/null)
  [ -z "$fe" ] && fe=$(ls $ROOT/frontends/*/testdata/*.sh 2>/dev/null)
  mapfile -t files < <(printf '%s\n%s\n' "$(ls $SUB/examples/*.sh 2>/dev/null)" "$fe" | grep -v '^$')
fi

run_one() {
  local f="$1" id d shir g s brc src
  id=$(printf '%s' "$f" | md5sum | cut -c1-16)
  d="$T/$id"; mkdir -p "$d/cwd/a"   # TWO levels: 046_cd..sh's body is `cd ..`
  printf '%s\n' "$f" > "$d/file"
  case "$f" in /*) ;; *) f="$PWD/$f" ;; esac
  [ -f "$f" ] || { echo -e "SKIP\tnofile" > "$d/v"; return; }
  shir=$("$CORE" "$f" --source-lang sh --target shir --raw 2>/dev/null) || { echo -e "SKIP\trender-error" > "$d/v"; return; }
  [ -z "$shir" ] && { echo -e "SKIP\tempty-shir" > "$d/v"; return; }
  g=$(printf '%s' "$shir" | "$RENDER" --target=c - 2>"$d/rerr") || { echo -e "RENDER-FAIL\t" > "$d/v"; return; }
  printf '%s' "$g" > "$d/prog.c"
  # stub test on the PROGRAM, never on the renderer's stderr
  s=$(command grep -cE 'TODO\(unsupported\)|sh2_[A-Za-z_]' "$d/prog.c")
  [ "$s" -gt 0 ] && { echo -e "STUB\t$s sh2 callouts" > "$d/v"; return; }
  $CC $UU_INC "$d/prog.c" $CLIBS $UU_LIBS -o "$d/plain" 2>"$d/ccerr" || { echo -e "CC-FAIL\t$(head -1 "$d/ccerr" | cut -c1-120)" > "$d/v"; return; }
  $CC $SAN $UU_INC "$d/prog.c" $CLIBS $UU_LIBS -o "$d/san" 2>"$d/sanccerr" || { echo -e "SAN-CC-FAIL\t$(head -1 "$d/sanccerr" | cut -c1-120)" > "$d/v"; return; }
  # IDENTICAL argv0 for both runs: programs that print $0 (057_case.sh prints
  # `Usage: $0 …`) must agree, and `$0` is the full PATH here, so the same
  # file name in two directories is not enough — both runs use one path,
  # swapped sequentially (the plain run is complete before the copy).
  mkdir -p "$d/run"; cp "$d/plain" "$d/run/argv0"
  ( cd "$d/cwd/a" && env -u BASH_ENV ASAN_OPTIONS=detect_leaks=0 \
      "$ROOT/harness/kill-session.sh" timeout "$SAN_TIMEOUT" "$d/run/argv0" 2>"$d/berr" \
      | perl "$ROOT/harness/cap-capture.pl" "$CAP" plain > "$d/out" ); brc=$?
  cp "$d/san" "$d/run/argv0"
  ( cd "$d/cwd/a" && env -u BASH_ENV ASAN_OPTIONS=detect_leaks=0:abort_on_error=1:allocator_may_return_null=1 \
      UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1 \
      "$ROOT/harness/kill-session.sh" timeout "$SAN_TIMEOUT" "$d/run/argv0" 2>"$d/serr" \
      | perl "$ROOT/harness/cap-capture.pl" "$CAP" san > "$d/sout" ); src=$?
  if [ "$brc" = 124 ] || [ "$src" = 137 ]; then echo -e "TIMEOUT\tsan" > "$d/v"; return; fi
  if [ "$brc" = 124 ]; then echo -e "TIMEOUT\tplain" > "$d/v"; return; fi
  local kind
  kind=$(command grep -m1 -oE 'runtime error: [a-z ]+' "$d/serr" 2>/dev/null | sed 's/runtime error: //')
  if [ -n "${kind:-}" ]; then echo -e "UBSAN\t$kind" > "$d/v"; return; fi
  if command grep -q 'ERROR: AddressSanitizer' "$d/serr" 2>/dev/null; then
    echo -e "ASAN\t$(command grep -m1 -oE 'ERROR: AddressSanitizer: [a-z-]+' "$d/serr" | sed 's/.*: //')" > "$d/v"; return
  fi
  if [ "$src" != 0 ] && [ "$brc" = 0 ]; then echo -e "SAN-EXIT\trc=$src" > "$d/v"; return; fi
  if ! diff -q "$d/out" "$d/sout" >/dev/null 2>&1; then
    echo -e "SAN-DIFF\t$(diff "$d/out" "$d/sout" | head -4 | tr '\n\t' '| ' | cut -c1-160)" > "$d/v"; return
  fi
  if [ "$WARN" = 1 ]; then
    local tw
    tw=$($CC -O1 -Wall -Wextra -Wconversion -Wsign-conversion -c "$d/prog.c" -o /dev/null 2>&1 \
         | command grep -m1 -oE "conversion from .* may change value")
    if [ -n "$tw" ]; then echo -e "TRUNC\t$tw" > "$d/v"; return; fi
  fi
  echo -e "CLEAN\t" > "$d/v"
}
export -f run_one
export T CORE RENDER CC SAN CLIBS UU_INC UU_LIBS CAP SAN_TIMEOUT ROOT WARN

printf '%s\n' "${files[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
for d in "$T"/*/; do [ -f "$d/v" ] && cat "$d/file" | tr '\n' '\t' && cat "$d/v"; done | sort -t$'\t' -k2,2 > "$T/all.tsv"

TSV=${OUTTSV:-$T/all.tsv}
if [ -n "$OUTTSV" ]; then cp "$T/all.tsv" "$OUTTSV"; fi
echo "== verdict classes =="
cut -f2 "$TSV" | sort | uniq -c | sort -rn
echo "== UBSan/ASan kinds =="
awk -F'\t' '$2=="UBSAN"||$2=="ASAN"{print $2"\t"$3}' "$TSV" | sort | uniq -c | sort -rn
if [ -n "$REPORT" ]; then
  mkdir -p "$REPORT"
  cp "$TSV" "$REPORT/c-ubsan-$(date +%Y%m%dT%H%M%S).tsv"
  echo "tally: $REPORT/c-ubsan-$(date +%Y%m%dT%H%M%S).tsv"
fi
