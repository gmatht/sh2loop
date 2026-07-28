#!/bin/bash
# Regression test: heredoc with Python/JS code containing braces, and other delimiters
cat > /tmp/heredoc_with_braces_test.py << 'PYEOF'
def foo():
    if True:
        return {"key": "value"}
PYEOF
echo "heredoc done"
