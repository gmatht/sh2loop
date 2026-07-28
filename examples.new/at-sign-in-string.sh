#!/bin/sh
# Verify that @ in double-quoted strings is escaped to \@
# to avoid accidental Perl array interpolation.
echo "Contact: user@example.com"
