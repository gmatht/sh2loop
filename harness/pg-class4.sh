#!/bin/sh
# Classify failures by the FIRST differing hunk, so identical defects group
# together. Usage: pg-class4.sh -f <names-file>
set -u
ROOT=/home/llm/sh2loop
CLI=$ROOT/otranspilerl/target/debug/otranspilerl-cli
OTRANSPILER_ROOT=$ROOT
export OTRANSPILER_ROOT
WORK=$(mktemp -d /tmp/pgc4.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

run_one() {
    name="$1"
    [ -f "$name" ] || name="$ROOT/sh2perl/examples/$name"
    [ -f "$name" ] || { echo "MISSING|$name"; return; }
    base=$(basename "$name")
    d="$WORK/$base.d"
    mkdir -p "$d"
    cp "$name" "$d/prog.sh"
    ( cd "$d" && timeout 25 "$CLI" prog.sh out.pl >gen.log 2>&1 )
    if [ ! -s "$d/out.pl" ]; then
        echo "NOGEN|$base|$(command grep -v 'uu-ffi' "$d/gen.log" | head -1 | tr -d '\n' | cut -c1-110)"
        return
    fi
    ( cd "$d" && timeout 10 perl out.pl >got.txt 2>err.txt; echo $? >rc.txt )
    ( cd "$d" && timeout 10 bash prog.sh >want.txt 2>/dev/null; echo $? >rcw.txt )
    gr=$(cat "$d/rc.txt"); wr=$(cat "$d/rcw.txt")
    if cmp -s "$d/got.txt" "$d/want.txt" && [ "$gr" = "$wr" ]; then
        echo "PASS|$base|"; return
    fi
    if [ "$gr" != "$wr" ]; then
        e=$(command grep -v 'uu-ffi' "$d/err.txt" | head -1 | tr -d '\n' | cut -c1-90)
        echo "EXITCODE|$base|got=$gr want=$wr $e"; return
    fi
    # stdout mismatch: first differing line pair
    h=$(diff "$d/got.txt" "$d/want.txt" 2>/dev/null | command grep -m1 '^<' | cut -c1-60 | tr -d '\n')
    w=$(diff "$d/got.txt" "$d/want.txt" 2>/dev/null | command grep -m1 '^>' | cut -c1-60 | tr -d '\n')
    echo "STDOUT|$base|got[$h] want[$w]"
}

if [ "${1:-}" = "-f" ]; then
    while IFS= read -r ln; do
        [ -n "$ln" ] || continue
        run_one "$ln"
    done < "$2"
else
    for a in "$@"; do run_one "$a"; done
fi
