#!/bin/bash
# Minimal reproduction: calling system() with a builtin 'return'
# This tests that the generator does not emit system('return').
result=$(return 42 2>/dev/null) || true
echo "Result: $result"
