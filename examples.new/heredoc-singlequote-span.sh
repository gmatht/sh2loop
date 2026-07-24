#!/bin/bash
# Regression test: heredoc body containing a single quote causes
# logos to start a SingleQuotedString that spans past the EOF
# delimiter, consuming post-heredoc content.
cat << EOF
It's a sunny day in the neighborhood.
EOF
echo "after heredoc"
data=$(echo "test" | grep -o '[0-9]\+')
echo "$data"
