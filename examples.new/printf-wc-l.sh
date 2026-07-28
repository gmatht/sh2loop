#!/bin/sh
# Demonstrates: printf '%s' "$var" | wc -l  inside command substitution
# Counts lines in a variable (wc -l counts newlines)
var="line1
line2
line3"
count=$(printf '%s' "$var" | wc -l)
echo "Lines: $count"
