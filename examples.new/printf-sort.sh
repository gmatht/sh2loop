#!/bin/sh
# Demonstrates: printf '%s\n' "$var" | sort  inside command substitution
# Common pattern: printf piped to sort for sorting lines
items="banana
apple
cherry"
sorted=$(printf '%s\n' "$items" | sort)
echo "$sorted"
