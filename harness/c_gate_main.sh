#!/bin/bash
# c_gate_main.sh — c_gate_repro.sh logic, rendering through MAIN's renderer
# (the superior worktree renderer was merged into main in 952a2cab).
# Usage: harness/c_gate_main.sh [file.sh ...] [jobs N]
set -u
ROOT=/home/llm/sh2loop
SUB=$ROOT/sh2perl
CORE=${CORE_BIN:-$SUB/target/debug/debashc}
CC=cc
JOBS=${JOBS:-8}
if [ "${1:-}" = "jobs" ]; then JOBS=$2; shift 2; fi
if [ $# -gt 0 ]; then corpus=$(printf '%s\n' "$@"); else corpus=$(ls $SUB/examples/*.sh $ROOT/frontends/*/testdata/*.sh 2>/dev/null); fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
run_one() {
  f="$1"; id=$(echo "$f" | md5sum | cut -d' ' -f1)
  d="$tmp/$id"; mkdir -p "$d"
  shir=$("$CORE" --shir "$f" --raw 2>/dev/null) || { echo "SKIP $f" > "$d/v"; return; }
  [ -z "$shir" ] && { echo "SKIP $f" > "$d/v"; return; }
  bash -n "$f" 2>/dev/null || { echo "SKIP $f" > "$d/v"; return; }
  g_out=$(printf '%s' "$shir" | "$CORE" --shir-in-c - 2>"$d/rerr") || { echo "FAIL $f render" > "$d/v"; return; }
  s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2[A-Za-z_]" || true)
  if [ "$s" -gt 0 ]; then echo "FAIL $f stub:$s" > "$d/v"; cp <<<"$g_out" /dev/null 2>/dev/null; printf '%s' "$g_out" > "$d/prog.c"; return; fi
  printf '%s' "$g_out" > "$d/prog.c"
  eq_exit=1
  cc "$d/prog.c" -o "$d/bin" 2>"$d/ccerr" && timeout 15 "$d/bin" > "$d/out" 2>/dev/null && eq_exit=0
  bash_rc=0
  timeout 15 bash "$f" > "$d/ref" 2>/dev/null || bash_rc=$?
  if [ "$eq_exit" != 124 ] && [ "$bash_rc" != 124 ] && [ "$eq_exit" = 0 ] && [ "$bash_rc" = 0 ] \
     && diff -q "$d/out" "$d/ref" >/dev/null 2>&1; then
    echo "PASS $f" > "$d/v"
  else
    echo "FAIL $f exec/diff" > "$d/v"
  fi
}
export -f run_one; export tmp CORE CC
printf '%s\n' "$corpus" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
cat "$tmp"/*/v | sort > "$tmp/all"
pass=$(grep -c '^PASS' "$tmp/all"); skip=$(grep -c '^SKIP' "$tmp/all"); fail=$(grep -c '^FAIL' "$tmp/all")
echo "PASS=$pass FAIL=$fail SKIP=$skip"
grep '^FAIL' "$tmp/all"
