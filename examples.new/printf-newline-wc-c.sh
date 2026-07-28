#!/bin/sh
# Demonstrates: printf '%s\n' "$var" | wc -c  inside command substitution
# Includes trailing newline in the count
var="hello"
size=$(printf '%s\n' "$var" | wc -c)
echo "Size: $size"
