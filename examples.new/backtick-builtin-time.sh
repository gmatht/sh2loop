#!/bin/bash
# Demonstrates backtick command substitution with time (a shell builtin)
result=`time sleep 1 2>&1`
echo "Time result: $result"
