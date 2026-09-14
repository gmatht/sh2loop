#!/bin/bash
# hash: per-record integer mix, accumulator kept mod 256 (the
# sh2runtime hash shape; modulo chains defeat the vectoriser).
n=$1
s=0
for ((i=0;i<n;i++)); do a=$(( (i*53) % 256 )); b=$(( (i*89) % 256 )); s=$(( (s + a*31 + b*17) % 256 )); done
echo $s
