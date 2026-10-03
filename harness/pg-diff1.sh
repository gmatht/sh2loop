#!/bin/sh
# Detail diff for one example: shows the first differing byte region.
# Usage: pg-diff1.sh <example.sh>
set -u
ROOT=/home/llm/sh2loop
CLI=$ROOT/otranspilerl/target/debug/otranspilerl-cli
OTRANSPILER_ROOT=$ROOT
export OTRANSPILER_ROOT
name="$1"
[ -f "$name" ] || name="$ROOT/sh2perl/examples/$name"
W=$(mktemp -d /tmp/pgd.XXXXXX)
trap 'rm -rf "$W"' EXIT
cp "$name" "$W/prog.sh"
( cd "$W" && timeout 25 "$CLI" prog.sh out.pl >gen.log 2>&1 )
echo "--- gen log ---"; head -5 "$W/gen.log"
( cd "$W" && timeout 10 perl out.pl >got.txt 2>err.txt; echo $? >rc.txt )
( cd "$W" && timeout 10 bash prog.sh >want.txt 2>/dev/null )
echo "--- rc got=$(cat "$W/rc.txt") want=$( [ -f "$W/rc.txt" ] && echo ) ---"
echo "--- stderr(perl) ---"; head -5 "$W/err.txt"
echo "--- diff (got < / want >) ---"
diff "$W/got.txt" "$W/want.txt" | head -30
echo "--- byte sizes: got=$(wc -c < "$W/got.txt") want=$(wc -c < "$W/want.txt") ---"
