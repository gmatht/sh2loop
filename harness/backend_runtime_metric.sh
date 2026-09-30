#!/usr/bin/env bash
# backend_runtime_metric.sh — count each backend's calls into ITS OWN runtime.
#
# WHY THIS EXISTS. The per-tree board reports, for a green tree, how much it
# still delegates to its runtime. The number it had was the gate's `stub`
# count, which is `grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\('
# (setup_backends.sh:1337). That pattern sees the `sh2_*` namespace ONLY.
#
# The backends do not share that namespace. Measured 2026-09-30 on
# 000__04c_text_processing_commands.sh:
#
#     backend   runtime calls in the output   gate's stub count
#     c             309  _sh_*                        0
#     rust          166  __sh_*                       0
#     perl           33  __sh_*                       0
#     zig            44  sh2*                        (sees it)
#     js/estree      51  sh2.*                       (sees it)
#
# So a 0 from that pattern means "this backend names its runtime something
# else", not "this backend is native" — and the board was printing it as the
# latter. Each namespace below was read off a real render, not guessed.
#
# WHAT IT IS NOT. The totals are NOT comparable across backends as a quality
# ranking: they measure how big each runtime's API is, not how native the
# lowering is. rust delegating 166 times to `__sh_print_words` is not 40x
# worse than python delegating 4 times to `__sh_exec` — a bulk helper can
# replace what another target spells out in many lines. Use the number to
# find the backends still leaning on their runtime, not to rank them.
#
# Usage:  harness/backend_runtime_metric.sh [LANG ...]
# Writes: <tree>/.rt_metric.tsv   (key<TAB>value, `total` first)
#         and prints the same table. progress.sh reads the per-tree file.
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
export OTRANSPILER_ROOT="${OTRANSPILER_ROOT:-$ROOT}"

[ -x "$CLI" ] || { echo "backend_runtime_metric: $CLI missing" >&2; exit 1; }

# The namespace each renderer actually emits. Keep these in step with the
# renderers; a backend that renames its runtime must be updated here or it
# silently reports 0 — which is the bug this script exists to stop.
SEAM_c='_sh_[A-Za-z_0-9]+'
SEAM_rust='__sh_[A-Za-z_0-9]+'
SEAM_perl='__sh_[A-Za-z_0-9]+'
SEAM_python='__sh_[A-Za-z_0-9]+'
SEAM_zig='sh2[A-Za-z_0-9]+'
SEAM_go='s2s|capRun|capCmd|runCmd|redirRun|redirCap'
SEAM_java='sh[A-Z][A-Za-z0-9]+'
SEAM_js='sh2\.[A-Za-z_0-9]+'
SEAM_sh='sh2[a-z_]+\('

ext_for() { case "$1" in c) echo c;; rust) echo rs;; perl) echo pl;; python) echo py;;
                  zig) echo zig;; go) echo go;; java) echo java;; js) echo mjs;; sh) echo sh;; esac; }
seam_for() { eval "printf '%s' \"\${SEAM_$1:-}\""; }

# The tree a backend's gate lives in, so the number lands beside the gate's
# own state (fail-estree's $outdir rule: a worker's state is its own).
tree_for() { case "$1" in estree) echo estree;; *) echo "$1";; esac; }

LANGS="${*:-c rust perl python zig go java js}"
CORPUS=("$ROOT"/sh2perl/examples/*.sh)
[ -e "${CORPUS[0]}" ] || { echo "no corpus under sh2perl/examples" >&2; exit 1; }

printf '%-8s %8s %10s %12s  %s\n' backend files calls per_file namespace
for lang in $LANGS; do
    seam=$(seam_for "$lang")
    [ -n "$seam" ] || { printf '%-8s (no seam defined — update SEAM_%s)\n' "$lang" "$lang"; continue; }
    ext=$(ext_for "$lang")
    tree=$(tree_for "$lang")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    files=0; total=0
    for f in "${CORPUS[@]}"; do
        [ -f "$f" ] || continue
        out="$tmp/$(basename "$f").$ext"
        # A render that fails is SKIPPED, not counted as zero calls: an
        # unrenderable file has no output to measure, and counting it as 0
        # would make a broken backend look like a native one.
        if "$CLI" "$f" "$out" --target "$lang" >/dev/null 2>&1 && [ -s "$out" ]; then
            n=$(grep -oE "$seam" "$out" 2>/dev/null | wc -l)
            total=$((total + n)); files=$((files + 1))
        fi
    done
    per=$( [ "$files" -gt 0 ] && echo $((total / files)) || echo 0 )
    printf '%-8s %8d %10d %12d  %s\n' "$lang" "$files" "$total" "$per" "$seam"
    # Per-tree artefact for progress.sh, written into the tree the gate for
    # this backend measures — same rule fail-estree uses, so two workers
    # measuring two trees cannot clobber each other.
    outdir="$ROOT/sh2perl/backends/$tree"
    [ -d "$outdir" ] || outdir="$ROOT/sh2perl"
    {
        printf 'total\t%d\n' "$total"
        printf 'files\t%d\n' "$files"
        printf 'per_file\t%d\n' "$per"
        printf 'seam\t%s\n' "$seam"
    } > "$outdir/.rt_metric.tsv"
    rm -rf "$tmp"; trap - EXIT
done
