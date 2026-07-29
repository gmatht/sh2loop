#!/bin/bash
# Demonstrates backtick command substitution with grep (a shell builtin)
result=`echo "hello world" | grep hello`
echo "$result"
