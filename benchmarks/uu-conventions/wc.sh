#!/bin/bash
# wc: per-iteration `wc -l FILE > /dev/null` — the cheapest utility, so it
# measures dispatch overhead rather than the utility's own work.
n=${1:-1000}
for ((i=0;i<n;i++)); do wc -l /tmp/uuconv/in.txt ; done
