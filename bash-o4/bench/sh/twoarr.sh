#!/bin/bash
# twoarr: a MULTI-STORE fill (two arrays) consumed by one reduction —
# the shape fuse-fill-consume's multi-store generalisation targets. The
# rewritten form is a single pass with no arrays at all; the handwritten
# reference below materialises both (two-pass, ~1.6GB of traffic at the
# N=2e5 gate size is still cache-resident, so compare at large N too).
n=$1
for ((i=0;i<n;i++)); do a[$i]=$((i*i)); b[$i]=$((i+1)); done
s=0
for ((i=0;i<n;i++)); do s=$(((s + a[i]*b[i]) & 0xFFFFFFFF)); done
echo $s
