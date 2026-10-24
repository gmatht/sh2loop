#!/usr/bin/env bash
# emit-shir-retry.selftest.sh — regression test for the core-emitter retry
# policy that setup_backends.sh's js|perl emit stage uses.
#
# Pins BOTH halves of the contract; either one alone is a bug:
#   RETRY the path-ABSENT exec failure (a concurrent relink into the shared
#   target dir) and succeed when the emitter reappears — otherwise two files
#   in a relink window are counted FAIL and a whole green corpus is classified
#   `CRASHED (no classification)`;
#   NEVER retry or reinterpret a PRESENT emitter's own rc — a WIP core that
#   rejects an input is a real result and must stay a FAIL.
#
# No cargo, no network, no real workspace: every emitter is a stub whose
# behaviour is written explicitly above the assertion that depends on it.
#
# Usage: harness/emit-shir-retry.selftest.sh [impl]
#   impl defaults to harness/emit-shir-retry.sh. Pass a PRE-FIX
#   implementation (one exec, no retry) to watch the retry cases fail — that
#   is how this test's discriminating power is re-verified:
#       printf '#!/usr/bin/env bash\nset -u\n"$1" --target shir "$2" 2>/dev/null\n' \
#         > /tmp/pre-fix.sh && bash harness/emit-shir-retry.selftest.sh /tmp/pre-fix.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
impl=${1:-$here/emit-shir-retry.sh}
if [ ! -f "$impl" ]; then
  echo "no such implementation: $impl" >&2
  exit 2
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/emit-retry-selftest.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok()  { pass=$((pass+1)); echo "PASS  $1"; }
bad() { fail=$((fail+1)); echo "FAIL  $1"; }

calls="$tmp/calls"
# stub <path> <body...> — an executable emitter that logs each invocation and
# then runs <body> (so both the count and the verdict are observable).
stub() {
  path=$1; shift
  { echo '#!/usr/bin/env bash'; echo "echo x >> '$calls'"; printf '%s\n' "$@"; } > "$path"
  chmod +x "$path"
}
# awk, not wc: `grep` is a ripgrep function in this workspace's shell profile
# and the count must never depend on that.
n_calls() { if [ -f "$calls" ]; then command awk 'END{print NR}' "$calls"; else echo 0; fi; }

f="$tmp/prog.sh"
printf 'echo hi\n' > "$f"

echo "--- present emitter: one exec, rc preserved ---"

# 1. Success: rc 0, stdout is the shIR BYTE-EXACT (the gate pipes it straight
#    into the renderer, so a stray newline is a different program).
: > "$calls"
stub "$tmp/good" "printf '%s' '{\"a\":1}'"
bash "$impl" "$tmp/good" "$f" > "$tmp/o1" 2>/dev/null; rc=$?
printf '%s' '{"a":1}' > "$tmp/e1"
if [ "$rc" -eq 0 ] && cmp -s "$tmp/o1" "$tmp/e1" && [ "$(n_calls)" -eq 1 ]; then
  ok "emit ok -> rc 0, byte-exact, ONE exec"
else
  bad "emit ok (rc=$rc calls=$(n_calls))"
fi

# 2. Multi-line shIR keeps every internal newline and gains no trailing one.
: > "$calls"
stub "$tmp/multi" "printf '%s\\n' '{\"a\":1,' '  \"b\":2}'"
bash "$impl" "$tmp/multi" "$f" > "$tmp/o2" 2>/dev/null; rc=$?
printf '%s' '{"a":1,
  "b":2}' > "$tmp/e2"
if [ "$rc" -eq 0 ] && cmp -s "$tmp/o2" "$tmp/e2"; then
  ok "multi-line shIR -> byte-exact passthrough"
else
  bad "multi-line shIR (rc=$rc)"
fi

# 3. The emitter ran and REJECTED the input (a WIP core, rc=1): rc preserved,
#    no stdout, and exactly ONE exec — retrying this class would turn a real
#    verdict into a sleep.
: > "$calls"
stub "$tmp/reject" 'exit 1'
bash "$impl" "$tmp/reject" "$f" > "$tmp/o3" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -s "$tmp/o3" ] && [ "$(n_calls)" -eq 1 ]; then
  ok "present emitter rc=1 -> rc 1, no stdout, ONE exec (no retry)"
else
  bad "present emitter rc=1 (rc=$rc calls=$(n_calls))"
fi

# 4. A PRESENT emitter that exits 127 (e.g. missing shared library) is still a
#    real result: the retry keys on the PATH being absent, not on the rc.
: > "$calls"
stub "$tmp/present127" 'exit 127'
bash "$impl" "$tmp/present127" "$f" > "$tmp/o4" 2>/dev/null; rc=$?
if [ "$rc" -eq 127 ] && [ "$(n_calls)" -eq 1 ]; then
  ok "present emitter rc=127 -> rc 127, ONE exec (rc is not the retry key)"
else
  bad "present emitter rc=127 (rc=$rc calls=$(n_calls))"
fi

# 5. The emitter is invoked with the gate's exact contract: --target shir <file>.
: > "$calls"
stub "$tmp/args" "if [ \"\$1\" = --target ] && [ \"\$2\" = shir ] && [ \"\$3\" = '$f' ]; then printf '%s' OK; else exit 9; fi"
bash "$impl" "$tmp/args" "$f" > "$tmp/o5" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/o5")" = OK ]; then
  ok "invocation contract: <emitter> --target shir <file>"
else
  bad "invocation contract (rc=$rc)"
fi

echo "--- absent emitter: retried ---"

# 6. The relink window: the path is ABSENT on the first attempt and the
#    relinker puts it back during the helper's sleep. Attempts land at ~0s,
#    ~1s, ~2s and the stub appears at ~0.2s, so there are two sleeps of slack
#    (sleep is a MINIMUM, so a loaded box can only make this safer).
late="$tmp/late"
rm -f "$late"
( sleep 0.2; stub "$late" "printf '%s' LATE" ) &
bash "$impl" "$late" "$f" > "$tmp/o6" 2>/dev/null; rc=$?
wait
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/o6" 2>/dev/null)" = LATE ]; then
  ok "absent then relinked -> rc 0, shIR from the retry"
else
  bad "absent then relinked (rc=$rc out='$(cat "$tmp/o6" 2>/dev/null)')"
fi

# 7. Absent through every attempt: rc 127, no stdout — and it really tried all
#    three (two 1s sleeps). A lower bound only: sleep never returns early.
absent="$tmp/never"
rm -f "$absent"
SECONDS=0
bash "$impl" "$absent" "$f" > "$tmp/o7" 2>/dev/null; rc=$?
elapsed=$SECONDS
if [ "$rc" -eq 127 ] && [ ! -s "$tmp/o7" ] && [ "$elapsed" -ge 2 ]; then
  ok "absent forever -> rc 127, no stdout, 3 attempts (${elapsed}s)"
else
  bad "absent forever (rc=$rc elapsed=${elapsed}s)"
fi

# 8. Usage error is its own verdict, never a silent emit.
bash "$impl" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "no args -> rc 2 (usage)" || bad "no args -> rc 2 (got $rc)"

echo
echo "[emit-shir-retry] $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
