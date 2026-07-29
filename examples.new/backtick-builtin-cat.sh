#!/bin/bash
# Demonstrates backtick command substitution with cat (a shell builtin)
content=`cat /etc/passwd | head -5`
echo "$content"
