#!/bin/bash
# Regression: GNU coreutils tests/df/sync.sh uses escaped parentheses in
# a case pattern (`sync\(*`, `statfs\(*|fstatfs\(*`). Valid bash, but
# debashc rejects the pattern unless a later `*)` catch-all alternative
# happens to exist:
#   Parse error: Invalid syntax: Expected ')' after case pattern
# Fix target: case-pattern parsing of escaped `\(` / `\)`.
line="sync(1)"
case "$line" in
    sync\(*) echo matched ;;
esac
