#!/bin/sh
# Demonstrates: printf '%s' "$var" | wc -c  inside command substitution
# sh2perl was generating qx{bash -c 'printf ... | wc -c'} which check_qx flagged
var="hello world"
len=$(printf '%s' "$var" | wc -c)
echo "Length: $len"
