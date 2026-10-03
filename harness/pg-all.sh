#!/bin/bash
# Batch repro of the whole perl-generator failure list, faithful to ./fail env.
# Usage: harness/pg-all.sh [outfile]
OUT="${1:-/tmp/pg-all.txt}"
: > "$OUT"
while read -r e; do
  [ -n "$e" ] || continue
  r=$(timeout 120 /home/llm/sh2loop/harness/pg-one.sh "$e" 2>&1 | tr '\n' '|')
  echo "$e :: $r" >> "$OUT"
done < harness/pg-fail-names.txt
echo "done -> $OUT"
