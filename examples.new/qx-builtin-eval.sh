#!/bin/sh
# Command substitution containing `eval` (a shell builtin).
# sh2perl must prepend `command` inside qx{} to avoid check_qx violations.
x=$(eval echo hello)
echo "$x"
