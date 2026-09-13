#!/usr/bin/env bash
# gpu_gate.sh — bash-O4 differential gate (docs/BASH-O4.md §4.8).
#
# For every corpus program, three runs must agree on stdout AND exit code:
#   1. real `bash` (the reference oracle),
#   2. `bash-O4 --cpu-only` (tcc JIT, CPU lowering),
#   3. `bash-O4 --gpu=auto` (GPU policy; dispatch not yet wired, so this
#      compiles CPU-only today — the gate pins flag-path equivalence and
#      catches any future divergence the moment dispatch lands).
# Any divergence = product bug (fix bash-O4, never bless).
#
# Usage: harness/gpu_gate.sh [file.sh ...] [jobs N]
#   BO4_BIN=path   bash-O4 binary (default: bash-o4/target/debug/bash-O4)
set -u
ROOT=/home/llm/sh2loop
BO4=${BO4_BIN:-$ROOT/bash-o4/target/debug/bash-O4}
export BASH_O4_SH2PERL="${BASH_O4_SH2PERL:-$ROOT/sh2perl}"
JOBS=${JOBS:-8}
if [ "${1:-}" = "jobs" ]; then JOBS=$2; shift 2; fi
if [ $# -gt 0 ]; then corpus=$(printf '%s\n' "$@"); else corpus=$(ls $ROOT/sh2perl/examples/*.sh 2>/dev/null); fi
if [ ! -x "$BO4" ]; then
  echo "gpu_gate: missing $BO4 (build bash-o4 first)" >&2
  exit 2
fi

_gate_tmp=$(mktemp -d)
trap 'rm -rf "$_gate_tmp"' EXIT
run_one() {
  f="$1"; id=$(echo "$f" | md5sum | cut -d' ' -f1)
  d="$_gate_tmp/$id"; mkdir -p "$d/w"
  case "$f" in /*) ;; *) f="$PWD/$f" ;; esac
  bash -n "$f" 2>/dev/null || { echo "SKIP $f" > "$d/v"; return; }
  (cd "$d/w" && timeout 60 bash "$f" > "$d/.ref" 2>/dev/null); ref_rc=$?
  # argv0: the DRIVER performs the c_gate_main.sh `exec -a` convention
  # itself (JIT temp exe runs with argv[0] = script path), so plain
  # invocation here still exercises `$0`/dirname conformance end to end.
  # (Lowercase $tmp must never be exported: test envs leak into the
  # scripts under test; see BASHC_FIX §2.1.)
  (cd "$d/w" && timeout 60 "$BO4" --cpu-only "$f" > "$d/.cpu" 2>/dev/null); cpu_rc=$?
  (cd "$d/w" && timeout 60 "$BO4" --gpu=auto "$f" > "$d/.gpu" 2>/dev/null); gpu_rc=$?
  # DETERMINISM (mirrors c_gate_main.sh): tty-cmdsub prints the first
  # readable /dev/pts/N, whose number varies with system-wide pty churn
  # between runs. Normalize device numbers before diffing.
  sed -i -E 's|/dev/pts/[0-9]+|/dev/pts/N|g' "$d/.cpu" "$d/.gpu" "$d/.ref" 2>/dev/null || true
  if [ "$ref_rc" != 124 ] && [ "$cpu_rc" != 124 ] && [ "$gpu_rc" != 124 ] \
     && [ "$ref_rc" = "$cpu_rc" ] && [ "$cpu_rc" = "$gpu_rc" ] \
     && diff -q "$d/.ref" "$d/.cpu" >/dev/null 2>&1 \
     && diff -q "$d/.cpu" "$d/.gpu" >/dev/null 2>&1; then
    echo "PASS $f" > "$d/v"
  else
    echo "FAIL $f (bash=$ref_rc cpu=$cpu_rc gpu=$gpu_rc)" > "$d/v"
  fi
}
export -f run_one; export _gate_tmp BO4 BASH_O4_SH2PERL
printf '%s\n' "$corpus" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}
pass=0; fail=0; skip=0
for v in "$_gate_tmp"/*/v; do
  case "$(cut -d' ' -f1 < "$v")" in
    PASS) pass=$((pass+1));;
    SKIP) skip=$((skip+1));;
    *) fail=$((fail+1)); grep -h "^FAIL" "$v";;
  esac
done
echo "PASS=$pass FAIL=$fail SKIP=$skip"
[ "$fail" -eq 0 ]
