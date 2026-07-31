#!/bin/bash
# Regression: GNU coreutils tests/printf/printf.sh runs a command with an
# env-var prefix whose name is a variable, inside an if condition
# (`if POSIXLY_CORRECT=1 $prog '2 \x' >/dev/null 2>&1; then`). Valid
# bash, but the lexer chokes on `$prog` after the env prefix:
#   Parse error: Lexer error: Unexpected character: $ at 1:22
# Fix target: env-var-prefixed commands in if conditions.
prog=echo
if POSIXLY_CORRECT=1 $prog hi >/dev/null 2>&1; then
    echo ok
fi
