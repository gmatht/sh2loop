#!/bin/bash
# Minimal sample: heredoc with single quotes creates spanning strings in shell lexer
cat > /tmp/heredoc_singlequote_span_x.py << 'EOF'
x = re.search(r'`([^`]+)`', line)
if x == '\'': pass
EOF
echo "ok"
