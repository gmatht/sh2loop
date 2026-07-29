#!/bin/sh
# Regression test: check_qx.pl used to flag open3() calls that pass
# 'gunzip' as the program argument (OPEN3 violation with builtin).
# sh2perl must use 'bash -c' wrapping with `command gunzip -c ...`
# instead of bare 'gunzip' in open3().
gzip -d /tmp/testfile.Z 2>/dev/null || true
