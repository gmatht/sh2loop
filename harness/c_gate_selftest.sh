#!/bin/bash
# c_gate_selftest.sh — prove that harness/c_gate_main.sh can PASS and can FAIL.
#
# Why this exists: the gate's worker (`run_one`) is not a subshell of the
# gate. It is a `bash -c` child spawned by xargs, so it only sees the
# EXPORTED environment. `ROOT` was never exported, so the worker ran
# `/harness/kill-session.sh` (which does not exist) instead of
# `$ROOT/harness/kill-session.sh`; BOTH sides died with 127, both captures
# were empty, `diff` compared two empty files, and every cell passed.
#
# Measured 2026-10-23, pre-fix: a script whose bash and C output can never
# agree (each side prints its own pid) reported `PASS=1 FAIL=0 SKIP=0`.
# Post-fix the same run reports `PASS=0 FAIL=1` and exits 1.
#
# The bad probe is `echo "pid=$$"`: the reference runs in one process and the
# compiled binary in another, so the values differ by construction — no
# renderer change can ever make that cell pass, which is exactly what pins
# the HARNESS rather than measuring the transpiler. The verdict must be
# `exec/diff` (the comparison actually ran), not `render`/`cc`.
#
# The good probe (`echo hi`) pins the other direction: a trivially correct
# cell must PASS and must exit 0. Without it, "always FAIL" would also look
# like a fixed gate.
#
# Usage: harness/c_gate_selftest.sh        (exit 0 = the gate discriminates)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/harness/c_gate_main.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

printf '#!/bin/bash\necho "pid=$$"\n'  > "$tmp/impossible.sh"
printf '#!/bin/bash\necho hi\n'        > "$tmp/trivial.sh"

bad_out=$(bash "$GATE" "$tmp/impossible.sh" 2>&1); bad_rc=$?
good_out=$(bash "$GATE" "$tmp/trivial.sh" 2>&1); good_rc=$?

echo "--- impossible.sh (want FAIL exec/diff, rc=1) ---"
printf '%s\n' "$bad_out"
echo "--- trivial.sh (want PASS, rc=0) ---"
printf '%s\n' "$good_out"

rc=0
if printf '%s\n' "$bad_out" | command grep -q 'PASS=1'; then
    echo "selftest FAILED: the gate passed a cell whose outputs cannot match." >&2
    echo "  The xargs worker is probably missing an exported variable again" >&2
    echo "  (see the 'export -f run_one' line in harness/c_gate_main.sh)." >&2
    rc=1
elif ! printf '%s\n' "$bad_out" | command grep -q 'PASS=0 FAIL=1' \
   || ! printf '%s\n' "$bad_out" | command grep -q 'exec/diff'; then
    echo "selftest INCONCLUSIVE: impossible.sh did not report FAIL exec/diff" >&2
    rc=2
elif [ "$bad_rc" != 1 ]; then
    echo "selftest FAILED: impossible.sh reported FAIL but exited $bad_rc (want 1)" >&2
    rc=1
fi

if ! printf '%s\n' "$good_out" | command grep -q 'PASS=1 FAIL=0'; then
    echo "selftest FAILED: trivial.sh did not PASS — the gate rejects everything" >&2
    rc=1
elif [ "$good_rc" != 0 ]; then
    echo "selftest FAILED: trivial.sh passed but exited $good_rc (want 0)" >&2
    rc=1
fi

[ "$rc" = 0 ] && echo "selftest OK: the gate passes a matching cell and fails a mismatched one"
exit "$rc"
