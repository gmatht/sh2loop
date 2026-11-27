#!/bin/bash
# sort-capture: per-iteration `v=$(sort -r FILE)` — the CAPTURE arm (pipe +
# reader thread inside sh2_uu_capture), then a plain wc run.
n=${1:-1000}
for ((i=0;i<n;i++)); do
  v=$(sort -r /tmp/uuconv/in.txt)
  wc -l /tmp/uuconv/in.txt
done
echo "${#v}"
