#!/bin/bash
# ─── frontend-js-gate.sh ────────────────────────────────────────────
# How well each SOURCE frontend translates to the DEFAULT JS output:
#
#   frontend(testdata file) ──► A1 shIR ──► estree (js render) ──► run ──►
#       stdout diff vs the NATIVE run (go run / python3 / fish / zsh /
#       perl / gcc / bash)
#
# The pass/total per source language feeds the otranspiler GUI's
# FRONTEND_STATUS table (the lang-pill colours in www/otranspiler.html),
# mirroring how setup_backends.sh --backend-gate feeds BACKEND_STATUS.
# Per-file verdicts are ALSO cached to .frontend_gate.tsv in the workspace
# root (lang\tfile\tPASS|FAIL|SKIP\t[reason], one row per testdata file) —
# the otranspiler GUI's sync-backend-gates.sh consumes it to colour the
# per-frontend example buttons (green = passes, red = fails, grey = skip).
#
# Semantics (mirroring the backend gate's skip rules):
#   • a frontend PARSE failure is a frontend gap → FAIL;
#   • a render (A1 → estree) failure is a frontend gap → FAIL;
#   • a reference (native run) failure is NOT the frontend's fault
#     (un-runnable testdata) → SKIP.
#
# Usage: ./frontend-js-gate.sh [lang…]   (default: all seven)
# -----------------------------------------------------------------

set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
OTRANSPILERL="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
RUNNER="$ROOT/harness/estree-runner.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TIMEOUT=20

# per-file verdict cache (lang<TAB>file<TAB>PASS|FAIL|SKIP<TAB>[reason])
TSV="$ROOT/.frontend_gate.tsv"
# A full run (no args) rewrites the cache from scratch; a partial run
# (lang args) appends so it can extend a cached full run without
# discarding the already-gated languages.
LANGS=("$@")
if [ "${#LANGS[@]}" -eq 0 ]; then
  LANGS=(sh go py fish zsh pl c cpp rust zig powershell)
  : > "$TSV"
fi

# source lang → (testdata dir, native ext, frontend binary | '' = core's sh parser)
declare -A TD=(  [sh]=posix-sh-go  [go]=go-sh  [py]=py-sh-go  [fish]=fish-sh-go  [zsh]=zsh-sh-go  [pl]=perl-sh-go  [c]=c-sh-go  [cpp]=cpp-sh-go  [rust]=rust-frontend  [zig]=zig-sh-go  [powershell]=powershell-sh-go )
declare -A EXT=( [sh]=sh  [go]=go  [py]=py  [fish]=fish  [zsh]=zsh  [pl]=pl  [c]=c  [cpp]=cc  [rust]=rs  [zig]=zig  [powershell]=ps1 )
declare -A BIN=( [go]=go-sh  [py]=py-sh-go  [fish]=fish-sh-go  [zsh]=zsh-sh-go  [pl]=perl-sh-go  [c]=c-sh-go  [cpp]=cpp-sh-go  [rust]=target/debug/rust-frontend  [zig]=zig-sh-go  [powershell]=powershell-sh-go )

# Native reference stdout (nonzero exit = un-runnable → skip).
# cpp/rust/powershell/zig gate exactly like harness/frontend-stdout.sh
# (the fleet's frontend-stdout gate): cpp/rust compile+run, zig merges
# stderr (zig's std.debug.print writes there), powershell prefers the
# direct snap binary (snap-confine fails in containerized workers).
ref_stdout() {
  local ext="$1" file="$2"
  case "$ext" in
    sh)   timeout $TIMEOUT bash "$file" 2>/dev/null ;;
    go)   timeout $TIMEOUT go run "$file" 2>/dev/null ;;
    py)   timeout $TIMEOUT python3 "$file" 2>/dev/null ;;
    fish) timeout $TIMEOUT fish "$file" 2>/dev/null ;;
    zsh)  timeout $TIMEOUT zsh "$file" 2>/dev/null ;;
    pl)   timeout $TIMEOUT perl "$file" 2>/dev/null ;;
    c)    timeout $TIMEOUT gcc "$file" -o "$TMP/refbin" 2>/dev/null && timeout $TIMEOUT "$TMP/refbin" 2>/dev/null ;;
    cpp)  timeout $TIMEOUT g++ "$file" -o "$TMP/refbin" 2>/dev/null && timeout $TIMEOUT "$TMP/refbin" 2>/dev/null ;;
    rs)   timeout $TIMEOUT rustc "$file" -o "$TMP/refbin" 2>/dev/null && timeout $TIMEOUT "$TMP/refbin" 2>/dev/null ;;
    zig)  timeout $TIMEOUT "${ZIGBIN:-zig}" run "$file" 2>&1 ;;
    ps1)  timeout $TIMEOUT "${PWSHBIN:-pwsh}" -NoProfile -File "$file" 2>/dev/null ;;
  esac
}

normalize() { printf '%s' "$1" | sed 's/\r$//' | sed '/^[[:space:]]*$/d'; }

# zig/pwsh: prefer the direct snap binary over the /snap/bin wrapper
# (snap-confine re-exec fails in containerized workers — the same
# rationale as harness/frontend-stdout.sh's go/zig/pwsh branches).
if [ -x /snap/zig/current/zig ]; then ZIGBIN=/snap/zig/current/zig; elif [ -x /snap/zig/current/bin/zig ]; then ZIGBIN=/snap/zig/current/bin/zig; fi
if [ -x /snap/powershell/current/opt/powershell/pwsh ]; then PWSHBIN=/snap/powershell/current/opt/powershell/pwsh; fi

# per-frontend testdata dir (cpp keeps it in testdata_cpp/, the rest in testdata/)
declare -A TDD=( [cpp]=testdata_cpp )

for lang in "${LANGS[@]}"; do
  pass=0; skip=0; fail=0; fails=""
  td="${TDD[$lang]:-testdata}"
  for f in "$ROOT/frontends/${TD[$lang]}/$td/"*."${EXT[$lang]}"; do
    [ -f "$f" ] || continue
    bn=$(basename "$f")
    # refusal pins (*_refuse.*) are the frontend's negative tests — the
    # emit MUST fail, asserted by the frontend's own gate; never a FAIL
    # here (mirrors harness/frontend-stdout.sh's skip).
    case "$bn" in *_refuse*) printf '%s\t%s\tSKIP\trefusal pin\n' "$lang" "$bn" >> "$TSV"; skip=$((skip+1)); continue ;; esac
    # 1. frontend → A1 (the core's sh parser for sh; the frontend wasm/binary otherwise)
    if [ "$lang" = sh ]; then
      a1=$("$OTRANSPILERL" --target shir "$f" 2>/dev/null)
    else
      a1=$("$ROOT/frontends/${BIN[$lang]}/${BIN[$lang]}" --shir "$f" 2>/dev/null)
    fi
    if [ -z "$a1" ]; then fail=$((fail+1)); fails="$fails $bn(parse)"; printf '%s\t%s\tFAIL\tparse\n' "$lang" "$bn" >> "$TSV"; continue; fi
    # 2. A1 → estree (default js render)
    printf '%s' "$a1" > "$TMP/a1.json"
    if ! "$OTRANSPILERL" --source-lang shir --target estree "$TMP/a1.json" > "$TMP/estree.json" 2>/dev/null; then
      fail=$((fail+1)); fails="$fails $bn(render)"; printf '%s\t%s\tFAIL\trender\n' "$lang" "$bn" >> "$TSV"; continue
    fi
    # 3. run the generated js
    js_out=$(timeout $TIMEOUT node "$RUNNER" "$TMP/estree.json" --source "$f" 2>/dev/null)
    # 4. reference: the native run
    ref=$(ref_stdout "${EXT[$lang]}" "$f")
    if [ $? -ne 0 ]; then skip=$((skip+1)); printf '%s\t%s\tSKIP\tnative run failed\n' "$lang" "$bn" >> "$TSV"; continue; fi
    if [ "$(normalize "$js_out")" = "$(normalize "$ref")" ]; then
      pass=$((pass+1)); printf '%s\t%s\tPASS\n' "$lang" "$bn" >> "$TSV"
    else
      fail=$((fail+1)); fails="$fails $bn"; printf '%s\t%s\tFAIL\tstdout mismatch\n' "$lang" "$bn" >> "$TSV"
    fi
  done
  total=$((pass+skip+fail))
  echo "$lang: $pass/$total pass ($(( pass*100/total ))%)  [skip $skip]${fails:+  fails:$fails}"
done
