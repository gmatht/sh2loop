#!/usr/bin/env bash
# harness/pass_sets.sh — persist per-backend PASS SETS (which corpus files
# pass each backend's gate) so a REGRESSION (a previously-passing file now
# failing) is distinguishable from a NEW WORK ITEM (a new/expanded test that
# fails — the failure-driven workers' roadmap).
#
# Policy (POSSIBLE_TESTING_IMPROVEMENTS.md):
#   - sh2js (estree) is the production path: its pass set is monotonic — a
#     previously-passing file may never start failing (--check exits 1).
#   - other backends may lag; their pass-set drift is informational.
#   - a NEW failing test is NOT a regression — only previously-passing →
#     failing counts; new files and new failures extend the baseline.
#
# Pass sets store RELATIVE PATHS (sh2perl/examples/x.sh, frontends/*/testdata/
# x.sh) — basenames are ambiguous in the "all" corpus (t01_echo.sh exists in
# both examples/ and a frontend testdata dir). Normalization: a bare
# basename from the estree/perl sources (examples-only gates) is prefixed
# with sh2perl/examples/; gate fails lists already carry full paths. Per-gate
# corpus scope: estree/perl run examples-only; the backend gates cover
# examples + frontends testdata ("all").
#
# Usage:
#   pass_sets.sh --seed-estree                 baseline estree from
#                                               .estree_failures.tsv
#   pass_sets.sh --seed <lang> <fails-file>    baseline <lang>: pass set =
#                                               corpus − the file's fails
#   pass_sets.sh --check <lang> <fails-file>   diff current vs baseline;
#                                               exit 1 on estree regressions
#                                               (--strict also for others)
#   pass_sets.sh --show <lang>                 print the baseline pass set
#
# Verdict sources (one per backend, maintained by its gate):
#   estree: .estree_failures.tsv (per-file PASS/FAIL, written by fail-estree)
#   others: a per-file fails list — the backend gate prints "fails: <file>
#           ..."; capture it, or use an equivalence run (render → run →
#           diff vs bash) and list the non-matching files.
#
# The pass-set files live in the workspace root (.<lang>_pass_set) and are
# committed so every gate run can diff against a known baseline.

set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# corpus <scope> — relative paths, sorted. scope: examples (estree/perl
# gates) or all (backend gates: examples + frontends testdata).
corpus() {
    local scope="${1:-all}"
    case "$scope" in
        examples) ls sh2perl/examples/*.sh 2>/dev/null ;;
        all) ls sh2perl/examples/*.sh frontends/*/testdata/*.sh 2>/dev/null ;;
        *) echo "bad scope: $scope" >&2; exit 2 ;;
    esac | sed 's|^\./||' | sort -u
}

# normalize — stdin lines: bare basenames (estree/perl sources) become
# sh2perl/examples/<name>; paths pass through (leading ./ stripped).
normalize() {
    while read -r n; do
        case "$n" in
            */*) echo "${n#./}" ;;
            *) echo "sh2perl/examples/$n" ;;
        esac
    done
}

# fails_paths <fails-file> — every *.sh token, normalized, sorted.
fails_paths() {
    grep -oE '[^[:space:]]+\.sh' "$1" 2>/dev/null | normalize | sort -u
}

# pass_set_from_fails <scope> <fails-file> — pass set = corpus − fails
pass_set_from_fails() {
    local scope="$1" fails_file="$2"
    comm -23 <(corpus "$scope") <(fails_paths "$fails_file")
}

# estree pass set from .estree_failures.tsv (PASS lines, first column)
# — tsv names are basenames over the examples-only corpus.
pass_set_estree() {
    awk -F'\t' '$2 == "PASS" { print "sh2perl/examples/" $1 }' .estree_failures.tsv 2>/dev/null | sort -u
}

# corpus scope for a backend's seed/check
scope_for() {
    case "$1" in
        estree|perl) echo examples ;;
        *) echo all ;;
    esac
}

seed() {
    local lang="$1" fails_file="$2" scope
    scope="$(scope_for "$lang")"
    pass_set_from_fails "$scope" "$fails_file" > ".${lang}_pass_set"
    echo "seeded .${lang}_pass_set ($scope corpus): $(wc -l < ".${lang}_pass_set") files pass"
}

seed_estree() {
    pass_set_estree > .estree_pass_set
    echo "seeded .estree_pass_set: $(wc -l < .estree_pass_set) files pass"
}

check() {
    local lang="$1" fails_file="$2" strict="${3:-}" scope current
    [ -f ".${lang}_pass_set" ] || { echo "no baseline .${lang}_pass_set — run --seed first" >&2; exit 2; }
    scope="$(scope_for "$lang")"
    if [ "$lang" = "estree" ]; then
        current="$(pass_set_estree)"
    else
        current="$(pass_set_from_fails "$scope" "$fails_file")"
    fi
    local regressed improved
    regressed="$(comm -23 ".${lang}_pass_set" <(printf '%s\n' "$current" | sort -u))"  # was passing, now failing
    improved="$(comm -13 ".${lang}_pass_set" <(printf '%s\n' "$current" | sort -u))"   # was failing, now passing
    echo "== $lang pass-set check ($scope corpus) =="
    echo "  baseline pass: $(wc -l < ".${lang}_pass_set")  current pass: $(printf '%s\n' "$current" | grep -c . || true)"
    if [ -n "$regressed" ]; then
        echo "  REGRESSED (previously passing, now failing):"
        printf '    %s\n' $regressed
    else
        echo "  regressions: none"
    fi
    if [ -n "$improved" ]; then
        echo "  improved (now passing):"
        printf '    %s\n' $improved
    fi
    if [ -n "$regressed" ] && { [ "$lang" = "estree" ] || [ "$strict" = "--strict" ]; }; then
        echo "  FAIL: pass-set regression on $lang (policy: sh2js pass set is monotonic)" >&2
        exit 1
    fi
}

case "${1:-}" in
    --seed-estree) seed_estree ;;
    --seed)        [ $# -eq 3 ] || { echo "usage: pass_sets.sh --seed <lang> <fails-file>" >&2; exit 2; }
                   seed "$2" "$3" ;;
    --check)       [ $# -ge 3 ] || { echo "usage: pass_sets.sh --check <lang> <fails-file> [--strict]" >&2; exit 2; }
                   check "$2" "$3" "${4:-}" ;;
    --show)        [ -f ".$2_pass_set" ] && cat ".$2_pass_set" || { echo "no .$2_pass_set" >&2; exit 1; } ;;
    *) echo "usage: $0 {--seed-estree|--seed <lang> <fails-file>|--check <lang> <fails-file> [--strict]|--show <lang>}" >&2; exit 2 ;;
esac
