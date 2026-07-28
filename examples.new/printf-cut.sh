#!/bin/sh
# Demonstrates: printf '%s' "$var" | cut -cN-M  inside command substitution
# Common pattern: printf piped to cut for substring extraction
str="abcdef"
sub=$(printf '%s' "$str" | cut -c2-4)
echo "Substring: $sub"
