#!/bin/bash
# Demonstrates backtick command substitution with id (a shell builtin)
user=`id -u`
echo "User ID: $user"
