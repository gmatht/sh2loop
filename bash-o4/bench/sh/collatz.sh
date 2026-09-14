#!/bin/bash
n=$1
total=0
for ((k=0;k<n;k++)); do v=$(( (k*37+3) % 251 )); s=0; while ((v > 1)); do if ((v % 2 == 0)); then v=$((v/2)); else v=$((3*v+1)); fi; s=$((s+1)); done; total=$((total+s)); done
echo $total
