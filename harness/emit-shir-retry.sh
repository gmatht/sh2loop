#!/usr/bin/env bash
# emit-shir-retry.sh <emitter> <corpus-file>
#
# Emit the A1 shIR for <corpus-file> from <emitter>, retrying the ONE failure
# class that is a MEASUREMENT ARTEFACT rather than an input verdict: the
# emitter PATH is absent at exec time (rc=127, `stat` says GONE).
#
# stdout: the shIR, and only when the emit succeeded
# exit:   0    emitted (stdout is the shIR)
#         N    the emitter RAN and failed — its own rc, never retried
#         rc   the path stayed absent through every attempt (127)
#
# WHY (2026-10-25, perl): otranspilerl/target and sh2perl/target are the SAME
# directory (/mnt/wsl/projects/.sh2target/otranspiler), so the estree worker
# relinks otranspilerl-cli into it WHILE a backend gate is looping over the
# corpus. The replacement is not atomic for a reader: the path can be
# momentarily absent. Measured on one perl gate run —
#
#   shir emit FAILED for .../dq-hashbang-multiline-assign.sh
#     (rc=127, binary=.../otranspilerl-cli inode=GONE)
#   shir emit FAILED for .../dqs-nested-awk-sed.sh (same)
#   CRASHED (no classification) — 2/650 files failed
#
# — where both files emit rc=0 on demand and the mirror gate on the same tree
# was 650/650. Two files measured in a relink window discarded a whole corpus.
#
# The retry is deliberately NARROW. A PRESENT emitter that rejects an input
# (a WIP core, rc=1) is a real result: its rc is returned on the FIRST
# attempt and nothing about that verdict changes. harness/
# emit-shir-retry.selftest.sh pins both halves.
set -u
if [ $# -ne 2 ]; then
  echo "usage: emit-shir-retry.sh <emitter> <corpus-file>" >&2
  exit 2
fi
emitter=$1
file=$2

# 3 attempts matches harness/perl_gate_local.sh's shir_of, so the fleet gate
# and its mirror apply one policy.
tries=3
try=1
while : ; do
  # The redirect is on the COMMAND, so a missing emitter is silent too.
  out=$("$emitter" --target shir "$file" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    # printf, not echo: the shIR is JSON and must pass through byte-exact
    # (the gate pipes it straight into the renderer).
    printf '%s' "$out"
    exit 0
  fi
  # PRESENT emitter -> a real result, whatever the rc says (1 = rejects the
  # input, 127 = e.g. a missing shared library). Never retried.
  if [ -x "$emitter" ]; then
    exit "$rc"
  fi
  # ABSENT path -> exec failure. Retry; cargo relinks in place.
  if [ "$try" -ge "$tries" ]; then
    exit "$rc"
  fi
  try=$((try+1))
  sleep 1
done
