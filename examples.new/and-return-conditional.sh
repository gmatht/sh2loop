#!/bin/bash
# Regression test: logical AND with a return command in a function.
# The generated Perl used to put the return and closing brace on the
# same line, confusing perlcritic's scoping analysis.  Also, do { }
# blocks used for command substitution carried my-declarations that
# perlcritic flagged as conditional declarations.
test -f /etc/motd && return
tmp=$(mktemp -d)
echo "$tmp"
