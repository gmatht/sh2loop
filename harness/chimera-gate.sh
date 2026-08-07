#!/bin/bash
# chimera-gate.sh — the sh backend's bash-free test: render the gate corpus
# (sh2perl/examples/*.sh + frontends/*/testdata/*.sh) through the sh backend
# and run it in the chimera WSL sandbox (BSD shell + busybox toolchain, no
# bash/perl/GNU coreutils) vs bash refs.
#
# A test PASSES only if it passes under BOTH Ubuntu (dash, the loop's dev
# equivalence gate) AND Chimera — this gate's failures union into the worker's
# work list (setup_backends.sh --backend-gate sh).
#
# Classification of chimera failures:
#   cannot-translate  — core --shir empty (parse error) or render refused;
#                       NOT in the corpus (like the dev gate's skip)
#   no-Perl           — rc=127/126: the sandbox cannot execute the render
#                       (missing runtime/tool: perl, bash, busybox-absent);
#                       known env limitation, reported not silently dropped
#   bad-translation   — runs in chimera but output != bash (or rc!=0 where
#                       bash itself exits 0): the worker's work items
#   original-rc!=0    — the SOURCE script exits nonzero under bash: the
#                       gate's rc==0 rule fails it identically in both
#                       environments (no Ubuntu-vs-Chimera information),
#                       so it is excluded from the chimera corpus + reported
#
# Usage: chimera-gate.sh <backend-debashc-bin> <workspace> [staging-dir]
# stdout: summary + classification + fail lists (the worker's log tail);
# exit 0 = all chimera tests pass, 1 = any fail, 2 = deployment missing.
set -u
BIN=${1:?backend debashc bin (backends/sh/target/debug/debashc)}
WORKSPACE=${2:?workspace root}
GATE=${3:-/home/llm/sh-gate-full}
SH_GATE=${SH_GATE:-/usr/local/bin/sh-gate}

if [ ! -x "$SH_GATE" ]; then
  echo "  [sh] chimera gate: sh-gate not available ($SH_GATE) — skipped" >&2
  exit 2
fi
if [ ! -x "$BIN" ]; then
  echo "  [sh] chimera gate: backend binary missing ($BIN)" >&2
  exit 2
fi

mkdir -p "$GATE/corpus" "$GATE/ref"
rm -f "$GATE/corpus"/*.sh "$GATE/ref"/*.out

# 1. render the gate corpus (same corpus the dev gate uses)
n=0; rendered=0; core_skip=0; refused=0
: > "$GATE/cannot_translate.txt"
for f in "$WORKSPACE"/sh2perl/examples/*.sh "$WORKSPACE"/frontends/*/testdata/*.sh; do
  [ -f "$f" ] || continue
  n=$((n+1))
  bn=$(basename "$f" .sh)
  shir=$(timeout 30 "$BIN" --shir "$f" --raw 2>/dev/null)
  if [ -z "$shir" ]; then
    core_skip=$((core_skip+1))
    echo "$bn (core --shir empty)" >> "$GATE/cannot_translate.txt"
    continue
  fi
  if ! printf '%s' "$shir" | timeout 30 "$BIN" --shir-in-sh - > "$GATE/corpus/$bn.sh" 2>/dev/null; then
    rm -f "$GATE/corpus/$bn.sh"
    refused=$((refused+1))
    echo "$bn (render refused)" >> "$GATE/cannot_translate.txt"
    continue
  fi
  rendered=$((rendered+1))
done

# 2. bash refs in a scratch COPY of the corpus — the gate's extraction layout
#    (shared dir; cwd = corpus' parent; $0 = corpus/<bn>.sh). Examples that
#    mutate their cwd touch the scratch, never the real corpus.
scratch=$(mktemp -d /tmp/sh-gate-refs.XXXXXX)
trap 'rm -rf "$scratch"' EXIT
cp -r "$GATE/corpus" "$scratch/corpus"
mkdir -p "$scratch/ref"
nref=0; rc_own=0
: > "$GATE/rc_nonzero.txt"
for f in "$scratch"/corpus/*.sh; do
  [ -f "$f" ] || continue
  bn=$(basename "$f" .sh)
  (cd "$scratch" && timeout 20 bash "corpus/$bn.sh" < /dev/null > "ref/$bn.out" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    rc_own=$((rc_own+1))
    echo "$bn (bash rc=$rc)" >> "$GATE/rc_nonzero.txt"
    rm -f "$GATE/corpus/$bn.sh"   # excluded: the gate's rc==0 rule fails it
                                  # identically under both environments
  fi
  nref=$((nref+1))
done
cp "$scratch"/ref/*.out "$GATE/ref/" 2>/dev/null
rm -rf "$scratch"

# 3. run the chimera gate
"$SH_GATE" "$GATE" > /tmp/chimera_summary.$$ 2>/tmp/chimera_fails.$$
gate_rc=$?
summary=$(cat /tmp/chimera_summary.$$ 2>/dev/null)
grep '^FAIL' /tmp/chimera_fails.$$ > "$GATE/chimera_fails.txt" 2>/dev/null || true
rm -f /tmp/chimera_summary.$$ /tmp/chimera_fails.$$

# 4. classify the failures
no_perl=0; bad=0
: > "$GATE/no_perl.txt"; : > "$GATE/bad_translation.txt"
while IFS= read -r line; do
  case "$line" in
    FAIL*rc=127*|FAIL*rc=126*)
      no_perl=$((no_perl+1)); echo "$line" >> "$GATE/no_perl.txt" ;;
    FAIL*)
      bad=$((bad+1)); echo "$line" >> "$GATE/bad_translation.txt" ;;
  esac
done < "$GATE/chimera_fails.txt"

echo "  [sh] chimera gate: $summary  [corpus $n: rendered $rendered, core-skip $core_skip, render-refused $refused, original-rc!=0 excluded $rc_own]"
echo "  [sh] chimera classification: bad-translation $bad (runs but != bash — the work items), no-Perl $no_perl (sandbox can't execute: rc 127/126)"
if [ "$bad" -gt 0 ]; then
  echo "  [sh] chimera bad-translation fails:"
  head -25 "$GATE/bad_translation.txt" | sed 's/^/    /'
  [ "$bad" -gt 25 ] && echo "    ... and $((bad-25)) more (full list: $GATE/bad_translation.txt)"
fi
if [ "$no_perl" -gt 0 ]; then
  echo "  [sh] chimera no-Perl fails (sandbox lacks the runtime — env limitation):"
  head -10 "$GATE/no_perl.txt" | sed 's/^/    /'
fi
[ "$gate_rc" -eq 0 ]
