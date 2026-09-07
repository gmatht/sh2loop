#!/bin/bash
# debug one example through the estree path: emits JSON, runs gate + node, diffs vs bash
# usage: harness/dbg.sh <example.sh>
set -u
cd /home/llm/sh2loop
EX=$1
BASE=$(basename "$EX" .sh)
TMP=$(mktemp -d /tmp/dbg-XXXX)
cd sh2perl && ./target/release/otranspilerl-cli --target estree "../$EX" > "$TMP/prog.estree.json" 2>"$TMP/emit-err.txt"
EMIT=$?
cd /home/llm/sh2loop
if [ $EMIT -ne 0 ] || ! grep -q '"type":"Program"' "$TMP/prog.estree.json"; then
  echo "EMIT FAILED"; cat "$TMP/emit-err.txt" | head -5; exit 1
fi
perl harness/estree_gate.pl "$TMP/prog.estree.json"
node harness/estree-runner.mjs "$TMP/prog.estree.json" > "$TMP/est.out" 2>"$TMP/est.err"
EST=$?
bash "$EX" > "$TMP/bash.out" 2>/dev/null
BASH=$?
echo "=== estree exit=$EST  bash exit=$BASH ==="
if [ $EST -ne 0 ]; then
  echo "--- estderr ---"; head -20 "$TMP/est.err"
fi
echo "--- diff (bash vs estree) ---"
diff <(cat "$TMP/bash.out") <(cat "$TMP/est.out") | head -40
echo "--- bash out (first 15 lines) ---"; head -15 "$TMP/bash.out"
echo "--- estree out (first 15 lines) ---"; head -15 "$TMP/est.out"
echo "TMP=$TMP"
