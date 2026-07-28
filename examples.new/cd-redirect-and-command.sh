#!/bin/bash
# Test: cd with redirect && command in $(...) command substitution
# cd "$orig_git" 2>/dev/null && git rev-parse --git-dir is a real pattern
DIR="$(cd /tmp 2>/dev/null && ls /)"
echo "$DIR"
