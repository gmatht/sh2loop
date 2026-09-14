#!/bin/bash
# addsum: scalar accumulation (bash-native i64). The addsum32 problem
# reuses this exact script with a smaller N (int32-exact sum).
n=$1
s=0
for ((i=0;i<n;i++)); do s=$((s+i)); done
echo $s
