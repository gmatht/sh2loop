#!/bin/sh
# bash-c-command-prefix.sh
# Demonstrates the pattern where the generator emits open3/bash -c with
# 'command echo' inside the command string (e.g., for gzip pipeline simulation).
# The 'command' prefix is a shell mechanism to bypass function overrides;
# in Perl-generated code it is unnecessary but should not be flagged.
gzip -lv < /dev/null 2>/dev/null | grep 'defl' > /dev/null
