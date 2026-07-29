#!/bin/sh
# Pipeline where a multiline sed script is passed to sed via
# the pipeline source text.  The generator must not truncate
# to the first line (which would produce an unterminated qx{}).
set | sed -n "
/^PATH=/ {
    p
}"
