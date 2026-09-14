#!/bin/bash
# squares: sum of squares (i64 multiply-accumulate; PMULLQ absent
# pre-AVX512DQ, so scalar on this hardware by construction).
n=$1
s=0
for ((i=0;i<n;i++)); do s=$((s + i*i)); done
echo $s
