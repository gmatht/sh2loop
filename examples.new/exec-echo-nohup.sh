#!/bin/sh
# Regression test: check_qx.pl used to flag exec() calls that pass
# 'echo' (a shell builtin) as the program name (EXEC violation).
# sh2perl must wrap exec() calls for builtins through bash -c with
# `command` prefix when used with nohup or similar constructs.
nohup echo "test output" > /dev/null 2>&1 &
