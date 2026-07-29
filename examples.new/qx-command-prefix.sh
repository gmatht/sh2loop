#!/bin/sh
# qx-command-prefix.sh
# Demonstrates the pattern where the generator emits qx{command $_qx_cmd[0]}
# to hide builtins from check_qx.pl.  The 'command' prefix should NOT be
# flagged because it is a shell mechanism, not a command with a native Perl equivalent.
echo "Welcome to $(lsb_release -s -d)"
