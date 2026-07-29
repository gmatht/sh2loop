#!/bin/bash
# Demonstrates backtick command substitution with readlink (a shell builtin)
result=`readlink -f /proc/self/exe`
echo "$result"
