#!/usr/bin/env bash
# transform-proofs.sh — check the Tier-1 proof artifacts that the transform
# manifests CLAIM are checked.
#
#   ./harness/transform-proofs.sh            # every manifest with a proof: line
#   ./harness/transform-proofs.sh --list     # show what would be checked
#
# A manifest line
#
#   proof: proof/Invariant.thy#div_mod_pow2_sound (checked — …)
#
# is a CLAIM. This gate makes the claim checkable: it builds the session next
# to that manifest with Isabelle and fails if the build fails. A claim that
# cannot be built is worse than no claim, because "sorry-free text that looks
# like a proof" is indistinguishable from a proof to a reader.
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

manifests=$(find "$root/core-requests" -name manifest -type f 2>/dev/null | sort)
checked=0; skipped=0; failed=0; stated=0
failed_names=()

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
