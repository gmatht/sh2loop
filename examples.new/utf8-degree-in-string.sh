#!/bin/sh
# Non-ASCII character (degree symbol °) in a shell string literal.
# sh2perl must escape it as \x{00B0} so that PPI does not choke on
# multi-byte UTF-8 sequences in the generated Perl output.
echo "Temperature: °C"
