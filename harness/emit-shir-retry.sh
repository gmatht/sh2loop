#!/usr/bin/env bash
# emit-shir-retry.sh <emitter> <corpus-file>
#
# Emit the A1 shIR for <corpus-file> from <emitter>, retrying the ONE failure
# class that is a MEASUREMENT ARTEFACT rather than an input verdict: the exec
# itself failed, because a concurrent relink into the shared target dir left
# the path ABSENT (rc=127) or PRESENT-but-busy (rc=126, ETXTBSY — see the
# rc=126 note below).
#
# stdout: the shIR, and only when the emit succeeded
# exit:   0    emitted (stdout is the shIR)
#         N    the emitter RAN and failed — its own rc, never retried
#         rc   the exec kept failing through every attempt (126/127)
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
#
# rc=126 IS THE SAME ARTEFACT CLASS, one window later (2026-10-25, go). The
# path-absent window has a successor: a PRESENT, executable path that the
# kernel still refuses to exec — ETXTBSY, "text file busy", because the
# relinker's binary is open for write. Measured on the go gate:
#
#   [go] backend gate: shir emit FAILED for .../tail-standalone.sh
#     (rc=126, binary=.../otranspilerl-cli inode=3617845)   <- PRESENT
#   [go] backend gate: CRASHED (no classification) — 1/651 files failed
#
# — where that file emits rc=0 on demand (200/200 sequential runs) and the
# gate was `644/651 render OK, 0 fail` on the runs either side. Here `-x` is
# TRUE, so the absent-path branch below never fired and one busy inode threw
# away a whole green corpus. ETXTBSY clears when the writer closes the file,
# so it is retried like the absent case.
#
# Retrying 126 cannot mask a real verdict: the emitter is a Rust program with
# no 126 exit path (no `exit(126` in otranspilerl/ or sh2perl/), and a 126
# that SURVIVES every attempt is still returned as the verdict below. rc=127
# from a present emitter stays untouched (pinned by selftest case 4) — that
# one is the shell's not-found code AND a program's own code, so it is not
# decidable here; 126 from a present, executable file is.
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
  # input, 127 = e.g. a missing shared library). Never retried. Exception:
  # rc=126 on a PRESENT, executable path is the relinker's ETXTBSY window
  # (see the header), which is an exec failure, not a result.
  if [ -x "$emitter" ] && [ "$rc" -ne 126 ]; then
    exit "$rc"
  fi
  # ABSENT path, or PRESENT-but-busy: an exec failure either way. Retry;
  # cargo relinks in place.
  if [ "$try" -ge "$tries" ]; then
    exit "$rc"
  fi
  try=$((try+1))
  sleep 1
done
