#!/usr/bin/env bash
# test_core_verify_concurrent.sh — regression test for
# harness/core_verify.sh's temporary-crate collision (2026-09-27).
#
# THE BUG. core_verify.sh writes a throwaway wrapper crate and deletes it with
# `trap cleanup EXIT; cleanup() { rm -rf "$CRATE"; }`. The crate path used to be
# a single FIXED path ($ROOT/.core-verify), so two concurrent runs shared it:
# whichever finished first deleted the directory the other was still building
# in. The loser failed immediately with an empty stdout and no cargo output.
#
# How it reached the fleet, and why it was so hard to see:
#   - the core worker reported "isolated core build FAILED — skipping iteration"
#     with NOT ONE line of cargo output, so the build never even appeared to run;
#   - `core_binary()` returns `bash core_verify.sh | tail -1`, so a run producing
#     no stdout yields an empty DEBASHC and the worker bails before A1;
#   - run by hand it ALWAYS succeeded (nothing else was building at that moment),
#     so it looked intermittent and unfixable. The trigger in the fleet is
#     anything else invoking core_verify.sh at the same moment.
#
# Reproduced deterministically: two runs at once gave A rc=0 / B rc=1 on every
# round, 3/3.
#
# THE FIX. The crate is per-process ($ROOT/.core-verify.$$), so the exit trap
# can only ever remove its own directory. The TARGET dir stays shared — that is
# deliberate (it dedupes the dependency build) and safe, because cargo's own
# target-dir lock serialises the compiles.
#
# WHAT IS ASSERTED, observably:
#   - two concurrent runs BOTH succeed (the regression);
#   - neither leaves a crate directory behind;
#   - a single run still produces an executable binary;
#   - a forced rebuild still works.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CV="$ROOT/harness/core_verify.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }

[ -f "$CV" ] || { echo "FATAL: $CV not found" >&2; exit 1; }
[ -d "$ROOT/sh2perl/backends/core/src" ] || { echo "FATAL: core worktree not present" >&2; exit 1; }

# ── case 1: two concurrent runs BOTH succeed ──
# The regression. Before the fix this was A:0 / B:1 on every round.
#
# CRITICAL: the cached binary must be REMOVED first. core_verify.sh skips the
# build entirely when its binary is newer than the sources, so a test that
# leaves the binary in place never exercises the crate at all — which is why
# the first version of this test passed against the buggy shared-crate script.
# Force a real build on every round.
pass=0; fail=0
for round in 1 2 3; do
  rm -f "$ROOT/.core-verify-target/debug/otranspilerl-cli"
  a_out=$(mktemp); b_out=$(mktemp)
  ( bash "$CV" >"$a_out" 2>&1; echo $? >"$a_out.rc" ) &
  ( sleep 0.3; bash "$CV" >"$b_out" 2>&1; echo $? >"$b_out.rc" ) &
  wait
  for f in "$a_out" "$b_out"; do
    if [ "$(cat "$f.rc" 2>/dev/null)" = "0" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
  done
  rm -f "$a_out" "$a_out.rc" "$b_out" "$b_out.rc"
done
if [ "$fail" -eq 0 ]; then
  ok "all 6 concurrent FORCED builds succeeded ($pass/6)"
else
  bad "$fail of 6 concurrent forced builds FAILED — the shared-crate collision is back"
fi

# ── case 2: no crate directory is left behind ──
# A per-process crate is removed by its own EXIT trap; a leftover means the
# path is still shared or the trap did not fire.
leftover=$(ls -d "$ROOT"/.core-verify[0-9]* 2>/dev/null | grep -v target || true)
if [ -z "$leftover" ]; then
  ok "no per-process crate directory left behind"
else
  bad "leftover crate dir(s): $(printf '%s' "$leftover" | tr '\n' ' ')"
fi

# ── case 3: a single run still yields an executable binary ──
out=$(bash "$CV" 2>/dev/null | tail -1)
if [ -n "$out" ] && [ -x "$out" ]; then
  ok "a single run returns an executable binary"
else
  bad "single run did not return an executable (got '$out')"
fi

# ── case 4: the skip-if-fresh path still works (fast, no rebuild) ──
t0=$(date +%s)
out2=$(bash "$CV" 2>/dev/null | tail -1)
t1=$(date +%s)
if [ -n "$out2" ] && [ -x "$out2" ] && [ "$out2" = "$out" ]; then
  ok "the cached-binary path still returns the same binary ($((t1-t0))s)"
else
  bad "the cached path changed the answer: '$out' then '$out2'"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
