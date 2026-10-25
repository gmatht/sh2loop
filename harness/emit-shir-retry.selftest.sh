#!/usr/bin/env bash
# emit-shir-retry.selftest.sh — regression test for the core-emitter retry
# policy that setup_backends.sh's js|perl emit stage uses, AND (from
# --mode=render) for the gate's render exec, which has the same relink window
# one step later: the renderer lives in the same relinked target dir, and its
# unclassified failure was the one path that printed NO per-file line, so a
# 644/651-green corpus read as `CRASHED (no classification)`. Cases R1-R6 pin
# the render arm; cases 1-11 pin emit.
#
# Pins BOTH halves of the contract; either one alone is a bug:
#   RETRY the exec-failure class (a concurrent relink into the shared target
#   dir) and succeed when the emitter becomes runnable — otherwise two files
#   in a relink window are counted FAIL and a whole green corpus is classified
#   `CRASHED (no classification)`. That class is the path ABSENT (rc=127) and
#   the path PRESENT-but-busy (rc=126, ETXTBSY: the relinker's binary is open
#   for write, so the kernel refuses the exec);
#   NEVER retry or reinterpret a PRESENT emitter's own rc — a WIP core that
#   rejects an input is a real result and must stay a FAIL. (127 from a
#   present emitter is such a case; 126 from a present, executable one is not
#   — the emitter has no 126 exit path. Cases 4 and 4b pin both sides.)
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

# 4b. A PRESENT, executable emitter that exits 126 is the relinker's ETXTBSY
#     window (2026-10-25, go gate: one file of 651 came back rc=126 with
#     inode=3617845 — PRESENT — and collapsed a 644/651-green corpus to
#     `CRASHED (no classification)`). The emitter has no 126 exit path, so
#     this is an exec failure: retried. It still returns 126 if every attempt
#     fails, so a genuinely broken emitter keeps its verdict.
#
#     FOUR execs, not three: after the third attempt the helper makes a
#     private copy and RUNS it (`- --target estree <minimal A1>`) before
#     trusting it. A copy that cannot run is never used, which is exactly why
#     this emitter's 126 survives unchanged.
: > "$calls"
stub "$tmp/present126" 'exit 126'
bash "$impl" "$tmp/present126" "$f" > "$tmp/o4b" 2>/dev/null; rc=$?
if [ "$rc" -eq 126 ] && [ ! -s "$tmp/o4b" ] && [ "$(n_calls)" -eq 4 ]; then
  ok "present emitter rc=126 -> retried (3 execs) + rejected copy, rc 126 verdict kept"
else
  bad "present emitter rc=126 (rc=$rc calls=$(n_calls))"
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

# 6b. The PRESENT-but-busy window CLEARS: the first exec is refused with
#     ETXTBSY and the next one runs. The corpus file is measured, not lost —
#     which is the whole point (a lost measurement is not a failing file).
: > "$calls"
rm -f "$tmp/busy.seen"
stub "$tmp/busy" "if [ ! -f '$tmp/busy.seen' ]; then : > '$tmp/busy.seen'; exit 126; fi; printf '%s' BUSY"
bash "$impl" "$tmp/busy" "$f" > "$tmp/o6b" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/o6b" 2>/dev/null)" = BUSY ] && [ "$(n_calls)" -eq 2 ]; then
  ok "busy then runnable -> rc 0, shIR from the retry (2 execs)"
else
  bad "busy then runnable (rc=$rc out='$(cat "$tmp/o6b" 2>/dev/null)' calls=$(n_calls))"
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

echo "--- window longer than the retries: the verified copy measures it ---"

# 9. THE WINDOW THAT BEAT THE SLEEPS (2026-10-25). An in-place copy of the
#    124MB debug binary keeps the path busy for as long as the write lasts —
#    measured: an 8s write window left the 3-attempt/1s retry at `rc=126, 0
#    bytes`, i.e. one counted FAIL and a `CRASHED (no classification)`
#    verdict for a corpus that was otherwise green. The stub below reproduces
#    that: the LIVE path is unusable on every attempt and a COPY (its path
#    contains `snap-`) is fine, which is what a private copy of a busy inode
#    actually is. The file must be MEASURED, not lost.
: > "$calls"
stub "$tmp/busy.snapcopy" 'case "$0" in */snap-*) ;; *) exit 126;; esac
if [ "$1" = "-" ] && [ "$2" = --target ] && [ "$3" = estree ]; then exit 0; fi
if [ "$1" = --target ] && [ "$2" = shir ]; then printf "%s" "{\"b\":9}"; exit 0; fi
exit 9'
TMPDIR="$tmp" bash "$impl" "$tmp/busy.snapcopy" "$f" > "$tmp/o9" 2>/dev/null; rc=$?
printf '%s' '{"b":9}' > "$tmp/e9"
if [ "$rc" -eq 0 ] && cmp -s "$tmp/o9" "$tmp/e9"; then
  ok "live path busy past every retry -> measured via a verified copy (rc 0, byte-exact)"
else
  bad "busy past every retry (rc=$rc out='$(cat "$tmp/o9" 2>/dev/null)')"
fi

# 10. The copy is REUSED, not remade, for the rest of the run: a gate loops
#     651 files through this helper, so a long window must cost ONE snapshot.
#     Second call on the same emitter (same inode+mtime) => 1 exec for the
#     live path + 1 for the already-trusted copy, and no new cp.
: > "$calls"
TMPDIR="$tmp" bash "$impl" "$tmp/busy.snapcopy" "$f" > "$tmp/o10" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && cmp -s "$tmp/o10" "$tmp/e9" && [ "$(n_calls)" -eq 2 ]; then
  ok "second file in the same window -> cached copy reused (2 execs, no new cp)"
else
  bad "cached copy reuse (rc=$rc calls=$(n_calls))"
fi

# 11. A copy that RUNS but REJECTS the corpus file is a real verdict: the
#     helper returns the copy's rc, not the live path's exec-failure rc. The
#     private copy changes how a file is MEASURED, never what counts.
: > "$calls"
stub "$tmp/busy.rejectcopy" 'case "$0" in */snap-*) ;; *) exit 126;; esac
if [ "$1" = "-" ] && [ "$2" = --target ] && [ "$3" = estree ]; then exit 0; fi
exit 1'
TMPDIR="$tmp" bash "$impl" "$tmp/busy.rejectcopy" "$f" > "$tmp/o11" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -s "$tmp/o11" ]; then
  ok "copy runs but rejects the input -> rc 1 (the copy's verdict, not 126)"
else
  bad "copy rejects the input (rc=$rc)"
fi

echo "--- render mode: the gate's SECOND exec, same policy ---"

a1="$tmp/a1.json"
printf '%s' '{"k":1}' > "$a1"

# R1. Happy path: the A1 on STDIN is passed to `<renderer> <flag> -`, the
#     render comes back byte-exact, and it costs exactly one exec (the gate
#     loops 651 files, so an extra exec per file would be a throughput bug).
: > "$calls"
stub "$tmp/rgood" 'if [ "$1" = "--target=go" ] && [ "$2" = "-" ] && [ $# -eq 2 ]; then
  got=$(cat); [ "$got" = "{\"k\":1}" ] || exit 8; printf "%s" RENDERED; else exit 9; fi'
bash "$impl" --mode=render "$tmp/rgood" --target=go < "$a1" > "$tmp/ro1" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/ro1" 2>/dev/null)" = RENDERED ] && [ "$(n_calls)" -eq 1 ]; then
  ok "render ok -> rc 0, byte-exact, ONE exec, A1 from stdin"
else
  bad "render ok (rc=$rc out='$(cat "$tmp/ro1" 2>/dev/null)' calls=$(n_calls))"
fi

# R2. The renderer RAN and rejected the A1 (a WIP renderer, rc=1): a real
#     verdict, preserved on the FIRST attempt. Retrying this would sleep on a
#     real result.
: > "$calls"
stub "$tmp/rreject" 'cat >/dev/null; exit 1'
bash "$impl" --mode=render "$tmp/rreject" --target=go < "$a1" > "$tmp/ro2" 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -s "$tmp/ro2" ] && [ "$(n_calls)" -eq 1 ]; then
  ok "present renderer rc=1 -> rc 1, no stdout, ONE exec (no retry)"
else
  bad "present renderer rc=1 (rc=$rc calls=$(n_calls))"
fi

# R3. The relink window CLEARS: the first render is refused ETXTBSY (126) and
#     the next runs. The file is measured, not lost.
: > "$calls"
rm -f "$tmp/rbusy.seen"
stub "$tmp/rbusy" "if [ ! -f '$tmp/rbusy.seen' ]; then : > '$tmp/rbusy.seen'; exit 126; fi
cat >/dev/null; printf '%s' BUSY"
bash "$impl" --mode=render "$tmp/rbusy" --target=go < "$a1" > "$tmp/ro3" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/ro3" 2>/dev/null)" = BUSY ] && [ "$(n_calls)" -eq 2 ]; then
  ok "busy renderer then runnable -> rc 0, render from the retry (2 execs)"
else
  bad "busy renderer then runnable (rc=$rc out='$(cat "$tmp/ro3" 2>/dev/null)' calls=$(n_calls))"
fi

# R4. Absent through every attempt: rc 127, no stdout, and it really tried all
#     three (two 1s sleeps) — the same verdict an emitter gets.
absentr="$tmp/rnever"
rm -f "$absentr"
SECONDS=0
bash "$impl" --mode=render "$absentr" --target=go < "$a1" > "$tmp/ro4" 2>/dev/null; rc=$?
elapsed=$SECONDS
if [ "$rc" -eq 127 ] && [ ! -s "$tmp/ro4" ] && [ "$elapsed" -ge 2 ]; then
  ok "absent renderer forever -> rc 127, no stdout, 3 attempts (${elapsed}s)"
else
  bad "absent renderer forever (rc=$rc elapsed=${elapsed}s)"
fi

# R5. A window longer than the sleeps: the LIVE renderer is unusable past every
#     attempt and a COPY (path contains `snap-`) runs, so the file must be
#     MEASURED via the verified copy — this is the case that collapsed go's
#     gate to CRASHED on a tree that renders 651/651.
: > "$calls"
stub "$tmp/rbusy.snapcopy" 'case "$0" in */snap-*) ;; *) exit 126;; esac
cat >/dev/null; printf "%s" RENDERED'
TMPDIR="$tmp" bash "$impl" --mode=render "$tmp/rbusy.snapcopy" --target=go < "$a1" > "$tmp/ro5" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/ro5" 2>/dev/null)" = RENDERED ]; then
  ok "live renderer busy past every retry -> measured via a verified copy (rc 0)"
else
  bad "renderer busy past every retry (rc=$rc out='$(cat "$tmp/ro5" 2>/dev/null)')"
fi

# R6. An EMPTY flag is passed as NO argument: the gate sets g_flag="" for a
#     renderer that takes no target flag, and an empty argv element would be a
#     different invocation (`"" -` instead of `-`).
: > "$calls"
stub "$tmp/rnoflag" 'if [ $# -eq 1 ] && [ "$1" = "-" ]; then cat >/dev/null; printf "%s" NOFLAG; else exit 9; fi'
bash "$impl" --mode=render "$tmp/rnoflag" "" < "$a1" > "$tmp/ro6" 2>/dev/null; rc=$?
if [ "$rc" -eq 0 ] && [ "$(cat "$tmp/ro6" 2>/dev/null)" = NOFLAG ]; then
  ok "empty flag -> invoked as <renderer> - (no empty argv element)"
else
  bad "empty flag (rc=$rc out='$(cat "$tmp/ro6" 2>/dev/null)')"
fi

# R7. Usage error is its own verdict in render mode too.
bash "$impl" --mode=render "$tmp/rgood" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "render mode with 1 arg -> rc 2 (usage)" || bad "render usage (got $rc)"

echo
echo "[emit-shir-retry] $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1