#!/bin/bash
# sumred: mod-2^32 accumulate of i*i (overflow-exact on every side).
n=$1
s=0
for ((i=0;i<n;i++)); do s=$(( (s + (i*i)%4294967296) % 4294967296 )); done
echo $s
