#!/bin/bash
tr "[:upper:]" "[:lower:]" <<< "$(echo "UPPER: X")"
echo "---"
tr "[:upper:]" "[:lower:]" <<< "ABC"
echo "---"
cat <<< "lit"
echo "---"
cat <<< $(echo cmdsub)
echo "---"
x=VAL
cat <<< "$x"
echo "---"
cat <<< "${x}s"