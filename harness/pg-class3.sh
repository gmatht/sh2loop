#!/bin/sh
# Reproduce perl-generator failures for a list of examples and print a
# compact signature per failure so classes can be counted.
# Usage: pg-class3.sh <example.sh> [<example.sh> ...]
#        pg-class3.sh -f <file-with-names>
set -u
ROOT=/home/llm/sh2loop
CLI=$ROOT/otranspilerl/target/debug/otranspilerl-cli
# The CLI locates its workspace root by walking up from cwd; the per-example
# temp dir has no such ancestor, so it must be told explicitly.
OTRANSPILER_ROOT=$ROOT
export OTRANSPILER_ROOT
WORK=$(mktemp -d /tmp/pgc.XXXXXX) || exit 1
trap 'rm -rf "$WORK"' EXIT

list=""
if [ "${1:-}" = "-f" ]; then
    list=$(command grep -v '^[[:space:]]*$' "$2")
else
    list="$*"
fi

for name in $list; do
    name=$(printf '%s' "$name" | sed 's/^\[perl\] //; s/[[:space:]]*$//')
    [ -f "$name" ] || name="$ROOT/sh2perl/examples/$name"
    if [ ! -f "$name" ]; then
        echo "MISSING  $name"
        continue
    fi
    base=$(basename "$name")
    d="$WORK/$base.d"
    mkdir -p "$d"
    cp "$name" "$d/prog.sh"
    ( cd "$d" && timeout 25 "$CLI" prog.sh out.pl >gen.log 2>&1 )
    genrc=$?
    if [ ! -s "$d/out.pl" ]; then
        echo "NOGEN($genrc)  $base :: $(head -c 150 "$d/gen.log" | tr '\n' ' ')"
        continue
    fi
    ( cd "$d" && timeout 10 perl out.pl >got.txt 2>err.txt; echo $? >rc.txt )
    ( cd "$d" && timeout 10 bash prog.sh >want.txt 2>/dev/null; echo $? >rcw.txt )
    gotrc=$(cat "$d/rc.txt"); wantrc=$(cat "$d/rcw.txt")
    if cmp -s "$d/got.txt" "$d/want.txt" && [ "$gotrc" = "$wantrc" ]; then
        echo "PASS      $base"
    elif [ "$gotrc" != "$wantrc" ]; then
        echo "EXITCODE  $base  got=$gotrc want=$wantrc :: $(head -c 100 "$d/err.txt" | tr '\n' ' ')"
    else
        # classify the stdout mismatch
        sig=$(awk 'NR==1{print "got|["$0"]"}' "$d/got.txt" 2>/dev/null)
        sigw=$(awk 'NR==1{print "want|["$0"]"}' "$d/want.txt" 2>/dev/null)
        if command grep -qE 'Can.t locate|No such file|syntax error|Global symbol|Undefined sub|not allowed' "$d/err.txt"; then
            echo "PERLERR   $base :: $(head -c 120 "$d/err.txt" | tr '\n' ' ')"
        else
            echo "STDOUT    $base  $sig  vs  $sigw"
        fi
    fi
done
