#!/bin/bash
# Regression: GNU coreutils tests/chmod/usage.sh uses `case` as a loop
# variable name (`for case in $cases; do`). `case` is only a keyword in
# `case ... esac` context, so this is valid bash, but otranspilerl-cli's parser
# rejects it:
#   Parse error: Unexpected token: Case at 1:1
# Fix target: parser keyword handling for for-loop variable names.
cases="a b c"
for case in $cases; do
    echo "item: $case"
done
