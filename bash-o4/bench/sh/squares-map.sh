#!/bin/bash
# squares-map: materialise a[i]=i*i, then a mod-2^32 checksum (the fair
# CPU counterpart to a GPU map+readback: same memory traffic). Matches
# bench/c/squaresmap.c exactly (unsigned wrap per element, u32 sum).
n=$1
for ((i=0;i<n;i++)); do a[$i]=$((i*i)); done
s=0
for ((i=0;i<n;i++)); do s=$(((s + a[i]) & 0xFFFFFFFF)); done
echo $s
