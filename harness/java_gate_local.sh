#!/bin/bash
# harness/java_gate_local.sh — LOCAL java backend gate, mirroring the exact
# verdict rules of `setup_backends.sh --backend-gate java` (render via the
# worktree shir_render --target=java, STUB GATE on sh2*(/TODO(unsupported),
# then javac + run and diff stdout against `bash "$f"`, both rc 0).
#
# Why a copy: the real gate builds the core AND holds .gate.lock for the
# whole 654-file pass (~1-2h), so it cannot be used to iterate on a renderer.
# This runs against an ALREADY BUILT renderer and binary, in parallel, and
# prints one line per failing file so the work list is directly visible.
#
#   java_gate_local.sh                 # whole corpus, PARALLEL=8
#   java_gate_local.sh <prefix>...     # subset by filename prefix
#   java_gate_local.sh -l <file>       # one file, verbose (render+java+diff)
#
# Env: RENDERER=<shir_render>, OTRAN=<otranspilerl-cli>, PARALLEL=N,
#      VERBOSE=1 (show first diff lines for every failure)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$ROOT/sh2perl"
WT="$SUB/backends/java"
RENDERER="${RENDERER:-$WT/target/debug/shir_render}"
OTRAN="${OTRAN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
PARALLEL="${PARALLEL:-8}"
KS="$ROOT/harness/kill-session.sh"

verbose() { echo "  $*" >&2; }

# one file -> prints "PASS <f>" | "FAIL <f>|<class>|<detail>"
one() {
  local f="$1" shir out s d
  local tag="$$.$RANDOM$RANDOM"
  if ! shir=$("$OTRAN" --target shir "$f" 2>/dev/null); then echo "FAIL $f|emit|rc"; return; fi
  if [ -z "$shir" ]; then echo "FAIL $f|emit|empty"; return; fi
  if ! env -u BASH_ENV bash -n "$f" 2>/dev/null; then echo "SKIP $f|parse|"; return; fi
  if ! out=$(printf '%s' "$shir" | "$RENDERER" --target=java - 2>/dev/null); then
    echo "FAIL $f|render|$out"; return
  fi
  s=$(printf '%s' "$out" | command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  if [ "${s:-0}" -gt 0 ]; then
    # first stub line, for classification
    d=$(printf '%s' "$out" | command grep -oE 'sh2[A-Za-z_0-9]+\(|TODO\(unsupported\)' | sort | uniq -c | sort -rn | head -3 | tr '\n' ' ')
    echo "FAIL $f|stub($s)|$d"; return
  fi
  # the gate's java arm: javac needs the public class in Sh2Program.java.
  # Per-worker scratch so parallel runs never collide (the real gate is serial).
  local wd="/tmp/jg.$tag"; mkdir -p "$wd"
  printf '%s' "$out" > "$wd/Sh2Program.java"
  local eq_exit=1 bash_rc=0
  if javac -d "$wd" "$wd/Sh2Program.java" >"$wd/javac.err" 2>&1; then
    ( cd "$wd" && "$KS" timeout 15 java -cp "$wd" Sh2Program > "$wd/out" 2>/dev/null ); eq_exit=$?
  else
    d=$(command grep -E 'error:' "$wd/javac.err" | head -2 | tr '\n' ' ')
    echo "FAIL $f|javac|$d"; rm -rf "$wd"; return
  fi
  # BASH_ENV: this agent's shell exports pir's grep/find WRAPPER FUNCTIONS
  # via BASH_ENV; they exist only in bash, so the reference side would
  # diverge from the real gate (which runs under a clean env) for reasons
  # that have nothing to do with the renderer. Drop it on the reference side.
  ( cd "$wd" && env -u BASH_ENV "$KS" timeout 15 bash "$f" > "$wd/ref" 2>/dev/null ); bash_rc=$?
  if [ "$eq_exit" = 124 ] || [ "$bash_rc" = 124 ]; then
    echo "FAIL $f|timeout|java=$eq_exit bash=$bash_rc"; rm -rf "$wd"; return
  fi
  if [ "$eq_exit" = 0 ] && [ "$bash_rc" = 0 ] && diff -q "$wd/out" "$wd/ref" >/dev/null 2>&1; then
    echo "PASS $f"; rm -rf "$wd"; return
  fi
  # java prints its argv0 basename ("Sh2Program") where bash prints $f —
  # a known convention gap; classify it separately so it is not confused
  # with a real lowering bug.
  local dd
  dd=$(diff "$wd/out" "$wd/ref" 2>/dev/null | head -6 | tr '\n' '~')
  echo "FAIL $f|equiv(rc java=$eq_exit bash=$bash_rc)|$dd"
  rm -rf "$wd"
}
export -f one verbose
export ROOT SUB WT RENDERER OTRAN KS

files=()
mode=all
if [ "${1:-}" = "-l" ]; then mode=one; files=("$2"); else
  for f in "$SUB"/examples/*.sh "$SUB"/frontends/*/testdata/*.sh; do
    [ -f "$f" ] || continue
    if [ "$#" -eq 0 ]; then files+=("$f"); else
      b=$(basename "$f")
      for p in "$@"; do case "$b" in "$p"*) files+=("$f"); break;; esac; done
    fi
  done
fi

if [ "$mode" = one ]; then
  f="${files[0]}"
  shir=$("$OTRAN" --target shir "$f") || { echo "emit failed"; exit 1; }
  printf '%s' "$shir" | "$RENDERER" --target=java - > /tmp/java_l.$$.java 2>/tmp/java_l.$$.err
  echo "render rc=$? -> /tmp/java_l.$$.java ($(wc -l < /tmp/java_l.$$.java) lines)"
  command grep -nE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' /tmp/java_l.$$.java | head -10
  wd=/tmp/jgl.$$; mkdir -p "$wd"; cp /tmp/java_l.$$.java "$wd/Sh2Program.java"
  javac -d "$wd" "$wd/Sh2Program.java" 2>&1 | head -15
  ( cd "$wd" && timeout 15 java -cp "$wd" Sh2Program > out 2>err ); echo "java rc=$?"
  ( cd "$wd" && env -u BASH_ENV timeout 15 bash "$f" > ref 2>/dev/null ); echo "bash rc=$?"
  diff "$wd/out" "$wd/ref" | head -20
  rm -rf "$wd"
  exit 0
fi

printf '%s\n' "${files[@]}" | xargs -P "$PARALLEL" -I{} bash -c 'one "$@"' _ {} > /tmp/java_gate.$$.log
total=$(wc -l < /tmp/java_gate.$$.log)
pass=$(command grep -c '^PASS' /tmp/java_gate.$$.log || true)
skip=$(command grep -c '^SKIP' /tmp/java_gate.$$.log || true)
fail=$(command grep -c '^FAIL' /tmp/java_gate.$$.log || true)
echo "== java local gate: $pass pass / $fail fail / $skip skip (of $total)"
echo "-- fail classes:"
command grep '^FAIL' /tmp/java_gate.$$.log | cut -d'|' -f2 | sed 's/(.*//' | sort | uniq -c | sort -rn
if [ -n "${VERBOSE:-}" ]; then
  echo "-- failures:"
  command grep '^FAIL' /tmp/java_gate.$$.log | sed "s|$SUB/||"
fi
echo "(log: /tmp/java_gate.$$.log)"
