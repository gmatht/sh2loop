#!/bin/sh
# Dangling || after heredoc (no right operand)
cat >/tmp/parse_heredoc_or_dangling_file <<EOF ||
content
EOF
echo done
