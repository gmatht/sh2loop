#!/bin/bash
# c-fanalyze.sh — GCC -fanalyzer + -Wall/-Wextra over RENDERED C, as a pass/fail
# signal the existing clang --analyze gate does not provide.
#
# Why this exists: setup_backends.sh's C-only static-analysis gate is
# `clang --analyze` grepped for `warning:|error:` (setup_backends.sh ~1603).
# It reports 0 findings on files where `gcc -fanalyzer` reports real
# heap-buffer-overflows in the EMITTED runtime helpers — the two analyzers do
# not agree, and the one wired into the gate is the weaker of the two.
#
# Usage: harness/c-fanalyze.sh [--jobs N] [--limit N] [--all] [--render-only]
#   --jobs N     parallel gcc processes (default 8)
#   --limit N    only the first N rendered files (default: 120)
#   --all        render the full corpus
#   --render-only  write the .c files and stop (for hand inspection)
#
# Exit status: 0 when no STRICT finding survived, 1 otherwise. NON-STRICT
# findings (leak classes, unused warnings) are counted and printed but never
# fail the pass — a transpiled program is a one-shot process, so "leak of
# 'map_v[0]'" at program exit is the renderer's chosen style, not a defect.
# Promoting a leak class to strict is a one-line edit to STRICT below, and
# requires the renderer to actually free.
set -uo pipefail

ROOT=${SH2_ROOT:-/home/llm/sh2loop}
SUB=$ROOT/sh2perl
CORE=${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}
JOBS=${JOBS:-8}
LIMIT=120
RENDER_ONLY=0
# GCC checkers that indicate a MEMORY-SAFETY defect in emitted code. These are
# the ones with confirmed true positives in the rendered runtime helpers.
#
# `double-free` is DELIBERATELY NOT here. It fires on the renderer's assignment
# idiom `{ char *_oldN = v; v = _sh_xstrdup(...); free(_oldN); }` and gcc
# traces the pointer VALUE, not the object: it reports `free(_old0)` at the
# assignment and again at the end-of-program `free(v)` as one object freed
# twice. They are two objects — `_old0` holds the pre-assignment value, `v`
# the post-assignment one. Verified: the reduced form does NOT trip the
# checker, and ASan on the compiled+running 000__04f_output_formatting binary
# is clean (rc=0, zero ASan output). Adding it back requires the renderer to
# stop using that idiom, not a suppression.
STRICT="out-of-bounds null-argument fd-double-close fd-use-without-check use-after-free"

while [ $# -gt 0 ]; do
  case "$1" in
    --jobs) JOBS=$2; shift 2 ;;
    --limit) LIMIT=$2; shift 2 ;;
    --all) LIMIT=100000; shift ;;
    --render-only) RENDER_ONLY=1; shift ;;
    *) echo "c-fanalyze: unknown arg $1" >&2; exit 2 ;;
  esac
done

command -v gcc >/dev/null 2>&1 || { echo "c-fanalyze: no gcc — cannot run (this is NOT a pass)" >&2; exit 2; }
[ -x "$CORE" ] || { echo "c-fanalyze: no renderer at $CORE" >&2; exit 2; }

# Probe the analyzer once. gcc without -fanalyzer accepts the flag silently on
# some builds and ignores it, which would render the whole pass a no-op — the
# same "silent measurement failure" shape as the crashed C gate (see
# core-requests/stalled/c-gate-crashed-not-637-regressions.md).
probe=$(mktemp -d); trap 'rm -rf "$probe"' EXIT
cat > "$probe/p.c" <<'EOF'
#include <string.h>
#include <stdlib.h>
int main(void){ char *p = malloc(4); strcpy(p, "toolong"); return p[0]; }
EOF
# Redirect to a file, never `gcc ... | grep -q`: grep -q exits on first match,
# closes the pipe, gcc takes SIGPIPE, and under `pipefail` the pipeline then
# reports failure — the probe would disable the pass on a perfectly good gcc.
gcc -c -fanalyzer -o /dev/null "$probe/p.c" > "$probe/probe.txt" 2>&1
if ! grep -q 'Wanalyzer' "$probe/probe.txt"; then
  echo "c-fanalyze: this gcc does not emit -Wanalyzer findings — pass DISABLED (would report a vacuous 0)" >&2
  echo "  probe output: $probe/probe.txt" >&2
  exit 2
fi

corpus=$(ls "$SUB"/examples/*.sh 2>/dev/null)
[ -n "$corpus" ] || { echo "c-fanalyze: no corpus under $SUB/examples" >&2; exit 2; }

out=$(mktemp -d "${TMPDIR:-/tmp}/c-fanalyze.XXXXXX")
rendered=0; skipped=0
for f in $corpus; do
  [ "$rendered" -ge "$LIMIT" ] && break
  shir=$(OTRANSPILER_ROOT=$ROOT "$CORE" "$f" --source-lang sh --target shir --raw 2>/dev/null) || { skipped=$((skipped+1)); continue; }
  [ -z "$shir" ] && { skipped=$((skipped+1)); continue; }
  base=$(basename "$f" .sh)
  if ! printf '%s' "$shir" | OTRANSPILER_ROOT=$ROOT "$CORE" - --target c > "$out/$base.c" 2>/dev/null; then
    rm -f "$out/$base.c"; skipped=$((skipped+1)); continue
  fi
  rendered=$((rendered+1))
done
echo "c-fanalyze: rendered $rendered file(s) ($skipped skipped: unparseable or renderer-failed) into $out"
[ "$rendered" -eq 0 ] && { echo "c-fanalyze: CRASHED — nothing rendered, no verdict" >&2; rm -rf "$out"; exit 2; }
[ "$RENDER_ONLY" = 1 ] && { echo "c-fanalyze: --render-only, keeping $out"; exit 0; }

# -Wall/-Wextra unused/dead warnings are renderer cosmetics (e.g. an unused
# `static char *_c0_wb` in a file that never captures); they are counted under
# -Wunused-*, not -Wanalyzer-*, so the strict filter below cannot see them.
ls "$out"/*.c | xargs -P "$JOBS" -I{} \
  gcc -c -fanalyzer -Wall -Wextra -fdiagnostics-plain-output -o /dev/null {} \
  > "$out/all.txt" 2>&1

echo
echo "=== findings by checker ==="
grep -oE '\[-W[a-z-]+\]' "$out/all.txt" | sort | uniq -c | sort -rn
echo
strict_n=0
for c in $STRICT; do
  n=$(command grep -c -- "\[-Wanalyzer-$c\]" "$out/all.txt"; true)
  n=${n:-0}
  [ "$n" -gt 0 ] && echo "  STRICT  -Wanalyzer-$c: $n"
  strict_n=$((strict_n + n))
done
echo
if [ "$strict_n" -gt 0 ]; then
  echo "=== strict sites (first 40) ==="
  command grep -E -- "\[-Wanalyzer-($(echo $STRICT | tr ' ' '|'))\]" "$out/all.txt" | head -40
  echo
  echo "FAIL: $strict_n strict -fanalyzer finding(s) across $rendered rendered file(s)"
  echo "  full diagnostics: $out/all.txt"
  exit 1
fi
echo "PASS: 0 strict -fanalyzer findings across $rendered rendered file(s)"
echo "  diagnostics kept at $out/all.txt"
exit 0