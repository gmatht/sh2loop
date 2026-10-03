#!/bin/bash
# pg-tri.sh [outdir] — report the real stdout delta per failing example,
# grouped by defect signature so classes, not instances, are visible.
# stderr is shown separately (the gate ignores stderr; it is a hint, not the cause).
set -u
OUT=${1:-/tmp/pgbase}
cd "$OUT/run" || exit 2

for d in */; do
    n=${d%/}
    v=$(cat "$d/verdict" 2>/dev/null)
    [ "$v" = PASS ] && continue
    [ -f "$d/bash.out" ] || { printf '### %-46s GENFAIL\n' "$n"; continue; }
    # first differing line, bash side vs perl side
    dl=$(diff "$d/bash.out" "$d/pl.out" 2>/dev/null | sed -n '1p')
    bx=$(cat "$d/bash.exit" 2>/dev/null); px=$(cat "$d/pl.exit" 2>/dev/null)
    nmiss=$(diff "$d/bash.out" "$d/pl.out" 2>/dev/null | command grep -c '^< ')
    nadd=$(diff "$d/bash.out" "$d/pl.out" 2>/dev/null | command grep -c '^> ')
    err=$(head -1 "$d/pl.err" 2>/dev/null | cut -c1-72)
    printf '### %-46s %-8s exit %s/%s  -%s +%s\n' "$n" "$v" "$bx" "$px" "$nmiss" "$nadd"
    printf '    %s\n' "${dl:-<identical stdout>}"
    [ -n "$err" ] && printf '    stderr: %s\n' "$err"
done
