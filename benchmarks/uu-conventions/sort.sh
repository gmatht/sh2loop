#!/bin/bash
# sort: per-iteration `sort FILE > /dev/null` — the plain-run (uu_run) arm.
n=${1:-1000}
for ((i=0;i<n;i++)); do sort /tmp/uuconv/in.txt ; done
