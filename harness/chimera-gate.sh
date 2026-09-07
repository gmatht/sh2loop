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
#   no-pcre           — the SANDBOX cannot execute the render: the rendered
#                       file calls a tool the minimal chimera lacks
#                       (perl / pgrep / pcregrep / pcre2grep / grep -P — the
#                       PCRE family), or rc=127/126 (not found / not
#                       executable). Fixed by ADDING perl + PCRE tooling to
#                       the sandbox (pcregrep is the grep -P fallback —
#                       busybox grep can never gain -P). NOT a renderer bug;
#                       not a worker work item.
#   bad-translation   — runs in chimera but output != bash (or rc!=0 where
#                       bash itself exits 0): the worker's work items
#   original-rc!=0    — the SOURCE script exits nonzero under bash: the
#                       gate's rc==0 rule fails it identically in both
#                       environments (no Ubuntu-vs-Chimera information),
#                       so it is excluded from the chimera corpus + reported
#
# Usage: chimera-gate.sh <backend-renderer-bin> <workspace> [staging-dir]
# stdout: summary + classification + fail lists (the worker's log tail);
# exit 0 = all chimera tests pass, 1 = any fail, 2 = deployment missing.
set -u
BIN=${1:?backend renderer bin (backends/sh/target/debug/shir_render)}
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

# 3b. sandbox-deployment check: a runnable sh-gate ALWAYS prints
#     "sh-gate: N pass, N fail" on stdout. No summary = the sandbox
#     itself failed to start (broken WSL distro attach — e.g. the
#     missing-disk ERROR_FILE_NOT_FOUND, or sudo down), NOT a renderer
#     verdict. Report deployment-missing (exit 2, the same contract as a
#     missing sh-gate binary) so the caller can skip instead of RED.
if ! printf '%s' "$summary" | grep -qE 'sh-gate: [0-9]+ pass, [0-9]+ fail'; then
  echo "  [sh] chimera gate: no sh-gate summary (sandbox failed to start — WSL deployment broken?) — skipped" >&2
  exit 2
fi

# 4. classify the failures: no-pcre (the sandbox lacks the runtime/tool —
#    fixed by adding perl + PCRE tooling to the chimera distro, e.g. pcregrep
#    as the grep -P fallback; NOT the worker's renderer) vs bad-translation
#    (runs but != bash — the worker's work items). PRIMARY signal: the
#    rendered file calls a no-pcre-family tool; FALLBACK: rc 127/126.
NO_PCRE_TOOLS='perl pgrep pcregrep pcre2grep'
no_pcre=0; bad=0
: > "$GATE/no_pcre.txt"; : > "$GATE/bad_translation.txt"
while IFS= read -r line; do
  case "$line" in
    FAIL*)
      name=$(echo "$line" | sed -E 's/^FAIL ([^ ]+).*/\1/')
      tool=""
      for t in $NO_PCRE_TOOLS; do
        if grep -qEw "$t" "$GATE/corpus/$name.sh" 2>/dev/null; then tool="$t"; break; fi
      done
      if [ -z "$tool" ] && grep -qE 'grep[^&|;]*(-P|--perl-regexp)' "$GATE/corpus/$name.sh" 2>/dev/null; then
        tool="grep -P"
      fi
      if [ -n "$tool" ] || echo "$line" | grep -qE 'rc=12[67]'; then
        no_pcre=$((no_pcre+1)); echo "$line  [no-pcre: missing $tool]" >> "$GATE/no_pcre.txt"
      else
        bad=$((bad+1)); echo "$line" >> "$GATE/bad_translation.txt"
      fi ;;
  esac
done < "$GATE/chimera_fails.txt"

echo "  [sh] chimera gate: $summary  [corpus $n: rendered $rendered, core-skip $core_skip, render-refused $refused, original-rc!=0 excluded $rc_own]"
echo "  [sh] chimera classification: bad-translation $bad (runs but != bash — the work items), no-pcre $no_pcre (sandbox lacks the PCRE-family tool: fixed by adding perl/pcregrep, not the renderer)"
if [ "$bad" -gt 0 ]; then
  echo "  [sh] chimera bad-translation fails:"
  head -25 "$GATE/bad_translation.txt" | sed 's/^/    /'
  [ "$bad" -gt 25 ] && echo "    ... and $((bad-25)) more (full list: $GATE/bad_translation.txt)"
fi
if [ "$no_pcre" -gt 0 ]; then
  echo "  [sh] chimera no-pcre fails (env limitation — add perl + PCRE tooling to the sandbox):"
  head -10 "$GATE/no_pcre.txt" | sed 's/^/    /'
fi
[ "$gate_rc" -eq 0 ]
