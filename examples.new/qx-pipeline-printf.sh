#!/bin/sh
# Pipeline starting with printf (a shell builtin) used at top level.
# sh2perl must prefix the qx{} body with `command` so that
# check_qx.pl does not flag the printf builtin.
printf "c\na\nb\n" | sort
