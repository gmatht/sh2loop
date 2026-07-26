#!/bin/bash
# Demonstrates heredoc parsing failure when the content after the heredoc
# delimiter causes unexpected end of input.  Minimal pattern: a heredoc
# followed by variable interpolation and redirect.
cat <<EOF
some text
EOF
