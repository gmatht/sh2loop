#!/bin/sh
# Regression test: check_qx.pl used to flag qx{} calls containing
# 'env' as a shell builtin.  sh2perl must prepend `command` so the
# generated Perl uses 'command env ...' instead of bare 'env ...'.
x=$(env LC_ALL=C.UTF-8 myprogram --help 2>/dev/null)
echo "$x"
