#!/bin/sh
# Test: command -v (find executable in PATH)
if command -v btrfs >/dev/null 2>&1; then
    echo "btrfs found"
fi
