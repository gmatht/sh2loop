#!/bin/bash
# c-arr-cap-scan.sh — make the ARR_CAP assumption OBSERVABLE over the corpus.
#
# C_UB_PROOF.md §2b calls `array_caps` "the unproven bound": the C backend
# sizes each fixed table from a syntactic census (`max_reset` literal bulk +
# bounded appends), declares `static T name[cap] = {0}`, then writes the
# elements one by one with no per-store check. If the census under-counts,
# those stores run past the declaration. Two things guard that:
#   * `array_fixed_caps` routes anything it cannot prove (or whose need
#     reaches ARR_CAP = 1024) to the growable vec instead of a fixed table;
#   * `emit_set_array` carries a `debug_assert!` that the static bulk fits
#     the declared cap — live in every debug build, i.e. in this scan.
#
# This script renders the whole example set through a DEBUG CLI and reports:
#   panic      — renders that tripped the cap assertion (must be 0)
#   tables     — fixed tables emitted (`static T name[N] = {0};`)
#   at-cap     — of those, declarations at the ARR_CAP ceiling
#   max-below  — largest fixed capacity strictly below the ceiling
#   max-bulk   — largest number of element stores the renderer emitted into
#                ONE table (the `name[_aiK] = ...` runs), i.e. max_reset
#   over       — tables whose emitted bulk exceeds their declared capacity
#                (must be 0; the assertion should have caught it first)
#
# Usage: harness/c-arr-cap-scan.sh [--quiet] [example.sh ...]
# Exit: 0 when panic = 0 and over = 0, else 1.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="${CORE_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
ARR_CAP=1024
QUIET=0
if [ "${1:-}" = "--quiet" ]; then QUIET=1; shift; fi
if [ $# -gt 0 ]; then files=("$@"); else files=("$ROOT"/sh2perl/examples/*.sh); fi

if [ ! -x "$CORE" ]; then
    echo "c-arr-cap-scan: no CLI at $CORE (build it: cd otranspilerl && cargo build --bin otranspilerl-cli)" >&2
    exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

panics=0 tables=0 atcap=0 maxbelow=0 maxbulk=0 over=0 renders=0
for f in "${files[@]}"; do
    out="$tmp/out.c"
    if ! "$CORE" "$f" --target c >"$out" 2>"$tmp/err"; then
        if command grep -q 'panicked at' "$tmp/err"; then
            panics=$((panics + 1))
            echo "PANIC $f" >&2
            sed -n '1,2p' "$tmp/err" >&2
        fi
        continue
    fi
    renders=$((renders + 1))
    if command grep -q 'panicked at' "$tmp/err"; then
        panics=$((panics + 1))
        echo "PANIC $f" >&2
        sed -n '1,2p' "$tmp/err" >&2
    fi
    # declarations: `static char *a[5] = {0};`, `static long long d[10] = {0};`
    awk -v cap="$ARR_CAP" '
        match($0, /^static [A-Za-z_][A-Za-z_0-9 ]*\*?([A-Za-z_][A-Za-z_0-9]*)\[([0-9]+)\] = \{0\};/, m) {
            n = m[2] + 0
            print m[1], n
        }' "$out" > "$tmp/decls" 2>/dev/null
    if [ ! -s "$tmp/decls" ]; then
        # mawk has no match(..., arr); fall back to sed for the same shape
        sed -nE 's/^static [A-Za-z_][A-Za-z_0-9 ]*\*?([A-Za-z_][A-Za-z_0-9]*)\[([0-9]+)\] = \{0\};/\1 \2/p' "$out" > "$tmp/decls"
    fi
    while read -r name n; do
        [ -z "$name" ] && continue
        tables=$((tables + 1))
        if [ "$n" -ge "$ARR_CAP" ]; then atcap=$((atcap + 1)); else
            [ "$n" -gt "$maxbelow" ] && maxbelow=$n
        fi
        # element stores into this table: `name[_aiK] = ...`
        bulk=$(command grep -cE "(^|[^A-Za-z_0-9])${name}\[_ai[0-9]+\] *=" "$out")
        if [ "$bulk" -gt "$maxbulk" ]; then maxbulk=$bulk; fi
        if [ "$bulk" -gt "$n" ]; then
            over=$((over + 1))
            echo "OVER $f: $name declared [$n], $bulk element stores" >&2
        fi
    done < "$tmp/decls"
done

[ "$QUIET" = 0 ] && echo "c-arr-cap-scan: $((${#files[@]})) files, $renders rendered"
echo "panic=$panics tables=$tables at-cap=$atcap max-below=$maxbelow max-bulk=$maxbulk over=$over"
[ "$panics" -eq 0 ] && [ "$over" -eq 0 ]
