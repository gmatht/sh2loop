#!/bin/sh
# Demonstrates: printf '%s' "$var" | tr -d -c '...' | wc -c
# 3-command pipeline: filter characters then count
var="abc123def456"
alnum_count=$(printf '%s' "$var" | tr -d -c 'A-Za-z0-9' | wc -c)
echo "Alphanumeric count: $alnum_count"
