#!/bin/bash
# Test: cd && non-builtin command in $(...) command substitution
# Verifies that 'cd <dir> && git ...' does not generate qx{} with builtin 'cd'
REV="$(cd .. && echo ok)"
echo "$REV"
