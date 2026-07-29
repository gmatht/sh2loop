#!/bin/bash
# Demonstrates backtick command substitution with sed (a shell builtin)
result=`echo "hello world" | sed 's/world/universe/'`
echo "$result"
