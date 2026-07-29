#!/bin/sh
# Pipeline where the first token is a subshell group starting with
# a builtin: `(cd ...)`.  sh2perl must place `command` AFTER the
# opening `(`, producing `(command cd ...)` not `command (cd ...)`.
x=$(cd /tmp && pwd)
echo "$x"
