#!/bin/sh
# Regression test: check_qx.pl used to flag qx{} calls containing
# 'cat' in a subshell because the generated '(cat; ...)' made 'cat'
# appear as the first word (after stripping '(').  sh2perl must add
# spaces inside subshell parentheses: '( cat; ... )' so the first
# word is just '('.
result=$( (cat /dev/null; echo "done") 2>/dev/null)
echo "$result"
