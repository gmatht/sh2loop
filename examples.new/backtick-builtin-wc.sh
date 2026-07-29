#!/bin/bash
# Demonstrates backtick command substitution with wc (a shell builtin)
count=`echo "hello world" | wc -w`
echo "Word count: $count"
