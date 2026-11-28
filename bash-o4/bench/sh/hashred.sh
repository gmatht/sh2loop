#!/bin/bash
# hashred: the `hash.sh` mix reduced to ONE masked accumulate, so the loop is
# a GPU candidate. hash.sh's two `%256` chains feeding a third are vetoed by
# candidacy (`non-single-accumulate`); this variant keeps the part a GPU can
# take — a per-element integer term folded into a masked register — and is
# what BASH_BENCH.md §3a quotes (gcc -O3 0.84 s at 1e9 vs ~2.8 ms on the
# GPU). The term is `i*i*7` rather than `(i*53)%256` + `(i*89)%256` because a
# chain of signed `%` is exactly the shape `docs/BASH-O4.md` §4.3 vetoes.
n=$1
s=0
for ((i=0;i<n;i++)); do s=$(( (s + i*i*7) & 0xFFFFFFFF )); done
echo $s
