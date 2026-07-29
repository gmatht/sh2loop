#!/bin/sh
# Command substitution containing `exec` (a shell builtin).
# sh2perl must prepend `command` inside qx{} to avoid check_qx violations.
x=$(exec echo hello)
echo "$x"
