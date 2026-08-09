#!/bin/bash
# Regression: unquoted `$i` as an echo argument is not word-split on IFS
# by either backend. bash field-splits unquoted expansions, so
#   i='a  b'; echo $i
# prints `a b` (two words -> two args, echo joins with one space). Both
# backends emit a scalar write of the raw value instead:
#   perl:   print($i, "\n")                                          -> "a  b"
#   estree: process.stdout.write([String(i)].join(" ") + "\n")       -> "a  b"
# Fix target: field-splitting on unquoted variable/positional/`for in`
# args in the shir lowering (the runtime's captureWords already splits
# `$(...)`; plain $var / $1 args do not). Goes green when the fix lands
# (AGENTS.md: red by design, never bless).
i='a  b'
echo $i
