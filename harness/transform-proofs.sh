#!/usr/bin/env bash
# transform-proofs.sh — build every Isabelle session in the tree that CLAIMS
# to be checked.
#
#   ./harness/transform-proofs.sh            # manifests + whole-dir sessions
#   ./harness/transform-proofs.sh --list     # show what would be checked
#
# TWO KINDS OF CLAIM are checked, because the repo has two:
#
#   1. A transform manifest carrying a `proof:` line — the per-transform
#      form, next to the offer it constrains.
#
# A manifest line
#
#   proof: proof/Invariant.thy#div_mod_pow2_sound (checked — …)
#
#   2. A top-level `ROOT` with `quick_and_dirty = false` and no `sorry` in its
#      theories — the analysis/verdict form (`proofs/`, the node semantics in
#      `sh2perl/docs/fm/`). Those claims currently live in a README, where
#      "built once, by hand" reads exactly like "proved".
#
# A claim that cannot be built is worse than no claim, because sorry-free text
# that LOOKS like a proof is indistinguishable from a proof to a reader.
#
# Exit: 0 when every `checked` claim builds (or there is none); 1 when a claim
# fails; 2 when Isabelle is absent (nothing was verified — do NOT read that as
# green), or when a manifest claims `checked` with no `ROOT` to build.
#
# Note on `--proofs`: PLAN's D3 wanted this run pre-merge, not per commit —
# an Isabelle build is ~30 s warm and ~6 min on a cold HOL image, and it wants
# ~4 GB. That cost is why it is a separate script rather than a step in ./fail.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISABELLE="${ISABELLE:-isabelle}"
if ! command -v "$ISABELLE" >/dev/null 2>&1; then
    for cand in /opt/Isabelle*/bin/isabelle; do
        [ -x "$cand" ] && ISABELLE="$cand" && break
    done
fi
if ! command -v "$ISABELLE" >/dev/null 2>&1 && [ ! -x "$ISABELLE" ]; then
    echo "transform-proofs: Isabelle not found — NOTHING was verified" >&2
    echo "  install: /opt/Isabelle2025-2/bin/isabelle, or set ISABELLE=" >&2
    exit 2
fi

list=0
[ "${1:-}" = "--list" ] && list=1

manifests=$(command find "$root/core-requests" -name manifest -type f 2>/dev/null | sort)
checked=0; skipped=0; failed=0; stated=0
failed_names=()

# ── The whole-directory form: every ROOT outside core-requests ────────────
# A session directory is checked when its ROOT sets quick_and_dirty = false
# (so `sorry` cannot sneak in) and none of its theories contains `sorry` /
# `oops`. A directory that opts out of quick_and_dirty is reported as STATED:
# it is a claim the repo is not standing behind.
# `command find`, not `find`: on this box `find` is a shell FUNCTION that
# forwards to `rg --files` and silently ignores `-prune`/`-o`, so the scratch
# tree `sh2loop/` (seven self-referencing copies) turned one gate run into
# eight doomed Isabelle builds. Same trap as AGENTS.md's `grep -q` note: a
# wrapper that accepts the arguments without honouring them.
dirs=$(command find "$root" \( -name node_modules -o -name target -o -name tmp_run \
                     -o -name core-requests -o -name sh2loop \) -prune -o \
        -name ROOT -type f -print 2>/dev/null | sort)
for r in $dirs; do
    d=$(dirname "$r")
    if grep -q "quick_and_dirty *= *false" "$r"; then
        status=checked
    else
        status=stated
    fi
    # Strip comments first: a theory that SAYS "no sorry can hide here" must
    # not be read as containing one (grep found exactly that comment in
    # proofs/DivModPow2). Isabelle's comments are (* … *), which the
    # lexer handles properly; perl -0777 slurps the whole file.
    # Isabelle comments are (* … *); strip them before looking for a bare
    # `sorry`/`oops` so a theory that SAYS "no sorry can hide here" is not
    # read as containing one. `perl -0777 -ne … && print` in a loop is the
    # wrong shape: perl exits 0 whatever it prints.
    sorries=""
    for f in "$d"/*.thy; do
        [ -f "$f" ] || continue
        if perl -0777 -ne 's/\(\*.*?\*\)//gs; exit(/ (?<![A-Za-z_])(?:sorry|oops)(?![A-Za-z_]) /x ? 0 : 1)' -- "$f"; then
            sorries="$sorries$f"$'\n'
        fi
    done
    sorries=$(printf '%s' "$sorries" | head -3)
    if [ -n "$sorries" ]; then
        echo "transform-proofs: $d contains sorry/oops — not a proof:" >&2
        printf '    %s\n' $sorries >&2
        failed=$((failed + 1)); failed_names+=("$d"); continue
    fi
    if [ "$status" = "stated" ]; then
        stated=$((stated + 1))
        [ $list -eq 1 ] && echo "STATED  $d  (ROOT does not set quick_and_dirty = false)"
        continue
    fi
    if [ $list -eq 1 ]; then
        echo "CHECK   $d"
        continue
    fi
    # Build the sessions whose theory is actually present: a ROOT may declare
    # a session that is NOT in the default build (BigIntRange, recorded in
    # proofs/ROOT as not-yet-checking). Those are reported as DECLARED-BUT-
    # FAILING rather than as a passing gate: silently skipping them would be
    # the same lie as claiming them.
    log=$(mktemp)
    names=""
    if [ -f "$d/ROOT" ]; then
        names=$(python3 - "$d/ROOT" <<'PYEOF'
import os, re, sys
root = sys.argv[1]
d = os.path.dirname(root)
names = []
for ln in open(root, encoding='utf-8', errors='replace'):
    m = re.match(r'session\s+(\S+)\s+in\s+(\S+)\s*=', ln)
    if m and os.path.exists(os.path.join(d, m.group(2) + '.thy')):
        names.append(m.group(1))
print(' '.join(names))
PYEOF
)
    fi
    if [ -n "$names" ]; then
        ok=1
        # shellcheck disable=SC2086
        timeout 1800 "$ISABELLE" build -c -o quick_and_dirty=false -D "$d" $names >"$log" 2>&1 || ok=0
    else
        ok=0
    fi
    if [ "$ok" = 1 ]; then
        checked=$((checked + 1))
        echo "OK      $d"
    else
        failed=$((failed + 1)); failed_names+=("$d")
        echo "FAILED  $d" >&2
        sed 's/^/    /' "$log" | tail -12 >&2
    fi
    rm -f "$log"
done

for m in $manifests; do
    # the proof: line, continuation lines included, read into one string
    claim=$(awk '
        /^proof:/ { inproof = 1 }
        inproof { printf "%s ", $0 }
        inproof && !/,$/ && NR > 1 {}
    ' "$m" | head -1)
    claim=$(awk 'BEGIN{p=0} /^proof:/{p=1} p{printf "%s ",$0} p && /$/{if (NR>0 && $0 !~ /^proof:/ ) {} }' "$m")
    # simpler and sufficient: grep the proof: line and the following indented lines
    claim=$(python3 - "$m" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
out, on = [], False
for ln in lines:
    if ln.startswith('proof:'):
        on = True
        out.append(ln)
        continue
    if on:
        if ln.startswith((' ', '\t')) and ln.strip():
            out.append(ln)
        else:
            break
print(' '.join(x.strip() for x in out))
PY
)
    [ -z "$claim" ] && continue

    case "$claim" in
        *"(checked"*|*"(checked)"*) status=checked ;;
        *"(stated"*|*"(stated)"*) status=stated ;;
        *) status=unknown ;;
    esac

    dir=$(dirname "$m")
    if [ "$status" = "stated" ]; then
        stated=$((stated + 1))
        [ $list -eq 1 ] && echo "STATED  $m"
        continue
    fi
    if [ "$status" != "checked" ]; then
        echo "transform-proofs: $m: unparseable proof: claim (want 'checked'/'stated')" >&2
        failed=$((failed + 1)); failed_names+=("$m"); continue
    fi

    theory=$(printf '%s' "$claim" | sed -n 's/.*proof: *\([^# ]*\)#.*/\1/p')
    proofdir="$dir/$(dirname "$theory")"
    if [ ! -f "$proofdir/ROOT" ]; then
        echo "transform-proofs: $m claims checked, but $proofdir/ROOT is missing" >&2
        failed=$((failed + 1)); failed_names+=("$m"); continue
    fi
    if [ $list -eq 1 ]; then
        echo "CHECK   $m  ->  $proofdir"
        continue
    fi
    # a `checked` claim must also be sorry-free: -o quick_and_dirty=false makes
    # Isabelle reject `sorry` outright, and `-c` forces a from-scratch build so
    # a cached heap cannot certify a file that has since been edited.
    log=$(mktemp)
    if timeout 1800 "$ISABELLE" build -c -o quick_and_dirty=false -D "$proofdir" >"$log" 2>&1; then
        checked=$((checked + 1))
        echo "OK      $m"
    else
        failed=$((failed + 1)); failed_names+=("$m")
        echo "FAILED  $m" >&2
        sed 's/^/    /' "$log" | tail -12 >&2
    fi
    rm -f "$log"
done

echo "transform-proofs: $checked checked-and-built, $stated stated-only, $failed failed"
if [ $failed -gt 0 ]; then
    printf '  failed: %s\n' "${failed_names[*]}" >&2
    exit 1
fi
exit 0
