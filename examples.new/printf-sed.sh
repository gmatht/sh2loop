#!/bin/sh
# Demonstrates: printf '%s\n' "$var" | sed '...'  inside command substitution
# Common pattern: printf piped to sed for string transformation
file="/some/path/filename.txt"
base=$(printf '%s\n' "$file" | sed 's|.*/||')
echo "Basename: $base"
