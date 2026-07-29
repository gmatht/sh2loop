#!/bin/sh
# Demonstrate perl -i -ne with in-place editing and file arguments.
# The -i.bak flag comes before -ne, which previous sh2perl versions
# did not detect (only checked position 0 for -e/-ne), causing it to
# fall back to eval qq{perl ...} which triggered Perl::Critic violations.

MSG_FILE=/tmp/test_commit_msg.txt
echo "initial content" > "$MSG_FILE"
/usr/bin/perl -i.bak -ne 'print unless(m/^#/)' "$MSG_FILE"
cat "$MSG_FILE"
