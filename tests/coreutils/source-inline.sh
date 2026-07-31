#!/bin/bash
# Regression: `. file` / `source file` are not inlined by the Perl
# backend. The generated code emits system('.', './lib.sh') (which fails
# at runtime: there is no executable named ".") and `source` is dropped
# entirely ("Builtin command 'source' not implemented"), so variables and
# functions defined in the sourced file are undefined. Every GNU coreutils
# test sources `tests/init.sh` this way, so this blocks running that
# suite's scripts through the transpiler.
echo 'greeting=hello' > lib.sh
. ./lib.sh
echo "$greeting"
rm -f lib.sh
