#!/bin/bash
# Regression: GNU coreutils tests/dd/bytes.sh assigns a command
# substitution concatenated with a digit suffix:
#   long_multiplier=$(yes 1x | head -n 10000 | tr -d '\n')1
# A digit immediately after the closing `)` (or `}`) of an expansion is
# misparsed as a redirect file descriptor:
#   Parse error: Invalid syntax: Invalid redirect operator
# Fix target: `)` / `}` followed by a digit inside a word.
long_multiplier=$(echo 1x)1
echo "$long_multiplier"
