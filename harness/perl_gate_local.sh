#!/usr/bin/env bash
# perl_gate_local.sh — the perl backend gate, runnable by one worker without
# taking the fleet's single .gate.lock.
#
# It reproduces setup_backends.sh --backend-gate perl (the js|perl arm):
#   shIR emit from the CORE A1 emitter -> shir_render --target=perl -
#   -> bash -n skip -> stub gate -> perl anti-cheat (bash-wrapper, check_qx)
#   -> executed equivalence in a hermetic scratch dir, with cap-capture.pl on
#      BOTH sides, stderr discarded on both sides, argv0 = the source path.
#
# WHY IT EXISTS. The real gate is `flock -o .gate.lock` over the whole
# workspace: on this box four other gates were queued on it, so a perl worker
# could not get a verdict at all while working. This runs the SAME verdict
# logic on the perl corpus alone, with its own scratch, and writes the same
# summary line — so a worker's iteration loop does not depend on the fleet
# lock. The official gate stays the authority; this is the local mirror.
#
# Usage:
#   harness/perl_gate_local.sh                 # whole corpus
#   harness/perl_gate_local.sh 016 064        # only basenames with those prefixes
#   harness/perl_gate_local.sh -v             # print per-file verdicts
#   harness/perl_gate_local.sh --render 016_fizzbuzz.sh   # render one file to stdout
#   harness/perl_gate_local.sh --why 016_fizzbuzz.sh     # classify one failure
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WT="$ROOT/sh2perl/backends/perl"
OTRANS="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
SR="${PERL_SHIR_RENDER:-$WT/target/debug/shir_render}"
CAP="$ROOT/harness/cap-capture.pl"
KS="$ROOT/harness/kill-session.sh"
TMPD="${PERL_GATE_TMP:-/tmp/perl-gate.$$}"
CAPBYTES="${PERL_GATE_CAP:-1048576}"
TIMEOUT_S="${PERL_GATE_TIMEOUT:-20}"

VERBOSE=0; MODE=loop; ARG1=""; ARG2=""
case "${1:-}" in -v) VERBOSE=1; shift;; esac
case "${1:-}" in --render) MODE=render; ARG1="${2:-}"; shift 2;;
                   --why)    MODE=why;    ARG1="${2:-}"; shift 2;; esac
PREFIXES=("$@")

[ -x "$OTRANS" ] || { echo "perl_gate_local: core emitter $OTRANS missing" >&2; exit 2; }
[ -x "$SR" ]     || { echo "perl_gate_local: $SR missing (cargo build --bin shir_render)" >&2; exit 2; }
command -v perl >/dev/null || { echo "perl_gate_local: no perl" >&2; exit 2; }

CORPUS=$(ls "$ROOT"/sh2perl/examples/*.sh "$ROOT"/sh2perl/frontends/*/testdata/*.sh 2>/dev/null)

# shIR JSON on stdout for one .sh file.
#
# AN EXEC FAILURE IS NOT AN INPUT VERDICT, so it is retried before it is
# believed. The core emitter is rebuilt by the estree loop into the SAME
# target dir every worker shares (sh2perl/target -> .sh2target/otranspiler),
# and cargo replaces target/debug/otranspilerl-cli by unlinking the old
# artifact and re-linking the new one — so for a moment the path does not
# exist and exec returns 127 with the file GONE. Measured on the fleet gate
# 2026-10-25T02:09:37: exactly two corpus files came back
# `rc=127 ... inode=GONE` and the run was reported as CRASHED, though the
# same two files emit clean on demand and the corpus was 648/650 green.
# An emit that fails while the BINARY IS PRESENT (rc=1: a WIP core) is a
# real result and is returned at once.
shir_of() {
  local try
  for try in 1 2 3; do
    if "$OTRANS" --target shir "$1" 2>/dev/null; then return 0; fi
    if [ -x "$OTRANS" ]; then return 1; fi
    sleep 1
  done
  return 1
}
# render shIR -> perl text on stdout.
render_of() { shir_of "$1" | "$SR" --target=perl - 2>/dev/null; }

run_side() { # $1 = command..., stdin = program text; stdout captured capped
  "$@" <"$STDIN_F" 2>/dev/null | perl "$CAP" "$CAPBYTES" out
}

case "$MODE" in
render)
  f=$(ls "$ROOT"/sh2perl/examples/"$ARG1" "$ROOT"/sh2perl/frontends/*/testdata/"$ARG1" 2>/dev/null | head -1)
  [ -n "$f" ] || { echo "no such corpus file: $ARG1" >&2; exit 2; }
  render_of "$f"; exit 0;;
why)
  f=$(ls "$ROOT"/sh2perl/examples/"$ARG1" "$ROOT"/sh2perl/frontends/*/testdata/"$ARG1" 2>/dev/null | head -1)
  [ -n "$f" ] || { echo "no such corpus file: $ARG1" >&2; exit 2; }
  echo "### source: $f"; echo "### bash source:"; cat "$f"; echo
  out=$(render_of "$f"); rc=$?
  if [ $rc -ne 0 ]; then echo "### RENDER FAILED (rc=$rc)"; exit 1; fi
  printf '%s' "$out" > "$TMPD.why.pl"; echo "### render:"; cat "$TMPD.why.pl"; echo
  bash -n "$f" 2>/dev/null || { echo "### (bash -n fails: skipped by the gate)"; exit 0; }
  printf '%s' "$out" | command grep -qE "system\('bash',\s*'[^']*'\)" && { echo "### FAIL: bash-wrapper anti-cheat"; exit 1; }
  qx=$(perl "$ROOT/check_qx.pl" "$TMPD.why.pl" 2>/dev/null | command grep -c FAIL || true)
  [ "${qx:-0}" -gt 0 ] && { echo "### FAIL: check_qx ($qx violations)"; perl "$ROOT/check_qx.pl" "$TMPD.why.pl" 2>/dev/null | command grep FAIL; exit 1; }
  s=$(printf '%s' "$out" | command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' || true)
  [ "${s:-0}" -gt 0 ] && { echo "### FAIL: stub gate ($s)"; exit 1; }
  sc=$(mktemp -d "$ROOT/.perlwhy.XXXXXX"); cd "$sc" || exit 2
  cp "$TMPD.why.pl" "$sc/prog.pl"
  bash_out=$("$KS" timeout -k 2 "$TIMEOUT_S" bash "$f" 2>/dev/null | perl "$CAP" "$CAPBYTES" out); bash_rc=${PIPESTATUS[0]}
  pl_out=$("$KS" timeout -k 2 "$TIMEOUT_S" perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$f" "$sc/prog.pl" 2>/dev/null | perl "$CAP" "$CAPBYTES" out); pl_rc=${PIPESTATUS[0]}
  echo "### bash (rc=$bash_rc):"; printf '%s\n' "$bash_out"
  echo "### perl (rc=$pl_rc):"; printf '%s\n' "$pl_out"
  if [ "$bash_out" = "$pl_out" ] && [ "$bash_rc" = "$pl_rc" ]; then echo "### EQUIV PASS"; else echo "### FAIL: equivalence (bash_rc=$bash_rc perl_rc=$pl_rc)"; diff <(printf '%s\n' "$bash_out") <(printf '%s\n' "$pl_out") | head -40; fi
  cd /; rm -rf "$sc" "$TMPD.why.pl"; exit 0;;
esac

mkdir -p "$TMPD"
# Named *.pl, NOT `.stdin`: check_qx.pl skips every file that is not `*.pl`
# (see the note at the anti-cheat stage below).
STDIN_F="$TMPD/render.pl"
pass=0; fail=0; skip=0; stub=0; qxf=0; renderfail=0; equivfail=0
fails=""
for f in $CORPUS; do
  b=$(basename "$f")
  case "${PREFIXES[*]-}" in "") ;; *) okp=0; for p in "${PREFIXES[@]}"; do case "$b" in "$p"*) okp=1;; esac; done; [ $okp = 1 ] || continue;; esac
  shir=$(shir_of "$f") || { renderfail=$((renderfail+1)); fail=$((fail+1)); fails="$b $fails"; echo "  [perl] shir emit FAILED: $b" >&2; continue; }
  [ -n "$shir" ] || { renderfail=$((renderfail+1)); fail=$((fail+1)); fails="$b $fails"; echo "  [perl] shir emit EMPTY: $b" >&2; continue; }
  bash -n "$f" 2>/dev/null || { skip=$((skip+1)); [ $VERBOSE = 1 ] && echo "SKIP (bash -n) $b"; continue; }
  if out=$(printf '%s' "$shir" | "$SR" --target=perl - 2>/dev/null); then ok=1; else ok=0; out=""; fi
  if [ $ok != 1 ]; then
    renderfail=$((renderfail+1)); fail=$((fail+1)); fails="$b $fails"
    [ $VERBOSE = 1 ] && echo "RENDER-FAIL $b"; continue
  fi
  printf '%s' "$out" > "$STDIN_F"
  # STAGE ORDER MIRRORS THE FLEET GATE, and that is load-bearing for the
  # verdict's MEANING: setup_backends.sh computes the stub count first and
  # enters its anti-cheat block only when it is zero, so a file that carries
  # both a TODO marker and a qx violation is counted as a STUB failure. With
  # the qx stage first (as this mirror had it) the same file was reported as
  # a check_qx failure — a different number for the same tree, which is the
  # one thing a mirror must not do.
  s=$(command grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\(' "$STDIN_F" || true)
  stub=$((stub + ${s:-0}))
  if [ "${s:-0}" -gt 0 ]; then fail=$((fail+1)); fails="$b $fails"; [ $VERBOSE = 1 ] && echo "FAIL(stub=$s) $b"; continue; fi
  if command grep -qE "system\('bash',\s*'[^']*'\)" "$STDIN_F"; then
    fail=$((fail+1)); fails="$b $fails"; [ $VERBOSE = 1 ] && echo "FAIL(bash-wrapper) $b"; continue
  fi
  # THE RENDER MUST BE NAMED *.pl HERE. check_qx.pl opens only `*.pl` files
  # (`next if $file !~ /\.pl$/`), and this mirror wrote the render to
  # "$TMPD/.stdin" — so the stage scanned NOTHING, printed nothing, and
  # reported `0 check_qx` for a corpus the fleet gate was simultaneously
  # failing 20+ files on. A gate stage that cannot fire is worse than a
  # missing one: it reports a verdict (green) it never measured.
  qx=$(perl "$ROOT/check_qx.pl" "$STDIN_F" 2>/dev/null | command grep -c FAIL || true)
  if [ "${qx:-0}" -gt 0 ]; then
    qxf=$((qxf+1)); fail=$((fail+1)); fails="$b $fails"; [ $VERBOSE = 1 ] && echo "FAIL(check_qx=$qx) $b"; continue
  fi
  # executed equivalence, hermetic scratch, argv0 = source path (the gate's
  # perl treatment), cap on both sides, stderr dropped on both sides
  sc=$(mktemp -d "$ROOT/.perlgate.XXXXXX")
  cp "$STDIN_F" "$sc/prog.pl"
  # SESSION TEARDOWN ORDER MATTERS. This used to be `timeout -k 2 N "$KS" ...`
  # — timeout OUTSIDE the session wrapper. Then `setsid` runs as a DESCENDANT
  # of timeout, so when the bound fires timeout signals only its direct child
  # (the KS shell, which is blocked in `wait`) and dies BEFORE its session
  # sweep; the example's perl/bash survives, still holding the write end of
  # the pipe into cap-capture.pl, so the command substitution never sees EOF
  # and the gate HANGS with no verdict (measured: a 52-minute-old orphaned
  # `perl -x prog.pl` holding one run open forever). The fleet gate wraps the
  # other way round — "$KS" timeout ... — so the sweep runs after the bound
  # fires and the pipe closes. Mirror the fleet order on BOTH sides.
  bash_out=$(cd "$sc" && "$KS" timeout -k 2 "$TIMEOUT_S" bash "$f" 2>/dev/null | perl "$CAP" "$CAPBYTES" out); bash_rc=${PIPESTATUS[0]}
  pl_out=$(cd "$sc" && "$KS" timeout -k 2 "$TIMEOUT_S" perl -M5.010 -e '$0 = shift @ARGV; my $__f = shift @ARGV; do $__f' "$f" "$sc/prog.pl" 2>/dev/null | perl "$CAP" "$CAPBYTES" out); pl_rc=${PIPESTATUS[0]}
  rm -rf "$sc"
  if [ "$bash_out" = "$pl_out" ]; then
    pass=$((pass+1)); [ $VERBOSE = 1 ] && echo "PASS $b"
  else
    equivfail=$((equivfail+1)); fail=$((fail+1)); fails="$b $fails"
    [ $VERBOSE = 1 ] && echo "FAIL(equiv) $b  [bash_rc=$bash_rc pl_rc=$pl_rc]"
  fi
done
total=$((pass+fail+skip))
printf '\n[perl-gate-local] %d/%d render OK, %d fail (%d stubs, %d check_qx, %d render-fail, %d equiv), %d skip — equiv: %d pass vs bash\n' \
  $((total-fail)) "$total" "$fail" "$stub" "$qxf" "$renderfail" "$equivfail" "$skip" "$pass"
[ -n "$fails" ] && echo "fails: $fails"
rm -rf "$TMPD"
[ "$fail" -eq 0 ]