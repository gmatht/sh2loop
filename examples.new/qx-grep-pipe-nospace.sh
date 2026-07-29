#!/bin/sh
# Regression test: check_qx.pl used to flag qx{} calls containing
# 'grep' when a pipe operator lacks surrounding spaces (e.g.
# 'mount|grep' is parsed as a single word 'mount|grep', causing
# a false positive grep detection).  sh2perl must reconstruct the
# command string with spaces around pipe operators.
if mount|grep -q /dev/sda; then echo "mounted"; fi
