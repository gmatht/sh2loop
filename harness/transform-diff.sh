#!/usr/bin/env bash
# transform-diff.sh — the differential (metamorphic) gate for the shared
# shIR→shIR transform channel: for every corpus example, render the Perl
# backend with the transforms ON and OFF and report where the text differs.
#
#   ./harness/transform-diff.sh                 # whole corpus, summary
#   ./harness/transform-diff.sh 051 064         # filename prefixes
#   ./harness/transform-diff.sh --list          # one line per differing file
#   DIFF_BIN=/path/to/transform_diff ...        # use a prebuilt binary
#
# Exit: 0 always for a completed comparison — a difference is a RESULT (the
# transform is observable for that input), not a failure. Exit 2 when the
# binary is missing (nothing was measured; do not read that as green).
#
# WHY A DIFFERENTIAL AND NOT A VERDICT. The transforms are allowed to change
# the rendered text; what the project actually wants to know is WHICH
# transform changes WHICH program, so that an offer can declare it ("this
# rewrite is text-invisible", "this one annotates only") and a reviewer can
# check the claim. `transform_diff` re-runs one transform at a time over the
# same input, so every DIFF line carries the transform that caused it. A file
# that matches with ALL transforms on is evidence that the whole channel is
# observationally inert for that program.
#
# Build: the binary lives in the crate that owns the Perl renderer; build it
# into a DISTINCT target dir first (the shared target is stale/racy):
#   CARGO_TARGET_DIR=/tmp/sh2-td cargo build --offline --bin transform_diff
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="${DIFF_BIN:-}"
if [ -z "$bin" ]; then
    for cand in "$root/sh2perl/target/debug/transform_diff" \
                "${TRANSFORM_DIFF_BIN:-}"; do
        [ -n "$cand" ] && [ -x "$cand" ] && bin="$cand" && break
    done
fi
if [ -z "$bin" ] || [ ! -x "$bin" ]; then
    echo "transform-diff: no transform_diff binary (DIFF_BIN=... or build it)" >&2
    exit 2
fi

corpus="${FAIL_CORPUS:-$root/sh2perl/examples}"
list=0
prefixes=()
for a in "$@"; do
    case "$a" in
        --list) list=1 ;;
        *) prefixes+=("$a") ;;
    esac
done

shopt -s nullglob
files=("$corpus"/*.sh)
if [ ${#prefixes[@]} -gt 0 ]; then
    selected=()
    for f in "${files[@]}"; do
        for p in "${prefixes[@]}"; do
            case "$(basename "$f")" in
                *"$p"*) selected+=("$f"); break ;;
            esac
        done
    done
    files=("${selected[@]}")
fi

total=0; same=0; diff=0; unparsed=0
declare -A by_transform=()
set +u   # associative-array subscript on bash 4.2 under `set -u` is a trap
: > "${TMPDIR:-/tmp}/sh2-transform-diff.tsv"

for f in ${files[@]+"${files[@]}"}; do
    [ -f "$f" ] || continue
    line=$("$bin" "$f" --json 2>/dev/null)
    rc=$?
    total=$((total + 1))
    if [ $rc -ne 0 ] || [ -z "$line" ]; then
        unparsed=$((unparsed + 1))
        continue
    fi
    printf '%s\n' "$line" >> "${TMPDIR:-/tmp}/sh2-transform-diff.tsv"
    if [[ "$line" == *'"equal":true'* ]]; then
        same=$((same + 1))
    else
        diff=$((diff + 1))
        # Attribute: the transforms that produced the RENDERED difference (the
        # `fired` list). Those need not be the transforms `apply()` reports as
        # "changed": a fold can fire and leave the render identical. What a
        # difference needs is the set of transforms whose individual
        # application differs from the unlowered render.
        fired=$(printf '%s' "$line" | sed -n 's/.*"fired":\[\([^]]*\)\].*/\1/p' | tr -d '"' | tr ',' ' ')
        # A large `fired` set is the signature of a cascade: one transform
        # enables the next, so no single re-run reproduces the difference and
        # the attribution cannot name one. Say so instead of listing 55.
        n_fired=$(printf '%s' "$fired" | wc -w)
        if [ "$n_fired" -gt 12 ]; then
            # A cascade: no single-transform re-run reproduces the difference.
            # (Key without spaces/punctuation: this bash splits an assoc-array
            # subscript that contains them.)
            by_transform[cascade]=$(( ${by_transform[cascade]:-0} + 1 ))
        elif [ -z "$fired" ]; then
            by_transform[unattributed]=$(( ${by_transform[unattributed]:-0} + 1 ))
        else
            # read into a LOCAL first: assigning to `by_transform[$t]` while
            # `t` is also the loop variable of the report below confuses the
            # subscript parser under some bash builds.
            for t in $fired; do
                prev=${by_transform["$t"]:-0}
                by_transform["$t"]=$(( prev + 1 ))
            done
        fi
        [ $list -eq 1 ] && printf 'DIFF %s  [%s]\n' "$(basename "$f")" "${fired:-unattributed}"
    fi
done

echo "transform-diff: $total examples — $same text-identical, $diff differ, $unparsed unlowered"
if [ $diff -gt 0 ]; then
    echo "  differing, by the transform that caused it:"
    for t in $(printf '%s\n' "${!by_transform[@]}" | sort); do
        n=${by_transform[$t]:-0}
        printf '    %-40s %d\n' "$t" "$n"
    done
fi
echo "  per-file JSON: ${TMPDIR:-/tmp}/sh2-transform-diff.tsv"
