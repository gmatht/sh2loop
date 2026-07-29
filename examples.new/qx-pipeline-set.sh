#!/bin/sh
# Pipeline starting with `set` (a shell builtin) used in command
# substitution.  sh2perl must prepend `command` so that check_qx.pl
# does not flag the builtin.
s=$(set | head -3)
echo "$s"
