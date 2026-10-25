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
#
# THE WAIT ALONE IS NOT ENOUGH (2026-10-25). A fixed 3-attempt/1s retry only
# covers a window SHORTER than ~2s, and the window is a whole-file WRITE: when
# cargo falls back to an in-place copy of the 124MB debug binary the refusal
# lasts as long as the copy. Reproduced deterministically (hold the emitter
# open for write for 8s, then run this helper):
#
#   retry rc=126 bytes=0          <- before: the file is counted FAIL
#
# So the exec-failure class now has a SECOND line of defence: once the live
# path stays unusable through every attempt, the file is measured with a
# VERIFIED PRIVATE COPY of the emitter (the same rule the frontend gates apply
# to the shared oracle — harness/snapshot-otranspilerl-cli.sh: copy once, run
# it on a trivial A1 program, trust it only if that RUNS). A copy cannot be
# ETXTBSY-busy, and because its identity is keyed on (path, inode, mtime) it
# can never serve a different binary than the one that was busy — so the
# snapshot carries no staleness risk, and a relink invalidates it by itself.
# The copy is made only on the failure path (never on the happy path, which
# still costs exactly one exec per file) and is reused across the rest of the
# run, so a long window costs ONE snapshot, not one per corpus file.
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

# ── the verified private copy of the emitter ────────────────────────────────
# Only ever consulted on the exec-failure path (see the header). The name
# carries the emitter's IDENTITY (inode + mtime), so a relink produces a
# different name and a stale copy is never picked up — no TTL, no guessing.
snapdir="${TMPDIR:-/tmp}/emit-shir-retry"
mkdir -p "$snapdir" 2>/dev/null || snapdir="${TMPDIR:-/tmp}"
mina1="$snapdir/min-a1.json"
# The liveness program: a copy is trusted only once it RUNS (the same check
# harness/snapshot-otranspilerl-cli.sh applies to the shared oracle).
cat > "$mina1" <<'MIN'
{"contract_version":1,"imports":[],"requires":[],"stmt_lines":[],"stmts":[],"subs":[],"type":"Program","var_bash_env":[],"var_const":[],"var_lengths":[],"var_lifetimes":[],"var_nospace":[],"var_types":[]}
MIN

snap_name() {
  _id=$(stat -c '%i.%Y' "$1" 2>/dev/null) || return 1
  printf '%s/snap-%s.%s' "$snapdir" "$(printf '%s' "$1" | md5sum | cut -c1-16)" "$_id"
}
# cached_snap <emitter> -> echoes an ALREADY-TRUSTED copy (no copy, no exec).
cached_snap() {
  _s=$(snap_name "$1") || return 1
  [ -x "$_s" ] || return 1
  printf '%s' "$_s"
}
# make_snap <emitter> -> echoes a copy that was made AND verified now.
make_snap() {
  _s=$(snap_name "$1") || return 1
  [ -x "$_s" ] && { printf '%s' "$_s"; return 0; }
  # A copy is a 124MB debug binary, and the emitter is RELINKED constantly:
  # every relink is a new identity and therefore a new name. Only the failure
  # path gets here, but a long-lived box must not accumulate them — drop this
  # copies older than 4h (best effort; a copy is only reused within
  # one gate run anyway, and never past its identity).
  find "$snapdir" -maxdepth 1 -name 'snap-*' -mmin +240 -delete 2>/dev/null || true
  # cp.tmp is unique per process: two gates sharing $snapdir must not write
  # the same temp file, and neither may trust a half-written one.
  _tmp="$_s.tmp.$$"
  cp "$1" "$_tmp" 2>/dev/null || { rm -f "$_tmp"; return 1; }
  chmod +x "$_tmp" 2>/dev/null || { rm -f "$_tmp"; return 1; }
  if ! "$_tmp" - --target estree < "$mina1" >/dev/null 2>&1; then
    rm -f "$_tmp"; return 1
  fi
  mv -f "$_tmp" "$_s" 2>/dev/null || { rm -f "$_tmp"; return 1; }
  printf '%s' "$_s"
}
# measure <emitter-that-can-actually-exec> — the emit, or nothing on failure.
emit_with() {
  # The redirect is on the COMMAND, so a missing emitter is silent too.
  out=$("$1" --target shir "$file" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    # printf, not echo: the shIR is JSON and must pass through byte-exact
    # (the gate pipes it straight into the renderer).
    printf '%s' "$out"
    exit 0
  fi
}

try=1
while : ; do
  emit_with "$emitter"
  # PRESENT emitter -> a real result, whatever the rc says (1 = rejects the
  # input, 127 = e.g. a missing shared library). Never retried. Exception:
  # rc=126 on a PRESENT, executable path is the relinker's ETXTBSY window
  # (see the header), which is an exec failure, not a result.
  if [ -x "$emitter" ] && [ "$rc" -ne 126 ]; then
    exit "$rc"
  fi
  # ABSENT path, or PRESENT-but-busy: an exec failure either way.
  last_rc=$rc
  # A long window (an in-place copy of the binary, not a rename) outlives the
  # sleeps — and once one file has paid for a verified copy, the rest of the
  # corpus must not pay again: use it the moment it exists. A copy that RUNS
  # and rejects the input is a real result, so its rc is the verdict.
  if snap=$(cached_snap "$emitter"); then
    emit_with "$snap"
    exit "$rc"
  fi
  if [ "$try" -ge "$tries" ]; then
    # Every attempt saw the same unusable live path: measure with a private
    # copy if one can be had. A copy that cannot RUN is not used, so this
    # still cannot rescue a genuinely broken emitter — its rc is returned.
    # A copy that DOES run and then rejects the input is a real result, so
    # its rc is the verdict.
    if snap=$(make_snap "$emitter"); then
      emit_with "$snap"
      exit "$rc"
    fi
    exit "$last_rc"
  fi
  try=$((try+1))
  # 1s, 2s: the sleeps are a MINIMUM, so a loaded box only makes this safer.
  sleep "$((try - 1))"
done
