#!/bin/sh
# Demonstrate false positive: check_qx.pl used to flag 'set' in
# dialog text argument even though 'set' is not the command.
# The command is '$cmd' (an external program), not 'set'.
cmd=/bin/echo
result=`$cmd --dialog "Please set the time..." 2>&1`
echo "$result"
